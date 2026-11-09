# 祠庙供台首页素材 v1

2026-10-24。用途：原生 Godot 初始页。用户已授权「先接通首页与真实征程入口」；本轮将原型素材接入，原生最终画面仍待前台确认。战斗主角、角色动画和正式背包资源未替换。

> 后续行为校准：当前 `home_screen.gd` 已打通首页与局内的 50 格正式背包（`prepared_alpha` 初始包含训练弓、布履、青龙、羊角、鼠毫、素食），首页拖拽整理的构筑结果通过 `home_initial_backpack` 传入本局出发；下文表格中“试装与属性未生效”描述的是 2026-10-24 首轮接入时的历史状态。底图、立绘 `hero-refined-v2.png`、字体与 SVG 槽位图标的源文件及运行引用保持不变。

## 参考、候选与交付

| 关系 | 对象／版本 | 处理与依据 | 确认／证据 |
| --- | --- | --- | --- |
| 原型 → 选择 | [ImageGen / HTML 原型](../../../output/ui-home-imagegen-20261023/README.md) | 保留祠庙供台布局与主角精修 v2。用户先要求优化主角，随后授权首页接入 | 接入授权为 2026-10-24 对话；不推导为原生视觉验收 |
| 候选 → 正式源文件 | [场景底图](shrine-background.png)、[透明主角 v2](hero-refined-v2.png) | 逐字节复制原型对应 PNG，无重新生成／调色／裁切。AI 选择 v2 作为本轮实现基线，细化衣纹、镂刻与铜制关节 | 生成路线为内置 `image_gen`，工具未披露模型及费用。完整提示词保存在本目录四个 `*-prompt.txt` |
| 正式源文件 → 运行文件 | 本目录 PNG → [Godot 首页资源](../../../godot/assets/ui/home-v1/) | 相同 PNG 复制，标准导入；运行使用 Godot 原生 TextureRect，保留真实 alpha | 源／运行 SHA-256 见 [provenance.json](provenance.json) |
| 图标与数据 → 运行文件 | 原 HTML `data.js` → [items.json](../../../godot/assets/ui/home-v1/items.json) 与 [icons](../../../godot/assets/ui/home-v1/icons/) | 沿用 24 件展示数据；将既有 SVG path 独立成文件，固定金色。没有生成新物品图或发明属性 | 首页与详情明确标记试装与属性未生效；不应用战斗效果 |
| 运行文件 → 引用 | [home.tscn](../../../godot/scenes/home.tscn)、[home_screen.gd](../../../godot/scripts/presentation/home_screen.gd) | 场景引用底图；脚本引用立绘／JSON／图标，字体复用既有 `NineTripodsHudSong.ttf` | 入口和验证见 [首页实施记录](../../../docs/mvp/首页与征程入口_实施记录_2026-10-24.md) |

原生成记录：整页 `exec-ff7b0fe2-3150-41aa-b4e0-2d04b9f40654.png`，底图 `exec-dcca1bbc-b45a-43e2-bf8e-0246f4b344a2.png`，主角 v1 `exec-5f8ef40c-17b7-49d5-94f8-270a405928d3.png`，v2 `exec-250b7256-c996-47b1-a782-f592a50bb268.png`；原始工具输出保存在 `$CODEX_HOME/generated_images/01a16945-8d7d-7181-80a4-bd05cb3e8479/`。正式运行只引用仓库资源。

字体来源与许可沿用 [HUD 字体记录](../hud-v2/font-provenance.json)及工程 [OFL](../../../godot/assets/fonts/OFL-NotoSerifSC.txt)。本轮没有新增第三方素材或在线依赖。

视觉确认范围：HTML 原型已有浏览器截图和 AI 检查，Godot 无头结构检查仅证明加载与布局边界；不代表纹理清晰度、裁切、色彩和原生点击体验已经通过。

## 分类证据（2026-10-24）

- 构建／导入：正式工程及无缓存副本导入通过，Mac／Windows 构建通过。PNG 源／运行文件一致，导入开启 mipmaps，UI 使用线性采样。
- 逻辑／回归：首页流程 6 项、界面 20 项及既有完整检查通过；随包字体覆盖首页、隐藏仓库与物品文案，缺失符号已改为现有字形。
- 运行／加载：导出 Mac 程序无头启动首页／level／boss 通过，同包 PCK 资源执行首页流程与界面检查通过。
- 交互：按钮／Esc／焦点只覆盖后台适配层，真实键鼠待前台。
- 视觉、性能：未做原生窗口或 GPU 画面对照、帧率／长时采样；Windows 实机仍暂缓。

完整证据与产物校验见[实施记录](../../../docs/mvp/首页与征程入口_实施记录_2026-10-24.md#验证证据)。本轮没有残留构建／脚本错误。
