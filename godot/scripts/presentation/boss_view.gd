extends Node2D

const Rules = preload("res://scripts/combat/boss_room.gd")
var state: Dictionary = {}
var character: Node2D
var standalone_environment: bool = true
var skill_effects: Node2D

func _ready() -> void:
	var floor: Node2D = preload("res://scripts/presentation/boss_floor.gd").new()
	floor.standalone_environment=standalone_environment
	floor.name="Floor"; floor.z_as_relative=false; floor.z_index=-1000
	add_child(floor)
	skill_effects=preload("res://scripts/presentation/boss_skill_effects.gd").new()
	add_child(skill_effects)

func setup(_layout: Dictionary,_atlas: Dictionary,_textures: Dictionary) -> void:
	z_index=-100

func update(snapshot: Dictionary,_clock: float) -> void:
	state=snapshot
	var hammer_position: Vector2 = Vector2(snapshot.boss.x,snapshot.boss.y-60)
	if snapshot.vulnerable: hammer_position=Vector2(snapshot.hammer.x,snapshot.hammer.y-60)
	if character!=null and character.has_node("hammer"):
		hammer_position=character.get_node("hammer").global_position
	skill_effects.update_state(snapshot,hammer_position)
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	var boss: Dictionary = state.boss
	var center: Vector2 = Vector2(boss.x,boss.y)
	var direction: Vector2 = Vector2.from_angle(boss.angle)
	if boss.phase in ["swing_warn","swing"]:
		var sector: PackedVector2Array = [center]
		for i in 25: sector.append(center+Vector2.from_angle(boss.angle-Rules.SWING_HALF_ANGLE+2*Rules.SWING_HALF_ANGLE*i/24)*Rules.SWING_RADIUS)
		var progress: float = 1-boss.timer/0.8 if boss.phase=="swing_warn" else 1.0
		draw_colored_polygon(sector,Color(1,0.44,0.18,0.12+progress*0.16))
		sector.append(center)
		draw_polyline(sector,Color("f6b96c"),2.5,true)
		draw_arc(center,Rules.SWING_RADIUS-7,boss.angle-Rules.SWING_HALF_ANGLE,boss.angle-Rules.SWING_HALF_ANGLE+2*Rules.SWING_HALF_ANGLE*progress,32,Color("ffe4a2"),3,true)
	if boss.phase=="throw_warn":
		draw_hammer_lane(center,state.throwTarget,false,boss.timer<=0.35)
	for mark in state.lightning:
		var point: Vector2 = Vector2(mark.x,mark.y)
		var progress: float = 1-clampf(mark.remaining,0,1)
		draw_circle(point,Rules.LIGHTNING_RADIUS,Color(0.3,0.7,1,0.12+progress*0.13))
		draw_arc(point,Rules.LIGHTNING_RADIUS,0,TAU,64,Color("88cbe7"),2,true)
		draw_arc(point,Rules.LIGHTNING_RADIUS-6,-PI/2,-PI/2+TAU*progress,64,Color("e3faff"),3,true)
		for i in 8:
			var ray: Vector2 = Vector2.from_angle(i*TAU/8)
			draw_line(point+ray*52,point+ray*61,Color("88cbe7"),2,true)
		draw_polyline(PackedVector2Array([point+Vector2(4,-19),point+Vector2(-8,1),point+Vector2(7,-1),point+Vector2(-4,19)]),Color("d4efff"),2,true)
	if state.vulnerable:
		draw_arc(center-Vector2(0,65),48,0,TAU,32,Color("ffd280"),4)
		draw_hammer_lane(state.hammer.origin,state.hammer.target,state.hammer.leg=="return",true)
		draw_circle(Vector2(state.hammer.x,state.hammer.y),Rules.HAMMER_RADIUS,Color(0.6,0.9,1,0.13))
		draw_arc(Vector2(state.hammer.x,state.hammer.y),Rules.HAMMER_RADIUS,0,TAU,32,Color("d4efff"),1.5,true)
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

func draw_hammer_lane(origin: Vector2,target: Vector2,returning: bool,locked: bool) -> void:
	var direction: Vector2 = (target-origin).normalized()
	var side: Vector2 = direction.orthogonal()*Rules.HAMMER_WARNING_WIDTH/2
	var tint: Color = Color("ffe0a0") if returning else Color("b8e9ff") if locked else Color("71badb")
	draw_colored_polygon(PackedVector2Array([origin+side,target+side,target-side,origin-side]),Color(tint,0.1 if state.vulnerable else 0.18))
	draw_line(origin+side,target+side,Color(tint,0.7),2,true)
	draw_line(origin-side,target-side,Color(tint,0.7),2,true)
	var travel: Vector2 = -direction if returning else direction
	var start: Vector2 = target if returning else origin
	for i in range(1,int(origin.distance_to(target)/72)):
		var point: Vector2 = start+travel*(i*72+fmod(state.elapsed*70,48))
		draw_polyline(PackedVector2Array([point-travel*9+travel.orthogonal()*8,point,point-travel*9-travel.orthogonal()*8]),Color(tint,0.7),2,true)
	draw_arc(target,12,0,TAU,20,tint,2,true)
