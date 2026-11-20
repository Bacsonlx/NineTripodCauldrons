extends Control

const Profile = preload("res://scripts/hub/profile.gd")
const UI = preload("res://scripts/hub/hub_theme.gd")
const Art = preload("res://scripts/presentation/item_art.gd")
var profile: RefCounted
var chosen: int = -1
var busy: bool = false
var notice: Label
var choices: ItemList

func _ready() -> void:
	profile=Profile.new(); theme=UI.make()
	if profile.data.settlement.is_empty():
		get_tree().change_scene_to_file.bind("res://scenes/safehouse.tscn").call_deferred(); return
	var veil: ColorRect = ColorRect.new(); veil.color=Color("0b1414"); add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new(); add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card: PanelContainer = PanelContainer.new(); center.add_child(card)
	card.custom_minimum_size=Vector2(700,0)
	var column: VBoxContainer = VBoxContainer.new(); column.add_theme_constant_override("separation",16); card.add_child(column)
	var result: Dictionary = profile.data.settlement
	column.add_child(UI.label("神 降 已 毕",14,UI.GOLD))
	column.add_child(UI.label({"victory":"汤谷归来","death":"影散，记忆仍在","incense":"香尽，归于祠前"}[result.result],32))
	column.add_child(UI.label("完成 %d 房间 · 筹备资源 +%d · 香火 +%d" % [result.completed.size(),result.reward,result.incense],20))
	var unlocked: PackedStringArray = []
	for recipe in Profile.RECIPES:
		if result.unlocks.has(recipe.id): unlocked.append(recipe.equipment+" · "+recipe.glyph)
	column.add_child(UI.label("解锁配方："+("、".join(unlocked) if not unlocked.is_empty() else "本次无新增"),17,UI.GOLD,true))
	column.add_child(UI.label("选择下一次传承 · 无名档最多一件，可不选\n只保留物品记忆与原形，占格并以一票参与祭坛；强化与嵌符不继承。",16,UI.MUTED,true))
	choices=ItemList.new(); choices.custom_minimum_size=Vector2(640,220); choices.fixed_icon_size=Vector2i(44,44)
	column.add_child(choices)
	choices.add_item("不传承",null); choices.set_item_metadata(0,-1); choices.select(0)
	for item in result.candidates:
		var index: int = choices.add_item("%s · %s · %d×%d" % [item.name,item.quality,item.size.x,item.size.y],Art.texture(item.name))
		choices.set_item_metadata(index,int(item.id))
	choices.item_selected.connect(func(index: int): chosen=int(choices.get_item_metadata(index)))
	notice=UI.label("确认后发放本局收益，并返回安全屋。未选中的传承记忆将失去。",16,UI.MUTED,true)
	column.add_child(notice)
	UI.button(column,"确认结算 · 返回安全屋",finish).grab_focus()
	UI.button(column,"退出游戏 · 稍后继续结算",func(): get_tree().quit())

func finish() -> void:
	if busy: return
	busy=true
	if not profile.finish_settlement(chosen):
		busy=false; notice.text="保存结算失败，请重试。未发放或扣除任何额外收益。"; return
	var result: Error = get_tree().change_scene_to_file("res://scenes/safehouse.tscn")
	if result!=OK: busy=false; notice.text="安全屋加载失败；结算已保存，重新启动可返回安全屋。"
