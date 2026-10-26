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
	var measured: Dictionary = rule_workload()
	quality_policy_workload()
	journey_workload()
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
