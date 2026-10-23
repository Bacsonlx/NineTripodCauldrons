extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok and not failures.has(message): failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func endpoint(actor: Node2D,part: String) -> Vector2:
	var sprite: Sprite2D = actor.get_node(part)
	return sprite.to_global(sprite.offset+sprite.texture.get_size()*actor.JOINTS[part][1])

func run() -> void:
	var path: String = "res://scripts/presentation/thor_motion_candidate.gd"
	check(ResourceLoader.exists(path),"三招独立候选必须可加载，默认Boss动作不提前替换")
	if not ResourceLoader.exists(path): finish(); return
	var actor: Node2D = load(path).new()
	actor.visual_scale=1.25
	root.add_child(actor)
	for spawn in [Vector2(840,520),Vector2(240,520),Vector2(600,520)]:
		var room: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"spawn":spawn})
		var phases: Dictionary = {}
		var previous_phase: String = ""
		var previous_hammer: Vector2 = Vector2.ZERO
		var transitions: int = 0
		var previous_boots: Array[Vector2] = []
		for frame in 950:
			room.update({"moveY":-0.1} if spawn.x==600 else {},0.01)
			var state: Dictionary = room.snapshot()
			actor.update_state(state)
			var hammer: Vector2 = actor.get_node("hammer").global_position
			if (previous_phase=="throw_warn" and state.boss.phase=="flight") or (previous_phase=="flight" and state.boss.phase=="throw_recover"):
				check(hammer.distance_to(previous_hammer)<18.75,"放大后的离手和接锤不发生脱手瞬移")
				transitions+=1
			var boots: Array[Vector2] = [actor.get_node("far_boot").global_position,actor.get_node("near_boot").global_position]
			if not previous_boots.is_empty():
				for i in 2: check(boots[i].distance_to(previous_boots[i])<6,"跨追近、蓄力及收招时实际脚点连续，不跳回固定站姿")
			previous_boots=boots
			previous_phase=state.boss.phase; previous_hammer=hammer
			if not state.boss.phase in ["swing_warn","swing","swing_recover","throw_warn","flight","throw_recover","lightning"]: continue
			phases[state.boss.phase]=true
			for prefix in ["near","far"]:
				check(endpoint(actor,prefix+"_arm").distance_to(actor.get_node(prefix+"_forearm").global_position)<0.02,"可见肘关节与前臂起点保持连接")
				check(endpoint(actor,prefix+"_thigh").distance_to(actor.get_node(prefix+"_shin").global_position)<0.02,"可见膝关节保持连接")
				check(endpoint(actor,prefix+"_shin").distance_to(actor.get_node(prefix+"_boot").global_position)<0.02,"脚点承重时可见踝关节保持连接")
				var upper: Vector2 = actor.get_node(prefix+"_forearm").global_position-actor.get_node(prefix+"_arm").global_position
				var lower: Vector2 = endpoint(actor,prefix+"_forearm")-actor.get_node(prefix+"_forearm").global_position
				check(absf(upper.length()-37.5)<0.02 and absf(lower.length()-38.75)<0.02,"三招使用固定30／31臂长，放大后仍不拉伸或脱节")
				check(absf(rad_to_deg(upper.angle_to(lower)))<=125,"手肘保持125度以内的有向屈曲，不靠反折手臂换姿势")
				check(upper.cross(lower)<0 if prefix=="near" else upper.cross(lower)>0,"肩肘运动保持同一弯曲方向，不跨奇异点翻肘")
			if not state.vulnerable:
				check(endpoint(actor,"near_forearm").distance_to(actor.get_node("hammer").global_position)<0.02,"持锤握点始终连接到手腕")
			if frame%31==0:
				var transforms: Array = []
				for part in actor.get_children(): transforms.append(part.global_transform)
				room.set_paused(true); room.update({},1); actor.update_state(room.snapshot())
				for i in transforms.size(): check(actor.get_child(i).global_transform==transforms[i],"暂停后完整关节姿态不推进")
				room.set_paused(false)
		check(transitions==2,"完整规则实际覆盖离手与接回两处姿态衔接")
		check(phases.has("throw_warn") and phases.has("flight") and phases.has("throw_recover") and phases.has("lightning"),"真实规则覆盖完整掷锤与落雷候选")
		if spawn.x==840: check(phases.has("swing") and phases.has("swing_recover"),"真实近距规则覆盖完整横锤候选")
	var reset_room: TrainingRoom = load("res://scripts/combat/boss_room.gd").new()
	actor.update_state(reset_room.snapshot())
	var fresh: Node2D = load(path).new(); fresh.visual_scale=1.25; root.add_child(fresh)
	fresh.update_state(reset_room.snapshot())
	for i in actor.get_child_count(): check(actor.get_child(i).global_transform.is_equal_approx(fresh.get_child(i).global_transform),"重开恢复与全新角色一致的关节姿态")
	fresh.free(); actor.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"boss_motion_candidate_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
