#!/usr/bin/env bash
# scan.sh — gather everything the Muse connector submission form asks for,
# from the repository at $1 (default: cwd). Read-only. Prints Markdown.
# Deps: bash, grep, find, sed. Optional: python3 (image dims), git, jq.
set -u
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
cd "$ROOT" || exit 1

EXCL='-not -path */.git/* -not -path */node_modules/* -not -path */vendor/* -not -path */dist/* -not -path */build/* -not -path */.venv/* -not -path */target/*'
g() { grep -rIn --exclude-dir={.git,node_modules,vendor,dist,build,.venv,target,.next} "$@" . 2>/dev/null; }
gh() { grep -rIh --exclude-dir={.git,node_modules,vendor,dist,build,.venv,target,.next} "$@" . 2>/dev/null; }
section() { printf '\n## %s\n\n' "$1"; }
kv() { printf -- '- **%s:** %s\n' "$1" "$2"; }
none() { echo "- _none found_"; }

echo "# Muse connector scan — $(basename "$ROOT")"
echo
echo "Scanned: \`$ROOT\` on $(date -u +%Y-%m-%d)"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  kv "Remote" "$(git remote get-url origin 2>/dev/null || echo n/a)"
  kv "HEAD" "$(git rev-parse --short HEAD 2>/dev/null)"
fi

# ---------- identity ----------
section "Identity (Connector name / Company or developer / Product website)"
if [ -f package.json ]; then
  kv "package.json name" "$(sed -n 's/^\s*"name"\s*:\s*"\([^"]*\)".*/\1/p' package.json | head -1)"
  kv "package.json description" "$(sed -n 's/^\s*"description"\s*:\s*"\([^"]*\)".*/\1/p' package.json | head -1)"
  kv "package.json homepage" "$(sed -n 's/^\s*"homepage"\s*:\s*"\([^"]*\)".*/\1/p' package.json | head -1)"
  kv "package.json author" "$(grep -o '"author"\s*:\s*"[^"]*"' package.json | head -1 | sed 's/.*:\s*"//;s/"$//')"
fi
if [ -f pyproject.toml ]; then
  kv "pyproject name" "$(sed -n 's/^name\s*=\s*"\([^"]*\)".*/\1/p' pyproject.toml | head -1)"
  kv "pyproject description" "$(sed -n 's/^description\s*=\s*"\([^"]*\)".*/\1/p' pyproject.toml | head -1)"
  grep -iE '^(homepage|documentation|repository)\s*=' pyproject.toml | sed 's/^/- pyproject /'
fi
[ -f Cargo.toml ] && kv "Cargo name" "$(sed -n 's/^name\s*=\s*"\([^"]*\)".*/\1/p' Cargo.toml | head -1)"
[ -f go.mod ] && kv "go module" "$(sed -n 's/^module \(.*\)/\1/p' go.mod)"
[ -f composer.json ] && kv "composer name" "$(sed -n 's/^\s*"name"\s*:\s*"\([^"]*\)".*/\1/p' composer.json | head -1)"
README=$(ls README.md README.rst README 2>/dev/null | head -1)
if [ -n "$README" ]; then
  kv "README H1" "$(grep -m1 '^# ' "$README" | sed 's/^# //')"
  kv "README first paragraph" "$(awk 'BEGIN{p=0} /^# /{p=1;next} p&&NF&&!/^[#!\[<`|-]/{print;exit}' "$README")"
fi
for f in LICENSE LICENSE.md LICENSE.txt; do [ -f "$f" ] && kv "License" "$(head -1 "$f" | cut -c1-80)" && break; done

# ---------- connection type ----------
section "Connection type (Raw API vs Existing MCP)"
echo "### MCP signals"
MCP=$( { g -lE '@modelcontextprotocol/sdk|from mcp\b|import mcp\b|fastmcp|mcp-go|mark3labs/mcp|McpServer|FastMCP|StreamableHTTP|streamable-?http' ; find . $EXCL -iname '*mcp*' -type f; } | sort -u)
[ -n "$MCP" ] && echo "$MCP" | sed 's/^/- /' || none
echo
echo "### MCP tool definitions (names Muse will see)"
TOOLS=$(g -oE '(server|mcp)\.(tool|registerTool)\(\s*["'"'"'][A-Za-z0-9_.-]+|@mcp\.tool\([^)]*\)|@(server|mcp)\.tool\(\)|name:\s*["'"'"'][a-z][A-Za-z0-9_.-]+["'"'"'],?\s*$|"name"\s*:\s*"[a-z][A-Za-z0-9_.-]+"' | grep -iE 'tool|name' | head -80)
[ -n "$TOOLS" ] && echo "$TOOLS" | sed 's/^/- /' || none
echo
echo "### OpenAPI / Swagger specs (Raw API path)"
SPEC=$(find . $EXCL -type f \( -iname 'openapi*.json' -o -iname 'openapi*.y*ml' -o -iname 'swagger*.json' -o -iname 'swagger*.y*ml' -o -iname 'api-spec*' \) | sort)
[ -n "$SPEC" ] && echo "$SPEC" | sed 's/^/- /' || none
SPEC_GEN=$(g -lE 'FastAPI\(|@app\.(get|post|put|delete)|swagger-jsdoc|swagger-ui|@nestjs/swagger|springdoc|utoipa|huma\.' | head -20)
[ -n "$SPEC_GEN" ] && { echo; echo "Frameworks that can emit OpenAPI at runtime:"; echo "$SPEC_GEN" | sed 's/^/- /'; }
echo
echo "### HTTP routes (Raw API surface)"
ROUTES=$(g -oE '(app|router|api|server)\.(get|post|put|patch|delete)\(\s*["'"'"']/[^"'"'"']*|@(app|router)\.(get|post|put|patch|delete)\(["'"'"'][^"'"'"']+|(GET|POST|PUT|PATCH|DELETE)\s+"/[^"]*"|HandleFunc\(["'"'"'][^"'"'"']+|\.route\(["'"'"'][^"'"'"']+' | head -80)
[ -n "$ROUTES" ] && echo "$ROUTES" | sed 's/^/- /' || none
echo
echo "### Hosted endpoints / base URLs found in code and config"
URLS=$(gh -oE 'https?://[A-Za-z0-9.-]+\.[a-z]{2,}(/[^"'"'"' )<>]*)?' --include='*.json' --include='*.yaml' --include='*.yml' --include='*.toml' --include='*.env.example' --include='*.md' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rs' --include='*.rb' | grep -vE 'github\.com|npmjs|pypi|localhost|127\.0\.0\.1|schemastore|json-schema|w3\.org|example\.com|shields\.io|badge' | sed 's/[.,)]*$//' | sort | uniq -c | sort -rn | head -40)
[ -n "$URLS" ] && echo "$URLS" | awk '{printf "- %s (%s)\n",$2,$1}' || none
echo
echo "### Deploy / hosting hints"
DEPLOY=$(ls -d Dockerfile docker-compose*.y*ml fly.toml vercel.json netlify.toml render.yaml railway.* Procfile serverless.y*ml wrangler.toml* app.yaml .github/workflows 2>/dev/null)
[ -n "$DEPLOY" ] && echo "$DEPLOY" | sed 's/^/- /' || none

# ---------- auth ----------
section "Authentication methods (API keys / OAuth with PKCE / Other)"
echo "### Signals"
for pat in 'pkce|code_verifier|code_challenge' 'oauth|OAuth|authorization_code|client_id' 'api[_-]?key|x-api-key|X-API-Key' 'Bearer |bearer' 'client_secret' 'basic auth|Authorization: Basic' 'jwt|jsonwebtoken|jose' 'session|cookie'; do
  n=$(g -lE "$pat" | wc -l | tr -d ' ')
  printf -- '- `%s`: %s file(s)\n' "$pat" "$n"
done
echo
echo "### Auth-related files"
AUTHF=$(find . $EXCL -type f \( -iname '*auth*' -o -iname '*oauth*' -o -iname '*token*' -o -iname '*apikey*' -o -iname '*api_key*' \) | grep -vE '\.(png|svg|jpg|lock)$' | head -30)
[ -n "$AUTHF" ] && echo "$AUTHF" | sed 's/^/- /' || none
echo
echo "### Env vars (what a deployer/tester must supply)"
ENVV=$( { cat .env.example .env.sample .env.template env.example 2>/dev/null | grep -oE '^[A-Z][A-Z0-9_]+' ; gh -oE 'process\.env\.[A-Z][A-Z0-9_]+|os\.environ(\.get)?\(["'"'"'][A-Z][A-Z0-9_]+|os\.getenv\(["'"'"'][A-Z][A-Z0-9_]+|os\.Getenv\("[A-Z][A-Z0-9_]+' | sed -E 's/.*[.("'"'"']([A-Z][A-Z0-9_]+)$/\1/'; } | sort -u)
[ -n "$ENVV" ] && echo "$ENVV" | sed 's/^/- /' || none

# ---------- access requirements ----------
section "Access requirements (account, plan, regional, rate, usage)"
LIM=$(g -iE 'rate[ _-]?limit|429|quota|throttl|per[ _-](minute|hour|day)|tier|plan[s]?\b.*(free|pro|enterprise)|paid plan|subscription|region|geo|GDPR|EU only|US only|allowlist|whitelist|beta access|invite' --include='*.md' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rs' --include='*.yaml' --include='*.yml' --include='*.toml' --include='*.json' | grep -vE 'node_modules|lock' | head -40)
[ -n "$LIM" ] && echo "$LIM" | sed 's/^/- /' || none

# ---------- payments ----------
section "Payments (accepts payments?)"
PAY=$(g -liE 'stripe|paddle|lemonsqueezy|checkout\.session|price_id|billing|subscription' | head -20)
[ -n "$PAY" ] && echo "$PAY" | sed 's/^/- /' || none

# ---------- legal / support ----------
section "Legal & support (privacy policy / terms / support / work email)"
LEG=$(gh -oiE 'https?://[^"'"'"' )<>]*(privacy|terms|tos|legal|support|help|contact|status)[^"'"'"' )<>]*' | sed 's/[.,)]*$//' | sort -u | head -30)
[ -n "$LEG" ] && echo "$LEG" | sed 's/^/- /' || none
echo
EMAILS=$(gh -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' --include='*.md' --include='*.json' --include='*.toml' --include='*.yaml' --include='*.yml' --include='*.txt' --include='*.html' | grep -viE 'noreply|no-reply|example\.|users\.noreply|@types|@[a-z]+/' | sort | uniq -c | sort -rn | head -10)
[ -n "$EMAILS" ] && { echo "Emails seen:"; echo "$EMAILS" | awk '{printf "- %s (%s)\n",$2,$1}'; }
echo
echo "Legal files in repo:"
LF=$(find . $EXCL -maxdepth 3 -type f \( -iname '*privacy*' -o -iname '*terms*' -o -iname 'SECURITY.md' -o -iname 'CODE_OF_CONDUCT.md' -o -iname 'SUPPORT.md' \) | head -20)
[ -n "$LF" ] && echo "$LF" | sed 's/^/- /' || none

# ---------- icon ----------
section "Connector icon (512×512 PNG or SVG)"
IMGS=$(find . $EXCL -type f \( -iname '*.png' -o -iname '*.svg' \) \( -iname '*icon*' -o -iname '*logo*' -o -iname '*brand*' -o -iname '*mark*' -o -iname 'favicon*' -o -iname '*512*' -o -iname '*app*' \) | head -40)
if [ -n "$IMGS" ]; then
  while IFS= read -r f; do
    dims=""
    case "$f" in
      *.png|*.PNG)
        if command -v python3 >/dev/null; then dims=$(python3 - "$f" <<'PY'
import struct,sys
try:
    with open(sys.argv[1],'rb') as fh:
        h=fh.read(24)
    if h[:8]==b'\x89PNG\r\n\x1a\n': print("%dx%d"%struct.unpack('>II',h[16:24]))
except Exception: pass
PY
); fi;;
      *.svg|*.SVG) dims=$(grep -oE 'viewBox="[^"]+"|width="[^"]+"|height="[^"]+"' "$f" | head -3 | tr '\n' ' ');;
    esac
    mark=""; [ "$dims" = "512x512" ] && mark=" ✅ 512×512"
    printf -- '- %s  %s%s\n' "$f" "$dims" "$mark"
  done <<< "$IMGS"
else none; fi

# ---------- docs ----------
section "Documentation (API or MCP documentation URL) & example prompts source"
DOCS=$(find . $EXCL -maxdepth 2 \( -iname 'docs' -o -iname 'doc' -o -iname 'documentation' -o -iname 'examples' -o -iname 'CHANGELOG*' -o -iname 'CONTRIBUTING*' -o -iname 'llms.txt' -o -iname 'AGENTS.md' -o -iname 'CLAUDE.md' -o -iname 'SKILL.md' \) | head -20)
[ -n "$DOCS" ] && echo "$DOCS" | sed 's/^/- /' || none
echo
echo "Tool/endpoint descriptions (raw material for the “Example prompts” field):"
DESC=$(g -oE 'description:\s*["'"'"'`][^"'"'"'`]{15,160}|"description"\s*:\s*"[^"]{15,160}|summary:\s*["'"'"'][^"'"'"']{10,120}|"summary"\s*:\s*"[^"]{10,120}' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.json' --include='*.yaml' --include='*.yml' | head -40)
[ -n "$DESC" ] && echo "$DESC" | sed 's/^/- /' || none

# ---------- test & security readiness ----------
section "Review readiness (functional / security / legal, end-to-end testing)"
kv "Test command hints" "$(grep -oE '"test[^"]*"\s*:\s*"[^"]+"' package.json 2>/dev/null | head -3 | tr '\n' ' '; grep -lE '^(test|check|e2e)' Makefile 2>/dev/null; ls pytest.ini tox.ini noxfile.py 2>/dev/null | tr '\n' ' ')"
kv "Test files" "$(find . $EXCL -type f \( -iname '*test*' -o -iname '*spec*' \) -not -iname '*.md' | wc -l | tr -d ' ')"
kv "CI workflows" "$(ls .github/workflows 2>/dev/null | tr '\n' ' ')"
kv "Health/status route" "$(g -lE '/health|/healthz|/status|/ready' | head -3 | tr '\n' ' ')"
kv "SECURITY.md" "$([ -f SECURITY.md ] && echo yes || echo no)"
kv "Secrets committed? (quick check)" "$(g -lE '(sk_live|sk_test|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY)' | head -5 | tr '\n' ' ')"
kv "Dependency audit files" "$(ls package-lock.json pnpm-lock.yaml yarn.lock poetry.lock uv.lock Cargo.lock go.sum 2>/dev/null | tr '\n' ' ')"
