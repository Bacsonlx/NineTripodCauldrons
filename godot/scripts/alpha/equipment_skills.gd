extends RefCounted

const Equipment = preload("res://scripts/alpha/equipment_rules.gd")
const DEFINITIONS: Dictionary = {
	"pierce":{"name":"穿透箭","key":"Q","requires":["训练弓"]},
	"rain":{"name":"箭雨","key":"E","requires":["训练弓"]},
	"backwind":{"name":"回风","key":"G","requires":["布履"]},
	"charge":{"name":"蓄势","key":"T","requires":["训练弓","布履"]},
	"wind":{"name":"引风","key":"C","requires":["青龙"]},
	"tiger":{"name":"金戈","key":"C","requires":["白虎"]},
	"phoenix":{"name":"火羽","key":"C","requires":["朱雀"]}
}

static func resolve(items: Array[Dictionary],blessing_beast: String = "") -> Dictionary:
	var equipped: Dictionary = {}
	var enabled: Array = Equipment.preview(items).enabledIds
	for item in items:
		if item.region!="equipment" or item.state!="normal" or item.get("shadow",false): continue
		if (enabled.has(item.id) or item.kind=="神兽" and item.name in ["青龙", "白虎", "朱雀"]) and not equipped.has(item.name): equipped[item.name]=item.id
	var beast_kind: String = "wind"
	var beast_title: String = blessing_beast
	if beast_title.is_empty():
		for item in items:
			if item.get("kind","")=="神兽" or item.name in ["青龙", "白虎", "朱雀"]:
				beast_title=item.name; break
	if beast_title=="白虎": beast_kind="tiger"
	elif beast_title=="朱雀": beast_kind="phoenix"
	elif beast_title=="青龙": beast_kind="wind"
	for item in items:
		if item.region=="equipment" and item.state=="normal" and not item.get("shadow",false) and item.get("kind","")=="神兽" and not beast_title.is_empty():
			equipped[beast_title]=item.id
			break
	var target_kinds: Array[String] = ["pierce","rain","backwind","charge",beast_kind]
	var result: Dictionary = {}
	for kind in target_kinds:
		var entry: Dictionary = DEFINITIONS[kind].duplicate(true)
		var missing: PackedStringArray = []
		entry.sourceIds=[]
		for title in entry.requires:
			if equipped.has(title): entry.sourceIds.append(equipped[title])
			else: missing.append(title)
		entry.source="羁绊：训练弓＋布履" if kind=="charge" else "随行："+entry.requires[0] if kind in ["wind", "tiger", "phoenix"] else "装备："+entry.requires[0]
		entry.active=missing.is_empty()
		entry.reason="" if entry.active else "缺少有效穿戴："+"、".join(missing)
		result[kind]=entry
	return result
