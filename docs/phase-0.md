# Phase 0: what is built, and how to verify it

Goal: on a fresh Omarchy machine, a local model opens Firefox, navigates it by
accessibility tree, and reads the page back, with no screenshot.

## What is in this repo

| Piece | Where | State |
| --- | --- | --- |
| Installer (10 idempotent steps) | `install.sh`, `install/*.sh` | written, not yet run on hardware |
| Bootstrap | `boot.sh` | written |
| `maus` entry point, help, JSON catalogue | `bin/maus` | written, catalogue tested |
| 43 commands across 14 groups | `bin/maus-*` | written; syntax-checked |
| AT-SPI tool (apps, tree, find, press, set, focus, text) | `lib/atspi.py` | written; needs a live a11y bus to test |
| MCP server (zero deps) | `mcp/server.mjs`, `mcp/metadata.mjs` | written and unit-tested |
| Registry v0: 20 manifests | `registry/manifests/` | curated |
| Skill for agents | `skill/mausos/SKILL.md` | written |
| Hyprland layer, systemd unit, desktop entry | `config/` | written |
| CI (shellcheck, bash -n, py_compile, tests, catalogue) | `.github/workflows/ci.yml` | written |

## First real run (6 Sep 2026, Arch Linux under WSL 2 with WSLg)

No Hyprland was available, so the window commands and the shell hotkey are
still unverified. Everything else ran for real:

| Verified | How |
| --- | --- |
| `boot.sh` → `install.sh` end to end on a fresh Arch | packages, a11y environment, 45 commands linked, Hyprland layer written, OpenMausBot cloned and built, `mausd` started as a user service, MCP registered, skill linked |
| `mausd` answers, bots list, `maus doctor` | `/api/health`, `maus agent list`, `maus daemon status` |
| `maus mcp` handshake and a tool call through `mausd`'s registry | `initialize` → `tools/list` (43 tools) → `tools/call maus_registry_list` |
| **Rung 3 end to end on a real GTK app** | a zenity entry dialog: `maus app tree` read the widget tree, `maus app find` located the field and the OK button, `maus app set` typed into the field, `maus app press OK` closed the dialog and zenity printed the typed text. No screenshot. |
| OpenCode + Ollama installed by the engines step; OpenCode connects to `maus mcp` | `opencode mcp list` shows `maus connected`; `mausd` lists `ollama/...` models under the `opencodeGo` instance |

Fixed on the way (each is a commit): pnpm install on Arch with Node 26 (no
corepack, root-owned global prefix); `~/.local/bin` on the installer PATH;
`loginctl enable-linger` so `mausd` survives logout; a 16k context for
Ollama (its CPU default of 4k cannot hold the tool catalogue); name
resolution preferring interactive widgets over their labels ("OK" matched the
button and the label inside it); silenced pygobject deprecation warnings that
polluted JSON output; duplicate skill links; `MAUS_MCP_GROUPS` to hand small
models a lean tool set.

### Agent run: the exit test, passed

A bot created over the `mausd` API on the OpenCode engine, given the task
*"a dialog titled 'MausOS test dialog' is open; find its text field, set it
to 'agent was here', press OK; never take a screenshot"*:

| Model | Outcome |
| --- | --- |
| `opencode/big-pickle` (OpenCode's free hosted model) | **Passed in 20 s.** Tool calls, in order: `maus_app_find` → `maus_app_set` on the field's tree id → `maus_app_find` → `maus_app_press OK`. zenity received exactly `agent was here` and closed. No screenshot, no approval card. |
| `ollama/qwen3:4b`, CPU only | Did not finish. 2.7 tokens/s and long "thinking"; OpenCode's provider times out after 5 minutes waiting for the first byte. |
| `ollama/qwen2.5:3b`, CPU only, `MAUS_MCP_GROUPS=app` | Did not finish. The prompt `mausd` assembles is ~12.6k tokens (its own system prompt plus its built-in agents/browser/computer tool servers, not the nine `maus` tools) and CPU prefill runs at ~29 tokens/s: 7 minutes to the first byte, past the 5-minute timeout. The model itself calls `maus_app_press` correctly when asked directly through Ollama. |

Conclusion: the whole chain works. Local-only operation on this class of
hardware (no GPU, 7 GB) is blocked by prompt size × CPU prefill speed, not by
MausOS. Phase 1's router should keep small local models for short prompts
and trim `mausd`'s built-in tool servers per bot; a GPU or a hosted model
removes the limit entirely.

Also exercised for real: `maus term open/send/wait/read` over tmux, `maus file
search` (name and content), `maus file trash` (which exposed that trash
listing needs a gvfs fallback, now added), `maus registry for/show`, `maus
agent list/send/stop`, `maus doctor`.

## Verify on a real machine

1. Install Omarchy (https://omarchy.org). Log in to Hyprland.
2. Run the bootstrap:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/aivsomkar/mausOS/main/boot.sh | bash
   ```
   Or with a local checkout: `bash install.sh`. Use `MAUSOS_SKIP_MODEL=1` to skip
   the model download the first time.
3. `maus doctor` — every required row should be ✓. The a11y bus row must say
   `IsEnabled=true`; if not, log out and in once (environment.d applies at login).
4. `maus daemon status` — mausd answers on 127.0.0.1:8799.
5. `Super+A` — the OpenMausBot UI appears on the special workspace.
6. The exit test, by hand:
   ```sh
   maus app launch firefox -- https://hyprland.org
   maus app apps                                # Firefox listed
   maus app find firefox "Search or enter address"
   maus app set firefox "Search or enter address" "hyprland window rules"
   maus win input key Return
   sleep 2
   maus app text firefox | head -40             # page text, no screenshot
   ```
7. The exit test, by a bot: in the shell, create a bot on the OpenCode engine
   (model `ollama/qwen3:8b`), confirm the `maus` MCP server is enabled under
   Plugins → MCP servers, and ask: *"Open hyprland.org in Firefox and tell me
   the first heading. Do not take a screenshot."* Watch the tool chips: they
   should be `maus_app_launch`, `maus_app_find`/`maus_app_text`, nothing from
   `maus_see_*`.

## Known gaps to close in Phase 0.1 (first hardware pass)

- Hyprland ≥ 0.53 changed window-rule syntax; MausOS avoids rules, but
  `hyprctl setprop` argument names may differ across versions. `maus win lease`
  tolerates failure of the border colour.
- The AT-SPI Python binding details (`get_action_iface`, `set_text_contents`,
  `grab_focus`) follow libatspi's API; a version mismatch shows up as a clear
  error from `atspi.py`, not a crash.
- `maus app launch` uses `gio launch`; on systems without it the Exec line is
  run directly.
- Ollama on Arch installs as a system service; the `ollama` package name is
  correct as of 2026, `ollama-cuda`/`ollama-rocm` give GPU builds.
- OpenCode's config schema for custom providers is as documented at
  opencode.ai in 2026; if the key names moved, `install/engines.sh` is the
  only place to change.

## Next: Phase 1

See [ROADMAP.md](../ROADMAP.md). The first Phase 1 items are the ones that
make the exit test routine rather than heroic: registry-aware tool selection
in mausd, Firefox/Chromium protocol clients, and the broker reading the risk
classes from the metadata.
