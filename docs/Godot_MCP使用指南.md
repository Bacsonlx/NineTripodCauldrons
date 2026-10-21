# 九鼎：Godot MCP 使用指南

2026-10-20。项目接入 [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)，Codex 服务名为 `jiuding_godot`。它是开发机上的 stdio 服务，无需在 `godot/` 安装插件，不进入游戏包，也不增加游戏运行时依赖。

## 1. 本机开始使用

依赖与项目配置已完成，MCP 后台联通和临时场景编辑已验证。**重载 Codex 的 MCP 服务，或在本项目开启新会话**，再查看 `/mcp` 中的 `jiuding_godot`。现有会话的工具列表不因文件写入自动更新；不要将命令行可识别配置当作当前聊天已经加载工具。

可直接对 Agent 说：

> 使用 jiuding_godot 查询 Godot 版本和当前 godot/ 工程信息，核对 engine-lock.json；只做后台操作。

> 使用 jiuding_godot 在 scenes/mcp_probe.tscn 新建一个 Node2D 场景并添加 Sprite2D。先检查目标不存在，保留正式汤谷地图和已有编辑结果，完成后运行项目后台检查。

> 检查 scripts/input/player_controls.gd 的 UID。使用 get_uid 查询，不批量重存工程。

`projectPath` 必须是包含 `project.godot` 的绝对路径，本机为 `/Users/linxin/Developer/GAME/十日/godot`，不能传仓库根目录。场景、脚本和纹理参数使用相对该目录的路径，例如 `scenes/tanggu.tscn`、`scripts/input/player_controls.gd`。

## 2. 安装与迁移到其他开发机

要求：Git、Node.js 22+、Python 3.11+（配置读取使用标准库 `tomllib`），以及 [engine-lock.json](../godot/engine-lock.json) 锁定的 Godot，均可从终端 PATH 找到。在仓库根目录执行：

```sh
npm ci --prefix tools/godot_mcp
python3 tools/godot_mcp/configure.py
npm run verify --prefix tools/godot_mcp
codex mcp get jiuding_godot --json
```

首次安装需要联网；正常启动使用本地已构建文件，无需每次通过 `npx` 下载。首次 Git 依赖构建会使用上游构建工具，更新依赖后以锁文件和验证结果为准。

配置程序会校验引擎版本，并写入项目级 `.codex/config.toml` 中的绝对 Node、服务入口和 `GODOT_PATH`。该文件已加入 Git 忽略，不提交本机路径；`package.json`、`package-lock.json`、配置与验证脚本属于共享工程文件。不会改动用户级 `~/.codex/config.toml` 或根 npm／Electron 工程。

如项目已有同名配置，程序保留它；其他 MCP 配置也保留。移动仓库、升级 Node 所在目录或更换 Godot 后，编辑 `.codex/config.toml` 的 `jiuding_godot` 对应路径，再验证。新机器没有该配置时重新执行配置程序。

Codex 仅加载可信项目的项目级配置；本机已查询到该仓库为 trusted。如其他机器不显示服务，先检查项目信任，再检查配置和可执行路径。依据为 [Codex 官方 MCP 文档](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)。

## 3. 工具怎么分工

| 工具 | 用法与项目边界 |
| --- | --- |
| `get_godot_version` | 核对实际调用的引擎；完整版本须匹配项目锁定值 |
| `list_projects`、`get_project_info` | 查找工程、读取文件结构统计与元信息；不是运行时场景树检查器 |
| `create_scene`、`add_node` | 新建局部场景／增加节点；写入磁盘，先确认目标路径与节点结构 |
| `load_sprite` | 把已导入的纹理赋给 Sprite2D；素材制作和图集锚点仍按项目现有管线处理 |
| `save_scene` | 重新打包并保存磁盘场景，可传 `newPath` 另存；不是保存编辑器中尚未落盘的修改 |
| `get_uid` | 此上游实现读取文件旁的 `.uid`，适合 `.gd`／shader；不等于能读取 `.tscn` 文件头或纹理导入缓存中的所有 UID |
| `update_project_uids` | 批量重存资源，会产生工程级修改；仅在明确的 UID 修复任务中使用并核对 diff |
| `get_debug_output`、`stop_project` | 管理同一 MCP 服务通过 `run_project` 启动的进程；不能接管手动启动的 Godot 窗口或读取其历史日志 |
| `launch_editor`、`run_project` | 会启动原生窗口；当前项目配置中已禁用 |
| `export_mesh_library` | 3D GridMap 资源工具，当前原生 2D 工程通常用不到；不负责 Windows／Mac 游戏导出 |

这个版本没有截图、系统键鼠控制、连接现有编辑器的实时节点修改、任意 GDScript 执行或通用测试运行工具。不要使用另一个同名 Godot MCP 项目的工具说明来调用它。[上游实际工具与实现](https://github.com/Coding-Solo/godot-mcp/blob/1209744fad78f3998f98c7394fd0f6ef50da5281/src/index.ts)

## 4. 项目开发流程

1. 用版本和工程查询确认目标为 `godot/`。读取相关场景／脚本；需要修改的场景先在编辑器中保存用户改动。
2. 局部新建场景、添加节点和绑定纹理可以使用 MCP；GDScript 编辑继续用代码工具。正式地图 `godot/scenes/tanggu_map.tscn` 包含项目自定义布局脚本，保持用户的节点和属性调整，避免为使用 MCP 重建整张地图。
3. 场景工具通过后台 Godot 批处理读写磁盘；没有实时编辑器事务。每次修改后检查 diff，确认脚本、资源引用、owner 和节点没有丢失。
4. 修改代码或场景后，仍运行项目检查：

```sh
python3 tools/migration/check_godot.py
```

规则／输入检查可用 `godot --headless --path godot --script res://tests/run_tests.gd`；资源与呈现变更还需干净导入和对应原生包检查。游戏导出继续使用 `python3 tools/migration/export_godot.py`。MCP 返回 success 不替代这些验证，也不替代用户画面／手感确认与双平台实机证据。

当前遵循后台测试约束，配置的 `disabled_tools = ["launch_editor", "run_project"]` 对 Codex 隐藏前台工具。用户安排前台验收后，再移除对应禁用项并重载服务，然后按 `run_project → get_debug_output → stop_project` 使用。仅修改配置不会自行启动游戏；窗口键鼠与性能验收仍按迁移 Spec 独立实施。

## 5. 版本与兼容补丁

使用上游 [`1209744`](https://github.com/Coding-Solo/godot-mcp/commit/1209744fad78f3998f98c7394fd0f6ef50da5281) 源码及项目 npm 锁文件。没有直接使用浮动 `npx @coding-solo/godot-mcp`；查询到 npm `0.1.1` 的发布提交为 `f341234`，与本次审读的源码提交不同。

本机临时工程验证发现两个实际问题，[patch.mjs](../tools/godot_mcp/patch.mjs) 在安装后自动对已构建的 GDScript 应用小补丁：

- 去掉 `create_scene` 中将根节点 owner 设为自身的操作，否则引擎报错。
- 在四处场景打包后释放临时实例，否则加载精灵等操作在退出时出现资源泄漏报错。

补丁检查预期源码形态，重复运行不叠加；更新上游时若匹配失败，先审查补丁，不绕过错误。没有修改游戏脚本或上游其他逻辑，也没有对外提交 fork／PR。

## 6. 故障排查与验证记录

| 现象 | 处理 |
| --- | --- |
| 新会话看不到工具 | 用 `codex mcp get jiuding_godot --json` 确认配置，再检查项目信任、重载服务和 Node 绝对路径 |
| 找不到 `build/index.js` | 重新运行 `npm ci --prefix tools/godot_mcp`，检查安装后的构建与补丁日志 |
| Godot 版本不符 | 按 `engine-lock.json` 安装正确版本，更新 `GODOT_PATH` 后重新验证 |
| 纹理加载失败 | 先做项目导入，确认纹理路径相对 `godot/`，再检查 MCP 返回的具体错误 |
| 临时验证报 user data／日志目录权限错误 | Godot 的后台工具也会写用户数据目录；为此次本地命令提供所需文件权限后重试，不用前台启动替代 |
| 场景工具报告成功但状态不符 | 检查输出／错误、磁盘文件与 diff，再运行正式检查；不以成功文本覆盖实际错误 |

2026-10-20，本机 Apple Silicon Mac 的实际证据：

- 干净 `npm ci`、自动补丁及 Codex 项目配置识别通过。
- stdio 握手返回 14 项工具；Codex 配置禁用其中两项前台启动工具。
- `verify.mjs` 成功调用版本、项目列表、工程信息，以及临时工程中的创建场景、增加节点、加载精灵、另存、脚本 UID 查询；验证后删除临时工程，未改正式场景。
- 项目 `check_godot.py` 通过：30 项检查、55 个规则场景／4,250 次快照对比，以及后台导入和完整场景加载。
- 未测试前台启动、MCP 运行输出链路、批量 UID 重存或 3D 导出，未进行 Windows MCP 实测；不据本轮工具联通改变游戏验收状态。

验证命令可重复运行 `npm run verify --prefix tools/godot_mcp`。它读取本项目实际配置进行连接，使用用户数据目录但只在系统临时目录写场景；运行依赖已准备的 `godot/assets/generated/arrow.png`。
