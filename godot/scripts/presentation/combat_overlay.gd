extends Node2D
var state: Dictionary = {}
var aim: Vector2 = Vector2.ZERO
var pointer_inside: bool = false
var enemy_bars: Dictionary = {}
var bar_fills: Dictionary = {}
var flash_bar: Color = Color("f4c388")
var normal_bar: Color = Color("c8533e")
func update(snapshot: Dictionary,world_aim: Vector2,inside: bool) -> void:
	state=snapshot; aim=world_aim; pointer_inside=inside
	for bar in enemy_bars.values():
		if bar.visible: bar.visible=false
	for enemy in state.enemies:
		if enemy.phase in ["inactive","dead"]: continue
		if not enemy_bars.has(enemy.id):
			var created: ProgressBar = ProgressBar.new()
			created.name="EnemyHealth%d" % enemy.id
			created.max_value=60; created.show_percentage=false; created.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var background: StyleBoxFlat = StyleBoxFlat.new()
			background.bg_color=Color("242821"); background.border_color=Color("a48b55")
			background.set_border_width_all(1)
			created.add_theme_stylebox_override("background",background)
			var fill: StyleBoxFlat = StyleBoxFlat.new()
			fill.bg_color=Color("c8533e"); fill.set_content_margin_all(1)
			created.add_theme_stylebox_override("fill",fill)
			add_child(created); enemy_bars[enemy.id]=created; bar_fills[enemy.id]=fill
		var bar: ProgressBar = enemy_bars[enemy.id]
		var next_position: Vector2 = Vector2(enemy.x-24,enemy.y-92)
		if bar.position!=next_position: bar.position=next_position
		if bar.size!=Vector2(48,6): bar.size=Vector2(48,6)
		if not is_equal_approx(bar.value,enemy.health): bar.value=enemy.health
		if not bar.visible: bar.visible=true
		var bar_fill: StyleBoxFlat = bar_fills[enemy.id]
		var next_color: Color = flash_bar if enemy.flash>0 else normal_bar
		if bar_fill.bg_color!=next_color: bar_fill.bg_color=next_color
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
