#!/bin/bash
# MausOS installer. Layers MausOS on an Omarchy (Arch + Hyprland) machine.
#
#   bash install.sh                    # everything
#   MAUSOS_SKIP="engines shell" bash install.sh
#   bash install.sh --only commands    # one step
#
# Steps run in this order; each is idempotent:
#   preflight    checks Arch, Hyprland, sudo, network
#   packages     pacman/yay packages the commands need, node + pnpm
#   environment  accessibility trees on for GTK/Qt/Firefox/Chromium/Electron
#   commands     links bin/maus* into ~/.local/bin
#   hyprland     ~/.config/hypr/mausos.conf (Super+A, interrupt chord, autostart)
#   mausd        builds OpenMausBot, installs and starts the mausd user service
#   engines      OpenCode + Ollama with a local model
#   mcp          registers `maus mcp` with mausd
#   skill        links the MausOS skill into agent skill directories
#   shell        desktop entry, opens the shell
set -euo pipefail

MAUSOS_PATH="${MAUSOS_PATH:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
export MAUSOS_PATH
export MAUSOS_INSTALL="$MAUSOS_PATH/install"
export MAUSOS_DATA="${MAUSOS_DATA:-$HOME/.local/share/mausos}"
export MAUSOS_LOG="$MAUSOS_DATA/install.log"
mkdir -p "$MAUSOS_DATA"

# shellcheck source=install/helpers.sh
source "$MAUSOS_INSTALL/helpers.sh"

STEPS=(preflight packages environment commands hyprland mausd engines mcp skill shell)
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --list) printf '%s\n' "${STEPS[@]}"; exit 0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

banner
info "checkout $MAUSOS_PATH"
info "data     $MAUSOS_DATA"
info "log      $MAUSOS_LOG"

if [[ -n "$ONLY" ]]; then
  run_step "$ONLY"
else
  for step in "${STEPS[@]}"; do
    if step_skipped "$step"; then
      warn "skipping $step (MAUSOS_SKIP)"
      continue
    fi
    run_step "$step"
  done
fi

echo
ok "MausOS is installed."
echo "   Super+A opens the shell · Super+Shift+Escape stops every agent"
echo "   maus            lists every command"
echo "   maus doctor     checks what works on this machine"
echo
