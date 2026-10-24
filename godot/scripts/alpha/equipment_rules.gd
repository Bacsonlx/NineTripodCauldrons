extends RefCounted

static func slot(item: Dictionary) -> String:
	return "weapon" if item.name=="训练弓" else "feet" if item.name=="布履" else ""

static func available(item: Dictionary) -> bool:
	return item.state=="normal" and not item.get("shadow",false) and not item.get("locked",false)

static func preview(items: Array[Dictionary]) -> Dictionary:
	var effects: Array[String] = []
	var enabled: Array[int] = []
	var slots: Array[String] = []
	for item in items:
		var part: String = slot(item)
		if item.region!="equipment" or part.is_empty() or item.state!="normal" or item.get("shadow",false) or slots.has(part): continue
		slots.append(part); enabled.append(item.id)
		for glyph in item.get("glyphs",[]):
			if not effects.has(glyph.name): effects.append(glyph.name)
	return {"healthMax":130 if effects.has("羊角") else 100,"pickupRadius":84.0 if effects.has("鼠毫") else 80.0,"effects":effects,"enabledIds":enabled}

static func embed(items: Array[Dictionary], equipment: Dictionary, glyph: Dictionary) -> String:
	if slot(equipment).is_empty() or not available(equipment): return "目标不是可装配训练装备"
	if not available(glyph) or glyph.kind!="符": return "需要一张可用实物符"
	if equipment.region not in ["equipment","warehouse","altar"] or glyph.region not in ["equipment","warehouse","altar"]: return "先将装备与实物符放入可整理区域"
	if equipment.get("glyphs",[]).size()>=3: return "每件装备最多三张符，已嵌入的符不可拆下"
	if not equipment.has("glyphs"): equipment.glyphs=[]
	equipment.glyphs.append(glyph.duplicate(true)); items.erase(glyph)
	if not equipment.get("mainGlyph",false): select_main(equipment,glyph.id)
	return "已嵌入实物符，不能拆下"

static func select_main(equipment: Dictionary, glyph_id: int) -> String:
	if slot(equipment).is_empty() or not available(equipment): return "目标不是可装配训练装备"
	for glyph in equipment.get("glyphs",[]):
		if glyph.id==glyph_id:
			equipment.mainGlyph=true; equipment.mainGlyphId=glyph.id; equipment.container=glyph.container
			return "已指定唯一主符："+glyph.name
	return "主符必须是此装备已嵌入的实物符"
