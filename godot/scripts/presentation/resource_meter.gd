extends ProgressBar

var tint: Color = Color.WHITE
var segmented: bool = false

func _ready() -> void:
	show_percentage=false; mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("background",StyleBoxEmpty.new())
	add_theme_stylebox_override("fill",StyleBoxEmpty.new())
	value_changed.connect(func(_value: float): queue_redraw())

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var outline: PackedVector2Array = [Vector2(6,0),Vector2(w-6,0),Vector2(w,h/2),Vector2(w-6,h),Vector2(6,h),Vector2(0,h/2),Vector2(6,0)]
	draw_colored_polygon(outline.slice(0,6),Color("0c100eea"))
	var inner: PackedVector2Array = [Vector2(7,3),Vector2(w-7,3),Vector2(w-3,h/2),Vector2(w-7,h-3),Vector2(7,h-3),Vector2(3,h/2)]
	var filled: PackedVector2Array = []
	var edge: float = 3+(w-6)*clampf(value/max_value,0,1)
	if value>0:
		for index in inner.size():
			var a: Vector2 = inner[index]
			var b: Vector2 = inner[(index+1)%inner.size()]
			if a.x<=edge: filled.append(a)
			if (a.x<edge and b.x>edge) or (a.x>edge and b.x<edge): filled.append(a.lerp(b,(edge-a.x)/(b.x-a.x)))
		if filled.size()>=3: draw_colored_polygon(filled,tint)
		if edge>8: draw_line(Vector2(7,3),Vector2(minf(w-7,edge),3),tint.lightened(0.25),1)
	if segmented:
		for index in [1,2,3]: draw_line(Vector2(w*index/4,3),Vector2(w*index/4,h-3),Color(0.04,0.1,0.05,0.55),1)
	draw_polyline(outline,Color("a58c60"),1,true)
	draw_circle(Vector2(4,h/2),1,Color("c1a778"))
	draw_circle(Vector2(w-4,h/2),1,Color("c1a778"))
