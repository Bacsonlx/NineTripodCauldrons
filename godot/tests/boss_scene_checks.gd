extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("Boss场景检查超时"); quit(1))
	run.call_deferred()

func effect_pose(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Node2D: result.append([str(child.name),child.transform,child.visible,child.modulate])
	return result

func check_skills() -> void:
	var view: Node2D = load("res://scripts/presentation/boss_art_view.gd").new()
	view.standalone_environment=false
	root.add_child(view)
	var effects: Node2D = view.get_node("SkillEffects")
	check(view.character.scale.is_equal_approx(Vector2.ONE*(1.25*2.0/3.0)),"正式Boss保留相对体量并将视觉缩放到原来的三分之二，规则范围不随角色缩放")
	var original: Node2D = load("res://scripts/presentation/thor_frame_actor.gd").new()
	root.add_child(original)
	var close: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"spawn":Vector2(840,520)})
	var saw_swing: bool = false
	for i in 220:
		close.update({},0.01); view.update(close.snapshot(),0)
		if close.snapshot().boss.phase!="swing": continue
		saw_swing=effects.get_node("SwingArc").visible
		check(view.character.body.clip=="thor-swing-v2" and view.character.body.frame_index==4,"默认Boss横锤生效相使用新绘画的挥击帧")
		for vertex in effects.get_node("SwingArc").polygon:
			check(vertex.length()<=180.001,"锤弧纹理不越过180单位真实危险扇区")
		close.set_paused(true)
		view.update(close.snapshot(),0)
		var frozen: Array = effect_pose(effects)
		close.update({},2); view.update(close.snapshot(),2)
		check(effect_pose(effects)==frozen,"暂停中的锤弧和残留效果不随表现调用推进")
		close.set_paused(false)
		break
	check(saw_swing,"真实近身横锤阶段显示已导入的锤弧美术")
	var far: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"health":10000})
	var outbound: bool = false
	var inbound: bool = false
	var lightning: Dictionary = {}
	var contacts: bool = false
	var scale_checked: bool = false
	for i in 1700:
		far.update({},0.01)
		var state: Dictionary = far.snapshot()
		view.update(state,0)
		original.update_state(state)
		if state.vulnerable:
			var ground: Vector2 = Vector2(state.hammer.x,state.hammer.y)
			if not scale_checked:
				# 不同缩放的真实行走会产生不同落脚姿态；用相同中立站姿隔离体量检查。
				var reference: Node2D = load("res://scripts/presentation/thor_frame_actor.gd").new()
				var enlarged: Node2D = load("res://scripts/presentation/thor_frame_actor.gd").new()
				enlarged.visual_scale=1.25; root.add_child(reference); root.add_child(enlarged)
				reference.update_state(state); enlarged.update_state(state)
				var expected_hammer: Vector2 = ground+(reference.get_node("hammer").global_position-ground)*1.25
				check(enlarged.get_node("hammer").global_position.distance_to(expected_hammer)<0.02,"同一站姿放大只改变空中锤体高度／体量，不放大规则地面飞行距离")
				reference.free(); enlarged.free(); scale_checked=true
			var wake: Sprite2D = effects.get_node("HammerWake")
			check(wake.visible and wake.position.is_equal_approx(view.character.get_node("hammer").global_position),"电流拖尾跟随实际空中锤体，保持地面路径独立")
			var expected: Vector2 = Vector2.LEFT if state.hammer.leg=="out" else Vector2.RIGHT
			check(Vector2.from_angle(wake.rotation).dot(expected)>0.99,"飞锤去回方向驱动拖尾朝向")
			outbound=outbound or state.hammer.leg=="out"
			inbound=inbound or state.hammer.leg=="return"
		for child in effects.get_children():
			if str(child.name).begins_with("Lightning") and child.visible:
				lightning[child.get_instance_id()]=true
				var frozen: Array = effect_pose(effects)
				far.set_paused(true); far.update({},1)
				view.update(far.snapshot(),1)
				check(effect_pose(effects)==frozen,"落雷电柱、冲击及拖尾暂停冻结")
				far.set_paused(false)
			if str(child.name).begins_with("Contact") and child.visible: contacts=true
	check(outbound and inbound,"完整掷锤往返均显示方向正确的独立特效")
	check(lightning.size()==3,"同一位置的三次落雷分别播放一次电柱，不因数组移位而漏播或重复，实际%d" % lightning.size())
	check(contacts,"真实命中、折返或接锤产生可见电流冲击")
	far.reset(); view.update(far.snapshot(),0)
	check(not effects.get_node("HammerWake").visible and effects.get_child_count()==2,"重开清掉所有旧电柱和命中残留")
	var dying: Dictionary = far.snapshot()
	dying.boss.health=0; dying.boss.phase="dead"; dying.status="complete"
	view.update(dying,0)
	check(effects.get_child_count()==2 and not effects.get_node("SwingArc").visible,"Boss死亡后清理全部技能威胁表现")
	original.free(); view.free()

func check_reinforcements() -> void:
	set_meta("home_test_arguments",["--test=boss","--seed=1"])
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	game.room.update({},2.01); game.present(game.room.snapshot(),0)
	check(game.boss_view.state.summons.size()==4 and game.enemy_bodies.is_empty(),"首页Boss入口读取四个真实召怪预警，尚未创建敌人精灵")
	game.room.update({},1.0); game.present(game.room.snapshot(),0)
	var state: Dictionary = game.room.snapshot()
	check(game.enemy_bodies.size()==4 and state.enemies.all(func(enemy: Dictionary): return game.enemy_bodies.has(enemy.id) and game.enemy_bodies[enemy.id].visible),"延迟出生的小怪动态创建精灵并显示，不依赖开场预建")
	check(game.encounter_label.text.contains("影偶 4 / 8") and game.interaction_label.text.contains("F"),"Boss HUD显示小怪数量和战中补给操作")
	game.controls.interrupt(true)
	var frozen: Dictionary = game.room.snapshot()
	game.room.update({},10); game.present(game.room.snapshot(),0)
	check(game.room.snapshot().summons==frozen.summons and game.room.snapshot().enemies==frozen.enemies,"真实失焦适配冻结援军和已出生小怪")
	game.room.set_paused(false)
	game.journey.update({"restart":true},0); game.present_new_room()
	await process_frame
	check(game.enemy_bodies.is_empty() and game.room.snapshot().enemies.is_empty() and game.room.snapshot().summons.is_empty(),"R重开清理动态小怪精灵和规则，保留Boss专项起点")
	game.free()

func run() -> void:
	var map: Node2D = load("res://scenes/rooms/boss.tscn").instantiate()
	root.add_child(map)
	check(map.has_node("Environment/Ground"),"Boss正式房间在编辑器场景中包含可加载的雷庭地面")
	var layout: Dictionary = map.get_layout()
	check(layout.obstacles.size()==4 and TrainingRoom.point(layout.doors[0].point)==Vector2(200,520) and TrainingRoom.point(layout.doors[1].point)==Vector2(1240,520),"地图美术保留四个门柱实体和两侧互动点，不添加场内障碍")
	map.queue_free()
	var game: Node2D = load("res://scenes/boss_test.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	check(game.room.snapshot().boss.health==1200 and game.boss_bar.value==1200,"独立Boss场景可加载，血条显示真实1200生命")
	check(game.backdrop.has_node("SkillEffects"),"独立Boss房加载三招透明美术与命中效果")
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
	game.select_trial(0)
	root.size=Vector2i(1280,720)
	await process_frame
	game.update_camera()
	check(game.view_zoom>0.5,"Boss固定取景使用紧凑边距，不额外留出大片外围空景")
	var fixed_origin: Vector2 = game.view_origin
	var fixed_zoom: float = game.view_zoom
	game.room.update({"moveY":1},0.4); game.update_camera()
	check(game.view_origin==fixed_origin and game.view_zoom==fixed_zoom,"Boss镜头固定居中，不随玩家移动平移或缩放")
	game.overview=true
	for size in [Vector2i(1280,720),Vector2i(900,900),Vector2i(1920,800),Vector2i(3840,1080),Vector2i(800,1200)]:
		root.size=size
		await process_frame
		game.update_camera()
		var visible: Rect2 = Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
		check(visible.encloses(Rect2(96,96,1248,848)),"窗口%s下所有预警与飞锤都处于镜头覆盖范围" % size)
		check(visible.encloses(Rect2(16,16,1408,1008)),"窗口%s下边缘落雷的完整80半径预警不被裁切" % size)
		var environment: Node2D = game.backdrop.get_node("Floor/Environment")
		var surround: Polygon2D = environment.get_node_or_null("Surround")
		var coverage: Rect2 = environment.get_node("Ground").get_rect()
		coverage=environment.get_node("Ground").transform*coverage
		if surround!=null:
			coverage=Rect2(surround.polygon[0],Vector2.ZERO)
			for point in surround.polygon: coverage=coverage.expand(point)
		check(coverage.encloses(visible),"窗口%s下Boss环境铺满可见区域，不露场景外空底" % size)
	game.overview=false
	for size in [Vector2i(1280,720),Vector2i(900,900),Vector2i(1920,800),Vector2i(800,1200)]:
		root.size=size
		await process_frame
		for spawn in [Vector2(240,520),Vector2(720,160),Vector2(720,880)]:
			game.room=load("res://scripts/combat/boss_room.gd").new({"spawn":spawn})
			game.update_camera()
			var battle_zoom: float = game.view_zoom
			var battle_origin: Vector2 = game.view_origin
			var saw_throw: bool = false
			for step in 360:
				game.room.update({},0.02); game.update_camera()
				check(game.view_origin==battle_origin and game.view_zoom==battle_zoom,"同一窗口下追近、掷锤、落雷及收招均不改变固定镜头")
				var sample: Dictionary = game.room.snapshot()
				var visible: Rect2 = Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
				check(visible.has_point(Vector2(sample.player.x,sample.player.y-96)) and visible.has_point(Vector2(sample.player.x,sample.player.y+24)),"固定镜头保留玩家完整身体")
				if sample.boss.phase in ["throw_warn","flight"]:
					saw_throw=true
					var target: Vector2 = sample.throwTarget if sample.boss.phase=="throw_warn" else sample.hammer.target
					for point in [Vector2(sample.boss.x,sample.boss.y),target]:
						check(visible.has_point(point-Vector2(72,240)) and visible.has_point(point+Vector2(72,48)),"预警及飞行阶段完整保留地面锤路和举起的空中锤体")
					var zoom_before: float = game.view_zoom
					var origin_before: Vector2 = game.view_origin
					game.room.set_paused(true); game.room.update({},1); game.update_camera()
					check(game.view_zoom==zoom_before and game.view_origin==origin_before,"暂停不改变固定镜头构图")
					game.room.set_paused(false)
			check(saw_throw,"固定镜头回归实际覆盖预警、去回程和收招")
	root.size=Vector2i(800,1200)
	await process_frame
	game.room=load("res://scripts/combat/boss_room.gd").new({"spawn":Vector2(240,520)})
	for step in 1100:
		game.room.update({"moveX":1} if game.room.snapshot().boss.phase=="lightning" else {},0.01); game.update_camera()
		var sample: Dictionary = game.room.snapshot()
		var visible: Rect2 = Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
		for mark in sample.lightning:
			check(visible.encloses(Rect2(mark.x-80,mark.y-80,160,160)),"竖屏持续走位仍完整显示此前锁定的落雷圆")
	game.queue_free()
	await process_frame
	check_skills()
	await check_reinforcements()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
