# 九鼎 · Godot 迁移动态小样

版本 `0.3.0-godot-sample.1`，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility 原生 2D。工程直接复用既有图集与帧锚点，游戏逻辑不依赖 Node.js。

当前接入移动、独立瞄准、普通射箭、单个影偶的激活／绕障／近战／死亡、一个实体遮挡、相机、生命／伤害反馈及重试。Q／E／闪避、完整汤谷和探索将在本小样试玩确认后接入。

用匹配版本编辑器导入 `project.godot`，运行主场景。也可在仓库根目录执行：

```sh
python3 tools/migration/prepare_sample_assets.py
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/run_tests.gd
godot --path godot
```

规则通过公开的输入＋时间→快照边界验证；快速按键和中断通过输入适配层验证。自动检查不代表画面、原生键鼠或双平台验收完成。

操作：WASD 移动，鼠标独立瞄准，左键点按／按住射箭，Esc 暂停／继续，R 重试，F11 或右上角按钮切换全屏。向右接近石庭激活影偶；站在影偶近处可自然受伤和失败。失焦暂停，窗口变化取消输入但不暂停，鼠标离开取消攻击并保留移动。

导出需安装 `4.7.2.stable` 官方模板；编辑器和模板校验见 `engine-lock.json`。在仓库根目录执行：

```sh
mkdir -p build/godot/windows
godot --headless --path godot --export-release 'macOS Universal'
godot --headless --path godot --export-release 'Windows x64'
```

Mac ZIP 内为包含 arm64 的 Universal 2 应用，使用本地 ad-hoc 签名，未公证；不代表正式商店发行配置。Windows EXE 内嵌资源包，尚需在指定 Windows x64 设备实际启动与操作。试玩包位于 `build/godot/`，完整实现状态见 [实施记录](../docs/migration/Godot迁移_实施记录.md)。
