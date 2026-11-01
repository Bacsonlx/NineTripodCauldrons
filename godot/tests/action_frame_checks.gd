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
	check(game.frame_actor.has_node("Lower") and game.frame_actor.has_node("Upper"),"新角色分别提供独立下肢和瞄准上身")
	game.controls.key_down(KEY_D)
	game.present(game.controls.update(target,true,0.05),0.05)
	check(game.frame_actor.lower.visible and game.frame_actor.upper.visible and not game.frame_actor.body.visible and not game.legs.visible and not game.torso.visible,"向右移动且向右瞄准组合新下肢和新上身")
	var frozen_frame: int = game.frame_actor.lower.frame_index
	var frozen_distance: float = game.frame_actor.distance
	check(game.visual_connection_delta(game.frame_actor.upper,game.frame_actor.lower).length()<=0.5,"新上身与新下肢的可见腰线相接")
	game.present(room.snapshot(),0.5)
	check(game.frame_actor.lower.frame_index==frozen_frame and game.frame_actor.distance==frozen_distance,"重复快照不因呈现秒数推进步态")
	game.controls.interrupt(true); game.present(room.snapshot(),1)
	check(game.frame_actor.lower.frame_index==frozen_frame and game.frame_actor.lower.visible,"失焦暂停保留新下肢姿态")
	room.set_paused(false)
	game.controls.key_down(KEY_A); game.controls.pointer_down(true)
	game.present(game.controls.update(target,true,0.02),0.02)
	check(not game.frame_actor.lower.visible and game.frame_actor.upper.visible and game.legs.visible and not game.torso.visible and game.state.player.facing==0,"向左移动配向右射击组合旧左下肢与新右上身")
	check(game.visual_connection_delta(game.frame_actor.upper,game.legs).length()<=0.5,"新上身与旧反向下肢的可见腰线相接")
	for angle in [PI/2,PI,-PI/2]:
		game.controls.interrupt(); room.reset()
		var aim: Vector2 = Vector2(room.player.x,room.player.y-52)+Vector2.from_angle(angle)*250
		game.controls.update(aim,true,0.001); game.controls.key_down(KEY_D)
		game.present(game.controls.update(aim,true,0.02),0.02)
		check(game.frame_actor.lower.visible and not game.legs.visible and (game.torso.visible if game.state.player.facing==1 else game.frame_actor.upper.visible and not game.torso.visible),"右向移动独立搭配各瞄准方向的统一上身")
		var top: Sprite2D = game.torso if game.state.player.facing==1 else game.frame_actor.upper
		check(game.state.player.facing!=0 and game.visual_connection_delta(top,game.frame_actor.lower).length()<=0.5,"四向上身与新下肢的可见腰线相接，鼠标朝向保持独立")
	game.controls.interrupt(); room.reset(); game.controls.update(target,true,0.001)
	var seen: Dictionary = {}
	game.controls.pointer_down(true); game.controls.pointer_up()
	for i in 35:
		game.present(game.controls.update(target,true,0.01),0.01)
		check(game.frame_actor.upper.visible and not game.frame_actor.lower.visible and game.legs.visible and not game.bow.visible and not game.nocked_arrow.visible,"原地射箭使用新上身和旧站立下肢，只显示一套武器")
		seen[game.frame_actor.upper.frame_index]=true
	check(seen.size()==8 and room.shots==1,"一次真实点射按原时钟采样8个上身姿态且只生成一箭")
	for key in [KEY_Q,KEY_E,KEY_SPACE]:
		game.controls.interrupt(); room.reset(); game.controls.update(target,true,0.001)
		game.controls.key_down(KEY_D); game.controls.key_down(key)
		game.present(game.controls.update(target,true,0.02),0.02)
		if key==KEY_SPACE:
			check(game.frame_actor.body.visible and not game.frame_actor.lower.visible and not game.frame_actor.upper.visible,"右向闪避沿用新完整姿态，暂时覆盖上下身")
			game.present(game.controls.update(target,true,0.02),0.02)
			check(game.combat_effects.ghosts.any(func(ghost: Dictionary): return ghost.lower.visible and ghost.lower.texture==game.frame_actor.body.texture and not ghost.upper.visible and ghost.lower.global_position.distance_to(game.frame_actor.body.global_position)<20),"闪避残影复制新全身姿态及世界位置，不叠旧上身")
		else:
			check(game.frame_actor.lower.visible and game.frame_actor.upper.visible and game.frame_actor.upper.clip=="hero-skills-upper","移动中Q/E分别组合新下肢与新技能上身")
			check((game.frame_actor.upper.frame_index>=4)==(key==KEY_E),"Q/E从同图集各自四帧区间取样")
	room.status="failed"; game.present(room.snapshot(),0)
	check(not game.frame_actor.lower.visible and not game.frame_actor.upper.visible and not game.frame_actor.body.visible and game.failed.visible,"失败隐藏全部新层并沿用既有失败素材")
	room.reset(); game.controls.interrupt(); game.present(game.controls.update(target,true,0),0)
	check(game.frame_actor.upper.visible and game.frame_actor.distance==0 and game.frame_actor.upper.frame_index==0,"重试归零步态并回到新待机上身")
	game.free()

# 量取腰点中央40单位内的不透明身体，排除独立弓及远端披风。
# 上身自然姿态的冠顶到腰线应为44—57单位；包括既有四向的透视差异。
var crown_cache: Dictionary = {}

func crown_height(sprite: Sprite2D) -> float:
	var key: String = str([sprite.texture.resource_path,sprite.region_rect,sprite.offset,sprite.scale])
	if crown_cache.has(key): return crown_cache[key]
	var image: Image = sprite.texture.get_image().get_region(Rect2i(sprite.region_rect))
	var start: int = maxi(0,floori(-sprite.offset.x-20.0/sprite.scale.x))
	var end: int = mini(image.get_width(),ceili(-sprite.offset.x+20.0/sprite.scale.x))
	var top: int = 0
	var bottom: int = image.get_height()
	if sprite.get_script()==preload("res://scripts/presentation/action_frame_sprite.gd"):
		var data: Dictionary = sprite.clips[sprite.clip]
		if data.has("head_rects"):
			var box: Array = data.head_rects[sprite.frame_index]
			start=maxi(start,int(box[0])); end=mini(end,int(box[0]+box[2]))
			top=int(box[1]); bottom=int(box[1]+box[3])
	for y in range(top,bottom):
		for x in range(start,end):
			if image.get_pixel(x,y).a>=0.5:
				var rendered_scale: float = sprite.global_transform.y.length()
				var height: float = -(sprite.offset.y+y)*rendered_scale
				crown_cache[key]=height
				return height
	return 0.0

func direction_size_checks() -> void:
	var game: Node2D = load("res://scenes/sample.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	# 从真实场景入口选层，覆盖8个新射箭姿态、4向瞄准、4向移动和旧腿6相。
	var poses: Array = [["idle",0.0,0.0],["draw",0.08,0.3],["draw",0.04,0.3],["draw",0.0,0.3],["release",0.0,0.26],["release",0.0,0.2],["recover",0.0,0.18],["recover",0.0,0.1]]
	var heights: Array = []
	for pose in poses:
		var smallest: float = INF
		var largest: float = 0.0
		for move in [KEY_D,KEY_S,KEY_A,KEY_W]:
			game.controls.interrupt(); game.room.reset(); game.controls.key_down(move)
			for facing in 4:
				for step in 6:
					var state: Dictionary = game.room.snapshot()
					state.player.facing=facing; state.player.moving=true
					state.player.x+=step*22; state.attack=pose[0]; state.windup=pose[1]
					game.room.cooldown=pose[2]; game.walk_time=step/12.0
					game.present(state,0)
					var upper: Sprite2D = game.frame_actor.upper if game.frame_actor.upper.visible else game.torso
					var height: float = crown_height(upper)
					check(height>=29.0 and height<=38.0,"转向及跑射保持缩小后的上身身体尺度，朝向%d/%s：%.2f" % [facing,pose[0],height])
					smallest=minf(smallest,height+20); largest=maxf(largest,height+20)
		check(largest/smallest<=1.16,"同一射箭阶段各移动与瞄准方向的冠顶至脚点高度差不超过16%")
		heights.append({"phase":pose[0],"min":smallest,"max":largest})
	print(JSON.stringify({"direction_size_world_units":heights}))
	game.free()

func identity_family_checks() -> void:
	var game: Node2D = load("res://scenes/sample.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	var neutral: Array = []
	for facing in 4:
		game.controls.interrupt(); game.room.reset()
		var state: Dictionary = game.room.snapshot()
		state.player.facing=facing; state.player.moving=false
		game.present(state,0)
		var upper: Sprite2D = game.frame_actor.body if facing==3 and game.frame_actor.body.visible else game.frame_actor.upper if game.frame_actor.upper.visible else game.torso
		var height: float = crown_height(upper)
		neutral.append(height)
		# 已确认向下源图的冠顶到腰线55.56；本轮视觉缩放为三分之二。
		if facing==3:
			check(height>=40.0 and height<=49.0,"背面完整身保持注册后的总高度，朝向%d：%.2f" % [facing,height])
			check(game.frame_actor.body.visible and game.frame_actor.body.clip=="hero-back-full" and not game.frame_actor.upper.visible and not game.frame_actor.head.visible,"背向中立使用完整身背面资产，避免上下身切割")
		elif facing==2:
			check(absf(height-55.56*2.0/3.0)<=2.0,"四向中立身体保持缩小后的母图比例，朝向%d：%.2f" % [facing,height])
			check(game.frame_actor.upper.visible and not game.torso.visible and not game.bow.visible and not game.nocked_arrow.visible,"左／上使用统一身份的联绘上身，避免混入旧侧面造型或重复武器")
		else:
			check(absf(height-55.56*2.0/3.0)<=2.0,"四向中立身体保持缩小后的母图比例，朝向%d：%.2f" % [facing,height])
		var transform: Transform2D = upper.transform
		game.room.set_paused(true); state=game.room.snapshot(); state.player.facing=facing
		game.present(state,1)
		check(upper.transform==transform,"四向暂停不因呈现时间改变身体注册")
		game.room.set_paused(false)
	print(JSON.stringify({"identity_neutral_crown_to_waist":neutral}))
	for facing in [0,2,3]:
		game.controls.interrupt(); game.room.reset()
		var point: Vector2 = Vector2(game.room.player.x,game.room.player.y)
		var target: Vector2 = point+Vector2(0,-52)+Vector2.from_angle(facing*PI/2)*300
		game.controls.update(target,true,0)
		game.controls.pointer_down(true); game.controls.pointer_up()
		var checked: bool = false
		for tick in 35:
			var state: Dictionary = game.controls.update(target,true,0.01)
			game.present(state,0)
			var upper: Sprite2D = game.frame_actor.upper
			if state.attack=="draw" and upper.frame_index==int(upper.clips[upper.clip].muzzle_frame):
				var data: Dictionary = upper.clips[upper.clip]
				var tip: Vector2 = Vector2(data.muzzle_px[0],data.muzzle_px[1])
				var expected_rule_grip: Vector2 = Vector2(game.room.player.x,game.room.player.y)+Vector2(data.grip.x,data.grip.y)
				var expected_visual_grip: Vector2 = Vector2(game.room.player.x,game.room.player.y)+Vector2(data.grip.x,data.grip.y)*2.0/3.0
				check(state.grip.is_equal_approx(expected_rule_grip),"四向普通箭规则握点保持既有坐标与稳定性")
				check((upper.global_transform*(upper.offset+tip)).distance_to(expected_visual_grip)<6.0,"普通箭视觉拉满帧箭尖随人物按三分之二比例稳定呈现")
			if not state.arrows.is_empty() and not checked:
				var arrow: Dictionary = state.arrows[0]
				var origin: Vector2 = Vector2(arrow.x,arrow.y)-Vector2.from_angle(arrow.angle)*700*arrow.age
				check(origin.distance_to(state.grip)<0.001,"四向实际普通箭按已标定起点发出，非仅移动显示")
				checked=true
		check(checked and game.room.shots==1,"每个修订方向一次真实点射仍只生成一支箭")
		var grip: Vector2 = game.room.grip()-Vector2(game.room.player.x,game.room.player.y)
		var shoulder: Vector2 = Vector2(0,-52)
		var center: Vector2 = Vector2(400,600)+(shoulder+grip)/2
		var blocked: TrainingRoom = load("res://scripts/combat/training_room.gd").new({"obstacle":Rect2(center-Vector2(2,2),Vector2(4,4))})
		blocked.layout.grips=game.room.layout.grips.duplicate()
		blocked.update({"aim":Vector2(400,548)+Vector2.from_angle(facing*PI/2)*300,"fire":true},0.1)
		check(blocked.snapshot().arrows.is_empty(),"新箭尖注册仍经过肩部到出箭点阻挡检查")
	for facing in 4:
		for key in [KEY_Q,KEY_E,KEY_SPACE]:
			game.controls.interrupt(); game.room.reset()
			var point: Vector2 = Vector2(game.room.player.x,game.room.player.y)
			var target: Vector2 = point+Vector2(0,-52)+Vector2.from_angle(facing*PI/2)*180
			game.controls.update(target,true,0)
			game.controls.key_down([KEY_D,KEY_S,KEY_A,KEY_W][facing] if key==KEY_SPACE else KEY_D)
			game.controls.key_down(key)
			var state: Dictionary = game.controls.update(target,true,0.02)
			game.present(state,0.02)
			check((state.dodge>0 if key==KEY_SPACE else state.skill!=null) and state.player.facing==facing,"四向技能对照使用实际生效的技能与合法目标")
			check((game.frame_actor.upper.visible or game.frame_actor.body.visible) and not game.torso.visible and not game.bow.visible and not game.nocked_arrow.visible,"四向技能／闪避持弓与身体联绘，无旧层悬空弓箭")
			if facing==3 and key==KEY_Q:
				check(game.frame_actor.upper.clip=="hero-archery-up" and game.frame_actor.upper.frame_index==1,"背向Q复用真正朝上的拉满姿态，拒绝朝右的候选")
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
	direction_size_checks()
	identity_family_checks()
	boss_checks()
	print(JSON.stringify({"action_frame_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
