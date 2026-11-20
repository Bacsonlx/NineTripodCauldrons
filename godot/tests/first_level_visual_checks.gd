extends SceneTree

const Room = preload("res://scripts/combat/training_room.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/boot.tscn","启动工程经首页路由，首关地图仍可独立加载")
	var map: Node2D = load("res://scenes/tanggu_first_level_map.tscn").instantiate()
	root.add_child(map)
	check(not map.has_node("ArtPlate") and not map.has_node("Foreground"),"运行地图不包含完整原图底板或原图遮挡裁片")
	var assets: int = 0
	var native: bool = true
	var independent: bool = true
	for item in map.get_children():
		if not item.has_method("update_state"): continue
		assets+=1
		var sprite: Sprite2D = item.get_node("Sprite")
		native=native and sprite.scale.x<=1.0 and sprite.scale.y<=1.0
		independent=independent and item.scene_file_path=="res://scenes/world/environment_prop.tscn" and sprite.texture!=null
	check(assets>100 and independent,"建筑和环境由可独立编辑的场景实例组成")
	check(native,"设计视口下所有环境素材均不放大超过原生像素")
	check(map.get_node("Ground/第一庭院").texture_repeat==CanvasItem.TEXTURE_REPEAT_ENABLED,"地面使用原生材质平铺")
	var floor_before: PackedVector2Array = map.get_node("Walkable/第一庭院").polygon.duplicate()
	var wall: Node2D = map.get_node("World_Boundary1")
	var original_position: Vector2 = wall.position
	wall.position=Vector2(1134,2232)
	var before: Vector2 = wall.position
	check(not Room.new(map.build_layout()).can_walk(before),"独立石墙确实阻挡移动")
	wall.position+=Vector2(120,0)
	var changed: TrainingRoom = Room.new(map.build_layout())
	check(changed.can_walk(before) and not changed.can_walk(wall.position),"移动建筑同步移动实际碰撞，旧位置可通行")
	check(map.get_node("Walkable/第一庭院").polygon==floor_before,"移动建筑不修改地面或其他场景构图")
	wall.position=before
	var original_size: Vector2 = wall.size
	wall.size=Vector2(120,60)
	check(wall.get_node("Sprite").position==wall.art_offset+Vector2(0,30),"修改建筑占地后画面脚点立即同步")
	wall.category="ground"
	check(wall.get_node("Sprite").position==wall.art_offset,"修改实体类别立即刷新脚点")
	wall.category="obstacle"; wall.size=original_size
	wall.position=original_position
	var stele: Node2D = map.get_node("Stele")
	var origin: Vector2 = stele.position
	stele.position+=Vector2(60,0)
	var moved_stele: Dictionary = {}
	for obstacle in map.build_layout().obstacles:
		if obstacle.kind=="stele": moved_stele=obstacle
	check(moved_stele.x==stele.position.x,"残碑独立素材与实体使用同一节点位置")
	var interaction: Dictionary = {}
	for entry in map.build_layout().exploration:
		if entry.id=="stele": interaction=entry
	check(interaction.x==stele.position.x+33 and interaction.y==stele.position.y+81,"移动残碑同步移动其可站立互动点")
	stele.position=origin
	var solids: TrainingRoom = Room.new(map.build_layout())
	check(not solids.can_walk(map.get_node("World_FirePillar0").position),"火柱有真实脚点碰撞")
	var gateway: Node2D = map.get_node("World_Gateway1")
	var left_post: Vector2 = gateway.position+gateway.get_node("LeftPost").position
	check(not solids.can_walk(left_post) and solids.can_walk(gateway.position+Vector2(0,-15)),"门楼柱脚阻挡，中央过道保持可走")
	gateway.position+=Vector2(120,0)
	check(not Room.new(map.build_layout()).can_walk(left_post+Vector2(120,0)),"移动门楼同步移动柱脚碰撞")
	map.free()
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game)
	check(game.find_child("OpenFirstLevelMap",true,false)==null and game.find_child("OpenAlpha",true,false)==null,"默认地图界面没有实验地图或旧地图切换入口")
	game.controls.key_down(KEY_D); game.controls.pointer_down(true)
	game.toggle_overview()
	check(game.overview and is_equal_approx(game.view_zoom,minf(game.get_viewport_rect().size.x/1440,game.get_viewport_rect().size.y/1040)),"总览镜头容纳当前独立房间")
	check(game.controls.movement()==Vector2.ZERO and not game.controls.fire,"切换视角清除移动和射击意图")
	game.toggle_overview()
	check(not game.overview and game.view_zoom>=1.0,"可从全图回到角色跟随")
	load("res://tests/player_art_checks.gd").new().run(game,Callable(self,"check"))
	load("res://tests/run_detail_probe.gd").new().run(game,Callable(self,"check"))
	load("res://tests/waist_alignment_checks.gd").new().run(game,Callable(self,"check"))
	game.free()
	print(JSON.stringify({"first_level_visual_checks":checks,"environment_instances":assets,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
