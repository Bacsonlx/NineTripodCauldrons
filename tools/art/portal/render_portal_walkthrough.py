"""
Render actual portal scenes and blessing visual layers offline;
Performs walk-through for:
1. Beast recognition (青龙青 / 白虎白 / 朱雀赤 + night environment tuning)
2. Tier distinction (初念 / 再念 / 三念 density)
3. State legibility (封印中 vs 可通行 vs 悬停可交互)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "output/art/TANGGU-PORTAL/2026-11-03-theme-graybox"
OUT.mkdir(parents=True, exist_ok=True)

# Colors exactly matching portal_blessing_visual.gd
BEAST_COLORS = {
    "青龙": (120, 214, 226),  # #78d6e2
    "白虎": (238, 247, 242),  # #eef7f2
    "朱雀": (200, 45, 36),    # #c82d24
}
NIGHT_STONE = (37, 51, 45)     # #25332d

def blend_night(rgb, factor=0.18):
    return tuple(round(c * (1.0 - factor) + n * factor) for c, n in zip(rgb, NIGHT_STONE))

TUNED_BEAST_COLORS = {k: blend_night(v, 0.18) for k, v in BEAST_COLORS.items()}

# Load source images
gateway_img = Image.open(ROOT / "godot/assets/world/portal/gateway.png").convert("RGBA").crop((320, 8, 320 + 906, 8 + 1000))
seal_img = Image.open(ROOT / "godot/assets/generated/exploration.png").convert("RGBA").crop((663, 738, 663 + 564, 738 + 432))
vortex_img = Image.open(ROOT / "godot/assets/world/portal/vortex.png").convert("RGBA")

font_title = ImageFont.truetype(str(ROOT / "godot/assets/fonts/NineTripodsHudSong.ttf"), 18)
font_sub = ImageFont.truetype(str(ROOT / "godot/assets/fonts/NineTripodsHudSong.ttf"), 14)
font_header = ImageFont.truetype(str(ROOT / "godot/assets/fonts/NineTripodsHudSong.ttf"), 22)

def apply_tint(im, tint_rgb, alpha=1.0):
    r, g, b, a = im.split()
    tr, tg, tb = tint_rgb
    r = r.point(lambda v: round(v * tr / 255.0))
    g = g.point(lambda v: round(v * tg / 255.0))
    b = b.point(lambda v: round(v * tb / 255.0))
    if alpha != 1.0:
        a = a.point(lambda v: round(v * alpha))
    return Image.merge("RGBA", (r, g, b, a))

def render_single_portal(beast: str, tier: int, sealed: bool, hovered: bool = False, usable: bool = False, scale: float = 1.2):
    # Canvas coordinates: width 380, height 480
    cw = int(360 * scale)
    ch = int(460 * scale)
    canvas = Image.new("RGBA", (cw, ch), (22, 28, 24, 255))
    draw = ImageDraw.Draw(canvas)

    # Origin (center of the portal floor)
    ox = cw // 2 - int(20 * scale)
    oy = ch - int(70 * scale)

    # 1. Background ground grid & mossy ground patch
    for gx in range(0, cw, int(30 * scale)):
        draw.line([(gx, 0), (gx, ch)], fill=(28, 35, 30, 255), width=1)
    for gy in range(0, ch, int(30 * scale)):
        draw.line([(0, gy), (cw, gy)], fill=(28, 35, 30, 255), width=1)
    draw.ellipse([ox - int(120 * scale), oy - int(35 * scale), ox + int(140 * scale), oy + int(25 * scale)], fill=(16, 22, 18, 200))

    # 2. Passage swirl if open
    if not sealed:
        vx = ox + int(100 * scale)
        vy = oy - int(25 * scale)
        v_w = int(1254 * 0.16 * scale)
        v_h = int(1254 * 0.16 * 0.42 * scale)
        v_resized = vortex_img.resize((v_w, v_h), Image.Resampling.BICUBIC)
        v_tinted = apply_tint(v_resized, (210, 245, 216), 0.76)
        canvas.alpha_composite(v_tinted, (vx - v_w // 2, vy - v_h // 2))

    # 3. Gateway frame
    gw_w = int(220 * scale)
    gw_h = int(220 * (1000 / 906) * scale)
    gw_resized = gateway_img.resize((gw_w, gw_h), Image.Resampling.BICUBIC)
    gw_tinted = apply_tint(gw_resized, (round(255 * 0.88), round(255 * 0.9), round(255 * 0.8)), 1.0)
    canvas.alpha_composite(gw_tinted, (ox - gw_w // 2, oy - gw_h))

    # 4. Seal prop if sealed
    if sealed:
        seal_w = int(125 * scale)
        seal_h = int(125 * (432 / 564) * scale)
        seal_resized = seal_img.resize((seal_w, seal_h), Image.Resampling.BICUBIC)
        seal_tinted = apply_tint(seal_resized, (round(255 * 0.88), round(255 * 0.9), round(255 * 0.8)), 0.95)
        canvas.alpha_composite(seal_tinted, (ox - seal_w // 2, oy - int(25 * scale) - seal_h))

    # Vector overlay calculations
    base_col = TUNED_BEAST_COLORS.get(beast, (212, 200, 165))
    alpha_val = (0.42 if sealed else 0.70) + (0.16 if hovered else 0.0) + (0.08 if usable else 0.0)
    tone = tuple(list(base_col) + [round(255 * min(1.0, alpha_val))])
    outline = (16, 24, 18, round(255 * min(1.0, alpha_val * 0.88)))

    def to_scr(lx, ly):
        return (ox + int(lx * scale), oy + int(ly * scale))

    # 5. Blessing Pattern (Beast)
    overlay_layer = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay_layer)

    if beast == "青龙":
        pts = [
            (-48, -165), (-30, -185), (-3, -193), (25, -184),
            (41, -164), (28, -145), (4, -139), (-16, -148),
            (-28, -164), (-15, -176), (4, -171)
        ]
        s_pts = [to_scr(x, y) for x, y in pts]
        odraw.line(s_pts, fill=outline, width=max(1, round(7 * scale)), joint="curve")
        odraw.line(s_pts, fill=tone, width=max(1, round(3.2 * scale)), joint="curve")
        head = [to_scr(x, y) for x, y in [(25, -184), (48, -190), (39, -174)]]
        odraw.polygon(head, fill=outline)
        head_inner = [to_scr(x, y) for x, y in [(27, -184), (44, -188), (38, -177)]]
        odraw.polygon(head_inner, fill=tone)
        w1, w2 = to_scr(-48, -165), to_scr(-59, -177)
        odraw.line([w1, w2], fill=outline, width=max(1, round(6 * scale)))
        odraw.line([w1, w2], fill=tone, width=max(1, round(2.4 * scale)))

    elif beast == "白虎":
        head = [to_scr(x, y) for x, y in [(-17, -194), (17, -194), (25, -167), (0, -146), (-25, -167)]]
        odraw.polygon(head, fill=outline)
        head_inner = [to_scr(x, y) for x, y in [(-14, -190), (14, -190), (19, -168), (0, -151), (-19, -168)]]
        odraw.polygon(head_inner, fill=tone)
        for bx in [-14.0, 0.0, 14.0]:
            p1 = to_scr(bx - 4.0, -188)
            p2 = to_scr(bx + 3.0, -174)
            odraw.line([p1, p2], fill=outline, width=max(1, round(5 * scale)))
            odraw.line([p1, p2], fill=tone, width=max(1, round(2 * scale)))
        for side in [-1.0, 1.0]:
            st = [to_scr(side * 24, -183), to_scr(side * 42, -170), to_scr(side * 25, -158)]
            odraw.line(st, fill=outline, width=max(1, round(6 * scale)), joint="curve")
            odraw.line(st, fill=tone, width=max(1, round(2.4 * scale)), joint="curve")

    elif beast == "朱雀":
        body = [to_scr(x, y) for x, y in [(0, -199), (13, -177), (8, -151), (0, -140), (-8, -151), (-13, -177)]]
        odraw.polygon(body, fill=outline)
        body_inner = [to_scr(x, y) for x, y in [(0, -194), (8, -176), (5, -153), (0, -146), (-5, -153), (-8, -176)]]
        odraw.polygon(body_inner, fill=tone)
        for side in [-1.0, 1.0]:
            wg = [to_scr(side * 8, -181), to_scr(side * 36, -197), to_scr(side * 54, -176), to_scr(side * 31, -181), to_scr(side * 18, -160)]
            odraw.line(wg, fill=outline, width=max(1, round(8 * scale)), joint="curve")
            odraw.line(wg, fill=tone, width=max(1, round(3.0 * scale)), joint="curve")
        cr = [to_scr(-5, -194), to_scr(-18, -211), to_scr(0, -202), to_scr(18, -211), to_scr(5, -194)]
        odraw.line(cr, fill=outline, width=max(1, round(6 * scale)), joint="curve")
        odraw.line(cr, fill=tone, width=max(1, round(2.3 * scale)), joint="curve")

    # 6. Tier Overlay (Density notches & Arch)
    for idx in range(tier):
        ny = -118.0 + float(idx) * 18.0
        for side in [-1.0, 1.0]:
            cx, cy = to_scr(side * 61.0, ny)
            d_out = [(cx, cy - round(5 * scale)), (cx + round(5 * scale), cy), (cx, cy + round(5 * scale)), (cx - round(5 * scale), cy)]
            odraw.polygon(d_out, fill=outline)
            d_in = [(cx, cy - round(3 * scale)), (cx + round(3 * scale), cy), (cx, cy + round(3 * scale)), (cx - round(3 * scale), cy)]
            odraw.polygon(d_in, fill=tone)

    # Ring arch
    rr = (24.0 + float(tier) * 5.0) * scale
    acx, acy = to_scr(0, -170)
    bbox = [acx - rr, acy - rr, acx + rr, acy + rr]
    odraw.arc(bbox, start=219, end=321, fill=outline, width=max(1, round(5 * scale)))
    odraw.arc(bbox, start=219, end=321, fill=tone, width=max(1, round(2 * scale)))

    if sealed:
        sl1, sl2 = to_scr(-31, -171), to_scr(31, -171)
        odraw.line([sl1, sl2], fill=outline, width=max(1, round(5 * scale)))
        seal_bar_color = (199, 185, 154, round(255 * min(1.0, tone[3] / 255.0 * 0.72)))
        odraw.line([sl1, sl2], fill=seal_bar_color, width=max(1, round(2 * scale)))

    if hovered:
        hr = rr + 9.0 * scale
        h_bbox = [acx - hr, acy - hr, acx + hr, acy + hr]
        h_col = tuple(list(base_col) + [round(255 * min(1.0, alpha_val + 0.12))])
        odraw.arc(h_bbox, start=180, end=360, fill=h_col, width=max(1, round((2.5 if usable else 1.5) * scale)))

    canvas.alpha_composite(overlay_layer)

    # 7. Destination Text overlay
    tier_name = ["初念", "再念", "三念"][tier - 1]
    status_prefix = "封印中" if sealed else "可通行"
    status_tint = (186, 147, 119) if sealed else (218, 232, 180) # sealed_tint vs open_tint

    line1 = f"{status_prefix} · 前行 · 汤谷"
    line2 = f"选择祝福 · {beast}{tier_name}"
    line3 = "F · 前往房间" if (usable and not sealed) else ("靠近按 F 交互" if hovered else "")

    text_y = oy - gw_h - int(52 * scale)
    for line_idx, ltext in enumerate([line1, line2, line3]):
        if not ltext:
            continue
        # Draw shadow/outline
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1)]:
            draw.text((ox - int(80 * scale) + dx, text_y + line_idx * int(22 * scale) + dy), ltext, font=font_sub, fill=(13, 18, 10, 255))
        draw.text((ox - int(80 * scale), text_y + line_idx * int(22 * scale)), ltext, font=font_sub, fill=status_tint)

    # Footer badge
    badge = f"{beast} · {tier_name} ({'封印' if sealed else '可通行'})"
    draw.text((ox - int(70 * scale), ch - int(34 * scale)), badge, font=font_title, fill=base_col)

    return canvas

def main():
    beasts = ["青龙", "白虎", "朱雀"]
    tiers = [1, 2, 3]

    # 1. 封印态 3x3
    w_sealed = Image.new("RGBA", (360 * 3, 460 * 3), (18, 22, 19, 255))
    for r, tier in enumerate(tiers):
        for c, beast in enumerate(beasts):
            tile = render_single_portal(beast, tier, sealed=True, scale=1.0)
            w_sealed.paste(tile, (c * 360, r * 460))
    w_sealed.save(OUT / "walkthrough-sealed-3x3.png")

    # 2. 可通行态 3x3
    w_open = Image.new("RGBA", (360 * 3, 460 * 3), (18, 22, 19, 255))
    for r, tier in enumerate(tiers):
        for c, beast in enumerate(beasts):
            tile = render_single_portal(beast, tier, sealed=False, usable=(tier==1), hovered=(tier>1), scale=1.0)
            w_open.paste(tile, (c * 360, r * 460))
    w_open.save(OUT / "walkthrough-open-3x3.png")

    # 3. 三兽三门并列走查对照图 (Sealed Row vs Open Row for 3 beasts at Tier 1, 2, 3)
    # Grid: 3 columns (青龙/白虎/朱雀), 2 rows (封印态, 可通行态) at Tier 2 (再念) - canonical walk-through
    w_compare = Image.new("RGBA", (380 * 3 + 40, 480 * 2 + 80), (15, 18, 16, 255))
    cdraw = ImageDraw.Draw(w_compare)
    cdraw.text((24, 18), "汤谷选择门神兽祝福视觉走查对照（三兽并列 · 封印态 vs 可通行态）", font=font_header, fill=(240, 228, 195))

    for c, beast in enumerate(beasts):
        # Row 0: Sealed (Tier 2 再念)
        tile_sealed = render_single_portal(beast, 2, sealed=True, scale=1.05)
        w_compare.paste(tile_sealed, (20 + c * 380, 60))
        # Row 1: Open (Tier 2 再念)
        tile_open = render_single_portal(beast, 2, sealed=False, hovered=True, usable=True, scale=1.05)
        w_compare.paste(tile_open, (20 + c * 380, 60 + 490))

    w_compare.save(OUT / "walkthrough-three-beasts-side-by-side.png")

    # 4. 念级密度渐进对比图 (初念 -> 再念 -> 三念 for 青龙, sealed & open)
    w_tier_prog = Image.new("RGBA", (380 * 3 + 40, 480 * 2 + 80), (15, 18, 16, 255))
    tdraw = ImageDraw.Draw(w_tier_prog)
    tdraw.text((24, 18), "念级装饰密度渐进走查（青龙 · 初念／再念／三念 · 柱身刻痕与门楣冠环）", font=font_header, fill=(240, 228, 195))
    for c, tier in enumerate(tiers):
        tile_sealed = render_single_portal("青龙", tier, sealed=True, scale=1.05)
        w_tier_prog.paste(tile_sealed, (20 + c * 380, 60))
        tile_open = render_single_portal("青龙", tier, sealed=False, hovered=True, usable=True, scale=1.05)
        w_tier_prog.paste(tile_open, (20 + c * 380, 60 + 490))
    w_tier_prog.save(OUT / "walkthrough-tier-density-progression.png")

    print("Successfully generated all walkthrough render sheets in:", OUT)

if __name__ == "__main__":
    main()
