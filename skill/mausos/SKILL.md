---
name: mausos
description: Operate a MausOS machine (Arch + Hyprland + OpenMausBot). Use the `maus` commands to drive apps through native interfaces and accessibility trees instead of screenshots, manage windows, packages, network, files and the shared terminal.
---

# MausOS

You are running on MausOS. The machine exposes a self-describing command family,
`maus`, and the same commands as MCP tools named `maus_<group>_<name>`. Run
`maus` (or `maus list --json`) to see everything; every command has `--help`.

## The rule: structure before pixels

Reach an app by the **highest rung** that works:

1. **Native interface** – a CLI, D-Bus, an IPC socket, a scripting API. Check the
   registry first: `maus registry for <window-class-or-app>` tells you what the
   app supports. Examples: `firefox --new-tab URL`, `blender -b file --python s.py`,
   `soffice --headless --convert-to pdf`, `nmcli`, `wpctl`, `playerctl`, `hyprctl`.
2. **Configuration** – edit the file the app reads (`~/.config/...`). Never touch
   `/usr/share/omarchy` or `/usr/share/mausos`; user overrides live in `~/.config`.
3. **Accessibility tree** – `maus app find <app> <name>`, `maus app press`,
   `maus app set`, `maus app text`, `maus app tree`. Works for GTK, Qt, Firefox,
   LibreOffice, and Chromium/Electron apps (MausOS enables their trees).
4. **Compositor / input** – `maus win focus`, `maus win input type|key`. Only when
   the app has no tree or no API.
5. **Vision** – `maus see shot` and a vision model. Only to confirm an outcome or
   when nothing above exists. Say so when you use it.

Terminal output is text: use `maus term open|send|read|wait`, never a screenshot.

## Procedure for driving a GUI app

```sh
maus win list                       # is it open? get its class/address
maus registry for firefox           # what channels exist?
maus app launch firefox -- URL      # rung 1 when possible
maus win lease firefox --by <you>   # green border: the user sees you hold it
maus app find firefox "Search"      # find widgets by name → ids
maus app set firefox "Search or enter address" "query"
maus win input key Return           # only if the tree has no 'activate' action
maus app text firefox               # read the result as text
maus win release --all              # give it back when done
```

Take a checkpoint before anything destructive: `maus file snapshot "before X"`.
Delete with `maus file trash`, never `rm`.

## Risk classes (the broker enforces these; act accordingly)

- `safe`: read-only or reversible inside the workspace. Just do it.
- `ask`: changes state outside the workspace, leaves the machine, or costs money.
  Explain what will happen; the user gets an approval card.
- `privileged`: needs root (`maus pkg add`, system units). Always an approval.
- `vision`: takes a screenshot. Label it.

## Stop conditions

- A CAPTCHA, an OAuth login, a payment form, or a password prompt: release the
  lease (`maus win release --all`), tell the user, wait.
- Something you did not expect appears on screen: stop and describe it.
- `Super+Shift+Escape` is the user's interrupt; if your turn ends abruptly, that
  is why. Do not resume without being asked.

## Talking to other bots and the daemon

`maus agent list`, `maus agent send <bot> <text>`, `maus agent stop --all`,
`maus daemon status`. Every action you take through `maus` is logged to
`~/.local/state/mausos/actions.log`; the user can read it.
