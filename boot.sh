#!/bin/bash
# MausOS bootstrap: clone the repo and run the installer.
#
#   curl -fsSL https://raw.githubusercontent.com/aivsomkar/mausOS/main/boot.sh | bash
#
# Environment:
#   MAUSOS_REPO   git URL to clone            (default: https://github.com/aivsomkar/mausOS)
#   MAUSOS_REF    branch or tag to check out  (default: main)
#   MAUSOS_PATH   where to put the checkout   (default: ~/.local/share/mausos/mausOS)
set -euo pipefail

MAUSOS_REPO="${MAUSOS_REPO:-https://github.com/aivsomkar/mausOS}"
MAUSOS_REF="${MAUSOS_REF:-main}"
MAUSOS_PATH="${MAUSOS_PATH:-$HOME/.local/share/mausos/mausOS}"

echo
echo "  MausOS · an AI-native Linux desktop"
echo "  repo: $MAUSOS_REPO ($MAUSOS_REF)"
echo "  path: $MAUSOS_PATH"
echo

if [[ $EUID -eq 0 ]]; then
  echo "Run boot.sh as your normal user, not root. It uses sudo where needed." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required. On Arch: sudo pacman -S git" >&2
  exit 1
fi

mkdir -p "$(dirname "$MAUSOS_PATH")"
if [[ -d "$MAUSOS_PATH/.git" ]]; then
  echo "Updating existing checkout…"
  git -C "$MAUSOS_PATH" fetch --quiet origin
  git -C "$MAUSOS_PATH" checkout --quiet "$MAUSOS_REF"
  git -C "$MAUSOS_PATH" pull --quiet --ff-only origin "$MAUSOS_REF" || true
else
  git clone --quiet --branch "$MAUSOS_REF" "$MAUSOS_REPO" "$MAUSOS_PATH"
fi

export MAUSOS_PATH
exec bash "$MAUSOS_PATH/install.sh" "$@"
