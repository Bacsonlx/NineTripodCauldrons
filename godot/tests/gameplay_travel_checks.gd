extends RefCounted
const Journey = preload("res://scripts/journey/room_journey.gd")

func fixture(id: String,target: String,combat: bool=false) -> Dictionary:
	var data: Dictionary = TrainingRoom.new().layout.duplicate(true)
	data.roomId=id; data.roomTitle=id; data.objective="combat" if combat else "safe"
	data.spawn=Vector2(400,600); data.camps=[Vector2(400,600)]; data.obstacles=[]; data.encounters=[]
	data.doors=[{"id":"door","target":target,"targetDoor":"door","title":target,"point":Vector2(400,600),"arrival":Vector2(400,600),"x":200,"y":600,"halfWidth":20,"halfHeight":50,"height":120,"kind":"wall"}]
	if combat: data.encounters=[{"x":400,"y":600,"enemies":[{"x":650,"y":600,"appearance":"bird"}]}]
	return data

func command(run: RefCounted,action: Dictionary) -> void: run.update({"alpha":action},0)
func id_of(run: RefCounted,title: String) -> int:
	for item in run.snapshot().alpha.items:
		if item.name==title: return item.id
	return -1
func cross(run: RefCounted) -> void:
	run.update({"interact":false},0); run.update({"interact":true},0)

func run(check: Callable) -> void:
	var run = Journey.new({"entry":fixture("entry","fight"),"fight":fixture("fight","entry",true)},{"potionDrops":true,"dropSeed":13})
	var exposed: Dictionary = run.snapshot()
	exposed.camps.clear()
	check.call(run.snapshot().camps==[Vector2(400,600)],"公开营地快照不能修改真实整理点")
	var food: Dictionary = run.snapshot().alpha.items.filter(func(item: Dictionary): return item.name=="素食")[0]
	check.call(food.description.contains("待接通"),"未接通的素食详情明确标记本批状态")
	var bow: int = id_of(run,"训练弓")
	command(run,{"action":"embed","equipmentId":bow,"glyphId":id_of(run,"羊角")})
	command(run,{"action":"embed","equipmentId":id_of(run,"布履"),"glyphId":id_of(run,"鼠毫")})
	var pact: int = id_of(run,"素食")
	command(run,{"action":"drop","id":pact})
	command(run,{"action":"depart"})
	cross(run)
	check.call(run.snapshot().roomId=="fight" and run.snapshot().healthMax==130 and run.snapshot().health==100,"过门保留构筑、生命上限与当前血量")
	run.update({},0.02)
	check.call(run.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==pact)[0].region=="ground","同坐标另一房间的实物不能被自动拾取")
	command(run,{"action":"pickup","id":pact})
	check.call(run.snapshot().alpha.message.contains("其他房间"),"显式拾取也不能跨房取物")
	command(run,{"action":"camp"})
	check.call(not run.snapshot().alpha.camp,"未清庭不能利用营地冻结战斗")
	for i in 300:
		var enemy: Dictionary = run.snapshot().enemies[0]
		run.update({"fire":true,"aim":Vector2(enemy.x,enemy.y-52)},0.02)
		if run.snapshot().roomComplete: break
	check.call(run.snapshot().roomComplete,"构筑流程真实击杀完成房间")
	var ground: Array = run.snapshot().alpha.items.filter(func(item: Dictionary): return item.region=="ground" and item.get("roomId","")=="fight")
	check.call(ground.size()==1 and ground[0].name=="羊角","每波首杀生成一件已接通的构筑符")
	check.call(not run.snapshot().drops.is_empty(),"构筑符与原药瓶独立共存")
	var count: int = run.snapshot().alpha.items.size()
	command(run,{"action":"camp"})
	check.call(run.snapshot().alpha.camp,"清庭后可在本房营地点整理")
	var elapsed: float = run.snapshot().alpha.elapsed
	run.update({"moveX":1,"fire":true},5)
	check.call(run.snapshot().alpha.elapsed==elapsed,"营地停时且不接受战斗移动")
	command(run,{"action":"depart"}); cross(run); cross(run)
	check.call(run.snapshot().roomId=="fight" and run.snapshot().alpha.items.size()==count,"往返已清房间不会复制背包或重发首杀奖励")
	var before: Dictionary = run.snapshot().resources
	PlayerControls.new(run.active).interrupt(true)
	run.update({"alpha":{"action":"depart"},"moveX":1},3)
	check.call(run.snapshot().resources==before,"失焦后背包指令不能绕过暂停推进资源")
	PlayerControls.new(run.active).key_down(KEY_ESCAPE)
	run.update({"restart":true},0)
	check.call(run.snapshot().roomId=="entry" and run.snapshot().alpha.items.size()==6 and run.snapshot().healthMax==100,"新局清空旧掉落与装备效果，重新进入入口营地")
