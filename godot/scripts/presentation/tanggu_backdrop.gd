extends Node2D

var layout: Dictionary
var atlas: Dictionary
var textures: Dictionary
var tiles: Dictionary = {}
var props: Array[Dictionary] = []
var objects: Dictionary = {}
var flames: Array[Sprite2D] = []

func setup(data: Dictionary,frames: Dictionary,images: Dictionary) -> void:
	layout=data; atlas=frames; textures=images; z_index=-1
	for frame in atlas.terrain.frames:
		tiles[frame.name]=ImageTexture.create_from_image(textures.terrain.get_image().get_region(Rect2i(frame.x,frame.y,frame.width,frame.height)))
	for pillar in layout.pillars: prop("worldProps",3,Vector2(pillar.x,pillar.y),Vector2.ONE*0.28,120)
	for item in layout.obstacles:
		var position: Vector2 = Vector2(item.x,item.y)
		if item.kind in ["tree","root","wall"]:
			prop("worldProps",{"tree":0,"root":1,"wall":2}[item.kind],position,Vector2.ONE*(0.44 if item.kind=="tree" else 0.46),item.height)
			if item.has("opensAfterEncounter"): props[-1].opensAfterEncounter=item.opensAfterEncounter
		elif item.kind in ["brazier","waystone"]:
			var body: Sprite2D = prop("props",0 if item.kind=="brazier" else 1,position,Vector2.ONE*(0.15 if item.kind=="brazier" else 0.19),item.height)
			if item.kind=="brazier": flames.append(body)
		else:
			var index: int = {"stele":0,"altar":1,"gate":3}[item.kind]
			var frame: Dictionary = atlas.exploration.frames[index]
			var body: Sprite2D = prop("exploration",index,position+Vector2(0,item.halfHeight),Vector2(item.halfWidth*2/frame.width,(item.height+item.halfHeight)/frame.height),item.height)
			body.z_index=int(item.y)+1
			objects[item.kind]={"body":body,"data":item}
	queue_redraw()

func prop(key: String,index: int,position: Vector2,scale_value: Vector2,height: float) -> Sprite2D:
	var frame: Dictionary = atlas[key].frames[index]
	var body: Sprite2D = Sprite2D.new()
	body.texture=textures[key]; body.region_enabled=true; body.region_rect=Rect2(frame.x,frame.y,frame.width,frame.height)
	body.centered=false; body.offset=Vector2(-frame.originX*frame.width,-frame.originY*frame.height)
	body.position=position; body.scale=scale_value; body.z_index=int(position.y)+1
	add_child(body); props.append({"body":body,"x":position.x,"y":position.y,"height":maxf(height,frame.height*scale_value.y)})
	return body

func update(state: Dictionary,clock: float) -> void:
	var player: Dictionary = state.player
	for item in props:
		item.body.visible=state.encounter<=int(item.get("opensAfterEncounter",2147483647))
		item.body.modulate.a=0.3 if player.y<item.y and player.y>item.y-item.height and absf(player.x-item.x)<item.body.region_rect.size.x*item.body.scale.x/2 else 1.0
	for index in flames.size():
		if flames[index].modulate.a>0.4: flames[index].modulate.a=0.94+sin(clock*4+index)*0.04
	var altar: Sprite2D = objects.altar.body
	var frame: Dictionary = atlas.exploration.frames[2 if state.exploration.altarUsed else 1]
	altar.region_rect=Rect2(frame.x,frame.y,frame.width,frame.height)
	var data: Dictionary = objects.altar.data
	altar.scale=Vector2(data.halfWidth*2/frame.width,(data.height+data.halfHeight)/frame.height)
	altar.offset=Vector2(-frame.originX*frame.width,-frame.originY*frame.height)
	var gate: Sprite2D = objects.gate.body
	data=objects.gate.data
	frame=atlas.exploration.frames[3]
	gate.scale.x=(14.0 if state.exploration.gateOpen else data.halfWidth*2)/frame.width
	gate.position.x=data.x-data.halfWidth+7 if state.exploration.gateOpen else data.x
	gate.rotation=sin(clock*45)*0.008 if state.gateOpening>0 else 0.0

func tile(texture: Texture2D,rect: Rect2,scale_value: float) -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_value)
	draw_texture_rect(texture,Rect2(rect.position/scale_value,rect.size/scale_value),true)
	draw_set_transform(Vector2.ZERO)
func area_rect(area: Dictionary) -> Rect2:
	return Rect2(area.left,area.top,area.right-area.left,area.bottom-area.top)
func _draw() -> void:
	if layout.is_empty(): return
	tile(tiles.forest,Rect2(0,0,layout.width,layout.height),0.55)
	for area in layout.walkableAreas: tile(tiles[area.material],area_rect(area),0.5)
	for patch in layout.groundPatches:
		var destination: Rect2 = Rect2(patch.x-patch.width/2,patch.y-patch.height/2,patch.width,patch.height)
		for area in layout.walkableAreas:
			var visible: Rect2 = destination.intersection(area_rect(area))
			if visible.has_area():
				var source: Rect2 = Rect2((visible.position-destination.position)/destination.size*textures.ground.get_size(),visible.size/destination.size*textures.ground.get_size())
				draw_texture_rect_region(textures.ground,visible,source)
	for index in range(1,layout.mainRoute.size()):
		var from: Vector2 = Vector2(layout.mainRoute[index-1].x,layout.mainRoute[index-1].y)
		var to: Vector2 = Vector2(layout.mainRoute[index].x,layout.mainRoute[index].y)
		draw_set_transform((from+to)/2,(to-from).angle(),Vector2.ONE*0.2)
		draw_texture_rect(tiles.paving,Rect2(-(from.distance_to(to)+12)/0.4,-110,(from.distance_to(to)+12)/0.2,220),true,Color(1,1,1,0.75))
		draw_set_transform(Vector2.ZERO)
	# 只描外缘，连接处保持通路连续；低矮边界不参与空中弹道阻挡。
	for area in layout.walkableAreas:
		for vertical in [false,true]:
			for side in [false,true]:
				var line: float = (area.right if side else area.left) if vertical else (area.bottom if side else area.top)
				var minimum: float = area.top if vertical else area.left
				var maximum: float = area.bottom if vertical else area.right
				var cuts: Array[float] = [minimum,maximum]
				for other in layout.walkableAreas:
					for value in ([other.top,other.bottom] if vertical else [other.left,other.right]):
						if value>=minimum and value<=maximum: cuts.append(value)
				cuts.sort()
				for index in range(1,cuts.size()):
					var low: float = cuts[index-1]
					var high: float = cuts[index]
					var center: Vector2 = Vector2(line,(low+high)/2) if vertical else Vector2((low+high)/2,line)
					var covered: bool = false
					for other in layout.walkableAreas:
						if other!=area and center.x>other.left and center.x<other.right and center.y>other.top and center.y<other.bottom: covered=true; break
					if covered or high==low: continue
					var start: Vector2 = Vector2(line,low) if vertical else Vector2(low,line)
					var end: Vector2 = Vector2(line,high) if vertical else Vector2(high,line)
					draw_line(start,end,Color("171f14"),10)
					draw_line(start,end,Color(0.51,0.45,0.29,0.6),2)
