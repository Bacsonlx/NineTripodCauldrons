extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	run.call_deferred()

func player_checks() -> void:
	var game: Node2D = load("res://scenes/sample.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	var room: TrainingRoom = game.room
	var target: Vector2 = Vector2(600,548)
	check(game.frame_actor.has_node("Lower") and game.frame_actor.has_node("Upper"),"新角色必须分别提供独立下肢和瞄准上身")
	if not game.frame_actor.has_node("Lower"):
		game.free(); return
	game.controls.key_down(KEY_D)
	game.present(game.controls.update(target,true,0.05),0.05)
	check(game.frame_actor.lower.visible and game.frame_actor.lower.clip=="hero-run-lower" and game.frame_actor.upper.visible and game.frame_actor.upper.clip=="hero-archery-upper" and not game.legs.visible and not game.torso.visible,"真实向右移动显示新下肢与独立瞄准上身，并隐藏旧身体")
	var frozen_frame: int = game.frame_actor.lower.frame_index
	var frozen_distance: float = game.frame_actor.distance
	game.present(room.snapshot(),0.5)
	check(game.frame_actor.lower.frame_index==frozen_frame and game.frame_actor.distance==frozen_distance,"重复快照不因呈现秒数推进步态")
	game.controls.interrupt(true); game.present(room.snapshot(),1)
	check(game.frame_actor.lower.frame_index==frozen_frame and game.frame_actor.lower.clip=="hero-run-lower","失焦暂停冻结新跑步姿态")
	room.set_paused(false)
	game.controls.key_down(KEY_A); game.controls.pointer_down(true)
	game.present(game.controls.update(target,true,0.02),0.02)
	check(not game.frame_actor.lower.visible and game.legs.visible and game.frame_actor.upper.visible and not game.torso.visible and game.state.player.facing==0,"向左移动且向右射击仍由独立上下身呈现")
	game.controls.interrupt(); room.reset()
	game.controls.update(target,true,0.001)
	var seen: Dictionary = {}
	game.controls.pointer_down(true); game.controls.pointer_up()
	for i in 35:
		game.present(game.controls.update(target,true,0.01),0.01)
		check(game.frame_actor.upper.visible and not game.frame_actor.body.visible and not game.bow.visible and not game.nocked_arrow.visible,"原地射箭全过程只显示一套独立上身及联绘武器")
		seen[game.frame_actor.upper.frame_index]=true
	check(seen.size()==8 and room.shots==1,"一次真实点射按原时钟采样8姿态且只生成一箭")
	for key in [KEY_Q,KEY_E,KEY_SPACE]:
		game.controls.interrupt(); room.reset()
		game.controls.update(target,true,0.001)
		game.controls.key_down(KEY_D) if key==KEY_SPACE else game.controls.key_up(KEY_D)
		game.controls.key_down(key)
		game.present(game.controls.update(target,true,0.02),0.02)
		check((game.frame_actor.body.visible and game.frame_actor.body.clip=="hero-dodge" if key==KEY_SPACE else game.frame_actor.upper.visible and game.frame_actor.upper.clip=="hero-skills-upper"),"真实Q/E/向右闪避使用对应新动作：键%d，技能%s，闪避%s，方向%d，新帧%s" % [key,str(game.state.skill),str(game.state.dodge),game.state.player.facing,game.frame_actor.body.clip if key==KEY_SPACE else game.frame_actor.upper.clip])
		if key==KEY_SPACE:
			game.present(game.controls.update(target,true,0.02),0.02)
			check(game.combat_effects.ghosts.any(func(ghost: Dictionary): return ghost.lower.visible and ghost.lower.texture==game.frame_actor.body.texture and not ghost.upper.visible),"新闪避残影使用新全身帧，不残留旧上身")
	room.status="failed"; game.present(room.snapshot(),0)
	check(not game.frame_actor.lower.visible and not game.frame_actor.upper.visible and not game.frame_actor.body.visible and game.failed.visible,"失败隐藏新身体并沿用既有失败素材")
	room.reset(); game.controls.interrupt(); game.present(game.controls.update(target,true,0),0)
	check(game.frame_actor.upper.visible and game.frame_actor.distance==0 and game.frame_actor.upper.frame_index==0,"重试归零步态并回到新待机姿态")
	game.free()

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
	player_checks()
	boss_checks()
	print(JSON.stringify({"action_frame_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
