# shellcheck shell=bash
# mausd: build OpenMausBot and run its harness server as a user service.
#
#   MAUSOS_OPENMAUSBOT_REPO   git URL   (default: upstream milind-soni/OpenMausBot)
#   MAUSOS_OPENMAUSBOT_REF    ref       (default: main)
#   OMB_PORT                  port      (default: 8799)

repo="${MAUSOS_OPENMAUSBOT_REPO:-https://github.com/milind-soni/OpenMausBot}"
ref="${MAUSOS_OPENMAUSBOT_REF:-main}"
checkout="$MAUSOS_DATA/openmausbot"

if [[ -d "$checkout/.git" ]]; then
  info "updating OpenMausBot checkout"
  git -C "$checkout" fetch --quiet origin
  git -C "$checkout" checkout --quiet "$ref"
  git -C "$checkout" pull --quiet --ff-only origin "$ref" || warn "could not fast-forward; building what is checked out"
else
  info "cloning OpenMausBot ($ref)"
  git clone --quiet --depth 1 --branch "$ref" "$repo" "$checkout"
fi

built_rev_file="$checkout/.mausos-built-rev"
rev=$(git -C "$checkout" rev-parse HEAD)
if [[ -f "$built_rev_file" && "$(cat "$built_rev_file")" == "$rev" && -f "$checkout/dist-server/index.js" ]]; then
  ok "OpenMausBot $rev already built"
else
  info "building OpenMausBot (this takes a few minutes the first time)"
  (
    cd "$checkout" || exit 1
    # Only the server and the web UI are built; the Electron shell is not.
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    pnpm install --frozen-lockfile
    pnpm build
    pnpm build:server
  )
  echo "$rev" > "$built_rev_file"
  ok "built OpenMausBot $rev"
fi

unitdir="$HOME/.config/systemd/user"
mkdir -p "$unitdir"
sed \
  -e "s|__OMB_PORT__|${OMB_PORT:-8799}|g" \
  "$MAUSOS_PATH/config/systemd/mausd.service" > "$unitdir/mausd.service"
ok "$unitdir/mausd.service"

if have systemctl; then
  systemctl --user daemon-reload
  systemctl --user enable --now mausd.service >/dev/null 2>&1 || systemctl --user restart mausd.service
  if wait_for_mausd 60; then
    ok "mausd is answering on http://127.0.0.1:${OMB_PORT:-8799}"
  else
    warn "mausd did not answer yet; check: journalctl --user -u mausd -n 50"
  fi
else
  warn "systemd user session not available; start with: maus daemon run"
fi
