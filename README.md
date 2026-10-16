# 九鼎

主 IP：九鼎。副 IP：十日。

Windows／macOS 单机动作肉鸽游戏的技术验证工程，采用固定等距二维战斗与分层 2.5D 表现，目标画风为皮影主导的像素质感混合风格。

## 开发

使用 Node.js 22 或更新版本；当前工程使用 npm 和 `package-lock.json`。

```sh
npm ci
npm start
```

```sh
npm run check    # TypeScript 检查
npm test         # 单房间移动、射箭、碰撞和状态边界
npm run package  # 检查并构建当前系统的应用目录
npm run make     # 检查并生成当前系统的分发包
```

当前入口是 MVP-01 汤谷试弓庭：WASD 跑动，鼠标独立瞄准，左键短按／按住射箭，Esc 暂停／恢复，R 重置。失焦自动暂停，回到窗口后需按 Esc 继续。按 F1 可临时显示碰撞参考区域。

人物和弓箭使用透明 PNG 精修样例，地面、柱和靶使用本项目绘制的 SVG。人物四方向、两张跨步关键帧与拉弦姿态用于动态评审；手部对位、步态过渡和开弓形变仍需打磨。来源、脚点及生成提示词见 [美术制作说明](assets/mvp/精修制作说明_v2.md)。

当前 `make` 生成 ZIP；Windows x64 可在本机执行 `npm run make -- --platform=win32 --arch=x64`。用户已选择先生成 Windows ZIP，再在 Windows 实机验收。构建成功不代表 Windows 运行通过；测试设备、当前产物和待验项目见 [MVP 实现与验收记录](docs/mvp/MVP01_实现与验收记录.md)。

## 目录

- `src/desktop/`：桌面主进程与 preload。
- `src/renderer/`：窗口页面与游戏启动。
- `src/game/`：Phaser 场景与可独立推进的房间规则。
- `assets/mvp/`：MVP 图集、原始素材与制作说明。
- `tests/`：房间规则的外部行为测试。
- `src/shared/`：进程间共享类型与通道常量。
- `docs/`：规则、架构结论与 ADR。
- `output/十日_战斗概念图/`：前期概念图与提示词，不是已制作的游戏素材。

## 设计依据

- [架构选型结论](docs/九鼎_架构选型结论.md)
- [玩法与运行规则](docs/十日_玩法与运行规则.md)
- [领域术语](GLOSSARY.md)
- [世界观与故事框架 v1.2](十日_世界观与故事框架_v1.2.pdf)

任务由当前仓库的 GitHub Issues 跟踪；Matt Pocock 技能配置复用用户级 `~/.agents/mattpocock-config/`。具体消费规则见 [AGENTS.md](AGENTS.md)。

当前安装包未配置发行签名。剧情、存档、Boss、神降和签署闭环仍属于后续范围。Windows 实机验收前，Spec #1 保持未完成。
