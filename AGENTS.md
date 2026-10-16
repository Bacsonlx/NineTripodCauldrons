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

提交前运行 `npm run check`；修改构建或进程入口时同时运行 `npm run package`，并说明实际验证的平台。
