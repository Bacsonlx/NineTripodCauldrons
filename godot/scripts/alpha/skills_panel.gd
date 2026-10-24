extends VBoxContainer

signal command_requested(intent: Dictionary)

var sources: OptionButton
var equipment: OptionButton
var slot: OptionButton
var summary: Label
var assign_button: Button
var embed_button: Button
var current: Array = []
var signature: String = ""

func setup(room: TrainingRoom) -> void:
	if sources!=null: return
	var title: Label = Label.new(); title.text="特殊技能 · 两槽与实物来源"; add_child(title)
	summary=Label.new(); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(summary)
	sources=OptionButton.new(); add_child(sources)
	slot=OptionButton.new(); slot.add_item("第一特殊槽 · E"); slot.add_item("第二特殊槽 · G"); add_child(slot)
	assign_button=Button.new(); assign_button.text="指定此实物来源"; add_child(assign_button)
	assign_button.pressed.connect(func(): command_requested.emit({"action":"assign_special","slot":slot.selected,"sourceId":selected_id(sources)}))
	var clear: Button = Button.new(); clear.text="清空此特殊槽"; add_child(clear)
	clear.pressed.connect(func(): command_requested.emit({"action":"assign_special","slot":slot.selected,"sourceId":-1}))
	equipment=OptionButton.new(); add_child(equipment)
	embed_button=Button.new(); embed_button.text="镶入装备（每件一本，不可取出）"; add_child(embed_button)
	embed_button.pressed.connect(func(): command_requested.emit({"action":"embed_book","equipmentId":selected_id(equipment),"bookId":selected_id(sources)}))
	sources.item_selected.connect(func(_index: int): update_buttons())
	refresh(room.snapshot())

func selected_id(menu: OptionButton) -> int:
	return menu.get_item_metadata(menu.selected) if menu.selected>=0 else -1

func refresh(snapshot: Dictionary) -> void:
	var alpha: Dictionary = snapshot.get("alpha",{})
	visible=alpha.get("camp",false) and alpha.has("specialSlots")
	if not visible: return
	var key: String = str(alpha.items)+str(alpha.specialSlots)+str(snapshot.paused)
	if key==signature: return
	signature=key
	var source_id: int = selected_id(sources)
	var equipment_id: int = selected_id(equipment)
	sources.clear(); equipment.clear(); current=alpha.skillSources
	for source in current:
		sources.add_item("%s #%d · %s" % [source.name,source.id,"有效" if source.active else "休眠／地面"])
		sources.set_item_metadata(sources.item_count-1,source.id)
		if source.id==source_id: sources.select(sources.item_count-1)
	for item in alpha.items:
		if item.name not in ["训练弓","布履"] or item.state!="normal" or item.get("shadow",false): continue
		equipment.add_item("%s #%d%s" % [item.name,item.id," · 已有书" if item.has("specialBook") else ""])
		equipment.set_item_metadata(equipment.item_count-1,item.id)
		if item.id==equipment_id: equipment.select(equipment.item_count-1)
	var lines: PackedStringArray = ["专属穿透1×2、神兽1×3必须留经脉；两轻书共9格，箭雨加轻书共11格须镶嵌。"]
	for index in 2:
		var choice: Dictionary = alpha.specialSlots[index]
		lines.append("%s：%s · 来源 #%d · %s" % ["E" if index==0 else "G",{"rain":"箭雨","backwind":"回风","charge":"蓄势"}.get(choice.get("skill",""),"空"),choice.get("sourceId",-1),"启用" if choice.active else "空缺／休眠"])
	summary.text="\n".join(lines)
	update_buttons()

func update_buttons() -> void:
	assign_button.disabled=true; embed_button.disabled=true
	for source in current:
		if source.id!=selected_id(sources): continue
		assign_button.disabled=not source.active
		embed_button.disabled=source.carrierId>=0 or equipment.item_count==0
