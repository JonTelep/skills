# SKILLS

Source-of-truth repository for custom Claude Code skills. The actual skill
content lives here (version-controlled), and Claude Code loads each skill via a
**symlink** placed in `~/.claude/skills/`.

> **Attribution:** `taste-skill/` is vendored from
> [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) (MIT — see its
> `LICENSE`). Everything else in this repo is original.

## How it works

Claude Code discovers skills by scanning `~/.claude/skills/`. Rather than copying
skills into that directory, each skill is symlinked back to its real location in
this repo. This means:

- There is **one** copy of each skill (here), tracked in git.
- Editing a file here immediately affects the skill Claude Code uses — no re-sync.
- `~/.claude/skills/<name>` is just a pointer, not a duplicate.

Note that skills are nested one level deep inside each `*-skill` project, under a
`skills/` subdirectory. The symlink hides that nesting so the skill appears at the
top level of `~/.claude/skills/`.

Linking is managed by the repo's **Makefile** — just run `make link` (see
[Makefile — linking skills locally](#makefile--linking-skills-locally)).

## VPS setup (`setup-vps.sh`)

`setup-vps.sh` (repo root) is a one-command bootstrap for running long-running
Claude Code sessions on a VPS, inside `tmux`, isolated to a dedicated user. It
provisions everything below in one shot and is safe to re-run.

**Run on a fresh VPS (as root, or via `sudo`/`doas`):**

```bash
curl -fsSL https://raw.githubusercontent.com/JonTelep/skills/main/setup-vps.sh | sudo sh
```

On Alpine (no `sudo`/`bash` by default, usually already root):

```bash
curl -fsSL https://raw.githubusercontent.com/JonTelep/skills/main/setup-vps.sh | sh
```

**What it does:**

1. Detects the package manager and installs `tmux`, `git`, `curl`, `bash`,
   `openssh`, `ripgrep`. Works on Debian/Ubuntu (apt), AlmaLinux/RHEL/Rocky/
   Fedora/CentOS (dnf/yum), Alpine (apk), Arch (pacman), openSUSE (zypper).
2. Creates a dedicated **unprivileged** user `claude-agent` (no sudo) — the
   isolation boundary for `claude --dangerously-skip-permissions`.
3. Installs Claude Code (official installer) for that user.
4. Clones this repo to `~/work/skills` and **symlinks every skill** into
   `~/.claude/skills/`.
5. Generates an `ed25519` SSH deploy key and prints the public key with
   instructions to add it to the target repo's **Deploy keys**.
6. Creates a detached `tmux` session named `claude`.
7. On systemd hosts, installs a boot service (re-creates the tmux session on
   reboot) and a daily timer (`git pull` on the skills repo).

**Auth is your Claude subscription.** Log in once interactively (`claude` →
OAuth) inside the tmux session; the token persists in `~/.claude`, so later
unattended runs just work. Do **not** set `ANTHROPIC_API_KEY` — that switches
billing to the pay-per-token API.

**Optional env overrides** (prefix the piped command, e.g.
`curl … | sudo AGENT_REPO=git@github.com:you/proj.git sh`):

| Variable | Effect |
| --- | --- |
| `AGENT_USER` | Dedicated user name (default `claude-agent`) |
| `SKILLS_REPO` | Skills repo URL to clone |
| `TMUX_SESSION` | tmux session name (default `claude`) |
| `AGENT_REPO` | If set, cloned into `~/work` after key setup |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | git identity for the agent's commits |
| `CREATE_SWAP=1` | Create a 2G swapfile if none exists (small VPS OOM guard) |

**Daily use:**

```bash
ssh vps
sudo su - claude-agent
tmux attach -t claude          # or: tmux new -s claude
cd ~/work/yourrepo && git pull
claude                         # first run: log in once
```

> **Alpine note:** Claude Code ships a glibc binary; the script installs
> `gcompat` as a shim, but on a stock musl image `claude` may still fail to
> launch. A glibc-based image is the reliable fix. Everything else (user,
> tmux, skills, key) works on Alpine regardless.

## Makefile — linking skills locally

The `Makefile` at the repo root manages all the symlinks. Running `make` with no
arguments prints the help:

| Target        | What it does |
| ------------- | ------------ |
| `make help`   | Show all targets (also the default when just typing `make`) |
| `make link`   | Symlink every skill (any directory containing a `SKILL.md`) into `~/.claude/skills/`. Idempotent — safe to re-run after adding a skill. |
| `make unlink` | Remove **only** the symlinks that point into this repo. |
| `make relink` | `unlink` + `link` — clears stale links left behind by renamed or deleted skills. |
| `make status` | List every symlink in `~/.claude/skills/` with OK/BROKEN and whether this repo owns it. |
| `make check`  | Exit non-zero if any skill is unlinked or any repo-owned link is broken/stale. |

Skills are discovered automatically by finding `SKILL.md` files, so adding a new
skill is just: create `<project>-skill/skills/<name>/SKILL.md`, then `make link`.

**Safety:** `~/.claude/skills/` also holds symlinks owned by *other* repos (e.g.
`absorb-x` and `checkin` from `second-brain`, `omarchy` from Omarchy). The
Makefile inspects each link's target and never creates, replaces, or removes a
link that doesn't resolve into this repo — those show up as `SKIP` in `make link`
and `(other)` in `make status`.

## How to verify manually

1. **Confirm the symlink exists and points into this repo:**

   ```bash
   ls -la ~/.claude/skills/intelligent-loop
   ```

   Expected: an `l` at the start of the permissions and an arrow pointing to
   `/home/telep/Projects/skills/fable-prompts-skill/skills/intelligent-loop`.

2. **Confirm the target resolves to a real directory with skill content:**

   ```bash
   readlink -f ~/.claude/skills/intelligent-loop
   ls ~/.claude/skills/intelligent-loop/   # should show SKILL.md (and README.md)
   ```

3. **Check for broken symlinks** (targets that no longer exist):

   ```bash
   find ~/.claude/skills/ -maxdepth 1 -xtype l
   ```

   Any path printed here is a **dangling** symlink and needs fixing.

4. **Confirm Claude Code sees it:** the skill should be invocable as
   `/intelligent-loop` inside Claude Code.

## Verify all repo-backed symlinks at once

```bash
make status   # human-readable overview of every link
make check    # CI-style: exits non-zero if anything is missing/broken/stale
```
