extends Node2D
## 移动选下肢，瞄准选同一身份的四向上身；规则负责全部时序。

const Frames = preload("res://scripts/presentation/action_frame_sprite.gd")
const HEAD_REPAIR_SCALE: float = 0.86
var lower: Sprite2D
var upper: Sprite2D
var body: Sprite2D
var head: Sprite2D
var head_material: ShaderMaterial
var head_overlay_material: ShaderMaterial
var distance: float = 0.0
var previous_point: Vector2 = Vector2.ZERO
var generation: int = -1

func _ready() -> void:
	lower=Frames.new(); lower.name="Lower"; add_child(lower)
	upper=Frames.new(); upper.name="Upper"; upper.z_index=1; add_child(upper)
	body=Frames.new(); body.name="Body"; body.z_index=1; add_child(body)
	head=Sprite2D.new(); head.name="HeadRepair"; head.centered=false
	head.region_enabled=true; head.region_filter_clip_enabled=true
	head.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; head.z_index=2
	head_material=ShaderMaterial.new()
	head_material.shader=preload("res://scripts/presentation/head_repair.gdshader")
	head_overlay_material=ShaderMaterial.new()
	head_overlay_material.shader=head_material.shader
	head.material=head_overlay_material
	add_child(head)
	reset_pose()

func reset_pose() -> void:
	generation=-1; distance=0
	lower.hide(); upper.hide(); body.hide(); head.hide()

func sample_skill(facing: int,phase: int) -> void:
	if facing==3:
		if phase==0:
			upper.sample("hero-archery-up",1); return
		phase-=1
	upper.sample("hero-skills-direction-"+str(facing),phase)

func update_state(state: Dictionary,movement: Vector2,attack_remaining: float,bob: float = 0.0) -> void:
	var p: Dictionary = state.player
	var point: Vector2 = Vector2(p.x,p.y)
	if generation!=state.runId:
		distance=0; generation=state.runId; previous_point=point
	if not state.paused and state.status!="failed": distance+=point.distance_to(previous_point)
	previous_point=point
	position=point+Vector2(0,bob); z_index=int(point.y)
	if state.status=="failed":
		lower.hide(); upper.hide(); body.hide(); head.hide(); return
	if state.paused: return
	lower.hide(); upper.hide(); body.hide(); head.hide()
	lower.modulate=Color.WHITE; upper.modulate=Color.WHITE; body.modulate=Color.WHITE; head.modulate=Color.WHITE
	body.position=Vector2.ZERO; body.scale=Vector2.ONE; body.rotation=0.0
	upper.position=Vector2(0,-30)
	if state.hurt>0:
		sample_skill(p.facing,3); upper.show()
		refresh_head_repair()
		return
	var dashing: bool = state.dodge>0 or state.get("skillDash",{}).get("remaining",0)>0
	if dashing:
		var dash_direction: Vector2 = state.dodgeDirection if state.dodge>0 else state.skillDash.direction
		var dash_kind: String = "dodge" if state.dodge>0 else str(state.skillDash.get("kind",""))
		var dash_tint: Color = Color("f3dc93") if dash_kind=="dodge" else Color("d7b77a") if dash_kind=="backwind" else Color("75d6e6")
		body.modulate=dash_tint; upper.modulate=dash_tint
		if dash_kind=="backwind":
			body.scale=Vector2(1.10,0.92)
			body.position=-dash_direction*4.0
			body.rotation=-0.08
		elif dash_kind=="wind" or dash_kind=="wind_extra":
			body.scale=Vector2(0.94,1.08)
			body.position=dash_direction*4.0
			body.rotation=0.08
		else:
			body.scale=Vector2(1.0,1.04)
		if absf(dash_direction.angle())>PI/4:
			sample_skill(p.facing,2); upper.show()
			refresh_head_repair()
			return
		var remaining: float = state.dodge if state.dodge>0 else state.skillDash.remaining
		body.sample("hero-dodge",clampi(int((0.2-remaining)/0.2*8),0,7)); body.show()
		return
	var move_facing: int = posmod(floori(movement.angle()/(PI/2)+0.5),4)
	if p.moving and move_facing==0:
		lower.sample("hero-run-lower",int(distance/22.0)%8)
		lower.position=Vector2(0,-30); lower.show()
	if p.facing==3 and not p.moving and state.skill==null:
		var back_phase: int = {"idle":0,"draw":1,"release":2,"recover":3}[state.attack]
		body.sample("hero-back-full",back_phase)
		body.position=Vector2.ZERO
		body.show()
		return
	if p.facing!=0:
		if state.skill!=null and state.skill.phase=="windup":
			sample_skill(p.facing,1 if state.skill.kind=="rain" else 0)
		elif p.facing==1: return
		else:
			var phase: int = {"idle":0,"draw":1,"release":2,"recover":3}[state.attack]
			if state.skill!=null: phase=2 if state.skill.remaining>0.06 else 3
			upper.sample("hero-archery-left" if p.facing==2 else "hero-archery-up",phase)
		upper.show()
		refresh_head_repair()
		return
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
	refresh_head_repair()

func refresh_head_repair() -> void:
	head.hide()
	upper.material=null
	if not upper.visible or upper.clip!="hero-archery-up":
		return
	var data: Dictionary = upper.clips[upper.clip]
	if not data.has("head_rects"):
		return
	var rects: Array = data.head_rects
	if upper.frame_index<0 or upper.frame_index>=rects.size():
		return
	var tex_size: Vector2 = upper.texture.get_size()
	var values: Array = rects[upper.frame_index]
	var head_rect: Rect2 = Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
	var abs_head_rect: Rect2 = Rect2(upper.region_rect.position+head_rect.position,head_rect.size)
	var uv_rect: Vector4 = Vector4(
		abs_head_rect.position.x/tex_size.x,
		abs_head_rect.position.y/tex_size.y,
		abs_head_rect.size.x/tex_size.x,
		abs_head_rect.size.y/tex_size.y
	)
	head_material.set_shader_parameter("head_rect",uv_rect)
	head_material.set_shader_parameter("mask_head",true)
	head_overlay_material.set_shader_parameter("head_rect",uv_rect)
	head_overlay_material.set_shader_parameter("mask_head",false)
	upper.material=head_material
	head.texture=upper.texture
	head.region_rect=upper.region_rect
	head.offset=upper.offset
	head.scale=upper.scale*HEAD_REPAIR_SCALE
	var center: Vector2 = upper.offset+head_rect.get_center()
	head.position=upper.position+center*upper.scale-center*head.scale
	head.z_index=upper.z_index+1
	head.show()
