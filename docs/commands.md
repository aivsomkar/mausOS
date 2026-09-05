# Command reference

`maus` prints this list from the commands' own headers; `maus list --json` is
the machine-readable form; `maus <group> <name> --help` shows one command.
Tags read `r<rung>/<risk>`: rung 1 native, 2 config, 3 accessibility tree,
4 compositor/input, 5 vision; risk safe / ask / privileged / vision.

## app — applications

| Command | What | Tag |
| --- | --- | --- |
| `maus app list [filter]` | Installed apps from desktop entries (id, name, exec, class) | r1/safe |
| `maus app launch <id\|name> [-- args]` | Launch; prints the new window's address | r1/safe |
| `maus app apps` | Running apps that publish an accessibility tree | r3/safe |
| `maus app tree <app> [--depth N] [--all]` | The tree as JSON: roles, names, states, actions, bounds | r3/safe |
| `maus app find <app> <query> [--role R]` | Widgets by name → ids | r3/safe |
| `maus app press <app> <name\|id> [--action A]` | Activate a widget through its a11y action | r3/ask |
| `maus app set <app> <name\|id> <value>` | Set a text field or slider | r3/ask |
| `maus app focus <app> <name\|id>` | Keyboard focus to a widget | r3/safe |
| `maus app text <app> [name\|id]` | Visible text of an app or widget | r3/safe |

## win — windows (Hyprland)

| Command | What | Tag |
| --- | --- | --- |
| `maus win list [--all]` | Open windows as JSON, with lease state | r4/safe |
| `maus win focus <addr\|class\|title>` | Focus a window | r4/safe |
| `maus win lease <window> [--by bot]` | Hold a window for an agent: green border, recorded | r4/ask |
| `maus win release <addr> \| --all` | Release leases, restore borders | r4/safe |
| `maus win events [--once]` | Hyprland event stream as JSON lines | r4/safe |
| `maus win input type <text> \| key <chord>` | Virtual keyboard to the focused window | r4/ask |

## term — shared terminal (tmux)

| Command | What | Tag |
| --- | --- | --- |
| `maus term open <name> [--cwd D] [--hidden]` | Open or reuse a named session, show it in a terminal | r1/safe |
| `maus term send <name> <cmd> [--no-enter]` | Type into it (the user sees it) | r1/ask |
| `maus term read <name> [--lines N]` | Read the tail as text | r1/safe |
| `maus term wait <name> [--until RE] [--timeout S]` | Wait for quiet or a pattern | r1/safe |

## file, pkg, net, hw, sys, see

| Command | What | Tag |
| --- | --- | --- |
| `maus file search <pattern> [dir] [--grep]` | Find by name or content | r1/safe |
| `maus file trash <path…> \| --list \| --restore` | Reversible delete | r1/ask |
| `maus file snapshot [label] \| --list` | Btrfs checkpoint of home | r1/privileged |
| `maus pkg search <q> [--json]` | Repos, AUR, Flathub | r1/safe |
| `maus pkg add <pkg…>` | Install (omarchy → yay → pacman → flatpak) | r1/privileged |
| `maus pkg remove <pkg…>` | Remove | r1/privileged |
| `maus net status [--scan]` | Devices, active connection, Wi‑Fi list | r1/safe |
| `maus net connect <ssid> [password]` | Join a network | r1/ask |
| `maus hw volume [get\|set N\|up\|down\|mute\|unmute]` | Output volume | r1/safe |
| `maus hw brightness [get\|set N\|up\|down]` | Screen brightness | r1/safe |
| `maus sys notify <title> [body]` | Desktop notification | r1/safe |
| `maus sys clipboard get \| set <text>` | Clipboard | r1/ask |
| `maus see shot [out.png] [--window\|--region] [--clipboard]` | Screenshot | r5/vision |

## registry, agent, shell, daemon, core

| Command | What | Tag |
| --- | --- | --- |
| `maus registry list [--json]` | Known apps and their best rung | r1/safe |
| `maus registry show <id>` | One manifest | r1/safe |
| `maus registry for <class\|desktop-id\|binary>` | Manifest for a window | r1/safe |
| `maus agent list` | Bots mausd knows | r1/safe |
| `maus agent send <bot> <text>` | Start a turn | r1/ask |
| `maus agent stop <bot> \| --all` | Interrupt, release leases, kill input | r1/safe |
| `maus shell open [--background]` | Open the shell window | r4/safe |
| `maus shell toggle` | Show/hide (Super+A) | r4/safe |
| `maus daemon run` | mausd in the foreground | r1/safe |
| `maus daemon status [--restart]` | Health, unit state, logs | r1/safe |
| `maus doctor [--json]` | What works here | r1/safe |
| `maus mcp` | The catalogue as an MCP server (stdio) | r1/safe |
| `maus list --json` | The catalogue as JSON | r1/safe |
