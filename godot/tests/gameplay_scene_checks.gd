extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	check(not game.camp_panel.panel.visible and not game.room.snapshot().alpha.camp,"正常首关背包默认关闭，不自动弹出")
	check(game.hud.bag_button!=null and game.hud.bag_button.is_visible_in_tree() and game.hud.bag_button.text.contains("背包"),"右下角提供固定背包入口按钮与B快捷键提示")
	var event_b: InputEventKey = InputEventKey.new()
	event_b.physical_keycode=KEY_B; event_b.pressed=true
	game._unhandled_input(event_b)
	game.camp_panel.refresh()
	check(game.camp_panel.panel.visible and game.room.snapshot().alpha.camp,"在入口营地按B打开营地整理")
	check(game.camp_panel.panel.size.x>=root.size.x and game.camp_panel.panel.size.y>=root.size.y,"营地面板覆盖视口，防止背景点击误攻击")
	var items: Array = game.room.snapshot().alpha.items
	var bow: int = -1
	var horn: int = -1
	for item in items:
		if item.name=="训练弓": bow=item.id
		if item.name=="羊角": horn=item.id
	game.camp_panel.equipment_ui.command_requested.emit({"action":"embed","equipmentId":bow,"glyphId":horn})
	check(game.room.snapshot().alpha.equipment.healthMax==130 and game.hud.health.max_value==100,"装备界面嵌符先预览，上限尚未应用")
	var depart: Button = game.camp_panel.depart_button
	check(depart!=null,"营地提供实际确认出发按钮")
	if depart!=null: depart.pressed.emit()
	game.present(game.room.snapshot(),0)
	check(not game.camp_panel.panel.visible and game.room.snapshot().healthMax==130 and game.hud.health_value.text=="100 / 130","按钮出发隐藏营地并同步真实生命上限HUD")
	check(not game.controls.fire and game.controls.movement()==Vector2.ZERO,"点击出发不残留移动或射箭意图")
	game.hud.bag_button.pressed.emit()
	game.camp_panel.refresh()
	check(game.camp_panel.panel.visible and game.room.snapshot().alpha.camp,"点击右下角入口重新打开营地")
	var esc_event: InputEventKey = InputEventKey.new()
	esc_event.physical_keycode=KEY_ESCAPE; esc_event.pressed=true
	game._input(esc_event)
	check(not game.camp_panel.panel.visible and not game.room.snapshot().alpha.camp,"Esc键关闭背包并恢复行动")
	game.journey.restart(); game.present_new_room()
	game.camp_panel.refresh()
	check(game.camp_panel.room==game.room and game.camp_panel.controls==game.controls and not game.camp_panel.panel.visible,"新局面板重新绑定当前模型且默认关闭")
	check(game.room.snapshot().healthMax==100 and game.room.snapshot().alpha.items.size()==6,"界面重开不沿用旧羊角或旧实例")
	game.queue_free(); await process_frame
	print(JSON.stringify({"gameplay_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
