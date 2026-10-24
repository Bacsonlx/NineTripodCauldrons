extends RefCounted

const NAMES: Dictionary = {"箭雨":"rain","回风":"backwind","蓄势":"charge"}

static func sources(items: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if item.kind=="技能书" and NAMES.has(item.name):
			result.append({"id":item.id,"name":item.name,"skill":NAMES[item.name],"carrierId":-1,"active":item.region=="meridian" and item.state=="normal" and not item.get("shadow",false)})
		if item.has("specialBook"):
			var book: Dictionary = item.specialBook
			result.append({"id":book.id,"name":book.name,"skill":NAMES[book.name],"carrierId":item.id,"active":item.region=="equipment" and item.state=="normal" and not item.get("shadow",false)})
	return result

static func slots(items: Array[Dictionary], selected: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var available: Array[Dictionary] = sources(items)
	for choice in selected:
		var entry: Dictionary = choice.duplicate()
		entry.active=false
		for source in available:
			if source.id==choice.get("sourceId",-1) and source.skill==choice.get("skill",""): entry.active=source.active
		result.append(entry)
	return result

static func embed(items: Array[Dictionary], equipment: Dictionary, book: Dictionary) -> String:
	if equipment.is_empty() or equipment.name not in ["训练弓","布履"] or equipment.state!="normal" or equipment.get("shadow",false) or equipment.get("locked",false): return "需要可用训练装备"
	if book.is_empty() or not NAMES.has(book.name) or book.kind!="技能书" or book.state!="normal" or book.get("shadow",false) or book.get("locked",false): return "仅可镶嵌可用特殊技能书"
	if equipment.region not in ["equipment","altar","warehouse"] or book.region not in ["meridian","equipment","altar","warehouse"]: return "先拾取书与装备"
	if equipment.has("specialBook"): return "每装备最多一本特殊书，已镶书不可取出"
	equipment.specialBook=book.duplicate(true)
	items.erase(book)
	return "已镶嵌特殊书，原实例与来源标识保留"
