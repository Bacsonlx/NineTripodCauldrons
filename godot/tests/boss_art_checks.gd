extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

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
		var binding: Array = actor.JOINTS[prefix+"_arm"]
		var end: Vector2 = upper.to_global(upper.offset+upper.texture.get_size()*binding[1])
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
	var walk: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"spawn":Vector2(600,520)})
	actor.update_state(walk.snapshot())
	var stable_frames: int = 0
	var paused_during_walk: bool = false
	var previous: Dictionary = actor.pose_snapshot()
	var limb_scales: Dictionary = {}
	var previous_boot: Vector2 = Vector2.ZERO
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
	walk.set_paused(true)
	var frozen: Dictionary = actor.pose_snapshot()
	walk.update({},1); actor.update_state(walk.snapshot())
	check(actor.pose_snapshot()==frozen,"暂停不推进骨架步态")
	var hammer: Sprite2D = actor.get_node("hammer")
	var previous_hammer: Vector2 = hammer.global_position
	var transitions: int = 0
	var previous_phase: String = room.snapshot().boss.phase
	for frame in 650:
		room.update({},0.01); actor.update_state(room.snapshot())
		var phase: String = room.snapshot().boss.phase
		if (phase=="flight" and previous_phase=="throw_warn") or (phase=="throw_recover" and previous_phase=="flight"):
			check(hammer.global_position.distance_to(previous_hammer)<15,"飞锤离手和接回连续，不从手部瞬移到脚点")
			transitions+=1
		previous_phase=phase; previous_hammer=hammer.global_position
	check(transitions==2,"真实规则覆盖离手与接回两个衔接")
	actor.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"boss_art_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
