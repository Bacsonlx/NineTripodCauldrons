extends "res://scripts/combat/training_room.gd"

var completed: bool = false
var requested_door: String = ""
var wave_delay: float = 0.0

func _init(data: Dictionary) -> void:
	super(data)
	energy_enabled=true
	completed=data.objective=="safe"

func update(input: Dictionary,seconds: float) -> void:
	super.update(input,seconds)
	if health<=0 or reading: return
	if layout.objective in ["combat","boss"] and status=="complete": completed=true
	if layout.objective=="explore" and exploration.steleRead: completed=true

func update_enemies(seconds: float,protection_at_start: float,dodge_at_start: float) -> void:
	wave_delay=maxf(0,wave_delay-seconds)
	var previous: int = encounter
	super.update_enemies(seconds,protection_at_start,dodge_at_start)
	if encounter!=previous and encounter<layout.encounters.size(): wave_delay=1.2

func encounter_ready(group: Dictionary) -> bool:
	return wave_delay<=0.000001 and (encounter>0 or super.encounter_ready(group))

func obstacles() -> Array:
	var result: Array = super.obstacles()
	if not completed: result.append_array(layout.get("doors",[]))
	return result

func nearest_interaction() -> Dictionary:
	var closest: Dictionary = super.nearest_interaction()
	if closest.has("dropId") and closest.reason==null: return closest
	var origin: Vector2 = point(player)
	var distance: float = origin.distance_to(closest.point) if not closest.is_empty() and not closest.has("dropId") else INF
	for door in layout.get("doors",[]):
		var location: Vector2 = point(door.point)
		var gap: float = origin.distance_to(location)
		if gap>80 or gap>=distance or not clear_path(origin,location): continue
		var reason: Variant = "影散后无法过门" if status=="failed" else "暂停中无法过门" if paused or reading else "完成本房间任务后开门" if not completed else null
		closest={"id":"door:"+door.id,"doorId":door.id,"point":location,"label":door.get("routeLabel","前往")+" · "+door.title,"reason":reason}
		distance=gap
	return closest

func interact() -> void:
	var target: Dictionary = nearest_interaction()
	if target.is_empty(): return
	if target.has("doorId"):
		if target.reason!=null: feedback={"text":target.reason,"remaining":1.6,"healed":false}
		else: requested_door=target.doorId
		return
	super.interact()

func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.camps=layout.get("camps",[]).duplicate(true)
	data.roomId=layout.roomId; data.roomTitle=layout.roomTitle
	data.roomComplete=completed; data.objective=layout.objective
	data.wave=mini(encounter+1,layout.encounters.size()); data.waveCount=layout.encounters.size()
	data.waveDelay=wave_delay
	return data

func travel_state() -> Dictionary:
	return {"health":health,"healthMax":health_max,"cooldown":cooldown,"pierce":pierce_cooldown,"rain":rain_cooldown,"dodge":dodge_cooldown,"recovery":skill_recovery,"hurt":hurt,"protection":protection,"mana":mana,"stamina":stamina,"staminaDelay":stamina_delay,"specialCooldowns":special_cooldowns.duplicate(),"chargeRemaining":charge_remaining,"chargeLayers":charge_layers}

func arrive(travel: Dictionary,location: Vector2,facing: int,generation: int) -> void:
	cancel_input()
	special_cooldowns=travel.specialCooldowns.duplicate()
	charge_remaining=travel.chargeRemaining; charge_layers=travel.chargeLayers; wind_path={}
	mana=travel.mana; stamina=travel.stamina; stamina_delay=travel.staminaDelay
	health_max=travel.healthMax
	health=travel.health; cooldown=travel.cooldown; pierce_cooldown=travel.pierce
	rain_cooldown=travel.rain; dodge_cooldown=travel.dodge; skill_recovery=travel.recovery
	hurt=travel.hurt; protection=travel.protection
	player.x=location.x; player.y=location.y; player.facing=facing; player.angle=facing*PI/2
	player.moving=false; run_id=generation
	cancel_input(); paper_arrows.clear(); arrows.clear(); rains.clear(); effects.clear(); invalid.clear(); feedback.clear()
	interact_held=true
	dodge_time=0; dodge_invulnerability=0; requested_door=""
