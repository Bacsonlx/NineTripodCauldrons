# 九鼎

主 IP 为「九鼎」，副 IP 为「十日」。所有回复使用中文。

## Agent skills

### Issue tracker

运行工程技能前读取 `~/.agents/mattpocock-config/issue-tracker.md`，由当前 `git remote` 识别目标仓库。Matt Pocock 技能使用用户级安装及全局配置。

### Triage labels

使用 `~/.agents/mattpocock-config/triage-labels.md` 的标签映射。

### Domain docs

单上下文：改动领域规则前读取根目录 `GLOSSARY.md` 和相关 `docs/adr/`；消费方式见 `~/.agents/mattpocock-config/domain.md`。

### Game development skills

编写 Godot 脚本、场景、资源、测试、HUD、动画、音频、Shader、导出，或开展关卡、手感、性能任务前，读取 [游戏开发 Skills 使用指南](docs/guides/游戏开发Skills使用指南.md)，按任务选择 `.agents/skills/` 中的最少技能并读取其 `SKILL.md`；参考文件按需加载。主工程固定为 `godot/`，版本读取 `godot/engine-lock.json`，旧 Phaser 文件不参与引擎选择。

项目约束及指南中的适配规则优先于上游示例；技能互相提及不代表其已安装，也不构成扩展玩法范围的授权。安装完整性检查：`python3 tools/gamedev_skills/verify.py`。

## Project context

先按 [文档索引](docs/README.md) 判断资料类别和状态。架构、范围或玩法改动前读取 [架构选型结论](docs/architecture/九鼎_架构选型结论.md)，具体已确认规则见 [玩法与运行规则](docs/product/十日_玩法与运行规则.md)。`docs/story/` 的历史大纲、`docs/product/` 的旧版 HTML、`docs/mvp/` 的草稿及 `output/` 的观察材料不自动成为实现要求；资源原件和来源记录见 `assets/` 与 `docs/art/`。移动文档时同步更新索引和站内链接。

### Godot project

迁移、工具链或迁移验收改动前，读取 [ADR-0010](docs/adr/0010-godot-migration-direction.md) 和 [Godot 迁移方案](docs/architecture/九鼎_Godot架构评估与迁移落地方案_2026-10-19.md)；以 Q1—Q9 的已确认决策为范围依据，后续商业版预案按各自规格实施。

汤谷迁移实施、拆票和验收以 [Godot 迁移 Spec](docs/mvp/九鼎_Godot迁移_Spec.md)（[GitHub #33](https://github.com/Bacsonlx/NineTripodCauldrons/issues/33)）为合同；已确认测试边界为规则输入／时间／可观察状态、操作中断输入适配和双平台原生体验。

- 当前开发与运行工程为 `godot/`，采用原生 2D＋带类型 GDScript；启动用 `godot --path godot`，版本与模板以 `godot/engine-lock.json` 为准，编辑／测试／导出见 [Godot README](godot/README.md)。
- 完整汤谷已接入 Godot，动态小样已获用户确认；当前功能与待验项以 [实施记录](docs/migration/Godot迁移_实施记录.md)和[候选验收记录](docs/migration/Godot候选_验收记录.md)为准。
- 内容布局由 Godot 编辑器承载，用户调整与验收，AI 负责脚本和批量配置。本集成分支采用 `godot/scenes/rooms/` 十六个独立房间（十三主线＋三支路），雷庭前径后为索尔 Boss 房与原出口；运行入口 `tanggu_first_level.tscn`。扩展候选、原生试玩与正式采用状态见[首关扩展实施记录](docs/mvp/汤谷首关扩展_实施记录_2026-10-26.md)。门连接、任务与编辑方式见 [房间地图说明](docs/guides/汤谷房间地图使用说明.md)。原连续地图 `tanggu_first_level_map.tscn` 和旧 `tanggu_map.tscn` 保留用户编辑结果，冻结规则夹具仅用于回归参照。
- `src/`、根 `tests/`、npm／Electron／Phaser 工具链保留为旧版参照与迁移制作工具；新增玩法在 Godot 实现，Node.js 不作为游戏运行依赖。
- 手柄、正式肉鸽闭环、存档和 Steam 完整功能属于后续范围；构建、规则测试或单平台通过分别记录，不能替代双平台实机完成证据。

### Godot MCP

使用 `jiuding_godot` 查询工程、编辑场景／节点／精灵或排查 UID 前，读取 [Godot MCP 使用指南](docs/guides/Godot_MCP使用指南.md)。配置和依赖安装位于 `tools/godot_mcp/`；当前仅后台操作，场景修改后仍执行下述项目检查。

### Sprite Forge

制作人物、道具、图标、短特效，或对已有图片切帧、对齐、打包时，先读取 [Agent Sprite Forge 使用指南](docs/art/Agent_Sprite_Forge使用指南.md)，按任务使用用户级 `generate2dsprite`／`video2dsprite`。安装锁与依赖位于 `tools/asset_forge/`；生图路线、角色分层合同及加工验收以该指南为准。

制作、修订或接入资产前，读取[资产追溯](docs/guides/验证证据与资产追溯.md#资产追溯)，在现有素材 README 维护“参考 → 候选／修订 → 选择依据 → 正式源文件 → 运行引用 → 验证证据”；用户决定和 AI 评审理由分别记录。

### Verification

修改或验收游戏前，读取[验证证据](docs/guides/验证证据与资产追溯.md#验证证据)，选择相关检查并在任务记录及交付结论中分类报告构建、逻辑、运行、交互、视觉、性能的结果与证据；未验证／不适用说明原因。构建通过不等于试玩通过，视觉确认注明对象、版本和范围。

修改 Godot 代码后运行 `python3 tools/migration/check_godot.py`（导入、规则测试、完整场景）；规则／输入可单独运行 `godot --headless --path godot --script res://tests/run_tests.gd`。资源与呈现改动同时检查干净导入及对应原生包；导出用 `python3 tools/migration/export_godot.py`。纯文档改动检查链接、命令与状态一致性。

当前测试仅在后台执行，不打开原生窗口或发送系统键鼠事件；用户安排前台验收后再测真实窗口、画面与性能。Windows 实测暂缓，双平台验收仍按迁移 Spec 记录；开发入口采用 Godot 不代表实机验收通过。更新实施记录中的 Task 与待验项，设备、指标及采样边界以迁移方案为准。

仅修改旧版 TypeScript／Electron 参照时运行 `npm run check`；涉及其构建或进程入口再运行 `npm run package`，并说明实际平台。npm 检查不覆盖 Godot。
