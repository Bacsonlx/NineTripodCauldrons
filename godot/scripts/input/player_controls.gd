class_name PlayerControls
extends RefCounted

signal backpack_toggle_requested

var room: TrainingRoom
var keys: Dictionary = {}
var burn: bool = false
var quick_action: String = ""
var loadout_pulses: Dictionary = {"backwind":false,"charge":false,"beast":false}
var fire: bool = false
var fire_pulse: bool = false
var interact: bool = false
var interact_pulse: bool = false
var skills: Dictionary = {"pierce":false,"rain":false,"dodge":false}

func _init(model: TrainingRoom) -> void:
	room=model

func key_down(code: int,repeated: bool = false) -> void:
	if repeated: return
	# 只读轻量状态，避免每次按键构造整份公开快照（含全部敌人与弹道深拷贝）。
	var hidden: bool = room.ui_paused()
	if code==KEY_ESCAPE:
		if room.reading: room.close_reading()
		else: room.set_paused(not room.paused)
		interrupt()
	elif code==KEY_R:
		if not hidden: room.reset(); interrupt()
	elif code==KEY_F:
		if not hidden or room.reading: interact=true; interact_pulse=true
	elif code==KEY_B:
		backpack_toggle_requested.emit()
	elif code==KEY_X and room.alpha!=null:
		if not room.paused and not room.reading and room.status!="failed": burn=true
	elif not hidden and room.status!="failed":
		if code==KEY_TAB and room.alpha!=null: quick_action="quick_altar"
		elif code==KEY_V and room.alpha!=null: quick_action="use_quick"
		elif code==KEY_Q: skills.pierce=true
		elif code==KEY_E: skills.rain=true
		elif code==KEY_G and room.has_loadout_skills(): loadout_pulses.backwind=true
		elif code==KEY_T and room.has_loadout_skills(): loadout_pulses.charge=true
		elif code==KEY_C and room.has_loadout_skills(): loadout_pulses.beast=true
		elif code==KEY_SPACE: skills.dodge=true
		else: keys[code]=true

func key_up(code: int) -> void:
	keys.erase(code)
	if code==KEY_F: interact=false

func pointer_down(inside: bool) -> void:
	if inside and not room.ui_paused() and room.status!="failed":
		fire=true; fire_pulse=true
func pointer_up() -> void:
	fire=false
func pointer_leave() -> void:
	loadout_pulses={"backwind":false,"charge":false,"beast":false}
	quick_action=""; fire=false; fire_pulse=false; skills.pierce=false; skills.rain=false
	room.cancel_pending()
func interrupt(blur: bool = false) -> void:
	loadout_pulses={"backwind":false,"charge":false,"beast":false}
	if blur: room.set_paused(true)
	keys.clear(); quick_action=""; burn=false; fire=false; fire_pulse=false; interact=false; interact_pulse=false
	skills={"pierce":false,"rain":false,"dodge":false}
	room.cancel_input()
func movement() -> Vector2:
	return Vector2(float(keys.has(KEY_D))-float(keys.has(KEY_A)),float(keys.has(KEY_S))-float(keys.has(KEY_W)))
func update(aim: Vector2,inside: bool,seconds: float) -> Dictionary:
	var was_reading: bool = room.reading
	var move: Vector2 = movement()
	var input: Dictionary = {"moveX":move.x,"moveY":move.y,"aim":aim,"fire":fire or fire_pulse,"pointerInside":inside,"interact":interact or interact_pulse}
	input.merge(skills)
	if room.has_loadout_skills(): input.merge(loadout_pulses)
	if room.alpha!=null: input.burn=burn
	if not quick_action.is_empty(): input.alpha={"action":quick_action}
	room.update(input,seconds)
	loadout_pulses={"backwind":false,"charge":false,"beast":false}
	quick_action=""; burn=false; fire_pulse=false; interact_pulse=false; skills={"pierce":false,"rain":false,"dodge":false}
	if room.reading!=was_reading: interrupt()
	# 每帧只在此处构造一次公开快照，供相机、HUD 与特效共用。
	return room.snapshot()
