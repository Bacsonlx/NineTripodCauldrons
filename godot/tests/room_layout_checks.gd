extends SceneTree
const Journey = preload("res://scripts/journey/room_journey.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var maps: Dictionary = Journey.read_maps()
	check(maps.size()==16,"十六个独立房间及双向门配置合法")
	if maps.size()!=16: finish(); return
	check(maps.dry_creek.doors.size()==3 and maps.court2.doors.size()==3,"分支与汇合房均有三个独立门")
	var editable: Node2D = load("res://scenes/rooms/stele.tscn").instantiate()
	var original: Dictionary = editable.build_layout()
	editable.get_node("Stele").position.x+=40
	check(editable.build_layout().exploration[0].x==original.exploration[0].x+40,"移动残碑同步移动互动点")
	var after_building: Dictionary = editable.build_layout()
	editable.get_node("Doors").position+=Vector2(20,10)
	var shifted: Dictionary = editable.build_layout()
	check(shifted.doors[0].x==original.doors[0].x+20 and shifted.doors[0].arrival.y==original.doors[0].arrival.y+10,"移动门组同步移动封锁、互动与到达坐标")
	check(shifted.obstacles[0].x==after_building.obstacles[0].x,"移动门组不移动其他建筑")
	check(shifted.obstacles[-1].x==original.obstacles[-1].x+20,"移动门组同步移动柱脚碰撞")
	editable.get_node("Doors").scale=Vector2(2,1)
	check(not editable.validation_errors().is_empty(),"不支持的门组缩放返回明确校验错误")
	editable.free()
	for id in maps:
		var room: TrainingRoom = load("res://scripts/journey/journey_room.gd").new(maps[id])
		for door in maps[id].doors:
			var path: Array = room.find_route(TrainingRoom.point(maps[id].spawn),TrainingRoom.point(door.point))
			check(not path.is_empty(),id+"可到达门前："+door.id)
		if id=="court2":
			check(not room.can_walk(Vector2(750,630)) and not room.clear_path(Vector2(610,630),Vector2(890,630)) and not room.find_route(Vector2(610,630),Vector2(890,630)).is_empty(),"扶桑残庭残石阻挡直穿且能绕行")
		elif id in ["court1","court3"]:
			var clear: bool = true
			for x in [-200,0,200]:
				for y in [-100,0,100]: clear=clear and room.can_walk(Vector2(720+x,550+y))
			check(clear,id+"圆庭中央净空")
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.journey.update({"alpha":{"action":"depart"}},0)
	check(game.room.snapshot().roomId=="entry","默认入口加载房间流程")
	# 通过真实键盘输入沿新山径走到门前，不改写角色位置或房间状态。
	var entry_path: Array = game.room.find_route(TrainingRoom.point(game.room.snapshot().player),TrainingRoom.point(game.room.layout.doors[0].point))
	for waypoint in entry_path:
		for i in 500:
			var delta: Vector2 = waypoint-TrainingRoom.point(game.room.snapshot().player)
			if delta.length()<5: break
			for pair in [[KEY_D,delta.x>2],[KEY_A,delta.x< -2],[KEY_S,delta.y>2],[KEY_W,delta.y< -2]]:
				if pair[1]: game.controls.key_down(pair[0])
				else: game.controls.key_up(pair[0])
			game._physics_process(0.02)
	for key in [KEY_D,KEY_A,KEY_S,KEY_W]: game.controls.key_up(key)
	check(game.room.snapshot().interaction!=null and game.room.snapshot().interaction.id=="door:court1","实际呈现输入可走到门前并显示目标")
	game.controls.key_down(KEY_ESCAPE); game.controls.key_down(KEY_F); game._physics_process(0)
	check(game.room.snapshot().roomId=="entry","暂停期间F不能过门")
	game.controls.key_down(KEY_ESCAPE); game.controls.key_down(KEY_F); game._physics_process(0)
	check(game.room.snapshot().roomId=="court1" and game.get_node("TangguMap").room_id=="court1","F同时切换规则房间和实际场景")
	check(game.controls.movement()==Vector2.ZERO and not game.controls.fire,"切房清除移动与射击意图")
	var retry: InputEventKey = InputEventKey.new()
	retry.physical_keycode=KEY_R; retry.pressed=true
	game._unhandled_input(retry)
	check(game.room.snapshot().roomId=="court1" and game.get_node_or_null("JourneyConfirmationLayer/JourneyConfirmation")!=null,"完整征程实际R输入先确认，不直接清空进度")
	var confirm: Button = find_button(game,"确认重开")
	if confirm!=null: confirm.pressed.emit()
	await process_frame
	check(game.room.snapshot().roomId=="entry" and game.journey.snapshot().visitedRooms==1,"确认后重开全部房间进度")
	game.free()
	finish()
func finish() -> void:
	print(JSON.stringify({"room_layout_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func find_button(node: Node,text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found: Button = find_button(child,text)
		if found!=null: return found
	return null
