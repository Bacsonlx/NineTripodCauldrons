extends Node2D
## 独立试点：片段由 AI 离线编辑，运行时仅按规则时间采样。

@onready var animation: AnimationPlayer = $AnimationPlayer

func sample(clip: StringName, seconds: float) -> void:
	if animation.assigned_animation != clip:
		animation.play(clip)
	var duration: float = animation.get_animation(clip).length
	var time: float = fposmod(seconds,duration) if clip==&"idle" else clampf(seconds,0,duration)
	animation.seek(time,true)
	animation.pause()

func update_state(snapshot: Dictionary) -> void:
	var boss: Dictionary = snapshot.boss
	position=Vector2(boss.x,boss.y)
	z_index=int(boss.y)
	match boss.phase:
		"swing_warn": sample(&"swing",0.8-boss.timer)
		"swing": sample(&"swing",0.8+0.12-boss.timer)
		"swing_recover": sample(&"swing",0.92+1.0-boss.timer)
		"dead": sample(&"idle",0)
		_: sample(&"idle",snapshot.elapsed)
	modulate=Color("fff2c7") if boss.flash>0 else Color.WHITE

func _draw() -> void:
	for foot in [Vector2(-12,-3),Vector2(12,3)]:
		draw_set_transform(foot,0,Vector2(1,0.28))
		draw_circle(Vector2.ZERO,16,Color(0.02,0.02,0.02,0.38))
	draw_set_transform(Vector2.ZERO)
