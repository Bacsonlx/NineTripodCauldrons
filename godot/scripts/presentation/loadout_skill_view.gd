extends Node2D
var state: Dictionary = {}
func update(snapshot: Dictionary) -> void:
	state=snapshot; queue_redraw()
func _draw() -> void:
	if state.is_empty(): return
	var wind: Dictionary = state.get("windPath",{})
	if not wind.is_empty():
		var tint: Color = Color(0.42,0.85,0.68,0.22) if wind.extra>0 else Color(0.42,0.65,0.68,0.1)
		if wind.points.size()>1:
			draw_polyline(PackedVector2Array(wind.points),tint,40)
			draw_polyline(PackedVector2Array(wind.points),Color(0.67,0.97,0.83,0.6),2)
		for endpoint in [wind.from,wind.to]: draw_arc(endpoint,20,0,TAU,24,tint,2)
	var charge: Dictionary = state.get("charge",{})
	for index in charge.get("layers",0): draw_circle(state.grip+Vector2(-6+index*12,-10),3,Color("f3d989"))
