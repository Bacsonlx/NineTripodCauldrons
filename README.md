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
npm run package  # 检查并构建当前系统的应用目录
npm run make     # 检查并生成当前系统的分发包
```

当前入口验证 Electron 主进程、隔离 preload、类型化 IPC 和 Phaser WebGL 启动。战斗、剧情、存档与原型闭环尚未实现。

2026-10-16 已验证 macOS arm64 开发启动、应用打包和 ZIP 生成；版本及检查详情见 [工程初始化记录](docs/工程初始化记录.md)。Windows 运行与发行签名尚未验证。当前 `make` 生成 ZIP 分发包。

## 目录

- `src/desktop/`：桌面主进程与 preload。
- `src/renderer/`：窗口页面与游戏启动。
- `src/game/`：Phaser 场景。
- `src/shared/`：进程间共享类型与通道常量。
- `docs/`：规则、架构结论与 ADR。
- `output/十日_战斗概念图/`：前期概念图与提示词，不是已制作的游戏素材。

## 设计依据

- [架构选型结论](docs/九鼎_架构选型结论.md)
- [玩法与运行规则](docs/十日_玩法与运行规则.md)
- [领域术语](GLOSSARY.md)
- [世界观与故事框架 v1.2](十日_世界观与故事框架_v1.2.pdf)

任务由当前仓库的 GitHub Issues 跟踪；Matt Pocock 技能配置复用用户级 `~/.agents/mattpocock-config/`。具体消费规则见 [AGENTS.md](AGENTS.md)。

当前安装包未配置发行签名。跨平台运行与 1080p／60 FPS 目标需要后续分别实测。
