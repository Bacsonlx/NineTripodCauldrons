extends RefCounted
## 接缝对齐检查：上下身的腰带线必须落在同一高度。
##
## 之前的实现把「下身 root 在脚点」与「上身 root 在腰线上方」两套语义
## 混在一起相减，导致上下身分离。这里直接断言两条腰线的世界 y 之差。

const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
const Frames = preload("res://scripts/presentation/action_frame_sprite.gd")

func run(game: Node2D, check: Callable) -> void:
	var room: TrainingRoom = Room.new()
	var controls: PlayerControls = Controls.new(room)
	var actor: Node2D = load("res://scripts/presentation/player_frame_actor.gd").new()
	game.add_child(actor)
	var directions: Dictionary = {"right":[KEY_D],"down":[KEY_S],"left":[KEY_A],"up":[KEY_W]}
	for label in ["right","down","left","up"]:
		var gaps: Array[float] = []
		for tick in 20:
			for code in directions[label]: controls.key_down(code)
			var here: Vector2 = Vector2(room.player.x,room.player.y)
			var snapshot: Dictionary = controls.update(here+Vector2(0,220),false,1.0/60.0)
			actor.update_state(snapshot,controls.movement(),room.cooldown,0.0)
			if actor.lower.visible and actor.upper.visible:
				gaps.append(absf(actor.lower_waist_y()-actor.upper_waist_y()))
		for code in directions[label]: controls.key_up(code)
		controls.interrupt()
		if gaps.is_empty():
			# 背面用整身图，不存在上下身分层。
			continue
		var worst: float = 0.0
		for gap in gaps: worst=maxf(worst,gap)
		check.call(worst<=1.0, "%s 方向上下身腰线对齐，最大偏差 %.2fpx" % [label,worst])
	# 静止时的四向也必须对齐。
	for facing in 4:
		var snapshot: Dictionary = room.snapshot()
		snapshot.player.facing=facing
		snapshot.player.moving=false
		actor.update_state(snapshot,Vector2.ZERO,room.cooldown,0.0)
		if actor.lower.visible and actor.upper.visible:
			var gap: float = absf(actor.lower_waist_y()-actor.upper_waist_y())
			check.call(gap<=1.0, "朝向%d 静止时上下身腰线对齐，偏差 %.2fpx" % [facing,gap])
	actor.free()
	# 像素级不变式：两层的 root 语义不同，按腰线对齐后必须完全重合。
	var lower: Sprite2D = Frames.new()
	var upper: Sprite2D = Frames.new()
	lower.sample("hero-run-lower",0,false)
	upper.sample("hero-archery-upper",0,false)
	var lower_gap: float = lower.waist_delta()
	var upper_gap: float = upper.waist_delta()
	check.call(absf(lower_gap-upper_gap)>0.001, "两层的 root 语义确实不同，必须靠腰线换算对齐")
	lower.position=Vector2.ZERO
	upper.position=Vector2.ZERO
	upper.position.y+=lower.waist_world_y()-upper.waist_world_y()
	var gap: float = absf(lower.waist_world_y()-upper.waist_world_y())
	check.call(gap<=0.01, "按腰线对齐后上下身腰线完全重合，偏差 %.4fpx" % gap)
	for index in 8:
		lower.sample("hero-run-lower",index,false)
		check.call(lower.waist_delta()!=0.0, "下身第%d帧能换算出真实腰线" % index)
	for index in 8:
		upper.sample("hero-archery-upper",index,false)
		check.call(upper.waist_delta()!=0.0, "上身第%d帧能换算出真实腰线" % index)
	lower.free()
	upper.free()
