extends SceneTree

const Alpha = preload("res://scripts/alpha/alpha_state.gd")
const Geometry = preload("res://scripts/alpha/altar_geometry.gd")

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	# 1. 赛菲莉娅核心：祭坛主位 2x2 与环位 12 格几何定义验证
	var core_points: Array[Vector2i] = [Vector2i(7,1), Vector2i(8,1), Vector2i(7,2), Vector2i(8,2)]
	for pt in core_points:
		check(Geometry.is_in_core(pt), "主位应精确包含中央2x2点: " + str(pt))
	check(not Geometry.is_in_core(Vector2i(6,0)), "外圈(6,0)属于环位而非主位")
	check(not Geometry.is_in_core(Vector2i(6,4)), "收纳区(6,4)不属于祭坛")
	check(Geometry.is_in_altar(Vector2i(6,0)) and Geometry.is_in_altar(Vector2i(9,3)), "祭坛4x4四角属于祭坛")

	# 2. 几何正交相邻判定
	check(Geometry.is_cell_adjacent(Vector2i(7,1), Vector2i(6,1)), "左右相邻曼哈顿距离为1")
	check(Geometry.is_cell_adjacent(Vector2i(7,1), Vector2i(7,2)), "上下相邻曼哈顿距离为1")
	check(not Geometry.is_cell_adjacent(Vector2i(7,1), Vector2i(6,2)), "对角线不判定为正交相邻")

	# 3. 祭坛摆放与通电网络传导测试
	var alpha_inst: RefCounted = Alpha.new(1, true)
	alpha_inst.reset(Vector2.ZERO)
	# 默认开局：训练弓在(0,0)，布履在(3,0)，青龙在(4,1)，羊角、鼠毫、素食在收纳区
	# 将羊角与虎牙摆入祭坛相邻格：羊角在(6,1)，虎牙在(6,2)
	var horn_item: Dictionary = {}
	for it in alpha_inst.items:
		if it.name == "羊角": horn_item = it; break
	alpha_inst.place(horn_item, Vector2i(6,1), false)
	# 添加虎牙实物到(6,2)
	var tiger_item: Dictionary = alpha_inst.add_item("虎牙", "altar", Vector2i(6,2))
	alpha_inst.recount()

	var analysis: Dictionary = alpha_inst.snapshot().altarAnalysis
	check(analysis.energized_ids.has(horn_item.id) and analysis.energized_ids.has(tiger_item.id), "相邻的生肖符产生共鸣通电")
	var has_mine_synergy: bool = false
	for syn in analysis.synergies:
		if syn.title == "埋雷箭矢":
			has_mine_synergy = true; break
	check(has_mine_synergy, "羊角与虎牙相邻点亮【埋雷箭矢】动作手感改造")

	# 4. 主位器通电传导测试
	# 在主位(7,1)放入快马(器，1x2，占用(7,1)与(7,2))
	var horse_item: Dictionary = alpha_inst.add_item("快马", "altar", Vector2i(7,1))
	alpha_inst.recount()
	var analysis2: Dictionary = alpha_inst.snapshot().altarAnalysis
	check(analysis2.core_items.has(horse_item.id), "快马正确识别为主位·器")
	var has_push_synergy: bool = false
	for syn in analysis2.synergies:
		if syn.title == "推击强控":
			has_push_synergy = true; break
	check(has_push_synergy, "主位快马与相邻虎牙点亮【推击强控】动作手感改造")

	# 5. 星界战士核心：神兽祝词（青龙引风）演化测试
	check(alpha_inst.snapshot().blessingTier == 1, "初始神兽祝词为初念")
	check(alpha_inst.snapshot().blessingEvolvesLeft == 2, "每局初始拥有2次重念演化机会")
	
	# 在安全营地演化
	alpha_inst.command({"action": "evolve_blessing"}, null)
	check(alpha_inst.snapshot().blessingTier == 2, "第一次演化成功提升为再念")
	check(alpha_inst.snapshot().blessingEvolvesLeft == 1, "演化后剩余1次机会")
	check(alpha_inst.snapshot().blessingTierName.contains("再念"), "阶位名称显示再念")

	# 第二次演化
	alpha_inst.command({"action": "evolve_blessing"}, null)
	check(alpha_inst.snapshot().blessingTier == 3, "第二次演化成功提升为三念（完成形态）")
	check(alpha_inst.snapshot().blessingEvolvesLeft == 0, "演化机会用尽")
	check(not alpha_inst.snapshot().canEvolveBlessing, "演化机会用尽后不可再演化")

	# 再次尝试演化应被拒绝
	alpha_inst.command({"action": "evolve_blessing"}, null)
	check(alpha_inst.snapshot().blessingTier == 3, "超过局限2次后不再演化")

	# 6. 场景级与HUD暖雪克制美学与交互验证
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame

	check(game.hud.bag_button != null, "HUD常驻背包入口")
	check(game.hud.bag_button.text == "背包 · B", "未打开时HUD入口为【背包 · B】")
	check(not game.camp_panel.backpack_open, "进入游戏背包默认关闭")

	# 按 B 键打开
	var event_b: InputEventKey = InputEventKey.new()
	event_b.physical_keycode = KEY_B; event_b.pressed = true
	game._unhandled_input(event_b)
	game.camp_panel.refresh()
	game.present(game.room.snapshot(), 0)

	check(game.camp_panel.backpack_open, "按B键打开背包")
	check(game.hud.bag_button.text == "收起 · B", "打开后HUD入口切换为【收起 · B】")
	check(game.camp_panel.blessing_label != null and game.camp_panel.blessing_label.text.contains("青龙引风"), "背包展示神兽祝福专区")
	check(game.camp_panel.synergy_label != null, "背包展示祭坛空间邻接改造词条")

	# 再次按 B 键关闭
	game._unhandled_input(event_b)
	game.camp_panel.refresh()
	game.present(game.room.snapshot(), 0)
	check(not game.camp_panel.backpack_open, "再次按B键收起背包")
	check(game.hud.bag_button.text == "背包 · B", "收起后HUD入口恢复为【背包 · B】")

	game.queue_free()
	await process_frame

	print(JSON.stringify({"backpack_deep_checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
