extends "res://scripts/presentation/training_scene.gd"

var overview: bool = false
var overview_button: Button
var hud: Control
var boss_camera_time: float = -1
var boss_camera_run: int = -1
var boss_camera_size: Vector2 = Vector2.ZERO
var boss_camera_overview: bool = false

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
	var snapshot: Dictionary = room.snapshot()
	var player: Vector2 = Vector2(snapshot.player.x,snapshot.player.y)
	var top: float = maxf(144,hud.encounter.position.y+84)
	var bottom: float = 112
	var near_zoom: float = maxf(size.y/720.0,size.x/1440.0)
	var target_zoom: float = near_zoom
	var frame: Rect2 = Rect2()
	if overview:
		frame=rules.ARENA_BOUNDS.grow(rules.LIGHTNING_RADIUS)
	elif snapshot.boss.phase in ["throw_warn","flight"]:
		# 危险通道含空中锤体的举起高度；拉远发生在预警阶段，不能等锤出屏才处理。
		var start: Vector2 = Vector2(snapshot.boss.x,snapshot.boss.y)
		var end: Vector2 = snapshot.throwTarget if snapshot.boss.phase=="throw_warn" else snapshot.hammer.target
		frame=Rect2(player-Vector2(32,112),Vector2(64,144))
		for point in [start,end]:
			frame=frame.expand(point-Vector2(80,260)).expand(point+Vector2(80,64))
	if not overview and not snapshot.lightning.is_empty():
		if not frame.has_area(): frame=Rect2(player-Vector2(32,112),Vector2(64,144))
		for mark in snapshot.lightning:
			var point: Vector2 = Vector2(mark.x,mark.y)
			frame=frame.expand(point-Vector2(80,195)).expand(point+Vector2(80,80))
	if frame.has_area():
		target_zoom=minf(target_zoom,minf((size.x-64)/frame.size.x,maxf(160,size.y-top-bottom)/frame.size.y))
	var delta: float = maxf(0,snapshot.elapsed-boss_camera_time)
	if boss_camera_run!=snapshot.runId or boss_camera_time<0 or size!=boss_camera_size or overview!=boss_camera_overview or overview:
		view_zoom=target_zoom
	else:
		# 拉远立即保证威胁可见，接锤后按有效游戏时间平缓恢复近景；暂停不推进。
		view_zoom=minf(target_zoom,move_toward(view_zoom,target_zoom,delta*1.8))
	boss_camera_time=snapshot.elapsed; boss_camera_run=snapshot.runId
	boss_camera_size=size; boss_camera_overview=overview
	var visible: Vector2 = size/view_zoom
	if frame.has_area():
		view_origin=frame.get_center()-Vector2(0,(top-bottom)/(2*view_zoom))-visible/2
	else:
		view_origin=player-visible/2
		for axis in 2:
			var extent: float = room.layout.width if axis==0 else room.layout.height
			view_origin[axis]=clampf(view_origin[axis],0,maxf(0,extent-visible[axis])) if visible[axis]<=extent else (extent-visible[axis])/2
		view_origin.x=clampf(view_origin.x,player.x-(size.x-32)/view_zoom,player.x-32/view_zoom)
		view_origin.y=clampf(view_origin.y,player.y-(size.y-bottom)/view_zoom,player.y-112-top/view_zoom)
	camera.zoom=Vector2.ONE*view_zoom
	camera.position=view_origin+visible/2
	camera.force_update_scroll()
	var environment: Node2D = get_node_or_null("TangguMap/Environment")
	if environment==null and backdrop!=null:
		environment=backdrop.get_node_or_null("Floor/Environment")
	if environment!=null: environment.cover_view(Rect2(view_origin,visible))
