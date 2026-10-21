// Compatibility fixes for the pinned upstream scene operations on the locked Godot.
import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";

const file = new URL("./node_modules/@coding-solo/godot-mcp/build/scripts/godot_operations.gd", import.meta.url);
let source = readFileSync(file, "utf8");
const original = "    scene_root.owner = scene_root";
const fixed = "    # Root ownership stays null; descendants are owned by this root.";
if (!source.includes(fixed)) {
  assert.equal(source.split(original).length - 1, 1, "Pinned upstream owner assignment changed; review patch");
  source = source.replace(original, fixed);
}
const pack = "    var result = packed_scene.pack(scene_root)";
const release = `${pack}\n    scene_root.free() # MCP: release temporary scene after packing`;
if (!source.includes(release)) {
  assert.equal(source.split(pack).length - 1, 4, "Pinned upstream scene packing changed; review patch");
  source = source.replaceAll(pack, release);
}
writeFileSync(file, source);
console.log("Applied Godot MCP root-owner and temporary-scene cleanup fixes");
