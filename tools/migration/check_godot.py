"""Verify the locked engine, import, public tests and full scene; fail on script errors."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
lock = json.loads((root / "godot/engine-lock.json").read_text())
version = subprocess.check_output(["godot", "--version"], text=True).strip()
if version != lock["version"]:
    raise SystemExit(f"Godot version mismatch: {version}; expected {lock['version']}")
commands = [["--editor", "--import"], ["--script", "res://tests/run_tests.gd"], ["--quit-after", "3"]]
for args in commands:
    result = subprocess.run(["godot", "--headless", "--path", str(root / "godot"), *args], capture_output=True, text=True)
    output = result.stdout + result.stderr
    if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
        sys.stderr.write(output)
        raise SystemExit(result.returncode or 1)
    if "run_tests" in " ".join(args):
        print(output.strip())
print("Godot engine/import/public tests/full scene: passed")
