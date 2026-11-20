# 祠庙前院正式素材 v1

2026-11-09。用户确认祠庙前院、三位服务 NPC 与孩子的局外身份，随后要求直接制作正式版本。正式采用的运行图由本轮内置 ImageGen 生成，角色规划与检查按 [Sprite Forge 项目指南](../../../docs/art/Agent_Sprite_Forge使用指南.md)执行。下表的选用理由由实现者记录，原生视觉验收待前台试玩。

| 对象 | 参考和取舍 | 正式源文件 | 运行引用 |
| --- | --- | --- | --- |
| 祠庙前院 | 项目皮影与纸纹的画风说明。中央连通，炉台、祠门与摊位各有地标，背景无人。 | [courtyard.png](courtyard.png) | [地图场景](../../../godot/scenes/safehouse.tscn) |
| 铁匠 | 靛衣皮围裙、锤与炉火形成清楚轮廓，单张透明站姿。 | [smith.png](smith.png) | 地图 `People/Smith` |
| 商人 | 青衣、算盘与赭色腰带区分服务角色，单张透明站姿。 | [merchant.png](merchant.png) | 地图 `People/Merchant` |
| 守祠人 | 浅衣、青边与礼器匹配祠门地标，单张透明站姿。 | [keeper.png](keeper.png) | 地图 `People/Keeper` |
| 孩子 | 附入[既有四向人物参考](../../mvp/child-upper-refined-v3.png)，生成右、正、左、背四向无武器上身。沿用既有四向待机与行走下肢，按腰线和脚点接合。 | [child-turnaround.png](child-turnaround.png) | [安全屋角色呈现](../../../godot/scripts/hub/safehouse.gd) |

本轮 PNG 原件均与 `godot/assets/hub/` 运行副本字节一致。NPC 以脚点对齐地图，孩子按 512×768 裁切四向上身，使用既有下肢图集。没有使用视频生成。图像路线为内置 ImageGen，工具未返回具体模型或费用。完整提示词见 [prompts.md](prompts.md)，图像尺寸、可见边界与透明度见 [alpha-geometry.json](alpha-geometry.json)，校验见 [SHA256SUMS](SHA256SUMS)。

后台导入和安全屋流程验证见[实施记录](../../../docs/mvp/局外安全屋_实施记录_2026-11-09.md)。透明度、脚点和帧切换属于素材与结构检查。角色比例、方向、场景可读性和整体画面待实际窗口评审。

2026-11-09 窗口布局修复同时调整了角色纹理的导入采样。铁匠、商人、守祠人和孩子四向上身沿用同一批 PNG，运行导入生成多级缩小纹理，前院人物层采用线性多级采样。后台从导入资源读取到 10–11 级缩小纹理，实际窗口待复验。[纹理检查](../../../output/hub-layout-20261109/textures.log)
