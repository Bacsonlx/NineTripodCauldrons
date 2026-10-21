extends Control

var icon: Texture2D
var remaining: float = 0.0
var duration: float = 1.0
var counter: Label
var insufficient: bool = false

func update_cooldown(seconds: float) -> void:
	remaining=seconds if seconds>0.000001 else 0.0
	counter.text="%.1f" % maxf(0.1,ceilf((remaining-0.000001)*10)/10) if remaining>0 else ""
	queue_redraw()

func _draw() -> void:
	if icon==null: return
	draw_texture_rect(icon,Rect2(0,0,60,60),false,Color("88877d") if remaining>0 or insufficient else Color.WHITE)
	if remaining<=0: return
	# 从十二点方向顺时针遮住剩余冷却，数字与遮罩共用规则时间。
	var fraction: float = clampf(remaining/duration,0,1)
	if fraction>=0.999999:
		draw_rect(Rect2(0,0,60,60),Color(0.02,0.03,0.025,0.67)); return
	if fraction<=0.000001: return
	var polygon: PackedVector2Array = [Vector2(30,30),Vector2(30,0)]
	var corners: Array[Vector2] = [Vector2(60,0),Vector2(60,60),Vector2(0,60),Vector2(0,0)]
	for i in 4:
		if fraction>0.125+i*0.25: polygon.append(corners[i])
	var ray: Vector2 = Vector2.from_angle(-PI/2+TAU*fraction)
	var endpoint: Vector2 = Vector2(30,30)+ray*30/maxf(absf(ray.x),absf(ray.y))
	if polygon[-1].distance_to(endpoint)>0.0001: polygon.append(endpoint)
	draw_colored_polygon(polygon,Color(0.02,0.03,0.025,0.67))
