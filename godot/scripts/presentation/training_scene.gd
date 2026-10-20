extends Node2D

const Room = preload("res://scripts/combat/training_room.gd")
const Backdrop = preload("res://scripts/presentation/tanggu_backdrop.gd")
const Overlay = preload("res://scripts/presentation/combat_overlay.gd")
const Effects = preload("res://scripts/presentation/combat_effects.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
var room: TrainingRoom = Room.new()
var controls: PlayerControls = Controls.new(room)
var state: Dictionary = {}
var atlas: Dictionary = {}
var textures: Dictionary = {}
var legs: Sprite2D
var torso: Sprite2D
var bow: Sprite2D
var nocked_arrow: Sprite2D
var failed: Sprite2D
var enemy_bodies: Dictionary = {}
var backdrop: Node2D
var combat_effects: Node2D
var overlay: Node2D
var obstacle_body: Sprite2D
var camera: Camera2D
var arrows: Dictionary = {}
var skills_label: Label
var interaction_label: Label
var reading_panel: Control
var health_label: Label
var encounter_label: Label
var status_label: Label
var fullscreen: Button
var walk_time: float = 0.0
var clock: float = 0.0
var pointer_inside: bool = true
var last_run: int = 0
var view_origin: Vector2 = Vector2.ZERO
var view_zoom: float = 1.0
var aim: Vector2 = Vector2.ZERO

func sprite(key: String) -> Sprite2D:
	var node: Sprite2D = Sprite2D.new()
	node.texture = textures[key]
	add_child(node)
	return node

func _ready() -> void:
	if has_node("TangguMap"):
		room=Room.new($TangguMap.get_layout())
		controls=Controls.new(room)
	atlas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/atlas.json"))
	for key in atlas:
		textures[key] = load("res://assets/generated/%s.png" % key)
	if has_node("TangguMap"):
		backdrop=Backdrop.new(); add_child(backdrop); backdrop.setup(room.layout,atlas,textures)
	else:
		var ground: Sprite2D = sprite("ground")
		ground.position=Vector2(640,500); ground.scale=Vector2.ONE*0.75; ground.z_index=-1000
		obstacle_body=sprite("props"); pose(obstacle_body,"props",2,room.obstacle.get_center()); obstacle_body.z_index=int(room.obstacle.get_center().y)
	legs = sprite("lower")
	torso = sprite("upper")
	failed = sprite("failed")
	bow = sprite("bow")
	nocked_arrow = arrow_sprite()
	for enemy in room.snapshot().enemies:
		enemy_bodies[enemy.id]=sprite({"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance])
	combat_effects=Effects.new(); add_child(combat_effects)
	var vfx_frames: Dictionary = {}
	for frame in atlas.vfx.frames: vfx_frames[frame.name]=frame
	combat_effects.setup(vfx_frames,textures.vfx,legs,torso)
	overlay=Overlay.new(); overlay.z_index=4091; add_child(overlay)
	camera = Camera2D.new()
	add_child(camera)
	build_hud()
	state = room.snapshot()
	get_window().focus_exited.connect(func(): controls.interrupt(true))
	get_window().mouse_exited.connect(func(): pointer_inside = false; controls.pointer_leave())
	get_window().mouse_entered.connect(func(): pointer_inside = true)
	get_viewport().size_changed.connect(func(): controls.interrupt(); update_camera())
	get_window().mode = Window.MODE_MAXIMIZED
	update_camera()
	present(0.0)

func pose(node: Sprite2D, key: String, index: int, point: Vector2) -> void:
	var frame: Dictionary = atlas[key].frames[index]
	node.texture = textures[key]
	node.region_enabled = true
	node.region_rect = Rect2(frame.x, frame.y, frame.width, frame.height)
	node.centered = false
	node.offset = Vector2(-frame.originX * frame.width, -frame.originY * frame.height)
	node.scale = Vector2.ONE * float(frame.get("scale", atlas[key].scale))
	node.position = point

func update_camera() -> void:
	var size: Vector2 = get_viewport_rect().size
	view_zoom = maxf(size.y / 720.0, maxf(size.x / room.layout.width, size.y / room.layout.height))
	var visible: Vector2 = size / view_zoom
	var player_point: Vector2 = Vector2(room.snapshot().player.x, room.snapshot().player.y)
	view_origin = Vector2(clampf(player_point.x - visible.x / 2.0, 0, maxf(0, room.layout.width - visible.x)), clampf(player_point.y - visible.y / 2.0, 0, maxf(0, room.layout.height - visible.y)))
	camera.zoom = Vector2.ONE * view_zoom
	camera.position = view_origin + visible / 2.0
	camera.force_update_scroll()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.physical_keycode == KEY_F11:
				if not event.echo:
					toggle_fullscreen()
			else:
				controls.key_down(event.physical_keycode, event.echo)
		else:
			controls.key_up(event.physical_keycode)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			controls.pointer_down(pointer_inside)
		else:
			controls.pointer_up()

func _physics_process(seconds: float) -> void:
	if state.is_empty():
		return
	update_camera()
	aim = get_viewport().get_mouse_position() / view_zoom + view_origin
	state = controls.update(aim, pointer_inside, seconds)
	if state.runId != last_run:
		walk_time = 0.0
		clock = 0.0
		last_run = state.runId
	if not state.paused and state.status != "failed":
		clock += seconds
		if state.player.moving:
			walk_time += seconds
	present(seconds)
	queue_redraw()

func present(_seconds: float) -> void:
	var p: Dictionary = state.player
	var point: Vector2 = Vector2(p.x, p.y)
	var movement: Vector2 = controls.movement()
	var leg_direction: int = direction(movement.angle()) if p.moving else p.facing
	var frame: int = (1 + int(walk_time * 12) % 6) * 4 + leg_direction if p.moving else leg_direction
	var bob: float = sin(walk_time * PI * 24.0 / 7.0) * 0.8 if p.moving else 0.0
	pose(legs, "lower", frame, point + Vector2(0, bob))
	var attack: int = {"idle":0,"draw":1,"release":2,"recover":3}[state.attack]
	var upper_key: String = "upper"
	var upper_frame: int = attack*4+p.facing
	if state.hurt>0: upper_key="skills"; upper_frame=12+p.facing
	elif state.dodge>0: upper_key="skills"; upper_frame=8+p.facing
	elif state.skill!=null and state.skill.phase=="windup": upper_key="skills"; upper_frame=(4 if state.skill.kind=="rain" else 0)+p.facing
	elif state.skill!=null: upper_frame=(2 if state.skill.remaining>0.06 else 3)*4+p.facing
	pose(torso,upper_key,upper_frame,point+Vector2(0,-30+bob))
	pose(failed, "failed", p.facing, point)
	legs.z_index = int(p.y)
	torso.z_index = int(p.y) + 1
	failed.z_index = int(p.y) + 1
	var alpha: float = 0.55 if state.protection > 0 and int(clock * 16) % 2 == 1 else 1.0
	legs.modulate.a = alpha
	torso.modulate.a = alpha
	legs.visible = state.status != "failed"
	torso.visible = state.status != "failed"
	failed.visible = state.status == "failed"
	pose(bow,"bow",1 if state.attack=="draw" or (state.skill!=null and state.skill.phase=="windup") else 2 if state.attack=="release" else 0,state.grip+Vector2(0,bob))
	bow.rotation=-PI/2 if state.skill!=null and state.skill.kind=="rain" and state.skill.phase=="windup" else p.angle
	bow.z_index = int(p.y) + 2
	bow.visible = state.status != "failed"
	nocked_arrow.position = state.grip + Vector2(0, bob)
	nocked_arrow.rotation = p.angle
	nocked_arrow.z_index = int(p.y) + 3
	nocked_arrow.visible=(state.attack=="draw" or (state.skill!=null and state.skill.kind=="pierce" and state.skill.phase=="windup")) and state.status!="failed"
	if is_instance_valid(obstacle_body): obstacle_body.modulate.a=0.3 if p.y<room.obstacle.get_center().y and p.y>room.obstacle.get_center().y-126 and absf(p.x-room.obstacle.get_center().x)<100 else 1.0
	if is_instance_valid(backdrop): backdrop.update(state,clock)
	for enemy in state.enemies:
		var body: Sprite2D = enemy_bodies[enemy.id]
		var key: String = {"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance]
		var row: int = 6 if enemy.phase=="dead" else 5 if enemy.flash>0 else 3 if enemy.phase=="warn" else 4 if enemy.phase=="swing" else (0 if enemy.timer<0.18 else 5) if enemy.phase=="recover" else 1+int(clock*8)%2
		pose(body,key,row*4+direction(enemy.angle),Vector2(enemy.x,enemy.y))
		body.z_index=int(enemy.y); body.visible=enemy.phase!="inactive" and (enemy.phase!="dead" or enemy.timer>0)
		body.modulate=Color("ffedc5") if enemy.flash>0 else Color.WHITE
		body.modulate.a=enemy.timer/0.6 if enemy.phase=="dead" else 1.0
	var live_arrows: Dictionary = {}
	for arrow in state.arrows:
		live_arrows[arrow.id] = true
		if not arrows.has(arrow.id):
			arrows[arrow.id] = arrow_sprite()
		arrows[arrow.id].position = Vector2(arrow.x, arrow.y)
		arrows[arrow.id].rotation = arrow.angle
		arrows[arrow.id].z_index = int(arrow.y + 52)
	for id in arrows.keys():
		if not live_arrows.has(id):
			arrows[id].queue_free()
			arrows.erase(id)
	combat_effects.update(state,_seconds,clock)
	overlay.update(state,aim,pointer_inside)
	health_label.text="生命  %d / 100" % state.health
	var guidance: Dictionary = guidance_at(point)
	encounter_label.text=guidance.region+" · "+guidance.landmark
	skills_label.text="Q 穿透箭 %s  ·  E 箭雨 %s  ·  空格 闪避 %s" % [cooldown_text(state.cooldowns.pierce),cooldown_text(state.cooldowns.rain),cooldown_text(state.cooldowns.dodge)]
	interaction_label.text=state.feedback.text if state.feedback!=null else ("F · "+state.interaction.label+(" · "+state.interaction.reason if state.interaction.reason!=null else "")) if state.interaction!=null else "残碑藏于北侧林径 · 祭火位于南侧支路"
	status_label.visible=(state.paused and not state.reading) or state.status=="failed"
	status_label.text="已暂停\nEsc 继续" if state.paused else "影散于汤谷\nR 从起点重试"
	reading_panel.visible=state.reading
	fullscreen.text = "退出全屏" if get_window().mode == Window.MODE_FULLSCREEN else "全屏"

func direction(angle: float) -> int:
	return posmod(floori(angle / (PI / 2.0) + 0.5), 4)

func arrow_sprite() -> Sprite2D:
	var node: Sprite2D = sprite("arrow")
	node.centered = false
	node.offset = Vector2(-1509, -textures.arrow.get_height() / 2.0)
	node.scale = Vector2.ONE * 0.029
	return node

func _draw() -> void:
	if state.is_empty():
		return
	for character in [state.player]+state.enemies:
		var phase: String = character.get("phase", "")
		if phase == "inactive" or (phase == "dead" and character.timer <= 0):
			continue
		var alpha: float = character.timer / 0.6 if phase == "dead" else 1.0
		draw_set_transform(Vector2(character.x, character.y), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 18, Color(0.02, 0.03, 0.02, 0.4 * alpha))
		draw_set_transform(Vector2.ZERO)
	for enemy in state.enemies:
		if enemy.phase=="inactive" or enemy.phase=="dead": continue
		if enemy.phase=="warn" or enemy.phase=="swing":
			var sector: PackedVector2Array = [Vector2(enemy.x,enemy.y)]
			for index in 17: sector.append(Vector2(enemy.x,enemy.y)+Vector2.from_angle(enemy.angle-PI/4+index*PI/32)*70)
			draw_colored_polygon(sector,Color(0.74,0.2,0.12,0.48 if enemy.phase=="swing" else 0.16))

func make_label(text: String, size: int, color: Color = Color("eedbb5")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var title: Label = make_label("九鼎  ·  汤谷", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	fullscreen = Button.new()
	fullscreen.focus_mode = Control.FOCUS_NONE
	fullscreen.text = "全屏"
	fullscreen.pressed.connect(toggle_fullscreen)
	top.add_child(fullscreen)
	health_label = make_label("生命 100 / 100", 15)
	column.add_child(health_label)
	skills_label=make_label("",13,Color("b8b59f")); column.add_child(skills_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	encounter_label = make_label("向右接近日鸟石庭", 18)
	column.add_child(encounter_label)
	interaction_label=make_label("",14); column.add_child(interaction_label)
	column.add_child(make_label("WASD 移动 · 鼠标瞄准 · 左键射箭\nQ 穿透箭 · E 箭雨 · 空格 闪避 · F 互动\nEsc 暂停 · R 重试 · F11 全屏", 13, Color("d0c4a4")))
	status_label = make_label("", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status_label)
	reading_panel=ColorRect.new(); reading_panel.color=Color(0.03,0.05,0.04,0.85)
	reading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(reading_panel)
	var inscription: Label = make_label("汤谷 · 碑林遗字\n\n风过残碑\n\n山风过谷，石火未冷。\n旧路覆叶，仍有人循光而行。\n碑上余字，已随岁月漫漶。\n\nF / Esc 合上残碑 · 阅读时已暂停",22)
	inscription.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; inscription.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	inscription.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); reading_panel.add_child(inscription)


func toggle_fullscreen() -> void:
	controls.interrupt()
	get_window().mode = Window.MODE_MAXIMIZED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func cooldown_text(value: float) -> String:
	return "就绪" if value<=0 else "%.1fs" % value
func guidance_at(position: Vector2) -> Dictionary:
	var region: String = "汤谷"
	var priority: int = -1
	for area in room.layout.get("walkableAreas",[]):
		if position.x>=area.left and position.x<=area.right and position.y>=area.top and position.y<=area.bottom and int(area.get("priority",0))>priority:
			region=area.get("region","汤谷"); priority=area.get("priority",0)
	var group: Dictionary = room.layout.encounters[mini(state.encounter,room.layout.encounters.size()-1)]
	return {"region":region,"landmark":"主路已肃清 · 可回头探索" if state.status=="complete" else "下一地标 · "+group.get("landmark","日鸟石庭")}
