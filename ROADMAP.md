# Roadmap

The design behind these phases is in [docs/blueprint.md](docs/blueprint.md).
The decisions that shaped them are in [docs/decisions.md](docs/decisions.md).

## Phase 0 — Omarchy plus a Maus layer (this repo, now)

Exit: on a fresh Omarchy machine, a local model opens Firefox, navigates it by
accessibility tree, and reads the page back, with no screenshot.

- [x] `install.sh` layering on an Omarchy / Arch + Hyprland install
- [x] `mausd` (the OpenMausBot harness) as a systemd user service
- [x] The shell as a Chromium app window on a Hyprland special workspace, Super+A
- [x] `maus` command family with self-describing metadata and risk classes
- [x] AT-SPI tool: tree, find, press, set, focus, text (rung 3)
- [x] Hyprland tools: list, focus, lease, release, events, input (rung 4)
- [x] tmux shared terminal: open, send, read, wait (rung 1)
- [x] Packages, network, audio, brightness, notifications, clipboard, files
- [x] `maus mcp`: the catalogue as a zero-dependency stdio MCP server
- [x] Registry v0: curated manifests for the first apps
- [x] MausOS skill linked into agent skill directories
- [x] OpenCode + Ollama as the default local engine
- [ ] Verified on a real Omarchy machine (needs hardware; see docs/phase-0.md)

## Phase 1 — The ladder and the registry (~3 months)

Exit: a week of daily use where fewer than one action in twenty needed vision.

- Ladder executor in mausd: D-Bus caller, Firefox and Chromium protocol clients,
  registry-aware tool selection, vision as labelled rung 5
- Registry v1: top 40 apps curated, D-Bus introspection, desktop entries,
  help-text parsing; Registry panel in the shell
- Broker with risk classes enforced from metadata; root helper with polkit;
  approval card as the polkit agent
- Checkpoints on Btrfs for root and home; Timeline panel
- Inline generated components (form, table, chart, choice, diff, preview)
- First-boot wizard; model router with a local-first policy
- Lease borders and the interrupt chord wired through Hyprland

## Phase 2 — Memory, made apps, hardening, an image (~3 months)

Exit: the OS proposes a correct routine from watching you and replays it
without a model.

- Observation layer: Hyprland events, shell history, inotify, browser history,
  notifications; SQLite timeline with local embeddings; proposed routines
- Structured skill recorder and model-free replay
- Made apps: sandboxed web views with scoped tool bridges
- Engine sandboxing (bubblewrap / Landlock); keyring for secrets; journald audit
- MausOS ISO and a signed package repo built from Omarchy's tooling
- Local Whisper and Piper for voice

## Phase 3 — Everyone, not just developers

- Declared-tools contract for apps, contributed upstream
- Natural-language install over Arch, AUR and Flathub metadata
- Installer polish, hardware enablement, multi-user, accessibility, localization
- Agent-generated Quickshell widgets
