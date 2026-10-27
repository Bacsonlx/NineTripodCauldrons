extends RefCounted

const Stage = preload("res://scripts/journey/journey_room.gd")
const Boss = preload("res://scripts/combat/boss_room.gd")
const MAIN_ROOM_IDS: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end"]
const ROOM_IDS: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end","moss_side","stele_side","ember_side"]
var layouts: Dictionary
var rooms: Dictionary = {}
var current_id: String = "entry"
var generation: int = 0
var active: TrainingRoom
var initial_options: Dictionary = {}
var drop_seed: int = 0
var inventory: RefCounted
var started_msec: int = 0

static func direction_label(target: String,source: String) -> String:
	if target in ["moss_side","stele_side","ember_side"]: return "可选支路"
	if source in ["moss_side","stele_side","ember_side"] and target in MAIN_ROOM_IDS: return "汇入主路"
	if source in MAIN_ROOM_IDS and target in MAIN_ROOM_IDS: return "前行" if MAIN_ROOM_IDS.find(target)>MAIN_ROOM_IDS.find(source) else "返回"
	return "前往"

static func read_maps() -> Dictionary:
	var result: Dictionary = {}
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
	return result

func _init(definitions: Dictionary,options: Dictionary = {}) -> void:
	layouts=definitions
	initial_options=options.duplicate()
	initial_options.isTest=options.get("isTest",options.get("startRoom","entry")!="entry" or options.get("mode","") in ["boss","drops"])
	restart()

func restart() -> void:
	started_msec=Time.get_ticks_msec()
	rooms.clear(); current_id=initial_options.get("startRoom","entry"); generation+=1
	drop_seed=int(initial_options.get("dropSeed",randi()))
	inventory=TrainingRoom.AlphaState.new(drop_seed,true)
	inventory.reset(TrainingRoom.point(layouts[current_id].spawn),current_id)
	if current_id!="entry": inventory.camp=false; inventory.departed=true
	active=create_room(layouts[current_id]); rooms[current_id]=active
	for item in inventory.items:
		if item.get("teaching",false) and not active.can_walk(item.world): item.world=active.potion_location(item.world)
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
	for door in layouts[current_id].doors:
		if door.id!=request: continue
		active.cancel_input(); active.wind_path.clear(); active.paper_arrows.clear(); active.arrows.clear(); active.rains.clear(); active.effects.clear()
		var travel: Dictionary = active.travel_state()
		current_id=door.target
		if not rooms.has(current_id): rooms[current_id]=create_room(layouts[current_id])
		active=rooms[current_id]
		for arrival in layouts[current_id].doors:
			if arrival.id!=door.targetDoor: continue
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
	data.journeyComplete=not data.isTest and initial_options.get("startRoom","entry")=="entry" and MAIN_ROOM_IDS.all(func(id: String): return rooms.has(id) and rooms[id].completed)
	var nodes: Array = []
	var connections: Array = []
	for id in layouts:
		var visited: bool = rooms.has(id)
		var complete: bool = visited and rooms[id].completed
		nodes.append({"id":id,"title":layouts[id].roomTitle,"objective":layouts[id].objective,"visited":visited,"complete":complete,"current":id==current_id,"locked":layouts[id].objective!="safe" and not complete})
		for door in layouts[id].doors:
			if str(id)<str(door.target): connections.append({"from":id,"to":door.target})
	data.roomGraph={"rooms":nodes,"connections":connections}
	if initial_options.get("potionDrops",false): data.dropSeed=drop_seed
	return data

func create_room(data: Dictionary) -> TrainingRoom:
	data=data.duplicate(true)
	data.gameplay=true
	for door in data.doors: door.routeLabel=direction_label(door.target,data.roomId)
	if initial_options.get("potionDrops",false):
		data.potionDrops=true
		data.dropSeed=drop_seed+str(data.roomId).hash()
	var room: TrainingRoom = Boss.new(data) if data.objective=="boss" else Stage.new(data)
	room.alpha=inventory
	return room
