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

func observe_loot(state: Dictionary) -> void:
	for item in state.get("drops",[]):
		observed_drops[item.id]=item.kind
		if item.kind=="mana": blue_waves[state.roomId+":"+str(item.wave)]=true

func collect_nearby() -> void:
	var before: Dictionary = journey.snapshot()
	if before.interaction==null or not before.interaction.has("dropId") or before.interaction.reason!=null: return
	journey.update({"interact":false},0); journey.update({"interact":true},0)
	var after: Dictionary = journey.snapshot()
	if after.drops.size()==before.drops.size()-1:
		collected+=1; restored_mana+=after.resources.mana-before.resources.mana; restored_health+=after.health-before.health
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
		for attempt in 64:
			journey.update({"interact":false},0); journey.update({"interact":true},0)
			if journey.snapshot().roomId==target: break
		if journey.snapshot().roomId==target:
			game.present_new_room(); return true
		return false
	return false
func fight() -> bool:
	if not walk(Vector2(510,550)): return false
	for i in 9000:
		var state: Dictionary = journey.snapshot()
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
			var score: float = minf(gap,290)-maxf(0,future.distance_to(Vector2(700,550))-300)*0.8
			if score>best: best=score; move=candidate
		journey.update({"moveX":move.x,"moveY":move.y,"aim":target-Vector2(0,52),"fire":true,"pierce":i%25==0,"rain":i%30==0,"dodge":player.distance_to(target)<100 and i%15==0},0.02)
	return false
func _initialize() -> void:
	run.call_deferred()

func boss_fight() -> bool:
	for i in 9000:
		var state: Dictionary = journey.snapshot()
		if state.roomComplete:
			game.present(state,0)
			combat_runs.append({"room":"boss","health":state.health,"mana":state.resources.mana,"seconds":i*0.01})
			return true
		if state.status=="failed": return false
		var offset: Vector2 = TrainingRoom.point(state.player)-TrainingRoom.point(state.boss)
		var move: Vector2 = (Vector2(-offset.y,offset.x).normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		journey.update({"moveX":move.x,"moveY":move.y,"fire":true,"aim":Vector2(state.boss.x,state.boss.y-52)},0.01)
		if i%30==0: game.present(journey.snapshot(),0)
	return false

func run() -> void:
	game=load("res://scenes/tanggu_first_level.tscn").instantiate()
	game.potion_drop_seed=13
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	journey=game.journey
	journey.update({"alpha":{"action":"depart"}},0)
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
	check(not journey.snapshot().journeyComplete and pass_to("boss"),"第三庭清场后必须先进入Boss房")
	check(game.boss_view.visible and game.boss_bar.visible and game.boss_bar.value==1200,"默认首关真实切房后显示索尔角色与1200生命条")
	var actor: Node2D = game.boss_view.get_node_or_null("ThorPuppet")
	check(actor!=null and actor.get_child_count()==16,"默认首关实际进Boss房后使用16拆件美术角色")
	var visible: Rect2 = Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
	check(visible.encloses(Rect2(16,16,1408,1008)) and is_equal_approx(game.camera.position.x,720),"首关进Boss房固定居中，并完整覆盖战斗与预警边界")
	game.toggle_overview()
	visible=Rect2(game.view_origin,game.get_viewport_rect().size/game.view_zoom)
	check(visible.encloses(Rect2(16,16,1408,1008)),"M仍可临时查看完整Boss房及预警边界")
	game.toggle_overview()
	check(boss_fight(),"42影偶后保留现有生命与资源，真实走射击败索尔")
	check(actor!=null and is_equal_approx(actor.get_node("chest").rotation,0.3),"Boss击败后规则时间停止，静态败退姿势仍应完整落定")
	check(game.boss_bar.value==0 and not journey.snapshot().journeyComplete,"Boss生命条归零后开放通路，未到出口不提前完成")
	var floor: Node2D = game.boss_view.get_node_or_null("Floor")
	var passages_visible: bool = floor!=null and not floor.z_as_relative
	for portal in game.get_node("TangguMap/Doors").get_children():
		passages_visible=passages_visible and portal.get_node("Passage").visible and floor.z_index<portal.get_node("Passage").z_index
	check(passages_visible,"击败Boss后的门漩涡高于独立地面层，不被灰盒底板遮住")
	check(pass_to("end") and journey.snapshot().journeyComplete and journey.snapshot().visitedRooms==8,"到达原出口后完成首关，八房间均可探索")
	check((actor==null or not actor.is_visible_in_tree()) and not game.boss_view.visible and not game.boss_bar.visible,"离开Boss房后隐藏Boss呈现与专属血条")
	check(pass_to("boss") and pass_to("court3") and pass_to("court2") and pass_to("stele"),"通关后可经过已击败Boss房跨房回溯")
	check(journey.snapshot().roomComplete and journey.snapshot().exploration.steleRead,"跨房回溯保留任务进度")
	check(journey.snapshot().alpha.items.size()==18,"八波共发八枚构筑符，往返不会额外复制实物")
	check(blue_waves.size()==8,"默认首关八波均产生蓝瓶，包括最后一波")
	check(collected>0 and restored_mana>0,"完整流程通过真实F拾取补充蓝量")
	finish()
func finish() -> void:
	print(JSON.stringify({"room_flow_checks":checks,"failures":failures,"combat_runs":combat_runs,"generated_drops":observed_drops.size(),"blue_waves":blue_waves.size(),"collected":collected,"restored_mana":restored_mana,"restored_health":restored_health}))
	if game!=null: game.free()
	quit(0 if failures.is_empty() else 1)
