#!/usr/bin/env bash
# forge.sh — outer harness: run /forge iterations, classify exits, survive
# usage-limit windows, park at barriers, and talk to you over telegram.
#
# usage: forge.sh <project-dir> [--once]
#
# telegram commands (any time, answered by a background listener):
#   status        state, tasks done/total, recent commits, last ledger entry
#   run|go|resume start iterating (from idle) or retry now (while parked)
#   stop|pause    finish the current task, then idle (harness stays alive)
#   quit          exit the harness
#   <anything>    saved to .forge/DIRECTION.md (approve gate / new direction) and runs
set -uo pipefail

PROJECT_DIR="$(cd "${1:?usage: forge.sh <project-dir> [--once]}" && pwd)"
ONCE="${2:-}"
PROJECT="$(basename "$PROJECT_DIR")"
FORGE_DIR="$PROJECT_DIR/.forge"
INBOX="$FORGE_DIR/inbox"            # listener → main loop: RUN / STOP / QUIT flags
STATE_FILE="$FORGE_DIR/harness.state"
CONFIG="${HOME}/.forge/config"
LOG="$FORGE_DIR/harness.log"
OFFSET_FILE="${HOME}/.forge/telegram.offset"

MODEL="${FORGE_MODEL:-opus}"
PERMISSION_MODE="${FORGE_PERMISSION_MODE:-bypassPermissions}"
LIMIT_RETRY_MIN="${FORGE_LIMIT_RETRY_MIN:-30}"   # fallback when reset time unparseable
POLL_SEC=25                                       # telegram long-poll timeout
MAX_CONSEC_FAIL=3

[ -f "$CONFIG" ] && . "$CONFIG"   # TELEGRAM_TOKEN, TELEGRAM_CHAT_ID
mkdir -p "$FORGE_DIR" "$INBOX"
rm -f "$INBOX"/*
for ign in .forge/inbox/ .forge/harness.state .forge/harness.log .forge/iterations.log .forge/EXIT; do
  grep -qxF "$ign" "$PROJECT_DIR/.gitignore" 2>/dev/null || echo "$ign" >> "$PROJECT_DIR/.gitignore"
done

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG" >&2; }
set_state() { echo "$*" > "$STATE_FILE"; log "state: $*"; }

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

# ---- status ---------------------------------------------------------------
jqs() { jq -r "$1" "$FORGE_DIR/STATE.json" 2>/dev/null; }

status_text() {
  local state done total cur gates commits ledger
  state="$(cat "$STATE_FILE" 2>/dev/null || echo unknown)"
  done="$(jqs '[.tasks[] | select(.status=="done")] | length')"
  total="$(jqs '.tasks | length')"
  cur="$(jqs '[.tasks[] | select(.status=="in_progress")][0] | select(.) | "\(.id) \(.title)"')"
  gates="$(jqs '[.gates[] | "\(.id):\(.status)"] | join(" ")')"
  commits="$(cd "$PROJECT_DIR" && git log --oneline -5 2>/dev/null)"
  ledger="$(grep -E '^## ' "$FORGE_DIR/LEDGER.md" 2>/dev/null | tail -1)"
  printf 'state: %s\ntasks: %s/%s done%s\ngates: %s\nbranch: %s\nrecent commits:\n%s\nlast ledger: %s' \
    "$state" "${done:-?}" "${total:-?}" "${cur:+ (working on $cur)}" "${gates:-none}" \
    "$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null)" "${commits:-none}" "${ledger:-none}"
}

task_done_text() {  # one-liner after a PROGRESS/MILESTONE exit
  local last next commit
  last="$(jqs '[.tasks[] | select(.status=="done")] | last | select(.) | "\(.id) — \(.title)"')"
  next="$(jqs '[.tasks[] | select(.status=="pending")][0] | select(.) | "\(.id) \(.title)"')"
  commit="$(cd "$PROJECT_DIR" && git log --oneline -1 2>/dev/null)"
  printf '✅ %s\n%s\nnext: %s' "${last:-task done}" "${commit:-}" "${next:-none (checking completion)}"
}

# ---- telegram listener (background) ---------------------------------------
listener() {
  local offset resp next text line
  while :; do
    offset="$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)"
    resp="$(curl -sf --max-time $((POLL_SEC + 10)) \
      "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?timeout=${POLL_SEC}&offset=${offset}")" \
      || { sleep 10; continue; }
    next="$(echo "$resp" | jq -r '([.result[].update_id] | max) as $m | if $m then $m + 1 else empty end' 2>/dev/null)"
    [ -n "$next" ] && echo "$next" > "$OFFSET_FILE"
    text="$(echo "$resp" | jq -r --arg chat "${TELEGRAM_CHAT_ID}" \
      '.result[] | select(.message.chat.id == ($chat|tonumber)) | .message.text // empty' 2>/dev/null)"
    [ -n "$text" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      log "telegram: $line"
      case "$(tr '[:upper:]' '[:lower:]' <<<"$line" | sed -E 's/^ +| +$//g')" in
        status|s)        tg_send "$(status_text)" ;;
        help|\?)         tg_send "commands: status · run · stop · quit · <free text = direction>" ;;
        stop|pause|halt) touch "$INBOX/STOP"; tg_send "will pause after the current task ($(cat "$STATE_FILE"))" ;;
        quit|exit|kill)  touch "$INBOX/QUIT"; tg_send "quitting after the current task" ;;
        run|go|resume|continue|start)
                         touch "$INBOX/RUN"; tg_send "run requested ($(cat "$STATE_FILE"))" ;;
        *)               printf '%s\n' "$line" >> "$FORGE_DIR/DIRECTION.md"; touch "$INBOX/RUN"
                         tg_send "got it — will act on: \"$line\"" ;;
      esac
    done <<<"$text"
  done
}

if [ -n "${TELEGRAM_TOKEN:-}" ]; then
  listener &
  LISTENER_PID=$!
  trap 'kill "$LISTENER_PID" 2>/dev/null' EXIT
fi

# ---- waiting helpers ------------------------------------------------------
# wait_for_flag <seconds|-1> [extra-file]: sleep until RUN/QUIT flag (or extra file) appears,
# or the timeout elapses. -1 = forever.
wait_for_flag() {
  local secs="$1" extra="${2:-}" waited=0
  while :; do
    [ -e "$INBOX/RUN" ] || [ -e "$INBOX/QUIT" ] || [ -e "$INBOX/STOP" ] && return 0
    [ -n "$extra" ] && [ -e "$extra" ] && return 0
    [ "$secs" -ge 0 ] && [ "$waited" -ge "$secs" ] && return 0
    sleep 5; waited=$((waited + 5))
  done
}

sleep_until_reset() {  # parse "resets 3pm"-style time from claude output
  local out="$1" now target secs t
  t="$(grep -oiE 'resets( at)? [0-9]{1,2}(:[0-9]{2})?(am|pm)?' <<<"$out" | head -1 | sed -E 's/resets( at)? //I')"
  if [ -n "$t" ] && target="$(date -d "$t" +%s 2>/dev/null)"; then
    now="$(date +%s)"
    [ "$target" -le "$now" ] && target=$((target + 86400))
    secs=$((target - now + 120))
  else
    secs=$((LIMIT_RETRY_MIN * 60))
  fi
  set_state "sleeping (usage limit) until $(date -d "+${secs} seconds" '+%H:%M')"
  tg_send "usage limit hit — sleeping $((secs/60)) min (send 'run' to retry early)"
  wait_for_flag "$secs"
}

run_iteration() {
  rm -f "$FORGE_DIR/EXIT"
  log "iteration starting (model=$MODEL)"
  ( cd "$PROJECT_DIR" && claude -p "/forge iterate" \
      --model "$MODEL" --permission-mode "$PERMISSION_MODE" \
      2>&1 | tee -a "$FORGE_DIR/iterations.log" )
}

# ---- main loop ------------------------------------------------------------
consec_fail=0
mode=run          # run | idle
log "=== forge harness up: $PROJECT (model=$MODEL, mode=$PERMISSION_MODE) ==="
set_state "starting"
tg_send "forge harness started — send 'status' anytime, 'help' for commands"

while :; do
  [ -e "$INBOX/QUIT" ] && { log "QUIT — exiting"; tg_send "harness exited. restart with: forge-start $PROJECT_DIR"; break; }
  if [ -e "$INBOX/STOP" ]; then rm -f "$INBOX/STOP" "$INBOX/RUN"; mode=idle; set_state "idle (paused) — send 'run' to continue"; tg_send "paused. send 'run' to continue"; fi
  if [ "$mode" = idle ]; then
    wait_for_flag -1
    [ -e "$INBOX/RUN" ] && { rm -f "$INBOX/RUN"; mode=run; log "run requested"; }
    continue
  fi
  rm -f "$INBOX/RUN"

  set_state "running iteration since $(date '+%H:%M')"
  out="$(run_iteration)"
  status="$(cat "$FORGE_DIR/EXIT" 2>/dev/null || echo NONE)"
  log "iteration exit: $status"
  flush_outbox

  case "$status" in
    PROGRESS)
      consec_fail=0; tg_send "$(task_done_text)" ;;
    MILESTONE)
      consec_fail=0
      tg_send "$(task_done_text)"
      tg_send "🏁 milestone reached — PR: $(cd "$PROJECT_DIR" && gh pr view --json url -q .url 2>/dev/null || echo 'see github')" ;;
    BARRIER|BLOCKED)
      consec_fail=0
      set_state "parked ($status) — waiting for your reply"
      log "parked ($status) — waiting for DIRECTION.md or 'run'"
      wait_for_flag -1 "$FORGE_DIR/DIRECTION.md" ;;
    DONE)
      tg_send "🎉 DONE — prod-ready checklist green. send new direction to continue, or 'quit'."
      mode=idle; set_state "idle (DONE)" ;;
    NONE)
      if grep -qiE 'usage limit|rate limit|limit reached|resets' <<<"$out"; then
        sleep_until_reset "$out"
      else
        consec_fail=$((consec_fail + 1))
        log "iteration failed without EXIT ($consec_fail/$MAX_CONSEC_FAIL)"
        tail -5 <<<"$out" | tee -a "$LOG" >&2
        if [ "$consec_fail" -ge "$MAX_CONSEC_FAIL" ]; then
          tg_send "⚠️ paused: $MAX_CONSEC_FAIL consecutive failures. last output: $(tail -3 <<<"$out")
send 'run' to retry or 'quit'."
          consec_fail=0; mode=idle; set_state "idle (failed)"
        else
          sleep 60
        fi
      fi ;;
    *)
      log "unknown exit '$status' — treating as failure"; sleep 60 ;;
  esac

  [ "$ONCE" = "--once" ] && { log "--once: stopping"; break; }
done
set_state "exited"
