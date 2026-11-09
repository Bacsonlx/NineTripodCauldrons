extends Node2D
var state: Dictionary = {}
var wind_time: float = 0.0
var previous_wind_remaining: float = 0.0
func update(snapshot: Dictionary) -> void:
	state=snapshot; queue_redraw()

func _process(delta: float) -> void:
	var wind: Dictionary = state.get("windPath",{})
	if wind.is_empty() or bool(state.get("paused",false)): return
	var remaining: float = float(wind.get("remaining",0.0))
	if remaining>previous_wind_remaining+0.001: wind_time=0.0
	previous_wind_remaining=remaining
	wind_time+=delta
	queue_redraw()

func has_active_dash(snapshot: Dictionary) -> bool:
	var dash: Dictionary = snapshot.get("skillDash",{})
	return not dash.is_empty() and float(dash.get("remaining",0.0))>0.001

func _draw() -> void:
	if state.is_empty(): return
	var player_point: Vector2 = Vector2(state.player.x,state.player.y)
	var dash: Dictionary = state.get("skillDash",{})
	var dash_remaining: float = float(dash.get("remaining",0.0))
	if has_active_dash(state):
		var direction: Vector2 = Vector2(dash.direction).normalized()
		var progress: float = clampf(1.0-dash_remaining/0.20,0.0,1.0)
		if dash.kind=="backwind":
			var return_direction: Vector2 = -direction
			var return_center: Vector2 = player_point+return_direction*(20.0+8.0*progress)
			draw_arc(return_center,18.0+5.0*progress,-PI*0.2,PI*1.45,20,Color("edc98e",0.78),3)
			for index in 3:
				var mark: Vector2 = player_point+return_direction*(12.0+index*14.0)
				draw_arc(mark,5.0+index*1.5,-PI*0.15,PI*1.05,12,Color("d6ad78",0.72-float(index)*0.12),2)
		elif dash.kind=="wind" or dash.kind=="wind_extra":
			var wind_center: Vector2 = player_point-direction*(18.0+10.0*progress)
			draw_arc(wind_center,22.0+6.0*progress,direction.angle()-PI*0.9,direction.angle()+PI*0.9,24,Color("78e1e2",0.72),3)
			draw_arc(wind_center,13.0+4.0*progress,direction.angle()-PI*0.75,direction.angle()+PI*0.75,20,Color("d5fff0",0.62),2)
	if state.get("dodge",0)>0:
		var dodge_direction: Vector2 = Vector2(state.get("dodgeDirection",Vector2.RIGHT)).normalized()
		var dodge_center: Vector2 = player_point-dodge_direction*28
		draw_arc(dodge_center,27,-PI*0.8,PI*0.8,20,Color("e9d18d",0.85),3)
		draw_line(dodge_center-dodge_direction*54,dodge_center-dodge_direction*20,Color("e86d5e",0.78),3,true)
	var strike: Dictionary = state.get("backwindStrike",{})
	if not strike.is_empty():
		var strike_point: Vector2 = Vector2(strike.point)
		var strike_progress: float = clampf(1.0-float(strike.remaining)/0.22,0.0,1.0)
		draw_arc(strike_point,22.0+strike_progress*82.0,0,TAU,32,Color(0.95,0.68,0.28,0.8*(1.0-strike_progress)),4)
		draw_arc(strike_point,12.0+strike_progress*54.0,0,TAU,24,Color("ffe0a4",0.7*(1.0-strike_progress)),2)
	var wind: Dictionary = state.get("windPath",{})
	if not wind.is_empty():
		var remaining: float = float(wind.get("remaining",0.0))
		var fade: float = clampf(remaining/3.0,0.2,1.0)
		var tint: Color = Color(0.42,0.85,0.68,0.22*fade) if wind.extra>0 else Color(0.42,0.65,0.68,0.1*fade)
		var core: Color = Color(0.67,0.97,0.83,0.6*fade)
		if wind.points.size()>1:
			var points: PackedVector2Array = PackedVector2Array(wind.points)
			var width_half: float = float(wind.get("width",40.0))*0.5
			draw_colored_polygon(_wind_ribbon(points,width_half),tint)
			draw_polyline(_wind_flow(points,width_half*0.18,0.0),core,2,true)
			draw_polyline(_wind_flow(points,width_half*0.35,PI*0.7),Color(core,0.55),1.5,true)
			draw_polyline(_wind_flow(points,width_half*0.18,PI*1.4),Color(core,0.4),1.0,true)
		if int(wind.get("extra",0))>0:
			var player_direction: Vector2 = Vector2.from_angle(float(state.player.angle))
			draw_arc(player_point,28,player_direction.angle()-0.7,player_direction.angle()+0.7,16,Color("bafbe3",0.85),3)
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

func _wind_ribbon(points: PackedVector2Array,half_width: float) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	for index in count:
		var width_scale: float = clampf(1.0-float(mini(index,count-1-index))/float(maxi(1,count-1))*0.75,0.25,1.0)
		var normal: Vector2 = _path_normal(points,index)
		polygon.append(points[index]+normal*half_width*width_scale)
	for index in range(count-1,-1,-1):
		var width_scale: float = clampf(1.0-float(mini(index,count-1-index))/float(maxi(1,count-1))*0.75,0.25,1.0)
		var normal: Vector2 = _path_normal(points,index)
		polygon.append(points[index]-normal*half_width*width_scale)
	return polygon

func _wind_flow(points: PackedVector2Array,half_width: float,phase: float) -> PackedVector2Array:
	var flow: PackedVector2Array = PackedVector2Array()
	for index in points.size():
		var normal: Vector2 = _path_normal(points,index)
		var wave: float = sin(wind_time*5.0+phase+float(index)*0.7)*4.0
		flow.append(points[index]+normal*(half_width+wave))
	return flow

func _path_normal(points: PackedVector2Array,index: int) -> Vector2:
	var count: int = points.size()
	var direction: Vector2
	if index==0: direction=points[1]-points[0]
	elif index==count-1: direction=points[count-1]-points[count-2]
	else: direction=(points[index+1]-points[index-1]).normalized()
	if direction.length_squared()<0.000001: return Vector2.UP
	return direction.normalized().orthogonal()

func tomb_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=Color("555b54"); style.border_color=Color("b5bcae"); style.set_border_width_all(2)
	return style
