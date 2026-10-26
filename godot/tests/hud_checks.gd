extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node2D = load("res://scenes/tanggu_first_level.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.journey.update({"alpha":{"action":"depart"}},0)
	await process_frame
	var hud: Control = game.find_child("CombatHUD",true,false)
	check(hud!=null,"正式首关显示头像、状态与左下动作栏")
	if hud==null: finish(game); return
	check(hud.get_node_or_null("RoomMinimap")!=null,"正式首关右上角显示房间关系小地图")
	check(hud.get_node("PlayerStatus/Portrait").texture!=null and hud.health.value==100,"已接入头像素材并展示真实初始生命")
	var font: Font = hud.health_value.get_theme_font("font")
	var minimap: Control = hud.get_node("RoomMinimap")
	check(minimap.mouse_filter==Control.MOUSE_FILTER_IGNORE and minimap.get_index()<hud.reading.get_index(),"小地图不截获射击，且阅读遮罩绘在其上方")
	check(minimap.graph.rooms.size()==16 and minimap.graph.connections.size()==18,"小地图显示十六房与十八条双向连接")
	check(font.resource_path=="res://assets/fonts/NineTripodsHudSong.ttf" and not font.allow_system_fallback,"HUD使用随包宋体，不依赖系统字体")
	var covered: bool = true
	for character in "无名之子生命蓝量精力未启用穿透箭箭雨闪避第波剩余0123456789 /":
		covered=covered and font.has_char(character.unicode_at(0))
	check(covered,"新字体包含HUD中文与数值所需字形")
	check(hud.get_node("StatusBacking").visible and hud.get_node("StatusBacking").mouse_filter==Control.MOUSE_FILTER_IGNORE,"状态底衬可见且不阻断射击")
	check(hud.actions.get_child_count()==4 and hud.actions.size.x<=288,"四个动作紧凑排列，宽度不超过288逻辑像素")
	check(hud.actions.position.x==24 and absf(hud.actions.position.y-(hud.size.y-112))<1,"动作栏锚定左下安全边距")
	check(hud.mouse_filter==Control.MOUSE_FILTER_IGNORE and hud.actions.mouse_filter==Control.MOUSE_FILTER_IGNORE,"装饰HUD不截获战斗鼠标输入")
	check(hud.mana.value==100 and hud.stamina.value==100 and hud.mana_value.text=="100 / 100","蓝量与精力启用并显示真实初始状态")
	game.controls.key_down(KEY_Q)
	game.present(game.controls.update(Vector2(1000,550),true,0.01),0)
	var q: Label = hud.get_node("Actions/Pierce/Cooldown")
	check(q.text=="4.0","Q真实输入后显示四秒冷却")
	check(hud.mana.value==88 and hud.mana_value.text=="88 / 100","Q起手后HUD蓝量同步扣除12")
	game.controls.key_up(KEY_Q); game.controls.key_down(KEY_ESCAPE)
	game.present(game.controls.update(Vector2(1000,550),true,1),0)
	check(q.text=="4.0" and game.status_label.visible,"暂停期间冷却数字冻结并显示暂停提示")
	game.controls.key_down(KEY_ESCAPE)
	game.present(game.controls.update(Vector2(1000,550),true,1),0)
	check(q.text=="3.0","恢复后按规则时间继续冷却")
	var retry: InputEventKey = InputEventKey.new()
	retry.keycode=KEY_R; retry.physical_keycode=KEY_R; retry.pressed=true
	root.push_input(retry)
	retry.pressed=false; root.push_input(retry)
	check(q.text=="3.0" and game.room.snapshot().paused,"完整征程R确认期间保留真实冷却并停时")
	var confirm: Button = find_button(game,"确认重开")
	check(confirm!=null,"完整征程R显示真实重开确认按钮")
	if confirm!=null: confirm.pressed.emit()
	await process_frame
	check(q.text.is_empty() and hud.health.value==100,"确认重开后清空冷却并恢复生命显示")
	game.journey.update({"alpha":{"action":"depart"}},0)
	for i in 8:
		game.room.update({},0)
		game.room.update({"pierce":true,"aim":Vector2(1000,550)},0.2)
		game.room.update({},4)
	game.present(game.room.snapshot(),0)
	check(hud.mana.value==4 and hud.slots.pierce.insufficient and hud.slots.rain.insufficient and not hud.slots.dodge.insufficient,"真实低蓝时Q/E图标变暗，闪避保持可用")
	for i in 4:
		game.room.update({},0); game.room.update({"dodge":true},0)
		if i<3: game.room.update({},1.001)
	game.present(game.room.snapshot(),0)
	check(hud.stamina_value.text=="0 / 100" and hud.slots.dodge.insufficient,"精力耗尽时真实数值归零，闪避图标变暗")
	check(hud.health.size.y<=16 and hud.get_node("StatusBacking").size.y<=100,"状态采用窄条和轻量底衬，避免上一版大块面板")
	# 独立战斗规则的真实命中快照输入呈现层，检查可观察的原生血条。
	var duel: TrainingRoom = load("res://scripts/combat/training_room.gd").new({"enemy":Vector2(455,600),"encounter":Vector2(400,600)})
	duel.update({"aim":Vector2(1000,549),"fire":true},0.01)
	duel.update({"aim":Vector2(1000,549),"fire":false},0.12)
	var snapshot: Dictionary = duel.snapshot()
	var original: Dictionary = snapshot.duplicate(true)
	hud.update_state(snapshot); game.overlay.update(snapshot,Vector2.ZERO,false)
	check(snapshot==original,"呈现层不修改输入的战斗快照")
	var enemy_bar: ProgressBar = game.overlay.get_node("EnemyHealth0")
	check(enemy_bar.visible and enemy_bar.value==45 and enemy_bar.max_value==60,"真实普通箭命中后怪物血条显示45/60")
	var first: Vector2 = enemy_bar.position
	duel.update({},0.2); snapshot=duel.snapshot(); game.overlay.update(snapshot,Vector2.ZERO,false)
	check(enemy_bar.position!=first,"追击中的怪物血条跟随位置")
	duel.update({},12); snapshot=duel.snapshot(); hud.update_state(snapshot)
	check(hud.health.value==0 and hud.health_value.text=="0 / 100","真实近战扣血直至失败，玩家生命条归零")
	duel.reset(); game.overlay.update(duel.snapshot(),Vector2.ZERO,false)
	check(not enemy_bar.visible,"重试后尚未激活的怪物不显示旧血条")
	duel=load("res://scripts/combat/training_room.gd").new({"enemy":Vector2(650,600),"encounter":Vector2(400,600)})
	for step in 200:
		var target: Dictionary = duel.snapshot().enemies[0]
		duel.update({"aim":Vector2(target.x,target.y-55),"fire":true},0.02)
		if duel.snapshot().enemies[0].phase=="dead": break
	game.overlay.update(duel.snapshot(),Vector2.ZERO,false)
	check(duel.snapshot().enemies[0].phase=="dead" and not enemy_bar.visible,"真实连射击杀后立即隐藏怪物血条")
	game.present(game.room.snapshot(),0)
	check(not enemy_bar.visible,"切回没有敌人的房间，旧怪物血条全部隐藏")
	for dimensions in [Vector2(800,450),Vector2(1280,720),Vector2(1920,1080),Vector2(2560,1080)]:
		hud.size=dimensions
		await process_frame
		var skills: Rect2 = hud.actions.get_rect()
		check(Rect2(Vector2.ZERO,dimensions).encloses(skills) and skills.end.x<dimensions.x/2,"%s左下动作栏不越界、不遮中央" % dimensions)
		check(not hud.encounter.get_rect().intersects(hud.get_node("PlayerStatus").get_rect()),"%s房间提示不重叠头像状态区" % dimensions)
		check(Rect2(Vector2.ZERO,dimensions).encloses(minimap.get_rect()) and not minimap.get_rect().intersects(hud.toolbar.get_rect()) and not minimap.get_rect().intersects(hud.encounter.get_rect()) and not minimap.get_rect().intersects(hud.get_node("PlayerStatus").get_rect()),"%s小地图不出界、不遮工具栏与状态提示" % dimensions)
	finish(game)

func finish(game: Node) -> void:
	game.free()
	print(JSON.stringify({"hud_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func find_button(node: Node,text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found: Button = find_button(child,text)
		if found!=null: return found
	return null
