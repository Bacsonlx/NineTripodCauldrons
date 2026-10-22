extends "res://scripts/combat/training_room.gd"

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
var initial: Dictionary = {}
var elapsed: float = 0.0
var hammer: Dictionary = {}
var lightning: Array[Dictionary] = []
var lightning_index: int = 0

static func arena_layout() -> Dictionary:
	return {"width":1440,"height":1040,"spawn":Vector2(300,520),
		"floor":[Vector2.ZERO,Vector2(1440,0),Vector2(1440,1040),Vector2(0,1040)],
		"walkableAreas":[{"left":96,"top":96,"right":1344,"bottom":944}],
		"pillars":[],"pillarBody":[],"obstacles":[],"targets":[],"targetFace":{},
		"shoulderHeight":52,"grips":GRIPS,"encounters":[]}

func _init(fixture: Dictionary = {}) -> void:
	initial=fixture.duplicate(true)
	var data: Dictionary = arena_layout()
	data.spawn=initial.get("spawn",data.spawn)
	super(data)
	energy_enabled=true

func reset() -> void:
	if paused or reading: return
	super.reset()
	health=int(initial.get("health",100)); mana=int(initial.get("mana",100))
	stamina=float(initial.get("stamina",100)); stamina_delay=float(initial.get("staminaDelay",0))
	elapsed=0
	hammer={}
	lightning.clear(); lightning_index=0
	var position: Vector2 = keep_throw_space(point(initial.get("boss",Vector2(720,520))))
	enemies=[{"id":BOSS_ID,"group":0,"appearance":"bird","x":position.x,"y":position.y,
		"health":MAX_HEALTH,"phase":"prepare","timer":1.2,"angle":PI,"flash":0.0,"struck":false}]

func update(input: Dictionary,seconds: float) -> void:
	if status!="running": return
	super.update(input,seconds)

func step(input: Dictionary,seconds: float) -> void:
	if status!="running": return
	super.step(input,seconds)
	if status!="running":
		hammer={}; lightning.clear(); arrows.clear(); rains.clear()

func update_enemies(seconds: float,_protection: float,_dodge: float) -> void:
	elapsed+=seconds
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
		elif boss.phase=="chase":
			var direction: Vector2 = (point(player)-point(boss)).normalized()
			var next: Vector2 = keep_throw_space(point(boss)+direction*minf(100*part,maxf(0,point(player).distance_to(point(boss))-BODY_RADIUS-PLAYER_RADIUS)))
			if super.can_walk_xy(next.x,next.y): boss.x=next.x; boss.y=next.y
		boss.timer=maxf(0,boss.timer-part)
		remaining-=part
		if boss.phase=="lightning" and lightning_index<3 and boss.timer<=3.4-lightning_index*0.7+0.0000001:
			lightning.append({"x":player.x,"y":player.y,"remaining":1.0,"active":0.1,"struck":false})
			lightning_index+=1
		if boss.timer<=0.0000001: finish_phase()

func finish_phase() -> void:
	var boss: Dictionary = enemies[0]
	match boss.phase:
		"prepare","rest":
			if point(player).distance_to(point(boss))<=160:
				boss.angle=(point(player)-point(boss)).angle()
				boss.phase="swing_warn"; boss.timer=0.8; boss.struck=false
			else: begin_throw()
		"swing_warn": boss.phase="swing"; boss.timer=0.12
		"swing": boss.phase="swing_recover"; boss.timer=1.0
		"swing_recover": boss.phase="chase"; boss.timer=1.5
		"chase": begin_throw()
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

func begin_throw() -> void:
	var boss: Dictionary = enemies[0]
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
	health=maxi(0,health-amount); hurt=0.12; protection=0.6
	cancel_pending(); needs_release=true
	if health==0:
		status="failed"; player.moving=false
	return true

func can_walk_xy(x: float,y: float) -> bool:
	if not super.can_walk_xy(x,y): return false
	if enemies.is_empty() or enemies[0].health<=0 or dodge_time>0: return true
	var distance: float = Vector2(x,y).distance_to(point(enemies[0]))
	var previous: float = point(player).distance_to(point(enemies[0]))
	return distance>=BODY_RADIUS+PLAYER_RADIUS or (previous<BODY_RADIUS+PLAYER_RADIUS and distance>=previous)

func rain_target_valid(position: Vector2) -> bool:
	return super.can_walk_xy(position.x,position.y)

func impact(hit: Dictionary,kind: String,angle: float) -> void:
	if hit.get("enemy",-1)!=BOSS_ID:
		super.impact(hit,kind,angle); return
	var boss: Dictionary = enemies[0]
	if boss.health<=0: return
	var damage: int = mini(boss.health,roundi(ATTACKS[kind].damage*(1.25 if not hammer.is_empty() else 1.0)))
	boss.health-=damage; boss.flash=0.12; hits+=1
	var effect: Dictionary = hit.duplicate()
	effect.merge({"id":next_effect,"kind":kind,"remaining":0.15,"age":0.0,"damage":damage,
		"angle":angle,"damagePosition":point(boss)})
	effects.append(effect); next_effect+=1
	if boss.health==0:
		boss.phase="dead"; status="complete"
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

func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.enemies=[]
	if not enemies.is_empty(): data.boss=enemies[0].duplicate(true)
	data.elapsed=elapsed
	data.hammer=hammer.duplicate(true)
	data.lightning=lightning.duplicate(true)
	data.vulnerable=not hammer.is_empty()
	data.throwTarget=throw_target() if not enemies.is_empty() else Vector2.ZERO
	return data
