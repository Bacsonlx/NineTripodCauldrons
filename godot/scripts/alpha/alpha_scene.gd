extends Node2D

const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
const State = preload("res://scripts/alpha/alpha_state.gd")
var room: TrainingRoom
var panel: PanelContainer
var status_label: Label
var detail: Label
var list: ItemList
var catalog: OptionButton
var cells: Array[Button] = []
var selected: int = -1
var rotated: bool = false
var last_items: String = ""
var battle_button: Button

func label(text: String, parent: Node) -> Label:
	var result: Label = Label.new()
	result.text=text
	parent.add_child(result)
	return result

func button(text: String, parent: Node, action: Callable) -> Button:
	var result: Button = Button.new()
	result.text=text
	result.pressed.connect(action)
	result.focus_mode=Control.FOCUS_NONE
	parent.add_child(result)
	return result

func _ready() -> void:
	var layout: Dictionary = $Reference.room.layout.duplicate(true)
	layout.mode="alpha"
	room=Room.new(layout)
	$Reference.room=room
	$Reference.controls=Controls.new(room)
	$Reference.state=room.snapshot()
	var reference_entry: Node = $Reference.find_child("OpenAlpha",true,false)
	if reference_entry: reference_entry.hide()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer=20; add_child(layer)
	battle_button=button("安全营地 / 白盒",layer,func(): send({"action":"camp"}))
	battle_button.position=Vector2(28,160)
	panel=PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	for edge in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+edge,20)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	margin.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	label("九鼎 · 汤谷初版白盒",column).add_theme_font_size_override("font_size",26)
	label("后羿：走射、排线、爆发 ｜ 鸟面追击 / 纸面远程 / 木甲精英 / 索尔单阶段：待接通",column)
	var actions: HBoxContainer = HBoxContainer.new(); column.add_child(actions)
	button("出发试操作",actions,func(): send({"action":"depart"}))
	button("Esc 暂停 / 继续",actions,func(): $Reference.controls.key_down(KEY_ESCAPE))
	button("迁移参照",actions,func(): get_tree().change_scene_to_file("res://scenes/tanggu.tscn"))
	status_label=label("",column)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var body: HBoxContainer = HBoxContainer.new(); column.add_child(body)
	var grid_column: VBoxContainer = VBoxContainer.new(); body.add_child(grid_column)
	label("装备 6×5 ｜ 祭坛 4×4 ｜ 经脉 5×2 ｜ 仓库 4（封闭格显示 ×）",grid_column)
	var grid: GridContainer = GridContainer.new()
	grid.columns=10; grid_column.add_child(grid)
	for y in 8:
		for x in 10:
			var cell: Vector2i = Vector2i(x,y)
			var tile: Button = button("",grid,func(): click_cell(cell))
			tile.custom_minimum_size=Vector2(48,42)
			cells.append(tile)
	var tools: HBoxContainer = HBoxContainer.new(); grid_column.add_child(tools)
	button("预览旋转90°",tools,func(): rotated=not rotated)
	button("拾取选中实物",tools,func(): send({"action":"pickup","id":selected}))
	button("取消选择",tools,func(): selected=-1)
	var side: VBoxContainer = VBoxContainer.new(); side.custom_minimum_size.x=290; body.add_child(side)
	label("背包与地面实例（选择后点击目标格）",side)
	list=ItemList.new(); list.custom_minimum_size=Vector2(290,200); side.add_child(list)
	list.item_selected.connect(func(index: int):
		selected=list.get_item_metadata(index)
		for item in room.snapshot().alpha.items:
			if item.id==selected: rotated=item.rotated
	)
	detail=label("",side); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	catalog=OptionButton.new(); side.add_child(catalog)
	for card in room.snapshot().alpha.cards: catalog.add_item(card.name)
	button("生成受控样本到脚边",side,func(): send({"action":"sample","name":catalog.get_item_text(catalog.selected)}))
	label("受控样本只用于白盒，不是正式掉落或已实现的战斗效果。",column)
	refresh()

func send(action: Dictionary) -> void:
	$Reference.controls.interrupt()
	room.update({"alpha":action},0)
	$Reference.controls.interrupt()
	refresh()

func click_cell(cell: Vector2i) -> void:
	if selected>=0:
		send({"action":"place","id":selected,"cell":cell,"rotated":rotated})
	else:
		for item in room.snapshot().alpha.items:
			if item.region!="ground" and Rect2i(item.cell,State.shape(item,item.rotated)).has_point(cell):
				selected=item.id; rotated=item.rotated; break

func _process(_seconds: float) -> void:
	if room==null: return
	refresh()
	queue_redraw()

func refresh() -> void:
	var state: Dictionary = room.snapshot()
	var alpha: Dictionary = state.alpha
	panel.visible=alpha.camp
	battle_button.visible=not alpha.camp
	status_label.text=("暂停中 · 请先点 Esc 继续。 " if room.paused else "")+alpha.message+"\n白盒版本 "+alpha.version+" ｜ 有效冒险 %.2f 秒" % alpha.elapsed
	var selected_item: Dictionary = {}
	for item in alpha.items:
		if item.id==selected: selected_item=item; break
	var card: Dictionary = alpha.cards[catalog.selected]
	detail.text="内容卡（战斗效果待接通）\n%s · %s · %s · %s\n%s\n\n%s" % [card.name,card.kind,card.quality,card.container,card.description,"未选实物" if selected_item.is_empty() else "选中：%s #%d\n%s朝向：%s" % [selected_item.name,selected_item.id,selected_item.region,"横／转" if rotated else "原形"]]
	var signature: String = str(alpha.items)
	if signature!=last_items:
		last_items=signature; list.clear()
		for item in alpha.items:
			var index: int = list.add_item("%s · %s #%d" % [item.name,item.region,item.id])
			list.set_item_metadata(index,item.id)
			if item.id==selected: list.select(index)
	for index in cells.size():
		var cell: Vector2i = Vector2i(index%10,index/10)
		var region: String = ""
		for key in State.REGIONS:
			if State.REGIONS[key].has_point(cell): region=key; break
		var tile: Button = cells[index]
		tile.text="×" if region.is_empty() else State.NAMES[region].left(1)
		tile.tooltip_text=""
		tile.disabled=region.is_empty()
		tile.modulate=Color("908773") if region.is_empty() else Color("c8bfa5")
		for item in alpha.items:
			if item.region!="ground" and Rect2i(item.cell,State.shape(item,item.rotated)).has_point(cell):
				tile.text=item.name.left(2)
				tile.modulate=Color("f2cd75") if item.id==selected else Color("b3d1bb")
				tile.tooltip_text="%s #%d · %s" % [item.name,item.id,item.description]

func _draw() -> void:
	if room==null: return
	for item in room.snapshot().alpha.items:
		if item.region=="ground":
			draw_circle(item.world,10,Color("f2cd75"))
			draw_string(ThemeDB.fallback_font,item.world+Vector2(14,0),item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
