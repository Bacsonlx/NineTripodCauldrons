extends "res://scripts/presentation/thor_puppet.gd"
## 独立三招候选：关键姿势以承重脚、骨盆、胸肩、肘腕顺序组织，不改变规则。

var attack_ground: Array[Vector2] = []
var entering_lift: Array = []
var attack_start: float = 0
var ankles: Array[Vector2] = []
var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/boss/thor-motion-v6/poses.json")).clips

func sample_pose(clip: String,seconds: float) -> Dictionary:
	var keys: Array = clips[clip]
	var first: Dictionary = keys[0]
	var last: Dictionary = keys[-1]
	for i in range(1,keys.size()):
		if seconds<=keys[i].t:
			first=keys[i-1]; last=keys[i]; break
	var weight: float = smoothstep(0,1,clampf((seconds-first.t)/maxf(0.001,last.t-first.t),0,1))
	var result: Dictionary = {}
	for field in ["pelvis","torso","hammer"]: result[field]=lerpf(first[field],last[field],weight)
	for field in ["hip","near","far"]:
		result[field]=Vector2(first[field][0],first[field][1]).lerp(Vector2(last[field][0],last[field][1]),weight)
	return result

func pose_for(state: Dictionary) -> Dictionary:
	var boss: Dictionary = state.boss
	match boss.phase:
		"swing_warn": return sample_pose("swing",0.8-boss.timer)
		"swing": return sample_pose("swing",0.92-boss.timer)
		"swing_recover": return sample_pose("swing",1.92-boss.timer)
		"throw_warn": return sample_pose("load",1-boss.timer)
		"flight":
			var duration: float = state.hammer.origin.distance_to(state.hammer.target)/500+state.hammer.origin.distance_to(state.hammer.target)/650
			var pose: Dictionary = sample_pose("flight",duration-boss.timer)
			if boss.timer<0.2:
				var target: Dictionary = sample_pose("catch",0)
				var weight: float = smoothstep(0,1,1-boss.timer/0.2)
				for field in pose: pose[field]=lerp(pose[field],target[field],weight)
			return pose
		"throw_recover": return sample_pose("catch",0.8-boss.timer)
		"lightning": return sample_pose("lightning",4-boss.timer)
	return {}

func hand_position(pose: Dictionary) -> Vector2:
	var hip: Vector2 = Vector2(0,-83)+pose.hip
	var chest: Vector2 = hip+Vector2(0,-33).rotated(deg_to_rad(pose.pelvis))
	var shoulder: Vector2 = chest+Vector2(-23,-19).rotated(deg_to_rad(pose.torso))
	return shoulder+Vector2.from_angle(deg_to_rad(pose.near.x+pose.torso))*30+Vector2.from_angle(deg_to_rad(pose.near.y+pose.torso))*31

func ground_pose(pose: Dictionary) -> Dictionary:
	var hip: Vector2 = Vector2(0,-83)+pose.hip
	var settle: float = 0
	for i in 2:
		var offset: Vector2 = (Vector2(-12,-5) if i==0 else Vector2(12,2)).rotated(deg_to_rad(pose.pelvis))
		var reach: float = sqrt(maxf(1,74.8*74.8-pow(ankles[i].x-hip.x-offset.x,2)))
		settle=maxf(settle,ankles[i].y-reach-hip.y-offset.y)
	pose.hip.y+=settle
	return pose

func update_state(snapshot: Dictionary) -> void:
	var restart: bool = generation!=snapshot.runId or snapshot.elapsed<previous_time
	var previous_ankles: Array[Vector2] = []
	var previous_lift: Array = lift.duplicate()
	if not restart:
		for prefix in ["far","near"]: previous_ankles.append(pieces[prefix+"_boot"].global_position)
	super.update_state(snapshot)
	var pose: Dictionary = pose_for(snapshot)
	if restart: attack_ground.clear()
	if pose.is_empty(): attack_ground.clear(); return
	if attack_ground.is_empty():
		attack_start=snapshot.elapsed
		entering_lift=previous_lift if not restart else [0.0,0.0]
		for i in 2:
			var prefix: String = "far" if i==0 else "near"
			var point: Vector2 = previous_ankles[i] if not restart else pieces[prefix+"_boot"].global_position
			attack_ground.append(point+Vector2(0,entering_lift[i]*visual_scale))
	ankles.clear()
	for i in 2:
		var remaining: float = entering_lift[i]*(1-smoothstep(0,0.12,snapshot.elapsed-attack_start))
		ankles.append((attack_ground[i]-position)/visual_scale-Vector2(0,remaining))
		# 与现有步态共享落地锚点，收招后恢复追近也不能跳回中立脚位。
		feet[i]=attack_ground[i]/visual_scale+Vector2(0,14)
		planted[i]=feet[i]; lift[i]=remaining; previous_swing[i]=false
	pose=ground_pose(pose)
	var hip: Vector2 = Vector2(0,-83)+pose.hip
	var pelvis_angle: float = deg_to_rad(pose.pelvis)
	var torso: float = deg_to_rad(pose.torso)
	var chest: Vector2 = hip+Vector2(0,-33).rotated(pelvis_angle)
	# 两脚钉在地面，重心转移由压膝和骨盆移动承担，肢体始终固定长度。
	for i in 2:
		var prefix: String = "far" if i==0 else "near"
		var ankle: Vector2 = ankles[i]
		var joint: Vector2 = hip+(Vector2(-12,-5) if i==0 else Vector2(12,2)).rotated(pelvis_angle)
		var middle: Vector2 = knee(joint,ankle)
		limb(prefix+"_thigh",joint,middle); limb(prefix+"_shin",middle,ankle)
		piece(prefix+"_boot",ankle,23,Vector2(0.38,0.18))
	piece("cape",chest+Vector2(-10,-5).rotated(torso),87,Vector2(0.5,0.1),0.12-torso*0.5)
	piece("pelvis",hip+Vector2(0,-5),38,Vector2(0.5,0.15),pelvis_angle)
	piece("chest",chest,56,Vector2(0.5,0.5),torso)
	piece("head",chest+Vector2(7,-25).rotated(torso),40,Vector2(0.5,0.78),torso*0.3)
	piece("tail",hip+Vector2(15,-10).rotated(pelvis_angle),48,Vector2(0.5,0.05),-pelvis_angle*0.6)
	for prefix in ["near","far"]:
		var shoulder: Vector2 = chest+(Vector2(-23,-19) if prefix=="near" else Vector2(23,-19)).rotated(torso)
		var angles: Vector2 = pose[prefix]+Vector2.ONE*pose.torso
		var elbow: Vector2 = shoulder+Vector2.from_angle(deg_to_rad(angles.x))*30
		var hand: Vector2 = elbow+Vector2.from_angle(deg_to_rad(angles.y))*31
		limb(prefix+"_arm",shoulder,elbow); limb(prefix+"_forearm",elbow,hand)
		if prefix=="far": pieces.far_forearm.scale*=31.0/39.0
	var hand: Vector2 = hand_position(pose)
	if snapshot.vulnerable:
		var span: float = snapshot.hammer.origin.distance_to(snapshot.hammer.target)
		var progress: float = clampf(1-snapshot.boss.timer/(span/500+span/650),0,1)
		var offset: Vector2 = hand_position(ground_pose(sample_pose("load",1))).lerp(hand_position(ground_pose(sample_pose("catch",0))),progress)-Vector2(0,sin(progress*PI)*22)
		var ground: Vector2 = (Vector2(snapshot.hammer.x,snapshot.hammer.y)-position)/visual_scale
		piece("hammer",ground+offset,54,Vector2(0.5,0.78),deg_to_rad(70)+progress*TAU*2)
		pieces.hammer.z_as_relative=false; pieces.hammer.z_index=int(snapshot.hammer.y)+2
	else:
		piece("hammer",hand,54,Vector2(0.5,0.78),deg_to_rad(pose.hammer))
		pieces.hammer.z_as_relative=true; pieces.hammer.z_index=0
		held_hand=hand
