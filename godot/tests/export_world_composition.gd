# Export actual scene placement for offline visual QA; this does not capture GPU rendering.
extends SceneTree

func _initialize() -> void:
	export_map.call_deferred()

func export_map() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var map_path: String = arguments[1] if arguments.size()>1 else "res://scenes/tanggu_first_level_map.tscn"
	var map: Node2D = load(map_path).instantiate()
	root.add_child(map)
	var data: Dictionary = {"size":[map.world_size.x,map.world_size.y],"ground":[],"sprites":[],"contacts":[],"labels":[]}
	data.rules=map.build_layout()
	data.rules.erase("groundPatches")
	for polygon in map.get_node("Ground").get_children():
		var points: Array = []
		for vertex in polygon.polygon: points.append([vertex.x,vertex.y])
		data.ground.append({"points":points,"image":polygon.texture.resource_path,"z":polygon.z_index,"name":str(polygon.name)})
	if map.get_node("Ground").has_method("blend_edges"):
		data.terrainBlend={"width":map.get_node("Ground").blend_width,"edges":[]}
		for edge in map.get_node("Ground").edges:
			data.terrainBlend.edges.append([[edge[0].x,edge[0].y],[edge[1].x,edge[1].y],[edge[2].x,edge[2].y]])
	var items: Array[Node] = map.get_children()
	if map.has_node("Doors"):
		var model: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(map.build_layout())
		for door in map.get_node("Doors").get_children():
			var state: Dictionary = model.snapshot()
			if arguments.size()>2: state.roomComplete=arguments[2]=="open"
			door.update_state(state,2.0)
			if door.get_node("Passage").visible: append_sprite(data,door.get_node("Passage/Swirl"),str(door.name)+"_Passage",false,[])
			var label: Label = door.get_node("Destination")
			data.labels.append({"text":label.text,"position":[label.global_position.x,label.global_position.y],"color":label.modulate.to_html(),"size":label.get_theme_font_size("font_size")})
			items.append(door.get_node("Frame"))
			if door.get_node("Seal").visible: items.append(door.get_node("Seal"))
	for item in items:
		if not item.has_method("update_state"): continue
		var sprite: Sprite2D = item.get_node("Sprite")
		append_sprite(data,sprite,str(item.name),item.category=="obstacle",[item.position.x,item.position.y,item.size.x,item.size.y])
		for patch in item.get_node("GroundContact").get_children():
			var vertices: Array = []
			for point in patch.polygon:
				var world_point: Vector2 = patch.to_global(point)
				vertices.append([world_point.x,world_point.y])
			var tint: Color = patch.vertex_colors[32]
			data.contacts.append({"points":vertices,"color":[tint.r,tint.g,tint.b,tint.a],"image":patch.texture.resource_path if patch.texture else "","z":-15})
	var out: FileAccess = FileAccess.open(arguments[0],FileAccess.WRITE)
	out.store_string(JSON.stringify(data,"  ")+"\n")
	print("Exported ",data.sprites.size()," independent scene sprites")
	map.free(); quit()

func append_sprite(data: Dictionary,sprite: Sprite2D,label: String,collision: bool,footprint: Array) -> void:
	var texture: Texture2D = sprite.texture
	var region: Rect2 = texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
	var sheet: Texture2D = texture.atlas if texture is AtlasTexture else texture
	var pose: Transform2D = sprite.global_transform
	var rect: Rect2 = sprite.get_rect()
	var depth: int = sprite.z_index
	var ancestor: CanvasItem = sprite
	while ancestor.z_as_relative and ancestor.get_parent() is Node2D:
		ancestor=ancestor.get_parent()
		depth+=ancestor.z_index
	data.sprites.append({"name":label,"image":sheet.resource_path,"sheetSize":[sheet.get_width(),sheet.get_height()],"region":[region.position.x,region.position.y,region.size.x,region.size.y],"position":[pose.origin.x,pose.origin.y],"size":[texture.get_width()*sprite.scale.x,texture.get_height()*sprite.scale.y],"z":depth,"mirror":sprite.flip_h,"collision":collision,"footprint":footprint,"rect":[rect.position.x,rect.position.y],"pose":[pose.x.x,pose.x.y,pose.y.x,pose.y.y,pose.origin.x,pose.origin.y],"tint":[sprite.self_modulate.r*sprite.modulate.r,sprite.self_modulate.g*sprite.modulate.g,sprite.self_modulate.b*sprite.modulate.b],"opacity":sprite.self_modulate.a*sprite.modulate.a})
