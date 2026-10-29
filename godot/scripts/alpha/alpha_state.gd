extends RefCounted

const ItemEffects = preload("res://scripts/gameplay/item_effects.gd")
const Skills = preload("res://scripts/alpha/equipment_skills.gd")
const Equipment = preload("res://scripts/alpha/equipment_rules.gd")
const Votes = preload("res://scripts/alpha/altar_votes.gd")
const Geometry = preload("res://scripts/alpha/altar_geometry.gd")

const REGIONS: Dictionary = {"equipment":Rect2i(0,0,6,5),"altar":Rect2i(6,0,4,4),"warehouse":Rect2i(6,4,4,1)}
const NAMES: Dictionary = {"equipment":"装备","altar":"祭坛","warehouse":"收纳"}
const CONTENT: Array = [
	["快马","器","残","雷",1,2,"使用后自身移速+40%，持续3秒；消耗一件；同效果尚在时拒绝重复且不耗物，不叠加／不刷新；不提供无敌，不影响首领"],
	["司晨","器","良","火",1,2,"使用后，当前已激活遭遇中的敌人停止行动1秒，取消尚未生效的攻击；消耗一件，本局最多用三件，按效果名计数；已释放投射物保留；首领受硬控保护，不绕过免疫，无合法可影响目标时不耗物"],
	["豕涉","器","常","水",1,2,"对距玩家240以内合法地面放半径90水洼，持续6秒，敌人区内移速降低40%，离开即恢复；消耗一件，每玩家最多一处，新使用替换旧水洼；不造成伤害、不自动附加湿润；首领可减速但不定身"],
	["守冢","器","常","土",1,2,"在玩家前方最近合法地面放一座80生命墓碑，持续8秒；240范围内普通怪优先攻击它；消耗一件，最多一座，新放替换旧墓碑；不阻玩家与箭、不产生伤害或掉落；首领不强制转仇恨，墓碑死亡不算击杀收益"],
	["囤积","契","残","金",1,2,"每首次拾取一件本局新道具，生命上限+1%，累计最多15%基础生命；占两格；按实例首次取得去重，丢下再捡不加层，器魂不算；离坛暂停加成、计数保留，重摆恢复，烧毁丢失；不自动补血"],
	["素食","契","残","木",1,2,"连续10秒没有击杀敌人后，每10秒恢复最大生命3%；击杀重置本周期；占两格；营地与其他停时不推进，离坛暂停周期；同名不叠加；安全走动仍耗香也可推进，不能靠暂停刷治疗；恢复不超过上限"],
	["涂炭","契","残","水",1,2,"在坛时移速−10%，受到伤害−10%；占两格；同名不叠加；离坛同时失去收益与代价；减伤在受击结算时应用，不改变敌方预警／命中几何"],
	["焚书","契","常","火",1,2,"每次成功发动一次容器点燃，本件记录本局攻击伤害+1%；占两格；一次点燃记一次，不按被烧件数计；离坛暂停加成，重摆恢复，毁掉失去；被本次点燃烧掉的焚书停止供给，不保留免费收益；无效发动不加层"],
	["鼠毫","符","残","金",1,1,"装备区生效时，道具拾取半径+5%，基础80变84；消耗一张嵌符名额，同名只一份；不扩大残碑、祭坛、营地等互动距离；不隔墙拾取"],
	["虎牙","符","残","场",1,1,"装备区生效时，直接普通箭／穿透箭暴击率+6个百分点；消耗一张嵌符名额，同名只一份，总概率上限100%；不让箭雨和派生伤害暴击；首领使用同一概率规则"],
	["羊角","符","残","木",1,1,"装备区生效时最大生命+30；消耗一张嵌符名额，同名只一份；保持当前生命数值，移除时只截到新上限，不自动补血；对首领无特殊效果"],
	["燧火","符","常","火",1,1,"直接普通箭／穿透箭命中时给该敌人燃烧，持续3秒，每完整秒2伤；消耗一张嵌符名额；同目标一份，重复命中刷新持续时间不叠伤；离开装备来源不追加新燃烧，已施加燃烧完成；首领可燃烧；燃烧不再次触发命中／暴击类词条"],
	["训练弓","装备","凡","",2,3,"训练载体，无额外属性；有效穿戴提供Q穿透箭、E箭雨；与布履形成羁绊提供T蓄势；可嵌三符"],
	["布履","装备","凡","",1,2,"训练载体，无额外属性；有效穿戴提供G回风；与训练弓形成羁绊提供T蓄势"],
	["青龙","神兽","","木",2,2,"真实邻接木系气息；有效随行提供C引风，首次16蓝包含一次追加，无无敌"],
	["白虎","神兽","","场",2,2,"真实邻接场斗气息；有效随行提供C金戈裂痕，撕裂硬直与破阵近身"],
	["朱雀","神兽","","火",2,2,"真实邻接火焚气息；有效随行提供C残烬火羽，地火引燃与爆裂火羽"],
]
const CHARACTERS: Array = [
	{
		"name": "孩子·后羿附体",
		"kind": "人物职责",
		"quality": "首轮初值",
		"container": "",
		"size": Vector2i.ONE,
		"description": "职责：持续走射、用穿透箭打排线、用箭雨处理聚集，以闪避和技能寻找输出窗口\n动作／状态：待机、四向移动／瞄准、普通射箭、穿透箭、箭雨、闪避、受击、失败；回风复用位移动作，蓄势增加手部提示\n规则：生命100、移速220，普通箭15、间隔0.35秒、前摇0.08秒，受击硬直0.12秒及保护0.6秒；初版新增暴击率10%、倍率1.5，仅普通箭／穿透箭每攻击动作判定一次；旧参照不开启，不混写为旧基线"
	},
	{
		"name": "鸟面影偶",
		"kind": "人物职责",
		"quality": "首轮初值",
		"container": "",
		"size": Vector2i.ONE,
		"description": "职责：基础近战追击者，教玩家保持距离与识别预警\n动作／状态：待机／发现、追击、预警、挥击、恢复、受击、退场\n规则：生命60、移速120、伤害20、近战范围70，预警0.45／挥击0.10／恢复0.65秒，沿用现有规则"
	},
	{
		"name": "纸面影偶",
		"kind": "人物职责",
		"quality": "首轮初值",
		"container": "",
		"size": Vector2i.ONE,
		"description": "职责：远程压迫者，迫使玩家横向走位、利用遮挡\n动作／状态：移动、蓄投、投射、恢复、受击、退场\n规则：生命45、移速90；约300距离停步锁定方向，预警0.75秒后投一枚10伤纸矢，速度360、寿命1.5秒、恢复1.25秒；不追踪，实体阻挡，只有在首次接触玩家时伤害一次"
	},
	{
		"name": "木甲影偶·精英",
		"kind": "人物职责",
		"quality": "首轮初值",
		"container": "",
		"size": Vector2i.ONE,
		"description": "职责：慢速高压近战目标，提供明确恢复窗口与既有构筑奖励\n动作／状态：追击、较长预警、横扫、恢复、受击、败退／奖励\n规则：生命150、移速85、伤害25、范围90，预警0.70／挥击0.12／恢复0.90秒；没有隐藏护甲，保持受击与实际扣血可解释；每组一只"
	},
	{
		"name": "索尔·验证阶段",
		"kind": "人物职责",
		"quality": "首轮初值",
		"container": "",
		"size": Vector2i.ONE,
		"description": "职责：测试排线、站位与点燃时机的首关终场\n动作／状态：出场、转向／移动、横扫预警／释放／恢复、落雷预告／释放、受击、倒下\n规则：生命900、移速75；近身横扫范围110、伤害25、预警0.8／有效0.15／恢复1.0秒；落雷固定三处合法点，半径70、每点15伤、间隔0.4秒，首处预告至少0.8秒，落下不追踪；循环横扫→恢复→落雷→恢复"
	}
]
const EFFECT_CARDS: Array = [
	{
		"name": "金·鼎·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "金",
		"size": Vector2i.ONE,
		"description": "显灵：显灵期间每次真实击杀记录+1基础攻击伤害，仅显灵时供给，离开排名不发免费收益\n作祟：祭坛左上横向两格封格：不许新放入，已有物仍投票、可移出／使用／点燃，不因封格失票循环\n点燃20秒：期间每次真实击杀记录+2基础攻击伤害，作为本局终极收益保留至局末；不是跨局属性\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "木·祠·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "木",
		"size": Vector2i.ONE,
		"description": "显灵：每30秒恢复最大生命15%，首次需满周期\n作祟：移速−10%\n点燃20秒：每5秒恢复最大生命8%，在第5／10／15／20秒各一次\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "水·沉·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "水",
		"size": Vector2i.ONE,
		"description": "显灵：每次实际受伤后保护延长至1.5秒，与既有0.6秒取较长者\n作祟：可见世界范围收窄20%，不改碰撞、施法距离或HUD\n点燃20秒：玩家无敌20秒，结束后3秒不能移动或发动攻击／技能；在原位置，不穿越实体，不清除敌人已有攻击\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "火·焚·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "火",
		"size": Vector2i.ONE,
		"description": "显灵：击杀时在死者脚点半径80造成15派生爆炸伤害，可连锁，每敌死亡一次\n作祟：每秒损失1生命，可致死，不产生敌人击杀奖励\n点燃20秒：已激活敌人每秒5燃烧伤害；不激活远处敌人。与燧火同目标燃烧取较高秒伤，不叠成两次伤害\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "土·葬·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "土",
		"size": Vector2i.ONE,
		"description": "显灵：受到伤害乘0.82，与涂炭的0.90分别相乘后最终取整\n作祟：只将基础闪避距离乘0.75，时长／无敌窗不变，不影响回风／引风\n点燃20秒：受到伤害乘0.50；无敌优先为零，不产生负伤害\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "雷·刑·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "雷",
		"size": Vector2i.ONE,
		"description": "显灵：直接攻击暴击后，对该次首个命中敌人追加一次15雷伤；每次攻击动作最多一次\n作祟：玩家每次实际受伤在同一事件中额外+5伤，不再次触发受伤链\n点燃20秒：每次直接攻击动作首次有效命中追加一次15雷伤，射空不触发；与显灵雷击不对同动作重复发动\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "场·斗·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "场",
		"size": Vector2i.ONE,
		"description": "显灵：显灵期间每次击杀记录普通攻击起手速率+2%，最多10层，仅显灵时供给\n作祟：当前遭遇激活时额外增加一只普通鸟面影偶，同一遭遇最多一次；离开第二名不删已经出现的敌人\n点燃20秒：期间每次击杀增加普通攻击起手速率5%，只在本次终极供给；最短起手间隔0.10秒，仍不能跳过攻击前摇\n白盒只记录周期与占格；战斗效果待后续接通。"
	},
	{
		"name": "塔·镇·效果说明",
		"kind": "容器说明",
		"quality": "首轮初值",
		"container": "塔",
		"size": Vector2i.ONE,
		"description": "显灵：白盒受控样例为半径160内敌移速−25%，正式小池不提供塔物品\n作祟：装备与羁绊主动技能的冷却乘1.15，不改变普通攻击或基础闪避\n点燃20秒：白盒受控样例令普通敌不能移动但仍可进行范围内攻击；对首领改为移速−50%，不长期冻结行动；不投放相关免耗道具\n白盒只记录周期与占格；战斗效果待后续接通。"
	}
]
var pickup_card: Dictionary = {}
var pickup_blocked: Dictionary = {}
var quick_item_id: int = -1
var rewarded_waves: Dictionary = {}
var runtime: RefCounted
var prototype_claimed: bool = false
var prototype_burn: bool = false
var acquired: Dictionary = {}
var skills: Dictionary = {}
var gameplay: bool = false
var initial_items: Array = []
var applied_equipment: Dictionary = {"healthMax":100,"pickupRadius":80.0,"effects":[],"enabledIds":[]}
var items: Array[Dictionary] = []
var camp: bool = true
var elapsed: float = 0.0
var adventure_complete: bool = false
var message: String = "先选物品，再点击目标格；营地整理暂停冒险。"
var departed: bool = false
var shadow_id: int = -1
var lost_shadows: Array[int] = []
var burn: Dictionary = {}
var last_burn: Dictionary = {}
var burn_held: bool = false
var ranking: Dictionary = {}
const BEAST_TIER_NAMES: Dictionary = {
	"青龙": ["初念 · 风道疾驰", "再念 · 踏风绝尘", "三念 · 疾风震爆"],
	"白虎": ["初念 · 裂痕初绽", "再念 · 金戈断空", "三念 · 破阵裂隙"],
	"朱雀": ["初念 · 残烬灼华", "再念 · 火线奔涌", "三念 · 火羽焚天"]
}
const BEAST_TIER_DESCS: Dictionary = {
	"青龙": [
		"冲刺120留3秒风道，时限内可0蓝追加一次冲刺",
		"实体风墙阻挡敌方纸矢，踏上风道免疫地面灼烧与陷阱伤害，移速+30%",
		"射出的箭矢穿过风道时引爆风道，向前化为强力多重风刃冲击"
	],
	"白虎": [
		"蓄力或暴击命中在目标身上刻下裂痕，下次直接箭命中触发撕裂硬直",
		"翻滚穿过裂痕敌人触发近身气爆震荡，冲刺转为进攻压制",
		"箭矢命中裂痕向同轴敌人传递连锁裂痕，实现链式全屏破阵"
	],
	"朱雀": [
		"命中燃烧目标在落点滞留3秒余烬，改变安全路线",
		"翻滚穿过余烬会将其引燃成横向烈焰火线，阻隔敌方走位",
		"箭雨落点与余烬相连提前引爆爆裂火羽，形成大范围灼烧轰鸣"
	]
}

var next_order: int = 0
var next_id: int = 0
var seed_value: int = 1
var altar_analysis: Dictionary = {}
var blessing_beast: String = "青龙"
var blessing_tier: int = 1
var blessing_evolves_left: int = 2
var pacts: Array[String] = []
var stele_inscription: Dictionary = {}

func _init(seed_number: int = 1, gameplay_mode: bool = false, starting_items: Array = []) -> void:
	seed_value=seed_number; gameplay=gameplay_mode; initial_items=starting_items.duplicate(true)

func reset(spawn: Vector2) -> void:
	adventure_complete=false
	runtime=ItemEffects.new(seed_value); prototype_claimed=false; prototype_burn=false; acquired.clear()
	pickup_card={}; pickup_blocked.clear(); quick_item_id=-1; rewarded_waves.clear()
	items.clear(); camp=true; elapsed=0; next_id=0; next_order=0; ranking={}; burn={}; last_burn={}; burn_held=false; departed=false; shadow_id=-1; lost_shadows.clear()
	blessing_beast="青龙"; blessing_tier=1; blessing_evolves_left=1 if pacts.has("重念限制") else 2; altar_analysis={}; stele_inscription.clear()
	message="先摆好背包；羊角可提高生命上限，鼠毫可扩大拾取范围。确认出发后进入汤谷。" if gameplay else "专项空间验证状态。"
	if not initial_items.is_empty() and initial_items[0].has("region"):
		for initial in initial_items:
			var restored: Dictionary = initial.duplicate(true)
			items.append(restored)
			next_id = maxi(next_id, int(restored.get("id", 0)) + 1)
	else:
		add_item("训练弓","equipment",Vector2i(0,0))
		add_item("布履","equipment",Vector2i(3,0))
		add_item("青龙","equipment",Vector2i(4,1))
		if gameplay:
			add_item("羊角","warehouse",Vector2i(6,4))
			add_item("鼠毫","warehouse",Vector2i(7,4))
			var pact: Dictionary = add_item("素食","warehouse",Vector2i(8,4)); pact.rotated=true
			pact.description+="\n已接通：仅在祭坛生效，营地和暂停不推进周期"
			for initial in initial_items:
				var extra: Dictionary = add_item(initial.get("name",""),"ground",Vector2i.ZERO)
				if not extra.is_empty(): extra.world=initial.get("world",spawn)
		else:
			var drop: Dictionary = add_item("快马","ground",Vector2i.ZERO)
			drop.world=spawn+Vector2(60,0)
	applied_equipment = Equipment.preview(items) if gameplay else {"healthMax":100,"pickupRadius":80.0,"effects":[],"enabledIds":[]}
	if gameplay:
		for item in items:
			if REGIONS.has(item.region) and item.kind in ["器","契","符"]: acquired[item.id]=true
	recount()

func definition(title: String) -> Dictionary:
	if title.begins_with("白盒装备·") and Votes.OPPOSITE.has(title.trim_prefix("白盒装备·")):
		return {"name":title,"kind":"装备","quality":"凡","container":title.trim_prefix("白盒装备·"),"size":Vector2i.ONE,"description":"受控装备票权样本；按品质和唯一主符投票，不提供属性或技能、不用于嵌符"}
	if title.begins_with("白盒·") and Votes.OPPOSITE.has(title.trim_prefix("白盒·")):
		return {"name":title,"kind":"受控票物","quality":"常","container":title.trim_prefix("白盒·"),"size":Vector2i.ONE,"description":"白盒受控定义，只验证票权、资格、倍率与锁物，不进入实际掉落"}
	for row in CONTENT:
		if row[0]==title:
			var description: String = row[6]
			return {"name":row[0],"kind":row[1],"quality":row[2],"container":row[3],"size":Vector2i(row[4],row[5]),"description":description}
	return {}

func add_item(title: String, region: String, cell: Vector2i) -> Dictionary:
	var item: Dictionary = definition(title)
	if item.is_empty(): return {}
	item.merge({"id":seed_value*100000+next_id,"region":region,"cell":cell,"rotated":false,"state":"normal","order":0})
	next_id+=1; items.append(item)
	return item

static func shape(item: Dictionary, rotated: bool) -> Vector2i:
	return Vector2i(item.size.y,item.size.x) if rotated else item.size

func at_cell(cell: Vector2i) -> Dictionary:
	for item in items:
		if REGIONS.has(item.region) and Rect2i(item.cell,shape(item,item.rotated)).has_point(cell): return item
	return {}

func placement_error(item: Dictionary, cell: Vector2i, rotated: bool, ignore_id: int = -1) -> String:
	if item.is_empty(): return "没有选中的物品"
	if item.get("shadow",false) and departed: return "出发残影本局锁定位置"
	if item.get("state","")=="burning": return "燃烧中仍占原格，不能移动"
	if item.get("locked",false): return "物品已锁定，不能移动"
	var rectangle: Rect2i = Rect2i(cell,shape(item,rotated))
	var region: String = ""
	for key in REGIONS:
		if REGIONS[key].encloses(rectangle):
			region=key
			break
	if region.is_empty(): return "目标位置越界、跨区或不可用"
	if item.get("shadow",false) and region!="altar": return "残影只能放入祭坛"
	if item.get("kind","")=="神兽" and region!="equipment": return "神兽只能放入装备区"
	for other in items:
		if other.id==ignore_id or other.id==item.get("id",-1): continue
		if gameplay and region=="equipment" and other.region=="equipment" and not Equipment.slot(item).is_empty() and Equipment.slot(item)==Equipment.slot(other):
			return "同部位只启用一件训练装备"
		if REGIONS.has(other.region) and rectangle.intersects(Rect2i(other.cell,shape(other,other.rotated))):
			return "目标格已被其他物品占用"
	for sealed in ranking.get("sealed",[]):
		if rectangle.has_point(sealed) and (item.get("region","")=="ground" or not Votes.cells(item).has(sealed)):
			return "金作祟封格：目标格不可进入"
	return ""

func place(item: Dictionary, cell: Vector2i, rotated: bool) -> bool:
	var error: String = placement_error(item,cell,rotated)
	if not error.is_empty():
		message="放置失败："+error
		return false
	var rectangle: Rect2i = Rect2i(cell,shape(item,rotated))
	var region: String = ""
	for key in REGIONS:
		if REGIONS[key].encloses(rectangle):
			region=key
			break
	if region=="altar" and item.region!="altar": next_order+=1; item.order=next_order
	item.cell=cell; item.region=region; item.rotated=rotated
	message="已摆放 "+item.name+" · "+NAMES[region]
	return true

func command(action: Dictionary, room: RefCounted) -> void:
	var kind: String = action.get("action","")
	if gameplay and room!=null and (room.paused or room.reading or room.status=="failed"):
		message="暂停、阅读或影散后不能调整构筑"; return
	if gameplay and kind=="prototype_kit":
		if not camp or room.layout.get("roomId","") not in ["","entry"]: message="只可在入口营地领取原型"; return
		if prototype_claimed: message="本局十二件原型已领，不重复生成"; return
		prototype_claimed=true; prototype_burn=true
		for index in 12:
			var item: Dictionary = add_item(CONTENT[index][0],"ground",Vector2i.ZERO)
			item.world=room.potion_location(Vector2(room.player.x,room.player.y)+Vector2((index%4-1.5)*20,(index/4-1)*20))
			item.roomId=room.layout.get("roomId",""); item.prototype=true
		message="十二件实物已放脚边；原型B只验证烧物与焚书，容器战斗效果未开放"; return
	if gameplay and kind in ["quick_altar","quick_bind","use_quick"]:
		if room.paused or room.reading or room.status=="failed": message="暂停、阅读或结算中不能快捷操作"; return
		if kind=="quick_altar": quick_altar(room)
		elif kind=="quick_bind": bind_quick(action.get("id",-1))
		else: use_quick(room)
		return
	if gameplay and kind in ["sample","fixture_lock","shadow"]: message="玩法模式不开放受控样本"; return
	if gameplay and kind in ["embed","main_glyph"]:
		if not camp or room.paused or room.reading or room.status=="failed": message="仅可在安全营地装配"; return
		var equipment: Dictionary = {}
		var glyph: Dictionary = {}
		for candidate in items:
			if candidate.id==action.get("equipmentId",-1): equipment=candidate
			if candidate.id==action.get("glyphId",-1): glyph=candidate
		if equipment.is_empty(): message="装备实例不存在"; return
		if kind=="embed":
			message="实物符不存在" if glyph.is_empty() else Equipment.embed(items,equipment,glyph)
		else: message=Equipment.select_main(equipment,action.get("glyphId",-1))
		return
	if kind=="select_beast":
		select_beast(action.get("beast","青龙"))
		return
	if kind=="toggle_pact":
		toggle_pact(action.get("pact",""))
		return
	if kind=="evolve_blessing":
		if not camp:
			message="仅可在安全营地进行神兽祝词重念演化"
			return
		if blessing_evolves_left<=0:
			message="本局重念演化次数已用尽（局限2次）"
			return
		if blessing_tier>=3:
			message=blessing_beast+"祝词已至完成形态（三念）"
			return
		blessing_tier+=1
		blessing_evolves_left-=1
		var tier_titles: Array = BEAST_TIER_NAMES.get(blessing_beast, BEAST_TIER_NAMES["青龙"])
		message="神兽祝福演化成功：已达成【%s】" % tier_titles[blessing_tier-1]
		recount(); return
	if kind=="shadow":
		choose_shadow(action,room); return
	if kind=="burn":
		if room.paused or room.reading: message="暂停或阅读中不能点燃"; return
		ignite(); return
	if kind=="depart":
		if room.paused or room.reading: message="先恢复暂停或关闭阅读"; return
		for candidate in items:
			if candidate.get("shadow",false) and candidate.region!="altar": message="先实际摆好残影或选择不带"; return
		if gameplay: applied_equipment=Equipment.preview(items)
		departed=true; camp=false; room.cancel_input(); message="冒险中；返回起点且清除已激活敌人后可整理"; return
	if kind=="camp":
		if gameplay and not room.snapshot().get("roomComplete",true): message="完成本房全部任务后才可整理"; return
		for enemy in room.snapshot().enemies:
			if enemy.phase!="inactive" and enemy.phase!="dead": message="请先清除已激活影偶"; return
		var safe: bool = false
		for location in room.layout.get("camps",[room.layout.spawn]) if gameplay else [room.layout.spawn]:
			if Vector2(room.player.x,room.player.y).distance_to(room.point(location))<=100 and room.clear_path(room.player,room.point(location)): safe=true
		if not safe: message="需返回安全营地"; return
		camp=true
		if gameplay: pickup_card={}
		room.cancel_input(); return
	if room.paused or room.reading: message="暂停或阅读中不能调整背包"; return
	if kind=="sample" and camp:
		var sample: Dictionary = definition(action.get("name",""))
		if sample.is_empty() or sample.kind=="神兽": message="此内容不能增发"; return
		var added: Dictionary = add_item(sample.name,"ground",Vector2i.ZERO)
		added.world=Vector2(room.player.x,room.player.y)
		if sample.kind=="受控票物" or sample.name.begins_with("白盒装备·"):
			added.quality=action.get("quality","常") if Votes.BASE.has(action.get("quality","常")) else "常"
			added.fixture_multiplier=1.5 if action.get("weighted",false) else 1.0
			added.eligible=action.get("eligible",true)
			added.locked=false
			if sample.kind=="装备":
				added.mainGlyph=action.get("mainGlyph",true)
				if not added.mainGlyph: added.container=""
		message="受控样本已放脚边，拾取后整理；战斗效果未接通"; return
	var item: Dictionary = {}
	for candidate in items:
		if candidate.id==action.get("id",-1): item=candidate; break
	if item.is_empty(): message="物品实例不存在"; return
	if item.get("shadow",false) and kind not in ["place"]: message="残影不能使用、改装或喂兽"; return
	if gameplay and kind=="drop":
		if not camp and item.region=="equipment": message="装备只能在营地卸下"; return
		if item.kind=="神兽": message="神兽不能丢弃"; return
		if item.region not in REGIONS or item.state=="burning" or item.get("locked",false): message="此物品不能丢弃"; return
		item.roomId=room.layout.get("roomId","")
		item.region="ground"; item.world=Vector2(room.player.x,room.player.y); pickup_blocked[item.id]=true
		message="已放到脚边，离开拾取范围后才重新自动拾取"; return
	if kind=="discard" and item.state=="ash":
		items.erase(item); message="已丢弃灰烬"; return
	if kind=="fixture_lock" and camp and item.kind=="受控票物":
		item.locked=not item.get("locked",false); return
	if kind=="pickup":
		if gameplay: pickup_item(item,room); return
		if item.region!="ground": message="该实例已拾取"; return
		var origin: Vector2 = Vector2(room.player.x,room.player.y)
		if origin.distance_to(item.world)>(applied_equipment.pickupRadius if gameplay else 80) or not room.clear_path(origin,item.world): message="物品过远或被实体遮挡"; return
		for x in range(6,10):
			if place(item,Vector2i(x,4),false) or place(item,Vector2i(x,4),true): return
		message="收纳区已满，物品留地"; return
	if not camp: message="精细整理仅限安全营地"; return
	if item.region=="ground": message="先拾取实物"; return
	if kind=="place": place(item,action.get("cell",item.cell),action.get("rotated",item.rotated))

func recount() -> void:
	if gameplay:
		normalize_references()
		skills=Skills.resolve(items)
	ranking=Votes.calculate(items,ranking)
	altar_analysis=Geometry.evaluate(items)

func active_synergy(title: String) -> Dictionary:
	for synergy in altar_analysis.get("synergies", []):
		if synergy.get("title", "") == title and synergy.get("energized", false):
			return synergy
	return {}

func has_active_synergy(title: String) -> bool:
	return not active_synergy(title).is_empty()

func snapshot() -> Dictionary:
	var cards: Array[Dictionary] = []
	for row in CONTENT: cards.append(definition(row[0]))
	for actor in CHARACTERS: cards.append(actor.duplicate(true))
	for effect in EFFECT_CARDS: cards.append(effect.duplicate(true))
	for key in Votes.OPPOSITE:
		cards.append(definition("白盒·"+key))
		cards.append(definition("白盒装备·"+key))
	var result: Dictionary = {"version":"tanggu-equipment-skills.2","seed":seed_value,"camp":camp,"elapsed":elapsed,"items":items.duplicate(true),"regions":REGIONS.duplicate(),"message":message,"cards":cards,"combatEffectsReady":gameplay,"departed":departed,"shadowId":shadow_id,"lostShadowIds":lost_shadows.duplicate(),"burn":burn.duplicate(true),"lastBurn":last_burn.duplicate(true)}

	if gameplay:
		result.prototypeClaimed=prototype_claimed
		result.prototypeBurn=prototype_burn
		result.skills=skills.duplicate(true)
		result.pickupCard=pickup_card_snapshot()
		result.quickItemId=quick_item_id
		result.quickItem=find_item(quick_item_id).duplicate(true)
		result.equipment=Equipment.preview(items)
		result.equipment.healthMax+=max_health()-int(applied_equipment.healthMax)
		result.appliedEquipment=applied_equipment.duplicate(true)
	result.altarAnalysis=altar_analysis.duplicate(true)
	result.blessingBeast=blessing_beast
	result.blessingTier=blessing_tier
	result.blessingEvolvesLeft=blessing_evolves_left
	var tier_names: Array = BEAST_TIER_NAMES.get(blessing_beast, BEAST_TIER_NAMES["青龙"])
	var tier_descs: Array = BEAST_TIER_DESCS.get(blessing_beast, BEAST_TIER_DESCS["青龙"])
	result.blessingTierName=tier_names[blessing_tier-1]
	result.blessingDesc=tier_descs[blessing_tier-1]
	result.canEvolveBlessing=camp and blessing_tier<3 and blessing_evolves_left>0
	result.pacts=pacts.duplicate()
	result.steleInscription=stele_inscription.duplicate(true)
	result.merge(ranking.duplicate(true))
	return result

func burn_input(pressed: bool) -> void:
	if pressed and not burn_held: ignite()
	burn_held=pressed

func ignite() -> void:
	if not burn.is_empty(): message="已有终极在进行，不能再次点燃"; return
	var winner: String = ranking.get("winner","")
	if winner.is_empty(): message="没有可点燃的显灵者"; return
	if winner in ["镜","草"]: message="镜／草只验证数学，本期没有准入终极"; return
	var targets: Array[int] = []
	for item in items:
		if item.region=="altar" and item.container==winner and item.state=="normal":
			if item.get("locked",false): message="该容器有锁物，不能整容器点燃"; return
			targets.append(item.id)
	if targets.is_empty(): message="没有可点燃的物品"; return
	for item in items:
		if targets.has(item.id): item.state="burning"
	burn={"container":winner,"remaining":20.0,"elapsed":0.0,"items":targets,"ticks":[],"period":5.0 if winner=="木" else 1.0 if winner=="火" else 0.0}
	if gameplay:
		for pact in items:
			if pact.name=="焚书" and pact.region=="altar" and pact.state=="normal": pact.burnStacks=pact.get("burnStacks",0)+1
	message=("已点燃%s：原效果和票停止，原格保留20秒；结束后生成灰烬" if gameplay else "已点燃%s：原格保留20秒并记录结算") % winner
	recount()

func advance(seconds: float, room: RefCounted) -> void:
	if room.layout.get("objective","")=="boss" and room.status=="complete": adventure_complete=true
	if not adventure_complete: elapsed+=seconds
	if gameplay and not pickup_card.is_empty():
		pickup_card.remaining=maxf(0,pickup_card.remaining-seconds)
		if pickup_card.remaining<=0.000001: pickup_card={}
	if burn.is_empty(): return
	var before: float = burn.elapsed
	burn.elapsed=minf(20.0,before+seconds)
	burn.remaining=maxf(0,20.0-burn.elapsed)
	if burn.period>0:
		var first: int = int(floor((before+0.000001)/burn.period))+1
		var last: int = int(floor((burn.elapsed+0.000001)/burn.period))
		for tick in range(first,last+1): burn.ticks.append(tick*burn.period)
	if burn.remaining>0.000001: return
	for item in items.duplicate():
		if not burn.items.has(item.id): continue
		if item.get("shadow",false):
			lost_shadows.append(item.id); shadow_id=-1; items.erase(item); continue
		item.state="ash"; item.description="灰烬保留原形状，不能投票或恢复原物，可丢弃"; item.name="灰烬·"+item.name; item.container=""; item.eligible=false; item.locked=false
		item.region="ground"; item.world=Vector2(room.player.x,room.player.y); item.roomId=room.layout.get("roomId","")
		for x in range(6,10):
			if place(item,Vector2i(x,4),false) or place(item,Vector2i(x,4),true): break
	last_burn=burn.duplicate(true); burn={}
	message="终极结束：灰烬自动入收纳区，无位留地，可丢弃"
	recount()

func choose_shadow(action: Dictionary, room: RefCounted) -> void:
	if departed or not camp or room.paused or room.reading or not burn.is_empty():
		message="只可在首次出发前、未暂停且无终极时选择受控前局残影"; return
	var title: String = action.get("name","")
	var original: Dictionary = definition(title)
	if not title.is_empty() and (original.is_empty() or original.kind=="神兽" or not Votes.OPPOSITE.has(original.container)):
		message="此卡不是有归属的前局残影候选"; return
	for previous in items.duplicate():
		if previous.get("shadow",false): items.erase(previous)
	shadow_id=-1
	if title.is_empty(): message="本次不携带残影"; return
	var item: Dictionary = add_item(title,"unplaced",Vector2i.ZERO)
	item.shadow=true; item.fixture=true
	item.quality=action.get("quality",item.quality) if Votes.BASE.has(action.get("quality",item.quality)) else item.quality
	item.description="受控前局候选：保留原形、种类、品质，基础1票；只投票、不恢复原效果。出发后锁位，可点燃且不产灰。"
	if item.kind=="装备": item.mainGlyph=true
	shadow_id=item.id
	message="已选择受控残影：请摆入祭坛；也可选择不带"

func find_item(id: int) -> Dictionary:
	for item in items:
		if item.id==id: return item
	return {}

func find_item_by_name(title: String) -> Dictionary:
	for item in items:
		if item.name==title: return item
	return {}

func select_beast(beast_name: String) -> bool:
	if not camp or departed:
		message="仅可在开局安全营地选择神兽祝福"
		return false
	if beast_name not in ["青龙","白虎","朱雀"]:
		message="未知的神兽："+beast_name
		return false
	blessing_beast=beast_name
	blessing_tier=1
	blessing_evolves_left=1 if pacts.has("重念限制") else 2
	for i in range(items.size()-1,-1,-1):
		if items[i].get("kind","")=="神兽":
			items.remove_at(i)
	add_item(beast_name,"equipment",Vector2i(4,1))
	recount()
	message="已立下神兽承诺：【%s】初念已锚定本局底色" % beast_name
	return true

func toggle_pact(pact_name: String) -> bool:
	if not camp or departed:
		message="仅可在出发前调整作祟契约"
		return false
	if pacts.has(pact_name):
		pacts.erase(pact_name)
		if pact_name=="重念限制": blessing_evolves_left=2
	else:
		pacts.append(pact_name)
		if pact_name=="重念限制": blessing_evolves_left=1
	recount()
	return true

func record_stele_inscription(inscription: Dictionary) -> void:
	stele_inscription=inscription.duplicate(true)

func normalize_references() -> void:
	var quick: Dictionary = find_item(quick_item_id)
	if quick.is_empty() or quick.region not in REGIONS or quick.kind!="器" or quick.state!="normal" or quick.get("shadow",false): quick_item_id=-1
	if not pickup_card.is_empty() and find_item(pickup_card.id).is_empty(): pickup_card={}

func pickup_card_snapshot() -> Dictionary:
	if pickup_card.is_empty(): return {}
	var item: Dictionary = find_item(pickup_card.id)
	if item.is_empty(): return {}
	var result: Dictionary = pickup_card.duplicate(true)
	result.name=item.name; result.region=item.region
	return result

func pickup_item(item: Dictionary, room: RefCounted) -> void:
	if item.region!="ground": message="该实例已拾取"; return
	if item.get("roomId","")!=room.layout.get("roomId",""): message="实物在其他房间"; return
	var origin: Vector2 = Vector2(room.player.x,room.player.y)
	if origin.distance_to(item.world)>applied_equipment.pickupRadius or not room.clear_path(origin,item.world): message="物品过远或被实体遮挡"; return
	if item.get("locked",false) or item.get("shadow",false) or item.state=="burning": message="此实例不能拾取"; return
	var stored: bool = false
	for x in range(6,10):
		if place(item,Vector2i(x,4),false) or place(item,Vector2i(x,4),true): stored=true; break
	message="已拾取 "+item.name if stored else "收纳区已满，物品留地；可按Tab尝试转坛"
	if stored: pickup_record(item)
	if not stored: pickup_blocked[item.id]=true
	if pickup_card.is_empty(): pickup_card={"id":item.id,"remaining":3.0,"reason":message,"attempted":false}

func auto_pickup(room: RefCounted) -> void:
	var origin: Vector2 = Vector2(room.player.x,room.player.y)
	var candidates: Array[Dictionary] = []
	for item in items:
		if item.region!="ground" or item.get("roomId","")!=room.layout.get("roomId",""): continue
		var distance: float = origin.distance_to(item.world)
		if distance>applied_equipment.pickupRadius: pickup_blocked.erase(item.id); continue
		if pickup_blocked.has(item.id) or item.get("locked",false) or item.get("shadow",false) or item.state=="burning" or not room.clear_path(origin,item.world): continue
		candidates.append({"item":item,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.item.id<b.item.id if is_equal_approx(a.distance,b.distance) else a.distance<b.distance)
	for candidate in candidates: pickup_item(candidate.item,room)
	normalize_references()

func quick_altar(room: RefCounted) -> void:
	if camp or pickup_card.is_empty(): message="没有有效的刚拾取转坛窗口"; return
	if pickup_card.attempted: message="此卡已尝试快捷转坛"; return
	pickup_card.attempted=true
	var item: Dictionary = find_item(pickup_card.id)
	if item.is_empty(): pickup_card={}; message="卡上实物已失效"; return
	if item.region=="ground":
		if item.get("roomId","")!=room.layout.get("roomId",""): message="卡上实物在其他房间"; pickup_card.reason=message; return
		var origin: Vector2 = Vector2(room.player.x,room.player.y)
		if origin.distance_to(item.world)>applied_equipment.pickupRadius or not room.clear_path(origin,item.world):
			message="卡上实物过远或被实体遮挡"; pickup_card.reason=message; return
	for y in range(0,4):
		for x in range(6,10):
			if place(item,Vector2i(x,y),false) or place(item,Vector2i(x,y),true):
				pickup_record(item)
				pickup_card.reason="已将卡上唯一实物转入祭坛"; message=pickup_card.reason; recount(); return
	pickup_card.reason="祭坛无合法空位，实物保持原处"; message=pickup_card.reason

func bind_quick(id: int) -> void:
	if id<0: quick_item_id=-1; message="已清空器快捷引用"; return
	var item: Dictionary = find_item(id)
	if item.is_empty() or item.region not in REGIONS or item.kind!="器" or item.state!="normal" or item.get("locked",false) or item.get("shadow",false): message="快捷栏只能引用携带的可用实物器"; return
	quick_item_id=id; message="V引用 "+item.name+" #"+str(id)

func use_quick(room: RefCounted) -> void:
	normalize_references()
	var item: Dictionary = find_item(quick_item_id)
	if item.is_empty(): message="V没有绑定可用实物器"; return
	if item.get("locked",false): message="快捷引用的实物被锁定"; return
	if camp: message="冒险中才可使用器"; return
	if runtime.use(item,room):
		items.erase(item); normalize_references(); recount()


func enemy_defeated(enemy: Dictionary, room: RefCounted) -> void:
	kill_record()
	if room.layout.get("objective","")=="boss": return
	# 没有资格字段的冻结夹具保留旧版每波首杀语义。
	if room.layout.has("constructionRewardWaves") and enemy.group not in room.layout.constructionRewardWaves: return
	if room.layout.has("constructionRewardWaves") and rewarded_waves.size()>=8: return
	var wave_key: String = "%s:%d" % [room.layout.get("roomId",""),enemy.group]
	if rewarded_waves.has(wave_key): return
	rewarded_waves[wave_key]=true
	var reward_cycle: Array[String] = ["羊角","虎牙","鼠毫","燧火","鼠毫","燧火","羊角","虎牙"]
	var reward_name: String = reward_cycle[(rewarded_waves.size()-1) % reward_cycle.size()] if room.layout.get("commercialDepthRewards",false) else ("羊角" if rewarded_waves.size()%2==1 else "鼠毫")
	var item: Dictionary = add_item(reward_name,"ground",Vector2i.ZERO)
	item.world=room.potion_location(Vector2(enemy.x,enemy.y))
	item.roomId=room.layout.get("roomId","")

func skill_active(kind: String) -> bool:
	return skills.get(kind,{}).get("active",false)

func active_pact(title: String) -> bool:
	return items.any(func(item: Dictionary): return item.name==title and item.region=="altar" and item.state=="normal" and not item.get("shadow",false))

func pickup_record(item: Dictionary) -> void:
	if acquired.has(item.id) or item.kind not in ["器","契","符"] or item.state!="normal": return
	acquired[item.id]=true
	for pact in items:
		if pact.name=="囤积" and pact.region=="altar" and pact.state=="normal" and not pact.get("shadow",false): pact.stacks=mini(15,pact.get("stacks",0)+1)

func max_health() -> int:
	var stacks: int = 0
	for pact in items:
		if pact.name=="囤积" and pact.region=="altar" and pact.state=="normal" and not pact.get("shadow",false): stacks=maxi(stacks,pact.get("stacks",0))
	return int(applied_equipment.healthMax)+stacks

func advance_pacts(room: RefCounted, seconds: float) -> void:
	var vegetarian: bool = false
	for pact in items:
		if pact.name!="素食" or pact.region!="altar" or pact.state!="normal" or pact.get("shadow",false): continue
		if vegetarian: continue
		vegetarian=true
		pact.period=pact.get("period",0.0)+seconds
		while pact.period>=10.0-0.000001:
			pact.period=maxf(0,pact.period-10.0)
			room.health=mini(room.health_max,room.health+roundi(room.health_max*0.03))

func kill_record() -> void:
	for pact in items:
		if pact.name=="素食": pact.period=0.0

func attack_bonus() -> float:
	var stacks: int = 0
	for pact in items:
		if pact.name=="焚书" and pact.region=="altar" and pact.state=="normal" and not pact.get("shadow",false): stacks+=pact.get("burnStacks",0)
	return 1.0+stacks*0.01

func can_camp(room: RefCounted) -> bool:
	if not gameplay: return true
	if room == null: return false
	if not room.snapshot().get("roomComplete", true): return false
	for enemy in room.snapshot().get("enemies", []):
		if enemy.get("phase", "") not in ["inactive", "dead"]: return false
	for location in room.layout.get("camps", [room.layout.get("spawn", Vector2.ZERO)]):
		var target: Vector2 = room.point(location)
		if Vector2(room.player.x, room.player.y).distance_to(target) <= 100.0 and room.clear_path(room.player, target):
			return true
	return false
