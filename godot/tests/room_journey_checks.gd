extends SceneTree

var failures: Array[String] = []
var checks: int = 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func fixture(id: String,task: String,target: String) -> Dictionary:
	var data: Dictionary = TrainingRoom.new().layout.duplicate(true)
	data.obstacles=[]; data.encounters=[]; data.exploration=[]
	data.spawn={"x":300,"y":600}
	data.roomId=id; data.roomTitle=id; data.objective=task
	data.doors=[{"id":"door","target":target,"targetDoor":"door","title":target,"point":{"x":300,"y":600},"arrival":{"x":300,"y":600},"x":200,"y":600,"halfWidth":20,"halfHeight":55,"height":120,"kind":"wall"}]
	if task=="combat": data.encounters=[{"x":300,"y":600,"enemies":[{"x":550,"y":600,"appearance":"bird"}]}]
	return data

func _initialize() -> void:
	var script: Script = load("res://scripts/journey/room_journey.gd")
	if script==null: check(false,"房间流程规则入口必须可加载"); finish(); return
	var run: RefCounted = script.new({"entry":fixture("entry","safe","fight"),"fight":fixture("fight","combat","entry")})
	check(run.snapshot().roomId=="entry" and run.snapshot().roomComplete,"安全入口直接开放")
	run.update({"interact":true},0)
	check(run.snapshot().roomId=="fight" and not run.snapshot().roomComplete,"F过门进入独立战斗房并封门")
	run.update({"interact":true},0)
	check(run.snapshot().roomId=="fight","未完成战斗不能从来路离开")
	run.update({"fire":true,"aim":Vector2(550,548)},1.5)
	check(run.snapshot().roomComplete,"真实射箭清敌后房间开放")
	run.update({"interact":false},0); run.update({"interact":true},0)
	check(run.snapshot().roomId=="entry","完成后允许返回入口房")
	run.update({"interact":false},0); run.update({"interact":true},0)
	check(run.snapshot().roomId=="fight" and run.snapshot().roomComplete and run.snapshot().enemies[0].phase=="dead","返回已完成战斗房不刷新敌人")
	var cooled: RefCounted = script.new({"entry":fixture("entry","safe","fight"),"fight":fixture("fight","combat","entry")})
	cooled.update({"pierce":true,"aim":Vector2(800,548)},0.35)
	var remaining: float = cooled.snapshot().cooldowns.pierce
	cooled.update({"interact":true},0)
	check(remaining>0 and cooled.snapshot().cooldowns.pierce==remaining and cooled.snapshot().arrows.is_empty(),"过门保留技能冷却但清除弹道")
	var explore: Dictionary = fixture("explore","explore","entry")
	explore.exploration=[{"id":"stele","x":500,"y":600}]
	var reader: RefCounted = script.new({"entry":fixture("entry","safe","explore"),"explore":explore})
	reader.update({"interact":true},0)
	reader.update({"moveX":1},0.9); reader.update({"interact":true},0)
	check(reader.snapshot().reading and not reader.snapshot().roomComplete,"探索房阅读期间继续封门")
	var controls: PlayerControls = PlayerControls.new(reader.active)
	controls.key_down(KEY_ESCAPE)
	reader.update({},0)
	check(not reader.snapshot().reading and reader.snapshot().roomComplete,"合上残碑后探索任务完成开门")
	reader.update({"moveX":-1},0.9); reader.update({"interact":true},0)
	reader.update({"interact":false},0); reader.update({"interact":true},0)
	check(reader.snapshot().roomId=="explore" and reader.snapshot().exploration.steleRead and reader.snapshot().roomComplete,"往返保留残碑已读和房间完成状态")
	reader.update({"restart":true},0)
	check(reader.snapshot().roomId=="entry" and reader.snapshot().visitedRooms==1 and reader.snapshot().health==100,"R规则入口重开整段流程")
	var held: RefCounted = script.new({"entry":fixture("entry","safe","safe"),"safe":fixture("safe","safe","entry")})
	held.update({"interact":true},0); held.update({"interact":true},0)
	check(held.snapshot().roomId=="safe","持续按住F不能在两个安全房之间反复切换")
	var hurt_layout: Dictionary = fixture("fight","combat","entry")
	hurt_layout.encounters[0].enemies[0].x=370
	var rest: Dictionary = fixture("entry","safe","fight")
	rest.exploration=[{"id":"altar","x":500,"y":600}]
	var survivor: RefCounted = script.new({"entry":rest,"fight":hurt_layout})
	survivor.update({"interact":true},0); survivor.update({},1.0)
	for i in 150:
		if survivor.snapshot().roomComplete or survivor.snapshot().status=="failed": break
		var enemy: Dictionary = survivor.snapshot().enemies[0]
		survivor.update({"fire":true,"aim":Vector2(enemy.x,enemy.y-52)},0.02)
	var health: int = survivor.snapshot().health
	survivor.update({"interact":true},0)
	check(health>0 and health<100 and survivor.snapshot().roomId=="entry" and survivor.snapshot().health==health,"真实受伤并清敌后过门不自动回血")
	survivor.update({"moveX":1},0.9); survivor.update({"interact":true},0)
	check(survivor.snapshot().exploration.altarUsed and survivor.snapshot().health==mini(100,health+40),"祭火沿用一次恢复40并封顶")
	survivor.update({"moveX":-1},0.9); survivor.update({"interact":true},0)
	survivor.update({"interact":false},0); survivor.update({"interact":true},0)
	check(survivor.snapshot().roomId=="entry" and survivor.snapshot().exploration.altarUsed,"跨房往返不刷新已用祭火")
	finish()

func finish() -> void:
	print(JSON.stringify({"room_journey_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
