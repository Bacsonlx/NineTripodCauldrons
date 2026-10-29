extends SceneTree

const Alpha = preload("res://scripts/alpha/alpha_state.gd")
const Geometry = preload("res://scripts/alpha/altar_geometry.gd")
const TrainingRoom = preload("res://scripts/combat/training_room.gd")
const BossRoom = preload("res://scripts/combat/boss_room.gd")

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	# =========================================================================
	# 1. 祭坛几何与正交通电（赛菲莉娅核心：反例与正例严格裁决）
	# =========================================================================
	# 4x4 祭坛范围：X=6..9, Y=0..3。中央主位：(7,1), (8,1), (7,2), (8,2)
	for x in range(6, 10):
		for y in range(0, 4):
			check(Geometry.is_in_altar(Vector2i(x, y)), "点(%d,%d)应在4x4祭坛内" % [x, y])
	check(not Geometry.is_in_altar(Vector2i(5, 0)), "外围X=5不在祭坛内")
	check(not Geometry.is_in_altar(Vector2i(6, 4)), "收纳区(6,4)不在祭坛内")

	# 正交相邻判定（曼哈顿距离 == 1），对角线严格排除
	check(Geometry.is_cell_adjacent(Vector2i(7, 1), Vector2i(7, 2)), "上下相邻应判定为正交相邻")
	check(Geometry.is_cell_adjacent(Vector2i(7, 1), Vector2i(8, 1)), "左右相邻应判定为正交相邻")
	check(not Geometry.is_cell_adjacent(Vector2i(7, 1), Vector2i(8, 2)), "对角线(7,1)与(8,2)严格不属于正交相邻")

	# 反例测试：物品未相邻或未通电，不触发共鸣
	var alpha_neg: RefCounted = Alpha.new(1, true)
	alpha_neg.reset(Vector2.ZERO)
	var horn_neg: Dictionary = alpha_neg.find_item_by_name("羊角")
	alpha_neg.place(horn_neg, Vector2i(6, 0), false) # 放在角上(6,0)
	var tiger_neg: Dictionary = alpha_neg.add_item("虎牙", "altar", Vector2i(9, 3)) # 放在对角(9,3)
	alpha_neg.recount()
	check(not alpha_neg.has_active_synergy("埋雷箭矢"), "反例：羊角与虎牙相距遥远且未相邻，严禁激活埋雷箭矢")

	# 正例测试：相邻且通电，激活埋雷箭矢
	var alpha_pos: RefCounted = Alpha.new(1, true)
	alpha_pos.reset(Vector2.ZERO)
	var horn_pos: Dictionary = alpha_pos.find_item_by_name("羊角")
	alpha_pos.place(horn_pos, Vector2i(6, 1), false)
	var tiger_pos: Dictionary = alpha_pos.add_item("虎牙", "altar", Vector2i(6, 2))
	alpha_pos.recount()
	check(alpha_pos.has_active_synergy("埋雷箭矢"), "正例：羊角与虎牙正交相邻通电，点亮【埋雷箭矢】")

	# 主位器通电推击测试
	var horse_pos: Dictionary = alpha_pos.add_item("快马", "altar", Vector2i(7, 1))
	alpha_pos.recount()
	check(alpha_pos.has_active_synergy("推击强控"), "主位快马与相邻虎牙点亮【推击强控】")

	# 双鼠毫测试：拾取牵引
	var alpha_mouse: RefCounted = Alpha.new(1, true)
	alpha_mouse.reset(Vector2.ZERO)
	var m1: Dictionary = alpha_mouse.find_item_by_name("鼠毫")
	alpha_mouse.place(m1, Vector2i(6, 1), false)
	var m2: Dictionary = alpha_mouse.add_item("鼠毫", "altar", Vector2i(6, 2))
	alpha_mouse.recount()
	check(alpha_mouse.has_active_synergy("拾取牵引"), "双鼠毫相邻点亮【拾取牵引】")

	# 双燧火测试：燃烧分裂
	var alpha_fire: RefCounted = Alpha.new(1, true)
	alpha_fire.reset(Vector2.ZERO)
	var f1: Dictionary = alpha_fire.add_item("燧火", "altar", Vector2i(6, 1))
	var f2: Dictionary = alpha_fire.add_item("燧火", "altar", Vector2i(6, 2))
	alpha_fire.recount()
	check(alpha_fire.has_active_synergy("燃烧分裂"), "双燧火相邻点亮【燃烧分裂】")

	# =========================================================================
	# 2. 动作质变手感与战斗裁决（TrainingRoom 规则层）
	# =========================================================================
	var room: RefCounted = TrainingRoom.new({
		"width": 1280, "height": 720, "spawn": Vector2(300, 300),
		"encounters": [{"target": Vector2(400, 300), "radius": 120}],
		"gameplay": true, "targets": []
	})
	room.alpha = alpha_pos
	var test_enemies: Array[Dictionary] = [
		{"id": 1, "group": 0, "x": 400.0, "y": 300.0, "role": "bird", "health": 100, "phase": "chase", "flash": 0.0, "knockTime": 0.0, "knockX": 0.0, "knockY": 0.0},
		{"id": 2, "group": 0, "x": 500.0, "y": 300.0, "role": "bird", "health": 100, "phase": "chase", "flash": 0.0, "knockTime": 0.0, "knockX": 0.0, "knockY": 0.0}
	]
	room.enemies = test_enemies

	# 测试 1: 埋雷箭矢
	check(room.has_spatial_synergy("埋雷箭矢"), "房间正确读取到埋雷箭矢共鸣")
	room.impact({"x": 400.0, "y": 265.0, "target": null, "enemy": 1}, "normal", 0.0, {"critical": false})
	check(room.mines.size() > 0, "埋雷箭矢命中敌人后应在地面埋下地雷")
	var mine: Dictionary = room.mines[0]
	check(mine.remaining > 2.5, "地雷拥有3秒寿命倒计时")
	# 引爆地雷
	room.detonate_mine(mine)
	check(room.enemies[0].health < 100, "地雷引爆对周围敌人造成震荡范围伤害")

	# 测试 2: 推击强控
	check(room.has_spatial_synergy("推击强控"), "房间正确读取到推击强控共鸣")
	var hp_before_crit: int = room.enemies[1].health
	room.impact({"x": 500.0, "y": 265.0, "target": null, "enemy": 2}, "normal", 0.0, {"critical": true, "criticalMultiplier": 1.5})
	check(room.enemies[1].knockTime > 0.15, "暴击触发推击强控产生显著击退位移")
	check(room.enemies[1].get("stopped", 0.0) > 0.2, "暴击触发推击强控对敌人造成短硬直断招")

	# 测试 3: 燃烧分裂
	room.alpha = alpha_fire
	check(room.has_spatial_synergy("燃烧分裂"), "房间切换为双燧火分裂共鸣")
	room.enemies[0].health = 1
	room.enemies[0].burnRemaining = 3.0
	room.impact({"x": room.enemies[0].x, "y": room.enemies[0].y, "target": null, "enemy": 1}, "normal", 0.0, {})
	check(room.enemies[0].phase == "dead", "目标已死亡")
	check(room.enemies[1].get("burnRemaining", 0.0) > 0, "燃烧目标死亡时火焰跳向240码内相邻目标")

	# =========================================================================
	# 3. 神兽祝福三选一与三阶演化（星界战士核心承诺）
	# =========================================================================
	var alpha_beast: RefCounted = Alpha.new(1, true)
	alpha_beast.reset(Vector2.ZERO)
	check(alpha_beast.blessing_tier == 1, "开局神兽祝词为初念 (Tier 1)")
	check(alpha_beast.blessing_evolves_left == 2, "开局神兽拥有2次重念演化机会")

	# 选择白虎
	check(alpha_beast.select_beast("白虎"), "开局营地成功选择白虎")
	check(alpha_beast.blessing_beast == "白虎", "当前神兽已锁定为白虎")
	var snap_b: Dictionary = alpha_beast.snapshot()
	check(snap_b.blessingTierName.contains("初念"), "白虎初始阶位名称包含初念")
	check(snap_b.blessingDesc.contains("裂痕"), "白虎初念描述包含裂痕机制")

	# 营地演化至再念与三念
	alpha_beast.command({"action": "evolve_blessing"}, null)
	check(alpha_beast.blessing_tier == 2, "第一次演化成功提升为再念 (Tier 2)")
	check(alpha_beast.blessing_evolves_left == 1, "剩余1次重念机会")

	alpha_beast.command({"action": "evolve_blessing"}, null)
	check(alpha_beast.blessing_tier == 3, "第二次演化成功提升为三念 (Tier 3)")
	check(alpha_beast.blessing_evolves_left == 0, "重念演化机会用尽")
	check(not alpha_beast.snapshot().canEvolveBlessing, "机会用尽后不可再演化")

	# 超过2次应被拒绝
	alpha_beast.command({"action": "evolve_blessing"}, null)
	check(alpha_beast.blessing_tier == 3, "超过2次演化上限后保持Tier 3，不继续演化")

	# 选择朱雀
	var alpha_phx: RefCounted = Alpha.new(1, true)
	alpha_phx.reset(Vector2.ZERO)
	check(alpha_phx.select_beast("朱雀"), "开局营地成功选择朱雀")
	check(alpha_phx.snapshot().blessingDesc.contains("余烬"), "朱雀初念描述包含余烬机制")

	# =========================================================================
	# 4. Boss 古神念名、弱点与断招（十容器语义解耦）
	# =========================================================================
	var boss_r: RefCounted = BossRoom.new({"width": 1280, "height": 720, "boss": Vector2(720, 520)})
	boss_r.alpha = alpha_pos
	boss_r.reset()

	var boss_snap: Dictionary = boss_r.snapshot()
	check(boss_snap.has("bossDivineName"), "Boss快照提供基于十容器的古神念名")
	check(boss_snap.has("bossWeakness"), "Boss快照提供基于十容器对冲的弱点描述")

	# 弱点断招测试
	boss_r.enemies[0].phase = "swing_warn"
	boss_r.enemies[0].timer = 0.8
	# 弱点命中（穿透箭或强控）
	boss_r.impact({"x": boss_r.enemies[0].x, "y": boss_r.enemies[0].y, "target": null, "enemy": 0}, "pierce", 0.0, {"critical": false})
	check(boss_r.enemies[0].phase != "swing_warn", "命中破绽弱点成功打断Boss蓄力挥击")

	# 战后残碑铭刻测试
	boss_r.enemies[0].health = 1
	boss_r.impact({"x": boss_r.enemies[0].x, "y": boss_r.enemies[0].y, "target": null, "enemy": 0}, "normal", 0.0, {})
	check(boss_r.status == "complete", "Boss生命归零，战斗胜利")
	check(alpha_pos.stele_inscription.has("beast"), "战后生成残碑铭刻：记录本局神兽")
	check(alpha_pos.stele_inscription.has("winner"), "战后生成残碑铭刻：记录显灵容器")

	# =========================================================================
	# 5. 十容器作祟惩罚契约（哈迪斯机制变异）
	# =========================================================================
	var alpha_pact: RefCounted = Alpha.new(1, true)
	alpha_pact.reset(Vector2.ZERO)
	check(alpha_pact.toggle_pact("地火割裂"), "成功激活【地火割裂】契约")
	check(alpha_pact.toggle_pact("空位落雷"), "成功激活【空位落雷】契约")
	check(alpha_pact.toggle_pact("重念限制"), "成功激活【重念限制】契约")
	check(alpha_pact.blessing_evolves_left == 1, "【重念限制】将本局重念机会压缩为1次")
	check(alpha_pact.pacts.has("地火割裂") and alpha_pact.pacts.has("空位落雷"), "契约列表正确保存已选机制")

	print(JSON.stringify({"commercial_depth_checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
