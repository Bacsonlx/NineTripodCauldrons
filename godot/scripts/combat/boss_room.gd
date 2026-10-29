extends "res://scripts/journey/journey_room.gd"

const BOSS_ID: int = 0
const MAX_HEALTH: int = 1200
const BODY_RADIUS: float = 32
const PLAYER_RADIUS: float = 12
const SWING_RADIUS: float = 180
const SWING_HALF_ANGLE: float = PI*55/180
const HAMMER_RADIUS: float = 36
const HAMMER_WARNING_WIDTH: float = (HAMMER_RADIUS+PLAYER_RADIUS)*2
const LIGHTNING_RADIUS: float = 80
const ARENA_BOUNDS: Rect2 = Rect2(96,96,1248,848)
# 340/500+340/650≈1.203秒，给任意朝向保留最小反击窗口。
const MIN_THROW_DISTANCE: float = 340
const REINFORCEMENT_LIMIT: int = 8
const REINFORCEMENT_BATCH: int = 4
const REINFORCEMENT_INTERVAL: float = 8.0
const SUMMON_WARNING: float = 1.0
const SUMMON_SAFE_DISTANCE: float = 240.0
var initial: Dictionary = {}
var elapsed: float = 0.0
var hammer: Dictionary = {}
var lightning: Array[Dictionary] = []
var lightning_index: int = 0
var reward_placeholders: Array[Dictionary] = []
var summons: Array[Dictionary] = []
var reinforcement_timer: float = 2.0
var reinforcement_batch: int = 0
var next_minion: int = 1

static func arena_layout() -> Dictionary:
	return {"width":1440,"height":1040,"spawn":Vector2(300,520),
		"roomId":"boss_test","roomTitle":"索尔独立原型","objective":"boss","doors":[],
		"floor":[Vector2.ZERO,Vector2(1440,0),Vector2(1440,1040),Vector2(0,1040)],
		"walkableAreas":[{"left":96,"top":96,"right":1344,"bottom":944}],
		"pillars":[],"pillarBody":[],"obstacles":[],"targets":[],"targetFace":{},
		"shoulderHeight":52,"grips":GRIPS,"encounters":[]}

func _init(fixture: Dictionary = {}) -> void:
	initial=fixture.duplicate(true)
	var data: Dictionary = arena_layout()
	data.merge(fixture, true)
	data.spawn=initial.get("spawn",data.spawn)
	if data.get("gameplay",false) or data.get("mode","")=="gameplay": data.potionDrops=true
	super(data)
	energy_enabled=true

func reset() -> void:
	if paused or reading: return
	super.reset()
	completed=false; requested_door=""; wave_delay=0
	invalidate_obstacles()
	health=int(initial.get("health",100)); mana=int(initial.get("mana",100))
	stamina=float(initial.get("stamina",100)); stamina_delay=float(initial.get("staminaDelay",0))
	elapsed=0
	hammer={}
	lightning.clear(); lightning_index=0
	reward_placeholders.clear()
	summons.clear(); reinforcement_timer=2.0; reinforcement_batch=0; next_minion=1
	var bounds: Rect2 = ARENA_BOUNDS.grow(-BODY_RADIUS)
	var position: Vector2 = point(initial.get("boss",Vector2(720,520))).clamp(bounds.position,bounds.end)
	enemies=[{"id":BOSS_ID,"group":-1,"boss":true,"appearance":"bird","x":position.x,"y":position.y,
		"health":MAX_HEALTH,"phase":"prepare","timer":1.2,"angle":PI,"flash":0.0,"struck":false}]

func update(input: Dictionary,seconds: float) -> void:
	if status=="failed" or (status=="complete" and layout.doors.is_empty() and not gameplay): return
	super.update(input,seconds)

func step(input: Dictionary,seconds: float) -> void:
	if status=="failed" or (status=="complete" and layout.doors.is_empty() and not gameplay): return
	super.step(input,seconds)
	if status!="running":
		hammer={}; lightning.clear(); arrows.clear(); rains.clear(); paper_arrows.clear(); summons.clear()
		if status=="complete": enemies.resize(1)

func update_enemies(seconds: float,protection_at_start: float,dodge_at_start: float) -> void:
	if status!="running": return
	elapsed+=seconds
	if gameplay:
		update_reinforcements(seconds)
		super.update_enemies(seconds,protection_at_start,dodge_at_start)
		if status!="running": return
	var boss: Dictionary = enemies[0]
	boss.flash=maxf(0,boss.flash-seconds)
	var remaining: float = seconds
	while remaining>0.0000001 and status=="running":
		var part: float = minf(remaining,boss.timer)
		if boss.phase=="throw_warn" and boss.timer>0.3500001:
			part=minf(part,boss.timer-0.35)
			boss.angle=(point(player)-point(boss)).angle()
		if boss.phase=="lightning" and lightning_index<3:
			part=minf(part,maxf(0,boss.timer-(3.4-lightning_index*0.7)))
		advance_lightning(part)
		if boss.phase=="swing" and not boss.struck:
			var delta: Vector2 = point(player)-point(boss)
			if delta.length()<=SWING_RADIUS and absf(angle_difference(boss.angle,delta.angle()))<=SWING_HALF_ANGLE:
				boss.struck=damage_player(20)
		elif boss.phase=="flight": advance_hammer(part)
		elif boss.phase in ["chase","reposition"]:
			var destination: Vector2 = point(player) if boss.phase=="chase" else keep_throw_space(point(boss))
			var gap: float = point(boss).distance_to(destination)
			var direction: Vector2 = (destination-point(boss)).normalized()
			var travel: float = minf(100*(alpha.runtime.enemy_speed(self,boss) if has_loadout_skills() else 1.0)*part,maxf(0,gap-(160 if boss.phase=="chase" else 0)))
			var bounds: Rect2 = ARENA_BOUNDS.grow(-BODY_RADIUS)
			var next: Vector2 = (point(boss)+direction*travel).clamp(bounds.position,bounds.end)
			if super.can_walk_xy(next.x,next.y): boss.x=next.x; boss.y=next.y
			if boss.phase=="chase" and point(boss).distance_to(point(player))<=160.000001: boss.timer=0
		boss.timer=maxf(0,boss.timer-part)
		remaining-=part
		if boss.phase=="lightning" and lightning_index<3 and boss.timer<=3.4-lightning_index*0.7+0.0000001:
			lightning.append({"x":player.x,"y":player.y,"remaining":1.0,"active":0.1,"struck":false})
			lightning_index+=1
		if boss.timer<=0.0000001: finish_phase()

func update_reinforcements(seconds: float) -> void:
	enemies=enemies.filter(func(enemy: Dictionary): return enemy.id==BOSS_ID or enemy.phase!="dead" or enemy.timer>0)
	# 死亡已在命中入口结算；清掉旧批次计数，不保留无限增长的尸体／保底表。
	for group in blue_waves.keys():
		if not enemies.any(func(enemy: Dictionary): return enemy.group==group) and not summons.any(func(mark: Dictionary): return mark.group==group): blue_waves.erase(group)
	for index in range(summons.size()-1,-1,-1):
		var mark: Dictionary = summons[index]
		mark.remaining=maxf(0,mark.remaining-seconds)
		if mark.remaining>0.000001: continue
		# 玩家主动走进预警点时取消此只，不能在脚下直接实体化。
		if summon_safe(point(mark)):
			enemies.append({"id":mark.id,"group":mark.group,"appearance":"bird","role":"bird",
				"x":mark.x,"y":mark.y,"health":60,"maxHealth":60,"phase":"chase","timer":0.0,
				"angle":0.0,"struck":false,"flash":0.0,"route":[],"repath":0.0,"knockX":0.0,"knockY":0.0,"knockTime":0.0})
		summons.remove_at(index)
	reinforcement_timer-=seconds
	if reinforcement_timer>0.000001: return
	reinforcement_timer+=REINFORCEMENT_INTERVAL
	var alive: int = enemies.filter(func(enemy: Dictionary): return enemy.id!=BOSS_ID and enemy.health>0).size()
	var count: int = mini(REINFORCEMENT_BATCH,REINFORCEMENT_LIMIT-alive-summons.size())
	if count<=0: return
	reinforcement_batch+=1
	for index in 16:
		if count<=0: break
		var angle: float = (index+reinforcement_batch*3)*TAU/16
		var location: Vector2 = ARENA_BOUNDS.get_center()+Vector2(cos(angle)*520,sin(angle)*320)
		if not summon_safe(location): continue
		summons.append({"id":next_minion,"group":reinforcement_batch,"x":location.x,"y":location.y,"remaining":SUMMON_WARNING})
		next_minion+=1; count-=1

func summon_safe(location: Vector2) -> bool:
	if not super.can_walk_xy(location.x,location.y) or location.distance_to(point(player))<SUMMON_SAFE_DISTANCE: return false
	if location.distance_to(point(enemies[0]))<BODY_RADIUS+32: return false
	for enemy in enemies:
		if enemy.id!=BOSS_ID and enemy.health>0 and location.distance_to(point(enemy))<36: return false
	for mark in summons:
		if location.distance_to(point(mark))>0.001 and location.distance_to(point(mark))<36: return false
	return true

func finish_phase() -> void:
	var boss: Dictionary = enemies[0]
	match boss.phase:
		"prepare","rest":
			if point(player).distance_to(point(boss))<=160:
				begin_swing()
			else: boss.phase="chase"; boss.timer=3.0
		"swing_warn": boss.phase="swing"; boss.timer=0.12
		"swing": boss.phase="swing_recover"; boss.timer=1.0
		"swing_recover","reposition": begin_throw()
		"chase":
			if point(player).distance_to(point(boss))<=160.000001: begin_swing()
			else: begin_throw()
		"throw_warn":
			var origin: Vector2 = point(boss)
			var target: Vector2 = throw_target()
			var distance: float = origin.distance_to(target)
			hammer={"x":origin.x,"y":origin.y,"origin":origin,"target":target,"leg":"out","struck":false}
			boss.phase="flight"; boss.timer=distance/500+distance/650
		"flight": hammer={}; boss.phase="throw_recover"; boss.timer=0.8
		"throw_recover": boss.phase="lightning"; boss.timer=4.0; lightning_index=0
		"lightning":
			boss.phase="rest"; boss.timer=0.0000001

func advance_lightning(seconds: float) -> void:
	var live: Array[Dictionary] = []
	for mark in lightning:
		var active_time: float = maxf(0,seconds-maxf(0,mark.remaining))
		mark.remaining=maxf(0,mark.remaining-seconds)
		if mark.remaining<=0.0000001:
			if not mark.struck and point(mark).distance_to(point(player))<=LIGHTNING_RADIUS:
				mark.struck=damage_player(15)
			mark.active=maxf(0,mark.active-active_time)
		if mark.remaining>0.0000001 or mark.active>0.0000001: live.append(mark)
	lightning=live

func begin_swing() -> void:
	var boss: Dictionary = enemies[0]
	boss.angle=(point(player)-point(boss)).angle()
	boss.phase="swing_warn"; boss.timer=0.8; boss.struck=false

func begin_throw() -> void:
	var boss: Dictionary = enemies[0]
	# 投锤前走回能容纳任意锁定方向的区域，追近时不再被此区域夹住。
	var distance: float = point(boss).distance_to(keep_throw_space(point(boss)))
	if distance>0.000001:
		boss.phase="reposition"; boss.timer=distance/100
		return
	boss.phase="throw_warn"; boss.timer=1.0
	boss.angle=(point(player)-point(boss)).angle()

func throw_target() -> Vector2:
	var boss: Dictionary = enemies[0]
	var direction: Vector2 = Vector2.from_angle(boss.angle)
	var origin: Vector2 = point(boss)
	var distance: float = 600
	var bounds: Rect2 = ARENA_BOUNDS.grow(-HAMMER_RADIUS)
	for axis in 2:
		if direction[axis]>0.000001:
			distance=minf(distance,(bounds.end[axis]-origin[axis])/direction[axis])
		elif direction[axis]<-0.000001:
			distance=minf(distance,(bounds.position[axis]-origin[axis])/direction[axis])
	return origin+direction*maxf(0,distance)

static func keep_throw_space(position: Vector2) -> Vector2:
	var bounds: Rect2 = ARENA_BOUNDS.grow(-HAMMER_RADIUS-MIN_THROW_DISTANCE)
	return position.clamp(bounds.position,bounds.end)

func advance_hammer(seconds: float) -> void:
	var remaining: float = seconds
	while remaining>0.0000001 and not hammer.is_empty():
		var from: Vector2 = point(hammer)
		var target: Vector2 = hammer.target if hammer.leg=="out" else hammer.origin
		var speed: float = 500 if hammer.leg=="out" else 650
		var part: float = minf(remaining,from.distance_to(target)/speed)
		var to: Vector2 = from.move_toward(target,speed*part)
		if not hammer.struck and segment_circle(from,to,point(player),HAMMER_RADIUS+PLAYER_RADIUS)>=0:
			hammer.struck=damage_player(20 if hammer.leg=="out" else 15)
		hammer.x=to.x; hammer.y=to.y; remaining-=part
		if to.distance_to(target)<0.000001:
			if hammer.leg=="out": hammer.leg="return"; hammer.struck=false
			else: break

func damage_player(amount: int) -> bool:
	if protection>0.000001 or dodge_invulnerability>0.000001 or status!="running": return false
	receive_hit(amount)
	return true

func can_walk_xy(x: float,y: float) -> bool:
	if not super.can_walk_xy(x,y): return false
	if enemies.is_empty() or enemies[0].health<=0 or dodge_time>0: return true
	var distance: float = Vector2(x,y).distance_to(point(enemies[0]))
	var previous: float = point(player).distance_to(point(enemies[0]))
	return distance>=BODY_RADIUS+PLAYER_RADIUS or (previous<BODY_RADIUS+PLAYER_RADIUS and distance>=previous)

func rain_target_valid(position: Vector2) -> bool:
	return super.can_walk_xy(position.x,position.y)

func impact(hit: Dictionary,kind: String,angle: float,attack: Dictionary = {}) -> void:
	if hit.get("enemy",-1)!=BOSS_ID:
		super.impact(hit,kind,angle,attack); return
	var boss: Dictionary = enemies[0]
	if boss.health<=0: return
	if boss.phase in ["swing_warn","throw_warn","prepare"]:
		if kind=="pierce" or has_spatial_synergy("推击强控") or attack.get("critical",false):
			boss.phase="prepare"; boss.timer=1.0; boss.struck=false
			feedback={"text":"破绽断招！","remaining":1.0,"healed":false}
	var damage: int = mini(boss.health,roundi(ATTACKS[kind].damage*damage_multiplier(kind,attack)*(1.25 if kind!="burn" and not hammer.is_empty() else 1.0)))
	boss.health-=damage; boss.flash=0.12; hits+=1
	apply_item_hit(boss,kind,attack)
	var effect: Dictionary = hit.duplicate()
	if has_loadout_skills(): effect.critical=attack.get("critical",false)
	effect.merge({"id":next_effect,"kind":kind,"remaining":0.15,"age":0.0,"damage":damage,
		"angle":angle,"damagePosition":point(boss)})
	effects.append(effect); next_effect+=1
	if boss.health==0:
		boss.phase="dead"; status="complete"
		summons.clear(); hammer={}; lightning.clear(); paper_arrows.clear()
		for enemy in enemies:
			if enemy.id==BOSS_ID: continue
			enemy.health=0; enemy.phase="dead"; enemy.timer=0
		if has_loadout_skills():
			alpha.kill_record(); clear_skill_effects()
			var info: Dictionary = get_divine_name_and_weakness()
			alpha.record_stele_inscription({
				"beast": alpha.blessing_beast,
				"tier": alpha.blessing_tier,
				"winner": info.winner,
				"harm": info.harm,
				"pacts": alpha.pacts.duplicate(),
				"synergies": alpha.altar_analysis.get("synergies",[]).duplicate(true),
				"time": elapsed
			})
		if potion_drops:
			reward_placeholders=[{"kind":"equipment","label":"装备 · 未入库占位","x":boss.x-32,"y":boss.y},{"kind":"item","label":"道具 · 未入库占位","x":boss.x+32,"y":boss.y}]
		cancel_pending(); arrows.clear(); rains.clear()

func contact(from: Vector2,to: Vector2,ignored: Array = []) -> Dictionary:
	var skipped: Array = ignored.duplicate()
	skipped.append(BOSS_ID)
	var hit: Dictionary = super.contact(from,to,skipped)
	if enemies.is_empty() or enemies[0].health<=0 or ignored.has(BOSS_ID): return hit
	var center: Vector2 = point(enemies[0])-Vector2(0,52)
	var distance: float = segment_circle(from,to,center,40)
	if distance>=0 and (hit.is_empty() or from.distance_to(from.lerp(to,distance))<from.distance_to(point(hit))):
		var location: Vector2 = from.lerp(to,distance)
		return {"x":location.x,"y":location.y,"target":null,"enemy":BOSS_ID}
	return hit

static func segment_circle(from: Vector2,to: Vector2,center: Vector2,radius: float) -> float:
	var origin: Vector2 = from-center
	if origin.length_squared()<=radius*radius: return 0
	var delta: Vector2 = to-from
	var a: float = delta.length_squared()
	var b: float = 2*origin.dot(delta)
	var discriminant: float = b*b-4*a*(origin.length_squared()-radius*radius)
	if a==0 or discriminant<0: return -1
	var entry: float = (-b-sqrt(discriminant))/(2*a)
	return entry if entry>=0 and entry<=1 else -1

func get_divine_name_and_weakness() -> Dictionary:
	var winner: String = ""
	var harm: String = ""
	if alpha!=null and alpha.ranking.has("winner"):
		winner=alpha.ranking.get("winner","")
		harm=alpha.ranking.get("harm","")
	var titles: Dictionary = {
		"木": {"name": "古神念名 · 岁木神君", "weakness": "弱点：惧雷刑贯通，以穿透箭或强控可断其招"},
		"火": {"name": "古神念名 · 祝融之残", "weakness": "弱点：惧水沉冰熄，以闪避引雷可断其招"},
		"金": {"name": "古神念名 · 白帝之刃", "weakness": "弱点：惧火焚熔金，以暴击推击可断其招"},
		"雷": {"name": "古神念名 · 震天神将", "weakness": "弱点：惧木祠生发，以神兽风道可断其招"},
		"场": {"name": "古神念名 · 破阵斗煞", "weakness": "弱点：惧塔镇锁气，以穿透箭击破绽可断其招"},
		"水": {"name": "古神念名 · 玄冥之魄", "weakness": "弱点：惧土葬重岳，以强力击退可断其招"},
		"土": {"name": "古神念名 · 后土残魂", "weakness": "弱点：惧木根破隙，以箭雨震地可断其招"},
		"塔": {"name": "古神念名 · 锁魔铜尊", "weakness": "弱点：惧场斗碎甲，以连续射击可断其招"},
		"镜": {"name": "古神念名 · 幻照影神", "weakness": "弱点：惧草野伏击，以近身破隙可断其招"},
		"草": {"name": "古神念名 · 幽野荒魂", "weakness": "弱点：惧明镜鉴破，以穿透箭直指心核可断其招"}
	}
	var default_entry: Dictionary = {"name": "古神念名 · 雷庭索尔", "weakness": "弱点：横锤与投锤前摇破绽，以穿透箭或推击可断其蓄力"}
	var entry: Dictionary = titles.get(winner, default_entry)
	return {
		"divineName": entry.name,
		"weakness": entry.weakness,
		"winner": winner,
		"harm": harm
	}

func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.enemies=data.enemies.filter(func(enemy: Dictionary): return enemy.id!=BOSS_ID)
	data.summons=summons.duplicate(true)
	if not enemies.is_empty(): data.boss=enemies[0].duplicate(true)
	data.elapsed=elapsed
	data.hammer=hammer.duplicate(true)
	data.lightning=lightning.duplicate(true)
	data.vulnerable=not hammer.is_empty()
	data.throwTarget=throw_target() if not enemies.is_empty() else Vector2.ZERO
	var divine_info: Dictionary = get_divine_name_and_weakness()
	data.bossDivineName=divine_info.divineName
	data.bossWeakness=divine_info.weakness
	if potion_drops: data.rewardPlaceholders=reward_placeholders.duplicate(true)
	return data
