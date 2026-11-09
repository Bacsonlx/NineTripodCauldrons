# 九鼎 · 十日 | 资产管理中心 (Asset Center)

《九鼎 · 十日》项目专属的本地可视化游戏资产管理与生命周期管理中心。打通 **414 条全量美术需求库**、**磁盘现役切片素材** 与 **Godot 六器构筑与战斗配置**。

## 🌟 核心特性

1. **暗黑青铜神话视觉 (Dark Mythic Bronze Aesthetic)**：
   - 定制《九鼎·十日》青铜金芒、朱砂赤红、墨玉琉璃质感。
   - 现代化响应式设计、毛玻璃与微动效。
2. **全维度数据打通**：
   - **美术需求总表 (414条)**：人物、Boss、敌人、武器装备、道具收集、建筑、植被、地形、贴花、特效、界面UI、肖像、叙事等 13 类资产。
   - **磁盘实物与切片关联**：自动索引 `assets/` 与 `output/art/` 中的素材原图、序列帧与动画切片。
   - **六器玩法构筑 (Gameplay & Rules)**：直接解析 `godot/scripts/alpha/alpha_state.gd` 中的 `CONTENT`（17 项：4器、4契、4符、训练弓／布履、青龙／白虎／朱雀三神兽；旧 5 本技能书已按[技能来源规则](../../docs/product/技能来源规则_装备与羁绊.md)退役）、`CHARACTERS` 与 `EFFECT_CARDS` 六器容器机制。
3. **交互式素材与动效工坊 (Media Workshop)**：
   - 支持图片、切片图集、WebP 动图预览。
   - 内置交互式序列帧/动画播放器（播放/暂停、单帧步进、FPS调节、棋盘格透明切换、无级缩放）。
4. **双向编辑与原子同步**：
   - 在界面中一键修改制作状态（仅登记未制作、候选制作中、候选预览、已入库交付）、备注、依据状态。
   - 支持新增资产登记并自动分配编号。
   - 点击“一键同步”自动原子写回 `docs/art/美术资产库_v0.1/资产总表.csv` (UTF-8 with BOM 保持 Excel 兼容)、`资产总表.json`，并同步刷新 `资产分类目录.md`。
   - 提供 JSON 快照与 CSV 主表直接导出。

---

## 🚀 启动与使用

AI 制作与接入资产时，按[验证证据与资产追溯指南](../../docs/guides/验证证据与资产追溯.md#资产追溯)在素材 README 保存参考、候选、选择理由和运行引用，现有备注可指向该记录。资产中心的制作状态与原生视觉验收分别记录；追溯示例见[皮影药囊](../../assets/props/potion-pouches-v1/README.md#参考候选与交付)。关系明细保存在文件记录中，本轮未增加画布编辑界面。

在项目根目录下执行：

```bash
python3 tools/asset_center/run.py
```

服务将自动选择空闲端口（默认 `8899`）并自动在默认浏览器中打开：

```
http://localhost:8899
```

### 常用启动参数

- 自定义端口：
  ```bash
  python3 tools/asset_center/run.py --port 9000
  ```
- 后台或无头模式（不自动弹出浏览器）：
  ```bash
  python3 tools/asset_center/run.py --no-browser
  ```

---

## InstaBox 一键部署

在项目根目录双击 `deploy-assets.command`，或执行：

```bash
python3 tools/asset_center/deploy.py
```

目标为已创建的免费机器 `jiuding-asset-center`
（`m_agqxzavig73nnfofr6sxgvcvka`），公开端口为 `8899`。
部署程序调用官方 InstaBox CLI；本机已准备在 `.scratch/instabox/instabox`，
也可以使用 PATH 中的 `instabox` 或通过 `INSTABOX_BIN` 指定。

首次使用需要在项目根目录的 `.env.instabox` 中设置部署凭据：

```json
{
  "api_key": "在 InstaBox 控制台创建的部署密钥",
  "username": "admin",
  "password": "独立的网页访问密码"
}
```

该文件已由现有 `.gitignore` 中的 `.env.*` 规则排除，并应保持 `600` 权限。
API 密钥只需要 `machines:write`（包含读取），不需要删除机器或快照权限。
密钥也可以从环境变量 `INSTABOX_API_KEY` 传入；不要提交密钥、密码或带凭据的访问链接。

部署行为：

- 自动启动已停止的机器、恢复已暂停的机器；使用原机器，避免重复创建。
- 按文件内容校验，只上传变化的服务代码、前端、玩法配置与图片素材。
  不上传 `.git`、Node.js 依赖、原生游戏包及本机凭据。
- CSV、JSON 和分类 Markdown 只在服务器缺少主数据时初始化；
  后续部署保留云端编辑，**不会用本机旧表覆盖云端记录**。
- 更新前停止服务并备份服务器 `docs/art/`，随后安装 systemd 服务，
  启用开机启动、故障重启及网页用户名/密码认证。
- 验证本机服务和公网 HTTPS 数据接口，并确认未登录访问返回 `401`。

持久文件位于服务器 `/data/home/jiuding-asset-center/`：

- `workspace/`：服务、素材和云端资产表。
- `backups/`：每次更新前的资产记录备份。
- `service.env`：网页认证配置，只允许所有者读取。

本机 `.scratch/instabox/deployment.json` 保存最近部署的网址和变化文件数。
首次约上传 1.75 GB 的图片和代码，后续为增量上传。
本机和云端的表格不会自动双向合并；云端编辑可用页面中的 JSON／CSV 导出功能取回，
服务器备份也可使用 `instabox pull` 下载。服务更新期间有短暂停机；
部署失败会明确退出，不会自动回滚代码。

免费计划的暂停和时长限制以 InstaBox 控制台为准：
当前空闲 30 分钟或连续运行 8 小时后暂停。
官方文档说明，空闲自动暂停后访问公开网址会唤醒机器；
手动暂停／停止需要恢复，执行一键部署也会恢复。
这不等同于全天在线的生产托管。

部署相关验证：

```bash
python3 -m unittest discover -s tools/asset_center -p 'test_deployment.py' -v
```

## 本地文件结构

```
tools/asset_center/
├── run.py                 # 启动器 CLI
├── server.py              # 本地 HTTP API 服务与媒体流支持
├── sync.py                # 数据解析、媒体扫描与 CSV/JSON/Markdown 同步引擎
├── README.md              # 使用说明文档
└── web/                   # 独立 Web 前端
    ├── index.html         # 单页应用骨架
    ├── styles.css         # 青铜神话设计系统样式
    └── app.js             # 响应式前端交互与播放器逻辑
```
