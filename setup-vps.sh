#!/usr/bin/env bash
#
# setup-vps.sh — one-command Claude Code VPS bootstrap
#
# Provisions a dedicated, unprivileged user that runs Claude Code inside tmux,
# with every skill in this repo wired in and a repo-scoped SSH deploy key ready.
# Designed for long-running `claude --dangerously-skip-permissions` sessions
# isolated to their own user account.
#
# Usage (run on a fresh Debian/Ubuntu VPS as a sudo-capable user):
#
#   curl -fsSL https://raw.githubusercontent.com/JonTelep/skills/main/setup-vps.sh | sudo bash
#
# Idempotent: safe to re-run to update skills / repair the install.
#
set -euo pipefail

# --------------------------------------------------------------------------
# Config (override via env, e.g. AGENT_USER=foo curl ... | sudo AGENT_USER=foo bash)
# --------------------------------------------------------------------------
AGENT_USER="${AGENT_USER:-claude-agent}"
SKILLS_REPO="${SKILLS_REPO:-https://github.com/JonTelep/skills.git}"
TMUX_SESSION="${TMUX_SESSION:-claude}"
AGENT_HOME="/home/${AGENT_USER}"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
# Phase A — system provisioning (as root)
# --------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "This script must run as root. Re-run with: curl -fsSL <url> | sudo bash"
command -v apt-get >/dev/null 2>&1 || die "This script targets Debian/Ubuntu (apt-get not found)."

log "Installing system packages (tmux, git, curl, ripgrep)…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends tmux git curl ca-certificates ripgrep sudo

if id "$AGENT_USER" >/dev/null 2>&1; then
  log "User '${AGENT_USER}' already exists — reusing."
else
  log "Creating dedicated unprivileged user '${AGENT_USER}' (no sudo — isolation boundary)…"
  useradd --create-home --shell /bin/bash "$AGENT_USER"
fi

# --------------------------------------------------------------------------
# Phase B — user-space setup (delegated to the agent user)
# --------------------------------------------------------------------------
# Everything below runs AS ${AGENT_USER} via a heredoc so nothing touches root's home.
log "Configuring Claude Code environment for '${AGENT_USER}'…"

su - "$AGENT_USER" bash <<EOF
set -euo pipefail

SKILLS_REPO="${SKILLS_REPO}"

log()  { printf '\033[1;36m  ->\033[0m %s\n' "\$*"; }

# --- PATH: ensure ~/.local/bin is available now and in future shells -------
export PATH="\$HOME/.local/bin:\$PATH"
if ! grep -qs 'HOME/.local/bin' "\$HOME/.bashrc" 2>/dev/null; then
  printf '\n# Claude Code\nexport PATH="\$HOME/.local/bin:\$PATH"\n' >> "\$HOME/.bashrc"
fi

# --- 1. Install Claude Code -----------------------------------------------
if command -v claude >/dev/null 2>&1 || [ -x "\$HOME/.local/bin/claude" ]; then
  log "Claude Code already installed — skipping install."
else
  log "Installing Claude Code (official installer)…"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# --- 2. Clone / update this skills repo -----------------------------------
mkdir -p "\$HOME/work"
SKILLS_DIR="\$HOME/work/skills"
if [ -d "\$SKILLS_DIR/.git" ]; then
  log "Updating skills repo…"
  git -C "\$SKILLS_DIR" pull --ff-only || log "(pull skipped — local changes or offline)"
else
  log "Cloning skills repo…"
  git clone --depth 1 "\$SKILLS_REPO" "\$SKILLS_DIR"
fi

# --- 3. Symlink every skill into ~/.claude/skills -------------------------
# `git pull` in \$SKILLS_DIR then instantly updates all linked skills.
mkdir -p "\$HOME/.claude/skills"
log "Linking skills into ~/.claude/skills …"
count=0
while IFS= read -r skillmd; do
  skilldir="\$(dirname "\$skillmd")"
  name="\$(basename "\$skilldir")"
  target="\$HOME/.claude/skills/\$name"
  # Refresh the link (remove stale symlink; never clobber a real dir the user added)
  if [ -L "\$target" ]; then rm -f "\$target"; fi
  if [ -e "\$target" ]; then
    log "  skip '\$name' (a real directory already exists there)"
    continue
  fi
  ln -s "\$skilldir" "\$target"
  count=\$((count + 1))
done < <(find "\$SKILLS_DIR" -name SKILL.md -not -path '*/.git/*')
log "Linked \$count skills."

# --- 4. SSH deploy key ----------------------------------------------------
mkdir -p "\$HOME/.ssh"
chmod 700 "\$HOME/.ssh"
if [ ! -f "\$HOME/.ssh/id_ed25519" ]; then
  log "Generating ed25519 SSH deploy key…"
  ssh-keygen -t ed25519 -N "" -C "${AGENT_USER}@\$(hostname)" -f "\$HOME/.ssh/id_ed25519" >/dev/null
else
  log "SSH key already exists — reusing."
fi
# Trust github.com so first git pull doesn't prompt
if ! grep -qs "github.com" "\$HOME/.ssh/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519 github.com >> "\$HOME/.ssh/known_hosts" 2>/dev/null || true
fi
chmod 600 "\$HOME/.ssh/id_ed25519" "\$HOME/.ssh/known_hosts" 2>/dev/null || true

# --- 5. Ensure a detached tmux session named '${TMUX_SESSION}' exists ------
if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
  log "tmux session '${TMUX_SESSION}' already running."
else
  log "Creating detached tmux session '${TMUX_SESSION}'…"
  tmux new-session -d -s "${TMUX_SESSION}" -c "\$HOME/work"
fi
EOF

# --------------------------------------------------------------------------
# Phase C — final banner (as root, reads the agent user's pubkey)
# --------------------------------------------------------------------------
PUBKEY="$(cat "${AGENT_HOME}/.ssh/id_ed25519.pub")"

cat <<BANNER

============================================================================
  Claude Code VPS setup complete for user: ${AGENT_USER}
============================================================================

  1) ADD THIS SSH DEPLOY KEY to the repo you want to work on
     (GitHub -> repo -> Settings -> Deploy keys -> Add deploy key;
      tick "Allow write access" only if Claude should push):

----------------------------------------------------------------------------
${PUBKEY}
----------------------------------------------------------------------------

  2) DAILY USE:

       ssh vps
       sudo su - ${AGENT_USER}
       tmux attach -t ${TMUX_SESSION}     # or: tmux new -s ${TMUX_SESSION}
       cd ~/work && git clone git@github.com:you/yourrepo.git   # first time
       cd ~/work/yourrepo && git pull
       claude                              # first run: log in once (OAuth)

     Then, for unattended long runs:

       claude --dangerously-skip-permissions

  ISOLATION: '${AGENT_USER}' has no sudo and its own home. Claude refuses
  --dangerously-skip-permissions as root, so it only runs here — blast
  radius is confined to this user's files and the repo's deploy key.

  Skills: symlinked from ~/work/skills into ~/.claude/skills.
  Update them anytime with:  git -C ~/work/skills pull

============================================================================
BANNER
