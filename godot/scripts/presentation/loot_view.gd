extends Node2D

const POTIONS: Dictionary = {"health":preload("res://assets/loot/health.tres"),"mana":preload("res://assets/loot/mana.tres")}
var items: Dictionary = {}
var float_time: float = 0.0
var run_id: int = -1
var fading: Array[Dictionary] = []

func update_state(state: Dictionary,seconds: float = 0.0) -> void:
	if run_id!=state.runId:
		for node in items.values(): node.queue_free()
		for effect in fading: effect.node.queue_free()
		items.clear(); fading.clear(); float_time=0; run_id=state.runId
	var dt: float = 0.0 if state.paused or state.status=="failed" else seconds
	float_time+=dt
	for index in range(fading.size()-1,-1,-1):
		var effect: Dictionary = fading[index]
		effect.age+=dt
		var progress: float = minf(1,effect.age/0.24)
		effect.node.position=effect.point+Vector2(0,-12*progress)
		effect.node.modulate.a=1-progress
		if progress>=1: effect.node.queue_free(); fading.remove_at(index)
	var live: Dictionary = {}
	var target: String = str(state.interaction.get("dropId","")) if state.interaction!=null else ""
	# 不拼接临时数组：直接遍历两个来源，避免每帧分配。
	var drops: Array = state.get("drops",[])
	var rewards: Array = state.get("rewardPlaceholders",[])
	for index in drops.size()+rewards.size():
		var item: Dictionary = drops[index] if index<drops.size() else rewards[index-drops.size()]
		var id: String = str(item.get("id","reward:"+item.kind))
		live[id]=true
		if not items.has(id): items[id]=make_item(item)
		var node: Node2D = items[id]
		node.position=Vector2(item.x,item.y); node.z_index=int(item.y)
		if node.has_node("Bottle"): node.get_node("Bottle").position.y=-2-(1-cos(float_time*TAU/2.7))
		node.get_node("Selection").visible=id==target and state.interaction.reason==null
	for id in items.keys():
		if not live.has(id):
			var node: Node2D = items[id]
			# 同一规则运行内的药瓶移除就是消费；换房和重试已由 runId 清理。
			if node.has_node("Bottle"):
				node.get_node("Selection").visible=false; node.get_node("Shadow").visible=false
				fading.append({"node":node,"point":node.position,"age":0.0})
			else: node.queue_free()
			items.erase(id)

func make_item(item: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	add_child(node)
	var reward: bool = item.kind in ["equipment","item"]
	var shadow: Polygon2D = Polygon2D.new()
	shadow.name="Shadow"
	shadow.polygon=PackedVector2Array([Vector2(-9,0),Vector2(0,-3),Vector2(9,0),Vector2(0,3)]) if reward else PackedVector2Array([Vector2(-13,0),Vector2(0,-4),Vector2(13,0),Vector2(0,4)])
	shadow.color=Color(0.02,0.03,0.02,0.45); node.add_child(shadow)
	if reward:
		var body: Polygon2D = Polygon2D.new()
		body.name="Body"
		body.polygon=PackedVector2Array([Vector2(-7,-10),Vector2(0,-20),Vector2(7,-10),Vector2(0,-2)])
		body.color=Color("c6ae77"); node.add_child(body)
		var outline: Line2D = Line2D.new()
		outline.points=body.polygon; outline.closed=true; outline.width=1.5; outline.default_color=Color("3c3025"); node.add_child(outline)
		var label: Label = Label.new()
		label.name="Label"
		label.text=item.label
		label.position=Vector2(-112,-44) if item.kind=="equipment" else Vector2(-10,-32)
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_color",Color("f1dfb6"))
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_y",1)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE; node.add_child(label)
	else:
		var bottle: Sprite2D = Sprite2D.new()
		bottle.name="Bottle"; bottle.texture=POTIONS[item.kind]
		bottle.centered=false; bottle.offset=Vector2(-bottle.texture.get_width()/2.0,-bottle.texture.get_height())
		bottle.scale=Vector2.ONE*28.0/bottle.texture.get_height(); bottle.position.y=-2
		bottle.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; node.add_child(bottle)
	var selection: Line2D = Line2D.new()
	selection.name="Selection"; selection.closed=true; selection.width=1.5
	selection.default_color=Color("f5df97")
	for index in 24:
		var angle: float = TAU*index/24
		selection.add_point(Vector2(cos(angle)*16,sin(angle)*5))
	selection.visible=false; node.add_child(selection)
	return node
