#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Nine Tripod Cauldrons - Asset Center Data & Sync Engine
九鼎 · 十日 | 资产管理中心数据与同步引擎
"""

import os
import sys
import json
import csv
import re
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
DOCS_ART_DIR = WORKSPACE_ROOT / "docs" / "art" / "美术资产库_v0.1"
JSON_PATH = DOCS_ART_DIR / "资产总表.json"
CSV_PATH = DOCS_ART_DIR / "资产总表.csv"
CATALOG_MD_PATH = DOCS_ART_DIR / "资产分类目录.md"
ALPHA_STATE_GD = WORKSPACE_ROOT / "godot" / "scripts" / "alpha" / "alpha_state.gd"

CSV_FIELDS = [
    "资产ID", "一级分类", "二级分类", "资产名称", "地区或环节", "用途",
    "所需形态_状态_动作", "范围阶段", "依据状态", "来源索引",
    "复用或关联资产", "制作状态", "备注"
]

def load_art_assets():
    """Load all art assets from JSON (fallback to CSV if necessary)."""
    if JSON_PATH.exists():
        with open(JSON_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data.get("assets", []), data
    elif CSV_PATH.exists():
        with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            assets = list(reader)
            return assets, {"schema_version": "0.1", "assets": assets}
    return [], {}

def load_gameplay_assets():
    """Parse gameplay definitions from godot/scripts/alpha/alpha_state.gd."""
    result = {
        "items": [],
        "characters": [],
        "vessels": []
    }
    if not ALPHA_STATE_GD.exists():
        return result

    try:
        with open(ALPHA_STATE_GD, "r", encoding="utf-8") as f:
            text = f.read()

        # Parse CONTENT
        content_match = re.search(r'const CONTENT:\s*Array\s*=\s*\[(.*?)\]\nconst CHARACTERS', text, re.DOTALL)
        if content_match:
            raw = content_match.group(1).strip()
            pattern = r'\[\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*"([^"]*)"\s*\]'
            for row in re.findall(pattern, raw):
                result["items"].append({
                    "name": row[0],
                    "kind": row[1],
                    "quality": row[2],
                    "container": row[3],
                    "width": int(row[4]),
                    "height": int(row[5]),
                    "description": row[6]
                })

        # Parse CHARACTERS
        chars_match = re.search(r'const CHARACTERS:\s*Array\s*=\s*\[(.*?)\]\nconst EFFECT_CARDS', text, re.DOTALL)
        if chars_match:
            raw = chars_match.group(1).strip()
            blocks = re.findall(r'\{\s*"name":\s*"([^"]+)".*?"kind":\s*"([^"]+)".*?"description":\s*"([^"]+)"\s*\}', raw, re.DOTALL)
            for b in blocks:
                result["characters"].append({
                    "name": b[0],
                    "kind": b[1],
                    "description": b[2]
                })

        # Parse EFFECT_CARDS
        effects_match = re.search(r'const EFFECT_CARDS:\s*Array\s*=\s*\[(.*?)\]\n', text, re.DOTALL)
        if effects_match:
            raw = effects_match.group(1).strip()
            blocks = re.findall(r'\{\s*"name":\s*"([^"]+)".*?"container":\s*"([^"]+)".*?"description":\s*"([^"]+)"\s*\}', raw, re.DOTALL)
            for b in blocks:
                result["vessels"].append({
                    "name": b[0],
                    "container": b[1],
                    "description": b[2]
                })
    except Exception as e:
        print(f"Error parsing alpha_state.gd: {e}", file=sys.stderr)

    return result

def scan_media_assets():
    """Scan workspace for images, spritesheets, and animations, mapping to asset IDs."""
    media_by_id = {}
    all_media_files = []

    # 1. output/art
    output_art = WORKSPACE_ROOT / "output" / "art"
    if output_art.exists():
        for root, dirs, files in os.walk(output_art):
            for f in files:
                if f.lower().endswith(('.png', '.webp', '.jpg', '.jpeg', '.svg')):
                    full_p = Path(root) / f
                    rel_p = full_p.relative_to(WORKSPACE_ROOT).as_posix()
                    file_info = {
                        "path": rel_p,
                        "filename": f,
                        "size": full_p.stat().st_size,
                        "type": "output_art"
                    }
                    all_media_files.append(file_info)

                    # ID extraction
                    m = re.search(r'(CHR-\d+|BOS-\d+|MOB-\d+|WEA-\d+|ITM-\d+|BLD-\d+|VEG-\d+|TER-\d+|DEC-\d+|VFX-\d+|UI-\d+|PRT-\d+|NAR-\d+)', rel_p)
                    if m:
                        aid = m.group(1)
                        media_by_id.setdefault(aid, []).append(file_info)
                    elif 'TANGGU-PORTAL' in rel_p:
                        media_by_id.setdefault('BLD-003', []).append(file_info)
                    elif 'TANGGU-RUIN-STONE' in rel_p:
                        media_by_id.setdefault('BLD-004', []).append(file_info)
                    elif 'TANGGU-WALL' in rel_p:
                        media_by_id.setdefault('BLD-001', []).append(file_info)
                    elif 'TANGGU-WORLD' in rel_p:
                        if 'tree' in f:
                            media_by_id.setdefault('VEG-001', []).append(file_info)
                        elif 'flora' in f:
                            media_by_id.setdefault('VEG-002', []).append(file_info)
                        elif 'terrain' in f:
                            media_by_id.setdefault('TER-001', []).append(file_info)
                        elif 'court' in f or 'pillar' in f:
                            media_by_id.setdefault('BLD-002', []).append(file_info)

    # 2. assets/
    assets_dir = WORKSPACE_ROOT / "assets"
    if assets_dir.exists():
        for root, dirs, files in os.walk(assets_dir):
            for f in files:
                if f.lower().endswith(('.png', '.webp', '.jpg', '.jpeg', '.svg')):
                    full_p = Path(root) / f
                    rel_p = full_p.relative_to(WORKSPACE_ROOT).as_posix()
                    file_info = {
                        "path": rel_p,
                        "filename": f,
                        "size": full_p.stat().st_size,
                        "type": "game_asset"
                    }
                    all_media_files.append(file_info)

                    if 'child' in rel_p:
                        media_by_id.setdefault('CHR-001', []).append(file_info)
                    elif 'thor' in rel_p:
                        media_by_id.setdefault('BOS-001', []).append(file_info)
                    elif 'shadow-puppet' in rel_p:
                        media_by_id.setdefault('MOB-001', []).append(file_info)
                    elif 'shadow-paper' in rel_p:
                        media_by_id.setdefault('MOB-002', []).append(file_info)
                    elif 'shadow-wood' in rel_p:
                        media_by_id.setdefault('MOB-003', []).append(file_info)
                    elif 'tanggu-ground' in rel_p:
                        media_by_id.setdefault('TER-001', []).append(file_info)
                    elif 'tanggu-props' in rel_p:
                        media_by_id.setdefault('ITM-001', []).append(file_info)
                    elif 'hud' in rel_p.lower():
                        media_by_id.setdefault('UI-001', []).append(file_info)

    return media_by_id, all_media_files

def calculate_stats(assets, media_by_id):
    """Compute multidimensional stats for dashboard."""
    stage_counts = {}
    category_counts = {}
    status_counts = {}
    media_count = 0

    for a in assets:
        stage = a.get("范围阶段", "未指定")
        stage_counts[stage] = stage_counts.get(stage, 0) + 1

        cat = a.get("一级分类", "未分类")
        category_counts[cat] = category_counts.get(cat, 0) + 1

        status = a.get("制作状态", "仅登记，未制作")
        status_counts[status] = status_counts.get(status, 0) + 1

        aid = a.get("资产ID")
        if aid in media_by_id and len(media_by_id[aid]) > 0:
            media_count += 1

    return {
        "total_assets": len(assets),
        "stage_breakdown": stage_counts,
        "category_breakdown": category_counts,
        "status_breakdown": status_counts,
        "with_live_media": media_count
    }

def get_full_dataset():
    """Retrieve full merged data for the Asset Center."""
    assets, raw_json = load_art_assets()
    gameplay = load_gameplay_assets()
    media_by_id, all_media_files = scan_media_assets()
    stats = calculate_stats(assets, media_by_id)

    # Attach media to assets
    enriched_assets = []
    for a in assets:
        aid = a.get("资产ID")
        item = dict(a)
        item["media"] = media_by_id.get(aid, [])
        enriched_assets.append(item)

    return {
        "meta": {
            "project": "九鼎",
            "sub_ip": "十日",
            "version": "1.0.0",
            "total_assets": len(assets)
        },
        "stats": stats,
        "assets": enriched_assets,
        "gameplay": gameplay,
        "media_catalog": all_media_files[:200]  # Cap for quick overview
    }

def save_all_views(assets_list):
    """Persist updated assets to CSV, JSON, and update markdown view."""
    # 1. Save JSON
    raw_json = {
        "schema_version": "0.1",
        "project": "九鼎",
        "sub_ip": "十日",
        "date": "2026-10-22",
        "purpose": "美术需求登记与资产管理中心主数据",
        "record_count": len(assets_list),
        "assets": [
            {k: a.get(k, "") for k in CSV_FIELDS} for a in assets_list
        ]
    }
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(raw_json, f, ensure_ascii=False, indent=2)

    # 2. Save CSV (UTF-8 with BOM for Excel compatibility)
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for a in assets_list:
            writer.writerow({k: a.get(k, "") for k in CSV_FIELDS})

    # 3. Synchronize Markdown Catalog if relevant
    update_catalog_markdown(assets_list)
    return True

def update_catalog_markdown(assets_list):
    """Safely update count and rows in 资产分类目录.md if it exists."""
    if not CATALOG_MD_PATH.exists():
        return
    try:
        with open(CATALOG_MD_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Update total count in line 5
        for i, line in enumerate(lines[:10]):
            if "共 **" in line and "条**" in line:
                lines[i] = f"共 **{len(assets_list)} 条**。范围按当前材料覆盖，未定内容另见《来源与待定项》，不宣称已穷尽尚未设计的招式与奖励。\n"
                break

        # Build quick map of ID -> asset
        id_map = {a.get("资产ID"): a for a in assets_list if a.get("资产ID")}

        # Scan for markdown table rows
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("|") and not stripped.startswith("| ID") and not stripped.startswith("| ---"):
                parts = [p.strip() for p in stripped.split("|")]
                if len(parts) >= 7:
                    aid = parts[1]
                    if aid in id_map:
                        a = id_map[aid]
                        # | ID | 名称 | 地区／环节 | 形态、状态与动作 | 范围／依据 | 来源 |
                        range_basis = f"{a.get('范围阶段', '')}／{a.get('依据状态', '')}".strip("／")
                        lines[i] = f"| {aid} | {a.get('资产名称', '')} | {a.get('地区或环节', '')} | {a.get('所需形态_状态_动作', '')} | {range_basis} | {a.get('来源索引', '')} |\n"

        with open(CATALOG_MD_PATH, "w", encoding="utf-8") as f:
            lines_str = "".join(lines)
            f.write(lines_str)
    except Exception as e:
        print(f"Warning: Failed to update catalog markdown: {e}", file=sys.stderr)

def update_single_asset(update_payload):
    """Update fields of an existing asset and save."""
    aid = update_payload.get("资产ID")
    if not aid:
        raise ValueError("Missing '资产ID'")

    assets, _ = load_art_assets()
    found = False
    for i, a in enumerate(assets):
        if a.get("资产ID") == aid:
            for k in CSV_FIELDS:
                if k in update_payload:
                    a[k] = update_payload[k]
            found = True
            break

    if not found:
        raise KeyError(f"Asset ID {aid} not found")

    save_all_views(assets)
    return True

def create_new_asset(new_payload):
    """Add a new asset to the registry."""
    assets, _ = load_art_assets()

    aid = new_payload.get("资产ID", "").strip()
    cat = new_payload.get("一级分类", "人物")

    prefix_map = {
        "人物": "CHR", "Boss 与对手": "BOS", "普通敌人与召唤物": "MOB",
        "武器与装备": "WEA", "道具与收集物": "ITM", "建筑与场景构件": "BLD",
        "树木与植被": "VEG", "地形与环境": "TER", "环境小物与贴花": "DEC",
        "视觉特效": "VFX", "界面与图标": "UI", "肖像与展示图": "PRT",
        "叙事画面与结局": "NAR"
    }

    if not aid:
        prefix = prefix_map.get(cat, "AST")
        # Find highest existing number for this prefix
        existing_nums = []
        for a in assets:
            cur_id = a.get("资产ID", "")
            if cur_id.startswith(prefix + "-"):
                m = re.search(r'\d+', cur_id)
                if m:
                    existing_nums.append(int(m.group(0)))
        next_num = max(existing_nums, default=0) + 1
        aid = f"{prefix}-{next_num:03d}"
        new_payload["资产ID"] = aid

    # Check for duplicate
    if any(a.get("资产ID") == aid for a in assets):
        raise ValueError(f"资产ID '{aid}' 已存在，不能重复！")

    cleaned_asset = {k: new_payload.get(k, "") for k in CSV_FIELDS}
    cleaned_asset["资产ID"] = aid
    if not cleaned_asset.get("制作状态"):
        cleaned_asset["制作状态"] = "仅登记，未制作"

    assets.append(cleaned_asset)
    save_all_views(assets)
    return cleaned_asset

if __name__ == "__main__":
    print("Testing data load...")
    dataset = get_full_dataset()
    print(f"Loaded {len(dataset['assets'])} assets, {len(dataset['gameplay']['items'])} gameplay items, {dataset['stats']['with_live_media']} with media.")
