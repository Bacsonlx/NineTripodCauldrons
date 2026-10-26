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
	var missing: String = ""
	var font: Font = home.get_theme_font("font")
	for character in visible_text(home,false):
		if character.unicode_at(0)>32 and not font.has_char(character.unicode_at(0)) and not missing.contains(character): missing+=character
	check(missing.is_empty(),"随包字体覆盖首页与仓库显示文案，缺字："+missing)
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
	find_button(home,"仓　").pressed.emit()
	await process_frame
	check(visible_text(home).contains("24 件"),"仓库初始显示24件原型展示物品")
	find_button(home,"符器").pressed.emit()
	check(visible_text(home).contains("8 件"),"符器分类只显示8件符器")
	find_button(home,"燧火").pressed.emit()
	check(find_button(home,"燧火").text.contains("已试装"),"点击物品完成试装反馈")
	find_button(home,"行囊").pressed.emit()
	check(find_button(home,"燧火")!=null,"行囊预览包含已试装物品")
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
