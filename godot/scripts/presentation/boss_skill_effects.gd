extends Node2D

const Rules = preload("res://scripts/combat/boss_room.gd")
const SWEEP: Texture2D = preload("res://assets/boss/thor-arena-v1/sweep.tres")
const WAKE: Texture2D = preload("res://assets/boss/thor-arena-v1/wake.tres")
const BOLT: Texture2D = preload("res://assets/boss/thor-arena-v1/bolt.tres")
const IMPACT: Texture2D = preload("res://assets/boss/thor-arena-v1/impact.tres")
var sweep: Polygon2D
var wake: Sprite2D
var previous: Dictionary = {}
var strikes: Dictionary = {}
var bursts: Array[Sprite2D] = []

func _ready() -> void:
	name="SkillEffects"
	z_as_relative=false; z_index=2000
	sweep=Polygon2D.new(); sweep.name="SwingArc"; sweep.texture=SWEEP
	var polygon: PackedVector2Array = [Vector2.ZERO]
	for i in 33:
		polygon.append(Vector2.from_angle(-Rules.SWING_HALF_ANGLE+2*Rules.SWING_HALF_ANGLE*i/32)*Rules.SWING_RADIUS)
	sweep.polygon=polygon
	var uv: PackedVector2Array = []
	for point in polygon: uv.append((point/Rules.SWING_RADIUS+Vector2.ONE)*SWEEP.get_width()/2)
	sweep.uv=uv; sweep.visible=false; add_child(sweep)
	wake=stamp("HammerWake",WAKE,Vector2(0.27,0.18))
	wake.offset=Vector2(-WAKE.get_width()*0.35,0); wake.visible=false

func stamp(label: String,texture: Texture2D,size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name=label; sprite.texture=texture; sprite.scale=size
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite,true)
	return sprite

func clear_transients() -> void:
	for sprite in bursts: sprite.free()
	bursts.clear()
	for sprite in strikes.values(): sprite.free()
	strikes.clear()
	sweep.hide(); wake.hide()

func burst(point: Vector2,now: float,tint: Color = Color.WHITE) -> void:
	var sprite: Sprite2D = stamp("Contact",IMPACT,Vector2.ONE*0.14)
	sprite.position=point; sprite.modulate=tint
	sprite.set_meta("born",now)
	bursts.append(sprite)

func update_state(state: Dictionary,hammer_position: Vector2) -> void:
	var now: float = state.elapsed
	var restart: bool = previous.is_empty() or state.runId!=previous.runId or now<previous.elapsed
	if restart: clear_transients()
	sweep.hide(); wake.hide()
	if state.boss.health<=0 or state.status!="running":
		clear_transients(); previous=state.duplicate(true); return
	var boss: Dictionary = state.boss
	if boss.phase=="swing" or (boss.phase=="swing_recover" and boss.timer>0.72):
		sweep.show(); sweep.position=Vector2(boss.x,boss.y); sweep.rotation=boss.angle
		sweep.modulate.a=1.0 if boss.phase=="swing" else clampf((boss.timer-0.72)/0.28,0,1)
	if state.vulnerable:
		var direction: Vector2 = (state.hammer.target-state.hammer.origin).normalized()
		if state.hammer.leg=="return": direction=-direction
		wake.show(); wake.position=hammer_position; wake.rotation=direction.angle()
		wake.modulate.a=0.7+0.15*sin(now*36)
	if not restart:
		if state.health<previous.health: burst(Vector2(state.player.x,state.player.y-42),now)
		if previous.boss.phase=="flight" and boss.phase=="throw_recover":
			burst(hammer_position,now,Color("ffe2a0"))
		elif state.vulnerable and previous.vulnerable and previous.hammer.leg=="out" and state.hammer.leg=="return":
			burst(hammer_position,now)
	for mark in state.lightning:
		# 由预警剩余时间／生效余量还原同一落雷时点，避免数组移位后重复播放。
		var at: float = now+mark.remaining if mark.remaining>0 else now-(0.1-mark.active)
		var key: String = "%.3f/%.3f/%.3f" % [mark.x,mark.y,at]
		if strikes.has(key): continue
		var column: Sprite2D = stamp("Lightning",BOLT,Vector2.ONE*0.36)
		column.centered=false; column.offset=Vector2(-350,-506)
		column.position=Vector2(mark.x,mark.y); column.hide()
		column.set_meta("at",at); column.set_meta("burst",false)
		strikes[key]=column
	for key in strikes.keys():
		var column: Sprite2D = strikes[key]
		var age: float = now-float(column.get_meta("at"))
		if age<0: continue
		if age>0.32: column.free(); strikes.erase(key); continue
		column.show(); column.modulate.a=1-clampf((age-0.1)/0.22,0,1)
		if not column.get_meta("burst"):
			burst(column.position,now)
			column.set_meta("burst",true)
	for i in range(bursts.size()-1,-1,-1):
		var sprite: Sprite2D = bursts[i]
		var age: float = now-float(sprite.get_meta("born"))
		if age>0.3: sprite.free(); bursts.remove_at(i); continue
		sprite.modulate.a=1-age/0.3
		sprite.scale=Vector2.ONE*lerpf(0.14,0.23,age/0.3)
	previous=state.duplicate(true)
