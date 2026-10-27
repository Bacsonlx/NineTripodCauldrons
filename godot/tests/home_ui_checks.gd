extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var layouts: Array = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("首页界面检查超时"); quit(1))
	run.call_deferred()

func find_button(node: Node,prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found: Button = find_button(child,prefix)
		if found!=null: return found
	return null

func visible_text(node: Node,visible_only: bool=true) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children():
		if child is Control and (child.visible or not visible_only): result+="\n"+visible_text(child,visible_only)
	return result

func avatar_badge(home: Control,slot: String,view: String="stage") -> Dictionary:
	var badges: Array=home.get("avatar_badges")
	for entry in badges:
		if entry.slot==slot and entry.view==view: return entry
	return {}

func equipped_item(home: Control,slot: String) -> String:
	var equipped: Dictionary=home.get("equipped")
	return equipped.get(slot,"")

func escape_key() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode=KEY_ESCAPE; event.physical_keycode=KEY_ESCAPE; event.pressed=true
	root.push_input(event)

func run() -> void:
	var home: Control = load("res://scenes/home.tscn").instantiate()
	root.add_child(home); current_scene=home
	await process_frame
	await process_frame
	check(find_button(home,"完整征程")!=null and find_button(home,"快速测试")!=null,"完整征程与快速测试模式均在首页可见")
	check(visible_text(home).contains("未接入") and visible_text(home).contains("不带入战斗"),"界面明确标记未接入数据与试装范围")
	var armor_badge: Dictionary=avatar_badge(home,"armor")
	var weapon_badge: Dictionary=avatar_badge(home,"weapon")
	var bag_armor_badge: Dictionary=avatar_badge(home,"armor","bag")
	check(not armor_badge.is_empty() and armor_badge.badge.visible and armor_badge.label.text=="素麻衣","角色装备标记显示当前衣槽装备")
	check(not weapon_badge.is_empty() and weapon_badge.badge.visible and weapon_badge.label.text=="训练弓","角色装备标记显示当前武器")
	var original_weapon: String=equipped_item(home,"weapon")
	var preview_tags: Label=home.get("tags")
	home.call("preview_item","robe_red")
	check(equipped_item(home,"armor")=="robe_hemp" and armor_badge.label.text=="赤霞袍" and bag_armor_badge.label.text=="赤霞袍" and preview_tags.text.contains("衣 · 预览 赤霞袍"),"悬停预览只临时更新角色对应槽位展示，不改已装备状态")
	home.call("preview_item","")
	check(armor_badge.label.text=="素麻衣","结束悬停后角色展示恢复已装备物品")
	home.call("show_bag_panel",true)
	home.call("choose_item","robe_red")
	check(equipped_item(home,"armor")=="robe_red" and equipped_item(home,"weapon")==original_weapon and armor_badge.label.text=="赤霞袍" and bag_armor_badge.label.text=="赤霞袍" and preview_tags.text.contains("衣 · 赤霞袍"),"更换衣槽装备同步角色与行囊预览且不影响武器槽")
	home.call("choose_item","robe_hemp")
	check(equipped_item(home,"armor")=="robe_hemp" and armor_badge.label.text=="素麻衣","再次更换同槽装备更新角色展示")
	home.call("choose_item","robe_hemp")
	check(equipped_item(home,"armor")=="" and not armor_badge.badge.visible and not bag_armor_badge.badge.visible,"卸下衣槽后两处角色标记立即隐藏，不被焦点预览重新显示")
	home.call("choose_item","robe_hemp")
	var robe_card: Button=find_button(home,"赤霞袍")
	robe_card.mouse_entered.emit()
	check(armor_badge.label.text=="赤霞袍" and equipped_item(home,"armor")=="robe_hemp","鼠标进入物品卡仅预览对应装备")
	robe_card.mouse_exited.emit()
	check(armor_badge.label.text=="素麻衣","鼠标离开物品卡恢复已装备标记")
	robe_card.mouse_entered.emit()
	home.call("show_bag_panel",false)
	check(armor_badge.label.text=="素麻衣" and home.get("preview")=="","退出行囊清除临时预览，首页恢复实际试装")
	var missing: String = ""
	var font: Font = home.get_theme_font("font")
	for character in visible_text(home,false):
		if character.unicode_at(0)>32 and not font.has_char(character.unicode_at(0)) and not missing.contains(character): missing+=character
	check(missing.is_empty(),"随包字体覆盖首页与行囊显示文案，缺字："+missing)
	check(not visible_text(home).contains("仓库"),"初始页面不再展示仓库入口或设置项，背包入口仍保留")
	for target in [Vector2(1280,720),Vector2(1920,1080),Vector2(1680,720),Vector2(1280,900)]:
		home.size=target
		await process_frame
		await process_frame
		var stage: Control = home.get_node("Layout/Sections/Main/Stage")
		var gear: Control = home.get_node("Layout/Sections/Main/Gear")
		var footer: Control = home.get_node("Layout/Sections/Footer")
		var bounds: Rect2 = Rect2(Vector2.ZERO,target)
		var fits: bool = bounds.encloses(gear.get_global_rect()) and bounds.encloses(footer.get_global_rect()) and gear.get_global_rect().end.y<=footer.get_global_rect().position.y
		check(fits,"逻辑画布 %s 下行装栏与出发操作不越界、不相交" % target)
		check(stage.size.x>200,"逻辑画布 %s 保留中央人物空间" % target)
		layouts.append({"size":[target.x,target.y],"gear_bottom":gear.get_global_rect().end.y,"footer_top":footer.get_global_rect().position.y,"fits":fits})
	home.size=Vector2(1280,720)
	find_button(home,"行　").pressed.emit()
	await process_frame
	check(visible_text(home).contains("24 件"),"行囊显示24件可浏览的原型物品")
	find_button(home,"装备").pressed.emit()
	check(visible_text(home).contains("15 件"),"行囊装备分类保留全部装备选项")
	find_button(home,"符器").pressed.emit()
	check(visible_text(home).contains("8 件"),"符器分类只显示8件符器")
	find_button(home,"燧火").pressed.emit()
	check(find_button(home,"燧火").text.contains("已试装"),"点击物品完成试装反馈")
	check(find_button(home,"燧火")!=null and visible_text(home).contains("行囊"),"行囊保留筛选结果与已试装物品")
	escape_key()
	await process_frame
	check(home.get_node("Layout/Sections/Main").visible,"Esc经引擎输入管线返回供台")
	find_button(home,"踏入汤谷").grab_focus()
	find_button(home,"踏入汤谷").pressed.emit()
	var dialog: Control = home.get_node("HomeDialog")
	check(visible_text(dialog).contains("不带入战斗") and visible_text(dialog).contains("现有首关默认"),"真实出发确认明确不应用试装物品")
	check(dialog.is_ancestor_of(root.gui_get_focus_owner()),"确认层获得键盘焦点")
	escape_key()
	await process_frame
	check(home.get_node_or_null("HomeDialog")==null,"Esc关闭确认层且没有进入首关")
	check(root.gui_get_focus_owner()==find_button(home,"踏入汤谷"),"确认层关闭后焦点回到出发按钮")
	home.queue_free(); current_scene=null
	await process_frame
	print(JSON.stringify({"home_ui_checks":checks,"failures":failures,"layouts":layouts}))
	quit(0 if failures.is_empty() else 1)
