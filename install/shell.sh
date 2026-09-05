# shellcheck shell=bash
# shell: a desktop entry for the MausOS shell, and open it now if we can.

appdir="$HOME/.local/share/applications"
mkdir -p "$appdir"
cp "$MAUSOS_PATH/config/applications/mausos-shell.desktop" "$appdir/mausos-shell.desktop"
have update-desktop-database && update-desktop-database "$appdir" >/dev/null 2>&1 || true
ok "$appdir/mausos-shell.desktop"

if in_hyprland; then
  if wait_for_mausd 5; then
    "$HOME/.local/bin/maus-shell-open" --background && ok "shell opened on the special workspace (Super+A)"
  else
    warn "mausd is not up; the shell opens at next login (or: maus shell open)"
  fi
fi
