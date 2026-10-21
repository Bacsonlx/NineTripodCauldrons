extends Node2D
var state: Dictionary = {}
var aim: Vector2 = Vector2.ZERO
var pointer_inside: bool = false
var enemy_bars: Dictionary = {}
func update(snapshot: Dictionary,world_aim: Vector2,inside: bool) -> void:
	state=snapshot; aim=world_aim; pointer_inside=inside
	for bar in enemy_bars.values(): bar.visible=false
	for enemy in state.enemies:
		if enemy.phase in ["inactive","dead"]: continue
		if not enemy_bars.has(enemy.id):
			var bar: ProgressBar = ProgressBar.new()
			bar.name="EnemyHealth%d" % enemy.id
			bar.max_value=60; bar.show_percentage=false; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var background: StyleBoxFlat = StyleBoxFlat.new()
			background.bg_color=Color("242821"); background.border_color=Color("a48b55")
			background.set_border_width_all(1)
			bar.add_theme_stylebox_override("background",background)
			var fill: StyleBoxFlat = StyleBoxFlat.new()
			fill.bg_color=Color("c8533e"); fill.set_content_margin_all(1)
			bar.add_theme_stylebox_override("fill",fill)
			add_child(bar); enemy_bars[enemy.id]=bar
		var bar: ProgressBar = enemy_bars[enemy.id]
		bar.position=Vector2(enemy.x-24,enemy.y-92); bar.size=Vector2(48,6)
		bar.value=enemy.health; bar.visible=true
		bar.get_theme_stylebox("fill").bg_color=Color("f4c388") if enemy.flash>0 else Color("c8533e")
	queue_redraw()
func _draw() -> void:
	if state.is_empty(): return
	if state.invalid!=null:
		var center: Vector2 = Vector2(state.invalid.x,state.invalid.y)
		draw_line(center-Vector2(9,9),center+Vector2(9,9),Color("e87956"),2)
		draw_line(center-Vector2(9,-9),center+Vector2(9,-9),Color("e87956"),2)
	if pointer_inside and not state.paused and state.status!="failed":
		draw_arc(aim,6,0,TAU,24,Color("f5dbad"),1.2)
		draw_line(aim-Vector2(11,0),aim-Vector2(4,0),Color("f5dbad"),1.2)
		draw_line(aim+Vector2(4,0),aim+Vector2(11,0),Color("f5dbad"),1.2)
