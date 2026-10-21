extends SceneTree

const Stage = preload("res://scripts/journey/journey_room.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func fixture() -> Dictionary:
	var data: Dictionary = TrainingRoom.new().layout.duplicate(true)
	data.roomId="waves"; data.roomTitle="分波测试"; data.objective="combat"
	data.spawn={"x":300,"y":600}; data.obstacles=[]; data.doors=[]
	data.encounters=[{"x":300,"y":600,"enemies":[{"x":550,"y":600,"appearance":"bird"}]},
		{"x":900,"y":600,"enemies":[{"x":650,"y":600,"appearance":"paper"}]}]
	return data

func _initialize() -> void:
	var room: TrainingRoom = Stage.new(fixture())
	for tick in 500:
		room.update({"aim":Vector2(1000,548),"fire":true},0.01)
		if room.snapshot().encounter==1: break
	var between: Dictionary = room.snapshot()
	check(between.encounter==1 and not between.roomComplete,"真实射箭清完第一波后仍封门")
	check(between.get("waveDelay",0)>1.18 and between.enemies[1].phase=="inactive","第二波先等待1.2秒并保持不可攻击")
	check(between.enemies[1].health==60,"前波的普通箭不会提前伤害未激活敌人")
	room.set_paused(true)
	room.update({},2)
	check(is_equal_approx(room.snapshot().get("waveDelay",0),between.get("waveDelay",0)),"暂停不推进波间倒计时")
	room.set_paused(false)
	room.update({},1.0)
	check(room.snapshot().enemies[1].phase=="inactive" and room.snapshot().get("waveDelay",0)>0.18,"缓冲未结束前不激活下一波")
	room.update({},0.22)
	check(room.snapshot().enemies[1].phase!="inactive","缓冲结束自动激活远离触发圆的下一波，避免空场封门")
	for tick in 500:
		var state: Dictionary = room.snapshot()
		room.update({"aim":Vector2(state.enemies[1].x,state.enemies[1].y-52),"fire":true},0.01)
		if room.snapshot().roomComplete: break
	check(room.snapshot().roomComplete and room.snapshot().encounter==2,"最后一波真实清敌后才完成房间")
	var completed: Dictionary = room.snapshot()
	room.arrive(room.travel_state(),Vector2(300,600),0,99)
	room.update({},0.1)
	check(room.snapshot().roomComplete and room.snapshot().enemies[1].phase=="dead" and room.snapshot().waveCount==completed.waveCount,"跨房回来保留全部波次清除状态")
	var short_steps: TrainingRoom = Stage.new(fixture())
	var long_step: TrainingRoom = Stage.new(fixture())
	for tick in 400: short_steps.update({"fire":true,"aim":Vector2(1000,548)},0.01)
	long_step.update({"fire":true,"aim":Vector2(1000,548)},4)
	check(short_steps.snapshot().encounter==long_step.snapshot().encounter and is_equal_approx(short_steps.snapshot().get("waveDelay",0),long_step.snapshot().get("waveDelay",0)) and short_steps.snapshot().shots==long_step.snapshot().shots,"长帧与短步波间推进及攻击结果一致")
	var maps: Dictionary = load("res://scripts/journey/room_journey.gd").read_maps()
	for pair in [["court1",[4,5]],["court2",[4,5,6]],["court3",[5,6,7]]]:
		var counts: Array = []
		for encounter in maps[pair[0]].encounters: counts.append(encounter.enemies.size())
		check(counts==pair[1],pair[0]+"按确认的人数逐波递增")
	var invalid: Node2D = load("res://scenes/rooms/court1.tscn").instantiate()
	for enemy in invalid.get_node("Encounter").get_children(): enemy.free()
	check(not invalid.validation_errors().is_empty(),"编辑器拒绝没有敌人的空波次")
	invalid.free()
	print(JSON.stringify({"wave_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
