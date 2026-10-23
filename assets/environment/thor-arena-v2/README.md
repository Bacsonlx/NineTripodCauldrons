# 索尔雷庭：全视野环境细节 v2

2026-10-23。用户指出 Boss 页未铺满视野、地图过于像单张背景，并授权前台验收。本轮只调整 Boss 呈现，延续已确认的焦土雷庭方向；角色、三招规则、门连接、行走边界不变，不增加场内障碍。v2 运行视觉由 AI 检视，尚未取得用户最终确认。

## 来源与选择

内置 imagegen 参考 [v1 地面](../thor-arena-v1/floor.png)生成四格透明贴花，完整提示词见 [prompt.txt](prompt.txt)。首版 [candidate-v1.png](candidate-v1.png) 有跨格实体／可见像素，各 1 项，未进入运行；随后将首版实际附图，按 [gutter-fix-prompt.txt](gutter-fix-prompt.txt) 修订透明间隔，选定 [ground-details.png](ground-details.png)。实际输入、原始输出路径、哈希、取图区域见 [generation.json](generation.json)。模型标识与费用未由工具返回，记录为未知；未调用视频或付费 API。

正式源图为 1254×1254 RGBA，2×2 每格 627×627，依次为焦痕、灰烬、铜纹残片、祭祀划痕。源像素与 alpha 保持原样；直接复制至 `godot/assets/boss/thor-arena-v2/`，四个原生 AtlasTexture 固定区域并启用 `filter_clip`。各格中心为锚点，地面 z=-20，无碰撞。

## 接入

[环境场景](../../../godot/scenes/world/boss_environment.tscn) 继续使用 v1 石坪，加上低对比贴花、铜质边界线，并放大既有残墙、残柱、枯根及红树形成外围层次。底层复用既有森林纹理随可见范围扩展；[地面边缘 Shader](../../../godot/scripts/world/boss_ground_edge.gdshader) 仅淡化石坪外缘，避免矩形贴图边界。环境遮挡与灰烬时间读取现有快照，暂停冻结。

Boss 专用镜头完整容纳行走边界外 80 单位的落雷预警，并预留 HUD；横屏、方屏、超宽及竖屏由外围环境填满视野。其他房间的相机方式不变。独立 Boss 入口及直接进入 Boss 的主线调试入口默认全屏，保留 F11／现有按钮切换。

## QA 与证据

[修订后贴花 QA](../../../output/art/BOS-001/2026-10-23-arena-v2/decal-qc-fixed/sheet-qc.json) 无失败：跨格实体、可见跨格、图外截断、空格及 13px 边界带均为 0。保留两项警告：`safe_frame=4`（不足建议 15% 留白），`faint_specks={floor_px:131114, detached_components:24}`。采用原区域裁片，保留透明灰烬边缘，不自动清理源图。

[原生全屏截图](../../../output/art/BOS-001/2026-10-23-arena-v2/native-fullscreen-final.png)来自同一临时 macOS QA 应用；只为定位 Boss 使用独立名称／包 ID、默认公共 Boss 启动选项和一次窗口诊断，未改变正式入口。截图显示暂停状态下的真实 GPU 画面，顶部系统共享指示属于捕获环境。R 重置、暂停／恢复、移动及 F11 有原生观察；不声明鼠标射击、闪避效果或完整原生通关已验收。测试应用已退出并确认进程结束。

全量回归、无缓存导入、578 次 Boss 场景采样／断言、双平台构建、Mac 原生包后台加载及两包资源检查见 [verification.json](../../../output/art/BOS-001/2026-10-23-arena-v2/verification.json)。Windows 实机和正式性能采样未执行。用户最终视觉确认仍待反馈。
