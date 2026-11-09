# 九鼎角色与 Boss 移动／动作：开源方案研究

查阅日期：2026-10-25。状态：研究建议，尚非接入决定；未安装插件、未替换现有角色、未进行本项目集成或前台视觉验收。（注：2026-10-29—11-05 主角侧已完成 2/3 视觉缩放、腰带连接、背面上身跨方向比例校准及按实际移动距离推进的背面八帧行走动画，见[人物连接与背面头部校准记录](../mvp/商业深度肉鸽_人物连接与背面头部校准_实施记录_2026-10-30.md)。）

研究流程：用户指定 ask-matt，路由至 research；核查范围为官方文档、项目源代码、项目维护者发布的许可证和兼容说明。项目采用原生 2D、带类型 GDScript、Godot 4.7.2 和 Compatibility 渲染器。

## 结论

**优先借鉴 Godot 官方 Skeleton2D 示例的动画组织方式，以及 AnimationPlayer／AnimationTree 的分层、过渡和步速同步能力。先建立能重复比较的移动与动作小样，再决定是否需要外部工具。**

没有找到一个安装后就能保证“角色灵活、Boss 有重量”的通用插件。动画控制器可以解决播放与衔接，骨架可以解决姿态编辑，状态机可以解决动作调度；它们都不能自动补出缺失的方向、正确的支撑脚、漂亮的关键姿势和攻击节奏。这是本研究对工具职责的判断，不是已验证的本项目根因。

按收益和接入成本排序：

1. **现有素材与控制器的最小修正**：核对实际位移、步频、转向时步态相位、移动／瞄准分离、动作中断。保留当前规则裁决。
2. **Godot 原生动画制作小样**：已有 Node2D 拆件可先由 AnimationPlayer 编排；需要网格形变时才评估 Skeleton2D + Bone2D + Polygon2D；需要复杂组合时才加入 AnimationTree。
3. **Blender 离线制作再烘焙图集**：适合现有素材／关键帧本身难以达到预期，而又希望维持离线图集运行边界的情况。
4. **Godot State Charts**：只有动作状态与中断关系确实变复杂时才考虑。
5. **LimboAI**：留给 Boss 战术决策复杂化；不是本次步态／动作质量问题的优先解。

## 必须分开的四类问题

| 观察到的问题 | 优先核查 | 工具能做什么 | 不能据此保证什么 |
| --- | --- | --- | --- |
| 身体移动但脚在滑；堵墙仍迈步 | 实际位移与步频、支撑相位 | 速度驱动播放、距离驱动相位、脚部约束 | 换状态机不会自动消除滑步 |
| 换向抽动、走两步又回第一帧 | 朝向切换阈值、切换是否重置相位、起停过渡 | 离散保相位切换、过渡动画 | 四向图不会凭空变成八向图 |
| 移动射击时上下身不协调 | 腿／躯干／武器控制权、锚点、遮挡次序 | 分层轨道、过滤器、局部叠加 | 两张整身位图不能像骨架一样插值出中间姿势 |
| Boss 动作软、关节扭曲、打击不清晰 | 重心、落脚、预备／出手／收招姿势、裁切边缘 | 可视化关键帧、曲线、IK 或补绘帧 | 加 IK 或加帧数不等于动作有力 |

上表是诊断分类和试点假设。应由相同场景下的录制、逐帧观察与规则日志判断属于哪一类，不能只凭“看起来不顺”认定需要重做引擎或全部素材。

## 开源方案对比

| 方案 | 开源与许可 | 实际解决的问题 | 对九鼎的建议／限制 |
| --- | --- | --- | --- |
| Godot 原生 AnimationPlayer／AnimationTree | 引擎 MIT | 关键帧编辑、状态过渡、局部分层、单次动作、播放速率 | 首选；序列帧和拆件都能组织，但两种资产不能采用相同的混合假设。[引擎许可](https://godotengine.org/license/)、[动画树文档](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) |
| 官方 Skeleton2D Demo | 示例代码 MIT；GBot 图与初始绑定／动画也注明 MIT | 展示骨架角色、移动动画及控制器 | 最值得读源代码的参考；实际为横版左右移动／跳跃，不是现成俯视角角色包。[示例及素材许可](https://github.com/godotengine/godot-demo-projects/tree/master/2d/skeleton)、[控制脚本](https://github.com/godotengine/godot-demo-projects/blob/master/2d/skeleton/player/player.gd) |
| Godot State Charts | MIT | 并行／层级状态、条件迁移、调试 | 可帮助管理移动、动作、操作中断的关系；不制作动作、不修脚滑。[项目](https://github.com/derkork/godot-statecharts)、[许可](https://github.com/derkork/godot-statecharts/blob/main/LICENSE) |
| LimboAI | MIT | 行为树与层级状态机、Boss／敌人决策 | 只有追击／选择招式／阶段策略复杂后再评估；C++ 插件需要匹配版本和平台。[兼容表](https://github.com/limbonaut/limboai/blob/master/README.md)、[许可](https://github.com/limbonaut/limboai/blob/master/LICENSE.md) |
| Blender／COA Tools | Blender GPL；COA Tools GPL-3.0 | 离线骨架、拆件、曲线与姿态制作 | 可走离线烘焙；COA 自带 Godot 导入器是旧 API，不能当 4.7 即用插件。[Blender 许可](https://www.blender.org/about/license/)、[COA 功能](https://github.com/ndee85/coa_tools)、[导入器源码](https://github.com/ndee85/coa_tools/blob/master/Godot/coa_importer/importer.gd) |

### 1. 原生动画：目前最值得投入的主线

官方 Cutout 文档明确支持拆件动画与逐帧动画混合，例如身体使用拆件，手、脚或表情使用替换帧；并可借助 AnimationTree 组织混合。对九鼎的启发是：**不必在“全骨架”和“全逐帧”之间二选一**。握弓、握锤、极端透视和出手瞬间可保留或补绘替换图，其余部分使用可编辑变换。[Cutout 文档](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html)

但该教程页面明确标记“尚未针对 Godot 4.7 更新”。它适合学习组织方式，具体节点与 API 必须以锁定引擎核验；不能把教程步骤当已经通过 4.7.2 的操作证据。[同页版本提示](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html)

适配建议：

- **序列帧玩家**：先保留现有播放代码；如果确实需要方向状态图，可采用 BlendSpace2D 的离散模式。`DISCRETE_CARRY` 会把旧动画的播放位置带入新动画，适合作为转向时保持步态相位的候选。前提是各方向循环长度、左右脚相位约定一致；仅打开此选项不能修复不一致的源帧。[BlendSpace2D 文档](https://docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html)
- **拆件／骨架 Boss**：先有可独立播放、可审阅的动作片段，再组织片段之间的衔接。AnimationPlayer 已能控制节点属性；不是每个拆件都必须先改为 Bone2D。[AnimationPlayer 与 AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)
- **并行跑射**：AnimationTree 的轨道过滤器可以让上身动作不覆盖下肢；OneShot 可以承载一次攻击和淡入／淡出。但本项目只应让它们控制表现，命中、冷却与操作中断仍由现有规则管理。[动画树过滤器与 OneShot](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)
- **网格形变**：Skeleton2D 是 Bone2D 层级的父节点，适用于确实需要骨骼变形的局部；不要仅为“更灵活”给整个角色全部增加形变。[Skeleton2D API](https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html)

官方 Skeleton2D Demo 的具体可借鉴点：先执行移动，再更新动画；walk／run 的播放速度根据角色速度计算。这是“脚步节奏随运动变化”的可读源代码示例，不证明其参数适合本项目。[player.gd](https://github.com/godotengine/godot-demo-projects/blob/master/2d/skeleton/player/player.gd)

版本边界：此次读取的 master 示例 `project.godot` 标记 4.7，README 标明 Compatibility；但示例仓库根说明 master 跟随 Godot 开发分支，不能持续依赖浮动 master。实际试点应固定一个通过本项目引擎导入的提交；本次未下载运行示例。[工程配置](https://github.com/godotengine/godot-demo-projects/blob/master/2d/skeleton/project.godot)、[分支规则](https://github.com/godotengine/godot-demo-projects/blob/master/README.md)

### 2. State Charts：适合解决动作关系，不负责画面质量

项目声明支持 Godot 4 及以后版本，提供节点／信号方式、条件迁移和运行调试。并行状态允许“移动状态”和“动作状态”各自演进，避免把每个组合都写成新状态。[README](https://github.com/derkork/godot-statecharts/blob/main/README.md)、[并行状态](https://derkork.github.io/godot-statecharts/usage/nodes)

适用触发条件：现有代码已反复出现“跑步覆盖攻击”“受击与收招相互抢播放”“暂停返回恢复了错误动作”等状态关系错误。若只是固定步频、姿势或脚点问题，先改现有呈现层更小。

需要注意：官方文档已将专用 `Animation tree states` 和 `Animation player states` 标记弃用，不建议新代码依赖它们。若未来接入，应以普通状态信号调用呈现接口。项目的“Godot 4+”声明不等于已经在九鼎锁定的 4.7.2 上通过测试。[节点弃用说明](https://derkork.github.io/godot-statecharts/usage/nodes)

### 3. LimboAI：当问题变成“Boss 应该怎么行动”再使用

它提供行为树、层级状态机、可视化调试和 GDScript 自定义任务。官方版本表列出 1.8.x 的 GDExtension 支持 Godot 4.6 及以后，module 对应 Godot 4.7。是否有本项目各目标平台的合适二进制，以及暂停／时间语义是否匹配，仍需集成验证。[官方 README](https://github.com/limbonaut/limboai/blob/master/README.md)

研究判断：若目标只是让索尔迈步自然、横锤更有重量，引入行为树收益低；若未来需要绕行、保持距离、招式选择、条件阶段切换，才有必要另开范围评估。不要借动画研究替换已经裁决战斗的规则状态机。

### 4. 离线骨架烘焙：符合既有图集基线的替代路线

Blender 是 GPL 软件；官方许可说明用户制作的图像、影片、`.blend` 等作品不因使用 Blender 自动变成 GPL。输出图像序列可用于现有图集加工流程，源素材本身的权利与来源仍需保留。[Blender 许可说明](https://www.blender.org/about/license/)、[输出说明](https://docs.staging.blender.org/manual/en/latest/render/output/introduction.html)

COA Tools 提供拆件导入、骨骼编辑、权重、IK／拉伸约束、正交相机和动画导出。适合参考其制作流程；但自带 Godot 导入器仍出现 `tool`、`instance()`、`File.new()`、`set_pos()` 等旧 API，本研究没有找到它已适配本项目 Godot 4.7 的可靠证据，不推荐把这个导入器直接装进主工程。[COA README](https://github.com/ndee85/coa_tools/blob/master/README.md)、[导入器源码](https://github.com/ndee85/coa_tools/blob/master/Godot/coa_importer/importer.gd)、[GPL-3.0 许可](https://github.com/ndee85/coa_tools/blob/master/LICENSE)

项目适用方式是制作端保持可编辑骨架，按固定相机、比例、脚点烘焙，再复用现有序列帧／图集运行链；代价是方向数和动作数增加时需要更多图与纹理预算。它不会自动解决动作设计，优势是同一套骨架可以反复调姿势与节奏。

### 5. 容易误选的工具

| 工具 | 核查结果 | 本次处理 |
| --- | --- | --- |
| Laigter | 开源 GPL-3.0；主要是为精灵生成法线等贴图。[项目](https://github.com/azagaya/laigter)、[作者说明](https://azagaya.itch.io/laigter) | 可改善受光质感，不能解决步态、转向、攻击动作；不列为本次候选 |
| PixelOver | 官网写明使用 EULA；免费 demo 禁止导出，付费版支持导出。[官方许可页](https://docs.pixelover.io/manual/licenses/) | 有骨骼／动画编辑能力，但不是本次要求的开源方案；可作为另行评估的商业制作工具 |
| Spine | runtime 提供源码，但使用 Spine 专用许可，并非 MIT／GPL 这类可直接归入本次开源候选的方案。[runtime 许可](https://en.esotericsoftware.com/spine-runtimes-license) | 可作为成熟商业制作路线的参照，不能把“GitHub 能看到源码”写成“免费开源替代” |

Spine 官方已有 Godot GDExtension 与自定义引擎 module 两条路线，不能再笼统说它只能用自定义 Godot。其编辑器导出的主版本必须与 runtime 主版本相配；本次没有验证九鼎 4.7.2 的相应发行包，也没有授权采购／接入。[spine-godot 官方说明](https://us.esotericsoftware.com/spine-godot)

## 与现有项目决策的关系

[ADR-0010](../adr/0010-godot-migration-direction.md) 确认采用 Godot、原生二维及既有规则边界；本研究不提出引擎切换。

[ADR-0007](../adr/0007-offline-animation-atlases.md) 的原则是制作端允许逐帧、骨骼或拆件，最终交付序列帧与图集，首版本不接入专用骨骼运行时。**扩大运行时骨架的采用范围需要单独确认**；当前存在的 Boss 试点或实现，不应自动改写整个项目的已确认基线。

社区证据支持两条可比较路线：

- 保持图集运行：提升源动作与播放控制，骨架只用于离线制作。
- 独立原生小样：在授权的试点范围内，用 Godot 编辑器组织现有拆件和关键帧，验证是否更容易调出满意动作，再决定是否扩展。

两者可使用同一角色、同一动作节奏和同一位移脚本对照，避免同时改素材、速度、攻击规则后无法判断收益来源。


## 当前九鼎实现：已确认事实与待验证判断

主代理于 2026-10-25 读取当前工作树。基准 HEAD 为 `a10e563`，工作树已有其他未提交改动；以下反映查阅时源码，不把 HEAD 当作完整运行版本。本轮没有运行游戏、导入候选库或重评历史视觉结论。

### 玩家：先核对步态同步，再判断是否需要更换素材

源码：[training_scene.gd](../../godot/scripts/presentation/training_scene.gd) 的 `_physics_process()` / `present()`（143—178 行），[training_room.gd](../../godot/scripts/combat/training_room.gd)（235—257 行），素材记录：[向下射箭 v3](../../assets/characters/child/README.md)。

| 代码事实 | 对调校的意义（推断，未做前台复现） |
| --- | --- |
| 下肢四向，每方向六帧循环，按 `walk_time * 12` 固定播放；只有实际发生移动才累计 walk_time | 已有基本的移动/停止区分，但步频没有按实际位移量变化。贴墙滑动、闪避等与普通跑动位移不同，应分别检查 |
| 腿方向取 `controls.movement()`，移动结果由碰撞裁决后的位置决定 | 贴墙斜移时，输入朝向与实际移动方向可能不一致；优先用同一规则步的实际位移校核表现 |
| 六帧循环周期 0.5 秒；身体 bob 使用 `sin(walk_time * PI * 24 / 7)`，周期约 0.583 秒 | 起伏与步态并非同一周期，可能产生重心与落脚错拍；应让起伏跟随素材的接触相位，而非单独调一个正弦频率 |
| 停步时下肢改用瞄准朝向的静态帧；移动/上身瞄准已经分开 | 反向跑射到停步的腿部切向需要检查；不能把“加入上下身分层”当成尚未实现的新方案 |
| 向下普通射箭使用手、弓、弦联绘的四阶段上身，其余方向仍有独立弓 | 任意角度旋转整张上身无法获得自然转身；若要连续手部瞄准，需要相应拆件/方向素材，单换 AnimationTree 不会补出这些画面 |

建议先保持现有规则速度、碰撞、射箭时序，只改变动画如何读取结果。普通移动的候选相位可用“累计实际地面移动距离 ÷ 每个完整步态周期的标定距离”；瞬移、换房、重开必须重置，闪避用独立表现策略，不把闪避距离直接快进成高速跑步。具体步幅从当前素材与最终显示比例标定，不预设一个通用数值。

### Boss：已经是程序拆件骨架，重点是动作制作和衔接

源码链：[boss_art_view.gd](../../godot/scripts/presentation/boss_art_view.gd) → [thor_motion_candidate.gd](../../godot/scripts/presentation/thor_motion_candidate.gd) → [thor_puppet.gd](../../godot/scripts/presentation/thor_puppet.gd)。动作数据：[poses.json](../../assets/characters/thor-motion-v6/poses.json)，来源与历史确认：[v6 README](../../assets/characters/thor-motion-v6/README.md)。

- 默认 Boss 不是单张图平移，也不是仅播放整身序列帧：它使用 16 个图片拆件、程序姿势和 JSON 关键姿势。
- `thor_puppet.update_state()` 已按实际距离推进步态，包含支撑脚保持、摆脚落点、抬脚和两段腿求解。不能再把“加距离步态、加 IK”当成空缺来重做。
- v6 已处理进入攻击的世界脚点承接、落脚缓冲、骨盆沉降及上肢固定长度。这些约束证明几何一致性，不证明承重、节奏和轮廓已经自然。
- 现有图片与动作仍为单方向。固定视角的拆件旋转不能生成缺失的背面、侧面透视和手部遮挡。若主要不满来自绕行时朝向不对，需要先确定方向素材范围。
- [独立关节片段试点](../mvp/首关Boss_索尔_AI关节片段最小试点_2026-10-23.md) 已有 Node2D 层级 + AnimationPlayer，但仅制作待机与完整横锤；[采样器](../../godot/scripts/presentation/thor_rig_pilot.gd) 的其他阶段回退待机。它尚未验证行走，不能称为完整移动方案。
- 历史离线三招对照曾获用户通过；当前用户提出整体运动仍不满意，是新的改进输入，不抹掉此前确认，也不据此前确认回避这次问题。

因此 Boss 的下一步优先是复用现有拆件和约束，把“追近 → 支撑脚落稳 → 蓄力 → 挥出 → 收招 → 再起步”作为同一段动作评审。IK 只维持接触与骨长；骨盆、胸肩和锤的动作节奏仍需制作并逐帧检查。

### 制作端与运行端的决定分开

[ADR-0007](../adr/0007-offline-animation-atlases.md) 的正式基线仍为离线制作、图集交付。Godot 原生拆件/关键帧可以作为制作工具，随后烘焙为分层序列帧；这条路线与现有玩家接入方式一致。

当前 Boss 的程序拆件实现及已授权的小试点是明确的现状，但不能据此认定全角色改成运行时骨架已经获批。扩大运行时骨架、增加四向/八向素材，或迁移第三方动画运行库属于后续决定。本研究不修改 ADR，也不替换默认游戏资源。

## 推荐的最小验证顺序（建议，尚未实施）

1. **玩家同步候选。** 保留现有图片、速度和攻击规则，比较原版本与“实际位移定腿方向、距离定步态相位、落脚相位定起伏”。用相同输入轨迹检查直行、斜行、贴墙、反向跑射、急停和重开。若同步改好后仍显僵硬，再决定补哪些关键帧。
2. **Boss 连续运动候选。** 基于已有默认步态及 rig 试点做一段连续移动—横锤链。先看接触、压低、经过、抬高等关键姿势与承重；再补时间曲线和衔接。不先铺满三招、全部方向和新运行库。
3. **用户确认动态后选交付形式。** 同素材、同尺度、同规则时序并排，提供正常速度、慢放、逐帧与脚点/锤轨迹叠加。分别比较动态观感、可编辑成本和图集开销，再决定烘焙还是扩大原生 rig。

建议的检查标准：

| 目标 | 应看什么 | 不能代替它的证据 |
| --- | --- | --- |
| 起停响应 | 输入到规则移动维持现有响应；身体可有落脚过渡，但不能等待动作播完才走 | 动画看起来流畅，不能证明输入延迟没变 |
| 无明显滑步 | 普通移动时支撑段脚点与地面接触协调；贴墙后步频对应实际运动 | 关节长度断言通过 |
| 转向不跳拍 | 方向切换保持兼容的步态相位；反向跑射时上下身连接稳定 | 仅静态四向截图 |
| 攻击连贯 | 承重—蓄力—挥出—收势清楚，握点稳定；画面与既有命中时刻对齐 | 插帧数量增加或平均帧率高 |
| 中断正确 | 暂停、失焦、死亡、重开不继续旧动作、不恢复残留姿势；动画不另行裁决伤害 | 正常播放一次完成 |
| 最终可交付 | 后台规则与导入通过后，按用户安排核查原生画面、交互及设备性能 | 离线预览或无头 FPS |

“保证灵活”应落实为这些可重复比较的标准。开源工具能提高可编辑性和控制一致性，但不能自动保证美术姿势、支撑关系或缺失方向的质量。

## 本轮验证与源码标识

- 文档：一手来源、适用范围及本地相对链接核查；没有安装第三方插件。
- 构建/导入、逻辑回归、运行加载：本轮未修改游戏，未执行，不把历史通过结果计为本轮验证。
- 交互、视觉、性能：未验证；只读代码和资料，未打开原生窗口、发送系统输入或进行前台采样。所有“可能”问题须由后续相同轨迹对照确认。
- 本地关键源码 SHA-256（用于识别本轮只读分析对象）：

```text
318d48331f1ee7468a838c0c722f2920523503f4244d5044e0a83994031e2c95  godot/scripts/presentation/training_scene.gd
d5206afb370347d14ff4d0c346e3ab34e38a18b870668a322df4235319947330  godot/scripts/presentation/thor_puppet.gd
79a2b99f77c4fc0481229cc3c8d81364a335428c9d10e3d2d8b204bdc93502d4  godot/scripts/presentation/thor_motion_candidate.gd
ce53e8068dad2718e7353fef7d14e4a0df00bd081a445e2651477a9d53ee01fb  godot/scripts/presentation/thor_rig_pilot.gd
c88c08d18b8cd431b6fa9ad81f6cb5671555bdc5d6ec899700e02203303ba2a6  godot/scripts/combat/training_room.gd
f48807fda3eacde85c9573adb9a35534eec9ae8f461d04ce1be133f8945a8e01  godot/scripts/presentation/boss_art_view.gd
```
