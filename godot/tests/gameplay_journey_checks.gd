extends SceneTree
const Journey = preload("res://scripts/journey/room_journey.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var run = Journey.new(Journey.read_maps(),{"potionDrops":true,"dropSeed":13})
	var state: Dictionary = run.snapshot()
	check(state.has("alpha"),"默认八房首关直接持有局内背包")
	if state.has("alpha"):
		check(state.alpha.camp,"正常出发从入口营地构筑开始")
	var bow: int = item_id(run,"训练弓")
	var horn: int = item_id(run,"羊角")
	run.update({"alpha":{"action":"embed","equipmentId":bow,"glyphId":horn}},0)
	check(run.snapshot().alpha.equipment.healthMax==130 and run.snapshot().health==100,"嵌羊角预览130且不回血")
	run.update({"alpha":{"action":"depart"}},0)
	check(run.snapshot().healthMax==130 and run.snapshot().health==100,"出发应用上限而不补血")
	var room_data: Dictionary = Journey.read_maps().court1
	var fight = Journey.new({"court1":room_data},{"startRoom":"court1"})
	check(fight.snapshot().enemies.any(func(e: Dictionary): return e.get("role","")=="paper" and e.health==45),"当前第一庭纸面敌使用远程职责与45生命")
	check(fight.snapshot().enemies.any(func(e: Dictionary): return e.get("role","")=="wood" and e.health==150),"当前第一庭木甲敌使用精英职责与150生命")
	load("res://tests/equipment_checks.gd").new().run(check)
	load("res://tests/enemy_roles_checks.gd").new().run(check)
	load("res://tests/gameplay_pickup_checks.gd").new().run(check)
	load("res://tests/gameplay_travel_checks.gd").new().run(check)
	print(JSON.stringify({"gameplay_journey_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func item_id(run: RefCounted,title: String) -> int:
	for item in run.snapshot().alpha.items:
		if item.name==title: return item.id
	return -1
