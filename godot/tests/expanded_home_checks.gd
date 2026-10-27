extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	create_timer(120).timeout.connect(func(): push_error("扩展首页检查超时"); quit(1))
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func button_named(node: Node,prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found: Button = button_named(child,prefix)
		if found!=null: return found
	return null

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event)

func walk_room(game: Node,destination: Vector2) -> void:
	var path: Array = game.room.find_route(TrainingRoom.point(game.room.snapshot().player),destination)
	for waypoint in path:
		for frame in 600:
			var state: Dictionary = game.room.snapshot()
			if state.status=="failed": return
			var offset: Vector2 = waypoint-TrainingRoom.point(state.player)
			if offset.length()<4: break
			var move: Vector2 = offset.normalized()
			game.room.update({"moveX":move.x,"moveY":move.y},0.01)

func run() -> void:
	var home: Control = load("res://scenes/home.tscn").instantiate()
	root.add_child(home); current_scene=home
	await process_frame
	await process_frame
	var full: Button = button_named(home,"完整征程")
	var quick: Button = button_named(home,"快速测试")
	check(full!=null and quick!=null,"首页有完整征程和快速测试两个原生入口")
	if full!=null and quick!=null:
		check(full.button_pressed and not quick.button_pressed,"默认持久选中完整征程")
		check(full.get_node("SelectionMark").visible and not quick.get_node("SelectionMark").visible,"默认模式以控件色块标记选中，无字体依赖")
		quick.pressed.emit()
		check(quick.get_node("SelectionMark").visible and not full.get_node("SelectionMark").visible,"切换模式同步原生色块标记")
		check(quick.button_pressed and not full.button_pressed and button_named(home,"进入测试")!=null,"选择测试同步选中态和底部按钮")
		for window_size in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(800,450)]:
			root.size=window_size
			await process_frame
			await process_frame
			var bounds: Rect2 = home.get_global_rect()
			var rail: Control = home.get_node("Layout/Sections/Main/Modes")
			var gear: Control = home.get_node("Layout/Sections/Main/Gear")
			var footer: Control = home.get_node("Layout/Sections/Footer")
			check(bounds.encloses(rail.get_global_rect()) and rail.get_global_rect().end.y<=footer.get_global_rect().position.y,"窗口%s下测试选择栏不越界或遮挡出发操作" % window_size)
			check(bounds.encloses(gear.get_global_rect()) and bounds.encloses(footer.get_global_rect()),"窗口%s下保留行装与底部按钮" % window_size)
		root.size=Vector2i(1280,720)
		await process_frame
		full.pressed.emit()
		check(full.button_pressed and button_named(home,"踏入汤谷")!=null,"切回完整征程同步底部按钮")
		quick.pressed.emit()
		var choices: Array[Node] = home.find_children("RoomChoice","OptionButton",true,false)
		check(choices.size()==1,"快速测试显示真实房间下拉控件")
		if choices.size()==1:
			var choice: OptionButton = choices[0]
			check(choice.item_count==16,"首页提供全部16个已实现房间")
			var expected: Array = ["entry","court1","dry_creek","root_fork","stele","court2","altar","ash_cloister","gate_forecourt","court3","thunder_approach","boss","end","moss_side","stele_side","ember_side"]
			for index in mini(choice.item_count,expected.size()):
				check(choice.get_item_metadata(index)==expected[index],"列表按主线顺序和A/B/C支路展示稳定房间ID："+str(expected[index]))
			var levels: Array[Node] = home.find_children("LevelChoice","OptionButton",true,false)
			check(levels.size()==1 and levels[0].item_count==1 and levels[0].get_item_text(0)=="第一关 · 汤谷","只展示已实现的汤谷关卡")
			var boss_index: int = -1
			for index in choice.item_count:
				if choice.get_item_metadata(index)=="boss": boss_index=index
			check(boss_index>=0,"房间列表包含真实索尔房间")
			if boss_index>=0 and "--home-only" not in OS.get_cmdline_user_args():
				choice.select(boss_index); choice.item_selected.emit(boss_index)
				button_named(home,"行　").pressed.emit()
				button_named(home,"进入测试").grab_focus()
				button_named(home,"进入测试").pressed.emit()
				check(button_named(home,"确认入局")!=null,"行囊页沿用测试选择打开确认")
				key(KEY_ESCAPE)
				check(root.gui_get_focus_owner()==button_named(home,"进入测试"),"取消出发焦点返回行囊按钮")
				button_named(home,"进入测试").pressed.emit()
				button_named(home,"确认入局").pressed.emit()
				await scene_changed
				var game: Node = current_scene; game.set_physics_process(false)
				check(game.journey.snapshot().roomId=="boss","行囊页确认后从已选择的Boss房间出发")
				check(not has_meta("home_test_arguments"),"首页启动条件仅消费一次")
				game.queue_free(); current_scene=null
				await process_frame
				home=null
	if is_instance_valid(home): home.queue_free(); current_scene=null
	await process_frame
	if "--home-only" not in OS.get_cmdline_user_args():
		await check_formal_confirmation()
		await check_test_starts()
		await check_failed_retry()
		await check_reading()
		await check_cli_isolation()
	print(JSON.stringify({"expanded_home_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check_formal_confirmation() -> void:
	set_meta("home_test_arguments",["--test=level"])
	var game: Node = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); current_scene=game
	game.set_physics_process(false)
	await process_frame
	var depart: Button = button_named(game,"确认构筑并出发")
	if depart!=null: depart.pressed.emit()
	var before: Dictionary = game.journey.snapshot()
	key(KEY_I)
	await process_frame
	var camping: Dictionary = game.journey.snapshot()
	key(KEY_R)
	check(camping.alpha.camp and game.journey.snapshot().runId==before.runId,"营地整理中R无效")
	depart=button_named(game,"确认构筑并出发")
	if depart!=null: depart.pressed.emit()
	var held: InputEventKey = InputEventKey.new(); held.physical_keycode=KEY_W; held.pressed=true
	root.push_input(held)
	key(KEY_R)
	var cancel: Button = button_named(game,"取消")
	check(cancel!=null and cancel.is_visible_in_tree(),"存活正式征程R打开二次确认")
	check(game.journey.snapshot().runId==before.runId,"打开重开确认不重建本局")
	if cancel!=null:
		check(game.journey.snapshot().paused,"确认层暂停规则时钟")
		game.controls.update(Vector2(0,900),true,1.5)
		var frozen: Dictionary = game.journey.snapshot()
		check(frozen.alpha.elapsed==before.alpha.elapsed and frozen.health==before.health and frozen.resources==before.resources,"确认期间有效时间与资源冻结")
		check(game.controls.movement()==Vector2.ZERO,"确认清理持续移动输入")
		var focus: Control = root.gui_get_focus_owner()
		check(focus==cancel,"确认默认聚焦取消以防误操作")
		key(KEY_TAB); key(KEY_TAB)
		check(root.gui_get_focus_owner()==cancel,"确认键盘焦点循环限制在确认层")
		root.size_changed.emit()
		key(KEY_R)
		check(game.journey.snapshot().runId==before.runId,"窗口变化与重复R不会穿透确认层")
		key(KEY_ESCAPE)
		check(not game.journey.snapshot().paused and game.journey.snapshot().runId==before.runId,"Esc取消重开后保留原局并恢复非暂停状态")
		game.controls.update(Vector2(0,900),true,0.2)
		var resumed: Dictionary = game.journey.snapshot()
		check(resumed.player.x==frozen.player.x and resumed.player.y==frozen.player.y and resumed.attack=="idle","取消确认不恢复持续移动或射箭")
		key(KEY_R)
		var confirm: Button = button_named(game,"确认重开")
		check(confirm!=null,"重开确认使用明确动作标签")
		if confirm!=null:
			confirm.pressed.emit(); confirm.pressed.emit()
			await process_frame
			check(game.journey.snapshot().runId==before.runId+1,"连续确认只创建一个新局")
		depart=button_named(game,"确认构筑并出发")
		if depart!=null: depart.pressed.emit()
	key(KEY_ESCAPE)
	game.present(game.journey.snapshot(),0)
	var paused_run: int = game.journey.snapshot().runId
	key(KEY_R)
	check(game.journey.snapshot().runId==paused_run,"暂停菜单中R无效")
	button_named(game,"返回首页").grab_focus()
	button_named(game,"返回首页").pressed.emit()
	cancel=button_named(game,"取消")
	check(cancel!=null and cancel.is_visible_in_tree(),"暂停菜单返回首页先确认")
	if cancel!=null:
		key(KEY_ESCAPE)
		check(current_scene==game and game.journey.snapshot().paused,"取消返回首页仍保留暂停菜单与本局")
		check(root.gui_get_focus_owner()==button_named(game,"返回首页"),"取消返回首页恢复原菜单按钮焦点")
		button_named(game,"返回首页").pressed.emit()
		var confirm: Button = button_named(game,"确认返回首页")
		confirm.pressed.emit(); confirm.pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path=="res://scenes/home.tscn","返回确认只切换一次至默认完整征程首页")
		check(button_named(current_scene,"完整征程").button_pressed,"返回首页不继承测试选择与低资源")
		current_scene.queue_free(); current_scene=null
		await process_frame
		return
	game.queue_free(); current_scene=null
	await process_frame

func check_test_starts() -> void:
	var ids: Array = preload("res://scripts/journey/room_journey.gd").ROOM_IDS
	for id in ids:
		var home: Control = load("res://scenes/home.tscn").instantiate()
		root.add_child(home); current_scene=home
		await process_frame
		button_named(home,"快速测试").pressed.emit()
		var choice: OptionButton = home.find_child("RoomChoice",true,false)
		var index: int = -1
		for candidate in choice.item_count:
			if choice.get_item_metadata(candidate)==id: index=candidate
		check(index>=0,"实际首页房间选择可达："+id)
		if index<0:
			home.free(); current_scene=null
			continue
		choice.select(index); choice.item_selected.emit(index)
		button_named(home,"进入测试").pressed.emit()
		var dialog: Control = home.get_node("HomeDialog")
		var labels: Array[Node] = dialog.find_children("*","Label",true,false)
		check(labels.any(func(label: Label): return label.text.contains("起点："+home.room_maps[id].roomTitle)),"出发确认显示所选房间："+id)
		var confirm: Button = button_named(home,"确认入局")
		confirm.pressed.emit(); confirm.pressed.emit()
		await scene_changed
		var game: Node = current_scene; game.set_physics_process(false)
		await process_frame
		var before: Dictionary = game.journey.snapshot()
		check(not has_meta("home_test_arguments"),"实际首页传入条件消费一次："+id)
		check(before.get("isTest",false) and before.roomId==id,"显式房间起点始终是测试（含entry）："+id)
		check(before.health==100 and before.resources.mana==100 and before.resources.stamina==100,"测试默认三资源100："+id)
		check(not before.journeyComplete and before.visitedRooms==1,"房间测试不伪造前序完成："+id)
		check(Vector2(before.player.x,before.player.y)==Vector2(game.room.layout.spawn.x,game.room.layout.spawn.y) and game.room.can_walk(Vector2(before.player.x,before.player.y)),"使用房间默认合法出生点："+id)
		check(before.alpha.camp==(id=="entry"),"只有入口测试先整理，其他房按正常任务触发："+id)
		var identity: Label = game.hud.get_node("JourneyIdentity")
		check(identity.text.contains("快速测试") and identity.text.contains(game.room.layout.roomTitle),"HUD持续显示测试身份与所选起点："+id)
		var depart: Button = button_named(game,"确认构筑并出发")
		if depart!=null: depart.pressed.emit()
		key(KEY_R)
		await process_frame
		var after: Dictionary = game.journey.snapshot()
		check(after.runId==before.runId+1 and after.roomId==id,"快速测试R直接回到所选起点新局："+id)
		check(after.get("isTest",false) and after.health==100 and after.resources.mana==100 and after.resources.stamina==100 and after.visitedRooms==1,"测试重试保留身份和初始条件并清空临时进度："+id)
		game.queue_free(); current_scene=null
		await process_frame

func check_failed_retry() -> void:
	set_meta("home_test_arguments",["--test=level","--health=1"])
	var game: Node = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); current_scene=game; game.set_physics_process(false)
	await process_frame
	button_named(game,"确认构筑并出发").pressed.emit()
	var before: Dictionary = game.journey.snapshot()
	walk_room(game,TrainingRoom.point(game.room.layout.doors[0].point))
	key(KEY_F); game._physics_process(0)
	check(game.journey.snapshot().roomId=="court1","正式低血局真实过门进入第一庭")
	if not game.room.layout.encounters.is_empty():
		walk_room(game,TrainingRoom.point(game.room.layout.encounters[0]))
	for frame in 600:
		if game.journey.snapshot().status=="failed": break
		game.controls.update(Vector2.ZERO,false,0.05)
	check(game.journey.snapshot().status=="failed","真实移动、过门与敌人攻击使低血正式局阵亡")
	key(KEY_R)
	await process_frame
	var after: Dictionary = game.journey.snapshot()
	check(after.roomId=="entry" and after.runId>before.runId and after.health==1 and not after.isTest,"正式阵亡R直接按入口与原始条件重试")
	check(button_named(game,"确认重开")==null,"阵亡重试无需确认")
	game.queue_free(); current_scene=null
	await process_frame

func check_reading() -> void:
	for id in ["stele_side","stele"]:
		set_meta("home_test_arguments",["--test=level","--room="+id])
		var game: Node = load("res://scenes/tanggu_first_level.tscn").instantiate()
		root.add_child(game); current_scene=game; game.set_physics_process(false)
		await process_frame
		var inscription: Label = game.hud.reading.get_child(0)
		if id=="stele_side":
			check(inscription.text.contains(game.room.layout.steleTitle) and inscription.text.contains(game.room.layout.steleText),"HUD绑定B支路房间自身短碑文")
		else:
			check(inscription.text.contains("风过残碑") and not inscription.text.contains("施工占位"),"主线碑文恢复原文，不残留支路文本")
		var stele: Dictionary = game.room.layout.exploration.filter(func(item: Dictionary): return item.id=="stele")[0]
		walk_room(game,TrainingRoom.point(stele))
		key(KEY_F); game._physics_process(0)
		game.present(game.journey.snapshot(),0)
		check(game.journey.snapshot().reading and game.hud.reading.visible,"通过正常移动和F规则打开本房碑文："+id)
		var run_id: int = game.journey.snapshot().runId
		key(KEY_R)
		check(game.journey.snapshot().reading and game.journey.snapshot().runId==run_id and button_named(game,"确认重开")==null,"阅读中R无效："+id)
		key(KEY_ESCAPE)
		game._physics_process(0)
		check(not game.journey.snapshot().reading and game.journey.snapshot().roomComplete,"合上碑文后正常完成探索任务："+id)
		game.queue_free(); current_scene=null
		await process_frame

func check_cli_isolation() -> void:
	set_meta("home_test_arguments",["--test=boss","--health=40","--mana=0","--stamina=0","--seed=13"])
	var game: Node = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); current_scene=game; game.set_physics_process(false)
	await process_frame
	var initial: Dictionary = game.journey.snapshot()
	check(initial.isTest and initial.health==40 and initial.resources.mana==0 and initial.resources.stamina==0 and initial.dropSeed==13,"CLI专项低资源和固定种子仍兼容")
	key(KEY_R)
	await process_frame
	check(game.journey.snapshot().health==40 and game.journey.snapshot().dropSeed==13,"CLI测试R保留本次显式初始条件")
	key(KEY_ESCAPE); game.present(game.journey.snapshot(),0)
	button_named(game,"返回首页").pressed.emit()
	button_named(game,"确认返回首页").pressed.emit()
	await scene_changed
	var home: Control = current_scene
	check(button_named(home,"完整征程").button_pressed,"低资源测试返回首页默认完整征程")
	button_named(home,"踏入汤谷").pressed.emit()
	button_named(home,"确认入局").pressed.emit()
	await scene_changed
	game=current_scene; game.set_physics_process(false)
	var fresh: Dictionary = game.journey.snapshot()
	check(not fresh.isTest and fresh.roomId=="entry" and fresh.health==100 and fresh.resources.mana==100 and fresh.resources.stamina==100,"返回后完整征程不继承CLI低资源和测试身份")
	check(not game.journey.initial_options.has("dropSeed") and not has_meta("home_test_arguments"),"返回后一次性启动参数及CLI种子隔离")
	game.queue_free(); current_scene=null
	await process_frame
