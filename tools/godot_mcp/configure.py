"""Write machine-local Codex MCP paths, preserving existing project configuration."""
import json
from pathlib import Path
import shutil
import subprocess
import tomllib

root = Path(__file__).resolve().parents[2]
entry = root / "tools/godot_mcp/node_modules/@coding-solo/godot-mcp/build/index.js"
if not entry.is_file():
    raise SystemExit("先运行 npm ci --prefix tools/godot_mcp")

node = shutil.which("node")
godot = shutil.which("godot")
if not node or not godot:
    raise SystemExit("PATH 中需要 Node.js 22+ 和 godot")
if int(subprocess.check_output([node, "--version"], text=True).strip().lstrip("v").split(".")[0]) < 22:
    raise SystemExit("需要 Node.js 22+")
version = subprocess.check_output([godot, "--version"], text=True).strip()
expected = json.loads((root / "godot/engine-lock.json").read_text())["version"]
if version != expected:
    raise SystemExit(f"Godot 版本不匹配：{version}；需要 {expected}")

config = root / ".codex/config.toml"
original = config.read_text() if config.exists() else ""
existing = tomllib.loads(original).get("mcp_servers", {}).get("jiuding_godot")
if existing is not None:
    print(f"保留已有 jiuding_godot 配置：{config}；路径变更请编辑此节后重新验证")
else:
    # JSON quoted strings are valid TOML basic strings, including Windows paths.
    quote = lambda value: json.dumps(str(value), ensure_ascii=False)
    section = f'''
[mcp_servers.jiuding_godot]
command = {quote(node)}
args = [{quote(entry)}]
cwd = {quote(root)}
startup_timeout_sec = 30
tool_timeout_sec = 60
disabled_tools = ["launch_editor", "run_project"]

[mcp_servers.jiuding_godot.env]
GODOT_PATH = {quote(godot)}
'''
    tomllib.loads(original + "\n" + section)
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(original.rstrip() + "\n" + section, encoding="utf-8")
    print(f"已写入项目配置：{config}")
print(f"Godot: {version}")
