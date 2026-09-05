// `maus mcp`: the command catalogue as an MCP server over stdio.
//
// Newline-delimited JSON-RPC 2.0 on stdin/stdout (the MCP stdio transport).
// Each maus-* command becomes one tool whose only input is `args` (an array
// of strings, exactly what you would type after the command). Output text is
// returned as-is; a non-zero exit sets isError. Logging goes to stderr only:
// stdout belongs to the protocol.
//
// Zero dependencies on purpose: this runs inside every bot's tool config and
// must start in milliseconds on a machine that may have no node_modules.
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { loadCatalogue, toolFromEntry, toolName } from "./metadata.mjs";

const VERSION = "0.0.1";
const PROTOCOL_DEFAULT = "2025-06-18";
const MAX_OUTPUT = 200_000;

export function defaultRunner(file, args, { timeoutMs, env }) {
  return new Promise((resolve) => {
    const child = spawn(file, args, {
      env: { ...process.env, ...env, MAUS_COMMAND: undefined },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, timeoutMs);
    child.stdout.on("data", (d) => {
      if (stdout.length < MAX_OUTPUT) stdout += d.toString();
    });
    child.stderr.on("data", (d) => {
      if (stderr.length < MAX_OUTPUT) stderr += d.toString();
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({ code: 127, stdout, stderr: `${stderr}${err.message}` });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code: timedOut ? 124 : code ?? 1, stdout, stderr: timedOut ? `${stderr}\n(timed out after ${timeoutMs}ms)` : stderr });
    });
  });
}

export function createServer({ binDir, runner = defaultRunner, timeoutMs = 120_000, log = () => {} } = {}) {
  const catalogue = loadCatalogue(binDir);
  const byTool = new Map(catalogue.map((e) => [toolName(e), e]));
  const tools = catalogue.map(toolFromEntry);

  const rpcError = (id, code, message) => ({ jsonrpc: "2.0", id, error: { code, message } });
  const rpcResult = (id, result) => ({ jsonrpc: "2.0", id, result });

  async function callTool(name, params) {
    const entry = byTool.get(name);
    if (!entry) {
      return { content: [{ type: "text", text: `Unknown tool ${name}. Call tools/list.` }], isError: true };
    }
    const args = Array.isArray(params?.args) ? params.args.map(String) : [];
    log(`call ${entry.command} ${JSON.stringify(args)}`);
    const { code, stdout, stderr } = await runner(entry.file, args, {
      timeoutMs,
      env: { MAUSOS_MCP: "1", MAUS_BIN_DIR: binDir },
    });
    const parts = [];
    if (stdout.trim()) parts.push(stdout.trimEnd());
    if (stderr.trim()) parts.push(`[stderr]\n${stderr.trimEnd()}`);
    if (code !== 0) parts.push(`[exit ${code}]`);
    const text = parts.join("\n") || "(no output)";
    const result = { content: [{ type: "text", text }], isError: code !== 0 };
    if (entry.json && code === 0) {
      try {
        result.structuredContent = { result: JSON.parse(stdout) };
      } catch {
        // not JSON this time (e.g. --json was not passed); text is enough
      }
    }
    return result;
  }

  /** Handle one JSON-RPC message. Returns a response, or null for notifications. */
  async function handle(msg) {
    if (!msg || typeof msg !== "object" || msg.jsonrpc !== "2.0") {
      return rpcError(msg?.id ?? null, -32600, "Invalid request");
    }
    const { id, method, params } = msg;
    const isNotification = id === undefined;
    try {
      switch (method) {
        case "initialize":
          return rpcResult(id, {
            protocolVersion: typeof params?.protocolVersion === "string" ? params.protocolVersion : PROTOCOL_DEFAULT,
            capabilities: { tools: { listChanged: false } },
            serverInfo: { name: "maus", version: VERSION },
            instructions:
              "MausOS commands. Climb the control ladder: prefer rung 1 (native interfaces) and 3 (accessibility tree: maus_app_find/press/set/text) over rung 4 (maus_win_input) and 5 (maus_see_shot). Take a maus_win_lease before driving a window. Commands marked ask/privileged need the user's approval.",
          });
        case "notifications/initialized":
        case "notifications/cancelled":
        case "notifications/progress":
          return null;
        case "ping":
          return rpcResult(id, {});
        case "tools/list":
          return rpcResult(id, { tools });
        case "tools/call":
          return rpcResult(id, await callTool(params?.name, params?.arguments));
        case "resources/list":
          return rpcResult(id, { resources: [] });
        case "prompts/list":
          return rpcResult(id, { prompts: [] });
        default:
          if (isNotification) return null;
          return rpcError(id, -32601, `Method not found: ${method}`);
      }
    } catch (err) {
      if (isNotification) return null;
      return rpcError(id, -32603, err?.message || String(err));
    }
  }

  return { handle, tools, catalogue };
}

export async function main() {
  const here = dirname(fileURLToPath(import.meta.url));
  const binDir = process.env.MAUS_BIN_DIR || join(here, "..", "bin");
  const server = createServer({ binDir, log: (s) => process.stderr.write(`maus mcp: ${s}\n`) });
  const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });
  const write = (obj) => process.stdout.write(`${JSON.stringify(obj)}\n`);
  for await (const line of rl) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let msg;
    try {
      msg = JSON.parse(trimmed);
    } catch {
      write({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } });
      continue;
    }
    if (Array.isArray(msg)) {
      const out = (await Promise.all(msg.map((m) => server.handle(m)))).filter(Boolean);
      if (out.length) write(out);
      continue;
    }
    const res = await server.handle(msg);
    if (res) write(res);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((err) => {
    process.stderr.write(`maus mcp: fatal ${err?.stack || err}\n`);
    process.exit(1);
  });
}
