# shellcheck shell=bash
# hyprland: add the MausOS layer to the user's Hyprland config.
#
# We never edit Omarchy's package-owned defaults. The user's
# ~/.config/hypr/hyprland.conf gets one `source` line; everything MausOS
# needs lives in ~/.config/hypr/mausos.conf, which the user may edit.

hyprdir="$HOME/.config/hypr"
mkdir -p "$hyprdir"

conf="$hyprdir/mausos.conf"
if [[ -f "$conf" ]]; then
  info "$conf exists; leaving your edits alone (delete it to regenerate)"
else
  cp "$MAUSOS_PATH/config/hypr/mausos.conf" "$conf"
  ok "$conf"
fi

main="$hyprdir/hyprland.conf"
touch "$main"
ensure_line "$main" "source = ~/.config/hypr/mausos.conf"
ok "sourced from $main"

if in_hyprland; then
  hyprctl reload >/dev/null 2>&1 && ok "hyprland reloaded" || warn "hyprctl reload failed"
  errors=$(hyprctl configerrors 2>/dev/null || true)
  if [[ -n "$errors" && "$errors" != *"no errors"* ]]; then
    warn "hyprland reports config errors:"
    echo "$errors" >&2
  fi
fi
