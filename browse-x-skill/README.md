# browse-x

Portable agent skill for reading **public** X (Twitter) posts, threads,
profiles, search, followers, and following as Markdown or JSON via
[x.md](https://x.pcstyle.dev). No X API key, cookies, or login.

Adapted from [pc-style/x-md](https://github.com/pc-style/x-md) (`skills/browse-x`),
MIT — curl-first so Codex, Claude Code, and Cursor work on a PC without Bun.

## Skill

| Path | Purpose |
| --- | --- |
| `skills/browse-x/SKILL.md` | Agent instructions: host-swap, curl routes, rate limits, limitations |
| `skills/browse-x/scripts/browse-x.sh` | Optional bash + curl helper (status / profile / search / followers / following) |

## Install on a PC

Clone this repo (or this folder) once, then symlink the **skill directory**
(the one that contains `SKILL.md`) into each agent’s skills path.

```bash
git clone https://github.com/JonTelep/skills.git
cd skills
SKILL="$PWD/browse-x-skill/skills/browse-x"
```

### Claude Code (this repo’s default)

From the repo root:

```bash
make link
# or, one skill only:
mkdir -p ~/.claude/skills
ln -s "$SKILL" ~/.claude/skills/browse-x
```

### Cursor

```bash
mkdir -p ~/.cursor/skills
ln -s "$SKILL" ~/.cursor/skills/browse-x
```

### Codex

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -s "$SKILL" ~/.agents/skills/browse-x
ln -s "$SKILL" ~/.codex/skills/browse-x   # still scanned; optional
```

### skills CLI

If you use the [skills CLI](https://skills.sh/):

```bash
npx skills add JonTelep/skills --skill browse-x -g -y
# or per agent:
npx skills add JonTelep/skills --skill browse-x --agent cursor -g -y
npx skills add JonTelep/skills --skill browse-x --agent claude-code -g -y
npx skills add JonTelep/skills --skill browse-x --agent copilot -g -y
```

Upstream’s Bun-based helper (optional; this fork prefers curl):

```bash
bunx skills add pc-style/x-md -g -y --skill browse-x
```

On Windows PowerShell (Developer Mode or an elevated shell may be required for
symlinks; copying the folder also works, but it will not track git pulls):

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cursor\skills" | Out-Null
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.cursor\skills\browse-x" `
  -Target "C:\path\to\skills\browse-x-skill\skills\browse-x"
```

Restart the agent / IDE after linking so it picks up `browse-x`.

## Use

Ask the agent to read a public post, thread, profile, or search. It should
swap `x.com` → `x.pcstyle.dev` or curl the routes in `SKILL.md`.

```bash
# helper (bash + curl)
./browse-x-skill/skills/browse-x/scripts/browse-x.sh \
  "https://x.com/jack/status/20"

curl -sS -H 'Accept: text/markdown' \
  'https://x.pcstyle.dev/jack/status/20'
```

On Windows PowerShell, use `curl.exe` (plain `curl` is often `Invoke-WebRequest`).

## Limitations

- Public content only — no private/protected accounts.
- Videos: CDN links / thumbnails / metadata, **not** spoken transcripts.
- Articles: Markdown when upstream exposes it.
- Hosted API is beta. Search is rate-limited (`429` + `Retry-After`).

## License

MIT. See `LICENSE`.
