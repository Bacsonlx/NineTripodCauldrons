extends Node2D
var state: Dictionary = {}
var aim: Vector2 = Vector2.ZERO
var pointer_inside: bool = false
func update(snapshot: Dictionary,world_aim: Vector2,inside: bool) -> void:
	state=snapshot; aim=world_aim; pointer_inside=inside; queue_redraw()
func _draw() -> void:
	if state.is_empty(): return
	for enemy in state.enemies:
		if enemy.phase in ["inactive","dead"]: continue
		draw_rect(Rect2(enemy.x-20,enemy.y-88,40,4),Color("151714"))
		draw_rect(Rect2(enemy.x-20,enemy.y-88,40*enemy.health/60.0,4),Color("bc6745"))
	if state.invalid!=null:
		var center: Vector2 = Vector2(state.invalid.x,state.invalid.y)
		draw_line(center-Vector2(9,9),center+Vector2(9,9),Color("e87956"),2)
		draw_line(center-Vector2(9,-9),center+Vector2(9,-9),Color("e87956"),2)
	if pointer_inside and not state.paused and state.status!="failed":
		draw_arc(aim,6,0,TAU,24,Color("f5dbad"),1.2)
		draw_line(aim-Vector2(11,0),aim-Vector2(4,0),Color("f5dbad"),1.2)
		draw_line(aim+Vector2(4,0),aim+Vector2(11,0),Color("f5dbad"),1.2)
