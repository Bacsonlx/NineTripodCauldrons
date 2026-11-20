@tool
extends Node2D

@export var path_texture: Texture2D
@export_range(8,96) var blend_width: float = 42.0
var signature: int = 0
var roads: Array[PackedVector2Array] = []
var edges: Array[PackedVector2Array] = []

func _ready() -> void:
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index=-50
	set_process(Engine.is_editor_hint())
	rebuild()

func _process(_seconds: float) -> void:
	if geometry_signature()!=signature: rebuild()

func geometry_signature() -> int:
	var values: Array = [blend_width,path_texture]
	for item in get_children():
		if item is Polygon2D and str(item.name) not in ["Forest","River"]: values.append(item.polygon); values.append(item.transform)
	return hash(values)

func rebuild() -> void:
	roads.clear()
	for item in get_children():
		if not item is Polygon2D or str(item.name) in ["Forest","River"]: continue
		roads.append(item.transform*item.polygon)
		item.visible=Engine.is_editor_hint()
	edges=blend_edges(roads)
	signature=geometry_signature()
	queue_redraw()

func inside(point: Vector2,polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false

func blend_edges(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	# 拆分相交边后只保留路网的外边界，连接处不会出现林地裂缝。
	for polygon in polygons:
		for index in polygon.size():
			var a: Vector2 = polygon[index]
			var b: Vector2 = polygon[(index+1)%polygon.size()]
			var delta: Vector2 = b-a
			if delta.length_squared()<0.01: continue
			var cuts: Array[float] = [0.0,1.0]
			for other in polygons:
				for edge in other.size():
					var hit: Variant = Geometry2D.segment_intersects_segment(a,b,other[edge],other[(edge+1)%other.size()])
					if hit!=null: cuts.append(clampf((hit-a).dot(delta)/delta.length_squared(),0,1))
			cuts.sort()
			var normal: Vector2 = Vector2(delta.y,-delta.x).normalized()
			for cut in range(1,cuts.size()):
				if cuts[cut]-cuts[cut-1]<0.0001: continue
				var from: Vector2 = a+delta*cuts[cut-1]
				var to: Vector2 = a+delta*cuts[cut]
				var mid: Vector2 = (from+to)/2
				var left: bool = inside(mid+normal*2,polygons)
				var right: bool = inside(mid-normal*2,polygons)
				if left==right: continue
				result.append(PackedVector2Array([from,to,-normal if left else normal]))
	return result

func textured_polygon(points: PackedVector2Array,colors: PackedColorArray) -> void:
	var uv: PackedVector2Array = []
	for point in points: uv.append(point/path_texture.get_size())
	draw_polygon(points,colors,uv,path_texture)

func _draw() -> void:
	if path_texture==null: return
	var is_room: bool = get_parent()!=null and get_parent().get("room_id")!=null
	var effective_blend: float = minf(blend_width,10.0) if is_room else blend_width
	# 正式房间缩小外扩过渡宽度，避免视觉路面大幅超出真实可行走边界形成空气墙错觉。
	for edge in edges:
		var divisions: int = maxi(1,ceili(edge[0].distance_to(edge[1])/18.0))
		for index in divisions:
			var a: Vector2 = edge[0].lerp(edge[1],float(index)/divisions)
			var b: Vector2 = edge[0].lerp(edge[1],float(index+1)/divisions)
			var wa: float = effective_blend*(0.8+0.2*sin(a.x*0.19+a.y*0.27))
			var wb: float = effective_blend*(0.8+0.2*sin(b.x*0.19+b.y*0.27))
			textured_polygon(PackedVector2Array([a,b,b+edge[2]*wb,a+edge[2]*wa]),PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0),Color(1,1,1,0)]))
			if is_room:
				draw_polygon(PackedVector2Array([a-edge[2]*4.0,b-edge[2]*4.0,b+edge[2]*(wb+4.0),a+edge[2]*(wa+4.0)]),PackedColorArray([Color(0.06,0.08,0.04,0.0),Color(0.06,0.08,0.04,0.0),Color(0.06,0.08,0.04,0.38),Color(0.06,0.08,0.04,0.38)]))
		var fan: int = 16
		for index in fan:
			var a: Vector2 = edge[0]+Vector2.from_angle(TAU*index/fan)*effective_blend*0.8
			var b: Vector2 = edge[0]+Vector2.from_angle(TAU*(index+1)/fan)*effective_blend*0.8
			textured_polygon(PackedVector2Array([edge[0],a,b]),PackedColorArray([Color.WHITE,Color(1,1,1,0),Color(1,1,1,0)]))
	for polygon in roads: textured_polygon(polygon,PackedColorArray([Color.WHITE]))
