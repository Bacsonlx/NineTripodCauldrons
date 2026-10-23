# 九鼎 · 十日 | 资产管理中心 (Asset Center)

《九鼎 · 十日》项目专属的本地可视化游戏资产管理与生命周期管理中心。打通 **414 条全量美术需求库**、**磁盘现役切片素材** 与 **Godot 六器构筑与战斗配置**。

## 🌟 核心特性

1. **暗黑青铜神话视觉 (Dark Mythic Bronze Aesthetic)**：
   - 定制《九鼎·十日》青铜金芒、朱砂赤红、墨玉琉璃质感。
   - 现代化响应式设计、毛玻璃与微动效。
2. **全维度数据打通**：
   - **美术需求总表 (414条)**：人物、Boss、敌人、武器装备、道具收集、建筑、植被、地形、贴花、特效、界面UI、肖像、叙事等 13 类资产。
   - **磁盘实物与切片关联**：自动索引 `assets/` 与 `output/art/` 中的素材原图、序列帧与动画切片。
   - **六器玩法构筑 (Gameplay & Rules)**：直接解析 `godot/scripts/alpha/alpha_state.gd` 中的器、契、符、装备、神兽、技能书（穿透箭/箭雨/回风/蓄势/引风）及六器容器机制。
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

## 📁 目录架构

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
