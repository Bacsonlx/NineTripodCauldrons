extends RefCounted

const Room = preload("res://scripts/combat/training_room.gd")

func depart(game: Node2D) -> void:
	if game.room.alpha!=null and game.room.alpha.gameplay: game.room.update({"alpha":{"action":"depart"}},0)

func run(game: Node2D, check: Callable) -> void:
	depart(game)
	check.call(game.frame_actor.scale.is_equal_approx(Vector2.ONE*2.0/3.0), "玩家人物视觉缩放到原来的三分之二，规则脚点仍由父节点保持")
	check.call(game.atlas.has("upperDown"), "正式场景加载已确认的 v3 向下射箭资源")
	for key in ["upper","upperDown","bow","lower","skills","failed"]:
		var legacy: Texture2D = game.textures[key]
		check.call(legacy.resource_path.begins_with(game.HERO_RUNTIME_DIRECTORY) and legacy.get_image().has_mipmaps() and absf(float(game.atlas[key].scale)-0.75)<0.03, "旧主角图层改用带 mipmap 的统一纹素密度运行图集")
	for layer in [game.legs,game.torso,game.failed,game.bow,game.frame_actor.upper,game.frame_actor.lower,game.frame_actor.body,game.frame_actor.head]:
		check.call(layer.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "主角各图层缩小时按 mipmap 采样")
	for clip in game.frame_actor.upper.runtime_clips:
		var runtime: Texture2D = load(game.frame_actor.upper.RUNTIME_DIRECTORY+clip+".png")
		check.call(runtime.get_image().has_mipmaps() and absf(float(game.frame_actor.upper.clips[clip].scale)-0.75)<0.03, "新主角各动作共享同一纹素密度并生成 mipmap")
	game.present(game.room.snapshot(),0)
	for enemy in game.room.snapshot().enemies:
		var key: String = {"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance]
		var body: Sprite2D = game.enemy_bodies[enemy.id]
		check.call(body.scale.is_equal_approx(Vector2.ONE*float(game.atlas[key].scale)*2.0/3.0), "野怪视觉缩放到原来的三分之二，规则实体位置保持不变")
	var point: Vector2 = Vector2(game.state.player.x, game.state.player.y)
	var snapshot: Dictionary = game.controls.update(point+Vector2(0,200),true,0)
	game.present(snapshot,0)
	var side_state: Dictionary = game.room.snapshot()
	side_state.player.facing=2; side_state.player.moving=false; side_state.attack="idle"
	game.present(side_state,0)
	check.call(game.frame_actor.upper.visible and game.visual_connection_delta(game.frame_actor.upper,game.legs).length()<=0.5, "正面侧向联绘上身与旧下身按可见像素腰线相接")
	game.present(snapshot,0)
	check.call(game.torso.texture==game.textures.get("upperDown"), "向下待机使用新上身")
	check.call(not game.bow.visible and not game.nocked_arrow.visible, "联绘上身不重复叠加旧弓和搭弦箭")
	var back_state: Dictionary = game.room.snapshot()
	back_state.player.facing=3; back_state.player.moving=false; back_state.attack="idle"
	game.present(back_state,0)
	check.call(game.frame_actor.body.visible and game.frame_actor.body.clip=="hero-back-full", "背面待机使用完整身图集")
	check.call(not game.frame_actor.upper.visible and not game.frame_actor.head.visible and not game.frame_actor.lower.visible, "背面完整身显示时不叠加旧上下身")
	check.call(game.frame_actor.body.position==Vector2.ZERO, "背面完整身沿共享脚点注册，不产生局部位移")
	var unchanged: Dictionary = game.room.snapshot().duplicate(true)
	game.present(unchanged,0)
	check.call(game.room.snapshot()==unchanged, "人物视觉校准不修改规则快照")
	check.call(game.legs.global_position.is_equal_approx(point) and game.frame_actor.global_position.is_equal_approx(point), "缩放后脚点与规则实体位置完全一致，无漂移")
	for test_atk in ["idle", "draw", "release", "recover"]:
		for test_facing in 4:
			var test_state: Dictionary = game.room.snapshot()
			test_state.player.facing = test_facing
			test_state.attack = test_atk
			game.present(test_state, 0)
			var test_up: Sprite2D = game.frame_actor.upper if game.frame_actor.upper.visible else game.torso
			var test_low: Sprite2D = game.frame_actor.lower if game.frame_actor.lower.visible else game.legs
			if test_facing==3:
				check.call(game.frame_actor.body.visible and game.frame_actor.body.clip=="hero-back-full", "背面完整身覆盖四个普通射击阶段：%s" % test_atk)
			else:
				check.call(game.visual_connection_delta(test_up, test_low).length() <= 0.5, "四向及射击阶段上下身腰线相接：朝向%d/%s" % [test_facing, test_atk])
	var vp_rect: Rect2 = game.get_viewport_rect()
	check.call(vp_rect.size.x >= 640 and vp_rect.size.y >= 360, "视口几何规格支持人物正常渲染不越界")
	var phases: Dictionary = {}
	var launch_checked: bool = false
	game.controls.pointer_down(true); game.controls.pointer_up()
	for tick in 36:
		snapshot=game.controls.update(point+Vector2(0,200),true,1.0/60)
		game.present(snapshot,0)
		var phase: int = {"idle":0,"draw":1,"release":2,"recover":3}[snapshot.attack]
		phases[snapshot.attack]=true
		check.call(game.torso.texture==game.textures.get("upperDown") and is_equal_approx(game.torso.region_rect.position.x,float(game.atlas.upperDown.frames[phase].x)), "普通攻击实际时钟映射到新版四阶段")
		check.call(not game.bow.visible and not game.nocked_arrow.visible, "射箭全过程不叠加旧弓箭")
		if snapshot.attack=="draw":
			var visual_tip: Vector2 = game.torso.position+(Vector2(game.atlas.upperDown.muzzle_px[0],game.atlas.upperDown.muzzle_px[1])+game.torso.offset)*game.torso.scale
			var expected_rule_grip: Vector2 = point+Vector2(game.atlas.upperDown.grip.x,game.atlas.upperDown.grip.y)
			var expected_visual_grip: Vector2 = point+Vector2(game.atlas.upperDown.grip.x,game.atlas.upperDown.grip.y)*2.0/3.0
			check.call(snapshot.grip.is_equal_approx(expected_rule_grip), "规则出箭点保持既有坐标与稳定性")
			check.call(visual_tip.distance_to(expected_visual_grip)<0.5, "拉满箭尖随向下射箭按三分之二比例稳定呈现")
		if not snapshot.arrows.is_empty() and not launch_checked:
			launch_checked=true
			var arrow: Dictionary = snapshot.arrows[0]
			var launch: Vector2 = Vector2(arrow.x,arrow.y)-Vector2.from_angle(arrow.angle)*700*arrow.age
			check.call(launch.distance_to(snapshot.grip)<0.001, "普通箭确实从新标定点生成，而非仅移动显示")
			check.call(game.arrows[arrow.id].position.is_equal_approx(Vector2(arrow.x,arrow.y)) and is_equal_approx(game.arrows[arrow.id].rotation,arrow.angle), "飞行箭显示与真实弹道相同")
			check.call(absf(game.arrows[arrow.id].texture.get_width()*game.arrows[arrow.id].scale.x-35.52)<2.0, "离弦后的箭长与搭弦箭一致，避免释放瞬间突然放大")
	check.call(phases.size()==4 and launch_checked, "真实点按完整经过预备、拉满、释放、收势并发箭")
	for code in [KEY_S,KEY_W]:
		game.controls.key_down(code)
		snapshot=game.controls.update(point+Vector2(0,200),true,0.02)
		game.present(snapshot,0)
		var expected: Dictionary = game.atlas.lower.frames[5 if code==KEY_S else 7]
		check.call(snapshot.player.moving and game.legs.region_rect==Rect2(expected.x,expected.y,expected.width,expected.height) and game.torso.texture==game.textures.upperDown, "移动与向下瞄准独立，正向与反向移动选择各自下肢")
		game.controls.key_up(code)
	for facing in [0,2,3]:
		var other: Dictionary = snapshot.duplicate(true)
		other.player.facing=facing; other.player.angle=facing*PI/2; other.attack="draw"; other.player.moving=false
		other.grip=Vector2(other.player.x,other.player.y)+Room.GRIPS[facing]
		game.present(other,0)
		if facing==0:
			other.player.moving=false
			other.windup=0.04
			game.present(other,0)
			check.call(game.frame_actor.upper.visible and game.frame_actor.upper.clip=="hero-archery-upper" and not game.bow.visible and not game.nocked_arrow.visible,"向右原地射箭使用新上身帧，不重复叠弓")
		elif facing==3:
			check.call(game.frame_actor.body.visible and game.frame_actor.body.clip=="hero-back-full" and not game.frame_actor.upper.visible and not game.bow.visible and not game.nocked_arrow.visible,"背向普通射箭使用完整身图，不重复叠加旧层")
		else:
			check.call(game.frame_actor.upper.visible and game.frame_actor.upper.clip==("hero-archery-left" if facing==2 else "hero-archery-up") and not game.torso.visible and not game.bow.visible and not game.nocked_arrow.visible, "左／上使用统一身份上身且不叠旧武器")
	game.controls.interrupt(); game.room.reset()
	depart(game)
	point=Vector2(game.room.player.x,game.room.player.y)
	game.controls.update(point+Vector2(0,200),true,0)
	for code in [KEY_Q,KEY_E,KEY_SPACE]:
		game.controls.key_down(code)
		snapshot=game.controls.update(point+Vector2(0,40),true,0.01)
		game.present(snapshot,0)
		check.call(game.frame_actor.upper.visible and game.frame_actor.upper.clip=="hero-skills-direction-1" and not game.bow.visible and not game.nocked_arrow.visible, "Q／E／闪避使用统一身份联绘上身且没有悬空武器")
		var expected_grip: Vector2 = Vector2(snapshot.player.x,snapshot.player.y)+Room.SKILL_GRIPS[{KEY_Q:"pierce",KEY_E:"rain",KEY_SPACE:"dodge"}[code]][1]
		check.call(snapshot.grip.is_equal_approx(expected_grip), "技能不使用新的普通箭出箭点")
		game.controls.interrupt(); game.room.reset()
		depart(game)
		game.controls.update(point+Vector2(0,200),true,0)
	game.room.hurt=0.1
	game.present(game.room.snapshot(),0)
	check.call(game.frame_actor.upper.visible and game.frame_actor.upper.clip=="hero-skills-direction-1" and not game.bow.visible and not game.nocked_arrow.visible, "受击弓与持弓手联绘，不残留独立武器")
	game.room.hurt=0
	game.present(game.room.snapshot(),0)
	game.controls.key_down(KEY_ESCAPE)
	snapshot=game.room.snapshot(); game.present(snapshot,0)
	check.call(snapshot.paused and game.torso.texture==game.textures.upperDown and not game.bow.visible, "暂停后保留新版且无重复武器")
	game.controls.key_down(KEY_ESCAPE)
	game.room.status="failed"
	game.present(game.room.snapshot(),0)
	check.call(game.failed.visible and not game.torso.visible and not game.legs.visible and not game.bow.visible and not game.nocked_arrow.visible, "失败时正常隐藏新版身体与武器")
	game.room.reset(); game.controls.interrupt()
	depart(game)
	check.call(game.room.snapshot().arrows.is_empty(), "重试清理箭实例的规则状态")
	for angle in [PI/3,PI*2/3]:
		var aim: Vector2 = point+Vector2(0,-52)+Vector2.from_angle(angle)*300
		snapshot=game.controls.update(aim,true,0)
		game.present(snapshot,0)
		check.call(snapshot.player.facing==1 and game.torso.texture==game.textures.upperDown and absf(angle_difference(snapshot.player.angle,(aim-snapshot.grip).angle()))<0.001, "向下扇区内鼠标斜向瞄准保持真实角度，角色使用四向姿态")
	var muzzle_wall: RefCounted = Room.new({"obstacle":Rect2(390,575,20,3)})
	muzzle_wall.layout.grips=game.room.layout.grips.duplicate()
	muzzle_wall.update({"aim":Vector2(400,800),"fire":true},0.1)
	check.call(muzzle_wall.snapshot().arrows.is_empty() and muzzle_wall.snapshot().effects.size()==1, "新出箭点仍受肩部到箭尖的实体阻挡检查约束")
	var reference: RefCounted = Room.new()
	reference.player.facing=1
	check.call(reference.grip().is_equal_approx(Vector2(reference.player.x,reference.player.y)+Vector2(24,-48)), "素材标定不污染共享常量和冻结规则参照")
