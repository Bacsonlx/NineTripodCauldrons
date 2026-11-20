"""Cut item art into character gear pieces.

Each item illustration is a large white-background sheet. This crops to the
alpha bounds, mirrors the asymmetric pieces (a shoe, a horn) into left/right
variants, and scales each piece to the size it should occupy on the character
in world pixels.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "godot/assets/items/first-level-v1"
DEST = ROOT / "godot/assets/characters/gear-v1"

# 角色世界高度约 60-90px；挂件按其在角色身上的实际占位换算成源图像素。
# scale 取该挂件所在 clip 的缩放，世界尺寸 = 源图像素 * scale。
PIECES = [
    {"name": "training-bow-hand", "source": "training-bow.png", "world_h": 42.0, "scale": 0.20,
     "mirror": False, "parts": ["single"]},
    # 布履原图是一整双鞋，整体挂在脚位即可，不需要左右镜像。
    {"name": "cloth-shoes-foot", "source": "cloth-shoes.png", "world_h": 16.0, "scale": 0.11,
     "mirror": False, "parts": ["single"]},
    # 羊角原图是单个带环挂饰，可挂在头侧，不需要左右两份。
    {"name": "ram-horn-head", "source": "ram-horn.png", "world_h": 18.0, "scale": 0.11,
     "mirror": False, "parts": ["single"]},
    {"name": "tiger-fang-body", "source": "tiger-fang.png", "world_h": 12.0, "scale": 0.11,
     "mirror": False, "parts": ["single"]},
    {"name": "flint-fire-hand", "source": "flint-fire.png", "world_h": 11.0, "scale": 0.11,
     "mirror": False, "parts": ["single"]},
    {"name": "rat-whisker-back", "source": "rat-whisker.png", "world_h": 14.0, "scale": 0.11,
     "mirror": False, "parts": ["single"]},
]


def crop_content(image):
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
    if bounds is None:
        raise ValueError("贴图没有可见像素")
    return image.crop(bounds)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    report = []
    for piece in PIECES:
        source = Image.open(SOURCE / piece["source"]).convert("RGBA")
        content = crop_content(source)
        target_px = piece["world_h"] / piece["scale"]
        ratio = target_px / content.height
        width = max(1, round(content.width * ratio))
        height = max(1, round(content.height * ratio))
        resized = content.resize((width, height), Image.Resampling.LANCZOS)
        for part in piece["parts"]:
            variant = resized
            if piece["mirror"] and part == "r":
                variant = resized.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            suffix = "" if part == "single" else "-" + part
            path = DEST / f"{piece['name']}{suffix}.png"
            variant.save(path)
            report.append({
                "file": path.name,
                "source": piece["source"],
                "source_content": [content.width, content.height],
                "output": [variant.width, variant.height],
                "world_h": round(variant.height * piece["scale"], 2),
                "world_w": round(variant.width * piece["scale"], 2),
                "mirrored": piece["mirror"] and part == "r",
            })
            print(f"{path.name}: {variant.width}x{variant.height}px -> world {variant.width * piece['scale']:.1f}x{variant.height * piece['scale']:.1f}")
    (DEST / "gear_manifest.json").write_text(
        json.dumps({"pieces": report}, indent=2, ensure_ascii=False) + "\n"
    )
    print(f"\nWrote {len(report)} gear files to {DEST}")


if __name__ == "__main__":
    main()
