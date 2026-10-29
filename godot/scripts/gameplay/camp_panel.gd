extends CanvasLayer

const Alpha = preload("res://scripts/alpha/alpha_state.gd")
const Art = preload("res://scripts/presentation/item_art.gd")
const Geometry = preload("res://scripts/alpha/altar_geometry.gd")
const FontSong = preload("res://assets/fonts/NineTripodsHudSong.ttf")

const INK: Color = Color("0d120e")
const PAPER: Color = Color("f4e5be")
const GOLD: Color = Color("c5a363")
const GOLD_BRIGHT: Color = Color("ead29a")
const MUTED: Color = Color("b9a88a")
const DIM: Color = Color("807b65")
const JADE: Color = Color("88b199")
const RED: Color = Color("ca7661")
const RED_SEAL: Color = Color("892c22")
const RED_BTN: Color = Color("853123")
const RED_BORDER: Color = Color("ba7752")
const LINE_COLOR: Color = Color(0.42, 0.38, 0.25, 0.35)

var room: TrainingRoom
var controls: PlayerControls
var panel: Control
var center_wrap: CenterContainer
var bag_panel: PanelContainer
var title: Label
var mode_chip: Label
var feedback: Label
var ranking: Label
var detail: Label
var legend: Label
var note: Label
var item_list: ItemList
var grid_cells: Array[Button] = []
var selected: int = -1
var rotated: bool = false
var signature: String = ""
var skills_ui: Control
var equipment_ui: Control
var equipment_host: VBoxContainer
var action_buttons_host: VBoxContainer
var grid_art: Control
var detail_image: TextureRect
var depart_button: Button
var kit_button: Button
var rotate_button: Button
var cancel_button: Button
var drop_button: Button
var pickup_button: Button
var discard_button: Button
var bind_button: Button
var close_button: Button
var footer_close_hint: Label
var blessing_panel: VBoxContainer
var blessing_label: Label
var evolve_button: Button
var synergy_label: Label

var context_label: Label
var capacity_label: Label
var carry_count_label: Label
var selection_hint: Label
var detail_top: HBoxContainer
var detail_kind: Label
var detail_state: Label
var detail_name: Label
var detail_subtitle: Label
var detail_copy: Label
var detail_facts: VBoxContainer
var detail_warning: Label
var detail_empty: VBoxContainer
var detail_content: VBoxContainer
var footer_state: Label
var footer_instruction: Label
var embed_buttons_host: VBoxContainer

var backpack_open: bool = false
var backpack_mode: String = "camp"
var dragging: bool = false
var drag_id: int = -1
var drag_grab_offset: Vector2i = Vector2i.ZERO
var drag_origin: Vector2i = Vector2i.ZERO
var drag_valid: bool = false
var drag_error: String = ""

class CornerFrame extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if size.x < 24 or size.y < 24: return
		var gold: Color = Color("c5a363")
		var pad: float = 6.0
		var arm: float = 20.0
		draw_line(Vector2(pad, pad), Vector2(pad + arm, pad), gold, 1.2)
		draw_line(Vector2(pad, pad), Vector2(pad, pad + arm), gold, 1.2)
		draw_line(Vector2(size.x - pad, size.y - pad), Vector2(size.x - pad - arm, size.y - pad), gold, 1.2)
		draw_line(Vector2(size.x - pad, size.y - pad), Vector2(size.x - pad, size.y - pad - arm), gold, 1.2)

static func make_box(bg: Color, border: Color = Color.TRANSPARENT, b_width: int = 0, pad: int = 0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = b_width
	sb.border_width_top = b_width
	sb.border_width_right = b_width
	sb.border_width_bottom = b_width
	sb.content_margin_left = pad
	sb.content_margin_top = pad
	sb.content_margin_right = pad
	sb.content_margin_bottom = pad
	return sb

func setup(model: TrainingRoom, adapter: PlayerControls) -> void:
	room = model; controls = adapter; layer = 20
	panel = Control.new()
	panel.name = "BackpackLayer"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var veil: ColorRect = ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.03, 0.05, 0.04, 0.85)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(veil)

	center_wrap = CenterContainer.new()
	center_wrap.name = "CenterWrap"
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center_wrap)

	bag_panel = PanelContainer.new()
	bag_panel.name = "BagPanel"
	bag_panel.custom_minimum_size = Vector2(1060, 620)
	bag_panel.add_theme_stylebox_override("panel", make_box(Color(0.07, 0.09, 0.06, 0.98), Color(0.69, 0.59, 0.36, 0.55), 1, 0))
	center_wrap.add_child(bag_panel)

	var corner: Control = CornerFrame.new()
	bag_panel.add_child(corner)

	var bag_column: VBoxContainer = VBoxContainer.new()
	bag_column.add_theme_constant_override("separation", 0)
	bag_panel.add_child(bag_column)

	# 1. 顶栏 Header
	var header_bar: PanelContainer = PanelContainer.new()
	header_bar.custom_minimum_size.y = 70
	header_bar.add_theme_stylebox_override("panel", make_box(Color(0,0,0,0), Color(0,0,0,0), 0, 16))
	bag_column.add_child(header_bar)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 18)
	header_bar.add_child(header_row)

	context_label = Label.new()
	context_label.text = "安全营地"
	context_label.add_theme_font_override("font", FontSong)
	context_label.add_theme_font_size_override("font_size", 11)
	context_label.add_theme_color_override("font_color", GOLD)
	header_row.add_child(context_label)

	title = Label.new()
	title.text = "背包"
	title.add_theme_font_override("font", FontSong)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", PAPER)
	header_row.add_child(title)

	var h_sep: VSeparator = VSeparator.new()
	h_sep.custom_minimum_size = Vector2(1, 20)
	h_sep.add_theme_color_override("separator", LINE_COLOR)
	h_sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(h_sep)

	mode_chip = Label.new()
	mode_chip.text = "整理中 · 冒险停时"
	mode_chip.add_theme_font_override("font", FontSong)
	mode_chip.add_theme_font_size_override("font_size", 11)
	mode_chip.add_theme_color_override("font_color", JADE)
	header_row.add_child(mode_chip)

	var h_spacer: Control = Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(h_spacer)

	close_button = Button.new()
	close_button.text = "收起 · Esc / B  ×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_override("font", FontSong)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_color_override("font_color", MUTED)
	close_button.add_theme_stylebox_override("normal", make_box(Color(0.12, 0.16, 0.12, 0.8), LINE_COLOR, 1, 6))
	close_button.add_theme_stylebox_override("hover", make_box(Color(0.18, 0.24, 0.18, 0.9), GOLD, 1, 6))
	close_button.pressed.connect(close_backpack)
	header_row.add_child(close_button)

	var sep_top: HSeparator = HSeparator.new()
	sep_top.add_theme_color_override("separator", LINE_COLOR)
	bag_column.add_child(sep_top)

	# 2. 主体 Body (左右双栏)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	bag_column.add_child(body)

	# 左栏 (背包空间)
	var left_margin: MarginContainer = MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 22)
	left_margin.add_theme_constant_override("margin_right", 20)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_bottom", 12)
	body.add_child(left_margin)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_vbox)

	# 角色条
	var char_strip: HBoxContainer = HBoxContainer.new()
	char_strip.add_theme_constant_override("separation", 12)
	left_vbox.add_child(char_strip)

	var seal: PanelContainer = PanelContainer.new()
	seal.custom_minimum_size = Vector2(32, 34)
	seal.add_theme_stylebox_override("panel", make_box(RED_SEAL, RED_BORDER, 1, 0))
	var seal_lbl: Label = Label.new()
	seal_lbl.text = "羿"
	seal_lbl.add_theme_font_override("font", FontSong)
	seal_lbl.add_theme_font_size_override("font_size", 20)
	seal_lbl.add_theme_color_override("font_color", Color("f0dab7"))
	seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(seal_lbl)
	char_strip.add_child(seal)

	var hero_info: VBoxContainer = VBoxContainer.new()
	hero_info.add_theme_constant_override("separation", 2)
	var hero_name: Label = Label.new()
	hero_name.text = "后羿 · 附体"
	hero_name.add_theme_font_override("font", FontSong)
	hero_name.add_theme_font_size_override("font_size", 14)
	hero_name.add_theme_color_override("font_color", PAPER)
	hero_info.add_child(hero_name)
	var hero_sub: Label = Label.new()
	hero_sub.text = "整理结果将在离开营地时应用"
	hero_sub.add_theme_font_override("font", FontSong)
	hero_sub.add_theme_font_size_override("font_size", 10)
	hero_sub.add_theme_color_override("font_color", DIM)
	hero_info.add_child(hero_sub)
	char_strip.add_child(hero_info)

	var char_spacer: Control = Control.new()
	char_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_strip.add_child(char_spacer)

	capacity_label = Label.new()
	capacity_label.text = "50 格"
	capacity_label.add_theme_font_override("font", FontSong)
	capacity_label.add_theme_font_size_override("font_size", 22)
	capacity_label.add_theme_color_override("font_color", GOLD)
	char_strip.add_child(capacity_label)

	# 区域标签
	var region_labels: HBoxContainer = HBoxContainer.new()
	region_labels.add_theme_constant_override("separation", 16)
	left_vbox.add_child(region_labels)

	var reg_equip: Label = Label.new()
	reg_equip.text = "装备 穿戴与随行 · 6 × 5"
	reg_equip.custom_minimum_size.x = 350
	reg_equip.add_theme_font_override("font", FontSong)
	reg_equip.add_theme_font_size_override("font_size", 12)
	reg_equip.add_theme_color_override("font_color", GOLD)
	region_labels.add_child(reg_equip)

	var reg_altar: Label = Label.new()
	reg_altar.text = "祭坛 构筑生效 · 4 × 4"
	reg_altar.add_theme_font_override("font", FontSong)
	reg_altar.add_theme_font_size_override("font_size", 12)
	reg_altar.add_theme_color_override("font_color", GOLD)
	region_labels.add_child(reg_altar)

	# 棋盘网格
	var grid_host: Control = Control.new()
	grid_host.custom_minimum_size = Vector2(610, 275)
	left_vbox.add_child(grid_host)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid_host.add_child(grid)

	grid_art = load("res://scripts/presentation/item_grid_art.gd").new()
	grid_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_host.add_child(grid_art)

	for y in 5:
		for x in 10:
			var cell: Vector2i = Vector2i(x, y)
			var tile: Button = Button.new()
			tile.custom_minimum_size = Vector2(57, 51)
			tile.focus_mode = Control.FOCUS_NONE
			tile.text = "" # 无任何字符
			var is_equip: bool = x < 6
			var is_altar: bool = x >= 6 and y < 4
			var bg_col: Color = Color(0.12, 0.16, 0.13, 0.40) if is_equip else (Color(0.20, 0.18, 0.12, 0.40) if is_altar else Color(0.22, 0.16, 0.11, 0.45))
			var b_col: Color = Color(0.35, 0.40, 0.32, 0.35) if is_equip else (Color(0.55, 0.48, 0.30, 0.40) if is_altar else Color(0.60, 0.45, 0.30, 0.50))
			tile.add_theme_stylebox_override("normal", make_box(bg_col, b_col, 1, 0))
			tile.add_theme_stylebox_override("hover", make_box(bg_col * 1.3, GOLD, 1, 0))
			tile.mouse_entered.connect(func(): on_cell_hover(cell))
			tile.mouse_exited.connect(func(): on_cell_unhover(cell))
			tile.gui_input.connect(func(event: InputEvent): on_cell_input(event, cell))
			grid.add_child(tile)
			grid_cells.append(tile)

	grid_art.cells = grid_cells
	grid.minimum_size_changed.connect(func(): grid_host.custom_minimum_size = grid.get_combined_minimum_size())
	grid.resized.connect(func(): grid_art.queue_redraw())

	# 图例
	var board_caption: HBoxContainer = HBoxContainer.new()
	board_caption.add_theme_constant_override("separation", 20)
	left_vbox.add_child(board_caption)

	legend = Label.new()
	legend.text = "装备 6×5 ｜ 祭坛 4×4 ｜ 收纳 4格"
	legend.add_theme_font_override("font", FontSong)
	legend.add_theme_font_size_override("font_size", 10)
	legend.add_theme_color_override("font_color", DIM)
	board_caption.add_child(legend)

	var caption_spacer: Control = Control.new()
	caption_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_caption.add_child(caption_spacer)

	carry_count_label = Label.new()
	carry_count_label.text = "收纳 4 / 4"
	carry_count_label.add_theme_font_override("font", FontSong)
	carry_count_label.add_theme_font_size_override("font_size", 11)
	carry_count_label.add_theme_color_override("font_color", GOLD)
	board_caption.add_child(carry_count_label)

	# 祝词与空间摘要
	var build_summary: HBoxContainer = HBoxContainer.new()
	build_summary.add_theme_constant_override("separation", 12)
	left_vbox.add_child(build_summary)

	var sym_panel: PanelContainer = PanelContainer.new()
	sym_panel.custom_minimum_size = Vector2(30, 30)
	sym_panel.add_theme_stylebox_override("panel", make_box(Color(0.20, 0.35, 0.24, 0.5), Color(0.40, 0.60, 0.45, 0.5), 1, 0))
	var sym_lbl: Label = Label.new()
	sym_lbl.text = "木"
	sym_lbl.add_theme_font_override("font", FontSong)
	sym_lbl.add_theme_font_size_override("font_size", 16)
	sym_lbl.add_theme_color_override("font_color", JADE)
	sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sym_panel.add_child(sym_lbl)
	build_summary.add_child(sym_panel)

	blessing_panel = VBoxContainer.new()
	blessing_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_panel.add_theme_constant_override("separation", 2)
	build_summary.add_child(blessing_panel)

	blessing_label = Label.new()
	blessing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blessing_label.add_theme_font_override("font", FontSong)
	blessing_label.add_theme_font_size_override("font_size", 11)
	blessing_label.add_theme_color_override("font_color", JADE)
	blessing_panel.add_child(blessing_label)

	synergy_label = Label.new()
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	synergy_label.add_theme_font_override("font", FontSong)
	synergy_label.add_theme_font_size_override("font_size", 10)
	synergy_label.add_theme_color_override("font_color", MUTED)
	blessing_panel.add_child(synergy_label)

	selection_hint = Label.new()
	selection_hint.text = "选中物品，查看作用与可用操作。"
	selection_hint.add_theme_font_override("font", FontSong)
	selection_hint.add_theme_font_size_override("font_size", 11)
	selection_hint.add_theme_color_override("font_color", MUTED)
	left_vbox.add_child(selection_hint)

	# 竖分割线
	var v_sep: VSeparator = VSeparator.new()
	v_sep.add_theme_color_override("separator", LINE_COLOR)
	body.add_child(v_sep)

	# 右栏 (详情卡)
	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.custom_minimum_size.x = 340
	right_margin.add_theme_constant_override("margin_left", 20)
	right_margin.add_theme_constant_override("margin_right", 22)
	right_margin.add_theme_constant_override("margin_top", 14)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	body.add_child(right_margin)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	detail_empty = VBoxContainer.new()
	detail_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(detail_empty)
	var empty_icon: Label = Label.new()
	empty_icon.text = "物"
	empty_icon.add_theme_font_override("font", FontSong)
	empty_icon.add_theme_font_size_override("font_size", 36)
	empty_icon.add_theme_color_override("font_color", Color(0.70, 0.60, 0.40, 0.4))
	empty_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_empty.add_child(empty_icon)
	var empty_text: Label = Label.new()
	empty_text.text = "选中一件物品\n查看它的作用、当前状态\n以及此刻可执行的操作"
	empty_text.add_theme_font_override("font", FontSong)
	empty_text.add_theme_font_size_override("font_size", 11)
	empty_text.add_theme_color_override("font_color", DIM)
	empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_empty.add_child(empty_text)

	detail_content = VBoxContainer.new()
	detail_content.visible = false
	detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 6)
	right_vbox.add_child(detail_content)

	detail_top = HBoxContainer.new()
	detail_content.add_child(detail_top)
	detail_kind = Label.new()
	detail_kind.add_theme_font_override("font", FontSong)
	detail_kind.add_theme_font_size_override("font_size", 11)
	detail_kind.add_theme_color_override("font_color", MUTED)
	detail_top.add_child(detail_kind)
	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_top.add_child(top_spacer)
	detail_state = Label.new()
	detail_state.add_theme_font_override("font", FontSong)
	detail_state.add_theme_font_size_override("font_size", 10)
	detail_state.add_theme_color_override("font_color", JADE)
	detail_top.add_child(detail_state)

	var art_center: CenterContainer = CenterContainer.new()
	art_center.custom_minimum_size.y = 96
	detail_content.add_child(art_center)
	detail_image = TextureRect.new()
	detail_image.custom_minimum_size = Vector2(96, 96)
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art_center.add_child(detail_image)

	detail_name = Label.new()
	detail_name.add_theme_font_override("font", FontSong)
	detail_name.add_theme_font_size_override("font_size", 20)
	detail_name.add_theme_color_override("font_color", PAPER)
	detail_content.add_child(detail_name)

	detail_subtitle = Label.new()
	detail_subtitle.add_theme_font_override("font", FontSong)
	detail_subtitle.add_theme_font_size_override("font_size", 10)
	detail_subtitle.add_theme_color_override("font_color", MUTED)
	detail_content.add_child(detail_subtitle)

	detail_copy = Label.new()
	detail_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_copy.add_theme_font_override("font", FontSong)
	detail_copy.add_theme_font_size_override("font_size", 11)
	detail_copy.add_theme_color_override("font_color", PAPER)
	detail_content.add_child(detail_copy)

	var sep_facts: HSeparator = HSeparator.new()
	sep_facts.add_theme_color_override("separator", LINE_COLOR)
	detail_content.add_child(sep_facts)

	detail_facts = VBoxContainer.new()
	detail_facts.add_theme_constant_override("separation", 3)
	detail_content.add_child(detail_facts)

	var sep_facts_bot: HSeparator = HSeparator.new()
	sep_facts_bot.add_theme_color_override("separator", LINE_COLOR)
	detail_content.add_child(sep_facts_bot)

	action_buttons_host = VBoxContainer.new()
	action_buttons_host.add_theme_constant_override("separation", 6)
	detail_content.add_child(action_buttons_host)

	var btn_row1: HBoxContainer = HBoxContainer.new()
	btn_row1.add_theme_constant_override("separation", 8)
	action_buttons_host.add_child(btn_row1)
	rotate_button = add_button("旋转拟放方向 [R]", btn_row1, rotate_selected)
	cancel_button = add_button("取消选中", btn_row1, func(): selected = -1; signature = ""; refresh())

	var btn_row2: HBoxContainer = HBoxContainer.new()
	btn_row2.add_theme_constant_override("separation", 8)
	action_buttons_host.add_child(btn_row2)
	drop_button = add_button("放到脚边", btn_row2, func(): send({"action":"drop","id":selected}))
	bind_button = add_button("选中器绑定 V 快捷使用", btn_row2, func(): send({"action":"quick_bind","id":selected}))

	embed_buttons_host = VBoxContainer.new()
	embed_buttons_host.add_theme_constant_override("separation", 4)
	action_buttons_host.add_child(embed_buttons_host)

	evolve_button = add_button("神兽祝词重念演化", action_buttons_host, func(): send({"action":"evolve_blessing"}))
	evolve_button.visible = false

	# 隐藏兼容测试按钮
	pickup_button = add_button("拾取选中地面实物", action_buttons_host, func(): send({"action":"pickup","id":selected}))
	pickup_button.visible = false
	discard_button = add_button("丢弃选中灰烬", action_buttons_host, func(): send({"action":"discard","id":selected}))
	discard_button.visible = false
	kit_button = Button.new()
	kit_button.visible = false

	detail_warning = Label.new()
	detail_warning.text = "关闭背包即可应用合法构筑并继续；不会自动恢复生命或冷却。"
	detail_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_warning.add_theme_font_override("font", FontSong)
	detail_warning.add_theme_font_size_override("font_size", 9)
	detail_warning.add_theme_color_override("font_color", DIM)
	detail_content.add_child(detail_warning)

	# 3. 底栏 Footer
	var sep_bot: HSeparator = HSeparator.new()
	sep_bot.add_theme_color_override("separator", LINE_COLOR)
	bag_column.add_child(sep_bot)

	var footer_bar: PanelContainer = PanelContainer.new()
	footer_bar.custom_minimum_size.y = 52
	footer_bar.add_theme_stylebox_override("panel", make_box(Color(0.04, 0.06, 0.04, 0.9), Color(0,0,0,0), 0, 16))
	bag_column.add_child(footer_bar)

	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 20)
	footer_bar.add_child(footer_row)

	footer_state = Label.new()
	footer_state.text = "● 安全营地 · 可整理"
	footer_state.add_theme_font_override("font", FontSong)
	footer_state.add_theme_font_size_override("font_size", 11)
	footer_state.add_theme_color_override("font_color", JADE)
	footer_row.add_child(footer_state)

	footer_instruction = Label.new()
	footer_instruction.text = "点击选中 → 按住拖拽 → 松开放置"
	footer_instruction.add_theme_font_override("font", FontSong)
	footer_instruction.add_theme_font_size_override("font_size", 10)
	footer_instruction.add_theme_color_override("font_color", DIM)
	footer_row.add_child(footer_instruction)

	var f_spacer: Control = Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(f_spacer)

	depart_button = Button.new()
	depart_button.text = "确认构筑并出发"
	depart_button.focus_mode = Control.FOCUS_NONE
	depart_button.add_theme_font_override("font", FontSong)
	depart_button.add_theme_font_size_override("font_size", 13)
	depart_button.add_theme_color_override("font_color", PAPER)
	depart_button.add_theme_stylebox_override("normal", make_box(RED_BTN, RED_BORDER, 1, 8))
	depart_button.add_theme_stylebox_override("hover", make_box(Color("a0422c"), Color("dfb27e"), 1, 8))
	depart_button.pressed.connect(close_backpack)
	footer_row.add_child(depart_button)

	footer_close_hint = Label.new()
	footer_close_hint.text = "B / Esc 收起并继续"
	footer_close_hint.add_theme_font_override("font", FontSong)
	footer_close_hint.add_theme_font_size_override("font_size", 10)
	footer_close_hint.add_theme_color_override("font_color", MUTED)
	footer_row.add_child(footer_close_hint)

	# 兼容自动化测试后台节点 (隐藏)
	var hidden_tools: Control = Control.new()
	hidden_tools.visible = false
	panel.add_child(hidden_tools)

	feedback = Label.new(); hidden_tools.add_child(feedback)
	ranking = Label.new(); hidden_tools.add_child(ranking)
	detail = Label.new(); hidden_tools.add_child(detail)
	note = Label.new(); hidden_tools.add_child(note)

	item_list = ItemList.new(); hidden_tools.add_child(item_list)
	item_list.item_selected.connect(func(index: int):
		selected = item_list.get_item_metadata(index)
		for item in room.snapshot().alpha.items:
			if item.id == selected: rotated = item.rotated
		refresh()
	)

	equipment_host = VBoxContainer.new(); hidden_tools.add_child(equipment_host)
	equipment_ui = load("res://scripts/alpha/equipment_panel.gd").new()
	equipment_host.add_child(equipment_ui)
	equipment_ui.setup(room)
	equipment_ui.command_requested.connect(send)

	skills_ui = load("res://scripts/alpha/skills_panel.gd").new()
	hidden_tools.add_child(skills_ui)
	skills_ui.setup(room)

	panel.visible = false
	backpack_open = false
	refresh()

func add_button(caption: String, parent: Node, action: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = caption
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", FontSong)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", PAPER)
	btn.add_theme_stylebox_override("normal", make_box(Color(0.12, 0.16, 0.12, 0.8), LINE_COLOR, 1, 6))
	btn.add_theme_stylebox_override("hover", make_box(Color(0.18, 0.24, 0.18, 0.9), GOLD, 1, 6))
	btn.pressed.connect(action)
	parent.add_child(btn)
	return btn

func is_at_safe_camp() -> bool:
	if room == null or room.alpha == null: return false
	if not room.alpha.gameplay: return true
	if room.alpha.has_method("can_camp"):
		return room.alpha.can_camp(room)
	var snapshot: Dictionary = room.snapshot()
	if not snapshot.get("roomComplete", true): return false
	for enemy in snapshot.get("enemies", []):
		if enemy.get("phase", "") not in ["inactive", "dead"]: return false
	var camps: Array = snapshot.get("camps", [])
	if camps.is_empty():
		camps = [room.layout.get("spawn", Vector2.ZERO)]
	var player_pos: Vector2 = Vector2(room.player.x, room.player.y)
	for loc in camps:
		var camp_pt: Vector2 = room.point(loc)
		if player_pos.distance_to(camp_pt) <= 100.0 and room.clear_path(room.player, camp_pt):
			return true
	return false

func toggle_backpack() -> void:
	if backpack_open: close_backpack()
	else: open_backpack()

func open_backpack() -> void:
	if room == null: return
	if is_at_safe_camp():
		backpack_mode = "camp"
		send({"action": "camp"})
	else:
		backpack_mode = "combat"
	backpack_open = true
	selected = -1
	rotated = false
	clear_drag()
	signature = ""
	apply_mode_layout()
	refresh()

func close_backpack() -> void:
	if not backpack_open: return
	clear_drag()
	selected = -1
	rotated = false
	grid_art.hover_preview = {}
	grid_art.queue_redraw()
	if backpack_mode == "camp" and room != null and room.alpha != null and room.alpha.camp:
		send({"action": "depart"})
	backpack_open = false
	panel.visible = false
	if controls != null: controls.interrupt()

func rotate_selected() -> void:
	if backpack_mode != "camp": return
	if dragging: return
	rotated = not rotated
	refresh()

func apply_mode_layout() -> void:
	panel.visible = backpack_open
	if not backpack_open: return
	if backpack_mode == "camp":
		context_label.text = "安全营地"
		mode_chip.text = "整理中 · 冒险停时"
		footer_state.text = "● 安全营地 · 可整理"
		footer_instruction.text = "点击选中 → 按住拖拽 → 松开放置"
		action_buttons_host.visible = true
		depart_button.visible = true
	else:
		context_label.text = "战斗探索"
		mode_chip.text = "紧凑查看 · 冒险未暂停"
		footer_state.text = "● 仅查看 · 冒险未暂停"
		footer_instruction.text = "精细整理需返回安全营地"
		action_buttons_host.visible = false
		depart_button.visible = false

func send(intent: Dictionary) -> void:
	if controls != null: controls.interrupt()
	if room != null: room.update({"alpha": intent}, 0)
	if controls != null: controls.interrupt()
	refresh()

func item_at_cell(cell: Vector2i) -> Dictionary:
	if room == null: return {}
	for item in room.snapshot().alpha.items:
		if Alpha.REGIONS.has(item.region) and Rect2i(item.cell, Alpha.shape(item, item.rotated)).has_point(cell):
			return item
	return {}

func select_item(item: Dictionary) -> void:
	if item.is_empty(): return
	selected = item.id
	rotated = item.rotated
	signature = ""

func on_cell_input(event: InputEvent, cell: Vector2i) -> void:
	if not event is InputEventMouseButton: return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT: return
	if backpack_mode != "camp":
		if mouse_event.pressed:
			click_cell(cell)
		return
	if mouse_event.pressed:
		var target: Dictionary = item_at_cell(cell)
		if not target.is_empty():
			if target.id != selected:
				select_item(target)
			begin_drag(cell, true)
			refresh()
			get_viewport().set_input_as_handled()
			return
		if selected < 0: return
		var selected_item: Dictionary = room.alpha.find_item(selected)
		if selected_item.is_empty(): return
		begin_drag(cell)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not backpack_open or backpack_mode != "camp" or not dragging:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var cell: Vector2i = cell_at_global(motion.position)
		if cell.x >= 0:
			update_drag_preview(cell)
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			finish_drag(mouse_event.position)
			get_viewport().set_input_as_handled()

func cell_at_global(global_position: Vector2) -> Vector2i:
	for index in grid_cells.size():
		if grid_cells[index].get_global_rect().has_point(global_position):
			return Vector2i(index % 10, index / 10)
	return Vector2i(-1, -1)

func finish_drag(global_position: Vector2) -> void:
	if not dragging: return
	var cell: Vector2i = cell_at_global(global_position)
	if cell.x < 0:
		selection_hint.text = "无法放置：目标不在背包网格内；物品未移动"
		selection_hint.add_theme_color_override("font_color", RED)
		clear_drag(false)
		return
	update_drag_preview(cell)
	var item: Dictionary = room.alpha.find_item(drag_id)
	if drag_valid:
		if not item.is_empty() and drag_origin == item.cell and rotated == item.rotated:
			clear_drag()
			on_cell_unhover(cell)
			return
		send({"action":"place","id":drag_id,"cell":drag_origin,"rotated":rotated})
		clear_drag()
	else:
		selection_hint.text = "无法放置："+drag_error+"；物品未移动"
		selection_hint.add_theme_color_override("font_color", RED)
		clear_drag(false)

func clear_drag(clear_preview: bool = true) -> void:
	dragging = false
	drag_id = -1
	drag_grab_offset = Vector2i.ZERO
	drag_origin = Vector2i.ZERO
	drag_valid = false
	drag_error = ""
	if clear_preview and grid_art != null:
		grid_art.hover_preview = {}
		grid_art.queue_redraw()

func click_cell(cell: Vector2i) -> void:
	if backpack_mode != "camp":
		select_item(item_at_cell(cell))
		refresh()
		return
	var target: Dictionary = item_at_cell(cell)
	if not target.is_empty() and target.id != selected:
		select_item(target)
	elif selected >= 0:
		begin_drag(cell)
	elif not target.is_empty():
		select_item(target)
	refresh()

func on_cell_hover(cell: Vector2i) -> void:
	if backpack_mode != "camp" or room == null: return
	if dragging:
		update_drag_preview(cell)
		return
	if selected < 0: return
	var item: Dictionary = room.alpha.find_item(selected)
	if item.is_empty(): return
	update_preview(item, cell, Vector2i.ZERO)

func begin_drag(cell: Vector2i, preserve_grab: bool = false) -> void:
	if room == null or selected < 0: return
	var item: Dictionary = room.alpha.find_item(selected)
	if item.is_empty(): return
	dragging = true
	drag_id = selected
	drag_grab_offset = cell - item.cell if preserve_grab else Vector2i.ZERO
	drag_origin = item.cell
	update_drag_preview(cell)

func update_drag_preview(cell: Vector2i) -> void:
	if room == null or drag_id < 0: return
	var item: Dictionary = room.alpha.find_item(drag_id)
	if item.is_empty(): return
	var origin: Vector2i = cell - drag_grab_offset
	drag_origin = origin
	update_preview(item, cell, drag_grab_offset)

func update_preview(item: Dictionary, cell: Vector2i, grab_offset: Vector2i) -> void:
	var origin: Vector2i = cell - grab_offset
	var item_shape: Vector2i = Alpha.shape(item, rotated)
	var cell_idx: int = cell.y * 10 + cell.x
	if cell_idx >= grid_cells.size(): return
	var end_x: int = mini(origin.x + item_shape.x - 1, 9)
	var end_y: int = mini(origin.y + item_shape.y - 1, 4)
	var start_x: int = maxi(origin.x, 0)
	var start_y: int = maxi(origin.y, 0)
	var footprint: Array[Vector2i] = []
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			footprint.append(Vector2i(x, y))
	var end_idx: int = end_y * 10 + end_x
	var preview_start_idx: int = start_y * 10 + start_x
	if preview_start_idx < 0 or preview_start_idx >= grid_cells.size(): return
	if end_idx < 0 or end_idx >= grid_cells.size(): return
	var start_pos: Vector2 = grid_cells[preview_start_idx].position
	var end_pos: Vector2 = grid_cells[end_idx].position + grid_cells[end_idx].size
	var prev_rect: Rect2 = Rect2(start_pos, end_pos - start_pos).grow(-2)

	drag_error = room.alpha.placement_error(item, origin, rotated, item.id)
	drag_valid = drag_error.is_empty()
	grid_art.hover_preview = {"active": true, "valid": drag_valid, "rect": prev_rect, "cells": footprint}
	grid_art.queue_redraw()
	selection_hint.text = ("可放置："+item.name+" · "+str(item_shape.x)+" × "+str(item_shape.y)+" 格") if drag_valid else "无法放置："+drag_error
	selection_hint.add_theme_color_override("font_color", JADE if drag_valid else RED)

func on_cell_unhover(_cell: Vector2i) -> void:
	if dragging: return
	grid_art.hover_preview = {}
	grid_art.queue_redraw()
	if selected >= 0 and room != null:
		for item in room.snapshot().alpha.items:
			if item.id == selected:
				var s: Vector2i = Alpha.shape(item, rotated)
				selection_hint.text = item.name + "已选中 · " + str(s.x) + " × " + str(s.y) + " 格 · 拖拽到目标格放置"
				selection_hint.add_theme_color_override("font_color", MUTED)
				return
	selection_hint.text = "选中物品，查看作用与可用操作。"
	selection_hint.add_theme_color_override("font_color", MUTED)

func _process(_seconds: float) -> void:
	if room != null and backpack_open: refresh()

func refresh() -> void:
	if room == null: return
	var state: Dictionary = room.snapshot()
	var alpha: Dictionary = state.alpha
	panel.visible = backpack_open
	if not panel.visible: return
	apply_mode_layout()
	equipment_ui.refresh(state)
	skills_ui.refresh(state)

	# 维护测试依赖的数据字段 (隐藏 Label)
	feedback.text = ("已暂停，Esc恢复。 " if room.paused else "") + alpha.message
	var totals: PackedStringArray = []
	for key in alpha.votes: totals.append("%s %d" % [key, alpha.votes[key]])
	ranking.text = " · ".join(totals)

	# 填充 item_list (供 item_scene_checks 等测试验证条目数量与图标)
	var current: String = str(alpha.items) + str(selected) + str(state.get("roomId", ""))
	if current != signature:
		signature = current
		item_list.clear()
		for item in alpha.items:
			if not Alpha.REGIONS.has(item.region) and item.region != "ground": continue
			if item.region == "ground" and item.get("roomId", "") != state.get("roomId", ""): continue
			var index: int = item_list.add_item("%s · %s" % [item.name, Alpha.NAMES.get(item.region, "地面")], Art.texture(item.name))
			item_list.set_item_icon_modulate(index, Art.tint(item))
			item_list.set_item_metadata(index, item.id)
			if item.id == selected: item_list.select(index)

	# 统计收纳区使用格数
	var carry_used: int = 0
	for item in alpha.items:
		if item.region == "warehouse":
			var s: Vector2i = Alpha.shape(item, item.rotated)
			carry_used += s.x * s.y
	carry_count_label.text = "收纳 %d / 4" % carry_used

	# 详情卡展示
	var selected_item: Dictionary = {}
	for item in alpha.items:
		if item.id == selected: selected_item = item; break

	if selected_item.is_empty():
		detail_empty.visible = true
		detail_content.visible = false
		detail_image.texture = null
		detail_image.visible = false
		detail.text = "选中一件物品查看详情"
	else:
		detail_empty.visible = false
		detail_content.visible = true
		detail_image.texture = Art.texture(selected_item.name)
		detail_image.modulate = Art.tint(selected_item)
		detail_image.visible = detail_image.texture != null

		var elem_suffix: String = (" · " + selected_item.element) if selected_item.get("element", "") != "" else ""
		detail_kind.text = selected_item.get("kind", "物品") + elem_suffix
		var s_text: String = "仅携带"
		if selected_item.region == "equipment": s_text = "穿戴生效"
		elif selected_item.region == "altar": s_text = "祭坛生效"
		detail_state.text = s_text

		detail_name.text = selected_item.name
		var s_shape: Vector2i = Alpha.shape(selected_item, rotated)
		detail_subtitle.text = "%s · 占 %d × %d 格" % [Alpha.NAMES.get(selected_item.region, "背包"), s_shape.x, s_shape.y]
		detail_copy.text = selected_item.get("description", "")

		# 事实属性列表
		for child in detail_facts.get_children(): child.queue_free()
		add_fact("生效条件", get_condition(selected_item))
		if selected_item.name in ["训练弓", "布履", "青龙"]:
			var skills_str: String = "Q 穿透箭 · E 箭雨" if selected_item.name == "训练弓" else ("G 回风" if selected_item.name == "布履" else "C 引风")
			add_fact("技能来源", skills_str)
		if selected_item.name in ["训练弓", "布履"]:
			add_fact("装备羁绊", "训练弓与布履同时穿戴获得蓄势")
		var glyph_names: PackedStringArray = []
		for g in selected_item.get("glyphs", []): glyph_names.append(g.get("name", ""))
		if selected_item.name in ["训练弓", "布履"]:
			var g_text: String = "未嵌符" if glyph_names.is_empty() else "、".join(glyph_names)
			add_fact("嵌符情况", "已嵌 %d / 3：%s" % [glyph_names.size(), g_text])
		add_fact("当前操作", "可整理" if backpack_mode == "camp" else "仅查看")

		# 动态操作按钮
		for child in embed_buttons_host.get_children(): child.queue_free()
		if backpack_mode == "camp" and selected_item.get("kind", "") == "符":
			for eq in alpha.items:
				if eq.region == "equipment" and eq.name in ["训练弓", "布履"] and eq.get("glyphs", []).size() < 3:
					var target_eq: Dictionary = eq
					var emb_btn: Button = add_button("嵌入 " + target_eq.name, embed_buttons_host, func():
						send({"action":"embed", "equipmentId": target_eq.id, "glyphId": selected_item.id})
					)
					emb_btn.add_theme_color_override("font_color", GOLD_BRIGHT)

		bind_button.visible = (backpack_mode == "camp" and selected_item.get("kind", "") == "器")
		evolve_button.visible = (backpack_mode == "camp" and selected_item.get("kind", "") == "神兽" and alpha.get("canEvolveBlessing", false))

		# 维护测试兼容用的 detail.text
		detail.text = "%s #%d\n%s" % [selected_item.name, selected_item.id, selected_item.description]

	# 祝词与空间摘要
	var tier_name: String = alpha.get("blessingTierName", "初念 · 风道疾驰")
	var evolves_left: int = alpha.get("blessingEvolvesLeft", 0)
	var tier_desc: String = alpha.get("blessingDesc", "")
	var beast_name: String = alpha.get("blessingBeast", "青龙")
	var display_beast: String = (beast_name + "引风") if beast_name == "青龙" else ((beast_name + "金戈") if beast_name == "白虎" else ((beast_name + "火羽") if beast_name == "朱雀" else beast_name))
	blessing_label.text = "【神兽祝福 · %s】 %s (本局剩余重念：%d)
%s" % [display_beast, tier_name, evolves_left, tier_desc]

	var synergies: Array = alpha.get("altarAnalysis", {}).get("synergies", [])
	var active_synergies: Array = synergies.filter(func(syn: Dictionary): return syn.get("energized", false) and str(syn.get("title", "")).begins_with("生肖共鸣"))
	if active_synergies.is_empty():
		synergy_label.text = "祭坛空间：尚未形成青龙共鸣。将青龙与已接入祝福网络的生肖符放入装备区与祭坛，可改变引风的持续方式。"
	else:
		var syn_lines: PackedStringArray = ["祭坛空间：青龙共鸣已形成"]
		for syn in active_synergies:
			syn_lines.append(" · 【%s】%s" % [syn.title, syn.desc])
		synergy_label.text = "\n".join(syn_lines)

	# 更新 grid_art
	grid_art.items = alpha.items
	grid_art.altar_analysis = alpha.get("altarAnalysis", {})
	grid_art.selected_id = selected
	grid_art.aura_cells = alpha.get("auraCells", [])
	grid_art.queue_redraw()

func add_fact(label_text: String, value_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var l_lbl: Label = Label.new()
	l_lbl.text = label_text
	l_lbl.add_theme_font_override("font", FontSong)
	l_lbl.add_theme_font_size_override("font_size", 10)
	l_lbl.add_theme_color_override("font_color", DIM)
	row.add_child(l_lbl)
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var r_lbl: Label = Label.new()
	r_lbl.text = value_text
	r_lbl.add_theme_font_override("font", FontSong)
	r_lbl.add_theme_font_size_override("font_size", 10)
	r_lbl.add_theme_color_override("font_color", MUTED)
	row.add_child(r_lbl)
	detail_facts.add_child(row)

func get_condition(item: Dictionary) -> String:
	if item.name in ["训练弓", "布履"]: return "放在装备区时生效"
	if item.name == "青龙": return "须位于装备区随行"
	if item.name in ["羊角", "鼠毫"]: return "嵌入装备且装备有效穿戴"
	if item.name == "素食": return "放在祭坛时生效"
	if item.get("kind", "") == "器": return "背包实物，可绑定快捷键 V"
	return "放在对应区域生效"
