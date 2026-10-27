extends Control

const Slot = preload("res://scripts/presentation/action_slot.gd")
const TEXT = Color("f2e6c5")
var health: ProgressBar
var health_value: Label
var mana: ProgressBar
var stamina: ProgressBar
var mana_value: Label
var stamina_value: Label
var encounter: Label
var interaction: Label
var status: Label
var reading: ColorRect
var toolbar: HBoxContainer
var actions: HBoxContainer
var slots: Dictionary = {}
var captions: Dictionary = {}
var costs: Dictionary = {}
var loadout_actions: HBoxContainer
var last_health: int = -1
var last_health_max: int = -1
var last_mana: int = -1
var last_stamina: int = -1

static func label(text: String,font_size: int) -> Label:
	var node: Label = Label.new()
	node.text=text; node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",TEXT)
	node.add_theme_color_override("font_shadow_color",Color("080d09"))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	return node

func _ready() -> void:
	name="CombatHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme=Theme.new()
	theme.default_font=preload("res://assets/fonts/NineTripodsHudSong.ttf")
	theme.default_font.allow_system_fallback=false
	var backing: Control = load("res://scripts/presentation/status_backing.gd").new()
	backing.name="StatusBacking"; backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backing.position=Vector2(136,28); backing.size=Vector2(330,90); add_child(backing)
	var statuses: HBoxContainer = HBoxContainer.new()
	statuses.name="PlayerStatus"; statuses.position=Vector2(24,16)
	statuses.add_theme_constant_override("separation",12); statuses.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(statuses)
	var portrait: TextureRect = TextureRect.new()
	portrait.name="Portrait"; portrait.texture=preload("res://assets/ui/portrait.tres")
	portrait.custom_minimum_size=Vector2(112,112); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	statuses.add_child(portrait)
	var meters: VBoxContainer = VBoxContainer.new()
	meters.name="Meters"
	meters.mouse_filter=Control.MOUSE_FILTER_IGNORE; meters.add_theme_constant_override("separation",0)
	meters.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	statuses.add_child(meters); meters.add_child(label("无名之子",18))
	health=add_meter(meters,"生命",Color("c82d24"),204)
	health_value=meters.get_node("生命/Value")
	mana=add_meter(meters,"蓝量",Color("09a9bc"),180)
	stamina=add_meter(meters,"精力",Color("539c32"),164)
	stamina.segmented=true
	mana_value=meters.get_node("蓝量/Value"); stamina_value=meters.get_node("精力/Value")
	encounter=label("",17); encounter.name="Encounter"
	encounter.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	encounter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	encounter.size=Vector2(330,56); add_child(encounter)
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
		captions[definition[0]]=caption
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; slot.add_child(caption)
		if definition[0]!="attack":
			var cost: Label = label("25 精力" if definition[0]=="dodge" else "12 蓝量" if definition[0]=="pierce" else "28 蓝量",10)
			costs[definition[0]]=cost
			cost.position=Vector2(0,82); cost.size.x=60; cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			cost.add_theme_color_override("font_color",Color("82b65b") if definition[0]=="dodge" else Color("63c4ce"))
			slot.add_child(cost)
		actions.add_child(slot); slots[definition[0]]=slot
	loadout_actions=HBoxContainer.new(); loadout_actions.name="LoadoutActions"
	loadout_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	loadout_actions.position=Vector2(24,-212); loadout_actions.add_theme_constant_override("separation",12)
	loadout_actions.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(loadout_actions)
	for definition in [["special2","G"],["wind","C"]]:
		var slot: Control = Slot.new(); slot.name=definition[0].capitalize()
		slot.custom_minimum_size=Vector2(60,88); slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.icon=load("res://assets/ui/dodge.tres"); loadout_actions.add_child(slot)
		var key: Label = label(definition[1],12); key.position=Vector2(2,-5); slot.add_child(key)
		slot.counter=label("",21); slot.counter.position=Vector2(0,19); slot.counter.size=Vector2(60,28)
		slot.counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; slot.add_child(slot.counter)
		var caption: Label = label("",13); caption.position=Vector2(0,64); caption.size.x=60
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; slot.add_child(caption); captions[definition[0]]=caption
		var cost: Label = label("",10); cost.position=Vector2(0,82); cost.size.x=60
		cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; cost.add_theme_color_override("font_color",Color("63c4ce"))
		slot.add_child(cost); costs[definition[0]]=cost; slots[definition[0]]=slot
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
	encounter.position=Vector2((size.x-330)/2,24 if size.x>=1280 else 148)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.offset_left=-214; toolbar.offset_top=24; toolbar.offset_right=-24
	interaction.offset_left=-minf(580,size.x-340)

func add_meter(parent: VBoxContainer,title: String,color: Color,width: int) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	row.name=title; row.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation",6)
	parent.add_child(row)
	var caption: Label = label(title,14); caption.custom_minimum_size.x=32; row.add_child(caption)
	var meter: ProgressBar = load("res://scripts/presentation/resource_meter.gd").new()
	meter.name="Bar"; meter.custom_minimum_size=Vector2(width,14); meter.tint=color
	meter.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	var value: Label = label("100 / 100",14)
	value.name="Value"; value.custom_minimum_size.x=64; row.add_child(value)
	return meter

func update_state(snapshot: Dictionary) -> void:
	# 数值未变时不重新格式化字符串，也不重复触发 ProgressBar／Label 重绘。
	var health_max: int = snapshot.get("healthMax",100)
	if snapshot.health!=last_health or health_max!=last_health_max:
		last_health=snapshot.health
		last_health_max=health_max
		health.max_value=health_max
		health.value=last_health
		health_value.text="%d / %d" % [last_health,health_max]
	if snapshot.has("resources"):
		var mana_now: int = snapshot.resources.mana
		var stamina_exact: float = snapshot.resources.stamina
		var stamina_now: int = floori(stamina_exact+0.000001)
		if mana_now!=last_mana:
			last_mana=mana_now
			mana.value=mana_now; mana_value.text="%d / 100" % mana_now
		if not is_equal_approx(stamina.value,stamina_exact): stamina.value=stamina_exact
		if stamina_now!=last_stamina:
			last_stamina=stamina_now
			stamina_value.text="%d / 100" % stamina_now
	for action in ["pierce","rain","dodge"]:
		slots[action].insufficient=snapshot.has("resources") and (snapshot.resources.stamina+0.000001<25 if action=="dodge" else snapshot.resources.mana<snapshot.resources.costs[action])
		slots[action].update_cooldown(snapshot.cooldowns[action])

	var loadout: bool = snapshot.get("alpha",{}).has("specialSlots")
	loadout_actions.visible=loadout
	if not loadout:
		captions.rain.text="箭雨"; costs.rain.text="28 蓝量"; slots.rain.duration=8.0
		slots.rain.icon=load("res://assets/ui/rain.tres")
	if loadout:
		for index in 2:
			var choice: Dictionary = snapshot.alpha.specialSlots[index]
			var kind: String = choice.get("skill","") if choice.active else ""
			var action: String = "rain" if index==0 else "special2"
			captions[action].text={"rain":"箭雨","backwind":"回风","charge":"蓄势"}.get(kind,"未启用")
			var cost: int = snapshot.get("resources",{}).get("costs",{}).get(kind,0)
			costs[action].text="%d 蓝量" % cost if not kind.is_empty() else "空槽"
			slots[action].duration={"rain":8.0,"backwind":5.0,"charge":10.0}.get(kind,1.0)
			slots[action].icon=load("res://assets/ui/%s.tres" % ("rain" if kind=="rain" else "dodge" if kind=="backwind" else "attack"))
			slots[action].insufficient=kind.is_empty() or snapshot.has("resources") and snapshot.resources.mana<cost
			slots[action].update_cooldown(snapshot.cooldowns.get(kind,0.0))
		var extra: bool = snapshot.get("windExtraReady",false)
		captions.wind.text="引风追加" if extra else "引风"
		costs.wind.text="追加0蓝" if extra else "16 蓝量"
		slots.wind.duration=8.0
		slots.wind.insufficient=not extra and snapshot.has("resources") and snapshot.resources.mana<16
		slots.wind.update_cooldown(0 if extra else snapshot.cooldowns.get("wind",0.0))
