"""Validated release export; the editor-owned map is authoritative."""
from pathlib import Path
import subprocess
import sys
import shutil
import zipfile

root = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(root / "tools/migration/check_godot.py")], check=True)
(root / "build/godot/candidate-windows").mkdir(parents=True, exist_ok=True)
for preset in ["macOS Universal", "Windows x64"]:
    result = subprocess.run(["godot", "--headless", "--path", str(root / "godot"), "--export-release", preset], capture_output=True, text=True)
    output = result.stdout + result.stderr
    if result.returncode or "ERROR:" in output:
        sys.stderr.write(output)
        raise SystemExit(result.returncode or 1)
    print(f"Export passed: {preset}")

output = root / "build/godot"
for source, name in [(root / "godot/PLAYTEST.txt", "试玩说明.txt"), (root / "godot/THIRD_PARTY_NOTICES.txt", "THIRD_PARTY_NOTICES.txt")]:
    shutil.copy2(source, output / name)
    shutil.copy2(source, output / "candidate-windows" / name)
with zipfile.ZipFile(output / "NineTripods-godot-macos.zip", "a", zipfile.ZIP_DEFLATED) as archive:
    for name in ["试玩说明.txt", "THIRD_PARTY_NOTICES.txt"]:
        archive.write(output / name, name)
with zipfile.ZipFile(output / "NineTripods-godot-windows.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for name in ["NineTripods.exe", "试玩说明.txt", "THIRD_PARTY_NOTICES.txt"]:
        archive.write(output / "candidate-windows" / name, name)
print("Packaged both candidates with playtest instructions and third-party notices")
