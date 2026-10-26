extends RefCounted

func run(check: Callable) -> void:
	var script: Script = load("res://scripts/combat/boss_room.gd")
	check.call(script!=null,"B01：独立Boss规则可加载")
	if script==null: return
	var room: TrainingRoom = script.new({"mana":0})
	room.update({"fire":true,"aim":Vector2(720,468)},0.8)
	check.call(room.snapshot().boss.health<1200 and room.snapshot().resources.mana==0,"B01：零蓝普攻真实命中Boss，不产生击杀或清波回蓝")
	var near: TrainingRoom = script.new({"spawn":Vector2(600,520)})
	near.update({},2.02)
	check.call(near.snapshot().health==80,"B02：1.2秒准备加0.8秒锁向预告后，横锤造成20伤害")
	near.update({},0.09)
	check.call(near.snapshot().health==80,"B02：横锤有效期内不会逐帧重复扣血")
	var avoid: TrainingRoom = script.new({"spawn":Vector2(600,520)})
	avoid.update({},1.21)
	var locked: float = avoid.snapshot().boss.angle
	avoid.update({"moveY":-1},0.9)
	check.call(avoid.snapshot().health==100 and is_equal_approx(avoid.snapshot().boss.angle,locked),"B02：预告锁向后可通过横向走位躲开，不追踪转向")
	var frozen: Dictionary = avoid.snapshot()
	avoid.set_paused(true); avoid.update({},5)
	check.call(avoid.snapshot().boss==frozen.boss and avoid.snapshot().elapsed==frozen.elapsed,"B02：暂停冻结Boss预告和规则时间")
	var thrower: TrainingRoom = throw_room(script)
	check.call(thrower.snapshot().get("vulnerable",false) and not thrower.snapshot().get("hammer",{}).is_empty(),"B03：远距离追近后掷锤，离手立即开启破绽并只有一个飞锤")
	thrower.update({"pierce":true,"aim":Vector2(720,468)},0.7)
	check.call(thrower.snapshot().boss.health==1150,"B03：破绽内Q实际造成50伤害")
	var rain: TrainingRoom = throw_room(script)
	rain.update({"rain":true,"aim":Vector2(720,520)},0.85)
	check.call(rain.snapshot().boss.health==1143,"B03：破绽内E逐段19伤，共57伤害")
	var normal: TrainingRoom = throw_room(script,{"mana":0})
	normal.update({"fire":true,"aim":Vector2(720,468)},0.1)
	normal.update({},0.6)
	check.call(normal.snapshot().boss.health==1181,"B03：破绽内普通箭四舍五入为19伤害")
	thrower.update({},1.5)
	check.call(not thrower.snapshot().get("vulnerable",true) and thrower.snapshot().get("hammer",{}).is_empty(),"B03：接锤关闭破绽并清除飞锤")
	var storm: TrainingRoom = script.new({"boss":Vector2(1000,520)})
	storm.update({"moveY":-1},0.4)
	advance_until(storm,"lightning")
	storm.update({},0.61)
	var marks: Array = storm.snapshot().get("lightning",[])
	var before_storm: int = storm.snapshot().health
	check.call(marks.size()==1 and not marks[0].get("struck",false),"B04：掷锤收招后落雷逐点记录位置，落点预告一秒")
	if not marks.is_empty():
		var mark: Vector2 = Vector2(marks[0].x,marks[0].y)
		storm.update({"moveY":1},0.3)
		check.call(Vector2(storm.snapshot().lightning[0].x,storm.snapshot().lightning[0].y)==mark,"B04：已记录的落点不追踪玩家")
		storm.update({"moveX":1},1.9)
		check.call(storm.snapshot().health==before_storm,"B04：普通走位可避开三点落雷，不必消耗闪避")
	var long_step: TrainingRoom = script.new()
	var short_step: TrainingRoom = script.new()
	long_step.update({},8)
	for i in 800: short_step.update({},0.01)
	check.call(long_step.snapshot().health==short_step.snapshot().health and long_step.snapshot().boss==short_step.snapshot().boss and long_step.snapshot().lightning==short_step.snapshot().lightning,"B04：长时间推进与短步得到相同招式、落点和伤害")
	var retry: TrainingRoom = script.new({"mana":44,"stamina":0,"staminaDelay":1.2})
	retry.update({},2.3); retry.reset()
	check.call(retry.snapshot().boss.health==1200 and retry.snapshot().hammer.is_empty() and retry.snapshot().lightning.is_empty() and retry.snapshot().resources.mana==44 and retry.snapshot().resources.stamina==0,"B04：重试清理威胁并恢复测试夹具，不擅自补满资源")
	var duel: TrainingRoom = script.new({"mana":0})
	var phases: Dictionary = {}
	for frame in 9000:
		var state: Dictionary = duel.snapshot()
		if state.status!="running": break
		phases[state.boss.phase]=true
		var offset: Vector2 = Vector2(state.player.x-state.boss.x,state.player.y-state.boss.y)
		var movement: Vector2 = (Vector2(-offset.y,offset.x).normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		duel.update({"moveX":movement.x,"moveY":movement.y,"fire":true,"aim":Vector2(state.boss.x,state.boss.y-52)},0.01)
	check.call(duel.snapshot().status=="complete" and duel.snapshot().resources.mana==0,"B04：零蓝通过普通移动与普攻真实击败Boss，无额外回蓝")
	check.call(phases.has("flight") and phases.has("lightning"),"B04：真实击败轨迹经过掷锤与落雷循环")
	check.call(duel.snapshot().hammer.is_empty() and duel.snapshot().lightning.is_empty() and duel.snapshot().arrows.is_empty(),"B04：最后一击立刻清除所有残留威胁和弹道")
	var settled: Dictionary = duel.snapshot()
	duel.update({"fire":true},3)
	check.call(duel.snapshot()==settled,"B04：胜利只结算一次，完成后时钟和输入不再推进战斗")
	var overlap: TrainingRoom = script.new({"spawn":Vector2(580,520)})
	overlap.update({"dodge":true,"moveX":1},0.2)
	overlap.update({"moveX":-1},0.2)
	check.call(overlap.snapshot().player.x<680,"闪避终点与Boss身体重叠后仍可走出，不会卡死")
	var crossing: TrainingRoom = throw_room(script)
	crossing.update({"moveY":-1},0.5); crossing.update({},0.98)
	crossing.update({"rain":true,"aim":Vector2(720,520)},0.9)
	check.call(crossing.snapshot().boss.health==1151,"箭雨跨接锤边界时按每段发生时点结算19、15、15伤害")
	var double_hit: TrainingRoom = throw_room(script)
	double_hit.update({},2.2)
	check.call(double_hit.snapshot().health==65,"雷锤同一去程只伤20一次，回程最多另伤15，遵守受击保护")
	var defeated: TrainingRoom = throw_room(script,{"health":20})
	defeated.update({},2.2)
	check.call(defeated.snapshot().status=="failed" and defeated.snapshot().hammer.is_empty() and defeated.snapshot().lightning.is_empty(),"玩家失败时清理残留威胁，停止规则推进")
	var lock: TrainingRoom = script.new({"boss":Vector2(1000,520)})
	advance_until(lock,"throw_warn"); lock.update({},0.66)
	var direction: float = lock.snapshot().boss.angle
	lock.update({"moveY":-1},0.3)
	check.call(is_equal_approx(lock.snapshot().boss.angle,direction),"掷锤最后0.35秒锁向，不再追踪玩家")
	var boundary_in: TrainingRoom = script.new({"spawn":Vector2(600,520)})
	boundary_in.update({},1.21); boundary_in.update({"moveX":-1},0.26); boundary_in.update({},0.64)
	var boundary_out: TrainingRoom = script.new({"spawn":Vector2(600,520)})
	boundary_out.update({},1.21); boundary_out.update({"moveX":-1},0.29); boundary_out.update({},0.61)
	check.call(boundary_in.snapshot().health==80 and boundary_out.snapshot().health==100,"横锤半径180内命中、范围外不伤害")
	var edge: TrainingRoom = script.new({"spawn":Vector2(108,520),"boss":Vector2(200,520)})
	var shortest: float = INF
	for frame in 1800:
		var state: Dictionary = edge.snapshot()
		if state.status!="running": break
		if state.vulnerable:
			var length: float = state.hammer.origin.distance_to(state.hammer.target)
			shortest=minf(shortest,length/500+length/650)
		edge.update({},0.01)
	check.call(shortest>=1.2 and shortest<INF,"贴边站位仍保持至少1.2秒离手窗口，不靠改变飞锤速度补偿")

func advance_until(room: TrainingRoom,phase: String) -> void:
	for frame in 3000:
		var state: Dictionary = room.snapshot()
		if state.boss.phase==phase or state.status!="running": return
		room.update({},0.01)

func throw_room(script: Script,options: Dictionary = {}) -> TrainingRoom:
	options=options.duplicate()
	options.boss=Vector2(1000,520)
	var room: TrainingRoom = script.new(options)
	advance_until(room,"flight")
	return room
