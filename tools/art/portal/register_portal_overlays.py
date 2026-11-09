"""Register generated portal relief crops onto the 906x1000 gateway frame.

Inputs are the transparent modular sheet selected from imagegen. Outputs are
world-frame RGBA layers that share gateway.tres coordinates, plus a composite
preview and per-layer QA. The script is deterministic and safe to rerun.
"""
from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFilter
import numpy as np


ROOT = Path(__file__).resolve().parents[3]
RUN_DIR = ROOT / "output/art/TANGGU-PORTAL/2026-11-04-relief-v1"
SOURCE = RUN_DIR / "overlay-source.png"
GATEWAY_SOURCE = ROOT / "godot/assets/world/portal/gateway.png"

# Mirrors portal_blessing_visual.gd so offline previews match runtime modulation.
BEAST_TINTS = {"青龙": (120, 214, 226), "白虎": (238, 247, 242), "朱雀": (200, 45, 36)}
TIER_BASE_TINT = (203, 189, 147)
TIER_TIER_ASSIGNED = {"青龙": 1, "白虎": 2, "朱雀": 3}

# Crops measured against overlay-source.png (1536x1024).
CREST_BOXES = {
    "青龙": (14, 0, 489, 422),
    "白虎": (520, 0, 998, 422),
    "朱雀": (1032, 0, 1515, 422),
}
PILLAR_BOXES = {
    1: ((72, 422, 220, 1000), (260, 422, 397, 1024)),
    2: ((566, 422, 725, 1000), (768, 422, 919, 1000)),
    3: ((1068, 422, 1255, 1000), (1289, 422, 1469, 1000)),
}

# Landmarks measured against gateway.tres / gateway.png crop (906x1000).
GATEWAY_LINTEL = {
    "left_base": (241.0, 431.0),
    "right_base": (604.0, 338.0),
    "left_top": (289.0, 151.0),
    "right_top": (643.0, 62.0),
}
GATEWAY_LEFT_PILLAR_PANEL = (240.0, 424.0, 319.0, 706.0)
GATEWAY_RIGHT_PILLAR_PANEL = (681.0, 246.0, 742.0, 541.0)

# Landmarks measured against each source crop.
CREST_LANDMARKS = {
    "青龙": [(70.0, 400.0), (468.0, 272.0), (74.0, 152.0), (448.0, 52.0)],
    "白虎": [(555.0, 400.0), (976.0, 272.0), (560.0, 151.0), (960.0, 52.0)],
    "朱雀": [(1078.0, 400.0), (1490.0, 272.0), (1080.0, 151.0), (1480.0, 52.0)],
}


def solve_affine(source_points: list[tuple[float, float]], target_points: list[tuple[float, float]]) -> tuple[float, float, float, float, float, float]:
    matrix = np.array([[x, y, 1.0] for x, y in target_points], dtype=float)
    target_x = np.array([point[0] for point in source_points], dtype=float)
    target_y = np.array([point[1] for point in source_points], dtype=float)
    horizontal = np.linalg.lstsq(matrix, target_x, rcond=None)[0]
    vertical = np.linalg.lstsq(matrix, target_y, rcond=None)[0]
    return (
        float(horizontal[0]),
        float(horizontal[1]),
        float(horizontal[2]),
        float(vertical[0]),
        float(vertical[1]),
        float(vertical[2]),
    )


def crop_alpha(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    layer = image.crop(box)
    alpha = np.array(layer.getchannel("A"), dtype=np.uint8)
    alpha[alpha < 6] = 0
    alpha[(alpha >= 6) & (alpha < 90)] = (alpha[(alpha >= 6) & (alpha < 90)].astype(float) * 255 / 90).astype(np.uint8)
    layer.putalpha(Image.fromarray(alpha, mode="L"))
    return layer


def warp_landmarks(
    layer: Image.Image,
    source_points: list[tuple[float, float]],
    target_points: list[tuple[float, float]],
    output_size: tuple[int, int],
) -> tuple[Image.Image, tuple[float, float, float, float, float, float]]:
    transform = solve_affine(source_points, target_points)
    warped = layer.transform(output_size, Image.Transform.AFFINE, transform, resample=Image.Resampling.BICUBIC)
    return warped, transform


def build_beast_layers(sheet: Image.Image) -> tuple[dict[str, Image.Image], dict[str, object]]:
    layers: dict[str, Image.Image] = {}
    metadata: dict[str, object] = {}
    for beast, source_box in CREST_BOXES.items():
        crop = crop_alpha(sheet, source_box)
        origin_x, origin_y = source_box[0], source_box[1]
        local_points = [(x - origin_x, y - origin_y) for x, y in CREST_LANDMARKS[beast]]
        target_points = [
            GATEWAY_LINTEL["left_base"],
            GATEWAY_LINTEL["right_base"],
            GATEWAY_LINTEL["left_top"],
            GATEWAY_LINTEL["right_top"],
        ]
        warped, transform = warp_landmarks(crop, local_points, target_points, (906, 1000))
        # Feather the transformed alpha slightly so edges blend into carved stone.
        warped.putalpha(warped.getchannel("A").filter(ImageFilter.GaussianBlur(0.6)))
        layers[beast] = warped
        metadata[f"beast.{beast}.transform"] = transform
    return layers, metadata


def build_tier_layers(sheet: Image.Image) -> tuple[dict[int, Image.Image], dict[str, object]]:
    layers: dict[int, Image.Image] = {}
    metadata: dict[str, object] = {}
    for tier, boxes in PILLAR_BOXES.items():
        canvas = Image.new("RGBA", (906, 1000), (0, 0, 0, 0))
        for side, source_box in zip(("left", "right"), boxes):
            crop = crop_alpha(sheet, source_box)
            source_alpha = np.array(crop.getchannel("A"), dtype=np.uint8)
            ys, xs = np.where(source_alpha > 12)
            if xs.size == 0:
                continue
            source_box_f = (float(xs.min()), float(ys.min()), float(xs.max() + 1), float(ys.max() + 1))
            target_box = GATEWAY_LEFT_PILLAR_PANEL if side == "left" else GATEWAY_RIGHT_PILLAR_PANEL
            scale_x = (target_box[2] - target_box[0]) / (source_box_f[2] - source_box_f[0])
            scale_y = (target_box[3] - target_box[1]) / (source_box_f[3] - source_box_f[1])
            transform = solve_affine(
                [
                    (source_box_f[0], source_box_f[1]),
                    (source_box_f[2], source_box_f[1]),
                    (source_box_f[0], source_box_f[3]),
                    (source_box_f[2], source_box_f[3]),
                ],
                [
                    (target_box[0], target_box[1]),
                    (target_box[2], target_box[1]),
                    (target_box[0], target_box[3]),
                    (target_box[2], target_box[3]),
                ],
            )
            warped = crop.transform(canvas.size, Image.Transform.AFFINE, transform, resample=Image.Resampling.BICUBIC)
            warped.putalpha(warped.getchannel("A").filter(ImageFilter.GaussianBlur(0.5)))
            canvas.alpha_composite(warped)
            metadata[f"tier.{tier}.{side}.transform"] = transform
        layers[tier] = canvas
    return layers, metadata


def modulate(layer: Image.Image,tint: tuple[float,float,float],alpha: float) -> Image.Image:
    result=layer.copy()
    channels=result.split()
    r,g,b,a=channels
    r=r.point(lambda pixel,value=tint[0]: int(pixel*value/255))
    g=g.point(lambda pixel,value=tint[1]: int(pixel*value/255))
    b=b.point(lambda pixel,value=tint[2]: int(pixel*value/255))
    a=a.point(lambda pixel: int(pixel*alpha))
    result=Image.merge("RGBA",(r,g,b,a))
    return result


def main() -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE).convert("RGBA")
    gateway = Image.open(GATEWAY_SOURCE).convert("RGBA").crop((320, 8, 320 + 906, 8 + 1000))

    beast_layers, beast_metadata = build_beast_layers(sheet)
    tier_layers, tier_metadata = build_tier_layers(sheet)

    for beast, layer in beast_layers.items():
        layer.save(RUN_DIR / f"beast-{beast}.png")
    for tier, layer in tier_layers.items():
        layer.save(RUN_DIR / f"tier-{tier}.png")

    # Composite previews: three choice gates, with tiers matching the journey route.
    for sealed in (True, False):
        row = Image.new("RGBA", (906 * 3 + 80, 1120), (16, 20, 18, 255))
        draw = ImageDraw.Draw(row)
        draw.text((20, 20), "registered gateway overlays", fill=(230, 220, 190, 255))
        for index, beast in enumerate(("青龙", "白虎", "朱雀")):
            composite = gateway.copy()
            composite.alpha_composite(beast_layers[beast])
            beast_tint = BEAST_TINTS[beast]
            tier_tint = tuple(
                round(TIER_BASE_TINT[index] * (1 - 0.55) + beast_tint[index] * 0.55)
                for index in range(3)
            )
            tier_alpha = 0.72 if sealed else 0.96
            composite.alpha_composite(modulate(tier_layers[TIER_TIER_ASSIGNED[beast]], tier_tint, tier_alpha))
            position = (20 + index * 916, 60)
            row.alpha_composite(composite, position)
            draw.text((position[0] + 350, 1080), beast, fill=(220, 210, 180, 255))
        suffix = "sealed" if sealed else "open"
        row.save(RUN_DIR / f"composite-{suffix}.png")

    metadata = {
        "schema": "tanggu.portal.overlay-registration.v1",
        "frame": {"source": "godot/assets/world/portal/gateway.tres", "crop": [320, 8, 906, 1000]},
        "outputs": {
            "beast_layers": {beast: f"beast-{beast}.png" for beast in beast_layers},
            "tier_layers": {str(tier): f"tier-{tier}.png" for tier in tier_layers},
        },
        "transforms": {**beast_metadata, **tier_metadata},
    }
    (RUN_DIR / "registration.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"registered {len(beast_layers)} beast layers and {len(tier_layers)} tier layers into {RUN_DIR}")


if __name__ == "__main__":
    main()
