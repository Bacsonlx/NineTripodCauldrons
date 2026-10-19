"""Prepare the existing sprite atlases used by the approved-scope Godot sample."""

import hashlib
import json
import math
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[2]
output = root / "godot/assets/generated"
output.mkdir(parents=True, exist_ok=True)
old = json.loads((root / "assets/mvp/child-refined-v3.frames.json").read_text())
atlases = json.loads((root / "assets/mvp02/atlases.json").read_text())
sample = json.loads((root / "assets/mvp03/frames.json").read_text())
definitions = {
    "upper": ("assets/mvp/child-upper-refined-v3.png", old["upper"], 0.20),
    "bow": ("assets/mvp/bow-states-v3.png", old["bow"], 0.04),
    "lower": ("assets/mvp02/child-lower-unified-v2.png", atlases["lower"]["frames"], 0.20),
    "enemy": ("assets/mvp02/shadow-puppet-v2.png", atlases["enemy"]["frames"], atlases["enemy"]["scale"]),
    "skills": ("assets/mvp02/child-skills-upper-v1.png", atlases["skills"]["frames"], 0.20),
    "failed": ("assets/mvp02/child-failed-v1.png", atlases["failed"]["frames"], atlases["failed"]["scale"]),
    "props": ("assets/mvp03/junction-props-v1.png", sample["props"], 0.30),
}


def write(path, content):
    if not path.exists() or path.read_bytes() != content:
        path.write_bytes(content)


result = {}
for key, (source, frames, scale) in definitions.items():
    if not frames or not math.isfinite(scale) or scale <= 0:
        raise ValueError(f"Missing frames or invalid scale: {key}")
    content = (root / source).read_bytes()
    if content[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Invalid PNG: {source}")
    width, height = struct.unpack(">II", content[16:24])
    names = set()
    for frame in frames:
        if frame["name"] in names:
            raise ValueError(f"Duplicate frame: {key}/{frame['name']}")
        names.add(frame["name"])
        frame_scale = frame.get("scale", scale)
        if not math.isfinite(frame_scale) or frame_scale <= 0:
            raise ValueError(f"Invalid frame scale: {key}/{frame['name']}")
        if not all(math.isfinite(frame[x]) for x in ("x", "y", "width", "height", "originX", "originY")):
            raise ValueError(f"Non-finite frame: {key}")
        if frame["x"] < 0 or frame["y"] < 0 or frame["width"] <= 0 or frame["height"] <= 0 or frame["x"] + frame["width"] > width or frame["y"] + frame["height"] > height:
            raise ValueError(f"Frame outside atlas: {key}/{frame['name']}")
    write(output / f"{key}.png", content)
    result[key] = {"frames": frames, "scale": scale, "source": source, "sha256": hashlib.sha256(content).hexdigest()}

for key, source in {"arrow": "assets/mvp/arrow-refined-v2.png", "ground": "assets/mvp03/junction-ground-v1.png"}.items():
    content = (root / source).read_bytes()
    write(output / f"{key}.png", content)
    result[key] = {"source": source, "sha256": hashlib.sha256(content).hexdigest()}
write(output / "atlas.json", (json.dumps(result, ensure_ascii=False, indent=2) + "\n").encode())
print(f"Prepared {len(result)} existing atlases/images for the Godot sample")
