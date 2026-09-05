import { test } from "node:test";
import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createServer } from "./server.mjs";

const BIN = join(dirname(fileURLToPath(import.meta.url)), "..", "bin");

function fakeRunner(calls) {
  return async (file, args) => {
    calls.push({ file, args });
    if (file.endsWith("maus-win-list")) {
      return { code: 0, stdout: '[{"address":"0x1","class":"firefox"}]\n', stderr: "" };
    }
    if (file.endsWith("maus-app-press")) {
      return { code: 1, stdout: "", stderr: "atspi: no widget named 'Nope'\n" };
    }
    return { code: 0, stdout: `ran ${file.split(/[\\/]/).pop()} ${args.join(" ")}\n`, stderr: "" };
  };
}

test("initialize → tools/list → tools/call round trip", async () => {
  const calls = [];
  const server = createServer({ binDir: BIN, runner: fakeRunner(calls) });

  const init = await server.handle({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18", capabilities: {} } });
  assert.equal(init.result.protocolVersion, "2025-06-18");
  assert.equal(init.result.serverInfo.name, "maus");
  assert.ok(init.result.capabilities.tools);

  assert.equal(await server.handle({ jsonrpc: "2.0", method: "notifications/initialized" }), null);

  const list = await server.handle({ jsonrpc: "2.0", id: 2, method: "tools/list" });
  const names = list.result.tools.map((t) => t.name);
  assert.ok(names.includes("maus_win_list"));
  assert.ok(names.includes("maus_app_press"));
  assert.ok(!names.includes("maus_mcp"), "hidden commands are not tools");
  for (const t of list.result.tools) {
    assert.ok(t.description.length > 10, `${t.name} needs a description`);
    assert.equal(t.inputSchema.type, "object");
  }

  const call = await server.handle({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "maus_win_list", arguments: { args: ["--all"] } } });
  assert.equal(call.result.isError, false);
  assert.match(call.result.content[0].text, /firefox/);
  assert.deepEqual(call.result.structuredContent.result, [{ address: "0x1", class: "firefox" }]);
  assert.deepEqual(calls.at(-1).args, ["--all"]);
});

test("a failing command is reported as an error result, not a protocol error", async () => {
  const server = createServer({ binDir: BIN, runner: fakeRunner([]) });
  const res = await server.handle({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "maus_app_press", arguments: { args: ["firefox", "Nope"] } } });
  assert.equal(res.result.isError, true);
  assert.match(res.result.content[0].text, /no widget named/);
  assert.match(res.result.content[0].text, /\[exit 1\]/);
});

test("unknown tools and methods", async () => {
  const server = createServer({ binDir: BIN, runner: fakeRunner([]) });
  const bad = await server.handle({ jsonrpc: "2.0", id: 5, method: "tools/call", params: { name: "maus_nope", arguments: {} } });
  assert.equal(bad.result.isError, true);
  const unknown = await server.handle({ jsonrpc: "2.0", id: 6, method: "wat" });
  assert.equal(unknown.error.code, -32601);
  const ping = await server.handle({ jsonrpc: "2.0", id: 7, method: "ping" });
  assert.deepEqual(ping.result, {});
});

test("arguments are always passed as strings", async () => {
  const calls = [];
  const server = createServer({ binDir: BIN, runner: fakeRunner(calls) });
  await server.handle({ jsonrpc: "2.0", id: 8, method: "tools/call", params: { name: "maus_hw_volume", arguments: { args: ["set", 40] } } });
  assert.deepEqual(calls.at(-1).args, ["set", "40"]);
});
