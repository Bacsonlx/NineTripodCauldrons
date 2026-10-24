extends VBoxContainer

signal command_requested(intent: Dictionary)

var equipment: OptionButton
var loose_glyphs: OptionButton
var embedded_glyphs: OptionButton
var summary: Label
var description: Label
var embed_button: Button
var main_button: Button
var items: Array = []
var signature: String = ""

func setup(room: TrainingRoom) -> void:
	if equipment!=null: return
	var title: Label = Label.new(); title.text="训练装备 · 实物嵌符（最多三张，不可拆）"; add_child(title)
	summary=Label.new(); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(summary)
	equipment=OptionButton.new(); add_child(equipment)
	equipment.item_selected.connect(func(_index: int): select_equipment())
	loose_glyphs=OptionButton.new(); add_child(loose_glyphs)
	embed_button=Button.new(); embed_button.text="嵌入选中实物符"; add_child(embed_button)
	embed_button.pressed.connect(func(): command_requested.emit({"action":"embed","equipmentId":selected_id(equipment),"glyphId":selected_id(loose_glyphs)}))
	description=Label.new(); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(description)
	embedded_glyphs=OptionButton.new(); add_child(embedded_glyphs)
	main_button=Button.new(); main_button.text="指定为唯一主符"; add_child(main_button)
	main_button.pressed.connect(func(): command_requested.emit({"action":"main_glyph","equipmentId":selected_id(equipment),"glyphId":selected_id(embedded_glyphs)}))
	refresh(room.snapshot())

func selected_id(menu: OptionButton) -> int:
	return menu.get_item_metadata(menu.selected) if menu.selected>=0 else -1

func restore_selection(menu: OptionButton, previous: int) -> void:
	for index in menu.item_count:
		if menu.get_item_metadata(index)==previous: menu.select(index); return

func refresh(snapshot: Dictionary) -> void:
	var state: Dictionary = snapshot.get("alpha",{})
	visible=state.get("camp",false) and state.has("equipment")
	if not visible: return
	var current: String = str(state.items)+str(snapshot.health)+str(snapshot.healthMax)+str(snapshot.paused)
	if current==signature: return
	signature=current
	var equipment_id: int = selected_id(equipment)
	var glyph_id: int = selected_id(loose_glyphs)
	items=state.items
	equipment.clear(); loose_glyphs.clear()
	for item in items:
		if item.state!="normal" or item.get("shadow",false): continue
		if item.name in ["训练弓","布履"] and item.region in ["equipment","warehouse","altar"]:
			equipment.add_item("%s #%d · %s" % [item.name,item.id,item.region]); equipment.set_item_metadata(equipment.item_count-1,item.id)
		if item.kind=="符" and item.region in ["equipment","warehouse","altar"]:
			loose_glyphs.add_item("%s #%d" % [item.name,item.id]); loose_glyphs.set_item_metadata(loose_glyphs.item_count-1,item.id)
	restore_selection(equipment,equipment_id); restore_selection(loose_glyphs,glyph_id)
	summary.text="最终构筑预览：生命上限 %d · 拾取 %.0f\n已应用：生命 %d / %d · 拾取 %.0f；出发时一次应用，不回血。" % [state.equipment.healthMax,state.equipment.pickupRadius,snapshot.health,snapshot.healthMax,state.appliedEquipment.pickupRadius]
	select_equipment()
	var blocked: bool = snapshot.reading or snapshot.status=="failed"
	embed_button.disabled=embed_button.disabled or blocked
	main_button.disabled=main_button.disabled or blocked

func select_equipment() -> void:
	var previous: int = selected_id(embedded_glyphs)
	embedded_glyphs.clear(); description.text="未选择训练装备"
	var target: Dictionary = {}
	for item in items:
		if item.id==selected_id(equipment): target=item; break
	if not target.is_empty():
		var names: PackedStringArray = []
		for glyph in target.get("glyphs",[]):
			names.append(glyph.name)
			embedded_glyphs.add_item(glyph.name+(" · 主符" if glyph.id==target.get("mainGlyphId",-1) else ""))
			embedded_glyphs.set_item_metadata(embedded_glyphs.item_count-1,glyph.id)
		description.text="已嵌 %d / 3：%s\n唯一归属：%s；只有装备区启用普通符效果。" % [names.size(),"、".join(names),target.container if not target.container.is_empty() else "无"]
	restore_selection(embedded_glyphs,previous)
	embed_button.disabled=target.is_empty() or target.get("glyphs",[]).size()>=3 or loose_glyphs.item_count==0
	main_button.disabled=embedded_glyphs.item_count==0
