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
var ranking_label: Label
var quality: OptionButton
var weighted: CheckBox
var main_glyph: CheckBox
var eligible: CheckBox
var battle_status: Label
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
	battle_status=label("",layer); battle_status.position=Vector2(28,205)
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
	label("装备 6×5 ｜ 祭坛 4×4 ｜ 收纳 4（封闭格显示 ×）",grid_column)
	var grid: GridContainer = GridContainer.new()
	grid.columns=10; grid_column.add_child(grid)
	for y in 8:
		for x in 10:
			var cell: Vector2i = Vector2i(x,y)
			var tile: Button = button("",grid,func(): click_cell(cell))
			tile.custom_minimum_size=Vector2(48,42)
			cells.append(tile)
	ranking_label=label("",grid_column)
	var tools: HBoxContainer = HBoxContainer.new(); grid_column.add_child(tools)
	button("预览旋转90°",tools,func(): rotated=not rotated)
	button("拾取选中实物",tools,func(): send({"action":"pickup","id":selected}))
	button("点燃第一名 · B",tools,func(): send({"action":"burn"}))
	button("丢弃灰烬",tools,func(): send({"action":"discard","id":selected}))
	button("锁物样例",tools,func(): send({"action":"fixture_lock","id":selected}))
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
	quality=OptionButton.new(); side.add_child(quality)
	for tier in ["残","常","良","珍","异","凡","精","仙","神","专属"]: quality.add_item(tier)
	main_glyph=CheckBox.new(); main_glyph.text="受控装备：有唯一主符"; main_glyph.button_pressed=true; side.add_child(main_glyph)
	weighted=CheckBox.new(); weighted.text="受控票物：额外倍率×1.5"; side.add_child(weighted)
	eligible=CheckBox.new(); eligible.text="受控票物：有投票资格"; eligible.button_pressed=true; side.add_child(eligible)
	button("生成受控样本到脚边",side,func(): send({"action":"sample","name":catalog.get_item_text(catalog.selected),"quality":quality.get_item_text(quality.selected),"weighted":weighted.button_pressed,"eligible":eligible.button_pressed,"mainGlyph":main_glyph.button_pressed}))
	button("选此卡为受控前局残影",side,func():
		send({"action":"shadow","name":catalog.get_item_text(catalog.selected),"quality":quality.get_item_text(quality.selected)})
		selected=room.snapshot().alpha.shadowId; rotated=false
	)
	button("不携带残影",side,func(): send({"action":"shadow","name":""}))
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
			if State.REGIONS.has(item.region) and Rect2i(item.cell,State.shape(item,item.rotated)).has_point(cell):
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
	battle_status.visible=not alpha.camp
	battle_status.text="B 点燃 · 有效冒险 %.1f 秒\n%s" % [alpha.elapsed,alpha.message]
	if not alpha.burn.is_empty(): battle_status.text+="\n%s终极占位 %.1f秒（白盒周期记录）" % [alpha.burn.container,alpha.burn.remaining]
	status_label.text=("暂停中 · 请先点 Esc 继续。 " if room.paused else "")+alpha.message+"\n白盒版本 "+alpha.version+" ｜ 有效冒险 %.2f 秒" % alpha.elapsed
	var totals: PackedStringArray = []
	for key in alpha.votes: totals.append("%s %d" % [key,alpha.votes[key]])
	ranking_label.text=" · ".join(totals)+"\n显灵：%s ｜ 作祟：%s\n%s" % [alpha.winner if not alpha.winner.is_empty() else "无",alpha.harm if not alpha.harm.is_empty() else "无",alpha.reason]
	ranking_label.text+="\n受控残影：%s ｜ 首次出发后锁位：%s" % ["不带" if alpha.shadowId<0 else str(alpha.shadowId),alpha.departed]
	if not alpha.burn.is_empty(): ranking_label.text+="\n点燃 %s · 占位还剩 %.2f秒 · 周期记录 %s" % [alpha.burn.container,alpha.burn.remaining,str(alpha.burn.ticks)]
	elif not alpha.lastBurn.is_empty(): ranking_label.text+="\n上次点燃 %s · 周期 %s（白盒记录）" % [alpha.lastBurn.container,str(alpha.lastBurn.ticks)]
	var selected_item: Dictionary = {}
	for item in alpha.items:
		if item.id==selected: selected_item=item; break
	var card: Dictionary = alpha.cards[catalog.selected]
	detail.text="内容卡（战斗效果待接通）\n%s · %s · %s · %s\n%s\n\n%s" % [card.name,card.kind,card.quality,card.container,card.description,"未选实物" if selected_item.is_empty() else "选中：%s #%d\n%s朝向：%s" % [selected_item.name,selected_item.id,selected_item.region,"横／转" if rotated else "原形"]]
	if selected_item.get("shadow",false): detail.text+="\n受控前局残影 · 原品质 %s · 基础票固定1\n原形 %s · 原种类 %s · 不恢复原效果" % [selected_item.quality,str(selected_item.size),selected_item.kind]
	for record in alpha.breakdown:
		if record.id==selected:
			detail.text+="\n票数：%d × %.2f → %d − %d = %d\n资格：%s ｜ 气息：%s ｜ 入坛序：%d" % [record.base,record.multiplier,record.weighted,record.opposition,record.total,record.eligible,record.aura,record.order]
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
		if alpha.auraCells.has(cell): tile.modulate=Color("98c8ae")
		if alpha.sealed.has(cell): tile.text="封"; tile.modulate=Color("e1937e")
		for item in alpha.items:
			if State.REGIONS.has(item.region) and Rect2i(item.cell,State.shape(item,item.rotated)).has_point(cell):
				tile.text=("影·" if item.get("shadow",false) else "")+item.name.left(2)
				tile.modulate=Color("f2cd75") if item.id==selected else Color("b3d1bb")
				for record in alpha.breakdown:
					if record.id==item.id and record.aura: tile.modulate=Color("7fe1b0")
				if item.state=="burning": tile.text="燃·"+tile.text; tile.modulate=Color("ed9373")
				if item.get("locked",false): tile.text="锁·"+tile.text
				tile.tooltip_text="%s #%d · %s" % [item.name,item.id,item.description]
		if alpha.sealed.has(cell):
			tile.text="封·"+tile.text.trim_prefix("封")
			tile.tooltip_text+="\n封格：已有物可移出／点燃，不允许新放入。"

func _draw() -> void:
	if room==null: return
	for item in room.snapshot().alpha.items:
		if item.region=="ground":
			draw_circle(item.world,10,Color("f2cd75"))
			draw_string(ThemeDB.fallback_font,item.world+Vector2(14,0),item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
