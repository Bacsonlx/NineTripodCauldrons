# 主角完整背面身图 v2

2026-11-05 后续：[背面上身比例校准](../back-proportion-v1/README.md) 已替代本目录的运行图集；本版保留为下肢来源与历史参考。

2026-11-05 更新：[背面行走 v1](../back-walk-v1/README.md) 已补齐八个迈步帧，普通行走改用独立图集；本目录继续承载待机和射箭。下方 2026-11-04 的“移动时没有步态”是当时限制，现已由本版行走资源替代。

日期：2026-10-30  
状态：已替换运行资源，原生画面待用户确认

## 参考、候选与交付

资产／任务标识：CHR-001 背面完整身图。v2 由 v1 根据用户视觉反馈修订。

| 关系 | 对象／版本 | 依据或处理 | 确认与证据 |
| --- | --- | --- | --- |
| v1 → 修订 | `output/art/CHR-001/2026-10-30-back-full-body-v1/normalized/hero-back-full.png` | 保留四格构图与服装，收紧四格背面头发外轮廓 | `output/art/CHR-001/2026-10-30-back-full-body-v2/revision.json` |
| v1 → 修订 | `output/art/CHR-001/2026-10-30-back-full-body-v2/revisions/bow-angle-v2.png` | 修正第二格普通背面拉弓，使弓体横置在肩部前方 | `output/art/CHR-001/2026-10-30-back-full-body-v2/revision.json` |
| 候选 → 交付 | `output/art/CHR-001/2026-10-30-back-full-body-v2/normalized/hero-back-full.png` → `godot/assets/characters/action-redraw-v1/hero-back-full.png` | 四格逐格注册到共享脚点 `[272,700]`，运行缩放 `0.12` | `godot/assets/characters/action-redraw-v1/clips.json` |

## 当前修订

- 四个姿态的黑发和发髻收紧，减少外扩尖刺，保留红色发绳与背面识别度。
- 第二格弓体改为肩部水平持弓，箭头朝上／远处，弦连接持弓和拉弦手。
- 其他服装、披带、裤腿、鞋子、四格顺序和透明画布保持不变。
- 四格顺序仍为 `idle_back`、`draw_back`、`release_back`、`recover_back`。

## 验证边界

- 资产预览：已检查透明背景、四格独立边界、人物完整轮廓和第二格弓的方向。
- Godot 导入：待专项命令重跑。
- 逻辑／回归：规则脚点、人物状态和普通射箭时序沿用 v1 合同。
- 原生窗口动态画面：待用户确认。

## 待机／移动切换修复（2026-11-04）

用户实测指出背向静止与此前移动状态的人物形象、大小不一致。根因为 `player_frame_actor.gd` 把 `hero-back-full` 只挂在 `p.facing==3 and not p.moving and state.skill==null` 分支：一旦移动（或右向移动＋背向瞄准），就落回 `hero-archery-up` + 旧下肢，而两套画布／根点／运行缩放不同（`724×0.12` 对 `453×0.24`），切换即突变。

本次只改呈现分支，未重绘、未改 yaw、脚点、握点或规则快照：

- 背向无技能、未受击、未闪避时，静止与移动均采样本图集。
- 移动不再叠加 `bob` 位移，避免人物在地面上下抖动。
- 背向技能／闪避／受击仍走原联绘层，和右向移动＋背向瞄准一致。

验证：`godot/tests/action_frame_checks.gd` 全绿；`python3 tools/migration/check_godot.py` 通过导入、规则、完整场景。

未覆盖：原生窗口移动画面待用户确认；当前图集只有站立四阶段，移动时下肢不会有步态，现采用移动起伏表现。
