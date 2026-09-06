# shellcheck shell=bash
# packages: what the maus commands and mausd need.

# Commands
pkg_add \
  jq \
  tmux \
  socat \
  curl \
  git \
  grim \
  slurp \
  wl-clipboard \
  libnotify \
  wtype \
  brightnessctl \
  fd \
  ripgrep \
  python-gobject \
  at-spi2-core \
  glib2 \
  networkmanager \
  wireplumber

# Shell window (Omarchy ships chromium already; keep it explicit)
pkg_add chromium

# Node 24+ for mausd (OpenMausBot requires >=24). Omarchy manages node with
# mise; use it when present so the version lives where the user expects.
if have mise; then
  if ! node --version 2>/dev/null | grep -Eq '^v(2[4-9]|[3-9][0-9])\.'; then
    info "installing node 24 via mise"
    mise use -g node@24
  fi
  # shellcheck disable=SC2016
  eval "$(mise env -s bash 2>/dev/null || true)"
else
  pkg_add nodejs npm
fi

if ! node --version 2>/dev/null | grep -Eq '^v(2[4-9]|[3-9][0-9])\.'; then
  warn "node $(node --version 2>/dev/null || echo missing) found; mausd needs 24 or newer"
fi

if ! have pnpm; then
  info "installing pnpm"
  # Node 25+ no longer ships corepack and Arch's global npm prefix is
  # root-owned, so install the major version OpenMausBot pins into the user's
  # own prefix (~/.local/bin is on the installer's PATH). Fall back to the
  # Arch package if npm cannot fetch it.
  if npm install -g --prefix "$HOME/.local" pnpm@10 >/dev/null 2>&1; then
    ok "pnpm $(pnpm --version 2>/dev/null) in ~/.local/bin"
  else
    warn "npm could not install pnpm; using the Arch package"
    pkg_add pnpm
  fi
fi

ok "packages present"
