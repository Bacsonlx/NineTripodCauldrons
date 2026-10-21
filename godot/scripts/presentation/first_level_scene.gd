extends "res://scripts/presentation/training_scene.gd"

var overview: bool = false
var overview_button: Button

func create_backdrop() -> Node2D:
	return load("res://scripts/presentation/first_level_backdrop.gd").new()

func build_hud() -> void:
	super.build_hud()
	var entry: Button = find_child("OpenFirstLevelMap",true,false)
	var toolbar: Node = entry.get_parent()
	entry.get_parent().remove_child(entry); entry.queue_free()
	var alpha_entry: Button = find_child("OpenAlpha",true,false)
	alpha_entry.get_parent().remove_child(alpha_entry); alpha_entry.queue_free()
	overview_button=Button.new()
	overview_button.text="地图总览 · M"; overview_button.focus_mode=Control.FOCUS_NONE
	overview_button.pressed.connect(toggle_overview)
	toolbar.add_child(overview_button)

func present(snapshot: Dictionary,seconds: float) -> void:
	super.present(snapshot,seconds)
	if state.status=="complete": encounter_label.text="三庭已肃清 · 可继续探索汤谷"
	if state.feedback==null and state.interaction==null:
		interaction_label.text="碑林在西侧 · 祭火在东侧"

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
	var size: Vector2 = get_viewport_rect().size
	view_zoom=minf(size.x/room.layout.width,size.y/room.layout.height)
	view_origin=(Vector2(room.layout.width,room.layout.height)-size/view_zoom)/2
	camera.zoom=Vector2.ONE*view_zoom
	camera.position=Vector2(room.layout.width,room.layout.height)/2
	camera.force_update_scroll()
