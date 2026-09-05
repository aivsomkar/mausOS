# engines: a local, tool-capable engine so MausOS works with no account.
#
# OpenCode (MIT) is the default engine: it has its own tool loop, speaks ACP
# (which mausd already drives), and talks to Ollama. Proprietary CLIs are not
# installed here; Omarchy's lazy stubs or the user do that.
#
#   MAUSOS_LOCAL_MODEL   ollama model tag   (default: qwen3:8b)
#   MAUSOS_SKIP_MODEL=1  do not pull a model now

model="${MAUSOS_LOCAL_MODEL:-qwen3:8b}"

# OpenCode
if have opencode; then
  ok "opencode $(opencode --version 2>/dev/null | head -1)"
else
  info "installing OpenCode"
  if have omarchy-npx-install; then
    omarchy-npx-install opencode-ai opencode || true
  fi
  if ! have opencode; then
    curl -fsSL https://opencode.ai/install | bash || warn "OpenCode install script failed"
  fi
  hash -r 2>/dev/null || true
  have opencode && ok "opencode installed" || warn "opencode not on PATH yet; open a new shell"
fi

# Ollama
if ! have ollama; then
  pkg_add ollama
fi
if have systemctl && systemctl list-unit-files ollama.service >/dev/null 2>&1; then
  sudo systemctl enable --now ollama.service >/dev/null 2>&1 || warn "could not start ollama.service"
fi
if have ollama; then
  ok "ollama"
  if [[ "${MAUSOS_SKIP_MODEL:-0}" != "1" ]]; then
    if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$model"; then
      ok "model $model present"
    else
      info "pulling $model (a few GB; set MAUSOS_SKIP_MODEL=1 to skip, MAUSOS_LOCAL_MODEL to change)"
      ollama pull "$model" || warn "pull failed; run later: ollama pull $model"
    fi
  fi
fi

# Point OpenCode at Ollama (only if the user has no opencode config yet).
occonf="$HOME/.config/opencode/opencode.json"
if [[ -f "$occonf" ]]; then
  if jq -e '.provider.ollama' "$occonf" >/dev/null 2>&1; then
    ok "opencode already knows ollama"
  else
    info "adding ollama provider to $occonf"
    tmp=$(mktemp)
    jq --arg m "$model" '.provider = (.provider // {}) | .provider.ollama = {
        npm: "@ai-sdk/openai-compatible",
        name: "Ollama (local)",
        options: { baseURL: "http://127.0.0.1:11434/v1" },
        models: { ($m): { name: ($m + " (local)") } }
      }' "$occonf" > "$tmp" && mv "$tmp" "$occonf"
  fi
else
  mkdir -p "$(dirname "$occonf")"
  jq -n --arg m "$model" '{
    "$schema": "https://opencode.ai/config.json",
    model: ("ollama/" + $m),
    provider: { ollama: {
      npm: "@ai-sdk/openai-compatible",
      name: "Ollama (local)",
      options: { baseURL: "http://127.0.0.1:11434/v1" },
      models: { ($m): { name: ($m + " (local)") } }
    } }
  }' > "$occonf"
  ok "$occonf"
fi
