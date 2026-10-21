extends SceneTree

const Room = preload("res://scripts/combat/training_room.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	var map: Node2D = load("res://scenes/tanggu_first_level_map.tscn").instantiate()
	var errors: Array[String] = map.validation_errors()
	check(errors.is_empty(),"首关原生节点合法："+str(errors))
	if not errors.is_empty(): map.free(); finish(); return
	var layout: Dictionary = map.get_layout()
	var room: TrainingRoom = Room.new(layout)
	check(room.snapshot().enemies.size()==12,"三组保留3/4/5个敌人出生")
	check(not room.find_route(Room.point(layout.spawn),Vector2(2607,1878)).size(),"第一遭遇未清时不能绕行到第二庭院")
	check(room.find_route(Room.point(layout.spawn),Vector2(1134,2232)).size()>0,"起点可到第一战斗区")
	check(not room.can_walk(Vector2(2100,1230)) and not room.can_walk(Vector2(240,1500)),"中央根系和汤水边界不可行走")
	for cleared in [1,2]:
		var staged_layout: Dictionary = layout.duplicate(true)
		staged_layout.encounters=[]
		staged_layout.obstacles=staged_layout.obstacles.filter(func(item: Dictionary): return not item.has("opensAfterEncounter") or item.opensAfterEncounter>=cleared)
		var staged: TrainingRoom = Room.new(staged_layout)
		check(staged.find_route(Room.point(layout.spawn),Vector2(2607,1878) if cleared==1 else Vector2(3600,1506)).size()>0,"清场阶段 %d 可达下一庭院" % cleared)
		check(staged.find_route(Room.point(layout.spawn),Vector2(3600,1506) if cleared==1 else Vector2(2400,438)).is_empty(),"清场阶段 %d 仍阻止跳过下一遭遇" % cleared)
	# 合法配置保留实际几何，剔除遭遇，仅验证清场后的开放世界可达性。
	var cleared_layout: Dictionary = layout.duplicate(true)
	cleared_layout.encounters=[]
	cleared_layout.obstacles=cleared_layout.obstacles.filter(func(item: Dictionary): return not item.has("opensAfterEncounter"))
	var walker: TrainingRoom = Room.new(cleared_layout)
	for target in [Vector2(1953,2097),Vector2(1065,1170),Vector2(2607,1878),Vector2(3090,1227),Vector2(3600,1506),Vector2(4014,2298),Vector2(4140,498),Vector2(2400,438),Vector2(1374,435)]:
		var route: Array = walker.find_route(Room.point(layout.spawn),target)
		var previous: Vector2 = Room.point(layout.spawn)
		var continuous: bool = not route.is_empty()
		for point in route:
			continuous=continuous and walker.clear_path(previous,point); previous=point
		check(continuous,"清场后存在连续可行走路径到地图节点 "+str(target))
	var gate: Vector2 = Vector2(1761,2304)
	check(not walker.can_walk(gate),"回程门初始阻挡")
	var gate_layout: Dictionary = cleared_layout.duplicate(true)
	gate_layout.spawn={"x":1761,"y":2379}
	var opener: TrainingRoom = Room.new(gate_layout)
	opener.update({"interact":true},0.29)
	check(opener.snapshot().exploration.gateOpen and opener.can_walk(gate),"从南侧合法F互动后门碰撞解除")
	gate_layout.spawn={"x":1761,"y":2249}
	var outside: TrainingRoom = Room.new(gate_layout)
	outside.update({"interact":true},0.29)
	check(not outside.snapshot().exploration.gateOpen and outside.snapshot().interaction!=null and outside.snapshot().interaction.reason=="需从祭坛支路内侧开启","外侧F不能提前打开回程门且显示原因")
	# 用真实攻击推进遭遇，验证出口与复位，不直接写血量或清场状态。
	var fight_layout: Dictionary = layout.duplicate(true)
	fight_layout.spawn={"x":1134,"y":2232}
	fight_layout.encounters=[{"x":1134,"y":2232,"enemies":[{"x":1294,"y":2232,"appearance":"bird"}]}]
	var fighter: TrainingRoom = Room.new(fight_layout)
	check(not fighter.can_walk(Vector2(1644,1980)),"第一庭院出口初始实体阻挡")
	fighter.update({"aim":Vector2(1294,2181),"fire":true},1.3)
	check(fighter.snapshot().encounter==1 and fighter.can_walk(Vector2(1644,1980)),"真实击败当前敌人后解开对应出口")
	fighter.reset()
	check(not fighter.can_walk(Vector2(1644,1980)),"重试恢复出口与遭遇初态")
	var saved: PackedScene = PackedScene.new()
	saved.pack(map)
	var save_path: String = "user://first-level-layout-check.tscn"
	check(ResourceSaver.save(saved,save_path)==OK,"地图可保存")
	var reopened: Node2D = ResourceLoader.load(save_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	check(reopened.get_layout()==layout,"保存重开后道路、出生、出口条件和互动点保持")
	reopened.free(); map.free(); DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	finish()

func finish() -> void:
	print(JSON.stringify({"first_level_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
