# 索尔焦土雷庭与技能特效 v1

2026-10-23。用户已确认[完整地图原型和三招效果板](../../../output/art/BOS-001/2026-10-23-arena-v1/README.md)，并明确要求按原型实现。本目录保存正式源图与提示词；运行副本位于 `godot/assets/boss/thor-arena-v1/`。接入画面、动态可读性与原生操作仍待前台验收，原型确认不替代该项。

已接受的[地图原型](arena-prototype.png)及[三招效果板](skills-prototype.png)另存于本目录，原型完整提示词见 `prototype-*-prompt.txt`；不会仅依赖被 Git 忽略的制作目录追溯用户确认对象。

## 素材与合同

| 文件 | 用途与加工 |
| --- | --- |
| [floor.png](floor.png) | 内置 imagegen 生成的纯地面，1476×1066、RGB；不包含墙、树、门或碰撞。运行按 1440×1040 展示，中心铜纹为平面嵌纹。 |
| [effects-sheet.png](effects-sheet.png) | 内置 imagegen 透明 RGBA 原图，1254×1254；严格 2×2 取图，每格 627×627。原图像素与 alpha 不改动。 |
| [floor-prompt.txt](floor-prompt.txt)、[effects-prompt.txt](effects-prompt.txt) | 两次生成的完整提示词。模型标识、费用未由工具返回，均为未知；未调用付费 API 或视频服务。 |
| [generation.json](generation.json) | 实际附图、原始输出、源图与运行副本 SHA-256、取图区和显示锚点。 |

特效格按左上、右上、左下、右下为锤弧、飞锤电流拖尾、落雷电柱、通用电流冲击；是四个独立特效母图，不将四格当作连续动作播放。运行用 AtlasTexture 原区域引用，保留全格透明边：

- 锤弧以格中心为旋转点，由 Polygon2D 裁在真实半径 180、总角 110° 扇区内；挥击及初段收招按规则余量显示／消散。
- 拖尾亮端约在格内 (533,313.5)，沿去回方向旋转，位置跟随现有角色真实空中锤体；地面危险通道独立显示。
- 落雷格的触地白核按源图测量位于约 (350,506)，此点绑定规则落点；0.1 秒生效后至 0.32 秒仅作淡出，不延长伤害。
- 冲击格以中心显示，命中玩家、落雷接地、折返、接锤分别由快照变化触发。锤离手破绽标记及地面范围仍来自规则。
- 全部时序读取规则 `elapsed`，无独立计时器；暂停冻结、重开和死亡清理。

## 参考、候选与交付

| 关系 | 对象／版本 | 用途、实际输入与选择依据 | 确认与证据 |
| --- | --- | --- | --- |
| 参考 → 原型 | 当前扶桑残庭与索尔拆件 → 焦土雷庭／三招效果板 | 已有场景材质、皮影人物语汇；详见原型记录中的实际附图 | 用户在本会话明确确认按两张原型实现，2026-10-23 |
| 原型 → 地面源图 | arena-concept.png → floor.png | 实际附入内置 imagegen，单独生成无物件地面，避免把装饰烘焙为错误路障 | AI 选择理由：保留石坪与铜纹，同时让外围物件继续可编辑；正式画面待验 |
| 效果板 → 特效源图 | skills-concept.png → effects-sheet.png | 实际附入内置 imagegen，生成四个独立透明母图；不切概念板中的角色、背景或文字 | AI 选择理由：各格无跨框主体、边缘完整，能按规则组合；动态待验 |
| 既有环境 → 边缘陈设 | ruin_stone／pillar／root／tree_red／rocks → boss_environment.tscn | 直接引用已有正式纹理，不重画或覆盖源图；降低色彩饱和并按外围布置，无场内碰撞 | [场景](../../../godot/scenes/world/boss_environment.tscn)；原有门框、封印、漩涡继续复用 |
| 选定 → 地图运行引用 | floor.png → 同名运行副本 → Environment/Ground | 像素直接复制；主线房实例化环境，独立 Boss 房复用同一场景，避免重复底板 | [正式 Boss 房](../../../godot/scenes/rooms/boss.tscn)、[独立地面容器](../../../godot/scripts/presentation/boss_floor.gd) |
| 选定 → 技能运行引用 | effects-sheet.png → 同名运行副本 → 四个 AtlasTexture | 区域 (0,0,627,627)、(627,0,627,627)、(0,627,627,627)、(627,627,627,627) | [技能脚本](../../../godot/scripts/presentation/boss_skill_effects.gd)、[预警与角色入口](../../../godot/scripts/presentation/boss_view.gd) |

## 加工与 QA

使用用户级 `generate2dsprite` 的 `sheet_qc.py spill` 检查和 `assemble_frames.py --key none` 无损切格复核。运行资源采用原图 AtlasTexture，未使用归位、改色、抠图或自动清理 alpha。透明源图未当作动画图集；数值来自现有规则，不由素材帧数反推。

[原始 QA](../../../output/art/BOS-001/2026-10-23-arena-v1/fx-qc/sheet-qc.json) 无失败，但有两个警告，不能称为全部通过：

- `safe_frame`：value 4、threshold 0，四格都不足建议的 15% 留白。跨格实体、可见边缘跨格、图外截断、空格、13 px 边界带均为 0；采用固定原区域取图并启用 filter_clip，不再裁紧或重排。
- `faint_specks`：value `{floor_px:189638, detached_components:16}`、threshold 0，为弱 alpha 光晕及离散微粒。保留源图，避免清理抹去电流边缘；需在原生深浅底动态画面继续观察。

[工具能力记录](../../../output/art/BOS-001/2026-10-23-arena-v1/forge-doctor.json) 的缺失项为未使用的 SVG 绘图／地图 Skill、API 密钥及 Grok CLI；项目按现有约定使用宿主 imagegen，不因此安装或切换服务。非 ASCII 路径已使用完整参数与引号处理。

## 分类证据索引

[实现预览](../../../output/art/BOS-001/2026-10-23-arena-v1/index.html) 使用实际场景变换、资源和规则快照离线组装，范围线按相同规则值重绘，部分接地渐变／脚影未完全复现；不是 Godot GPU 截图。

最终后台检查、干净导入、原生包资源和加载结果见[验证清单](../../../output/art/BOS-001/2026-10-23-arena-v1/verification.json)与[Boss 实施记录](../../../docs/mvp/首关Boss_索尔_实施记录_2026-10-22.md)。结构与逻辑检查不代表动态视觉认可；前台键鼠、画面、性能及 Windows 实机继续待验。
