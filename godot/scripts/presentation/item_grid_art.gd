extends Control

const Art = preload("res://scripts/presentation/item_art.gd")
const Alpha = preload("res://scripts/alpha/alpha_state.gd")
var cells: Array[Button] = []
var items: Array = []

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	for item in items:
		if not Alpha.REGIONS.has(item.region): continue
		var image: Texture2D = Art.texture(item.name)
		if image==null: continue
		var shape: Vector2i = Alpha.shape(item,item.rotated)
		var start: int = item.cell.y*10+item.cell.x
		var end: int = (item.cell.y+shape.y-1)*10+item.cell.x+shape.x-1
		var bounds: Rect2 = Rect2(cells[start].position,cells[end].position+cells[end].size-cells[start].position).grow(-4)
		# 格子继续处理点击；图像只读状态，并随真实占格旋转。
		var has_label: bool = shape.x*shape.y>1
		var area: Rect2 = Rect2(bounds.position,bounds.size-Vector2(0,14 if has_label else 0))
		if item.rotated:
			draw_set_transform(area.get_center(),PI/2)
			var turned: Rect2 = Rect2(-Vector2(area.size.y,area.size.x)/2,Vector2(area.size.y,area.size.x))
			draw_texture_rect(image,Art.fit(image,turned),false,Art.tint(item))
			draw_set_transform(Vector2.ZERO)
		else: draw_texture_rect(image,Art.fit(image,area),false,Art.tint(item))
		if has_label:
			var title: String = ("燃·" if item.state=="burning" else "灰·" if item.state=="ash" else "")+item.name.trim_prefix("灰烬·")
			draw_string(ThemeDB.fallback_font,Vector2(bounds.position.x,bounds.end.y-1),title,HORIZONTAL_ALIGNMENT_CENTER,bounds.size.x,12,Color("f7e8c7"))
