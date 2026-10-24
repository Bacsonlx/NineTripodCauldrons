extends RefCounted

const Stage = preload("res://scripts/journey/journey_room.gd")

func fixture(count: int = 1,seed_value: int = 1) -> Dictionary:
	var data: Dictionary = TrainingRoom.new({"spawn":Vector2(400,600),"enemy":Vector2(500,600),"encounter":Vector2(400,600)}).layout.duplicate(true)
	data.roomId="loot_test"; data.roomTitle="掉落测试"; data.objective="combat"; data.doors=[]
	data.potionDrops=true; data.dropSeed=seed_value
	for index in range(1,count): data.encounters[0].enemies.append(Vector2(500+index*40,600))
	return data

func walk_to(room: TrainingRoom,location: Vector2) -> void:
	for index in 600:
		var delta: Vector2 = location-TrainingRoom.point(room.snapshot().player)
		if delta.length()<3: return
		room.update({"moveX":delta.normalized().x,"moveY":delta.normalized().y},0.01)

func tap(room: TrainingRoom) -> void:
	room.update({},0); room.update({"interact":true},0)

func run(check: Callable) -> void:
	var room: TrainingRoom = Stage.new(fixture())
	room.update({"pierce":true,"aim":Vector2(100,548)},0.2)
	room.update({"fire":true,"aim":Vector2(1000,548)},1.4)
	var state: Dictionary = room.snapshot()
	check.call(state.status=="complete","药瓶夹具通过真实射箭完成击杀")
	check.call(state.resources.mana==88,"药瓶模式关闭击杀与清波自动回蓝")
	check.call(state.get("drops",[]).size()==1,"单怪波至少产生一瓶蓝瓶")
	if state.get("drops",[]).is_empty(): return
	check.call(state.drops[0].kind=="mana","单怪波保底是蓝瓶")
	room.update({},1)
	check.call(room.snapshot().drops==state.drops,"死亡动画和重复时间不重复掉落")
	walk_to(room,TrainingRoom.point(state.drops[0]))
	tap(room)
	check.call(room.snapshot().drops.is_empty() and room.snapshot().resources.mana==100,"F消耗整瓶蓝瓶，实际恢复12并截断至100")
	var full: TrainingRoom = Stage.new(fixture())
	full.update({"fire":true,"aim":Vector2(1000,548)},1.4)
	walk_to(full,TrainingRoom.point(full.snapshot().drops[0]))
	tap(full)
	check.call(full.snapshot().drops.size()==1 and full.snapshot().resources.mana==100,"满蓝时蓝瓶留地")
	full.update({"pierce":true,"aim":Vector2(100,548)},0)
	var skill: Dictionary = full.snapshot().skill
	tap(full)
	check.call(full.snapshot().drops.is_empty() and full.snapshot().skill==skill and full.snapshot().resources.pendingMana==12,"前摇中F即时补充，不取消技能或预扣费")
	var red: TrainingRoom = Stage.new(fixture(2,1))
	red.update({},0.65)
	red.update({},0.2)
	red.update({"pierce":true,"aim":Vector2(1000,548)},0.2)
	for index in 150:
		if red.snapshot().status!="running": break
		var live: Array = red.snapshot().enemies.filter(func(enemy: Dictionary): return enemy.phase!="dead")
		if live.is_empty(): red.update({},0.02); break
		var target: Dictionary = live[0]
		red.update({},0)
		red.update({"fire":true,"aim":Vector2(target.x,target.y-52)},0.02)
	check.call(red.snapshot().status=="complete" and red.snapshot().drops.size()==2,"两怪真实击杀生成血瓶和蓝瓶")
	if red.snapshot().drops.size()!=2: return
	check.call(red.snapshot().drops[0].kind=="health" and red.snapshot().drops[1].kind=="mana","固定种子1先掉血瓶再掉蓝瓶")
	walk_to(red,TrainingRoom.point(red.snapshot().drops[0]))
	var before_health: int = red.snapshot().health
	tap(red)
	check.call(before_health<100 and red.snapshot().health==mini(100,before_health+20),"F血瓶只恢复生命")
	var guard: TrainingRoom = Stage.new(fixture())
	guard.update({"pierce":true,"aim":Vector2(100,548)},0.2)
	guard.update({"fire":true,"aim":Vector2(1000,548)},1.4)
	walk_to(guard,TrainingRoom.point(guard.snapshot().drops[0]))
	guard.set_paused(true); tap(guard)
	check.call(guard.snapshot().drops.size()==1 and guard.snapshot().resources.mana==88,"暂停时F不能消耗药瓶")
	guard.set_paused(false); tap(guard)
	check.call(guard.snapshot().drops.is_empty(),"暂停恢复后新F能拾取")
	var door_data: Dictionary = fixture()
	door_data.roomId="entry"
	door_data.doors=[{"id":"exit","target":"other","targetDoor":"exit","title":"出口","point":Vector2(400,600),"arrival":Vector2(400,600),"x":200,"y":600,"halfWidth":10,"halfHeight":20,"height":100,"kind":"wall"}]
	var destination: Dictionary = door_data.duplicate(true)
	destination.roomId="other"; destination.objective="safe"; destination.encounters=[]
	destination.doors[0].target="entry"
	var door_run: RefCounted = load("res://scripts/journey/room_journey.gd").new({"entry":door_data,"other":destination})
	door_run.update({"alpha":{"action":"depart"}},0)
	door_run.update({"pierce":true,"aim":Vector2(100,548)},0.2)
	door_run.update({"fire":true,"aim":Vector2(1000,548)},1.4)
	walk_to(door_run.active,Vector2(400,600).lerp(TrainingRoom.point(door_run.snapshot().drops[0]),0.4))
	check.call(door_run.snapshot().interaction.has("dropId"),"可用药瓶优先于更近的门")
	door_run.update({},0); door_run.update({"interact":true},0)
	check.call(door_run.snapshot().drops.is_empty() and door_run.snapshot().roomId=="entry","单次F只捡瓶不同时过门")
	door_run.update({"interact":true},0)
	check.call(door_run.snapshot().roomId=="entry","持续按F不执行第二动作")
	door_run.update({},0); door_run.update({"interact":true},0)
	check.call(door_run.snapshot().roomId=="other","松开重新按F才过门")
	var source: Dictionary = fixture()
	source.roomId="entry"
	source.doors=door_data.doors.duplicate(true)
	source.doors[0].target="other"; source.doors[0].targetDoor="exit"
	var other: Dictionary = source.duplicate(true)
	other.roomId="other"; other.objective="safe"; other.encounters=[]
	other.doors[0].target="entry"; other.doors[0].arrival=Vector2(400,600)
	source.doors[0].arrival=Vector2(400,600)
	var journey: RefCounted = load("res://scripts/journey/room_journey.gd").new({"entry":source,"other":other})
	journey.update({"alpha":{"action":"depart"}},0)
	journey.update({"fire":true,"aim":Vector2(1000,548)},1.4)
	var stored: Array = journey.snapshot().drops
	tap(journey.active); journey.consume_transition()
	check.call(journey.snapshot().roomId=="other" and journey.snapshot().drops.is_empty(),"满蓝药瓶不挡门，药瓶不跟随玩家到下一房")
	tap(journey.active); journey.consume_transition()
	check.call(journey.snapshot().roomId=="entry" and journey.snapshot().drops==stored,"往返保留原药瓶且不重复掉落")
	journey.update({"restart":true},0)
	check.call(journey.snapshot().drops.is_empty() and journey.snapshot().visitedRooms==1,"整段R清空所有房间药瓶")
	var boss_data: Dictionary = load("res://scripts/combat/boss_room.gd").arena_layout()
	boss_data.potionDrops=true
	var boss: TrainingRoom = load("res://scripts/combat/boss_room.gd").new(boss_data)
	for frame in 9000:
		var current: Dictionary = boss.snapshot()
		if current.status!="running": break
		var offset: Vector2 = TrainingRoom.point(current.player)-TrainingRoom.point(current.boss)
		var move: Vector2 = (Vector2(-offset.y,offset.x).normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		boss.update({"moveX":move.x,"moveY":move.y,"fire":true,"aim":Vector2(current.boss.x,current.boss.y-52)},0.01)
	check.call(boss.snapshot().status=="complete" and boss.snapshot().get("rewardPlaceholders",[]).size()==2,"实际击败Boss只生成两类未入库奖励占位")
	var rewards: Array = boss.snapshot().get("rewardPlaceholders",[])
	boss.update({"fire":true},2)
	check.call(boss.snapshot().get("rewardPlaceholders",[])==rewards and boss.snapshot().drops.is_empty(),"Boss不生成药瓶，重复结算不增加奖励占位")
	for seed_value in [6,13]:
		var multi_data: Dictionary = fixture(2,seed_value)
		multi_data.encounters[0].enemies=[Vector2(650,600),Vector2(690,600)]
		var multi: TrainingRoom = Stage.new(multi_data)
		multi.update({"pierce":true,"aim":Vector2(1000,548)},0.55)
		multi.update({"rain":true,"aim":Vector2(590,600)},0.9)
		check.call(multi.snapshot().status=="complete","真实Q多目标与E三段可清空两怪波")
		if seed_value==6:
			check.call(multi.snapshot().drops.size()==1 and multi.snapshot().drops[0].guaranteed,"种子6连续不出瓶，末只只产生一瓶保底蓝瓶")
		else:
			check.call(multi.snapshot().drops.size()==2 and not multi.snapshot().drops[1].guaranteed,"种子13此前已掉蓝瓶，未拾取也不再次触发保底")
	var coarse: TrainingRoom = Stage.new(fixture())
	var fine: TrainingRoom = Stage.new(fixture())
	coarse.update({"fire":true,"aim":Vector2(1000,548)},1.4)
	for index in 140: fine.update({"fire":true,"aim":Vector2(1000,548)},0.01)
	check.call(coarse.snapshot().drops==fine.snapshot().drops,"不同外层时间步得到相同掉落与死亡点")
	var exposed: Dictionary = coarse.snapshot()
	exposed.drops[0].kind="health"
	check.call(coarse.snapshot().drops[0].kind=="mana","外部快照修改不污染地面药瓶")
