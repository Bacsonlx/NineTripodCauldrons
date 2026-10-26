extends SceneTree

const Journey = preload("res://scripts/journey/room_journey.gd")
const MAIN: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end"]
const SIDES: Array[String] = ["moss_side","stele_side","ember_side"]
const COMPOSITIONS: Dictionary = {
	"court1":[[2,1,1],[1,2,2]], "dry_creek":[[3,1,1],[3,2,2]],
	"root_fork":[[2,1,1],[2,2,1],[2,2,2]], "court2":[[2,2,1],[2,2,2],[2,3,2]],
	"ash_cloister":[[2,3,1],[3,2,2],[2,3,2]],
	"gate_forecourt":[[1,2,1],[2,2,1],[2,2,2],[2,2,2]],
	"court3":[[2,2,1],[2,2,2],[2,2,2],[2,2,3]],
	"moss_side":[[2,1,1],[2,2,1]], "ember_side":[[3,2,1]],
}
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--journey"):
		var maps: Dictionary = Journey.read_maps()
		check(maps.size() == 16, "汤谷完整旅程读取16个真实房间")
		if maps.size() == 16: check_contract(maps)
	elif args.is_empty():
		var maps: Dictionary = {}
		for id in MAIN + SIDES:
			maps[id] = check_scene(id)
		if maps.values().all(func(data: Dictionary): return not data.is_empty()): check_contract(maps)
	else:
		for id in args:
			check_scene(id)
	print(JSON.stringify({"expanded_map_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check_scene(id: String) -> Dictionary:
	var path: String = "res://scenes/rooms/%s.tscn" % id
	check(ResourceLoader.exists(path), id + "真实房间存在")
	if not ResourceLoader.exists(path): return {}
	var packed: PackedScene = load(path)
	check(packed != null, id + "场景可解析")
	if packed == null: return {}
	var scene: Node2D = packed.instantiate()
	var errors: Array[String] = scene.validation_errors()
	check(errors.is_empty(), id + "布局合法：" + str(errors))
	var layout: Dictionary = scene.build_layout()
	var model: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(layout)
	var spawn: Vector2 = TrainingRoom.point(layout.spawn)
	for door in layout.doors:
		check(not model.find_route(spawn, TrainingRoom.point(door.arrival)).is_empty(), id + "出生可到达门内：" + door.id)
	for point in layout.exploration:
		check(model.can_walk(TrainingRoom.point(point)) and not model.find_route(spawn, TrainingRoom.point(point)).is_empty(), id + "互动可达：" + point.id)
	for camp in layout.camps:
		check(not model.find_route(spawn, camp).is_empty(), id + "整理点可达")
	for wave in layout.encounters:
		check(not model.find_route(spawn, TrainingRoom.point(wave)).is_empty(), id + "战斗口袋可达")
		for enemy in wave.enemies:
			check(not model.find_route(spawn, TrainingRoom.point(enemy)).is_empty(), id + "敌人出生可接近")
	if not layout.encounters.is_empty():
		var route: Array = model.find_route(spawn, TrainingRoom.point(layout.encounters[0]))
		for waypoint in route:
			for step in 100:
				if first_wave_active(model): break
				var delta: Vector2 = TrainingRoom.point(waypoint) - TrainingRoom.point(model.snapshot().player)
				if delta.length() < 5: break
				var direction: Vector2 = delta.normalized()
				model.update({"moveX":direction.x,"moveY":direction.y}, 0.02)
			if first_wave_active(model): break
		check(first_wave_active(model), id + "从默认出生通过移动输入进入170半径触发首波")
	scene.free()
	return layout

func first_wave_active(model: TrainingRoom) -> bool:
	for enemy in model.snapshot().enemies:
		if enemy.group == 0 and enemy.phase != "inactive": return true
	return false

func check_contract(maps: Dictionary) -> void:
	var edges: Array[String] = []
	for index in MAIN.size() - 1: edges.append(MAIN[index] + "/" + MAIN[index + 1])
	edges.append_array(["dry_creek/moss_side","moss_side/root_fork","stele/stele_side","stele_side/court2","ash_cloister/ember_side","ember_side/gate_forecourt"])
	var expected: Dictionary = {}
	for edge in edges:
		var ids: PackedStringArray = edge.split("/")
		if not expected.has(ids[0]): expected[ids[0]] = []
		if not expected.has(ids[1]): expected[ids[1]] = []
		expected[ids[0]].append(ids[1]); expected[ids[1]].append(ids[0])
	var doors: int = 0
	var main_enemies: int = 0
	var main_waves: int = 0
	var side_enemies: int = 0
	var side_waves: int = 0
	for id in maps:
		var layout: Dictionary = maps[id]
		var targets: Array = layout.doors.map(func(d: Dictionary): return d.target)
		var desired: Array = expected[id].duplicate()
		targets.sort(); desired.sort()
		check(targets == desired, id + "精确邻接符合主线与短环路合同")
		doors += layout.doors.size()
		for door in layout.doors:
			var reciprocal: bool = false
			if maps.has(door.target):
				for back in maps[door.target].doors:
					if back.id == door.targetDoor and back.target == id and back.targetDoor == door.id: reciprocal = true
			check(reciprocal, id + "/" + door.id + "门标识双向配对")
		check(layout.camps.size() == (1 if id in ["entry","altar","thunder_approach"] else 0), id + "仅三处允许整理")
		var rewards: Array = [1] if id == "moss_side" else [0] if id in COMPOSITIONS and id in MAIN else []
		check(layout.get("constructionRewardWaves",[]) == rewards, id + "公开构筑奖励资格符合7主线加A末波合同")
		if id == "stele_side":
			check(not layout.get("steleTitle","").is_empty() and "占位" in layout.get("steleText",""), "B独立短碑文明确标注待审核占位")
		if COMPOSITIONS.has(id):
			var actual: Array = []
			for wave in layout.encounters:
				var roles: Array[int] = [0,0,0]
				for enemy in wave.enemies:
					var role: int = ["bird","paper","wood"].find(enemy.get("role",enemy.appearance))
					if role >= 0: roles[role] += 1
				actual.append(roles)
				check(wave.enemies.size() <= 7, id + "普通单波不超过7只")
				if id in MAIN: main_enemies += wave.enemies.size(); main_waves += 1
				else: side_enemies += wave.enemies.size(); side_waves += 1
			check(actual == COMPOSITIONS[id], id + "逐波鸟面／纸面／木甲职责符合施工表")
	check(doors == 36, "16房18对双向连接共36个门实例")
	check(main_enemies == 119 and main_waves == 21, "主线119敌21波")
	check(main_enemies + side_enemies == 134 and main_waves + side_waves == 24, "含支路134敌24波")
