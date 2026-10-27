extends "res://scripts/presentation/training_scene.gd"

var overview: bool = false
var overview_button: Button
var hud: Control

func create_backdrop() -> Node2D:
	return load("res://scripts/presentation/first_level_backdrop.gd").new()

func build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud=load("res://scripts/presentation/combat_hud.gd").new(); layer.add_child(hud)
	encounter_label=hud.encounter; interaction_label=hud.interaction
	status_label=hud.status; reading_panel=hud.reading
	fullscreen=Button.new(); fullscreen.text="全屏"; fullscreen.focus_mode=Control.FOCUS_NONE
	fullscreen.pressed.connect(toggle_fullscreen); hud.toolbar.add_child(fullscreen)
	overview_button=Button.new()
	overview_button.text="地图总览 · M"; overview_button.focus_mode=Control.FOCUS_NONE
	overview_button.pressed.connect(toggle_overview)
	hud.toolbar.add_child(overview_button)

func update_hud(snapshot: Dictionary) -> void:
	hud.update_state(snapshot)

func hud_lines() -> Dictionary:
	var lines: Dictionary = super.hud_lines()
	if state.status=="complete": lines.encounter="三庭已肃清 · 可继续探索汤谷"
	if state.feedback==null and state.interaction==null:
		lines.interaction="碑林在西侧 · 祭火在东侧"
	return lines

func toggle_overview() -> void:
	controls.interrupt()
	overview=not overview
	overview_button.text="跟随角色 · M" if overview else "地图总览 · M"
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
		toggle_overview(); get_viewport().set_input_as_handled(); return
	super._unhandled_input(event)

func update_camera() -> void:
	if not overview:
		super.update_camera(); return
	fit_room()

func fit_room(top_margin: float = 0) -> void:
	if camera==null: return
	var size: Vector2 = get_viewport_rect().size
	view_zoom=maxf(0.1,minf(size.x/room.layout.width,(size.y-top_margin)/room.layout.height))
	var center: Vector2 = Vector2(room.layout.width,room.layout.height)/2-Vector2(0,top_margin/(2*view_zoom))
	view_origin=center-size/view_zoom/2
	camera.zoom=Vector2.ONE*view_zoom
	camera.position=center
	camera.force_update_scroll()

func fit_boss_room() -> void:
	if camera==null: return
	var size: Vector2 = get_viewport_rect().size
	var rules: Script = preload("res://scripts/combat/boss_room.gd")
	var frame: Rect2 = rules.ARENA_BOUNDS.grow(rules.LIGHTNING_RADIUS)
	# 固定保留空中重锤的头顶空间，战斗中不根据角色或招式重新构图。
	frame.position.y-=180; frame.size.y+=180
	if overview: frame=frame.grow(96)
	view_zoom=maxf(0.1,minf((size.x-48)/frame.size.x,(size.y-48)/frame.size.y))
	var visible: Vector2 = size/view_zoom
	view_origin=frame.get_center()-visible/2
	camera.zoom=Vector2.ONE*view_zoom
	camera.position=frame.get_center()
	camera.force_update_scroll()
	var environment: Node2D = get_node_or_null("TangguMap/Environment")
	if environment==null and backdrop!=null:
		environment=backdrop.get_node_or_null("Floor/Environment")
	if environment!=null: environment.cover_view(Rect2(view_origin,visible))
