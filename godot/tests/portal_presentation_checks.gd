extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for id in preload("res://scripts/journey/room_journey.gd").ROOM_IDS:
		var map: Node2D = load("res://scenes/rooms/%s.tscn" % id).instantiate()
		root.add_child(map)
		var data: Dictionary = map.build_layout()
		var model: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(data)
		var state: Dictionary = model.snapshot()
		for portal in map.get_node("Doors").get_children():
			check(portal.has_node("Passage"),id+"/"+str(portal.name)+"具有共用贴地通行标识")
			if not portal.has_node("Passage"): continue
			var definition: Dictionary = portal.definition()
			state.roomComplete=false; portal.update_state(state,0)
			check(not portal.get_node("Passage").visible and portal.get_node("Seal").visible,"任务未完成时漩涡熄灭且门锁可见")
			state.roomComplete=true; portal.update_state(state,2)
			var passage: Node2D = portal.get_node("Passage")
			check(passage.visible and not portal.get_node("Seal").visible and portal.get_node("Destination").text.contains("可通行"),"正式开门后出现通行标识与文字")
			check(not passage.z_as_relative and passage.z_index<0,"漩涡位于地面层而非覆盖人物")
			check(passage.position==portal.get_node("Approach").position,"漩涡对齐实际F操作位置")
			var before: Transform2D = portal.get_node("Passage/Swirl").transform
			portal.update_state(state,3)
			check(before!=portal.get_node("Passage/Swirl").transform,"开放漩涡随游戏时钟旋转")
			before=portal.get_node("Passage/Swirl").transform
			state.paused=true; portal.update_state(state,5)
			check(before==portal.get_node("Passage/Swirl").transform,"暂停时漩涡动画冻结")
			state.paused=false
			check(portal.definition()==definition,"门呈现状态变化不改规则连接或碰撞")
		check(map.build_layout()==data,"房间规则数据不受新门表现影响")
		map.free()
	var entry: Node2D = load("res://scenes/rooms/entry.tscn").instantiate()
	root.add_child(entry)
	var data: Dictionary = entry.build_layout()
	data.spawn={"x":1180,"y":450}
	var blocked: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(data)
	var portal: Node2D = entry.get_node("Doors/court1")
	portal.update_state(blocked.snapshot(),2)
	check(blocked.can_walk(Vector2(1180,450)) and blocked.snapshot().interaction==null and not portal.get_node("Destination").text.contains("F ·"),"隔着柱脚时不显示无效F提示")
	data.spawn=portal.definition().point
	var ready: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(data)
	portal.update_state(ready.snapshot(),2)
	check(ready.snapshot().interaction!=null and portal.get_node("Destination").text.contains("F ·"),"真正可互动时显示F提示")
	entry.free()
	choice_spacing_checks()
	print(JSON.stringify({"portal_presentation_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func choice_spacing_checks() -> void:
	var journey_script = preload("res://scripts/journey/room_journey.gd")
	var maps: Dictionary = journey_script.read_maps()
	for id in journey_script.ROOM_IDS:
		var journey: RefCounted = journey_script.new(maps,{"isTest":true,"startRoom":id})
		check_door_spacing(journey.active,id)
		for source in journey_script.CHOICE_ROUTES:
			if not journey_script.CHOICE_ROUTES[source].any(func(route: Dictionary): return route.target==id): continue
			var room: TrainingRoom = journey.create_room(maps[id],source,id)
			check_door_spacing(room,id+" 来自 "+source)
			journey.ensure_return_door(journey.active,source,id)
			check(journey.active.layout.doors.any(func(door: Dictionary): return door.target==source),id+"重访时保留来路门："+source)
		check_door_spacing(journey.active,id+" 多次重访")

func check_door_spacing(model: TrainingRoom,context: String) -> void:
	var map: Node2D = load("res://scenes/rooms/%s.tscn" % model.layout.roomId).instantiate()
	root.add_child(map)
	map.configure_doors(model.layout.doors)
	var state: Dictionary = model.snapshot()
	state.roomComplete=true
	var bounds: Array[Rect2] = []
	var points: Array[Vector2] = []
	for portal in map.get_node("Doors").get_children():
		state.interaction={"id":"door:"+portal.portal_id,"reason":null}
		portal.update_state(state,0)
		var sprite: Sprite2D = portal.get_node("Frame/Sprite")
		var label: Label = portal.get_node("Destination")
		var rect: Rect2 = sprite.global_transform*sprite.get_rect()
		rect=rect.merge(label.get_global_transform()*Rect2(Vector2.ZERO,label.get_minimum_size()))
		var definition: Dictionary = portal.definition()
		var point: Vector2 = TrainingRoom.point(definition.point)
		for index in bounds.size():
			check(not rect.grow(12).intersects(bounds[index]),context+"门框及完整提示保留12单位间隔："+portal.portal_id)
			check(point.distance_to(points[index])>160,context+"门的80单位互动范围互不重叠："+portal.portal_id)
		bounds.append(rect); points.append(point)
		check(model.can_walk(point) and model.can_walk(TrainingRoom.point(definition.arrival)),context+"门前和到达点可行走："+portal.portal_id)
		check(not model.find_route(TrainingRoom.point(model.layout.spawn),point).is_empty(),context+"门前可从出生点到达："+portal.portal_id)
	map.free()
