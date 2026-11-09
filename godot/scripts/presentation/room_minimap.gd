extends Control

var layout: Dictionary = {}
var player: Vector2 = Vector2.ZERO
var locked: bool = false

func _ready() -> void:
	name="RoomMinimap"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left=-258; offset_right=-24; offset_top=72; offset_bottom=208
	get_parent().resized.connect(layout_edges)
	layout_edges()

func layout_edges() -> void:
	offset_top=72 if get_parent().size.x>=1280 else 224
	offset_bottom=offset_top+136

func update_state(room_layout: Dictionary,position: Vector2,is_locked: bool) -> void:
	if layout==room_layout and player==position and locked==is_locked: return
	layout=room_layout
	player=position
	locked=is_locked
	queue_redraw()

func map_point(point: Vector2) -> Vector2:
	var world_size: Vector2 = Vector2(layout.width,layout.height)
	var area: Rect2 = Rect2(12,27,size.x-24,size.y-37)
	var scale_factor: float = minf(area.size.x/world_size.x,area.size.y/world_size.y)
	return area.get_center()-world_size*scale_factor/2+point*scale_factor

func _draw() -> void:
	if layout.is_empty(): return
	var font: Font = get_theme_default_font()
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(11,17),str(layout.roomTitle),HORIZONTAL_ALIGNMENT_LEFT,150,12,Color("e6c877"))
	draw_string(font,Vector2(size.x-55,17),"封门" if locked else "可通行",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d77b60") if locked else Color("a6bc8b"))
	draw_line(Vector2(10,22),Vector2(size.x-10,22),Color("827e59"),1)
	for polygon in layout.walkablePolygons:
		var points: PackedVector2Array = PackedVector2Array()
		for point in polygon: points.append(map_point(point))
		if points.size()<3: continue
		draw_colored_polygon(points,Color("42584a"))
		points.append(points[0])
		draw_polyline(points,Color("9eaf89"),1.2,true)
	for door in layout.doors:
		var p: Vector2 = map_point(TrainingRoom.point(door.point))
		var color: Color = Color("d77b60") if locked else Color("e6c877")
		draw_circle(p,4.0,Color("17231d"))
		draw_rect(Rect2(p-Vector2(2.5,2.5),Vector2(5,5)),color)
	var marker: Vector2 = map_point(player)
	draw_circle(marker,6,Color("17231d"))
	draw_circle(marker,3.5,Color("fff3c5"))
	draw_arc(marker,5,0,TAU,16,Color("e6c877"),1.0,true)

func panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.07,0.05,0.88)
	style.border_color=Color(0.48,0.49,0.34,0.8)
	style.set_border_width_all(1)
	return style
