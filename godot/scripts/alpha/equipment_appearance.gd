extends RefCounted
## 由已穿戴的装备与符产出「人物外观描述」。
##
## 规则层只描述"身上穿着什么"，表现层不读背包原始结构。
## 契类道具在祭坛生效、不穿戴，因此绝不进入外观描述。
## 神兽是随行而非穿戴，也不挂身上。

# 符 -> 外观槽位。未列出的符不改变人物外观。
const GLYPH_SLOTS: Dictionary = {
	"羊角": "head",
	"虎牙": "body",
	"燧火": "hand",
	"鼠毫": "back",
}
# 装备 -> 外观槽位。
const ITEM_SLOTS: Dictionary = {
	"训练弓": "weapon",
	"布履": "feet",
}
# 装备/符 -> 挂件贴图路径（相对 assets/characters/gear-v1/）。
const ITEM_ART: Dictionary = {
	"训练弓": "training-bow-hand",
	"布履": "cloth-shoes-foot",
	"羊角": "ram-horn-head",
	"虎牙": "tiger-fang-body",
	"燧火": "flint-fire-hand",
	"鼠毫": "rat-whisker-back",
}
# 明确禁止出现在人物身上的类别：契在祭坛生效，神兽是随行。
const EXCLUDED_KINDS: Array[String] = ["契","神兽"]

static func slot_for(title: String) -> String:
	if GLYPH_SLOTS.has(title): return str(GLYPH_SLOTS[title])
	if ITEM_SLOTS.has(title): return str(ITEM_SLOTS[title])
	return ""

static func art_for(title: String) -> String:
	return str(ITEM_ART[title]) if ITEM_ART.has(title) else ""

## 产出外观描述。items 是背包全部物品，只有装备区里真实穿戴的才计入。
static func describe(items: Array[Dictionary]) -> Dictionary:
	var slots: Dictionary = {}
	var effects: Array[String] = []
	for item in items:
		var title: String = str(item.get("name",""))
		if title.is_empty(): continue
		var kind: String = str(item.get("kind",""))
		if EXCLUDED_KINDS.has(kind): continue
		if str(item.get("region",""))!="equipment": continue
		if str(item.get("state",""))!="normal": continue
		if item.get("shadow",false) or item.get("locked",false): continue
		var slot: String = slot_for(title)
		if slot.is_empty(): continue
		# 每槽只挂一件实体；后来者不渲染实体，由表现层退化为光晕标记。
		if slots.has(slot): continue
		slots[slot]={"itemId":int(item.get("id",-1)),"name":title,"art":art_for(title)}
		# 符要嵌进装备才算穿戴；嵌入的符随装备一起生效。
		for glyph in item.get("glyphs",[]):
			var glyph_title: String = str(glyph.get("name",""))
			if glyph_title.is_empty(): continue
			if not effects.has(glyph_title): effects.append(glyph_title)
			var glyph_slot: String = slot_for(glyph_title)
			if glyph_slot.is_empty() or slots.has(glyph_slot): continue
			slots[glyph_slot]={"itemId":int(glyph.get("id",-1)),"name":glyph_title,"art":art_for(glyph_title)}
	return {"version":1,"signature":signature(slots,effects),"slots":slots,"effects":effects}

## 内容签名：只由槽位内容与生效符决定，相同签名不触发任何过渡。
static func signature(slots: Dictionary,effects: Array[String]) -> String:
	var parts: Array[String] = []
	for slot in ["weapon","feet","head","body","hand","back"]:
		if slots.has(slot):
			var entry: Dictionary = slots[slot]
			parts.append(slot+"="+str(entry.get("name","")))
		else:
			parts.append(slot+"=")
	for effect in effects: parts.append("fx:"+effect)
	return "|".join(parts)
