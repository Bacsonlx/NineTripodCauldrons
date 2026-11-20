extends RefCounted
## 装备外观检查：人物身上的挂件必须与真实穿戴一致，且契类道具绝不出现。

const Appearance = preload("res://scripts/alpha/equipment_appearance.gd")

func item(title: String,kind: String,region: String,glyphs: Array = []) -> Dictionary:
	return {"id":1,"name":title,"kind":kind,"region":region,"state":"normal","glyphs":glyphs}

func run(check: Callable) -> void:
	# 训练弓与布履在装备区 -> 挂到 weapon 与 feet。
	var equipped: Array[Dictionary] = [item("训练弓","装备","equipment"),item("布履","装备","equipment")]
	var appearance: Dictionary = Appearance.describe(equipped)
	check.call(appearance.slots.has("weapon") and appearance.slots.has("feet"), "装备区的训练弓与布履进入人物外观槽位")
	check.call(str(appearance.slots.weapon.name)=="训练弓" and str(appearance.slots.feet.name)=="布履", "武器与鞋履槽位对应正确装备")
	check.call(appearance.effects.is_empty(), "未嵌符时没有生效符")
	# 符要嵌入装备才随装备生效。
	var horn: Dictionary = item("羊角","符","equipment")
	var with_glyph: Array[Dictionary] = [item("训练弓","装备","equipment",[horn]),item("布履","装备","equipment")]
	var glyph_appearance: Dictionary = Appearance.describe(with_glyph)
	check.call(glyph_appearance.slots.has("head") and str(glyph_appearance.slots.head.name)=="羊角", "嵌入装备的羊角进入头部槽位")
	check.call(glyph_appearance.effects.has("羊角"), "嵌入的符记入生效符列表")
	# 符不在装备区、没被嵌入 -> 不应上身。
	var loose: Array[Dictionary] = [item("训练弓","装备","equipment"),item("羊角","符","warehouse")]
	var loose_appearance: Dictionary = Appearance.describe(loose)
	check.call(not loose_appearance.slots.has("head"), "未嵌入装备的符不上人物身上")
	check.call(not loose_appearance.effects.has("羊角"), "未嵌入的符不计入生效符")
	# 契在祭坛生效，神兽是随行：两者都不得出现在人物身上。
	var pacts: Array[Dictionary] = [item("训练弓","装备","equipment"),item("素食","契","altar"),item("涂炭","契","equipment"),item("青龙","神兽","equipment"),item("白虎","神兽","equipment")]
	var pact_appearance: Dictionary = Appearance.describe(pacts)
	for slot in ["head","body","hand","back"]:
		if pact_appearance.slots.has(slot):
			check.call(false, "契与神兽不得出现在人物 %s 槽位" % slot)
	check.call(not pact_appearance.effects.has("素食") and not pact_appearance.effects.has("青龙"), "契与神兽不进入生效符列表")
	# 影子、锁定、燃烧中的物品不算穿戴。
	var not_worn: Array[Dictionary] = [
		{"id":2,"name":"训练弓","kind":"装备","region":"equipment","state":"normal","shadow":true},
		{"id":3,"name":"布履","kind":"装备","region":"equipment","state":"normal","locked":true},
		{"id":4,"name":"羊角","kind":"符","region":"equipment","state":"burning"},
	]
	var not_worn_appearance: Dictionary = Appearance.describe(not_worn)
	check.call(not_worn_appearance.slots.is_empty(), "影子、锁定与燃烧中的物品不进入人物外观")
	# 同槽后到者不覆盖先到者。
	var two_weapons: Array[Dictionary] = [item("训练弓","装备","equipment"),{"id":9,"name":"训练弓","kind":"装备","region":"equipment","state":"normal"}]
	var two_appearance: Dictionary = Appearance.describe(two_weapons)
	check.call(two_appearance.slots.size()==1, "同槽多件装备只挂一件")
	# 签名稳定：相同输入得到相同签名，不同穿戴得到不同签名。
	var again: Dictionary = Appearance.describe(with_glyph)
	check.call(str(again.signature)==str(glyph_appearance.signature), "相同穿戴得到相同签名，不触发过渡")
	check.call(str(Appearance.describe(equipped).signature)!=str(glyph_appearance.signature), "不同穿戴得到不同签名")
