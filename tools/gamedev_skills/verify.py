#!/usr/bin/env python3
"""离线检查项目引入的游戏技能与固定来源快照是否一致。"""

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LOCK = Path(__file__).with_name("skills.lock.json")


def main() -> int:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    errors = []
    checked = 0
    for skill in lock["skills"]:
        directory = ROOT / skill["destination"]
        expected = skill["files"]
        actual = {str(p.relative_to(directory)) for p in directory.rglob("*") if p.is_file()}
        if actual != set(expected):
            errors.append(f"{skill['name']}: 文件清单不一致")
        for name, digest in expected.items():
            path = directory / name
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                errors.append(f"{path.relative_to(ROOT)}: 缺失或 SHA-256 不一致")
                continue
            checked += 1
            if path.suffix == ".md":
                content = path.read_text(encoding="utf-8")
                for target in re.findall(r"`((?:references|scripts|assets)/[^`\s]+)`", content):
                    if not (directory / target).is_file():
                        errors.append(f"{skill['name']}: 引用缺失 {target}")
        entry = directory / "SKILL.md"
        if entry.is_file():
            text = entry.read_text(encoding="utf-8")
            if not re.search(rf"^name: {re.escape(skill['name'])}$", text, re.M):
                errors.append(f"{skill['name']}: name 不匹配")
            if not text.startswith("---\n") or not re.search(r"^description:", text, re.M):
                errors.append(f"{skill['name']}: 元数据缺失")
    for name, digest in lock["support_files"].items():
        path = ROOT / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append(f"{name}: 缺失或 SHA-256 不一致")
    if errors:
        print("\n".join(errors))
        return 1
    print(f"通过：{len(lock['skills'])} 项技能、{checked} 个技能文件、许可与版本政策一致。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
