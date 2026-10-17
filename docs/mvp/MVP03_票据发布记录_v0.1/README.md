# MVP-03 票据发布记录

2026-10-18。用户已批准 15 项拆分及 16 条阻塞关系；均已发布为 [Spec #17](https://github.com/Bacsonlx/NineTripodCauldrons/issues/17) 的原生子 Issue，并设置 ready-for-agent。

已通过远程回读核对：15 项标题／正文／标签／开启状态一致，父子关系正确，16 条原生阻塞关系逐项一致；父规格正文、标题、标签和开启状态未改写。未开始开发、未提交或推送代码、未重新采样。

| 票据 | Issue | 原生阻塞 |
| --- | --- | --- |
| T01 跑通主路、两支路与捷径预留的灰盒流程 | [#18](https://github.com/Bacsonlx/NineTripodCauldrons/issues/18) | 无 |
| T02 制作一处岔口与战斗区的环境动态小样 | [#19](https://github.com/Bacsonlx/NineTripodCauldrons/issues/19) | #18 |
| T03 精修普通箭从拉弦到命中的完整反馈 | [#20](https://github.com/Bacsonlx/NineTripodCauldrons/issues/20) | 无 |
| T04 精修穿透箭聚光、贯穿与障碍终止反馈 | [#21](https://github.com/Bacsonlx/NineTripodCauldrons/issues/21) | 无 |
| T05 精修箭雨预告、分段落箭与地面冲击 | [#22](https://github.com/Bacsonlx/NineTripodCauldrons/issues/22) | 无 |
| T06 精修闪避墨影残像、扬尘与消散 | [#23](https://github.com/Bacsonlx/NineTripodCauldrons/issues/23) | 无 |
| T07 整合动态小样并取得用户画面确认 | [#24](https://github.com/Bacsonlx/NineTripodCauldrons/issues/24) | #19、#20、#21、#22、#23 |
| T08 跑通残碑阅读与安全 F 互动 | [#25](https://github.com/Bacsonlx/NineTripodCauldrons/issues/25) | #24 |
| T09 接入一次性回血祭坛与满血不消耗 | [#26](https://github.com/Bacsonlx/NineTripodCauldrons/issues/26) | #25 |
| T10 接入内侧开栅门与可往返捷径 | [#27](https://github.com/Bacsonlx/NineTripodCauldrons/issues/27) | #25 |
| T11 精修完整主路、三庭院与地标引导 | [#28](https://github.com/Bacsonlx/NineTripodCauldrons/issues/28) | #24 |
| T12 精修两支路并完成正式探索内容接入 | [#29](https://github.com/Bacsonlx/NineTripodCauldrons/issues/29) | #26、#27 |
| T13 整合全图战斗探索并完成外部行为复验 | [#30](https://github.com/Bacsonlx/NineTripodCauldrons/issues/30) | #28、#29 |
| T14 交付双平台运行包并验收 macOS 实际体验 | [#31](https://github.com/Bacsonlx/NineTripodCauldrons/issues/31) | #30 |
| T15 收集 Windows 实机结果并收束平台记录 | [#32](https://github.com/Bacsonlx/NineTripodCauldrons/issues/32) | #31 |

当前无阻塞前沿：[T01 #18](https://github.com/Bacsonlx/NineTripodCauldrons/issues/18)、[T03 #20](https://github.com/Bacsonlx/NineTripodCauldrons/issues/20)、[T04 #21](https://github.com/Bacsonlx/NineTripodCauldrons/issues/21)、[T05 #22](https://github.com/Bacsonlx/NineTripodCauldrons/issues/22)、[T06 #23](https://github.com/Bacsonlx/NineTripodCauldrons/issues/23)。

动态画面确认由 T07 保留；碑文由 T01 提交候选、T08 可先以明确占位验证能力、T12 正式接入前单独获批；Windows 实机在 T15 等待用户回传。任何准备完成、包构建或未回复都不能自动代替这些条件。

每个同名 Markdown 文件保存发布正文；manifest.json 保存映射与正文哈希，verification.json 保存逐项远程核对结果。所有验收框仍未勾选，不表示功能或平台已通过。
