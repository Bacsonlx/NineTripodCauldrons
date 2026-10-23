extends SceneTree

var frames: Array = []

func _initialize() -> void:
	run.call_deferred()

func capture(actor: Node2D,variant: String,mode: String,time: float,state: Dictionary) -> void:
	actor.update_state(state)
	var parts: Array = []
	for sprite in actor.get_children():
		if not sprite is Sprite2D: continue
		var transform: Transform2D = sprite.global_transform
		parts.append({"name":str(sprite.name),"x":[transform.x.x,transform.x.y],"y":[transform.y.x,transform.y.y],"origin":[transform.origin.x,transform.origin.y],"offset":[sprite.offset.x,sprite.offset.y],"z":sprite.z_index})
	var hammer: Variant = null
	if state.vulnerable: hammer={"x":state.hammer.x,"y":state.hammer.y,"leg":state.hammer.leg}
	frames.append({"variant":variant,"mode":mode,"time":time,"phase":state.boss.phase,"origin":[state.boss.x,state.boss.y],"parts":parts,"hammer":hammer})

func run() -> void:
	for mode in ["swing","throw","lightning"]:
		var room: TrainingRoom = load("res://scripts/combat/boss_room.gd").new({"spawn":Vector2(840,520) if mode=="swing" else Vector2(240,520)})
		var original: Node2D = load("res://scripts/presentation/thor_puppet.gd").new()
		var candidate: Node2D = load("res://scripts/presentation/thor_motion_candidate.gd").new()
		original.visual_scale=1.25; candidate.visual_scale=1.25
		root.add_child(original); root.add_child(candidate)
		var phase: String = {"swing":"swing_warn","throw":"throw_warn","lightning":"lightning"}[mode]
		for i in 800:
			if room.snapshot().boss.phase==phase: break
			room.update({},0.01)
			original.update_state(room.snapshot()); candidate.update_state(room.snapshot())
		var beginning: float = room.snapshot().elapsed
		var duration: float = 1.92 if mode=="swing" else 3.92 if mode=="throw" else 4.0
		for i in int(duration/0.02)+1:
			var state: Dictionary = room.snapshot()
			capture(original,"baseline",mode,state.elapsed-beginning,state)
			capture(candidate,"candidate",mode,state.elapsed-beginning,state)
			room.update({},0.02)
		original.free(); candidate.free()
	var output: String = OS.get_cmdline_user_args()[0]
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(frames))
	print("Exported ",frames.size()," actual baseline/candidate poses; offline composite only")
	quit()
