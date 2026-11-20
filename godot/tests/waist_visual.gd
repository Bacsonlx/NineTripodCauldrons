extends Node2D
## 渲染角色四向姿态，检查上下身是否真的连成一体。

func _ready() -> void:
	var actor: Node2D = load("res://scripts/presentation/player_frame_actor.gd").new()
	actor.scale=Vector2.ONE*(2.0/3.0)
	add_child(actor)
	var cases: Array[Dictionary] = [
		{"facing":0,"moving":false},
		{"facing":1,"moving":false},
		{"facing":2,"moving":false},
		{"facing":3,"moving":false},
		{"facing":0,"moving":true},
		{"facing":1,"moving":true},
		{"facing":2,"moving":true},
		{"facing":0,"moving":true},
	]
	var frames: Array[Dictionary] = []
	for case in cases:
		var state: Dictionary = {"runId":1,"paused":false,"status":"playing","player":{"x":0,"y":0,"facing":case.facing,"moving":case.moving,"angle":0.0},"skill":null,"attack":"idle","hurt":0,"dodge":0,"protection":0,"health":100,"healthMax":100}
		var movement: Vector2 = Vector2.ZERO
		if case.moving:
			movement=Vector2.RIGHT
			if case.facing==1: movement=Vector2.DOWN
			if case.facing==2: movement=Vector2.LEFT
		frames.append({"state":state,"movement":movement})
	var cell: int = 200
	var canvas: Image = Image.create(cell*4,cell*2,false,Image.FORMAT_RGBA8)
	canvas.fill(Color(0.85,0.82,0.75))
	for index in frames.size():
		var entry: Dictionary = frames[index]
		for step in 8:
			actor.update_state(entry.state,entry.movement,0.0,0.0)
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		var crop: Image = shot.get_region(Rect2i(0,0,cell,cell))
		canvas.blend_rect(crop,Rect2i(0,0,cell,cell),Vector2i((index%4)*cell,(index/4)*cell))
	canvas.save_png("user://waist_check.png")
	print("saved")
	get_tree().quit()

func _process(_delta: float) -> void:
	# 兜底：窗口模式若始终没拿到帧，也要退出，避免测试挂住。
	if Engine.get_process_frames()>240:
		print("timeout")
		get_tree().quit()
