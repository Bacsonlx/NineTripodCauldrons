extends Node2D

const Profile = preload("res://scripts/hub/profile.gd")
const UI = preload("res://scripts/hub/hub_theme.gd")
const Art = preload("res://scripts/presentation/item_art.gd")
const Bag = preload("res://scripts/hub/hub_bag.gd")
const Journey = preload("res://scripts/journey/room_journey.gd")
const PlayerActor = preload("res://scripts/presentation/player_frame_actor.gd")
const FIRST_LEVEL = "res://scenes/tanggu_first_level.tscn"
const ROLES: Dictionary = {"Smith":"铁匠 · 打造", "Merchant":"商人 · 补给", "Keeper":"守祠人 · 出征"}
const SKILL_LABELS: Dictionary = {"pierce":"Q 穿透箭","rain":"E 箭雨","backwind":"G 回风","charge":"T 蓄势","wind":"C 引风"}
const SPEED: float = 245.0
const REACH: float = 88.0

@onready var child: Node2D = $People/Child
@onready var people: Node2D = $People
@onready var camera: Camera2D = $Camera
@onready var courtyard: Sprite2D = $Courtyard
@onready var walkable: PackedVector2Array = $Walkable.polygon
var profile: RefCounted
var bag: CanvasLayer
var preparation_room: TrainingRoom
var upper: Sprite2D
var legs: Sprite2D
var frame_actor: Node2D
var facing: int = 3
var walk_distance: float = 0.0
var keys: Dictionary = {}
var interface: Control
var summary: Label
var hint: Label
var modal: ColorRect
var service: String = ""
var notice: String = ""
var launching: bool = false

func _ready() -> void:
	profile=Profile.new()
	if profile.error.is_empty() and not profile.data.settlement.is_empty():
		get_tree().change_scene_to_file.bind("res://scenes/settlement.tscn").call_deferred()
		return
	if profile.error.is_empty() and not profile.data.active.is_empty():
		get_tree().set_meta("resume_safehouse_journey",true)
		get_tree().change_scene_to_file.bind(FIRST_LEVEL).call_deferred()
		return
	child.position=$Spawn.position
	make_child()
	make_interface()
	preparation_room=TrainingRoom.new({"width":1280,"height":720,"spawn":Vector2(320,520),"gameplay":true})
	preparation_room.alpha=profile.preparation()
	bag=Bag.new()
	bag.profile=profile
	add_child(bag)
	bag.setup(preparation_room,null)
	bag.preparation_changed.connect(update_summary)
	bag.preparation_closed.connect(update_summary)
	bag.add_button("撤销手动嵌符",bag.action_buttons_host,bag.undo_glyphs)
	bag.add_button("恢复免费方案",bag.action_buttons_host,reset_bag)
	get_viewport().size_changed.connect(fit_camera)
	get_window().focus_exited.connect(func(): keys.clear())
	fit_camera()
	update_summary()
	if not profile.error.is_empty(): open_service("error",profile.error)

func fit_camera() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = courtyard.transform*courtyard.get_rect()
	var zoom: float = maxf(screen.x/bounds.size.x,screen.y/bounds.size.y)
	camera.zoom=Vector2.ONE*zoom
	var center: Vector2 = bounds.get_center()
	var travel: Vector2 = (bounds.size-screen/zoom).max(Vector2.ZERO)*0.5
	camera.position=child.position.clamp(center-travel,center+travel)

func make_child() -> void:
	frame_actor=PlayerActor.new()
	frame_actor.scale=Vector2.ONE*(2.0/3.0)
	child.add_child(frame_actor)
	legs=frame_actor.lower; upper=frame_actor.upper
	pose_child(false)

func pose_child(moving: bool) -> void:
	frame_actor.generation=0; frame_actor.distance=walk_distance
	var state: Dictionary = {"runId":0,"paused":false,"status":"playing","unarmed":true,
		"player":{"x":0.0,"y":0.0,"facing":facing,"moving":moving},
		"hurt":0.0,"dodge":0.0,"skill":null,"attack":"idle"}
	frame_actor.update_state(state,Vector2.from_angle(facing*PI/2) if moving else Vector2.ZERO,0.0)

func _physics_process(seconds: float) -> void:
	if bag==null or modal!=null or bag.backpack_open or launching: return
	var direction: Vector2 = Vector2(float(keys.has(KEY_D))-float(keys.has(KEY_A)),float(keys.has(KEY_S))-float(keys.has(KEY_W))).normalized()
	if direction!=Vector2.ZERO:
		var previous: Vector2 = child.position
		var delta: Vector2 = direction*SPEED*seconds
		for offset in [Vector2(delta.x,0),Vector2(0,delta.y)]:
			var target: Vector2 = child.position+offset
			if can_walk(target): child.position=target
		if child.position.distance_squared_to(previous)<delta.length_squared()*0.25:
			var base_angle: float = delta.angle()
			var step_len: float = delta.length()
			for slide_offset in [0.35,-0.35,0.70,-0.70,1.05,-1.05]:
				var candidate: Vector2 = previous+Vector2.from_angle(base_angle+slide_offset)*(step_len*maxf(0.4,cos(slide_offset)))
				if can_walk(candidate):
					child.position=candidate
					break
		facing=posmod(roundi(direction.angle()/(PI/2)),4)
		walk_distance+=previous.distance_to(child.position)
		pose_child(previous!=child.position)
		if previous!=child.position: fit_camera()
	else: pose_child(false)
	var person: String = nearest_service()
	hint.text="F  %s" % ROLES[person] if not person.is_empty() else "WASD 行走     B 背包     Esc 菜单"
	hint.get_parent().visible=true

func can_walk(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point,walkable): return false
	for name_text in ROLES:
		if point.distance_to(people.get_node(name_text).position)<28.0: return false
	return true

func nearest_service() -> String:
	var best: String = ""
	var distance: float = REACH
	for name_text in ROLES:
		var gap: float = child.position.distance_to(people.get_node(name_text).position)
		if gap<distance:
			distance=gap
			best=name_text
	return best

func _input(event: InputEvent) -> void:
	if bag==null or not event is InputEventKey: return
	var key: int = event.physical_keycode
	if key in [KEY_W,KEY_A,KEY_S,KEY_D]:
		if not event.pressed: keys.erase(key)
		elif not event.echo and modal==null and not bag.backpack_open and not launching: keys[key]=true
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.echo or launching: return
	match key:
		KEY_ESCAPE:
			if bag.backpack_open: bag.close_backpack()
			elif service=="confirm": open_service("Keeper")
			elif modal!=null: close_modal()
			else: open_service("menu")
		KEY_B:
			if bag.backpack_open: bag.close_backpack()
			elif modal==null and profile.error.is_empty(): open_bag()
		KEY_R:
			if bag.backpack_open: bag.rotate_selected()
		KEY_F:
			if modal==null and not bag.backpack_open:
				var person: String = nearest_service()
				if not person.is_empty(): open_service(person)
		KEY_F11:
			if DisplayServer.get_name()!="headless": toggle_fullscreen()
		_: return
	get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	var window: Window = get_window()
	window.mode=Window.MODE_MAXIMIZED if window.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN

func make_interface() -> void:
	interface=Control.new()
	$Interface.add_child(interface)
	interface.theme=UI.make()
	interface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	interface.add_child(margin)
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,26)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layout.add_child(header)
	var place: PanelContainer = PanelContainer.new()
	place.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.add_child(place)
	var words: VBoxContainer = VBoxContainer.new()
	place.add_child(words)
	words.add_child(UI.label("九 鼎  /  局 外",12,UI.GOLD))
	words.add_child(UI.label("祠庙前院",29))
	var spacer: Control = Control.new()
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var funds: PanelContainer = PanelContainer.new()
	funds.mouse_filter=Control.MOUSE_FILTER_IGNORE
	funds.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	header.add_child(funds)
	summary=UI.label("",17)
	funds.add_child(summary)
	spacer=Control.new()
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	var footer: CenterContainer = CenterContainer.new()
	footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layout.add_child(footer)
	var plaque: PanelContainer = PanelContainer.new()
	plaque.mouse_filter=Control.MOUSE_FILTER_IGNORE
	footer.add_child(plaque)
	hint=UI.label("走向守祠人 · 请后羿，踏入汤谷",17)
	plaque.add_child(hint)
	for name_text in ROLES:
		var label: Label = UI.label(ROLES[name_text],24,UI.PAPER)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",interface.theme.default_font)
		label.add_theme_color_override("font_outline_color",Color("171915"))
		label.add_theme_constant_override("outline_size",8)
		label.position=people.get_node(name_text).position+Vector2(-104,-153)
		label.size=Vector2(208,42)
		label.z_index=2
		add_child(label)

func update_summary() -> void:
	summary.text="筹备资源  %d    香火  %d" % [profile.data.resources,profile.data.incense]

func open_bag() -> void:
	close_modal()
	keys.clear()
	preparation_room.alpha=profile.preparation()
	bag.open_backpack()

func reset_bag() -> void:
	var previous: Dictionary = profile.data.duplicate(true)
	profile.reset_preparation()
	if not profile.commit(previous):
		preparation_room.alpha.message="保存失败，准备未重置"
		return
	preparation_room.alpha=profile.preparation()
	bag.selected=-1
	bag.signature=""
	bag.refresh()

func close_modal() -> void:
	if modal==null: return
	interface.remove_child(modal)
	modal.queue_free()
	modal=null
	service=""
	keys.clear()

func open_service(which: String,message: String = "") -> void:
	close_modal()
	service=which
	notice=message
	keys.clear()
	modal=ColorRect.new()
	modal.color=Color(0.04,0.07,0.06,0.68)
	interface.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	modal.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,18)
	var center: CenterContainer = CenterContainer.new()
	margin.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	panel.custom_minimum_size.x=minf(730,get_viewport_rect().size.x-36)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	column.add_child(UI.label("祠 庙 前 院",12,UI.GOLD))
	var titles: Dictionary = {"Smith":"炉边打造","Merchant":"行前补给","Keeper":"请神出征","confirm":"确认出征","menu":"系统菜单","error":"进度读取失败"}
	column.add_child(UI.label(titles[which],31))
	if which in ["Smith","Merchant","Keeper","confirm"]:
		column.add_child(UI.label("持有 %d  /  本次 %d  /  支付后 %s" % [profile.data.resources,profile.cost(),str(profile.data.resources-profile.cost()) if profile.data.resources>=profile.cost() else "资源不足"],16,UI.GOLD))
	match which:
		"Smith": show_smith(column)
		"Merchant": show_merchant(column)
		"Keeper": show_departure(column,false)
		"confirm": show_departure(column,true)
		"menu":
			column.add_child(UI.label("WASD 行走，F 与 NPC 交谈，B 整理背包。每次出征可使用免费基础方案。",17,UI.PAPER,true))
			UI.button(column,"切换全屏 · F11",toggle_fullscreen)
			UI.button(column,"退出游戏",func(): get_tree().quit())
		"error":
			UI.button(column,"退出游戏",func(): get_tree().quit())
	if not notice.is_empty(): column.add_child(UI.label(notice,15,Color("e5ad86"),true))
	var close: Button = UI.button(column,"返回出征准备 · Esc" if which=="confirm" else "关闭 · Esc",func():
		if which=="confirm": open_service("Keeper")
		else: close_modal()
	)
	close.grab_focus()

func row(parent: Node,title: String,body: String,item_name: String,action_text: String,action: Callable,disabled: bool = false) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation",14)
	parent.add_child(line)
	var icon: TextureRect = TextureRect.new()
	icon.texture=Art.texture(item_name)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size=Vector2(36,36)
	line.add_child(icon)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.add_child(content)
	content.add_child(UI.label(title,16))
	content.add_child(UI.label(body,13,UI.MUTED,true))
	var action_button: Button = UI.button(line,action_text,action)
	action_button.disabled=disabled

func show_smith(column: VBoxContainer) -> void:
	var alpha: RefCounted = profile.preparation()
	for recipe in Profile.RECIPES:
		var equipment: Dictionary = alpha.find_item_by_name(recipe.equipment)
		var selected: bool = equipment.get("recipe","")==recipe.id
		var locked: bool = not profile.data.unlocks.has(recipe.id)
		var effect: String = "最大生命 +30" if recipe.glyph=="羊角" else "拾取半径 +5%"
		var shape: Vector2i = alpha.definition(recipe.equipment).size
		row(column,recipe.equipment+" · "+recipe.glyph+"  /  20", "%d×%d · %s · %s" % [shape.x,shape.y,effect,recipe.goal],recipe.equipment,
			"未解锁" if locked else "取消打造" if selected else "加入准备",
			func(): open_service("Smith",profile.select_recipe(recipe.id)),locked)

func show_merchant(column: VBoxContainer) -> void:
	var alpha: RefCounted = profile.preparation()
	var selected: Array[String] = profile.shop_names()
	column.add_child(UI.label("额外补给 %d / 2 · 同名限一件" % selected.size(),14,UI.MUTED))
	for name_text in Profile.SHOP:
		var item: Dictionary = alpha.definition(name_text)
		var short: String = str(item.description).get_slice("；",0)
		row(column,name_text+"  /  10",short,name_text,"移除" if selected.has(name_text) else "加入准备",
			func(): open_service("Merchant",profile.remove_purchase(name_text) if selected.has(name_text) else profile.buy(name_text)))

func show_departure(column: VBoxContainer,confirm: bool) -> void:
	var alpha: RefCounted = profile.preparation()
	column.add_child(UI.label("请神  后羿     地区  汤谷     完整征程",22))
	var skill_names: PackedStringArray = []
	for key in SKILL_LABELS:
		if alpha.skill_active(key): skill_names.append(SKILL_LABELS[key])
	column.add_child(UI.label("%d 件携带物 · %s" % [alpha.items.size(),"  ".join(skill_names) if not skill_names.is_empty() else "仅基础普攻和闪避"],15,UI.MUTED,true))
	var shadows: Array = alpha.items.filter(func(item: Dictionary): return item.get("shadow",false))
	if not shadows.is_empty():
		column.add_child(UI.label("传承：%s · 占用祭坛格 · 出征后锁定" % shadows[0].name,16,UI.GOLD))
	elif not profile.data.heritage.is_empty():
		column.add_child(UI.label("未携带残影「%s」，确认出征将失去这份传承。" % profile.data.heritage[0].name,16,Color("e5ad86"),true))
	var reason: String = profile.departure_error()
	if not reason.is_empty(): column.add_child(UI.label(reason,16,Color("e5ad86"),true))
	if not confirm: UI.button(column,"整理背包",open_bag)
	var go: Button = UI.button(column,"确认入局 · 支付 %d" % profile.cost() if confirm else "核对出征准备",depart if confirm else func(): open_service("confirm"))
	go.disabled=not reason.is_empty()

func depart() -> void:
	if launching: return
	var reason: String = profile.departure_error()
	if not reason.is_empty():
		open_service("confirm",reason)
		return
	launching=true
	var maps: Dictionary = Journey.read_maps()
	var next_scene: PackedScene = load(FIRST_LEVEL)
	if maps.is_empty() or next_scene==null or not next_scene.can_instantiate():
		launching=false
		open_service("confirm","汤谷加载失败，准备与资源已保留。")
		return
	var journey: RefCounted = Journey.new(maps,{"startRoom":"entry","mode":"level","potionDrops":true,
		"dropSeed":randi_range(1,2147483),"initial_backpack":profile.data.preparation})
	var before: Dictionary = profile.data.duplicate(true)
	if not profile.depart(journey):
		launching=false
		open_service("confirm","保存出征失败，准备与资源已保留。")
		return
	get_tree().set_meta("resume_safehouse_journey",true)
	if get_tree().change_scene_to_packed(next_scene)!=OK:
		get_tree().remove_meta("resume_safehouse_journey")
		launching=false
		var launched: Dictionary = profile.data
		profile.data=before
		if profile.commit(launched):
			open_service("confirm","汤谷加载失败。")
		else:
			open_service("error","无法切换场景。请重启以恢复已保存的征程。")
