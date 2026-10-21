# T14：Windows 实机验证与双平台结果收束

**状态：** 已审核并发布为 [#16](https://github.com/Bacsonlx/NineTripodCauldrons/issues/16)，标记 ready-for-agent；未开工。

## Parent

[[Spec] MVP-02：汤谷大地图、全屏与弓箭战斗切片（macOS／Windows）](https://github.com/Bacsonlx/NineTripodCauldrons/issues/2)

## What to build

在 Windows x64 实机验证用户收到的最终 ZIP，修复兼容问题并与 Mac 结果对齐，给出完整双平台验收记录。

**规格覆盖：** AC-01、AC-25、AC-29、AC-30。涉及跨票组合时，最终在 T12—T14 复验，不把部分覆盖记成整项通过。

沿用父规格的技术栈、二维等距世界、离线图集与公开行为测试入口；数值从父规格可调初值起步，记录实际值，不改变验收门槛。本票变更运行必要检查；涉及窗口、资源或构建时完成对应打包检查，并注明实际运行平台。

## Acceptance criteria

- [ ] 使用用户实机或经用户提供的可用 Windows x64 环境，记录系统、CPU／GPU、内存、刷新率、缩放和 ZIP／源码标识；无环境或无报告则保持未验收。
- [ ] 解压完整 ZIP 并离线运行，验证全部适用功能、资源、画风、普通／超宽比例、最大化／全屏、Alt-Tab 后暂停、重试与输入清理。
- [ ] 预热后在 1080p 前台连续跑射施技采样 60 秒，平均至少 58 FPS、至少 95% 帧间隔不超过 20 ms，保存完整数据；另做 5 分钟稳定性与内存／对象清理记录。
- [ ] 若修复 Windows 问题导致代码、素材或玩法变化，生成同版两端产物并复验受影响 Mac 项；必要时重做性能，记录最终实际参数和证据。
- [ ] 逐项对齐 AC-01—AC-30、资产与两端结果；失败或缺失不得用另一端抵消，不把 ZIP 构建成功、JS 测试或截图替代实机。
- [ ] 交付最终双平台结论、产物和待处理事项；所有完成条件满足前不声称 Spec 完成，不自动修改或关闭父 Spec #2 或旧 MVP-01 #1。

## Blocked by

- [T13 / #15：最终双平台 ZIP 交付与 macOS 实机验收](https://github.com/Bacsonlx/NineTripodCauldrons/issues/15)
