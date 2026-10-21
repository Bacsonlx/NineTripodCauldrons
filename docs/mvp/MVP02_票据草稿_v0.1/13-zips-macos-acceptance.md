# T13：最终双平台 ZIP 交付与 macOS 实机验收

**状态：** 已审核并发布为 [#15](https://github.com/Bacsonlx/NineTripodCauldrons/issues/15)，标记 ready-for-agent；未开工。

## Parent

[[Spec] MVP-02：汤谷大地图、全屏与弓箭战斗切片（macOS／Windows）](https://github.com/Bacsonlx/NineTripodCauldrons/issues/2)

## What to build

获得同一版玩法和代表美术的 macOS Apple Silicon／Windows x64 ZIP，并完成 Mac 解压离线运行、功能、美术和性能验收，交给用户可复现的 Windows 验收步骤。

**规格覆盖：** AC-01、AC-29、AC-30。涉及跨票组合时，最终在 T12—T14 复验，不把部分覆盖记成整项通过。

沿用父规格的技术栈、二维等距世界、离线图集与公开行为测试入口；数值从父规格可调初值起步，记录实际值，不改变验收门槛。本票变更运行必要检查；涉及窗口、资源或构建时完成对应打包检查，并注明实际运行平台。

## Acceptance criteria

- [ ] 运行类型检查、完整适用测试及打包检查，生成两个平台 ZIP，记录版本、源码／工作区标识、实际参数和产物校验信息。
- [ ] 从最终 Mac ZIP 解压启动并离线操作，验证本地素材、加载失败提示、最大化／全屏、焦点、全部技能、三组遭遇及重试，不以开发服务器结果替代产物。
- [ ] 在 Apple Silicon Mac 记录系统、CPU／GPU、内存、刷新率、缩放、内部与输出尺寸，逐项记录 AC-01—AC-30 的适用 Mac 结果与动态美术证据。
- [ ] 1080p 输出预热后前台完整采样 60 秒，包含活动影偶、普通箭、Q、E 和闪避；平均至少 58 FPS、至少 95% 帧间隔不超过 20 ms，保存完整可复核数据。
- [ ] 另做 5 分钟连续操作，检查崩溃／卡死、对象清理与内存趋势；打断采样记录原因并重采，不删除慢帧或伪造焦点。
- [ ] 提供 Windows 完整 ZIP、解压启动与功能／全屏／性能步骤、设备与数据回传模板；构建成功仅记为产物交付。
- [ ] 本票在两端 ZIP 已交付且 Mac 验收通过时可完成；Windows 实机结果留在 T14，未返回时保持待验，不声称父规格已完成，也不阻塞前面功能票完成。

## Blocked by

- [T12 / #14：战斗特效、HUD 与全状态整合复验](https://github.com/Bacsonlx/NineTripodCauldrons/issues/14)
