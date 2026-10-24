extends RefCounted
const Journey = preload("res://scripts/journey/room_journey.gd")
func fixture(id: String,target: String) -> Dictionary:
	var data: Dictionary = TrainingRoom.new().layout.duplicate(true)
	data.roomId=id; data.roomTitle=id; data.objective="safe"; data.spawn=Vector2(400,600)
	data.obstacles=[]; data.encounters=[]; data.camps=[Vector2(400,600)]
	data.doors=[{"id":"door","target":target,"targetDoor":"door","title":target,"point":Vector2(400,600),"arrival":Vector2(400,600),"x":200,"y":600,"halfWidth":10,"halfHeight":20,"height":100,"kind":"wall"}]
	return data
func item_id(run: RefCounted,title: String) -> int:
	for item in run.snapshot().alpha.items:
		if item.name==title: return item.id
	return -1
func command(run: RefCounted,data: Dictionary) -> void: run.update({"alpha":data},0)
func prepare(mana: int, skill: String = "回风") -> RefCounted:
	var run = Journey.new({"entry":fixture("entry","other"),"other":fixture("other","entry")},{"mana":mana})
	configure(run,skill)
	return run
func configure(run: RefCounted,skill: String) -> void:
	command(run,{"action":"embed","equipmentId":item_id(run,"训练弓"),"glyphId":item_id(run,"羊角")})
	command(run,{"action":"embed","equipmentId":item_id(run,"布履"),"glyphId":item_id(run,"鼠毫")})
	var book: int = item_id(run,skill)
	command(run,{"action":"pickup","id":book})
	command(run,{"action":"place","id":book,"cell":Vector2i(1,6),"rotated":true})
	command(run,{"action":"assign_special","slot":0,"sourceId":book})
	command(run,{"action":"depart"})
func run(check: Callable) -> void:
	var poor = prepare(11)
	poor.update({"special1":true,"moveX":1},0.2)
	check.call(poor.snapshot().resources.mana==11 and poor.snapshot().cooldowns.backwind==0 and poor.snapshot().skillDash.remaining==0,"回风差1蓝不能启动或产生冷却")
	var exact = prepare(12)
	exact.update({"special1":true,"moveX":1},0.05)
	check.call(exact.snapshot().resources.mana==0 and exact.snapshot().resources.pendingMana==0,"回风刚好12蓝成功且费用立即完成")
	PlayerControls.new(exact.active).interrupt(true)
	exact.update({},2)
	check.call(exact.snapshot().resources.mana==0 and exact.snapshot().skillDash.remaining==0,"回风生效后失焦中断不退款或续冲")
	var refund = prepare(100)
	refund.update({"pierce":true,"aim":Vector2(1000,548)},0.05)
	check.call(refund.snapshot().resources.mana==88 and refund.snapshot().resources.pendingMana==12,"Q先真实起手，保留待确认蓝量")
	refund.update({"special1":true,"moveX":1},0.05)
	check.call(refund.snapshot().resources.mana==88 and refund.snapshot().resources.pendingMana==0 and refund.snapshot().arrows.is_empty() and refund.snapshot().cooldowns.pierce>3.8,"回风取消Q先退12再付12，Q冷却保留且不补箭")
	var charging = prepare(16,"蓄势")
	charging.update({"special1":true},0)
	check.call(charging.snapshot().resources.mana==0 and charging.snapshot().charge.layers==2 and charging.snapshot().charge.remaining==4,"蓄势刚好16蓝时两层增幅与10秒冷却一次生效")
	charging.update({},0.5); charging.update({"special1":true},0)
	check.call(is_equal_approx(charging.snapshot().charge.remaining,3.5) and charging.snapshot().charge.layers==2,"剩层存在时重复发动不刷新持续时间")
	var insufficient = prepare(15,"蓄势")
	insufficient.update({"special1":true},0)
	check.call(insufficient.snapshot().resources.mana==15 and insufficient.snapshot().charge.layers==0 and insufficient.snapshot().cooldowns.charge==0,"蓄势差1蓝失败不产生层数或冷却")
	var prepaid = prepare(16)
	prepaid.update({"beast":true,"moveX":1},0.2); prepaid.update({},0); prepaid.update({"beast":true,"moveX":1},0.2)
	check.call(prepaid.snapshot().resources.mana==0 and absf(prepaid.snapshot().player.x-640)<0.01,"引风首次刚好16蓝后，零蓝仍可用一次预付追加")
	var priority = prepare(100)
	priority.update({"dodge":true,"beast":true,"special1":true,"moveX":1},0)
	check.call(priority.snapshot().resources.stamina==75 and priority.snapshot().resources.mana==100 and priority.snapshot().cooldowns.wind==0 and priority.snapshot().cooldowns.backwind==0,"同帧闪避先行，不重复支付引风或回风")
	var cross = prepare(100,"蓄势")
	cross.update({"special1":true},0.01); cross.update({"beast":true,"moveX":1},0.05)
	var before: Dictionary = cross.snapshot()
	cross.update({"interact":true},0)
	var after: Dictionary = cross.snapshot()
	check.call(after.roomId=="other" and after.cooldowns.wind==before.cooldowns.wind and after.cooldowns.charge==before.cooldowns.charge and after.charge==before.charge,"过门携带按技能名计的冷却与已获得的蓄势增幅")
	check.call(after.windPath.is_empty() and after.skillDash.remaining==0,"过门清本房风道与未完成位移，不带到另一房间")
	cross.update({"beast":true},0)
	check.call(cross.snapshot().resources.mana==after.resources.mana and cross.snapshot().skillDash.remaining==0,"新房间不能利用旧风道追加")
	var from_snapshot: Dictionary = before.windPath
	from_snapshot.extra=99
	check.call(cross.snapshot().windPath.is_empty(),"修改旧快照不能生成新房间风道")
