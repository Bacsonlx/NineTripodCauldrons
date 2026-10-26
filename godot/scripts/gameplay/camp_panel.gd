extends CanvasLayer

const Alpha = preload("res://scripts/alpha/alpha_state.gd")
const Art = preload("res://scripts/presentation/item_art.gd")
var room: TrainingRoom
var controls: PlayerControls
var panel: PanelContainer
var feedback: Label
var ranking: Label
var detail: Label
var item_list: ItemList
var grid_cells: Array[Button] = []
var selected: int = -1
var rotated: bool = false
var signature: String = ""
var skills_ui: Control
var equipment_ui: Control
var equipment_host: VBoxContainer
var grid_art: Control
var detail_image: TextureRect

func setup(model: TrainingRoom, adapter: PlayerControls) -> void:
	room=model; controls=adapter; layer=20
	panel=PanelContainer.new(); add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,20)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new(); margin.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
	var title: Label = Label.new(); title.text="汤谷 · 营地构筑"; title.add_theme_font_size_override("font_size",28); column.add_child(title)
	feedback=Label.new(); feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(feedback)
	var legend: Label = Label.new(); legend.text="装备 6×5 ｜ 祭坛 4×4 ｜ 经脉 5×2 ｜ 仓库起步4格（×为未开放格）"; column.add_child(legend)
	var body: HBoxContainer = HBoxContainer.new(); column.add_child(body)
	var grid_host: Control = Control.new(); body.add_child(grid_host)
	var grid: GridContainer = GridContainer.new(); grid.columns=10; grid_host.add_child(grid)
	grid_art=load("res://scripts/presentation/item_grid_art.gd").new(); grid_host.add_child(grid_art)
	grid.minimum_size_changed.connect(func(): grid_host.custom_minimum_size=grid.get_combined_minimum_size())
	grid.resized.connect(func(): grid_art.queue_redraw())
	for y in 8:
		for x in 10:
			var cell: Vector2i = Vector2i(x,y)
			var tile: Button = Button.new(); tile.custom_minimum_size=Vector2(45,40); tile.focus_mode=Control.FOCUS_NONE
			tile.pressed.connect(func(): click_cell(cell)); grid.add_child(tile); grid_cells.append(tile)
	grid_art.cells=grid_cells
	grid_host.custom_minimum_size=grid.get_combined_minimum_size()
	var side: VBoxContainer = VBoxContainer.new(); side.custom_minimum_size.x=320; body.add_child(side)
	item_list=ItemList.new(); item_list.custom_minimum_size=Vector2(320,180); side.add_child(item_list)
	item_list.fixed_icon_size=Vector2i(32,32)
	item_list.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	item_list.item_selected.connect(func(index: int):
		selected=item_list.get_item_metadata(index)
		for item in room.snapshot().alpha.items:
			if item.id==selected: rotated=item.rotated
	)
	add_button("旋转拟放方向",side,func(): rotated=not rotated)
	add_button("取消选中",side,func(): selected=-1; signature="")
	add_button("拾取选中地面实物",side,func(): send({"action":"pickup","id":selected}))
	add_button("丢到脚边",side,func(): send({"action":"drop","id":selected}))
	add_button("丢弃选中灰烬",side,func(): send({"action":"discard","id":selected}))
	add_button("选中器绑定 V 快捷使用",side,func(): send({"action":"quick_bind","id":selected}))
	detail_image=TextureRect.new(); detail_image.custom_minimum_size=Vector2(96,96)
	detail_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; detail_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.mouse_filter=Control.MOUSE_FILTER_IGNORE; detail_image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; side.add_child(detail_image)
	detail=Label.new(); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; side.add_child(detail)
	equipment_host=VBoxContainer.new(); side.add_child(equipment_host)
	equipment_ui=load("res://scripts/alpha/equipment_panel.gd").new()
	equipment_host.add_child(equipment_ui)
	equipment_ui.setup(room)
	equipment_ui.command_requested.connect(send)
	skills_ui=load("res://scripts/alpha/skills_panel.gd").new(); column.add_child(skills_ui)
	skills_ui.setup(room); skills_ui.command_requested.connect(send)
	ranking=Label.new(); ranking.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(ranking)
	add_button("领取十二件道具原型 · 本局一次",column,func(): send({"action":"prototype_kit"}))
	add_button("确认构筑并出发",column,func(): send({"action":"depart"}))
	var note: Label = Label.new(); note.text="点击物品选中，再点击目标格放置；精细整理仅限安全营地。"; column.add_child(note)
	refresh()

func add_button(text: String,parent: Node,action: Callable) -> void:
	var button: Button = Button.new(); button.text=text; button.focus_mode=Control.FOCUS_NONE; button.pressed.connect(action); parent.add_child(button)

func send(intent: Dictionary) -> void:
	controls.interrupt()
	room.update({"alpha":intent},0)
	controls.interrupt()
	refresh()

func click_cell(cell: Vector2i) -> void:
	if selected>=0:
		send({"action":"place","id":selected,"cell":cell,"rotated":rotated})
	else:
		for item in room.snapshot().alpha.items:
			if Alpha.REGIONS.has(item.region) and Rect2i(item.cell,Alpha.shape(item,item.rotated)).has_point(cell):
				selected=item.id; rotated=item.rotated; signature=""; break

func _process(_seconds: float) -> void:
	if room!=null: refresh()

func refresh() -> void:
	var state: Dictionary = room.snapshot()
	var alpha: Dictionary = state.alpha
	panel.visible=alpha.camp
	if not panel.visible: return
	equipment_ui.refresh(state)
	skills_ui.refresh(state)
	feedback.text=("已暂停，Esc恢复。 " if room.paused else "")+alpha.message+"\n选择实例 #%d · 拟放方向 %s" % [selected,"已旋转" if rotated else "原形"]
	var totals: PackedStringArray = []
	for key in alpha.votes: totals.append("%s %d" % [key,alpha.votes[key]])
	ranking.text=" · ".join(totals)+"\n票数预览：首位 %s ｜ 次位 %s · %s（容器战斗效果未开放）" % [alpha.winner,alpha.harm,alpha.reason]
	detail.text="选择实物查看占格与票数。羊角、鼠毫可嵌符；特殊书可摆入经脉或镶装备，营地指定E/G；器、契、符可试用；容器战斗效果待P8。领取原型后B只测试烧物与焚书。"
	detail_image.texture=null; detail_image.visible=false
	for item in alpha.items:
		if item.id!=selected: continue
		detail_image.texture=Art.texture(item.name); detail_image.modulate=Art.tint(item); detail_image.visible=detail_image.texture!=null
		detail.text="%s #%d\n%s" % [item.name,item.id,item.description]
		if item.name=="囤积": detail.text+="\n本实例首次取得层数：%d / 15" % item.get("stacks",0)
		if item.name=="焚书": detail.text+="\n本实例点燃层数：%d（离坛不供给）" % item.get("burnStacks",0)
		if item.name=="素食": detail.text+="\n本实例恢复周期：%.1f / 10秒" % item.get("period",0)
		for record in alpha.breakdown:
			if record.id==selected:
				detail.text+="\n票数 %d × %.2f → %d − %d = %d\n气息 %s · 入坛序 %d" % [record.base,record.multiplier,record.weighted,record.opposition,record.total,record.aura,record.order]
	var current: String = str(alpha.items)+str(selected)+str(state.get("roomId",""))
	if current!=signature:
		signature=current; item_list.clear()
		for item in alpha.items:
			if not Alpha.REGIONS.has(item.region) and item.region!="ground": continue
			if item.region=="ground" and item.get("roomId","")!=state.get("roomId",""): continue
			var index: int = item_list.add_item("%s · %s #%d" % [item.name,Alpha.NAMES.get(item.region,"地面"),item.id],Art.texture(item.name))
			item_list.set_item_icon_modulate(index,Art.tint(item))
			item_list.set_item_metadata(index,item.id)
			if item.id==selected: item_list.select(index)
	for index in grid_cells.size():
		var cell: Vector2i = Vector2i(index%10,index/10)
		var region: String = ""
		for key in Alpha.REGIONS:
			if Alpha.REGIONS[key].has_point(cell): region=key; break
		var tile: Button = grid_cells[index]
		tile.text="×" if region.is_empty() else Alpha.NAMES[region].left(1)
		tile.disabled=region.is_empty(); tile.tooltip_text=""
		tile.modulate=Color("a69e89") if region.is_empty() else Color("e2d7bb")
		if alpha.auraCells.has(cell): tile.modulate=Color("98c8ae")
		for item in alpha.items:
			if Alpha.REGIONS.has(item.region) and Rect2i(item.cell,Alpha.shape(item,item.rotated)).has_point(cell):
				tile.text="" if Art.texture(item.name)!=null else item.name.left(2); tile.modulate=Color("f0c764") if item.id==selected else Color("aaccb6")
				tile.tooltip_text=item.name+"\n"+item.description
		if alpha.sealed.has(cell): tile.text="封·"+tile.text
	grid_art.items=alpha.items; grid_art.queue_redraw()
