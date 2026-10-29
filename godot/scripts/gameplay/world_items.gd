extends Node2D

const Art = preload("res://scripts/presentation/item_art.gd")
var items: Array = []
var camps: Array = []
var camp_ready: bool = false

func update(snapshot: Dictionary) -> void:
	items=snapshot.get("alpha",{}).get("items",[]).filter(func(item: Dictionary): return item.get("roomId","")==snapshot.get("roomId",""))
	camps=snapshot.get("camps",[])
	camp_ready=snapshot.get("roomComplete",false)
	queue_redraw()

func _draw() -> void:
	for location in camps:
		var color: Color = Color("98c8ae") if camp_ready else Color("777777")
		draw_arc(location,26,0,TAU,32,color,2)
		draw_string(ThemeDB.fallback_font,location+Vector2(-35,-32),"营地 · B" if camp_ready else "清庭后整理",HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
	for item in items:
		if item.region!="ground": continue
		var location: Vector2 = TrainingRoom.point(item.world)
		draw_circle(location,10,Color("302d22"))
		draw_arc(location,10,0,TAU,24,Color("f2cd75"),2)
		var image: Texture2D = Art.texture(item.name)
		if image!=null:
			texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			draw_texture_rect(image,Art.fit(image,Rect2(location+Vector2(-22,-46),Vector2(44,44))),false,Art.tint(item))
		draw_string(ThemeDB.fallback_font,location+Vector2(25,-3),item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f2dfb9"))
