extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(15).timeout.connect(func(): push_error("Boss场景检查超时"); quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node2D = load("res://scenes/boss_test.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	check(game.room.snapshot().boss.health==1200 and game.boss_bar.value==1200,"独立Boss场景可加载，血条显示真实1200生命")
	game.trial_selector.select(1); game.select_trial(1)
	check(game.room.snapshot().resources.mana==44 and game.hud.mana.value==44,"切换44蓝测试条件，规则和HUD同步重开")
	game.controls.key_down(KEY_Q)
	game.present(game.controls.update(Vector2(720,468),true,0.01),0)
	check(game.hud.mana.value==32,"真实Q输入沿用玩家能耗，HUD同步扣12蓝")
	game.controls.interrupt(true)
	var before: Dictionary = game.room.snapshot()
	game.present(game.controls.update(Vector2(720,468),true,2),0)
	check(game.room.snapshot().boss==before.boss and game.hud.mana.value==44,"失焦冻结Boss并按原规则退还技能前摇蓝量")
	game.select_trial(2)
	game.room.update({"fire":true,"aim":Vector2(720,468)},0.8)
	game.present(game.room.snapshot(),0)
	check(game.boss_bar.value<1200 and game.hud.mana.value==0,"零蓝测试房真实普攻扣Boss生命，血条同步")
	for size in [Vector2i(1280,720),Vector2i(900,900),Vector2i(1920,800)]:
		root.size=size
		await process_frame
		game.update_camera()
		var visible: Rect2 = Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
		check(visible.encloses(Rect2(96,96,1248,848)),"窗口%s下所有预警与飞锤都处于镜头覆盖范围" % size)
	game.queue_free()
	await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
