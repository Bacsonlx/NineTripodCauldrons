extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func transforms(actor: Node) -> Array:
	var result: Array = []
	for child in actor.get_children():
		if child is Node2D: result.append(child.transform)
		result.append_array(transforms(child))
	return result

func endpoint(actor: Node,path: String,uv: Vector2) -> Vector2:
	var art: Sprite2D = actor.get_node(path+"/Art")
	return art.to_global(art.offset+art.texture.get_size()*uv)

func run() -> void:
	var path: String = "res://scenes/prototypes/thor_rig_pilot.tscn"
	check(ResourceLoader.exists(path),"可加载独立、持久化的关节候选")
	if not ResourceLoader.exists(path): finish(); return
	var actor: Node2D = load(path).instantiate()
	root.add_child(actor)
	await process_frame
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	check(player.has_animation("idle") and player.has_animation("swing"),"保存待机与完整横锤片段")
	check(is_equal_approx(player.get_animation("swing").length,1.92),"横锤长度保持0.8前摇+0.12挥击+1.0收招")
	var Room: Script = load("res://scripts/combat/boss_room.gd")
	var room: TrainingRoom = Room.new({"spawn":Vector2(840,520)})
	var rest: Dictionary = room.snapshot()
	actor.update_state(rest)
	var initial: Array = transforms(actor)
	var grip: Node2D = actor.get_node("pelvis/chest/near_arm/near_forearm/hammer")
	var shoulder: Node2D = grip.get_parent().get_parent()
	var elbow: Node2D = grip.get_parent()
	var foot: Node2D = actor.get_node("pelvis/near_thigh/near_shin/near_boot")
	var planted: Vector2 = foot.position
	for seconds in [0.0,0.3,0.62,0.8,0.84,0.88,0.92,1.08,1.4,1.92]:
		actor.sample(&"swing",seconds)
		check(is_equal_approx(shoulder.global_position.distance_to(elbow.global_position),30.0),"片段不拉伸上臂")
		check(is_equal_approx(elbow.global_position.distance_to(grip.global_position),31.0),"锤握点跟随前臂，固定31单位")
		check(foot.position.is_equal_approx(planted),"横锤不移动脚部枢轴")
		for side in ["near","far"]:
			var upper_path: String = "pelvis/chest/"+side+"_arm"
			var arm_end: Vector2 = Vector2(0.25,0.78) if side=="near" else Vector2(0.72,0.81)
			check(endpoint(actor,upper_path,arm_end).distance_to(actor.get_node(upper_path+"/"+side+"_forearm").global_position)<0.01,"图片上臂末端与前臂枢轴重合")
			var thigh_path: String = "pelvis/"+side+"_thigh"
			var thigh_end: Vector2 = Vector2(0.50,0.76) if side=="near" else Vector2(0.56,0.76)
			var shin_path: String = thigh_path+"/"+side+"_shin"
			check(endpoint(actor,thigh_path,thigh_end).distance_to(actor.get_node(shin_path).global_position)<0.01,"图片大腿末端与小腿枢轴重合")
			var shin_end: Vector2 = Vector2(0.50,0.83) if side=="near" else Vector2(0.50,0.84)
			check(endpoint(actor,shin_path,shin_end).distance_to(actor.get_node(shin_path+"/"+side+"_boot").global_position)<0.01,"图片小腿末端与靴子枢轴重合")
		check(endpoint(actor,"pelvis/chest/near_arm/near_forearm",Vector2(0.83,0.85)).distance_to(grip.global_position)<0.01,"图片持锤手末端与锤握点重合")
		var pose: Array = transforms(actor)
		actor.sample(&"idle",1.3)
		actor.sample(&"swing",seconds)
		check(transforms(actor)==pose,"随机顺序采样得到相同姿势")
	actor.update_state(rest)
	check(transforms(actor)==initial,"从挥击直接重开恢复待机全部关节")
	room.update({},2.04)
	actor.update_state(room.snapshot())
	check(room.snapshot().boss.phase=="swing","真实规则已进入挥击")
	var frozen: Array = transforms(actor)
	room.set_paused(true); room.update({},1.0); actor.update_state(room.snapshot())
	check(transforms(actor)==frozen,"挥击中规则暂停，动画完全冻结")
	actor.update_state(room.snapshot())
	check(transforms(actor)==frozen,"重复快照不推进动画")
	var dead: Dictionary = room.snapshot()
	dead.boss.phase="dead"; dead.boss.health=0
	actor.update_state(dead)
	check(player.assigned_animation==&"idle" and is_zero_approx(player.current_animation_position),"死亡立即中断横锤并采用静态占位；未制作败退片段")
	var fresh: Node2D = load(path).instantiate()
	root.add_child(fresh)
	fresh.update_state(rest)
	actor.update_state(rest)
	check(transforms(actor)==transforms(fresh),"重开结果与全新实例一致")
	actor.free(); fresh.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"thor_rig_pilot_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
