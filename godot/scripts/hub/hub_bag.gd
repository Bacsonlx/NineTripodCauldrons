extends "res://scripts/gameplay/camp_panel.gd"

signal preparation_changed
signal preparation_closed
const Profile = preload("res://scripts/hub/profile.gd")
var profile: RefCounted

func open_backpack() -> void:
	backpack_mode="camp"
	backpack_open=true
	selected=-1; rotated=false; signature=""
	clear_drag()
	refresh()

func refresh() -> void:
	super.refresh()
	if not backpack_open: return
	context_label.text="祠庙前院"
	mode_chip.text="出征准备 · 尚未支付"
	footer_state.text="筹备 %d · 本次 %d" % [profile.data.resources,profile.cost(room.alpha.items)]
	depart_button.text="保存准备并合上背包"
	drop_button.text="本次不带"
	kit_button.hide(); evolve_button.hide(); pickup_button.hide(); discard_button.hide()
	blessing_panel.hide()

func close_backpack() -> void:
	if not backpack_open: return
	clear_drag(); selected=-1; backpack_open=false; panel.hide()
	room.alpha.camp=true; room.alpha.departed=false
	preparation_closed.emit()

func send(intent: Dictionary) -> void:
	if room==null or room.alpha==null: return
	var action: String = intent.get("action","")
	if action in ["evolve_blessing","prototype_kit","burn","use"]: return
	if action=="depart": close_backpack(); return
	var before: Array = room.alpha.items.duplicate(true)
	if action=="drop":
		var item: Dictionary = room.alpha.find_item(int(intent.get("id",-1)))
		if item.is_empty(): return
		if room.alpha.items.size()==1:
			room.alpha.message="至少保留一件出征物品"
			refresh()
			return
		room.alpha.items.erase(item)
		room.alpha.message="已取消携带；出征前可恢复免费方案。残影不带的损失将在出征确认中提示。"
		selected=-1
	else:
		room.update({"alpha":intent},0)
	room.alpha.camp=true; room.alpha.departed=false; room.alpha.recount()
	if not profile.save_preparation(room.alpha):
		room.alpha.items.assign(before); room.alpha.recount()
		room.alpha.message="保存准备失败，本次操作未生效"
	preparation_changed.emit()
	refresh()

func undo_glyphs() -> void:
	var before: Array = room.alpha.items.duplicate(true)
	var additions: Array = []
	for equipment in room.alpha.items:
		if not equipment.has("glyphs"): continue
		var keep: Array = []
		for glyph in equipment.glyphs:
			if glyph.get("recipeGlyph",false): keep.append(glyph)
			else: additions.append(glyph)
		equipment.glyphs=keep; Profile.repair_main(equipment)
	for glyph in additions:
		glyph.region="ground"; room.alpha.items.append(glyph)
		if not Profile.fit(room.alpha,glyph):
			room.alpha.items.assign(before); room.alpha.message="空间不足，请先整理后撤销嵌符"; refresh(); return
	room.alpha.recount()
	if not profile.save_preparation(room.alpha):
		room.alpha.items.assign(before); room.alpha.recount()
		room.alpha.message="保存失败，嵌符准备未改变"
	else: room.alpha.message="已撤销手动嵌符；打造预嵌符请到铁匠处取消"
	preparation_changed.emit(); refresh()
