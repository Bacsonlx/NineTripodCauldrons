extends RefCounted

func run(check: Callable) -> void:
	var base: Dictionary = TrainingRoom.new({"spawn":Vector2(400,600),"enemy":Vector2(760,600),"encounter":Vector2(400,600)}).layout.duplicate(true)
	for blocks in [false,true]:
		var data: Dictionary = base.duplicate(true)
		data.obstacles=[{"x":600,"y":600,"halfWidth":75,"halfHeight":20,"height":100,"kind":"root","blocksProjectiles":blocks}]
		for action in ["fire","pierce"]:
			var room: TrainingRoom = TrainingRoom.new(data)
			room.update({action:true,"aim":Vector2(1000,549)},0.7)
			var health: int = room.snapshot().enemies[0].health
			check.call(health==60 if blocks else health<60,("高实体拦截" if blocks else "低矮装饰不拦截")+action)
			check.call(not room.can_walk(Vector2(600,600)),"投射物开关不改变实体移动阻挡")
	var map: Node2D = load("res://scenes/rooms/court2.tscn").instantiate()
	var stones: Array = map.build_layout().obstacles.filter(func(item: Dictionary): return item.x==750 and item.y==630)
	check.call(stones.size()==1 and not stones[0].get("blocksProjectiles",true),"正式扶桑残石已导出不拦箭属性")
	map.free()
