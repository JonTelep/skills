#!/bin/sh
#
# setup-vps.sh — one-command, distro-agnostic Claude Code VPS bootstrap
#
# Provisions a dedicated, unprivileged user that runs Claude Code inside tmux,
# with every skill in this repo wired in and a repo-scoped SSH deploy key ready.
# Built for long-running `claude --dangerously-skip-permissions` sessions that
# stay isolated to their own user account.
#
# Works on: Debian/Ubuntu (apt), AlmaLinux/RHEL/Rocky/Fedora/CentOS (dnf/yum),
#           Alpine (apk), Arch (pacman), openSUSE (zypper).
#
# Usage (run as root, or via sudo/doas, on a fresh VPS):
#
#   curl -fsSL https://raw.githubusercontent.com/JonTelep/skills/main/setup-vps.sh | sudo sh
#   # Alpine (no sudo/bash by default), typically already root:
#   curl -fsSL https://raw.githubusercontent.com/JonTelep/skills/main/setup-vps.sh | sh
#
# Optional env overrides:
#   AGENT_USER=claude-agent        dedicated user name
#   SKILLS_REPO=<git url>          this repo (defaults to origin)
#   TMUX_SESSION=claude            tmux session name
#   AGENT_REPO=<git ssh url>       if set, cloned into ~/work after key setup
#   GIT_USER_NAME / GIT_USER_EMAIL git identity for the agent's commits
#   ANTHROPIC_API_KEY=<key>        pass through for unattended (no-login) runs
#   CREATE_SWAP=1                  create a 2G swapfile if none exists (small VPS)
#
# Idempotent: safe to re-run to update skills / repair the install.
#
set -eu

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
AGENT_USER="${AGENT_USER:-claude-agent}"
SKILLS_REPO="${SKILLS_REPO:-https://github.com/JonTelep/skills.git}"
TMUX_SESSION="${TMUX_SESSION:-claude}"
AGENT_REPO="${AGENT_REPO:-}"
GIT_USER_NAME="${GIT_USER_NAME:-${AGENT_USER}}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-${AGENT_USER}@$(hostname 2>/dev/null || echo localhost)}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
CREATE_SWAP="${CREATE_SWAP:-0}"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
# Phase A — system provisioning (as root)
# --------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Must run as root. Pipe to 'sudo sh' (or run as root / with doas)."

# --- Detect package manager & install deps --------------------------------
PM=""
for c in apt-get dnf yum apk pacman zypper; do
  if command -v "$c" >/dev/null 2>&1; then PM="$c"; break; fi
done
[ -n "$PM" ] || die "No supported package manager found (need apt/dnf/yum/apk/pacman/zypper)."
log "Detected package manager: $PM"

# openssh client package name varies by family
case "$PM" in
  apt-get)        SSH_PKG="openssh-client" ;;
  dnf|yum)        SSH_PKG="openssh-clients" ;;
  *)              SSH_PKG="openssh" ;;
esac
[ "$PM" = "apk" ] && SSH_PKG="openssh-client"

pm_install() {
  case "$PM" in
    apt-get) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
    dnf)     dnf install -y "$@" ;;
    yum)     yum install -y "$@" ;;
    apk)     apk add --no-cache "$@" ;;
    pacman)  pacman -S --needed --noconfirm "$@" ;;
    zypper)  zypper --non-interactive install -y "$@" ;;
  esac
}

log "Refreshing package index…"
case "$PM" in
  apt-get) DEBIAN_FRONTEND=noninteractive apt-get update -y ;;
  pacman)  pacman -Sy --noconfirm ;;
  apk)     apk update ;;
  *)       : ;;  # dnf/yum/zypper resolve metadata on install
esac

log "Installing core packages (tmux, git, curl, bash, openssh)…"
pm_install tmux git curl ca-certificates bash "$SSH_PKG"

# ripgrep is a nice-to-have; some minimal repos (older RHEL) lack it — don't fail.
pm_install ripgrep >/dev/null 2>&1 || warn "ripgrep not available in repos — skipping (optional)."

# Alpine/musl: Claude's native binary is glibc-built; add compat shims + shadow (for useradd).
if [ "$PM" = "apk" ]; then
  pm_install shadow gcompat libstdc++ >/dev/null 2>&1 || true
fi

# Warn if running on musl (Claude Code is best-effort there)
if ldd --version 2>&1 | grep -qi musl; then
  warn "musl libc detected. Claude Code ships a glibc binary; gcompat is installed as a shim,"
  warn "but if 'claude' fails to launch, this distro may need a glibc-based image."
fi

# --- Create the dedicated unprivileged user (NO sudo — isolation boundary) --
if id "$AGENT_USER" >/dev/null 2>&1; then
  log "User '${AGENT_USER}' already exists — reusing."
else
  log "Creating dedicated unprivileged user '${AGENT_USER}'…"
  if command -v useradd >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$AGENT_USER"
  else
    # busybox adduser (Alpine without shadow)
    adduser -D -s /bin/bash "$AGENT_USER"
  fi
fi
AGENT_HOME="$(getent passwd "$AGENT_USER" 2>/dev/null | cut -d: -f6)"
[ -n "$AGENT_HOME" ] || AGENT_HOME="/home/${AGENT_USER}"

# --- Optional swap (small VPS OOM guard for the Node runtime) --------------
if [ "$CREATE_SWAP" = "1" ] && [ "$(swapon --show 2>/dev/null | wc -l)" -eq 0 ]; then
  log "Creating 2G swapfile (CREATE_SWAP=1)…"
  if fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null; then
    chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
    grep -qs '/swapfile' /etc/fstab || printf '/swapfile none swap sw 0 0\n' >> /etc/fstab
  else
    warn "Swapfile creation failed (unsupported filesystem?) — continuing."
  fi
fi

# --------------------------------------------------------------------------
# Phase B — user-space setup (runs AS ${AGENT_USER})
# --------------------------------------------------------------------------
# Config is injected as quoted assignments; the body below is verbatim (no
# escaping). We write to a temp file and run it via `su -c` so it works with
# both util-linux su and busybox su.
TMP_SETUP="$(mktemp /tmp/claude-agent-setup.XXXXXX)"
{
  printf 'SKILLS_REPO=%s\n'       "'$SKILLS_REPO'"
  printf 'TMUX_SESSION=%s\n'      "'$TMUX_SESSION'"
  printf 'AGENT_REPO=%s\n'        "'$AGENT_REPO'"
  printf 'GIT_USER_NAME=%s\n'     "'$GIT_USER_NAME'"
  printf 'GIT_USER_EMAIL=%s\n'    "'$GIT_USER_EMAIL'"
  printf 'ANTHROPIC_API_KEY=%s\n' "'$ANTHROPIC_API_KEY'"
} > "$TMP_SETUP"

cat >> "$TMP_SETUP" <<'BODY'
set -eu
log() { printf '\033[1;36m  ->\033[0m %s\n' "$*"; }

# --- PATH: ensure ~/.local/bin now and in future shells -------------------
export PATH="$HOME/.local/bin:$PATH"
if ! grep -qs 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# Claude Code\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

# --- git identity (so the agent can commit/push) --------------------------
git config --global user.name  "$GIT_USER_NAME"  || true
git config --global user.email "$GIT_USER_EMAIL" || true
git config --global --get init.defaultBranch >/dev/null 2>&1 || git config --global init.defaultBranch main

# --- Optional API key passthrough for unattended (no interactive login) ---
if [ -n "$ANTHROPIC_API_KEY" ] && ! grep -qs 'ANTHROPIC_API_KEY' "$HOME/.bashrc" 2>/dev/null; then
  printf 'export ANTHROPIC_API_KEY=%s\n' "$ANTHROPIC_API_KEY" >> "$HOME/.bashrc"
  log "ANTHROPIC_API_KEY written to ~/.bashrc (unattended auth enabled)."
fi

# --- 1. Install Claude Code -----------------------------------------------
if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
  log "Claude Code already installed — skipping install."
else
  log "Installing Claude Code (official installer)…"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# --- 2. Clone / update this skills repo -----------------------------------
mkdir -p "$HOME/work"
SKILLS_DIR="$HOME/work/skills"
if [ -d "$SKILLS_DIR/.git" ]; then
  log "Updating skills repo…"
  git -C "$SKILLS_DIR" pull --ff-only || log "(pull skipped — local changes or offline)"
else
  log "Cloning skills repo…"
  git clone --depth 1 "$SKILLS_REPO" "$SKILLS_DIR"
fi

# --- 3. Symlink every skill into ~/.claude/skills -------------------------
# `git pull` in $SKILLS_DIR then instantly updates every linked skill.
mkdir -p "$HOME/.claude/skills"
log "Linking skills into ~/.claude/skills …"
find "$SKILLS_DIR" -name SKILL.md -not -path '*/.git/*' | while IFS= read -r skillmd; do
  skilldir="$(dirname "$skillmd")"
  name="$(basename "$skilldir")"
  target="$HOME/.claude/skills/$name"
  [ -L "$target" ] && rm -f "$target"
  if [ -e "$target" ]; then
    log "  skip '$name' (a real directory already exists there)"
    continue
  fi
  ln -s "$skilldir" "$target"
done
log "Linked $(find "$HOME/.claude/skills" -maxdepth 1 -type l | wc -l) skills."

# --- 4. SSH deploy key ----------------------------------------------------
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  log "Generating ed25519 SSH deploy key…"
  ssh-keygen -t ed25519 -N "" -C "$(id -un)@$(hostname 2>/dev/null || echo vps)" -f "$HOME/.ssh/id_ed25519" >/dev/null
else
  log "SSH key already exists — reusing."
fi
if ! grep -qs "github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
fi
chmod 600 "$HOME/.ssh/id_ed25519" 2>/dev/null || true

# --- 5. Optional: clone the target work repo ------------------------------
if [ -n "$AGENT_REPO" ]; then
  dest="$HOME/work/$(basename "$AGENT_REPO" .git)"
  if [ -d "$dest/.git" ]; then
    log "Target repo already cloned at $dest."
  else
    log "Cloning target repo $AGENT_REPO (needs the deploy key added first)…"
    git clone "$AGENT_REPO" "$dest" || warn "Clone failed — add the deploy key to the repo, then: git clone $AGENT_REPO ~/work/"
  fi
fi

# --- 6. Detached tmux session ---------------------------------------------
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  log "tmux session '$TMUX_SESSION' already running."
else
  log "Creating detached tmux session '$TMUX_SESSION'…"
  tmux new-session -d -s "$TMUX_SESSION" -c "$HOME/work"
fi

# --- 7. Verify install ----------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  log "Claude Code installed: $(claude --version 2>/dev/null || echo 'version check unavailable')"
else
  warn "claude not on PATH yet — a fresh login shell will pick it up (~/.local/bin)."
fi
BODY

chmod 600 "$TMP_SETUP"
chown "$AGENT_USER" "$TMP_SETUP" 2>/dev/null || true
log "Configuring Claude Code environment for '${AGENT_USER}'…"
su - "$AGENT_USER" -c "bash '$TMP_SETUP'"
rm -f "$TMP_SETUP"

# --------------------------------------------------------------------------
# Phase C — final banner
# --------------------------------------------------------------------------
PUBKEY="$(cat "${AGENT_HOME}/.ssh/id_ed25519.pub" 2>/dev/null || echo '(key not found — check the log above)')"

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

     For unattended long runs:  claude --dangerously-skip-permissions
     (set ANTHROPIC_API_KEY at setup time to skip the interactive login.)

  ISOLATION: '${AGENT_USER}' has no sudo and its own home. Claude refuses
  --dangerously-skip-permissions as root, so it only runs here — blast
  radius is confined to this user's files and the repo's deploy key.

  Skills: symlinked from ~/work/skills into ~/.claude/skills.
  Update anytime with:  git -C ~/work/skills pull

============================================================================
BANNER
