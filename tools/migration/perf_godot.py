"""Headless CPU baseline for the Godot rule + snapshot path.

This is NOT a native FPS measurement: it runs the pure rule layer and the public
snapshot contract without a window or GPU. Use it on the same machine/engine to
compare before/after optimization, then do the real 1080p foreground check on
the target PC as documented in docs/architecture/九鼎_性能优化_2026-10-26.md.
"""
import argparse
import json
from pathlib import Path
import statistics
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
engine_lock = json.loads((root / "godot/engine-lock.json").read_text())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repeat", type=int, default=3, help="重复次数，取中位数")
    args = parser.parse_args()
    if args.repeat < 1:
        parser.error("--repeat 须大于 0")
    version = subprocess.check_output(["godot", "--version"], text=True).strip()
    if version != engine_lock["version"]:
        raise SystemExit(f"Godot 版本不符：{version}；需要 {engine_lock['version']}")
    results = []
    for _ in range(args.repeat):
        proc = subprocess.run(
            ["godot", "--headless", "--path", str(root / "godot"), "--script", "res://tests/performance_checks.gd"],
            capture_output=True, text=True,
        )
        output = proc.stdout + proc.stderr
        if proc.returncode or "ERROR:" in output:
            sys.stderr.write(output)
            return proc.returncode or 1
        for line in proc.stdout.splitlines():
            if not line.startswith("{"):
                continue
            payload = json.loads(line)
            if "measurement" in payload:
                results.append(payload["measurement"])
                break
    if not results:
        raise SystemExit("未读到 measurement 输出")
    per_frame = [item["ruleAndSnapshotUsecPerFrame"] for item in results]
    summary = {
        "engine": version,
        "repeat": len(results),
        "scenario": results[0]["scenario"],
        "ruleAndSnapshotUsecPerFrameMedian": statistics.median(per_frame),
        "ruleAndSnapshotUsecPerFrameSamples": per_frame,
        "workCounters": {key: results[0][key] for key in ["obstacleRebuilds", "interactionScans", "clearPathCalls", "snapshotCalls"]},
        "scope": "headless 纯规则与公开快照成本；不是原生 FPS、GPU 帧时间或双平台验收结果",
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
