# 九鼎

主 IP：九鼎。副 IP：十日。

Windows／macOS 单机动作肉鸽游戏，当前开发与运行工程为 **Godot 原生 2D＋带类型 GDScript**。采用固定等距二维战斗与分层 2.5D 表现，目标画风为皮影主导的像素质感混合风格。根目录 Electron／Phaser 工程保留为旧版参照。

## 开发与运行

安装 [engine-lock.json](godot/engine-lock.json) 锁定的 Godot（`4.7.2.stable.official.ed1daf0bf`）和 Python 3。导出需安装匹配的官方模板；Node.js 不作为 Godot 游戏运行依赖。在仓库根目录执行：

```sh
./play                            # 首页确认出发后进入已集成首关
./play --test level               # 直达首关进行全流程测试
./play --test boss --mana 0        # 直达索尔 Boss 房，零蓝测试
./play --room court2              # 指定房间起点（如第二庭院）
godot --editor --path godot        # 打开 Godot 编辑器
python3 tools/migration/check_godot.py   # 后台导入、规则检查、全量测试和场景启动
python3 tools/migration/export_godot.py  # 后台预检并导出双平台 ZIP
```

首次准备或更新源素材后运行 `python3 tools/migration/prepare_sample_assets.py`，再执行检查。快捷参数见[试玩启动命令](docs/guides/试玩启动命令.md)，环境与导出见 [Godot 开发说明](godot/README.md)。

- 默认启动入口为 `godot/scenes/boot.tscn`，无参数时路由至原生首页 `home.tscn`，确认出发后进入首关主场景 `godot/scenes/tanggu_first_level.tscn`。
- 首关已接入 **16 个独立房间场景**（`godot/scenes/rooms/`：13 个主线房间＋3 条支路探索），包含三组主战庭院、四类影偶、残碑阅读、营地、Boss 索尔与终点出口。门连接、任务与编辑规则见 [汤谷房间地图使用说明](docs/guides/汤谷房间地图使用说明.md)；原连续地图保留为历史布局参照。
- Codex 已接入项目级 `jiuding_godot` MCP，工程查询、场景／节点／精灵编辑与安装方法见 [Godot MCP 使用指南](docs/guides/Godot_MCP使用指南.md)。
- 人物、道具、图标、短特效制作及已有图片切帧／对齐／打包，按 [Agent Sprite Forge 使用指南](docs/art/Agent_Sprite_Forge使用指南.md) 调用用户级 Skill。

## 核心系统与当前实现

首关已接通端到端的核心肉鸽循环与战斗体系（代码已实现并完成后台自动化检查，原生窗口画面手感与双平台实机待前台最终验收）：

1. **统一 50 格背包与构筑**：
   - 首页与局内共享同一套 `AlphaState` 空间体系（装备区 6×5、祭坛区 4×4、收纳区 4×1，共 50 格）；首页完成行囊整理后，确认出发真实带入初始快照。
   - 局内按 `B` 或点击右下角 `背包 · B` 开关背包（安全营地停时整理、支持拖拽与按 `R` 旋转，非安全营地紧凑只读查看；靠近营地亦可按 `F` 整理）。
   - 战斗中支持按 `X` 容器点燃（20 秒停票占格后转为灰烬）。祭坛区支持中央 2×2 主位与外圈 12 格环位正交通电空间共鸣。
2. **16 房选择路线与神兽祝福**：
   - 清除当前房间敌人或完成探索后开门；前进房间提供两扇绑定神兽（青龙／白虎／朱雀）与阶位（初念／再念／三念）的**选择门**，过门即应用祝福演化。
   - 选择门具备分层呈现（门框＋门楣神兽浮雕＋柱面念级章数覆盖层），并自动生成双向互达回退门与保守避让。
   - 右上角小地图实时绘制当前房间的可行走多边形轮廓、玩家位置及门开启／锁闭状态。
3. **战斗、动作条与技能来源**：
   - 七槽单行 HUD（左键普攻、Q 穿透箭、E 箭雨、G 回风、T 蓄势、C 随行神兽、空格闪避），标明 `基／装／羁／兽` 来源角标、冷却与费用。
   - 技能由有效装备与羁绊自动授予（如训练弓＋布履激活 `T 蓄势`，神兽祝词激活 `C 引风／金戈／火羽`）；`G 回风` 造成起点 30 伤，`C 引风` 提供 0 蓝突进、恢复 20 精力并残留流向风带。
   - 首关真实掉落涵盖血囊、蓝囊、羊角、虎牙、鼠毫、燧火共 6 项，四符循环由清庭统一发放。
4. **角色与 Boss 呈现**：
   - 主角缩放至 2/3、统一语义腰线，接入 `back-walk-v1` 背面真实迈步八帧与 `back-proportion-v1` 背面上身比例校准；索尔 Boss 拥有 1200 生命、横锤／投锤／落雷与持续援军机制。

## 当前交付与验收边界

- [Mac 候选 ZIP](build/godot/NineTripods-godot-macos.zip)：含 arm64 的 Universal 2，本地 ad-hoc 签名，未公证。
- [Windows x64 候选 ZIP](build/godot/NineTripods-godot-windows.zip)：未签名，实机验收按用户要求暂缓。
- 两包均附完整操作说明（`试玩说明.txt`）和第三方许可；规则检查、干净构建、产物校验与待验项见 [候选验收记录](docs/migration/Godot候选_验收记录.md)。

**当前测试边界**：
当前门禁与回归为后台 headless 测试，不打开原生窗口或发送系统键鼠事件。真实键鼠手感、原生全屏／失焦行为、1080p 前台跑射 60 秒（平均≥58 FPS、至少 95% 帧间隔≤20ms）与 5 分钟稳定性属于待验项，由用户安排前台单独验收。
手柄映射、随机房间生成、跨局长线成长树、正式云存档和 Steam SDK 闭环属于后续版本规划。

操作摘要：
- **移动与战斗**：`WASD` 移动，鼠标独立瞄准，`鼠标左键` 射箭（点按／蓄力），`Q` 穿透箭，`E` 箭雨，`G` 回风，`T` 蓄势，`C` 随行神兽，`空格` 闪避。
- **互动与背包**：`F` 拾取／开门／阅读残碑／营地整理，`B` 开关背包（安全区整理／非安全区查看），营地整理中选中物品按 `R` 旋转，`X` 点燃容器。
- **界面与系统**：`M` 地图总览，`Esc` 暂停／关闭面板，`R` 重开整段流程（存活需确认），`F11` 全屏切换。

## 目录与维护

- `godot/scenes/`：运行场景与编辑器地图；`boot.tscn` 路由至 `home.tscn` 首页，确认出发进入 `tanggu_first_level.tscn`，16 个独立房间在 `rooms/`。
- `godot/scripts/combat/`、`journey/`：战斗逻辑、索尔 Boss、房间任务、切房与路线管理。
- `godot/scripts/alpha/`、`gameplay/`：50 格背包、装备与羁绊技能、祭坛共鸣、道具效果与营地面板。
- `godot/scripts/presentation/`、`world/`、`input/`：相机、HUD、单行技能条、角色动画帧驱动、传送门视觉及键鼠输入。
- `godot/tests/`：自动化边界与规则检查（`action_frame_checks.gd`、`expanded_journey_checks.gd`、`hud_checks.gd`、`portal_presentation_checks.gd` 等）。
- `tools/migration/`：素材转换、Godot 自动化检查（`check_godot.py`）与双平台导出（`export_godot.py`）。
- `assets/`：源素材、制作记录与切片数据；`godot/assets/` 为运行时游戏素材。
- [`docs/`](docs/README.md)：分类文档索引；详细开发说明见 [Godot README](godot/README.md)。
- `src/`、根 `tests/`、`scripts/`：旧版 Electron／Phaser 代码，仅作行为比对参考。

## 旧版参照

需要复现迁移前行为时，使用 Node.js 22+ 及根 npm 工具链：`npm ci`、`npm start` 启动旧版，`npm run check`／`npm test` 检查旧版。它们不负责运行、测试或导出 Godot。历史阶段记录见 [MVP-02 修订记录](docs/mvp/MVP02_0.2.1_人物与小怪修订.md) 与 [MVP-03 探索记录](docs/mvp/MVP03_完整探索_实现与验收记录.md)。

## 文档入口

全部资料的类别、用途和历史状态见 [文档索引](docs/README.md)。核心决策的最短阅读路径如下：

- [玩法与运行规则](docs/product/十日_玩法与运行规则.md)、[六器系统玩法主干](docs/product/九鼎_六器系统_玩法主干确认稿_v0.3.md)、[领域术语](GLOSSARY.md)
- [当前技术选型与 ADR-0010](docs/adr/0010-godot-migration-direction.md)、[架构选型结论](docs/architecture/九鼎_架构选型结论.md)
- [Godot 迁移方案](docs/architecture/九鼎_Godot架构评估与迁移落地方案_2026-10-19.md)、[迁移 Spec #33](docs/mvp/九鼎_Godot迁移_Spec.md)
- [首关扩展实施记录](docs/mvp/汤谷首关扩展_实施记录_2026-10-26.md)、[最新实施记录](docs/migration/Godot迁移_实施记录.md)
- [技能来源规则](docs/product/技能来源规则_装备与羁绊.md)、[背包统一重构记录](docs/mvp/背包统一重构_原型与评审_2026-10-28.md)
- [世界观与故事框架 v1.2](docs/story/十日_世界观与故事框架_v1.2.pdf)

任务由当前仓库的 GitHub Issues 跟踪；Agent 执行约定见 [AGENTS.md](AGENTS.md)。
