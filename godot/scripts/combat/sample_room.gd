class_name SampleRoom
extends RefCounted

var player: Dictionary = {"x": 400.0, "y": 600.0, "moving": false, "angle": 0.0, "facing": 0}
var bounds: Rect2 = Rect2(100, 180, 1080, 640)
var obstacle: Rect2 = Rect2(720, 430, 80, 36)
const GRIPS: Array[Vector2] = [Vector2(27, -51), Vector2(24, -48), Vector2(-21, -48), Vector2(-22, -53)]
var arrows: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var shots: int = 0
var next_arrow: int = 0
var next_effect: int = 0
var cooldown: float = 0.0
var windup: float = -1.0
var attack_released: bool = false
var needs_release: bool = false
var paused: bool = false
var run_id: int = 0
var configuration: Dictionary = {}
var enemy: Dictionary = {}
var health: int = 100
var hurt: float = 0.0
var protection: float = 0.0
var status: String = "running"
var route: Array[Vector2] = []
var repath: float = 0.0

func _init(options: Dictionary = {}) -> void:
	configuration = options.duplicate(true)
	run_id = -1
	reset()

func reset() -> void:
	if paused:
		return
	run_id += 1
	var spawn: Vector2 = configuration.get("spawn", Vector2(400, 600))
	var enemy_spawn: Vector2 = configuration.get("enemy", Vector2(840, 600))
	player = {"x": spawn.x, "y": spawn.y, "moving": false, "angle": 0.0, "facing": 0}
	enemy = {"id": 0, "x": enemy_spawn.x, "y": enemy_spawn.y, "health": 60, "phase": "inactive", "timer": 0.0, "angle": 0.0, "struck": false, "flash": 0.0, "knockX": 0.0, "knockY": 0.0, "knockTime": 0.0}
	bounds = configuration.get("bounds", Rect2(100, 180, 1080, 640))
	obstacle = configuration.get("obstacle", Rect2(720, 430, 80, 36))
	arrows.clear()
	effects.clear()
	health = 100
	hurt = 0.0
	protection = 0.0
	status = "running"
	route.clear()
	repath = 0.0
	cooldown = 0.0
	shots = 0
	next_arrow = 0
	next_effect = 0
	needs_release = run_id > 0
	cancel_pending()

func update(input: Dictionary, seconds: float) -> void:
	var steps: int = maxi(1, ceili(seconds / 0.01))
	for index in steps:
		step(input, seconds / steps)

func step(input: Dictionary, seconds: float) -> void:
	if paused or status == "failed":
		return
	var protection_at_start: float = protection
	hurt = maxf(0.0, hurt - seconds)
	protection = maxf(0.0, protection - seconds)
	var movement: Vector2 = Vector2(input.get("moveX", 0.0), input.get("moveY", 0.0)).limit_length()
	if hurt > 0:
		movement = Vector2.ZERO
	var start: Vector2 = Vector2(player.x, player.y)
	var travel: Vector2 = movement * 220.0 * seconds
	if can_walk(Vector2(player.x + travel.x, player.y)):
		player.x += travel.x
	if can_walk(Vector2(player.x, player.y + travel.y)):
		player.y += travel.y
	player.moving = start.distance_to(Vector2(player.x, player.y)) > 0.01
	var aim: Vector2 = input.get("aim", Vector2(player.x + 100, player.y - 52))
	if input.get("pointerInside", true) and aim.distance_to(Vector2(player.x, player.y - 52)) > 4:
		var reference: float = (aim - Vector2(player.x, player.y - 52)).angle()
		if absf(angle_difference(player.facing * PI / 2.0, reference)) > PI / 4.0 + 0.08:
			player.facing = posmod(floori(reference / (PI / 2.0) + 0.5), 4)
		if aim.distance_to(grip()) > 4:
			player.angle = (aim - grip()).angle()
	update_enemy(seconds, protection_at_start)
	if health <= 0:
		return
	if not input.get("fire", false):
		needs_release = false
	if not input.get("pointerInside", true):
		cancel_pending()
		needs_release = input.get("fire", false)
	cooldown = maxf(0.0, cooldown - seconds)
	if input.get("fire", false) and not needs_release and hurt <= 0 and cooldown <= 0.000001 and input.get("pointerInside", true):
		windup = 0.08
		cooldown = 0.35
		attack_released = false
	if windup >= 0:
		windup -= seconds
		if windup <= 0:
			var muzzle: Vector2 = grip()
			var blocked: Dictionary = contact(Vector2(player.x, player.y - 52), muzzle)
			if blocked.is_empty():
				arrows.append({"id": next_arrow, "x": muzzle.x, "y": muzzle.y, "angle": player.angle, "age": 0.0, "initialStep": -windup})
				next_arrow += 1
			else:
				impact(blocked, player.angle)
			shots += 1
			windup = -1.0
			attack_released = true
	var active: Array[Dictionary] = []
	for arrow in arrows:
		var elapsed: float = maxf(0.0, minf(arrow.get("initialStep", seconds), 2.0 - arrow.age))
		arrow.erase("initialStep")
		var start_point: Vector2 = Vector2(arrow.x, arrow.y)
		var end_point: Vector2 = start_point + Vector2.from_angle(arrow.angle) * 700.0 * elapsed
		var hit: Dictionary = contact(start_point, end_point)
		if not hit.is_empty():
			impact(hit, arrow.angle)
			continue
		arrow.x = end_point.x
		arrow.y = end_point.y
		arrow.age += elapsed
		if arrow.age < 2.0 - 0.000001 and bounds.has_point(end_point):
			active.append(arrow)
	arrows = active
	var live_effects: Array[Dictionary] = []
	for effect in effects:
		effect.age += seconds
		if effect.age < 0.65:
			live_effects.append(effect)
	effects = live_effects

func impact(hit: Dictionary, angle: float) -> void:
	var damage: int = 0
	if hit.has("enemy"):
		damage = mini(enemy.health, 15)
		enemy.health -= damage
		enemy.flash = 0.12
		enemy.knockX = cos(angle) * 14.0 / 0.10
		enemy.knockY = sin(angle) * 14.0 / 0.10
		enemy.knockTime = 0.10
		route.clear()
		repath = 0.0
		if enemy.health == 0:
			enemy.phase = "dead"
			enemy.timer = 0.6
			status = "complete"
	effects.append({"id": next_effect, "x": hit.x, "y": hit.y, "age": 0.0, "damage": damage, "damagePosition": Vector2(enemy.x, enemy.y), "angle": angle})
	next_effect += 1

func update_enemy(seconds: float, protection_at_start: float) -> void:
	var player_point: Vector2 = Vector2(player.x, player.y)
	var trigger: Vector2 = configuration.get("encounter", Vector2(740, 600))
	if enemy.phase == "inactive" and trigger.distance_to(player_point) <= 170:
		enemy.phase = "chase"
	enemy.flash = maxf(0.0, enemy.flash - seconds)
	if enemy.phase == "inactive":
		return
	var pushed: bool = enemy.knockTime > 0
	if pushed:
		var elapsed: float = minf(seconds, enemy.knockTime)
		var distance: Vector2 = Vector2(enemy.knockX, enemy.knockY) * elapsed
		var divisions: int = maxi(1, ceili(distance.length() / 2.0))
		for index in divisions:
			if can_walk(Vector2(enemy.x + distance.x / divisions, enemy.y)):
				enemy.x += distance.x / divisions
			if can_walk(Vector2(enemy.x, enemy.y + distance.y / divisions)):
				enemy.y += distance.y / divisions
		enemy.knockTime = maxf(0.0, enemy.knockTime - seconds)
	if enemy.phase == "dead":
		enemy.timer = maxf(0.0, enemy.timer - seconds)
		return
	var swing_until: float = -1.0
	if enemy.phase == "swing":
		swing_until = minf(seconds, enemy.timer)
	elif enemy.phase == "warn" and seconds > enemy.timer:
		swing_until = minf(seconds, enemy.timer + 0.10)
	enemy.timer -= seconds
	var delta: Vector2 = player_point - Vector2(enemy.x, enemy.y)
	if enemy.phase == "chase":
		enemy.angle = delta.angle()
		if delta.length() <= 70:
			enemy.phase = "warn"
			enemy.timer = 0.45
			enemy.struck = false
		elif not pushed:
			var destination: Vector2 = player_point
			var enemy_point: Vector2 = Vector2(enemy.x, enemy.y)
			repath -= seconds
			if not clear_path(enemy_point, player_point):
				if repath <= 0:
					route = find_route(enemy_point, player_point)
					repath = 0.35
				while route.size() > 1 and clear_path(enemy_point, route[1]):
					route.pop_front()
				if not route.is_empty() and enemy_point.distance_to(route[0]) < 3:
					route.pop_front()
				if route.is_empty():
					return
				destination = route[0]
			enemy.angle = (destination - enemy_point).angle()
			var travel: Vector2 = (destination - enemy_point).limit_length(120.0 * seconds)
			if can_walk(Vector2(enemy.x + travel.x, enemy.y)):
				enemy.x += travel.x
			if can_walk(Vector2(enemy.x, enemy.y + travel.y)):
				enemy.y += travel.y
	else:
		if enemy.phase == "warn" and enemy.timer <= 0:
			enemy.phase = "swing"
			enemy.timer += 0.10
		if enemy.phase == "swing" and enemy.timer <= 0:
			enemy.phase = "recover"
			enemy.timer += 0.65
		if enemy.phase == "recover" and enemy.timer <= 0:
			enemy.phase = "chase"
			enemy.timer = 0.0
	if swing_until >= 0 and not enemy.struck and delta.length() <= 70 and absf(angle_difference(enemy.angle, delta.angle())) <= PI / 4.0 and protection_at_start < swing_until and protection <= 0:
		enemy.struck = true
		health = maxi(0, health - 20)
		hurt = 0.12
		protection = 0.6
		cancel_pending()
		needs_release = true
		if health == 0:
			status = "failed"
			player.moving = false

func cancel_pending() -> void:
	windup = -1.0
	attack_released = false

func set_paused(value: bool) -> void:
	paused = value
	cancel_pending()
	needs_release = true
	player.moving = false

func attack_phase() -> String:
	if windup >= 0:
		return "draw"
	if attack_released and cooldown > 0.22:
		return "release"
	if attack_released and cooldown > 0.12:
		return "recover"
	return "idle"

func contact(from: Vector2, to: Vector2) -> Dictionary:
	var body: Rect2 = Rect2(Vector2(obstacle.position.x, obstacle.get_center().y - 120), Vector2(obstacle.size.x, 120 + obstacle.size.y / 2))
	var t: float = segment_rectangle(from, to, body)
	var is_enemy: bool = false
	if enemy.phase != "inactive" and enemy.phase != "dead":
		var candidate: float = segment_rectangle(from, to, Rect2(enemy.x - 18, enemy.y - 82, 36, 74))
		if candidate >= 0 and (t < 0 or candidate < t):
			t = candidate
			is_enemy = true
	if t < 0:
		return {}
	var point: Vector2 = from.lerp(to, t)
	var hit: Dictionary = {"x": point.x, "y": point.y}
	if is_enemy:
		hit.enemy = 0
	return hit

func segment_rectangle(from: Vector2, to: Vector2, rectangle: Rect2) -> float:
	var entry: float = 0.0
	var exit_time: float = 1.0
	for axis in 2:
		var delta: float = to[axis] - from[axis]
		if absf(delta) < 0.00001:
			if from[axis] < rectangle.position[axis] or from[axis] > rectangle.end[axis]:
				return -1.0
		else:
			var first: float = (rectangle.position[axis] - from[axis]) / delta
			var last: float = (rectangle.end[axis] - from[axis]) / delta
			entry = maxf(entry, minf(first, last))
			exit_time = minf(exit_time, maxf(first, last))
			if entry > exit_time:
				return -1.0
	return entry

func grip() -> Vector2:
	return Vector2(player.x, player.y) + GRIPS[player.facing]

func can_walk(point: Vector2) -> bool:
	return bounds.grow(-12).has_point(point) and not obstacle.grow(12).has_point(point)

func clear_path(from: Vector2, to: Vector2) -> bool:
	var steps: int = ceili(from.distance_to(to) / 10.0)
	for index in range(1, steps + 1):
		if not can_walk(from.lerp(to, float(index) / steps)):
			return false
	return true

func find_route(from: Vector2, to: Vector2) -> Array[Vector2]:
	# 与参照相同的32单位四向网格；实际移动仍按脚点碰撞。
	var columns: int = 40
	var rows: int = 29
	var start: Vector2i = Vector2i(floori(from.x / 32), floori(from.y / 32))
	var previous: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	var result: Array[Vector2] = []
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var point: Vector2 = (Vector2(current) + Vector2.ONE * 0.5) * 32
		if point.distance_to(to) <= 48 and clear_path(point, to):
			result.append(to)
			while current != start:
				result.append((Vector2(current) + Vector2.ONE * 0.5) * 32)
				current = previous[current]
			result.reverse()
			return result
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.y < 0 or next.x >= columns or next.y >= rows or previous.has(next):
				continue
			if can_walk((Vector2(next) + Vector2.ONE * 0.5) * 32):
				previous[next] = current
				queue.append(next)
	return result

func snapshot() -> Dictionary:
	return {"player": player.duplicate(), "grip": grip(), "arrows": arrows.duplicate(true), "effects": effects.duplicate(true), "enemies": [enemy.duplicate(true)], "health": health, "hurt": hurt, "protection": protection, "status": status, "shots": shots, "attack": attack_phase(), "paused": paused, "runId": run_id}
