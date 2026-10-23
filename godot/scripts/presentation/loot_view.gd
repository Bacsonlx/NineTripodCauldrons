extends Node2D

var items: Dictionary = {}

func update_state(state: Dictionary) -> void:
	var live: Dictionary = {}
	var target: String = str(state.interaction.get("dropId","")) if state.interaction!=null else ""
	for item in state.get("drops",[])+state.get("rewardPlaceholders",[]):
		var id: String = str(item.get("id","reward:"+item.kind))
		live[id]=true
		if not items.has(id): items[id]=make_item(item)
		var node: Node2D = items[id]
		node.position=Vector2(item.x,item.y); node.z_index=int(item.y)
		node.get_node("Selection").visible=id==target and state.interaction.reason==null
	for id in items.keys():
		if not live.has(id):
			items[id].queue_free(); items.erase(id)

func make_item(item: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	add_child(node)
	var reward: bool = item.kind in ["equipment","item"]
	var color: Color = Color("bd5a45") if item.kind=="health" else Color("539ba9") if item.kind=="mana" else Color("c6ae77")
	var shadow: Polygon2D = Polygon2D.new()
	shadow.polygon=PackedVector2Array([Vector2(-13,0),Vector2(0,-4),Vector2(13,0),Vector2(0,4)])
	shadow.color=Color(0.02,0.03,0.02,0.45); node.add_child(shadow)
	var body: Polygon2D = Polygon2D.new()
	body.polygon=PackedVector2Array([Vector2(-10,-12),Vector2(0,-24),Vector2(10,-12),Vector2(0,-2)]) if reward else PackedVector2Array([Vector2(-7,-3),Vector2(-8,-14),Vector2(-4,-20),Vector2(-4,-25),Vector2(4,-25),Vector2(4,-20),Vector2(8,-14),Vector2(7,-3)])
	body.color=color; node.add_child(body)
	var outline: Line2D = Line2D.new()
	outline.points=body.polygon; outline.closed=true; outline.width=2; outline.default_color=Color("3c3025"); node.add_child(outline)
	var label: Label = Label.new()
	label.text=item.label if reward else "血" if item.kind=="health" else "蓝"
	label.position=Vector2(-152,-60) if item.kind=="equipment" else Vector2(-12,-40) if reward else Vector2(-10,-48)
	label.add_theme_font_size_override("font_size",12 if reward else 14)
	label.add_theme_color_override("font_color",Color("f1dfb6"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; node.add_child(label)
	var selection: Line2D = Line2D.new()
	selection.name="Selection"; selection.closed=true; selection.width=2
	selection.default_color=Color("f5df97")
	selection.points=PackedVector2Array([Vector2(-15,-8),Vector2(0,-14),Vector2(15,-8),Vector2(0,-2)])
	selection.visible=false; node.add_child(selection)
	return node
