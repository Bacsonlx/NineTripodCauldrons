extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func room() -> TrainingRoom:
	var model: TrainingRoom = TrainingRoom.new({"mode":"gameplay"})
	model.energy_enabled=true
	return model

func item(model: TrainingRoom, title: String) -> Dictionary:
	for entry in model.alpha.items:
		if entry.name==title: return entry
	return {}

func active(model: TrainingRoom, skill: String) -> bool:
	return model.snapshot().alpha.get("skills",{}).get(skill,{}).get("active",false)

func act(model: TrainingRoom, intent: Dictionary) -> void:
	model.update({"alpha":intent},0)

func remove_source(model: TrainingRoom, title: String) -> void:
	# 仅防御性失效测试注入损坏状态；正常换装另经公开营地命令验证。
	model.alpha.items.erase(item(model,title)); model.alpha.recount(); model.update({},0)

func _initialize() -> void:
	var model: TrainingRoom = room()
	check(model.snapshot().alpha.get("skills",{}).size()==5,"初始装备自动提供五项技能，无手动启用步骤")
	check(not model.snapshot().alpha.regions.has("meridian") and not model.snapshot().alpha.has("specialSlots"),"不再存在经脉和旧启用名额")
	check(model.snapshot().alpha.items.all(func(entry: Dictionary): return entry.kind!="技能书" and not entry.has("specialBook")),"开局无书物品或内嵌书")
	var bow: Dictionary = item(model,"训练弓")
	act(model,{"action":"place","id":bow.id,"cell":Vector2i(6,0)})
	check(not active(model,"pierce") and not active(model,"rain") and not active(model,"charge") and active(model,"backwind") and active(model,"wind"),"弓上坛只撤销弓技能与羁绊，不影响履和青龙")
	act(model,{"action":"depart"})
	model.update({"pierce":true,"rain":true,"aim":Vector2(650,600)},0.1)
	check(model.snapshot().resources.mana==100 and model.snapshot().cooldowns.pierce==0 and model.snapshot().cooldowns.rain==0,"无弓Q/E不能起手、扣蓝或产生冷却")
	model.update({"fire":true,"aim":Vector2(900,548)},0.1)
	check(model.snapshot().shots==1,"卸弓仍可执行已确认的人物基础普攻")
	act(model,{"action":"camp"})
	act(model,{"action":"place","id":bow.id,"cell":Vector2i(0,0)})
	check(active(model,"pierce") and active(model,"rain") and active(model,"charge"),"重新穿戴恢复弓技能与羁绊")
	var boots: Dictionary = item(model,"布履")
	act(model,{"action":"place","id":boots.id,"cell":Vector2i(9,0)})
	check(not active(model,"backwind") and not active(model,"charge") and active(model,"rain"),"移除履同时解除回风与蓄势，保留弓技能")
	act(model,{"action":"depart"})
	model.update({"dodge":true,"moveX":1},0.05)
	check(model.snapshot().resources.stamina==75 and model.snapshot().dodgeInvulnerability>0,"卸履仍能基础闪避")
	var forbidden: Vector2i = bow.cell
	act(model,{"action":"place","id":bow.id,"cell":Vector2i(6,0)})
	check(bow.cell==forbidden,"冒险中精细换装被拒绝")
	for title in ["训练弓","布履","青龙"]:
		for region in ["ground","warehouse","altar"]:
			var stored: TrainingRoom = room()
			item(stored,title).region=region; stored.alpha.recount(); stored.update({},0)
			var skill: String = "pierce" if title=="训练弓" else "backwind" if title=="布履" else "wind"
			check(not active(stored,skill),title+"仅持有于"+region+"不授予技能")
		for state in ["burning","ash"]:
			var damaged: TrainingRoom = room()
			item(damaged,title).state=state; damaged.alpha.recount(); damaged.update({},0)
			check(not active(damaged,"pierce" if title=="训练弓" else "backwind" if title=="布履" else "wind"),title+state+"不授予技能")
		var shadow: TrainingRoom = room()
		item(shadow,title).shadow=true; shadow.alpha.recount(); shadow.update({},0)
		check(not active(shadow,"pierce" if title=="训练弓" else "backwind" if title=="布履" else "wind"),title+"残影不恢复技能")
	var pending: TrainingRoom = room()
	act(pending,{"action":"depart"}); pending.update({"pierce":true,"aim":Vector2(900,548)},0.05)
	check(pending.snapshot().resources.pendingMana==12,"穿透前摇真实预扣蓝量")
	var remaining: float = pending.snapshot().cooldowns.pierce
	remove_source(pending,"训练弓")
	check(pending.snapshot().resources.mana==100 and pending.snapshot().resources.pendingMana==0 and pending.snapshot().skill==null and pending.snapshot().arrows.is_empty() and pending.snapshot().cooldowns.pierce==remaining,"前摇失源退款、不补箭、不刷新已开始冷却")
	var pending_rain: TrainingRoom = room()
	act(pending_rain,{"action":"depart"}); pending_rain.update({"rain":true,"aim":Vector2(600,600)},0.1)
	remaining=pending_rain.snapshot().cooldowns.rain
	remove_source(pending_rain,"训练弓")
	check(pending_rain.snapshot().resources.mana==100 and pending_rain.snapshot().resources.pendingMana==0 and pending_rain.snapshot().rains.is_empty() and pending_rain.snapshot().skill==null and pending_rain.snapshot().cooldowns.rain==remaining,"箭雨前摇失源退款且不补落箭，冷却保留")
	var released: TrainingRoom = room()
	act(released,{"action":"depart"}); released.update({"charge":true},0)
	released.update({"fire":true,"aim":Vector2(900,548)},0.1)
	var arrows: Array = released.snapshot().arrows
	check(not arrows.is_empty() and arrows[0].chargeMultiplier==1.5,"普攻离弦时已取得蓄势倍率")
	remove_source(released,"布履")
	check(released.snapshot().arrows==arrows and released.snapshot().charge.layers==0,"解除羁绊保留已离弦攻击及其倍率，仅清未消费层数")
	var rain: TrainingRoom = room()
	act(rain,{"action":"depart"}); rain.update({"rain":true,"aim":Vector2(600,600)},0.5)
	check(not rain.snapshot().rains.is_empty(),"箭雨先真实生效")
	remove_source(rain,"训练弓")
	check(not rain.snapshot().rains.is_empty() and rain.snapshot().resources.mana==72,"生效箭雨失源仍保留且不退款")
	var charged: TrainingRoom = room()
	act(charged,{"action":"depart"}); charged.update({"charge":true},0)
	check(charged.snapshot().charge.layers==2 and charged.snapshot().resources.mana==84,"羁绊授予的蓄势真实支付并生效")
	remove_source(charged,"布履")
	check(charged.snapshot().charge.layers==0 and charged.snapshot().charge.remaining==0 and charged.snapshot().cooldowns.charge==10 and charged.snapshot().resources.mana==84,"羁绊解除清层，不退已生效费用或清冷却")
	var dash: TrainingRoom = room()
	act(dash,{"action":"depart"}); dash.update({"backwind":true,"moveX":1},0.05)
	var position: float = dash.snapshot().player.x
	remove_source(dash,"布履"); dash.update({},0.2)
	check(dash.snapshot().player.x==position and dash.snapshot().skillDash.remaining==0 and dash.snapshot().resources.mana==88,"回风途中失履停止冲刺，已付蓝不退")
	var wind: TrainingRoom = room()
	act(wind,{"action":"depart"}); wind.update({"beast":true,"moveX":1},0.2)
	check(wind.snapshot().windExtraReady,"引风先形成真实追加资格")
	remove_source(wind,"青龙")
	check(wind.snapshot().windPath.is_empty() and not wind.snapshot().windExtraReady and wind.snapshot().resources.mana==84,"失青龙撤销追加而不退即时费用")
	var duplicates: TrainingRoom = room()
	duplicates.alpha.add_item("训练弓","equipment",Vector2i.ZERO); duplicates.alpha.add_item("布履","equipment",Vector2i.ZERO)
	duplicates.alpha.recount(); act(duplicates,{"action":"depart"}); duplicates.update({"charge":true},0)
	check(duplicates.snapshot().charge.layers==2 and duplicates.snapshot().resources.mana==84 and duplicates.snapshot().alpha.get("skills",{}).size()==5,"重复来源与组合不重复授予、叠层或多扣蓝")
	var original_boots: Dictionary = item(duplicates,"布履")
	duplicates.alpha.items.erase(original_boots); duplicates.alpha.recount(); duplicates.update({},0)
	check(active(duplicates,"charge") and duplicates.snapshot().charge.layers==2 and duplicates.snapshot().cooldowns.charge==10,"同名有效来源替换不重复授予、重置层数或冷却")
	var stored_boots: TrainingRoom = room()
	for pair in [["训练弓","羊角"],["布履","鼠毫"]]:
		act(stored_boots,{"action":"embed","equipmentId":item(stored_boots,pair[0]).id,"glyphId":item(stored_boots,pair[1]).id})
	act(stored_boots,{"action":"place","id":item(stored_boots,"布履").id,"cell":Vector2i(6,4),"rotated":true})
	check(item(stored_boots,"布履").region=="warehouse" and not active(stored_boots,"backwind") and not active(stored_boots,"charge"),"公开营地入仓命令真实撤销装备与羁绊资格")
	act(stored_boots,{"action":"drop","id":item(stored_boots,"布履").id})
	check(item(stored_boots,"布履").region=="ground" and not active(stored_boots,"backwind"),"丢地仍不因持有记录获得技能")
	var cycling: TrainingRoom = room()
	act(cycling,{"action":"depart"}); cycling.update({"backwind":true,"moveX":1},0.05)
	act(cycling,{"action":"camp"}); remaining=cycling.snapshot().cooldowns.backwind
	for index in 3:
		act(cycling,{"action":"place","id":item(cycling,"布履").id,"cell":Vector2i(9,0)})
		act(cycling,{"action":"place","id":item(cycling,"布履").id,"cell":Vector2i(3,0)})
	cycling.update({},10)
	check(active(cycling,"backwind") and cycling.snapshot().cooldowns.backwind==remaining,"反复卸装恢复资格但营地不推进或重置冷却")
	cycling.reset()
	check(active(cycling,"charge") and cycling.snapshot().charge.layers==0 and cycling.snapshot().cooldowns.backwind==0,"重试恢复初始来源，清本局效果和冷却")
	print(JSON.stringify({"equipment_source_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
