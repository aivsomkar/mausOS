# MausOS

**An AI-native Linux desktop.** A team of agents is the shell. They operate your
apps through the interfaces Linux already exposes (D-Bus, command lines, IPC
sockets, config files, the accessibility tree) and look at the screen only when
nothing else works.

MausOS is a layer on top of [Omarchy](https://github.com/omacom/omarchy)
(Arch + Hyprland) that installs [OpenMausBot](https://github.com/milind-soni/OpenMausBot)
as a system daemon, pins its chat interface to a hotkey, and gives every agent a
self-describing command surface for the machine.

> Status: **Phase 0**. It boots into chat on top of an Omarchy install and lets
> a local model drive Firefox by accessibility tree instead of screenshots.
> See [ROADMAP.md](ROADMAP.md) for what comes next and
> [docs/blueprint.md](docs/blueprint.md) for the full design.

## Install

On a machine that already runs Omarchy (or any Arch + Hyprland setup):

```sh
curl -fsSL https://raw.githubusercontent.com/aivsomkar/mausOS/main/boot.sh | bash
```

That clones this repo to `~/.local/share/mausos/mausOS` and runs `install.sh`,
which:

1. installs the small set of packages the commands need (jq, tmux, grim, wtype,
   python-gobject, at-spi2-core, nodejs, pnpm, chromium…),
2. turns on accessibility trees for GTK, Qt, Firefox, Chromium and Electron apps,
3. links the `maus` command family into `~/.local/bin`,
4. adds `~/.config/hypr/mausos.conf` (Super+A toggles the shell,
   Super+Shift+Escape stops every agent),
5. builds OpenMausBot and runs it as the `mausd` user service on `127.0.0.1:8799`,
6. installs OpenCode and Ollama with a local model so it works offline,
7. registers `maus mcp` with mausd so every bot gets the commands as tools,
8. links the MausOS skill into your agents' skill directories,
9. opens the shell.

Every step can be skipped: `MAUSOS_SKIP="engines shell" bash install.sh`.
Re-running the installer is safe; it is idempotent.

## Use

| Key | What |
| --- | --- |
| `Super + A` | Toggle the MausOS shell (chat with your bots) |
| `Super + Shift + Escape` | Interrupt: stop every agent turn and release every window lease |

From a terminal, or from any agent:

```sh
maus                       # every command, grouped
maus win list              # open windows as JSON (Hyprland IPC)
maus app tree firefox      # Firefox's accessibility tree, no screenshot
maus app press firefox "Reload"
maus app set firefox "Search" "hyprland window rules"
maus term open build && maus term send build "make" && maus term wait build
maus pkg add blender       # asks, then installs through omarchy/pacman/yay
maus net status
maus agent send maus "clean up my downloads"
maus doctor                # what works on this machine
maus list --json           # machine-readable catalogue (what `maus mcp` serves)
```

Every command carries metadata in its header: a summary, its arguments, the
control **rung** it uses (1 native interface … 5 vision) and a **risk** class
(`safe`, `ask`, `privileged`, `vision`). `maus mcp` turns the same catalogue into
an MCP server, so agents that speak MCP get typed tools and agents that only run
commands get the same thing.

## Layout

```
bin/            maus entry point and every maus-<group>-<name> command
lib/            shared bash helpers and the AT-SPI tool (python-gobject)
mcp/            stdio MCP server that wraps the commands (node, zero deps)
registry/       capability manifests: how each app can be driven, per rung
skill/          the MausOS skill given to every agent
config/         Hyprland layer, systemd unit, desktop entry, environment
install/        the installer steps, one file each
docs/           blueprint, decisions, phase notes, command reference
```

## Principles

1. **Structure before pixels.** Reach an app by API, CLI, IPC, config, or
   accessibility tree. Look at the screen only to confirm or when nothing else exists.
2. **Every app is callable.** The registry knows how.
3. **Learn, then replay.** Anything done through structured channels is a script.
4. **The OS renders what agents make.**
5. **Ask, watch, approve, undo.**
6. **Any model, local first.**

## Credits and licenses

MausOS is MIT licensed. It stands on Omarchy (MIT, David Heinemeier Hansson) and
OpenMausBot (Apache 2.0, Milind Soni). See [NOTICE](NOTICE).
