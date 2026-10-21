extends SceneTree
var data: Dictionary = {}
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	for action in ["normal","pierce","rain","dodge"]:
		var game: Node2D = load("res://scenes/sample.tscn").instantiate()
		root.add_child(game); game.set_physics_process(false)
		var room: TrainingRoom = game.room
		room.layout.obstacles=[]
		room.enemies.clear()
		# Isolated reproducible showcase; each target is a real rule enemy, not an effect trigger.
		room=TrainingRoom.new({"spawn":Vector2(400,600),"enemy":Vector2(630,600),"encounter":Vector2(400,600),"obstacle":Rect2(1000,800,20,20)})
		game.room=room; game.controls=PlayerControls.new(room)
		var samples: Array = []
		for tick in 72:
			var input: Dictionary = {"aim":Vector2(630,548),"fire":action=="normal" and tick==0,"pierce":action=="pierce" and tick==0,"rain":action=="rain" and tick==0,"dodge":action=="dodge" and tick==0,"moveX":1 if action=="dodge" else 0}
			if action=="rain": input.aim=Vector2(600,600)
			room.update(input,1.0/60)
			var state: Dictionary = room.snapshot()
			game.clock+=1.0/60
			if state.player.moving: game.walk_time+=1.0/60
			game.present(state,1.0/60)
			var sprites: Array = [game.legs,game.torso,game.bow,game.nocked_arrow]
			sprites.append_array(game.enemy_bodies.values()); sprites.append_array(game.arrows.values()); sprites.append_array(game.combat_effects.stamps)
			for ghost in game.combat_effects.ghosts: sprites.append(ghost.lower); sprites.append(ghost.upper)
			var layers: Array = []
			for sprite: Sprite2D in sprites:
				if not sprite.visible: continue
				var region: Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO,sprite.texture.get_size())
				var offset: Vector2 = sprite.offset-(region.size/2 if sprite.centered else Vector2.ZERO)
				layers.append({"file":sprite.texture.resource_path,"region":[region.position.x,region.position.y,region.size.x,region.size.y],"offset":[offset.x,offset.y],"scale":[sprite.scale.x,sprite.scale.y],"rotation":sprite.rotation,"position":[sprite.position.x,sprite.position.y],"z":sprite.z_index,"color":[sprite.modulate.r,sprite.modulate.g,sprite.modulate.b,sprite.modulate.a]})
			samples.append({"tick":tick,"layers":layers,"hits":state.hits,"health":state.health})
		data[action]=samples
		game.free()
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(data)+"\n")
	print("Captured actual rule-driven combat stamps")
	quit()
