@tool
extends Node2D

const SOIL: Texture2D = preload("res://assets/world/forest.png")

func configure(prop: Node2D) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	z_as_relative=false
	z_index=-15
	if prop.flat: return
	var asset: String = prop.texture_asset.resource_path.get_file().get_basename()
	var width: float = prop.render_width
	var height: float = prop.texture_asset.get_height()*width/prop.texture_asset.get_width()
	var foot: Vector2 = prop.get_node("Sprite").position
	var radius: Vector2 = Vector2(width*0.38,width*0.13)
	var center: Vector2 = foot-Vector2(0,height*0.04)
	var slope: float = 0.0
	if asset=="wall_north":
		radius=Vector2(width*0.35,height*0.47)
		center=foot-Vector2(0,height*0.43)
	elif asset.begins_with("wall"):
		radius=Vector2(width*0.53,width*0.12)
		center=foot-Vector2(0,height*0.24)
		slope=0.55 if asset=="wall_east" else -0.55
	elif asset in ["grass","ferns"]: return
	elif asset=="camp":
		radius=Vector2(width*0.52,width*0.22)
		center=foot-Vector2(0,height*0.12)
	elif asset=="gateway":
		# 门洞留亮，只在两侧门墩下接地。
		for side in [-1.0,1.0]:
			var offset: Vector2 = Vector2(width*0.29*side,-height*(0.14 if side==(1.0 if prop.mirror_art else -1.0) else 0.02))
			add_contact(prop,foot+offset,Vector2(width*0.19,width*0.08),0.0)
		return
	elif asset=="root":
		radius=Vector2(width*0.43,width*0.17)
		center=foot-Vector2(0,height*0.09)
	add_contact(prop,center,radius,slope)

func add_contact(prop: Node2D,center: Vector2,radius: Vector2,slope: float) -> void:
	# 同一脚点生成苔土与柔和接触阴影；只改变呈现，不生成实体。
	for shadow in [false,true]:
		var patch: Polygon2D = Polygon2D.new()
		var points: PackedVector2Array = []
		var colors: PackedColorArray = []
		var uv: PackedVector2Array = []
		var triangles: Array[PackedInt32Array] = []
		var tint: Color = Color(0.11,0.12,0.075,0.48) if shadow else Color(0.8,0.83,0.65,0.68)
		for i in range(32):
			var angle: float = TAU*i/32.0
			var irregular: float = 1.0+0.12*sin(angle*5.0+prop.position.x*0.03)
			var point: Vector2 = Vector2(cos(angle)*radius.x,sin(angle)*radius.y)*irregular*(0.67 if shadow else 1.0)
			point.y+=point.x*slope
			point=Vector2(point.x*prop.ground_axis.x,point.y+point.x*prop.ground_axis.y)+center
			points.append(point)
			colors.append(Color(tint,0.0))
			uv.append(prop.position+point)
			triangles.append(PackedInt32Array([i,(i+1)%32,32]))
		points.append(center); colors.append(tint); uv.append(prop.position+center)
		patch.polygon=points
		patch.internal_vertex_count=1
		patch.polygons=triangles
		patch.vertex_colors=colors
		patch.uv=uv
		if not shadow:
			patch.texture=SOIL
			patch.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		add_child(patch)
