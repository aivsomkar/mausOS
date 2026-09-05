# Registry manifests

One JSON file per app or service in `manifests/`. A manifest answers: *how can
an agent drive this thing, at which rung, and what should it watch out for?*

```json
{
  "id": "firefox",
  "name": "Firefox",
  "kind": "browser",
  "match": { "class": ["firefox"], "desktop": ["firefox.desktop"], "binary": ["firefox"] },
  "rungs": {
    "1": [ { "channel": "cli|dbus|protocol|socket|api|data", "how": "…", "notes": "…" } ],
    "2": [ { "channel": "config", "how": "…", "notes": "…" } ],
    "3": [ { "channel": "atspi", "how": "…", "notes": "…" } ],
    "4": [ { "channel": "input", "how": "…" } ]
  },
  "capabilities": [
    { "name": "open_url", "rung": 1, "risk": "safe", "run": "firefox --new-tab {url}" }
  ],
  "quirks": [ "…" ],
  "verified": "curated-2026-09 | introspected | learned | unverified"
}
```

- `match` is how `maus registry for` finds the manifest from a Hyprland window
  class, a desktop id, or a binary name.
- `rungs` lists every known channel, best first. Rung numbers follow the
  control ladder: 1 native interface, 2 configuration, 3 accessibility tree,
  4 compositor/input, 5 vision. Rung 5 is never listed; it always exists.
- `capabilities` are concrete, runnable recipes. `{placeholders}` are filled by
  the caller. `risk` uses the same classes as commands.
- `verified` says where the entry came from. Only `curated-*` entries ship
  with MausOS; Phase 1 adds introspected and learned entries.

Sources, in order of trust: curated manifests (this directory), runtime D-Bus
introspection, desktop entries, `--help` parsing, entries learned by agents,
and tools declared by apps themselves.
