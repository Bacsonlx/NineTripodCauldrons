"""Verify the installed Sprite Forge revision and local image-processing tools."""

import hashlib
from importlib.metadata import version
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    here = Path(__file__).resolve().parent
    lock = json.loads((here / "skills.lock.json").read_text())
    skills_root = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "skills"
    for name, expected in lock["skills"].items():
        directory = skills_root / name
        rows = [
            [path.relative_to(directory).as_posix(), hashlib.sha256(path.read_bytes()).hexdigest()]
            for path in sorted(directory.rglob("*"))
            if path.is_file() and "__pycache__" not in path.parts and path.suffix not in (".pyc", ".pyo")
        ]
        digest = hashlib.sha256(json.dumps(rows, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()
        if len(rows) != expected["files"] or digest != expected["sha256"]:
            raise ValueError(f"{name}: missing or different from locked revision {lock['ref']}")
    for requirement in (here / "requirements.txt").read_text().splitlines():
        name, expected = requirement.split("==")
        if version(name) != expected:
            raise ValueError(f"Dependency mismatch: {requirement}")
    for script in ("assemble_frames.py", "build_animation_clips.py", "export_engine.py"):
        subprocess.run(
            [sys.executable, str(skills_root / "generate2dsprite/scripts" / script), "--help"],
            check=True, stdout=subprocess.DEVNULL, timeout=30,
        )
    print(f"PASS: 3 skills match {lock['ref']}; dependencies and image-processing commands ready")


if __name__ == "__main__":
    main()
