# shellcheck shell=bash
# preflight: is this a machine MausOS can layer onto?

[[ $EUID -ne 0 ]] || die "run the installer as your normal user, not root"

if [[ -f /etc/arch-release ]] || have pacman; then
  ok "Arch Linux"
else
  die "MausOS Phase 0 targets Arch Linux (Omarchy). See docs/decisions.md for why."
fi

if have hyprctl || [[ -d /usr/share/hypr ]] || pacman -Qq hyprland >/dev/null 2>&1; then
  ok "Hyprland"
else
  warn "Hyprland is not installed. Window commands (maus win *) and the shell hotkey need it."
fi

if have omarchy || [[ -d /usr/share/omarchy || -d "$HOME/.local/share/omarchy" ]]; then
  ok "Omarchy"
else
  warn "Omarchy not detected. MausOS still installs, but you lose its themes, menu and updates. https://omarchy.org"
fi

if sudo -n true 2>/dev/null; then
  ok "sudo (cached)"
else
  info "sudo will prompt for your password when packages are installed"
fi

if curl -fsS --max-time 5 https://github.com >/dev/null 2>&1; then
  ok "network"
else
  warn "cannot reach github.com; package and engine steps will fail"
fi

if in_hyprland; then
  ok "running inside a Hyprland session"
else
  info "not inside Hyprland right now; config is written, effects apply at next login"
fi
