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

Everything in this repo was written on a Windows machine without a Hyprland
session available. Bash syntax, the Node tests and the JSON manifests are
verified. The AT-SPI tool, Hyprland integration, and the installer are
**unverified on real hardware**. Expect small fixes on first run; the design
is sound, the details may not be.

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
