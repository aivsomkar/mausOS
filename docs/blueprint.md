# MausOS blueprint (revision 2)

The design behind this repository. Written 5–6 September 2026 after reading
the OpenMausBot source (v0.1.55) and studying Omarchy 4.0.

## The short answer

MausOS is a Linux distribution whose session is a team of agents that operate
the machine through its native interfaces, not through pictures of it. The
reason to build on Linux is not that it is free: on Linux every application,
service and setting is reachable through a structured channel (D-Bus, a
command line, an IPC socket, a config file, the accessibility tree).
Screenshots are what you fall back to on platforms that hide those channels.
On MausOS they are the last rung of a ladder.

Roughly 80% of the agent runtime exists in OpenMausBot (harness, 17 engine
drivers, permission broker, computer use, embedded browser, skills, routines,
channels, companions). Roughly 80% of the distribution exists in Omarchy
(Arch + Hyprland, installer, package repo, migrations, snapshots, themes, agent
stubs). What remains is what makes it an operating system rather than a desktop
with agents installed: a capability registry, a daemon that mediates and
remembers, an observation layer that learns your workflows, and a shell that
renders interfaces agents generate.

## Principles

1. **Structure before pixels.** Reach an app by API, CLI, IPC, config, or
   accessibility tree. Look at the screen only to confirm or when nothing else exists.
2. **Every app is callable.** The OS maintains a registry of what each program
   can do and how to ask it.
3. **Learn, then replay.** Anything done through structured channels is a script.
   Recorded workflows run again without a model in the loop.
4. **The OS renders what agents make.** Inline components, whole custom apps,
   changes to the desktop itself.
5. **Ask, watch, approve, undo.** Risky actions ask. Everything is visible. Every
   approved action is a checkpoint.
6. **Any model, local first.** Frontier CLIs, open runtimes and local models share
   one driver contract. Structured control is what lets small local models work.

## The control ladder

| Rung | Channel | Examples | Share of actions (target) |
| --- | --- | --- | --- |
| 1 | Native interface: D-Bus, CLI, IPC socket, API | NetworkManager, systemd, PipeWire, MPRIS, `hyprctl`, Firefox/Chromium protocols, Blender/GIMP/Inkscape/LibreOffice scripting, Neovim RPC, tmux, mpv | ~55% |
| 2 | Configuration: dotfiles, GSettings, TOML/JSON | Hyprland reloads on save; themes; editor settings | ~15% |
| 3 | Accessibility tree (AT-SPI2) | Any GTK/Qt/Firefox/LibreOffice app; Chromium/Electron with a flag MausOS sets | ~20% |
| 4 | Compositor: window IPC, virtual input | Windows with no tree; games; canvases | ~7% |
| 5 | Vision: screenshot + vision model | Confirming outcomes; "this thing here" | ~3% |

When most actions land on rungs 1–3, a small local model becomes a competent
operator, actions become replayable logs, and approval cards can show the
actual call ("remove package firefox") rather than a coordinate.

## The capability registry

A local database of how each installed app can be driven, in order of trust:
curated manifests shipped with the OS (this repo's `registry/`), runtime D-Bus
introspection, desktop entries, `--help` parsing by a local model, entries
learned by agents and saved as skills, and tools declared by apps themselves.
Before a turn, the daemon hands the engine only the entries relevant to the
apps involved.

## What Omarchy teaches

Omarchy (DHH, MIT) turns Arch into a finished Hyprland desktop with one
command. Version 4.0 (Aug 2026) calls itself agentic: nine agent CLIs as lazy
stubs, a default-agent hotkey, a bar widget for subscription usage, crashes
routed to an agent with a diagnose skill, a shipped skill for system tailoring,
a `omarchy-{group}-{name}` command architecture with metadata comments, config
layering (package-owned files never edited), and a Quickshell desktop that is
"programmable rather than configurable".

MausOS takes: the base, the plumbing, the command architecture, the
agent-citizen conveniences, the config layering, the Quickshell bar, and the
terminal-first transport (tmux). MausOS adds what Omarchy lacks: structured app
control, a permission broker and sandbox, memory of the user, generated
interfaces, and a conversational shell for people who are not developers.

Cautions: Omarchy's repo is unsigned and Arch is rolling. MausOS signs its own
repo and keeps a slower stable channel.

## Architecture

```
Apps          Arch/AUR/Flatpak · Firefox, VS Code, LibreOffice, Blender… · made apps · declared-tools apps
Shell         OpenMausBot chat (React) · generated components · stage · terminal/files/timeline panels · Quickshell bar
Compositor    Hyprland: IPC, window rules, virtual input, screencopy, layer-shell · lease borders, interrupt chord
Daemon        mausd (OpenMausBot harness): drivers, broker, routines, skills · registry · ladder executor · observation · router · checkpoints · maus-* commands + MCP
Engines       claude/codex/gemini/… (user-installed) · OpenCode, Hermes, Pi (bundled) · llama.cpp/Ollama service
Services      maus-system (polkit helper) · NetworkManager · PipeWire · BlueZ · AT-SPI · keyring · journald · bubblewrap/Landlock
Base          Arch, Btrfs + Limine snapshots, Omarchy update/migrations, themes · signed MausOS repo · MausOS ISO
```

One request: user or trigger → context assembled (registry entries, workflow
memory, skills) → router picks a model (local for structured work, frontier for
open-ended, vision only for rung 5) → agent calls a tool → broker classifies
(safe: run; ask: card; privileged: polkit card; vision: labelled) → checkpoint,
execute, verify → observe and remember.

### Display and control

Hyprland is the compositor; no compositor of our own. Leases are Hyprland window
properties (green border), the interrupt chord is a Hyprland bind, input rate
limits live in the daemon. The Cua driver is not needed on MausOS.

### Daemon and command surface

The OpenMausBot harness becomes `mausd`, a systemd user service. Commands first,
MCP second: every capability is a `maus-{group}-{name}` script with metadata
(summary, args, rung, risk, sudo); `maus mcp` serves the same catalogue as
MCP tools.

### Models

OpenMausBot's engine matrix plus Omarchy's lazy stubs. The local-tool-calling
gap is closed by OpenCode over ACP with Ollama. The router defaults local for
rungs 1–4.

### Security and undo

Engines sandboxed (bubblewrap/Landlock). Privileged work through a root helper
with polkit; the approval card is the polkit UI. Btrfs snapshots before any
"ask"-class action, listed in a Timeline, restorable in one click. An audit
journal of bot, tool, rung, arguments, approval, snapshot.

## Knows your workflows

Structured events, never pixels: Hyprland focus events, shell history, inotify,
browser history, MPRIS, notifications, udev, package logs, journald. A local
SQLite timeline with embeddings, pattern mining, proposed routines that land
paused. Off by default, per-source opt-in, visible, pausable, with exclusions.
The skill recorder records structured events and generalizes them into a skill
whose body is a script of `maus` commands: replay needs no model.

## Generative interfaces

Inline components (form, table, chart, diff, preview, choice) from a small
JSON schema, rendered as React with actions bound to tools. Made apps: small
web apps written by the agent into `~/.maus/apps/<name>`, opened on the stage
in a sandboxed web view with a scoped tool bridge. The desktop itself: themes
from a 24-colour palette, Quickshell widgets in QML.

## The interface

Chat pinned to a hotkey (Super+A) on a Hyprland special workspace; the stage is
Hyprland's tiling area with a green border on any window a bot holds; the
Quickshell bar gains a Maus widget (activity, model, usage, interrupt). Rail:
bots, channels, made apps, System (Files, Terminal, Timeline, Registry). Modes:
Chat, Desktop (plain Omarchy with the overlay), Call (voice first).

## Execution plan

- **Phase 0 (2 weeks):** Omarchy + Maus layer. This repo.
- **Phase 1 (~3 months):** ladder executor, registry v1 (top 40 apps), broker
  with risk classes, polkit helper, checkpoints, inline components, first-boot
  wizard, router. Exit: a week of daily use with under 5% vision.
- **Phase 2 (~3 months):** observation layer, structured recorder and replay,
  made apps, sandboxing, keyring, signed repo and ISO, local voice. Exit: a
  correct routine proposed from watching, replayed without a model.
- **Phase 3 (3–6 months):** declared-tools contract, natural-language install,
  installer polish, multi-user, accessibility, localization, generated widgets.

## Risks

Registry coverage (mitigate: curate the top 40, measure the vision rate).
Electron/Chromium apps hiding their trees (mitigate: launch flags; fall back to
rung 4/5). Observation trust (off by default, local, visible). Arch/Omarchy
drift (own signed repo, stable channel). Proprietary CLI terms (lazy stubs).
Electron shell weight (acceptable; daemon API is the contract). Scope (no
kernel, no compositor, no package manager).

## Decisions

See [decisions.md](decisions.md).
