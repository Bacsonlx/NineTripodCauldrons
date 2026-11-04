# 第一关实际掉落资产 v1

本目录记录第一关当前规则下**实际可能掉落**的视觉资产。它不复制运行 PNG；正式源文件仍位于 `godot/assets/loot/` 与 `godot/assets/items/first-level-v1/`，本目录只保存范围、来源、哈希和复核入口。

## 范围冻结

| 资产 | 掉落链路 | 运行引用 | 状态 |
| --- | --- | --- | --- |
| 血囊 | 普通敌人击杀随机掉落，`roll >= 0.30 && roll < 0.42` | `godot/assets/loot/health.tres` | 当前正式掉落 |
| 蓝囊 | 每个普通遭遇的首个保底蓝囊，或 `roll < 0.30` 的随机掉落 | `godot/assets/loot/mana.tres` | 当前正式掉落 |
| 羊角 | 构筑奖励循环第 1、7 个奖励位 | `godot/assets/items/first-level-v1/ram-horn.tres` | 当前正式掉落 |
| 虎牙 | 构筑奖励循环第 2、8 个奖励位 | `godot/assets/items/first-level-v1/tiger-fang.tres` | 当前正式掉落 |
| 鼠毫 | 构筑奖励循环第 3、5 个奖励位 | `godot/assets/items/first-level-v1/rat-whisker.tres` | 当前正式掉落 |
| 燧火 | 构筑奖励循环第 4、6 个奖励位 | `godot/assets/items/first-level-v1/flint-fire.tres` | 当前正式掉落 |

构筑奖励循环由 `godot/scripts/alpha/alpha_state.gd` 的 `reward_cycle` 定义，当前最多 8 个奖励位；普通路线和带 A 支路路线的实际资格由房间布局的 `constructionRewardWaves` 决定。

## 明确排除

- 训练弓、布履、青龙：开局装备，不是掉落资产。
- 快马、司晨、豕涉、守冢、囤积、素食、涂炭、焚书：当前只通过入口原型套件生成，不属于普通战斗掉落。
- Boss 奖励：当前仍是“装备 · 未入库”占位，没有正式资产合同，不能提前绘制。
- 已退役技能书：不进入当前运行资源和掉落范围。

## 验收入口

- [掉落矩阵](drop-matrix.json)
- [六项资产预览](preview.html)
- [资产哈希与规格](asset-record.json)
- [验证记录](../../../docs/mvp/首关实际掉落资产_实施记录_2026-11-03.md)
- [后台验证记录](../../../docs/mvp/首关实际掉落资产_验证_2026-11-03.json)

视觉风格沿用当前已接入的皮影主导、像素质感为辅方案；本轮不修改掉落概率、奖励顺序、物品效果或运行引用。
