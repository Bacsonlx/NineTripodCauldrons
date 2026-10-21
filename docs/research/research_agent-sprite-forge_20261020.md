# Agent Sprite Forge 对九鼎的适配评估

2026-10-20 · 来源：`0x0funky/agent-sprite-forge` · 核对版本：`v0.4.0`，main 提交 [`5324342`](https://github.com/0x0funky/agent-sprite-forge/commit/5324342fdfab72430f4e9604f3fe427009f8596d)（2026-10-06）。本轮只读源码、文档及社区反馈，未安装、运行候选脚本、生成素材或导入 Godot。

**结论：值得列入素材制作候选，优先试用静态道具、特效与已有帧的整理；暂不作为主角全套动画或正式地图的默认生产管线。** 它比通用游戏开发 Skill 更贴近九鼎的资产问题，但“能导出 Godot 格式”与“适配九鼎当前工程和画风”之间还有验证工作。

## 1. 评估依据与当前项目状态

本次采用当前工作区，而非上一轮调研时的历史状态：主工程已经是 `godot/`，锁定 Godot `4.7.2`、Compatibility 原生 2D；完整汤谷已接入，动态小样已获确认，双平台最终原生验收仍独立跟踪。见 [Godot README](../../godot/README.md)、[引擎锁定](../../godot/engine-lock.json)、[ADR-0010](../adr/0010-godot-migration-direction.md)。

美术仍为皮影主导、像素质感为辅，动画使用离线序列帧／图集；角色移动与瞄准独立，不能由动画重定义碰撞、攻击时点或中断行为。依据为[架构结论](../九鼎_架构选型结论.md)、[动作与状态需求](../art/美术资产库_v0.1/动作与状态需求.md)及当前[角色呈现代码](../../godot/scripts/presentation/training_scene.gd)。本报告不改变这些规则，也不安排前台测试。

置信度：Skill 能力、导出方式与已知限制有一手文档／源码支持；社区案例有用户原帖支持；九鼎适配结论属于工程判断。没有运行素材制作实验，不能给出成功率、节省工时或正式质量保证。

## 2. 它是一套素材管线，包含五个 Skill

| Skill | 核对到的职责 | 九鼎建议 |
| --- | --- | --- |
| [`generate2dsprite`][sprite] | 母图、道具／图标／特效帧表、抠图、切帧、对齐、尺寸与导出 | **优先候选**：静态道具、短特效、已有帧整理 |
| [`video2dsprite`][video] | 母图生成逐动作视频，再去背、配准、选循环、重定时及打包 | **实验性**：优先简单敌人或环境小循环，暂不接管主角 |
| [`generate2dmap`][map] | 地面、物件包、场景层与地图数据、可达性检查及引擎导出 | **局部可用**：场景素材与独立新区域草稿；不替换汤谷正式布局 |
| [`generate2dmedia`][media] | 图像／视频服务路由、账号能力检查、费用记录 | 生成时才涉及；沿用现有原生图像工具可减少额外接入 |
| [`codeart2d`][codeart] | 代码绘制像素／SVG、离线绑定动画、程序特效与地形 | 简单纹样、占位物或可精确描述的效果按需参考；不默认重画角色 |

这套 Skill 并不只适用于像素画：当前版本默认 HD，另提供像素处理路线。对九鼎应先评估 HD 是否保留皮影细线、镂空、纹样和边缘，不应仅因项目含“像素质感”就统一减色或最近邻缩放。[精灵 Skill][sprite]

它提供了实际加工脚本，而不只是提示词。价值主要是把生成结果整理成可检查的资产；素材是否好看、动作是否正确仍需目视和游戏内验收。[脚本目录][sprite-scripts]、[引擎导出实现][export-source]

## 3. 为什么部分适合，为什么不能直接全量采用

### 3.1 贴合点：离线资产、锚点与质量检查

工具支持共享锚点、统一画布与跨动作比例，能输出 PNG 图集、Godot SpriteFrames 及 AnimatedSprite2D 场景；源码也会重新读回导出结果进行结构与数据比较。这些能力与九鼎的离线图集、脚点和资源交付需求相关。[导出说明][export-doc]、[实现][export-source]

特别值得借鉴的是其“数值 QA 不等于视觉通过”的边界：质量报告与预览能发现症状，不能证明身份、动作和美术质量。[已知限制][limits]

### 3.2 主角分层是关键接入成本

九鼎当前使用 `legs`、`torso`、`bow` 等分层 Sprite2D，由状态分别选择腿部移动方向和上身瞄准／攻击帧；`pose()` 使用现有图集中的逐帧原点与缩放。资产制作脚本把这些信息转成项目自己的 `atlas.json`。[呈现代码](../../godot/scripts/presentation/training_scene.gd)、[转换脚本](../../tools/migration/prepare_sample_assets.py)

ASF 的默认角色路线是“一张已批准母图，每个动作一段视频”，而导出器以共享锚点的动画片段为单位。**这不自动给出九鼎所需的四方向分层、持弓握点、上身与腿的组合关系。** 它可以处理已有图片，但本次没有找到自动解决上述项目结构的专用流程。[角色流程][video]、[导出实现][export-source]

因此不能直接把一个完整 AnimatedSprite2D 场景替换现有主角。若后续采用，需要按现有分层合同制作，或另行论证呈现方案，不能为了适应工具改掉独立瞄准。

### 3.3 动画应服从规则，默认动作参数不能成为需求

上游含通用动作时长、循环与播放建议，也带有 hit-stop 和前摇等运行时指导。它们是工具作者的默认设计，不是九鼎已确认数值；尤其不能从新动画事件反向触发实际扣血、射箭或修改模拟时钟。[运行时指导][runtime]

适合的接法是规则状态驱动帧选择，必要时将视觉释放帧对齐现有技能时点。PNG／图集即可使用，不需要引入其 JavaScript 播放器、透明视频运行时或 Sprite3D。

### 3.4 地图导出格式不同，不能覆盖用户编辑结果

ASF 地图导出包含 TileMapLayer、Sprite2D、StaticBody2D、Marker2D 等；其导航验证对应自己的 `map_bundle`／`forge_nav`。九鼎正式地图通过 `MapDefinition`／`MapItem` 提供道路、障碍高度、遭遇和互动数据，战斗读取自己的规则模型。[ASF 导出源码][map-export]、[项目布局代码](../../godot/scripts/world/map_definition.gd)

因此 ASF 的场景不是九鼎正式地图的直接替代，也不能用其“路径可达”报告证明九鼎的阻箭、脚底碰撞或探索交互正确。可借它制作石块、树木、地面和前后遮挡拆件；正式摆放继续在 `godot/scenes/tanggu_map.tscn` 完成。

## 4. 社区反馈：有真实使用，效果并不稳定

| 来源 | 实际证据 | 不能外推的部分 |
| --- | --- | --- |
| [miya，5 月 31 日][miya-dragon] | 用户展示十帧像素龙动画、透明帧表与 GIF，评价正面 | 不代表复杂角色动作、皮影风格或 Godot 导入已验证 |
| [同用户，6 月 6 日][miya-walk] | 步行动画反复修正，逐帧提示后仍有左右脚错误和风格变化，暂时采用 | 属于旧版反馈，不能直接判定 0.4.0 一定复现 |
| [Mystic Forest Three 发布记录][miya-game] | 独立游戏使用了素材生成、透明 PNG 和拆帧 | 技术栈是 Three.js，不是 Godot |
| [issue #3][issue-3] | 多位用户报告紫色残边，包括像素素材 | 发生于升级前；新版本有去背改进，未找到原用户复测闭环 |
| [issue #4][issue-4]、[issue #11][issue-11] | 分别报告 Codex 本地图片缺失、Grok 视频路线失败 | 不能将旧版路线限制当作当前功能清单 |
| [PR #13][pr-13]、[PR #10][pr-10] | 外部贡献者针对轴漂移、帧表边界误拒提出复现／测试与修复 | 本次仍显示未合并，不能算正式版本已经解决 |

这些证据说明它不是只有宣传的空项目；但“有原型产出”也不足以证明可稳定批量生产。未找到独立用户公开验证“0.4.0＋Godot 编辑器导入＋皮影画风”的完整案例。

维护时间线：5—7 月已有用户反馈与外部修复提案；10 月 6 日发布 0.4.0 集中升级，本次 main 仍为该提交。仓库约 4.5k 星只能算采用线索，不能替代质量验证。[仓库][repo]、[版本发布][release]

## 5. 作者自己披露的限制更值得重视

1. **Godot 导出只做解析层验证，未验证编辑器导入。** 导出测试也明确说明没有安装引擎。九鼎的 Godot 版本虽属于目标大版本，仍不能据此宣称兼容通过。[导出测试][export-test]、[地图导出测试][map-test]
2. **macOS 尚未实测。** 作者运行环境为 Windows 11；九鼎的 Apple Silicon 工具链适配尚需补证据。这表示未知，不表示一定不能运行。[平台限制][limits]
3. **自动检查覆盖不了视觉错误。** 作者新版 HD 角色测试中，部分片段通过数值检查后仍被目视发现颜色、武器或动作问题；多轮重试也未消除所有瑕疵。验收不能只看 PASS。[真实验证记录][validation]
4. **测试很多，不等于完整端到端验证。** 作者报告本地 Python／JS 测试通过，但没有 CI，API 适配器没有在这些验证中实际调用；本次只读测试源码，未复跑。[验证记录][validation]、[媒体路由测试][route-test]

对皮影而言，柔边、镂空和有色纹样尤其需要实测：上游去背阈值主要以黑描边卡通视频标定，不能假定对纸质半透明与细线效果同样有效。这是结合素材特征与上游覆盖边界的推断。[去背覆盖限制][limits]

## 6. 接入成本和采用方式

基础加工依赖 Python 3.10+、numpy、Pillow；仓库 requirements 另列 scipy；视频加工需 ffmpeg，部分浏览器／代码绘制功能还有额外依赖。不是复制一份 `SKILL.md` 就获得完整功能，多个技能引用相邻技能的脚本和参考文件。[依赖文件][requirements]、[精灵 Skill][sprite]、[视频 Skill][video]

图像与视频生成还需可用的生成工具或账号。当前会话有原生图像生成工具，没有原生图生视频工具；视频路线须另接服务／CLI或提供已有视频。不能把 Codex 可生成图片等同于能完成该套角色视频流程。

当前媒体路由默认优先使用已配置的付费 API，且没有默认配额上限。这与“沿用现有会话图像工具”是不同选择。若后续试用，建议明确采用现有图像工具生成，再只调用本地加工脚本；视频单独确定路线、次数和预算。本次没有检查用户密钥或调用服务。[媒体 Skill][media]

仓库代码与文档为 MIT；生成图像／视频另受提供商条款约束，不能把工具开源当成生成素材授权证明。[许可证][license]、[素材授权说明][rights]

## 7. 最小试用建议

**建议纳入候选，先验证加工价值，再扩展生成。** 比上一轮仅有流程原则的 `create-game-assets`，它提供更多可执行加工能力；两者分别偏生产管理与素材处理，不必重复引入全部指导。[上轮评估](九鼎_社区游戏Skills评估_2026-10-19.md)

| 试用顺序 | 范围 | 验收点 |
| --- | --- | --- |
| 1 | 一张现有原创道具／特效帧表，只做切帧、透明与锚点整理 | 不变形、不误删细线／独立碎片；原点和实际显示大小正确；记录人工修正耗时 |
| 2 | 一个新道具或短特效 | 固定已有风格参照；检查亮暗背景、边缘、纹样、帧间一致性及生成次数 |
| 3 | 一个简单敌人的单方向待机／受击 | 验证母图一致性、循环和既有规则时点；不直接展开主角全套动作 |
| 4 | 独立隔离目录中的 Godot 样本 | 干净导入与资源加载；前台画面待用户安排后验收，不替换正式地图或已接受素材 |

若准备采用，先锁定版本，保留所需完整依赖，再以小样的返工量决定是否继续。暂不建议整库自动触发、批量重做角色、自动生成正式地图或使用其整套运行时。

## 8. 调研方法与未完成证据

采用 `research` 和 `github-deep-research` 的一手来源流程：核对 GitHub 当前提交与技能目录，审读五项 Skill、精灵／地图导出实现、相关测试及限制文档；交叉检查 issue／PR、用户原帖和项目当前资产结构。GitHub 普通 API 曾限流，改以只读 `gh api` 和源码检出补充。

只新增本报告，未变动游戏、正式地图、素材、用户级技能或账户配置。未运行候选测试、制作实验和 Godot 验证；这些不应写成已通过。下一步若实施，上表是试用建议，不代表本次已经获得生成、安装或前台测试任务。

[repo]: https://github.com/0x0funky/agent-sprite-forge
[release]: https://github.com/0x0funky/agent-sprite-forge/releases/tag/v0.4.0
[sprite]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dsprite/SKILL.md
[video]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/video2dsprite/SKILL.md
[map]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dmap/SKILL.md
[media]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dmedia/SKILL.md
[codeart]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/codeart2d/SKILL.md
[sprite-scripts]: https://github.com/0x0funky/agent-sprite-forge/tree/5324342/skills/generate2dsprite/scripts
[export-source]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dsprite/scripts/export_engine.py
[export-doc]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dsprite/references/engine-export.md
[runtime]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dsprite/references/runtime-integration.md
[map-export]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/skills/generate2dmap/scripts/export_godot.py
[limits]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/docs/known-limitations.md
[validation]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/docs/validation-2026-10-06.md
[export-test]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/tests/test_export_engine.py
[map-test]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/tests/test_export_godot.py
[route-test]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/tests/test_route_media.py
[requirements]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/requirements.txt
[license]: https://github.com/0x0funky/agent-sprite-forge/blob/5324342/LICENSE
[rights]: https://github.com/0x0funky/agent-sprite-forge/tree/5324342#generated-assets-and-licensing
[miya-dragon]: https://note.com/miya19/n/n7d51e1ef63a6
[miya-walk]: https://note.com/miya19/n/n7bc1080838a4
[miya-game]: https://note.com/miya19/n/na9e715b9d793
[issue-3]: https://github.com/0x0funky/agent-sprite-forge/issues/3
[issue-4]: https://github.com/0x0funky/agent-sprite-forge/issues/4
[issue-11]: https://github.com/0x0funky/agent-sprite-forge/issues/11
[pr-13]: https://github.com/0x0funky/agent-sprite-forge/pull/13
[pr-10]: https://github.com/0x0funky/agent-sprite-forge/pull/10
