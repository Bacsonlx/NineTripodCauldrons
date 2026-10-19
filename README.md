# 九鼎

主 IP：九鼎。副 IP：十日。

Windows／macOS 单机动作肉鸽游戏的技术验证工程，采用固定等距二维战斗与分层 2.5D 表现，目标画风为皮影主导的像素质感混合风格。

各版本内容与验证状态见 [更新日志](CHANGELOG.md)。

## Godot 迁移

后续开发已确定采用 **Godot 原生 2D＋带类型的 GDScript**，面向 PC／Steam，保持现有二维战斗平面、固定俯视／等距表现与离线图集。决策见 [ADR-0010](docs/adr/0010-godot-migration-direction.md)，完整范围与验收标准见 [Godot 迁移落地方案](docs/九鼎_Godot架构评估与迁移落地方案_2026-10-19.md)。

**Godot 动态小样已在 `godot/` 建立，旧版主入口仍为 Electron＋TypeScript＋Phaser。** 引擎固定为 Godot 4.7.2 official，Compatibility 为候选渲染器，匹配官方模板与校验见 [Godot 开发说明](godot/README.md)。小样已接入跑射、单影偶近战、遮挡、相机和操作中断；Mac 原生启动与部分操作已检查，Windows 实机及用户试玩确认仍待验。

- 首个交付覆盖当前汤谷的战斗、探索、镜头、反馈、键鼠操作，以及 Windows x64／Apple Silicon Mac 原生运行。
- 先交付移动、独立瞄准、普通射箭、一个影偶、遮挡物和跟随镜头的可玩动态小样；试玩确认画面与手感后，再铺完整汤谷。
- 保持已确认的玩法规则与数值，允许经确认的表现改进。用户在 Godot 编辑器调整道路、障碍、出生点和互动点并验收，AI 负责脚本与批量配置。
- 指定两平台实机在 1080p 下连续跑射 60 秒：平均 ≥58 FPS，至少 95% 帧间隔 ≤20ms；另做 5 分钟稳定性检查。双平台验收通过后切换主入口，商业版最低配置后续验证。
- 手柄、随机房间、Boss、成长、正式存档和 Steam 完整功能进入后续商业闭环；迁移早期先核实 Steam 接入路径与兼容性。

M0—M4 的实施规格已发布为 [GitHub Spec #33](https://github.com/Bacsonlx/NineTripodCauldrons/issues/33)，本地镜像见 [Godot 迁移 Spec](docs/mvp/九鼎_Godot迁移_Spec.md)。18 个 Task 已发布为 #34—#51；当前实现、试玩包、检查与待验项见 [Godot 实施记录](docs/migration/Godot迁移_实施记录.md)。用户确认动态小样后继续技能、完整地图与探索，最后按双平台验收切入口。

## 当前工程开发

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

当前入口为 **MVP-03 汤谷探索 0.3.0**：固定等距跟随镜头，三组 3／4／5 战斗，一条主路、两条支路及内侧开启的捷径；分层环境沿已批准小样铺满全图。WASD 跑动、鼠标瞄准、左键射箭，Q 穿透箭、E 箭雨、空格闪避、F 互动，Esc 暂停／关闭阅读，R 重试。残碑采用已单独批准的 v0.1；祭坛一次恢复40，满血不消耗；R 同时复原探索与战斗。46项测试与渲染功能流程通过，Mac／Windows 原生完整体验仍待验。见 [完整探索实现与验收记录](docs/mvp/MVP03_完整探索_实现与验收记录.md)。

人物、影偶与环境使用本地透明 PNG，人物四向各 6 帧跑步，独立上身与技能／受击／失败动作；弓和箭保持握点与箭尖一致。HUD、冷却与朱红预警由代码绘制，技能使用纹理与代码动画组合。复用来源见 [MVP-02 美术接入记录](assets/mvp02/制作与接入记录.md)，新增局部地面、分离物件和特效纹理见 [MVP-03 美术接入记录](assets/mvp03/制作与接入记录.md)。

`make` 生成 ZIP；Windows x64 可在 Mac 执行 `npm run make -- --platform=win32 --arch=x64`，EXE 使用 `npm run make:win-exe`。构建成功不代表平台验收通过，Windows 实机仍由用户回传。历史 0.2.1／0.2.0 验收分别保留在 [人物与小怪修订记录](docs/mvp/MVP02_0.2.1_人物与小怪修订.md)和[旧实现记录](docs/mvp/MVP02_实现与验收记录.md)，不被本轮小样追溯改写。

## 目录

- `src/desktop/`：桌面主进程与 preload。
- `src/renderer/`：窗口页面与游戏启动。
- `src/game/`：Phaser 场景与可独立推进的房间规则。
- `assets/mvp/`：MVP-01 图集、原始素材及复用的上身／弓箭。
- `assets/mvp02/`：汤谷、影偶、人物扩展图集、实际裁切和完整生成提示词。
- `assets/mvp03/`：局部动态小样的地面、分离物件与特效纹理、帧裁切和生成提示词。
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

### 0.2.1 人物与小怪修订

统一人物腰带／衣摆与脚点，新增纸面、木甲两种影偶外观；三组共 12 只，仍用原近战规则。修复默认最大化启动时的画布与可见性同步。

运行 `npm run make:win-exe`，Forge 先构建 Windows x64 ZIP，再由固定版本 electron-builder 将相同产物包装为 NSIS EXE；当前为未签名的当前用户安装包，不包含自动更新。Windows 实际安装／运行仍待回传，详见 [0.2.1 修订记录](docs/mvp/MVP02_0.2.1_人物与小怪修订.md)。
