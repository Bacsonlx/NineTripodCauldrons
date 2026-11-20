extends RefCounted
## 跑动细节探针：验证四向跑动确实走新素材、逐帧腰点转换及上下身接缝、不混用旧画风。
## 用空白训练场而非关卡地图，避免地形边界把角色卡住而测不到跑动分支。

const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")

func run(game: Node2D, check: Callable) -> void:
	var probe_lines: Array[String] = []
	var room: TrainingRoom = Room.new()
	var controls: PlayerControls = Controls.new(room)
	var actor: Node2D = load("res://scripts/presentation/player_frame_actor.gd").new()
	game.add_child(actor)
	var directions: Dictionary = {"right":[KEY_D],"down":[KEY_S],"left":[KEY_A],"up":[KEY_W]}
	for label in ["right","down","left","up"]:
		var clips_seen: Dictionary = {}
		var frames_seen: Dictionary = {}
		var last_moving: bool = false
		var last_move: Vector2 = Vector2.ZERO
		for tick in 30:
			for code in directions[label]: controls.key_down(code)
			var snapshot: Dictionary = controls.update(Vector2(room.player.x,room.player.y)+Vector2(0,220),false,1.0/60.0)
			actor.update_state(snapshot,controls.movement(),room.cooldown,0.0)
			last_moving = snapshot.player.moving
			last_move = controls.movement()
			if actor.lower.visible:
				clips_seen["lower:"+actor.lower.clip]=true
				frames_seen[actor.lower.frame_index]=true
				var data: Dictionary = actor.lower.clips[actor.lower.clip]
				var waist: Array = data.waistPoints[actor.lower.frame_index]
				var root: Array = data.roots[actor.lower.frame_index] if data.has("roots") else data.root
				var expected: Vector2 = (Vector2(waist[0],waist[1])-Vector2(root[0],root[1]))*float(data.scale)
				check.call(actor.lower.waist_parent_point().distance_to(expected)<=1.0,"%s 跑动帧 %d 的腰点与素材标注转换一致" % [label,actor.lower.frame_index])
			if actor.upper.visible:
				clips_seen["upper:"+actor.upper.clip]=true
				if actor.lower.visible:
					check.call(actor.lower.waist_world_point().distance_to(actor.upper.waist_world_point())<0.01,"%s 跑动上下身腰点 XY 对接" % label)
		for code in directions[label]: controls.key_up(code)
		controls.interrupt()
		var lower_clips: Array[String] = []
		for key in clips_seen.keys():
			if key.begins_with("lower:"): lower_clips.append(key.substr(6))
		var upper_clips: Array[String] = []
		for key in clips_seen.keys():
			if key.begins_with("upper:"): upper_clips.append(key.substr(6))
		probe_lines.append("[probe] %s moving=%s move=%s lower=%s upper=%s flip=%s scale=%s" % [label,last_moving,last_move,lower_clips,upper_clips,actor.lower.flipped,actor.lower.scale])
		check.call(last_moving, "%s 方向跑动时角色确实在移动" % label)
		check.call(lower_clips.size()>0, "%s 方向跑动时新素材下身参与绘制" % label)
		check.call(upper_clips.size()>0, "%s 方向跑动时新素材上身参与绘制" % label)
		for clip in lower_clips:
			check.call(clip=="shadow-run-lower", "%s 方向跑动下身采用同一皮影动作：%s" % [label,clip])
		for clip in upper_clips:
			check.call(clip=="shadow-run-upper", "%s 方向跑动上身采用同一皮影动作：%s" % [label,clip])
		check.call(frames_seen.size()>1, "%s 方向跑动时步态帧推进" % label)
	# 向左跑动不应把射箭姿势当作跑动上身。
	controls.key_down(KEY_A)
	var facing_state: Dictionary = controls.update(Vector2(room.player.x,room.player.y)+Vector2(0,220),false,1.0/60.0)
	actor.update_state(facing_state,controls.movement(),room.cooldown,0.0)
	check.call(actor.upper.visible and actor.upper.clip=="shadow-run-upper", "向左跑动不再把射箭姿势当作跑动上身")
	controls.interrupt()
	actor.free()
	var report: FileAccess = FileAccess.open("user://run_detail_probe.log",FileAccess.WRITE)
	if report!=null:
		for line in probe_lines: report.store_line(line)
		report.close()
	else:
		for line in probe_lines: print(line)
