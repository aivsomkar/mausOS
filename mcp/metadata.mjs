// Reads the `# maus:key=value` header of every maus-* command and turns it
// into a catalogue. Shared by `maus mcp` (tools) and by tests. Zero deps.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const HEADER_LINES = 40;
const META_RE = /^# maus:([a-z-]+)=(.*)$/;

/** Parse one command's source. `fileName` is the basename, e.g. maus-win-list. */
export function parseMetadata(source, fileName) {
  const meta = {};
  for (const line of source.split(/\r?\n/).slice(0, HEADER_LINES)) {
    const m = META_RE.exec(line);
    if (m) meta[m[1]] = m[2].trim();
  }
  const base = fileName.replace(/^maus-?/, "");
  const [group, ...rest] = base.split("-");
  return {
    command: fileName,
    group: meta.group || group || "core",
    name: rest.join("-"),
    summary: meta.summary || "",
    args: meta.args || "",
    risk: meta.risk || "ask",
    rung: Number.parseInt(meta.rung || "1", 10) || 1,
    requiresSudo: meta["requires-sudo"] === "true",
    hidden: meta.hidden === "true",
    json: meta.json === "true",
    examples: meta.examples
      ? meta.examples.split("|").map((s) => s.trim()).filter(Boolean)
      : [],
  };
}

/** Every visible maus-* command in a directory, sorted by name. */
export function loadCatalogue(binDir, { includeHidden = false } = {}) {
  const out = [];
  for (const name of readdirSync(binDir)) {
    if (!name.startsWith("maus-")) continue;
    const file = join(binDir, name);
    let st;
    try {
      st = statSync(file);
    } catch {
      continue;
    }
    if (!st.isFile()) continue;
    const entry = parseMetadata(readFileSync(file, "utf8"), name);
    entry.file = file;
    if (entry.hidden && !includeHidden) continue;
    out.push(entry);
  }
  out.sort((a, b) => a.command.localeCompare(b.command));
  return out;
}

/** MCP tool name for an entry: maus-win-list → maus_win_list. */
export function toolName(entry) {
  return entry.command.replace(/-/g, "_");
}

const RISK_TEXT = {
  safe: "safe (read-only or reversible inside the workspace)",
  ask: "ask (changes state outside the workspace; needs the user's approval)",
  privileged: "privileged (needs root; needs the user's approval)",
  vision: "vision (takes a screenshot; rung 5, use only to confirm or when no tree exists)",
};

/** The MCP tool description for an entry. */
export function toolFromEntry(entry) {
  const usage = `maus ${entry.group} ${entry.name} ${entry.args}`.replace(/\s+$/, "");
  const lines = [
    entry.summary,
    `Usage: ${usage}`,
    `Rung ${entry.rung} of 5 · risk: ${RISK_TEXT[entry.risk] || entry.risk}${entry.requiresSudo ? " · uses sudo" : ""}`,
  ];
  if (entry.json) lines.push("Output is JSON (or supports --json).");
  if (entry.examples.length) lines.push(`Examples: ${entry.examples.join("  ·  ")}`);
  return {
    name: toolName(entry),
    description: lines.join("\n"),
    inputSchema: {
      type: "object",
      properties: {
        args: {
          type: "array",
          items: { type: "string" },
          description: `Command-line arguments, one per item: ${entry.args || "(none)"}`,
        },
      },
      additionalProperties: false,
    },
    annotations: {
      title: `maus ${entry.group} ${entry.name}`.trim(),
      readOnlyHint: entry.risk === "safe",
      destructiveHint: entry.risk === "ask" || entry.risk === "privileged",
      idempotentHint: entry.risk === "safe",
      openWorldHint: false,
    },
  };
}
