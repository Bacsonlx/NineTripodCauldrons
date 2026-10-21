extends Control

const Slot = preload("res://scripts/presentation/action_slot.gd")
const INK = Color("111611eb")
const BRASS = Color("9a7f4d")
const TEXT = Color("f2e6c5")
var health: ProgressBar
var health_value: Label
var encounter: Label
var interaction: Label
var status: Label
var reading: ColorRect
var toolbar: HBoxContainer
var actions: HBoxContainer
var slots: Dictionary = {}

static func label(text: String,font_size: int) -> Label:
	var node: Label = Label.new()
	node.text=text; node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",TEXT)
	node.add_theme_color_override("font_shadow_color",Color("080d09"))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	return node

static func box(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=fill; style.border_color=BRASS
	style.set_border_width_all(1); style.set_corner_radius_all(3)
	return style

func _ready() -> void:
	name="CombatHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme=Theme.new()
	theme.default_font=preload("res://assets/fonts/NineTripodsHudSong.ttf")
	theme.default_font.allow_system_fallback=false
	var backing: Panel = Panel.new()
	backing.name="StatusBacking"; backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backing.position=Vector2(130,16); backing.size=Vector2(316,120)
	var surface: StyleBoxFlat = box(INK)
	surface.set_border_width_all(0); surface.set_corner_radius_all(5)
	surface.shadow_color=Color(0.02,0.035,0.02,0.6); surface.shadow_size=8
	backing.add_theme_stylebox_override("panel",surface); add_child(backing)
	var statuses: HBoxContainer = HBoxContainer.new()
	statuses.name="PlayerStatus"; statuses.position=Vector2(24,16)
	statuses.add_theme_constant_override("separation",12); statuses.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(statuses)
	var portrait: TextureRect = TextureRect.new()
	portrait.name="Portrait"; portrait.texture=preload("res://assets/ui/portrait.tres")
	portrait.custom_minimum_size=Vector2(104,112); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	statuses.add_child(portrait)
	var meters: VBoxContainer = VBoxContainer.new()
	meters.name="Meters"
	meters.mouse_filter=Control.MOUSE_FILTER_IGNORE; meters.add_theme_constant_override("separation",4)
	statuses.add_child(meters); meters.add_child(label("无名之子",22))
	health=add_meter(meters,"生命",Color("d9422d"),true)
	health_value=meters.get_node("生命/Value")
	add_meter(meters,"蓝量",Color("14a9bd"),false)
	add_meter(meters,"精力",Color("4d943e"),false)
	encounter=label("",17); encounter.name="Encounter"
	encounter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	encounter.size=Vector2(370,56); add_child(encounter)
	toolbar=HBoxContainer.new(); toolbar.name="Toolbar"
	toolbar.mouse_filter=Control.MOUSE_FILTER_IGNORE; toolbar.add_theme_constant_override("separation",10)
	add_child(toolbar)
	actions=HBoxContainer.new(); actions.name="Actions"
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	actions.position=Vector2(24,-112); actions.add_theme_constant_override("separation",12)
	actions.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(actions)
	for definition in [["attack","普攻","左键",1.0],["pierce","穿透箭","Q",4.0],["rain","箭雨","E",8.0],["dodge","闪避","空格",1.0]]:
		var slot: Control = Slot.new()
		slot.name=definition[0].capitalize(); slot.icon=load("res://assets/ui/%s.tres" % definition[0])
		slot.duration=definition[3]; slot.custom_minimum_size=Vector2(60,88)
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var key: Label = label(definition[2],12)
		key.position=Vector2(2,-5)
		key.add_theme_color_override("font_outline_color",Color("141812"))
		key.add_theme_constant_override("outline_size",5); slot.add_child(key)
		slot.counter=label("",21); slot.counter.name="Cooldown"
		slot.counter.position=Vector2(0,19); slot.counter.size=Vector2(60,28)
		slot.counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; slot.add_child(slot.counter)
		var caption: Label = label(definition[1],13)
		caption.position=Vector2(0,64); caption.size.x=60
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; slot.add_child(caption)
		actions.add_child(slot); slots[definition[0]]=slot
	interaction=label("",14); interaction.name="Interaction"
	interaction.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	interaction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	interaction.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	interaction.offset_left=-580; interaction.offset_top=-76; interaction.offset_right=-24; interaction.offset_bottom=-24
	add_child(interaction)
	status=label("",26); status.name="Status"
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(status)
	reading=ColorRect.new(); reading.name="Reading"
	reading.color=Color(0.03,0.05,0.04,0.94); reading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(reading)
	var inscription: Label = label("汤谷 · 碑林遗字\n\n风过残碑\n\n山风过谷，石火未冷。\n旧路覆叶，仍有人循光而行。\n碑上余字，已随岁月漫漶。\n\nF / Esc 合上残碑 · 阅读时已暂停",22)
	inscription.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; inscription.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	inscription.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); reading.add_child(inscription)
	resized.connect(layout_edges)
	layout_edges()

func layout_edges() -> void:
	encounter.position=Vector2((size.x-370)/2,24 if size.x>=1280 else 148)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.offset_left=-214; toolbar.offset_top=24; toolbar.offset_right=-24
	interaction.offset_left=-minf(580,size.x-340)

func add_meter(parent: VBoxContainer,title: String,color: Color,enabled: bool) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	row.name=title; row.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation",6)
	parent.add_child(row)
	var caption: Label = label(title,14); caption.custom_minimum_size.x=32; row.add_child(caption)
	var meter: ProgressBar = ProgressBar.new()
	meter.name="Bar"; meter.custom_minimum_size=Vector2(184 if enabled else 158,16 if enabled else 12)
	meter.size_flags_vertical=Control.SIZE_SHRINK_CENTER; meter.show_percentage=false
	meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background",box(INK if enabled else Color(color,0.12)))
	var fill: StyleBoxFlat = box(color)
	fill.set_border_width_all(0); fill.border_width_top=1; fill.border_color=color.lightened(0.2)
	meter.add_theme_stylebox_override("fill",fill)
	row.add_child(meter)
	var value: Label = label("100 / 100" if enabled else "未启用",14)
	value.name="Value"; value.custom_minimum_size.x=64; row.add_child(value)
	if not enabled: row.modulate=Color(0.7,0.76,0.73,1)
	return meter

func update_state(snapshot: Dictionary) -> void:
	health.value=snapshot.health
	health_value.text="%d / 100" % snapshot.health
	for action in ["pierce","rain","dodge"]:
		slots[action].update_cooldown(snapshot.cooldowns[action])
