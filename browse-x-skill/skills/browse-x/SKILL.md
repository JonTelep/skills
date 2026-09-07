---
name: browse-x
description: >
  Read and search public X (Twitter) posts, threads, profiles, followers, or
  following via x.pcstyle.dev as Markdown or JSON. No X API key, cookies, or
  login. Use when the user wants to fetch a public tweet/post, conversation
  thread, X article, profile, search results, or social graph from an x.com
  or twitter.com URL or handle. Prefer curl (Bun is optional). Public content
  only; videos are not transcribed.
allowed-tools:
  - Bash(curl *)
  - Bash(curl.exe *)
  - Bash(*browse-x.sh *)
---

# browse-x

Read public X through [x.md](https://x.pcstyle.dev): a hosted, read-only
converter. **No X API key.** Public posts, profiles, search, followers, and
following only. Beta: routes and fields can change.

Prefer **curl** so Codex, Claude Code, and Cursor work on a PC without Bun.
On Windows PowerShell, call `curl.exe` (plain `curl` is often an alias for
`Invoke-WebRequest`). Optional helper: `scripts/browse-x.sh` (bash + curl).

## Host swap (fastest path)

Replace `x.com` (or `twitter.com`) with `x.pcstyle.dev` on a **public**
status URL, then fetch Markdown:

```text
https://x.com/handle/status/1234567890
https://x.pcstyle.dev/handle/status/1234567890
```

```bash
curl -sS -H 'Accept: text/markdown' \
  'https://x.pcstyle.dev/handle/status/1234567890'
```

Browsers that request HTML get a readable page. Agents should send
`Accept: text/markdown` or `Accept: application/json`. Discord/Slack/Telegram
preview bots get embed HTML unless `Accept` or `?format=` is set.

## curl: convert a post or thread

`GET /:handle/status/:id` and `GET /api/convert?url=…` are equivalent.

```bash
curl -sS -G 'https://x.pcstyle.dev/api/convert' \
  --data-urlencode 'url=https://x.com/handle/status/1234567890' \
  -H 'Accept: text/markdown'

# Expanded conversation, no replies
curl -sS 'https://x.pcstyle.dev/handle/status/1234567890?full=true&replies=off'

# Author thread only, capped at 20 posts
curl -sS 'https://x.pcstyle.dev/handle/status/1234567890?context=thread&thread=20'

# JSON
curl -sS -H 'Accept: application/json' \
  'https://x.pcstyle.dev/handle/status/1234567890'
```

| Parameter | Default | Values |
| --- | --- | --- |
| `format` | `markdown` | `markdown`, `obsidian`, `json` |
| `full` | false | `true` / `1` / `yes` — dates, metrics, richer details |
| `thread` | `full` | `off`, `full`, `conversation`, or `2`–`100` |
| `context` | `full` | `full` (parents + author thread + replies) or `thread` (author chain only) |
| `replies` | `top` | `top`, `recent`, `off` |
| `userinfo` | `off` | `off`, `author`, `all` |
| `nocache` | false | `true` bypasses the app cache (not upstream caches) |

`thread=off` returns only the requested post. Obsidian format (status only)
adds YAML frontmatter. JSON includes `url`, `markdown`, `posts`, `warnings`,
`source`, `cache`. Check `warnings` instead of inventing missing replies,
quotes, or media.

## curl: browse profiles, search, followers

```bash
curl -sS -H 'Accept: text/markdown' 'https://x.pcstyle.dev/elonmusk'
curl -sS 'https://x.pcstyle.dev/search?q=typescript&feed=latest&limit=20'
curl -sS 'https://x.pcstyle.dev/elonmusk/followers?full=true'
curl -sS -H 'Accept: application/json' \
  'https://x.pcstyle.dev/elonmusk/following?limit=20'
```

| Route | Behavior |
| --- | --- |
| `GET /:handle` | Profile + latest original posts (replies/reposts filtered) |
| `GET /search?q=…` | Search; `feed=latest` (default), `top`, `photos`, `videos`, `users` (`media` aliases `photos`) |
| `GET /:handle/followers` | Followers |
| `GET /:handle/following` | Accounts followed |

`limit` default and max is **20**. Prefer the opaque `nextCursor` for more
results. `page` is `1`–`10` (clamped); page walks are slower than a cursor.

Same thing via `/api/browse`:

```bash
curl -sS -G 'https://x.pcstyle.dev/api/browse' \
  --data-urlencode 'resource=profile' \
  --data-urlencode 'handle=elonmusk'

curl -sS -G 'https://x.pcstyle.dev/api/browse' \
  --data-urlencode 'resource=search' \
  --data-urlencode 'q=from:handle release' \
  --data-urlencode 'feed=latest'
```

## Optional helper (bash + curl, no Bun)

```bash
scripts/browse-x.sh "https://x.com/handle/status/123"
scripts/browse-x.sh status "https://x.com/handle/status/123" --thread 20 --context thread --replies top --full
scripts/browse-x.sh profile @handle --limit 20
scripts/browse-x.sh search "from:handle release" --feed latest
scripts/browse-x.sh followers handle --limit 20
scripts/browse-x.sh following handle --page 2 --json
```

`X_API_BASE` or `X_MD_API_BASE` overrides `https://x.pcstyle.dev` (self-host).

Exit codes: **0** ok, **2** bad usage, **3** rate limited (`Retry-After`
printed in seconds — wait that long), **1** other network/API error.

## Rate limits

- Live search: **5 uncached requests per minute per IP**. Cache hits are free.
- Live provider: **10 per IP per 15-minute window** (shared across feeds;
  each page of a walk counts).
- **429** with `Retry-After` (seconds until reset). **503** with
  `Retry-After: 30` on upstream outage.
- Successful responses cache ~1 hour (`X-Cache`, `X-Source`).

On 429: read `Retry-After`, wait, retry once. Do not hammer the host.

## Limitations (do not invent around these)

- **Public only.** Private, protected, gated, or deleted posts cannot be
  read. No X login, cookies, or credentials — never send secrets in URLs
  or search terms.
- **Videos** return CDN links, thumbnails, and metadata (duration,
  dimensions, bitrate, variants) when upstream exposes them — **not spoken
  transcripts**. Do not claim to have watched or transcribed a video.
- **Articles** return article Markdown text when upstream exposes it;
  otherwise you only have the post body. Do not fabricate article sections.
- **No public lists.** No pinned-post markers (upstream does not expose
  them). Profiles list recent originals, not the full timeline.
- Fallback sources may omit replies, quotes, media, or article text; honor
  `warnings` / `X-Source`. Media URLs are X/FxTwitter CDNs and can expire.
- Not affiliated with X Corp. Hosted service is beta.

## Attribution

Adapted from [pc-style/x-md](https://github.com/pc-style/x-md) (`skills/browse-x`),
MIT. Hosted API: https://x.pcstyle.dev
