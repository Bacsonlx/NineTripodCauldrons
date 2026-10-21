# 九鼎 · Godot 开发说明

`godot/` 是当前开发与运行工程，候选 `0.3.0-godot-candidate.1`，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility 原生 2D。动态小样已获用户试玩通过，完整汤谷已接入。Windows 实测按用户要求暂缓；旧版 npm 工程仅作为参照，Godot 运行不依赖 Node.js。

已接入普通箭、Q 穿透箭、E 固定落点三段箭雨、空格闪避、三庭42影偶共8波、两条房间分支、残碑阅读与一次性回血祭火。完整实施和平台验收状态见 [实施记录](../docs/migration/Godot迁移_实施记录.md)。

安装 `engine-lock.json` 中的 Godot 及 Python 3；导出另需匹配的官方模板。在仓库根目录执行：

```sh
python3 tools/migration/prepare_sample_assets.py
python3 tools/migration/check_godot.py
godot --path godot                 # 运行完整汤谷
godot --editor --path godot        # 打开编辑器
```

资源转换保留既有图像、脚点、锚点和帧缩放；重复运行结果一致。规则检查包含旧版 55 个场景／4,250 次公开状态对比，以及小样、输入适配和布局保存重开检查。参照回放容许 0.001 世界单位数值误差；角度按同方向比较。自动检查不代表原生操作、性能或双平台验收通过。

2026-10-21 已正式接入确认的 v3 向下普通射箭上身，包含四阶段、出箭点及飞行箭尺寸标定；其余方向、跑动下肢和技能保留原素材。制作来源、绑定与测试边界见 [正式素材说明](../assets/characters/child/README.md)。

操作：WASD 移动，鼠标独立瞄准，左键点按／按住射箭，Q 穿透箭，E 箭雨，空格闪避，F 互动，Esc 暂停／合上残碑，R 重试，F11 或右上角按钮切换全屏。失焦暂停，窗口变化取消输入但不暂停。阅读停止游戏时间；三组肃清后可以回头探索。

默认运行 `scenes/tanggu_first_level.tscn`，编辑 `scenes/rooms/` 七个独立房间。F 靠近门切房，M 切换当前房间总览／角色跟随；任务期间封门，完成后可回溯，R 重开整段流程。门连接、互动锚点和编辑限制见[房间地图说明](../docs/汤谷房间地图使用说明.md)。原连续地图与旧地图保留用户编辑结果。

保存后 F5、重新打开与导出均读取当前原生场景；生成工具只允许新路径，不覆盖编辑器修改。地图使用二维世界坐标，不额外叠加等距投影，Node.js 不参与运行。

后台检查使用 headless，不启动窗口或发送系统键鼠事件。真实窗口、画面、前台性能和稳定性待用户安排后单独验收；不以后台帧率冒充前台结果。当前证据与逐项验收清单见 [候选验收记录](../docs/migration/Godot候选_验收记录.md)。

导出需安装匹配的官方模板，版本／校验见 `engine-lock.json`：

```sh
python3 tools/migration/export_godot.py
```

Mac ZIP 位于 `build/godot/NineTripods-godot-macos.zip`，为包含 arm64 的 Universal 2 应用，本地 ad-hoc 签名，未公证。Windows ZIP 位于 `build/godot/NineTripods-godot-windows.zip`，内含资源内嵌的 EXE。两包均附完整操作说明和引擎第三方声明；完整 Steam 功能后置。导出预检独立验证编辑器地图合法性，冻结规则夹具不限制用户的合法布局修改。

小样入口 `scenes/sample.tscn` 继续复用现有脚本；已批准小样的原包与源码校验保存在 sample 路径及 `docs/migration/sample-verification.json`，不把当前脚本追溯称为用户已批准版本。

## 默认汤谷房间地图

2026-10-21 首关三庭增加为4＋5、4＋5＋6、5＋6＋7影偶，清波后1.2秒自动续波，全部清完开门；普通箭命中与Q／E／闪避动效已强化。伤害、技能判定范围和冷却保持原值，见 [调校与动效预览](../output/combat-feel-20261021/README.md)。后台通过不替代原生密集战斗性能和用户爽感验收。

当前入口采用七个手工独立房间，互通分支、房间任务和过门状态已接入。复用独立素材、路网外缘渐变、原生材质平铺和可编辑建筑。旧连续地图的素材、519→507实例历史与制作记录见[历史首关地图说明](../docs/首关地图候选使用说明.md)。当前制作和验证状态见[房间地图说明](../docs/汤谷房间地图使用说明.md)。
