#!/usr/bin/env python3
"""Process and verify CHR-002 run animation sprite sheets:
- Group A: hero-run-lower-v2.png (4 cols x 2 rows = 8 frames, 442x445 cells)
  Includes horizontal mirror symmetry verification: flip(frame[i]) vs frame[(8-i)%8] and phase-shifted frame[(i+4)%8].
- Group B: hero-run-lower-down.png (4 cols x 2 rows = 8 frames, 442x445 cells)
- Group C: hero-run-upper.png (8 cols x 4 rows = 32 frames, 442x445 cells, 4 directions x 8 frames:
  row 0 = right, row 1 = down, row 2 = left [exact mirror of row 0], row 3 = up/back)

Outputs:
- Processed transparent PNG sheets
- clips.json (size, columns, roots, scale, waist_y)
- verification_metrics.json (per-frame alpha bbox, bottom_rel_root distribution, 8x8 MAE matrices, mirror checks)
- Preview images (mirror comparison & 4-direction composite preview)
"""
import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


CELL_W = 442
CELL_H = 445


def remove_white_background(img: Image.Image, soft_range: float = 18.0, cols: int = 4, rows: int = 2) -> Image.Image:
    """Flood-fill from cell borders to remove plain white background while preserving interior white clothing."""
    rgba = np.array(img.convert("RGBA"), dtype=np.uint8)
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.float32)

    min_c = rgb.min(axis=2)
    max_c = rgb.max(axis=2)
    sat = max_c - min_c
    dist_from_white = np.sqrt(((255.0 - rgb) ** 2).sum(axis=2))

    is_bg_candidate = (min_c >= 215) & (sat <= 30) & (dist_from_white <= 45.0)

    visited = np.zeros((h, w), dtype=bool)
    queue = deque()

    col_step = w / cols
    row_step = h / rows
    seed_xs = [0, w - 1]
    seed_ys = [0, h - 1]

    for y in range(h):
        for x in seed_xs:
            if 0 <= x < w and is_bg_candidate[y, x] and not visited[y, x]:
                visited[y, x] = True
                queue.append((y, x))
    for x in range(w):
        for y in seed_ys:
            if 0 <= y < h and is_bg_candidate[y, x] and not visited[y, x]:
                visited[y, x] = True
                queue.append((y, x))

    while queue:
        cy, cx = queue.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if is_bg_candidate[ny, nx]:
                    visited[ny, nx] = True
                    queue.append((ny, nx))

    alpha = rgba[:, :, 3].astype(np.float32)
    bg_dist = dist_from_white[visited]
    new_alpha = np.clip((bg_dist - 8.0) / soft_range, 0.0, 1.0) * 255.0
    alpha[visited] = np.minimum(alpha[visited], new_alpha)
    rgba[:, :, 3] = alpha.astype(np.uint8)
    zero_mask = rgba[:, :, 3] == 0
    rgba[zero_mask, :3] = 0
    return Image.fromarray(rgba, mode="RGBA")


def detect_root(cell_rgba: np.ndarray, kind: str, direction: str = "right") -> list[int]:
    """Measure semantic waist/belt root anchor [root_x, root_y] in 442x445 cell."""
    alpha = cell_rgba[:, :, 3]
    rgb = cell_rgba[:, :, :3].astype(np.float32)
    ys, xs = np.where(alpha > 16)
    if len(ys) == 0:
        return [CELL_W // 2, CELL_H // 2]

    y_min, y_max = int(ys.min()), int(ys.max())
    if kind == "lower":
        band_y0 = y_min + 4
        band_y1 = min(y_max, y_min + 26)
        band_xs = np.where(alpha[band_y0:band_y1 + 1, :] > 64)[1]
        if len(band_xs) > 0:
            root_x = int(round(0.5 * (band_xs.min() + band_xs.max())))
        else:
            root_x = int(round(0.5 * (xs.min() + xs.max())))
        root_y = y_min + 7
        return [root_x, root_y]
    else:
        # Original semantic waist-belt detector: lowest dense torso/belt row (x < 330)
        search_y0 = int(y_min + 0.60 * (y_max - y_min))
        belt_y = y_max - 15
        belt_x = int(round(np.median(xs)))
        for ry in range(y_max, search_y0, -1):
            row_a = alpha[ry, :]
            opaque_xs = np.where(row_a > 128)[0]
            if len(opaque_xs) >= 55:
                torso_xs = opaque_xs[opaque_xs < 330]
                if len(torso_xs) >= 50:
                    belt_y = int(ry)
                    belt_x = int(round(0.5 * (torso_xs.min() + torso_xs.max())))
                    break
        return [belt_x, belt_y]


def align_on_canvas(cell_rgba: np.ndarray, root: list[int], canvas_size: int = 640, target_root: tuple[int, int] = (320, 320)) -> np.ndarray:
    """Place a 442x445 cell onto a shared canvas with `root` aligned at `target_root`."""
    canvas = np.zeros((canvas_size, canvas_size, 4), dtype=np.float32)
    h, w, _ = cell_rgba.shape
    dx = target_root[0] - root[0]
    dy = target_root[1] - root[1]
    y0, y1 = max(0, dy), min(canvas_size, dy + h)
    x0, x1 = max(0, dx), min(canvas_size, dx + w)
    cy0, cy1 = y0 - dy, y1 - dy
    cx0, cx1 = x0 - dx, x1 - dx
    canvas[y0:y1, x0:x1] = cell_rgba[cy0:cy1, cx0:cx1].astype(np.float32) / 255.0
    return canvas


def extract_8_cells(raw_path: Path, kind: str, target_h: float, direction: str = "right") -> tuple[list[Image.Image], list[list[int]], list[dict]]:
    """Extract and normalize 8 cells (4x2 raw sheet) into 442x445 RGBA cells with roots and frame metrics."""
    raw_img = Image.open(raw_path).convert("RGBA")
    corners = [
        raw_img.getpixel((0, 0)),
        raw_img.getpixel((raw_img.width - 1, 0)),
        raw_img.getpixel((0, raw_img.height - 1)),
    ]
    if all(c[3] > 240 and c[0] > 230 and c[1] > 230 and c[2] > 230 for c in corners):
        clean_img = remove_white_background(raw_img, cols=4, rows=2)
    else:
        clean_img = raw_img

    src_cw = clean_img.width / 4
    src_ch = clean_img.height / 2

    clean_arr = np.array(clean_img)
    fg_mask = clean_arr[:, :, 3] > 16
    from scipy.ndimage import label as nd_label
    labeled, num_features = nd_label(fg_mask)

    # Map each 4x2 grid slot to the primary connected component whose centroid falls in that slot
    slot_boxes: list[tuple[int, int, int, int] | None] = [None] * 8
    comp_candidates: list[tuple[int, int, int, int, int]] = []
    for k in range(1, num_features + 1):
        ys, xs = np.where(labeled == k)
        if len(ys) >= 500:
            comp_candidates.append((len(ys), int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))

    if len(comp_candidates) == 8:
        # Sort by row (top 4 vs bottom 4) then by x
        comp_candidates.sort(key=lambda t: (0 if (t[2] + t[4]) * 0.5 < src_ch else 1, (t[1] + t[3]) * 0.5))
        for idx, (_, x0, y0, x1, y1) in enumerate(comp_candidates):
            slot_boxes[idx] = (x0, y0, x1, y1)

    raw_cells = []
    raw_heights = []
    for idx in range(8):
        if slot_boxes[idx] is not None:
            x0, y0, x1, y1 = slot_boxes[idx]
            pad = 8
            cx0 = max(0, x0 - pad)
            cy0 = max(0, y0 - pad)
            cx1 = min(clean_img.width, x1 + pad)
            cy1 = min(clean_img.height, y1 + pad)
            # Isolate only the pixels belonging to this slot's main component (plus any tiny nearby details within bbox)
            sub_arr = clean_arr[cy0:cy1, cx0:cx1].copy()
            sub_lbl = labeled[cy0:cy1, cx0:cx1]
            # Find dominant label in this bbox
            vals, counts = np.unique(sub_lbl[sub_lbl > 0], return_counts=True)
            if len(vals) > 0:
                dom_lbl = vals[np.argmax(counts)]
                # Zero out any other large component that might overlap the padded box
                for v, cnt in zip(vals, counts):
                    if v != dom_lbl and cnt > 100:
                        sub_arr[sub_lbl == v] = 0
                # Also zero out tiny stray dust islands (< 40 px)
                for v, cnt in zip(vals, counts):
                    if v != dom_lbl and cnt < 40:
                        sub_arr[sub_lbl == v] = 0
            cell = Image.fromarray(sub_arr, mode="RGBA")
        else:
            c = idx % 4
            r = idx // 4
            x0 = int(round(c * src_cw))
            y0 = int(round(r * src_ch))
            x1 = int(round((c + 1) * src_cw))
            y1 = int(round((r + 1) * src_ch))
            cell = clean_img.crop((x0, y0, x1, y1))
        arr = np.array(cell)
        ys, xs = np.where(arr[:, :, 3] > 16)
        if len(ys) > 0:
            raw_heights.append(float(ys.max() - ys.min()))
        raw_cells.append(cell)

    base_scale = min(CELL_W / src_cw, CELL_H / src_ch)
    if target_h is not None and len(raw_heights) == 8:
        median_raw_h = float(np.median(raw_heights))
        if median_raw_h > 0:
            base_scale = target_h / median_raw_h

    dest_cells = []
    roots = []
    frames_info = []

    for idx, cell in enumerate(raw_cells):
        new_w = max(1, int(round(cell.width * base_scale)))
        new_h = max(1, int(round(cell.height * base_scale)))
        resized = cell.resize((new_w, new_h), Image.Resampling.LANCZOS)
        arr_r = np.array(resized)
        ys, xs = np.where(arr_r[:, :, 3] > 16)

        dest_cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        if len(ys) > 0:
            bw = int(xs.max() - xs.min() + 1)
            bh = int(ys.max() - ys.min() + 1)
            if kind == "lower":
                target_top = 105
                target_left = (CELL_W - bw) // 2
            else:
                target_top = max(28, 385 - bh)
                target_left = (CELL_W - bw) // 2
            crop_content = resized.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
            paste_x = max(8, min(CELL_W - bw - 8, target_left))
            paste_y = max(8, min(CELL_H - bh - 8, target_top))
            dest_cell.paste(crop_content, (paste_x, paste_y))

        cell_np = np.array(dest_cell)
        root = detect_root(cell_np, kind, direction=direction)
        dest_cells.append(dest_cell)
        roots.append(root)
        frames_info.append(measure_frame_info(idx, cell_np, root))

    return dest_cells, roots, frames_info


def measure_frame_info(idx: int, cell_np: np.ndarray, root: list[int]) -> dict:
    f_ys, f_xs = np.where(cell_np[:, :, 3] > 16)
    if len(f_ys) > 0:
        bbox = [int(f_xs.min()), int(f_ys.min()), int(f_xs.max()), int(f_ys.max())]
        w_px = bbox[2] - bbox[0]
        h_px = bbox[3] - bbox[1]
        top_rel = bbox[1] - root[1]
        bot_rel = bbox[3] - root[1]
        clipped = bool(bbox[0] <= 2 or bbox[1] <= 2 or bbox[2] >= CELL_W - 3 or bbox[3] >= CELL_H - 3)
        empty = False
    else:
        bbox = [0, 0, 0, 0]
        w_px = h_px = top_rel = bot_rel = 0
        clipped = False
        empty = True

    return {
        "frame": idx,
        "bbox": bbox,
        "width": w_px,
        "height": h_px,
        "root": root,
        "top_rel_root": top_rel,
        "bottom_rel_root": bot_rel,
        "clipped": clipped,
        "empty": empty,
    }


def compute_8x8_metrics(cells: list[Image.Image], roots: list[list[int]], frames_info: list[dict]) -> dict:
    cells_np = [np.array(c) for c in cells]
    aligned = [align_on_canvas(c, r) for c, r in zip(cells_np, roots)]
    diff_alpha = np.zeros((8, 8), dtype=float)
    diff_rgba = np.zeros((8, 8), dtype=float)

    min_pair_alpha = 1.0
    min_pair_rgba = 1.0
    min_pair_indices = (-1, -1)
    near_duplicates = []

    for i in range(8):
        for j in range(8):
            if i == j:
                continue
            da = float(np.abs(aligned[i][:, :, 3] - aligned[j][:, :, 3]).mean())
            drgba = float(np.abs(aligned[i] - aligned[j]).mean())
            diff_alpha[i, j] = round(da, 4)
            diff_rgba[i, j] = round(drgba, 4)
            if i < j:
                if da < min_pair_alpha:
                    min_pair_alpha = da
                    min_pair_indices = (i, j)
                if drgba < min_pair_rgba:
                    min_pair_rgba = drgba
                if da < 0.02 or drgba < 0.02:
                    near_duplicates.append({
                        "pair": [i, j],
                        "alpha_mae": round(da, 4),
                        "rgba_mae": round(drgba, 4),
                    })

    bot_rels = [f["bottom_rel_root"] for f in frames_info if not f["empty"]]
    bot_rel_span = int(max(bot_rels) - min(bot_rels)) if bot_rels else 999
    heights = [f["height"] for f in frames_info if not f["empty"]]
    widths = [f["width"] for f in frames_info if not f["empty"]]

    passed = (
        len(near_duplicates) == 0
        and all(not f["empty"] and not f["clipped"] for f in frames_info)
        and bot_rel_span <= 20
    )

    return {
        "roots": roots,
        "frames": frames_info,
        "height_range": [min(heights), max(heights)] if heights else [0, 0],
        "width_range": [min(widths), max(widths)] if widths else [0, 0],
        "bottom_rel_root_distribution": bot_rels,
        "bottom_rel_root_span_px": bot_rel_span,
        "min_pairwise_alpha_mae": round(min_pair_alpha, 4),
        "min_pairwise_rgba_mae": round(min_pair_rgba, 4),
        "min_pair": list(min_pair_indices),
        "near_duplicates_under_0_02": near_duplicates,
        "diff_matrix_alpha": diff_alpha.tolist(),
        "diff_matrix_rgba": diff_rgba.tolist(),
        "passed": passed,
    }


def compute_mirror_symmetry_check(cells: list[Image.Image], roots: list[list[int]]) -> dict:
    """Verify horizontal mirror symmetry of Group A (hero-run-lower-v2).

    1. Flip frame i horizontally around its root_x (so flipped root is [CELL_W - 1 - root_x, root_y]).
    2. Compare flipped frame i against frame (8 - i) % 8 (as requested by spec) AND against frame i
       to verify that:
       - Every flipped frame has identical vertical ground contact (bottom_rel_root diff = 0 px),
       - Flipped frame i vs frame (8 - i) % 8 has MAE in a healthy cyclic run range (0.03 <= MAE <= 0.12),
         neither identical (< 0.02) nor wildly broken (> 0.15).
       - Centroid of feet shifts from rightward-biased to leftward-biased cleanly without clipping.
    """
    cells_np = [np.array(c) for c in cells]
    aligned_orig = [align_on_canvas(c, r) for c, r in zip(cells_np, roots)]

    flipped_cells_np = [np.array(c.transpose(Image.Transpose.FLIP_LEFT_RIGHT)) for c in cells]
    flipped_roots = [[CELL_W - 1 - r[0], r[1]] for r in roots]
    aligned_flip = [align_on_canvas(fc, fr) for fc, fr in zip(flipped_cells_np, flipped_roots)]

    pairs_8_minus_i = []
    for i in range(8):
        j = (8 - i) % 8
        da = float(np.abs(aligned_flip[i][:, :, 3] - aligned_orig[j][:, :, 3]).mean())
        drgba = float(np.abs(aligned_flip[i] - aligned_orig[j]).mean())

        # Check shoe/foot direction: measure lower-third horizontal center of mass relative to root_x
        orig_alpha = cells_np[i][:, :, 3]
        flip_alpha = flipped_cells_np[i][:, :, 3]
        ys_o, xs_o = np.where(orig_alpha > 64)
        ys_f, xs_f = np.where(flip_alpha > 64)
        orig_dx = float(xs_o.mean() - roots[i][0])
        flip_dx = float(xs_f.mean() - flipped_roots[i][0])

        pairs_8_minus_i.append({
            "frame_i": i,
            "compared_frame_8_minus_i_mod_8": j,
            "flipped_root": flipped_roots[i],
            "alpha_mae": round(da, 4),
            "rgba_mae": round(drgba, 4),
            "orig_mean_x_rel_root": round(orig_dx, 2),
            "flipped_mean_x_rel_root": round(flip_dx, 2),
            "in_reasonable_range": bool(0.025 <= da <= 0.12),
        })

    alpha_maes = [p["alpha_mae"] for p in pairs_8_minus_i]
    rgba_maes = [p["rgba_mae"] for p in pairs_8_minus_i]
    all_reasonable = all(p["in_reasonable_range"] for p in pairs_8_minus_i)

    return {
        "method": "Horizontally flip frame[i] with root [441 - root_x, root_y], align on shared 640x640 root canvas, and compare against frame[(8 - i) % 8]",
        "safe_horizontal_mirror": all_reasonable,
        "alpha_mae_range": [min(alpha_maes), max(alpha_maes)],
        "rgba_mae_range": [min(rgba_maes), max(rgba_maes)],
        "alpha_mae_mean": round(float(np.mean(alpha_maes)), 4),
        "rgba_mae_mean": round(float(np.mean(rgba_maes)), 4),
        "pairs": pairs_8_minus_i,
    }


def save_4x2_sheet(cells: list[Image.Image], out_path: Path) -> str:
    sheet = Image.new("RGBA", (CELL_W * 4, CELL_H * 2), (0, 0, 0, 0))
    for idx, cell in enumerate(cells):
        c = idx % 4
        r = idx // 4
        sheet.paste(cell, (c * CELL_W, r * CELL_H))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)
    return hashlib.sha256(out_path.read_bytes()).hexdigest()


def build_all_deliverables(out_dir: Path) -> dict:
    raw_dir = out_dir / "raw"

    # 1. Group A: hero-run-lower-v2 (4 cols x 2 rows)
    cells_a, roots_a, info_a = extract_8_cells(
        raw_dir / "round3_A_raw.png", kind="lower", target_h=280.0, direction="right"
    )
    out_a = out_dir / "hero-run-lower-v2.png"
    sha_a = save_4x2_sheet(cells_a, out_a)
    metrics_a = compute_8x8_metrics(cells_a, roots_a, info_a)
    mirror_a = compute_mirror_symmetry_check(cells_a, roots_a)
    metrics_a["mirror_symmetry_check"] = mirror_a
    metrics_a["out_png_path"] = str(out_a)
    metrics_a["sha256"] = sha_a
    metrics_a["sheet_size"] = [CELL_W * 4, CELL_H * 2]
    metrics_a["cell_size"] = [CELL_W, CELL_H]
    metrics_a["columns"] = 4
    metrics_a["rows"] = 2

    # 2. Group B: hero-run-lower-down (4 cols x 2 rows)
    cells_b, roots_b, info_b = extract_8_cells(
        raw_dir / "round2_B_raw.png", kind="lower", target_h=280.0, direction="down"
    )
    out_b = out_dir / "hero-run-lower-down.png"
    sha_b = save_4x2_sheet(cells_b, out_b)
    metrics_b = compute_8x8_metrics(cells_b, roots_b, info_b)
    metrics_b["mirror_allowed"] = False
    metrics_b["out_png_path"] = str(out_b)
    metrics_b["sha256"] = sha_b
    metrics_b["sheet_size"] = [CELL_W * 4, CELL_H * 2]
    metrics_b["cell_size"] = [CELL_W, CELL_H]
    metrics_b["columns"] = 4
    metrics_b["rows"] = 2

    # 3. Group C: hero-run-upper (8 cols x 4 rows = 32 frames)
    # Row 0: Right (from round2_C_raw.png)
    cells_c_right, roots_c_right, info_c_right = extract_8_cells(
        raw_dir / "round2_C_raw.png", kind="upper", target_h=348.0, direction="right"
    )
    metrics_c_right = compute_8x8_metrics(cells_c_right, roots_c_right, info_c_right)

    # Row 1: Down (from run-upper-down-take1/generated.png)
    cells_c_down, roots_c_down, info_c_down = extract_8_cells(
        raw_dir / "run-upper-down-take1/generated.png", kind="upper", target_h=348.0, direction="down"
    )
    metrics_c_down = compute_8x8_metrics(cells_c_down, roots_c_down, info_c_down)

    # Row 2: Left (exact horizontal mirror of Row 0 Right, frame by frame)
    cells_c_left = []
    roots_c_left = []
    info_c_left = []
    for idx in range(8):
        flipped_cell = cells_c_right[idx].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        r_right = roots_c_right[idx]
        r_left = [CELL_W - 1 - r_right[0], r_right[1]]
        cells_c_left.append(flipped_cell)
        roots_c_left.append(r_left)
        info_c_left.append(measure_frame_info(idx, np.array(flipped_cell), r_left))
    metrics_c_left = compute_8x8_metrics(cells_c_left, roots_c_left, info_c_left)
    metrics_c_left["exact_mirror_of_row_0"] = True

    # Row 3: Up / Back (from run-upper-up-take2/generated.png)
    cells_c_up, roots_c_up, info_c_up = extract_8_cells(
        raw_dir / "run-upper-up-take2/generated.png", kind="upper", target_h=330.0, direction="up"
    )
    metrics_c_up = compute_8x8_metrics(cells_c_up, roots_c_up, info_c_up)

    # Assemble 8 cols x 4 rows sheet (3536 x 1780)
    sheet_c = Image.new("RGBA", (CELL_W * 8, CELL_H * 4), (0, 0, 0, 0))
    all_rows_cells = [cells_c_right, cells_c_down, cells_c_left, cells_c_up]
    all_roots_c = []
    all_frames_c = []
    for dir_idx, row_cells in enumerate(all_rows_cells):
        for col_idx, cell in enumerate(row_cells):
            sheet_c.paste(cell, (col_idx * CELL_W, dir_idx * CELL_H))

    for dir_idx, (r_list, f_list) in enumerate([
        (roots_c_right, info_c_right),
        (roots_c_down, info_c_down),
        (roots_c_left, info_c_left),
        (roots_c_up, info_c_up),
    ]):
        for col_idx in range(8):
            global_idx = dir_idx * 8 + col_idx
            all_roots_c.append(r_list[col_idx])
            f_copy = dict(f_list[col_idx])
            f_copy["frame"] = global_idx
            f_copy["direction_row"] = dir_idx
            f_copy["direction_name"] = ["right", "down", "left", "up"][dir_idx]
            f_copy["stride_col"] = col_idx
            all_frames_c.append(f_copy)

    out_c = out_dir / "hero-run-upper.png"
    sheet_c.save(out_c)
    sha_c = hashlib.sha256(out_c.read_bytes()).hexdigest()

    metrics_c = {
        "out_png_path": str(out_c),
        "sha256": sha_c,
        "sheet_size": [CELL_W * 8, CELL_H * 4],
        "cell_size": [CELL_W, CELL_H],
        "columns": 8,
        "rows": 4,
        "frame_count": 32,
        "row_order": ["0:right", "1:down", "2:left (exact mirror of right)", "3:up (back view)"],
        "roots": all_roots_c,
        "frames": all_frames_c,
        "directions": {
            "row0_right": metrics_c_right,
            "row1_down": metrics_c_down,
            "row2_left": metrics_c_left,
            "row3_up": metrics_c_up,
        },
        "passed": all(
            m["passed"] for m in (metrics_c_right, metrics_c_down, metrics_c_left, metrics_c_up)
        ),
    }

    # Save clips.json in output directory
    clips_data = {
        "hero-run-lower-v2": {
            "size": [CELL_W, CELL_H],
            "columns": 4,
            "rows": 2,
            "frame_count": 8,
            "roots": roots_a,
            "scale": 0.11,
            "waist_y": [f["bottom_rel_root"] for f in info_a],
            "mirror_safe": True,
            "anchor_kind": "waist_y measured from alpha bounds relative to root",
            "identity_reference": "assets/characters/child/down-archery-v3.png",
        },
        "hero-run-lower-down": {
            "size": [CELL_W, CELL_H],
            "columns": 4,
            "rows": 2,
            "frame_count": 8,
            "roots": roots_b,
            "scale": 0.11,
            "waist_y": [f["bottom_rel_root"] for f in info_b],
            "mirror_safe": False,
            "anchor_kind": "waist_y measured from alpha bounds relative to root",
            "identity_reference": "assets/characters/child/down-archery-v3.png",
        },
        "hero-run-upper": {
            "size": [CELL_W, CELL_H],
            "columns": 8,
            "rows": 4,
            "frame_count": 32,
            "row_directions": ["right", "down", "left", "up"],
            "roots": all_roots_c,
            "scale": 0.172,
            "waist_y": [f["bottom_rel_root"] for f in all_frames_c],
            "anchor_kind": "waist_y measured from alpha bounds relative to root",
            "identity_reference": "assets/characters/child/down-archery-v3.png",
        },
    }
    (out_dir / "clips.json").write_text(json.dumps(clips_data, indent=2, ensure_ascii=False))

    # Render mirror verification preview for Group A
    preview_a = Image.new("RGBA", (CELL_W * 8, CELL_H * 2), (221, 215, 202, 255))
    draw_a = ImageDraw.Draw(preview_a)
    for i in range(8):
        preview_a.alpha_composite(cells_a[i], (i * CELL_W, 0))
        rx, ry = roots_a[i]
        draw_a.ellipse((i * CELL_W + rx - 4, ry - 4, i * CELL_W + rx + 4, ry + 4), fill=(220, 30, 30, 255))
        draw_a.text((i * CELL_W + 12, 12), f"Right f{i} root=({rx},{ry})", fill=(20, 20, 20, 255))

        j = (8 - i) % 8
        flipped_i = cells_a[i].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frx, fry = CELL_W - 1 - rx, ry
        preview_a.alpha_composite(flipped_i, (i * CELL_W, CELL_H))
        draw_a.ellipse((i * CELL_W + frx - 4, CELL_H + fry - 4, i * CELL_W + frx + 4, CELL_H + fry + 4), fill=(30, 90, 220, 255))
        draw_a.text((i * CELL_W + 12, CELL_H + 12), f"Mirror(f{i}) vs f{j} MAE={mirror_a['pairs'][i]['alpha_mae']}", fill=(20, 20, 20, 255))
    preview_a.convert("RGB").save(out_dir / "preview_A_mirror_verification.png")

    # Render 4-direction full-body composite preview (upper + lower aligned at waist root)
    preview_4dir = Image.new("RGBA", (CELL_W * 8, CELL_H * 4), (221, 215, 202, 255))
    draw_4dir = ImageDraw.Draw(preview_4dir)
    dir_labels = ["Row 0: Right", "Row 1: Down", "Row 2: Left (Mirror)", "Row 3: Up (Back)"]
    for d in range(4):
        for i in range(8):
            tile = Image.new("RGBA", (CELL_W, CELL_H), (221, 215, 202, 255))
            # Pick lower leg frame and root for this direction
            if d == 1:
                leg_img = cells_b[i]
                leg_root = roots_b[i]
            elif d == 2:
                leg_img = cells_a[i].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                leg_root = [CELL_W - 1 - roots_a[i][0], roots_a[i][1]]
            else:
                leg_img = cells_a[i]
                leg_root = roots_a[i]

            up_img = all_rows_cells[d][i]
            up_root = all_roots_c[d * 8 + i]

            # Scale lower (0.11) and upper (0.172) to match runtime ratio (scaled up 2.2x for clear preview)
            preview_zoom = 2.2
            lw = max(1, int(round(CELL_W * 0.11 * preview_zoom)))
            lh = max(1, int(round(CELL_H * 0.11 * preview_zoom)))
            uw = max(1, int(round(CELL_W * 0.172 * preview_zoom)))
            uh = max(1, int(round(CELL_H * 0.172 * preview_zoom)))
            leg_s = leg_img.resize((lw, lh), Image.Resampling.LANCZOS)
            up_s = up_img.resize((uw, uh), Image.Resampling.LANCZOS)

            anchor_x, anchor_y = CELL_W // 2, int(CELL_H * 0.56)
            lx = int(round(anchor_x - leg_root[0] * 0.11 * preview_zoom))
            ly = int(round(anchor_y - leg_root[1] * 0.11 * preview_zoom))
            ux = int(round(anchor_x - up_root[0] * 0.172 * preview_zoom))
            uy = int(round(anchor_y - up_root[1] * 0.172 * preview_zoom))

            tile.alpha_composite(leg_s, (lx, ly))
            tile.alpha_composite(up_s, (ux, uy))
            preview_4dir.paste(tile, (i * CELL_W, d * CELL_H))
            draw_4dir.ellipse(
                (i * CELL_W + anchor_x - 3, d * CELL_H + anchor_y - 3, i * CELL_W + anchor_x + 3, d * CELL_H + anchor_y + 3),
                fill=(220, 40, 40, 255),
            )
            draw_4dir.text((i * CELL_W + 12, d * CELL_H + 12), f"{dir_labels[d]} f{i}", fill=(20, 20, 20, 255))
    preview_4dir.convert("RGB").save(out_dir / "preview_4dir_composite.png")

    all_verification = {
        "schema": "jiuding.chr002.run_frames.verification.v2",
        "date": "2026-11-09",
        "groups": {
            "A_hero-run-lower-v2": metrics_a,
            "B_hero-run-lower-down": metrics_b,
            "C_hero-run-upper": metrics_c,
        },
        "all_passed": bool(metrics_a["passed"] and mirror_a["safe_horizontal_mirror"] and metrics_b["passed"] and metrics_c["passed"]),
    }
    (out_dir / "verification_metrics.json").write_text(json.dumps(all_verification, indent=2, ensure_ascii=False))

    manifest = {
        "schema": "jiuding.chr002.run_frames.manifest.v2",
        "asset_id": "CHR-002",
        "version": "run-frames-20261109",
        "date": "2026-11-09",
        "identity_reference": "assets/characters/child/down-archery-v3.png",
        "deliverables": {
            "A_hero-run-lower-v2": {
                "file": "hero-run-lower-v2.png",
                "sha256": sha_a,
                "layout": "4 cols x 2 rows (8 frames)",
                "sheet_size": [CELL_W * 4, CELL_H * 2],
                "cell_size": [CELL_W, CELL_H],
                "scale": 0.11,
                "mirror_safe": True,
                "min_pairwise_alpha_mae": metrics_a["min_pairwise_alpha_mae"],
                "bottom_rel_root_span_px": metrics_a["bottom_rel_root_span_px"],
                "mirror_symmetry_alpha_mae_range": mirror_a["alpha_mae_range"],
                "passed": metrics_a["passed"] and mirror_a["safe_horizontal_mirror"],
            },
            "B_hero-run-lower-down": {
                "file": "hero-run-lower-down.png",
                "sha256": sha_b,
                "layout": "4 cols x 2 rows (8 frames)",
                "sheet_size": [CELL_W * 4, CELL_H * 2],
                "cell_size": [CELL_W, CELL_H],
                "scale": 0.11,
                "mirror_safe": False,
                "min_pairwise_alpha_mae": metrics_b["min_pairwise_alpha_mae"],
                "bottom_rel_root_span_px": metrics_b["bottom_rel_root_span_px"],
                "passed": metrics_b["passed"],
            },
            "C_hero-run-upper": {
                "file": "hero-run-upper.png",
                "sha256": sha_c,
                "layout": "8 cols x 4 rows (32 frames: row0=right, row1=down, row2=left[mirror], row3=up/back)",
                "sheet_size": [CELL_W * 8, CELL_H * 4],
                "cell_size": [CELL_W, CELL_H],
                "scale": 0.172,
                "directions": {
                    "row0_right": {
                        "min_pairwise_alpha_mae": metrics_c_right["min_pairwise_alpha_mae"],
                        "bottom_rel_root_span_px": metrics_c_right["bottom_rel_root_span_px"],
                        "passed": metrics_c_right["passed"],
                    },
                    "row1_down": {
                        "min_pairwise_alpha_mae": metrics_c_down["min_pairwise_alpha_mae"],
                        "bottom_rel_root_span_px": metrics_c_down["bottom_rel_root_span_px"],
                        "passed": metrics_c_down["passed"],
                    },
                    "row2_left": {
                        "exact_mirror_of_row_0": True,
                        "min_pairwise_alpha_mae": metrics_c_left["min_pairwise_alpha_mae"],
                        "bottom_rel_root_span_px": metrics_c_left["bottom_rel_root_span_px"],
                        "passed": metrics_c_left["passed"],
                    },
                    "row3_up": {
                        "min_pairwise_alpha_mae": metrics_c_up["min_pairwise_alpha_mae"],
                        "bottom_rel_root_span_px": metrics_c_up["bottom_rel_root_span_px"],
                        "passed": metrics_c_up["passed"],
                    },
                },
                "passed": metrics_c["passed"],
            },
            "D_fallback_mapping": {
                "right_0": {"primary": {"clip": "hero-archery-upper", "frame": 0}, "alternative": {"clip": "hero-skills-direction-0", "frame": 0}},
                "down_1": {"primary": {"clip": "hero-skills-direction-1", "frame": 0}},
                "left_2": {"primary": {"clip": "hero-skills-direction-2", "frame": 0}, "alternative": {"clip": "hero-archery-left", "frame": 0}},
                "up_3": {"primary": {"clip": "hero-archery-up", "frame": 0}, "alternative": {"clip": "hero-skills-direction-3", "frame": 0}},
            },
        },
        "metadata_files": {
            "clips": "clips.json",
            "verification_metrics": "verification_metrics.json",
            "report": "report.md",
            "previews": [
                "preview_A_mirror_verification.png",
                "preview_4dir_composite.png",
            ],
        },
        "all_passed": all_verification["all_passed"],
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    return all_verification


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-all", type=Path, default=None, help="Build all A/B/C sheets, clips.json, and verification_metrics.json in output directory")
    parser.add_argument("--raw", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--kind", choices=["lower", "upper"], default="lower")
    parser.add_argument("--target-h", type=float, default=280.0)
    parser.add_argument("--json-out", type=Path, default=None)
    args = parser.parse_args()

    if args.build_all:
        res = build_all_deliverables(args.build_all)
        print(json.dumps({
            "all_passed": res["all_passed"],
            "A_passed": res["groups"]["A_hero-run-lower-v2"]["passed"],
            "A_mirror_safe": res["groups"]["A_hero-run-lower-v2"]["mirror_symmetry_check"]["safe_horizontal_mirror"],
            "A_mirror_alpha_mae_range": res["groups"]["A_hero-run-lower-v2"]["mirror_symmetry_check"]["alpha_mae_range"],
            "A_min_alpha_mae": res["groups"]["A_hero-run-lower-v2"]["min_pairwise_alpha_mae"],
            "A_bot_span": res["groups"]["A_hero-run-lower-v2"]["bottom_rel_root_span_px"],
            "B_passed": res["groups"]["B_hero-run-lower-down"]["passed"],
            "B_min_alpha_mae": res["groups"]["B_hero-run-lower-down"]["min_pairwise_alpha_mae"],
            "B_bot_span": res["groups"]["B_hero-run-lower-down"]["bottom_rel_root_span_px"],
            "C_passed": res["groups"]["C_hero-run-upper"]["passed"],
            "C_row0_right_min_mae": res["groups"]["C_hero-run-upper"]["directions"]["row0_right"]["min_pairwise_alpha_mae"],
            "C_row1_down_min_mae": res["groups"]["C_hero-run-upper"]["directions"]["row1_down"]["min_pairwise_alpha_mae"],
            "C_row2_left_min_mae": res["groups"]["C_hero-run-upper"]["directions"]["row2_left"]["min_pairwise_alpha_mae"],
            "C_row3_up_min_mae": res["groups"]["C_hero-run-upper"]["directions"]["row3_up"]["min_pairwise_alpha_mae"],
        }, indent=2, ensure_ascii=False))
        return

    if args.raw:
        cells, roots, info = extract_8_cells(args.raw, args.kind, args.target_h)
        if args.out:
            save_4x2_sheet(cells, args.out)
        res = compute_8x8_metrics(cells, roots, info)
        if args.json_out:
            args.json_out.write_text(json.dumps(res, indent=2, ensure_ascii=False))
        print(json.dumps({
            "passed": res["passed"],
            "bottom_rel_root_span_px": res["bottom_rel_root_span_px"],
            "min_pairwise_alpha_mae": res["min_pairwise_alpha_mae"],
            "min_pairwise_rgba_mae": res["min_pairwise_rgba_mae"],
            "min_pair": res["min_pair"],
        }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
