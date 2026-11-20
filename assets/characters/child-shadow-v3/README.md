# CHR-001 皮影童子 v3：完整状态原画

2026-11-17，按用户要求细化人物与多状态素材。GPT-6.1 Sol 负责提示、图像编排与源图评审；实际绘制调用内置 `image_gen.imagegen`，后端具体型号及费用未返回。不使用 Runway、视频生成或旧部件 IK 来冒充新画关键帧。

用户已经确认的身份来自 [四向母版](../child-shadow-v1/approved-turnaround.png)与[持弓设计](../child-shadow-v1/approved-combat-design.png)：黑发高束、红巾、传统衣裤、绑腿与小布履。用户对旧版前倾、持弓和跑射的反馈是本轮改动依据；本轮授权实施不等于新动作已经获用户最终视觉认可。

| 关系 | 源文件与处理 | 选择依据及边界 |
| --- | --- | --- |
| 已确认身份 → 新母图 | [neutral-four-views.png](sources/neutral-four-views.png)，1254² RGBA；2×2顺序 right/down/left/up | 实际附空手已确认母版，细化纹样与皮影线条；AI认为可作本轮身份候选，用户尚未逐姿态验收 |
| 母图 → 完整联绘状态 | [right](sources/right-actions-v1.png)、[down](sources/down-actions-v1.png)、[left](sources/left-actions-v1.png)、[up](sources/up-actions-v1.png) | 每张4×4：前8格跑步，后8格 ready/nock/half_draw/full_draw/release/follow_through/lower_bow/recover；实图不保证等比例和完整步态，须注册与复核 |
| 候选 → 未采用修订 | [right-v2](sources/right-actions-v2.png) | 针对半周期与留白的图像编辑未有效解决问题；保留失败记录，射箭优先v1，v1/v2顶部跑步不采用 |
| 母图 → 独立跑步／特殊姿态 | [右跑8帧](sources/extra-run-right/README.md)、[四向特殊状态](sources/extra-special-states/README.md) | 第二名Sol独立绘制，具体格位、校验、警告以各自README与metadata为准 |
| 源图 → 人工注册 | [core-registration-sol.json](sources/core-registration-sol.json) | 每帧box、腰点、地平线及弓手／弦手／弓端点；约±8px，手弓约±12px，人工估计不能当精确解剖或画面验收 |
| 新源 → 集成与验证 | [本轮集成记录](../../../output/art/CHR-001/2026-11-17-multistate-v3/README.md) | 实际运行引用、切帧注册、Godot检查由集成记录维护；磁盘存在不代表已运行使用 |

完整实际生成路径、附图、工具、哈希与选择理由见 [provenance.json](provenance.json)；逐字提示和浅／深／棋盘背景复核见 [候选原画记录](../../../output/art/CHR-001/2026-11-17-multistate-v3/art/README.md)。所有输出保留真实alpha；底色预览只是合成展示，不回写源图。

仍有明确限制：right-v1/v2首行头发顶到边界，跑步弃用；其他动作表的左右腿支撑交替和循环连续性未动态验收；down正面弓箭透视近似；up后向箭与箭尾不可读，尝试定向修图被服务拒绝，未产生v2。up注册的 `arrowVisible=false`、`arrowTip=null`，如需出箭只能按弓中心投射语义点，不可称实绘箭尖。低持弓与满弦下弓臂低于腰线，简单横切上身会截弓，必须保留武器像素域。

本轮源图视觉为AI部分通过；构建、逻辑、运行、交互与性能仅看集成记录，源图生成不证明这些类别通过。原生窗口、真实输入、跑射连续自然度和Windows实机仍需相应验收。

## 运行接入（2026-11-17）

已切换[统一主角](../../../godot/scripts/presentation/player_frame_actor.gd)至[运行资源](../../../godot/assets/characters/child-shadow-v3/clips.json)，安全屋、训练场、首关、Boss共用。选入84个完整绘制姿态：四向中立4、跑动32、普通射箭32、特殊状态16；注册后打包15组／204个层采样，复用帧不计为新画。

[注册合同](sources/registration.json)与[打包脚本](../../../tools/art/action_redraw/pack_authored_player_v3.py)保留每组固定缩放、脚点与腰点，不以每帧外框重缩放；[手弓蒙版](sources/extra-upper-masks.json)保留跨腰线武器像素。透明加工仅清除不超过3/255覆盖度的背景散点，源图不改。跑步下身按移动方向、上身按瞄准方向；站立持弓上身复用于持弓跑动，无弓跑动使用完整绘制的摆臂上身。受击／闪避各向一张完整身体，倒下／倒地两张，避免低姿横切。

普通与Q共用八阶段射箭，E目前也复用普通射箭姿态，**没有独立高抛动画**；高抛生成被服务拒绝。背向出箭使用弓手前方的投射语义点，标为遮挡，不称可见箭尖。伤害与冷却不改，新发射标定会改变近墙几何，四向近墙专项已覆盖。正式导出门槛仍受既存11条回放差异阻挡，本轮输出独立预览包，不覆盖旧候选包。分类结果与未通过项见[接入证据](../../../output/art/CHR-001/2026-11-17-multistate-v3/README.md)。

180°反向跑射复用同朝向正跑帧倒放，避免腰膝朝向相反；不是独立退步原画。最终下层裁切另排除左向后手和背向袖口的少量跨衣摆像素，详见registration的excludeLower字段。

## 左右跑动步幅修订（2026-11-17）

用户指出第一与第三个方向腿跨得太大。已用Sol编排内置imagegen定向编辑[右向](sources/stride-fix/right.png)及[左向](sources/stride-fix/left.png)八帧下身；运行run-lower的左右两行改用独立修订ID，原上身、攻击与前后跑步保持不变。左右源各用0.35整组缩放，保持鞋形与裤腿形状；没有横向压扁整张腿图或改变游戏速度／48单位循环。

[完整提示、原图、手工脚点与缩幅量化](../../../output/art/CHR-001/2026-11-17-stride-fix/art/README.md)记录实际图像工具路线与未知模型／费用。[范围校验](../../../output/art/CHR-001/2026-11-17-stride-fix/scope-check.json)核实其他14套图集及元数据、正背16腿帧与演员脚本未变。当前接入与预览包以[本轮记录](../../../output/art/CHR-001/2026-11-17-stride-fix/README.md)为准；之前v3包仍是修订前版本。
