extends SceneTree

const Profile = preload("res://scripts/hub/profile.gd")
var failures: Array[String] = []
var checks: int = 0
var path: String

func _initialize() -> void:
	create_timer(25).timeout.connect(func(): push_error("安全屋流程检查超时"); quit(1))
	run.call_deferred()

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: Key, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event)

func run() -> void:
	check(int(ProjectSettings.get_setting("display/window/size/mode"))==Window.MODE_MAXIMIZED,"正式启动默认使用最大化窗口")
	path="/private/tmp/jiuding-safehouse-flow-%d.save" % Time.get_ticks_usec()
	OS.set_environment("JIUDING_PROFILE_PATH",path)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await scene_changed
	var hub: Node = current_scene
	check(hub.scene_file_path=="res://scenes/safehouse.tscn","无参数启动进入可行走安全屋")
	if not hub.has_method("nearest_service"): finish(); return
	check(hub.frame_actor.DIRECTORY=="res://assets/characters/child-shadow-v3/","安全屋与战斗共享新版皮影资源")
	for direction in 4:
		hub.facing=direction; hub.walk_distance=36.0; hub.pose_child(true)
		check(hub.upper.clip=="shadow-run-unarmed-upper" and hub.legs.clip=="shadow-run-lower","四向非战斗动作使用新版统一身体")
	await check_layout(hub)
	check(hub.nearest_service().is_empty(),"出生处无需打开任何面板")
	var spawn: Vector2 = hub.child.position
	key(KEY_W)
	for frame in 12: await physics_frame
	key(KEY_W,false)
	check(hub.child.position.y<spawn.y-20,"WASD 真实输入推动孩子行走")
	key(KEY_B)
	check(hub.bag.backpack_open and hub.preparation_room.alpha.items.size()==6,"安全屋背包显示免费六件方案")
	var bow: Dictionary = hub.preparation_room.alpha.find_item_by_name("训练弓")
	var glyph: Dictionary = hub.preparation_room.alpha.find_item_by_name("羊角")
	hub.bag.send({"action":"embed","equipmentId":bow.id,"glyphId":glyph.id})
	check(hub.preparation_room.alpha.find_item_by_name("训练弓").glyphs.size()==1,"准备中可嵌入已有实物符")
	hub.bag.undo_glyphs()
	check(hub.preparation_room.alpha.find_item_by_name("训练弓").glyphs.is_empty() and not hub.preparation_room.alpha.find_item_by_name("羊角").is_empty(),"撤销准备中的嵌符返还原实物")
	key(KEY_ESCAPE)
	check(not hub.bag.backpack_open,"Esc 关闭背包并回到原地")
	for station in ["Smith","Merchant","Keeper"]:
		hub.child.position=hub.people.get_node(station).position+Vector2(0,52)
		key(KEY_F); key(KEY_F,false)
		check(hub.service==station,"走近按 F 开启服务："+station)
		if station!="Keeper": key(KEY_ESCAPE)
	hub.open_service("confirm")
	root.mode=Window.MODE_WINDOWED
	var departure_mode: Window.Mode = root.mode
	hub.depart()
	await scene_changed
	var game: Node = current_scene
	check(game.scene_file_path=="res://scenes/tanggu_first_level.tscn" and game.hub_profile!=null,"确认后进入正式汤谷与磁盘征程")
	check(root.mode==departure_mode,"从安全屋进入汤谷时保留当前窗口模式")
	var identity: int = game.hub_profile.data.active.id
	var generation: int = game.journey.generation
	key(KEY_R)
	check(game.journey.generation==generation,"正式征程禁用 R 重建")
	change_scene_to_file("res://scenes/safehouse.tscn")
	await scene_changed
	await scene_changed
	game=current_scene
	check(game.hub_profile.data.active.id==identity and game.journey.current_id=="entry","重启顺序继续同一局起点，跳过局外准备")
	game.set_physics_process(false)
	game.room.health=0
	game.room.status="failed"
	game.update_saved_journey()
	await scene_changed
	var settlement: Node = current_scene
	check(settlement.profile.data.settlement.result=="death","阵亡自动打开可恢复结算")
	change_scene_to_file("res://scenes/safehouse.tscn")
	await scene_changed
	await scene_changed
	settlement=current_scene
	check(settlement.profile.data.settlement.run==identity,"重启优先恢复待完成结算")
	settlement.finish()
	await scene_changed
	check(current_scene.scene_file_path=="res://scenes/safehouse.tscn","确认结算回到安全屋")
	check(root.mode==departure_mode,"结算回安全屋时保留当前窗口模式")
	var saved: RefCounted = Profile.new(path)
	check(saved.data.incense==1 and saved.data.active.is_empty() and saved.data.settlement.is_empty(),"回屋只增加一次香火并清除局内记录")
	current_scene.queue_free()
	await process_frame
	finish()

func check_layout(hub: Node) -> void:
	var title: Label
	for node in hub.interface.find_children("*","Label",true,false):
		if node.text=="祠庙前院": title=node; break
	if title==null:
		check(false,"安全屋有可见的地点标题")
		return
	var window_size: Vector2i = root.size
	var courtyard: Sprite2D = hub.get_node("Courtyard")
	hub.open_service("Merchant")
	var card: PanelContainer = hub.modal.find_children("*","PanelContainer",true,false)[0]
	for target in [Vector2i(1280,720),Vector2i(800,450),Vector2i(2560,1080),Vector2i(900,800)]:
		root.size=target
		await process_frame
		await process_frame
		var viewport: Rect2 = root.get_visible_rect()
		var projected: Rect2 = courtyard.get_global_transform_with_canvas()*courtyard.get_rect()
		check(projected.grow(1).encloses(viewport),"%s：安全屋底图铺满视口（%s）" % [target,projected])
		var spawn: Vector2 = hub.child.get_global_transform_with_canvas().origin
		check(viewport.has_point(spawn),"%s：铺满视口时仍看得到孩子的出生点" % target)
		for label in [title,hub.summary,hub.hint]:
			check(label.get_line_count()==1 and viewport.encloses(label.get_global_rect()),
				"%s：%s 横排且在窗口内（%d 行，%s）" % [target,label.text,label.get_line_count(),label.get_global_rect()])
		check(viewport.encloses(card.get_global_rect()),"%s：商店弹窗在窗口内（%s）" % [target,card.get_global_rect()])
	hub.close_modal()
	root.size=window_size

func finish() -> void:
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print(JSON.stringify({"safehouse_flow_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
