# 首关左上 HUD 样式细化

2026-10-21，按用户反馈继续贴近[确认原型](../hud-v1/prototype.png)。本次实现样式与素材，能耗规则单独[规划](../../../docs/product/首关_蓝量与精力规划_v0.1.md)，未把建议数值写成正式资源状态。

## 样式

| 元素 | 当前规格 |
| --- | --- |
| 头像 | 同一孩子、红巾、米白衣、侧向目光、青铜圆框与墨黑内底；104×112逻辑像素槽，等比显示 |
| 文字 | 暖白 `#F2E6C5`、深墨阴影；姓名22、资源文字／数值14逻辑像素 |
| 状态底衬 | `#111611EB`、无硬边暗影，承托姓名和状态文字，人物圆框压在其左侧 |
| 青铜细边 | `#9A7F4D` |
| 生命／蓝量／精力填充 | `#D9422D`／`#14A9BD`／`#4D943E`，填充顶部有一像素浅色高光 |
| 未启用状态 | 两个资源仍为空条和“未启用”，不显示原型演示数值；整体适当降低亮度 |

上述是匹配原型画风的样式值，不声称逐像素还原原型的纹理取色。左下四动作大小、位置以及怪物血条保持上一轮实现。

## 新头像

运行源图：[portrait-v2.png](../../../godot/assets/ui/portrait-v2.png)，原生RGBA与透明边保留；`portrait.tres`取整图，线性mipmaps缩小显示。新图只细化头像，四个动作图标继续复用原图集。

路线为内置 `image_gen`，以已确认原型作为实际图片参考；[完整提示词](portrait-prompt.txt)与[来源／尺寸／校验](portrait-provenance.json)已保留。请求512×512，工具实际返回1280×1280，以实际尺寸绑定；未调用外部API或CLI、未推测图像模型或费用。

## 随包字体

采用 [Google Fonts 官方 Noto Serif SC](https://github.com/google/fonts/tree/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/notoserifsc) 固定提交，来源许可为 [SIL OFL 1.1](../../../godot/assets/fonts/OFL-NotoSerifSC.txt)。用临时隔离环境中的 `fonttools==4.60.1` 固定字重500，保留基本汉字、ASCII与标点及当前脚本字符，移除无关字形后另名为 `NineTripods HUD Song`。原始与成品哈希、上游提交和覆盖说明见[字体来源](font-provenance.json)。未复制系统宋体。

运行字体：[NineTripodsHudSong.ttf](../../../godot/assets/fonts/NineTripodsHudSong.ttf)，随包加载、禁用系统回退；中文界面与数值不依赖开发机字体。OFL全文同时加入 `godot/THIRD_PARTY_NOTICES.txt`，由既有导出脚本随两平台包附带。稀有扩展汉字／新增图符超出当前覆盖时需要按来源重新扩字，不静默依赖系统替补。

后台检查包含28项HUD状态、字体覆盖、点击穿透和四尺寸布局，以及既有完整项目回归。实际构建／干净导入／Mac包后台启动证据见[本轮交付记录](../../../output/ui/hud-refinement-20261021/README.md)；前台GPU画面、字体在屏幕上的阅读感与Windows实机仍待验。
