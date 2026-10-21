// Exercise the configured stdio server; all scene writes stay in a temporary project.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport, getDefaultEnvironment } from "@modelcontextprotocol/sdk/client/stdio.js";

const root = fileURLToPath(new URL("../../", import.meta.url));
const config = JSON.parse(execFileSync("python3", ["-c",
  "import json,sys,tomllib; print(json.dumps(tomllib.load(open(sys.argv[1],'rb'))['mcp_servers']['jiuding_godot']))",
  join(root, ".codex/config.toml")], { encoding: "utf8" }));
const expectedVersion = JSON.parse(readFileSync(join(root, "godot/engine-lock.json"), "utf8")).version;
process.chdir(config.cwd);
const transport = new StdioClientTransport({
  command: config.command,
  args: config.args,
  env: { ...getDefaultEnvironment(), ...config.env },
});
const client = new Client({ name: "nine-tripods-mcp-check", version: "1.0.0" }, { capabilities: {} });
const temporary = mkdtempSync(join(tmpdir(), "jiuding-godot-mcp-"));
const passed = [];

async function call(name, args = {}) {
  assert(!config.disabled_tools?.includes(name), `${name} is disabled in project config`);
  const result = await client.callTool({ name, arguments: args }, undefined, { timeout: 20000 });
  const text = result.content.filter(item => item.type === "text").map(item => item.text).join("\n");
  assert(!result.isError && !/SCRIPT ERROR:|\[ERROR\]|\bERROR:/.test(text), `${name}: ${text}`);
  passed.push(name);
  return text;
}

try {
  await client.connect(transport);
  const { tools } = await client.listTools();
  assert.equal(tools.length, 14);
  assert((await call("get_godot_version")).includes(expectedVersion));
  await call("list_projects", { directory: root, recursive: false });
  const info = JSON.parse(await call("get_project_info", { projectPath: join(root, "godot") }));
  assert.equal(info.path, join(root, "godot"));
  assert.equal(info.godotVersion, expectedVersion);

  writeFileSync(join(temporary, "project.godot"), 'config_version=5\n[application]\nconfig/name="MCP check"\n');
  writeFileSync(join(temporary, "probe.gd"), "extends RefCounted\n");
  copyFileSync(join(root, "godot/assets/generated/arrow.png"), join(temporary, "sprite.png"));
  const imported = execFileSync(config.env.GODOT_PATH, ["--headless", "--path", temporary, "--editor", "--import"],
    { encoding: "utf8", timeout: 20000, stdio: ["ignore", "pipe", "pipe"] });
  assert(!/SCRIPT ERROR:|\bERROR:/.test(imported));
  const scene = { projectPath: temporary, scenePath: "probe.tscn" };
  await call("create_scene", { ...scene, rootNodeType: "Node2D" });
  assert(existsSync(join(temporary, "probe.tscn")));
  await call("add_node", { ...scene, parentNodePath: "root", nodeType: "Sprite2D", nodeName: "ProbeSprite" });
  await call("load_sprite", { ...scene, nodePath: "ProbeSprite", texturePath: "sprite.png" });
  await call("save_scene", { ...scene, newPath: "probe-copy.tscn" });
  const saved = readFileSync(join(temporary, "probe-copy.tscn"), "utf8");
  assert(saved.includes("ProbeSprite") && saved.includes("sprite.png"));
  assert((await call("get_uid", { projectPath: temporary, filePath: "probe.gd" })).includes("uid://"));
  console.log(JSON.stringify({ status: "passed", godot: expectedVersion, tools: tools.length,
    disabled: config.disabled_tools, calls: passed, sceneWrites: "temporary project only" }, null, 2));
} finally {
  await client.close();
  await transport.close();
  rmSync(temporary, { recursive: true, force: true });
}
