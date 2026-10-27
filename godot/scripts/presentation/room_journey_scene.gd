extends "res://scripts/presentation/first_level_scene.gd"

const Journey = preload("res://scripts/journey/room_journey.gd")
const PlayOptions = preload("res://scripts/input/play_options.gd")
@export var potion_drop_seed: int = -1 # 非负值仅用于固定种子重演夹具。
var journey: RefCounted
var minimap: Control
var boss_view: Node2D
var boss_bar: ProgressBar
var loot_view: Node2D
var camp_panel: CanvasLayer
var world_items: Node2D
var pickup_label: Label
var skill_view: Node2D
var item_label: Label
var journey_data: Dictionary = {}
var pause_menu: ColorRect
var resume_button: Button
var returning_home: bool = false

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
	pickup_label=Label.new(); pickup_label.name="PickupCard"
	pickup_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pickup_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pickup_label.offset_left=-450; pickup_label.offset_right=-24; pickup_label.offset_top=-185; pickup_label.offset_bottom=-90
	pickup_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(pickup_label)
	item_label=Label.new(); item_label.name="ItemPrototypeStatus"; item_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	item_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	item_label.offset_left=-450; item_label.offset_right=-24; item_label.offset_top=-255; item_label.offset_bottom=-190
	item_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hud.add_child(item_label)
	var pause_layer: CanvasLayer = CanvasLayer.new(); pause_layer.layer=30; add_child(pause_layer)
	pause_menu=ColorRect.new(); pause_menu.name="PauseMenu"; pause_menu.color=Color("080d09ed")
	pause_menu.theme=hud.theme; pause_layer.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); pause_menu.hide()
	var center: CenterContainer = CenterContainer.new(); pause_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu: VBoxContainer = VBoxContainer.new(); menu.add_theme_constant_override("separation",16); center.add_child(menu)
	menu.add_child(make_label("已暂停",26))
	menu.add_child(make_label("返回首页将结束本次测试，不保留进度。",16))
	resume_button=Button.new(); resume_button.text="继续测试 · Esc"; menu.add_child(resume_button)
	resume_button.custom_minimum_size.y=48; resume_button.pressed.connect(resume_test)
	var back: Button = Button.new(); back.text="返回首页"; menu.add_child(back)
	back.custom_minimum_size.y=48; back.pressed.connect(return_home)
	resume_button.focus_next=resume_button.get_path_to(back); resume_button.focus_previous=resume_button.get_path_to(back)
	back.focus_next=back.get_path_to(resume_button); back.focus_previous=back.get_path_to(resume_button)

func resume_test() -> void:
	controls.interrupt(); room.set_paused(false)
	present(room.snapshot(),0)

func return_home() -> void:
	if returning_home or not room.paused: return
	returning_home=true; controls.interrupt()
	get_viewport().set_input_as_handled()
	enter_home.call_deferred()

func enter_home() -> void:
	var error: Error = get_tree().change_scene_to_file("res://scenes/home.tscn")
	if error!=OK:
		returning_home=false; push_error("首页加载失败："+str(error))

func layout_boss_bar() -> void:
	boss_bar.offset_top=hud.encounter.position.y+60
	boss_bar.offset_bottom=boss_bar.offset_top+12

func _ready() -> void:
	var arguments: Array = Array(OS.get_cmdline_user_args())
	# 首页选择只消费一次；命令行启动继续使用原参数。
	if get_tree().has_meta("home_test_arguments"):
		arguments=get_tree().get_meta("home_test_arguments")
		get_tree().remove_meta("home_test_arguments")
	var options: Dictionary = PlayOptions.parse(arguments)
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
	boss_view.standalone_environment=false
	boss_view.z_index=1; add_child(boss_view)
	loot_view=load("res://scripts/presentation/loot_view.gd").new(); add_child(loot_view)
	world_items=load("res://scripts/gameplay/world_items.gd").new(); add_child(world_items)
	skill_view=load("res://scripts/presentation/loadout_skill_view.gd").new(); skill_view.z_index=4095; add_child(skill_view)
	super._ready()
	camp_panel=load("res://scripts/gameplay/camp_panel.gd").new(); add_child(camp_panel); camp_panel.setup(room,controls)

	if options.startRoom=="boss" and DisplayServer.get_name()!="headless": get_window().mode=Window.MODE_FULLSCREEN
	overview_button.text="房间总览 · M"

func toggle_overview() -> void:
	super.toggle_overview()
	overview_button.text=("固定战斗视角 · M" if journey.current_id=="boss" else "跟随角色 · M") if overview else "房间总览 · M"

func update_camera() -> void:
	if journey!=null and journey.current_id=="boss":
		fit_boss_room(); return
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
	register_player_grips()
	controls=Controls.new(room)
	if camp_panel!=null: camp_panel.room=room; camp_panel.controls=controls; camp_panel.signature=""
	for body in enemy_bodies.values(): body.queue_free()
	enemy_bodies.clear()
	pose_cache.clear()
	for body in arrows.values(): body.queue_free()
	arrows.clear()
	for enemy in room.snapshot().enemies:
		enemy_bodies[enemy.id]=sprite({"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance])
	backdrop.setup(room.layout,atlas,textures)
	overview=false; overview_button.text="房间总览 · M"
	walk_time=0; clock=0
	frame_actor.reset_pose()
	update_camera(); present(room.snapshot(),0); mark_presented()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode==KEY_I and event.pressed and not event.echo:
		controls.interrupt(); room.update({"alpha":{"action":"camp"}},0)
		get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.physical_keycode==KEY_R and event.pressed and not event.echo:
		if not room.snapshot().paused:
			journey.restart(); present_new_room()
		get_viewport().set_input_as_handled(); return
	super._unhandled_input(event)

func guidance_at(_position: Vector2) -> Dictionary:
	return {"region":room.layout.roomTitle,"landmark":{"safe":"安全房 · 可探索与通行","combat":"清除所有影偶后开门","explore":"阅读并合上残碑后开门","boss":"击败索尔后开门 · 锤离手时反击"}[room.layout.objective]}

func present(snapshot: Dictionary,seconds: float) -> void:
	# 复用本帧公开快照，避免第二次深拷贝；HUD 文本统一在 hud_lines() 写入一次。
	journey_data=journey.snapshot(snapshot)
	super.present(snapshot,seconds)
	var data: Dictionary = journey_data
	var show_pause: bool = room.paused and not data.reading
	if pause_menu.visible!=show_pause:
		pause_menu.visible=show_pause
		if show_pause: resume_button.grab_focus()
		else:
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused!=null and pause_menu.is_ancestor_of(focused): focused.release_focus()
	loot_view.update_state(data,seconds)
	world_items.update(data)
	skill_view.update(data)
	item_label.visible=not data.alpha.camp and not data.reading
	var quick: Dictionary = data.alpha.quickItem
	var runtime: Dictionary = data.itemEffects
	item_label.text="V：%s · 快马%.1f秒 · 司晨%d/3" % [(quick.name+" #"+str(quick.id)) if not quick.is_empty() else "未绑定实物",runtime.haste,runtime.morningUses]
	if data.alpha.prototypeBurn: item_label.text+="\n原型B：只测试烧物／焚书；容器战斗效果未开放"

	var card: Dictionary = data.alpha.pickupCard
	pickup_label.visible=not data.alpha.camp and not data.reading
	pickup_label.text=("%s · %.1f秒\n%s" % [card.name,card.remaining,card.reason]+("\nTab 尝试转坛" if not card.attempted else "")) if not card.is_empty() else "I 营地整理（完成房间并靠近整理点）\n"+data.alpha.message
	if data.alpha.camp and not room.paused: status_label.visible=false

	minimap.update_state(data.roomGraph)
	boss_view.visible=data.has("boss")
	boss_bar.visible=data.has("boss")
	if data.has("boss"):
		boss_view.update(data,clock); boss_bar.value=data.boss.health

func hud_lines() -> Dictionary:
	var lines: Dictionary = super.hud_lines()
	var data: Dictionary = journey_data
	if data.is_empty(): return lines
	var encounter: String = room.layout.roomTitle+" · 已探索 %d / %d 房间" % [data.visitedRooms,Journey.ROOM_IDS.size()]+"\n"+("房间已完成 · 所有门已开放" if data.roomComplete else guidance_at(Vector2.ZERO).landmark)
	if data.has("boss"):
		encounter="索尔  %d / 1200\n%s" % [data.boss.health,"索尔已败退 · 前往出口完成首关" if data.roomComplete else "锤已离手 · 承伤提高25%" if data.vulnerable else "观察招式 · 击败后开门"]
		if not data.roomComplete:
			encounter+=" · 影偶 %d / 8" % data.enemies.filter(func(enemy: Dictionary): return enemy.health>0).size()
	if data.objective=="combat" and not data.roomComplete:
		var remaining: int = 0
		for enemy in data.enemies:
			if enemy.group==data.encounter and enemy.phase!="dead": remaining+=1
		encounter=room.layout.roomTitle+" · 第 %d / %d 波" % [data.wave,data.waveCount]+"\n"+("下一波 %.1f 秒后出现" % data.waveDelay if data.waveDelay>0 else "影偶剩余 %d · 清完全部波次后开门" % remaining)
	if data.journeyComplete: encounter="汤谷流程完成 · 可返回探索\nR 重开整段流程"
	if not data.get("rewardPlaceholders",[]).is_empty(): encounter+="\nBoss战利品为未入库占位 · 阶段奖励后续接通"
	lines.encounter=encounter
	if state.feedback==null and state.interaction==null:
		lines.interaction="走近门按 F 前往下一房间" if data.roomComplete else "完成本房任务后，来路与出口一起开放"
		if data.objective in ["combat","boss"]: lines.interaction="血／蓝瓶落地后走近按 F 即时补充 · 满值留地"
	return lines
