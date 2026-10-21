extends SceneTree

var failures: Array[String] = []
var checks: int = 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var map: Node2D = load("res://scenes/tanggu_first_level_map.tscn").instantiate()
	root.add_child(map)
	var layout: Dictionary = map.build_layout()
	var room: TrainingRoom = TrainingRoom.new(layout)
	# 圆庭的中央战斗椭圆必须可自由穿行，不仅检查中心一个点。
	for court in [Vector3(1134,2232,330),Vector3(2607,1878,305),Vector3(3675,1545,375),Vector3(2400,438,420)]:
		var clear: bool = true
		for x in range(-3,4):
			for y in range(-3,4):
				if x*x+y*y>9: continue
				clear=clear and room.can_walk(Vector2(court.x+x*court.z/3,court.y+y*court.z/5))
		check(clear,"圆庭中央区域净空："+str(court))
	var spawn: Vector2 = TrainingRoom.point(layout.spawn)
	check(room.clear_path(spawn,spawn+Vector2(60,-90)),"从门前出生后能直接向前走出入口")
	check(map.get_node("World_Gateway1").get("mirror_art")==true,"入口门朝向与道路一致")
	check(map.get_node("Ground").has_method("blend_edges"),"地表采用连续过渡，不能回到硬切多边形")
	var surface: Node2D = map.get_node("Ground")
	var only_external: bool = surface.edges.size()>0
	for edge in surface.edges:
		var mid: Vector2 = (edge[0]+edge[1])/2
		only_external=only_external and not surface.inside(mid+edge[2]*2,surface.roads) and surface.inside(mid-edge[2]*2,surface.roads)
	check(only_external,"渐变只沿路网外边界生成，路口不露林地裂缝")
	var portal: Vector2 = map.get_node("World_Gateway1").position+Vector2(0,-34)
	check((spawn-portal).dot(Vector2(52,-144))>0 and spawn.distance_to(portal)<95,"出生点位于调整朝向后的门洞正前方")
	var wall: Node2D = map.get_node("World_Seal1_0")
	var contact: Node2D = wall.get_node("GroundContact")
	check(contact.get_child_count()==2 and not contact.z_as_relative and contact.z_index==-15,"墙基苔土和接触阴影位于独立地表层")
	var patch: Polygon2D = contact.get_child(0)
	var center: Vector2 = patch.to_global(patch.polygon[32])
	wall.position+=Vector2(90,30)
	check(patch.to_global(patch.polygon[32])==center+Vector2(90,30),"编辑器移动墙体时接地层同步移动")
	wall.position-=Vector2(90,30)
	check(patch.texture!=null and patch.vertex_colors[0].a==0 and patch.vertex_colors[32].a>0,"接地使用真实土壤材质，外缘透明渐隐")
	check(wall.texture_asset.get_height()>wall.texture_asset.get_width()*3 and not map.has_node("World_Seal1_1"),"纵向封路采用完整纵向残墙，不再堆叠平行短墙")
	var state: Dictionary = room.snapshot()
	state.encounter=1
	wall.update_state(state,0)
	check(not contact.is_visible_in_tree(),"阶段开通后墙基和阴影随墙体一起移除")
	state.encounter=0; wall.update_state(state,0)
	var no_court_patch: bool = true
	for item in map.get_children():
		if item.has_method("update_state") and item.flat:
			no_court_patch=no_court_patch and item.get_node("GroundContact").get_child_count()==0
	check(no_court_patch,"圆盘地面不添加中央苔土或阴影覆盖")
	check(map.build_layout()==layout,"接地与色调调整不改变任何规则布局数据")
	map.free()
	print(JSON.stringify({"map_revision_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
