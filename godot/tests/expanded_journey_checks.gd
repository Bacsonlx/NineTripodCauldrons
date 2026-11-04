extends SceneTree

const Journey = preload("res://scripts/journey/room_journey.gd")
const Options = preload("res://scripts/input/play_options.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func fixture(id: String,task: String = "safe") -> Dictionary:
	var data: Dictionary = preload("res://scripts/combat/boss_room.gd").arena_layout()
	data.roomId=id; data.roomTitle=id; data.objective=task
	data.spawn=Vector2(300,520); data.doors=[]; data.exploration=[]; data.camps=[]
	return data

func connect_rooms(maps: Dictionary,source: String,target: String) -> void:
	for pair in [[source,target],[target,source]]:
		var location: Vector2 = Vector2(300+240*maps[pair[0]].doors.size(),520)
		maps[pair[0]].doors.append({"id":pair[1],"target":pair[1],"targetDoor":pair[0],"title":pair[1],"point":location,"arrival":location,"x":96,"y":520,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"})

func combat_fixture(id: String,waves: int,rewards: Array) -> Dictionary:
	var data: Dictionary = fixture(id,"combat")
	data.constructionRewardWaves=rewards
	for wave in waves:
		data.encounters.append({"x":300,"y":520,"enemies":[Vector2(550,520),Vector2(650,520)]})
	return data

func fight_until_wave(run: RefCounted,wave: int) -> void:
	for frame in 6000:
		var state: Dictionary = run.snapshot()
		if state.roomComplete or state.encounter>=wave or state.status=="failed": return
		var aim: Vector2 = Vector2(700,468)
		var movement: Vector2 = Vector2.ZERO
		if state.encounter==0 and state.enemies.all(func(enemy: Dictionary): return enemy.phase=="inactive"):
			movement=(Vector2(300,520)-TrainingRoom.point(state.player)).normalized()
		for enemy in state.enemies:
			if enemy.health>0 and enemy.phase!="inactive": aim=Vector2(enemy.x,enemy.y-52); break
		run.update({"fire":true,"aim":aim,"moveX":movement.x,"moveY":movement.y},0.01)
	check(false,"战斗必须在有限时间内推进")

func rewards(run: RefCounted) -> Array:
	return run.snapshot().alpha.items.filter(func(item: Dictionary): return item.name in ["羊角","虎牙","鼠毫","燧火"] and not str(item.get("roomId","")).is_empty())

func reward_checks() -> void:
	var maps: Dictionary = {"moss_side":combat_fixture("moss_side",2,[1]),"court1":combat_fixture("court1",2,[0])}
	connect_rooms(maps,"moss_side","court1")
	var run: RefCounted = Journey.new(maps,{"startRoom":"moss_side","isTest":true})
	fight_until_wave(run,1)
	check(rewards(run).is_empty(),"A首波真实清敌不发符，也不占用交替序号")
	fight_until_wave(run,2)
	check(run.snapshot().roomComplete and rewards(run).size()==1 and rewards(run)[0].name=="羊角","A末波首杀只发首枚羊角")
	var original: Dictionary = rewards(run)[0].duplicate(true)
	check(pass_to(run,"court1"),"真实过门继续使用同一局")
	fight_until_wave(run,1)
	check(not run.snapshot().roomComplete and rewards(run).size()==1,"主线首波达成但未清庭时，构筑战利品暂入本房待发队列，战中0构筑物落地")
	fight_until_wave(run,2)
	check(run.snapshot().roomComplete and rewards(run).size()==2 and rewards(run)[1].name=="鼠毫","主线清庭瞬间全额发放待发奖励，按实际第二次发放鼠毫")
	check(rewards(run)[0].id==original.id and rewards(run)[0].roomId=="moss_side","跨房共享背包且地面奖励仍属原房")
	check(pass_to(run,"moss_side") and rewards(run).size()==2 and run.snapshot().roomComplete,"回溯不刷新敌人与构筑奖励")
	run.update({"restart":true},0)
	check(run.snapshot().roomId=="moss_side" and rewards(run).is_empty() and run.snapshot().visitedRooms==1,"快速测试R新建所选起点并清空发放记录")

func settlement_timing_checks() -> void:
	var data: Dictionary = combat_fixture("court1",2,[0,1])
	data.encounters=[
		{"x":300,"y":520,"enemies":[Vector2(520,520),Vector2(760,520)]},
		{"x":300,"y":520,"enemies":[Vector2(520,520),Vector2(760,520)]}
	]
	var run: RefCounted = Journey.new({"court1":data},{"startRoom":"court1","isTest":true,"potionDrops":true,"dropSeed":1,"health":10000})
	var hoard_item: Dictionary = run.inventory.add_item("囤积","altar",Vector2i(7,1))
	var m1: Dictionary = run.inventory.find_item_by_name("鼠毫")
	run.inventory.place(m1,Vector2i(6,1),false)
	var m2: Dictionary = run.inventory.add_item("鼠毫","altar",Vector2i(6,2))
	# 填满4格收纳区，使清庭落地时若进入拾取范围会触发pickupCard与转坛流程。
	run.inventory.add_item("虎牙","warehouse",Vector2i(7,4))
	run.inventory.recount()
	check(run.active.has_spatial_synergy("拾取牵引"),"双鼠毫点亮拾取牵引")
	var pact_id: int = -1
	for it in run.snapshot().alpha.items:
		if it.name=="素食": pact_id=it.id
	# 击杀首波第一只近身怪（但首波尚未清完）
	var pulled_recall: bool = false
	for frame in 300:
		var state: Dictionary = run.snapshot()
		if not state.recalls.is_empty(): pulled_recall=true
		if state.enemies[0].phase=="dead": break
		run.active.hurt=0.0
		var move_x: float = -1.0 if state.player.x>340 else 0.0
		run.update({"moveX":move_x,"fire":true,"aim":Vector2(state.enemies[0].x,state.enemies[0].y-52)},0.01)
	check(run.snapshot().enemies[0].phase=="dead" and not run.snapshot().roomComplete,"首波首杀达成但房间未清庭")
	check(pulled_recall,"拾取牵引在命中时正常触发牵引与视觉记录")
	check(rewards(run).is_empty() and run.snapshot().alpha.pickupCard.is_empty(),"战中首杀0构筑物落地，不触发自动拾取或弹出pickupCard")
	# 战斗中主动从背包丢弃物品到脚边不受延迟影响
	run.update({"alpha":{"action":"drop","id":pact_id}},0)
	check(run.snapshot().alpha.items.filter(func(i: Dictionary): return i.id==pact_id)[0].region=="ground","玩家战中主动drop放到脚边的物品立即落地不受延迟影响")
	# 清完首波，进入第二波战斗中
	for frame in 1000:
		var state: Dictionary = run.snapshot()
		if state.encounter>=1: break
		run.active.hurt=0.0
		var aim: Vector2 = Vector2(760,468)
		for enemy in state.enemies:
			if enemy.health>0 and enemy.phase!="inactive": aim=Vector2(enemy.x,enemy.y-52); break
		var move_x: float = -1.0 if state.player.x>340 else 0.0
		run.update({"moveX":move_x,"fire":true,"aim":aim},0.01)
	check(not run.snapshot().roomComplete and not run.snapshot().drops.is_empty() and rewards(run).is_empty(),"首波清完即时掉落蓝囊保底，但构筑奖励仍保持待发不落地")
	# 清完第二波（房间完成），两波待发构筑物在清庭瞬间全额落地且防叠排布
	for frame in 1500:
		var state: Dictionary = run.snapshot()
		if state.roomComplete: break
		run.active.hurt=0.0
		var aim: Vector2 = Vector2(760,468)
		for enemy in state.enemies:
			if enemy.health>0 and enemy.phase!="inactive": aim=Vector2(enemy.x,enemy.y-52); break
		var move_x: float = -1.0 if state.player.x>340 else 0.0
		run.update({"moveX":move_x,"fire":true,"aim":aim},0.01)
	var settled: Array = rewards(run)
	check(run.snapshot().roomComplete and settled.size()==2,"清庭瞬间全额发放本房2件待发构筑战利品")
	if settled.size()==2:
		var p0: Vector2 = TrainingRoom.point(settled[0].world)
		var p1: Vector2 = TrainingRoom.point(settled[1].world)
		check(p0.distance_to(p1)>=20.0 and run.active.can_walk(p0) and run.active.can_walk(p1),"同房间多件清庭奖励經potion_location合法采样并环形错位防叠")
	# 重新填满收纳区后走近清庭落地的构筑物，验证满仓弹出pickupCard、Tab转坛与【囤积】契约计数正常生效
	run.inventory.add_item("燧火","warehouse",Vector2i(8,4))
	run.inventory.add_item("燧火","warehouse",Vector2i(9,4))
	run.inventory.pickup_blocked[pact_id]=true
	run.inventory.pickup_card={}
	var stacks_before: int = run.snapshot().alpha.items.filter(func(i: Dictionary): return i.id==hoard_item.id)[0].get("stacks",0)
	if not settled.is_empty():
		var ground_rewards: Array = rewards(run).filter(func(i: Dictionary): return i.region=="ground")
		check(not ground_rewards.is_empty() and walk(run,TrainingRoom.point(ground_rewards[0].world)),"清庭后走近第一件落地构筑物")
	check(not run.snapshot().alpha.pickupCard.is_empty(),"清庭后走近构筑物正常触发满仓pickupCard")
	var card_item_id: int = int(run.snapshot().alpha.pickupCard.get("id",-1))
	run.active.hurt=0.0
	run.update({"alpha":{"action":"quick_altar"}},0)
	var updated_hoard: Dictionary = run.snapshot().alpha.items.filter(func(i: Dictionary): return i.id==hoard_item.id)[0]
	var transferred: Array = run.snapshot().alpha.items.filter(func(i: Dictionary): return i.id==card_item_id and i.region=="altar")
	check(not transferred.is_empty() and updated_hoard.get("stacks",0)>=stacks_before+1,"清庭奖励经Tab快捷转坛正常入坛并累计【囤积】层数")

func budget_checks() -> void:
	var ids: Array[String] = ["court1","dry_creek","root_fork","court2","ash_cloister","gate_forecourt","court3","moss_side","ember_side"]
	var maps: Dictionary = {}
	for id in ids: maps[id]=combat_fixture(id,1,[0])
	for index in range(ids.size()-1): connect_rooms(maps,ids[index],ids[index+1])
	var run: RefCounted = Journey.new(maps,{"startRoom":"court1","isTest":true})
	for index in ids.size():
		if index>0: check(pass_to(run,ids[index]),"预算夹具真实过门："+ids[index])
		fight_until_wave(run,1)
		check(run.snapshot().roomComplete,"预算夹具真实清场："+ids[index])
		check(rewards(run).size()==mini(index+1,8),"整局发放硬上限8，不受更多合资格房／波影响")
	check(rewards(run).map(func(item: Dictionary): return item.name)==["羊角","鼠毫","羊角","鼠毫","羊角","鼠毫","羊角","鼠毫"],"实际发出8枚按次数交替")
	var legacy: Dictionary = combat_fixture("court1",2,[])
	legacy.erase("constructionRewardWaves")
	var old: RefCounted = Journey.new({"court1":legacy},{"startRoom":"court1"})
	fight_until_wave(old,2)
	check(rewards(old).size()==2,"冻结旧夹具没有资格字段时仍按旧每波首杀发放")
	var none: RefCounted = Journey.new({"ember_side":combat_fixture("ember_side",1,[])},{"startRoom":"ember_side"})
	fight_until_wave(none,1)
	check(none.snapshot().roomComplete and rewards(none).is_empty(),"显式空资格的C房清敌不发构筑符")

func route_checks() -> void:
	for pair in [["court1","dry_creek","前行"],["court3","gate_forecourt","返回"],["dry_creek","moss_side","可选支路"],["moss_side","dry_creek","汇入主路"],["moss_side","root_fork","汇入主路"]]:
		var maps: Dictionary = {pair[0]:fixture(pair[0]),pair[1]:fixture(pair[1])}
		connect_rooms(maps,pair[0],pair[1])
		var run: RefCounted = Journey.new(maps,{"startRoom":pair[0],"isTest":true})
		run.update({"alpha":{"action":"depart"}},0)
		check(run.snapshot().interaction.label.contains(pair[2]) and run.snapshot().interaction.label.contains(pair[1]),"门互动按设计方向显示路线和目标："+str(pair))
		check(pass_to(run,pair[1]) and pass_to(run,pair[0]),"门引导保留真实双向回溯")
		check(run.snapshot().interaction.label.contains(pair[2]),"目标已完成后仍保持设计方向而不是一律返回")

func time_checks() -> void:
	var entry: Dictionary = fixture("entry")
	entry.camps=[Vector2(300,520)]
	var run: RefCounted = Journey.new({"entry":entry},{"isTest":true})
	run.update({"alpha":{"action":"camp"}},0)
	run.update({},3)
	check(is_equal_approx(run.snapshot().get("activeSeconds",-1),0),"初始整理不计有效冒险时间")
	run.update({"alpha":{"action":"depart"}},0)
	run.update({},1.25)
	check(is_equal_approx(run.snapshot().get("activeSeconds",-1),1.25),"有效冒险公开累计输入时间")
	run.active.set_paused(true); run.update({},8); run.active.set_paused(false)
	check(is_equal_approx(run.snapshot().get("activeSeconds",-1),1.25),"暂停不增加有效冒险时间")
	run.update({"alpha":{"action":"camp"}},0)
	run.update({},6)
	check(is_equal_approx(run.snapshot().get("activeSeconds",-1),1.25),"再次整理停有效时间")
	check(run.snapshot().get("actualSeconds",-1)>=0,"公开实际总耗时采样")
	run.update({"restart":true},0)
	check(is_equal_approx(run.snapshot().get("activeSeconds",-1),1.25),"整理中R不能清空计时")
	run.update({"alpha":{"action":"depart"}},0)
	run.update({"restart":true},0)
	check(is_equal_approx(run.snapshot().get("activeSeconds",-1),0),"合法重试新局清空有效时间")

func defeat_boss(run: RefCounted) -> void:
	for frame in 12000:
		var state: Dictionary = run.snapshot()
		if state.roomComplete or state.status=="failed": return
		var offset: Vector2 = TrainingRoom.point(state.player)-TrainingRoom.point(state.boss)
		var movement: Vector2 = (Vector2(-offset.y,offset.x).normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		run.update({"moveX":movement.x,"moveY":movement.y,"fire":true,"aim":Vector2(state.boss.x,state.boss.y-52)},0.01)
	check(false,"真实Boss战必须在有限时间内结束")

func completion_checks() -> void:
	var ids: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end"]
	var maps: Dictionary = {}
	for id in ids:
		maps[id]=combat_fixture(id,1,[0]) if id in ["court1","dry_creek","root_fork","court2","ash_cloister","gate_forecourt","court3"] else fixture(id,"boss" if id=="boss" else "explore" if id=="stele" else "safe")
		if id=="stele": maps[id].exploration=[{"id":"stele","x":400,"y":700}]
	for index in range(ids.size()-1): connect_rooms(maps,ids[index],ids[index+1])
	# 合法自定义门加入旁通，用真实输入证明仅第三庭/Boss/出口不足以正式完成。
	connect_rooms(maps,"court1","root_fork")
	var run: RefCounted = Journey.new(maps,{"isTest":false,"dropSeed":13,"potionDrops":true})
	run.update({"alpha":{"action":"depart"}},0)
	for id in ["court1","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss"]:
		var entered: bool = pass_to(run,id)
		check(entered,"完整规则链真实过门："+id)
		if not entered: return
		if run.snapshot().objective=="combat": fight_until_wave(run,1)
		if id=="stele":
			check(walk(run,Vector2(400,700)),"真实走近残碑互动点")
			run.update({"interact":false},0); run.update({"interact":true},0)
			var before: float = run.snapshot().activeSeconds
			run.update({},5)
			check(run.snapshot().reading and not run.snapshot().roomComplete and is_equal_approx(run.snapshot().activeSeconds,before),"主线读碑期间停时且不提前开门")
			run.update({"restart":true},0)
			check(run.snapshot().reading and run.snapshot().visitedRooms>1,"阅读中R无效")
			run.update({"interact":false},0); run.update({"interact":true},0)
			check(run.snapshot().roomComplete,"真实合上残碑才完成探索目标")
	var issued: int = rewards(run).size()
	defeat_boss(run)
	check(run.snapshot().roomComplete and run.snapshot().boss.health==0,"真实射箭击败Boss完成必要目标")
	check(rewards(run).size()==issued,"Boss和真实援军击杀不增发普通构筑符")
	var stopped: float = run.snapshot().activeSeconds
	run.update({"dodge":true},0.1)
	var cooldown: float = run.snapshot().cooldowns.dodge
	run.update({},0.5)
	check(is_equal_approx(run.snapshot().activeSeconds,stopped) and run.snapshot().cooldowns.dodge<cooldown,"Boss倒下只停冒险累计，闪避冷却仍推进")
	check(pass_to(run,"end") and not run.snapshot().journeyComplete,"第三庭Boss出口都完成仍因遗漏前序主线而不正式通关")
	check(not run.snapshot().segmentComplete,"正式征程不显示测试段完成")
	for id in ["boss","thunder_approach","court3","gate_forecourt","ash_cloister","altar","court2","stele","root_fork","dry_creek"]:
		check(pass_to(run,id),"主线回溯不刷新："+id)
	fight_until_wave(run,1)
	check(run.snapshot().journeyComplete and rewards(run).size()==7,"所有13个主线目标完成且已到出口才正式完成，主线累计7枚")
	check(is_equal_approx(run.snapshot().activeSeconds,stopped),"Boss后跨房和补走路线不重新启动冒险累计")
	var trial: RefCounted = Journey.new(maps,{"isTest":true,"startRoom":"end"})
	check(trial.snapshot().segmentComplete and not trial.snapshot().journeyComplete and trial.snapshot().visitedRooms==1,"出口测试不伪造前序或正式通关")

func choice_door_blessing_checks() -> void:
	var maps: Dictionary = Journey.read_maps()
	var custom: Dictionary = {}
	for id in ["entry","court1","moss_side","dry_creek","root_fork","stele","stele_side","court2","altar","ash_cloister","ember_side","gate_forecourt","court3","thunder_approach"]:
		var room_check: RefCounted = Journey.new(maps,{"isTest":true,"startRoom":id})
		var choices: Array = room_check.snapshot().get("roomChoices",[])
		check(choices.size()==2,id+"关卡通关后提供两个前进选择门")
		if choices.size()==2:
			check(choices[0].target!=choices[1].target,id+"两个选择门分别通向两个不同房间")
			check(choices[0].get("blessingBeast","") in ["青龙","白虎","朱雀"] and choices[1].get("blessingBeast","") in ["青龙","白虎","朱雀"],id+"每个选择门绑定神兽祝福")
			for choice in choices:
				check_portal_visual_theme(choice,id)
				var p: Vector2 = TrainingRoom.point(choice.point)
				check(room_check.active.can_walk(p) and not room_check.active.find_route(TrainingRoom.point(room_check.snapshot().player),p).is_empty(),id+"选择门可达："+str(choice.target))
	for id in maps:
		custom[id]=combat_fixture(id,1,[0]) if maps[id].objective=="combat" else fixture(id,maps[id].objective)
		custom[id].roomTitle=maps[id].roomTitle
		if maps[id].has("choiceDoors"): custom[id].choiceDoors=maps[id].choiceDoors.duplicate(true)
		if maps[id].objective=="explore": custom[id].exploration=[{"id":"stele","x":480,"y":520}]
	var run: RefCounted = Journey.new(custom,{"isTest":true,"startRoom":"entry","health":10000,"mana":100,"stamina":100})
	run.update({"alpha":{"action":"depart"}},0)
	# 路径A：从入口选第二扇门（白虎初念 -> dry_creek），随后一路选择任意门直至Boss
	check(pass_to(run,"dry_creek"),"入口第二扇选择门真实进入落叶溪床")
	check(run.snapshot().alpha.blessingBeast=="白虎" and run.snapshot().alpha.blessingTier==1 and run.snapshot().alpha.skills.has("tiger"),"穿过白虎选择门获得白虎初念祝福并切换C技能")
	fight_until_wave(run,1)
	check(pass_to(run,"stele"),"落叶溪床第二扇选择门进入碑林遗径")
	check(run.snapshot().alpha.blessingBeast=="白虎" and run.snapshot().alpha.blessingTier==2,"同神兽选择门将白虎祝福升至再念")
	check(walk(run,TrainingRoom.point(run.active.layout.exploration[0])),"走近碑林残碑")
	run.update({"interact":false},0); run.update({"interact":true},0)
	run.update({"interact":false},0); run.update({"interact":true},0)
	check(pass_to(run,"stele_side"),"碑林第一扇选择门进入残碑幽径")
	check(run.snapshot().alpha.blessingBeast=="白虎" and run.snapshot().alpha.blessingTier==3,"白虎祝福通过选择门升至三念")
	# 无论每房选哪扇门，从任意房间按左门或右门推进都必定抵达Boss
	for branch_index in [0,1]:
		var cursor: String = "entry"
		var steps: int = 0
		var reached_boss: bool = false
		while steps<20:
			var options: Array = maps[cursor].choiceDoors
			var chosen: Dictionary = options[mini(branch_index,options.size()-1)]
			cursor=chosen.target
			steps+=1
			if cursor=="boss":
				reached_boss=true; break
		check(reached_boss,"全选第%d扇门最终汇入索尔Boss房" % (branch_index+1))

func check_portal_visual_theme(choice: Dictionary,room_id: String) -> void:
	var portal: Node2D = preload("res://scenes/world/room_portal.tscn").instantiate()
	portal.blessing_beast=str(choice.get("blessingBeast",""))
	portal.blessing_tier=int(choice.get("blessingTier",0))
	check(portal.visual_theme_matches(portal.blessing_beast,portal.blessing_tier),room_id+"选择门兽种／念级同步到两层视觉主题："+str(choice.target))
	var key: Dictionary = portal.visual_theme_key()
	check(key.get("beast","")==portal.blessing_beast and key.get("tier",0)==portal.blessing_tier and key.get("layer","")=="beast",room_id+"兽种纹样层读取祝福数据："+str(choice.target))
	var overlay_key: Dictionary = portal.get_node("TierOverlay").theme_key()
	check(overlay_key.get("beast","")==portal.blessing_beast and overlay_key.get("tier",0)==portal.blessing_tier and overlay_key.get("layer","")=="tier",room_id+"念级叠加层读取祝福数据："+str(choice.target))
	portal.free()

func pass_to(run: RefCounted,target: String) -> bool:
	for door in run.active.layout.doors:
		if door.target!=target: continue
		if not walk(run,TrainingRoom.point(door.point)): return false
		run.update({"interact":false},0); run.update({"interact":true},0)
		return run.snapshot().roomId==target
	return false

func walk(run: RefCounted,destination: Vector2) -> bool:
	var path: Array = run.active.find_route(TrainingRoom.point(run.snapshot().player),destination)
	for waypoint in path:
		for frame in 1000:
			var delta: Vector2 = waypoint-TrainingRoom.point(run.snapshot().player)
			if delta.length()<4: break
			var movement: Vector2 = delta.normalized()
			run.update({"moveX":movement.x,"moveY":movement.y},0.01)
	return destination.distance_to(TrainingRoom.point(run.snapshot().player))<8

func _initialize() -> void:
	check(Options.parse([]).get("isTest")==false,"默认完整征程具有明确正式身份")
	check(Options.parse(["--test=level"]).get("isTest")==false,"level未指定房间仍为正式征程")
	for args in [["--room=entry"],["--test=level","--room=entry"],["--test=boss"],["--test=drops"]]:
		check(Options.parse(args).get("isTest")==true,"显式房间或专项具有测试身份："+str(args))
	var maps: Dictionary = {"entry":fixture("entry"),"end":fixture("end")}
	connect_rooms(maps,"entry","end")
	var run: RefCounted = Journey.new(maps,{"isTest":true,"startRoom":"entry"})
	run.update({"alpha":{"action":"depart"}},0)
	check(run.snapshot().get("isTest")==true,"入口快速测试保留测试身份")
	check(pass_to(run,"end"),"入口测试可使用真实F推进到出口")
	check(run.snapshot().get("segmentComplete")==true and not run.snapshot().journeyComplete,"测试到出口只完成测试段")
	reward_checks()
	settlement_timing_checks()
	budget_checks()
	route_checks()
	time_checks()
	completion_checks()
	choice_door_blessing_checks()
	finish()

func finish() -> void:
	print(JSON.stringify({"expanded_journey_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
