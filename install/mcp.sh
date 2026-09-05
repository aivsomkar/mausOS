# mcp: register `maus mcp` with mausd so every bot gets the commands as tools.
#
# OpenMausBot reads custom stdio MCP servers from ~/.openmausbot/config.json
# under "mcpServers" ({command, args, env, enabled}). Their tools go through
# the permission broker as Allow/Deny cards on Claude, on-request approval on
# Codex, and the agent's own permission asks on ACP engines.

datadir="${OMB_DATA_DIR:-$HOME/.openmausbot}"
conf="$datadir/config.json"
mkdir -p "$datadir"
chmod 700 "$datadir" 2>/dev/null || true

if [[ ! -f "$conf" ]]; then
  echo '{}' > "$conf"
fi
chmod 600 "$conf" 2>/dev/null || true

cmd="$HOME/.local/bin/maus-mcp"
tmp=$(mktemp)
jq --arg cmd "$cmd" '
  .mcpServers = (.mcpServers // {}) |
  .mcpServers.maus = {
    command: $cmd,
    args: [],
    env: { MAUSOS_MCP_CALLER: "mausd" },
    enabled: true
  }' "$conf" > "$tmp" && mv "$tmp" "$conf"
chmod 600 "$conf" 2>/dev/null || true
ok "maus registered as an MCP server in $conf"

if have systemctl && systemctl --user is-active mausd.service >/dev/null 2>&1; then
  systemctl --user restart mausd.service
  wait_for_mausd 30 && ok "mausd restarted" || warn "mausd restarting; check journalctl --user -u mausd"
fi
