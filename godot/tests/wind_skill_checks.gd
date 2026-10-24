extends RefCounted
func room(options: Dictionary = {}) -> TrainingRoom:
	options=options.duplicate(true); options.mode="gameplay"
	var model: TrainingRoom = TrainingRoom.new(options)
	model.energy_enabled=true; model.update({"alpha":{"action":"depart"}},0)
	return model
func run(check: Callable) -> void:
	var model: TrainingRoom = room()
	model.update({"beast":true,"moveX":1,"aim":Vector2(900,548)},0.2)
	var state: Dictionary = model.snapshot()
	check.call(state.has("windPath"),"C引风创建可观察风道和一次追加机会")
	if not state.has("windPath"): return
	check.call(absf(state.player.x-520)<0.01 and state.resources.mana==84 and state.resources.stamina==100 and state.dodgeInvulnerability==0,"引风冲120支付16蓝，不耗精力、不提供无敌")
	check.call(state.windPath.extra==1 and state.cooldowns.wind>7.7 and state.windPath.from==Vector2(400,600) and state.windPath.to.distance_to(Vector2(520,600))<0.01,"首次实际路径建立风道并开始8秒冷却")
	model.update({},0); model.update({"beast":true,"moveX":1},0.2)
	check.call(absf(model.snapshot().player.x-640)<0.01 and model.snapshot().resources.mana==84 and model.snapshot().windPath.extra==0 and model.snapshot().windPath.to.distance_to(Vector2(520,600))<0.01,"第二冲使用一次预付机会，不重建风道、不再次扣蓝")
	var remaining: float = model.snapshot().cooldowns.wind
	model.update({},0); model.update({"beast":true},0)
	check.call(model.snapshot().cooldowns.wind==remaining and model.snapshot().resources.mana==84 and model.snapshot().skillDash.remaining==0,"第三次C拒绝，不刷新冷却或免费续冲")
	var outside: TrainingRoom = room()
	outside.update({"beast":true,"moveX":1},0.2); outside.update({"moveY":1},0.1)
	outside.update({"beast":true},0)
	check.call(outside.snapshot().windPath.extra==1 and outside.snapshot().skillDash.remaining==0,"离开40宽风道不能追加，未消耗机会")
	outside.update({"moveY":-1},0.1); outside.update({"beast":true,"moveX":1},0.2)
	check.call(outside.snapshot().windPath.extra==0,"有效期内返回风道后允许手动追加一次")
	var expired: TrainingRoom = room()
	expired.update({"beast":true},0.2); expired.update({},3.1); expired.update({"beast":true},0)
	check.call(expired.snapshot().windPath.is_empty() and expired.snapshot().skillDash.remaining==0,"三秒过期丢失追加机会，剩余首次冷却仍约束C")
	var blocked: TrainingRoom = room({"obstacle":Rect2(413,580,20,40)})
	blocked.update({"beast":true,"moveX":1},0.2)
	check.call(blocked.snapshot().resources.mana==100 and blocked.snapshot().cooldowns.wind==0 and blocked.snapshot().windPath.is_empty(),"引风完全受阻不支付蓝量、不建立风道或冷却")
	var blur: TrainingRoom = room()
	var controls: PlayerControls = PlayerControls.new(blur)
	controls.key_down(KEY_D); controls.key_down(KEY_C); controls.update(Vector2(900,548),true,0.05)
	var x: float = blur.snapshot().player.x
	controls.interrupt(true)
	var frozen: Dictionary = blur.snapshot()
	blur.update({},5)
	check.call(blur.snapshot().cooldowns.wind==frozen.cooldowns.wind and blur.snapshot().windPath==frozen.windPath,"失焦冻结风道和冷却时钟")
	controls.key_down(KEY_ESCAPE); controls.update(Vector2(900,548),true,0.3)
	check.call(blur.snapshot().player.x==x and blur.snapshot().skillDash.remaining==0 and blur.snapshot().resources.mana==84,"回焦不自动续冲，已生效引风不退款")
