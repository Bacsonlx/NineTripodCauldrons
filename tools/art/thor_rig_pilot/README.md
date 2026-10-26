# 索尔 AI 关节片段最小试点

仅验证同一套 PNG 的待机与完整横锤。AI 负责绑定数据、关键帧、合成预览与迭代；用户只评价效果，无需拖动关节。不是游戏中接入 AI 模型，也不是任意素材的一键自动识骨算法。

## 编辑入口

- `bindings.json`：16 件的父节点、统一脚点坐标系下的枢轴、裁图像素偏移、原始缩放与旋转、遮挡顺序。保留 v4 形象与尺寸；修正远侧前臂旧显示长度 39 与求解长度 31 不一致，使其采用 31。不是全套统一缩放或重拆件。
- `clips.json`：`idle` 2.4 秒循环、`swing` 1.92 秒非循环。旋转为相对绑定姿势的角度，位置为相对绑定姿势的世界像素偏移；原始 Sprite 缩放只保存在叶节点。横锤固定 0.8 秒前摇、0.12 秒挥击、1 秒收招。
- `build.py`：将两份数据写为持久化 `.tscn`，每个片段为所有使用过的属性提供初值，避免随机 seek 或重开残留。AI 的下次修改优先更新 JSON 再重建；直接在 Godot 编辑轨道后须回填 JSON，避免重建覆盖。
- `export_poses.gd`：实际实例化旧候选与新场景；横锤使用相同近距规则快照。待机使用隔离时间夹具，覆盖完整呼吸周期。
- `preview.py`：用真实导出变换和同一 PNG 合成并排预览。不是 GPU 截图；不验证过滤、灯光、原生 FPS。

```bash
python3 tools/art/thor_rig_pilot/build.py
godot --headless --path godot --script "$PWD/tools/art/thor_rig_pilot/export_poses.gd"
tools/asset_forge/.venv/bin/python tools/art/thor_rig_pilot/preview.py
godot --headless --path godot --script res://tests/thor_rig_pilot_checks.gd
# 后台构建专用入口包；Windows只导出，macOS另做无窗口启动检查
python3 tools/art/thor_rig_pilot/export_pilot.py
```

产物：`output/art/BOS-001/2026-10-23-rig-pilot/preview.html`（自包含、正常／慢放／逐帧）、`swing.webp`、`idle.webp`、`contact-sheet.png`。合成过程不修改原始 PNG。

原生候选：`godot/scenes/prototypes/thor_rig_pilot_test.tscn`；用户安排前台验收后才运行真实窗口。启动后使用近距规则夹具，未制作阶段显示待机占位，死亡立即中断横锤并回到静态占位；不得将其作为完整 Boss 接入。默认地图与原 Boss 脚本未修改。

运行时通过规则快照的 `phase/timer/elapsed` 直接定位片段；不自行推进动画时钟、不绑定动画事件裁决伤害。待机与横锤之外的动作、四向、素材重画、全面迁移均不在本轮。

原生专用包写入 `build/godot/thor-rig-pilot-macos.zip` 和 `build/godot/thor-rig-pilot-windows/NineTripods-ThorRigPilot.exe`。发布模板禁止命令行覆盖入口，因此 `export_pilot.py` 只在临时副本改主场景后导出，不修改当前工程或默认包的入口。
