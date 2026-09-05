# MausOS agent notes

Conventions for AI agents (and people) working on this repository.

## Commands

- Every command is a file `bin/maus-<group>-<name>`, bash 5, `#!/bin/bash`,
  two-space indent, `set -euo pipefail` after the metadata block.
- The first 40 lines carry metadata comments. Required: `group`, `summary`,
  `risk`, `rung`. Optional: `args`, `examples` (pipe-separated), `requires-sudo`,
  `hidden`, `json` (true when `--json` is supported or output is always JSON).

  ```bash
  #!/bin/bash
  # maus:group=win
  # maus:summary=List open windows
  # maus:args=[--json]
  # maus:risk=safe
  # maus:rung=4
  # maus:examples=maus win list|maus win list --json
  ```

- Risk classes: `safe` (read, or reversible inside the workspace), `ask`
  (changes state outside the workspace, leaves the machine, or costs money),
  `privileged` (needs root), `vision` (uses a screenshot; rung 5).
- Rungs: 1 native interface, 2 configuration, 3 accessibility tree,
  4 compositor/input, 5 vision. Pick the highest rung that does the job.
- Source `lib/maus-common.sh` through the real path of the script
  (`readlink -f`), because commands are symlinked into `~/.local/bin`.
- Prefer JSON output when `--json` is given; keep human output one item per line.
- Never edit files under `/usr/share/omarchy` or `/usr/share/mausos`. User
  overrides live in `~/.config`.
- A command that acts on the user's desktop must be visible: log it with
  `maus_log` so it lands in `~/.local/state/mausos/actions.log`.

## Install steps

- `install/<step>.sh` files are sourced by `install.sh`, not executed: no
  shebang, no `set -e` of their own, use the helpers in `install/helpers.sh`.
- Steps must be idempotent. Re-running the installer on a configured machine
  changes nothing.

## Tests and checks

```sh
npm test                 # node --test mcp/*.test.mjs
bash -n bin/* install/*.sh lib/*.sh install.sh boot.sh
shellcheck bin/* install/*.sh lib/*.sh install.sh boot.sh
python3 -m py_compile lib/atspi.py
```

Before claiming a desktop-facing change works, run it on a real Hyprland
session (`maus doctor` first) and say what you ran.
