"""Write measured waist lines into the runtime clips manifest.

Waist lines differ per clip kind: lower-body clips are cut at the tunic hem
(near the top of their content) while upper-body clips are cut at the torso
bottom. Both are stored as an absolute clip pixel y so the runtime can
convert them to a world position without mixing root semantics.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CLIPS_PATH = ROOT / "godot/assets/characters/action-redraw-v1/clips.json"
MEASURED = ROOT / "tools/art/action_redraw/measured_anchors.json"


def main():
    clips = json.loads(CLIPS_PATH.read_text())
    measured = json.loads(MEASURED.read_text())
    updated = []
    for name, data in measured.items():
        if name not in clips:
            continue
        entry = clips[name]
        entry["waistLine"] = data["waist_px"]
        entry.pop("waist_y", None)
        entry["anchor_kind"] = "waist line measured from alpha bounds"
        updated.append(name)
    CLIPS_PATH.write_text(json.dumps(clips, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated waist lines for {len(updated)} clips: {updated}")


if __name__ == "__main__":
    main()
