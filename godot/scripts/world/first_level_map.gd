@tool
extends "res://scripts/world/map_definition.gd"

func _ready() -> void:
	if not Engine.is_editor_hint(): $Walkable.hide()

func build_layout() -> Dictionary:
	var data: Dictionary = super.build_layout()
	data.walkablePolygons=[]
	for area in $Walkable.get_children():
		if area is Polygon2D: data.walkablePolygons.append(area.transform*area.polygon)
	# 门楼保留中间通道，柱脚等子实体使用相对建筑的坐标。
	for item in get_children():
		if not item.has_method("update_state"): continue
		for foot in item.get_children():
			if not foot is MapItem or foot.category!="obstacle": continue
			var point: Vector2 = item.position+foot.position
			data.obstacles.append({"x":point.x,"y":point.y,"kind":foot.obstacle_kind,"halfWidth":foot.size.x/2,"halfHeight":foot.size.y/2,"height":foot.body_height})
	# 互动锚点存为建筑子节点，移动建筑时与美术、碰撞一起移动。
	for name in ["Stele","Altar","ReturnGate"]:
		var anchor: Marker2D = get_node(name+"/InteractionAnchor")
		var point: Vector2 = get_node(name).position+anchor.position
		var id: String = {"Stele":"stele","Altar":"altar","ReturnGate":"gate"}[name]
		for interaction in data.exploration:
			if interaction.id==id: interaction.x=point.x; interaction.y=point.y
	return data
