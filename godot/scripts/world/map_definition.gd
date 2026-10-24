@tool
class_name MapDefinition
extends Node2D

@export var world_size: Vector2 = Vector2(2560,1440)
@export var floor_polygon: PackedVector2Array = PackedVector2Array([Vector2(120,180),Vector2(2440,180),Vector2(2440,1310),Vector2(120,1310)])

func build_layout() -> Dictionary:
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
				if not item.blocks_projectiles: position_data.blocksProjectiles=false
				if not is_nan(item.marker_offset_y): position_data.markerOffsetY=item.marker_offset_y
				if item.opens_after_encounter>=0: position_data.opensAfterEncounter=item.opens_after_encounter
				layout.obstacles.append(position_data)
			"encounter":
				position_data.merge({"landmark":item.label,"enemies":[]})
				for enemy in item.get_children():
					if enemy is MapItem and enemy.category=="enemy":
						var spawn: Dictionary = {"x":item.position.x+enemy.position.x,"y":item.position.y+enemy.position.y,"appearance":enemy.appearance}
						if enemy.enemy_role!="appearance": spawn.role=enemy.enemy_role
						position_data.enemies.append(spawn)
				layout.encounters.append(position_data)
			"interaction": position_data.id=item.interaction_id; layout.exploration.append(position_data)
			"pillar": layout.pillars.append(position_data)
			"route": layout.mainRoute.append(position_data)
			"ground": position_data.merge({"width":item.size.x,"height":item.size.y}); layout.groundPatches.append(position_data)
	return layout

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not world_size.is_finite() or world_size.x<=0 or world_size.y<=0: errors.append("TangguMap.World Size 必须为有限正数")
	if floor_polygon.size()<3: errors.append("TangguMap.Floor Polygon 至少需要三个顶点")
	for vertex in floor_polygon:
		if not vertex.is_finite() or vertex.x<0 or vertex.y<0 or vertex.x>world_size.x or vertex.y>world_size.y: errors.append("TangguMap.Floor Polygon 顶点必须在世界范围内且为有限数值")
	for index in floor_polygon.size():
		var first: Vector2 = floor_polygon[(index+1)%floor_polygon.size()]-floor_polygon[index]
		var second: Vector2 = floor_polygon[(index+2)%floor_polygon.size()]-floor_polygon[(index+1)%floor_polygon.size()]
		if first.cross(second)<=0: errors.append("TangguMap.Floor Polygon 必须保持非退化的凸多边形顺序")
	if position!=Vector2.ZERO or rotation!=0 or scale!=Vector2.ONE: errors.append("TangguMap 根节点变换必须保持原点与原比例")
	var counts: Dictionary = {"spawn":0,"road":0,"encounter":0,"route":0,"stele":0,"altar":0,"gate":0}
	var interactions: Dictionary = {"stele":0,"altar":0,"gate":0}
	for item in get_children():
		if not item is MapItem: continue
		var prefix: String = str(item.name)+": "
		if item.category not in ["road","obstacle","spawn","encounter","interaction","pillar","route","ground"]: errors.append(prefix+"未知布局类型 "+item.category)
		if item.category=="road" and item.terrain_material not in ["path","stone"]: errors.append(prefix+"未知地面素材引用 "+item.terrain_material)
		if not item.position.is_finite(): errors.append(prefix+"Position 必须为有限数值")
		if item.scale!=Vector2.ONE or item.rotation!=0: errors.append(prefix+"布局使用 Position / Size，不支持节点旋转或缩放")
		if item.category in ["road","obstacle","ground"] and (not item.size.is_finite() or item.size.x<=0 or item.size.y<=0): errors.append(prefix+"Size 必须为有限正数")
		if counts.has(item.category): counts[item.category]+=1
		if item.category=="road" and (item.size.x<=24 or item.size.y<=24): errors.append(prefix+"道路宽高必须大于脚点直径24")
		if item.category=="obstacle":
			if not is_finite(item.body_height) or item.body_height<=0: errors.append(prefix+"Body Height 必须为有限正数")
			if item.obstacle_kind not in ["tree","root","wall","gate","stele","altar","brazier","waystone"]: errors.append(prefix+"未知的物件素材引用 "+item.obstacle_kind)
			if item.obstacle_kind in ["stele","altar","gate"]: counts[item.obstacle_kind]+=1
		if item.category=="interaction":
			if not interactions.has(item.interaction_id): errors.append(prefix+"未知的互动对象引用 "+item.interaction_id)
			else: interactions[item.interaction_id]+=1
		if item.category=="encounter":
			if item.get_child_count()==0: errors.append(prefix+"遭遇缺少敌人出生点")
			for enemy in item.get_children():
				if not enemy is MapItem or enemy.category!="enemy": errors.append(prefix+"子节点必须为敌人出生点"); continue
				if not enemy.position.is_finite() or enemy.appearance not in ["bird","paper","wood"]: errors.append(prefix+str(enemy.name)+" 出生或外观引用无效")
				if enemy.enemy_role not in ["appearance","bird","paper","wood"]: errors.append(prefix+str(enemy.name)+" 职责引用无效 "+enemy.enemy_role)
				if enemy.scale!=Vector2.ONE or enemy.rotation!=0: errors.append(prefix+str(enemy.name)+" 不支持节点旋转或缩放")
	if counts.spawn!=1: errors.append("TangguMap 必须恰有一个玩家出生点")
	if counts.road<1 or counts.encounter<1 or counts.route<2: errors.append("TangguMap 缺少道路、主路折线或战斗遭遇")
	for key in ["stele","altar","gate"]:
		if counts[key]!=1 or interactions[key]!=1: errors.append("TangguMap 需要唯一的 "+key+" 实体及对应互动点")
	if errors.is_empty():
		var data: Dictionary = build_layout()
		var room: TrainingRoom = TrainingRoom.new(data)
		if not room.can_walk(TrainingRoom.point(data.spawn)): errors.append("PlayerSpawn 位于不可行走区域或实体内部")
		for enemy in room.snapshot().enemies:
			if not room.can_walk(Vector2(enemy.x,enemy.y)): errors.append("敌人出生点 %d 位于不可行走区域或实体内部" % enemy.id)
		for item in data.exploration:
			if not room.can_walk(Vector2(item.x,item.y)): errors.append(item.id+" 互动点位于不可行走区域或实体内部")
	return errors

func get_layout() -> Dictionary:
	var errors: Array[String] = validation_errors()
	if not errors.is_empty():
		push_error("汤谷布局无效：\n"+"\n".join(errors)); return {}
	return build_layout()

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(validation_errors())
