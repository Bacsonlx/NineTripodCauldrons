extends Control

var icon: Texture2D
var remaining: float = 0.0
var duration: float = 1.0
var counter: Label
var insufficient: bool = false
var last_insufficient: bool = false
var slot_size: Vector2 = Vector2(60,60)

func set_slot_size(size: Vector2) -> void:
	slot_size=size
	queue_redraw()

func update_cooldown(seconds: float) -> void:
	var next: float = seconds if seconds>0.000001 else 0.0
	if is_equal_approx(remaining,next) and insufficient==last_insufficient: return
	remaining=next
	last_insufficient=insufficient
	var value: String = "%.1f" % maxf(0.1,ceilf((remaining-0.000001)*10)/10) if remaining>0 else ""
	if counter.text!=value: counter.text=value
	queue_redraw()

func _draw() -> void:
	if icon==null: return
	draw_texture_rect(icon,Rect2(Vector2.ZERO,slot_size),false,Color("88877d") if remaining>0 or insufficient else Color.WHITE)
	if remaining<=0: return
	# 从十二点方向顺时针遮住剩余冷却，数字与遮罩共用规则时间。
	var fraction: float = clampf(remaining/duration,0,1)
	if fraction>=0.999999:
		draw_rect(Rect2(Vector2.ZERO,slot_size),Color(0.02,0.03,0.025,0.67)); return
	if fraction<=0.000001: return
	var center: Vector2 = slot_size/2.0
	var polygon: PackedVector2Array = [center,Vector2(center.x,0)]
	var corners: Array[Vector2] = [
		Vector2(slot_size.x,0),
		Vector2(slot_size.x,slot_size.y),
		Vector2(0,slot_size.y),
		Vector2(0,0)
	]
	for i in 4:
		if fraction>0.125+i*0.25: polygon.append(corners[i])
	var ray: Vector2 = Vector2.from_angle(-PI/2+TAU*fraction)
	var endpoint: Vector2 = center+ray*minf(slot_size.x,slot_size.y)/2.0/maxf(absf(ray.x),absf(ray.y))
	if polygon[-1].distance_to(endpoint)>0.0001: polygon.append(endpoint)
	draw_colored_polygon(polygon,Color(0.02,0.03,0.025,0.67))
