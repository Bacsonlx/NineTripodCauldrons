# 九鼎

主 IP：九鼎。副 IP：十日。

Windows／macOS 单机动作肉鸽游戏，当前开发与运行工程为 **Godot 原生 2D＋带类型 GDScript**。采用固定等距二维战斗与分层 2.5D 表现，目标画风为皮影主导的像素质感混合风格。Electron／Phaser 工程保留为旧版参照。

## 开发与运行

安装 [engine-lock.json](godot/engine-lock.json) 锁定的 Godot 和 Python 3。导出需安装匹配的官方模板；Node.js 不作为 Godot 游戏运行依赖。在仓库根目录执行：

```sh
./play                            # 首页确认出发后进入已集成首关
./play --test level               # 开发时直达首关
./play --test boss --mana 0        # 第一关索尔房，零蓝测试
godot --editor --path godot        # 打开编辑器
python3 tools/migration/check_godot.py   # 后台导入、规则检查和完整场景启动
python3 tools/migration/export_godot.py  # 后台预检并导出双平台ZIP
```

首次准备或更新源素材后运行 `python3 tools/migration/prepare_sample_assets.py`，再执行检查。快捷参数见[试玩启动命令](docs/guides/试玩启动命令.md)，环境与导出见 [Godot 开发说明](godot/README.md)。默认启动先到原生首页，确认后进入 `godot/scenes/tanggu_first_level.tscn`，八个独立房间位于 `godot/scenes/rooms/`；门连接、任务与编辑规则见 [房间地图说明](docs/guides/汤谷房间地图使用说明.md)。原连续地图保留为历史布局。

Codex 已接入项目级 `jiuding_godot` MCP，工程查询、场景／节点／精灵编辑与安装方法见 [Godot MCP 使用指南](docs/guides/Godot_MCP使用指南.md)。

人物、道具、图标、短特效制作及已有图片切帧／对齐／打包，按 [Agent Sprite Forge 使用指南](docs/art/Agent_Sprite_Forge使用指南.md) 调用用户级 Skill。

## 当前交付与验收

完整汤谷候选为 `0.3.0-godot-candidate.1`，后续已接入八房间互通、三庭 42 影偶／8 波、索尔、野怪血／蓝瓶与 F 即时补给、残碑阅读、一次性回血祭坛、房间门任务与通行标识，以及普通箭、Q 穿透箭、E 固定落点三段箭雨、闪避和 HUD 反馈。所有已接入首关内容默认启用；背包与 Boss 正式装备奖励仍后续制作。已批准动态小样 `0.3.0-godot-sample.1` 的确认仅覆盖对应小样版本；当前改动和待验项见 [实施记录](docs/migration/Godot迁移_实施记录.md)。

- [Mac候选ZIP](build/godot/NineTripods-godot-macos.zip)：含arm64的Universal 2，本地ad-hoc签名，未公证。
- [Windows x64候选ZIP](build/godot/NineTripods-godot-windows.zip)：未签名，实机验收按用户要求暂缓。
- 两包均附完整操作说明和第三方许可；规则检查、干净构建、产物校验与待验项见 [候选验收记录](docs/migration/Godot候选_验收记录.md)。

当前默认后台测试，不打开窗口或发送系统键鼠事件；原生完整玩法、画面／手感、1080p前台跑射60秒与5分钟稳定性由用户安排后单独验收。两平台目标为平均≥58FPS、至少95%帧间隔≤20ms；构建或单平台通过不替代双平台证据。Godot已成为开发入口，交付验收仍独立跟踪。

操作：WASD移动，鼠标独立瞄准，左键点按／按住射箭，Q穿透箭，E箭雨，空格闪避，F互动／过门，M地图总览，Esc暂停／合上残碑，R重试，F11全屏。残碑阅读冻结游戏时间；祭坛一次恢复40并封顶至100，满血不消耗；完成终点后仍可回溯探索，R重开整段流程。

手柄、随机房间、正式背包与成长、Boss正式形象／奖励、正式存档、神降／签署闭环和Steam完整功能属于后续范围。旧MVP-01／02／03的独立待验项保留，不因引擎迁移自动关闭。

## 目录与维护

- `godot/scenes/`：运行场景与编辑器地图；默认 `boot.tscn` 路由至 `home.tscn` 首页，确认出发进入 `tanggu_first_level.tscn`，八个独立房间在 `rooms/`。
- `godot/scripts/combat/`、`input/`：战斗规则与输入适配；`presentation/`：相机、动作、反馈及HUD；`world/`：编辑布局。
- `godot/tests/`：公开边界检查与冻结规则对照；`godot/assets/generated/`：转换后的离线图集与锚点。
- `tools/migration/`：素材转换、Godot检查和双平台导出；`build/godot/`：本地产物。
- `assets/mvp/`、`assets/mvp02/`、`assets/mvp03/`：复用源素材、帧裁切与制作记录。
- [`docs/`](docs/README.md)：按产品、故事、技术、操作指南与实施证据分类的文档索引；`output/`：历史观察与生成证据。
- [文件与资产清理记录](docs/art/项目文件与资产清理_2026-10-27.md)：已清理副本、资产分类入口、历史材料保留原因和验证证据。
- `src/`、根 `tests/`、`scripts/`及npm配置：旧版Electron／Phaser代码、行为参照与制作工具。

战斗参数与后续属性建议见 [战斗数值方案](docs/balance/九鼎_战斗数值方案_v0.1.md)；当前动作和反馈实现以Godot为准，旧TypeScript修复过程见 [历史架构修复记录](docs/architecture/九鼎_架构深化修复记录_2026-10-19.md)。源素材沿用 [MVP-02制作记录](assets/mvp02/制作与接入记录.md)与 [MVP-03制作记录](assets/mvp03/制作与接入记录.md)。各版本历史见 [更新日志](CHANGELOG.md)。

## 旧版参照

需要复现迁移前行为时，使用Node.js 22+及根npm工具链：`npm ci`、`npm start`启动旧版，`npm run check`／`npm test`检查旧版，`npm run package`／`npm run make`生成旧版包。它们不会启动、检查或导出Godot。历史0.2.1的Windows安装包命令为 `npm run make:win-exe`，其原生待验状态见 [0.2.1修订记录](docs/mvp/MVP02_0.2.1_人物与小怪修订.md)；0.3.0旧版完整探索见 [历史实现记录](docs/mvp/MVP03_完整探索_实现与验收记录.md)。

## 文档入口

全部资料的类别、用途和历史状态见 [文档索引](docs/README.md)。当前决策的最短阅读路径如下：

- [当前Godot决策 ADR-0010](docs/adr/0010-godot-migration-direction.md)
- [架构选型结论](docs/architecture/九鼎_架构选型结论.md)
- [玩法与运行规则](docs/product/十日_玩法与运行规则.md)、[领域术语](GLOSSARY.md)
- [Godot迁移方案](docs/architecture/九鼎_Godot架构评估与迁移落地方案_2026-10-19.md)、[迁移Spec #33](docs/mvp/九鼎_Godot迁移_Spec.md)
- [实施记录与Task状态](docs/migration/Godot迁移_实施记录.md)、[64项行为映射](docs/migration/Godot行为用例映射.md)
- [世界观与故事框架 v1.2](docs/story/十日_世界观与故事框架_v1.2.pdf)

任务由当前仓库的GitHub Issues跟踪；Matt Pocock技能采用用户级全局配置。Agent执行约定见 [AGENTS.md](AGENTS.md)。
