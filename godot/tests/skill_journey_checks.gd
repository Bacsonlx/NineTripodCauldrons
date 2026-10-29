extends SceneTree
const Journey = preload("res://scripts/journey/room_journey.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var run = Journey.new(Journey.read_maps())
	var state: Dictionary = run.snapshot().alpha
	check(state.get("skills",{}).size()==5 and state.skills.rain.active and state.skills.charge.active,"默认首关从装备和羁绊自动获得五项技能")
	check(state.items.all(func(item: Dictionary): return item.kind!="技能书"),"默认首关不生成技能书")
	var room: TrainingRoom = TrainingRoom.new({"mode":"gameplay"})
	room.energy_enabled=true
	var bow: int = -1; var boots: int = -1; var horn: int = -1; var mouse: int = -1
	for item in room.snapshot().alpha.items:
		if item.name=="训练弓": bow=item.id
		if item.name=="布履": boots=item.id
		if item.name=="羊角": horn=item.id
		if item.name=="鼠毫": mouse=item.id
	for action in [{"action":"embed","equipmentId":bow,"glyphId":horn},{"action":"embed","equipmentId":boots,"glyphId":mouse},{"action":"depart"}]: room.update({"alpha":action},0)
	room.update({"backwind":true,"aim":Vector2(900,548)},0.2)
	check(absf(room.snapshot().player.x-280)<0.01,"无移动回风背向瞄准冲120")
	check(room.snapshot().resources.mana==88 and room.snapshot().dodgeInvulnerability==0,"回风支付12蓝，不提供闪避无敌")
	load("res://tests/special_skills_checks.gd").new().run(check)
	load("res://tests/wind_skill_checks.gd").new().run(check)
	load("res://tests/skill_resource_checks.gd").new().run(check)
	load("res://tests/skill_boss_checks.gd").new().run(check)
	print(JSON.stringify({"skill_journey_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
