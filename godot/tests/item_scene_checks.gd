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
	var pictured: bool = true
	for index in game.camp_panel.item_list.item_count:
		pictured=pictured and game.camp_panel.item_list.get_item_icon(index)!=null
	check(pictured,"首关实际营地列表的装备、技能书和十二件原型均有图像")
	var art = load("res://scripts/presentation/item_art.gd")
	var catalog = load("res://scripts/alpha/alpha_state.gd")
	var complete_art: bool = true
	for row in catalog.CONTENT:
		var image: Texture2D = art.texture(row[0])
		complete_art=complete_art and image!=null
		if image is AtlasTexture:
			complete_art=complete_art and image.atlas.get_size()==Vector2(256,256) and Rect2(Vector2.ZERO,image.atlas.get_size()).encloses(image.region)
	check(complete_art,"二十项当前首关内容均能加载透明图标，导入限制256且裁切不越界")
	check(game.camp_panel.grid_art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"跨格图像不截获营地点击")
	var menus: Array = [game.camp_panel.equipment_ui.equipment,game.camp_panel.equipment_ui.loose_glyphs,game.camp_panel.skills_ui.sources]
	var menu_art: bool = true
	for menu in menus:
		for index in menu.item_count: menu_art=menu_art and menu.get_item_icon(index)!=null
	check(menu_art,"初始装备、实物符、镶嵌箭雨与地面教学书选择器都有图像")
	game.camp_panel.click_cell(Vector2i(0,0)); game.camp_panel.refresh()
	check(game.camp_panel.detail_image.visible and game.camp_panel.detail_image.texture==art.texture("训练弓"),"点击被图像覆盖的真实装备格仍能选中训练弓并显示详情图")
	check(art.texture("灰烬·快马")==art.texture("快马") and art.tint({"state":"ash"})!=art.tint({"state":"normal"}),"灰烬保留来源轮廓并以不同状态色呈现")
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
	game.journey.restart(); game.present_new_room(); game.camp_panel.refresh()
	check(game.camp_panel.item_list.item_count==10 and not game.camp_panel.detail_image.visible,"重开后物品图像列表清理原型且选中详情不残留")
	game.queue_free(); await process_frame
	print(JSON.stringify({"item_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
