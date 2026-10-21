extends "res://scripts/presentation/first_level_scene.gd"

const Journey = preload("res://scripts/journey/room_journey.gd")
var journey: RefCounted

func _ready() -> void:
	var maps: Dictionary = Journey.read_maps()
	if maps.is_empty(): get_tree().quit(1); return
	journey=Journey.new(maps)
	mount_map()
	super._ready()
	overview_button.text="房间总览 · M"

func toggle_overview() -> void:
	super.toggle_overview()
	overview_button.text="跟随角色 · M" if overview else "房间总览 · M"

func mount_map() -> void:
	var previous: Node = get_node_or_null("TangguMap")
	if previous!=null:
		remove_child(previous); previous.queue_free()
	var map: Node2D = load("res://scenes/rooms/%s.tscn" % journey.current_id).instantiate()
	map.name="TangguMap"; add_child(map)

func create_room(_layout: Dictionary) -> TrainingRoom:
	return journey.active

func _physics_process(seconds: float) -> void:
	super._physics_process(seconds)
	if journey.consume_transition(): present_new_room()

func present_new_room() -> void:
	controls.interrupt()
	mount_map()
	room=journey.active
	room.layout.grips=room.layout.grips.duplicate()
	room.layout.grips[1]=atlas.upperDown.grip.duplicate()
	controls=Controls.new(room)
	for body in enemy_bodies.values(): body.queue_free()
	enemy_bodies.clear()
	for body in arrows.values(): body.queue_free()
	arrows.clear()
	for enemy in room.snapshot().enemies:
		enemy_bodies[enemy.id]=sprite({"bird":"enemy","paper":"enemyPaper","wood":"enemyWood"}[enemy.appearance])
	backdrop.setup(room.layout,atlas,textures)
	overview=false; overview_button.text="房间总览 · M"
	walk_time=0; clock=0
	update_camera(); present(room.snapshot(),0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode==KEY_R and event.pressed and not event.echo:
		if not room.snapshot().paused:
			journey.restart(); present_new_room()
		get_viewport().set_input_as_handled(); return
	super._unhandled_input(event)

func guidance_at(_position: Vector2) -> Dictionary:
	return {"region":room.layout.roomTitle,"landmark":{"safe":"安全房 · 可探索与通行","combat":"清除所有影偶后开门","explore":"阅读并合上残碑后开门"}[room.layout.objective]}

func present(snapshot: Dictionary,seconds: float) -> void:
	super.present(snapshot,seconds)
	var data: Dictionary = journey.snapshot()
	encounter_label.text=room.layout.roomTitle+" · 已探索 %d / 7 房间" % data.visitedRooms+"\n"+("房间已完成 · 所有门已开放" if data.roomComplete else guidance_at(Vector2.ZERO).landmark)
	if data.objective=="combat" and not data.roomComplete:
		var remaining: int = data.enemies.filter(func(enemy: Dictionary): return enemy.group==data.encounter and enemy.phase!="dead").size()
		encounter_label.text=room.layout.roomTitle+" · 第 %d / %d 波" % [data.wave,data.waveCount]+"\n"+("下一波 %.1f 秒后出现" % data.waveDelay if data.waveDelay>0 else "影偶剩余 %d · 清完全部波次后开门" % remaining)
	if data.journeyComplete: encounter_label.text="汤谷流程完成 · 可返回探索\nR 重开整段流程"
	if state.feedback==null and state.interaction==null:
		interaction_label.text="走近门按 F 前往下一房间" if data.roomComplete else "完成本房任务后，来路与出口一起开放"
