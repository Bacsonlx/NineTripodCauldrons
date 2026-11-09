# CHR-001 背面行走 v1

2026-11-05 后续：[上身比例校准](../back-proportion-v1/README.md) 已替代本页运行图集；本版作为腿部来源保留。下文“与背面待机高度相近”只描述旧版局部比较，不能证明与其他三向一致。

日期：2026-11-05。用户要求使用 imagegen 重做精细迈步帧；本版由 AI 选择并接入，用户原生动态确认待验。

## 参考、候选与交付

| 关系 | 对象 | 依据与证据 |
| --- | --- | --- |
| 参考 → 首版 | [完整背面 v2](../back-full-body-v2/hero-back-full.png) → [首版](../../../../output/art/CHR-001/2026-11-05-back-walk-v1/source/initial.png) | 实际附入参考图，保留发髻、披带、服装、弓和俯视镜头；内置 `image_gen.imagegen`，不是视频路线 |
| 首版 → 修订 | [修订源图](../../../../output/art/CHR-001/2026-11-05-back-walk-v1/source/revised.png) | 只修订双腿交替，减少首版重复步态；[完整两轮提示词](../../../../output/art/CHR-001/2026-11-05-back-walk-v1/prompts.json) |
| 修订 → 选择 | [hero-back-walk.png](hero-back-walk.png) | AI 选择：左右脚抬起／落地可辨、轮廓完整、细节延续。用户要求制作和接入，不等于用户已确认本版美术 |
| 选择 → 运行 | [运行图集](../../../../godot/assets/characters/action-redraw-v1/hero-back-walk.png)、[clips.json](clips.json) | 源 PNG 逐字节复制，4×2 网格；[主角采样](../../../../godot/scripts/presentation/player_frame_actor.gd) 消费 `hero-back-walk` |
| 运行 → 检查 | [证据入口](../../../../output/art/CHR-001/2026-11-05-back-walk-v1/README.md) | 位移采样、尺度、暂停／重置、导入、原生包分别记录 |

## 合同

- 实际工具返回 `1536×1024` RGBA，8 帧，每格 `384×512`；未将提示词中的目标尺寸当成实际尺寸。
- 保留原始 alpha；没有抠色、重绘、单帧缩放或按最低像素强制贴地。每帧 alpha≥128 的轮廓均在格内，最小边距 24 像素。
- 统一根点 `[180,450]` 是胯部下方虚拟地面原点；抬脚和鞋底可越过该平面，不能逐帧取 alpha 底部代替根点。
- 全组固定缩放 `0.1485`，外层仍为 `2/3`；按现有待机冠顶到共享地面高度约 42.08 世界单位校准，未单独放大头部。
- 背向普通行走每移动 22 世界单位推进一帧，8 帧循环；向下倒退时反序采样。暂停／相同快照不推进，停步恢复既有背面待机。
- 背向横移也保持本版身份和体量，但没有单独的侧跨步图；背向射箭使用原四阶段整身姿态，跑射腿部尚无独立迈步层。技能、闪避和受击仍为既有资源。
- 图集整身采样不改变鼠标瞄准、规则移动方向、碰撞、伤害或箭矢起点。

加工复现：先保留候选目录内两张源图，再运行 `tools/asset_forge/.venv/bin/python tools/art/action_redraw/register_back_walk.py`；完整素材转换 `tools/art/action_redraw/prepare.py` 也会从本目录重建运行条目。

模型名与费用未由内置工具返回，记录为未知。[generation.json](generation.json) 保存参考、选择、哈希与逐帧几何，[prompts.json](prompts.json) 保留完整两轮提示词；[待机／行走 GIF](../../../../output/art/CHR-001/2026-11-05-back-walk-v1/review/idle-walk.gif) 是离线合成，不是 Godot 原生录屏。
