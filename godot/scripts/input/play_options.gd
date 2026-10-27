extends RefCounted

const Journey = preload("res://scripts/journey/room_journey.gd")

static func parse(arguments: Array) -> Dictionary:
	var values: Dictionary = {}
	var index: int = 0
	while index<arguments.size():
		var argument: String = str(arguments[index])
		index+=1
		if argument in ["--layout-audit","--native-suite","--native-probe"]:
			if index>=arguments.size() or str(arguments[index]).is_empty() or str(arguments[index]).begins_with("--"):
				return {"error":argument+" 缺少输出路径"}
			index+=1
			continue
		var parts: PackedStringArray = argument.split("=",true,1)
		if parts.size()!=2 or parts[0] not in ["--test","--room","--health","--mana","--stamina","--seed","--quality"]:
			return {"error":"未知或缺值参数："+argument}
		values[parts[0].trim_prefix("--")]=parts[1]
	var mode: String = values.get("test","level")
	if mode not in ["level","boss","drops","alpha"]: return {"error":"未知专项内容："+mode}
	if values.has("quality") and values.quality not in ["high","medium","low","auto"]:
		return {"error":"未知画质档位："+str(values.quality)}
	var gameplay_values: Array = values.keys().filter(func(key): return key not in ["test","quality"])
	if mode=="alpha" and not gameplay_values.is_empty(): return {"error":"背包白盒不接受房间、资源或掉落种子参数"}
	var room_id: String = values.get("room","boss" if mode=="boss" else "court1" if mode=="drops" else "entry")
	if room_id not in Journey.ROOM_IDS: return {"error":"未知房间："+room_id}
	if mode=="boss" and room_id!="boss": return {"error":"Boss 专项只能指定 boss 房间"}
	var result: Dictionary = {"mode":mode,"startRoom":room_id,"potionDrops":true,"health":100,"mana":100,"stamina":100}
	if values.has("quality"): result.quality=values.quality
	for key in ["health","mana","stamina","seed"]:
		if not values.has(key): continue
		if not str(values[key]).is_valid_int(): return {"error":key+" 必须是整数"}
		var number: int = int(values[key])
		if number<(1 if key=="health" else 0) or key!="seed" and number>100: return {"error":key+" 超出范围"}
		result["dropSeed" if key=="seed" else key]=number
	return result
