extends SceneTree
const Journey = preload("res://scripts/journey/room_journey.gd")
var failures: Array[String] = []
var checks: int = 0
var journey: RefCounted
var combat_runs: Array = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func walk(destination: Vector2) -> bool:
	var path: Array = journey.active.find_route(TrainingRoom.point(journey.snapshot().player),destination)
	if path.is_empty(): return false
	for waypoint in path:
		for i in 800:
			var delta: Vector2 = waypoint-TrainingRoom.point(journey.snapshot().player)
			if delta.length()<5: break
			var move: Vector2 = delta.normalized()
			journey.update({"moveX":move.x,"moveY":move.y},0.02)
	return destination.distance_to(TrainingRoom.point(journey.snapshot().player))<10
func pass_to(target: String) -> bool:
	for door in journey.active.layout.doors:
		if door.target!=target: continue
		if not walk(TrainingRoom.point(door.point)): return false
		journey.update({"interact":false},0); journey.update({"interact":true},0)
		return journey.snapshot().roomId==target
	return false
func fight() -> bool:
	if not walk(Vector2(510,550)): return false
	for i in 9000:
		var state: Dictionary = journey.snapshot()
		if state.roomComplete:
			combat_runs.append({"room":state.roomId,"waves":state.waveCount,"enemies":state.enemies.size(),"health":state.health,"seconds":i*0.02})
			return true
		if state.status=="failed": return false
		var live: Array = state.enemies.filter(func(enemy: Dictionary): return enemy.phase not in ["dead","inactive"])
		if live.is_empty(): journey.update({},0.02); continue
		var player: Vector2 = TrainingRoom.point(state.player)
		live.sort_custom(func(a: Dictionary,b: Dictionary): return player.distance_squared_to(TrainingRoom.point(a))<player.distance_squared_to(TrainingRoom.point(b)))
		var target: Vector2 = TrainingRoom.point(live[0])
		var move: Vector2 = Vector2.ZERO
		var best: float = -INF
		for direction in 16:
			var candidate: Vector2 = Vector2.from_angle(direction*TAU/16)
			var future: Vector2 = player+candidate*70
			if not journey.active.can_walk(future) or not journey.active.clear_path(player,future): continue
			var gap: float = INF
			for enemy in live: gap=minf(gap,future.distance_to(TrainingRoom.point(enemy)))
			var score: float = minf(gap,290)-maxf(0,future.distance_to(Vector2(700,550))-300)*0.8
			if score>best: best=score; move=candidate
		journey.update({"moveX":move.x,"moveY":move.y,"aim":target-Vector2(0,52),"fire":true,"pierce":i%25==0,"rain":i%30==0,"dodge":player.distance_to(target)<100 and i%15==0},0.02)
	return false
func _initialize() -> void:
	journey=Journey.new(Journey.read_maps())
	check(pass_to("court1"),"入口进入第一庭")
	check(fight(),"真实跑射和技能完成第一庭两波9影偶")
	if not journey.snapshot().roomComplete: finish(); return
	check(pass_to("stele"),"第一庭选择碑林分支")
	check(walk(TrainingRoom.point(journey.active.layout.exploration[0])),"可走到外缘残碑")
	journey.update({"interact":true},0)
	check(journey.snapshot().reading,"F打开真实残碑")
	PlayerControls.new(journey.active).key_down(KEY_ESCAPE); journey.update({},0)
	check(pass_to("court1") and pass_to("altar"),"读碑完成后回到第一庭补走祭火分支")
	check(journey.snapshot().roomComplete,"祭火安全房无需回血即可通行")
	check(pass_to("court2") and fight(),"两支汇合后完成第二庭三波15影偶")
	check(pass_to("court3") and fight(),"进入第三庭并完成三波18影偶")
	check(pass_to("end") and journey.snapshot().journeyComplete and journey.snapshot().visitedRooms==7,"到达终点且七房间均可探索")
	check(pass_to("court3") and pass_to("court2") and pass_to("stele"),"通关后可跨多个已完成房间回溯")
	check(journey.snapshot().roomComplete and journey.snapshot().exploration.steleRead,"跨房回溯保留任务进度")
	finish()
func finish() -> void:
	print(JSON.stringify({"room_flow_checks":checks,"failures":failures,"combat_runs":combat_runs}))
	quit(0 if failures.is_empty() else 1)
