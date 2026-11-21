"""Build hero runtime atlases from the full-resolution action-redraw-v1 frames and legacy hero layers.

Run from the repository root: python3 tools/art/hero_runtime/build.py
Sources stay untouched; output goes to godot/assets/characters/hero-runtime-v1/.
"""
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from density import PAD, RUNTIME_SCALE, TEXELS_PER_UNIT, map_point, resample  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "godot/assets/characters/action-redraw-v1"
LEGACY = ROOT / "godot/assets/generated"
LEGACY_KEYS = ["upper", "upperDown", "bow", "lower", "skills", "failed"]
SHEET_WIDTH = 2048
# 旧 atlas.json 未携带的像素合同，从已确认的源帧记录补入后再换算。
LEGACY_CONTRACTS = {"upperDown": ROOT / "assets/characters/child/down-archery-v3.frames.json"}
DEST = ROOT / "godot/assets/characters/hero-runtime-v1"


def build_legacy(sources: list) -> None:
    atlas = json.loads((LEGACY / "atlas.json").read_text())
    result = {}
    for key in LEGACY_KEYS:
        data = atlas[key]
        source_path = LEGACY / f"{key}.png"
        image = Image.open(source_path).convert("RGBA")
        packed, entry = [], {k: v for k, v in data.items() if k != "frames"}
        for frame in data["frames"]:
            x, y, w, h = frame["x"], frame["y"], frame["width"], frame["height"]
            frame_scale = float(frame.get("scale", data["scale"]))
            cell, kx, ky = resample(image.crop((x, y, x + w, y + h)), frame_scale)
            origin = map_point([frame["originX"] * w, frame["originY"] * h], kx, ky)
            item = dict(frame)
            item.update({"width": cell.width, "height": cell.height, "originX": origin[0] / cell.width,
                         "originY": origin[1] / cell.height, "scale": round(frame_scale / kx, 6)})
            packed.append((cell, item, kx, ky))
        cursor_x = cursor_y = shelf = 0
        for cell, item, _, _ in packed:
            if cursor_x + cell.width > SHEET_WIDTH:
                cursor_x, cursor_y, shelf = 0, cursor_y + shelf, 0
            item["x"], item["y"] = cursor_x, cursor_y
            cursor_x += cell.width
            shelf = max(shelf, cell.height)
        sheet = Image.new("RGBA", (max(i["x"] + c.width for c, i, _, _ in packed), cursor_y + shelf), (0, 0, 0, 0))
        for cell, item, _, _ in packed:
            sheet.paste(cell, (item["x"], item["y"]))
        contract = json.loads(LEGACY_CONTRACTS[key].read_text()) if key in LEGACY_CONTRACTS else data
        for field in ("waist_px", "muzzle_px"):
            if field in contract:
                entry[field] = map_point(contract[field], packed[0][2], packed[0][3])
        entry["scale"] = packed[0][1]["scale"]
        entry["frames"] = [item for _, item, _, _ in packed]
        entry["runtime_source"] = str(source_path.relative_to(ROOT))
        target = DEST / f"legacy-{key}.png"
        sheet.save(target, optimize=True)
        result[key] = entry
        sources.append({"source": str(source_path.relative_to(ROOT)), "sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
                        "runtime": str(target.relative_to(ROOT))})
    (DEST / "legacy_atlas.json").write_text(json.dumps(result, indent=2) + "\n")


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    clips = json.loads((SOURCE / "clips.json").read_text())
    result, sources = {}, []
    for name, data in clips.items():
        if not name.startswith("hero-"):
            continue
        atlas_path = SOURCE / f"{name}.png"
        atlas = Image.open(atlas_path).convert("RGBA")
        width, height = data["size"]
        columns = int(data["columns"])
        count = (atlas.width // width) * (atlas.height // height)
        if "roots" in data:
            count = len(data["roots"])
        frames, kx, ky = [], 1.0, 1.0
        for index in range(count):
            box = ((index % columns) * width, (index // columns) * height)
            cell = atlas.crop((box[0], box[1], box[0] + width, box[1] + height))
            frame, kx, ky = resample(cell, float(data["scale"]))
            frames.append(frame)
        cell_w, cell_h = frames[0].size
        rows = (count + columns - 1) // columns
        sheet = Image.new("RGBA", (cell_w * min(columns, count), cell_h * rows), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            sheet.paste(frame, ((index % columns) * cell_w, (index // columns) * cell_h))
        target = DEST / f"{name}.png"
        sheet.save(target, optimize=True)
        entry = dict(data)
        entry["size"] = [cell_w, cell_h]
        entry["scale"] = round(float(data["scale"]) / kx, 6)
        if "roots" in data:
            entry["roots"] = [map_point(p, kx, ky) for p in data["roots"]]
        if "root" in data:
            entry["root"] = map_point(data["root"], kx, ky)
        if "muzzle_px" in data:
            entry["muzzle_px"] = map_point(data["muzzle_px"], kx, ky)
        if "head_rects" in data:
            entry["head_rects"] = [[round(r[0] * kx + PAD, 3), round(r[1] * ky + PAD, 3), round(r[2] * kx, 3), round(r[3] * ky, 3)]
                                   for r in data["head_rects"]]
        entry["runtime_source"] = str(atlas_path.relative_to(ROOT))
        result[name] = entry
        sources.append({"source": str(atlas_path.relative_to(ROOT)), "sha256": hashlib.sha256(atlas_path.read_bytes()).hexdigest(),
                        "runtime": str(target.relative_to(ROOT))})
    build_legacy(sources)
    (DEST / "clips.json").write_text(json.dumps(result, indent=2) + "\n")
    (DEST / "provenance.json").write_text(json.dumps({
        "art_source": "existing", "process": "premultiplied Lanczos resample + transparent padding",
        "texels_per_unit": TEXELS_PER_UNIT, "runtime_scale": RUNTIME_SCALE, "padding_px": PAD, "sources": sources,
    }, indent=2) + "\n")
    print(f"Resampled {len(result)} hero clips and {len(LEGACY_KEYS)} legacy hero atlases to {DEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
