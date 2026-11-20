extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	run.call_deferred()

func boss_checks() -> void:
	var actor: Node2D = load("res://scripts/presentation/thor_frame_actor.gd").new()
	root.add_child(actor)
	var room: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"health":10000,"spawn":Vector2(840,520)})
	var phases: Dictionary = {}
	for i in 1600:
		room.update({},0.01)
		var state: Dictionary = room.snapshot()
		var before: Dictionary = state.duplicate(true)
		actor.update_state(state)
		check(state==before,"新Boss呈现不改写规则快照")
		phases[state.boss.phase]=true
		check(actor.body.region_rect.end.x<=actor.body.texture.get_width() and actor.body.region_rect.end.y<=actor.body.texture.get_height(),"全部Boss阶段只采样图集内有效帧")
		if state.vulnerable:
			check(actor.hammer.visible and actor.body.frame_index in [4,5],"飞行时身体为空手帧，独立飞锤按规则存在")
			check(actor.hammer.global_position.is_equal_approx(Vector2(state.hammer.x,state.hammer.y)+Vector2(30,-110)),"飞锤保留真实地面坐标和固定空中高度")
		if i%100==0:
			var frame: int = actor.body.frame_index
			var transform: Transform2D = actor.body.transform
			var distance: float = actor.distance
			actor.update_state(state)
			check(actor.body.frame_index==frame and actor.body.transform==transform and actor.distance==distance,"Boss重复快照不推进动作或步态")
	check(phases.has("swing") and phases.has("flight") and phases.has("lightning"),"真实规则循环覆盖新Boss三招")
	room.set_paused(true)
	var paused_frame: int = actor.body.frame_index
	room.update({},2); actor.update_state(room.snapshot())
	check(actor.body.frame_index==paused_frame,"Boss暂停冻结动作帧")
	room.set_paused(false); room.reset(); actor.update_state(room.snapshot())
	check(actor.distance==0 and not actor.hammer.visible and actor.body.frame_index==0,"Boss重试清理步态、飞锤和旧攻击姿态")
	room.enemies[0].health=0; actor.update_state(room.snapshot())
	check(not actor.body.visible and not actor.hammer.visible and actor.fallen.visible,"Boss死亡停止新动作及飞锤，沿用既有静态败退")
	actor.free()

func run() -> void:
	set_meta("home_test_arguments",["--room=court1"])
	for scene in ["sample","tanggu_first_level"]:
		var game: Node2D = load("res://scenes/"+scene+".tscn").instantiate()
		root.add_child(game); game.set_physics_process(false)
		load("res://tests/player_art_checks.gd").new().run(game,Callable(self,"check"))
		game.free()
	if "--waist-only" not in OS.get_cmdline_user_args(): boss_checks()
	print(JSON.stringify({"action_frame_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
