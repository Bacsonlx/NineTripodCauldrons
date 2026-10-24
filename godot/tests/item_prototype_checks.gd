extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var room: TrainingRoom = TrainingRoom.new({"mode":"gameplay"})
	room.update({"alpha":{"action":"prototype_kit"}},0)
	var items: Array = room.snapshot().alpha.items
	check(items.filter(func(item: Dictionary): return item.get("prototype",false)).size()==12,"入口一次领取全部十二件唯一道具原型")
	if items.any(func(item: Dictionary): return item.get("prototype",false)):
		var horse: int = -1
		for item in items:
			if item.name=="快马" and item.get("prototype",false): horse=item.id
		for action in [{"action":"embed","equipmentId":items.filter(func(item: Dictionary): return item.name=="布履")[0].id,"glyphId":items.filter(func(item: Dictionary): return item.name=="鼠毫")[0].id},{"action":"embed","equipmentId":items[0].id,"glyphId":items.filter(func(item: Dictionary): return item.name=="羊角")[0].id},{"action":"pickup","id":horse},{"action":"quick_bind","id":horse},{"action":"depart"}]: room.update({"alpha":action},0)
		room.update({"alpha":{"action":"use_quick"}},0)
		var start: float = room.snapshot().player.x
		room.update({"moveX":-1},0.25)
		check(is_equal_approx(start-room.snapshot().player.x,77),"快马实物使用后移动速度提高40%")
		check(not room.snapshot().alpha.items.any(func(item: Dictionary): return item.id==horse),"快马成功只消费绑定唯一实物")
	load("res://tests/item_use_checks.gd").new().run(check)
	load("res://tests/item_pact_checks.gd").new().run(check)
	load("res://tests/item_glyph_checks.gd").new().run(check)
	load("res://tests/item_boundary_checks.gd").new().run(check)
	print(JSON.stringify({"item_prototype_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
