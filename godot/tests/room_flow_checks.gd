extends SceneTree
const Journey = preload("res://scripts/journey/room_journey.gd")
var failures: Array[String] = []
var checks: int = 0
var journey: RefCounted
var combat_runs: Array = []
var game: Node2D
var observed_drops: Dictionary = {}
var blue_waves: Dictionary = {}
var collected: int = 0
var restored_mana: int = 0
var restored_health: int = 0
var samples: Array = []
var baseline_items: int = 0
var visit_start: Dictionary = {}
var visit_revisit: bool = false
var visit_milestones: Dictionary = {}
var returning: bool = false
var route_name: String = "main"
const MAIN_ROUTE: Array[String] = ["court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end"]
const BRANCH_ROUTE: Array[String] = ["court1","dry_creek","moss_side","dry_creek","moss_side","root_fork","moss_side","dry_creek","root_fork","stele","stele_side","stele","stele_side","court2","stele_side","stele","court2","altar","ash_cloister","ember_side","ash_cloister","ember_side","gate_forecourt","ember_side","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end"]

func include_branches() -> bool: return false

func timing(state: Dictionary) -> Dictionary:
	return {"effective_seconds":state.alpha.elapsed,"actual_seconds":state.actualSeconds,"health":state.health,"mana":state.resources.mana,"stamina":state.resources.stamina}

func observe_progress(state: Dictionary) -> void:
	var live: Array = state.enemies.filter(func(enemy: Dictionary): return enemy.phase not in ["dead","inactive"])
	if not live.is_empty():
		if not visit_milestones.has("first_combat"): visit_milestones.first_combat=timing(state)
		var wave: String = "wave_"+str(state.encounter)
		if not visit_milestones.has(wave): visit_milestones[wave]=timing(state)
	if state.roomComplete and not visit_milestones.has("complete"): visit_milestones.complete=timing(state)

func sample_visit(before: Dictionary,revisit: bool) -> void:
	var after: Dictionary = journey.snapshot()
	observe_progress(after)
	visit_milestones.left=timing(after)
	var room_drops: Array = observed_drops.values().filter(func(item: Dictionary): return item.room==after.roomId)
	var wave_sizes: Array = []
	for encounter in journey.active.layout.encounters: wave_sizes.append(encounter.enemies.size())
	var sample: Dictionary = {"route":route_name,"phase":"return" if returning else "outbound","room":after.roomId,"revisit":revisit,"seed":13,"milestones":visit_milestones.duplicate(true),
		"effective_seconds":after.alpha.elapsed-before.alpha.elapsed,"total_effective_seconds":after.alpha.elapsed,
		"actual_seconds":after.actualSeconds-before.actualSeconds,"total_actual_seconds":after.actualSeconds,
		"health_before":before.health,"health_after":after.health,"mana_before":before.resources.mana,"mana_after":after.resources.mana,
		"stamina_before":before.resources.stamina,"stamina_after":after.resources.stamina,
		"waves":after.waveCount,"wave_sizes":wave_sizes,"room_drops":room_drops,"fixed_enemies":after.enemies.size() if after.objective=="combat" else 0,
		"room_complete":after.roomComplete,"status":after.status,"generated_drops":observed_drops.size(),
		"blue_waves":blue_waves.size(),"collected":collected,"restored_mana":restored_mana,
		"restored_health":restored_health,"glyphs_issued":after.alpha.items.size()-baseline_items}
	samples.append(sample)
	print(JSON.stringify({"tanggu_room_sample":sample}))

func observe_loot(state: Dictionary) -> void:
	for item in state.get("drops",[]):
		var key: String = state.roomId+":"+str(item.id)
		if not observed_drops.has(key):
			observed_drops[key]={"room":state.roomId,"id":item.id,"kind":item.kind,"wave":item.wave,"guaranteed":item.guaranteed,"generated_at":timing(state),"collected":false}
		if item.kind=="mana" and state.objective=="combat": blue_waves[state.roomId+":"+str(item.wave)]=true

func collect_nearby() -> void:
	var before: Dictionary = journey.snapshot()
	if before.interaction==null or not before.interaction.has("dropId") or before.interaction.reason!=null: return
	journey.update({"interact":false},0); journey.update({"interact":true},0)
	var after: Dictionary = journey.snapshot()
	if after.drops.size()==before.drops.size()-1:
		collected+=1; restored_mana+=after.resources.mana-before.resources.mana; restored_health+=after.health-before.health
		var key: String = before.roomId+":"+str(before.interaction.dropId)
		if observed_drops.has(key):
			observed_drops[key].collected=true
			observed_drops[key].collected_at=timing(after)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func walk(destination: Vector2) -> bool:
	var path: Array = journey.active.find_route(TrainingRoom.point(journey.snapshot().player),destination)
	if path.is_empty(): return false
	for waypoint in path:
		for i in 800:
			var state: Dictionary = journey.snapshot()
			observe_progress(state)
			if state.status=="failed": return false
			var delta: Vector2 = waypoint-TrainingRoom.point(state.player)
			if delta.length()<5: break
			var move: Vector2 = delta.normalized()
			journey.update({"moveX":move.x,"moveY":move.y},0.02)
	return destination.distance_to(TrainingRoom.point(journey.snapshot().player))<10
func pass_to(target: String) -> bool:
	for door in journey.active.layout.doors:
		if door.target!=target: continue
		if not walk(TrainingRoom.point(door.point)): return false
		if not visit_start.is_empty(): sample_visit(visit_start,visit_revisit)
		for attempt in 64:
			journey.update({"interact":false},0)
			var before: Dictionary = journey.snapshot()
			journey.update({"interact":true},0)
			var after: Dictionary = journey.snapshot()
			if after.roomId==target:
				check(after.health==before.health and after.healthMax==before.healthMax and after.resources==before.resources and after.cooldowns==before.cooldowns and after.alpha.items==before.alpha.items,"真实过门保持生命、资源、冷却及共享背包："+before.roomId+" → "+target)
				break
		if journey.snapshot().roomId==target:
			game.present_new_room()
			check(game.minimap.layout.roomId==target and game.minimap.player==TrainingRoom.point(journey.snapshot().player) and game.minimap.locked==(not journey.snapshot().roomComplete),"真实过门后小地图更新："+target)
			return true
		return false
	return false
func fight() -> bool:
	var encounters: Array = journey.active.layout.encounters
	if encounters.is_empty() or not walk(TrainingRoom.point(encounters[0])): return false
	var center: Vector2 = TrainingRoom.point(encounters[0])
	for i in 18000:
		var state: Dictionary = journey.snapshot()
		observe_progress(state)
		observe_loot(state)
		if state.roomComplete:
			for item in state.drops:
				if item.kind=="mana" and journey.snapshot().resources.mana==100 or item.kind=="health" and journey.snapshot().health==100: continue
				if walk(TrainingRoom.point(item)): collect_nearby()
			combat_runs.append({"room":state.roomId,"waves":state.waveCount,"enemies":state.enemies.size(),"health":journey.snapshot().health,"mana":journey.snapshot().resources.mana,"seconds":i*0.02})
			return true
		if state.status=="failed": return false
		if i%2==0: collect_nearby()
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
			var score: float = minf(gap,290)-maxf(0,future.distance_to(center)-300)*0.8
			if score>best: best=score; move=candidate
		journey.update({"moveX":move.x,"moveY":move.y,"aim":target-Vector2(0,52),"fire":state.hurt<=0,"pierce":i%25==0,"rain":i%30==0,"dodge":player.distance_to(target)<100 and i%15==0},0.02)
	return false
func _initialize() -> void:
	create_timer(150).timeout.connect(func(): push_error("完整路线检查超时"); quit(1))
	run.call_deferred()

func boss_fight() -> bool:
	for i in 9000:
		var state: Dictionary = journey.snapshot()
		observe_progress(state)
		observe_loot(state)
		if state.roomComplete:
			game.present(state,0)
			combat_runs.append({"room":"boss","health":state.health,"mana":state.resources.mana,"seconds":i*0.01})
			return true
		if state.status=="failed": return false
		var offset: Vector2 = TrainingRoom.point(state.player)-TrainingRoom.point(state.boss)
		var move: Vector2 = (Vector2(-offset.y,offset.x).normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		journey.update({"moveX":move.x,"moveY":move.y,"fire":state.hurt<=0,"aim":Vector2(state.boss.x,state.boss.y-52)},0.01)
		if i%30==0: game.present(journey.snapshot(),0)
	return false

func read_stele() -> bool:
	if not walk(TrainingRoom.point(journey.active.layout.exploration[0])): return false
	journey.update({"interact":false},0); journey.update({"interact":true},0)
	visit_milestones.reading_open=timing(journey.snapshot())
	check(journey.snapshot().reading and not journey.snapshot().roomComplete,"F打开真实残碑，合上前保持封门")
	PlayerControls.new(journey.active).key_down(KEY_ESCAPE); journey.update({},0)
	visit_milestones.reading_close=timing(journey.snapshot())
	return journey.snapshot().roomComplete and journey.snapshot().exploration.steleRead

func boss_presentation() -> void:
	check(game.boss_view.visible and game.boss_bar.visible and game.boss_bar.value==1200,"真实进Boss房显示索尔及完整1200生命")
	var actor: Node2D = game.boss_view.character
	check(actor!=null and actor.body.texture!=null and actor.body.clip=="thor-swing-v2","实际Boss房加载当前逐帧角色及中立姿态")
	var visible: Rect2 = Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
	check(visible.encloses(Rect2(16,16,1408,1008)) and is_equal_approx(game.camera.position.x,720),"Boss房相机居中并覆盖战斗边界")
	game.toggle_overview()
	visible=Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
	check(visible.encloses(Rect2(16,16,1408,1008)),"M仍可查看Boss全房")
	game.toggle_overview()

func run() -> void:
	route_name="all_branches" if include_branches() else "main"
	var maps: Dictionary = Journey.read_maps()
	check(maps.size()==16,"扩展路线需要16个真实房间")
	if maps.size()!=16: finish(); return
	game=load("res://scenes/tanggu_first_level.tscn").instantiate()
	game.potion_drop_seed=13
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	journey=game.journey
	baseline_items=journey.snapshot().alpha.items.size()
	check(journey.snapshot().health==100 and journey.snapshot().resources.mana==100 and journey.snapshot().resources.stamina==100,"完整征程保持默认生命蓝量精力100，不模拟构筑")
	journey.update({"alpha":{"action":"depart"}},0)
	visit_start=journey.snapshot()
	visit_milestones={"entered":timing(visit_start)}
	var seen: Dictionary = {"entry":true}
	var route: Array[String] = BRANCH_ROUTE if include_branches() else MAIN_ROUTE
	for target in route:
		check(journey.snapshot().roomComplete,"完成当前房真实任务后才尝试F过门："+journey.snapshot().roomId)
		var crossed: bool = pass_to(target)
		check(crossed,"真实移动并F进入："+target)
		if not crossed: finish(); return
		var before: Dictionary = journey.snapshot()
		var revisit: bool = seen.has(target)
		visit_start=before; visit_revisit=revisit
		visit_milestones={"entered":timing(before)}
		seen[target]=true
		var complete: bool = before.roomComplete
		if revisit:
			check(complete,"往返后房间保持已完成："+target)
		elif before.objective=="combat":
			for role in ["bird","paper","wood"]:
				check(before.enemies.any(func(enemy: Dictionary): return enemy.get("role","")==role),target+"保留敌人职责："+role)
			check(before.enemies.all(func(enemy: Dictionary): return enemy.health=={"bird":60,"paper":45,"wood":150}.get(enemy.get("role",""),-1)),target+"沿用三职责默认生命，不为bot降低数值")
			complete=fight()
			check(complete,"真实跑射清场："+target)
		elif before.objective=="explore":
			complete=read_stele()
			check(complete,"真实阅读并合上残碑："+target)
		elif before.objective=="boss":
			check(not before.journeyComplete,"Boss开战前不标记正式完成")
			boss_presentation()
			var glyphs: int = before.alpha.items.size()
			complete=boss_fight()
			check(complete,"保留沿途真实资源，完整战斗击败1200生命索尔")
			check(journey.snapshot().alpha.items.size()==glyphs,"Boss及持续援军不增发普通构筑符")
			check(not journey.snapshot().journeyComplete,"Boss倒下但未到出口仍未完成征程")
			if complete:
				var actor: Node2D = game.boss_view.character
				check(not actor.body.visible and actor.fallen.visible and is_equal_approx(actor.fallen.get_node("chest").rotation,0.3),"Boss真实败退落定并停止新动作")
				check(game.boss_bar.value==0,"Boss真实败退后生命条归零")
				var floor: Node2D = game.boss_view.get_node_or_null("Floor")
				var passages_visible: bool = floor!=null and not floor.z_as_relative
				for portal in game.get_node("TangguMap/Doors").get_children():
					passages_visible=passages_visible and portal.get_node("Passage").visible and floor.z_index<portal.get_node("Passage").z_index
				check(passages_visible,"Boss清场门漩涡高于独立地面层")
		if not complete: sample_visit(before,revisit); finish(); return
		if revisit: check(journey.snapshot().alpha.items.size()==before.alpha.items.size(),"支路往返不复制构筑符："+target)
	sample_visit(visit_start,visit_revisit)
	var expected_rooms: int = 16 if include_branches() else 13
	var expected_waves: int = 24 if include_branches() else 21
	var expected_glyphs: int = 8 if include_branches() else 7
	check(journey.snapshot().journeyComplete and journey.snapshot().visitedRooms==expected_rooms,"完整清场主线及Boss，实际抵达出口才标记正式完成")
	check(not game.boss_view.visible and not game.boss_bar.visible,"离开Boss房隐藏Boss角色及专属血条")
	check(journey.snapshot().alpha.items.size()==baseline_items+expected_glyphs,"实际击杀只发主线7枚／含A支路8枚构筑符")
	check(blue_waves.size()==expected_waves,"每一普通波真实产生可拾取蓝囊，包含末波")
	check(collected>0 and restored_mana>0,"全流程真实F拾取蓝囊并恢复蓝量")
	var exit_test: RefCounted = Journey.new(maps,{"startRoom":"end","isTest":true,"potionDrops":true,"dropSeed":13})
	check(exit_test.snapshot().isTest and exit_test.snapshot().segmentComplete and not exit_test.snapshot().journeyComplete and exit_test.snapshot().visitedRooms==1,"直接测试出口只标记测试段结束，不伪造前序或正式完整通关")
	var before_return: int = journey.snapshot().alpha.items.size()
	returning=true
	visit_start=journey.snapshot(); visit_revisit=true
	visit_milestones={"entered":timing(visit_start)}
	for target in ["boss","thunder_approach","court3"]:
		var crossed: bool = pass_to(target)
		check(crossed,"出口经已击败Boss房真实F回溯主线："+target)
		if not crossed: finish(); return
		visit_start=journey.snapshot(); visit_revisit=true
		visit_milestones={"entered":timing(visit_start)}
	sample_visit(visit_start,visit_revisit)
	check(journey.snapshot().roomComplete and journey.snapshot().alpha.items.size()==before_return,"通关回溯保留完成状态且不增发实物")
	finish()
func finish() -> void:
	print(JSON.stringify({"room_flow_checks":checks,"route":route_name,"samples":samples,"sampling_limit":"bot不证明正常玩家首通15–20分钟","failures":failures,"combat_runs":combat_runs,"generated_drops":observed_drops.size(),"blue_waves":blue_waves.size(),"collected":collected,"restored_mana":restored_mana,"restored_health":restored_health}))
	if game!=null: game.free()
	quit(0 if failures.is_empty() else 1)
