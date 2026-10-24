extends RefCounted
const Boss = preload("res://scripts/combat/boss_room.gd")
func run(check: Callable) -> void:
	var helper = load("res://tests/item_use_checks.gd").new()
	var repeat: TrainingRoom = helper.setup({"initialItems":[{"name":"快马"}]})
	var first: int = helper.carry(repeat,"快马")
	var second: int = helper.id(repeat,"快马")
	helper.act(repeat,{"action":"pickup","id":second}); helper.act(repeat,{"action":"depart"})
	helper.use(repeat,Vector2(600,600)); repeat.update({},1)
	helper.act(repeat,{"action":"quick_bind","id":second}); helper.use(repeat,Vector2(600,600))
	check.call(helper.id(repeat,"快马")==second and is_equal_approx(repeat.snapshot().itemEffects.haste,2),"快马生效中重复使用不耗物、不刷新时长")
	repeat.update({},2.01); helper.use(repeat,Vector2(600,600))
	check.call(helper.id(repeat,"快马")==-1 and is_equal_approx(repeat.snapshot().itemEffects.haste,3),"快马到期后同类另一实物可正常使用")
	var morning: TrainingRoom = helper.setup({"initialItems":[{"name":"司晨"},{"name":"司晨"},{"name":"司晨"}],"enemy":{"x":650,"y":600,"appearance":"wood"},"encounter":Vector2(400,600)})
	# 五件器依次放坛，快捷使用后释放各自空间；三次计数属于效果名而非实例。
	var ids: Array = []
	for item in morning.snapshot().alpha.items:
		if item.name=="司晨": ids.append(item.id)
	for index in ids.size():
		helper.act(morning,{"action":"pickup","id":ids[index]})
		helper.act(morning,{"action":"place","id":ids[index],"cell":Vector2i(6+(index%2)*2,1+index/2),"rotated":true})
	helper.act(morning,{"action":"depart"}); morning.update({},0.01)
	for index in ids.size():
		helper.act(morning,{"action":"quick_bind","id":ids[index]}); helper.use(morning,Vector2(650,600))
	check.call(morning.snapshot().itemEffects.morningUses==3 and morning.snapshot().alpha.items.any(func(i: Dictionary): return i.id==ids.back()),"司晨按效果名累计最多三次，第四件保留实物")
	var halted: TrainingRoom = helper.setup({"initialItems":[{"name":"羊角"}]})
	var hoard: int = helper.id(halted,"囤积",true)
	helper.act(halted,{"action":"pickup","id":hoard}); helper.act(halted,{"action":"place","id":hoard,"cell":Vector2i(6,1),"rotated":true})
	var horn: int = helper.id(halted,"羊角",true)
	helper.act(halted,{"action":"pickup","id":horn}); helper.act(halted,{"action":"depart"})
	check.call(halted.snapshot().healthMax==131,"囤积对原型实物取得正常计层")
	helper.act(halted,{"action":"camp"}); helper.act(halted,{"action":"drop","id":hoard}); helper.act(halted,{"action":"depart"})
	check.call(halted.snapshot().healthMax==130,"囤积离坛暂停生命加成，层数保留在原实例")
	helper.act(halted,{"action":"camp"}); helper.act(halted,{"action":"pickup","id":hoard}); helper.act(halted,{"action":"place","id":hoard,"cell":Vector2i(6,1),"rotated":true}); helper.act(halted,{"action":"depart"})
	check.call(halted.snapshot().healthMax==131 and halted.snapshot().health==100,"原囤积回坛恢复旧层，不复制自拾取收益或回血")
	var boss_data: Dictionary = Boss.arena_layout(); boss_data.roomId="entry"; boss_data.mode="gameplay"
	var boss: TrainingRoom = Boss.new(boss_data)
	helper.act(boss,{"action":"prototype_kit"})
	helper.act(boss,{"action":"embed","equipmentId":helper.id(boss,"训练弓"),"glyphId":helper.id(boss,"羊角")})
	helper.act(boss,{"action":"embed","equipmentId":helper.id(boss,"布履"),"glyphId":helper.id(boss,"鼠毫")})
	helper.act(boss,{"action":"place","id":helper.id(boss,"素食"),"cell":Vector2i(6,0),"rotated":true})
	var glyph: int = helper.id(boss,"燧火",true)
	helper.act(boss,{"action":"pickup","id":glyph}); helper.act(boss,{"action":"embed","equipmentId":helper.id(boss,"训练弓"),"glyphId":glyph})
	helper.act(boss,{"action":"depart"}); boss.update({"fire":true,"aim":Vector2(720,468)},0.1); boss.update({},0.6)
	var health: int = boss.snapshot().boss.health
	boss.update({},3.1)
	check.call(boss.snapshot().boss.health==health-6,"索尔可受燧火完整三秒燃烧，派生固定2伤不乘离手破绽")
	var many: Array = []
	for index in 20: many.append({"name":"羊角"})
	var capped: TrainingRoom = helper.setup({"initialItems":many})
	var accumulating: int = helper.id(capped,"囤积",true)
	helper.act(capped,{"action":"pickup","id":accumulating}); helper.act(capped,{"action":"place","id":accumulating,"cell":Vector2i(6,1),"rotated":true})
	var fresh: Array = []
	for item in capped.snapshot().alpha.items:
		if item.name=="羊角" and not item.get("prototype",false) and item.region=="ground": fresh.append(item.id)
	for target in fresh:
		helper.act(capped,{"action":"pickup","id":target}); helper.act(capped,{"action":"drop","id":target})
	helper.act(capped,{"action":"depart"})
	check.call(capped.snapshot().healthMax==145 and capped.snapshot().health==100,"囤积二十次新取得最多15基础生命，叠羊角后145且不补血")
	var saved: Dictionary = capped.snapshot().itemEffects
	saved.morningUses=100; saved.haste=100
	check.call(capped.snapshot().itemEffects.morningUses==0 and capped.snapshot().itemEffects.haste==0,"外部道具效果快照不可更改本局次数或持续时间")
	var respec: TrainingRoom = helper.setup()
	var respec_pact: int = helper.id(respec,"囤积",true)
	helper.act(respec,{"action":"pickup","id":respec_pact}); helper.act(respec,{"action":"place","id":respec_pact,"cell":Vector2i(6,1),"rotated":true})
	helper.act(respec,{"action":"pickup","id":helper.id(respec,"虎牙",true)})
	helper.act(respec,{"action":"depart"})
	# 祭火为合法公开回血入口，填满131后再测试营地试摆。
	respec.layout.exploration=[{"id":"altar","x":400,"y":600}]
	respec.update({"interact":true},0)
	check.call(respec.snapshot().health==131,"囤积加成下祭火可填满131上限")
	helper.act(respec,{"action":"camp"}); helper.act(respec,{"action":"drop","id":respec_pact})
	check.call(respec.snapshot().health==131 and respec.snapshot().healthMax==131 and respec.snapshot().alpha.equipment.healthMax==130,"营地移出囤积只预览130，不截当前131生命")
	helper.act(respec,{"action":"pickup","id":respec_pact}); helper.act(respec,{"action":"place","id":respec_pact,"cell":Vector2i(6,1),"rotated":true}); helper.act(respec,{"action":"depart"})
	check.call(respec.snapshot().health==131 and respec.snapshot().healthMax==131,"营地摆回再出发一次应用，不因中间试摆失血")
	var old: TrainingRoom = helper.setup()
	var old_hoard: int = helper.id(old,"囤积",true)
	helper.act(old,{"action":"pickup","id":old_hoard}); helper.act(old,{"action":"place","id":old_hoard,"cell":Vector2i(6,1),"rotated":true})
	var initial_food: int = helper.id(old,"素食")
	helper.act(old,{"action":"drop","id":initial_food}); helper.act(old,{"action":"pickup","id":initial_food}); helper.act(old,{"action":"depart"})
	check.call(old.snapshot().healthMax==130,"初始已持有物丢下重拾不算囤积新道具")
