@tool
extends Node2D

@export var title: String = "营地"
@export var subtitle: String = ""
@export var radius: float = 70
@export var tint: Color = Color("a6b693")

func _draw() -> void:
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(tint,0.55),2)
	draw_circle(Vector2.ZERO,5,tint)
	var font: Font = ThemeDB.fallback_font
	draw_string(font,Vector2(-radius,-radius-28),title,HORIZONTAL_ALIGNMENT_CENTER,radius*2,20,Color("ecd7ad"))
	draw_string(font,Vector2(-radius,-radius-5),subtitle,HORIZONTAL_ALIGNMENT_CENTER,radius*2,14,tint)
