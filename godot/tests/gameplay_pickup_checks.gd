extends RefCounted

func run(check: Callable) -> void:
	var room: TrainingRoom = TrainingRoom.new({"mode":"gameplay","initialItems":[{"name":"羊角","world":Vector2(400,600)}]})
	var initial_count: int = room.snapshot().alpha.items.size()
	room.update({"alpha":{"action":"depart"}},0)
	room.update({},0.02)
	var state: Dictionary = room.snapshot().alpha
	check.call(not state.get("pickupCard",{}).is_empty(),"满仓接近实物产生三秒拾取卡，实物留地")
	if state.get("pickupCard",{}).is_empty(): return
	var id: int = state.pickupCard.id
	check.call(state.items.back().region=="ground","仓满不覆盖已有物品")
	room.update({"alpha":{"action":"quick_altar"}},0)
	check.call(room.snapshot().alpha.items.back().id==id and room.snapshot().alpha.items.back().region=="altar","Tab转移原实例入坛而不复制")
	room.update({"alpha":{"action":"quick_altar"}},0)
	check.call(room.snapshot().alpha.items.size()==initial_count,"同卡只尝试一次，不能复制物品")
	room.update({"alpha":{"action":"drop","id":id}},0)
	room.update({},0.1)
	check.call(room.snapshot().alpha.items.back().region=="ground","主动丢弃后原地不立即自动捡回")
	room.update({"moveX":-1},0.4); room.update({"moveX":1},0.4)
	check.call(room.snapshot().alpha.items.back().region=="ground","满仓再次接近仍保留实物")
	var card: Dictionary = room.snapshot().alpha.pickupCard
	room.set_paused(true); room.update({},4)
	check.call(room.snapshot().alpha.pickupCard==card,"暂停不推进拾取卡有效时间")
	room.set_paused(false); room.update({},4)
	check.call(room.snapshot().alpha.pickupCard.is_empty(),"三秒后卡过期，仓满不会逐帧重新弹卡")

	var quick: TrainingRoom = TrainingRoom.new({"mode":"gameplay","initialItems":[{"name":"快马","world":Vector2(400,600)}]})
	var bow: int = -1
	var horn: int = -1
	var horse: int = -1
	for item in quick.snapshot().alpha.items:
		if item.name=="训练弓": bow=item.id
		if item.name=="羊角": horn=item.id
		if item.name=="快马": horse=item.id
	quick.update({"alpha":{"action":"embed","equipmentId":bow,"glyphId":horn}},0)
	quick.update({"alpha":{"action":"place","id":quick.snapshot().alpha.items.filter(func(item: Dictionary): return item.name=="素食")[0].id,"cell":Vector2i(6,0)}},0)
	quick.update({"alpha":{"action":"pickup","id":horse}},0)
	quick.update({"alpha":{"action":"quick_bind","id":horse}},0)
	quick.update({"alpha":{"action":"depart"}},0)
	var adapter: PlayerControls = PlayerControls.new(quick)
	adapter.key_down(KEY_V); adapter.update(Vector2(900,548),true,0)
	check.call(quick.snapshot().alpha.quickItemId==-1 and quick.snapshot().alpha.quickItem.is_empty() and quick.snapshot().itemEffects.haste>0,"V只消费真实器实例并启动快马，引用随消费清空")
	quick.update({"alpha":{"action":"drop","id":horse}},0)
	check.call(quick.snapshot().alpha.quickItemId==-1 and quick.snapshot().alpha.quickItem.is_empty(),"丢弃被引用器后快捷栏立即失效")
