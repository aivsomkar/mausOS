import { test } from "node:test";
import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { loadCatalogue, parseMetadata, toolFromEntry, toolName } from "./metadata.mjs";

const BIN = join(dirname(fileURLToPath(import.meta.url)), "..", "bin");

test("parseMetadata reads the header keys and derives group/name from the file name", () => {
  const src = [
    "#!/bin/bash",
    "# maus:group=win",
    "# maus:summary=List open windows",
    "# maus:args=[--all]",
    "# maus:risk=safe",
    "# maus:rung=4",
    "# maus:json=true",
    "# maus:examples=maus win list|maus win list --all",
    "set -euo pipefail",
  ].join("\n");
  const e = parseMetadata(src, "maus-win-list");
  assert.equal(e.group, "win");
  assert.equal(e.name, "list");
  assert.equal(e.summary, "List open windows");
  assert.equal(e.risk, "safe");
  assert.equal(e.rung, 4);
  assert.equal(e.json, true);
  assert.equal(e.hidden, false);
  assert.deepEqual(e.examples, ["maus win list", "maus win list --all"]);
});

test("parseMetadata defaults are conservative", () => {
  const e = parseMetadata("#!/bin/bash\necho hi\n", "maus-foo-bar-baz");
  assert.equal(e.group, "foo");
  assert.equal(e.name, "bar-baz");
  assert.equal(e.risk, "ask");
  assert.equal(e.rung, 1);
});

test("metadata beyond the first 40 lines is ignored", () => {
  const src = `${"# filler\n".repeat(45)}# maus:summary=late\n`;
  const e = parseMetadata(src, "maus-x-y");
  assert.equal(e.summary, "");
});

test("the real bin directory yields a complete catalogue", () => {
  const cat = loadCatalogue(BIN);
  assert.ok(cat.length >= 30, `expected at least 30 commands, got ${cat.length}`);
  for (const e of cat) {
    assert.ok(e.summary, `${e.command} needs a summary`);
    assert.ok(["safe", "ask", "privileged", "vision"].includes(e.risk), `${e.command} has risk ${e.risk}`);
    assert.ok(e.rung >= 1 && e.rung <= 5, `${e.command} has rung ${e.rung}`);
    assert.ok(e.group, `${e.command} needs a group`);
  }
  assert.ok(!cat.some((e) => e.command === "maus-mcp"), "hidden commands are excluded");
  const withHidden = loadCatalogue(BIN, { includeHidden: true });
  assert.ok(withHidden.some((e) => e.command === "maus-mcp"));
});

test("tool descriptors carry usage, rung and risk annotations", () => {
  const e = parseMetadata(
    "# maus:group=pkg\n# maus:summary=Install packages\n# maus:args=<package…>\n# maus:risk=privileged\n# maus:rung=1\n# maus:requires-sudo=true\n",
    "maus-pkg-add",
  );
  const t = toolFromEntry(e);
  assert.equal(t.name, "maus_pkg_add");
  assert.equal(toolName(e), "maus_pkg_add");
  assert.match(t.description, /Usage: maus pkg add <package…>/);
  assert.match(t.description, /privileged/);
  assert.match(t.description, /uses sudo/);
  assert.equal(t.annotations.readOnlyHint, false);
  assert.equal(t.annotations.destructiveHint, true);
  assert.equal(t.inputSchema.properties.args.type, "array");
});
