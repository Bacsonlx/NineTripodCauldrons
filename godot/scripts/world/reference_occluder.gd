@tool
extends Polygon2D

func update_player(point: Vector2) -> void:
	# 图上的墙面按脚点深度遮挡；靠近墙后时减淡，避免人物完全消失。
	modulate.a=0.4 if Geometry2D.is_point_in_polygon(point+Vector2(0,-45),polygon) else 1.0
