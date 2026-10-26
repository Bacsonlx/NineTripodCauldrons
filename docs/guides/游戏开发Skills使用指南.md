# 九鼎：游戏开发 Skills 使用指南

2026-10-20 引入 12 项项目级技能，来自 [awesome-gamedev-agent-skills 固定提交](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/tree/0a70cfc64672d512c5b5b6006b5dcb5cf90dbdbd)。筛选理由、未引入项及已知问题见 [评估记录](../research/九鼎_游戏开发Skills接入评估_2026-10-20.md)。它们是开发参考，不进入 Godot 运行依赖。

## Agent 执行顺序

1. 从当前任务确认目标与完成标准。主工程是 `godot/`；读取 `godot/engine-lock.json` 后选择 API。项目规则、范围、正式地图和验证要求以根 [AGENTS.md](../../AGENTS.md) 及其指向的规格为准。
2. 从下表选择通常 1—3 项技能，说明“本次加载哪些、解决什么问题”，打开对应 `SKILL.md`。同一任务已读过的正文可复用；仅在任务转向时重新选择。
3. 根据具体问题再打开技能内的 `references/`。技能中的 Related skills 是候选链接，不是自动安装／全量加载指令；未安装项需要时先重新评估。
4. 在原模块内完成最小改动，按下文适配规则处理示例。运行根 AGENTS 要求的检查，按[验证证据指南](验证证据与资产追溯.md#验证证据)分类记录结果、证据与待验边界；资产改动同时维护该指南的追溯记录。

## 按任务选择

| 任务／触发条件 | 读取技能 | 九鼎中的用途与完成标准 |
| --- | --- | --- |
| 编写／修复 `.gd`，类型、生命周期、信号语法 | [godot-gdscript](../../.agents/skills/godot-gdscript/SKILL.md) | 带类型 GDScript；维持现有规则调用顺序，通过项目后台检查 |
| `.tscn` 结构、实例化、节点路径、释放对象 | [godot-nodes-scenes](../../.agents/skills/godot-nodes-scenes/SKILL.md) | 编辑器场景与可复用节点；保存、重开和运行保持布局一致 |
| `.tres`、自定义 Resource、共享数据／加载 | [godot-resources](../../.agents/skills/godot-resources/SKILL.md) | 只在任务确实需要 Inspector 数据资产时使用；实例状态不污染共享模板 |
| 规则回归、CI、无头测试挂起或错误退出码 | [godot-gdscript-headless-testing](../../.agents/skills/godot-gdscript-headless-testing/SKILL.md) | 扩展现有 `godot/tests/run_tests.gd`；失败能返回非零，等待有超时 |
| HUD、暂停／阅读面板、缩放、Theme、点击穿透 | [godot-ui-control](../../.agents/skills/godot-ui-control/SKILL.md) | Godot 原生 Control／Container；装饰不吞点击，布局适应目标窗口 |
| 序列帧播放、Tween、动画状态或 UI 过渡 | [godot-animation](../../.agents/skills/godot-animation/SKILL.md) | 保留人物分层、独立移动／瞄准和既有帧元数据；正确处理中断 |
| 音效播放、Music／SFX 总线、音量／静音 | [godot-audio](../../.agents/skills/godot-audio/SKILL.md) | 实现已有授权音频需求；重复播放、停止、重试与静音符合任务规格 |
| `.gdshader`、描边／溶解／受击材质 | [godot-shaders](../../.agents/skills/godot-shaders/SKILL.md) | 限原生 2D `canvas_item` 与 Compatibility；效果需原生画面验证 |
| 导出模板、预设、资源遗漏、Mac／Windows 包 | [godot-export](../../.agents/skills/godot-export/SKILL.md) | 复用项目导出脚本，锁定模板；分别登记构建与实机结果 |
| 汤谷主路／支路、遭遇节奏、引导与软锁检查 | [level-design](../../.agents/skills/level-design/SKILL.md) | 根据实际移动／攻击距离评审；用现有场景节点表达布局，保留用户编辑 |
| 普通箭等已实现事件的视听反馈与手感调校 | [game-feel](../../.agents/skills/game-feel/SKILL.md) | 从单事件候选做比较；规则、伤害、冷却、击退和瞄准保持规格一致 |
| 掉帧、卡顿、内存增长或已有性能证据分析 | [performance-optimization](../../.agents/skills/performance-optimization/SKILL.md) | 先定位瓶颈，再改一个主因；有同场景、同设备的前后证据 |

语言任务可单用 `godot-gdscript`，不用每次搭配所有基础技能。例如 HUD 布局只加载 `godot-ui-control`；只有新增动画才加 `godot-animation`。

## 上游示例的项目适配

- **规则与呈现：** 保持 `combat/training_room.gd` 裁决、`input/player_controls.gd` 输入适配、`presentation/` 呈现的职责。生命周期建议不触发规则时钟迁移；动画方法轨、Area 回调或 Tween 完成信号不另行判定伤害。Autoload／Resource 是可选工具，不借引入技能重构现有模块。
- **场景与关卡：** 当前默认采用 `godot/scenes/rooms/` 独立房间和 `world/` 环境节点，门连接及任务见[房间地图说明](汤谷房间地图使用说明.md)；原连续地图保留作历史参照。`level-design` 中的跳跃数值、格子、存档点仅是其他类型游戏的示例；本项目按通路、闪避距离、射程、视野和门的先后条件评审。技能提到 TileMap 时继续使用现有场景方案。
- **动画与美术：** 优先保留现有离线帧、脚点、腰带点、握点与缩放；简单播放不强加 AnimationTree。生成、切帧和打包仍从 [Sprite Forge 指南](../art/Agent_Sprite_Forge使用指南.md) 进入；Godot 动画技能只负责引擎接入。
- **手感：** `game-feel` 的 hit-stop 示例直接改 `Engine.time_scale` 并恢复到 `1.0`，没有处理重叠和原缩放。采用已有规则事件做表现候选；涉及停顿或输入缓存的改动先明确规则并验证暂停、阅读、失焦、重试、连续触发及取消行为。震动只作用视觉，不移动碰撞体，也须校核鼠标瞄准。上游“5—8 层反馈”、弹性缩放和设置开关不是必交功能。
- **音频与 Shader：** 音乐时间不能取代规则时间；音量总线名先核实，音源保留来源。Shader 的 `TIME`／动画行为须单独核对暂停与失焦；空间 Shader／3D 示例不用于当前项目。API 与单位从锁定引擎和官方文档核实，示例不当作已验证实现。
- **测试：** 新检出先导入，再运行已有测试。扩展原 runner，不因上游示例另建一套测试框架。`assert()`／`push_error()` 不单独充当 CI 成败依据；显式退出码、异步超时和外层进程超时分别处理。
- **导出：** 根目录执行 `python3 tools/migration/export_godot.py`，具体命令见 [Godot README](../../godot/README.md)。上游参考表把 `--quit-after` 写成 frames／seconds，正文则说主循环次数；使用本机 `godot --help` 核对，不能把它当秒表。签名与分发状态按实际产物记录。
- **性能与前台：** 上游“打开 Profiler／试玩”不越过项目当前仅后台验证的边界。用户安排前台前，可分析已有采样、做后台诊断和准备测量方案；无头模式的结果不作为真实 FPS。池化、LOD、材质共享先有证据再采用，共享材质还须避免实例间参数串改。`Performance.TIME_PROCESS` 的单位为秒，报告毫秒需乘 1000，见 [官方 Performance 文档](https://docs.godotengine.org/en/stable/classes/class_performance.html#class-performance-constant-time-process)。

## 可直接交给 Agent 的示例

- “修复 GDScript 类型错误：先读 `$godot-gdscript`，保持规则时钟和行为不变，运行项目后台检查。”
- “使用 `$godot-ui-control` 修复暂停面板在窄窗口的布局和点击穿透，不扩大输入设备范围。”
- “使用 `$godot-animation` 接入已确认的四向帧，保留腿／上身／弓的锚点与独立瞄准，验证重试和阅读中断。”
- “使用 `$level-design` 审查汤谷主路、两条支路和内侧门：只输出引导、节奏与可达性问题及证据，暂不修改正式地图。”
- “使用 `$game-feel` 和 `$godot-animation` 做普通箭命中的表现候选，沿用现有伤害、冷却和击退，不引入全局时间缩放。”
- “使用 `$godot-gdscript-headless-testing` 为这次规则修复增加回归，确保反例失败返回非零，复用现有 runner。”
- “使用 `$performance-optimization` 分析已有原生采样，列出瓶颈证据与单项修复方案，当前只在后台验证。”

## 安装、更新与跨 Agent 使用

Codex 的项目级目录为 `.agents/skills/<名称>/`，下个回合可用 `$技能名` 触发；当前回合也可按上表路径直接读取。未发现新条目的会话可重新打开。其他 Agent 若不原生发现该目录，先让它读取根 AGENTS 和本指南，再按相对路径读取技能；本次未配置其他宿主的自动发现目录。

Matt Pocock 的工程流程继续使用用户级安装；本次没有复制或修改它们。`ask-matt` 用来选择工程流程，技能选取参考本指南：实现时搭配具体 Godot 技能，回归使用项目检查，方案与评审继续沿用已有工程流程，不自动新增票据或发布操作。

仓库保存上游原文完整目录、[版本与 SHA-256 锁](../../tools/gamedev_skills/skills.lock.json)、[LICENSE](../../tools/gamedev_skills/LICENSE)、[NOTICE](../../tools/gamedev_skills/NOTICE) 及上游版本政策。检查：

```sh
python3 tools/gamedev_skills/verify.py
```

已有项目副本随仓库检出即可使用，不依赖远程下载。需要重新安装缺失目录时，使用 `skill-installer` 官方 helper，并明确 `--dest "$PWD/.agents/skills"`、锁文件中的 `--ref` 和所选 `--path`；已有同名目录先比较，helper 会拒绝覆盖。升级时先在临时目录安装新提交，审读差异与引用文件，重核已知问题，再更新选定目录、锁和验证记录。保持上游原文不变，项目适配写在本指南。

安装校验只证明文件、元数据和内部引用完整；本次额外在临时工程核验了测试示例。各技能对实际任务的收益及原生画面仍需随任务登记，详见 [verification.json](../../tools/gamedev_skills/verification.json)。
