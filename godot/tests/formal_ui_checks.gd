extends SceneTree

var failures: Array[String]=[]
var checks: int=0
const FORBIDDEN: Array[String]=["DEBUG","调试","白盒","原型","待接通","未开放","可试用","票数预览","快速测试","试装","行囊","未接入","不带入战斗","占位"]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func visible_text(node: Node) -> String:
	var result: String=node.text if node is Label or node is Button else ""
	for child in node.get_children():
		if child is Control and child.visible: result+="\n"+visible_text(child)
	return result

func scan(label: String, node: Node) -> void:
	var text: String=visible_text(node)
	for forbidden in FORBIDDEN:
		check(not text.contains(forbidden),label+"仍显示开发态词汇："+forbidden)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var home: Control=load("res://scenes/home.tscn").instantiate()
	root.add_child(home); current_scene=home
	await process_frame
	await process_frame
	scan("首页",home)
	home.queue_free(); current_scene=null
	await process_frame

	var game: Node2D=load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); current_scene=game; game.set_physics_process(false)
	await process_frame
	scan("局内默认状态",game)
	game.camp_panel.open_backpack()
	game.camp_panel.refresh()
	scan("正式背包",game)
	check(not game.hud.bag_button.text.contains("调试"),"固定背包入口没有调试字样")
	game.queue_free(); current_scene=null
	await process_frame
	print(JSON.stringify({"formal_ui_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
