# Decisions

Architecture decision records. Each one names the alternatives and why the
chosen path wins for MausOS. Revisit when the evidence changes.

## ADR-1 · Base: an Omarchy derivative (Arch + Hyprland), not an Ubuntu respin

**Chosen.** MausOS layers on Omarchy: Arch Linux, Hyprland, Omarchy's installer,
package repo, update/migration mechanism, Btrfs+Limine snapshots, themes and
lazy-installed agent CLIs. MIT licensed; attribution kept in NOTICE.

**Why.** Six months of distribution plumbing already exist and are maintained.
Hyprland has every window protocol agents need and a JSON IPC. Arch plus AUR
means "install X" works for nearly everything. The cost is a rolling release
(breakage) and dependence on Omarchy's direction and its unsigned repo.
Mitigation: our own signed repo (Phase 2) and a stable channel that lags.

**Rejected.** Ubuntu 24.04 respin with a custom compositor (revision 1 of the
blueprint): stable, but every piece of the distribution had to be built first.

## ADR-2 · Control strategy: structured first, vision last

**Chosen.** Every action climbs a five-rung ladder: native interface,
configuration, accessibility tree, compositor/input, vision. The highest rung
that works wins. Vision is labelled in the transcript. The share of actions that
needed vision is the product's key metric.

**Why.** Structured control is fast (milliseconds), cheap (small local models
suffice), deterministic (replays are exact), and inspectable (an approval card
shows the actual call). Linux is the only desktop where the top three rungs are
broadly available. Cost: per-app coverage work, and Electron apps that hide
their tree until a flag is set.

**Rejected.** Screenshot-first with structured shortcuts: works on any app on
day one, but slow, expensive, brittle, and impossible to replay.

## ADR-3 · Tool surface: self-describing commands first, MCP as a wrapper

**Chosen.** Every capability is a `maus-<group>-<name>` script with metadata
(summary, args, rung, risk, sudo). `maus mcp` serves the same catalogue as MCP
tools; `maus list --json` serves it to anything else. Omarchy's pattern.

**Why.** Every agent harness can run a command; humans can run and read the
same thing; tests are trivial. The MCP wrapper costs nothing and adds typed
annotations. Cost: per-call process spawn and clumsier streaming.

**Rejected.** An in-process MCP server as the primary surface: richer types,
but invisible to humans and to engines that do not speak MCP.

## ADR-4 · Shell: keep the React chat (OpenMausBot) beside Omarchy's Quickshell bar

**Chosen.** Phase 0 shows OpenMausBot's web UI in a Chromium app window on a
Hyprland special workspace (Super+A). The bar, notifications, OSD and lock
screen stay Omarchy's. Later phases extend the React shell (stage, terminal,
timeline panels).

**Why.** The interface already exists and generated components are web
technology. Cost: a Chromium process next to a QML shell. Acceptable on
developer hardware; the daemon API is the contract if a lighter shell comes.

**Rejected.** Rewriting the chat in QML.

## ADR-5 · Observation: off by default, per-source opt-in

**Chosen.** The observation layer (Phase 2) records structured events, never
pixels, and every source (windows, commands, files, browsing, notifications) is
off until the user enables it in the first-boot wizard. Local only, visible,
pausable, with exclusions.

**Why.** Trust. A system that watches everything is a liability if it leaks or
surprises. Cost: the "knows your workflows" features appear only for users who
opt in.

## ADR-6 · Trust default: approve rungs 1–3 inside the workspace, ask for the rest

**Chosen.** Reading files, calling apps by API, editing settings inside the
workspace are approved automatically once the user picks "Approve for me".
Anything privileged, anything outside the workspace, anything that leaves the
machine, and anything vision-driven asks. Checkpoints precede every "ask".

**Why.** Ten approval cards per simple task push users to "full access", which
is worse. Structured calls are inspectable and replays exact, so the risk of
auto-approving them is bounded. Phase 0 ships with OpenMausBot's default
(Ask) until the broker reads the risk classes (Phase 1).

## ADR-7 · No compositor of our own (supersedes blueprint revision 1)

**Chosen.** Hyprland is the display layer; MausOS drives it over IPC and the
standard Wayland protocols. Leases are Hyprland window properties; the
interrupt chord is a Hyprland bind.

**Why.** Everything a custom compositor would have provided already exists,
maintained by others. Placement of the shell window is done through
`hyprctl dispatch` rather than window rules so it survives Hyprland's rule
syntax changes.

## ADR-8 · Local engine: OpenCode over ACP with Ollama

**Chosen.** OpenCode (MIT) is the bundled default engine, connected to Ollama
with a small tool-capable model. OpenMausBot already drives OpenCode over ACP
with permission requests intact.

**Why.** OpenMausBot's OpenAI-compatible driver streams text only; OpenCode
brings a tool loop to any local model today. A native tool loop in the daemon
comes when routing needs it.
