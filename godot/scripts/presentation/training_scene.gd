extends Node2D

const Room = preload("res://scripts/combat/training_room.gd")
const Backdrop = preload("res://scripts/presentation/tanggu_backdrop.gd")
const NativeSuite = preload("res://scripts/qa/native_suite.gd")
const NativeProbe = preload("res://scripts/qa/native_probe.gd")
const Overlay = preload("res://scripts/presentation/combat_overlay.gd")
const Effects = preload("res://scripts/presentation/combat_effects.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
const QualityPolicy = preload("res://scripts/presentation/quality_policy.gd")
const ACTOR_VISUAL_SCALE: float = 2.0/3.0
const HERO_RUNTIME_DIRECTORY: String = "res://assets/characters/hero-runtime-v1/"
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
var frame_actor: Node2D
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
var pose_cache: Dictionary = {}
var alpha_bounds_cache: Dictionary = {}
var quality
var flash_tint: Color = Color("ffedc5")
var pierce_tint: Color = Color("ffd06c")
# 呈现节流：规则仍按物理 tick 推进，呈现只跟渲染帧；跳过的 tick 累积时间。
var present_seconds: float = 0.0
var ticks_since_present: int = 0
var last_present_frame: int = -1

func sprite(key: String) -> Sprite2D:
	var node: Sprite2D = Sprite2D.new()
	node.texture = textures[key]
	add_child(node)
	var id: int = node.get_instance_id()
	node.tree_exiting.connect(func(): pose_cache.erase(id),CONNECT_ONE_SHOT)
	return node

func _ready() -> void:
	quality=QualityPolicy.new()
	quality.configure(OS.get_cmdline_user_args())
	if has_node("TangguMap"):
		var layout: Dictionary = $TangguMap.get_layout()
		if layout.is_empty(): get_tree().quit(1); return
		room=create_room(layout)
		controls=Controls.new(room)
	atlas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/atlas.json"))
	var hero_atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HERO_RUNTIME_DIRECTORY+"legacy_atlas.json"))
	atlas.merge(hero_atlas,true)
	for key in atlas:
		textures[key] = load(HERO_RUNTIME_DIRECTORY+"legacy-%s.png" % key if hero_atlas.has(key) else "res://assets/generated/%s.png" % key)
	if has_node("TangguMap"):
		backdrop=create_backdrop(); add_child(backdrop); backdrop.setup(room.layout,atlas,textures)
	else:
		var ground: Sprite2D = sprite("ground")
		ground.position=Vector2(640,500); ground.scale=Vector2.ONE*0.75; ground.z_index=-1000
		obstacle_body=sprite("props"); pose(obstacle_body,"props",2,room.obstacle.get_center()); obstacle_body.z_index=int(room.obstacle.get_center().y)
	legs = sprite("lower")
	torso = sprite("upper")
	failed = sprite("failed")
	bow = sprite("bow")
	for hero_layer in [legs,torso,failed,bow]: hero_layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	nocked_arrow = arrow_sprite()
	frame_actor=preload("res://scripts/presentation/player_frame_actor.gd").new()
	frame_actor.scale=Vector2.ONE*ACTOR_VISUAL_SCALE
	add_child(frame_actor)
	register_player_grips()
	var initial: Dictionary = room.snapshot()
	for enemy in initial.enemies:
		enemy_bodies[enemy.id]=sprite({"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance])
	combat_effects=Effects.new(); add_child(combat_effects)
	var vfx_frames: Dictionary = {}
	for frame in atlas.vfx.frames: vfx_frames[frame.name]=frame
	combat_effects.setup(vfx_frames,textures.vfx,legs,torso)
	overlay=Overlay.new(); overlay.z_index=4091; add_child(overlay)
	camera = Camera2D.new()
	add_child(camera)
	build_hud()
	state = initial
	get_window().focus_exited.connect(func(): controls.interrupt(true))
	get_window().mouse_exited.connect(func(): pointer_inside = false; controls.pointer_leave())
	get_window().mouse_entered.connect(func(): pointer_inside = true)
	get_viewport().size_changed.connect(func(): controls.interrupt(); update_camera())
	if get_window().mode not in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]:
		get_window().mode = Window.MODE_MAXIMIZED
	update_camera()
	present(state,0.0)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if get_window().has_meta("native_qa_started"): return
	if "--layout-audit" in arguments or "--native-suite" in arguments or "--native-probe" in arguments: get_window().set_meta("native_qa_started",true)
	if "--layout-audit" in arguments:
		var output: FileAccess = FileAccess.open(arguments[arguments.find("--layout-audit")+1],FileAccess.WRITE)
		output.store_string(JSON.stringify(room.layout,"  ")+"\n"); get_tree().quit()
	elif "--native-suite" in arguments:
		add_child(NativeSuite.new())
	elif "--native-probe" in arguments:
		add_child(NativeProbe.new())

func create_backdrop() -> Node2D:
	return Backdrop.new()

func create_room(layout: Dictionary) -> TrainingRoom:
	return Room.new(layout)

func register_player_grips() -> void:
	# 联绘普通箭取正式拉满帧箭尖；复制布局，不改共享常量或技能握点。
	room.layout.grips=room.layout.grips.duplicate()
	var sources: Array = [frame_actor.upper.clips["hero-archery-upper"],atlas.upperDown,frame_actor.upper.clips["hero-archery-left"],frame_actor.upper.clips["hero-archery-up"]]
	for facing in 4:
		var grip: Dictionary = sources[facing].grip
		room.layout.grips[facing]=grip.duplicate() if room.layout.grips[facing] is Dictionary else Vector2(grip.x,grip.y)

func pose(node: Sprite2D, key: String, index: int, point: Vector2, scale_multiplier: float = 1.0) -> void:
	# 帧未变时只有位置变化：纹理／区域／锚点／缩放保持原值，
	# 避免每个精灵每帧向 RenderingServer 重复提交 6 次属性写入。
	var id: int = node.get_instance_id()
	var cached: Variant = pose_cache.get(id)
	if cached is Array and cached[0]==key and cached[1]==index:
		node.position=point
		return
	pose_cache[id]=[key,index]
	var frame: Dictionary = atlas[key].frames[index]
	node.texture = textures[key]
	node.region_enabled = true
	node.region_rect = Rect2(frame.x, frame.y, frame.width, frame.height)
	node.centered = false
	node.offset = Vector2(-frame.originX * frame.width, -frame.originY * frame.height)
	node.scale = Vector2.ONE * float(frame.get("scale", atlas[key].scale)) * scale_multiplier
	node.position = point

func waist_point(node: Sprite2D) -> Vector2:
	if node==null: return Vector2.ZERO
	if node==legs: return node.global_position+Vector2(0,-30.0*ACTOR_VISUAL_SCALE)
	return node.global_position

func visual_connection_delta(upper: Sprite2D, lower: Sprite2D) -> Vector2:
	if upper==null or lower==null or not upper.visible or not lower.visible:
		return Vector2.ZERO
	return waist_point(lower)-waist_point(upper)

func align_visual_connection(upper: Sprite2D, lower: Sprite2D) -> void:
	if upper==null or lower==null or not upper.visible or not lower.visible:
		return
	upper.global_position+=visual_connection_delta(upper,lower)

func update_camera() -> void:
	var size: Vector2 = get_viewport_rect().size
	view_zoom = maxf(size.y / 720.0, maxf(size.x / room.layout.width, size.y / room.layout.height))
	var visible: Vector2 = size / view_zoom
	var player_point: Vector2 = room.player_point()
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
	# 低配机器显示 30FPS 时物理仍按 60Hz 跑；原实现每个 tick 都做整场景呈现。
	# 现在只在每个渲染帧的第一个物理 tick 呈现，其余 tick 只推进规则并累积时间。
	present_seconds=QualityPolicy.accumulated_seconds(present_seconds,seconds)
	ticks_since_present+=1
	var process_frame: int = Engine.get_process_frames()
	var should_present: bool = QualityPolicy.should_present(process_frame,last_present_frame,ticks_since_present)
	if should_present:
		last_present_frame=process_frame
		ticks_since_present=0
		if quality!=null:
			quality.begin_frame(get_process_delta_time())
			combat_effects.vfx_budget=quality.vfx_budget()
		# 相机与瞄准共用同一步变换；跳过的 tick 沿用上次呈现的 view_zoom/origin，
		# 与屏幕实际显示的画布变换一致，不会让角色相对镜头抖动。
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
	if should_present:
		present(state,present_seconds)
		present_seconds=0.0
		queue_redraw()

func present(snapshot: Dictionary,_seconds: float) -> void:
	state=snapshot
	var p: Dictionary = state.player
	var point: Vector2 = Vector2(p.x, p.y)
	var movement: Vector2 = controls.movement()
	var leg_direction: int = direction(movement.angle()) if p.moving else p.facing
	var frame: int = (1 + int(walk_time * 12) % 6) * 4 + leg_direction if p.moving else leg_direction
	var bob: float = sin(walk_time * PI * 24.0 / 7.0) * 0.8 if p.moving else 0.0
	pose(legs, "lower", frame, point + Vector2(0, bob), ACTOR_VISUAL_SCALE)
	var attack: int = {"idle":0,"draw":1,"release":2,"recover":3}[state.attack]
	var upper_key: String = "upper"
	var upper_frame: int = attack*4+p.facing
	if state.hurt>0: upper_key="skills"; upper_frame=12+p.facing
	elif state.dodge>0 or state.get("skillDash",{}).get("remaining",0)>0: upper_key="skills"; upper_frame=8+p.facing
	elif state.skill!=null and state.skill.phase=="windup": upper_key="skills"; upper_frame=(4 if state.skill.kind=="rain" else 0)+p.facing
	elif state.skill!=null: upper_frame=(2 if state.skill.remaining>0.06 else 3)*4+p.facing
	var down_pose: bool = p.facing==1 and upper_key=="upper"
	if down_pose: upper_key="upperDown"; upper_frame=attack
	pose(torso,upper_key,upper_frame,point+Vector2(0,-30*ACTOR_VISUAL_SCALE+bob), ACTOR_VISUAL_SCALE)
	pose(failed, "failed", p.facing, point, ACTOR_VISUAL_SCALE)
	legs.z_index = int(p.y)
	torso.z_index = int(p.y) + 1
	failed.z_index = int(p.y) + 1
	var alpha: float = 0.55 if state.protection > 0 and int(clock * 16) % 2 == 1 else 1.0
	if not is_equal_approx(legs.modulate.a,alpha):
		legs.modulate.a=alpha; torso.modulate.a=alpha
	var alive: bool = state.status!="failed"
	if legs.visible!=alive: legs.visible=alive
	if torso.visible!=alive: torso.visible=alive
	if failed.visible==alive: failed.visible=not alive
	var bow_grip: Vector2 = state.grip
	if p.facing==1 and not down_pose and state.dodge<=0 and state.get("skillDash",{}).get("remaining",0)<=0 and not (state.skill!=null and state.skill.phase=="windup"):
		bow_grip=point+Room.GRIPS[1]
	pose(bow,"bow",1 if state.attack=="draw" or (state.skill!=null and state.skill.phase=="windup") else 2 if state.attack=="release" else 0,bow_grip+Vector2(0,bob),ACTOR_VISUAL_SCALE)
	bow.rotation=-PI/2 if state.skill!=null and state.skill.kind=="rain" and state.skill.phase=="windup" else p.angle
	bow.z_index = int(p.y) + 2
	bow.visible = state.status != "failed" and not down_pose
	nocked_arrow.position = bow_grip + Vector2(0, bob)
	nocked_arrow.rotation = p.angle
	nocked_arrow.z_index = int(p.y) + 3
	nocked_arrow.visible=(state.attack=="draw" or (state.skill!=null and state.skill.kind=="pierce" and state.skill.phase=="windup")) and state.status!="failed" and not down_pose
	frame_actor.update_state(state,movement,room.cooldown,bob)
	frame_actor.modulate.a=alpha
	if frame_actor.body.visible:
		legs.hide(); torso.hide(); bow.hide(); nocked_arrow.hide()
	else:
		if frame_actor.lower.visible: legs.hide()
		if frame_actor.upper.visible: torso.hide(); bow.hide(); nocked_arrow.hide()
	var lower_visual: Sprite2D = frame_actor.lower if frame_actor.lower.visible else legs
	var upper_visual: Sprite2D = frame_actor.upper if frame_actor.upper.visible else torso
	if not frame_actor.body.visible:
		align_visual_connection(upper_visual,lower_visual)
		if upper_visual==frame_actor.upper:
			frame_actor.refresh_head_repair()
	combat_effects.lower=frame_actor.body if frame_actor.body.visible else frame_actor.lower if frame_actor.lower.visible else legs
	combat_effects.upper=frame_actor.upper if frame_actor.upper.visible else torso
	if is_instance_valid(obstacle_body): obstacle_body.modulate.a=0.3 if p.y<room.obstacle.get_center().y and p.y>room.obstacle.get_center().y-126 and absf(p.x-room.obstacle.get_center().x)<100 else 1.0
	if is_instance_valid(backdrop): backdrop.update(state,clock)
	var live_enemies: Dictionary = {}
	for enemy in state.enemies:
		var key: String = {"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance]
		live_enemies[enemy.id]=true
		if not enemy_bodies.has(enemy.id): enemy_bodies[enemy.id]=sprite(key)
		var body: Sprite2D = enemy_bodies[enemy.id]
		var row: int = 6 if enemy.phase=="dead" else 5 if enemy.flash>0 else 3 if enemy.phase=="warn" else 4 if enemy.phase=="swing" else (0 if enemy.timer<0.18 else 5) if enemy.phase=="recover" else 1+int(clock*8)%2
		if enemy.has("role") and enemy.phase=="recover" and enemy.flash<=0:
			row=4 if enemy.role=="paper" and enemy.timer>1.15 else 0
		pose(body,key,row*4+direction(enemy.angle),Vector2(enemy.x,enemy.y),ACTOR_VISUAL_SCALE)
		var depth: int = int(enemy.y)
		if body.z_index!=depth: body.z_index=depth
		var shown: bool = enemy.phase!="inactive" and (enemy.phase!="dead" or enemy.timer>0)
		if body.visible!=shown: body.visible=shown
		var tint: Color = flash_tint if enemy.flash>0 else Color.WHITE
		tint.a=enemy.timer/0.6 if enemy.phase=="dead" else 1.0
		if body.modulate!=tint: body.modulate=tint
	for id in enemy_bodies.keys():
		if not live_enemies.has(id):
			enemy_bodies[id].queue_free(); enemy_bodies.erase(id)
	var live_arrows: Dictionary = {}
	for arrow in state.arrows:
		live_arrows[arrow.id] = true
		if not arrows.has(arrow.id):
			arrows[arrow.id] = arrow_sprite()
		var arrow_body: Sprite2D = arrows[arrow.id]
		var arrow_scale: float = 0.037 if arrow.kind=="pierce" else atlas.upperDown.arrowScale if direction(arrow.angle)==1 else 0.029
		if not is_equal_approx(arrow_body.scale.x,arrow_scale): arrow_body.scale=Vector2.ONE*arrow_scale
		var arrow_tint: Color = pierce_tint if arrow.kind=="pierce" else Color.WHITE
		if arrow_body.modulate!=arrow_tint: arrow_body.modulate=arrow_tint
		arrow_body.position = Vector2(arrow.x, arrow.y)
		arrows[arrow.id].rotation = arrow.angle
		arrows[arrow.id].z_index = int(arrow.y + 52)
	for id in arrows.keys():
		if not live_arrows.has(id):
			arrows[id].queue_free()
			arrows.erase(id)
	combat_effects.update(state,_seconds,clock)
	overlay.update(state,aim,pointer_inside)
	update_hud(state)
	apply_hud_lines()

func mark_presented() -> void:
	# 场景切换/试炼切换等主动呈现后，重置节流计时，避免下一帧重复补偿时间。
	last_present_frame=Engine.get_process_frames()
	ticks_since_present=0
	present_seconds=0.0

func set_text(node: Variant,value: String) -> void:
	# Label.text 变更会触发字形整形；值未变时跳过写入。
	if node.text!=value: node.text=value

func hud_lines() -> Dictionary:
	# 子类只覆写需要的字段；每帧最终只对每个标签赋值一次。
	var guidance: Dictionary = guidance_at(Vector2(state.player.x,state.player.y))
	var remaining: int = 0
	for enemy in state.enemies:
		if enemy.group==state.encounter and enemy.phase!="dead": remaining+=1
	var encounter: String = guidance.region+" · "+guidance.landmark+("\n三庭肃清" if state.status=="complete" else "\n遭遇 %d / %d · 影偶 %d" % [mini(state.encounter+1,state.totalEncounters),state.totalEncounters,remaining])
	var interaction: String = state.feedback.text if state.feedback!=null else ("F · "+state.interaction.label+(" · "+state.interaction.reason if state.interaction.reason!=null else "")) if state.interaction!=null else "残碑藏于北侧林径 · 祭火位于南侧支路"
	return {"encounter":encounter,"interaction":interaction,"status":"已暂停\nEsc 继续" if state.paused else "影散于汤谷\nR 从起点重试","statusVisible":(state.paused and not state.reading) or state.status=="failed"}

func apply_hud_lines() -> void:
	var lines: Dictionary = hud_lines()
	set_text(encounter_label,lines.encounter)
	set_text(interaction_label,lines.interaction)
	set_text(status_label,lines.status)
	status_label.visible=bool(lines.statusVisible)
	reading_panel.visible=state.reading
	set_text(fullscreen,"退出全屏" if get_window().mode==Window.MODE_FULLSCREEN else "全屏")

func update_hud(snapshot: Dictionary) -> void:
	health_label.text="生命  %d / 100" % snapshot.health
	skills_label.text="Q 穿透箭 %s  ·  E 箭雨 %s  ·  空格 闪避 %s" % [cooldown_text(snapshot.cooldowns.pierce),cooldown_text(snapshot.cooldowns.rain),cooldown_text(snapshot.cooldowns.dodge)]

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
		draw_circle(Vector2.ZERO, 18 * ACTOR_VISUAL_SCALE, Color(0.02, 0.03, 0.02, 0.4 * alpha))
		draw_set_transform(Vector2.ZERO)
	for enemy in state.enemies:
		if enemy.phase=="inactive" or enemy.phase=="dead": continue
		if enemy.phase=="warn" or enemy.phase=="swing":
			if enemy.get("role","")=="paper":
				var origin: Vector2 = Vector2(enemy.x,enemy.y)
				draw_line(origin,origin+Vector2.from_angle(enemy.angle)*300,Color(0.56,0.82,0.9,0.65),2)
				continue
			var radius: float = 90.0 if enemy.get("role","")=="wood" else 70.0
			var sector: PackedVector2Array = [Vector2(enemy.x,enemy.y)]
			for index in 17: sector.append(Vector2(enemy.x,enemy.y)+Vector2.from_angle(enemy.angle-PI/4+index*PI/32)*radius)
			var tint: Color = Color("d9a14d") if enemy.get("role","")=="wood" else Color(0.74,0.2,0.12)
			tint.a=0.48 if enemy.phase=="swing" else 0.16
			draw_colored_polygon(sector,tint)

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
	var alpha_entry: Button = Button.new()
	alpha_entry.name="OpenAlpha"; alpha_entry.text="初版白盒"; alpha_entry.focus_mode=Control.FOCUS_NONE
	alpha_entry.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/tanggu_alpha.tscn"))
	top.add_child(alpha_entry)
	var map_entry: Button = Button.new()
	map_entry.name="OpenFirstLevelMap"; map_entry.text="首关地图"; map_entry.focus_mode=Control.FOCUS_NONE
	map_entry.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/tanggu_first_level.tscn"))
	top.add_child(map_entry)
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
