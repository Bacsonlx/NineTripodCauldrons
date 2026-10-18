# 九鼎 MVP-03 汤谷探索 0.3.0 证据

- `九鼎_MVP03_汤谷探索演示.mp4`：1280×720，约41秒完整成功走访。三组战斗、两支路、批准碑文、正常受伤后的80→100恢复、开门、清敌回读及R均由真实CDP键鼠输入完成。VFR按409帧原时间戳编码，不加速、不删慢帧；不是FPS采样。
- `main-only-summary.json`／`16-main-route-only.jpg`：独立主路约18秒通关，三个探索标记均为false、生命100；初次自动路线未绕第一庭院火盆的失败另存 main-only-driver-attempt.json。
- `summary.json`／`walkthrough.json.gz`／`frames.json`：主流程结果、只读快照及时间戳。原始JPEG在忽略目录 `out/validation/mvp03-full-recording/`。
- 夹具从实际Mac ASAR提取，游戏JS／素材与两端最终包相同；只在临时HTML加一个外部脚本，替代Electron低频窗口API。没有游戏状态、生命、敌人、时钟、焦点或可见性覆盖。诊断观察器不随游戏交付。
- `F-tap-regression-red.*`：快速F点按丢失的真实失败记录；修复后完整走访通过。
- `driver-obstacle-attempt.json`、`driver-brazier-attempt.json`、`driver-brazier-failure.jpg`：自动操作路线未绕开石柱／火盆的失败记录，保留而不算通过；调整的是操作路线，未放宽实体或AI。出生点重叠另经公开输入RED→GREEN修复。
- `window-checks.json`：800×450和1920×720的面板／提示通过。headless标签激活没有产生真实window blur，焦点动态结果不成立；初次断言失败保留在 `window-checks-attempt.json`，不能改写成游戏失焦通过。失焦规则另有模型测试，原生链路仍待验。
- `native-attempt.json`／`01-native-start.jpg`：早期0.3构建的原生Mac启动、截图与全屏进出。页面hidden，未验证最终包完整原生玩法，不以截图冒充实际键鼠通过。
- `test-results.txt`：46／46；`build-mac.txt`／`build-win.txt`：本轮构建日志，副本仅规范化终端控制码和行末空白。
- `release-manifest.json`：最终EXE／ZIP／ASAR／渲染脚本／素材／源码／视频SHA-256，视频使用的renderer与两端包一致。ZIP均通过完整性检查，ZIP内ASAR匹配已验目录。

Windows安装及两端原生完整玩法保持待验。没有重复60秒／5分钟稳定性循环，没有追溯补写MVP-01／02结果。正式逐项覆盖及限制见 `docs/mvp/MVP03_完整探索_验收覆盖.md`。
