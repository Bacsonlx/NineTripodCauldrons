"""Render mirrored run frames to check the hero does not deform when flipped.

Negative x scale mirrors the sprite around its offset origin. This renders the
right-facing run cycle and its mirror side by side so the flip can be reviewed
without launching the game.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
CLIPS_DIR = ROOT / "godot/assets/characters/action-redraw-v1"
OUT = ROOT / "output/characters-vfx-20261109/run-mirror-review"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    clips = json.loads((CLIPS_DIR / "clips.json").read_text())
    clip = "hero-run-lower"
    data = clips[clip]
    width, height = data["size"]
    columns = data.get("columns", 1)
    scale = data["scale"]
    image = Image.open(CLIPS_DIR / f"{clip}.png").convert("RGBA")

    canvas = Image.new("RGBA", (width * 4, height * 2), "#ddd7ca")
    draw = ImageDraw.Draw(canvas)
    for index in range(8):
        left, top = index % columns * width, index // columns * height
        frame = image.crop((left, top, left + width, top + height))
        root = data["roots"][index]
        rendered = frame.resize(
            (round(width * scale * 3), round(height * scale * 3)),
            Image.Resampling.LANCZOS,
        )
        # 原图放在上排，镜像放在下排，锚点对齐以便逐帧比较。
        canvas.alpha_composite(rendered, (index % 4 * width, index // 4 * height))
        mirrored = rendered.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        canvas.alpha_composite(
            mirrored,
            (index % 4 * width + round(root[0] * scale * 3) * 0, height + index // 4 * height),
        )
        draw.text((index % 4 * width + 8, index // 4 * height + 8), f"f{index}", fill="black")
    out = OUT / "run-mirror-pair.png"
    canvas.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    main()
