# 九鼎 · Godot 汤谷迁移工程

当前候选 `0.3.0-godot-candidate.1`，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility 原生 2D。用户已明确试玩通过 `0.3.0-godot-sample.1`，当前在同一套规则与呈现上接入完整汤谷。Windows 实测按用户要求暂缓，旧版 npm 主入口保留。

已接入普通箭、Q 穿透箭、E 固定落点三段箭雨、空格闪避、三组 3／4／5 影偶、主路两支路、残碑阅读、一次性祭坛与内侧开门捷径。完整实施和平台验收状态见 [实施记录](../docs/migration/Godot迁移_实施记录.md)。

在仓库根目录执行：

```sh
python3 tools/migration/prepare_sample_assets.py
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/run_tests.gd
godot --path godot
```

资源转换保留既有图像、脚点、锚点和帧缩放；重复运行结果一致。规则检查包含旧版 55 个场景／4,250 次公开状态对比，以及小样、输入适配和布局保存重开检查。参照回放容许 0.001 世界单位数值误差；角度按同方向比较。自动检查不代表原生操作、性能或双平台验收通过。

操作：WASD 移动，鼠标独立瞄准，左键点按／按住射箭，Q 穿透箭，E 箭雨，空格闪避，F 互动，Esc 暂停／合上残碑，R 重试，F11 或右上角按钮切换全屏。失焦暂停，窗口变化取消输入但不暂停。阅读停止游戏时间；三组肃清后可以回头探索。

编辑 `scenes/tanggu_map.tscn`，Scene 树中选择对应节点：

- 道路：`Road*` 的 Position、Size、Terrain Material，绿色矩形表示可行走脚点区域。
- 障碍：`Obstacle*` 的 Position、Size（脚底占地）、Body Height（阻箭高度）、Obstacle Kind；红色矩形表示脚底实体。
- 出生：`PlayerSpawn` 改玩家出生；`Encounter*/Enemy*` 改敌人出生与 Appearance。遭遇节点决定激活中心，子节点使用相对坐标。
- 互动：`SteleInteraction`、`AltarInteraction`、`GateInteraction` 的 Position。互动点与实体分别表示可站立操作点和物件轮廓。

保存后 F5 运行完整主场景；关闭重开与导出都读取这份原生场景。地图单位与运行规则相同，不再叠加等距投影；布局编辑使用 Position／Size，不以 Node 的旋转／缩放代替它们。`prepare_tanggu_scene.py` 仅用于首次迁移，已有场景时拒绝覆盖，避免抹掉编辑器调整。旧版规则参照仅供回归，不从 Node.js 加载游戏运行逻辑。

导出需安装匹配的官方模板，版本／校验见 `engine-lock.json`：

```sh
mkdir -p build/godot/candidate-windows
godot --headless --path godot --export-release 'macOS Universal'
godot --headless --path godot --export-release 'Windows x64'
```

Mac ZIP 位于 `build/godot/NineTripods-godot-macos.zip`，为包含 arm64 的 Universal 2 应用，本地 ad-hoc 签名，未公证。Windows EXE 内嵌资源，位于 `build/godot/candidate-windows/`。引擎及其第三方声明随包分发；完整 Steam 功能后置。

已批准小样保留为 `scenes/sample.tscn`；初次交付包与校验保存在原有 sample 路径及 `docs/migration/sample-verification.json`。候选资源和规则继续改进，不将新候选追溯称为用户已批准版本。
