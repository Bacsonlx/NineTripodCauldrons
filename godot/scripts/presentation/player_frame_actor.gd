extends Node2D
## 同一皮影身份的离线帧；身体朝向与位移独立，规则仍裁决全部战斗时序。

const Frames = preload("res://scripts/presentation/action_frame_sprite.gd")
const GearRig = preload("res://scripts/presentation/gear_rig.gd")
const DIRECTORY: String = "res://assets/characters/child-shadow-v3/"
const STRIDE_WORLD: float = 48.0
var lower: Sprite2D
var upper: Sprite2D
var body: Sprite2D
var head: Sprite2D
var gear: Node2D
var distance: float = 0.0
var previous_point: Vector2 = Vector2.ZERO
var generation: int = -1
var failure_age: float = 0.0
var was_failed: bool = false

func _ready() -> void:
	lower=Frames.new(); lower.name="Lower"; add_child(lower)
	upper=Frames.new(); upper.name="Upper"; upper.z_index=1; add_child(upper)
	body=Frames.new(); body.name="Body"; body.z_index=1; add_child(body)
	for layer in [lower,upper,body]: layer.use_directory(DIRECTORY)
	head=Sprite2D.new(); head.name="HeadRepair"; add_child(head)
	gear=GearRig.new(); gear.name="Gear"; gear.z_index=2; add_child(gear)
	gear.integrated_slots.assign(["weapon","feet"])
	reset_pose()

func reset_pose() -> void:
	generation=-1; distance=0.0; failure_age=0.0; was_failed=false
	lower.hide(); upper.hide(); body.hide(); head.hide(); gear.hide()

func sample_layer(layer: Sprite2D,clip: String,facing: int,phase: int) -> void:
	var count: int = int(layer.clips[clip].perDirection)
	layer.sample(clip,facing*count+clampi(phase,0,count-1))
	layer.show()

func sample_phase(layer: Sprite2D,clip: String,facing: int,phase: int,phases: int) -> void:
	var count: int = int(layer.clips[clip].perDirection)
	sample_layer(layer,clip,facing,mini(count-1,int(float(phase)*count/phases)))

func align_waist() -> void:
	if lower.visible and upper.visible:
		upper.position=lower.position+lower.waist_parent_point()-upper.waist_parent_point()

func update_state(state: Dictionary,movement: Vector2,attack_remaining: float,_bob: float = 0.0,seconds: float = 0.0) -> void:
	var p: Dictionary = state.player
	var point: Vector2 = Vector2(p.x,p.y)
	if generation!=state.runId:
		distance=0.0; generation=state.runId; previous_point=point
		failure_age=0.0; was_failed=false
	position=point; z_index=int(point.y)
	if state.paused: return
	var failed: bool = state.status=="failed"
	if not failed: distance+=point.distance_to(previous_point)
	previous_point=point
	lower.hide(); upper.hide(); body.hide(); head.hide()
	lower.position=Vector2.ZERO; upper.position=Vector2.ZERO
	lower.modulate=Color.WHITE; upper.modulate=Color.WHITE; body.modulate=Color.WHITE
	var facing: int = int(p.facing)
	if failed:
		failure_age=failure_age+seconds if was_failed else 0.0
		was_failed=true
		sample_phase(body,"shadow-failed",facing,mini(7,int(failure_age*24.0)),8)
		gear.hide()
		return
	was_failed=false
	var stride: int = posmod(int(distance/STRIDE_WORLD*16.0),16)
	var move_facing: int = posmod(roundi(movement.angle()/(PI/2)),4)
	var dash: Dictionary = state.get("skillDash",{})
	var dashing: bool = state.dodge>0 or float(dash.get("remaining",0))>0
	if dashing and body.clips.has("shadow-dodge-body"):
		var dash_direction: Vector2 = state.dodgeDirection if state.dodge>0 else dash.direction
		var dash_facing: int = posmod(roundi(dash_direction.angle()/(PI/2)),4)
		sample_layer(body,"shadow-dodge-body",dash_facing,0)
		gear.hide()
		return
	if not dashing and state.hurt>0 and body.clips.has("shadow-hurt-body"):
		sample_layer(body,"shadow-hurt-body",facing,0)
		gear.hide()
		return
	if dashing:
		var remaining: float = state.dodge if state.dodge>0 else float(dash.remaining)
		var phase: int = clampi(int((0.2-remaining)/0.2*8),0,7)
		sample_phase(lower,"shadow-dodge-lower",facing,phase,8)
		sample_phase(upper,"shadow-dodge-upper",facing,phase,8)
	elif p.moving:
		var run: Dictionary = lower.clips["shadow-run-lower"]
		var count: int = int(run.perDirection)
		var backwards: bool = posmod(move_facing-facing,4)==2
		var row: int = facing*4+move_facing if int(run.get("movementRows",1))==4 else facing if backwards else move_facing
		var phase: int = int(float(stride)*count/16.0)
		# 复用正跑倒放，近似退步；不代表独立绘制的退步动作。
		if backwards and int(run.get("movementRows",1))==1: phase=posmod(-phase,count)
		lower.sample("shadow-run-lower",row*count+phase)
		lower.show()
	else:
		sample_layer(lower,"shadow-idle-lower",facing,0)
	if not dashing:
		if state.hurt>0:
			sample_phase(upper,"shadow-hurt-upper",facing,clampi(int((0.16-state.hurt)/0.16*4),0,3),4)
		elif state.skill!=null:
			var skill: Dictionary = state.skill
			var phase: int = 0
			if skill.phase=="windup":
				var duration: float = 0.45 if skill.kind=="rain" else 0.18
				phase=clampi(1+int((1.0-float(skill.remaining)/duration)*3.0),1,3)
			else: phase=4 if skill.remaining>0.06 else 6
			sample_phase(upper,"shadow-rain-upper" if skill.kind=="rain" else "shadow-pierce-upper",facing,phase,8)
		elif state.attack!="idle":
			var phase: int = 0
			match state.attack:
				"draw": phase=clampi(1+int((0.08-float(state.get("windup",0.0)))/0.08*3),1,3)
				"release": phase=4
				"recover": phase=5 if attack_remaining>0.187 else 6 if attack_remaining>0.153 else 7
			sample_phase(upper,"shadow-attack-upper",facing,phase,8)
		else:
			var action: String = "run" if p.moving else "idle"
			if state.get("unarmed",false): action+="-unarmed"
			sample_phase(upper,"shadow-"+action+"-upper",facing,stride if p.moving else 0,16 if p.moving else 1)
	align_waist()

func projectile_grips() -> Array:
	return upper.clips["shadow-attack-upper"].grips.duplicate(true)

func skill_grips() -> Dictionary:
	return {"pierce":upper.clips["shadow-pierce-upper"].grips.duplicate(true),"rain":upper.clips["shadow-rain-upper"].grips.duplicate(true)}

func projectile_length(kind: String,facing: int) -> float:
	var action: String = "shadow-pierce-upper" if kind=="pierce" else "shadow-attack-upper"
	return float(upper.clips[action].arrowLengths[facing])

func sync_gear_context() -> void:
	if not upper.visible:
		gear.hide(); return
	gear.show()
	gear.position=upper.position
	var data: Dictionary = upper.clips[upper.clip]
	gear.set_context(upper.clip,false,absf(upper.scale.x),upper.root_anchor(),upper.frame_index,data.get("attachments",{}))

func apply_appearance(appearance: Dictionary) -> void:
	gear.set_appearance(appearance)

func update_gear(delta: float) -> void:
	gear.update(delta)

func lower_waist_y() -> float:
	return lower.waist_world_y() if lower.visible else NAN

func upper_waist_y() -> float:
	return upper.waist_world_y() if upper.visible else NAN

func lower_waist_above_foot() -> float:
	return lower_waist_y()-global_position.y

func upper_waist_above_foot() -> float:
	return upper_waist_y()-global_position.y
