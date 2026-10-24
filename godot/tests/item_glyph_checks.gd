extends RefCounted
func run(check: Callable) -> void:
	var helper = load("res://tests/item_use_checks.gd").new()
	var fire: TrainingRoom = helper.setup({"enemy":{"x":550,"y":600,"appearance":"wood"},"encounter":Vector2(400,600)})
	var glyph: int = helper.id(fire,"燧火",true)
	helper.act(fire,{"action":"pickup","id":glyph}); helper.act(fire,{"action":"embed","equipmentId":helper.id(fire,"训练弓"),"glyphId":glyph})
	helper.act(fire,{"action":"depart"}); fire.update({"fire":true,"aim":Vector2(550,548)},0.1); fire.update({},0.2)
	var first: int = fire.snapshot().enemies[0].health
	check.call(first==135 and fire.snapshot().enemies[0].get("burnRemaining",0.0)>0,"燧火直接普通箭只造成15并给三秒单份燃烧")
	fire.set_paused(true); fire.update({},4); check.call(fire.snapshot().enemies[0].health==first,"暂停冻结燃烧周期")
	fire.set_paused(false); fire.update({},3.1)
	check.call(fire.snapshot().enemies[0].health==129 and fire.snapshot().enemies[0].get("burnRemaining",0.0)==0,"燃烧每完整秒2伤共6，不触发递归或暴击")
	var critical: TrainingRoom = helper.setup({"seed":38,"enemy":{"x":550,"y":600,"appearance":"wood"},"encounter":Vector2(400,600)})
	var tooth: int = helper.id(critical,"虎牙",true)
	helper.act(critical,{"action":"pickup","id":tooth}); helper.act(critical,{"action":"embed","equipmentId":helper.id(critical,"训练弓"),"glyphId":tooth})
	helper.act(critical,{"action":"depart"}); critical.update({"fire":true,"aim":Vector2(550,548)},0.1); critical.update({},0.2)
	check.call(critical.snapshot().enemies[0].health==127,"固定种子在虎牙16%窗口内的普通箭暴击最终23伤")
	check.call(critical.snapshot().alpha.appliedEquipment.effects.has("虎牙"),"虎牙由真实嵌符装备来源供给")

	var plain: TrainingRoom = helper.setup({"seed":38,"enemy":{"x":550,"y":600,"appearance":"wood"},"encounter":Vector2(400,600)})
	helper.act(plain,{"action":"depart"}); plain.update({"fire":true,"aim":Vector2(550,548)},0.1); plain.update({},0.2)
	check.call(plain.snapshot().enemies[0].health==135,"相同种子无虎牙时未跨10%基础暴击阈值")
	var data: Dictionary = TrainingRoom.new().layout.duplicate(true)
	data.mode="gameplay"; data.seed=38; data.spawn=Vector2(400,600); data.obstacles=[]
	data.encounters=[{"x":400,"y":600,"enemies":[{"x":550,"y":600,"appearance":"wood"},{"x":650,"y":600,"appearance":"wood"}]}]
	var line: TrainingRoom = helper.setup(data)
	var line_tooth: int = helper.id(line,"虎牙",true)
	helper.act(line,{"action":"pickup","id":line_tooth}); helper.act(line,{"action":"embed","equipmentId":helper.id(line,"训练弓"),"glyphId":line_tooth})
	helper.act(line,{"action":"depart"}); line.update({"pierce":true,"aim":Vector2(900,548)},0.5)
	check.call(line.snapshot().enemies[0].health==90 and line.snapshot().enemies[1].health==90,"同一次穿透攻击共用一次暴击结果，两目标各60伤")
