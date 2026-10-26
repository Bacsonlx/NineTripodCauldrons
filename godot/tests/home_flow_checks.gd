extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("首页流程检查超时"); quit(1))
	run.call_deferred()

func button_with_text(node: Node,text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found: Button = button_with_text(child,text)
		if found!=null: return found
	return null

func run() -> void:
	var entry: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var initial: Node = entry.instantiate()
	root.add_child(initial); current_scene=initial
	await process_frame
	await process_frame
	var start: Button = button_with_text(current_scene,"踏入汤谷")
	check(start!=null,"默认启动显示首页的真实征程入口")
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
	check(current_scene.scene_file_path=="res://scenes/tanggu_first_level.tscn","确认后切换到现有真实八房首关")
	if current_scene.has_method("create_room"):
		current_scene.set_physics_process(false)
		var snapshot: Dictionary = current_scene.journey.snapshot()
		check(snapshot.roomId=="entry" and snapshot.health==100 and snapshot.resources.mana==100,"征程从正常入口和默认资源开始")
		check(snapshot.has("drops"),"首关仍启用正式药瓶规则")
	change_scene_to_file("res://scenes/home.tscn")
	await scene_changed
	for target in [["Boss 测试\n索尔雷庭","boss"],["野怪测试\n第一庭 · 战斗与掉落","court1"],["完整地图\n汤谷 · 八房","entry"]]:
		var portal: Button = button_with_text(current_scene,target[0])
		check(portal!=null,"首页提供可用测试入口："+target[0])
		if portal==null: break
		portal.pressed.emit()
		button_with_text(current_scene,"返回准备").pressed.emit()
		check(current_scene.scene_file_path=="res://scenes/home.tscn","取消确认保持首页")
		portal.pressed.emit()
		button_with_text(current_scene,"确认入局").pressed.emit()
		await scene_changed
		current_scene.set_physics_process(false)
		var game: Node = current_scene
		var state: Dictionary = game.journey.snapshot()
		check(state.roomId==target[1] and state.health==100 and state.resources.mana==100,"所选测试从对应房间满资源开始："+target[1])
		check(state.paused==state.alpha.camp,"新测试仅因入口营地暂停，不继承旧局暂停")
		if state.alpha.camp:
			button_with_text(game,"确认构筑并出发").pressed.emit()
		var run_id: int = game.journey.snapshot().runId
		key(KEY_R)
		check(game.journey.snapshot().roomId==target[1] and game.journey.snapshot().runId>run_id,"R 重开仍使用当前测试起点")
		var back: Button = button_with_text(game,"返回首页")
		check(back!=null and not back.is_visible_in_tree(),"战斗时隐藏返回首页按钮")
		if back==null: break
		key(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		check(game.journey.snapshot().paused and back.is_visible_in_tree(),"Esc 暂停后显示返回首页")
		key(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		check(game.journey.snapshot().paused==game.journey.snapshot().alpha.camp and not back.is_visible_in_tree(),"Esc 恢复游戏并隐藏返回首页")
		key(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		back.pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path=="res://scenes/home.tscn","暂停菜单能返回首页继续选测试")
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
