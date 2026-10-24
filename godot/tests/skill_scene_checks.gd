extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func id(game: Node2D,title: String) -> int:
	for item in game.room.snapshot().alpha.items:
		if item.name==title: return item.id
	return -1
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("技能场景检查超时"); quit(1))
	run.call_deferred()
func run() -> void:
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	check(game.camp_panel.skills_ui.visible,"默认营地显示真实来源的技能镶书与E/G选择界面")
	for intent in [{"action":"embed","equipmentId":id(game,"训练弓"),"glyphId":id(game,"羊角")},{"action":"embed","equipmentId":id(game,"布履"),"glyphId":id(game,"鼠毫")},{"action":"pickup","id":id(game,"蓄势")},{"action":"place","id":id(game,"蓄势"),"cell":Vector2i(1,6),"rotated":true},{"action":"pickup","id":id(game,"回风")}]: game.camp_panel.send(intent)
	game.camp_panel.skills_ui.command_requested.emit({"action":"embed_book","equipmentId":id(game,"布履"),"bookId":id(game,"回风")})
	var wind_id: int = -1
	for source in game.room.snapshot().alpha.skillSources:
		if source.skill=="backwind": wind_id=source.id
	game.camp_panel.skills_ui.command_requested.emit({"action":"assign_special","slot":0,"sourceId":wind_id})
	game.camp_panel.skills_ui.command_requested.emit({"action":"assign_special","slot":1,"sourceId":id(game,"蓄势")})
	game.camp_panel.send({"action":"depart"})
	game.present(game.room.snapshot(),0)
	check(game.hud.captions.rain.text=="回风" and game.hud.costs.rain.text=="12 蓝量" and game.hud.captions.special2.text=="蓄势" and game.hud.costs.special2.text=="16 蓝量","E/G显示已选技能名称和确认蓝量成本")
	check(game.hud.loadout_actions.visible and game.hud.captions.wind.text=="引风","HUD提供独立G/C提示，保留普攻Q与基础闪避")
	game.controls.key_down(KEY_G); game.controls.key_up(KEY_G)
	game.present(game.controls.update(Vector2(800,608),true,0.01),0)
	check(game.hud.slots.special2.counter.text=="10.0" and game.hud.mana.value==84 and game.skill_view.state.charge.layers==2,"G短按只支付16蓝，HUD冷却与手部层数跟真实状态一致")
	game.controls.key_down(KEY_D); game.controls.key_down(KEY_C)
	game.present(game.controls.update(Vector2(800,608),true,0.2),0)
	game.controls.key_up(KEY_D)
	check(not game.skill_view.state.windPath.is_empty() and game.hud.captions.wind.text=="引风追加" and game.hud.costs.wind.text=="追加0蓝","首次引风显示实际风道，HUD区分预付追加与首次技能")
	var before: Dictionary = game.room.snapshot()
	game.skill_view.update(before); game.hud.update_state(before)
	check(game.room.snapshot()==before,"技能表现与HUD不重新结算费用或消耗追加机会")
	for dimensions in [Vector2(800,450),Vector2(1280,720),Vector2(1920,1080)]:
		game.hud.size=dimensions; await process_frame
		check(Rect2(Vector2.ZERO,dimensions).encloses(game.hud.loadout_actions.get_rect()) and game.hud.loadout_actions.get_rect().end.x<dimensions.x/2,"%s附加槽不越界或遮中央" % dimensions)
	game.journey.restart(); game.present_new_room()
	game.camp_panel.refresh()
	check(game.room.snapshot().charge.layers==0 and game.room.snapshot().windPath.is_empty() and game.room.snapshot().alpha.specialSlots[0].skill=="rain","R模型重开清旧增幅与风道，并恢复默认箭雨来源")
	game.queue_free(); await process_frame
	print(JSON.stringify({"skill_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
