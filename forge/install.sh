#!/usr/bin/env bash
# forge installer — symlink skills into ~/.claude/skills and prep ~/.forge
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.claude/skills"

mkdir -p "$SKILLS_DIR" "${HOME}/.forge"
touch "${HOME}/.forge/ports"

for skill in forge local-deploy; do
  target="${SKILLS_DIR}/${skill}"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "SKIP  ${skill}: ${target} exists and is not a symlink" >&2
    continue
  fi
  ln -sfn "${REPO}/skills/${skill}" "$target"
  echo "LINK  ${skill} -> ${REPO}/skills/${skill}"
done

# harness scripts -> ~/.local/bin (setup-vps.sh puts it on PATH)
mkdir -p "${HOME}/.local/bin"
for b in "${REPO}"/bin/*; do
  [ -f "$b" ] || continue
  chmod +x "$b"
  ln -sfn "$b" "${HOME}/.local/bin/$(basename "$b")"
  echo "LINK  bin/$(basename "$b") -> ~/.local/bin"
done
for dep in jq curl tmux claude gh; do
  command -v "$dep" >/dev/null 2>&1 || echo "WARN  missing dependency: $dep"
done

echo "done. skills available: /forge, /local-deploy"
