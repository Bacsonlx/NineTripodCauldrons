extends RefCounted

const CORE_RECT: Rect2i = Rect2i(7, 1, 2, 2)
const ALTAR_RECT: Rect2i = Rect2i(6, 0, 4, 4)

static func item_cells(item: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base_size: Vector2i = item.get("size", Vector2i.ONE)
	var size: Vector2i = Vector2i(base_size.y, base_size.x) if item.get("rotated", false) else base_size
	var cell: Vector2i = item.get("cell", Vector2i.ZERO)
	for x in size.x:
		for y in size.y:
			result.append(cell + Vector2i(x, y))
	return result

static func is_in_core(cell: Vector2i) -> bool:
	return CORE_RECT.has_point(cell)

static func is_in_altar(cell: Vector2i) -> bool:
	return ALTAR_RECT.has_point(cell)

static func is_core_item(item: Dictionary) -> bool:
	if item.get("region", "") != "altar": return false
	for c in item_cells(item):
		if is_in_core(c): return true
	return false

static func is_cell_adjacent(c1: Vector2i, c2: Vector2i) -> bool:
	return absi(c1.x - c2.x) + absi(c1.y - c2.y) == 1

static func evaluate(items: Array) -> Dictionary:
	var core_items: Array[int] = []
	var ring_items: Array[int] = []
	var altar_items: Array[Dictionary] = []

	for it in items:
		if it.get("region", "") == "altar":
			altar_items.append(it)
			if is_core_item(it):
				core_items.append(it.id)
			else:
				ring_items.append(it.id)

	# 寻找所有物理正交相邻的物品对
	var adjacent_pairs: Array[Dictionary] = []
	var energized_ids: Dictionary = {}
	var energized_edges: Array[Dictionary] = []

	for i in altar_items.size():
		var a: Dictionary = altar_items[i]
		var a_cells: Array[Vector2i] = item_cells(a)
		for j in range(i + 1, altar_items.size()):
			var b: Dictionary = altar_items[j]
			var b_cells: Array[Vector2i] = item_cells(b)
			var found_adj: bool = false
			var edge_a: Vector2i = Vector2i.ZERO
			var edge_b: Vector2i = Vector2i.ZERO
			for ca in a_cells:
				for cb in b_cells:
					if is_cell_adjacent(ca, cb):
						found_adj = true
						edge_a = ca
						edge_b = cb
						break
				if found_adj: break

			if found_adj:
				adjacent_pairs.append({
					"id_a": a.id, "name_a": a.name, "kind_a": a.get("kind", ""),
					"id_b": b.id, "name_b": b.name, "kind_b": b.get("kind", ""),
					"cell_a": edge_a, "cell_b": edge_b
				})

	# 通电判定规则：
	# 1. 主位（中央2x2）如果放置了物品（特别是"器"），作为通电源头
	# 2. 与主位物品相邻的环位物品被通电点亮
	# 3. 相邻的符之间互相共鸣通电
	for c_id in core_items:
		energized_ids[c_id] = true

	# 广度优先传导通电
	var changed: bool = true
	var passes: int = 0
	while changed and passes < 5:
		changed = false
		passes += 1
		for pair in adjacent_pairs:
			var id_a: int = pair.id_a
			var id_b: int = pair.id_b
			var has_a: bool = energized_ids.has(id_a)
			var has_b: bool = energized_ids.has(id_b)
			if has_a and not has_b:
				energized_ids[id_b] = true
				changed = true
			elif has_b and not has_a:
				energized_ids[id_a] = true
				changed = true
			elif not has_a and not has_b:
				var is_rune_a: bool = pair.kind_a == "符"
				var is_rune_b: bool = pair.kind_b == "符"
				if is_rune_a and is_rune_b:
					energized_ids[id_a] = true
					energized_ids[id_b] = true
					changed = true

	# 收集所有处于通电网络中的边缘
	for pair in adjacent_pairs:
		if energized_ids.has(pair.id_a) and energized_ids.has(pair.id_b):
			energized_edges.append({
				"cell_a": pair.cell_a,
				"cell_b": pair.cell_b,
				"name_a": pair.name_a,
				"name_b": pair.name_b,
				"is_core": core_items.has(pair.id_a) or core_items.has(pair.id_b)
			})

	# 8条动作改造词条匹配（赛菲莉娅核心：几何邻接产生手感改造，非数值膨胀）
	var synergies: Array[Dictionary] = []
	for pair in adjacent_pairs:
		var na: String = pair.name_a
		var nb: String = pair.name_b
		var is_energized: bool = energized_ids.has(pair.id_a) and energized_ids.has(pair.id_b)

		if (na == "羊角" and nb == "虎牙") or (na == "虎牙" and nb == "羊角"):
			synergies.append({
				"title": "埋雷箭矢",
				"desc": "命中的箭插地3秒成雷，闪避碰撞引发范围冲击（箭从伤害变位移埋雷）",
				"energized": is_energized,
				"pair": [na, nb]
			})
		elif na == "鼠毫" and nb == "鼠毫":
			synergies.append({
				"title": "拾取牵引",
				"desc": "射出的箭自动飞回手中，回收动作转为瞬时位移（弓手钩索战术）",
				"energized": is_energized,
				"pair": [na, nb]
			})
		elif na == "燧火" and nb == "燧火":
			synergies.append({
				"title": "燃烧分裂",
				"desc": "燃烧目标死亡时火苗跳向240内另一目标（火源主动扩散）",
				"energized": is_energized,
				"pair": [na, nb]
			})
		elif ((na == "虎牙" and nb == "快马") or (na == "快马" and nb == "虎牙")) and (core_items.has(pair.id_a) or core_items.has(pair.id_b)):
			synergies.append({
				"title": "推击强控",
				"desc": "暴击不造成纯伤害加成，改为将敌人强力向后击退120（从数字变位移控制）",
				"energized": is_energized,
				"pair": [na, nb]
			})
		elif (na == "涂炭" and pair.kind_b == "符") or (nb == "涂炭" and pair.kind_a == "符"):
			synergies.append({
				"title": "代价换覆盖",
				"desc": "移速−10%，该符生效范围从‘相邻’扩大至同行整排",
				"energized": is_energized,
				"pair": [na, nb]
			})
		elif (na == "焚书" and (core_items.has(pair.id_b) or pair.kind_b == "器")) or (nb == "焚书" and (core_items.has(pair.id_a) or pair.kind_a == "器")):
			synergies.append({
				"title": "改写器性",
				"desc": "点燃主位时永久改写器动作手感（冲刺留下持续加速火痕）",
				"energized": is_energized,
				"pair": [na, nb]
			})
		elif (na == "素食" and pair.kind_b == "符") or (nb == "素食" and pair.kind_a == "符"):
			synergies.append({
				"title": "无风心境",
				"desc": "脱战拖延进入无风状态：拉弓免体力必暴击但箭速变缓",
				"energized": is_energized,
				"pair": [na, nb]
			})

	for it in items:
		if it.get("kind", "") == "神兽" and it.get("region", "") == "equipment":
			var beast_name: String = it.name
			for ait in altar_items:
				if ait.name in ["羊角", "鼠毫", "虎牙", "燧火"] and energized_ids.has(ait.id):
					var desc: String = ""
					if beast_name == "青龙":
						desc = "神兽与祭坛生肖符共振，引风风道宽度翻倍且残留时间+1秒"
					elif beast_name == "白虎":
						desc = "神兽与祭坛生肖符共振，暴击撕裂硬直时间增加50%"
					elif beast_name == "朱雀":
						desc = "神兽与祭坛生肖符共振，余烬滞留时间增加1秒且点燃范围扩大"
					synergies.append({
						"title": "生肖共鸣 · " + beast_name + "×" + ait.name,
						"desc": desc,
						"energized": true,
						"pair": [beast_name, ait.name]
					})
					break

	return {
		"core_items": core_items,
		"ring_items": ring_items,
		"adjacent_pairs": adjacent_pairs,
		"energized_ids": energized_ids.keys(),
		"energized_edges": energized_edges,
		"synergies": synergies
	}
