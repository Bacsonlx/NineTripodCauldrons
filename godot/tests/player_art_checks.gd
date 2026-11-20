extends RefCounted
## 真实正式场景的角色合同；检查身份来源、移动/瞄准组合、接缝和真实发箭。

func depart(game: Node2D) -> void:
	if game.room.alpha!=null and game.room.alpha.gameplay:
		game.room.update({"alpha":{"action":"depart"}},0)

func run(game: Node2D, check: Callable) -> void:
	depart(game)
	var actor: Node2D = game.frame_actor
	check.call(actor.scale.is_equal_approx(Vector2.ONE*(2.0/3.0)),"同一皮影身份保持演员缩放与规则脚点分离")
	var poses: Array = [["idle",0.0,0.0],["draw",0.08,0.3],["draw",0.04,0.3],["draw",0.0,0.3],["release",0.0,0.26],["release",0.0,0.20],["recover",0.0,0.18],["recover",0.0,0.10]]
	var point: Vector2 = Vector2(game.room.player.x,game.room.player.y)
	var keys: Array[int] = [KEY_D,KEY_S,KEY_A,KEY_W]
	var run_data: Dictionary = actor.lower.clips["shadow-run-lower"]
	var run_count: int = int(run_data.perDirection)
	check.call(run_count==8 and int(run_data.movementRows)==1,"新版跑动使用四向各八帧并按移动方向选行")
	var attack_data: Dictionary = actor.upper.clips["shadow-attack-upper"]
	check.call(int(attack_data.perDirection)==8 and not attack_data.semantics.arrowVisible[3*8+3] and String(attack_data.projectileAnnotation[3]).contains("occluded"),"背向箭被遮挡，发射点注明估算")
	check.call(actor.upper.clips["shadow-rain-upper"].reusesAuthoredClip=="shadow-attack-upper","箭雨明确复用普通射箭动作")
	for facing in 4:
		for move in 4:
			game.controls.keys.clear(); game.controls.keys[keys[move]]=true
			for stride in run_count:
				for pose in poses:
					var state: Dictionary = game.room.snapshot()
					state.player.facing=facing; state.player.moving=true
					state.attack=pose[0]; state.windup=pose[1]
					actor.generation=state.runId; actor.previous_point=point
					actor.distance=(stride+0.1)/run_count*actor.STRIDE_WORLD
					game.room.cooldown=pose[2]
					var before: Dictionary = state.duplicate(true)
					game.present(state,0)
					check.call(actor.lower.visible and actor.upper.visible and not game.legs.visible and not game.torso.visible and not game.bow.visible and not game.nocked_arrow.visible,"四向跑射只显示同一新版上下身，不混旧身体或武器")
					var row: int = facing*4+move if int(run_data.get("movementRows",1))==4 else facing if posmod(move-facing,4)==2 else move
					check.call(actor.lower.frame_index/run_count==row and actor.upper.frame_index/int(actor.upper.clips[actor.upper.clip].perDirection)==facing,"移动独立推进步态，反向与侧移保持身体朝向连续")
					check.call(game.visual_connection_delta(actor.upper,actor.lower).length()<0.01,"全部移动方向和攻击阶段的腰点XY连续")
					check.call(state==before,"动画采样不改写规则状态")
	# 四行步态素材由移动方向选行，独立于瞄准；恢复元数据后继续实际素材检查。
	var old_rows: int = int(run_data.get("movementRows",1))
	run_data.movementRows=1
	for facing in 4:
		for move in 4:
			var state: Dictionary = game.room.snapshot()
			state.player.facing=facing; state.player.moving=true
			actor.generation=state.runId; actor.previous_point=point; actor.distance=0.0
			actor.update_state(state,Vector2.from_angle(move*PI/2),0.0)
			var expected_row: int = facing if posmod(move-facing,4)==2 else move
			check.call(actor.lower.frame_index/run_count==expected_row,"反向近似退步，其他方向按移动方向选行")
	run_data.movementRows=old_rows
	for facing in 4:
		var state: Dictionary = game.room.snapshot()
		state.player.facing=facing; state.player.moving=true
		var before: Dictionary = state.duplicate(true)
		for phase in run_count:
			actor.generation=state.runId; actor.previous_point=point
			actor.distance=(phase+0.1)/run_count*actor.STRIDE_WORLD
			actor.update_state(state,Vector2.from_angle(((facing+2)%4)*PI/2),0.0)
			check.call(actor.lower.frame_index==facing*run_count+posmod(-phase,run_count),"四向反向移动完整倒放八帧")
			check.call(actor.lower.waist_world_point().distance_to(actor.upper.waist_world_point())<0.01,"退步近似保持腰点 XY 对接")
			check.call(state==before,"退步采样不改写规则快照")
		var frame_before_pause: int = actor.lower.frame_index
		var distance_before_pause: float = actor.distance
		state.paused=true
		actor.update_state(state,Vector2.from_angle(((facing+2)%4)*PI/2),0.0,0.0,1.0)
		check.call(actor.lower.frame_index==frame_before_pause and actor.distance==distance_before_pause,"反向移动暂停时冻结采样和距离")
	game.controls.interrupt(); game.room.reset(); depart(game)
	for facing in 4:
		var state: Dictionary = game.room.snapshot()
		state.player.facing=facing; state.player.moving=false
		game.present(state,0)
		check.call(actor.upper.clip=="shadow-idle-upper" and actor.lower.clip=="shadow-idle-lower","四向待机均使用确认后的皮影身份")
		check.call(actor.upper.texture.resource_path.begins_with(actor.DIRECTORY) and actor.lower.texture.resource_path.begins_with(actor.DIRECTORY),"人物真实纹理来自新版正式目录")
		state.attack="idle"
		for kind in ["pierce","rain"]:
			for phase in ["windup","active"]:
				state.skill={"kind":kind,"phase":phase,"remaining":0.1}
				game.present(state,0)
				check.call(actor.upper.clip=="shadow-"+kind+"-upper" and actor.upper.frame_index/int(actor.upper.clips[actor.upper.clip].perDirection)==facing,"四向Q/E分别映射自己的前摇与释放，不固定在向下待机帧")
		state.skill=null
		state.hurt=0.1; game.present(state,0)
		if actor.body.clips.has("shadow-hurt-body"):
			check.call(actor.body.visible and actor.body.clip=="shadow-hurt-body" and not actor.upper.visible and not actor.lower.visible,"受击优先使用新绘全身")
		else:
			check.call(actor.upper.clip=="shadow-hurt-upper" and actor.lower.visible,"受击保留同一身体与连接")
		state.hurt=0.0; state.dodge=0.1; game.present(state,0)
		if actor.body.clips.has("shadow-dodge-body"):
			check.call(actor.body.visible and actor.body.clip=="shadow-dodge-body" and not actor.upper.visible and not actor.lower.visible,"闪避优先使用新绘全身")
			state.dodgeDirection=Vector2.from_angle(((facing+1)%4)*PI/2); game.present(state,0)
			check.call(actor.body.frame_index==((facing+1)%4),"闪避全身朝锁定的位移方向")
		else:
			check.call(actor.upper.clip=="shadow-dodge-upper" and actor.lower.clip=="shadow-dodge-lower","四向闪避均有新版上下身，不回退单向整身图")
	game.controls.interrupt(); game.room.reset(); depart(game)
	for facing in 4:
		game.room.reset(); depart(game)
		point=Vector2(game.room.player.x,game.room.player.y)
		var aim: Vector2 = point+Vector2.from_angle(facing*PI/2)*300
		game.controls.update(aim,true,0)
		game.controls.pointer_down(true); game.controls.pointer_up()
		var phases: Dictionary = {}
		var launched: bool = false
		for tick in 36:
			var state: Dictionary = game.controls.update(aim,true,0.01)
			game.present(state,0.01)
			phases[state.attack]=true
			if not state.arrows.is_empty() and not launched:
				var arrow: Dictionary = state.arrows[0]
				var origin: Vector2 = Vector2(arrow.x,arrow.y)-Vector2.from_angle(arrow.angle)*700.0*arrow.age
				check.call(origin.distance_to(state.grip)<0.01,"四向真实箭从规则发射点生成")
				var visible_arrow: Sprite2D = game.arrows[arrow.id]
				check.call(is_equal_approx(visible_arrow.scale.x*visible_arrow.texture.get_width(),actor.projectile_length(arrow.kind,facing)),"飞行箭长使用对应方向的显示尺寸")
				launched=true
		check.call(game.room.shots==1 and phases.size()==4 and launched,"四向真实单次输入均经过四阶段并仅发一箭")
		var grip: Vector2 = point+TrainingRoom.point(game.room.layout.grips[facing])
		var shoulder: Vector2 = point+Vector2(0,-game.room.layout.shoulderHeight)
		var middle: Vector2 = (grip+shoulder)*0.5
		var wall: TrainingRoom = TrainingRoom.new({"spawn":point,"obstacle":Rect2(middle-Vector2(1,1),Vector2(2,2))})
		wall.layout.grips=game.room.layout.grips.duplicate(true)
		wall.layout.shoulderHeight=game.room.layout.shoulderHeight
		wall.update({"aim":aim,"fire":true},0.1)
		check.call(wall.snapshot().arrows.is_empty(),"四向规则发射点仍受肩点到发射点的障碍阻挡")
	game.controls.interrupt(); game.room.reset(); depart(game)
	game.controls.key_down(KEY_D)
	game.present(game.controls.update(point+Vector2(300,-40),true,0.05),0.05)
	var frame: int = actor.lower.frame_index
	var distance: float = actor.distance
	game.present(game.room.snapshot(),0.5)
	check.call(actor.lower.frame_index==frame and actor.distance==distance,"重复快照不会因呈现时间推进步态")
	game.controls.interrupt(true)
	game.present(game.room.snapshot(),1)
	check.call(actor.lower.frame_index==frame and actor.distance==distance,"暂停及失焦冻结角色动作")
	game.room.set_paused(false)
	game.room.status="failed"; game.present(game.room.snapshot(),0)
	check.call(actor.body.visible and actor.body.clip=="shadow-failed" and not actor.upper.visible and not actor.lower.visible and not game.failed.visible and not actor.gear.visible,"失败只显示新版倒地，身体与装备同步切换")
	game.present(game.room.snapshot(),0.4)
	var failed_count: int = int(actor.body.clips["shadow-failed"].perDirection)
	check.call(actor.body.frame_index%failed_count==failed_count-1,"倒地播放至终态，保留同一角色身份")
	game.room.reset(); game.controls.interrupt(); depart(game)
	game.present(game.room.snapshot(),0)
	check.call(actor.distance==0 and actor.upper.visible and not actor.body.visible,"重试清空旧步态与倒地状态")
	for slot in actor.gear.slots:
		if slot in ["feet","weapon"]:
			check.call(not actor.gear.slots[slot].visible,"已联绘的布履与弓不再重复叠加")
