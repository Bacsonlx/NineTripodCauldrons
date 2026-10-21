# 首关 HUD 素材与绑定

本页保留首轮规格；当前头像、颜色、背景和字体的细化见[HUD v2说明](../hud-v2/README.md)。

2026-10-21，用户要求按确认的 [原型](prototype.png) 更新正式第一关，并新增清晰怪物血条。原型战场为概念图，不作为实际引擎截图。

- 左上：88 逻辑像素孩子头像、生命条和真实 `health / 100`；蓝量、精力保留配色并标注“未启用”，不新增消耗规则或演示数值。
- 左下：四个 60 像素动作图标，总宽 276 像素；左键普攻、Q 穿透箭、E 箭雨、空格闪避。Q／E／闪避遮罩及剩余时间来自公开冷却快照，暂停冻结；冷却总时长沿用 4／8／1 秒。
- 怪物：48×6 世界单位描边血条，绑定现有 60 点生命，跟随位置；受击变亮，死亡／未激活／换房后隐藏。

静态图集：[hud-atlas.png](../../../godot/assets/ui/hud-atlas.png)，1536×1024，原生 RGBA，未抠图或缩放。通过同目录五个 `AtlasTexture` 精确取图，文字、按键、数值和冷却遮罩由 Godot 实时绘制。缩小显示使用线性过滤与 mipmaps。

生成路线为内置 `image_gen`，角色身份与风格来自已确认原型；不调用付费 API 或外部 CLI。完整 [提示词](prompt.txt)、[区域及来源校验](provenance.json) 随仓库保留。宿主未报告具体图像模型和费用，不推测。

仅在首关呈现层接入新 HUD，旧小样保留文字 HUD；怪物血条增强复用共享呈现层。没有修改战斗伤害、冷却、碰撞、怪物数量或房间布局。运行入口仍为 `godot/scenes/tanggu_first_level.tscn`。

验证使用 `python3 tools/migration/check_godot.py`，包含新增 `hud_checks.gd` 的真实输入、生命／冷却与四种尺寸布局检查；导出用 `python3 tools/migration/export_godot.py`。实际结果见 [交付记录](../../../output/ui/hud-implementation-20261021/README.md)。后台验证不代表原生 GPU 画面、鼠标体验或 Windows 实机验收通过。
