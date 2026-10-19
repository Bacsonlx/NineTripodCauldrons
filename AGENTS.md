# 九鼎

主 IP 为「九鼎」，副 IP 为「十日」。所有回复使用中文。

## Agent skills

### Issue tracker

运行工程技能前读取 `~/.agents/mattpocock-config/issue-tracker.md`，由当前 `git remote` 识别目标仓库。技能使用用户级安装及全局配置。

### Triage labels

使用 `~/.agents/mattpocock-config/triage-labels.md` 的标签映射。

### Domain docs

单上下文：改动领域规则前读取根目录 `GLOSSARY.md` 和相关 `docs/adr/`；消费方式见 `~/.agents/mattpocock-config/domain.md`。

## Project context

架构、范围或玩法改动前读取 `docs/九鼎_架构选型结论.md`，具体已确认规则见 `docs/十日_玩法与运行规则.md`。历史故事材料中的未决建议不自动成为实现要求。

### Godot migration

迁移、工具链或迁移验收改动前，读取 [ADR-0010](docs/adr/0010-godot-migration-direction.md) 和 [Godot 迁移方案](docs/九鼎_Godot架构评估与迁移落地方案_2026-10-19.md)；以 Q1—Q9 的已确认决策为范围依据，后续商业版预案按各自规格实施。

汤谷迁移实施、拆票和验收以 [Godot 迁移 Spec](docs/mvp/九鼎_Godot迁移_Spec.md)（[GitHub #33](https://github.com/Bacsonlx/NineTripodCauldrons/issues/33)）为合同；已确认测试边界为规则输入／时间／可观察状态、操作中断输入适配和双平台原生体验。

- Godot 增量工程位于 `godot/`，采用原生 2D＋带类型 GDScript，版本与模板校验见 `godot/engine-lock.json`，开发／测试／导出命令见 `godot/README.md`；旧版主入口仍为 Electron／Phaser。
- 首个交付为 M0—M4 的完整汤谷迁移，保持已确认的规则、数值和操作中断行为；先经用户试玩确认动态小样的画面与手感，再扩展完整汤谷。
- 内容布局由 Godot 编辑器承载，用户调整与验收，AI 负责脚本和批量配置；主入口在双平台原生验收通过后切换，过渡期保留旧工程作对照。
- 手柄、正式肉鸽闭环、存档和 Steam 完整功能属于后续范围；构建、规则测试或单平台通过分别记录，不能替代双平台实机完成证据。

### Verification

当前 Electron／TypeScript 工程提交前运行 `npm run check`；修改其构建或进程入口时同时运行 `npm run package`，并说明实际验证的平台。修改 Godot 规则／输入后运行 `godot --headless --path godot --script res://tests/run_tests.gd`；资源与呈现改动同时检查干净导入、完整场景启动及对应原生包。完整 Task 状态与待验项更新 `docs/migration/Godot迁移_实施记录.md`；npm 检查仅覆盖现有 TypeScript 工程。迁移性能设备、指标与采样边界以迁移方案为准。
