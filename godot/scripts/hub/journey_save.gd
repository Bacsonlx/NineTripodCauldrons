extends RefCounted
## 保存规则数据，不保存节点、输入意图或表现对象。

static func capture(model: Object) -> Dictionary:
	var result: Dictionary = {}
	for property in model.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0: continue
		var value: Variant = model.get(property.name)
		if value is RandomNumberGenerator:
			result[property.name+"__rng"]=value.state
		elif not value is Object:
			result[property.name]=value.duplicate(true) if value is Array or value is Dictionary else value
	return result

static func restore(model: Object, values: Dictionary) -> void:
	for property in model.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0: continue
		var key: String = property.name
		var value: Variant = model.get(key)
		if value is RandomNumberGenerator and values.has(key+"__rng"):
			value.state=int(values[key+"__rng"])
		elif values.has(key) and not value is Object:
			var saved: Variant = values[key]
			model.set(key,saved.duplicate(true) if saved is Array or saved is Dictionary else saved)

static func pack(journey: RefCounted) -> Dictionary:
	var rooms: Dictionary = {}
	for id in journey.rooms: rooms[id]=capture(journey.rooms[id])
	return {"options":journey.initial_options.duplicate(true),"current":journey.current_id,
		"generation":journey.generation,"seed":journey.drop_seed,"rooms":rooms,
		"inventory":capture(journey.inventory),"effects":capture(journey.inventory.runtime),
		"departure":journey.departure_inventory_snapshot.duplicate(true)}

static func unpack(journey: RefCounted, saved: Dictionary) -> void:
	journey.rooms.clear()
	journey.drop_seed=int(saved.seed)
	journey.generation=int(saved.generation)+1
	journey.departure_inventory_snapshot=saved.departure.duplicate(true)
	restore(journey.inventory,saved.inventory)
	restore(journey.inventory.runtime,saved.effects)
	for id in saved.rooms:
		var room: TrainingRoom = journey.create_room(journey.layouts[id])
		restore(room,saved.rooms[id])
		room.alpha=journey.inventory
		room.paused=false; room.reading=false
		room.cancel_input(); room.invalidate_obstacles()
		journey.rooms[id]=room
	journey.current_id=saved.current
	journey.active=journey.rooms[journey.current_id]
	journey.active.run_id=journey.generation
	journey.inventory.camp=false
	journey.inventory.departed=true
	journey.inventory.recount()
