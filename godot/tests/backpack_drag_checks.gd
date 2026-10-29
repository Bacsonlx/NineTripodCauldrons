extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func find_item(items: Array, title: String) -> Dictionary:
	for item in items:
		if item.get("name", "") == title:
			return item
	return {}

func mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

func run() -> void:
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.camp_panel.open_backpack()
	game.camp_panel.refresh()
	await process_frame
	await process_frame

	var alpha: RefCounted = game.room.alpha
	var bow: Dictionary = find_item(alpha.items, "训练弓")
	var shoes: Dictionary = find_item(alpha.items, "布履")
	check(not bow.is_empty() and not shoes.is_empty(), "背包拖拽回归需要初始训练弓和布履")

	# 点击另一件物品只切换选择，不移动原物品。
	var bow_button: Button = game.camp_panel.grid_cells[bow.cell.y * 10 + bow.cell.x]
	var shoes_button: Button = game.camp_panel.grid_cells[shoes.cell.y * 10 + shoes.cell.x]
	alpha.message = "拖拽空操作基线"
	game.camp_panel.on_cell_input(mouse_button(bow_button.get_global_rect().get_center(), true), bow.cell)
	game.camp_panel._input(mouse_button(bow_button.get_global_rect().get_center(), false))
	game.camp_panel.on_cell_input(mouse_button(shoes_button.get_global_rect().get_center(), true), shoes.cell)
	game.camp_panel._input(mouse_button(shoes_button.get_global_rect().get_center(), false))
	check(game.camp_panel.selected == shoes.id, "点击其他物品后应默认切换到其他物品")
	check(alpha.message == "拖拽空操作基线", "原地点击物品不应提交无意义的放置操作")
	var bow_after_switch: Dictionary = alpha.find_item(bow.id)
	check(bow_after_switch.cell == bow.cell and bow_after_switch.region == bow.region, "切换选择不应移动原物品")

	# 非法拖拽目标按物品占用的每个可见格显示红色预览并给出原因。
	game.camp_panel.click_cell(bow.cell)
	game.camp_panel.on_cell_hover(Vector2i(9, 3))
	var invalid_preview: Dictionary = game.camp_panel.grid_art.hover_preview
	check(not invalid_preview.get("valid", true), "越界拖拽预览应判定为不可放置")
	check(invalid_preview.get("cells", []).size() > 0, "非法拖拽预览应覆盖目标物品占用的可见格")
	check(game.camp_panel.selection_hint.text.begins_with("无法放置："), "非法拖拽应在背包中提示失败原因")

	# 模拟完整拖拽：按住训练弓并放到祭坛左上角。
	game.camp_panel.click_cell(bow.cell)
	game.camp_panel.begin_drag(bow.cell)
	game.camp_panel.update_drag_preview(Vector2i(6, 0))
	check(game.camp_panel.drag_valid, "拖拽到合法祭坛位置应显示可放置")
	var target_button: Button = game.camp_panel.grid_cells[6]
	var target_point: Vector2 = target_button.get_global_rect().get_center()
	game.camp_panel.finish_drag(target_point)
	var moved_bow: Dictionary = alpha.find_item(bow.id)
	check(moved_bow.cell == Vector2i(6, 0) and moved_bow.region == "altar", "松开鼠标后应提交物品的新位置")

	# 真实输入链路：物品按下、移动、松开，不依赖测试直接调用 begin/finish。
	var empty_button: Button = game.camp_panel.grid_cells[3 * 10 + 0]
	game.camp_panel.on_cell_input(mouse_button(shoes_button.get_global_rect().get_center(), true), shoes.cell)
	check(game.camp_panel.dragging and game.camp_panel.selected == shoes.id, "按下物品应进入拖拽状态")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = empty_button.get_global_rect().get_center()
	game.camp_panel._input(motion)
	check(game.camp_panel.drag_valid and game.camp_panel.grid_art.hover_preview.get("cells", []).size() == 2, "拖拽移动应按布履两格显示合法预览")
	game.camp_panel._input(mouse_button(empty_button.get_global_rect().get_center(), false))
	var moved_shoes: Dictionary = alpha.find_item(shoes.id)
	check(moved_shoes.cell == Vector2i(0, 3) and moved_shoes.region == "equipment", "真实鼠标松开应放置到目标格")

	# 松开在网格外时保持原位置并保留失败提示。
	var before_outside: Vector2i = moved_shoes.cell
	var shoes_button_after: Button = game.camp_panel.grid_cells[before_outside.y * 10 + before_outside.x]
	game.camp_panel.on_cell_input(mouse_button(shoes_button_after.get_global_rect().get_center(), true), before_outside)
	game.camp_panel._input(mouse_button(Vector2(-100, -100), false))
	check(alpha.find_item(shoes.id).cell == before_outside, "网格外松开不应移动物品")
	check(game.camp_panel.selection_hint.text.contains("不在背包网格内"), "网格外松开应提示目标不在网格内")

	# 从多格物品的非左上格抓起时，应保持抓取点相对位置，而不是把左上角吸附到鼠标。
	var shoes_second_cell: Vector2i = before_outside + Vector2i(0, 1)
	var shoes_second_button: Button = game.camp_panel.grid_cells[shoes_second_cell.y * 10 + shoes_second_cell.x]
	var grab_target: Vector2i = Vector2i(3, 3)
	var grab_target_button: Button = game.camp_panel.grid_cells[grab_target.y * 10 + grab_target.x]
	game.camp_panel.on_cell_input(mouse_button(shoes_second_button.get_global_rect().get_center(), true), shoes_second_cell)
	check(game.camp_panel.drag_grab_offset == Vector2i(0, 1), "抓取多格物品应记录相对抓取点")
	var grab_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	grab_motion.position = grab_target_button.get_global_rect().get_center()
	game.camp_panel._input(grab_motion)
	check(game.camp_panel.drag_origin == Vector2i(3, 2), "拖拽预览应以抓取点保持物品相对位置")
	game.camp_panel._input(mouse_button(grab_target_button.get_global_rect().get_center(), false))
	var grabbed_shoes: Dictionary = alpha.find_item(shoes.id)
	check(grabbed_shoes.cell == Vector2i(3, 2), "多格物品应按相对抓取点落在鼠标目标位置")

	game.queue_free()
	await process_frame
	print(JSON.stringify({"backpack_drag_checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
