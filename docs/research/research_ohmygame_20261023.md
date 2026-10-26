# OhMyGame 对九鼎的适配与现有 Skills 对比

日期：2026-10-23。调研对象：[WhiteTowerAI/ohmygame](https://github.com/WhiteTowerAI/ohmygame)，以 `main` 固定提交 [`ca2df725cc4e836e1120ea1f3374e7b99021a903`](https://github.com/WhiteTowerAI/ohmygame/commit/ca2df725cc4e836e1120ea1f3374e7b99021a903) 为源码基线，对应 `v0.0.0-beta.4.13`。这是选型研究，不是安装、接入或质量认证。

后续采用（2026-10-23）：用户确认将验证分类与参考／候选／交付关系融入项目，现已通过 [AGENTS.md](../../AGENTS.md)、[执行指南](../guides/验证证据与资产追溯.md)和[药囊真实示例](../../assets/props/potion-pouches-v1/README.md)落地为文件记录约定。下文“本次未接入”等描述保留原调研范围；后续没有安装应用或新增画布界面。

## 结论

**有帮助，主要帮助设计与素材制作的组织；当前不建议用它替换九鼎的开发工作台，也不建议整包导入其 Skills。** 保留现有 Codex、Matt 工程流程、Godot 专项技能和 Sprite Forge；优先借鉴“设计文档—参考—生成候选—实际使用”的关联方式。若要试用应用，采用独立设计工作区或外部 Studio MCP 的旁路，先检验一个资产任务是否减少返工。

OhMyGame 的突出价值是把设计画布、媒体生成、代码代理和 Web 试玩组织在一个界面。九鼎当前已有明确的引擎、规则和资产合同，缺口更集中于皮影动作质量、候选比较与原生体验证据。这些问题不能仅靠增加生成入口或更换代理宿主解决。前半句是上游能力事实，后半句是结合本项目记录的适配判断。[上游介绍][omg-readme]、[当前项目基线](../../godot/README.md)、[索尔实施记录](../mvp/首关Boss_索尔_实施记录_2026-10-22.md)

## 1. 本次比较的基线

- 当前工程为 `godot/`：Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility、原生 2D、带类型 GDScript。旧 Phaser／Electron 是参照和制作工具，不作为选择新工作流的依据。[引擎锁](../../godot/engine-lock.json)、[ADR-0010](../adr/0010-godot-migration-direction.md)
- 已安装 12 项游戏开发技能：9 项 Godot 专项及 `level-design`、`game-feel`、`performance-optimization`。本轮运行 `python3 tools/gamedev_skills/verify.py`，12 项、23 个技能文件及许可／版本政策校验通过。这证明安装完整，不证明成品质量。[使用指南](../guides/游戏开发Skills使用指南.md)、[版本锁](../../tools/gamedev_skills/skills.lock.json)
- 素材采用已安装的 `generate2dsprite`／`video2dsprite`，并有项目适配：沿用宿主图片工具，保留脚点、握点、逐帧缩放及独立移动／瞄准，生成与加工分开验证。[Sprite Forge 指南](../art/Agent_Sprite_Forge使用指南.md)
- 已有项目资产管理中心，连接资产编号、需求状态和磁盘素材，支持动画预览与状态回写。源码中的关联主要来自资产编号、目录和文件名；不能把九鼎当成尚无资产管理界面的项目。[说明](../../tools/asset_center/README.md)、[数据与扫描实现](../../tools/asset_center/sync.py)
- 索尔正在进行单方向二维关节片段最小试点：现有 PNG、Node2D 枢轴、AnimationPlayer、规则快照驱动；仅待机和完整横锤，不代表全面迁移获准。此处采用本轮工作区的试点记录，尚未提交的记录不是正式视觉验收。[试点记录](../mvp/首关Boss_索尔_AI关节片段最小试点_2026-10-23.md)
- 当前只安排后台验证，Windows 实机暂缓。任何候选工具的自动试玩宣传，都不能直接关闭九鼎的原生功能、画面、性能或双平台待验项。[候选验收记录](../migration/Godot候选_验收记录.md)

本次从 `ask-matt` 路由到 `research`，以后台代理核验外部仓库，主代理核对本地技能正文和项目合同；没有进入实施、发布或新增票据流程。Matt 技能使用用户级安装与全局配置。

## 2. OhMyGame 提供什么，不能混为一谈的是什么

| 层次 | 上游提供的能力 | 对九鼎的含义 |
| --- | --- | --- |
| 应用与运行环境 | 桌面应用、Pi 代理、本地 daemon、工作区文件与会话管理 | 是另一套开发期工作台；完整使用的成本高于复制一份技能文件 |
| 设计与素材画布 | Markdown、参考图、图片／视频／3D 节点、引用关系与生成记录 | 适合方案比较、角色参考与素材探索，可作为现有资产中心的补充 |
| 制作 Skills | 游戏制作、架构、验证等任务指导 | 需要分别评估正文和依赖；通用流程可以借鉴，内部工具调用不能仅靠复制文字获得 |
| 媒体服务 | 图片、视频、3D 生成及部分 3D 后处理，按模型／服务能力调用 | 多供应商操作集中，但不等于生成结果已满足九鼎二维图集合同 |
| 预览、试玩、发布 | Web 预览、浏览器游戏操作与静态构建发布 | 对网页原型价值较高；不能等同于原生 Godot 的键鼠与画面验收 |
| Godot 接入 | 通过 Godot MCP 调用引擎工具 | 与本项目已有 `jiuding_godot` 的工具路线重叠，需逐项比较工具能力 |

该分层来自上游 README、插件及运行时源码；本次未运行其应用，界面效率和模型输出质量尚无实测。[上游介绍][omg-readme]、[插件加载测试][omg-plugin-tests]

### 内置 Skills 的具体内容

跨引擎的 Game Studio 插件包含以下 **3 项**，适用于 General Game、Godot 和交互叙事；独立的 Web Game Studio 则有 **9 项**，其加载范围是 Web Game。不能把后者全部算作 Godot 能力。[加载范围与清单][omg-plugin-tests]

| 跨引擎 Skill | 具体长处 | 可移植性与限制 |
| --- | --- | --- |
| [`game-studio`][omg-production] | 区分新建、功能、修复、打磨、重构；把核心循环、视觉方向、资产表、导入和验证串起来；美术必须实际进入运行画面，闲置文件不算交付 | 方法可借鉴；部分步骤依赖 `canvas_initialize`／`generate_canvas_media`，复制文字不会获得这些工具；尊重既有引擎、灰盒及不生成素材的任务约束，并非每次都强制重做美术 |
| [`game-foundations`][omg-foundations] | 检查模拟／呈现边界、输入阻断、稳定资源键、存档、生命周期和性能测量 | 原则容易迁移，但不是 Godot API 专项指南；与九鼎现有规则／呈现分离、输入中断和工程约定大量重叠 |
| [`game-qa`][omg-qa] | 区分冒烟、功能、回归、视觉与性能；明确构建不等于试玩、编辑器 MCP 不等于玩法证据 | 最值得选择性吸收；原生项目仍调用引擎工具或项目自动化；Web 分支才依赖 `game_use` |

Web Game Studio 的 9 项是 `web-game-studio`、`web-game-foundations`、`game-playtest`、`game-ui-frontend`、`phaser-2d-game`、`react-three-fiber-game`、`three-webgl-game`、`sprite-pipeline`、`web-3d-asset-pipeline`。本轮全文审读其中与问题直接相关的 `sprite-pipeline` 和 `game-playtest`，其余只核对目录与加载范围，未逐项评价质量。[清单][omg-plugin-tests]、[精灵制作 Skill][omg-sprite]、[Web 试玩 Skill][omg-playtest-skill]

### 自动试玩的实际边界

上游 Godot 接入采用 `npx -y @coding-solo/godot-mcp@0.1.1`，通过配置注入 `GODOT_PATH`，按需启动。其 Godot Skill 是简短的项目读取、场景操作、日志与 CLI 冒烟指引，明确说明该 MCP 不能截图或发送玩法输入。九鼎已接入同一上游路线，但本地锁定源码和适配另行维护，不能视为两个版本已完全等价。[Godot 配置][omg-godot-mcp]、[Godot Skill][omg-godot]、[九鼎工具边界](../guides/Godot_MCP使用指南.md)

源码也支持这个边界：`WEB_GAME_USE_CAPABILITIES` 的项目类型不含 `godot-game`；当前 `ProcessPlaytestDriver` 使用这组能力；工具注册还要求 driver 可用且包含当前项目类型。因此，**OhMyGame 当前不能直接补齐九鼎的原生 Godot 自动试玩缺口**。类型定义中出现 `godot`，或测试中出现 Godot `FakeDriver`，都不等于已有真实输入／截图驱动。[能力定义][omg-playtest-capability]、[实际驱动][omg-playtest-driver]、[工具注册条件][omg-tool-gate]、[FakeDriver 测试][omg-playtest-tests]

即使后续增加截图和输入工具，也仍需在用户安排前台验收后使用；截图和操作记录本身不能证明关节动作好看、战斗手感通过或 Windows 兼容完成。

### 3D 自动绑定与当前二维皮影问题

上游的 3D 模型、绑定与动画服务适合相应的三维素材任务。索尔当前问题涉及二维拆件枢轴、固定骨长、握锤点、前后遮挡、蓄力到收招的姿态连接。两者的输入和交付物不同，本次没有找到能直接替代该试点的二维皮影自动绑定管线。[媒体工具合同][omg-external-tools]、[索尔试点](../mvp/首关Boss_索尔_AI关节片段最小试点_2026-10-23.md)

### 精灵约束与可执行加工的差别

`sprite-pipeline` 要求先定帧尺寸、锚点、方向和时间，检查比例漂移、裁切及真实尺寸效果；这些要求有用。但该 Skill 目录只有说明文件，没有随附确定性切帧、去背、配准或时序加工脚本，运行接入指导面向 Phaser。[精灵制作 Skill][omg-sprite]

进一步检查已核验的图片适配路径，输入为提示词、模型、尺寸、分辨率、宽高比和参考图；没有帧数、锚点、FPS 或 alpha mask 的程序化合同。OpenAI 适配实现也未设置 `background=transparent`。这不能证明它无法生成透明图或帧表，但说明不能仅凭提示词就承诺精确帧数、透明边、锚点和动作时序。因此可以把它作为源图生成侧候选，后续仍用项目加工与 QA 管线。[图片合同与请求实现][omg-image-source]

## 3. 与现有 Skills 和工具逐项比较

下表比较的是已核对的职责、实现覆盖及项目适配，不是同模型盲测得分；“更合适”不代表已测得更高成功率或更少工时。

| 任务 | OhMyGame 的长处 | 现有方案的长处与不足 | 九鼎建议 |
| --- | --- | --- | --- |
| 从创意到可见候选 | 设计、美术、实现、检查在一个工作区连续推进，查看结果方便 | Matt 的规格、依赖票据和评审更适合已有合同的跨会话实施；视觉探索需另开候选预览，流程也更重 | 已有功能继续用 Matt；开放美术探索借鉴其画布与制作清单 |
| GDScript 与场景实现 | 代理可编辑项目，并借 MCP 操作引擎 | `godot-gdscript`、`godot-nodes-scenes` 明确覆盖类型、生命周期、节点、实例化；已按项目锁定版本和职责适配 | 保留现有专项技能；增加一份通用 Godot 入口的边际价值低 |
| 二维精灵与动画加工 | 参考驱动的多媒体生成和候选展示集中 | `generate2dsprite`／`video2dsprite` 有切帧、去背、配准、循环、重定时、QA 和打包脚本；仍不能保证复杂角色动作或分层接入成功 | 生成侧可选 OhMyGame；加工和引擎交付仍沿用 Sprite Forge 与项目合同 |
| 索尔关节与动作 | 可集中参考、候选和反馈 | `godot-animation` 加当前原生片段试点能直接表达二维枢轴与关键帧；其通用示例也不能代替解剖、承重和动作判断 | 优先完成已有最小试点的动态评审；不为 3D 展示改造当前角色路线 |
| 命中手感、关卡、性能 | 制作／检查流程能提醒关注游戏体验 | `game-feel` 有事件反馈配方，`level-design` 有指标／节奏／门控，`performance-optimization` 要求先测瓶颈；专项更贴近具体任务，但示例须做项目适配 | 保留专项技能，按当前任务加载；无需用通用制作流程覆盖它们 |
| 规则与构建回归 | 有统一验证指导，Web 可与实际操作结合 | `tdd` 约束行为测试，headless 技能约束退出码和异步等待；项目检查已有规则／输入／场景回归，导出锁定引擎与模板；仍有原生体验待验 | 继续用项目测试和导出链；额外工作台不能替代这些证据 |
| 资产管理与可追溯 | 画布直接表达参考依赖、生成过程和空间关系 | 资产中心已管理编号、需求、状态、媒体和预览，更贴近九鼎交付；当前扫描关联不等于完整生成血缘图 | 优先补充“某候选参考了谁、为何选中、交付到哪里”的关系，避免再建一份全量资产台账 |
| Web 小游戏／叙事试验 | 浏览器预览、操作和发布集成度高 | `prototype` 能快速回答一个逻辑／UI 问题，工具负担小；不提供同等的一站式媒体画布 | 独立网页探索可考虑 OhMyGame；网页试验结论不能当成 Godot 动态验收 |

本地比较已阅读相关 `SKILL.md`，不是仅凭技能描述推断。工程流程核对了 `ask-matt`、`to-spec`、`to-tickets`、`implement`、`tdd`、`code-review`；Godot／通用实践核对了语言、节点、动画、无头测试、导出、手感、关卡和性能；美术核对了两项 Sprite Forge 技能及项目适配指南。未逐条执行所有技能的参考示例。

### 现有方案也有明确短板

现有技能不是越多越好，也不是都能直接照抄。项目此前已发现并登记 `game-feel` 全局时间缩放恢复、动画方法轨产生第二份命中裁决、性能单位等通用示例问题；它们依赖本地适配规则约束。Sprite Forge 的动画生成路线和完整分层接入也没有因安装校验通过就自动获得验证。[已知问题与适配](../guides/游戏开发Skills使用指南.md)、[素材验证边界](../../tools/asset_forge/verification.json)

因此，OhMyGame 值得借鉴的是把零散制作步骤连起来、让候选和依据更易查看；现有方案更适合九鼎的部分，是已经明确的行为合同、专项实现与验证入口。两者的长处处于不同层次。

## 4. 最值得借鉴的三件事

1. **让设计要求与候选形成可追踪关系。** 例如索尔横锤候选同时指向接受母图、动作参考、当前规则时点和评审意见；改了姿态以后能知道哪些预览和交付物需要更新。重点是关系信息，不必先引入整套节点编辑器。
2. **把美术验收落实到实际使用位置。** 静态图好看以后，还要检查最小显示尺寸、透明边、方向、遮挡、动态连续性和状态切换。项目已有这些要求，可借其制作清单使每个候选的证据更集中，而不是再增加一份同义规范。
3. **让“生成完成”“加工通过”“已接入”“视觉认可”分别有依据。** 资产中心已经有候选与交付状态，实施记录也保留了待验项；增量应是给现有状态挂具体证据与参考关系，不是再建立平行状态系统。

这些是建议，不是本次实施范围；本报告不调整资产字段、现有 UI 或正式流程。

## 5. 接入选择与成本

| 方式 | 新增负担 | 适合度 |
| --- | --- | --- |
| 阅读并吸收制作／评审方法 | 少量文档适配，无新增运行环境 | 当前优先；只在实际任务暴露缺口时吸收具体条目 |
| 复制若干 Skill | 核对许可、内部链接与工具依赖，维护固定来源和本地适配 | 可考虑少量纯方法内容；不能整包复制后假定内部工具可用 |
| 运行独立 OhMyGame 设计工作区 | 安装应用、管理工作区与媒体服务，导出候选再按九鼎合同接入 | 有持续多媒体探索需求时小范围试用 |
| 保留现有代理，经外部 Studio MCP 使用其能力 | 仍需 OhMyGame 运行、项目配置与模型能力；还需验证工具和路径边界 | 比迁移全部工作流更容易隔离，但本轮未联通验证 |
| 把当前工程整体迁入新工作台 | 重新验证规则入口、技能发现、素材路径、工作区管理和构建行为 | 当前收益证据不足，暂不推荐 |

外部 `ohmygame-studio` MCP 已有实现及测试，可以保留现有编码代理，仅调用其媒体和画布能力。它需要运行中的应用／daemon、MCP 开关及启动器、明确绑定的 OhMyGame 项目。接口包含图片／视频／3D、语音／音效／音乐生成、画布检查／初始化／生成、可用范围内的 `game_use` 和叙事节点工具，以及项目／异步任务查询；它有写入和生成能力，不能当成只读资源浏览器。它不透传 Godot 等插件 MCP，所以本项目现有 `jiuding_godot` 仍需保留。[外部接入合同][omg-external-doc]、[工具清单实现][omg-external-tools]、[桥接 Skill][omg-bridge-skill]

这些接入工具有项目绑定、令牌撤销、慢任务与取消等测试；测试证明接口契约有覆盖，不能证明模型产物质量。生成任务未完成时应继续查询原任务，避免重复发起；外部文件编辑也不在工作台自身的 Undo 范围内。[接入测试][omg-external-tests]、[使用边界][omg-external-doc]

完整应用源码开发环境要求 Bun ≥1.4.2、Node.js ≥22.19；普通安装包另有打包运行环境，不能把源码开发要求直接当成用户必须手动安装的条件。媒体能力还受所选服务的账号、模型和额度限制。它们属于制作期依赖；如只使用导出的 PNG 等资产，不必把工作台加入 Godot 游戏运行环境。[依赖声明][omg-package]、[上游运行说明][omg-readme]

维护状态也需要区分：外部 MCP 是 2026-10-22 的 beta.4.12 新增入口，次日 beta.4.13 又扩展了项目和画布导入导出。适合固定版本做隔离验证，尚无本项目使用收益证据。仓库 CI 包含多平台 TypeScript／应用测试，但未安装 Godot 或执行九鼎规则集，不能据此认定原生 Godot 双平台验证通过。[发布记录][omg-changelog]、[CI 定义][omg-ci]

上游软件为 Apache-2.0；名称和标志另有声明。复用源码或技能应保留适用的许可／通知，第三方媒体服务产物还需按实际来源记录条款。软件开源本身不能证明每张生成资产的来源与可用权利。[许可证][omg-license]、[上游介绍][omg-readme]

## 6. 如后续试用，建议只回答一个问题

**问题：它的参考关联与候选画布，能否让一个二维道具任务更容易评审和追溯？** 使用现有药囊等非核心资产的副本，在独立工作区放入已接受参考和两份已有候选；第一轮不需要新增模型调用。

| 检查点 | 可观察的通过条件 |
| --- | --- |
| 来源 | 能从候选追到输入参考、制作说明和原始文件，而非只留下截图 |
| 比较 | 能在游戏实际显示尺寸下比较候选，明确记录选中或退回原因 |
| 可回收 | 文件可独立取回，保留可用的来源／提示词记录；无需工作台在线才能在九鼎使用 |
| 项目兼容 | 仍能绑定九鼎资产编号与既有目录，不改变脚点、握点、画布和规则时序 |
| 实际收益 | 记录整理步骤、人工修正和重复维护，和现有资产中心的同类任务比较 |

若只是重复展示已有预览，或者需要维护第二份完整资产台账，就停止扩展接入。若证实能减少整理与沟通，再考虑单项媒体生成或外部 MCP；不由此自动进入主角全套动作、地图重做或二维／三维路线迁移。

## 7. 调研与验证边界

本次审读公开仓库一手文档、插件／运行时实现与相关测试，并核对本地项目文档、代表性技能正文及现有工具代码。仓库仍处于 beta，能力判断绑定上述提交；未把星标、演示视频或测试文件数量当作质量证明。部分搜索缓存仍停留在更早版本，最新状态与源码判断以公开 GitHub API 和固定提交原文为准。

置信度：插件范围、工具门控、依赖及文件合同有源码与测试支持；对九鼎的适配结论是工程判断；实际接入稳定性、媒体质量、动作成功率、成本与节省工时仍未知。画布的文件化合同和参考关系值得关注，但新增画布文档不应成为取代现有确认规则／Spec／ADR 的第二套权威来源。[画布文件合同][omg-canvas]

本次只新增研究报告和文档索引入口。没有安装 OhMyGame、执行上游脚本、接入模型服务、生成素材、启动原生窗口、调用键鼠或改动 Godot 代码。本地仅复核了 12 项游戏技能安装完整性；没有运行游戏回归或导出，因为本次不涉及实现变化。没有进行同模型 A/B、成功率、费用或工时基准，不能给出定量效率承诺。

[omg-readme]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/README.md
[omg-license]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/LICENSE
[omg-production]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/game-studio/skills/game-studio/SKILL.md
[omg-foundations]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/game-studio/skills/game-foundations/SKILL.md
[omg-qa]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/game-studio/skills/game-qa/SKILL.md
[omg-plugin-tests]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/test/bundled-plugins.test.ts#L93-L129
[omg-sprite]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/web-game-studio/skills/sprite-pipeline/SKILL.md
[omg-playtest-skill]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/web-game-studio/skills/game-playtest/SKILL.md
[omg-godot]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/godot/skills/godot-game/SKILL.md
[omg-godot-mcp]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/plugins/godot/mcp.json
[omg-playtest-capability]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/src/shared/playtest.ts#L8-L34
[omg-playtest-driver]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/src/daemon/playtest-driver.ts#L20-L27
[omg-tool-gate]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/src/daemon/agent-tools.ts#L589-L591
[omg-playtest-tests]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/test/playtest-tools.test.ts#L129-L147
[omg-image-source]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/src/daemon/openai-image.ts#L11-L59
[omg-external-doc]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/docs/external-agents.md
[omg-external-tools]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/src/daemon/external-mcp.ts#L26-L61
[omg-external-tests]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/test/external-mcp.test.ts
[omg-bridge-skill]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/integrations/skills/ohmygame-studio/SKILL.md
[omg-canvas]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/docs/canvas-agent.md
[omg-package]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/package.json
[omg-changelog]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/CHANGELOG.md
[omg-ci]: https://github.com/WhiteTowerAI/ohmygame/blob/ca2df725cc4e836e1120ea1f3374e7b99021a903/.github/workflows/ci.yml
