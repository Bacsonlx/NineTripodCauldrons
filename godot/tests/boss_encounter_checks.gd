extends RefCounted

const Boss = preload("res://scripts/combat/boss_room.gd")

func run(check: Callable) -> void:
	var room: TrainingRoom = Boss.new({"spawn":Vector2(300,200)})
	var origin: Vector2 = TrainingRoom.point(room.snapshot().boss)
	room.update({},2.2)
	var state: Dictionary = room.snapshot()
	check.call(TrainingRoom.point(state.boss).distance_to(origin)>90 and state.boss.y<472,"Boss远距离开场主动追近，能离开旧中央狭长区域")
	var frozen: Dictionary = room.snapshot()
	room.set_paused(true); room.update({},3)
	check.call(room.snapshot().boss==frozen.boss and room.snapshot().elapsed==frozen.elapsed,"Boss主动追近受暂停冻结")
	var data: Dictionary = Boss.arena_layout()
	data.gameplay=true; data.potionDrops=true; data.dropSeed=1; data.health=10000; data.mana=40
	var battle: TrainingRoom = Boss.new(data)
	battle.update({},2.01)
	state=battle.snapshot()
	check.call(state.get("summons",[]).size()==4 and state.enemies.is_empty(),"Boss首批四怪先预警一秒，预警期间尚无可攻击实体")
	battle.update({},1.0)
	state=battle.snapshot()
	check.call(state.enemies.size()==4,"Boss开战三秒后首批四只近战小怪入场")
	if state.enemies.size()!=4: return
	var first_ids: Array = state.enemies.map(func(enemy: Dictionary): return enemy.id)
	check.call(state.enemies.all(func(enemy: Dictionary): return enemy.id!=0 and enemy.group==1 and TrainingRoom.point(enemy).distance_to(TrainingRoom.point(state.player))>=238),"小怪独立编号和批次，出生避开玩家身边")
	battle.update({},8.0)
	state=battle.snapshot()
	check.call(state.enemies.size()==8,"首批八秒后补四只，上限八只不包含Boss")
	battle.update({},16.0)
	check.call(battle.snapshot().enemies.size()==8 and battle.snapshot().get("summons",[]).is_empty(),"达到上限后跳过补怪，不积攒预警或突破上限")
	frozen=battle.snapshot(); battle.set_paused(true); battle.update({},20)
	check.call(battle.snapshot().enemies==frozen.enemies and battle.snapshot().get("summons",[])==frozen.get("summons",[]),"暂停同时冻结小怪与召怪时钟")
	battle.set_paused(false); battle.reset()
	check.call(battle.snapshot().enemies.is_empty() and battle.snapshot().get("summons",[]).is_empty() and battle.snapshot().drops.is_empty(),"重开清空小怪、预警与药囊")
	battle.update({},3.01)
	check.call(battle.snapshot().enemies.map(func(enemy: Dictionary): return enemy.id)==first_ids,"固定种子重试重新按同一批次编号生成，不残留旧怪")

	var first_batch: Array = first_ids.duplicate()
	shoot_batch(battle,first_batch)
	state=battle.snapshot()
	check.call(not state.enemies.any(func(enemy: Dictionary): return first_batch.has(enemy.id) and enemy.health>0),"普通箭真实击杀首批小怪，尸体不会重复结算")
	check.call(state.drops.any(func(item: Dictionary): return item.kind=="health") and state.drops.any(func(item: Dictionary): return item.kind=="mana" and item.wave==1),"固定种子下Boss小怪真实掉血囊、蓝囊，首批享有独立蓝囊保底")
	var drop_ids: Dictionary = {}
	for item in state.drops: drop_ids[item.id]=true
	check.call(drop_ids.size()==state.drops.size() and state.resources.mana==40,"击杀不叠加旧自动回蓝，药囊独立留地")
	for frame in 12000:
		state=battle.snapshot()
		if state.status!="running": break
		var offset: Vector2 = TrainingRoom.point(state.player)-TrainingRoom.point(state.boss)
		var move: Vector2 = (offset.orthogonal().normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		battle.update({"moveX":move.x,"moveY":move.y,"fire":state.hurt<=0,"aim":TrainingRoom.point(state.boss)-Vector2(0,52)},0.01)
	state=battle.snapshot()
	check.call(state.boss.health==0 and state.status=="complete" and state.enemies.is_empty() and state.summons.is_empty() and state.hammer.is_empty() and state.lightning.is_empty(),"真实击败Boss立即清掉小怪、预警和威胁，不要求清怪才完成")
	var settled_drops: Array = state.drops.duplicate(true)
	battle.update({},20)
	check.call(battle.snapshot().drops==settled_drops and battle.snapshot().enemies.is_empty(),"消散小怪不额外掉落，战后停止补怪并保留已有药囊")
	var mana_drops: Array = settled_drops.filter(func(item: Dictionary): return item.kind=="mana")
	if not mana_drops.is_empty():
		var destination: Vector2 = TrainingRoom.point(mana_drops[0])
		for frame in 1200:
			var delta: Vector2 = destination-TrainingRoom.point(battle.snapshot().player)
			if delta.length()<3: break
			battle.update({"moveX":delta.normalized().x,"moveY":delta.normalized().y},0.01)
		var mana: int = battle.snapshot().resources.mana
		var count: int = battle.snapshot().drops.size()
		battle.update({},0); battle.update({"interact":true},0)
		check.call(battle.snapshot().resources.mana==mini(100,mana+20) and battle.snapshot().drops.size()==count-1,"战后仍可实际走近按F拾取蓝囊，恢复20且不再刷怪")

	data.dropSeed=6
	var guaranteed: TrainingRoom = Boss.new(data)
	guaranteed.update({},3.01)
	var ids: Array = guaranteed.snapshot().enemies.map(func(enemy: Dictionary): return enemy.id)
	shoot_batch(guaranteed,ids)
	var potions: Array = guaranteed.snapshot().drops.filter(func(item: Dictionary): return item.wave==1)
	check.call(potions.size()==1 and potions[0].kind=="mana" and potions[0].guaranteed,"种子6前四次均为无掉落，末只独立强制一个蓝囊，存活Boss不阻塞保底")

func shoot_batch(room: TrainingRoom,ids: Array) -> void:
	for frame in 1000:
		var state: Dictionary = room.snapshot()
		var live: Array = state.enemies.filter(func(enemy: Dictionary): return ids.has(enemy.id) and enemy.health>0)
		if live.is_empty(): return
		var target: Vector2 = TrainingRoom.point(live[0])-Vector2(0,52)
		var offset: Vector2 = TrainingRoom.point(state.player)-TrainingRoom.point(state.boss)
		var move: Vector2 = (offset.orthogonal().normalized()+offset.normalized()*(420-offset.length())/100).limit_length()
		room.update({"moveX":move.x,"moveY":move.y,"fire":state.hurt<=0,"aim":target},0.02)
