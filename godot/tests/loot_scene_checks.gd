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
	await process_frame
	check(game.room.potion_drops and game.room.snapshot().drops.is_empty(),"独立灰盒入口启用掉落并从空地面状态启动")
	var original: Dictionary = game.room.snapshot()
	var state: Dictionary = original.duplicate(true)
	state.drops=[{"id":"sample","kind":"mana","x":400,"y":600}]
	state.interaction={"dropId":"sample","reason":null}
	game.loot_view.update_state(state)
	check(game.loot_view.items.size()==1 and game.loot_view.items.sample.position==Vector2(400,600),"只读掉落快照生成地面瓶并按脚点定位")
	check(game.loot_view.items.sample.get_node("Selection").visible,"规则当前F目标显示地面高亮")
	check(game.room.snapshot()==original,"药瓶呈现不反向修改真实资源或地面状态")
	game.loot_view.update_state(original)
	await process_frame
	check(game.loot_view.items.is_empty(),"消费或换房后的快照清除旧药瓶呈现")
	var old_seed: int = game.journey.drop_seed
	game.journey.restart(); game.present_new_room()
	check(game.journey.drop_seed!=old_seed and game.room.snapshot().drops.is_empty(),"灰盒R重开使用新种子并清空药瓶")
	game.queue_free(); await process_frame
	var standard: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(standard); standard.set_physics_process(false)
	await process_frame
	check(not standard.room.potion_drops,"默认入口保留旧回蓝，等待灰盒试玩确认再切换")
	standard.queue_free(); await process_frame
	print(JSON.stringify({"loot_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
