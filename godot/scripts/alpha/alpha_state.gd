extends RefCounted

const Votes = preload("res://scripts/alpha/altar_votes.gd")

const REGIONS: Dictionary = {"equipment":Rect2i(0,0,6,5),"altar":Rect2i(6,0,4,4),"meridian":Rect2i(0,5,5,2),"warehouse":Rect2i(6,4,4,1)}
const NAMES: Dictionary = {"equipment":"装备","altar":"祭坛","meridian":"经脉","warehouse":"仓库"}
const CONTENT: Array = [
	["快马","器","残","雷",1,2,"使用后自身移速+40%，持续3秒；消耗一件；同效果尚在时拒绝重复且不耗物，不叠加／不刷新；不提供无敌，不影响首领"],
	["司晨","器","良","火",1,2,"使用后，当前已激活遭遇中的敌人停止行动1秒，取消尚未生效的攻击；消耗一件，本局最多用三件，按效果名计数；已释放投射物保留；首领受硬控保护，不绕过免疫，无合法可影响目标时不耗物"],
	["豕涉","器","常","水",1,2,"对距玩家240以内合法地面放半径90水洼，持续6秒，敌人区内移速降低40%，离开即恢复；消耗一件，每玩家最多一处，新使用替换旧水洼；不造成伤害、不自动附加湿润；首领可减速但不定身"],
	["守冢","器","常","土",1,2,"在玩家前方最近合法地面放一座80生命墓碑，持续8秒；240范围内普通怪优先攻击它；消耗一件，最多一座，新放替换旧墓碑；不阻玩家与箭、不产生伤害或掉落；首领不强制转仇恨，墓碑死亡不算击杀收益"],
	["囤积","契","残","金",1,2,"每首次拾取一件本局新道具，生命上限+1%，累计最多15%基础生命；占两格；按实例首次取得去重，丢下再捡不加层，器魂／技能奖励不算；离坛暂停加成、计数保留，重摆恢复，烧毁丢失；不自动补血"],
	["素食","契","残","木",1,2,"连续10秒没有击杀敌人后，每10秒恢复最大生命3%；击杀重置本周期；占两格；营地与其他停时不推进，离坛暂停周期；同名不叠加；安全走动仍耗香也可推进，不能靠暂停刷治疗；恢复不超过上限"],
	["涂炭","契","残","水",1,2,"在坛时移速−10%，受到伤害−10%；占两格；同名不叠加；离坛同时失去收益与代价；减伤在受击结算时应用，不改变敌方预警／命中几何"],
	["焚书","契","常","火",1,2,"每次成功发动一次容器点燃，本件记录本局攻击伤害+1%；占两格；一次点燃记一次，不按被烧件数计；离坛暂停加成，重摆恢复，毁掉失去；被本次点燃烧掉的焚书停止供给，不保留免费收益；无效发动不加层"],
	["鼠毫","符","残","金",1,1,"装备区生效时，道具拾取半径+5%，基础80变84；消耗一张嵌符名额，同名只一份；不扩大残碑、祭坛、营地等互动距离；不隔墙拾取"],
	["虎牙","符","残","场",1,1,"装备区生效时，直接普通箭／穿透箭暴击率+6个百分点；消耗一张嵌符名额，同名只一份，总概率上限100%；不让箭雨和派生伤害暴击；首领使用同一概率规则"],
	["羊角","符","残","木",1,1,"装备区生效时最大生命+30；消耗一张嵌符名额，同名只一份；保持当前生命数值，移除时只截到新上限，不自动补血；对首领无特殊效果"],
	["燧火","符","常","火",1,1,"直接普通箭／穿透箭命中时给该敌人燃烧，持续3秒，每完整秒2伤；消耗一张嵌符名额；同目标一份，重复命中刷新持续时间不叠伤；离开装备来源不追加新燃烧，已施加燃烧完成；首领可燃烧；燃烧不再次触发命中／暴击类词条"],
	["训练弓","装备","凡","",2,3,"训练载体，无额外属性；嵌符与镶书待接通"],
	["布履","装备","凡","",1,2,"训练载体，无额外属性"],
	["青龙","神兽","","木",2,2,"真实邻接木系气息；引风主动技能待接通"],
	["穿透箭","技能书","","",1,2,"专属，沿鼠标瞄准方向释放；沿用已有贯穿敌人、每箭每敌一次、实体挡箭的效果；冷却4秒，原打断与未发射取消规则保持"],
	["箭雨","技能书","","",2,2,"特殊·领域，合法固定地面点；沿用既有三段箭雨，敌人可走出落点；冷却8秒，不合法落点不消费冷却；显示有效圈与预告"],
	["回风","技能书","","",1,2,"特殊·位移，按当前移动方向；无移动则背向瞄准方向；0.20秒移动120，不造成伤害、不提供无敌，按路径分段检查实体；不穿墙；冷却5秒，无前摇，打断尚未释放的攻击，不销毁已生效的箭／雨；完全无法位移时拒绝且不扣冷却"],
	["蓄势","技能书","","",1,2,"特殊·增幅，对自身；接下来两次普通箭伤害增加50%，最多持续4秒；技能伤害不消费也不获此增幅；冷却10秒，无伤害动作；普通箭离弦即消费一层，射空／撞墙也消费；剩层存在时不能重复发动，不叠层；到期或局末清除"],
	["引风书","技能书","","",1,3,"神兽·位移，按当前移动方向，无方向则朝瞄准方向；首次0.20秒冲120，无无敌、无伤害，留下宽40、持续3秒的风道；风道内允许再冲一次；冷却8秒从首次发动算；再冲不重开冷却、不再生成额外次数；3秒内不用则失去；全程实体阻挡、失焦／暂停不自动续冲"]
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
		"description": "职责：慢速高压近战目标，提供明确恢复窗口与技能奖励\n动作／状态：追击、较长预警、横扫、恢复、受击、败退／奖励\n规则：生命150、移速85、伤害25、范围90，预警0.70／挥击0.12／恢复0.90秒；没有隐藏护甲，保持受击与实际扣血可解释；每组一只"
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
var items: Array[Dictionary] = []
var camp: bool = true
var elapsed: float = 0.0
var message: String = "先选物品，再点击目标格；营地整理暂停冒险。"
var ranking: Dictionary = {}
var next_order: int = 0
var next_id: int = 0
var seed_value: int = 1

func _init(seed_number: int = 1) -> void:
	seed_value=seed_number

func reset(spawn: Vector2) -> void:
	items.clear(); camp=true; elapsed=0; next_id=0; next_order=0; ranking={}
	message="白盒：仅空间规则已接通，内容卡中的战斗效果尚未实现。"
	add_item("训练弓","equipment",Vector2i(0,0))
	add_item("布履","equipment",Vector2i(3,0))
	add_item("青龙","equipment",Vector2i(4,1))
	var drop: Dictionary = add_item("快马","ground",Vector2i.ZERO)
	drop.world=spawn+Vector2(60,0)
	recount()

func definition(title: String) -> Dictionary:
	if title.begins_with("白盒装备·") and Votes.OPPOSITE.has(title.trim_prefix("白盒装备·")):
		return {"name":title,"kind":"装备","quality":"凡","container":title.trim_prefix("白盒装备·"),"size":Vector2i.ONE,"description":"受控装备票权样本；按品质和唯一主符投票，不提供属性、嵌符或镶书"}
	if title.begins_with("白盒·") and Votes.OPPOSITE.has(title.trim_prefix("白盒·")):
		return {"name":title,"kind":"受控票物","quality":"常","container":title.trim_prefix("白盒·"),"size":Vector2i.ONE,"description":"白盒受控定义，只验证票权、资格、倍率与锁物，不进入实际掉落"}
	for row in CONTENT:
		if row[0]==title:
			return {"name":row[0],"kind":row[1],"quality":row[2],"container":row[3],"size":Vector2i(row[4],row[5]),"description":row[6]}
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
		if item.region!="ground" and Rect2i(item.cell,shape(item,item.rotated)).has_point(cell): return item
	return {}

func place(item: Dictionary, cell: Vector2i, rotated: bool) -> bool:
	if item.get("locked",false): message="物品被锁定，不能移动"; return false
	var region: String = ""
	var rectangle: Rect2i = Rect2i(cell,shape(item,rotated))
	for key in REGIONS:
		if REGIONS[key].encloses(rectangle): region=key; break
	if region.is_empty(): message="放置失败：越界、跨区或仓格未开放"; return false
	if item.kind=="神兽" and region!="equipment": message="神兽须在装备区"; return false
	for other in items:
		if other.id!=item.id and other.region!="ground" and rectangle.intersects(Rect2i(other.cell,shape(other,other.rotated))):
			message="放置失败：目标格已占用"; return false
	for sealed in ranking.get("sealed",[]):
		if rectangle.has_point(sealed) and (item.region=="ground" or not Votes.cells(item).has(sealed)):
			message="金作祟封格：不许新放入，已有物不失效"; return false
	if region=="altar" and item.region!="altar": next_order+=1; item.order=next_order
	item.cell=cell; item.region=region; item.rotated=rotated
	message="已摆放 "+item.name+" · "+NAMES[region]
	return true

func command(action: Dictionary, room: RefCounted) -> void:
	var kind: String = action.get("action","")
	if kind=="depart":
		if room.paused or room.reading: message="先恢复暂停或关闭阅读"; return
		camp=false; room.cancel_input(); message="冒险中；返回起点且清除已激活敌人后可整理"; return
	if kind=="camp":
		for enemy in room.snapshot().enemies:
			if enemy.phase!="inactive" and enemy.phase!="dead": message="请先清除已激活影偶"; return
		if Vector2(room.player.x,room.player.y).distance_to(room.point(room.layout.spawn))>100:
			message="需返回安全出发点"; return
		camp=true; room.cancel_input(); return
	if room.paused or room.reading: message="暂停或阅读中不能改动白盒"; return
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
	if kind=="pickup":
		if item.region!="ground": message="该实例已拾取"; return
		var origin: Vector2 = Vector2(room.player.x,room.player.y)
		if origin.distance_to(item.world)>80 or not room.clear_path(origin,item.world): message="物品过远或被实体遮挡"; return
		for x in range(6,10):
			if place(item,Vector2i(x,4),false) or place(item,Vector2i(x,4),true): return
		message="仓库无位，物品留地"; return
	if not camp: message="精细整理仅限安全营地"; return
	if item.region=="ground": message="先拾取实物"; return
	if kind=="place": place(item,action.get("cell",item.cell),action.get("rotated",item.rotated))

func recount() -> void:
	ranking=Votes.calculate(items,ranking)

func snapshot() -> Dictionary:
	var cards: Array[Dictionary] = []
	for row in CONTENT: cards.append(definition(row[0]))
	for actor in CHARACTERS: cards.append(actor.duplicate(true))
	for key in Votes.OPPOSITE:
		cards.append(definition("白盒·"+key))
		cards.append(definition("白盒装备·"+key))
	var result: Dictionary = {"version":"tanggu-alpha-whitebox.1","seed":seed_value,"camp":camp,"elapsed":elapsed,"items":items.duplicate(true),"regions":REGIONS.duplicate(),"message":message,"cards":cards,"combatEffectsReady":false}

	result.merge(ranking.duplicate(true))
	return result
