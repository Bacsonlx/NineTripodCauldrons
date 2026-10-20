@tool
class_name MapDefinition
extends Node2D

@export var world_size: Vector2 = Vector2(2560,1440)
@export var floor_polygon: PackedVector2Array = PackedVector2Array([Vector2(120,180),Vector2(2440,180),Vector2(2440,1310),Vector2(120,1310)])

func get_layout() -> Dictionary:
	var layout: Dictionary = {"width":world_size.x,"height":world_size.y,"floor":[],"spawn":{"x":400,"y":820},"walkableAreas":[],"obstacles":[],"encounters":[],"exploration":[],"pillars":[],"targets":[],"mainRoute":[],"groundPatches":[],"shoulderHeight":52,"grips":[{"x":27,"y":-51},{"x":24,"y":-48},{"x":-21,"y":-48},{"x":-22,"y":-53}],"pillarBody":[[40,-122,-95],[26,-98,-22],[40,-28,0]],"targetFace":{"offsetY":-44.8,"radiusX":21.6,"radiusY":23.2}}
	for vertex in floor_polygon: layout.floor.append({"x":vertex.x,"y":vertex.y})
	for item in get_children():
		if not item is MapItem: continue
		var position_data: Dictionary = {"x":item.position.x,"y":item.position.y}
		match item.category:
			"spawn": layout.spawn=position_data
			"road": layout.walkableAreas.append({"name":item.label,"region":item.region,"material":item.terrain_material,"priority":item.priority,"left":item.position.x-item.size.x/2,"top":item.position.y-item.size.y/2,"right":item.position.x+item.size.x/2,"bottom":item.position.y+item.size.y/2})
			"obstacle":
				position_data.merge({"kind":item.obstacle_kind,"halfWidth":item.size.x/2,"halfHeight":item.size.y/2,"height":item.body_height})
				if not is_nan(item.marker_offset_y): position_data.markerOffsetY=item.marker_offset_y
				layout.obstacles.append(position_data)
			"encounter":
				position_data.merge({"landmark":item.label,"enemies":[]})
				for enemy in item.get_children():
					if enemy is MapItem and enemy.category=="enemy": position_data.enemies.append({"x":item.position.x+enemy.position.x,"y":item.position.y+enemy.position.y,"appearance":enemy.appearance})
				layout.encounters.append(position_data)
			"interaction": position_data.id=item.interaction_id; layout.exploration.append(position_data)
			"pillar": layout.pillars.append(position_data)
			"route": layout.mainRoute.append(position_data)
			"ground": position_data.merge({"width":item.size.x,"height":item.size.y}); layout.groundPatches.append(position_data)
	return layout
