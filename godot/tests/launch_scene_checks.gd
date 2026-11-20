extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(20).timeout.connect(func(): push_error("启动场景检查超时"); quit(1))
	run.call_deferred()

func run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	scene_changed.connect(func():
		if current_scene!=null: current_scene.set_physics_process(false))
	var path: String = "res://scenes/tanggu_first_level.tscn" if arguments.is_empty() else ProjectSettings.get_setting("application/run/main_scene")
	var game: Node = load(path).instantiate()
	root.add_child(game); game.set_physics_process(false); current_scene=game
	if arguments.is_empty():
		await process_frame
	else:
		var expected: String = "res://scenes/tanggu_alpha.tscn" if "--test=alpha" in arguments else "res://scenes/tanggu_first_level.tscn"
		while current_scene==null or current_scene.scene_file_path!=expected:
			await scene_changed
	game=current_scene
	game.set_physics_process(false)
	if "--test=alpha" in arguments:
		check(current_scene!=null and current_scene.scene_file_path=="res://scenes/tanggu_alpha.tscn","alpha参数从统一游戏入口选择已有背包白盒")
	else:
		var state: Dictionary = game.journey.snapshot()
		check(state.has("drops"),"所有正常／专项房间默认使用药瓶规则")
		if "--test=boss" in arguments:
			check(state.roomId=="boss" and state.health==40 and state.resources.mana==0 and state.resources.stamina==0,"Boss参数从首关实际雷庭开始，资源条件生效")
			check(game.boss_view.visible and game.boss_bar.value==1200,"Boss专项使用首关呈现与真实血条")
		elif "--test=drops" in arguments:
			check(state.roomId=="court1" and state.health==60 and state.resources.mana==40,"掉落参数直接进入真实第一战斗庭")
		elif "--room=court2" in arguments:
			check(state.roomId=="court2","单独房间参数无需启用测试环境")
		else:
			check(state.roomId=="entry" and state.health==100 and state.resources.mana==100,"无参数首关从正常入口满资源开始")
		var initial: Dictionary = {"room":state.roomId,"health":state.health,"mana":state.resources.mana}
		game.journey.update({"restart":true},0); game.present_new_room()
		state=game.journey.snapshot()
		check(state.roomId==initial.room and state.health==initial.health and state.resources.mana==initial.mana,"R保留本次启动房间和资源条件")
	if "--test=boss" in arguments:
		var profile_path: String = "/private/tmp/jiuding-launch-scene-%d.save" % Time.get_ticks_usec()
		OS.set_environment("JIUDING_PROFILE_PATH",profile_path)
		game.controls.key_down(KEY_ESCAPE)
		game.present(game.journey.snapshot(),0)
		button_with_text(game,"结束测试").pressed.emit()
		button_with_text(game,"确认结束测试").pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path=="res://scenes/safehouse.tscn","开发测试结束进入安全屋")
		current_scene.depart()
		await scene_changed
		var fresh: Dictionary = current_scene.journey.snapshot()
		check(fresh.roomId=="entry" and fresh.health==100 and fresh.resources.mana==100 and fresh.resources.stamina==100,"命令行低资源 Boss 回到安全屋后，完整征程不继承测试参数")
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	current_scene.queue_free(); current_scene=null
	await process_frame
	print(JSON.stringify({"launch_scene_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func button_with_text(node: Node,text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found: Button = button_with_text(child,text)
		if found!=null: return found
	return null
