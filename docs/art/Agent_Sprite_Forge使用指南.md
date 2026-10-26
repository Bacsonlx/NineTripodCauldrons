# Agent Sprite Forge：九鼎素材制作与加工

本项目按需采用 [agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge/blob/5324342fdfab72430f4e9604f3fe427009f8596d/README.zh-CN.md) v0.4.0，用于人物、道具、图标、短特效，以及已有图片的切帧、对齐和打包。它是开发期素材工具，不进入 Godot 游戏运行依赖。适用性与社区反馈见 [评估记录](../research/research_agent-sprite-forge_20261020.md)。

## 按任务选择

| 任务 | 使用方式 | 本项目要求 |
| --- | --- | --- |
| 人物静态母图／拆件 | `generate2dsprite` 规划规格，内置 `imagegen` 生成／编辑 | 先对照已接受角色与当前层级；角色身份、镜头、脚点、腰带点与握点一致 |
| 新人物连续动作 | 确认母图后，按需转 `video2dsprite` | 每个动作分别制作；视频生成服务与费用路线须来自用户指定或明确授权，当前未配置、未验证 |
| 道具／图标 | `generate2dsprite`，静图或同族状态图集 | 按实际显示尺寸检查轮廓；图标文字由 UI 绘制；透明边与统一比例按用途确定 |
| 短特效 | `generate2dsprite` 的 FX 图集与 clips | 分清前摇、触发、消退及循环；命中时点取自玩法规则，不能由新帧数反推伤害时间 |
| 已有整图／序列帧 | `assemble_frames.py` → `build_animation_clips.py` → `export_engine.py` | 使用现有裁切、顺序、锚点与时长；只做所需步骤，记录 `art_source=existing` |
| 已有图片需要统一画布／锚点 | `generate2dsprite.py process`，再构建 clips／导出 | 有明确共享原点时用 `registered`；先验证动作位移没有被对齐抹掉 |

已安装 `generate2dsprite`、其依赖 `generate2dmedia`、人物动画分支 `video2dsprite`；没有安装地图和代码绘图分支。`generate2dmedia` 是按需显式读取的路由依赖，不单独作为日常制作入口。地图、地形、背景不纳入此接入。

## 生图与角色合同

每次制作、修订或接入资产，按[资产追溯指南](../guides/验证证据与资产追溯.md#资产追溯)维护现有候选／正式素材 README 的关系记录；完整提示词、哈希与 QA 明细继续复用本指南规定的原文件。示例见[皮影药囊](../../assets/props/potion-pouches-v1/README.md#参考候选与交付)。

1. 从 [资产需求库](美术资产库_v0.1/README.md) 选定本次资产及已确认用途，填清参考、镜头／朝向、拆层、显示尺寸、画布、原点、动作／状态、时长、循环与输出格式。414 条登记不等于制作授权；只有本次选定范围进入制作。
2. 在 Codex 内新建／编辑图片使用内置 `imagegen`，读取其 Skill 并设置所需透明背景。此处遵循宿主图像工具要求，覆盖上游的 API-first 默认：不因检测到密钥自动调用 API，也不自动切换 CLI 或视频服务。`generate2dsprite` 负责素材合同与后处理；已有图片直接加工。
3. 对照接受版本检查身份、比例、皮影主导的像素质感、轮廓与透明边。上游默认 HD 不是本项目画风决策；只有确定为真实像素网格时才使用 nearest／整数缩放／像素调色板。
4. 玩家沿用腿、上身、弓分层，移动与瞄准独立。现有四向与帧序以 [制作与接入记录](../../assets/mvp02/制作与接入记录.md) 和图集元数据为准；新角色按 [动作需求](美术资产库_v0.1/动作与状态需求.md) 裁剪，不套用上游默认动作数、方向数、帧数或母图尺寸。角色连续动作采用母图→动作视频分支时，仍需验证拆层与各层连接；无法保持时先作为候选，不替换当前素材。

所有候选写入新的 `output/art/<资产ID>/<版本>/` 目录，保留输入、完整提示词、实际工具／模型路线、源文件校验、规格、PNG／帧、图集、元数据、预览与 QA。来源和第三方许可有据可查；输出目录不覆盖接受版本。视觉确认后再选取必要交付物纳入 `assets/`。

## 已有图片：切帧、对齐、打包

先读对应 `frames.json`／`atlases.json`。本项目存在非均匀矩形、逐帧 origin 和 scale，不能按图片外观猜等距网格。已有透明 PNG 默认保留 alpha；直接组装默认 `--key none`，需要 `process` 时显式设 `--background-mode native_alpha --alpha-hygiene none`，避免默认降噪改变边缘。确实要清理边缘时另存版本并比较结果。

- **只切帧与组合**：`assemble_frames.py` 不缩放、不对齐。规则网格用 rows／cols；不规则图集用 `--crop-boxes`，格式为 `{"items":[{"id":"帧名","box":[左,上,右,下]}]}`，右／下边界不包含。多张输入帧必须具有相同画布尺寸。
- **需要对齐**：`process --scale-strategy registered --anchor-px X,Y` 给整组帧一个共同变换，保留跳跃、起伏和后坐。`preserve` 会逐帧移动到目标锚点，适合确实需要重新归位的素材；`fit` 以包围盒适配画布，必须核对它是否改变姿态间比例。默认保留全部可见组件，避免删掉武器、飘带或特效碎片。锚点是语义连接点，不是每帧可见像素的最低点。
- **不同裁切尺寸**：先按现有 origin 放入同尺寸透明画布，记录平移及更新后的像素锚点，保留每帧 scale；不能统一居中后丢掉脚点／腰带关系。对已接受资产可直接保留原 atlas 合同，无需重排。
- **跨框提示**：先检查是否真实切断。新生成图跨框应修图或增加留白；项目旧下身图有意裁掉重复腰带，按既有合同切帧会触发 spill 拒绝。仅在明确复用这种已确认矩形时，记录依据并对该次命令显式加 `--allow-spill`；保留 QA warning。`--slice ownership` 会改变取图范围，不适合静默替代既有矩形。
- **时间与打包**：`build_animation_clips.py` 只编排已准备好的帧、时长、循环和事件，不负责修图或对齐。清单记录共享 `anchor_px`、实际帧序、`duration_ms`、`loop`、`sampling` 和 `art_source`。它不承载九鼎全部逐帧缩放／握点合同，这些仍需保留在项目侧元数据。

本项目导出选择 `godot-spriteframes`。上游 `.tres`／`.tscn` 是可供验证的新资源，不会自动接入当前分层脚本；完整检查脚点／握点、缩放、播放时序和状态映射后再决定是否使用。当前运行资产仍由 `tools/migration/prepare_sample_assets.py` 按既有元数据转换；不要直接覆盖 `godot/assets/generated/`。

### 命令入口

在仓库根目录使用项目专用 Python：

```sh
ASF_PY="$PWD/tools/asset_forge/.venv/bin/python"
ASF_SPRITE="${CODEX_HOME:-$HOME/.codex}/skills/generate2dsprite"
"$ASF_PY" tools/asset_forge/verify.py
"$ASF_PY" "$ASF_SPRITE/scripts/assemble_frames.py" --help
"$ASF_PY" "$ASF_SPRITE/scripts/generate2dsprite.py" process --help
```

例如 `output/art/<ID>/<版本>/clips.json` 已列出同尺寸、有正确共享锚点的现有帧后，执行以下步骤；将 `ART_RUN` 换成本次新目录路径。两个输出目录须尚不存在：

```sh
ART_RUN="output/art/<ID>/<版本>"
"$ASF_PY" "$ASF_SPRITE/scripts/build_animation_clips.py" --manifest "$ART_RUN/clips.json" --output-dir "$ART_RUN/clips"
"$ASF_PY" "$ASF_SPRITE/scripts/export_engine.py" --clips "$ART_RUN/clips/animation-clips.json" --target godot-spriteframes --name asset --output-dir "$ART_RUN/engine"
```

`clips.json` 最小结构如下，帧路径相对该文件；尺寸、锚点和时长只是示例，须按当前素材填写：

```json
{
  "schema": "generate2dsprite.animation_clips.v2",
  "frames": ["frames/frame-00.png"],
  "anchor_px": [102, 154],
  "clips": {"idle": {"frames": [0], "duration_ms": 100, "loop": true}},
  "states": {"idle": "idle"},
  "sampling": "linear",
  "pixel_art": false,
  "art_source": "existing"
}
```

## 接入与验收

先看浅色、深色、棋盘格预览，再按实际游戏尺寸检查边缘、方向、动作、共享锚点与循环接缝。QA warning 必须逐项解释，不能只凭 exit 0 标为画面通过。导出不会设置完整 Godot PNG 导入参数；结合像素／绘画素材选择过滤、无损压缩和 mipmap，并检查图集边缘渗色。

确认接入后运行素材转换及 `python3 tools/migration/check_godot.py`，资源呈现改动按 [Godot README](../../godot/README.md) 检查干净导入与原生包。编辑场景可使用 [Godot MCP](../guides/Godot_MCP使用指南.md)，保留用户正式地图。当前仅后台验证；真实动态画面、手感和双平台体验由对应验收任务记录。

2026-10-20 已在 macOS 后台验证：三 Skill 与锁定源码一致；已有腿部单帧按原矩形切出后 RGBA 一致；两帧共用平移后保留 8 px 上下运动、alpha 和可见 RGB；单帧 Godot 导出可干净导入、实例化，原点、纹理区域、循环及 100 ms 时长正确。跨框裁切保留一个 warning；单帧测试不证明完整动画质量，未验证图生视频、付费 API、Windows 或前台画面。证据见 [verification.json](../../tools/asset_forge/verification.json)。`verify.py` 仅复核安装完整性、依赖和命令可启动性，不重新执行这些后台素材／Godot 实验。

### 首个现有角色动作候选

玩家四向待机、移动、普通射箭、跑射、反向跑射、Q／E 与闪避姿态已按现有元数据整理为独立候选，见 [候选说明与交互预览](../../output/art/CHR-001/2026-10-20-existing-actions-v1/README.md)。该包保留逐帧 scale 和精确锚点，含 64 帧素材、32 组动作采样及 Godot 资源；未补画新姿态、未替换正式素材。独立工程导入与播放变换验证不代替用户动态画面验收。

用户指出 down 握弓错位及下肢循环不连贯后，新增 [射箭与四向跑步修订 v2](../../output/art/CHR-001/2026-10-20-down-redesign-v2/README.md)：down 四关键姿态联绘手／弓／弦，四向下肢八姿态循环；包含前后对照，尚未替换正式资源。该设计候选仍需验证独立瞄准、技能覆盖和真实动态效果，不能将候选展示直接视作正式接入完成。

2026-10-21 用户确认问题截图来自上一版动画对照，继续新增 [向下射箭修订 v3](../../output/art/CHR-001/2026-10-21-down-review-v3/README.md)：重画横置前弓、拉弦手与箭尾连接，入口仅显示新版；复用 v2 下肢。四阶段可单独暂停查看，Godot 资源与 Mac 候选仅后台验证，正式绑定及视觉验收仍未完成。

同日用户要求替换正式素材后，v3 向下普通射箭上身已接入正式场景，详见 [正式素材合同](../../assets/characters/child/README.md)。该方向使用已确认的联绘组并隐藏旧武器层，按箭尖校准出箭点；移动与鼠标瞄准保持独立，上身仍为四向量化姿态。其他方向、跑步下肢和技能保留原资源。候选目录是接入前的历史记录，当前运行状态以正式素材合同和 [后台证据](../../output/art/CHR-001/2026-10-21-production-down-v3/README.md) 为准。

## 安装与版本维护

Skill 位于用户级 `${CODEX_HOME:-~/.codex}/skills/`，项目只保存 [版本及校验锁](../../tools/asset_forge/skills.lock.json)、Python 依赖和指南；不复制上游工具到游戏工程。当前依赖要求 Python 3.12+，本机验证使用 Python 3.13。换机器时由 Codex 使用 `skill-installer` 的官方 helper：

```sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py" --repo 0x0funky/agent-sprite-forge --ref 5324342fdfab72430f4e9604f3fe427009f8596d --path skills/generate2dsprite skills/generate2dmedia skills/video2dsprite --method git
python3 -m venv tools/asset_forge/.venv
tools/asset_forge/.venv/bin/python -m pip install -r tools/asset_forge/requirements.txt
tools/asset_forge/.venv/bin/python tools/asset_forge/verify.py
```

安装已有同名目录时 helper 会停止。用户级 Skill 由多个项目共用，版本冲突先报告差异，不静默覆盖。升级需复查上游差异，更新锁文件并重跑素材与 Godot 临时工程验证，不能只更新版本号。本次未改上游 Skill 内容；解释冲突时以本指南及宿主工具指令为准。

## 可直接给 Agent 的任务示例

- “使用 `$generate2dsprite`，为已选定道具制作三个状态图标。沿用接受参考，先给出实际显示尺寸与统一画布方案，再生成透明候选。”
- “使用 `$generate2dsprite`，为孩子制作分层母图候选，保留腿、上身、弓和独立瞄准连接；先做静态对照，不启动视频路线。”
- “使用 `$generate2dsprite` 制作箭命中的短特效，时序沿用当前规则，交付透明帧、预览与 Godot 候选资源。”
- “使用 `$generate2dsprite`，按指定 atlases.json 加工已有 PNG，只切帧、保留原锚点并打包；不重新生成图片、不覆盖接受版本。”
