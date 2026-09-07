#!/usr/bin/env bash
# Thin curl-only client for https://x.pcstyle.dev (no Bun).
# Exit: 0 ok, 1 API/network error, 2 usage, 3 rate limited (Retry-After on stderr).
set -euo pipefail

BASE="${X_API_BASE:-${X_MD_API_BASE:-https://x.pcstyle.dev}}"
BASE="${BASE%/}"

usage() {
  cat <<'EOF'
Usage:
  browse-x.sh <status-url> [options]
  browse-x.sh status <status-url> [options]
  browse-x.sh profile <handle-or-url> [options]
  browse-x.sh search <query> [options]
  browse-x.sh followers <handle> [options]
  browse-x.sh following <handle> [options]

Output: --json, --full, --format markdown|obsidian|json, --headers
Lists:  --page 1-10, --limit 1-20, --cursor <opaque>, --feed latest|top|photos|videos|users|media
Status: --thread off|full|conversation|2-100, --userinfo off|author|all,
        --context full|thread, --replies top|recent|off
Other:  --nocache, --help

X_API_BASE / X_MD_API_BASE overrides https://x.pcstyle.dev.
EOF
}

die() {
  local code="$1"
  shift
  printf '%s\n' "$*" >&2
  exit "$code"
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
esac

command=""
target=""
if [[ "$1" =~ ^(status|profile|search|followers|following)$ ]]; then
  command="$1"
  shift
  if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    [[ $# -gt 0 ]] && exit 0
    die 2 "browse-x: ${command} requires a target"
  fi
  target="$1"
  shift
else
  target="$1"
  shift
fi

format=""
full=""
page=""
limit=""
cursor=""
feed=""
thread=""
userinfo=""
context=""
replies=""
nocache=""
headers=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --json) format="json" ;;
    --full) full="true" ;;
    --compact) full="false" ;;
    --headers) headers="1" ;;
    --nocache) nocache="true" ;;
    --format|--page|--limit|--cursor|--feed|--thread|--userinfo|--context|--replies)
      [[ $# -ge 2 ]] || die 2 "browse-x: $1 requires a value"
      case "$1" in
        --format) format="$2" ;;
        --page) page="$2" ;;
        --limit) limit="$2" ;;
        --cursor) cursor="$2" ;;
        --feed) feed="$2" ;;
        --thread) thread="$2" ;;
        --userinfo) userinfo="$2" ;;
        --context) context="$2" ;;
        --replies) replies="$2" ;;
      esac
      shift
      ;;
    *)
      die 2 "browse-x: unknown option '$1'"
      ;;
  esac
  shift
done

if [[ -n "$format" && ! "$format" =~ ^(markdown|obsidian|json)$ ]]; then
  die 2 "browse-x: --format must be markdown, obsidian, or json"
fi

is_status_url() {
  [[ "$1" =~ ^https?://(www\.)?(x\.com|twitter\.com|mobile\.twitter\.com)/[^/]+/status/[0-9]+/?$ ]]
}

is_profile_url() {
  [[ "$1" =~ ^https?://(www\.)?(x\.com|twitter\.com|mobile\.twitter\.com)/[^/]+/?$ ]]
}

handle_from_url() {
  local path="${1#*://}"
  path="${path#*/}"
  path="${path%%/*}"
  printf '%s' "$path"
}

strip_at() {
  local h="$1"
  h="${h#@}"
  printf '%s' "$h"
}

resource=""
endpoint=""
qs=()

add_q() {
  local name="$1" value="$2"
  [[ -n "$value" ]] || return 0
  qs+=(--data-urlencode "${name}=${value}")
}

if [[ "$command" == "status" ]]; then
  is_status_url "$target" || die 2 "browse-x: status requires a public x.com or twitter.com status URL"
  resource="status"
  endpoint="${BASE}/api/convert"
  add_q url "$target"
elif [[ "$command" == "profile" ]]; then
  resource="profile"
  if is_profile_url "$target" && ! is_status_url "$target"; then
    endpoint="${BASE}/$(strip_at "$(handle_from_url "$target")")"
  else
    endpoint="${BASE}/$(strip_at "$target")"
  fi
elif [[ "$command" == "search" ]]; then
  resource="search"
  endpoint="${BASE}/search"
  add_q q "$target"
elif [[ "$command" == "followers" || "$command" == "following" ]]; then
  resource="list"
  endpoint="${BASE}/$(strip_at "$target")/${command}"
elif is_status_url "$target"; then
  resource="status"
  endpoint="${BASE}/api/convert"
  add_q url "$target"
elif is_profile_url "$target"; then
  resource="profile"
  endpoint="${BASE}/$(strip_at "$(handle_from_url "$target")")"
else
  die 2 "browse-x: expected a command or public X status/profile URL (got '${target}')"
fi

if [[ "$resource" != "status" ]]; then
  [[ -z "$thread" && -z "$userinfo" && -z "$context" && -z "$replies" ]] \
    || die 2 "browse-x: status options are only valid for status requests"
  [[ "$format" != "obsidian" ]] || die 2 "browse-x: --format obsidian is only valid for status requests"
fi
[[ "$resource" == "search" || -z "$feed" ]] || die 2 "browse-x: --feed is only valid for search"
if [[ "$resource" == "status" ]]; then
  [[ -z "$page" && -z "$limit" && -z "$cursor" && -z "$feed" ]] \
    || die 2 "browse-x: list options are not valid for status requests"
fi

add_q format "$format"
add_q full "$full"
add_q page "$page"
add_q limit "$limit"
add_q cursor "$cursor"
add_q feed "$feed"
add_q thread "$thread"
add_q userinfo "$userinfo"
add_q context "$context"
add_q replies "$replies"
add_q nocache "$nocache"

accept="text/markdown"
[[ "$format" == "json" ]] && accept="application/json"

hdr="$(mktemp)"
body="$(mktemp)"
trap 'rm -f "$hdr" "$body"' EXIT

curl_bin="curl"
if command -v curl.exe >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
  curl_bin="curl.exe"
fi

set +e
http_code="$("$curl_bin" -sS -D "$hdr" -o "$body" -w '%{http_code}' \
  -H "Accept: ${accept}" \
  -G "$endpoint" \
  "${qs[@]+"${qs[@]}"}")"
curl_status=$?
set -e

if [[ $curl_status -ne 0 ]]; then
  die 1 "browse-x: request to ${BASE} failed (curl exit ${curl_status})"
fi

retry_after() {
  awk 'BEGIN{IGNORECASE=1} /^retry-after:/{gsub(/\r/,""); print $2; exit}' "$hdr"
}

if [[ "$http_code" == "429" ]]; then
  ra="$(retry_after || true)"
  {
    echo "browse-x: HTTP 429 from ${BASE} (rate limited)"
    [[ -n "$ra" ]] && echo "Retry-After: ${ra}"
    cat "$body"
    [[ -s "$body" && "$(tail -c1 "$body")" != $'\n' ]] && echo
  } >&2
  exit 3
fi

if [[ "$http_code" != "200" && "$http_code" != "304" ]]; then
  {
    echo "browse-x: HTTP ${http_code} from ${endpoint}"
    ra="$(retry_after || true)"
    [[ -n "$ra" ]] && echo "Retry-After: ${ra}"
    cat "$body"
    [[ -s "$body" && "$(tail -c1 "$body")" != $'\n' ]] && echo
  } >&2
  exit 1
fi

if [[ -n "$headers" ]]; then
  status_line="$(head -n 1 "$hdr" | tr -d '\r')"
  printf '%s\r\n' "$status_line"
  awk 'NR>1 && NF{gsub(/\r/,""); print}' "$hdr"
  printf '\r\n'
fi

cat "$body"
[[ -s "$body" && "$(tail -c1 "$body")" != $'\n' ]] && echo
true
