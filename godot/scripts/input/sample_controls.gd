class_name SampleControls
extends RefCounted

var room: SampleRoom
var keys: Dictionary = {}
var fire: bool = false
var fire_pulse: bool = false

func _init(model: SampleRoom) -> void:
	room = model

func key_down(code: int, repeated: bool = false) -> void:
	if repeated:
		return
	if code == KEY_ESCAPE:
		room.set_paused(not room.snapshot().paused)
		interrupt()
	elif code == KEY_R:
		if not room.snapshot().paused:
			room.reset()
			interrupt()
	elif not room.snapshot().paused and room.snapshot().status != "failed":
		keys[code] = true

func key_up(code: int) -> void:
	keys.erase(code)

func pointer_down(inside: bool) -> void:
	if inside and not room.snapshot().paused and room.snapshot().status != "failed":
		fire = true
		fire_pulse = true

func pointer_up() -> void:
	fire = false

func pointer_leave() -> void:
	fire = false
	fire_pulse = false
	room.cancel_pending()

func interrupt(blur: bool = false) -> void:
	if blur:
		room.set_paused(true)
	keys.clear()
	fire = false
	fire_pulse = false
	room.cancel_pending()

func movement() -> Vector2:
	return Vector2(float(keys.has(KEY_D)) - float(keys.has(KEY_A)), float(keys.has(KEY_S)) - float(keys.has(KEY_W)))

func update(aim: Vector2, inside: bool, seconds: float) -> Dictionary:
	var move: Vector2 = movement()
	room.update({"moveX": move.x, "moveY": move.y, "aim": aim, "fire": fire or fire_pulse, "pointerInside": inside}, seconds)
	fire_pulse = false
	return room.snapshot()
