#!/usr/bin/env python3
"""Register and pack authored character poses; never synthesizes anatomy or poses.

Run with the asset-forge Python. Source boxes, semantic roots, waist points and
layer cuts are reviewed annotations in sources/registration.json. Scale is shared
by a source sheet, never inferred from each pose's alpha bounding box.
"""

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageChops

ROOT = Path(__file__).resolve().parents[3]
ASSET = ROOT / "assets/characters/child-shadow-v3"
OUT = ROOT / "godot/assets/characters/child-shadow-v3"
REVIEW = ROOT / "output/art/CHR-001/2026-11-17-multistate-v3/review"
CANVAS = (256, 256)
ANCHOR = (128, 224)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def register(source, annotation):
    image = Image.open(ASSET / source["path"]).convert("RGBA")
    # Generated native-alpha sheets contain invisible alpha=1 background specks.
    # Remove only <= 3/255 coverage; retain every visible authored component.
    image.putalpha(image.getchannel("A").point(lambda value: 0 if value <= 3 else value))
    box = annotation["box"]
    image = image.crop(box)
    scale = source["scale"]
    size = tuple(round(v * scale) for v in image.size)
    # Premultiplied alpha avoids dark fringes around the drawn outline.
    image = image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    origin = annotation["root"]
    offset = tuple(round(ANCHOR[i] - origin[i] * scale) for i in range(2))
    canvas = Image.new("RGBA", CANVAS)
    canvas.alpha_composite(image, offset)

    def point(value):
        return [round(value[i] * scale + offset[i], 3) for i in range(2)]

    waist = point(annotation["waist"])
    points = {key: point(value) for key, value in annotation.get("points", {}).items()}
    points["arrowVisible"] = [int(annotation.get("arrowVisible", False))]
    cuts = [round(y * scale + offset[1]) for y in annotation["cuts"]]
    keep = [[point(p) for p in polygon] for polygon in annotation.get("keepBelowCut", [])]
    exclude_lower = [[point(p) for p in polygon] for polygon in annotation.get("excludeLower", [])]
    return canvas, waist, points, cuts, keep, exclude_lower


def layer_frame(registered, layer):
    original, waist, points, cuts, keep, exclude_lower = registered
    frame = original.copy()
    if layer == "upper":
        mask = Image.new("L", CANVAS)
        draw = ImageDraw.Draw(mask)
        draw.rectangle((0, 0, 255, cuts[1] - 1), fill=255)
        for polygon in keep:
            draw.polygon([tuple(point) for point in polygon], fill=255)
        frame.putalpha(ImageChops.multiply(frame.getchannel("A"), mask))
    elif layer == "lower":
        frame.paste((0, 0, 0, 0), (0, 0, 256, cuts[0]))
        if exclude_lower:
            alpha = frame.getchannel("A")
            draw = ImageDraw.Draw(alpha)
            for polygon in exclude_lower:
                draw.polygon([tuple(point) for point in polygon], fill=0)
            frame.putalpha(alpha)
    return frame, waist, points


def main():
    manifest = json.loads((ASSET / "sources/registration.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    registered = {}
    for frame_id, annotation in manifest["frames"].items():
        registered[frame_id] = register(manifest["sources"][annotation["source"]], annotation)
    metadata, qa = {}, []
    for name, spec in manifest["clips"].items():
        rows = spec["rows"]
        columns = len(rows[0])
        assert len(rows) == 4 and all(len(row) == columns for row in rows), name
        frames = [layer_frame(registered[frame_id], spec["layer"])
                  for row in rows for frame_id in row]
        boxes = [frame.getbbox() for frame, _, _ in frames]
        assert all(boxes), f"Empty source in {name}"
        crop = [max(0, min(b[0] for b in boxes) - 4),
                max(0, min(b[1] for b in boxes) - 4),
                min(256, max(b[2] for b in boxes) + 4),
                min(256, max(b[3] for b in boxes) + 4)]
        width, height = crop[2] - crop[0], crop[3] - crop[1]
        atlas = Image.new("RGBA", (width * columns, height * 4))
        info = {"size": [width, height], "columns": columns,
                "perDirection": columns, "root": [ANCHOR[0] - crop[0], ANCHOR[1] - crop[1]],
                "scale": 0.75, "waistPoints": [], "waistLine": [],
                "attachments": {key: [] for key in ("head", "body", "back", "hand")},
                "sourceFrames": [item for row in rows for item in row],
                "artSource": "host_image_authored_poses"}
        if spec["layer"] == "lower":
            info["movementRows"] = 1
        semantic = {key: [] for key in ("bowTips", "drawHand", "arrowTip", "arrowVisible")}
        for index, (frame, waist, points) in enumerate(frames):
            local = lambda p: [round(p[0] - crop[0], 3), round(p[1] - crop[1], 3)]
            atlas.alpha_composite(frame.crop(crop), ((index % columns) * width, (index // columns) * height))
            info["waistPoints"].append(local(waist))
            info["waistLine"].append(round(waist[1] - crop[1], 3))
            for key in info["attachments"]:
                assert key in points, f"Missing {key}: {name}/{index}"
                info["attachments"][key].append(local(points[key]))
            if "bowTop" in points:
                semantic["bowTips"].append([local(points["bowTop"]), local(points["bowBottom"])])
                semantic["drawHand"].append(local(points["drawHand"]))
                semantic["arrowTip"].append(local(points["arrowTip"]))
                semantic["arrowVisible"].append(bool(points.get("arrowVisible", [1])[0]))
            b = frame.getbbox()
            qa.append({"clip": name, "frame": index, "source": info["sourceFrames"][index],
                       "bbox": b, "edge": min(b[:2]) <= 0 or max(b[2:]) >= 256,
                       "sha256": hashlib.sha256(frame.tobytes()).hexdigest()})
        if semantic["bowTips"]:
            info["semantics"] = semantic
        if "gripFrames" in spec:
            info["grips"], info["arrowLengths"] = [], []
            info["projectileAnnotation"] = []
            for direction, frame_id in enumerate(spec["gripFrames"]):
                _, waist, points, _, _, _ = registered[frame_id]
                idle = manifest["clips"]["shadow-idle-lower"]["rows"][direction][0]
                standing_waist = registered[idle][1]
                tip = points.get("projectileEmission", points["arrowTip"])
                tail = points["drawHand"]
                info["grips"].append({"x": (tip[0] - waist[0] + standing_waist[0] - ANCHOR[0]) * .5,
                                      "y": (tip[1] - waist[1] + standing_waist[1] - ANCHOR[1]) * .5})
                info["arrowLengths"].append(round(sum((tip[i] - tail[i]) ** 2 for i in range(2)) ** .5 * .5, 3))
                info["projectileAnnotation"].append(manifest["frames"][frame_id].get("projectileAnnotation", "visible-arrow-tip"))
        for key in ("reusesAuthoredClip", "knownLimitation", "gripBasis"):
            if key in spec:
                info[key] = spec[key]
        atlas.save(OUT / f"{name}.png")
        metadata[name] = info
        # Four rows of actual artwork at 2x final world size, clearly labeled.
        plate = Image.new("RGB", (160 * columns, 168 * 4), "#d2cdbb")
        draw = ImageDraw.Draw(plate)
        for i, (frame, _, _) in enumerate(frames):
            small = frame.resize((160, 160), Image.Resampling.LANCZOS)
            x, y = (i % columns) * 160, (i // columns) * 168
            plate.paste(small, (x, y), small)
            draw.text((x + 3, y + 153), info["sourceFrames"][i], fill="#33352e")
        plate.save(REVIEW / f"{name}.png")
    (OUT / "clips.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    report = {"frames": len(qa), "edgeFailures": sum(item["edge"] for item in qa),
              "uniqueDrawnSourceFrames": len(manifest["frames"]), "samples": qa,
              "sources": {key: {"path": value["path"], "sha256": digest(ASSET / value["path"])}
                          for key, value in manifest["sources"].items()}}
    (REVIEW.parent / "asset-qa.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key not in ("samples", "sources")}))
    assert not report["edgeFailures"], "Artwork touches the production canvas edge"


if __name__ == "__main__":
    main()
