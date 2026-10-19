"""Restore the pinned T01 source into a new directory; never edit the working tree."""

import hashlib
import gzip
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile


baseline = Path(__file__).resolve().parent
repository = baseline.parents[2]
manifest = json.loads((baseline / "source-manifest.json").read_text())
if len(sys.argv) != 2:
    raise SystemExit("用法：python3 restore.py 尚不存在的目标目录")
destination = Path(sys.argv[1]).resolve()
if destination.exists():
    raise SystemExit("目标必须是尚不存在的新目录，避免覆盖已有工作。")

for name, expected in manifest["restore_artifacts"].items():
    if hashlib.sha256((baseline / name).read_bytes()).hexdigest() != expected:
        raise SystemExit(f"恢复材料校验失败：{name}")

archive = subprocess.check_output(
    ["git", "archive", manifest["base_commit"], "--", *manifest["archive_paths"]],
    cwd=repository,
)
destination.mkdir(parents=True)
with tarfile.open(fileobj=io.BytesIO(archive)) as files:
    files.extractall(destination, filter="data")
patch = gzip.decompress((baseline / "tracked.patch.gz").read_bytes())
if patch:
    subprocess.run(
        ["git", "apply", "--check"], input=patch, cwd=destination, check=True
    )
    subprocess.run(["git", "apply"], input=patch, cwd=destination, check=True)
with tarfile.open(baseline / "untracked.tar.gz") as files:
    files.extractall(destination, filter="data")

expected_paths = {item["path"] for item in manifest["files"]}
actual_paths = {
    str(path.relative_to(destination))
    for path in destination.rglob("*")
    if path.is_file()
}
if actual_paths != expected_paths:
    raise SystemExit("恢复文件清单不一致，请保留目标目录排查。")
for item in manifest["files"]:
    content = (destination / item["path"]).read_bytes()
    if len(content) != item["bytes"] or hashlib.sha256(content).hexdigest() != item["sha256"]:
        raise SystemExit(f"恢复内容不一致：{item['path']}")

print(json.dumps({"restored": str(destination), "verified_files": len(expected_paths)}, ensure_ascii=False))
