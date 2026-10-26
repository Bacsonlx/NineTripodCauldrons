extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func joint_point(actor: Node2D,part: String) -> Vector2:
	var sprite: Sprite2D = actor.get_node(part)
	return sprite.to_global(sprite.offset+sprite.texture.get_size()*actor.JOINTS[part][1])

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var source: Script = load("res://scripts/presentation/thor_puppet.gd")
	check(source!=null,"实际美术候选必须提供可加载的皮影角色")
	if source==null: finish(); return
	var actor: Node2D = source.new()
	root.add_child(actor)
	await process_frame
	var room: TrainingRoom = load("res://scripts/combat/boss_room.gd").new()
	actor.update_state(room.snapshot())
	check(actor.get_child_count()>=16,"角色使用独立头身、四肢、布带与重锤组件")
	for prefix in ["near","far"]:
		var upper: Sprite2D = actor.get_node(prefix+"_arm")
		var end: Vector2 = joint_point(actor,prefix+"_arm")
		check(absf((end-upper.global_position).angle_to(Vector2.DOWN))<deg_to_rad(30),"站姿上臂放松下垂，不再大幅外架")
		var thigh: Sprite2D = actor.get_node(prefix+"_thigh")
		var shin: Sprite2D = actor.get_node(prefix+"_shin")
		var ankle: Vector2 = actor.get_node(prefix+"_boot").global_position
		var upper_direction: Vector2 = shin.global_position-thigh.global_position
		var lower_direction: Vector2 = ankle-shin.global_position
		check(absf(upper_direction.angle_to(lower_direction))<deg_to_rad(50),"站姿膝盖轻屈，避免深蹲侧折")
	var initial: Dictionary = actor.pose_snapshot()
	actor.update_state(room.snapshot())
	check(actor.pose_snapshot()==initial,"相同规则快照重复呈现不推进步态或布带")
	var head: Sprite2D = actor.get_node("head")
	var foot: Sprite2D = actor.get_node("near_boot")
	var height: float = foot.position.y+(foot.texture.get_height()+foot.offset.y)*foot.scale.y-head.position.y-head.offset.y*head.scale.y
	check(absf(height-182)<3,"Boss头顶至脚底为孩子约两倍，目标182世界单位，实际%.2f" % height)
	var waist: Sprite2D = actor.get_node("pelvis")
	var sole: float = foot.position.y+(foot.texture.get_height()+foot.offset.y)*foot.scale.y
	var lower_ratio: float = (sole-waist.position.y)/height
	check(lower_ratio>=0.52 and lower_ratio<=0.56,"腰线至脚底占总高0.52至0.56，避免上长下短，实际%.3f" % lower_ratio)
	var walk: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"spawn":Vector2(720,200)})
	actor.update_state(walk.snapshot())
	var stable_frames: int = 0
	var paused_during_walk: bool = false
	var previous: Dictionary = actor.pose_snapshot()
	var limb_scales: Dictionary = {}
	var previous_boot: Vector2 = Vector2.ZERO
	var arm_swing_min: float = INF
	var arm_swing_max: float = -INF
	var cape_walk_min: float = INF
	var cape_walk_max: float = -INF
	var last_plant: Vector2 = Vector2.ZERO
	var plant_distance: float = 0
	var moving_streak: int = 0
	for frame in 600:
		walk.update({"moveY":-0.1},0.01)
		actor.update_state(walk.snapshot())
		var pose: Dictionary = actor.pose_snapshot()
		for part in actor.JOINTS:
			var sprite: Sprite2D = actor.get_node(part)
			if not limb_scales.has(part): limb_scales[part]=sprite.scale
			check(sprite.scale.is_equal_approx(limb_scales[part]),"肢体固定骨长，不能依靠拉伸图片连接关节")
		for prefix in ["near","far"]:
			var thigh: Sprite2D = actor.get_node(prefix+"_thigh")
			var shin: Sprite2D = actor.get_node(prefix+"_shin")
			var boot: Sprite2D = actor.get_node(prefix+"_boot")
			var knee_point: Vector2 = thigh.to_global(thigh.offset+thigh.texture.get_size()*actor.JOINTS[prefix+"_thigh"][1])
			var ankle_point: Vector2 = shin.to_global(shin.offset+shin.texture.get_size()*actor.JOINTS[prefix+"_shin"][1])
			check(knee_point.distance_to(shin.global_position)<0.01,"可见膝关节连接点必须重合")
			check(ankle_point.distance_to(boot.global_position)<0.01,"可见踝关节连接点必须重合")
		if pose.moving or previous.moving:
			for index in 2: check(pose.feet[index].distance_to(previous.feet[index])<6,"落脚轨迹连续，10ms采样不出现超限跳变")
		if pose.moving and previous.moving and pose.lift[0]==0 and previous.lift[0]==0:
			check(pose.feet[0].distance_to(previous.feet[0])<0.001,"行走支撑脚固定世界接触点，不随身体滑动")
			var boot: Sprite2D = actor.get_node("far_boot")
			check(boot.global_position.distance_to(previous_boot)<0.01,"固定骨长后实际渲染支撑脚也不能滑动")
			stable_frames+=1
		moving_streak=moving_streak+1 if pose.moving else 0
		if moving_streak>20:
			var chest_node: Sprite2D = actor.get_node("chest")
			var free_hand: Vector2 = joint_point(actor,"far_forearm")
			var relative: float = (free_hand-chest_node.global_position).y
			arm_swing_min=minf(arm_swing_min,relative)
			arm_swing_max=maxf(arm_swing_max,relative)
			var cape_rotation: float = actor.get_node("cape").rotation
			cape_walk_min=minf(cape_walk_min,cape_rotation)
			cape_walk_max=maxf(cape_walk_max,cape_rotation)
			if previous.lift[1]>0 and pose.lift[1]==0:
				if last_plant!=Vector2.ZERO: plant_distance=last_plant.distance_to(pose.feet[1])
				last_plant=pose.feet[1]
		if pose.moving and not paused_during_walk:
			paused_during_walk=true
			var transforms: Array = []
			for part in actor.get_children(): transforms.append(part.transform)
			actor.update_state(walk.snapshot())
			check(actor.pose_snapshot()==pose,"行走快照重复呈现保持完整步态")
			walk.set_paused(true); walk.update({},1); actor.update_state(walk.snapshot())
			check(actor.pose_snapshot()==pose,"行走中暂停冻结抬脚和移动状态")
			for index in transforms.size(): check(actor.get_child(index).transform==transforms[index],"行走中暂停不重算关节姿态")
			walk.set_paused(false)
		previous_boot=actor.get_node("far_boot").global_position
		previous=pose
	check(stable_frames>5,"真实追近位移覆盖多个支撑脚采样")
	check(arm_swing_max-arm_swing_min>8,"行走时自由手相对躯干沿移动方向摆动，峰谷超过8世界单位，实际%.2f" % (arm_swing_max-arm_swing_min))
	check(plant_distance>55,"同侧脚相邻落点间距反映放开后的步幅，实际%.2f" % plant_distance)
	check(cape_walk_max-cape_walk_min>0.09,"披风摆幅随移动速度放大，实际%.3f" % (cape_walk_max-cape_walk_min))
	walk.set_paused(true)
	var frozen: Dictionary = actor.pose_snapshot()
	walk.update({},1); actor.update_state(walk.snapshot())
	check(actor.pose_snapshot()==frozen,"暂停不推进骨架步态")
	var hammer: Sprite2D = actor.get_node("hammer")
	var previous_hammer: Vector2 = hammer.global_position
	var transitions: int = 0
	var previous_phase: String = room.snapshot().boss.phase
	for frame in 1500:
		room.update({},0.01); actor.update_state(room.snapshot())
		var phase: String = room.snapshot().boss.phase
		if (phase=="flight" and previous_phase=="throw_warn") or (phase=="throw_recover" and previous_phase=="flight"):
			check(hammer.global_position.distance_to(previous_hammer)<15,"飞锤离手和接回连续，不从手部瞬移到脚点")
			transitions+=1
		previous_phase=phase; previous_hammer=hammer.global_position
		if transitions==2: break
	check(transitions==2,"真实规则覆盖离手与接回两个衔接")
	var close: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"spawn":Vector2(840,520)})
	var charge_torso: float = 0
	var strike_torso: float = 0
	var swing_path: Array[Vector2] = []
	var swing_cycles: int = 0
	var close_phase: String = ""
	var paused_during_swing: bool = false
	for frame in 500:
		close.update({},0.01); actor.update_state(close.snapshot())
		var phase: String = close.snapshot().boss.phase
		if phase=="swing" and not paused_during_swing:
			paused_during_swing=true
			var frozen_pose: Dictionary = actor.pose_snapshot()
			var transforms: Array = []
			for part_node in actor.get_children(): transforms.append(part_node.transform)
			close.set_paused(true); close.update({},1); actor.update_state(close.snapshot())
			check(actor.pose_snapshot()==frozen_pose,"横锤挥出中暂停冻结姿态与停顿推进")
			for index in transforms.size(): check(actor.get_child(index).transform==transforms[index],"横锤挥出中暂停不重算关节姿态")
			close.set_paused(false)
		if phase=="swing_warn": charge_torso=minf(charge_torso,actor.get_node("chest").rotation)
		if phase=="swing":
			strike_torso=maxf(strike_torso,actor.get_node("chest").rotation)
			swing_path.append(joint_point(actor,"near_forearm"))
		if phase=="swing" and close_phase!="swing": swing_cycles+=1
		close_phase=phase
	check(swing_cycles>=1,"近距夹具覆盖至少一轮横锤循环，实际%d" % swing_cycles)
	check(charge_torso<-0.22,"横锤蓄力时躯干后旋超过14度，实际%.3f" % charge_torso)
	check(strike_torso>0.2,"横锤挥出时躯干送髋前旋超过11度，实际%.3f" % strike_torso)
	if swing_path.size()>2:
		var chord_vec: Vector2 = swing_path[swing_path.size()-1]-swing_path[0]
		var chord_len: float = maxf(chord_vec.length(),0.001)
		var max_dev: float = 0
		for point in swing_path: max_dev=maxf(max_dev,absf((point-swing_path[0]).cross(chord_vec))/chord_len)
		check(max_dev>8,"挥击手轨迹为过顶弧线而非直线拉扯，最大弦偏离%.2f" % max_dev)
	else:
		check(false,"真实规则覆盖横锤挥出相用于弧线采样")
	actor.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"boss_art_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
