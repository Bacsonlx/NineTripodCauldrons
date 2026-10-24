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

	var item_effects: Dictionary = state.get("itemEffects",{})
	var puddle: Dictionary = item_effects.get("puddle",{})
	if not puddle.is_empty():
		draw_circle(puddle.point,90,Color(0.2,0.6,0.85,0.18))
		draw_arc(puddle.point,90,0,TAU,48,Color(0.4,0.8,0.96,0.7),2)
	var tomb: Dictionary = item_effects.get("tomb",{})
	if not tomb.is_empty():
		draw_style_box(tomb_style(),Rect2(tomb.point-Vector2(12,42),Vector2(24,42)))
		draw_rect(Rect2(tomb.point+Vector2(-18,-50),Vector2(36*tomb.health/80.0,4)),Color("b8bdae"))

func tomb_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=Color("555b54"); style.border_color=Color("b5bcae"); style.set_border_width_all(2)
	return style
