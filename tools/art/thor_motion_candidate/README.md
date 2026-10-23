# 三招动作候选 v6：制作与复核

原始 PNG 保留，AI 编辑 `assets/characters/thor-motion-v6/poses.json` 并原样复制到 `godot/assets/boss/thor-motion-v6/poses.json`。`thor_motion_candidate.gd` 只在独立场景中采样三招，默认 Boss 动作不替换。不是新图像／视频生成，也不是全面迁移旧关节试点。

```sh
godot --headless --path godot --script "$PWD/tools/art/thor_motion_candidate/export_poses.gd" -- "$PWD/output/art/BOS-001/2026-10-23-combat-focus-v3/poses.json"
tools/asset_forge/.venv/bin/python tools/art/thor_motion_candidate/preview.py
godot --headless --path godot --script res://tests/boss_motion_candidate_checks.gd
```

`export_poses.gd` 用真实 Boss 规则、同一快照分别驱动当前默认动作与候选；`preview.py` 按实际变换离线合成 PNG 关键姿势、动画 WebP、自包含 HTML。素材像素不改动，支持逐帧／慢放及完整飞锤路径。合成不是 GPU 截图；未验证最终过滤、原生动态视觉或性能。当前播放对照采用直接近／远起手；实际追近转蓄力另由移动回归覆盖。

视觉确认和运行引用以[素材记录](../../../assets/characters/thor-motion-v6/README.md)为准。用户未确认本候选前，不在 `boss_art_view.gd` 替换默认角色。修改关键姿势后重导出、检查接缝、固定骨长、握点和承重脚，并重新生成预览。
