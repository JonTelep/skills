# SKILLS

Source-of-truth repository for custom Claude Code skills. The actual skill
content lives here (version-controlled), and Claude Code loads each skill via a
**symlink** placed in `~/.claude/skills/`.

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

## Current symlinks

Each entry below is `~/.claude/skills/<name>` → target in this repo:

| Skill name           | Target |
| -------------------- | ------ |
| `fable-prompts`      | `SKILLS/fable-prompts-skill/skills/fable-prompts` |
| `intelligent-loop`   | `SKILLS/fable-prompts-skill/skills/intelligent-loop` |
| `repo-conventions`   | `SKILLS/fable-prompts-skill/skills/repo-conventions` |
| `llms-txt`           | `SKILLS/reach-optimization-skill/skills/llms-txt` |
| `reach-optimization` | `SKILLS/reach-optimization-skill/skills/reach-optimization` |

## How to create a new symlink

To expose a skill in this repo to Claude Code:

```bash
ln -s /home/telep/Projects/SKILLS/<project>-skill/skills/<name> \
      ~/.claude/skills/<name>
```

Example (this is exactly how `intelligent-loop` is wired up):

```bash
ln -s /home/telep/Projects/SKILLS/fable-prompts-skill/skills/intelligent-loop \
      ~/.claude/skills/intelligent-loop
```

## How to verify

1. **Confirm the symlink exists and points into this repo:**

   ```bash
   ls -la ~/.claude/skills/intelligent-loop
   ```

   Expected: an `l` at the start of the permissions and an arrow pointing to
   `/home/telep/Projects/SKILLS/fable-prompts-skill/skills/intelligent-loop`.

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

## Verify all SKILLS-backed symlinks at once

```bash
for l in ~/.claude/skills/*; do
  [ -L "$l" ] || continue
  tgt=$(readlink "$l")
  case "$tgt" in
    */Projects/SKILLS/*)
      if [ -e "$l" ]; then status="OK"; else status="BROKEN"; fi
      printf '%-22s %-7s -> %s\n' "$(basename "$l")" "$status" "$tgt";;
  esac
done
```
