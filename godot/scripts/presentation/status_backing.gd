extends Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# 四条墨色底衬在文字后收窄，避免整块面板遮挡地图。
	for index in 4:
		var y: float = index*23
		var width: float = 300 if index==0 else 330
		var points: PackedVector2Array = [Vector2(0,y),Vector2(width-24,y),Vector2(width,y+10),Vector2(width-24,y+21),Vector2(0,y+21)]
		draw_colored_polygon(points,Color(0.025,0.04,0.03,0.58))
