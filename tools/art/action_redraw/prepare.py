"""Copy existing prototype atlases unchanged; retain their ownership-slice geometry."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "output/art/action-redraw/2026-10-26-prototype-v1/frames"
DEST = ROOT / "godot/assets/characters/action-redraw-v1"
# Semantic ground roots in the original 444px cells, not each alpha bbox bottom.
# Scale is fixed within each clip; neutral poses normalize differing drawing sizes.
CLIPS = {
    "hero-dodge": ([220, 425], 0.22),
    "thor-walk": ([270, 425], 0.45),
    "thor-swing-v2": ([255, 385], 0.59),
    "thor-throw": ([255, 440], 0.52),
    "thor-lightning": ([255, 440], 0.50),
}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    clips, sources = {}, []
    for name, (root, scale) in CLIPS.items():
        bundle = SOURCE / name
        data = json.loads((bundle / "animation.json").read_text())
        atlas = bundle / "atlas.png"
        target = DEST / f"{name}.png"
        shutil.copyfile(atlas, target)
        padding = data["slicing"]["padding"]
        clips[name] = {
            "size": data["frame_size"], "columns": data["atlas"]["cols"],
            "root": [root[0] + padding[0], root[1] + padding[1]], "scale": scale,
        }
        sources.append({
            "source": str(atlas.relative_to(ROOT)), "runtime": str(target.relative_to(ROOT)),
            "sha256": hashlib.sha256(atlas.read_bytes()).hexdigest(),
        })
    layered = ROOT / "assets/characters/action-redraw-v1/layered-v2"
    for name, data in json.loads((layered / "clips.json").read_text()).items():
        atlas = layered / f"{name}.png"
        target = DEST / f"{name}.png"
        shutil.copyfile(atlas, target)
        clips[name] = data
        sources.append({"source": str(atlas.relative_to(ROOT)), "runtime": str(target.relative_to(ROOT)),
                        "sha256": hashlib.sha256(atlas.read_bytes()).hexdigest()})
    # 本工具上一版生成的整身图已由独立上下身替代；原型源图仍保留。
    for name in ["hero-run", "hero-archery", "hero-skills"]:
        for suffix in [".png", ".png.import"]:
            (DEST / f"{name}{suffix}").unlink(missing_ok=True)
    (DEST / "clips.json").write_text(json.dumps(clips, indent=2) + "\n")
    record = ROOT / "assets/characters/action-redraw-v1/provenance.json"
    record.write_text(json.dumps({"art_source": "existing", "sources": sources}, indent=2) + "\n")
    print(f"Copied {len(sources)} unmodified atlases to {DEST}")


if __name__ == "__main__":
    main()
