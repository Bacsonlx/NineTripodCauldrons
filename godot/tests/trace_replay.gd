extends RefCounted
const Room = preload("res://scripts/combat/training_room.gd")
var errors: Array[String] = []
var snapshots: int = 0
func json_value(value: Variant) -> Variant:
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = json_value(value[key])
		return result
	if value is Array:
		return value.map(json_value)
	return value
func difference(actual: Variant, expected: Variant, at: String = "") -> String:
	if expected is Dictionary:
		if not actual is Dictionary: return at + " 对象类型不符"
		for key in expected:
			if not actual.has(key): return at + "." + key + " 缺失"
			var issue: String = difference(actual[key], expected[key], at + "." + key)
			if not issue.is_empty(): return issue
	elif expected is Array:
		if not actual is Array or actual.size() != expected.size(): return at + " 数组长度不符"
		for index in expected.size():
			var issue: String = difference(actual[index], expected[index], at + "[%d]" % index)
			if not issue.is_empty(): return issue
	elif (expected is float or expected is int) and (actual is float or actual is int):
		var delta: float = angle_difference(float(actual),float(expected)) if at.ends_with(".angle") else float(actual)-float(expected)
		if absf(delta)>0.001: return at + " 实际%s 参照%s" % [actual,expected]
	elif actual != expected:
		return at + " 实际%s 参照%s" % [actual, expected]
	return ""
func run() -> Dictionary:
	var traces: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rule-traces.json"))
	for trace in traces:
		var rooms: Dictionary = {}
		for event in trace.events:
			if event.op == "create":
				rooms[event.room] = Room.new(event.args[0])
			elif event.op == "snapshot":
				snapshots += 1
				var issue: String = difference(json_value(rooms[event.room].snapshot()), event.expected)
				if not issue.is_empty():
					errors.append(trace.name + ": " + issue)
					break
			else:
				var methods: Dictionary = {"setPaused":"set_paused", "cancelPendingAttacks":"cancel_pending", "cancelInput":"cancel_input", "closeReading":"close_reading"}
				rooms[event.room].callv(methods.get(event.op, event.op), event.args)
	return {"cases":traces.size(),"snapshots":snapshots,"failures":errors}
