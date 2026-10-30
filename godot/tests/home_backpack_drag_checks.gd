extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event

func find_item(items: Array, title: String) -> Dictionary:
	for item in items:
		if item.get("name", "") == title:
			return item
	return {}

func run() -> void:
	var home: Control = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	home.show_bag_panel(true)
	await process_frame
	await process_frame

	var alpha: RefCounted = home.prepared_alpha
	var bow: Dictionary = find_item(alpha.items, "训练弓")
	var goat: Dictionary = find_item(alpha.items, "羊角")
	var mouse: Dictionary = find_item(alpha.items, "鼠毫")
	check(not bow.is_empty() and not goat.is_empty() and not mouse.is_empty(), "首页拖拽检查使用真实初始物品")
	check(home.backpack_cells.all(func(cell: Button): return cell.text.is_empty()), "普通背包格不再显示装、符、祭等区域首字")

	var bow_cell: Button = home.backpack_cells[bow.cell.y * 10 + bow.cell.x]
	var empty_cell: Button = home.backpack_cells[0 * 10 + 0]
	var bow_origin: Vector2i = bow.cell
	home.on_backpack_cell_input(mouse_button(bow_cell.get_global_rect().get_center(), true), bow_origin)
	check(home.dragging and home.drag_id == bow.id, "按住初始页面物品进入拖拽状态")
	var bow_target: Vector2 = empty_cell.get_global_rect().get_center()
	home._input(mouse_button(bow_target, false))
	check(alpha.find_item(bow.id).cell == bow_origin, "拖回原位不会产生无意义移动")

	var valid_target: Button = home.backpack_cells[2 * 10 + 0]
	home.on_backpack_cell_input(mouse_button(bow_cell.get_global_rect().get_center(), true), bow_origin)
	home._input(mouse_button(valid_target.get_global_rect().get_center(), false))
	var moved_bow: Dictionary = alpha.find_item(bow.id)
	check(moved_bow.cell == Vector2i(0, 2) and moved_bow.region == "equipment", "拖拽物品后真实布局更新")
	check(str(home.bag_feedback.text).contains("已摆放"), "成功放置提供结果反馈")

	var goat_cell: Button = home.backpack_cells[goat.cell.y * 10 + goat.cell.x]
	var mouse_cell: Button = home.backpack_cells[mouse.cell.y * 10 + mouse.cell.x]
	var goat_position: Vector2i = goat.cell
	home.on_backpack_cell_input(mouse_button(goat_cell.get_global_rect().get_center(), true), goat_position)
	home._input(mouse_button(mouse_cell.get_global_rect().get_center(), false))
	check(alpha.find_item(goat.id).cell == Vector2i(7, 4) and alpha.find_item(mouse.id).cell == goat_position, "同尺寸物品拖拽可交换位置")

	var moved_origin: Vector2i = moved_bow.cell
	var moved_bow_cell: Button = home.backpack_cells[moved_origin.y * 10 + moved_origin.x]
	var invalid_cell: Button = home.backpack_cells[3 * 10 + 9]
	home.on_backpack_cell_input(mouse_button(moved_bow_cell.get_global_rect().get_center(), true), moved_origin)
	home._input(mouse_button(invalid_cell.get_global_rect().get_center(), false))
	check(alpha.find_item(bow.id).cell == moved_origin, "非法目标释放后物品保留原位")
	check(str(home.bag_feedback.text).contains("无法放置"), "非法目标提供明确失败反馈")

	var talisman_target: Button = home.backpack_cells[3 * 10 + 5]
	var swapped_goat: Dictionary = alpha.find_item(goat.id)
	var swapped_goat_cell: Button = home.backpack_cells[swapped_goat.cell.y * 10 + swapped_goat.cell.x]
	home.on_backpack_cell_input(mouse_button(swapped_goat_cell.get_global_rect().get_center(), true), swapped_goat.cell)
	home._input(mouse_button(talisman_target.get_global_rect().get_center(), false))
	check(alpha.find_item(goat.id).region == "equipment", "符类物品拖入装备区后进入装备状态")
	check(home.equipped.get("talisman", "") == "talis_goat", "角色装备摘要与背包状态同步")

	home.queue_free()
	current_scene = null
	await process_frame
	print(JSON.stringify({"home_backpack_drag_checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("首页背包拖拽检查超时"); quit(1))
	run.call_deferred()
