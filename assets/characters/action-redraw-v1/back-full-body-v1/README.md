# 主角完整背面身图 v1

日期：2026-10-30  
状态：已被 v2 替代，保留用于追溯

## 参考、候选与交付

资产／任务标识：CHR-001 背面完整身图。用途是修复背面普通待机与普通射箭状态中，上身、腰布和下肢被分层切开的视觉问题。

| 关系 | 对象／版本 | 依据或处理 | 确认与证据 |
| --- | --- | --- | --- |
| 参考 → 候选 | `assets/characters/child/down-archery-v3.png`、`identity-v4/hero-archery-up.png`、`identity-v4/hero-run-lower.png` | 保留已确认角色身份、背面头发／披带／弓、下装比例和固定俯视镜头；实际生成时附入上述三张图 | `output/art/CHR-001/2026-10-30-back-full-body-v1/generation.json` |
| 候选 → 修订 | `output/art/CHR-001/2026-10-30-back-full-body-v1/source/generated-full-back-sheet.png` → `normalized/hero-back-full.png` | 四格画布为 `543×724`；逐格仅沿 Y 轴对齐到共享脚点 `y=700`，没有缩放、重绘或按包围盒拉伸 | `output/art/CHR-001/2026-10-30-back-full-body-v1/clips.json` |
| 候选 → 选择 | `normalized/hero-back-full.png` | 四个姿态均为完整背面身图，头发、披带、腰布、裤腿和鞋子连续；保留普通箭四阶段 | 本轮 AI 评审；用户原生视觉确认待执行 |
| 选定 → 交付 | `hero-back-full.png` → `godot/assets/characters/action-redraw-v1/hero-back-full.png` | 以 `hero-back-full` clip 接入 `player_frame_actor.gd`；普通背面待机／射箭隐藏旧上身、下肢和独立弓箭 | `godot/assets/characters/action-redraw-v1/clips.json`、`godot/tests/player_art_checks.gd` |

## 规格

- 四格顺序：`idle_back`、`draw_back`、`release_back`、`recover_back`。
- 画布：每格 `543×724`，共享根点 `[272,700]`，运行缩放 `0.12`，外层人物缩放仍为 `2/3`。
- `art_source=image_gen.imagegen`；原始生成图、提示词、逐格注册和 SHA-256 保存在候选目录。
- 背面普通动作采用完整身图，背面技能、闪避、受击和移动仍使用原有动画路径。

## 验证边界

- 构建／导入：待运行 Godot 检查。
- 逻辑／回归：待运行背面四阶段、脚点和规则快照检查。
- 视觉／表现：候选静图已确认透明边、四格不相邻、人物轮廓完整；原生窗口动态画面仍待用户确认。
- 性能：本轮没有改变对象数量级或规则逻辑，未单独采样前台性能。
