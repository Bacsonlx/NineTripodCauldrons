extends RefCounted
const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")

func act(room: TrainingRoom, action: Dictionary) -> void:
	room.update({"alpha":action},0)

func prepare(options: Dictionary = {}) -> TrainingRoom:
	var configuration: Dictionary = {"mode":"gameplay"}
	configuration.merge(options,true)
	return Room.new(configuration)

func run(check: Callable) -> void:
	var mobility: TrainingRoom = prepare()
	act(mobility,{"action":"depart"})
	mobility.update({"backwind":true,"aim":Vector2(1000,548)},0.2)
	check.call(abs(mobility.snapshot().player.x-280)<0.01 and mobility.snapshot().dodgeInvulnerability==0 and mobility.snapshot().cooldowns.backwind>4.7,"无移动回风背向瞄准冲120，无无敌且记录5秒冷却")

	var charge: TrainingRoom = prepare({"enemy":{"x":500,"y":600,"appearance":"wood"},"encounter":Vector2(400,600)})
	act(charge,{"action":"depart"})
	charge.update({"charge":true},0.01)
	charge.update({"fire":true,"aim":Vector2(550,548)},0.3)
	check.call(charge.snapshot().enemies[0].health==127 and charge.snapshot().get("charge",{}).get("layers",0)==1,"蓄势普通箭15×1.5最终取整23，离弦即消费一层")

	var keyboard_room: TrainingRoom = prepare()
	act(keyboard_room,{"action":"depart"})
	var controls: PlayerControls = Controls.new(keyboard_room)
	controls.key_down(KEY_T); controls.key_up(KEY_T)
	controls.update(Vector2(900,548),true,0.01)
	check.call(keyboard_room.snapshot().charge.layers==2,"T短按脉冲对应羁绊蓄势，不被同帧松键吞掉")

	var blocked: TrainingRoom = prepare({"obstacle":Rect2(413,580,20,40)})
	act(blocked,{"action":"depart"})
	blocked.update({"backwind":true,"moveX":1},0.2)
	check.call(blocked.snapshot().player.x==400 and blocked.snapshot().cooldowns.backwind==0,"回风完全受阻拒绝且不扣冷却")
	var partial: TrainingRoom = prepare({"obstacle":Rect2(460,580,20,40)})
	act(partial,{"action":"depart"})
	partial.update({"backwind":true,"moveX":1},0.2)
	check.call(partial.snapshot().player.x<=448 and partial.snapshot().player.x>400 and partial.snapshot().cooldowns.backwind>4.7,"回风按路径分段受实体阻断，部分位移支付一次")
	var air: TrainingRoom = prepare()
	act(air,{"action":"depart"})
	air.update({"charge":true},0.01)
	air.update({"fire":true,"aim":Vector2(200,548)},0.1)
	check.call(air.snapshot().charge.layers==1,"蓄势射空也在离弦时消层")
	air.update({},0.3)
	air.update({"pierce":true,"aim":Vector2(200,548)},0.3)
	check.call(air.snapshot().charge.layers==1,"穿透箭不消费也不获得普通箭蓄势层")
	air.update({},4)
	check.call(air.snapshot().charge.layers==0,"蓄势四秒到期清除剩层")
	var cancel: TrainingRoom = prepare()
	act(cancel,{"action":"depart"})
	var canceled_controls: PlayerControls = Controls.new(cancel)
	canceled_controls.key_down(KEY_G)
	canceled_controls.interrupt(true); canceled_controls.key_down(KEY_ESCAPE)
	canceled_controls.update(Vector2(900,548),true,0.2)
	check.call(cancel.snapshot().player.x==400 and cancel.snapshot().cooldowns.backwind==0,"失焦清除G回风待发意图，恢复不补发回风")
	canceled_controls.key_down(KEY_D); canceled_controls.key_down(KEY_G)
	canceled_controls.update(Vector2(900,548),true,0.05)
	var stopped: float = cancel.snapshot().player.x
	canceled_controls.interrupt(true); canceled_controls.key_down(KEY_ESCAPE)
	canceled_controls.update(Vector2(900,548),true,0.3)
	check.call(cancel.snapshot().player.x==stopped and cancel.snapshot().skillDash.remaining==0,"暂停中断已开始的回风，回焦不自动续冲")
