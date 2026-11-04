extends Node2D

const Art = preload("res://scripts/presentation/item_art.gd")
const ICON_BOX_SIZE: Vector2 = Vector2(28,28)
const ICON_BOX_OFFSET: Vector2 = Vector2(-14,-30)
const RING_RADIUS: float = 7.0
const RING_WIDTH: float = 1.5
const LABEL_OFFSET: Vector2 = Vector2(16,-2)
const LABEL_FONT_SIZE: int = 13
var items: Array = []
var camps: Array = []
var camp_ready: bool = false

static func icon_box(location: Vector2) -> Rect2:
	return Rect2(location+ICON_BOX_OFFSET,ICON_BOX_SIZE)

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
		draw_circle(location,RING_RADIUS,Color("302d22"))
		draw_arc(location,RING_RADIUS,0,TAU,24,Color("f2cd75"),RING_WIDTH)
		var image: Texture2D = Art.texture(item.name)
		if image!=null:
			texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			draw_texture_rect(image,Art.fit(image,icon_box(location)),false,Art.tint(item))
		draw_string(ThemeDB.fallback_font,location+LABEL_OFFSET,item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_FONT_SIZE,Color("f2dfb9"))
