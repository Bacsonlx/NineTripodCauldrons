# MVP-03 动态小样证据

候选版本 0.3.0-sample.1；本目录不证明 T07 已获用户通过，也不证明 Windows／macOS 原生验收通过。

- `九鼎_MVP03_动态小样.mp4`：1280×720、约 22 秒，在实际第一庭院操作普通箭／Q／E／闪避；无运行时异常。
- `九鼎_MVP03_通路与战斗走访.mp4`：原视口 756×469，编码仅补齐一行至偶数高度，约 37 秒，三组战斗及两支路走访；末尾 10 次 R 另见摘要。
- 视频来自 Mac 实际包中原样提取的 renderer，隔离 Chromium 仅替代 Electron 窗口 API；CDP 发送键鼠，调试器只安装观察快照，不修改血量、敌人、进度、时钟、焦点或可见性。它们是渲染／玩法证据，不能替代原生桌面验收。
- `browser/summary.json`／`browser/walkthrough.json.gz`：完整走访摘要／逐次只读快照。`showcase/summary.json`：特效演示摘要。两个帧清单保留原始时间戳，视频用 concat VFR 编码，不加速、不剔除慢帧；这不是性能采样。
- `walkthrough.json.gz`：被系统锁屏中断的原生 Mac 尝试；失败／中断不记为通过。`01-start.jpg` 仅是该包截图，不证明窗口实际键鼠通过。
- `renderer-observer.cjs`、`renderer-walkthrough.cjs`、`renderer-showcase.cjs`、`cdp-helper.cjs`：当时使用的本地诊断脚本，原路径及端口保留用于追溯，不随游戏打包。其 `/private/tmp/` 输入依赖属于临时测试夹具；不能直接视为自动化验收套件。
- `test-results.txt`：完整 38 项测试；`route-layout.svg`：与布局对应的通路图。选定截图用于复核质感和遮挡。

原始逐帧 JPEG 与未压缩快照保留在忽略目录 `out/validation/mvp03-raw/`，本目录只纳入选定截图、时间戳、压缩快照和视频。

未执行新的 60 秒／5 分钟性能或稳定性循环。最终包的文件名、哈希及资源核验见同目录 `release-manifest.json`，交付边界与待确认事项见 `docs/mvp/MVP03_动态小样_交付说明.md`。
