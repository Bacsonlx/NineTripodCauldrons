"""Resample hero frames to one runtime texel density with mipmap-safe padding.

Source atlases are drawn at 250-700px per body while the hero is ~40-70 screen px
at 720p. Each frame is resized once (premultiplied Lanczos) so every hero layer
shares the same texels per world unit, then padded so mipmaps never mix frames.
Pixel-space metadata (roots, origins, muzzles, head boxes) is remapped; world-space
data (grips, rule geometry) and the displayed world size stay unchanged.
"""
import numpy as np
from PIL import Image

DISPLAY_SCALE = 2.0 / 3.0  # training_scene.gd ACTOR_VISUAL_SCALE
TEXELS_PER_UNIT = 2.0  # runtime texels per displayed world unit; base level ~1:1 at 1440p, mipmaps below
RUNTIME_SCALE = 1.0 / (TEXELS_PER_UNIT * DISPLAY_SCALE)
PAD = 8


def resample(cell: Image.Image, source_scale: float) -> tuple[Image.Image, float, float]:
    """Return the padded frame plus the actual x/y texel ratios."""
    factor = source_scale / RUNTIME_SCALE
    width, height = cell.size
    new_width, new_height = max(1, round(width * factor)), max(1, round(height * factor))
    rgba = np.asarray(cell.convert("RGBA")).astype(np.float64) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    channels = [Image.fromarray(rgba[..., i].astype(np.float32), "F").resize((new_width, new_height), Image.LANCZOS)
                for i in range(4)]
    out = np.clip(np.stack([np.asarray(c) for c in channels], axis=-1), 0.0, 1.0)
    alpha = out[..., 3:4]
    out[..., :3] = np.where(alpha > 1e-6, out[..., :3] / np.maximum(alpha, 1e-6), 0.0)
    out[..., 3:4] = np.where(alpha < 1.0 / 255.0, 0.0, alpha)
    frame = Image.fromarray(np.round(np.clip(out, 0.0, 1.0) * 255.0).astype(np.uint8), "RGBA")
    padded = Image.new("RGBA", (new_width + 2 * PAD, new_height + 2 * PAD), (0, 0, 0, 0))
    padded.paste(frame, (PAD, PAD))
    return padded, new_width / width, new_height / height


def map_point(point, kx: float, ky: float) -> list[float]:
    return [round(point[0] * kx + PAD, 3), round(point[1] * ky + PAD, 3)]
