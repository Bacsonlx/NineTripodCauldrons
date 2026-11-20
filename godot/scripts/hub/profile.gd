extends RefCounted

const Alpha = preload("res://scripts/alpha/alpha_state.gd")
const Equipment = preload("res://scripts/alpha/equipment_rules.gd")
const Save = preload("res://scripts/hub/journey_save.gd")
const RECIPES: Array[Dictionary] = [
	{"id":"bow_horn","equipment":"训练弓","glyph":"羊角","room":"court1","goal":"正式结算：完成第一庭"},
	{"id":"bow_brush","equipment":"训练弓","glyph":"鼠毫","room":"court2","goal":"正式结算：完成第二庭"},
	{"id":"boots_horn","equipment":"布履","glyph":"羊角","room":"court3","goal":"正式结算：完成第三庭"},
	{"id":"boots_brush","equipment":"布履","glyph":"鼠毫","room":"victory","goal":"正式通关汤谷"}
]
const SHOP: Array[String] = ["羊角","虎牙","鼠毫","燧火","素食"]
const VERSION: int = 1
var path: String
var data: Dictionary = {}
var error: String = ""

func _init(save_path: String = "") -> void:
	path=save_path if not save_path.is_empty() else OS.get_environment("JIUDING_PROFILE_PATH")
	if path.is_empty(): path="user://journey-profile-v1.save"
	data={"version":VERSION,"resources":0,"incense":0,"unlocks":[],"heritage":[],
		"preparation":[],"active":{},"settlement":{},"sequence":0}
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
		var loaded: Variant = read_save(path)
		if loaded==null: loaded=read_save(path+".bak")
		if loaded==null: error="进度文件无法读取，已保留原文件；请恢复有效备份。"; return
		data=loaded
	if data.preparation.is_empty() and data.active.is_empty() and data.settlement.is_empty(): reset_preparation()

func read_save(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path): return null
	var file: FileAccess = FileAccess.open(file_path,FileAccess.READ)
	if file==null: return null
	var value: Variant = file.get_var(false)
	if not value is Dictionary or value.get("version",0)!=VERSION: return null
	for key in ["resources","incense","sequence"]:
		if not value.get(key) is int or value[key]<0: return null
	for key in ["unlocks","heritage","preparation"]:
		if not value.get(key) is Array: return null
	for key in ["active","settlement"]:
		if not value.get(key) is Dictionary: return null
	if not value.active.is_empty():
		var checkpoint: Variant = value.active.get("checkpoint")
		if not value.active.get("id") is int or not checkpoint is Dictionary: return null
		for key in ["options","rooms","inventory","effects"]:
			if not checkpoint.get(key) is Dictionary: return null
		if not checkpoint.get("current") is String or not checkpoint.rooms.has(checkpoint.current): return null
		if not checkpoint.get("departure") is Array or not checkpoint.get("seed") is int or not checkpoint.get("generation") is int: return null
	if not value.settlement.is_empty():
		if value.active.is_empty() or value.settlement.get("run")!=value.active.id: return null
		if value.settlement.get("result") not in ["victory","death","incense"]: return null
		for key in ["reward","incense"]:
			if not value.settlement.get(key) is int: return null
		for key in ["completed","unlocks","candidates"]:
			if not value.settlement.get(key) is Array: return null
	return value

func flush() -> bool:
	if not error.is_empty(): return false
	var full_path: String = ProjectSettings.globalize_path(path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	if directory_error!=OK: return false
	var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_var(data,false); file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error!=OK: return false
	if FileAccess.file_exists(path) and read_save(path)!=null:
		if DirAccess.copy_absolute(full_path,full_path+".bak")!=OK: return false
	return DirAccess.rename_absolute(full_path+".tmp",full_path)==OK

func commit(previous: Dictionary) -> bool:
	if flush(): return true
	data=previous
	return false

func reset_preparation() -> void:
	var alpha: RefCounted = Alpha.new(1,true,[])
	alpha.reset(Vector2.ZERO)
	for item in alpha.items: item.prepKey="base:"+item.name
	data.preparation=alpha.items.duplicate(true)
	for shadow in data.heritage:
		var item: Dictionary = shadow.duplicate(true)
		item.id=100000+alpha.next_id; alpha.next_id+=1
		item.prepKey="shadow"; item.region="ground"
		alpha.items.append(item)
		if not fit(alpha,item,"altar"): item.region="unplaced"
	data.preparation=alpha.items.duplicate(true)

static func fit(alpha: RefCounted,item: Dictionary,preferred: String = "") -> bool:
	var regions: Array = [preferred] if not preferred.is_empty() else ["warehouse","altar","equipment"]
	for region in regions:
		var bounds: Rect2i = Alpha.REGIONS[region]
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				for rotated in [false,true]:
					if alpha.place(item,Vector2i(x,y),rotated): return true
	return false

func preparation() -> RefCounted:
	var alpha: RefCounted = Alpha.new(1,true,data.preparation)
	alpha.reset(Vector2.ZERO); alpha.camp=true; alpha.departed=false
	return alpha

func save_preparation(alpha: RefCounted) -> bool:
	if not data.active.is_empty() or not data.settlement.is_empty(): return false
	if alpha.items.is_empty(): return false
	var before: Dictionary = data.duplicate(true)
	data.preparation=alpha.items.duplicate(true)
	return commit(before)

func cost(items: Variant = null) -> int:
	if items==null: items=data.preparation
	var total: int = 0
	for item in items:
		if item.has("recipe"): total+=20
		if item.has("shop"): total+=10
		for glyph in item.get("glyphs",[]):
			if glyph.has("shop"): total+=10
	return total

func shop_names(items: Variant = null) -> Array[String]:
	if items==null: items=data.preparation
	var result: Array[String] = []
	for item in items:
		if item.has("shop"): result.append(item.name)
		for glyph in item.get("glyphs",[]):
			if glyph.has("shop"): result.append(glyph.name)
	return result

func buy(name_text: String) -> String:
	if not SHOP.has(name_text): return "该商品未开放"
	var names: Array[String] = shop_names()
	if names.has(name_text): return "本次已选择该商品；同名最多额外一件"
	if names.size()>=2: return "每次出征最多额外购买两件"
	var alpha: RefCounted = preparation()
	var item: Dictionary = alpha.add_item(name_text,"ground",Vector2i.ZERO)
	item.shop=name_text
	if not fit(alpha,item): return "背包放不下，请先整理或减少物品"
	return "已加入准备，出征时支付" if save_preparation(alpha) else "保存失败，选择未生效"

func remove_purchase(name_text: String) -> String:
	var alpha: RefCounted = preparation()
	for item in alpha.items.duplicate():
		if item.get("shop","")==name_text:
			alpha.items.erase(item)
			return "已移除额外补给" if save_preparation(alpha) else "保存失败，选择未生效"
		for glyph in item.get("glyphs",[]).duplicate():
			if glyph.get("shop","")!=name_text: continue
			item.glyphs.erase(glyph)
			repair_main(item)
			return "已撤销该符的嵌入与购买" if save_preparation(alpha) else "保存失败，选择未生效"
	return "未选择该商品"

func select_recipe(recipe_id: String) -> String:
	var recipe: Dictionary = {}
	for entry in RECIPES:
		if entry.id==recipe_id: recipe=entry
	if recipe.is_empty() or not data.unlocks.has(recipe_id): return "尚未解锁该配方"
	var alpha: RefCounted = preparation()
	var item: Dictionary = alpha.find_item_by_name(recipe.equipment)
	if item.is_empty(): return "请先恢复对应基础装备，再选择打造方案"
	var glyphs: Array = item.get("glyphs",[]).filter(func(glyph: Dictionary): return not glyph.get("recipeGlyph",false))
	if item.get("recipe","")==recipe_id:
		item.erase("recipe")
	else:
		if glyphs.size()>=3: return "嵌符名额已满，请先撤销准备中的嵌符"
		var glyph: Dictionary = alpha.add_item(recipe.glyph,"ground",Vector2i.ZERO)
		alpha.items.erase(glyph); glyph.recipeGlyph=true; glyphs.append(glyph)
		item.recipe=recipe_id
	item.glyphs=glyphs
	repair_main(item)
	alpha.recount()
	return "已更新打造准备，出征时支付" if save_preparation(alpha) else "保存失败，选择未生效"

static func repair_main(item: Dictionary) -> void:
	var glyphs: Array = item.get("glyphs",[])
	if glyphs.is_empty():
		item.mainGlyph=false; item.erase("mainGlyphId"); item.container=""
	else:
		var retained: int = int(item.get("mainGlyphId",-1))
		if not glyphs.any(func(glyph: Dictionary): return int(glyph.id)==retained): retained=int(glyphs[0].id)
		Equipment.select_main(item,retained)

func departure_error() -> String:
	if not error.is_empty(): return error
	if not data.active.is_empty() or not data.settlement.is_empty(): return "请先继续并完成当前征程"
	if cost()>data.resources: return "筹备资源不足：需要 %d，持有 %d" % [cost(),data.resources]
	var alpha: RefCounted = preparation()
	for item in alpha.items:
		if not Alpha.REGIONS.has(item.region): return "还有未放入背包的物品"
		var reason: String = alpha.placement_error(item,item.cell,item.rotated)
		if not reason.is_empty(): return reason
	return ""

func depart(journey: RefCounted) -> bool:
	if not departure_error().is_empty(): return false
	var before: Dictionary = data.duplicate(true)
	data.resources-=cost(); data.sequence+=1
	data.active={"id":data.sequence,"checkpoint":Save.pack(journey)}
	data.heritage=[]; data.preparation=[]
	return commit(before)

func checkpoint(journey: RefCounted) -> bool:
	if data.active.is_empty() or not data.settlement.is_empty(): return false
	var before: Dictionary = data.duplicate(true)
	data.active.checkpoint=Save.pack(journey)
	return commit(before)

func prepare_settlement(journey: RefCounted,result: String) -> bool:
	if data.active.is_empty(): return false
	if not data.settlement.is_empty(): return true
	if not result in ["victory","death","incense"]: return false
	var before: Dictionary = data.duplicate(true)
	var complete: Array[String] = []
	var reward: int = 30 if result=="victory" else 0
	for id in journey.rooms:
		var room: TrainingRoom = journey.rooms[id]
		if not room.completed: continue
		complete.append(id)
		if room.layout.objective in ["combat","boss"]: reward+=10
	var unlocks: Array[String] = []
	for recipe in RECIPES:
		if (complete.has(recipe.room) or recipe.room=="victory" and result=="victory") and not data.unlocks.has(recipe.id): unlocks.append(recipe.id)
	var candidates: Array = []
	for item in journey.inventory.items:
		if item.get("region","")!="ground" and not item.get("container","").is_empty() and item.get("state","")=="normal":
			candidates.append(item.duplicate(true))
	data.settlement={"run":data.active.id,"result":result,"reward":reward,"incense":1,
		"unlocks":unlocks,"candidates":candidates,"completed":complete}
	return commit(before)

func finish_settlement(selected_id: int = -1) -> bool:
	if data.settlement.is_empty(): return false
	var before: Dictionary = data.duplicate(true)
	var selected: Dictionary = {}
	if selected_id!=-1:
		for item in data.settlement.candidates:
			if int(item.id)==selected_id: selected=item
		if selected.is_empty(): return false
	data.resources+=int(data.settlement.reward); data.incense+=int(data.settlement.incense)
	for id in data.settlement.unlocks:
		if not data.unlocks.has(id): data.unlocks.append(id)
	data.heritage=[]
	if not selected.is_empty():
		var shadow: Dictionary = Alpha.new().definition(selected.name)
		if shadow.is_empty(): shadow=selected.duplicate(true)
		for key in ["glyphs","recipe","shop","mainGlyph","mainGlyphId","burnStacks"]: shadow.erase(key)
		shadow.merge({"shadow":true,"state":"normal","quality":selected.quality,"container":selected.container,
			"size":selected.size,"rotated":false,"cell":Vector2i(7,1),"region":"altar","order":1},true)
		data.heritage.append(shadow)
	data.active={}; data.settlement={}; reset_preparation()
	return commit(before)

func abandon() -> bool:
	if data.active.is_empty() or not data.settlement.is_empty(): return false
	var before: Dictionary = data.duplicate(true)
	data.active={}; data.heritage=[]; reset_preparation()
	return commit(before)
