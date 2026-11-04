extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(20).timeout.connect(func(): push_error("药瓶场景检查超时"); quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node2D = load("res://scenes/loot_test.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.journey.update({"alpha":{"action":"depart"}},0)
	await process_frame
	check(game.room.potion_drops and game.room.snapshot().drops.is_empty(),"独立灰盒入口启用掉落并从空地面状态启动")
	var original: Dictionary = game.room.snapshot()
	var state: Dictionary = original.duplicate(true)
	state.drops=[{"id":"sample","kind":"mana","x":400,"y":600}]
	state.interaction={"dropId":"sample","reason":null}
	game.loot_view.update_state(state)
	check(game.loot_view.items.size()==1 and game.loot_view.items.sample.position==Vector2(400,600),"只读掉落快照生成地面瓶并按脚点定位")
	check(game.loot_view.items.sample.get_node("Selection").visible,"规则当前F目标显示地面高亮")
	var bottle: Sprite2D = game.loot_view.items.sample.get_node_or_null("Bottle")
	check(bottle!=null and bottle.texture!=null and is_equal_approx(bottle.get_rect().size.y*bottle.scale.y,28),"蓝瓶使用已选皮影药囊纹理并保持28世界单位高度")
	if bottle!=null:
		var initial_y: float = bottle.position.y
		game.loot_view.update_state(state,0.675)
		check(bottle.position.y<initial_y and bottle.position.y>=initial_y-2,"闲置药囊只在脚点上方作不超过2单位的微浮动")
		var frozen_y: float = bottle.position.y
		var paused: Dictionary = state.duplicate(true); paused.paused=true
		game.loot_view.update_state(paused,0.6)
		check(bottle.position.y==frozen_y,"暂停或失焦冻结药囊浮动时钟")
	state.drops.append({"id":"red","kind":"health","x":480,"y":600})
	var read_only: Dictionary = state.duplicate(true)
	game.loot_view.update_state(state)
	var health_bottle: Sprite2D = game.loot_view.items.red.get_node("Bottle")
	check(health_bottle.texture!=bottle.texture and health_bottle.get_rect().size.x*health_bottle.scale.x>bottle.get_rect().size.x*bottle.scale.x,"血囊宽圆、蓝囊棱肩，使用各自纹理并保留轮廓宽度差")
	check(not game.loot_view.items.red.get_children().any(func(child: Node): return child is Label),"药囊本体不再显示灰盒血蓝文字")
	var full: Dictionary = state.duplicate(true); full.interaction={"dropId":"red","reason":"生命已满"}
	game.loot_view.update_state(full)
	check(game.loot_view.items.red.modulate.a==1 and not game.loot_view.items.red.get_node("Selection").visible,"满资源药囊保持完整留地，不显示可拾取目标环")
	check(state==read_only,"呈现不改写传入的公开掉落快照")
	check(game.room.snapshot()==original,"药瓶呈现不反向修改真实资源或地面状态")
	var consumed: Node2D = game.loot_view.items.sample
	var collected: Dictionary = state.duplicate(true)
	collected.drops=[state.drops[1]]; collected.interaction=null
	collected.feedback={"text":"蓝量 +24","remaining":1.2,"healed":false}
	game.loot_view.update_state(collected)
	await process_frame
	check(is_instance_valid(consumed),"规则确认补给后保留短暂消失表现，不在成功当帧生硬删除")
	if is_instance_valid(consumed):
		game.loot_view.update_state(collected,0.12)
		check(is_equal_approx(consumed.modulate.a,0.5) and consumed.position.y<600 and not consumed.get_node("Shadow").visible and not consumed.get_node("Selection").visible,"拾取消失上收淡出，同时移除地面目标与阴影")
		var paused_pickup: Dictionary = collected.duplicate(true); paused_pickup.paused=true
		game.loot_view.update_state(paused_pickup,1)
		check(is_equal_approx(consumed.modulate.a,0.5),"暂停冻结已经开始的拾取消失表现")
		game.loot_view.update_state(collected,0.13)
		await process_frame
		check(not is_instance_valid(consumed),"拾取表现到期释放节点，不重复重播或残留")
	game.loot_view.update_state(state)
	var overwritten_pickup: Node2D = game.loot_view.items.sample
	var overwritten_feedback: Dictionary = collected.duplicate(true)
	overwritten_feedback.feedback={"text":"蓝量不足","remaining":0.8,"healed":false}
	game.loot_view.update_state(overwritten_feedback)
	await process_frame
	check(is_instance_valid(overwritten_pickup),"同帧技能不足提示覆盖反馈时，已成功移除的药囊仍播放拾取表现")
	game.loot_view.update_state(original)
	await process_frame
	check(game.loot_view.items.is_empty(),"消费或换房后的快照清除旧药瓶呈现")
	game.loot_view.update_state(state)
	var old_bottle: Node2D = game.loot_view.items.sample
	var arrived: Dictionary = collected.duplicate(true); arrived.runId+=1
	arrived.drops=[]
	game.loot_view.update_state(arrived)
	await process_frame
	check(not is_instance_valid(old_bottle) and game.loot_view.get_child_count()==0,"换房或R重试直接清除旧药囊，不因残留反馈误播拾取")
	var reward: Dictionary = arrived.duplicate(true)
	reward.rewardPlaceholders=[{"id":"reward","kind":"equipment","x":500,"y":600,"label":"装备 · 未入库"}]
	game.loot_view.update_state(reward)
	check(not game.loot_view.items.reward.has_node("Bottle") and game.loot_view.items.reward.get_children().any(func(child: Node): return child is Label and child.text=="装备 · 未入库"),"Boss未入库奖励保持原占位和文字，不套用药瓶纹理")
	var reward_body: Polygon2D = game.loot_view.items.reward.get_node_or_null("Body")
	check(reward_body!=null and reward_body.polygon[2].x-reward_body.polygon[0].x<=16.0 and reward_body.polygon[3].y-reward_body.polygon[1].y<=20.0,"奖励占位菱形尺寸收敛至与28px药囊协调")
	var world_items_script = load("res://scripts/gameplay/world_items.gd")
	var icon_box: Rect2 = world_items_script.icon_box(Vector2(400,600))
	check(icon_box.size==Vector2(28,28) and world_items_script.RING_RADIUS==7.0 and world_items_script.LABEL_FONT_SIZE==13,"地面构筑道具贴图框收敛至28×28且同步缩小底环与字号")
	var old_seed: int = game.journey.drop_seed
	game.journey.restart(); game.present_new_room()
	check(game.journey.drop_seed!=old_seed and game.room.snapshot().drops.is_empty(),"灰盒R重开使用新种子并清空药瓶")
	game.queue_free(); await process_frame
	var standard: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(standard); standard.set_physics_process(false)
	await process_frame
	check(standard.room.potion_drops,"默认第一关直接启用药瓶，无需测试环境参数")
	standard.queue_free(); await process_frame
	print(JSON.stringify({"loot_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
