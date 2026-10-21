# 九鼎文档索引

本页按**用途和效力**查找资料。主 IP 为「九鼎」，「十日」是副 IP；旧文件名保留，不能仅凭文件名判断是否仍是当前方案。游戏当前在 `godot/` 开发，迁移候选的双平台原生验收尚未完成。

## 当前决策从哪里读

| 要解决的问题 | 先读 | 再读 |
| --- | --- | --- |
| 产品范围、玩法与术语 | [玩法与运行规则](product/十日_玩法与运行规则.md)、[根目录术语表](../GLOSSARY.md) | [六器玩法主干](product/九鼎_六器系统_玩法主干确认稿_v0.3.md)、相关 [ADR](adr/) |
| 当前技术方向 | [架构选型结论](architecture/九鼎_架构选型结论.md) | [ADR-0010](adr/0010-godot-migration-direction.md)、[Godot 迁移方案](architecture/九鼎_Godot架构评估与迁移落地方案_2026-10-19.md) |
| 当前 Godot 工程与地图 | [Godot README](../godot/README.md)、[七房间地图说明](guides/汤谷房间地图使用说明.md) | [迁移实施记录](migration/Godot迁移_实施记录.md) |
| 故事与美术来源 | [世界观与故事框架 v1.2](story/十日_世界观与故事框架_v1.2.pdf)、[故事基线及影响](story/九鼎_故事基线_v1.2与架构影响.md) | [美术资产库](art/美术资产库_v0.1/README.md)、`assets/` 中的源文件与制作记录 |
| 实施规格与验收 | [Godot 迁移 Spec](mvp/九鼎_Godot迁移_Spec.md) 或相应 MVP Spec | [候选验收记录](migration/Godot候选_验收记录.md)、`mvp/` 中相应实施记录 |

同一主题有多份材料时，先按**用户确认的规则／Spec → ADR → 当前实施与验收记录 → 历史候选或研究材料**核对；实施记录说明现状，不自行扩大产品范围。故事 PDF 是叙事来源，其中未决建议不能替代确认规则。旧版 HTML 和票据草稿仅供追溯。

## 分类与存放

| 类别 | 位置 | 内容与边界 |
| --- | --- | --- |
| 产品规划与规则 | [`product/`](product/) | 当前玩法确认记录、六器主干；`基础玩法文档_v0.2.html` 与 `十日_道具图鉴_v0.1.html` 是旧版候选稿，冲突时以确认记录为准。战斗数值提案和已确认波次合同位于 [`balance/`](balance/)。 |
| 故事与大纲 | [`story/`](story/) | 世界观 PDF、故事基线及架构影响；`十日_游戏故事大纲.html` 是历史故事圣经。 |
| 技术规划与工程沿革 | [`architecture/`](architecture/) | 当前架构结论、Godot 迁移方案；`十日_技术架构与实现风险评估.md`、工程初始化和架构修复记录描述旧 Electron／Phaser 阶段。设计取舍和替代关系见 [`adr/`](adr/)。 |
| 功能规格、任务与验收 | [`mvp/`](mvp/) | `*Spec*` 和需求／范围讨论为规划，`*票据草稿*` 为历史拆票稿，`*实现与验收记录*`、发布记录和日志为实施证据；同目录存放是为了保持每轮 MVP 的资料链。 |
| 迁移与交付证据 | [`migration/`](migration/) | Godot 实施状态、候选验收、行为映射、Steam 核查和冻结基线。T15—T18 的完整候选原生体验与双平台实机待验，Windows 实测暂缓，因此迁移文档仍需保留。`baseline-*`、`candidate-evidence/`、`sample-evidence/` 是历史可还原证据，不随当前路径重写。 |
| 美术与其他资源 | [`art/`](art/)、[`../assets/`](../assets/) | `art/` 保存资产清单、来源／待定项和 Sprite Forge 指南；`assets/` 是源图、图集元数据及制作记录。`godot/assets/` 是游戏使用的资源，`output/` 是概念预览、生成过程与历史验证产物；不要把预览当正式资源。 |
| 使用指南 | [`guides/`](guides/) | 七房间地图、旧首关地图候选、Godot MCP、游戏开发 Skills 的操作说明；素材制作另见 [`art/Agent_Sprite_Forge使用指南.md`](art/Agent_Sprite_Forge使用指南.md)。 |
| 研究与历史 | [`research/`](research/)、[`../output/`](../output/) | 工具与技能评估、专题研究，以及按任务留存的预览、日志和验证结果；不是当前决策入口。 |
| 仓库入口与代理约定 | [根 README](../README.md)、[AGENTS.md](../AGENTS.md)、[GLOSSARY.md](../GLOSSARY.md)、[CHANGELOG.md](../CHANGELOG.md) | 分别用于运行入口、AI 取用规则、术语与版本历史。 |

## 维护规则

- 新的确认规则写入 `product/` 的当前记录，技术取舍写入 `adr/` 或 `architecture/`；功能规格与对应验收继续留在 `mvp/`，原始资源和来源留在 `assets/` 与 `art/`。
- 移动文档时更新本索引、根 README、AGENTS.md 和相关相对链接。冻结清单及验收证据中的历史路径表示当时状态，保留原样。
- 只有迁移 Spec 中的剩余验收完成并有同一最终版本的双平台实机证据后，才重新评估迁移档案的归档方式；当前不删除这些材料。
