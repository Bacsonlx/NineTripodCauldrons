extends Node2D
## 移动选下肢，瞄准选上身；未覆盖方向独立回退，规则负责全部时序。

const Frames = preload("res://scripts/presentation/action_frame_sprite.gd")
var lower: Sprite2D
var upper: Sprite2D
var body: Sprite2D
var distance: float = 0.0
var previous_point: Vector2 = Vector2.ZERO
var generation: int = -1

func _ready() -> void:
	lower=Frames.new(); lower.name="Lower"; add_child(lower)
	upper=Frames.new(); upper.name="Upper"; upper.z_index=1; add_child(upper)
	body=Frames.new(); body.name="Body"; add_child(body)
	reset_pose()

func reset_pose() -> void:
	generation=-1; distance=0
	lower.hide(); upper.hide(); body.hide()

func update_state(state: Dictionary,movement: Vector2,attack_remaining: float,bob: float = 0.0) -> void:
	var p: Dictionary = state.player
	var point: Vector2 = Vector2(p.x,p.y)
	if generation!=state.runId:
		distance=0; generation=state.runId; previous_point=point
	if not state.paused and state.status!="failed": distance+=point.distance_to(previous_point)
	previous_point=point
	position=point+Vector2(0,bob); z_index=int(point.y)
	if state.status=="failed" or state.hurt>0:
		lower.hide(); upper.hide(); body.hide(); return
	if state.paused: return
	lower.hide(); upper.hide(); body.hide()
	var dashing: bool = state.dodge>0 or state.get("skillDash",{}).get("remaining",0)>0
	if dashing:
		var dash_direction: Vector2 = state.dodgeDirection if state.dodge>0 else state.skillDash.direction
		if absf(dash_direction.angle())>PI/4: return
		var remaining: float = state.dodge if state.dodge>0 else state.skillDash.remaining
		body.sample("hero-dodge",clampi(int((0.2-remaining)/0.2*8),0,7)); body.show()
		return
	var move_facing: int = posmod(floori(movement.angle()/(PI/2)+0.5),4)
	if p.moving and move_facing==0:
		lower.sample("hero-run-lower",int(distance/22.0)%8)
		lower.position=Vector2(0,-30); lower.show()
	if p.facing!=0: return
	if state.skill!=null:
		var skill: Dictionary = state.skill
		var frame: int
		if skill.phase=="windup": frame=0 if skill.remaining>(0.225 if skill.kind=="rain" else 0.09) else 1
		else: frame=2 if skill.remaining>0.06 else 3
		upper.sample("hero-skills-upper",frame+(4 if skill.kind=="rain" else 0))
	else:
		var frame: int = 0
		match state.attack:
			"draw": frame=clampi(1+int((0.08-float(state.windup if state.windup!=null else 0))/0.08*3),1,3)
			"release": frame=4 if attack_remaining>0.245 else 5
			"recover": frame=6 if attack_remaining>0.17 else 7
		upper.sample("hero-archery-upper",frame)
	upper.position=Vector2(0,-30); upper.show()
