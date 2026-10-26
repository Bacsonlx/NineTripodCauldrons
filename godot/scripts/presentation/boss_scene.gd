extends "res://scripts/presentation/first_level_scene.gd"

const BossRoom = preload("res://scripts/combat/boss_room.gd")
@export_range(0,100) var starting_mana: int = 100
@export_range(1,100) var starting_health: int = 100
@export_range(0,100) var starting_stamina: int = 100
var boss_bar: ProgressBar
var trial_selector: OptionButton

func create_room(_layout: Dictionary) -> TrainingRoom:
	return BossRoom.new({"mana":starting_mana,"health":starting_health,"stamina":starting_stamina})

func create_backdrop() -> Node2D:
	return load("res://scripts/presentation/boss_view.gd").new()

func build_hud() -> void:
	super.build_hud()
	overview_button.hide()
	trial_selector=OptionButton.new(); trial_selector.name="TrialSelector"
	trial_selector.focus_mode=Control.FOCUS_NONE
	for text in ["满资源","44蓝","零蓝","40生命","零精力"]: trial_selector.add_item(text)
	trial_selector.item_selected.connect(select_trial)
	hud.toolbar.add_child(trial_selector)
	boss_bar=ProgressBar.new(); boss_bar.name="BossHealth"
	boss_bar.max_value=1200; boss_bar.show_percentage=false
	boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_bar.offset_left=-160; boss_bar.offset_right=160
	boss_bar.offset_top=208; boss_bar.offset_bottom=220
	hud.add_child(boss_bar)
	var return_button: Button = Button.new()
	return_button.text="返回汤谷"; return_button.focus_mode=Control.FOCUS_NONE
	return_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/tanggu_first_level.tscn"))
	hud.toolbar.add_child(return_button)
	hud.resized.connect(layout_boss_hud)
	layout_boss_hud()

func layout_boss_hud() -> void:
	hud.toolbar.offset_left=-360
	boss_bar.offset_top=hud.encounter.position.y+60
	boss_bar.offset_bottom=boss_bar.offset_top+12

func select_trial(index: int) -> void:
	controls.interrupt()
	starting_mana=44 if index==1 else 0 if index==2 else 100
	starting_health=40 if index==3 else 100
	starting_stamina=0 if index==4 else 100
	var generation: int = room.run_id+1
	room=create_room({}); room.run_id=generation
	room.layout.grips=room.layout.grips.duplicate()
	room.layout.grips[1]=TrainingRoom.point(atlas.upperDown.grip)
	controls=Controls.new(room)
	present(room.snapshot(),0); mark_presented()

func update_camera() -> void:
	fit_room(200)

func guidance_at(_position: Vector2) -> Dictionary:
	return {"region":"索尔 · 独立战斗原型","landmark":"锤离手时反击"}

func present(snapshot: Dictionary,seconds: float) -> void:
	super.present(snapshot,seconds)
	boss_bar.value=snapshot.boss.health

func hud_lines() -> Dictionary:
	var lines: Dictionary = super.hud_lines()
	var boss: Dictionary = state.boss
	var phase: String = {"prepare":"观察对手","rest":"准备出招","chase":"正在逼近", "swing_warn":"横锤 · 侧移或退开", "swing":"横锤挥击", "swing_recover":"横锤收招 · 可反击", "throw_warn":"掷锤 · 横向走位", "flight":"锤已离手 · 承伤提高25%", "throw_recover":"接锤收招", "lightning":"落雷 · 持续走位", "dead":"已击败"}[boss.phase]
	lines.encounter="索尔  %d / 1200\n%s" % [boss.health,phase]
	lines.interaction="WASD 移动 · 左键射箭 · Q / E 技能 · 空格闪避\n独立原型 · R 按当前条件重试 · Esc 暂停"
	if state.status=="complete":
		lines.statusVisible=true
		lines.status="索尔已败退\n%.1f秒 · R 重试" % state.elapsed
	elif state.status=="failed": lines.status="影散于雷下\nR 按当前条件重试"
	return lines
