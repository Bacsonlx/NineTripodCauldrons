extends Node2D
## 单方向绘画帧替换默认拆件；阶段、位移和飞锤始终读取真实规则。

const Frames = preload("res://scripts/presentation/action_frame_sprite.gd")
var visual_scale: float = 1.0
var body: Sprite2D
var hammer: Sprite2D
var fallen: Node2D
var distance: float = 0.0
var previous: Dictionary = {}

func _ready() -> void:
	scale=Vector2.ONE*visual_scale
	body=Frames.new(); body.name="Body"; add_child(body)
	hammer=Sprite2D.new(); hammer.name="hammer"
	hammer.texture=preload("res://assets/boss/thor-puppet-v1/hammer.tres")
	hammer.scale=Vector2.ONE*54/hammer.texture.get_height()
	hammer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(hammer)

func update_state(state: Dictionary) -> void:
	var boss: Dictionary = state.boss
	var point: Vector2 = Vector2(boss.x,boss.y)
	var restart: bool = previous.is_empty() or state.runId!=previous.runId or state.elapsed<previous.elapsed
	if restart: distance=0
	elif state.elapsed>previous.elapsed and boss.phase in ["chase","reposition"]:
		distance+=point.distance_to(Vector2(previous.boss.x,previous.boss.y))
	position=point; z_index=int(point.y)
	visible=true
	modulate=Color("ffedc5") if boss.flash>0 else Color.WHITE
	body.visible=boss.health>0
	if fallen!=null: fallen.visible=boss.health<=0
	if boss.health<=0:
		hammer.hide()
		if fallen==null:
			fallen=preload("res://scripts/presentation/thor_puppet.gd").new()
			fallen.visual_scale=visual_scale
			add_child(fallen)
		var local_state: Dictionary = state.duplicate(true)
		local_state.boss.x=0; local_state.boss.y=0
		fallen.update_state(local_state)
		return
	var clip: String = "thor-swing-v2"
	var frame: int = 0
	match boss.phase:
		"chase","reposition":
			clip="thor-walk"; frame=int(distance/17.0)%8
		"swing_warn": frame=mini(3,int((0.8-boss.timer)/0.8*4))
		"swing": frame=4
		"swing_recover": frame=5+mini(2,int((1-boss.timer)*3))
		"throw_warn": clip="thor-throw"; frame=mini(2,int((1-boss.timer)*3))
		"flight": clip="thor-throw"; frame=5 if state.hammer.leg=="return" else 4
		"throw_recover": clip="thor-throw"; frame=6 if boss.timer>0.4 else 7
		"lightning": clip="thor-lightning"; frame=clampi(int((4-boss.timer)*2),0,7)
	body.sample(clip,frame)
	# 原图的离手帧含飞锤，飞行期间改用真正空手的第5/6帧，避免双锤。
	hammer.visible=state.vulnerable and visible
	hammer.z_as_relative=false
	hammer.z_index=int(state.hammer.y)+2 if state.vulnerable else z_index+2
	if state.vulnerable:
		hammer.position=(Vector2(state.hammer.x,state.hammer.y)-point)/visual_scale+Vector2(30,-110)
		hammer.rotation=state.elapsed*12
	else:
		hammer.position=Vector2(30,-110)
	previous=state.duplicate(true)
