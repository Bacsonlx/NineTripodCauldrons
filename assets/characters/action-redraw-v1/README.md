# 主角与索尔逐帧接入 v1

2026-10-26，用户在当前聊天明确要求将已生成的主角和 Boss 逐帧原型集成并替换旧实现。本轮据此接入默认场景；这项授权不表示用户已认可动作自然度、四向完整性或原生动态画面。

## 原型与首次接入历史（v1）

| 关系 | 文件与处理 | 决定及证据 |
| --- | --- | --- |
| 已有形象 → 重绘候选 | 历史目录 `output/art/action-redraw/2026-10-26-prototype-v1/` 中的 README、原图、提示词、实际附图及 provenance.json | 原型由内置 imagegen 生成，原型说明保留生成与定点修订历史；首次接入 art_source=existing，不重新生图 |
| 候选 → 首次接入版本 | hero-run、hero-archery、hero-dodge、hero-skills、thor-walk、thor-swing-v2、thor-throw、thor-lightning 八套 atlas | 用户要求集成；横锤选择有隔离留白的 v2，弃用旧切帧失败版；原型的 loop_seam needs-visual-review 仍保留。三套主角整身图的后续替代见下节 |
| 接入版本 → 运行文件 | [转换脚本](../../../tools/art/action_redraw/prepare.py) → [运行资源](../../../godot/assets/characters/action-redraw-v1/)、[SHA-256](provenance.json) | atlas 逐字节复制；复用 ownership 切帧矩形及透明补边，不重画、重排、逐帧居中、强制贴地或拉伸 |
| 运行文件 → 场景 | [帧采样器](../../../godot/scripts/presentation/action_frame_sprite.gd)、[主角](../../../godot/scripts/presentation/player_frame_actor.gd)、[Boss](../../../godot/scripts/presentation/thor_frame_actor.gd) | 默认训练／首关共享 training_scene；默认 Boss 的 boss_art_view 已切换到新帧角色；历史关节候选保持独立 |
| 场景 → 历史验证 | 历史路径 `output/art/action-redraw/2026-10-26-integrated-v1/README.md` | 仅作为首次接入记录，不覆盖后续 layered-v2；上述两处历史 output 在本集成目录中未保留可读副本，当前证据见下节 |

首次整身接入以原画格内地面参考点加透明补边取得固定根点，各组固定缩放、同组8帧不按包围盒逐帧缩放；当时主角普通中立身高约90单位，Boss以原182单位基准校准并保留外层1.25放大，整体约225—230单位。这些是 v1 历史体量说明，不能直接套用到现有分层主角；主角闪避与 Boss 仍使用固定地面根点，当前数值见[运行 clips](../../../godot/assets/characters/action-redraw-v1/clips.json)。根点属于呈现注册，不更换规则脚点、碰撞体或出箭点，原图漂移与原生观感仍待验。

## 当前分层替代与追溯（layered-v2）

本集成从已有工作目录同步三份分层图及其加工／来源记录，实际文件和 SHA-256 见[本次同步清单](../../../output/level-design/tanggu-expanded-implementation-20261026/existing-layered-assets-sync.json)。同步原因是补齐隔离快照后已有帧角色所需的资源，不是本轮新生图或动作逻辑改写。[分层 provenance](layered-v2/provenance.json)保留原生成工具、实际编辑目标、完整提示词路径、源图与图集哈希；模型和费用未返回，记录为未知。

| 替代关系 | 分层源图 → 正式图集 | 运行文件／资源键 |
| --- | --- | --- |
| hero-run 整身跑步 → hero-run-lower 下肢 | [源图](layered-v2/sheets/hero-run-lower.png) → [图集](layered-v2/hero-run-lower.png) | [hero-run-lower.png](../../../godot/assets/characters/action-redraw-v1/hero-run-lower.png)／`hero-run-lower` |
| hero-archery 整身射箭 → hero-archery-upper 上身 | [留白修订源图](layered-v2/sheets/hero-archery-upper.png) → [图集](layered-v2/hero-archery-upper.png) | [hero-archery-upper.png](../../../godot/assets/characters/action-redraw-v1/hero-archery-upper.png)／`hero-archery-upper` |
| hero-skills 整身技能 → hero-skills-upper 上身 | [源图](layered-v2/sheets/hero-skills-upper.png) → [图集](layered-v2/hero-skills-upper.png) | [hero-skills-upper.png](../../../godot/assets/characters/action-redraw-v1/hero-skills-upper.png)／`hero-skills-upper` |

下肢与技能上身分别以原 hero-run／hero-skills 图为编辑目标；射箭上身从原 hero-archery 派生，经留白修订替代相邻轮廓粘连、导致两帧为空的早期上身候选。该选择理由来自 provenance 的制作评审，不是用户视觉认可。原型、未采用候选及其修订历史不因替换而删除。

[转换脚本](../../../tools/art/action_redraw/prepare.py)逐字节复制分层图集，并将[分层 clips](layered-v2/clips.json)写入运行 clips；[交付 provenance](provenance.json)可从运行文件倒查正式源图。本次静态核对三份图集的源文件、运行副本及 provenance 哈希一致。脚本还负责清理旧 hero-run／hero-archery／hero-skills 整身运行副本；当前磁盘仍保留这些旧 PNG，但运行 clips 已不注册，不能据此列作当前加载动作。hero-dodge 及四套 Boss 图集继续沿用 v1。

三份分层图各有8帧、3列，按逐帧腰带中心注册：provenance 的 `source_cell_belt_centers` 加透明补边得到 clips 的 `roots[frame]`。[帧采样器](../../../godot/scripts/presentation/action_frame_sprite.gd)逐帧取该根点并设置 `offset=-anchor`，不以包围盒中心或脚底替代。下肢／射箭上身／技能上身尺寸分别为442×445／447×444／457×462，固定缩放为0.112／0.25／0.22；补边分别为 `[0,0,0,0]`／`[3,0,0,0]`／`[13,0,0,18]`，仅左／上补边进入锚点坐标。[主角脚本](../../../godot/scripts/presentation/player_frame_actor.gd)将上下身都放到角色局部 `(0,-30)`，叠加同一 bob，按移动选下肢、按瞄准选上身。元数据的 `manually-reviewed waist belt center` 仅说明锚点标注方式，不表示用户已认可原生衔接。

## 当前实际覆盖

- 主角下肢：仅移动方向落在右向分区（`move_facing==0`）且正在移动时使用 hero-run-lower，以实际累计位移每22单位推进一帧；其他移动方向及站立下肢沿用旧分层。
- 主角上身：仅瞄准右向（`p.facing==0`）时使用 hero-archery-upper 或 hero-skills-upper，既可原地也可移动。待机取射箭第0帧；普通箭前摇0.08秒、释放与收势取真实攻击状态和剩余冷却；Q／E分别采样技能图0—3／4—7帧。上下身独立覆盖／回退，因此向左移动、向右瞄准可组合旧下肢与新上身，向右移动、瞄准其他方向可组合新下肢与旧上身；右向跑射和移动技能不再整体回退旧分层。
- 闪避及技能冲刺仍优先使用 hero-dodge 整身图，仅覆盖冲刺方向角绝对值不超过 `PI/4` 的右向范围，其余方向回退旧图；受击和失败隐藏所有新层，失败沿用旧素材。v1整身图中弓、手臂跨腰线的问题是历史拆分限制，现有上下身来自独立分层重绘。[场景呈现](../../../godot/scripts/presentation/training_scene.gd)分别隐藏被替代的旧下肢／上身，整身闪避时隐藏旧身体及武器，残影复制对应新层而不叠旧上身。
- Boss：默认迈步与三招替换为新全身帧，仍为单方向；横锤前4帧覆盖0.8秒预警，第4索引帧覆盖0.12秒生效，后3帧覆盖1秒收招。投锤前3帧用于1秒预警，飞行使用真正空手的第4／5索引帧，接锤用第6／7索引帧；含锤离手图第3索引帧不叠加独立飞锤。引雷8帧采样原4秒时钟。
- 独立飞锤复用既有 hammer.tres，位置为规则地面点加固定空中高度；放大只作用视觉偏移与锤体，不放大地面路径。警告扇区、拖尾、电柱继续取真实规则。
- 步态取实际位移，重复快照不推进；主角暂停保留当前新姿态，重试／切房清空旧步态；主角失败和 Boss 静态败退沿用旧素材，新图没有死亡动作。呈现不裁决伤害，不等待动画完成。

## 验证证据与原生待验

- 本集成[分层动作回归日志](../../../output/level-design/tanggu-expanded-implementation-20261026/regression/action-frames-layered.log)记录 `action_frame_checks=4101`、`failures=[]`；[用例](../../../godot/tests/action_frame_checks.gd)覆盖独立上下身、反向移动与右瞄准组合、点射8姿态与单箭、Q／E／右向闪避、残影、暂停、失败／重试及 Boss 时序等。这是后台逻辑／结构证据，不等于用户视觉或真实键鼠体验通过。
- [同步清单](../../../output/level-design/tanggu-expanded-implementation-20261026/existing-layered-assets-sync.json)证明本次资源补齐范围与哈希，不证明新包或原生加载。旧接入与回归结论仅适用于各自基线；最终构建／导入／导出状态由集成线程另行验收，不从4101项动作结果推定。
- 单方向分层图不代表四向完成，也不代表已接入的跑射组合获视觉认可。原型的左右腿支撑、头高／体量漂移、贴边裁切、弓弦与握点细节作为历史风险保留，新分层是否改善、腰带接缝及不同方向回退是否自然均待原生动态复核；联绘箭尖与真实出箭点、斜向瞄准及招式危险方向也待验。
- 步态承重、脚滑、招式衔接、最终遮挡、玩家手感、真实窗口键鼠及前台性能待用户安排原生验收，Windows 实测仍暂缓。用户的接入授权不扩展为 layered-v2 最终视觉认可。

本次 README 修复仅核对来源、注册、脚本引用、已有证据和文档链接；未制作素材、运行引擎或重跑测试。构建／导入、逻辑／回归重跑、运行、交互、视觉及性能检查对本次纯文档修改均不适用，上述动作通过仅引用既有日志。
