# shellcheck shell=bash
# environment: make every toolkit publish its accessibility tree (rung 3).
#
# GTK 3 needs the atk bridge module; GTK 4 speaks AT-SPI natively when the
# a11y bus says it is enabled; Qt needs ALWAYS_ON; Firefox needs
# GNOME_ACCESSIBILITY; Chromium and Electron need --force-renderer-accessibility
# (Arch's chromium and electron read *-flags.conf files).

envfile="$HOME/.config/environment.d/mausos.conf"
mkdir -p "$(dirname "$envfile")"
cat > "$envfile" <<'EOF'
# MausOS: accessibility trees on for every toolkit. Managed by install/environment.sh.
MAUSOS=1
GTK_MODULES=gail:atk-bridge
QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
GNOME_ACCESSIBILITY=1
ACCESSIBILITY_ENABLED=1
EOF
ok "$envfile"

ensure_line "$HOME/.config/chromium-flags.conf" "--force-renderer-accessibility"
ensure_line "$HOME/.config/electron-flags.conf" "--force-renderer-accessibility"
ok "chromium and electron flags"

# Tell the a11y bus that assistive technology is wanted; GTK 4 and Chromium check this.
if have gsettings; then
  gsettings set org.gnome.desktop.interface toolkit-accessibility true 2>/dev/null \
    && ok "toolkit-accessibility on" \
    || warn "could not set org.gnome.desktop.interface toolkit-accessibility (no schema?)"
fi
if have busctl; then
  busctl --user set-property org.a11y.Bus /org/a11y/bus org.a11y.Status IsEnabled b true 2>/dev/null || true
fi

# Import the environment into the running user session so mausd and the
# commands see it without a re-login.
if have systemctl; then
  systemctl --user import-environment GTK_MODULES QT_LINUX_ACCESSIBILITY_ALWAYS_ON GNOME_ACCESSIBILITY ACCESSIBILITY_ENABLED 2>/dev/null || true
fi
