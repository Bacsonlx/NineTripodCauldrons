extends SceneTree

const TraceReplay = preload("res://tests/trace_replay.gd")
const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
var failures: Array[String] = []
var count: int = 0

func check(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	if "--launch-only" in OS.get_cmdline_user_args():
		load("res://tests/launch_options_checks.gd").new().run(Callable(self,"check"))
		print(JSON.stringify({"checks":count,"failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	if "--loot-only" in OS.get_cmdline_user_args():
		load("res://tests/loot_checks.gd").new().run(Callable(self,"check"))
		print(JSON.stringify({"checks":count,"failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	if "--boss-only" in OS.get_cmdline_user_args():
		load("res://tests/boss_checks.gd").new().run(Callable(self,"check"))
		print(JSON.stringify({"checks":count,"failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	if "--alpha-only" in OS.get_cmdline_user_args():
		load("res://tests/alpha_checks.gd").new().run(Callable(self,"check"))
		print(JSON.stringify({"checks":count,"failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	var room = Room.new()
	room.update({"moveX": 1.0, "moveY": 0.0, "aim": Vector2(1000, 549), "fire": false, "pointerInside": true}, 1.0)
	check(abs(room.snapshot().player.x - 620.0) < 0.01, "单轴移动一秒推进220世界单位")
	var archer = Room.new()
	archer.update({"moveX": 0.0, "moveY": 0.0, "aim": Vector2(840, 549), "fire": true, "pointerInside": true}, 0.01)
	archer.update({"moveX": 0.0, "moveY": 0.0, "aim": Vector2(840, 549), "fire": false, "pointerInside": true}, 0.8)
	check(archer.snapshot().get("shots", 0) == 1, "短按释放后仍完成一箭，松开不追加攻击")
	var duel = Room.new({"enemy": Vector2(455, 600), "encounter": Vector2(400, 600)})
	duel.update({"aim": Vector2(1000, 549), "fire": true, "pointerInside": true}, 0.01)
	duel.update({"aim": Vector2(1000, 549), "fire": false, "pointerInside": true}, 0.12)
	var enemies: Array = duel.snapshot().get("enemies", [])
	check(not enemies.is_empty() and enemies[0].health == 45, "普通箭从握点命中已激活影偶并扣除15生命")
	var chase = Room.new({"spawn": Vector2(650, 448), "enemy": Vector2(880, 448), "encounter": Vector2(650, 448)})
	chase.update({}, 4.0)
	check(chase.snapshot().enemies[0].x < 720 and chase.snapshot().health < 100, "影偶绕过实体追击，进入近战范围后造成自然伤害")
	var lethal = Room.new({"enemy": Vector2(455, 600), "encounter": Vector2(400, 600)})
	lethal.update({}, 12.0)
	check(lethal.snapshot().health == 0 and lethal.snapshot().status == "failed", "连续正常近战造成失败，失败后时间推进不再改写战斗")
	lethal.reset()
	check(lethal.snapshot().health == 100 and lethal.snapshot().enemies[0].health == 60 and lethal.snapshot().arrows.is_empty() and lethal.snapshot().effects.is_empty(), "重试恢复双方生命并清理旧箭与反馈")
	var input_room = Room.new()
	var controls = Controls.new(input_room)
	controls.pointer_down(true)
	controls.pointer_up()
	controls.update(Vector2(1000, 549), true, 0.01)
	controls.update(Vector2(1000, 549), true, 0.15)
	check(input_room.snapshot().shots == 1, "同一规则帧之前的鼠标按下松开仍消费一次点按")
	controls.key_down(KEY_D)
	controls.pointer_down(true)
	controls.interrupt(true)
	controls.update(Vector2(1000, 549), true, 1.0)
	check(input_room.snapshot().paused and input_room.snapshot().player.x == 400, "真实失焦的适配入口暂停规则并清理移动")
	controls.key_down(KEY_ESCAPE)
	controls.update(Vector2(1000, 549), true, 1.0)
	check(input_room.snapshot().shots == 1 and input_room.snapshot().player.x == 400, "恢复暂停不补发旧攻击和旧移动")
	controls.key_down(KEY_D)
	controls.pointer_down(true)
	controls.pointer_leave()
	controls.update(Vector2(1000, 549), false, 0.1)
	check(input_room.snapshot().player.x > 400 and input_room.snapshot().shots == 1, "鼠标离开只取消待发攻击，合法移动继续")
	controls.interrupt()
	controls.update(Vector2(1000, 549), true, 0.5)
	check(not input_room.snapshot().paused and input_room.snapshot().shots == 1 and not input_room.snapshot().player.moving, "窗口变化清理意图但不额外暂停")
	var wall = Room.new({"spawn": Vector2(650, 448), "enemy": Vector2(880, 448), "encounter": Vector2(650, 448)})
	wall.update({"aim": Vector2(1000, 397), "fire": true}, 0.2)
	check(wall.snapshot().enemies[0].health == 60 and wall.snapshot().arrows.is_empty() and wall.snapshot().effects.size() == 1, "实体按最早接触阻箭，墙体反馈不扣敌人生命")
	var kill = Room.new({"enemy": Vector2(500, 600), "encounter": Vector2(400, 600)})
	kill.update({"aim": Vector2(1000, 549), "fire": true}, 1.2)
	check(kill.snapshot().enemies[0].health == 0 and kill.snapshot().status == "complete", "四次普通箭造成真实击败并结束遭遇")
	var muzzle_wall = Room.new({"obstacle": Rect2(413, 580, 6, 36)})
	muzzle_wall.update({"aim": Vector2(1000, 549), "fire": true}, 0.1)
	check(muzzle_wall.snapshot().arrows.is_empty() and muzzle_wall.snapshot().effects.size() == 1, "握点伸过薄实体时，肩部到握点的最早接触仍阻箭")
	var diagonal = Room.new()
	diagonal.update({"moveX": -1, "moveY": -1}, 0.5)
	var position: Vector2 = Vector2(diagonal.snapshot().player.x, diagonal.snapshot().player.y)
	check(absf(position.distance_to(Vector2(400, 600)) - 110) < 0.01, "斜向移动归一化，不比单轴更快")
	diagonal.update({}, 0.1)
	check(not diagonal.snapshot().player.moving and absf(diagonal.snapshot().player.x - position.x) < 0.001, "松键停止移动")
	var blocked_walk = Room.new({"spawn": Vector2(650, 448)})
	blocked_walk.update({"moveX": 1}, 0.8)
	check(blocked_walk.snapshot().player.x <= 708, "脚点碰撞阻止玩家穿入实体")
	var cooldown_room = Room.new()
	cooldown_room.update({"fire": true}, 0.1)
	cooldown_room.update({"fire": false}, 0.01)
	cooldown_room.update({"fire": true}, 0.01)
	cooldown_room.update({"fire": false}, 1.0)
	check(cooldown_room.snapshot().shots == 1, "冷却期间点击不会排队补箭")
	var short_steps = Room.new({"enemy": Vector2(455, 600), "encounter": Vector2(400, 600)})
	var long_step = Room.new({"enemy": Vector2(455, 600), "encounter": Vector2(400, 600)})
	for frame in 180:
		short_steps.update({}, 0.01)
	long_step.update({}, 1.8)
	check(short_steps.snapshot().health == long_step.snapshot().health and short_steps.snapshot().health == 60, "长帧与短步近战时序一致，不追溯或重复扣血")
	var repeated = Room.new()
	var repeat_controls = Controls.new(repeated)
	repeat_controls.key_down(KEY_ESCAPE)
	repeat_controls.key_down(KEY_ESCAPE, true)
	check(repeated.snapshot().paused, "系统重复按键不反复切换暂停")
	var upper_edge = Room.new({"spawn": Vector2(200, 210), "enemy": Vector2(550, 210), "encounter": Vector2(200, 210)})
	upper_edge.update({"aim": Vector2(1000, 159), "fire": true}, 0.01)
	upper_edge.update({"aim": Vector2(1000, 159), "fire": false}, 0.44)
	check(upper_edge.snapshot().enemies[0].health == 45, "合法上缘脚点释放的空中箭不被脚点边界清除，仍可命中")
	var traces: RefCounted = TraceReplay.new()
	var report: Dictionary = traces.run()
	check(report.failures.is_empty(),"55个参照场景回放："+str(report.failures))
	var scene: PackedScene = load("res://scenes/tanggu_map.tscn")
	var map: Node2D = scene.instantiate()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tanggu.json"))
	var map_errors: Array[String] = map.validation_errors()
	check(map_errors.is_empty(),"正式编辑器地图通过布局校验，允许合法调整而不改写冻结规则参照："+str(map_errors))
	map.free()
	# 保存重开使用独立布局，避免测试偏移量限制用户的合法关卡编辑。
	map=load("res://scripts/world/map_definition.gd").new()
	for definition in [
		{"name":"Road1","category":"road","position":Vector2(1280,745),"size":Vector2(2320,1130)},
		{"name":"PlayerSpawn","category":"spawn","position":Vector2(400,600)},
		{"name":"Obstacle1","category":"obstacle","position":Vector2(1000,900)},
		{"name":"Stele","category":"obstacle","position":Vector2(840,280),"obstacle_kind":"stele"},
		{"name":"Altar","category":"obstacle","position":Vector2(1000,1100),"obstacle_kind":"altar"},
		{"name":"Gate","category":"obstacle","position":Vector2(1500,700),"obstacle_kind":"gate"},
		{"name":"SteleInteraction","category":"interaction","position":Vector2(840,365),"interaction_id":"stele"},
		{"name":"AltarInteraction","category":"interaction","position":Vector2(1000,1180),"interaction_id":"altar"},
		{"name":"GateInteraction","category":"interaction","position":Vector2(1580,700),"interaction_id":"gate"},
		{"name":"Encounter1","category":"encounter","position":Vector2(830,600)},
		{"name":"Route1","category":"route","position":Vector2(400,600)},
		{"name":"Route2","category":"route","position":Vector2(1200,600)},
	]:
		var item: Node2D = load("res://scripts/world/map_item.gd").new()
		for key in definition: item.set(key,definition[key])
		map.add_child(item); item.owner=map
	var enemy_spawn: Node2D = load("res://scripts/world/map_item.gd").new()
	enemy_spawn.name="Enemy1"; enemy_spawn.category="enemy"
	map.get_node("Encounter1").add_child(enemy_spawn); enemy_spawn.owner=map
	var road_width: float = map.get_node("Road1").size.x
	map.get_node("Road1").size.x=-20
	check(not map.validation_errors().is_empty() and str(map.validation_errors()).contains("Road1"),"非法道路尺寸在编辑、运行和导出预检时明确定位节点")
	map.get_node("Road1").size.x=road_width
	map.get_node("Road1").size.x+=20
	map.get_node("Obstacle1").position.x+=10
	map.get_node("PlayerSpawn").position.x+=20
	map.get_node("Encounter1/Enemy1").position.x+=20
	map.get_node("SteleInteraction").position.y+=10
	var edited: Dictionary = map.get_layout()
	var packed: PackedScene = PackedScene.new()
	var edited_path: String = "user://editor-roundtrip-%d.tscn" % OS.get_process_id()
	var saved: bool = packed.pack(map)==OK and ResourceSaver.save(packed,edited_path)==OK
	check(saved,"四类编辑器配置可以保存为原生场景")
	if not saved:
		map.free(); quit(1); return
	map.free()
	var reopened: PackedScene = ResourceLoader.load(edited_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	map=reopened.instantiate()
	check(traces.difference(traces.json_value(map.get_layout()),traces.json_value(edited)).is_empty(),"保存关闭后重开四类布局保留，未写回参照地图")
	var edited_room = Room.new(map.get_layout())
	check(edited_room.snapshot().player.x==edited.spawn.x and edited_room.snapshot().enemies.size()==edited.encounters[0].enemies.size() and edited_room.snapshot().enemies[0].x==edited.encounters[0].enemies[0].x,"重新载入的场景配置直接进入正式规则，玩家与敌人出生点使用编辑结果")
	map.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(edited_path))
	var reading_layout: Dictionary = expected.duplicate(true)
	reading_layout.spawn={"x":840,"y":365}; reading_layout.encounters=[]
	var reader = Room.new(reading_layout)
	var reader_controls = Controls.new(reader)
	reader_controls.key_down(KEY_F); reader_controls.key_up(KEY_F)
	reader_controls.update(Vector2(1000,300),true,0)
	check(reader.snapshot().reading,"适配层快速F点按打开阅读，不被同帧松键吞掉")
	reader_controls.interrupt(true); reader_controls.key_down(KEY_ESCAPE)
	check(not reader.snapshot().reading and reader.snapshot().paused,"阅读叠加失焦后Esc只关闭阅读，仍保持暂停")
	reader_controls.key_down(KEY_ESCAPE)
	reader_controls.update(Vector2(1000,300),true,0.1)
	check(not reader.snapshot().paused and reader.snapshot().arrows.is_empty(),"二次Esc恢复后不续射，阅读切换已清理操作意图")
	load("res://tests/boss_checks.gd").new().run(Callable(self,"check"))
	load("res://tests/projectile_obstacle_checks.gd").new().run(Callable(self,"check"))
	load("res://tests/loot_checks.gd").new().run(Callable(self,"check"))
	load("res://tests/launch_options_checks.gd").new().run(Callable(self,"check"))
	load("res://tests/alpha_checks.gd").new().run(Callable(self,"check"))
	print(JSON.stringify({"checks":count,"failures":failures,"rule_traces":report}))
	quit(0 if failures.is_empty() else 1)
