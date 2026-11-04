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
	game.camp_panel.open_backpack()
	check(game.camp_panel.skills_ui.visible and game.camp_panel.skills_ui.summary.text.contains("羁绊：训练弓＋布履"),"默认营地显示自动技能来源和羁绊组成")
	check(game.camp_panel.skills_ui.find_children("*","Button",true,false).is_empty(),"技能来源面板没有手动启用、选源或镶嵌按钮")
	game.camp_panel.send({"action":"place","id":id(game,"布履"),"cell":Vector2i(9,0)})
	check(game.camp_panel.skills_ui.summary.text.contains("缺少有效穿戴：布履"),"卸履后营地解释回风与羁绊失效原因")
	game.present(game.room.snapshot(),0)
	check(game.hud.costs.backwind.text=="需布履" and game.hud.costs.charge.text=="需弓＋履" and game.hud.slots.backwind.insufficient,"HUD缺来源时保留技能名并明确显示条件")
	game.camp_panel.send({"action":"place","id":id(game,"布履"),"cell":Vector2i(3,0)})
	game.camp_panel.send({"action":"depart"}); game.present(game.room.snapshot(),0)
	check(game.hud.captions.rain.text=="箭雨" and game.hud.costs.rain.text=="28 蓝量" and game.hud.captions.backwind.text=="回风" and game.hud.captions.charge.text=="蓄势","E/G/T自动显示对应技能和原费用")
	check(game.hud.slots.pierce.tooltip_text.contains("消耗：12 蓝量") and game.hud.slots.pierce.tooltip_text.contains("冷却：4.0 秒"),"Q悬停说明显示真实蓝量消耗和冷却")
	check(game.hud.slots.rain.tooltip_text.contains("消耗：28 蓝量") and game.hud.slots.rain.tooltip_text.contains("冷却：8.0 秒"),"E悬停说明显示真实蓝量消耗和冷却")
	check(game.hud.loadout_actions==game.hud.actions and game.hud.loadout_actions.visible and not game.hud.source_summary.visible and game.hud.actions.get_child_count()==7 and game.hud.captions.wind.text=="引风","HUD将G/T/C与普攻、Q/E、闪避合并为一行，来源改由悬停说明提供")
	var expected_order: Array[String] = ["Attack","Pierce","Rain","Backwind","Charge","Wind","Dodge"]
	for index in expected_order.size():
		check(game.hud.actions.get_child(index).name==expected_order[index],"技能栏第%d槽为%s" % [index+1,expected_order[index]])
	check(game.hud.source_legend.visible and game.hud.source_legend.text.contains("人物基础") and game.hud.source_legend.text.contains("青龙"),"技能栏直接显示基础操作与来源技能分层")
	check(game.hud.slots.backwind.icon.resource_path.ends_with("skill-candidates-v2/backwind.png") and game.hud.slots.wind.icon.resource_path.ends_with("skill-candidates-v2/wind.png") and game.hud.slots.dodge.icon.resource_path.ends_with("skill-candidates-v2/dodge.png"),"回风、引风、闪避使用独立候选图标")
	var missing: String = ""
	var font: Font = game.hud.theme.default_font
	for text in [game.camp_panel.skills_ui.summary.text,game.hud.source_summary.text]:
		for character in text:
			if character.unicode_at(0)>32 and not font.has_char(character.unicode_at(0)) and not missing.contains(character): missing+=character
	check(missing.is_empty(),"随包字体覆盖新技能来源与羁绊文案，缺字："+missing)
	check(game.hud.slots.backwind.tooltip_text.contains("来源：装备：布履") and game.hud.slots.charge.tooltip_text.contains("来源：羁绊：训练弓＋布履"),"G/T悬停说明读取真实技能来源")
	check(game.hud.slots.backwind.tooltip_text.contains("方向：") and game.hud.slots.backwind.tooltip_text.contains("阻挡：") and game.hud.slots.backwind.tooltip_text.contains("无敌：否"),"回风说明包含方向、阻挡和无敌状态")
	check(game.hud.slots.wind.tooltip_text.contains("追加：") and game.hud.slots.wind.tooltip_text.contains("风道"),"引风说明包含风道追加合同")
	check(game.hud.slots.dodge.tooltip_text.contains("无敌：是") and game.hud.slots.dodge.tooltip_text.contains("25 精力"),"闪避说明明确基础来源、精力消耗和短暂无敌")
	game.controls.key_down(KEY_T); game.controls.key_up(KEY_T)
	game.present(game.controls.update(Vector2(800,608),true,0.01),0)
	check(game.hud.slots.charge.counter.text=="10.0" and game.hud.mana.value==84 and game.skill_view.state.charge.layers==2,"T短按只支付16蓝，HUD冷却与手部层数跟真实状态一致")
	game.controls.key_down(KEY_D); game.controls.key_down(KEY_C)
	game.present(game.controls.update(Vector2(800,608),true,0.2),0)
	game.controls.key_up(KEY_D)
	check(not game.skill_view.has_active_dash({"skillDash":{"kind":"wind","remaining":0.0}}),"冲刺结束后不再绘制残留轨迹")
	check(not game.skill_view.state.windPath.is_empty() and game.hud.captions.wind.text=="引风回息" and game.hud.costs.wind.text=="精力+20","首次引风显示风道，HUD区分恢复性追加")
	check(game.hud.slots.wind.availability=="extra_ready","合法风道内将引风槽标为追加可用")
	var before: Dictionary = game.room.snapshot()
	game.skill_view.update(before); game.hud.update_state(before)
	check(game.room.snapshot()==before,"技能表现与HUD不重新结算费用或消耗追加机会")
	for dimensions in [Vector2(800,450),Vector2(1280,720),Vector2(1920,1080)]:
		game.hud.size=dimensions; await process_frame
		check(Rect2(Vector2.ZERO,dimensions).encloses(game.hud.actions.get_rect()) and game.hud.actions.get_rect().end.x<dimensions.x/2 and game.hud.actions.size.y<=72,"%s单行动作栏不越界、不换行或遮中央" % dimensions)
	game.journey.restart(); game.present_new_room(); game.camp_panel.refresh()
	check(game.room.snapshot().charge.layers==0 and game.room.snapshot().windPath.is_empty() and game.room.snapshot().alpha.skills.rain.active,"R重开清旧增幅与风道，并从默认装备恢复资格")
	game.queue_free(); await process_frame
	var home: Control = load("res://scenes/home.tscn").instantiate()
	root.add_child(home); await process_frame
	check(home.items.all(func(entry: Dictionary): return entry.type!="技能书"),"首页独立预览库存也没有技能书")
	home.queue_free(); await process_frame
	print(JSON.stringify({"skill_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
