# Steam 早期接入核查

2026-10-19。此阶段仅调查，不加载 SDK，不要求 Steam 账号或网络才能玩小样。

候选为官方 Godot＋GodotSteam GDExtension，保持现有官方引擎与导出模板，不引入自编译引擎。GodotSteam 的当前维护源为 [Codeberg](https://codeberg.org/godotsteam/godotsteam)，不是将旧 GitHub 镜像作为主源。

[Godot 官方资产库条目](https://godotengine.org/asset-library/asset/2445)在核查时列出 4.23.1（2026-10-07），Godot 4.4+、Steamworks SDK 1.65、MIT；声明覆盖 Windows 32/64、Linux、Android arm64 和 Mac Universal。本项目候选目标为 Windows x64 与 Mac arm64。上述是上游声明，尚未取得本项目 4.7.2＋两平台的插件加载实证；不将“4.4+”推断为已验证兼容。

后续商业闭环接入前，下载并固定扩展版本、二进制校验、许可证与对应 Steamworks SDK，逐平台验证扩展加载、Steam 初始化／离线失败退化、回调、Overlay、退出，以及 Mac 签名／权限与 Windows DLL 分发。初始化失败时须能继续单机离线运行。不能混用模块版与扩展版，说明见 [GodotSteam 发行说明](https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/)。

Steamworks 的账户、App ID、SDK 使用和发行条款在正式接入时由项目发行方核实；当前不将社区扩展 MIT 许可当成 Valve SDK 的许可。商业签名和公证后续配置，当前仅本地小样，参见 [Godot macOS 导出说明](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html)。
