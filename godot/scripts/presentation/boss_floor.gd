extends Node2D

const Rules = preload("res://scripts/combat/boss_room.gd")

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,1040),Color("151c1d"))
	draw_rect(Rules.ARENA_BOUNDS,Color("343c3b"))
	draw_rect(Rules.ARENA_BOUNDS,Color("b1a483"),false,3)
	for x in range(96,1344,96): draw_line(Vector2(x,96),Vector2(x,944),Color(0.6,0.6,0.5,0.12))
	for y in range(96,944,96): draw_line(Vector2(96,y),Vector2(1344,y),Color(0.6,0.6,0.5,0.12))
