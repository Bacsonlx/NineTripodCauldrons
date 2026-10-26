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
	return run.snapshot().alpha.items.filter(func(item: Dictionary): return item.name in ["羊角","鼠毫"] and not str(item.get("roomId","")).is_empty())

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
	fight_until_wave(run,2)
	check(rewards(run).size()==2 and rewards(run)[1].name=="鼠毫","主线仅首波发符，按实际第二次发放鼠毫")
	check(rewards(run)[0].id==original.id and rewards(run)[0].roomId=="moss_side","跨房共享背包且地面奖励仍属原房")
	check(pass_to(run,"moss_side") and rewards(run).size()==2 and run.snapshot().roomComplete,"回溯不刷新敌人与构筑奖励")
	run.update({"restart":true},0)
	check(run.snapshot().roomId=="moss_side" and rewards(run).is_empty() and run.snapshot().visitedRooms==1,"快速测试R新建所选起点并清空发放记录")

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
	budget_checks()
	route_checks()
	time_checks()
	completion_checks()
	finish()

func finish() -> void:
	print(JSON.stringify({"expanded_journey_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
