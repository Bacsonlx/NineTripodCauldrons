extends SceneTree

const Stage = preload("res://scripts/journey/journey_room.gd")
const Journey = preload("res://scripts/journey/room_journey.gd")
var failures: Array[String] = []
var checks: int = 0
var maps: Dictionary

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func stage() -> TrainingRoom:
	var data: Dictionary = maps.entry.duplicate(true)
	data.spawn={"x":720,"y":550}; data.encounters=[]
	return Stage.new(data)

func cast(room: TrainingRoom,action: String,seconds: float = 0.0) -> void:
	room.update({},0)
	room.update({action:true,"aim":Vector2(800,550)},seconds)

func _initialize() -> void:
	maps=Journey.read_maps()
	var room: TrainingRoom = stage()
	check(room.snapshot().has("resources"),"正式房间公开真实蓝量精力状态")
	check(room.snapshot().resources.mana==100 and room.snapshot().resources.stamina==100,"开局蓝量与精力都是100")
	cast(room,"pierce")
	check(room.snapshot().resources.mana==88 and room.snapshot().resources.pendingMana==12 and room.snapshot().cooldowns.pierce==4,"Q成功起手只扣12蓝，进入原4秒冷却")
	room.update({"pierce":true,"aim":Vector2(800,550)},0.1)
	check(room.snapshot().resources.mana==88,"按住技能不重复扣费")
	room.set_paused(true)
	check(room.snapshot().resources.mana==100 and room.snapshot().cooldowns.pierce>3.8,"前摇暂停退款但保留冷却")
	room.update({},3)
	check(room.snapshot().resources.mana==100,"暂停不产生自然回蓝")
	room.set_paused(false); room.update({},4)
	cast(room,"pierce",0.2)
	room.cancel_input()
	check(room.snapshot().resources.mana==88 and room.snapshot().resources.pendingMana==0,"Q离弦后中断不退款")
	room=stage(); cast(room,"rain")
	check(room.snapshot().resources.mana==72 and room.snapshot().cooldowns.rain==8,"E成功起手扣28蓝，保持8秒冷却")
	room.update({"pointerInside":false},0)
	check(room.snapshot().resources.mana==100 and room.snapshot().skill==null,"鼠标离场取消E前摇，恰好退回28")
	room=stage(); room.update({"rain":true,"aim":Vector2(-1000,-1000)},0)
	check(room.snapshot().resources.mana==100 and room.snapshot().cooldowns.rain==0,"E无效落点不扣费不启动冷却")
	room=stage(); cast(room,"rain",0.46); room.cancel_input()
	check(room.snapshot().resources.mana==72 and not room.snapshot().rains.is_empty(),"E已生成固定箭雨后中断不退款或清除箭雨")
	room=stage()
	for i in 3:
		cast(room,"rain",0.46); room.update({},8)
	check(room.snapshot().resources.mana==16,"三次E消耗84，无自然回蓝")
	cast(room,"rain")
	check(room.snapshot().resources.mana==16 and room.snapshot().cooldowns.rain==0 and room.snapshot().feedback.text=="蓝量不足","蓝量不足不进入E前摇或冷却")
	cast(room,"pierce",0.2); room.update({},4); cast(room,"pierce")
	check(room.snapshot().resources.mana==4 and room.snapshot().cooldowns.pierce==0,"剩余4蓝不足Q时不扣蓝")
	var exact: TrainingRoom = stage()
	for i in 5: cast(exact,"pierce",0.2); exact.update({},4)
	cast(exact,"rain",0.46); exact.update({},8)
	check(exact.snapshot().resources.mana==12,"五次Q加一次E后剩12蓝")
	cast(exact,"pierce",0.2)
	check(exact.snapshot().resources.mana==0,"恰好12蓝仍可起手Q并归零")
	exact.update({},4); cast(exact,"rain")
	check(exact.snapshot().resources.mana==0 and exact.snapshot().cooldowns.rain==0,"零蓝时E失败不会进入负数")
	var start: Vector2 = TrainingRoom.point(room.snapshot().player)
	room.update({"fire":true,"moveX":1,"aim":Vector2(1000,550)},0.2)
	check(room.snapshot().shots>0 and room.snapshot().player.x>start.x,"低蓝仍可移动和普通射箭")
	cast(room,"dodge")
	check(room.snapshot().resources.stamina==75 and room.snapshot().resources.mana==4,"闪避只消耗25精力，与蓝量独立")
	room=stage()
	for i in 4:
		cast(room,"dodge")
		if i<3: room.update({},1.001)
	check(absf(room.snapshot().resources.stamina)<0.001,"按原冷却连续四次闪避耗尽精力")
	room.update({},1.001); cast(room,"dodge")
	check(room.snapshot().dodge==0 and room.snapshot().cooldowns.dodge==0 and room.snapshot().feedback.text=="精力不足","精力不足不触发位移或冷却")
	room.update({},0.199)
	check(absf(room.snapshot().resources.stamina)<0.001,"最后一次成功闪避后1.2秒内不恢复")
	room.update({},2.5)
	check(absf(room.snapshot().resources.stamina-25)<0.001,"延迟结束后2.5秒恰好恢复25点")
	cast(room,"dodge")
	check(room.snapshot().dodge>0 and room.snapshot().resources.stamina<0.001,"精力刚好25时可再次闪避")
	var frozen: Dictionary = room.snapshot().resources
	room.set_paused(true); room.update({},10)
	check(room.snapshot().resources==frozen,"暂停冻结精力和恢复等待")
	room.set_paused(false); room.update({},0.01); room.reset()
	check(room.snapshot().resources.mana==100 and room.snapshot().resources.stamina==100 and room.snapshot().resources.staminaDelay==0,"重试恢复双资源并清空恢复等待")
	var coarse: TrainingRoom = stage(); var fine: TrainingRoom = stage()
	cast(coarse,"dodge"); cast(fine,"dodge")
	coarse.update({},2.7)
	for i in 270: fine.update({},0.01)
	check(absf(coarse.snapshot().resources.stamina-fine.snapshot().resources.stamina)<0.0001,"不同时间步长的精力恢复一致")
	var simultaneous: TrainingRoom = stage()
	simultaneous.update({"pierce":true,"rain":true,"dodge":true,"aim":Vector2(800,550)},0)
	check(simultaneous.snapshot().resources.mana==100 and simultaneous.snapshot().resources.stamina==75,"同帧闪避优先，不同时多扣技能蓝量")
	var duel_data: Dictionary = TrainingRoom.new({"enemy":Vector2(650,600),"encounter":Vector2(400,600)}).layout.duplicate(true)
	duel_data.roomId="duel"; duel_data.roomTitle="测试"; duel_data.objective="combat"; duel_data.doors=[]
	var duel: TrainingRoom = Stage.new(duel_data)
	cast(duel,"rain",0.46); duel.update({},0.3)
	check(duel.snapshot().resources.mana==72,"无目标箭雨不凭命中动画回蓝")
	for i in 300:
		var target: Dictionary = duel.snapshot().enemies[0]
		duel.update({"fire":true,"aim":Vector2(target.x,target.y-52)},0.02)
		if duel.snapshot().status=="complete": break
	check(duel.snapshot().enemies[0].phase=="dead" and duel.snapshot().resources.mana==88,"真实普攻击杀后只获4击杀＋12清波蓝量")
	duel.update({},2)
	check(duel.snapshot().resources.mana==88,"重复时间和死亡动画不会重复派发回蓝")
	var full: TrainingRoom = Stage.new(duel_data)
	for i in 300:
		var target: Dictionary = full.snapshot().enemies[0]
		full.update({"fire":true,"aim":Vector2(target.x,target.y-52)},0.02)
		if full.snapshot().status=="complete": break
	check(full.snapshot().status=="complete" and full.snapshot().resources.mana==100,"满蓝击杀和清波奖励截断到100")
	cast(room,"pierce",0.2); room.update({},0.2); cast(room,"dodge")
	var travel: Dictionary = room.travel_state()
	var arriving: TrainingRoom = stage(); arriving.arrive(travel,Vector2(720,550),0,9)
	check(arriving.snapshot().resources.mana==travel.mana and arriving.snapshot().resources.stamina==travel.stamina and arriving.snapshot().resources.staminaDelay==travel.staminaDelay,"过门携带蓝量精力与恢复等待")
	check(travel.mana==88 and travel.stamina==75 and travel.staminaDelay==1.2,"携带测试实际使用非满值与未结束恢复等待")
	var door_data: Dictionary = maps.entry.duplicate(true)
	door_data.spawn={"x":720,"y":550}
	door_data.doors=[{"id":"back","target":"other","targetDoor":"back","title":"另一房","point":{"x":720,"y":550},"arrival":{"x":720,"y":550},"x":200,"y":550,"halfWidth":20,"halfHeight":55,"height":120,"kind":"wall"}]
	var other: Dictionary = door_data.duplicate(true); other.roomId="other"; other.doors[0].target="entry"
	var journey: RefCounted = Journey.new({"entry":door_data,"other":other})
	journey.update({"pierce":true,"aim":Vector2(800,550)},0)
	check(journey.snapshot().resources.mana==88,"过门前技能确已扣蓝")
	journey.update({"interact":true},0)
	check(journey.snapshot().roomId=="other" and journey.snapshot().resources.mana==100 and journey.snapshot().cooldowns.pierce==4,"真实F过门先退未生效技能蓝量，再携带资源和冷却")
	journey.update({"restart":true},0)
	check(journey.snapshot().resources.mana==100 and journey.snapshot().resources.stamina==100,"真实重开流程恢复双资源")
	var reading_data: Dictionary = duel_data.duplicate(true)
	reading_data.encounters=[]; reading_data.objective="explore"
	reading_data.exploration=[{"id":"stele","x":400,"y":600}]
	var reader: TrainingRoom = Stage.new(reading_data)
	cast(reader,"dodge"); reader.update({},0.3)
	reader.update({"moveX":-1},0.25)
	reader.update({"interact":true},0)
	var before_read: Dictionary = reader.snapshot().resources
	reader.update({},5)
	check(reader.snapshot().reading and reader.snapshot().resources==before_read,"残碑阅读期间冻结精力恢复")
	var fallen: TrainingRoom = Stage.new(duel_data)
	cast(fallen,"dodge"); fallen.update({},12)
	var stopped: Dictionary = fallen.snapshot().resources
	fallen.update({},10)
	check(fallen.snapshot().status=="failed" and fallen.snapshot().resources==stopped,"失败后冻结精力与资源等待")
	var expected_mana: int = room.snapshot().resources.mana
	var snapshot: Dictionary = room.snapshot(); snapshot.resources.mana=0
	check(room.snapshot().resources.mana==expected_mana,"修改外部资源快照不污染内部状态")
	print(JSON.stringify({"energy_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
