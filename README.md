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

当前入口是 MVP-02 汤谷弓箭战斗切片：2560×1440 连续手工地图，镜头跟随，启动最大化、可切换全屏，画面铺满任意窗口比例。WASD 跑动，鼠标独立瞄准，左键短按／按住射箭，Q 穿透箭、E 固定范围箭雨、空格闪避，Esc 暂停／恢复，R 从起点重试。三组影偶依次按 2／3／4 激活，清完可继续探索。失焦自动暂停，回到窗口后需按 Esc 继续。

人物、影偶与环境使用本地透明 PNG／地面背景，人物四向各 7 帧跑步，独立上身与完整技能／受击／失败动作；弓和箭保持握点与箭尖一致。源码绘制 HUD、冷却、金色箭雨和朱红预警。原图、帧裁切、来源与提示词见 [MVP-02 美术接入记录](assets/mvp02/制作与接入记录.md)。

`make` 生成 ZIP；Windows x64 可在 Mac 执行 `npm run make -- --platform=win32 --arch=x64`。用户选择先交付 Windows ZIP，再在 Windows 实机验收。构建成功不代表平台验收通过；实际产物、测试证据与未验项目见 [MVP-02 实现与验收记录](docs/mvp/MVP02_实现与验收记录.md)。

## 目录

- `src/desktop/`：桌面主进程与 preload。
- `src/renderer/`：窗口页面与游戏启动。
- `src/game/`：Phaser 场景与可独立推进的房间规则。
- `assets/mvp/`：MVP-01 图集、原始素材及复用的上身／弓箭。
- `assets/mvp02/`：汤谷、影偶、人物扩展图集、实际裁切和完整生成提示词。
- `scripts/`：图集描述与开发验收采样工具；采样不覆写焦点、不丢弃慢帧。
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

当前安装包未配置发行签名。剧情、存档、Boss、神降和签署闭环仍属于后续范围。MVP-02 的功能、美术、性能与双平台实机结果完整前，Spec #2 保持未完成；旧 MVP-01 #1 的验收缺口也保持独立。
