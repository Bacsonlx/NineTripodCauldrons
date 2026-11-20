extends Node2D
## 渲染带装备的角色，检查挂件位置。

func _ready() -> void:
	var actor: Node2D = load("res://scripts/presentation/player_frame_actor.gd").new()
	add_child(actor)
	var state: Dictionary = {"runId":1,"paused":false,"status":"playing","player":{"x":0,"y":0,"facing":0,"moving":false,"angle":0.0},"skill":null,"attack":"idle","hurt":0,"dodge":0,"protection":0,"health":130,"healthMax":130}
	var appearance: Dictionary = {"signature":"x","slots":{"weapon":{"name":"训练弓","art":"training-bow-hand"},"feet":{"name":"布履","art":"cloth-shoes-foot"},"head":{"name":"羊角","art":"ram-horn-head"},"body":{"name":"虎牙","art":"tiger-fang-body"}},"effects":[]}
	actor.apply_appearance(appearance)
	actor.update_state(state,Vector2.ZERO,0.0,0.0)
	actor.sync_gear_context()
	for i in 20: actor.update_gear(0.05)
	var frames: int = 0
	while frames < 6:
		await RenderingServer.frame_post_draw
		frames += 1
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://gear_visual.png")
	print("saved")
	get_tree().quit()
