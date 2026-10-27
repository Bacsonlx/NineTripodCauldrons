extends Control

const Journey = preload("res://scripts/journey/room_journey.gd")
const HERO = preload("res://assets/ui/home-v1/hero-refined-v2.png")
const PAPER = Color("f4e5be")
const GOLD = Color("c5a363")
const DIM = Color("b9a88a")
const SLOTS: Array = [["weapon","主武","bow"],["armor","衣","robe"],["boots","履","boot"],["talisman","符","talisman"],["relic","器","relic"],["beast","神兽","beast"]]
var items: Array = []
var equipped: Dictionary = {"weapon":"bow_training","armor":"robe_hemp","boots":"boots_cloth","talisman":"","relic":"","beast":""}
var tab: String = "stash"
var category: String = "all"
var selected: String = ""
var preview: String = ""
var launching: bool = false
var departure_mode: String = "full"
var room_choices: Array[String] = []
var room_maps: Dictionary = {}
var selected_room: String = "entry"
var mode_buttons: Dictionary = {}
var test_fields: VBoxContainer
var room_choice: OptionButton
var mode_summary: Label
var footer_title: Label
var footer_summary: Label
var warehouse_start: Button
var modal: Control
var modal_focus: Control
var start_button: Button
var slot_list: VBoxContainer
var inventory: GridContainer
var detail: VBoxContainer
var tags: Label
var notice: Label
var warehouse_count: Label
@onready var sections: VBoxContainer = $Layout/Sections
@onready var main: HBoxContainer = $Layout/Sections/Main
@onready var warehouse: HBoxContainer = $Layout/Sections/Warehouse
@onready var footer: HBoxContainer = $Layout/Sections/Footer

func _ready() -> void:
	items=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/home-v1/items.json"))
	build_theme()
	build_header()
	build_modes()
	build_stage($Layout/Sections/Main/Stage)
	build_gear()
	build_footer()
	build_warehouse()
	resized.connect(layout_inventory)
	if DisplayServer.get_name()!="headless": get_window().mode=Window.MODE_MAXIMIZED
	start_button.grab_focus.call_deferred()

func box(color: Color,border: Color=Color("8d75444d")) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=color; style.border_color=border; style.set_border_width_all(1)
	style.set_content_margin_all(12)
	return style

func build_theme() -> void:
	theme=Theme.new(); theme.default_font=preload("res://assets/fonts/NineTripodsHudSong.ttf")
	theme.default_font.allow_system_fallback=false
	theme.default_font_size=15
	theme.set_color("font_color","Label",PAPER)
	theme.set_color("font_color","Button",PAPER)
	theme.set_color("font_hover_color","Button",Color("fff2d2"))
	theme.set_color("font_disabled_color","Button",Color("93876f"))
	theme.set_stylebox("normal","Button",box(Color("10150ee6")))
	theme.set_stylebox("hover","Button",box(Color("332e1be6"),GOLD))
	theme.set_stylebox("pressed","Button",box(Color("69291bd9"),GOLD))
	theme.set_stylebox("hover_pressed","Button",box(Color("823321ed"),GOLD))
	theme.set_color("font_pressed_color","Button",PAPER)
	theme.set_color("font_hover_pressed_color","Button",PAPER)
	theme.set_stylebox("disabled","Button",box(Color("141710b8")))
	theme.set_stylebox("focus","Button",box(Color(0,0,0,0),Color("ffe0a1")))
	theme.set_stylebox("panel","PanelContainer",box(Color("0c110ee8")))
	for style in ["normal","hover","pressed","disabled","focus"]:
		theme.set_stylebox(style,"OptionButton",theme.get_stylebox(style,"Button"))
	theme.set_color("font_color","OptionButton",PAPER)
	theme.set_stylebox("panel","PopupMenu",box(Color("0c110e"),GOLD))
	theme.set_color("font_color","PopupMenu",PAPER)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func text(value: String,font_size: int=15,color: Color=PAPER) -> Label:
	var label: Label = Label.new()
	label.text=value; label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func button(value: String,parent: Node,action: Callable,accent: bool=false) -> Button:
	var node: Button = Button.new()
	node.text=value; node.pressed.connect(action); parent.add_child(node)
	if accent:
		node.add_theme_stylebox_override("normal",box(Color("a42b1ced"),Color("d59169")))
		node.add_theme_stylebox_override("hover",box(Color("c13c24"),Color("e9bc8a")))
	return node

func column(parent: Node) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.add_theme_constant_override("separation",8); parent.add_child(node)
	return node

func spacer(parent: Node) -> Control:
	var node: Control = Control.new()
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL; node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node); return node

func picture(texture: Texture2D) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture=texture; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return image

func icon(name_text: String) -> Texture2D:
	return load("res://assets/ui/home-v1/icons/%s.svg" % name_text)

func build_header() -> void:
	var header: HBoxContainer = $Layout/Sections/Header
	var seal: Button = button("九",header,func(): show_warehouse(false),true)
	seal.add_theme_font_size_override("font_size",30)
	var brand: VBoxContainer = column(header)
	brand.add_theme_constant_override("separation",0)
	brand.add_child(text("九 鼎",30)); brand.add_child(text("十 日 · 汤 谷",11,DIM))
	spacer(header)
	header.add_child(text("祠 庙 · 供 台",18,GOLD))
	spacer(header)
	header.add_child(text("香火  未接入\n碎片  未接入",11,DIM))
	header.add_child(text("未入局",16))
	button("？",header,show_help)

func build_modes() -> void:
	for id in Journey.ROOM_IDS:
		var path: String = "res://scenes/rooms/%s.tscn" % id
		if not ResourceLoader.exists(path): continue
		var scene: PackedScene = load(path)
		if scene==null: continue
		var map: Node = scene.instantiate()
		room_maps[id]=map.build_layout(); map.free()
	var rail: VBoxContainer = column($Layout/Sections/Main/Modes)
	rail.add_child(text("选择行程",11,DIM)); rail.add_child(text("行 程",28))
	var group: ButtonGroup = ButtonGroup.new()
	for entry in [["full","完整征程\n汤谷首关 · 目标15–20分钟"],["quick","快速测试\n选择关卡与房间起点"]]:
		var portal: Button = button(entry[1],rail,select_mode.bind(entry[0]))
		portal.toggle_mode=true; portal.button_group=group
		portal.alignment=HORIZONTAL_ALIGNMENT_LEFT; portal.custom_minimum_size.y=80
		# 原生按钮保留完整可访问名称，子控件分别排版标题与说明。
		portal.add_theme_font_size_override("font_size",12)
		for color_name in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
			portal.add_theme_color_override(color_name,Color.TRANSPARENT)
		for state_name in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBox = portal.get_theme_stylebox(state_name).duplicate()
			style.content_margin_left=66; style.content_margin_right=28
			portal.add_theme_stylebox_override(state_name,style)
		var seal: PanelContainer = PanelContainer.new(); seal.mouse_filter=Control.MOUSE_FILTER_IGNORE
		seal.position=Vector2(10,14); seal.custom_minimum_size=Vector2(42,42)
		var seal_style: StyleBoxFlat = box(Color("a42b1ced"),GOLD); seal_style.set_content_margin_all(4)
		seal.add_theme_stylebox_override("panel",seal_style); portal.add_child(seal)
		var glyph: Label = text("山" if entry[0]=="full" else "电",26)
		glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; seal.add_child(glyph)
		var caption: VBoxContainer = VBoxContainer.new(); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		portal.add_child(caption); caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left=66; caption.offset_right=-28; caption.offset_top=12; caption.offset_bottom=-12
		var lines: PackedStringArray = str(entry[1]).split("\n")
		caption.add_child(text(lines[0],22)); caption.add_child(text(lines[1],12,DIM))
		var mark: ColorRect = ColorRect.new(); mark.color=GOLD; mark.name="SelectionMark"
		mark.mouse_filter=Control.MOUSE_FILTER_IGNORE; portal.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		mark.offset_left=-18; mark.offset_right=-10; mark.offset_top=-4; mark.offset_bottom=4
		mode_buttons[entry[0]]=portal
	rail.add_child(HSeparator.new())
	test_fields=column(rail)
	test_fields.add_child(text("关卡",14,GOLD))
	var level: OptionButton = OptionButton.new(); level.name="LevelChoice"
	level.add_item("第一关 · 汤谷"); level.custom_minimum_size.y=38; test_fields.add_child(level)
	test_fields.add_child(text("房间起点",14,GOLD))
	room_choice=OptionButton.new(); room_choice.name="RoomChoice"
	room_choice.custom_minimum_size.y=38; room_choice.fit_to_longest_item=false
	test_fields.add_child(room_choice)
	var main_index: int = 0
	for id in Journey.ROOM_IDS:
		if not room_maps.has(id) or not ResourceLoader.exists("res://scenes/rooms/%s.tscn" % id): continue
		var branch: String = {"moss_side":"A","stele_side":"B","ember_side":"C"}.get(id,"")
		if branch.is_empty(): main_index+=1
		var number: String = "%02d" % main_index if branch.is_empty() else branch+" 支路"
		room_choices.append(id)
		room_choice.add_item(number+" · "+str(room_maps[id].roomTitle))
		room_choice.set_item_metadata(room_choice.item_count-1,id)
	room_choice.item_selected.connect(select_room)
	rail.add_child(HSeparator.new())
	mode_summary=text("",12,DIM); mode_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rail.add_child(mode_summary)
	select_mode("full")

func select_mode(mode: String) -> void:
	if modal!=null or launching: return
	departure_mode=mode
	if mode=="full": selected_room="entry"
	for id in mode_buttons:
		mode_buttons[id].set_pressed_no_signal(id==mode)
		mode_buttons[id].get_node("SelectionMark").visible=id==mode
	test_fields.visible=mode=="quick"
	room_choice.select(maxi(0,room_choices.find(selected_room)))
	refresh_departure()

func select_room(index: int) -> void:
	if modal!=null or launching: return
	selected_room=room_choices[index]
	refresh_departure()

func departure_arguments() -> Array:
	var arguments: Array = ["--test=level"]
	if departure_mode=="quick": arguments.append("--room="+selected_room)
	return arguments

func refresh_departure() -> void:
	var testing: bool = departure_mode=="quick"
	var title: String = "快速测试 · 汤谷" if testing else "完整征程 · 汤谷"
	var origin: String = str(room_maps.get(selected_room,{}).get("roomTitle","汤谷入口"))
	var summary: String = "起点："+origin+" · 生命／蓝量／精力100" if testing else "从汤谷入口开始 · 目标15–20分钟"
	mode_summary.text="新建测试局，可继续推进\n独立初始状态，不计正式通关" if testing else "从入口开启完整征程\n完成全部主线后前往出口"
	if start_button==null: return
	footer_title.text=title; footer_summary.text=summary
	start_button.text="进入测试" if testing else "踏入汤谷"
	if warehouse_start!=null: warehouse_start.text=start_button.text

func build_stage(stage: Control) -> void:
	var title: Label = text("后\n羿\n\n附体",28)
	title.position=Vector2(8,48); stage.add_child(title)
	var hero: Button = Button.new()
	hero.name="Portrait"; hero.tooltip_text="细观主角"; hero.pressed.connect(show_portrait)
	hero.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	hero.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	hero.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	hero.anchor_left=0.15; hero.anchor_right=0.85; hero.anchor_top=0.17; hero.anchor_bottom=0.82
	stage.add_child(hero)
	var image: TextureRect = picture(HERO)
	hero.add_child(image); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caption: Label = text("后羿 · 附体\n点击影偶 · 细观其形",12)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(caption); caption.anchor_left=0.15; caption.anchor_right=0.85
	caption.anchor_top=0.88; caption.anchor_bottom=0.98

func build_gear() -> void:
	var rail: VBoxContainer = column($Layout/Sections/Main/Gear)
	rail.add_child(text("本次神降",11,DIM)); rail.add_child(text("行 装",28))
	rail.add_child(text("试装预览 · 不带入战斗",12,GOLD))
	slot_list=column(rail)
	refresh_slots()
	button("仓　仓 库　›",rail,func(): show_warehouse(true),true)
	rail.add_child(text("行前试装 · 正式背包待接入",11,DIM))

func item_by_id(id: String) -> Dictionary:
	for item in items:
		if item.id==id: return item
	return {}

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child); child.queue_free()

func refresh_slots() -> void:
	clear_children(slot_list)
	for slot in SLOTS:
		var item: Dictionary = item_by_id(equipped[slot[0]])
		var node: Button = button(slot[1]+"　"+str(item.get("name","未备")),slot_list,open_slot.bind(slot[0]))
		node.alignment=HORIZONTAL_ALIGNMENT_LEFT
		node.icon=icon(slot[2]); node.expand_icon=true; node.add_theme_constant_override("icon_max_width",24)
		node.custom_minimum_size.y=42

func open_slot(slot: String) -> void:
	show_warehouse(true)
	category="charm" if slot in ["talisman","relic"] else "gear"
	refresh_inventory()

func build_footer() -> void:
	var description: VBoxContainer = column(footer)
	footer_title=text("",23); description.add_child(footer_title)
	footer_summary=text("",12,DIM); description.add_child(footer_summary)
	spacer(footer)
	notice=text("现有默认构筑 · 试装不带入战斗",12,GOLD)
	footer.add_child(notice); spacer(footer)
	start_button=button("踏入汤谷",footer,show_departure,true)
	start_button.add_theme_font_size_override("font_size",26)
	start_button.custom_minimum_size=Vector2(224,60)
	refresh_departure()

func build_warehouse() -> void:
	var left: PanelContainer = PanelContainer.new()
	left.custom_minimum_size.x=350; left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio=0.7; warehouse.add_child(left)
	var preview_box: VBoxContainer = column(left)
	button("返回祠庙",preview_box,func(): show_warehouse(false))
	var portrait: Control = Control.new()
	portrait.custom_minimum_size.y=140; portrait.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_box.add_child(portrait)
	var hero: TextureRect = picture(HERO)
	portrait.add_child(hero); hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tags=text("",12,GOLD); tags.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	portrait.add_child(tags); tags.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tags.offset_left=-140; tags.offset_top=12
	preview_box.add_child(text("后羿 · 行前试装预览",19))
	preview_box.add_child(text("所选物品暂不影响首关战斗。",13,DIM))
	warehouse_start=button(start_button.text,preview_box,show_departure,true)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; warehouse.add_child(panel)
	var right: VBoxContainer = column(panel)
	var tabs: HBoxContainer = HBoxContainer.new(); right.add_child(tabs)
	tabs.add_child(text("行前所藏",23)); spacer(tabs)
	button("仓库",tabs,set_tab.bind("stash")); button("行囊",tabs,set_tab.bind("bag"))
	warehouse_count=text("",12,GOLD); tabs.add_child(warehouse_count)
	var filters: HBoxContainer = HBoxContainer.new(); right.add_child(filters)
	for filter in [["all","全部"],["gear","装备"],["charm","符器"],["skill","技能"],["use","消耗"]]:
		button(filter[1],filters,set_category.bind(filter[0]))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; right.add_child(scroll)
	inventory=GridContainer.new(); inventory.columns=5
	inventory.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inventory.add_theme_constant_override("h_separation",6); inventory.add_theme_constant_override("v_separation",6)
	scroll.add_child(inventory)
	detail=column(right); detail.custom_minimum_size.y=104
	refresh_inventory()

func set_tab(value: String) -> void:
	tab=value; category="all"; selected=""; refresh_inventory()

func set_category(value: String) -> void:
	tab="stash"; category=value; selected=""; refresh_inventory()

func matches_category(item: Dictionary) -> bool:
	var slot: String = item.get("slot","")
	if tab=="bag": return item.id in equipped.values() or slot.is_empty()
	match category:
		"gear": return not slot.is_empty()
		"charm": return slot in ["talisman","relic"]
		"skill": return item.type=="技能书"
		"use": return item.type in ["消耗","材料"]
	return true

func refresh_inventory() -> void:
	clear_children(inventory)
	var count: int = 0
	for item in items:
		if not matches_category(item): continue
		count+=1
		var is_equipped: bool = item.id in equipped.values()
		var card: Button = button(str(item.name)+("\n已试装" if is_equipped else "\n"+str(item.type)),inventory,choose_item.bind(item.id),is_equipped)
		card.name=item.id; card.tooltip_text="试装预览："+str(item.name)
		card.icon=icon(item.icon); card.expand_icon=true; card.add_theme_constant_override("icon_max_width",22)
		card.add_theme_font_size_override("font_size",13)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.custom_minimum_size=Vector2(0,78)
		card.mouse_entered.connect(preview_item.bind(item.id)); card.mouse_exited.connect(preview_item.bind(""))
		card.focus_entered.connect(preview_item.bind(item.id)); card.focus_exited.connect(preview_item.bind(""))
	warehouse_count.text="%d 件 · %s" % [count,"行囊预览" if tab=="bag" else "仓库预览"]
	preview_item("")
	refresh_detail()
	layout_inventory.call_deferred()

func choose_item(id: String) -> void:
	selected=id
	var item: Dictionary = item_by_id(id)
	var slot: String = item.get("slot","")
	if not slot.is_empty(): equipped[slot]="" if equipped[slot]==id else id
	refresh_slots(); refresh_inventory()
	var card: Button = inventory.get_node_or_null(NodePath(id))
	if card!=null: card.grab_focus()

func refresh_detail() -> void:
	clear_children(detail)
	var item: Dictionary = item_by_id(selected)
	detail.add_child(text(str(item.get("name","行前整理 · 预览")),20))
	var description: Label = text("原型说明（未生效）："+str(item.desc) if not item.is_empty() else "点击物品试装，悬停或聚焦查看六器签。",12,DIM)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.add_child(description)
	detail.add_child(text("本轮征程使用既有默认配置；试装不会改变战斗属性。",12,GOLD))

func preview_item(id: String) -> void:
	preview=id
	var lines: PackedStringArray = []
	var item: Dictionary = item_by_id(id)
	for slot in SLOTS:
		var hot: bool = item.get("slot","")==slot[0]
		var current: Dictionary = item_by_id(equipped[slot[0]])
		lines.append(slot[1]+" · "+("预览 "+str(item.name) if hot else str(current.get("name","未备"))))
	tags.text="\n".join(lines)

func layout_inventory() -> void:
	if inventory==null: return
	inventory.columns=5 if size.x>=1200 else 4 if size.x>=1000 else 3
	$Layout/Sections/Main/Modes.custom_minimum_size.x=maxf(224,size.x*0.19)
	$Layout/Sections/Main/Gear.custom_minimum_size.x=244 if size.x>=1100 else 208
	warehouse.get_child(0).custom_minimum_size.x=350 if size.x>=1100 else 260
	notice.visible=size.x>=1100

func show_warehouse(open: bool) -> void:
	main.visible=not open; footer.visible=not open; warehouse.visible=open
	if open:
		refresh_inventory()
		button_focus(warehouse,"返回祠庙")
	else: start_button.grab_focus()

func button_focus(parent: Node,caption: String) -> void:
	for child in parent.get_children():
		if child is Button and child.text==caption: child.grab_focus(); return
		button_focus(child,caption)

func open_modal(title: String) -> VBoxContainer:
	modal_focus=get_viewport().gui_get_focus_owner()
	modal=Control.new(); modal.name="HomeDialog"; add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new(); shade.color=Color("030703ec")
	modal.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	modal.add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x=minf(560,size.x-48); center.add_child(panel)
	var content: VBoxContainer = column(panel)
	content.add_child(text(title,28,GOLD))
	return content

func trap_modal_focus(content: Control) -> void:
	var buttons: Array[Button] = []
	for child in content.get_children():
		if child is Button: buttons.append(child)
	for index in buttons.size():
		var previous: NodePath = buttons[index].get_path_to(buttons[(index+buttons.size()-1)%buttons.size()])
		var next: NodePath = buttons[index].get_path_to(buttons[(index+1)%buttons.size()])
		buttons[index].focus_previous=previous; buttons[index].focus_next=next
		buttons[index].focus_neighbor_top=previous; buttons[index].focus_neighbor_bottom=next
		buttons[index].focus_neighbor_left=previous; buttons[index].focus_neighbor_right=next
	if not buttons.is_empty(): buttons[0].grab_focus()

func close_modal() -> void:
	if modal==null or launching: return
	remove_child(modal); modal.queue_free(); modal=null
	if is_instance_valid(modal_focus): modal_focus.grab_focus()

func show_departure() -> void:
	if modal!=null or launching: return
	var testing: bool = departure_mode=="quick"
	var content: VBoxContainer = open_modal("快速测试 · 汤谷" if testing else "完整征程 · 汤谷")
	var origin: String = str(room_maps[selected_room].roomTitle)
	for line in ["起点："+origin+(" · 不计正式完整通关，可继续推进。" if testing else " · 完成全部主线后前往出口。"), "生命、蓝量与精力100 · Esc 暂停后可返回首页。", "本次将以现有首关默认角色、技能与数值出发。", "仓库试装预览不带入战斗；不写入存档。"]:
		var label: Label = text(line,15,DIM)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(label)
	button("返回准备",content,close_modal)
	button("确认入局",content,confirm_departure,true)
	trap_modal_focus(content)

func confirm_departure() -> void:
	if launching or modal==null: return
	launching=true
	get_viewport().set_input_as_handled()
	enter_journey.call_deferred()

func enter_journey() -> void:
	get_tree().set_meta("home_test_arguments",departure_arguments())
	var error: Error = get_tree().change_scene_to_file("res://scenes/tanggu_first_level.tscn")
	if error!=OK:
		get_tree().remove_meta("home_test_arguments")
		launching=false; close_modal(); notice.text="首关加载失败，请重试。"; push_error("首关加载失败："+str(error))

func show_portrait() -> void:
	if modal!=null: return
	var content: VBoxContainer = open_modal("后羿 · 附体")
	var image: TextureRect = picture(HERO)
	image.custom_minimum_size=Vector2(0,minf(size.y-180,600)); content.add_child(image)
	button("返回供台",content,close_modal)
	trap_modal_focus(content)

func show_help() -> void:
	if modal!=null: return
	var content: VBoxContainer = open_modal("祠庙 · 供台")
	for line in ["行程：完整征程，或选择房间进行快速测试。", "仓库：仅行前试装预览，不改变战斗配置。", "香火、碎片与存档尚未接入。", "Esc 关闭当前面板；F11 切换全屏。"]:
		content.add_child(text(line,15,DIM))
	button("继续查看",content,close_modal)
	trap_modal_focus(content)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_ESCAPE:
		if modal!=null: close_modal()
		elif warehouse.visible: show_warehouse(false)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_F11:
		get_window().mode=Window.MODE_MAXIMIZED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
