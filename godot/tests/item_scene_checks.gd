extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("道具原型场景超时"); quit(1))
	run.call_deferred()
func run() -> void:
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false); await process_frame
	var button: Button
	for node in game.camp_panel.find_children("*","Button",true,false):
		if node.text.begins_with("领取十二件"): button=node; break
	check(button!=null,"实际首关营地可发现十二件道具原型入口")
	if button!=null: button.pressed.emit()
	var original: Dictionary = game.room.snapshot()
	check(original.alpha.items.filter(func(item: Dictionary): return item.get("prototype",false)).size()==12,"实际按钮领取全十二件唯一实物")
	if button!=null: button.pressed.emit()
	check(game.room.snapshot().alpha.items.size()==original.alpha.items.size(),"重复按钮不复制原型")
	var helper = load("res://tests/item_use_checks.gd").new()
	var horse: int = helper.id(game.room,"快马",true)
	for intent in [{"action":"embed","equipmentId":helper.id(game.room,"训练弓"),"glyphId":helper.id(game.room,"羊角")},{"action":"embed","equipmentId":helper.id(game.room,"布履"),"glyphId":helper.id(game.room,"鼠毫")},{"action":"pickup","id":horse},{"action":"quick_bind","id":horse},{"action":"depart"}]: game.camp_panel.send(intent)
	game.present(game.room.snapshot(),0)
	check(game.item_label.text.contains("快马 #") and game.item_label.text.contains("原型B"),"HUD明确显示V引用目标和原型点燃边界")
	game.controls.key_down(KEY_V); game.controls.key_up(KEY_V)
	game.present(game.controls.update(Vector2(500,660),true,0),0)
	check(game.room.snapshot().itemEffects.haste==3 and game.item_label.text.contains("快马3.0秒"),"真实V短按驱动消费、效果与只读HUD")
	var before: Dictionary = game.room.snapshot()
	game.skill_view.update(before); game.present(before,0)
	check(game.room.snapshot()==before,"原型表现和HUD不会重复消费或计层")
	game.room.set_paused(true); var effect: Dictionary = game.room.snapshot().itemEffects
	game.room.update({},20)
	check(game.room.snapshot().itemEffects==effect,"暂停冻结器的真实持续时间")
	game.queue_free(); await process_frame
	print(JSON.stringify({"item_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
