extends Control

signal backpack_button_pressed

const Slot = preload("res://scripts/presentation/action_slot.gd")
const TEXT = Color("f2e6c5")
const SLOT_SIZE := Vector2(44,72)
const SLOT_ICON_SIZE := Vector2(44,44)
const ACTION_SEPARATION: int = 8
const LOADOUT_KINDS: Array[String] = ["backwind","charge","wind"]
const ACTION_ORDER: Array = [
	{"kind":"attack","title":"普攻","key":"左键","duration":1.0,"cost":"","source_kind":"base","source":"人物基础","stamina":false},
	{"kind":"pierce","title":"穿透箭","key":"Q","duration":4.0,"cost":"12 蓝量","source_kind":"equipment","source":"装备：训练弓","stamina":false},
	{"kind":"rain","title":"箭雨","key":"E","duration":8.0,"cost":"28 蓝量","source_kind":"equipment","source":"装备：训练弓","stamina":false},
	{"kind":"backwind","title":"回风","key":"G","duration":5.0,"cost":"12 蓝量","source_kind":"equipment","source":"装备：布履","stamina":false},
	{"kind":"charge","title":"蓄势","key":"T","duration":10.0,"cost":"16 蓝量","source_kind":"synergy","source":"羁绊：训练弓＋布履","stamina":false},
	{"kind":"wind","title":"引风","key":"C","duration":8.0,"cost":"16 蓝量","source_kind":"beast","source":"随行：青龙","stamina":false},
	{"kind":"dodge","title":"闪避","key":"空格","duration":1.0,"cost":"25 精力","source_kind":"base","source":"人物基础","stamina":true}
]
const ICON_PATHS: Dictionary = {
	"attack":"res://assets/ui/attack.tres",
	"pierce":"res://assets/ui/pierce.tres",
	"rain":"res://assets/ui/rain.tres",
	"backwind":"res://assets/ui/skill-candidates-v2/backwind.png",
	"charge":"res://assets/ui/attack.tres",
	"wind":"res://assets/ui/skill-candidates-v2/wind.png",
	"dodge":"res://assets/ui/skill-candidates-v2/dodge.png"
}
const SOURCE_TAGS: Dictionary = {"base":"基","equipment":"装","synergy":"羁","beast":"兽"}
const SOURCE_COLORS: Dictionary = {
	"base":Color("d9d3b6"),
	"equipment":Color("e6b66d"),
	"synergy":Color("d6a9e0"),
	"beast":Color("78d6e2")
}
const SKILL_DESCRIPTIONS: Dictionary = {
	"attack":"基础射箭。左键按下后按当前射击间隔发射普通箭。",
	"pierce":"发射一支穿透箭，可穿过目标并造成穿透伤害。",
	"rain":"向目标区域降下箭雨，对范围内敌人造成多段伤害。",
	"dodge":"向当前输入方向闪避，消耗精力并提供短暂无敌。",
	"backwind":"布履回身并在起点释放回风打击，先脱离再反击。",
	"charge":"蓄势强化接下来的两发普通箭，消耗蓝量并记录蓄势层。",
	"wind":"青龙引导风道；风道内追加一次回息，恢复精力并保留风爆机会。"
}
const SKILL_CONTRACTS: Dictionary = {
	"attack":{"category":"人物基础操作","direction":"鼠标瞄准","motion":"原地射击；无位移","damage":"普通箭伤害","invulnerable":"否","blocked":"受出箭点阻挡","interrupt":"会被闪避、回风、引风打断待发"},
	"pierce":{"category":"装备技能","direction":"鼠标瞄准","motion":"原地施放；前摇 0.18 秒","damage":"穿透伤害","invulnerable":"否","blocked":"出箭点被阻挡时按现有规则处理","interrupt":"会被闪避、回风、引风打断前摇"},
	"rain":{"category":"装备技能","direction":"鼠标指向合法落点","motion":"原地施放；前摇 0.45 秒","damage":"落点多段范围伤害","invulnerable":"否","blocked":"落点不可行走时失败","interrupt":"会被闪避、回风、引风打断前摇；已生效箭雨保留"},
	"backwind":{"category":"装备攻击技能","direction":"移动输入；无输入时沿瞄准反方向","motion":"冲刺约 120；持续 0.20 秒；起点回风半径约 120","damage":"起点回风打击 30 基础伤害","invulnerable":"否","blocked":"受可行走区域和实体阻挡","interrupt":"会取消当前待发攻击／技能；已发射箭和已生效箭雨保留"},
	"charge":{"category":"装备羁绊技能","direction":"无方向","motion":"原地蓄势","damage":"不直接造成伤害","invulnerable":"否","blocked":"受技能前摇与已有蓄势限制","interrupt":"会被闪避、回风、引风打断待发"},
	"wind":{"category":"神兽恢复技能","direction":"移动输入；无输入时沿瞄准方向","motion":"首次铺设约 120 的风道；持续约 3 秒","damage":"箭穿风道可触发现有风爆；追加本身不造成伤害","invulnerable":"否","blocked":"首次路径受可行走区域和实体阻挡","interrupt":"会取消当前待发攻击／技能；已发射箭和已生效箭雨保留"},
	"dodge":{"category":"人物基础操作","direction":"移动输入；无输入时沿当前瞄准方向","motion":"冲刺约 120；持续 0.20 秒","damage":"不造成伤害","invulnerable":"是；约 0.12 秒","blocked":"受可行走区域和实体阻挡","interrupt":"优先级最高；会取消当前待发攻击／技能"}
}
var health: ProgressBar
var health_value: Label
var mana: ProgressBar
var stamina: ProgressBar
var mana_value: Label
var stamina_value: Label
var encounter: Label
var interaction: Label
var bag_button: Button
var status: Label
var reading: ColorRect
var toolbar: HBoxContainer
var actions: HBoxContainer
var slots: Dictionary = {}
var captions: Dictionary = {}
var costs: Dictionary = {}
const DEFAULT_INSCRIPTION: String = "汤谷 · 碑林遗字\n\n风过残碑\n\n山风过谷，石火未冷。\n旧路覆叶，仍有人循光而行。\n碑上余字，已随岁月漫漶。"
var inscription: Label
var loadout_actions: HBoxContainer
var source_summary: Label
var source_legend: Label
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
	actions.position=Vector2(24,-96); actions.add_theme_constant_override("separation",ACTION_SEPARATION)
	actions.mouse_filter=Control.MOUSE_FILTER_PASS; add_child(actions)
	for definition in ACTION_ORDER:
		add_action_slot(definition.kind,definition.title,definition.key,definition.duration,definition.cost,definition.stamina,definition.source_kind)
	loadout_actions=actions
	source_summary=label("Q/E 来源 训练弓 · G 来源 布履\nT 来源 弓＋履羁绊 · C 来源 青龙",11)
	source_summary.visible=false
	add_child(source_summary)
	source_legend=label("人物基础：普攻／闪避    ·    来源技能：训练弓／布履／羁绊／青龙",11)
	source_legend.add_theme_color_override("font_color",Color("c3b995"))
	source_legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	source_legend.offset_left=24; source_legend.offset_top=-119; source_legend.offset_right=610; source_legend.offset_bottom=-101
	add_child(source_legend)
	for kind in LOADOUT_KINDS:
		slots[kind].visible=false
	bag_button=Button.new(); bag_button.name="BagButton"
	bag_button.text="背包 · B"
	bag_button.focus_mode=Control.FOCUS_NONE
	bag_button.mouse_filter=Control.MOUSE_FILTER_STOP
	bag_button.add_theme_font_size_override("font_size",14)
	bag_button.add_theme_color_override("font_color",Color("f4e5be"))
	var btn_norm: StyleBoxFlat = StyleBoxFlat.new()
	btn_norm.bg_color = Color(0.10, 0.14, 0.10, 0.92)
	btn_norm.border_color = Color(0.65, 0.55, 0.35, 0.75)
	btn_norm.border_width_left = 1; btn_norm.border_width_top = 1; btn_norm.border_width_right = 1; btn_norm.border_width_bottom = 1
	btn_norm.content_margin_left = 8; btn_norm.content_margin_top = 6; btn_norm.content_margin_right = 8; btn_norm.content_margin_bottom = 6
	bag_button.add_theme_stylebox_override("normal", btn_norm)
	var btn_hov: StyleBoxFlat = StyleBoxFlat.new()
	btn_hov.bg_color = Color(0.16, 0.22, 0.16, 0.95)
	btn_hov.border_color = Color("ead29a")
	btn_hov.border_width_left = 1; btn_hov.border_width_top = 1; btn_hov.border_width_right = 1; btn_hov.border_width_bottom = 1
	btn_hov.content_margin_left = 8; btn_hov.content_margin_top = 6; btn_hov.content_margin_right = 8; btn_hov.content_margin_bottom = 6
	bag_button.add_theme_stylebox_override("hover", btn_hov)
	bag_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bag_button.offset_left=-140; bag_button.offset_top=-68; bag_button.offset_right=-24; bag_button.offset_bottom=-24
	bag_button.pressed.connect(func(): backpack_button_pressed.emit())
	add_child(bag_button)
	interaction=label("",14); interaction.name="Interaction"
	interaction.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	interaction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	interaction.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	interaction.offset_left=-600; interaction.offset_top=-68; interaction.offset_right=-152; interaction.offset_bottom=-24
	add_child(interaction)
	status=label("",26); status.name="Status"
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(status)
	reading=ColorRect.new(); reading.name="Reading"
	reading.color=Color(0.03,0.05,0.04,0.94); reading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(reading)
	inscription=label("",22)
	inscription.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; inscription.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	inscription.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); reading.add_child(inscription)
	set_inscription("","")
	resized.connect(layout_edges)
	layout_edges()

func add_action_slot(kind: String,title: String,key_text: String,duration: float,cost_text: String,is_stamina: bool,source_kind: String) -> void:
	var slot: Control = Slot.new()
	slot.name=kind.capitalize()
	slot.set_slot_size(SLOT_ICON_SIZE)
	slot.custom_minimum_size=SLOT_SIZE
	slot.mouse_filter=Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape=Control.CURSOR_HELP
	slot.duration=duration
	slot.icon=load(ICON_PATHS[kind])
	slot.source_kind=source_kind
	var key: Label = label(key_text,11)
	key.position=Vector2(1,-4)
	key.size=Vector2(SLOT_SIZE.x-2,16)
	key.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	key.add_theme_color_override("font_outline_color",Color("141812"))
	key.add_theme_constant_override("outline_size",4)
	slot.add_child(key)
	var source_tag: Label = label(SOURCE_TAGS.get(source_kind,""),9)
	source_tag.position=Vector2(SLOT_SIZE.x-17,-4)
	source_tag.size=Vector2(16,14)
	source_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	source_tag.add_theme_color_override("font_color",SOURCE_COLORS.get(source_kind,TEXT))
	source_tag.add_theme_color_override("font_outline_color",Color("141812"))
	source_tag.add_theme_constant_override("outline_size",3)
	slot.add_child(source_tag)
	slot.counter=label("",17); slot.counter.name="Cooldown"
	slot.counter.position=Vector2(0,14); slot.counter.size=Vector2(SLOT_SIZE.x,20)
	slot.counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; slot.add_child(slot.counter)
	var caption: Label = label(title,11)
	caption.position=Vector2(0,45); caption.size=Vector2(SLOT_SIZE.x,16)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	captions[kind]=caption; slot.add_child(caption)
	if kind!="attack":
		var cost: Label = label(cost_text,9)
		cost.position=Vector2(0,60); cost.size=Vector2(SLOT_SIZE.x,14)
		cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		cost.add_theme_color_override("font_color",Color("82b65b") if is_stamina else Color("63c4ce"))
		costs[kind]=cost; slot.add_child(cost)
	actions.add_child(slot); slots[kind]=slot

func set_inscription(title: String,body: String) -> void:
	inscription.text=(DEFAULT_INSCRIPTION if body.is_empty() else title+"\n\n"+body)+"\n\nF / Esc 合上残碑 · 阅读时已暂停"

func layout_edges() -> void:
	encounter.position=Vector2((size.x-330)/2,24 if size.x>=1280 else 148)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.offset_left=-214; toolbar.offset_top=24; toolbar.offset_right=-24
	source_legend.position=Vector2(24,size.y-119)
	if bag_button!=null:
		bag_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		bag_button.offset_left=-140; bag_button.offset_top=-68; bag_button.offset_right=-24; bag_button.offset_bottom=-24
	interaction.offset_right=-152
	interaction.offset_left=-minf(600,size.x-340)

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
	var resources: Dictionary = snapshot.get("resources",{})
	var costs_snapshot: Dictionary = resources.get("costs",{})
	slots.attack.insufficient=false
	slots.attack.update_cooldown(0)
	slots.attack.tooltip_text=tooltip_for("attack",snapshot,{},0,false)
	for action in ["pierce","rain","dodge"]:
		var required: int = 25 if action=="dodge" else int(costs_snapshot.get(action,0))
		slots[action].insufficient=resources.is_empty() or (resources.stamina+0.000001<required if action=="dodge" else resources.mana<required)
		slots[action].update_cooldown(snapshot.cooldowns.get(action,0.0))
		slots[action].set_availability(availability_for(action,snapshot,required,false,true))
		slots[action].tooltip_text=tooltip_for(action,snapshot,{},required,false)
	var loadout: bool = snapshot.get("alpha",{}).has("skills")
	for kind in LOADOUT_KINDS:
		slots[kind].visible=loadout
	source_summary.visible=false
	if loadout:
		var beast_name: String = snapshot.get("alpha",{}).get("blessingBeast","青龙")
		source_summary.text="Q/E 来源 训练弓 · G 来源 布履\nT 来源 弓＋履羁绊 · C 来源 "+beast_name
		for kind in LOADOUT_KINDS:
			var skill: Dictionary = snapshot.alpha.skills.get(kind,{})
			var cost: int = int(costs_snapshot.get(kind,0))
			var extra: bool = kind=="wind" and snapshot.get("windExtraReady",false)
			var active: bool = bool(skill.get("active",false))
			captions[kind].text="引风回息" if extra else str(skill.get("name",kind))
			var missing_hint: String = {"backwind":"需布履","charge":"需弓＋履","wind":"需"+beast_name}.get(kind,"需穿戴")
			costs[kind].text=("精力+20" if extra else "%d 蓝量" % cost) if active else missing_hint
			slots[kind].duration={"backwind":5.0,"charge":10.0,"wind":8.0}.get(kind,5.0)
			slots[kind].insufficient=not active or not extra and resources.mana<cost
			slots[kind].update_cooldown(0 if extra else snapshot.cooldowns.get(kind,0.0))
			slots[kind].set_availability(availability_for(kind,snapshot,cost,extra,active))
			slots[kind].tooltip_text=tooltip_for(kind,snapshot,skill,cost,extra)

func tooltip_for(kind: String,snapshot: Dictionary,skill: Dictionary,required: int,extra: bool) -> String:
	var title: String = str(captions[kind].text)
	var key_text: String = {"attack":"左键","pierce":"Q","rain":"E","dodge":"空格","backwind":"G","charge":"T","wind":"C"}.get(kind,"")
	var contract: Dictionary = SKILL_CONTRACTS.get(kind,{})
	var lines: Array[String] = [
		title+"  ·  "+key_text,
		"类别："+str(contract.get("category","")),
		"作用："+SKILL_DESCRIPTIONS.get(kind,""),
		"来源："+(str(skill.get("source","未接入")) if kind in LOADOUT_KINDS else str(contract.get("category","人物基础操作"))),
		"方向："+str(contract.get("direction",""))+"；"+str(contract.get("motion","")),
		"伤害："+str(contract.get("damage",""))+"；无敌："+str(contract.get("invulnerable","")),
		"阻挡："+str(contract.get("blocked","")),
		"打断："+str(contract.get("interrupt",""))
	]
	if kind in LOADOUT_KINDS:
		if not bool(skill.get("active",false)):
			lines.append("当前：来源缺失 · "+str(skill.get("reason","来源未满足")))
		else:
			lines.append("消耗："+("追加 0 蓝；恢复 20 精力" if extra else "%d 蓝量" % required)+"；冷却："+("不重置" if extra else "%.1f 秒" % slots[kind].duration))
			if kind=="wind":
				lines.append("追加：首次成功后留下约 3 秒风道；站在风道内可追加 1 次，恢复 20 精力，不重建风道")
	else:
		lines.append("消耗："+("25 精力" if kind=="dodge" else "无")+"；冷却："+("1.0 秒" if kind=="dodge" else "按当前射击间隔"))
	var state_text: String = status_text(kind,snapshot,required,extra)
	lines.append("状态："+state_text)
	return "\n".join(lines)

func availability_for(kind: String,snapshot: Dictionary,required: int,extra: bool,active: bool) -> String:
	if kind in LOADOUT_KINDS and not active:
		return "missing"
	if extra:
		return "extra_ready"
	if snapshot.cooldowns.get(kind,0.0)>0.001:
		return "cooldown"
	var resources: Dictionary = snapshot.get("resources",{})
	if kind=="dodge" and float(resources.get("stamina",0))<required:
		return "resource"
	if kind!="attack" and kind!="dodge" and int(resources.get("mana",0))<required:
		return "resource"
	var feedback: Dictionary = snapshot.get("feedback",{}) if snapshot.get("feedback",{}) is Dictionary else {}
	if str(feedback.get("text","")).contains("无合法位移") and kind in ["backwind","wind","dodge"]:
		return "blocked"
	return "ready"

func status_text(kind: String,snapshot: Dictionary,required: int,extra: bool) -> String:
	var skill: Dictionary = snapshot.get("alpha",{}).get("skills",{}).get(kind,{})
	if kind in LOADOUT_KINDS and not bool(skill.get("active",false)):
		return "来源缺失 · "+str(skill.get("reason","来源未满足"))
	if extra:
		return "回息可用 · 0 蓝 · 精力+20 · 风道内"
	var remaining: float = slots[kind].remaining
	if remaining>0.001:
		return "冷却中 · %.1f 秒" % remaining
	var feedback: Dictionary = snapshot.get("feedback",{}) if snapshot.get("feedback",{}) is Dictionary else {}
	var feedback_text: String = str(feedback.get("text",""))
	if feedback_text.contains("无合法位移") and kind in ["backwind","wind","dodge"]:
		return "被实体或边界阻挡 · 本次未支付"
	if slots[kind].insufficient:
		return "精力不足" if kind=="dodge" else "蓝量不足"
	return "可用"

func set_backpack_open(open: bool) -> void:
	if bag_button!=null:
		bag_button.text="收起 · B" if open else "背包 · B"
		bag_button.add_theme_color_override("font_color",Color("c8382b") if open else Color("d8cfc0"))
