extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	scene_changed.connect(func():
		if current_scene!=null: current_scene.set_physics_process(false))
	create_timer(60).timeout.connect(func(): push_error("首页流程检查超时"); quit(1))
	run.call_deferred()

func button_with_text(node: Node,text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found: Button = button_with_text(child,text)
		if found!=null: return found
	return null

func run() -> void:
	# 旧首页保留为开发夹具，正式入口由安全屋流程检查覆盖。
	var entry: PackedScene = load("res://scenes/home.tscn")
	var initial: Node = entry.instantiate()
	root.add_child(initial); current_scene=initial
	await process_frame
	await process_frame
	var start: Button = button_with_text(current_scene,"踏入汤谷")
	check(start!=null,"开发夹具可从旧首页启动征程")
	if start==null:
		current_scene.queue_free(); current_scene=null
		await process_frame
		print(JSON.stringify({"home_flow_checks":checks,"failures":failures})); quit(1); return
	check(not current_scene.has_method("create_room"),"未确认出发前不启动战斗场景")
	start.pressed.emit()
	await process_frame
	var confirm: Button = button_with_text(current_scene,"确认入局")
	check(confirm!=null and confirm.is_visible_in_tree(),"出发先显示确认层")
	if confirm!=null: confirm.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path=="res://scenes/tanggu_first_level.tscn","确认后切换到真实十六房首关")
	if current_scene.has_method("create_room"):
		current_scene.set_physics_process(false)
		var snapshot: Dictionary = current_scene.journey.snapshot()
		check(snapshot.roomId=="entry" and snapshot.health==100 and snapshot.resources.mana==100 and snapshot.resources.stamina==100 and not snapshot.isTest,"征程从正常入口和默认资源开始")
		check(snapshot.has("drops"),"首关仍启用正式药瓶规则")
	change_scene_to_file("res://scenes/home.tscn")
	await scene_changed
	var targets: Array[String] = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end","moss_side","stele_side","ember_side"]
	for target in targets:
		var quick: Button = button_with_text(current_scene,"自选起点\n从已开放房间开始")
		check(quick!=null,"首页提供独立自选起点入口")
		if quick==null: break
		quick.pressed.emit()
		var rooms: OptionButton = current_scene.find_child("RoomChoice",true,false)
		check(rooms!=null and rooms.item_count==16,"自选起点提供16个已实现房间")
		if rooms==null: break
		var selected: int = -1
		for i in rooms.item_count:
			if rooms.get_item_metadata(i)==target: selected=i
		check(selected>=0,"可选择行程起点："+target)
		if selected<0: break
		rooms.select(selected); rooms.item_selected.emit(selected)
		button_with_text(current_scene,"进入行程").pressed.emit()
		button_with_text(current_scene,"返回准备").pressed.emit()
		check(current_scene.scene_file_path=="res://scenes/home.tscn","取消确认保持首页")
		button_with_text(current_scene,"进入行程").pressed.emit()
		button_with_text(current_scene,"确认入局").pressed.emit()
		await scene_changed
		current_scene.set_physics_process(false)
		var game: Node = current_scene
		var state: Dictionary = game.journey.snapshot()
		check(state.roomId==target and state.health==100 and state.resources.mana==100 and state.resources.stamina==100,"所选起点从对应房间默认资源开始："+target)
		check(state.isTest and not state.journeyComplete and state.visitedRooms==1,"自选起点保持独立身份且不伪造前序完成："+target)
		check(state.paused==state.alpha.camp,"新测试仅因入口营地暂停，不继承旧局暂停")
		if state.alpha.camp:
			game.camp_panel.open_backpack()
			button_with_text(game,"确认构筑并出发").pressed.emit()
		var run_id: int = game.journey.snapshot().runId
		key(KEY_R)
		var retried: Dictionary = game.journey.snapshot()
		check(retried.roomId==target and retried.runId>run_id and retried.isTest,"R直接重开当前测试起点并保留测试身份："+str({"roomId":retried.roomId,"runId":retried.runId,"before":run_id,"isTest":retried.isTest,"camp":retried.alpha.camp}))
		if game.journey.snapshot().alpha.camp:
			game.camp_panel.open_backpack()
			button_with_text(game,"确认构筑并出发").pressed.emit()
		var back: Button = button_with_text(game,"返回首页")
		check(back!=null and not back.is_visible_in_tree(),"战斗时隐藏返回首页按钮")
		if back==null: break
		key(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		check(game.journey.snapshot().paused and back.is_visible_in_tree(),"Esc暂停后显示返回首页："+str({"paused":game.journey.snapshot().paused,"visible":back.is_visible_in_tree(),"alphaCamp":game.journey.snapshot().alpha.camp}))
		key(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		check(not game.journey.snapshot().paused and not back.is_visible_in_tree(),"Esc恢复并隐藏返回首页："+str({"paused":game.journey.snapshot().paused,"visible":back.is_visible_in_tree(),"alphaCamp":game.journey.snapshot().alpha.camp}))
		key(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		back.pressed.emit()
		var confirm_home: Button = button_with_text(game,"确认返回首页")
		check(confirm_home!=null and current_scene==game,"返回首页先确认，不能立即丢弃本局")
		if confirm_home==null: break
		confirm_home.pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path=="res://scenes/home.tscn","确认后返回首页继续选测试")
	current_scene.queue_free(); current_scene=null
	await process_frame
	print(JSON.stringify({"home_flow_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=true
	root.push_input(event)
	event=InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=false
	root.push_input(event)
