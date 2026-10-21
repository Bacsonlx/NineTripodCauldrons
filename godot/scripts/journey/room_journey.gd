extends RefCounted

const Stage = preload("res://scripts/journey/journey_room.gd")
const ROOM_IDS: Array[String] = ["entry","court1","stele","altar","court2","court3","end"]
var layouts: Dictionary
var rooms: Dictionary = {}
var current_id: String = "entry"
var generation: int = 0
var active: TrainingRoom

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

func _init(definitions: Dictionary) -> void:
	layouts=definitions
	restart()

func restart() -> void:
	rooms.clear(); current_id="entry"; generation+=1
	active=Stage.new(layouts[current_id]); rooms[current_id]=active
	active.run_id=generation

func update(input: Dictionary,seconds: float) -> void:
	if input.get("restart",false) and not active.snapshot().paused:
		restart(); return
	active.update(input,seconds)
	consume_transition()

func consume_transition() -> bool:
	var request: String = active.requested_door
	active.requested_door=""
	if request.is_empty() or not active.completed or active.paused or active.reading or active.health<=0: return false
	for door in layouts[current_id].doors:
		if door.id!=request: continue
		var travel: Dictionary = active.travel_state()
		active.cancel_input(); active.arrows.clear(); active.rains.clear(); active.effects.clear()
		current_id=door.target
		if not rooms.has(current_id): rooms[current_id]=Stage.new(layouts[current_id])
		active=rooms[current_id]
		for arrival in layouts[current_id].doors:
			if arrival.id!=door.targetDoor: continue
			generation+=1
			active.arrive(travel,TrainingRoom.point(arrival.arrival),int(arrival.get("facing",0)),generation)
			return true
	return false

func snapshot() -> Dictionary:
	var data: Dictionary = active.snapshot()
	data.visitedRooms=rooms.size()
	data.journeyComplete=rooms.has("court3") and rooms.court3.completed and rooms.has("end")
	return data
