"""Measure the waist line for every character clip.

The waist line is the y where the torso meets the legs, expressed in clip
pixels. Semantics differ by clip kind and must not be mixed:

  lower clips (legs only)   the waist is the TOP of the content (the hem of
                             the tunic), not the bottom (which is the foot).
  upper clips (torso only)   the waist is the BOTTOM of the content, where
                             the torso is cut off.

Both are stored as an absolute clip pixel y so the runtime can convert to a
world position with (waist_px - root_y) * scale, whatever the root means.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CLIPS_DIR = ROOT / "godot/assets/characters/action-redraw-v1"
CLIPS = json.loads((CLIPS_DIR / "clips.json").read_text())

# 只画下半身的剪辑：腰带在内容顶端（衣摆）。
LOWER_CLIPS = {"hero-run-lower", "hero-run-lower-v2", "hero-run-lower-down"}
# 上身或全身的剪辑：腰带在内容底端（躯干被裁断处）。
UPPER_CLIPS = {
    "hero-archery-upper", "hero-archery-left", "hero-archery-up",
    "hero-skills-upper", "hero-skills-direction-0", "hero-skills-direction-1",
    "hero-skills-direction-2", "hero-skills-direction-3",
    "hero-back-full", "hero-back-walk", "hero-dodge",
}
# 衣摆厚度：下半身内容顶端往下这么多像素才算真正的腰线。
HEM_INSET = 0.06


def frame_alpha(clip, index):
    data = CLIPS[clip]
    width, height = data["size"]
    columns = data.get("columns", 1)
    image = Image.open(CLIPS_DIR / f"{clip}.png").convert("RGBA")
    left = index % columns * width
    top = index // columns * height
    return np.array(
        image.crop((left, top, left + width, top + height)).getchannel("A"),
        dtype=float,
    )


def measure(clip):
    data = CLIPS[clip]
    count = len(data["roots"]) if "roots" in data else 1
    waists = []
    for index in range(count):
        alpha = frame_alpha(clip, index)
        rows = np.where(alpha.max(axis=1) > 16)[0]
        if len(rows) == 0:
            waists.append(0)
            continue
        top, bottom = int(rows[0]), int(rows[-1])
        if clip in LOWER_CLIPS:
            # 衣摆：内容顶端往下一点，避免取到布料的毛边。
            waists.append(top + max(1, round((bottom - top) * HEM_INSET)))
        else:
            waists.append(bottom)
    return waists


def main():
    report = {}
    for clip in sorted(CLIPS):
        if not clip.startswith("hero"):
            continue
        waists = measure(clip)
        report[clip] = {"waist_px": waists}
        print(f"{clip:24s} waist_px={waists}")
    out = Path(__file__).resolve().parent / "measured_anchors.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"\nWrote {out}")


def measure_legacy():
    """Measure the legacy atlases, whose originY is the foot origin.

    The legacy lower sheet is 7 rows x 4 columns (row = frame, column =
    direction) and the legacy upper sheet is 4 rows x 4 columns (row = attack
    phase, column = facing). The waist comes from each frame's alpha bounds.
    """
    atlas = json.loads((ROOT / "godot/assets/generated/atlas.json").read_text())
    legacy = {}
    for key in ["lower", "upper", "upperDown", "skills"]:
        if key not in atlas:
            continue
        entry = atlas[key]
        scale = entry.get("scale", 1.0)
        image = Image.open(ROOT / f"godot/assets/generated/{key}.png").convert("RGBA")
        waists = []
        for frame in entry["frames"]:
            alpha = np.array(
                image.crop((frame["x"], frame["y"], frame["x"] + frame["width"], frame["y"] + frame["height"])).getchannel("A"),
                dtype=float,
            )
            rows = np.where(alpha.max(axis=1) > 16)[0]
            if len(rows) == 0:
                waists.append(0)
                continue
            top, bottom = int(rows[0]), int(rows[-1])
            # 腰带：下身取衣摆（内容顶端往下一点），上身取躯干被裁断的底端。
            waist = top + max(1, round((bottom - top) * 0.06)) if key == "lower" else bottom
            waists.append(round(waist - frame["originY"] * frame["height"], 2))
        legacy[key] = {"scale": scale, "waistOffset": waists}
        print(f"{key}: scale={scale} waistOffset={waists}")
    out = Path(__file__).resolve().parent / "measured_legacy_anchors.json"
    out.write_text(json.dumps(legacy, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
    measure_legacy()
