extends RefCounted

const Room = preload("res://scripts/combat/training_room.gd")

func depart(game: Node2D) -> void:
	if game.room.alpha!=null and game.room.alpha.gameplay: game.room.update({"alpha":{"action":"depart"}},0)

func run(game: Node2D, check: Callable) -> void:
	depart(game)
	check.call(game.atlas.has("upperDown"), "正式场景加载已确认的 v3 向下射箭资源")
	var point: Vector2 = Vector2(game.state.player.x, game.state.player.y)
	var snapshot: Dictionary = game.controls.update(point+Vector2(0,200),true,0)
	game.present(snapshot,0)
	check.call(game.torso.texture==game.textures.get("upperDown"), "向下待机使用新上身")
	check.call(not game.bow.visible and not game.nocked_arrow.visible, "联绘上身不重复叠加旧弓和搭弦箭")
	var phases: Dictionary = {}
	var launch_checked: bool = false
	game.controls.pointer_down(true); game.controls.pointer_up()
	for tick in 36:
		snapshot=game.controls.update(point+Vector2(0,200),true,1.0/60)
		game.present(snapshot,0)
		var phase: int = {"idle":0,"draw":1,"release":2,"recover":3}[snapshot.attack]
		phases[snapshot.attack]=true
		check.call(game.torso.texture==game.textures.get("upperDown") and is_equal_approx(game.torso.region_rect.position.x,phase*543.0), "普通攻击实际时钟映射到新版四阶段")
		check.call(not game.bow.visible and not game.nocked_arrow.visible, "射箭全过程不叠加旧弓箭")
		if snapshot.attack=="draw":
			var visual_tip: Vector2 = game.torso.position+(Vector2(272,650)+game.torso.offset)*game.torso.scale
			check.call(visual_tip.distance_to(snapshot.grip)<0.001, "拉满箭尖与正式出箭点相接")
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
		other.player.facing=facing; other.player.angle=facing*PI/2; other.attack="draw"
		other.grip=Vector2(other.player.x,other.player.y)+Room.GRIPS[facing]
		game.present(other,0)
		check.call(game.torso.texture==game.textures.upper and game.bow.visible and game.nocked_arrow.visible, "其他方向保留原上身和独立弓箭层")
	game.controls.interrupt(); game.room.reset()
	depart(game)
	point=Vector2(game.room.player.x,game.room.player.y)
	game.controls.update(point+Vector2(0,200),true,0)
	for code in [KEY_Q,KEY_E,KEY_SPACE]:
		game.controls.key_down(code)
		snapshot=game.controls.update(point+Vector2(0,40),true,0.01)
		game.present(snapshot,0)
		check.call(game.torso.texture==game.textures.skills and game.bow.visible, "Q／E／闪避继续使用原技能姿态和武器层")
		var expected_grip: Vector2 = Vector2(snapshot.player.x,snapshot.player.y)+Room.SKILL_GRIPS[{KEY_Q:"pierce",KEY_E:"rain",KEY_SPACE:"dodge"}[code]][1]
		check.call(snapshot.grip.is_equal_approx(expected_grip), "技能不使用新的普通箭出箭点")
		game.controls.interrupt(); game.room.reset()
		depart(game)
		game.controls.update(point+Vector2(0,200),true,0)
	game.room.hurt=0.1
	game.present(game.room.snapshot(),0)
	check.call(game.torso.texture==game.textures.skills and game.bow.visible and game.bow.position.is_equal_approx(point+Room.GRIPS[1]), "受击仍使用原技能图及对应旧握点")
	game.room.hurt=0
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
