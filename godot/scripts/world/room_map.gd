@tool
extends "res://scripts/world/map_definition.gd"

@export var room_id: String = "entry"
@export var room_title: String = "汤谷入口"
@export_enum("safe","combat","explore","boss") var objective: String = "safe"

func build_layout() -> Dictionary:
	var data: Dictionary = super.build_layout()
	data.roomId=room_id; data.roomTitle=room_title; data.objective=objective
	data.walkablePolygons=[]; data.doors=[]
	for area in $Walkable.get_children(): data.walkablePolygons.append($Walkable.transform*area.transform*area.polygon)
	for door in $Doors.get_children():
		data.doors.append(door.definition())
		for foot in door.get_children():
			if foot is MapItem and foot.category=="obstacle":
				var point: Vector2 = $Doors.position+door.position+foot.position
				var obstacle_data: Dictionary = {"x":point.x,"y":point.y,"kind":foot.obstacle_kind,"halfWidth":foot.size.x/2,"halfHeight":foot.size.y/2,"height":foot.body_height}
				if not foot.blocks_projectiles: obstacle_data.blocksProjectiles=false
				data.obstacles.append(obstacle_data)
	for item in get_children():
		if not item is MapItem: continue
		for foot in item.get_children():
			if foot is MapItem and foot.category=="interaction":
				data.exploration.append({"id":foot.interaction_id,"x":item.position.x+foot.position.x,"y":item.position.y+foot.position.y})
			if foot is MapItem and foot.category=="obstacle":
				var obstacle_data: Dictionary = {"x":item.position.x+foot.position.x,"y":item.position.y+foot.position.y,"kind":foot.obstacle_kind,"halfWidth":foot.size.x/2,"halfHeight":foot.size.y/2,"height":foot.body_height}
				if not foot.blocks_projectiles: obstacle_data.blocksProjectiles=false
				data.obstacles.append(obstacle_data)
	return data

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not has_node("Doors") or not has_node("Walkable"): return ["房间缺少 Doors 或 Walkable"]
	if transform!=Transform2D.IDENTITY: errors.append("房间根节点必须保持原点、无旋转且缩放为1")
	for node in [$Doors]+$Doors.get_children()+get_children():
		if node is Node2D and (node.rotation!=0 or node.scale!=Vector2.ONE): errors.append(str(node.name)+"：不支持节点旋转或缩放，请调整素材宽度和占地")
	if not world_size.is_finite() or world_size.x<=0 or world_size.y<=0: errors.append("房间尺寸无效")
	var data: Dictionary = build_layout()
	if room_id.is_empty() or room_title.is_empty(): errors.append("房间缺少标识或名称")
	if data.doors.is_empty(): errors.append("房间缺少出入口")
	if objective=="combat" and data.encounters.is_empty(): errors.append("战斗房缺少遭遇")
	if objective=="explore" and data.exploration.filter(func(item: Dictionary): return item.id=="stele").is_empty(): errors.append("探索房缺少残碑任务")
	var model: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(data)
	for wave in data.encounters:
		if wave.enemies.is_empty(): errors.append("波次缺少敌人")
		if wave.enemies.size()>=100: errors.append("单波敌人数须小于100")
	if not model.can_walk(TrainingRoom.point(data.spawn)): errors.append("房间出生点不可行走")
	var ids: Dictionary = {}
	for door in data.doors:
		if ids.has(door.id) or door.id.is_empty(): errors.append("重复或空白门标识")
		ids[door.id]=true
		if not model.can_walk(TrainingRoom.point(door.arrival)) or not model.can_walk(TrainingRoom.point(door.point)): errors.append("门前出生或互动位置受阻："+door.id)
		if not model.clear_path(TrainingRoom.point(door.arrival),TrainingRoom.point(door.point)): errors.append("门前通路不连续："+door.id)
	for enemy in model.snapshot().enemies:
		if not model.can_walk(Vector2(enemy.x,enemy.y)): errors.append("敌人出生点受阻")
		elif model.find_route(Vector2(enemy.x,enemy.y),TrainingRoom.point(data.encounters[enemy.group])).is_empty(): errors.append("敌人出生点无法到达本波战斗中心")
	return errors
