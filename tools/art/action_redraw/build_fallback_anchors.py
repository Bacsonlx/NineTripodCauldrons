"""Build a fallback gear anchor table from measured clip geometry.

Slots are placed from measured alpha bounds: the head sits at the top of the
content box, the waist at the bottom of the torso, hands at the horizontal
extremes. This keeps the gear rig functional before hand-measured anchors
arrive, and marks every entry as approximate so it can be replaced.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CLIPS_DIR = ROOT / "godot/assets/characters/action-redraw-v1"
OUT = CLIPS_DIR / "gear_anchors.json"

# 头部中心相对内容框顶部的比例；手部取内容框左右极值；腰部取内容框底部。
SLOT_RULES = {
    "head": {"from": "top", "x": 0.5, "y": 0.18},
    "chest": {"from": "top", "x": 0.5, "y": 0.42},
    "back": {"from": "top", "x": 0.5, "y": 0.30},
    "waist": {"from": "bottom", "x": 0.5, "y": 0.0},
    "hand": {"from": "right", "x": 0.0, "y": 0.55},
    "foot_l": {"from": "bottom", "x": 0.35, "y": 0.0},
    "foot_r": {"from": "bottom", "x": 0.65, "y": 0.0},
}
# 槽位别名：表现层用到的名字映射到测量规则。
ALIASES = {
    "body": "chest",
    "hand": "hand",
    "head": "head",
    "feet": "foot_r",
    "weapon": "hand",
    "back": "back",
}
UPPER_CLIPS = [
    "hero-archery-upper",
    "hero-archery-left",
    "hero-archery-up",
    "hero-skills-direction-0",
    "hero-skills-direction-1",
    "hero-skills-direction-2",
    "hero-skills-direction-3",
    "hero-skills-upper",
    "hero-back-full",
    "hero-back-walk",
    "hero-dodge",
]
LOWER_CLIPS = ["hero-run-lower"]


def measure(clip: str, frames: int):
    import numpy as np
    from PIL import Image

    data = json.loads((CLIPS_DIR / "clips.json").read_text())[clip]
    width, height = data["size"]
    columns = data.get("columns", 1)
    image = Image.open(CLIPS_DIR / f"{clip}.png").convert("RGBA")
    boxes = []
    for index in range(frames):
        left, top = index % columns * width, index // columns * height
        alpha = np.array(
            image.crop((left, top, left + width, top + height)).getchannel("A"),
            dtype=float,
        )
        rows = np.where(alpha.max(axis=1) > 16)[0]
        cols = np.where(alpha.max(axis=0) > 16)[0]
        if len(rows) == 0 or len(cols) == 0:
            boxes.append(None)
            continue
        boxes.append((int(cols[0]), int(rows[0]), int(cols[-1]), int(rows[-1])))
    return data, boxes


def anchor(box, rule):
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    source = rule["from"]
    if source == "top":
        x = left + width * rule["x"]
        y = top + height * rule["y"]
    elif source == "bottom":
        x = left + width * rule["x"]
        y = bottom - height * rule["y"]
    else:
        x = right - width * rule["x"]
        y = top + height * rule["y"]
    return [round(x), round(y)]


def main():
    table = {}
    for clip in UPPER_CLIPS + LOWER_CLIPS:
        data = json.loads((CLIPS_DIR / "clips.json").read_text())[clip]
        frames = len(data["roots"]) if "roots" in data else 1
        _, boxes = measure(clip, frames)
        entry = {}
        for slot, rule_name in ALIASES.items():
            rule = SLOT_RULES[rule_name]
            points = []
            for box in boxes:
                if box is None:
                    continue
                points.append(anchor(box, rule))
            if points:
                entry[slot] = points
        if entry:
            table[clip] = entry
    OUT.write_text(json.dumps(table, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {OUT} with {len(table)} clips")
    for clip, entry in table.items():
        print(f"  {clip}: {sorted(entry.keys())}")


if __name__ == "__main__":
    main()
