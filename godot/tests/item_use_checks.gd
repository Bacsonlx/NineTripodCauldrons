extends RefCounted
const Boss = preload("res://scripts/combat/boss_room.gd")
func id(room: TrainingRoom,title: String, prototype: bool = false) -> int:
	for item in room.snapshot().alpha.items:
		if item.name==title and (not prototype or item.get("prototype",false)): return item.id
	return -1
func act(room: TrainingRoom,data: Dictionary) -> void: room.update({"alpha":data},0)
func setup(options: Dictionary = {}) -> TrainingRoom:
	options=options.duplicate(true); options.mode="gameplay"
	var room: TrainingRoom = TrainingRoom.new(options)
	act(room,{"action":"prototype_kit"})
	act(room,{"action":"embed","equipmentId":id(room,"训练弓"),"glyphId":id(room,"羊角")})
	act(room,{"action":"embed","equipmentId":id(room,"布履"),"glyphId":id(room,"鼠毫")})
	act(room,{"action":"place","id":id(room,"素食"),"cell":Vector2i(6,0),"rotated":true})
	return room
func carry(room: TrainingRoom,title: String) -> int:
	var target: int = id(room,title,true)
	act(room,{"action":"pickup","id":target}); act(room,{"action":"quick_bind","id":target})
	return target
func use(room: TrainingRoom,aim: Vector2) -> void: room.update({"alpha":{"action":"use_quick"},"aim":aim},0)
func run(check: Callable) -> void:
	var stopped: TrainingRoom = setup({"enemy":{"x":650,"y":600,"appearance":"paper"},"encounter":Vector2(400,600)})
	carry(stopped,"司晨"); act(stopped,{"action":"depart"}); stopped.update({},0.4)
	use(stopped,Vector2(650,600)); var position: Vector2 = TrainingRoom.point(stopped.snapshot().enemies[0])
	stopped.update({},0.99)
	check.call(stopped.snapshot().health==100 and stopped.snapshot().paperArrows.is_empty() and TrainingRoom.point(stopped.snapshot().enemies[0])==position,"司晨取消蓄投并停止普通敌一秒")
	stopped.update({},0.85)
	check.call(not stopped.snapshot().paperArrows.is_empty() or stopped.snapshot().health<100,"司晨到期后敌人可重新预警攻击")
	var water: TrainingRoom = setup({"enemy":{"x":650,"y":600,"appearance":"bird"},"encounter":Vector2(400,600)})
	var water_id: int = carry(water,"豕涉"); act(water,{"action":"depart"})
	use(water,Vector2(1000,600))
	check.call(id(water,"豕涉",true)==water_id and water.snapshot().itemEffects.puddle.is_empty(),"水洼超240无效不耗器")
	use(water,Vector2(630,600)); water.update({},0.5)
	check.call(is_equal_approx(water.snapshot().enemies[0].x,614) and id(water,"豕涉",true)==-1,"水洼半径90内敌人移速降低40%，成功消耗原实物")
	var stone: TrainingRoom = setup({"enemy":{"x":580,"y":600,"appearance":"bird"},"encounter":Vector2(400,600)})
	carry(stone,"守冢"); act(stone,{"action":"depart"}); use(stone,Vector2(800,548))
	stone.update({},1.2)
	check.call(stone.snapshot().health==100 and not stone.snapshot().itemEffects.tomb.is_empty() and stone.snapshot().itemEffects.tomb.health<80,"普通敌优先攻击范围内80血墓碑，玩家不受该次伤害")
	check.call(stone.snapshot().enemies[0].phase!="dead" and stone.snapshot().alpha.items.filter(func(item: Dictionary): return item.region=="ground" and not item.get("prototype",false)).is_empty(),"攻击墓碑不产生敌人击杀或物品收益")
	var data: Dictionary = Boss.arena_layout(); data.mode="gameplay"; data.roomId="entry"
	var boss: TrainingRoom = Boss.new(data)
	act(boss,{"action":"prototype_kit"})
	act(boss,{"action":"embed","equipmentId":id(boss,"训练弓"),"glyphId":id(boss,"羊角")})
	act(boss,{"action":"embed","equipmentId":id(boss,"布履"),"glyphId":id(boss,"鼠毫")})
	act(boss,{"action":"place","id":id(boss,"素食"),"cell":Vector2i(6,0),"rotated":true})
	var morning: int = carry(boss,"司晨"); act(boss,{"action":"depart"}); use(boss,Vector2(720,520))
	check.call(id(boss,"司晨",true)==morning and boss.snapshot().itemEffects.morningUses==0,"首领硬控保护，无合法普通目标时司晨不耗物也不计次")
	boss.update({},3.01)
	var before: Dictionary = boss.snapshot()
	use(boss,Vector2(720,520))
	var after: Dictionary = boss.snapshot()
	check.call(after.enemies.size()==4 and after.enemies.all(func(enemy: Dictionary): return enemy.get("stopped",0)==1.0) and after.boss==before.boss,"Boss房司晨只停止已出生普通小怪，不改Boss招式、位置或时钟")
	check.call(id(boss,"司晨",true)==-1 and after.itemEffects.morningUses==1,"存在合法援军时司晨消耗实物并只计一次")
