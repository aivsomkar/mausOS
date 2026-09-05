#!/usr/bin/env python3
"""MausOS AT-SPI tool: read and drive any app through its accessibility tree.

Rung 3 of the control ladder. Every GTK, Qt, Firefox, LibreOffice and (with the
flag MausOS sets) Chromium/Electron app publishes a live tree of its widgets
over D-Bus. This tool turns that into JSON and lets an agent press buttons and
set fields by name, with no screenshot and no coordinates.

    atspi.py apps
    atspi.py tree  <app> [--depth N] [--all] [--max N]
    atspi.py find  <app> <query> [--role ROLE] [--all]
    atspi.py press <app> <target> [--action NAME]
    atspi.py set   <app> <target> <value>
    atspi.py focus <app> <target>
    atspi.py text  <app> [target]

<app>    a substring of the application name (case-insensitive) or a pid.
<target> a path like "0.3.1" (child indexes from the app root, as printed by
         tree/find) or a widget name. Names are matched exactly first, then
         case-insensitively, then as a substring; ambiguity is an error that
         lists the candidates.

Requires python-gobject and at-spi2-core (installed by install/packages.sh).
"""

import json
import re
import sys

try:
    import gi

    gi.require_version("Atspi", "2.0")
    from gi.repository import Atspi
except (ImportError, ValueError) as exc:  # pragma: no cover - environment
    sys.stderr.write(
        "atspi: python-gobject with the Atspi typelib is required "
        f"(pacman -S python-gobject at-spi2-core): {exc}\n"
    )
    sys.exit(2)


STATE_NAMES = [
    ("showing", "SHOWING"),
    ("visible", "VISIBLE"),
    ("enabled", "ENABLED"),
    ("sensitive", "SENSITIVE"),
    ("focused", "FOCUSED"),
    ("focusable", "FOCUSABLE"),
    ("checked", "CHECKED"),
    ("selected", "SELECTED"),
    ("expanded", "EXPANDED"),
    ("editable", "EDITABLE"),
    ("pressed", "PRESSED"),
    ("active", "ACTIVE"),
    ("default", "DEFAULT"),
    ("modal", "MODAL"),
]

PATH_RE = re.compile(r"^\d+(\.\d+)*$")
DEFAULT_MAX_NODES = 4000


def fail(message, code=1):
    sys.stderr.write(f"atspi: {message}\n")
    sys.exit(code)


def emit(obj):
    json.dump(obj, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


# ---------------------------------------------------------------- accessibles


def safe(fn, default=None):
    try:
        return fn()
    except Exception:  # noqa: BLE001 - AT-SPI raises GLib errors for stale nodes
        return default


def states_of(acc):
    ss = safe(acc.get_state_set)
    if ss is None:
        return []
    out = []
    for label, enum_name in STATE_NAMES:
        enum = getattr(Atspi.StateType, enum_name, None)
        if enum is not None and safe(lambda: ss.contains(enum), False):
            out.append(label)
    return out


def actions_of(acc):
    action = safe(acc.get_action_iface)
    if action is None:
        return []
    n = safe(action.get_n_actions, 0) or 0
    names = []
    for i in range(n):
        name = safe(lambda i=i: action.get_action_name(i)) or ""
        names.append(name)
    return names


def bounds_of(acc):
    comp = safe(acc.get_component_iface)
    if comp is None:
        return None
    rect = safe(lambda: comp.get_extents(Atspi.CoordType.SCREEN))
    if rect is None:
        return None
    return [rect.x, rect.y, rect.width, rect.height]


def value_of(acc):
    val = safe(acc.get_value_iface)
    if val is None:
        return None
    return safe(val.get_current_value)


def text_of(acc, limit=400):
    text = safe(acc.get_text_iface)
    if text is None:
        return None
    count = safe(text.get_character_count, 0) or 0
    if count <= 0:
        return None
    s = safe(lambda: text.get_text(0, min(count, limit))) or ""
    if count > limit:
        s += "…"
    return s


def child_count(acc):
    return safe(acc.get_child_count, 0) or 0


def child_at(acc, i):
    return safe(lambda: acc.get_child_at_index(i))


def node_dict(acc, path, with_text=True):
    d = {
        "id": path,
        "role": safe(acc.get_role_name, "") or "",
        "name": safe(acc.get_name, "") or "",
    }
    desc = safe(acc.get_description, "") or ""
    if desc:
        d["description"] = desc
    states = states_of(acc)
    if states:
        d["states"] = states
    actions = actions_of(acc)
    if actions:
        d["actions"] = actions
    b = bounds_of(acc)
    if b:
        d["bounds"] = b
    v = value_of(acc)
    if v is not None:
        d["value"] = v
    if with_text and d["role"] in ("text", "entry", "password text", "paragraph", "label", "heading", "static", "document web", "terminal"):
        t = text_of(acc)
        if t:
            d["text"] = t
    return d


def is_shown(acc):
    ss = safe(acc.get_state_set)
    if ss is None:
        return True
    showing = safe(lambda: ss.contains(Atspi.StateType.SHOWING), True)
    visible = safe(lambda: ss.contains(Atspi.StateType.VISIBLE), True)
    return showing or visible


# ---------------------------------------------------------------- apps


def desktop_apps():
    desktop = Atspi.get_desktop(0)
    for i in range(child_count(desktop)):
        app = child_at(desktop, i)
        if app is None:
            continue
        yield app


def find_app(query):
    q = str(query)
    apps = list(desktop_apps())
    if q.isdigit():
        for app in apps:
            if safe(app.get_process_id, -1) == int(q):
                return app
    exact = [a for a in apps if (safe(a.get_name, "") or "") == q]
    if len(exact) == 1:
        return exact[0]
    lowered = [a for a in apps if (safe(a.get_name, "") or "").lower() == q.lower()]
    if len(lowered) == 1:
        return lowered[0]
    subs = [a for a in apps if q.lower() in (safe(a.get_name, "") or "").lower()]
    if len(subs) == 1:
        return subs[0]
    if not subs:
        names = sorted({safe(a.get_name, "") or "?" for a in apps})
        fail(f"no application matches '{q}'. Running: {', '.join(names)}")
    names = [f"{safe(a.get_name, '')}(pid {safe(a.get_process_id, '?')})" for a in subs]
    fail(f"'{q}' is ambiguous: {', '.join(names)}. Use a pid.")
    return None


def app_summary(app):
    return {
        "name": safe(app.get_name, "") or "",
        "pid": safe(app.get_process_id, None),
        "toolkit": safe(app.get_toolkit_name, "") or "",
        "windows": child_count(app),
    }


# ---------------------------------------------------------------- walking


def walk(acc, path, depth, max_depth, include_hidden, budget, visit):
    """Depth-first walk. `visit(acc, path, depth)` returns False to prune."""
    if budget[0] <= 0:
        return
    budget[0] -= 1
    if not include_hidden and depth > 0 and not is_shown(acc):
        return
    if visit(acc, path, depth) is False:
        return
    if max_depth is not None and depth >= max_depth:
        return
    for i in range(child_count(acc)):
        child = child_at(acc, i)
        if child is None:
            continue
        walk(child, f"{path}.{i}" if path else str(i), depth + 1, max_depth, include_hidden, budget, visit)


def build_tree(app, max_depth, include_hidden, max_nodes):
    root = {"app": app_summary(app), "children": []}
    nodes = {}

    def visit(acc, path, depth):
        d = node_dict(acc, path)
        d["children"] = []
        if "." in path:
            parent = nodes.get(path.rsplit(".", 1)[0], root)
        else:
            parent = root
        parent["children"].append(d)
        nodes[path] = d
        return True

    budget = [max_nodes]
    # Children of the app are its windows; start at path index per window.
    for i in range(child_count(app)):
        win = child_at(app, i)
        if win is None:
            continue
        walk(win, str(i), 1, max_depth, include_hidden, budget, visit)
    root["truncated"] = budget[0] <= 0
    return root


def resolve_path(app, path):
    acc = app
    for part in path.split("."):
        acc = child_at(acc, int(part))
        if acc is None:
            fail(f"path {path} does not exist (tree changed?)")
    return acc


def find_nodes(app, query, role=None, include_hidden=False, max_nodes=DEFAULT_MAX_NODES):
    q = query.lower()
    exact, ci, sub = [], [], []

    def visit(acc, path, depth):
        name = safe(acc.get_name, "") or ""
        r = safe(acc.get_role_name, "") or ""
        if role and r != role:
            return True
        if not name:
            return True
        if name == query:
            exact.append((acc, path))
        elif name.lower() == q:
            ci.append((acc, path))
        elif q in name.lower():
            sub.append((acc, path))
        return True

    budget = [max_nodes]
    for i in range(child_count(app)):
        win = child_at(app, i)
        if win is None:
            continue
        walk(win, str(i), 1, None, include_hidden, budget, visit)
    return exact, ci, sub


def resolve_target(app, target, role=None, include_hidden=False):
    if PATH_RE.match(target):
        return resolve_path(app, target), target
    exact, ci, sub = find_nodes(app, target, role, include_hidden)
    for bucket in (exact, ci, sub):
        if len(bucket) == 1:
            return bucket[0]
        if len(bucket) > 1:
            cands = ", ".join(f"{p} {safe(a.get_role_name, '')} '{safe(a.get_name, '')}'" for a, p in bucket[:12])
            fail(f"'{target}' matches several widgets: {cands}. Use a path id.")
    fail(f"no widget named '{target}' in {safe(app.get_name, '')}. Try: atspi.py find <app> <part-of-name>")
    return None, None


# ---------------------------------------------------------------- commands


def parse_flags(args):
    flags, rest = {}, []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--all",):
            flags["all"] = True
        elif a in ("--depth", "--max", "--role", "--action"):
            if i + 1 >= len(args):
                fail(f"{a} needs a value")
            flags[a[2:]] = args[i + 1]
            i += 1
        else:
            rest.append(a)
        i += 1
    return flags, rest


def cmd_apps(args):
    emit([app_summary(a) for a in desktop_apps()])


def cmd_tree(args):
    flags, rest = parse_flags(args)
    if not rest:
        fail("usage: tree <app> [--depth N] [--all] [--max N]")
    app = find_app(rest[0])
    depth = int(flags["depth"]) if "depth" in flags else None
    max_nodes = int(flags.get("max", DEFAULT_MAX_NODES))
    emit(build_tree(app, depth, flags.get("all", False), max_nodes))


def cmd_find(args):
    flags, rest = parse_flags(args)
    if len(rest) < 2:
        fail("usage: find <app> <query> [--role ROLE] [--all]")
    app = find_app(rest[0])
    exact, ci, sub = find_nodes(app, rest[1], flags.get("role"), flags.get("all", False))
    out = []
    for bucket, how in ((exact, "exact"), (ci, "case-insensitive"), (sub, "substring")):
        for acc, path in bucket:
            d = node_dict(acc, path)
            d["match"] = how
            out.append(d)
    emit(out)


def pick_action(names, wanted):
    if wanted:
        for i, n in enumerate(names):
            if n == wanted or n.lower() == wanted.lower():
                return i
        fail(f"no action '{wanted}'; available: {names}")
    for pref in ("click", "press", "activate", "toggle", "jump", "select", "expand"):
        for i, n in enumerate(names):
            if n.lower() == pref:
                return i
    return 0


def cmd_press(args):
    flags, rest = parse_flags(args)
    if len(rest) < 2:
        fail("usage: press <app> <target> [--action NAME]")
    app = find_app(rest[0])
    acc, path = resolve_target(app, rest[1], include_hidden=flags.get("all", False))
    action = safe(acc.get_action_iface)
    if action is None:
        fail(f"{path} ({safe(acc.get_role_name, '')} '{safe(acc.get_name, '')}') has no actions; try focus + maus win input")
    names = actions_of(acc)
    idx = pick_action(names, flags.get("action"))
    ok = safe(lambda: action.do_action(idx), False)
    emit({"ok": bool(ok), "id": path, "name": safe(acc.get_name, ""), "role": safe(acc.get_role_name, ""), "action": names[idx] if names else None})
    if not ok:
        sys.exit(1)


def cmd_set(args):
    flags, rest = parse_flags(args)
    if len(rest) < 3:
        fail("usage: set <app> <target> <value>")
    app = find_app(rest[0])
    acc, path = resolve_target(app, rest[1], include_hidden=flags.get("all", False))
    value = " ".join(rest[2:])
    editable = safe(acc.get_editable_text_iface)
    if editable is not None:
        ok = safe(lambda: editable.set_text_contents(value), False)
        emit({"ok": bool(ok), "id": path, "name": safe(acc.get_name, ""), "via": "editable-text", "value": value})
        sys.exit(0 if ok else 1)
    val = safe(acc.get_value_iface)
    if val is not None:
        try:
            number = float(value)
        except ValueError:
            fail(f"{path} takes a numeric value")
        ok = safe(lambda: val.set_current_value(number), False)
        emit({"ok": bool(ok), "id": path, "name": safe(acc.get_name, ""), "via": "value", "value": number})
        sys.exit(0 if ok else 1)
    fail(f"{path} ({safe(acc.get_role_name, '')}) is neither editable text nor a value; focus it and use maus win input type")


def cmd_focus(args):
    flags, rest = parse_flags(args)
    if len(rest) < 2:
        fail("usage: focus <app> <target>")
    app = find_app(rest[0])
    acc, path = resolve_target(app, rest[1], include_hidden=flags.get("all", False))
    comp = safe(acc.get_component_iface)
    if comp is None:
        fail(f"{path} cannot take focus")
    ok = safe(comp.grab_focus, False)
    emit({"ok": bool(ok), "id": path, "name": safe(acc.get_name, "")})
    sys.exit(0 if ok else 1)


def cmd_text(args):
    flags, rest = parse_flags(args)
    if not rest:
        fail("usage: text <app> [target]")
    app = find_app(rest[0])
    if len(rest) >= 2:
        acc, path = resolve_target(app, rest[1], include_hidden=flags.get("all", False))
        roots = [(acc, path)]
    else:
        roots = [(child_at(app, i), str(i)) for i in range(child_count(app))]
    pieces = []

    def visit(acc, path, depth):
        t = text_of(acc, limit=20000)
        if t:
            pieces.append(t)
            return False  # a text node's children repeat its content
        name = safe(acc.get_name, "") or ""
        role = safe(acc.get_role_name, "") or ""
        if name and role in ("heading", "label", "link", "push button", "menu item", "list item", "table cell", "static"):
            pieces.append(name)
        return True

    budget = [DEFAULT_MAX_NODES]
    for acc, path in roots:
        if acc is None:
            continue
        walk(acc, path, 1, None, flags.get("all", False), budget, visit)
    sys.stdout.write("\n".join(pieces) + "\n")


COMMANDS = {
    "apps": cmd_apps,
    "tree": cmd_tree,
    "find": cmd_find,
    "press": cmd_press,
    "set": cmd_set,
    "focus": cmd_focus,
    "text": cmd_text,
}


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        sys.stdout.write(__doc__)
        return 0
    cmd = argv[1]
    if cmd not in COMMANDS:
        fail(f"unknown command '{cmd}'. One of: {', '.join(COMMANDS)}")
    Atspi.init()
    try:
        COMMANDS[cmd](argv[2:])
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        fail(f"{type(exc).__name__}: {exc}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
