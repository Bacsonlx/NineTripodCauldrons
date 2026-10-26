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
	print(JSON.stringify({"portal_presentation_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
