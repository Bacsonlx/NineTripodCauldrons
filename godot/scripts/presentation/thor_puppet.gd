extends Node2D

const PART_NAMES: Array[String] = ["cape","far_arm","far_forearm","far_shin","far_thigh","far_boot","near_shin","near_thigh","near_boot","pelvis","chest","head","tail","near_arm","near_forearm","hammer"]
const HEIGHT: float = 182.0
const STRIDE: float = 68.0
# 横锤挥击弧线关键帧：举锤过顶→命中位，控制点在前侧撑开弧线。
const SWING_LIFT: Vector2 = Vector2(-58,-178)
const SWING_STRIKE: Vector2 = Vector2(56,-94)
# 每个点对应裁片中可见的解剖连接点，不能用包围框中心替代。
const JOINTS: Dictionary = {
	"near_arm":[Vector2(0.74,0.18),Vector2(0.25,0.78),30.0],
	"far_arm":[Vector2(0.22,0.19),Vector2(0.72,0.81),30.0],
	"near_forearm":[Vector2(0.45,0.14),Vector2(0.83,0.85),31.0],
	"far_forearm":[Vector2(0.28,0.11),Vector2(0.64,0.83),39.0],
	"near_thigh":[Vector2(0.50,0.14),Vector2(0.50,0.76),36.0],
	"far_thigh":[Vector2(0.40,0.15),Vector2(0.56,0.76),36.0],
	"near_shin":[Vector2(0.52,0.13),Vector2(0.50,0.83),39.0],
	"far_shin":[Vector2(0.50,0.13),Vector2(0.50,0.84),39.0],
}
var visual_scale: float = 1.0
var pieces: Dictionary = {}
var feet: Array[Vector2] = []
var planted: Array[Vector2] = []
var previous_swing: Array[bool] = [false,false]
var swing_start: Array[Vector2] = []
var previous_position: Vector2 = Vector2.ZERO
var previous_time: float = 0
var generation: int = -1
var distance: float = 0
var stance: Dictionary = {}
var held_hand: Vector2 = Vector2(-48,-176)
var release_hand: Vector2 = Vector2(-48,-176)
var hammer_angle: float = PI-0.35
var last_phase: String = ""
var landing: Array[Vector2] = []
var lift: Array[float] = [0.0,0.0]
var movement_weight: float = 0
var pose_elapsed: float = 0
var blend_from: Dictionary = {}
var last_body: Dictionary = {}

func _ready() -> void:
	name="ThorPuppet"
	scale=Vector2.ONE*visual_scale
	for part in PART_NAMES:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name=part; sprite.texture=load("res://assets/boss/thor-puppet-v1/%s.tres" % part)
		sprite.centered=false; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(sprite); pieces[part]=sprite

func piece(part: String,point: Vector2,height: float,pivot: Vector2 = Vector2(0.5,0.5),angle: float = 0) -> void:
	var sprite: Sprite2D = pieces[part]
	var size: Vector2 = sprite.texture.get_size()
	sprite.offset=-size*pivot
	sprite.scale=Vector2.ONE*height/size.y
	sprite.position=point; sprite.rotation=angle; sprite.visible=true

func limb(part: String,from: Vector2,to: Vector2) -> void:
	var sprite: Sprite2D = pieces[part]
	var size: Vector2 = sprite.texture.get_size()
	var binding: Array = JOINTS[part]
	var start: Vector2 = size*binding[0]
	var axis: Vector2 = size*(binding[1]-binding[0])
	sprite.offset=-start
	sprite.scale=Vector2.ONE*float(binding[2])/axis.length()
	sprite.position=from; sprite.rotation=(to-from).angle()-axis.angle(); sprite.visible=true

static func knee(hip: Vector2,ankle: Vector2,upper: float = 36,lower: float = 39,side: float = 1) -> Vector2:
	var vector: Vector2 = ankle-hip
	var length: float = clampf(vector.length(),absf(upper-lower)+0.001,upper+lower-0.001)
	var direction: Vector2 = vector.normalized()
	var along: float = (upper*upper-lower*lower+length*length)/(2*length)
	return hip+direction*along+Vector2(direction.y,-direction.x)*sqrt(maxf(0,upper*upper-along*along))*side

func reset_pose(snapshot: Dictionary,origin: Vector2) -> void:
	generation=snapshot.runId; distance=0; stance={}; last_phase=""
	previous_position=origin; previous_time=snapshot.elapsed
	feet=[origin+Vector2(-12,-3),origin+Vector2(12,3)]
	planted=feet.duplicate(); swing_start=feet.duplicate()
	previous_swing=[false,false]
	landing=feet.duplicate(); lift=[0.0,0.0]; movement_weight=0; last_body={}; blend_from={}; pose_elapsed=0
	hammer_angle=PI-0.35

func update_state(snapshot: Dictionary) -> void:
	if pieces.is_empty(): return
	var boss: Dictionary = snapshot.boss
	var origin: Vector2 = Vector2(boss.x,boss.y)/visual_scale
	scale=Vector2.ONE*visual_scale
	if generation!=snapshot.runId or snapshot.elapsed<previous_time: reset_pose(snapshot,origin)
	var delta: float = maxf(0,snapshot.elapsed-previous_time)
	var travel: Vector2 = origin-previous_position
	if delta==0 and travel==Vector2.ZERO and not stance.is_empty(): return
	var moving: bool = travel.length()>0.00001 and boss.health>0
	if not snapshot.paused: distance+=travel.length()
	var direction: Vector2 = travel.normalized() if moving else Vector2.RIGHT
	movement_weight=move_toward(movement_weight,1.0 if moving else 0.0,delta/0.16)
	for index in 2:
		var neutral: Vector2 = Vector2(-12,-3) if index==0 else Vector2(12,3)
		if moving:
			var phase: float = fposmod(distance/STRIDE+index*0.5,1)
			var swing: bool = phase>=0.62
			if swing:
				if not previous_swing[index]:
					swing_start[index]=feet[index]
					landing[index]=origin+neutral+direction*(STRIDE*(0.38+0.62/2))
					landing[index]=swing_start[index]+(landing[index]-swing_start[index]).limit_length(74)
				var progress: float = (phase-0.62)/0.38
				var eased: float = progress*progress*progress*(progress*(progress*6-15)+10)
				feet[index]=swing_start[index].lerp(landing[index],eased)
				lift[index]=sin(progress*PI)*6
			else:
				if previous_swing[index]:
					planted[index]=landing[index]
				feet[index]=planted[index]; lift[index]=0
			previous_swing[index]=swing
		elif delta>0:
			# 停步先落脚，不让悬空脚在一个采样内弹回地面。
			lift[index]=move_toward(lift[index],0,delta*45)
			feet[index]=feet[index].move_toward(origin+neutral,delta*100)
			planted[index]=feet[index]; previous_swing[index]=false
	var gait: float = distance/STRIDE*TAU
	var bob: float = -sin(gait*2)*0.45*movement_weight+sin(snapshot.elapsed*1.7)*0.7*(1-movement_weight)
	var hip: Vector2 = Vector2(0,-83+bob)
	var chest: Vector2 = Vector2(0,-116+bob)
	var torso_angle: float = sin(gait)*0.018*movement_weight
	var near_shoulder: Vector2
	var far_shoulder: Vector2
	# 摆臂沿实际移动方向、与对侧腿反相；肩胯反向但待机仍收拢贴身。
	var arm_swing: Vector2 = direction*(-sin(gait)*10)*movement_weight
	var near_hand: Vector2 = Vector2(-27,-77+bob)-arm_swing
	var far_hand: Vector2 = Vector2(29,-77+bob)+arm_swing
	var extension: Vector2 = Vector2.from_angle(boss.angle)
	match boss.phase:
		"swing_warn":
			var charge: float = smoothstep(0,1,1-boss.timer/0.8)
			near_hand=near_hand.lerp(SWING_LIFT,charge)
			torso_angle=-charge*0.3
			hip+=Vector2(-7,4)*charge; chest+=Vector2(-9,3)*charge
		"swing":
			var progress: float = smoothstep(0,1,1-boss.timer/0.12)
			# 手走过顶前侧弧线（二次贝塞尔），锤头划弧而非直线拉扯。
			var arc_control: Vector2 = SWING_LIFT.lerp(SWING_STRIKE,0.5)+Vector2(14,-24)
			near_hand=SWING_LIFT.lerp(arc_control,progress).lerp(arc_control.lerp(SWING_STRIKE,progress),progress)
			torso_angle=lerpf(-0.3,0.3,progress)
			hip+=Vector2(-7,4).lerp(Vector2(8,0),progress)
			chest+=Vector2(-9,3).lerp(Vector2(7,1),progress)
		"swing_recover":
			# 命中后先保持0.04秒发力收尾（纯视觉停顿，不改规则时钟），再回位。
			var progress: float = smoothstep(0,1,clampf((1-boss.timer-0.04)/0.96,0,1))
			near_hand=SWING_STRIKE.lerp(near_hand,progress)
			torso_angle=(1-progress)*0.3
			hip+=Vector2(8,0)*(1-progress); chest+=Vector2(7,1)*(1-progress)
		"throw_warn":
			var charge: float = smoothstep(0,1,1-boss.timer)
			near_hand=near_hand.lerp(Vector2(-48,-176),charge)
			torso_angle=-charge*0.1
		"flight":
			near_hand=extension*54+Vector2(0,-110)
			far_hand=Vector2(29,-77); torso_angle=0.04
		"throw_recover":
			var progress: float = smoothstep(0,1,1-boss.timer/0.8)
			near_hand=(extension*54+Vector2(0,-110)).lerp(near_hand,progress)
			torso_angle=sin(progress*PI)*0.10
		"lightning":
			var charge: float = smoothstep(0,0.6,4-boss.timer)
			var recover: float = smoothstep(0,1,boss.timer)
			near_hand=near_hand.lerp(Vector2(-30,-181),charge*recover)
			far_hand=far_hand.lerp(Vector2(36,-155),charge*recover)
		"dead":
			hip+=Vector2(14,20); chest+=Vector2(20,18); near_hand=Vector2(-38,-32); far_hand=Vector2(55,-35)
			torso_angle=0.3
	if boss.phase!=last_phase:
		blend_from=last_body.duplicate(); pose_elapsed=0
	pose_elapsed+=delta
	if not blend_from.is_empty() and boss.phase!="dead":
		# 过渡分级：发力保持快 snap，收招回位用更长弧线过渡。
		var blend_duration: float = 0.25 if boss.phase in ["swing_recover","throw_recover"] else (0.05 if boss.phase in ["swing","flight"] else 0.12)
		var mix: float = smoothstep(0,1,pose_elapsed/blend_duration)
		hip=blend_from.hip.lerp(hip,mix); chest=blend_from.chest.lerp(chest,mix)
		near_hand=blend_from.near_hand.lerp(near_hand,mix); far_hand=blend_from.far_hand.lerp(far_hand,mix)
		torso_angle=lerp_angle(blend_from.angle,torso_angle,mix)
	# 斜向移动时用骨盆沉降满足固定腿长，不能偷偷拖动已落地的靴子。
	var settle: float = 0
	for index in 2:
		var side: Vector2 = Vector2(-12,-5) if index==0 else Vector2(12,2)
		var ankle: Vector2 = feet[index]-origin-Vector2(0,lift[index]+14)
		var horizontal: float = ankle.x-side.x
		var reach: float = sqrt(maxf(1,74.8*74.8-horizontal*horizontal))
		settle=maxf(settle,ankle.y-reach-side.y-hip.y)
	hip.y+=settle
	chest.y+=settle; near_hand.y+=settle; far_hand.y+=settle
	last_body={"hip":hip,"chest":chest,"near_hand":near_hand,"far_hand":far_hand,"angle":torso_angle}
	near_shoulder=chest+Vector2(-23,-19).rotated(torso_angle)
	far_shoulder=chest+Vector2(23,-19).rotated(torso_angle)
	position=origin*visual_scale; z_as_relative=false; z_index=int(boss.y)
	for index in 2:
		var prefix: String = "far" if index==0 else "near"
		var foot: Vector2 = feet[index]-origin-Vector2(0,lift[index])
		var joint: Vector2 = hip+Vector2(-12,-5) if index==0 else hip+Vector2(12,2)
		var ankle: Vector2 = foot-Vector2(0,14)
		ankle=joint+(ankle-joint).limit_length(74.8)
		var bend: Vector2 = knee(joint,ankle)
		limb(prefix+"_thigh",joint,bend)
		limb(prefix+"_shin",bend,ankle)
		piece(prefix+"_boot",ankle,23,Vector2(0.38,0.18))
	piece("cape",chest+Vector2(-10,-5),87,Vector2(0.5,0.1),0.12+sin(snapshot.elapsed*3-0.5)*(0.035+0.10*movement_weight))
	piece("pelvis",hip+Vector2(0,-5),38,Vector2(0.5,0.15),-torso_angle*0.4)
	piece("chest",chest,56,Vector2(0.5,0.5),torso_angle)
	piece("head",chest+Vector2(7,-25).rotated(torso_angle),40,Vector2(0.5,0.78),torso_angle*0.35)
	piece("tail",hip+Vector2(15,-10),48,Vector2(0.5,0.05),sin(snapshot.elapsed*3-0.8)*0.07)
	for prefix in ["near","far"]:
		var shoulder: Vector2 = near_shoulder if prefix=="near" else far_shoulder
		var hand: Vector2 = near_hand if prefix=="near" else far_hand
		hand=shoulder+(hand-shoulder).limit_length(60.8)
		if prefix=="near": near_hand=hand
		var middle: Vector2 = knee(shoulder,hand,30,31,-1 if prefix=="near" else 1)
		limb(prefix+"_arm",shoulder,middle)
		limb(prefix+"_forearm",middle,hand)
	var hammer: Sprite2D = pieces.hammer
	if snapshot.vulnerable:
		var point: Vector2 = Vector2(snapshot.hammer.x,snapshot.hammer.y)/visual_scale
		if last_phase!="flight": release_hand=held_hand
		var span: float = snapshot.hammer.origin.distance_to(snapshot.hammer.target)
		var total: float = span/500+span/650
		var progress: float = clampf(1-boss.timer/total,0,1)
		var height_offset: Vector2 = release_hand.lerp(near_hand,progress)-Vector2(0,sin(progress*PI)*22)
		var rotation_angle: float = lerpf(0.3,PI-0.35+TAU*2,progress)
		piece("hammer",point-origin+height_offset,54,Vector2(0.5,0.78),rotation_angle)
		hammer.z_as_relative=false; hammer.z_index=int(snapshot.hammer.y)+2
	else:
		var angle: float = PI-0.35
		if boss.phase in ["swing_warn","throw_warn"]:
			var duration: float = 0.8 if boss.phase=="swing_warn" else 1.0
			angle=lerpf(PI-0.35,0.3,smoothstep(0,1,1-boss.timer/duration))
		elif boss.phase=="swing": angle=lerpf(0.3,PI/2,smoothstep(0,1,1-boss.timer/0.12))
		elif boss.phase=="swing_recover": angle=lerpf(PI/2,PI-0.35,smoothstep(0,1,clampf((1-boss.timer-0.04)/0.96,0,1)))
		elif boss.phase=="lightning": angle=lerpf(PI-0.35,0.3,smoothstep(0,0.6,4-boss.timer)*smoothstep(0,1,boss.timer))
		# 重锤滞后跟随持锤手，挥击时收紧跟随；重复快照 delta 为0时保持姿态不变。
		hammer_angle=lerp_angle(hammer_angle,angle,minf(1.0,delta*(30.0 if boss.phase=="swing" else 14.0)))
		piece("hammer",near_hand,54,Vector2(0.5,0.78),hammer_angle)
		hammer.z_as_relative=true; hammer.z_index=0
		held_hand=near_hand
	modulate=Color("fff2c7") if boss.flash>0 else Color.WHITE
	stance={"feet":feet.duplicate(),"lift":lift,"phase":boss.phase,"moving":moving,"distance":distance}
	previous_position=origin; previous_time=snapshot.elapsed; last_phase=boss.phase
	queue_redraw()

func _draw() -> void:
	if stance.is_empty(): return
	for foot in feet:
		draw_set_transform(foot-position/visual_scale,0,Vector2(1,0.28))
		draw_circle(Vector2.ZERO,16,Color(0.02,0.02,0.02,0.38))
	draw_set_transform(Vector2.ZERO)

func pose_snapshot() -> Dictionary:
	return stance.duplicate(true)
