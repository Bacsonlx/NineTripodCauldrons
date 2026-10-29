# 首关装备与道具图像原型 v1

2026-10-25。用户明确确认补齐当前首关 20 项资产并集成。交付为 12 件器／契／符、训练弓、布履、青龙库存图标、5 本技能书；现有血囊／蓝囊继续使用。图片原型进入现有首关物品流程，玩法、投放预算、占格和装备属性沿用当前实现。

## 2026-10-27 运行引用变更

用户确认取消技能书概念和机制，采用[装备与羁绊合同](../../../docs/product/技能来源规则_装备与羁绊.md)。本目录20张源图、提示词、asset-record及预览保留为2026-10-25制作快照；其中五张书图已退役，不再作为游戏需求或运行图标。下文20项交付与菜单说明均属于原轮次历史。

当前15项器／契／符／装备／神兽图标继续由[item_art.gd](../../../godot/scripts/presentation/item_art.gd)引用；五张书的运行PNG、导入描述和AtlasTexture均已移除，避免all_resources导出继续携带。移除路径与SHA-256见[退役清单](../../../output/verification/2026-10-27-equipment-skills/retired-runtime-assets.json)；源图仍在本目录，可据历史记录还原。未重绘图像。

这是用户对机制的决定；AI据实际引用移除专属副本，未将源图删除视为美术评审。契「焚书」独立于技能书，保留图像与效果。运行来源变为文字说明，验收见[本轮记录](../../../docs/mvp/技能来源修订_实施记录_2026-10-27.md)，原生视觉仍待验。

## 参考、候选与交付

任务标识 `FIRST-LEVEL-ITEMS`。需求清单来自 [alpha_state.gd](../../../godot/scripts/alpha/alpha_state.gd) 的 20 项 `CONTENT`，玩法合同见 [十二件原型记录](../../../docs/mvp/第一关玩法补全_道具原型实施记录_2026-10-24.md) 与 [第二批技能记录](../../../docs/mvp/第一关玩法补全_第二批技能实施记录_2026-10-24.md)。

| 关系 | 对象与依据 | 决定与边界 |
| --- | --- | --- |
| 参考 → 候选 | Q23 皮影主导画风、现有 [药囊合同](../potion-pouches-v1/README.md) 和上述物品用途；[完整提示词集](prompts.json) | 仅文字上下文，未附图像参考；器为动物形器物、契为同族契牌、符为护符、技能书以封面符号区分 |
| 候选 → 选择 | [候选目录与生成路径](../../../output/art/FIRST-LEVEL-ITEMS/2026-10-25-v1/all-generated-paths.json)；本目录 20 张原始 PNG | 用户确认 20 项范围及沿用皮影风，授权接入；未逐张确认最终视觉。AI按主体完整、同族材质、用途图案和真实 alpha 选用此次首个有效结果；鼠毫首次调用未返回产物，重试得到当前源图 |
| 选择 → 源文件 | 本目录 PNG、[校验与裁切记录](asset-record.json) | 内置 `image_gen`，`art_source=host_image`；工具未披露具体模型和费用。所有原图 1254×1254 RGBA，原始像素未编辑 |
| 源文件 → 运行资源 | [Godot 目录](../../../godot/assets/items/first-level-v1/)、[名称映射](../../../godot/scripts/presentation/item_art.gd) | 运行 PNG 与源图逐字节一致；Godot 无损导入时限制 256，AtlasTexture 按已记录主体区域裁切，线性过滤、不生成 mipmap |
| 运行资源 → 真实流程 | [地面物品](../../../godot/scripts/gameplay/world_items.gd)、[营地](../../../godot/scripts/gameplay/camp_panel.gd)、[跨格图层](../../../godot/scripts/presentation/item_grid_art.gd)、[嵌符](../../../godot/scripts/alpha/equipment_panel.gd)、[技能来源](../../../godot/scripts/alpha/skills_panel.gd) | `tanggu_first_level.tscn` → `room_journey_scene.gd` → 营地／地面图层；选择器沿现有真实实例 ID。格子仍处理点击，跨格图层忽略鼠标；旋转按真实占格，燃烧／灰烬改变色调 |
| 接入 → 验证 | [实施与分类证据](../../../docs/mvp/首关装备与道具图像_实施记录_2026-10-25.md)、[源图预览](preview.html) | 自动化引用、加载与原生体验分别记录；预览不是 Godot 游戏截图 |

## 20 项源图

| 类别 | 文件 |
| --- | --- |
| 器 | [快马](swift-horse.png)、[司晨](dawn-rooster.png)、[豕涉](water-boar.png)、[守冢](grave-guard.png) |
| 契 | [囤积](hoard-pact.png)、[素食](herb-pact.png)、[涂炭](charcoal-pact.png)、[焚书](burning-pact.png) |
| 符 | [鼠毫](rat-whisker.png)、[虎牙](tiger-fang.png)、[羊角](ram-horn.png)、[燧火](flint-fire.png) |
| 装备／神兽图标 | [训练弓](training-bow.png)、[布履](cloth-shoes.png)、[青龙](azure-dragon.png) |
| 技能书 | [穿透箭](piercing-book.png)、[箭雨](rain-book.png)、[回风](backwind-book.png)、[蓄势](charge-book.png)、[引风书](dragon-wind-book.png) |

## 显示合同

- 地面物品按 44×44 世界单位范围等比适配，底边距脚点 2；保留名称和地环。实际屏幕尺寸受相机倍率影响。
- 营地列表固定 32×32 图标，详情 96×96；格子内图像按真实跨格区域适配，旋转时同转。多格物品下方显示名称，单格护符通过列表和悬停提示查看名称。燃烧橙色、灰烬暗灰；灰烬沿用来源轮廓，不引入新资产。
- 嵌符／技能来源菜单图标最大宽度 24；图片只供识别，不替代真实实例、占格和效果裁决。青龙是库存图标，训练弓是物品图片，不代表新增神兽动作或替换角色持弓动画。
- 原图 alpha 范围均为 0—255，完全透明像素占 44.58%—94.61%；完整尺寸、包围盒、区域和 SHA-256 在 `asset-record.json`。裁切以 alpha≥8 主体框加 4 源像素留边计算，不重绘、不抠色。

## 体验与待验

运行 `./play --test level`，入口营地可查看初始装备与技能书，点击“领取十二件道具原型 · 本局一次”查看全部器／契／符；在营地拾取、放置、嵌符或绑定 V，确认构筑后出发。图片不会自动把未拾取物品塞入仓库。

源图、引擎呈现和最终美术认可分别验收。20 项范围已确认，逐图最终视觉、原生缩小辨识度、遮挡、真实键鼠与前台性能仍待用户安排；Windows 实机仍暂缓。当前分类结果以实施记录为准。
