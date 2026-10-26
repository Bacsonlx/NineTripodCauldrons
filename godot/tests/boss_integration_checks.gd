extends SceneTree

const Journey = preload("res://scripts/journey/room_journey.gd")
const Boss = preload("res://scripts/combat/boss_room.gd")
var failures: Array[String] = []
var checks: int = 0
var run: RefCounted

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	var maps: Dictionary = Journey.read_maps()
	check(maps.has("boss") and maps.has("thunder_approach") and maps.thunder_approach.doors.any(func(door: Dictionary): return door.target=="boss"),"默认首关经雷庭前径连接Boss房")
	if not maps.has("boss"): finish(); return
	check(maps.boss.objective=="boss" and maps.boss.doors.any(func(door: Dictionary): return door.target=="end"),"Boss房连接原出口，地图配置合法")
	var entry: Dictionary = safe_room("entry","court3")
	var court: Dictionary = safe_room("court3","entry")
	court.objective="combat"
	court.encounters=[{"x":300,"y":520,"enemies":[Vector2(360,520)]}]
	court.doors.append(door("boss","boss","court3",Vector2(500,520)))
	var boss: Dictionary = maps.boss.duplicate(true)
	for back in boss.doors:
		if back.target=="thunder_approach": back.target="court3"; back.targetDoor="boss"
	var exit: Dictionary = safe_room("end","boss")
	exit.doors[0].targetDoor="end"
	run=Journey.new({"entry":entry,"court3":court,"boss":boss,"end":exit},{"isTest":true})
	run.update({"alpha":{"action":"depart"}},0)
	check(pass_to("court3"),"通过真实F进入第三庭夹具")
	run.update({},1)
	for i in 200:
		var state: Dictionary = run.snapshot()
		if state.roomComplete: break
		var enemy: Dictionary = state.enemies[0]
		run.update({"fire":true,"aim":Vector2(enemy.x,enemy.y-52)},0.02)
	check(run.snapshot().roomComplete and run.snapshot().health<100,"真实受伤并射箭清场，不改写生命或完成状态")
	check(walk(Vector2(500,520)),"可走到第三庭通往Boss的门前")
	run.update({},0); run.update({"pierce":true,"aim":Vector2(1000,468)},0.2)
	run.update({"dodge":true},0)
	var travel: Dictionary = run.active.travel_state()
	run.update({"interact":true},0)
	check(run.snapshot().roomId=="boss" and not run.snapshot().roomComplete and not run.snapshot().journeyComplete,"进入Boss房封门，第三庭清场不能提前通关")
	check(run.snapshot().health==travel.health and run.snapshot().resources.mana==travel.mana and run.snapshot().resources.stamina==travel.stamina and is_equal_approx(run.snapshot().resources.staminaDelay,travel.staminaDelay),"进入Boss房继承非满生命、蓝量、精力及恢复等待")
	check(is_equal_approx(run.snapshot().cooldowns.pierce,travel.pierce) and is_equal_approx(run.snapshot().cooldowns.dodge,travel.dodge) and run.snapshot().arrows.is_empty(),"Boss过门保留冷却并清理旧弹道")
	run.update({"interact":false},0); run.update({"interact":true},0)
	check(run.snapshot().roomId=="boss" and run.snapshot().interaction.reason!=null,"Boss未击败时来路不能退出")
	for frame in 9000:
		var state: Dictionary = run.snapshot()
		if state.roomComplete or state.status=="failed": break
		var offset: Vector2 = TrainingRoom.point(state.player)-TrainingRoom.point(state.boss)
		var movement: Vector2 = (Vector2(-offset.y,offset.x).normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		run.update({"moveX":movement.x,"moveY":movement.y,"fire":true,"aim":Vector2(state.boss.x,state.boss.y-52)},0.01)
	check(run.snapshot().roomComplete and run.snapshot().boss.health==0 and not run.snapshot().journeyComplete,"实际击败Boss开放通路，尚未到出口仍未通关")
	check(pass_to("end") and run.snapshot().segmentComplete and not run.snapshot().journeyComplete,"测试夹具击败后到出口仅完成测试段，不冒充正式完整通关")
	check(pass_to("boss") and run.snapshot().boss.health==0 and run.snapshot().roomComplete,"从出口回Boss房不刷新或重打")
	check(pass_to("court3"),"已击败Boss房保留移动和F交互，可回溯第三庭")
	run.update({"restart":true},0)
	check(run.snapshot().roomId=="entry" and run.snapshot().visitedRooms==1 and not run.snapshot().journeyComplete,"R重开清除Boss和通关进度")
	finish()

func door(id: String,target: String,target_door: String,point: Vector2) -> Dictionary:
	return {"id":id,"target":target,"targetDoor":target_door,"title":target,"point":point,"arrival":point,"x":96,"y":520,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"}

func safe_room(id: String,target: String) -> Dictionary:
	var data: Dictionary = Boss.arena_layout()
	data.roomId=id; data.roomTitle=id; data.objective="safe"
	data.doors=[door(target,target,id,Vector2(300,520))]
	return data

func walk(destination: Vector2) -> bool:
	var path: Array = run.active.find_route(TrainingRoom.point(run.snapshot().player),destination)
	if path.is_empty(): return false
	for waypoint in path:
		for i in 1000:
			var delta: Vector2 = waypoint-TrainingRoom.point(run.snapshot().player)
			if delta.length()<4: break
			var movement: Vector2 = delta.normalized()
			run.update({"moveX":movement.x,"moveY":movement.y},0.01)
	return destination.distance_to(TrainingRoom.point(run.snapshot().player))<8

func pass_to(target: String) -> bool:
	for exit in run.active.layout.doors:
		if exit.target!=target: continue
		if not walk(TrainingRoom.point(exit.point)): return false
		run.update({"interact":false},0); run.update({"interact":true},0)
		return run.snapshot().roomId==target
	return false

func finish() -> void:
	print(JSON.stringify({"boss_integration_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
