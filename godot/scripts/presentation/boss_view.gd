extends Node2D

const Rules = preload("res://scripts/combat/boss_room.gd")
var state: Dictionary = {}
var character: Node2D

func _ready() -> void:
	var floor: Node2D = preload("res://scripts/presentation/boss_floor.gd").new()
	floor.name="Floor"; floor.z_as_relative=false; floor.z_index=-1000
	add_child(floor)

func setup(_layout: Dictionary,_atlas: Dictionary,_textures: Dictionary) -> void:
	z_index=-100

func update(snapshot: Dictionary,_clock: float) -> void:
	state=snapshot
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	var boss: Dictionary = state.boss
	var center: Vector2 = Vector2(boss.x,boss.y)
	var direction: Vector2 = Vector2.from_angle(boss.angle)
	if boss.phase in ["swing_warn","swing"]:
		var sector: PackedVector2Array = [center]
		for i in 25: sector.append(center+Vector2.from_angle(boss.angle-Rules.SWING_HALF_ANGLE+2*Rules.SWING_HALF_ANGLE*i/24)*Rules.SWING_RADIUS)
		draw_colored_polygon(sector,Color(1,0.44,0.18,0.65 if boss.phase=="swing" else 0.25))
		draw_polyline(sector,Color("f6b96c"),2)
	if boss.phase=="throw_warn":
		draw_line(center,state.throwTarget,Color(0.4,0.8,1,0.22),Rules.HAMMER_WARNING_WIDTH)
		draw_line(center,state.throwTarget,Color("a1dce9"),2)
		draw_circle(state.throwTarget,12,Color("e3faff"),false,2)
	for mark in state.lightning:
		var point: Vector2 = Vector2(mark.x,mark.y)
		draw_circle(point,Rules.LIGHTNING_RADIUS,Color(0.4,0.8,1,0.20 if mark.remaining>0 else 0.75))
		draw_arc(point,Rules.LIGHTNING_RADIUS,-PI/2,-PI/2+TAU*(1-mark.remaining),48,Color("bef4ff"),3)
		if mark.remaining<=0: draw_line(point,point-Vector2(0,180),Color("f1feff"),9)
	if state.vulnerable:
		draw_arc(center-Vector2(0,65),48,0,TAU,32,Color("ffd280"),4)
		draw_line(state.hammer.origin,state.hammer.target,Color(0.5,0.8,1,0.12),Rules.HAMMER_WARNING_WIDTH)
		draw_circle(Vector2(state.hammer.x,state.hammer.y),Rules.HAMMER_RADIUS,Color(0.6,0.9,1,0.3))
	if character!=null: return
	if boss.health<=0: return
	draw_circle(center,Rules.BODY_RADIUS,Color("161c20"))
	draw_circle(center,Rules.BODY_RADIUS,Color("aa9676"),false,2)
	var body_color: Color = Color("fff1c2") if boss.flash>0 else Color("77828a")
	draw_rect(Rect2(center-Vector2(32,110),Vector2(64,96)),body_color)
	draw_circle(center-Vector2(0,128),20,body_color)
	draw_line(center-Vector2(20,90),center+Vector2(16,-20),Color("9a3e39"),12)
	if state.vulnerable:
		var hammer: Vector2 = Vector2(state.hammer.x,state.hammer.y)
		draw_rect(Rect2(hammer-Vector2(24,18),Vector2(48,36)),Color("c4d8db"))
	else:
		var hand: Vector2 = center+direction*50-Vector2(0,60)
		if boss.phase in ["swing_warn","throw_warn"]: hand-=Vector2(0,50)
		draw_line(center-Vector2(0,70),hand,body_color,10)
		draw_rect(Rect2(hand-Vector2(24,18),Vector2(48,36)),Color("c4d8db"))
