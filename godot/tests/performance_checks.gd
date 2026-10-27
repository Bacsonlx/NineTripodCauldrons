extends SceneTree
# 后台性能回归：断言的是「工作量」而非墙钟时间，避免机器差异造成假失败。
# 同时打印规则+快照的微秒耗时，供同一台机器做优化前后对比；headless 结果不代表原生 FPS。

const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
const Journey = preload("res://scripts/journey/room_journey.gd")
const QualityPolicy = preload("res://scripts/presentation/quality_policy.gd")

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func dense_layout() -> Dictionary:
	var layout: Dictionary = Room.new().layout.duplicate(true)
	layout.encounters=[]
	for wave in 8:
		var enemies: Array = []
		for index in 6:
			enemies.append({"x":600+index*18,"y":560+wave*12,"appearance":"bird"})
		layout.encounters.append({"x":500,"y":600,"enemies":enemies})
	return layout

func journey_fixture(id: String,task: String,target: String) -> Dictionary:
	var data: Dictionary = Room.new().layout.duplicate(true)
	data.obstacles=[]; data.encounters=[]; data.exploration=[]
	data.spawn={"x":300,"y":600}
	data.roomId=id; data.roomTitle=id; data.objective=task
	data.doors=[{"id":"door","target":target,"targetDoor":"door","title":target,"point":{"x":300,"y":600},"arrival":{"x":300,"y":600},"x":200,"y":600,"halfWidth":20,"halfHeight":55,"height":120,"kind":"wall"}]
	if task=="combat": data.encounters=[{"x":300,"y":600,"enemies":[{"x":550,"y":600,"appearance":"bird"}]}]
	return data

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var measured: Dictionary = rule_workload()
	quality_policy_workload()
	journey_workload()
	await present_throttle_workload()
	await occlusion_workload()
	critical_vfx_workload()
	pose_cache_workload()
	print(JSON.stringify({"performance_checks":checks,"failures":failures,"measurement":measured}))
	quit(0 if failures.is_empty() else 1)

func rule_workload() -> Dictionary:
	var room: TrainingRoom = Room.new(dense_layout())
	room.profile=true
	room.reset_diagnostics()
	# 2000 次地形查询期间没有门／波次变化，障碍集合只需构建一次。
	for index in 2000:
		room.can_walk(Vector2(200+index%800,300+index%400))
	check(room.diagnostics.obstacleRebuilds==1,"2000 次可行走查询只重建一次障碍集合")
	room.reset_diagnostics()
	room.snapshot()
	check(room.diagnostics.interactionScans==1,"单次公开快照只扫描一次交互目标")
	check(room.diagnostics.snapshotCalls==1,"快照调用计数与公开状态一致")
	var controls: PlayerControls = Controls.new(room)
	controls.pointer_down(true)
	room.reset_diagnostics()
	var frames: int = 300
	var start: int = Time.get_ticks_usec()
	for index in frames:
		controls.update(Vector2(1000,549),true,1.0/60.0)
	var elapsed_usec: int = Time.get_ticks_usec()-start
	check(room.diagnostics.snapshotCalls==frames,"输入适配层每帧只构造一次公开快照")
	check(room.diagnostics.obstacleRebuilds<=20,"300 帧密集战斗中障碍重建次数受状态变化限制")
	check(elapsed_usec>0,"规则与快照耗时可测量")
	return {"scenario":"8 波 × 6 影偶，连续 300 帧射箭","frames":frames,"ruleAndSnapshotUsecTotal":elapsed_usec,"ruleAndSnapshotUsecPerFrame":float(elapsed_usec)/frames,"obstacleRebuilds":room.diagnostics.obstacleRebuilds,"interactionScans":room.diagnostics.interactionScans,"clearPathCalls":room.diagnostics.clearPathCalls,"snapshotCalls":room.diagnostics.snapshotCalls,"note":"微秒为 headless 纯规则成本，不含渲染；只用于同机同版本前后对比"}

func journey_workload() -> void:
	var run = Journey.new({"entry":journey_fixture("entry","safe","fight"),"fight":journey_fixture("fight","combat","entry")})
	var base: Dictionary = run.active.snapshot()
	run.active.profile=true
	run.active.reset_diagnostics()
	var decorated: Dictionary = run.snapshot(base)
	check(run.active.diagnostics.snapshotCalls==0,"流程快照复用本帧公开状态，不二次深拷贝")
	check(decorated.roomGraph.rooms.size()==2,"复用快照仍生成完整房间关系图")
	var graph: Dictionary = run.snapshot().roomGraph
	graph.rooms[0].id="外部修改"
	check(run.snapshot().roomGraph.rooms[0].id=="entry","外部修改图快照不污染真实房间状态")

func present_throttle_workload() -> void:
	# 纯函数：同一渲染帧内的后续物理 tick 不呈现，但最多跳过 4 个 tick 兜底。
	check(QualityPolicy.should_present(10,9,1),"新渲染帧的第一个物理 tick 正常呈现")
	check(not QualityPolicy.should_present(9,9,1),"同一渲染帧的后续物理 tick 跳过呈现")
	check(not QualityPolicy.should_present(9,9,3),"连续跳过 3 个 tick 仍不呈现")
	check(QualityPolicy.should_present(9,9,4),"引擎帧计数停滞时第 4 个 tick 兜底呈现")
	check(is_equal_approx(QualityPolicy.accumulated_seconds(0.016,0.016),0.032),"跳过的物理 tick 累积呈现时间")
	check(is_equal_approx(QualityPolicy.accumulated_seconds(0.20,0.10),QualityPolicy.MAX_PRESENT_SECONDS),"累积呈现时间有上限，长暂停后不产生巨帧")
	check(is_equal_approx(QualityPolicy.accumulated_seconds(0.016,-1.0),0.016),"负数步长不倒退累积时间")
	var game: Node2D = load("res://scenes/sample.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	game._physics_process(0.016)
	check(game.present_seconds==0.0 and game.ticks_since_present==0,"首个物理 tick 呈现并清空累积时间")
	game._physics_process(0.016)
	check(is_equal_approx(game.present_seconds,0.016) and game.ticks_since_present==1,"低帧率下第二个 tick 只推进规则并累积时间")
	game._physics_process(0.016)
	game._physics_process(0.016)
	check(is_equal_approx(game.present_seconds,0.048),"跳过的 tick 持续累积到下一次呈现")
	game._physics_process(0.016)
	check(game.present_seconds==0.0 and game.ticks_since_present==0,"第 4 个跳过 tick 兜底呈现并重置节流计时")
	game.mark_presented()
	check(game.present_seconds==0.0 and game.ticks_since_present==0,"主动呈现后重置节流计时，不重复补偿时间")
	game.queue_free()
	await process_frame

func quality_policy_workload() -> void:
	var auto = QualityPolicy.new()
	auto.configure(["--quality=auto"])
	for index in 90: auto.begin_frame(0.03)
	check(auto.tier_name()=="medium" and auto.vfx_budget()==256,"持续低于45FPS时自动降到中档特效预算")
	for index in 90: auto.begin_frame(0.03)
	check(auto.tier_name()=="low" and auto.vfx_budget()==96,"持续低帧时继续降到低档")
	for index in 240: auto.begin_frame(0.01)
	check(auto.tier_name()=="medium","恢复高帧后回升一档，避免抖动")
	var default_policy = QualityPolicy.new()
	default_policy.configure([])
	for index in 300: default_policy.begin_frame(0.05)
	check(default_policy.tier_name()=="high" and default_policy.vfx_budget()==512,"默认档位始终保持已批准画面，不自动降级")
	var pinned = QualityPolicy.new()
	pinned.configure(["--quality=low"])
	for index in 100: pinned.begin_frame(0.001)
	check(pinned.vfx_budget()==96,"指定低档时不因高帧自动升档")

func occlusion_workload() -> void:
	var prop: Node2D = load("res://scenes/world/environment_prop.tscn").instantiate()
	prop.texture_asset=ImageTexture.create_from_image(Image.create_empty(100,200,false,Image.FORMAT_RGBA8))
	prop.position=Vector2(1000,900)
	root.add_child(prop)
	var body: Sprite2D = prop.get_node("Sprite")
	var previous: Transform2D = root.canvas_transform
	for canvas in [Transform2D.IDENTITY,Transform2D(Vector2(2,0),Vector2(0,2),Vector2(-1360,-1160)),Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2(100,40))]:
		root.canvas_transform=canvas
		await process_frame
		for point in [Vector2(1000,835),Vector2(1400,835)]:
			var state: Dictionary = {"player":{"x":point.x,"y":point.y+45}}
			check(prop.occludes(state)==body.get_rect().has_point(body.to_local(point)),"遮挡在跟随／缩放／总览画布中保持世界坐标语义")
	root.canvas_transform=previous
	prop.free()

func critical_vfx_workload() -> void:
	var effects: Node2D = load("res://scripts/presentation/combat_effects.gd").new()
	root.add_child(effects)
	var frames: Dictionary = {}
	for key in ["spark","shards","halo","streak","ring","embers","dust","feather"]:
		frames[key]={"x":0,"y":0,"width":16,"height":16}
	var lower: Sprite2D = Sprite2D.new()
	var upper: Sprite2D = Sprite2D.new()
	effects.setup(frames,null,lower,upper)
	var state: Dictionary = Room.new().snapshot()
	state.skill={"kind":"rain","phase":"windup","remaining":0.3}
	state.rainPreview=Vector2(1000,1000)
	state.rains=[{"x":1600,"y":1000,"age":0.05}]
	state.waveDelay=0.5
	state.enemies=[{"id":99,"group":state.encounter,"phase":"inactive","x":2200,"y":1000}]
	for index in 7:
		state.effects.append({"id":index,"x":0,"y":0,"kind":"normal","damage":0,"angle":0,"enemy":index})
	for budget in [512,256,96]:
		effects.vfx_budget=budget
		effects.update(state,0,0)
		var preview: int = 0
		var rain: int = 0
		var wave: int = 0
		for body in effects.stamps:
			if not body.visible: continue
			if body.position.distance_to(state.rainPreview)<150: preview+=1
			if body.position.distance_to(Vector2(1600,1000))<150: rain+=1
			if body.position.distance_to(Vector2(2200,1000))<150: wave+=1
		check(preview==8 and rain==12 and wave==2,"密集命中下所有画质仍保留箭雨预告／落点和下一波提示")
		check(effects.used<=budget,"关键预告优先后总特效数仍受画质预算约束")
	state.effects=[]; state.rainPreview=null; state.rains=[]; state.waveDelay=0
	effects.update(state,1,1)
	check(effects.stamps.all(func(body: Sprite2D): return not body.visible),"预告结束与降档后不残留旧特效")
	lower.free(); upper.free(); effects.free()

func pose_cache_workload() -> void:
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.journey.initial_options.startRoom="court1"
	game.journey.restart(); game.present_new_room()
	var initial: int = game.pose_cache.size()
	for index in 10:
		game.journey.restart(); game.present_new_room()
		check(game.pose_cache.size()==initial,"重试重建敌人后姿态缓存大小保持稳定")
	for target in ["stele","court1","altar","court1"]:
		game.journey.initial_options.startRoom=target
		game.journey.restart(); game.present_new_room()
		check(game.pose_cache.size()<=initial,"切换不同房间不会累积已释放精灵的姿态缓存")
	var body: Sprite2D = game.enemy_bodies.values()[0]
	var id: int = body.get_instance_id()
	body.free()
	check(not game.pose_cache.has(id),"单个敌人精灵释放时同步移除其姿态缓存")
	game.free()
