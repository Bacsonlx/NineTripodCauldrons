extends "res://scripts/presentation/first_level_scene.gd"

const Journey = preload("res://scripts/journey/room_journey.gd")
const PlayOptions = preload("res://scripts/input/play_options.gd")
@export var potion_drop_seed: int = -1 # 非负值仅用于固定种子重演夹具。
var journey: RefCounted
var minimap: Control
var boss_view: Node2D
var boss_bar: ProgressBar
var loot_view: Node2D

func build_hud() -> void:
	super.build_hud()
	minimap=load("res://scripts/presentation/room_minimap.gd").new()
	hud.add_child(minimap)
	hud.move_child(minimap,hud.reading.get_index())
	boss_bar=ProgressBar.new(); boss_bar.name="JourneyBossHealth"
	boss_bar.max_value=preload("res://scripts/combat/boss_room.gd").MAX_HEALTH
	boss_bar.show_percentage=false; boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_bar.offset_left=-160; boss_bar.offset_right=160
	hud.add_child(boss_bar)
	hud.resized.connect(layout_boss_bar)
	layout_boss_bar()

func layout_boss_bar() -> void:
	boss_bar.offset_top=hud.encounter.position.y+60
	boss_bar.offset_bottom=boss_bar.offset_top+12

func _ready() -> void:
	var options: Dictionary = PlayOptions.parse(Array(OS.get_cmdline_user_args()))
	if options.has("error"):
		push_error(options.error); get_tree().quit(2); return
	if options.mode=="alpha":
		get_tree().change_scene_to_file.bind("res://scenes/tanggu_alpha.tscn").call_deferred()
		return
	var maps: Dictionary = Journey.read_maps()
	if maps.is_empty(): get_tree().quit(1); return
	if potion_drop_seed>=0 and not options.has("dropSeed"): options.dropSeed=potion_drop_seed
	journey=Journey.new(maps,options)
	mount_map()
	boss_view=load("res://scripts/presentation/boss_art_view.gd").new()
	boss_view.z_index=1; add_child(boss_view)
	loot_view=load("res://scripts/presentation/loot_view.gd").new(); add_child(loot_view)
	super._ready()
	overview_button.text="房间总览 · M"

func toggle_overview() -> void:
	super.toggle_overview()
	overview_button.text="跟随角色 · M" if overview else "房间总览 · M"

func update_camera() -> void:
	if journey!=null and journey.current_id=="boss":
		fit_room(200); return
	super.update_camera()

func mount_map() -> void:
	var previous: Node = get_node_or_null("TangguMap")
	if previous!=null:
		remove_child(previous); previous.queue_free()
	var map: Node2D = load("res://scenes/rooms/%s.tscn" % journey.current_id).instantiate()
	map.name="TangguMap"; add_child(map)

func create_room(_layout: Dictionary) -> TrainingRoom:
	return journey.active

func _physics_process(seconds: float) -> void:
	super._physics_process(seconds)
	if journey!=null and journey.consume_transition(): present_new_room()

func present_new_room() -> void:
	controls.interrupt()
	mount_map()
	room=journey.active
	room.layout.grips=room.layout.grips.duplicate()
	room.layout.grips[1]=atlas.upperDown.grip.duplicate()
	controls=Controls.new(room)
	for body in enemy_bodies.values(): body.queue_free()
	enemy_bodies.clear()
	for body in arrows.values(): body.queue_free()
	arrows.clear()
	for enemy in room.snapshot().enemies:
		enemy_bodies[enemy.id]=sprite({"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance])
	backdrop.setup(room.layout,atlas,textures)
	overview=false; overview_button.text="房间总览 · M"
	walk_time=0; clock=0
	update_camera(); present(room.snapshot(),0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode==KEY_R and event.pressed and not event.echo:
		if not room.snapshot().paused:
			journey.restart(); present_new_room()
		get_viewport().set_input_as_handled(); return
	super._unhandled_input(event)

func guidance_at(_position: Vector2) -> Dictionary:
	return {"region":room.layout.roomTitle,"landmark":{"safe":"安全房 · 可探索与通行","combat":"清除所有影偶后开门","explore":"阅读并合上残碑后开门","boss":"击败索尔后开门 · 锤离手时反击"}[room.layout.objective]}

func present(snapshot: Dictionary,seconds: float) -> void:
	super.present(snapshot,seconds)
	var data: Dictionary = journey.snapshot()
	loot_view.update_state(data,seconds)
	minimap.update_state(data.roomGraph)
	boss_view.visible=data.has("boss")
	boss_bar.visible=data.has("boss")
	if data.has("boss"):
		boss_view.update(data,clock); boss_bar.value=data.boss.health
	encounter_label.text=room.layout.roomTitle+" · 已探索 %d / %d 房间" % [data.visitedRooms,Journey.ROOM_IDS.size()]+"\n"+("房间已完成 · 所有门已开放" if data.roomComplete else guidance_at(Vector2.ZERO).landmark)
	if data.has("boss"):
		encounter_label.text="索尔  %d / 1200\n%s" % [data.boss.health,"索尔已败退 · 前往出口完成首关" if data.roomComplete else "锤已离手 · 承伤提高25%" if data.vulnerable else "观察招式 · 击败后开门"]
	if data.objective=="combat" and not data.roomComplete:
		var remaining: int = data.enemies.filter(func(enemy: Dictionary): return enemy.group==data.encounter and enemy.phase!="dead").size()
		encounter_label.text=room.layout.roomTitle+" · 第 %d / %d 波" % [data.wave,data.waveCount]+"\n"+("下一波 %.1f 秒后出现" % data.waveDelay if data.waveDelay>0 else "影偶剩余 %d · 清完全部波次后开门" % remaining)
	if data.journeyComplete: encounter_label.text="汤谷流程完成 · 可返回探索\nR 重开整段流程"
	if not data.get("rewardPlaceholders",[]).is_empty(): encounter_label.text+="\n装备／道具为未入库占位 · 背包后续接入"
	if state.feedback==null and state.interaction==null:
		interaction_label.text="走近门按 F 前往下一房间" if data.roomComplete else "完成本房任务后，来路与出口一起开放"
		if data.objective=="combat": interaction_label.text="血／蓝瓶落地后走近按 F 即时补充 · 满值留地"
