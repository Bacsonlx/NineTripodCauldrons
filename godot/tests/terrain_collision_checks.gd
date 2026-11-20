extends SceneTree

const Stage = preload("res://scripts/journey/journey_room.gd")
const Journey = preload("res://scripts/journey/room_journey.gd")

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var maps: Dictionary = Journey.read_maps()
	check(maps.size() == 16, "读取全部16个正式房间")
	if maps.size() != 16:
		finish(); return

	# 1. 斜边切向滑动：在 ash_cloister L 形斜角内侧 (690, 500) 单轴向左移动，应沿斜边向左下切线滑行而不死卡
	var ash_data: Dictionary = maps.ash_cloister.duplicate(true)
	ash_data.encounters = []
	ash_data.spawn = {"x": 690, "y": 500}
	var ash_room: TrainingRoom = Stage.new(ash_data)
	check(ash_room.can_walk(Vector2(690, 500)), "ash_cloister 测试起点合法")
	for _i in 30:
		ash_room.update({"moveX": -1.0, "moveY": 0.0}, 0.02)
	var ash_pos: Vector2 = TrainingRoom.point(ash_room.snapshot().player)
	check(ash_room.can_walk(ash_pos), "斜边滑动后角色仍处于合法可行走区域")
	check(ash_pos.x < 680.0 and ash_pos.y > 505.0, "单轴撞上45度斜边时沿切线顺滑移动而非原地卡死")

	# 2. 正面垂直撞墙停下：在 entry 左侧垂直墙 (x=180) 正面按左键，应停住且不乱偏转
	var entry_data: Dictionary = maps.entry.duplicate(true)
	entry_data.spawn = {"x": 200, "y": 590}
	var entry_room: TrainingRoom = Stage.new(entry_data)
	for _i in 30:
		entry_room.update({"moveX": -1.0, "moveY": 0.0}, 0.02)
	var entry_pos: Vector2 = TrainingRoom.point(entry_room.snapshot().player)
	check(entry_pos.x >= 191.5 and absf(entry_pos.y - 590.0) < 0.05, "正面垂直撞墙应正常停下，不盲目左右偏转")

	# 3. 角落退出：贴近 entry 内角后反向/斜向移动应顺畅退出
	for _i in 20:
		entry_room.update({"moveX": 0.7, "moveY": -0.7}, 0.02)
	var exit_pos: Vector2 = TrainingRoom.point(entry_room.snapshot().player)
	check(exit_pos.distance_to(entry_pos) > 40.0 and entry_room.can_walk(exit_pos), "从边界角落可顺畅移动退出")

	# 4. 牵引连续路径不穿薄墙
	var thin_data: Dictionary = maps.entry.duplicate(true)
	thin_data.spawn = {"x": 600, "y": 520}
	thin_data.obstacles = [{"x": 636, "y": 520, "kind": "wall", "halfWidth": 12.0, "halfHeight": 80.0, "height": 120.0}]
	var thin_room: TrainingRoom = Stage.new(thin_data)
	thin_room.pull_player_toward(Vector2(700, 520), 60.0)
	var pulled_pos: Vector2 = TrainingRoom.point(thin_room.snapshot().player)
	check(pulled_pos.x < 624.0 and thin_room.can_walk(pulled_pos), "牵引位移受薄墙阻挡，不会隔墙瞬移穿透")

	# 5. 长短帧一致性：同一房间内分别用 0.02s*10 和 0.10s*2 移动，均保持合法且终点一致
	var fine_data: Dictionary = maps.court2.duplicate(true)
	fine_data.encounters = []
	fine_data.spawn = {"x": 750, "y": 560}
	var fine_room: TrainingRoom = Stage.new(fine_data)
	var coarse_room: TrainingRoom = Stage.new(fine_data)
	for _i in 10:
		fine_room.update({"moveX": 0.6, "moveY": 0.8}, 0.02)
	for _i in 2:
		coarse_room.update({"moveX": 0.6, "moveY": 0.8}, 0.10)
	var fine_pos: Vector2 = TrainingRoom.point(fine_room.snapshot().player)
	var coarse_pos: Vector2 = TrainingRoom.point(coarse_room.snapshot().player)
	check(fine_room.can_walk(fine_pos) and coarse_room.can_walk(coarse_pos), "长短帧绕障后均位于合法区域")
	check(fine_pos.distance_to(coarse_pos) < 2.5, "长短帧沿障碍圆角滑动结果一致")

	# 6. 完全无效位移时闪避与位移技能不白扣资源
	var wall_data: Dictionary = maps.entry.duplicate(true)
	wall_data.spawn = {"x": 192.1, "y": 590}
	var wall_room: TrainingRoom = Stage.new(wall_data)
	wall_room.update({"moveX": -1.0, "moveY": 0.0, "dodge": true, "aim": Vector2(100, 590)}, 0.02)
	var wall_snap: Dictionary = wall_room.snapshot()
	check(is_equal_approx(wall_snap.resources.stamina, 100.0) and wall_snap.cooldowns.dodge == 0.0, "正面贴墙无有效位移时闪避不白扣精力与冷却")

	# 7. 出生、互动点与门往返可达性覆盖
	for id in ["entry", "stele", "stele_side", "ash_cloister", "end", "root_fork", "gate_forecourt"]:
		var r: TrainingRoom = Stage.new(maps[id])
		var sp: Vector2 = TrainingRoom.point(maps[id].spawn)
		check(r.can_walk(sp), id + " 出生点可站立")
		for door in maps[id].doors:
			check(not r.find_route(sp, TrainingRoom.point(door.point)).is_empty(), id + " 可到达门前：" + door.id)
		for ex in maps[id].exploration:
			check(not r.find_route(sp, TrainingRoom.point(ex)).is_empty(), id + " 可到达互动点：" + ex.id)

	finish()

func finish() -> void:
	print(JSON.stringify({"terrain_collision_checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
