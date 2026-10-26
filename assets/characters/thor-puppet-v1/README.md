# 索尔单方向皮影拆件候选 v1

当前状态（2026-10-26）：默认Boss战斗已切换为[新全身逐帧图](../action-redraw-v1/README.md)，本套拆件继续用于历史候选、独立飞锤及静态败退。下文保留各轮制作／接入历史；新动作不继承旧版本的视觉结论。

用户于 2026-10-22 确认：采用已生成母图方向、简化细节并强化皮影平面感；使用分层关节动画，先确认一个方向的行走和完整掷锤，再扩展四向。当前素材尚未替换默认首关灰盒。

- 母图：`output/art/BOS-001/2026-10-22-production-master-v1/master-candidate.png`。
- 生成：内置 imagegen，母图作为引用；提示词 `output/art/BOS-001/2026-10-22-puppet-v1/parts-prompt.txt`。
- `parts-source.png`：1254×1254 RGBA，4×4 共 16 个身体／武器部件，不是动作帧表。
- 切片：Sprite Forge `assemble_frames.py`，`--key none --slice ownership`，使用同目录 `ownership-boxes.json`；所有部件完整保留在统一 339×383 画布。
- QA：矩形切片发现跨格像素，ownership 分配完整保留；`cross_cell_spill` 为 resolved/pass。切片工具的 `loop_seam` 对 16 个不同身体部件的序列不适用，不能当角色动作环验收。
- Godot：`godot/assets/boss/thor-puppet-v1/` 保存各 PNG 与 AtlasTexture，`parts.json` 记录显示区域与 SHA-256；区域为 alpha>16 的包围框，原始透明像素仍在完整 PNG 中。
- 动态：`godot/scripts/presentation/thor_puppet.gd`，实际位移驱动步相，支撑脚世界坐标固定；肩胯、红布、手臂和飞锤由规则快照驱动。没有图生视频，没有拿整张母图旋转代替动作。
- 身高：中立姿势约 182 世界单位；现有主角测得约 91。碰撞半径、受击范围、伤害和战斗时序不变。

预览和后台证据见 `output/art/BOS-001/2026-10-22-puppet-v1/README.md`。待确认项为形象、重量感、关节遮挡与完整投掷动作；四向、前台原生画面和性能尚未验收。


2026-10-23更新：用户退回v1动态（不流畅、关节错位）。原PNG保留，运行骨架已重新标定解剖轴并固定骨段尺寸；v2说明与预览见 `output/art/BOS-001/2026-10-23-motion-redesign/README.md`。v1预览只作历史问题证据，不能作为已接受动画。

后续用户继续指出v2腿部扭曲与手臂外架；当前动作候选见 `output/art/BOS-001/2026-10-23-motion-v3/README.md`，源PNG不变。各版本动作均未获视觉验收。

比例后续：用户指出v3腿短，现有v4维持总高、上提腰胯及加长固定腿骨；当前候选见 `output/art/BOS-001/2026-10-23-proportions-v4/README.md`，源图仍不变、未获视觉验收。

当前运行状态（2026-10-23）：用户授权先接入v4、后调细节，默认首关现使用此角色；上文“尚未替换”的描述为候选制作历史。动画与原型仍有差异，不记为视觉验收，四向后续制作。

## 2026-10-26 动作重绘原型

用户要求主角与 Boss 的动作重绘，先用内置 imagegen 画各帧原型。本轮实际附入既有索尔母图和迈步图，重新绘制单方向迈步、横锤、投锤／接锤、引雷各8姿态；来源、原始提示词、留白修订和待修问题见[制作说明](../../../output/art/action-redraw/2026-10-26-prototype-v1/README.md)及[逐帧查看页](../../../output/art/action-redraw/2026-10-26-prototype-v1/preview.html)。新图仅为评审候选，未替换16拆件或默认 v6；既有三招确认不扩大到新绘画帧，左右承重和帧间注册仍待修订。
