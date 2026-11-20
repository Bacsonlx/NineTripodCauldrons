extends RefCounted

const Profile = preload("res://scripts/hub/profile.gd")
const Journey = preload("res://scripts/journey/room_journey.gd")
const Save = preload("res://scripts/hub/journey_save.gd")

func run(check: Callable) -> void:
	var path: String = "/private/tmp/jiuding-hub-test-%d.save" % Time.get_ticks_usec()
	var profile: RefCounted = Profile.new(path)
	check.call(profile.data.resources==0 and profile.data.preparation.size()==6,"新玩家免费六件方案，不依赖筹备资源")
	check.call(profile.departure_error().is_empty(),"默认方案可合法免费出征")
	check.call(profile.buy("虎牙").contains("已加入"),"商店额外物品能进入真实空间")
	check.call(profile.cost()==10 and profile.data.resources==0,"准备购买尚不扣费")
	check.call(profile.buy("虎牙").contains("同名"),"额外同名商品限一件")
	profile.buy("燧火")
	check.call(profile.buy("羊角").contains("最多"),"商店每次最多额外两件")
	check.call(not profile.departure_error().is_empty(),"资源不足时阻止出发")
	profile.data.resources=60; profile.data.unlocks=["bow_horn"]
	check.call(profile.select_recipe("bow_horn").contains("已更新"),"已解锁配方替换基础装备")
	check.call(profile.cost()==40,"打造与额外购买合计准确")
	check.call(profile.preparation().find_item_by_name("训练弓").glyphs[0].name=="羊角","打造携带预嵌符实物")
	var journey: RefCounted = Journey.new(Journey.read_maps(),{"dropSeed":31,"potionDrops":true,"initial_backpack":profile.data.preparation})
	check.call(profile.depart(journey),"合法出发保存本局并支付一次")
	check.call(profile.data.resources==20 and not profile.data.active.is_empty(),"出发只扣本次总成本")
	check.call(not profile.depart(journey) and profile.data.resources==20,"重复出发不能重复扣费或另开一局")
	var resumed: RefCounted = Profile.new(path)
	check.call(resumed.data.resources==20 and resumed.data.active.checkpoint.seed==31,"磁盘恢复保留付款与固定种子")
	var restored: RefCounted = Journey.new(journey.layouts,resumed.data.active.checkpoint.options)
	Save.unpack(restored,resumed.data.active.checkpoint)
	check.call(restored.inventory.items.size()==journey.inventory.items.size(),"首间房初始恢复保留付费物品，不再收费")
	check.call(restored.inventory.runtime.random.state==journey.inventory.runtime.random.state,"恢复保留规则随机数状态")
	journey.rooms.court1=journey.create_room(journey.layouts.court1)
	journey.rooms.court1.completed=true
	check.call(profile.checkpoint(journey),"房间结算点可保存")
	check.call(profile.prepare_settlement(journey,"death"),"阵亡产生可恢复的待确认结算")
	check.call(profile.data.settlement.reward==10 and profile.data.resources==20,"完成战斗房才记收益，确认前不入账")
	check.call(profile.prepare_settlement(journey,"death") and profile.data.settlement.reward==10,"重复准备结算不累加奖励")
	var settlement_id: int = -1
	for item in profile.data.settlement.candidates:
		if item.name=="羊角": settlement_id=item.id; break
	check.call(settlement_id!=-1 and profile.finish_settlement(settlement_id),"合法候选可选为一件残影")
	check.call(profile.data.resources==30 and profile.data.incense==1,"正常局末统一发资源和一次香火")
	check.call(profile.data.heritage.size()==1 and profile.data.heritage[0].shadow,"仅留下残影，没有永久实物库存")
	check.call(not profile.finish_settlement(settlement_id) and profile.data.resources==30,"重复确认结算不会重复领取")
	check.call(profile.shop_names().is_empty() and profile.cost()==0,"回屋不自动续订付费方案")
	var next: RefCounted = Journey.new(journey.layouts,{"dropSeed":32,"initial_backpack":profile.data.preparation})
	profile.depart(next)
	check.call(profile.abandon(),"主动放弃结束进行中的征程")
	check.call(profile.data.resources==30 and profile.data.incense==1 and profile.data.heritage.is_empty(),"放弃不发奖励且失去携带残影，保留账户与解锁")
	check.call(Profile.new(path).data.active.is_empty(),"放弃结果跨重启保持，不恢复旧征程")
	var victory: RefCounted = Journey.new(journey.layouts,{"dropSeed":33,"initial_backpack":profile.data.preparation})
	profile.depart(victory)
	for id in ["court1","court2","court3","dry_creek","altar","thunder_approach","boss"]:
		victory.rooms[id]=victory.create_room(victory.layouts[id])
		victory.rooms[id].completed=true
	victory.rooms.boss.enemies[0].health=0
	victory.rooms.boss.enemies[0].phase="dead"
	victory.rooms.boss.status="complete"
	victory.current_id="boss"; victory.active=victory.rooms.boss
	profile.checkpoint(victory)
	var after_boss: RefCounted = Profile.new(path)
	var restored_boss: RefCounted = Journey.new(victory.layouts,after_boss.data.active.checkpoint.options)
	Save.unpack(restored_boss,after_boss.data.active.checkpoint)
	check.call(restored_boss.active.completed and restored_boss.active.enemies[0].health==0 and not restored_boss.complete(),"战后检查点恢复已败 Boss，出口之前不算胜利")
	victory.rooms.end=victory.create_room(victory.layouts.end)
	victory.current_id="end"; victory.active=victory.rooms.end
	check.call(victory.complete() and profile.prepare_settlement(victory,"victory"),"满足原通关条件且抵达出口后可结算胜利")
	var battle_rooms: int = 0
	for room in victory.rooms.values():
		if room.completed and room.layout.objective in ["combat","boss"]: battle_rooms+=1
	check.call(profile.data.settlement.reward==battle_rooms*10+30 and profile.data.settlement.unlocks.has("boots_brush"),"胜利包括 Boss 房、额外奖励及首次通关配方")
	var beast: Dictionary = victory.inventory.find_item_by_name("青龙")
	check.call(profile.finish_settlement(beast.id),"有容器归属的神兽可以转为传承残影")
	var shadow: Dictionary = profile.preparation().items.back()
	check.call(shadow.shadow and shadow.region=="altar" and profile.departure_error().is_empty(),"神兽残影能合法摆进祭坛，无随行技能")
	var incense_run: RefCounted = Journey.new(journey.layouts,{"dropSeed":34,"initial_backpack":profile.data.preparation})
	profile.depart(incense_run)
	check.call(profile.prepare_settlement(incense_run,"incense") and profile.data.settlement.reward==0,"香尽结算可用且无胜利额外奖励")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
