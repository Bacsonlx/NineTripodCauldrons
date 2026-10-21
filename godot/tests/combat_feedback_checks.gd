extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node2D = load("res://scenes/sample.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	var room: TrainingRoom = game.room
	var target: Dictionary = room.enemies[0]
	room.player.x=400; room.player.y=600
	target.x=455; target.y=600; target.phase="chase"
	room.update({"aim":Vector2(800,549),"fire":true},0.1)
	var hit: Dictionary = room.snapshot()
	check(hit.effects.any(func(effect: Dictionary): return effect.damage==15),"真实普通箭命中产生15点伤害事件")
	var before: Dictionary = hit.duplicate(true)
	game.present(hit,0)
	var effects: Node2D = game.combat_effects
	var impact_count: int = effects.used
	var largest: float = 0
	for sprite in effects.stamps:
		if sprite.visible: largest=maxf(largest,sprite.region_rect.size.x*sprite.scale.x)
	check(largest>=64,"命中反馈具有至少64世界单位的短促冲击层")
	game.present(hit,0)
	check(effects.used==impact_count,"同一真实命中快照重复呈现不会重复产生冲击")
	check(hit==before,"呈现不改写伤害、击退或弹道快照")
	var paused: Dictionary = hit.duplicate(true); paused.paused=true
	game.present(paused,0.2)
	check(effects.used==impact_count,"暂停冻结命中特效寿命")
	var empty: Dictionary = hit.duplicate(true); empty.effects=[]; empty.arrows=[]; empty.attack="idle"; empty.windup=null
	game.present(empty,0.5)
	check(effects.used==0,"短促命中反馈到期完全消退")
	var charge: Dictionary = empty.duplicate(true)
	charge.skill={"kind":"pierce","phase":"windup","remaining":0.06}
	game.present(charge,0)
	largest=0
	for sprite in effects.stamps:
		if sprite.visible: largest=maxf(largest,sprite.region_rect.size.x*sprite.scale.x)
	check(largest>=90,"穿透箭蓄力光晕明显放大且具有阶段动效")
	charge.skill={"kind":"rain","phase":"windup","remaining":0.1}; charge.rainPreview=Vector2(600,550)
	game.present(charge,0)
	check(effects.used>=15,"箭雨预告含旋转光晕、收束与下落箭多层动效")
	var reset: Dictionary = empty.duplicate(true); reset.runId+=1
	game.present(reset,0)
	check(effects.used==0 and effects.bursts.is_empty() and effects.trails.is_empty(),"重试／切房清空旧冲击和弹道拖尾")
	var stress: Dictionary = reset.duplicate(true)
	for i in 90:
		stress.effects.append({"id":i,"x":500,"y":550,"kind":"pierce","damage":0,"angle":0,"target":null})
	game.present(stress,0)
	check(effects.used<=512 and effects.stamps.size()<=512,"密集命中特效使用有上限的复用精灵池")
	stress.effects=[]
	game.present(stress,0.6)
	check(effects.used==0,"密集冲击到期后不残留可见精灵")
	room.reset()
	room.update({"aim":Vector2(400,800)},0)
	room.update({"aim":Vector2(400,800),"pierce":true},0.19)
	var launched: Dictionary = room.snapshot()
	game.present(launched,0)
	var origin: Vector2 = Vector2(417,557)
	check(effects.stamps.any(func(sprite: Sprite2D): return sprite.visible and sprite.position.distance_to(origin)<0.01 and sprite.region_rect.size.x*sprite.scale.x>=60),"向下穿透箭离弦当帧在技能真实发射点产生冲击")
	var launch_count: int = effects.used
	launched.paused=true
	game.present(launched,0.1)
	check(effects.used==launch_count,"离弦后立即暂停，不会在暂停帧追加迟到的冲击")
	game.free()
	print(JSON.stringify({"combat_feedback_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
