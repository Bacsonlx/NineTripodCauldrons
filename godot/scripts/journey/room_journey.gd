extends RefCounted

const Stage = preload("res://scripts/journey/journey_room.gd")
const Boss = preload("res://scripts/combat/boss_room.gd")
const BEAST_TIER_NAMES: Dictionary = {
	"青龙":["初念","再念","三念"],
	"白虎":["初念","再念","三念"],
	"朱雀":["初念","再念","三念"]
}
const MAIN_ROOM_IDS: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end"]
const ROOM_IDS: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end","moss_side","stele_side","ember_side"]
const CHOICE_ROUTES: Dictionary = {
	"entry":[{"target":"court1","blessingBeast":"青龙","blessingTier":1},{"target":"dry_creek","blessingBeast":"白虎","blessingTier":1}],
	"court1":[{"target":"dry_creek","blessingBeast":"朱雀","blessingTier":1},{"target":"moss_side","blessingBeast":"青龙","blessingTier":2}],
	"moss_side":[{"target":"dry_creek","blessingBeast":"白虎","blessingTier":2},{"target":"root_fork","blessingBeast":"朱雀","blessingTier":2}],
	"dry_creek":[{"target":"root_fork","blessingBeast":"青龙","blessingTier":2},{"target":"stele","blessingBeast":"白虎","blessingTier":2}],
	"root_fork":[{"target":"stele","blessingBeast":"朱雀","blessingTier":3},{"target":"stele_side","blessingBeast":"青龙","blessingTier":3}],
	"stele":[{"target":"stele_side","blessingBeast":"白虎","blessingTier":3},{"target":"court2","blessingBeast":"朱雀","blessingTier":3}],
	"stele_side":[{"target":"court2","blessingBeast":"青龙","blessingTier":2},{"target":"altar","blessingBeast":"白虎","blessingTier":2}],
	"court2":[{"target":"altar","blessingBeast":"朱雀","blessingTier":3},{"target":"ash_cloister","blessingBeast":"青龙","blessingTier":3}],
	"altar":[{"target":"ash_cloister","blessingBeast":"白虎","blessingTier":3},{"target":"ember_side","blessingBeast":"朱雀","blessingTier":3}],
	"ash_cloister":[{"target":"gate_forecourt","blessingBeast":"青龙","blessingTier":3},{"target":"court3","blessingBeast":"白虎","blessingTier":3}],
	"ember_side":[{"target":"gate_forecourt","blessingBeast":"朱雀","blessingTier":3},{"target":"court3","blessingBeast":"青龙","blessingTier":3}],
	"gate_forecourt":[{"target":"court3","blessingBeast":"白虎","blessingTier":3},{"target":"thunder_approach","blessingBeast":"朱雀","blessingTier":3}],
	"court3":[{"target":"thunder_approach","blessingBeast":"青龙","blessingTier":3},{"target":"boss","blessingBeast":"白虎","blessingTier":3}],
	"thunder_approach":[{"target":"boss","blessingBeast":"朱雀","blessingTier":3},{"target":"end","blessingBeast":"青龙","blessingTier":3}],
	"boss":[{"target":"end","blessingBeast":"青龙","blessingTier":3}],
	"end":[{"target":"boss","blessingBeast":"朱雀","blessingTier":3}]
}
var layouts: Dictionary
var rooms: Dictionary = {}
var current_id: String = "entry"
var generation: int = 0
var active: TrainingRoom
var initial_options: Dictionary = {}
var drop_seed: int = 0
var inventory: RefCounted
var started_msec: int = 0
var departure_inventory_snapshot: Array = []

static func direction_label(target: String,source: String) -> String:
	if target in ["moss_side","stele_side","ember_side"]: return "可选支路"
	if source in ["moss_side","stele_side","ember_side"] and target in MAIN_ROOM_IDS: return "汇入主路"
	if source in MAIN_ROOM_IDS and target in MAIN_ROOM_IDS: return "前行" if MAIN_ROOM_IDS.find(target)>MAIN_ROOM_IDS.find(source) else "返回"
	return "前往"

static func read_maps() -> Dictionary:
	var result: Dictionary = {}
	if Engine.get_main_loop()!=null and Engine.get_main_loop().has_meta("cached_tanggu_maps"):
		return Engine.get_main_loop().get_meta("cached_tanggu_maps").duplicate(true)
	for id in ROOM_IDS:
		var map: Node2D = load("res://scenes/rooms/%s.tscn" % id).instantiate()
		var errors: Array[String] = map.validation_errors()
		if not errors.is_empty():
			push_error(id+": "+str(errors)); map.free(); return {}
		result[id]=map.build_layout(); map.free()
		if result[id].roomId!=id: push_error("房间标识与场景名称不一致："+id); return {}
	for id in result:
		for door in result[id].doors:
			if not result.has(door.target): push_error("门目标房间不存在："+id); return {}
			var reciprocal: bool = false
			for back in result[door.target].doors:
				if back.id==door.targetDoor and back.target==id and back.targetDoor==door.id: reciprocal=true
			if not reciprocal: push_error("门缺少双向连接："+id+"/"+door.id); return {}
	var reachable: Array[String] = ["entry"]
	var index: int = 0
	while index<reachable.size():
		for door in result[reachable[index]].doors:
			if not reachable.has(door.target): reachable.append(door.target)
		index+=1
	if reachable.size()!=result.size(): push_error("有房间无法从入口到达"); return {}
	for id in CHOICE_ROUTES:
		if not result.has(id): push_error("选择门来源房间不存在："+id); return {}
		result[id].choiceDoors=[]
		for route_index in CHOICE_ROUTES[id].size():
			var route: Dictionary = CHOICE_ROUTES[id][route_index].duplicate(true)
			if not result.has(route.target): push_error("选择门目标房间不存在："+id+"/"+route.target); return {}
			route.id=route.target
			route.choice=true
			route.title=result[route.target].roomTitle
			result[id].choiceDoors.append(route)
	if Engine.get_main_loop()!=null:
		Engine.get_main_loop().set_meta("cached_tanggu_maps",result.duplicate(true))
	return result

func _init(definitions: Dictionary,options: Dictionary = {}) -> void:
	layouts=definitions
	initial_options=options.duplicate()
	initial_options.isTest=options.get("isTest",options.get("startRoom","entry")!="entry" or options.get("mode","") in ["boss","drops"])
	if initial_options.has("initial_backpack"):
		departure_inventory_snapshot=initial_options.initial_backpack.duplicate(true)
	restart()

func restart() -> void:
	started_msec=Time.get_ticks_msec()
	rooms.clear(); current_id=initial_options.get("startRoom","entry"); generation+=1
	drop_seed=int(initial_options.get("dropSeed",randi()))
	inventory=TrainingRoom.AlphaState.new(drop_seed,true,departure_inventory_snapshot)
	inventory.reset(TrainingRoom.point(layouts[current_id].spawn))
	inventory.camp=false; inventory.departed=true
	if departure_inventory_snapshot.is_empty():
		departure_inventory_snapshot=inventory.items.duplicate(true)
	active=create_room(layouts[current_id]); rooms[current_id]=active
	active.run_id=generation
	active.health=int(initial_options.get("health",100))
	active.mana=int(initial_options.get("mana",100))
	active.stamina=float(initial_options.get("stamina",100))

func update(input: Dictionary,seconds: float) -> void:
	if input.get("restart",false) and not active.ui_paused():
		restart(); return
	active.update(input,seconds)
	consume_transition()

func consume_transition() -> bool:
	if rooms.has("boss") and rooms.boss.completed: inventory.adventure_complete=true
	var request: String = active.requested_door
	active.requested_door=""
	if request.is_empty() or not active.completed or active.paused or active.reading or active.health<=0: return false
	for door in active.layout.doors:
		if door.id!=request: continue
		active.cancel_input(); active.wind_path.clear(); active.paper_arrows.clear(); active.arrows.clear(); active.rains.clear(); active.effects.clear()
		var travel: Dictionary = active.travel_state()
		var source_id: String = current_id
		current_id=door.target
		if door.get("choice",false):
			inventory.apply_door_blessing(str(door.get("blessingBeast","青龙")),int(door.get("blessingTier",1)))
		if not rooms.has(current_id):
			active=create_room(layouts[current_id],source_id,request)
			rooms[current_id]=active
		else:
			active=rooms[current_id]
			ensure_return_door(active,source_id,request)
		for arrival in active.layout.doors:
			if arrival.id!=door.targetDoor and arrival.target!=source_id: continue
			generation+=1
			active.arrive(travel,TrainingRoom.point(arrival.arrival),int(arrival.get("facing",0)),generation)
			return true
	return false

func snapshot(base: Dictionary = {}) -> Dictionary:
	# 呈现层已持有本帧公开快照时直接复用，避免第二次深拷贝全部敌人／弹道。
	# roomGraph 每次新建，保证外部修改图快照不影响真实房间状态。
	if rooms.has("boss") and rooms.boss.completed: inventory.adventure_complete=true
	var data: Dictionary = active.snapshot() if base.is_empty() else base.duplicate()
	data.activeSeconds=inventory.elapsed
	data.actualSeconds=(Time.get_ticks_msec()-started_msec)/1000.0
	data.visitedRooms=rooms.size()
	data.isTest=initial_options.isTest
	data.segmentComplete=data.isTest and rooms.has("end")
	var completed_rooms: int = rooms.values().filter(func(room: TrainingRoom): return room.completed).size()
	var required_rooms: int = 8 if layouts.get("entry",{}).has("choiceDoors") else MAIN_ROOM_IDS.size()
	var all_main_complete: bool = MAIN_ROOM_IDS.all(func(id: String): return rooms.has(id) and rooms[id].completed)
	data.journeyComplete=not data.isTest and initial_options.get("startRoom","entry")=="entry" and rooms.has("boss") and rooms.boss.completed and rooms.has("end") and rooms.end.completed and (all_main_complete or (layouts.get("entry",{}).has("choiceDoors") and completed_rooms>=required_rooms))
	var nodes: Array = []
	var connections: Array = []
	for id in layouts:
		var visited: bool = rooms.has(id)
		var complete: bool = visited and rooms[id].completed
		nodes.append({"id":id,"title":layouts[id].roomTitle,"objective":layouts[id].objective,"visited":visited,"complete":complete,"current":id==current_id,"locked":layouts[id].objective!="safe" and not complete})
		for door in layouts[id].doors:
			if str(id)<str(door.target): connections.append({"from":id,"to":door.target})
	data.roomGraph={"rooms":nodes,"connections":connections}
	data.roomChoices=active.layout.doors.filter(func(door: Dictionary): return door.get("choice",false)).duplicate(true)
	if initial_options.get("potionDrops",false): data.dropSeed=drop_seed
	return data

func create_room(data: Dictionary,return_from: String = "",entered_door: String = "") -> TrainingRoom:
	data=data.duplicate(true)
	data.gameplay=true
	if data.has("choiceDoors"):
		data.doors=compose_choice_doors(data,return_from,entered_door)
	for door in data.doors:
		if door.get("choice",false):
			door.routeLabel="选择门"
			door.choiceLabel="%s · %s" % [door.blessingBeast,BEAST_TIER_NAMES[door.blessingBeast][int(door.blessingTier)-1]]
		else:
			door.routeLabel=direction_label(door.target,data.roomId)
	data.commercialDepthRewards=not initial_options.isTest and data.has("constructionRewardWaves")
	if initial_options.get("potionDrops",false):
		data.potionDrops=true
		data.dropSeed=drop_seed+str(data.roomId).hash()
	var room: TrainingRoom = Boss.new(data) if data.objective=="boss" else Stage.new(data)
	room.alpha=inventory
	return room

static func place_extra_door(data: Dictionary,base: Dictionary,used_points: Array,order: int) -> Dictionary:
	var door: Dictionary = base.duplicate(true)
	door.halfWidth=0; door.halfHeight=0; door.blocksProjectiles=false
	var base_point: Vector2 = TrainingRoom.point(base.point)
	var base_arrival: Vector2 = TrainingRoom.point(base.arrival)
	var delta_arrival: Vector2 = base_arrival-base_point
	var delta_center: Vector2 = Vector2(float(base.x),float(base.y))-base_point
	var candidate_point: Vector2 = base_point
	var candidate_arrival: Vector2 = base_arrival
	for offset in [Vector2(0,72*order),Vector2(0,-72*order),Vector2(-72*order,0),Vector2(72*order,0)]:
		var trial: Vector2 = base_point+offset
		if used_points.any(func(p: Vector2): return p.distance_to(trial)<48.0): continue
		if data.has("walkablePolygons"):
			var inside: bool = false
			for poly in data.walkablePolygons:
				if Geometry2D.is_point_in_polygon(trial,poly):
					inside=true; break
			if not inside: continue
		candidate_point=trial
		candidate_arrival=trial
		break
	door.point=candidate_point
	door.arrival=candidate_arrival
	door.x=candidate_point.x+delta_center.x
	door.y=candidate_point.y+delta_center.y
	return door

static func compose_choice_doors(data: Dictionary,return_from: String,entered_door: String) -> Array:
	var result: Array = data.get("doors",[]).duplicate(true)
	var used_points: Array = result.map(func(d: Dictionary): return TrainingRoom.point(d.point))
	for index in data.choiceDoors.size():
		var choice: Dictionary = data.choiceDoors[index].duplicate(true)
		var matched: bool = false
		for existing in result:
			if existing.target==choice.target:
				existing.choice=true
				existing.blessingBeast=choice.blessingBeast
				existing.blessingTier=choice.blessingTier
				matched=true
				break
		if not matched:
			var fallback: Dictionary = result.back() if not result.is_empty() else {"point":Vector2(400,520),"arrival":Vector2(440,520),"x":400,"y":495,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"}
			var door: Dictionary = place_extra_door(data,fallback,used_points,index+1)
			used_points.append(TrainingRoom.point(door.point))
			door.id=choice.id
			door.target=choice.target
			door.targetDoor=data.roomId
			door.title=choice.title
			door.choice=true
			door.blessingBeast=choice.blessingBeast
			door.blessingTier=choice.blessingTier
			result.append(door)
	if not return_from.is_empty() and not result.any(func(d: Dictionary): return d.target==return_from):
		var fallback: Dictionary = result[0] if not result.is_empty() else {"point":Vector2(240,520),"arrival":Vector2(280,520),"x":240,"y":495,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"}
		var return_door: Dictionary = place_extra_door(data,fallback,used_points,1)
		return_door.id=return_from
		return_door.target=return_from
		return_door.targetDoor=entered_door if not entered_door.is_empty() else data.roomId
		return_door.title=data.get("roomTitle","")
		return_door.routeLabel="返回"
		result.append(return_door)
	return result

func ensure_return_door(room: TrainingRoom,source_id: String,entered_door: String) -> void:
	for existing in room.layout.doors:
		if existing.target==source_id:
			return
	var templates: Array = room.layout.doors
	var used_points: Array = templates.map(func(d: Dictionary): return TrainingRoom.point(d.point))
	var fallback: Dictionary = templates[0] if not templates.is_empty() else {"point":Vector2(240,520),"arrival":Vector2(280,520),"x":240,"y":495,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"}
	var return_door: Dictionary = place_extra_door(room.layout,fallback,used_points,1)
	return_door.id=source_id
	return_door.target=source_id
	return_door.targetDoor=entered_door if not entered_door.is_empty() else room.layout.roomId
	return_door.routeLabel="返回"
