# 主角完整背面身图 v2

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
