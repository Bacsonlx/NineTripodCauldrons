@tool
extends Node2D

var atmosphere_time: float = 0.0
var view_bounds: Rect2 = Rect2()

func cover_view(visible: Rect2) -> void:
	var bounds: Rect2 = visible.grow(96).merge(Rect2(-600,-500,2640,2040))
	if bounds==view_bounds: return
	view_bounds=bounds
	$Surround.polygon=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])

func update_state(state: Dictionary,clock: float) -> void:
	for prop in get_children():
		if prop.has_method("update_state"): prop.update_state(state,clock)
	var time: float = float(state.get("elapsed",clock))
	if atmosphere_time==time: return
	atmosphere_time=time
	queue_redraw()

func _draw() -> void:
	# 少量无伤害飘灰只读规则时间；警戒线与人物始终绘在其上方。
	for i in 24:
		var point: Vector2 = Vector2(fposmod(i*173.3+atmosphere_time*9,1700)-130,fposmod(i*97.7-atmosphere_time*13,1200)-80)
		point.x+=sin(atmosphere_time*0.5+i)*12
		var alpha: float = 0.08+0.08*sin(i*1.7+atmosphere_time*0.4)
		draw_line(point,point+Vector2(2.5,-1.5),Color(0.82,0.75,0.60,alpha),1.2,true)
