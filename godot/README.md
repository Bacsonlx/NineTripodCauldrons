# 九鼎 · Godot 开发说明

`godot/` 是当前开发与运行工程，候选 `0.3.0-godot-candidate.1`，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility 原生 2D。动态小样已获用户试玩通过，完整汤谷已接入。Windows 实测按用户要求暂缓；旧版 npm 工程仅作为参照，Godot 运行不依赖 Node.js。

已接入普通箭、Q 穿透箭、E 固定落点三段箭雨、空格闪避、三庭42影偶共8波、两条房间分支、残碑阅读与一次性回血祭火。完整实施和平台验收状态见 [实施记录](../docs/migration/Godot迁移_实施记录.md)。

首关HUD采用左上孩子头像与状态条、左下四动作图标和实时冷却，怪物头顶显示随生命变化的描边血条。切角窄条、分行墨色底衬与随包宋体已按原型细化，见[HUD说明](../assets/ui/hud-v3/README.md)。默认房间流程正式启用蓝量、精力和药瓶：Q耗12蓝、E耗28蓝、闪避耗25精力；F 拾取药瓶即时补充，每波保底蓝瓶，原击杀／清波自动回蓝已替换；精力停用1.2秒后每秒回10。消耗、退款和跨房规则见[资源规格](../docs/product/首关_蓝量与精力规划_v0.1.md)，旧小样／迁移参照保留历史行为。

安装 `engine-lock.json` 中的 Godot 及 Python 3；导出另需匹配的官方模板。在仓库根目录执行：

```sh
python3 tools/migration/prepare_sample_assets.py
python3 tools/migration/check_godot.py
./play                            # 直接运行已集成首关
./play --test boss --mana 0        # 同一首关中的索尔专项
godot --editor --path godot        # 打开编辑器
```

资源转换保留既有图像、脚点、锚点和帧缩放；重复运行结果一致。规则检查包含旧版 55 个场景／4,250 次公开状态对比，以及小样、输入适配和布局保存重开检查。参照回放容许 0.001 世界单位数值误差；角度按同方向比较。自动检查不代表原生操作、性能或双平台验收通过。

2026-10-21 已正式接入确认的 v3 向下普通射箭上身，包含四阶段、出箭点及飞行箭尺寸标定；其余方向、跑动下肢和技能保留原素材。制作来源、绑定与测试边界见 [正式素材说明](../assets/characters/child/README.md)。

操作：WASD 移动，鼠标独立瞄准，左键点按／按住射箭，Q 穿透箭，E 箭雨，空格闪避，F 互动／过门，M 地图总览，Esc 暂停／合上残碑，R 重试，F11 或右上角按钮切换全屏。失焦暂停，窗口变化取消输入但不暂停。阅读停止游戏时间；完成终点后可以回头探索。

默认运行 `scenes/tanggu_first_level.tscn`，编辑 `scenes/rooms/` 八个独立房间。F 靠近门切房，M 切换当前房间总览／角色跟随；任务期间封门，完成后可回溯，R 重开整段流程。门连接、互动锚点和编辑限制见[房间地图说明](../docs/guides/汤谷房间地图使用说明.md)。原连续地图与旧地图保留用户编辑结果。

保存后 F5、重新打开与导出均读取当前原生场景；生成工具只允许新路径，不覆盖编辑器修改。地图使用二维世界坐标，不额外叠加等距投影，Node.js 不参与运行。

后台检查使用 headless，不启动窗口或发送系统键鼠事件。真实窗口、画面、前台性能和稳定性待用户安排后单独验收；不以后台帧率冒充前台结果。当前证据与逐项验收清单见 [候选验收记录](../docs/migration/Godot候选_验收记录.md)。

导出需安装匹配的官方模板，版本／校验见 `engine-lock.json`：

```sh
python3 tools/migration/export_godot.py
```

Mac ZIP 位于 `build/godot/NineTripods-godot-macos.zip`，为包含 arm64 的 Universal 2 应用，本地 ad-hoc 签名，未公证。Windows ZIP 位于 `build/godot/NineTripods-godot-windows.zip`，内含资源内嵌的 EXE。两包均附完整操作说明和引擎第三方声明；完整 Steam 功能后置。导出预检独立验证编辑器地图合法性，冻结规则夹具不限制用户的合法布局修改。

小样入口 `scenes/sample.tscn` 继续复用现有脚本；已批准小样的原包与源码校验保存在 sample 路径及 `docs/migration/sample-verification.json`，不把当前脚本追溯称为用户已批准版本。

## 低配机器与性能诊断

2026-10-26 首轮后台性能调优已合入：缓存障碍集合、每帧只构造一次公开快照、HUD 文本一次写入、环境物件复用几何与画布逆变换、特效精灵缓冲复用。规则、数值、碰撞、输入中断和默认画面保持不变，详见[首轮性能调优记录](../docs/architecture/九鼎_性能优化_2026-10-26.md)。

后台工作量回归位于 `tests/performance_checks.gd`，已纳入 `tools/migration/check_godot.py`；同机前后对比使用 `python3 tools/migration/perf_godot.py --repeat 3`。该脚本只测量 headless 规则＋快照成本，**不是原生 FPS**，前台画面、手感、60 秒跑射和 5 分钟稳定性仍需用户在目标机器验收。

需要降低低配机特效叠加时，可显式指定画质档位（默认 `high` 与已批准画面一致）：

```sh
./play --quality=auto    # 按帧时间自动在 512 / 256 / 96 个特效叠加间切换
./play --quality=low     # 固定低档
```

原生包把参数放在 `--` 之后，例如 `NineTripods.exe -- --quality=auto`。画质档位只减少非玩法关键的特效叠加，不改碰撞、伤害、冷却或规则时间。

## 统一试玩入口

`./play` 默认集成八房、技能与能量、索尔、血／蓝瓶与 F 补给；不需要 `--potion-drops` 等环境开关。专项使用 `./play --test boss`、`./play --test drops`、`./play --room court2`，可组合初始资源和固定种子。背包白盒用 `./play --test alpha`，后台规则用 `./play --test rules`。

参数、原生包用法与后台约束见[试玩启动命令](../docs/guides/试玩启动命令.md)。源码旧 `loot_test.tscn` 仍可作为兼容入口，但玩法与默认首关一致；旧独立 Boss 场景保留原灰盒回归，不作为新快捷命令的 Boss 入口。尚未接通的背包效果不随默认集成扩大范围。

专项药瓶规则仍可运行 `godot --headless --path godot --script res://tests/run_tests.gd -- --loot-only`。默认完整流程现在直接覆盖八波药瓶与索尔，集成、启动参数与当前证据见[统一启动实施记录](../docs/mvp/首关集成与快捷启动_实施记录_2026-10-22.md)。

## 索尔独立 Boss 灰盒

启动命令：`godot --path godot res://scenes/boss_test.tscn`。该入口复用现有玩家、技能、能耗、闪避、输入和HUD，包含1200生命索尔、横锤、往返雷锤、三点落雷及锤离手承伤提高25%。右上可切换满资源、44蓝、零蓝、40生命和零精力，切换会重开；R按当前条件重试，Esc暂停，返回汤谷按钮回到原有入口。

几何占位用于验证预告、判定、收招与反击，不是最终美术。镜头固定覆盖测试场；用户确认灰盒通过后，默认首关也已在第三庭与原出口之间接入Boss房。设计、B01—B04后台实现及后续B05—B07边界见[实施记录](../docs/mvp/首关Boss_索尔_实施记录_2026-10-22.md)。只测Boss规则可运行 `godot --headless --path godot --script res://tests/run_tests.gd -- --boss-only`；完整检查仍使用项目脚本。独立灰盒已获用户测试通过；集成后的完整流程仍待前台确认，Windows实测暂缓。

## 默认汤谷房间地图

2026-10-21 首关三庭增加为4＋5、4＋5＋6、5＋6＋7影偶，清波后1.2秒自动续波，全部清完开门；普通箭命中与Q／E／闪避动效已强化。伤害、技能判定范围和冷却保持原值，见 [调校与动效预览](../output/combat-feel-20261021/README.md)。后台通过不替代原生密集战斗性能和用户爽感验收。

当前入口采用八个手工独立房间，互通分支、房间任务和过门状态已接入。复用独立素材、路网外缘渐变、原生材质平铺和可编辑建筑。旧连续地图的素材、519→507实例历史与制作记录见[历史首关地图说明](../docs/guides/首关地图候选使用说明.md)。当前制作和验证状态见[房间地图说明](../docs/guides/汤谷房间地图使用说明.md)。

扶桑残庭已按确认的 v0.3 样板接入上沿主根、低矮灰褐残石、较小原石庭与双侧绕行通路；保留三门、三波4＋5＋6影偶。新残石使用正常导入的[纹理资源与脚点合同](../assets/environment/tanggu-ruin-stone-v1/README.md)，原型专用读图脚本不进入运行工程；其他六房的精细原型与还原仍待后续推进。
