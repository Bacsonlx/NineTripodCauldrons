# 技术验证采用 Electron、Phaser 与 Forge Webpack

当前状态（2026-10-20）：本工具链决定已由 [ADR-0010](0010-godot-migration-direction.md) 取代。现役工程为 Godot 原生2D＋带类型GDScript；Electron／Phaser代码保留作旧版参照。版本化JSON仍是后续正式存档方案，当前汤谷未实现正式存档。下文保留历史选型理由。

2026-10-16 已确认：以 Electron、TypeScript、Phaser WebGL、Electron Forge＋Webpack 以及带版本的 JSON 存档作为技术验证基线。Electron 承担桌面能力，Phaser 承担游戏框架职责；具体版本在真实安装包验证后锁定。

Phaser 用于复用二维游戏基础设施，避免从纯渲染库起步补齐所有系统。早先的 Forge Vite 建议已由 Forge Webpack 取代，原因是官方 Vite 插件仍有实验性及小版本不兼容提示。JSON 用于当前小范围单机进度；它本身不保证多项结算的一致提交，仍需实现和测试恢复协议。
