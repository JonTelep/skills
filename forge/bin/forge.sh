#!/usr/bin/env bash
# forge.sh — outer harness: run /forge iterations, classify exits, survive
# usage-limit windows, notify via telegram, park at barriers and accept
# approve/redirect replies (single-project poller; forged replaces it in slice 3).
#
# usage: forge.sh <project-dir> [--once]
set -uo pipefail

PROJECT_DIR="$(cd "${1:?usage: forge.sh <project-dir> [--once]}" && pwd)"
ONCE="${2:-}"
PROJECT="$(basename "$PROJECT_DIR")"
FORGE_DIR="$PROJECT_DIR/.forge"
CONFIG="${HOME}/.forge/config"
LOG="$FORGE_DIR/harness.log"
OFFSET_FILE="${HOME}/.forge/telegram.offset"

MODEL="${FORGE_MODEL:-opus}"
PERMISSION_MODE="${FORGE_PERMISSION_MODE:-bypassPermissions}"
LIMIT_RETRY_MIN="${FORGE_LIMIT_RETRY_MIN:-30}"   # fallback when reset time unparseable
PARK_POLL_SEC=25                                  # telegram long-poll timeout
MAX_CONSEC_FAIL=3

[ -f "$CONFIG" ] && . "$CONFIG"   # TELEGRAM_TOKEN, TELEGRAM_CHAT_ID
mkdir -p "$FORGE_DIR"

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

tg_send() {  # tg_send <text>
  [ -n "${TELEGRAM_TOKEN:-}" ] || { log "telegram not configured; msg: $1"; return 0; }
  curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=[${PROJECT}] $1" >/dev/null \
    || log "telegram send FAILED"
}

flush_outbox() {  # send every unsent gate/barrier message
  local f
  for f in "$FORGE_DIR"/outbox/*.md; do
    [ -e "$f" ] || continue
    tg_send "$(cat "$f")"
    mkdir -p "$FORGE_DIR/outbox-sent"
    mv "$f" "$FORGE_DIR/outbox-sent/"
    log "sent outbox $(basename "$f")"
  done
}

# Poll telegram for replies. $1 = long-poll timeout seconds (0 = non-blocking).
# "stop" → notify + exit harness (after the current iteration, since this runs
# between iterations). Anything else → DIRECTION.md, consumed next iteration.
# Single-consumer getUpdates: run only ONE forge.sh per bot until forged (slice 3).
poll_reply() {
  local timeout="${1:-$PARK_POLL_SEC}"
  [ -n "${TELEGRAM_TOKEN:-}" ] || { [ "$timeout" -gt 0 ] && sleep 60; return 1; }
  local offset resp text next
  offset="$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)"
  resp="$(curl -sf "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?timeout=${timeout}&offset=${offset}")" || return 1
  next="$(echo "$resp" | jq -r '([.result[].update_id] | max) as $m | if $m then $m + 1 else empty end' 2>/dev/null)"
  [ -n "$next" ] && echo "$next" > "$OFFSET_FILE"
  text="$(echo "$resp" | jq -r --arg chat "${TELEGRAM_CHAT_ID}" \
    '[.result[] | select(.message.chat.id == ($chat|tonumber)) | .message.text // empty] | join("\n")' 2>/dev/null)"
  [ -n "$text" ] || return 1
  log "reply received: $text"
  if grep -qixE '\s*(stop|halt|pause)\s*' <<<"$text"; then
    tg_send "stopping harness as requested. resume with: forge-start $PROJECT_DIR"
    log "STOP requested via telegram — exiting"
    exit 0
  fi
  printf '%s\n' "$text" >> "$FORGE_DIR/DIRECTION.md"
  tg_send "got it — will act on: \"$text\""
  return 0
}

# Try to parse a reset time from claude's limit message; sleep until then.
sleep_until_reset() {
  local out="$1" now target secs
  # patterns like "resets 3pm", "resets at 14:00", "resets 11:30pm"
  local t
  t="$(grep -oiE 'resets( at)? [0-9]{1,2}(:[0-9]{2})?(am|pm)?' <<<"$out" | head -1 | sed -E 's/resets( at)? //I')"
  if [ -n "$t" ] && target="$(date -d "$t" +%s 2>/dev/null)"; then
    now="$(date +%s)"
    [ "$target" -le "$now" ] && target=$((target + 86400))  # tomorrow
    secs=$((target - now + 120))                            # 2 min grace
  else
    secs=$((LIMIT_RETRY_MIN * 60))
  fi
  log "usage limit — sleeping $((secs/60)) min"
  tg_send "usage limit hit — sleeping $((secs/60)) min, then resuming"
  sleep "$secs"
}

run_iteration() {
  rm -f "$FORGE_DIR/EXIT"
  log "iteration starting (model=$MODEL)"
  ( cd "$PROJECT_DIR" && claude -p "/forge iterate" \
      --model "$MODEL" --permission-mode "$PERMISSION_MODE" \
      2>&1 | tee -a "$FORGE_DIR/iterations.log" )
}

consec_fail=0
log "=== forge harness up: $PROJECT (model=$MODEL, mode=$PERMISSION_MODE) ==="
tg_send "forge harness started"

while :; do
  poll_reply 0 || true          # pick up stop/direction sent mid-run
  out="$(run_iteration)"
  status="$(cat "$FORGE_DIR/EXIT" 2>/dev/null || echo NONE)"
  log "iteration exit: $status"
  flush_outbox

  case "$status" in
    PROGRESS)
      consec_fail=0 ;;
    MILESTONE)
      consec_fail=0
      tg_send "milestone reached — PR updated. $(cd "$PROJECT_DIR" && gh pr view --json url -q .url 2>/dev/null || true)" ;;
    BARRIER|BLOCKED)
      consec_fail=0
      log "parked ($status) — polling telegram for approval/direction"
      while [ ! -f "$FORGE_DIR/DIRECTION.md" ]; do poll_reply "$PARK_POLL_SEC" || true; done ;;
    DONE)
      tg_send "🎉 DONE — prod-ready checklist green."
      log "DONE — harness exiting"; break ;;
    NONE)
      # iteration died without writing EXIT: usage limit or hard error
      if grep -qiE 'usage limit|rate limit|limit reached|resets' <<<"$out"; then
        sleep_until_reset "$out"
      else
        consec_fail=$((consec_fail + 1))
        log "iteration failed without EXIT ($consec_fail/$MAX_CONSEC_FAIL)"
        tail -5 <<<"$out" | tee -a "$LOG"
        if [ "$consec_fail" -ge "$MAX_CONSEC_FAIL" ]; then
          tg_send "⚠️ harness stopped: $MAX_CONSEC_FAIL consecutive failures. Last output: $(tail -3 <<<"$out")"
          break
        fi
        sleep 60
      fi ;;
    *)
      log "unknown exit '$status' — treating as failure"; sleep 60 ;;
  esac

  [ "$ONCE" = "--once" ] && { log "--once: stopping"; break; }
done
