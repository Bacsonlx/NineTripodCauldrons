extends Control

const GRID: Dictionary = {"entry":Vector2(0,1),"court1":Vector2(1,1),"stele":Vector2(2,0),"altar":Vector2(2,2),"court2":Vector2(3,1),"court3":Vector2(4,1),"boss":Vector2(5,1),"end":Vector2(6,1)}
const MARKS: Dictionary = {"entry":"入","court1":"一","stele":"碑","altar":"+","court2":"二","court3":"三","boss":"首","end":"出"}
var graph: Dictionary = {}

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

func update_state(value: Dictionary) -> void:
	if graph==value: return
	graph=value.duplicate(true)
	queue_redraw()

func room_rect(id: String) -> Rect2:
	return Rect2(Vector2(12,26)+GRID[id]*Vector2(30,28),Vector2(22,18))

func _draw() -> void:
	if graph.is_empty(): return
	var font: Font = get_theme_default_font()
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(10,16),"汤谷 · 房间",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c8b78e"))
	var nodes: Dictionary = {}
	for room in graph.rooms: nodes[room.id]=room
	for edge in graph.connections:
		if not GRID.has(edge.from) or not GRID.has(edge.to): continue
		var left_id: String = edge.from if GRID[edge.from].x<GRID[edge.to].x else edge.to
		var right_id: String = edge.to if left_id==edge.from else edge.from
		var left: Rect2 = room_rect(left_id)
		var right: Rect2 = room_rect(right_id)
		var a: Vector2 = Vector2(left.end.x,left.get_center().y)
		var b: Vector2 = Vector2(right.position.x,right.get_center().y)
		var mid: float = (a.x+b.x)/2
		var color: Color = Color("9c9e76") if nodes[left_id].visited and nodes[right_id].visited else Color("596558")
		draw_polyline(PackedVector2Array([a,Vector2(mid,a.y),Vector2(mid,b.y),b]),color,2)
		for pair in [[left_id,a],[right_id,b]]:
			if nodes[pair[0]].current and nodes[pair[0]].locked:
				draw_rect(Rect2(pair[1]-Vector2(2,3),Vector2(4,6)),Color("d77b60"))
	var current: Dictionary = {}
	for room in graph.rooms:
		if not GRID.has(room.id): continue
		var rect: Rect2 = room_rect(room.id)
		var color: Color = Color("526747") if room.complete else Color("345a53") if room.visited else Color("252e29")
		draw_rect(rect,color)
		draw_rect(rect,Color("e6c877") if room.current else Color("9ca98b") if room.visited else Color("687168"),false,2 if room.current else 1)
		draw_string(font,rect.position+Vector2(5,13),MARKS[room.id],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ede5c8") if room.visited else Color("899386"))
		if room.complete:
			var p: Vector2 = rect.end-Vector2(7,4)
			draw_polyline(PackedVector2Array([p-Vector2(3,1),p,p+Vector2(4,-5)]),Color("d5dfaa"),1.5)
		if room.current: current=room
	if not current.is_empty():
		draw_string(font,Vector2(10,115),current.title,HORIZONTAL_ALIGNMENT_LEFT,140,11,Color("e6c877"))
		draw_string(font,Vector2(157,115),"封门" if current.locked else "可通行",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d77b60") if current.locked else Color("a6bc8b"))
	draw_string(font,Vector2(10,129),"金框·当前   碑·碑林   +·回血",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("a5b09d"))

func panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.07,0.05,0.76)
	style.border_color=Color(0.48,0.49,0.34,0.7)
	style.set_border_width_all(1)
	return style
