extends RefCounted

const Room = preload("res://scripts/combat/training_room.gd")

func item_id(room: TrainingRoom, title: String) -> int:
	for item in room.snapshot().alpha.items:
		if item.name==title: return item.id
	return -1

func intent(room: TrainingRoom, action: Dictionary) -> void:
	room.update({"alpha":action},0)

func run(check: Callable) -> void:
	var room: TrainingRoom = Room.new({"mode":"gameplay"})
	check.call(room.snapshot().has("alpha"), "玩法开关接通营地构筑")
	if not room.snapshot().has("alpha"): return
	var bow: int = item_id(room,"训练弓")
	var horn: int = item_id(room,"羊角")
	intent(room,{"action":"embed","equipmentId":bow,"glyphId":horn})
	check.call(room.snapshot().alpha.equipment.healthMax==130 and room.snapshot().health==100, "嵌入实物羊角预览130上限且不回血")
	check.call(room.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==horn).is_empty(), "嵌符消费原仓库实例不复制")
	check.call(room.snapshot().get("healthMax",100)==100, "营地试摆只预览，出发一次应用")
	intent(room,{"action":"depart"})
	check.call(room.snapshot().healthMax==130 and room.snapshot().health==100, "出发应用羊角上限但保持生命100")

	var respec: TrainingRoom = Room.new({"mode":"gameplay"})
	var target: int = item_id(respec,"训练弓")
	var mouse: int = item_id(respec,"鼠毫")
	var sheep: int = item_id(respec,"羊角")
	intent(respec,{"action":"embed","equipmentId":target,"glyphId":mouse})
	intent(respec,{"action":"embed","equipmentId":target,"glyphId":sheep})
	intent(respec,{"action":"place","id":target,"cell":Vector2i(6,0)})
	check.call(respec.snapshot().alpha.votes["金"]==1 and respec.snapshot().alpha.votes["木"]==0, "两张实物符只由唯一主符提供一份凡品装备票")
	intent(respec,{"action":"main_glyph","equipmentId":target,"glyphId":sheep})
	check.call(respec.snapshot().alpha.votes["木"]==2 and respec.snapshot().alpha.votes["金"]==0, "营地重选已嵌主符改唯一归属，气息按装备真实形状加权")

	var radius: TrainingRoom = Room.new({"mode":"gameplay","initialItems":[{"name":"快马","world":Vector2(482,600)}]})
	var drop: int = item_id(radius,"快马")
	intent(radius,{"action":"pickup","id":drop})
	check.call(radius.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==drop)[0].region=="ground", "基础80半径不能拾取82距离实物")
	intent(radius,{"action":"embed","equipmentId":item_id(radius,"训练弓"),"glyphId":item_id(radius,"羊角")})
	intent(radius,{"action":"embed","equipmentId":item_id(radius,"布履"),"glyphId":item_id(radius,"鼠毫")})
	intent(radius,{"action":"depart"})
	intent(radius,{"action":"pickup","id":drop})
	check.call(radius.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==drop)[0].region=="warehouse" and radius.snapshot().alpha.appliedEquipment.pickupRadius==84, "真实嵌鼠毫并出发后可拾取82距离实物")
	var wall: TrainingRoom = Room.new({"mode":"gameplay","obstacle":Rect2(425,580,10,40),"initialItems":[{"name":"快马","world":Vector2(482,600)}]})
	intent(wall,{"action":"embed","equipmentId":item_id(wall,"训练弓"),"glyphId":item_id(wall,"羊角")})
	intent(wall,{"action":"embed","equipmentId":item_id(wall,"布履"),"glyphId":item_id(wall,"鼠毫")})
	intent(wall,{"action":"depart"})
	intent(wall,{"action":"pickup","id":item_id(wall,"快马")})
	check.call(wall.snapshot().alpha.items.back().region=="ground" and wall.snapshot().alpha.message.contains("遮挡"), "鼠毫84范围仍不能隔墙拾取")

	var capacity: TrainingRoom = Room.new({"mode":"gameplay","initialItems":[{"name":"羊角"},{"name":"虎牙"},{"name":"燧火"}]})
	var carrier: int = item_id(capacity,"训练弓")
	intent(capacity,{"action":"embed","equipmentId":carrier,"glyphId":item_id(capacity,"羊角")})
	intent(capacity,{"action":"embed","equipmentId":item_id(capacity,"布履"),"glyphId":item_id(capacity,"鼠毫")})
	for title in ["羊角","虎牙","燧火"]:
		var glyph: int = item_id(capacity,title)
		intent(capacity,{"action":"pickup","id":glyph})
		intent(capacity,{"action":"embed","equipmentId":carrier,"glyphId":glyph})
	var equipped: Dictionary = capacity.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==carrier)[0]
	check.call(equipped.glyphs.size()==3 and item_id(capacity,"燧火")>=0 and capacity.snapshot().alpha.message.contains("最多三张"), "每件最多三符，第四符拒绝且保留实物")
	check.call(capacity.snapshot().alpha.equipment.healthMax==130, "同名羊角多张仍只提供一份30生命上限")
	intent(capacity,{"action":"depart"})
	intent(capacity,{"action":"main_glyph","equipmentId":carrier,"glyphId":equipped.glyphs[1].id})
	check.call(capacity.snapshot().alpha.message.contains("营地"), "出发后不能重选主符")

	var heal_layout: Dictionary = {"mode":"gameplay","width":1280,"height":900,"spawn":Vector2(400,600),"walkableAreas":[{"left":100,"top":180,"right":1180,"bottom":820}],"floor":[Vector2.ZERO,Vector2(1280,0),Vector2(1280,900),Vector2(0,900)],"pillars":[],"pillarBody":[],"targets":[],"targetFace":{},"grips":Room.GRIPS,"shoulderHeight":52,"obstacles":[],"encounters":[],"exploration":[{"id":"altar","x":400,"y":600}]}
	var healing: TrainingRoom = Room.new(heal_layout)
	var healer_bow: int = item_id(healing,"训练弓")
	intent(healing,{"action":"embed","equipmentId":healer_bow,"glyphId":item_id(healing,"羊角")})
	intent(healing,{"action":"depart"})
	healing.update({"interact":true},0)
	check.call(healing.snapshot().health==130, "已有祭火恢复尊重羊角的新生命上限")
	intent(healing,{"action":"camp"})
	intent(healing,{"action":"place","id":healer_bow,"cell":Vector2i(6,0)})
	intent(healing,{"action":"place","id":healer_bow,"cell":Vector2i(0,0)})
	intent(healing,{"action":"depart"})
	check.call(healing.snapshot().health==130, "营地移出再摆回不应用中间试摆结果")
	intent(healing,{"action":"camp"})
	intent(healing,{"action":"place","id":healer_bow,"cell":Vector2i(6,0)})
	intent(healing,{"action":"depart"})
	check.call(healing.snapshot().healthMax==100 and healing.snapshot().health==100 and healing.snapshot().alpha.equipment.effects.is_empty(), "装备上坛同时停普通符属性，只将当前生命截到100")

	heal_layout.exploration=[{"id":"stele","x":482,"y":600}]
	var interaction: TrainingRoom = Room.new(heal_layout)
	intent(interaction,{"action":"embed","equipmentId":item_id(interaction,"布履"),"glyphId":item_id(interaction,"鼠毫")})
	intent(interaction,{"action":"depart"})
	interaction.update({"interact":true},0)
	check.call(not interaction.snapshot().reading and interaction.snapshot().interaction==null, "鼠毫不扩大F的80互动距离")
	var legacy: TrainingRoom = Room.new({"mode":"alpha"})
	check.call(item_id(legacy,"羊角")==-1 and not legacy.snapshot().alpha.has("equipment"), "alpha旧白盒不获得装备玩法或起始收益")
	intent(room,{"action":"sample","name":"羊角"})
	check.call(room.snapshot().alpha.message.contains("不开放"), "玩法营地拒绝调试样本增发")

	var duplicates: TrainingRoom = Room.new({"mode":"gameplay","initialItems":[{"name":"布履"}]})
	intent(duplicates,{"action":"embed","equipmentId":item_id(duplicates,"训练弓"),"glyphId":item_id(duplicates,"羊角")})
	intent(duplicates,{"action":"embed","equipmentId":item_id(duplicates,"布履"),"glyphId":item_id(duplicates,"鼠毫")})
	var spare_feet: int = duplicates.snapshot().alpha.items.back().id
	intent(duplicates,{"action":"pickup","id":spare_feet})
	intent(duplicates,{"action":"place","id":spare_feet,"cell":Vector2i(3,2),"rotated":false})
	check.call(duplicates.snapshot().alpha.items.back().region=="warehouse" and duplicates.snapshot().alpha.message.contains("同部位"), "同部位第二件训练装备不能在装备区启用")
	intent(respec,{"action":"place","id":target,"cell":Vector2i(6,0),"rotated":true})
	check.call(respec.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==target)[0].rotated, "训练弓允许在合法祭坛空间旋转90度")
	intent(respec,{"action":"place","id":target,"cell":Vector2i(9,3),"rotated":true})
	check.call(respec.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==target)[0].cell==Vector2i(6,0), "装备跨区失败保留原物原位置")
	var boundary: TrainingRoom = Room.new({"mode":"gameplay","initialItems":[{"name":"快马","world":Vector2(485,600)}]})
	intent(boundary,{"action":"embed","equipmentId":item_id(boundary,"训练弓"),"glyphId":item_id(boundary,"羊角")})
	intent(boundary,{"action":"embed","equipmentId":item_id(boundary,"布履"),"glyphId":item_id(boundary,"鼠毫")})
	intent(boundary,{"action":"depart"})
	intent(boundary,{"action":"pickup","id":item_id(boundary,"快马")})
	check.call(boundary.snapshot().alpha.items.back().region=="ground", "鼠毫不允许拾取85距离实物")

	var altar_assembly: TrainingRoom = Room.new({"mode":"gameplay"})
	var altar_bow: int = item_id(altar_assembly,"训练弓")
	intent(altar_assembly,{"action":"place","id":altar_bow,"cell":Vector2i(6,0)})
	intent(altar_assembly,{"action":"embed","equipmentId":altar_bow,"glyphId":item_id(altar_assembly,"鼠毫")})
	check.call(altar_assembly.snapshot().alpha.votes["金"]==1 and altar_assembly.snapshot().alpha.equipment.pickupRadius==80, "营地可给上坛装备嵌符，主符改票但不启动普通符效果")

	var stored: TrainingRoom = Room.new({"mode":"gameplay"})
	var boots: int = item_id(stored,"布履")
	intent(stored,{"action":"embed","equipmentId":item_id(stored,"训练弓"),"glyphId":item_id(stored,"羊角")})
	intent(stored,{"action":"embed","equipmentId":boots,"glyphId":item_id(stored,"鼠毫")})
	intent(stored,{"action":"place","id":boots,"cell":Vector2i(6,4),"rotated":true})
	intent(stored,{"action":"depart"})
	check.call(stored.snapshot().alpha.appliedEquipment.pickupRadius==80 and stored.snapshot().healthMax==130, "布履转仓停止鼠毫，训练弓上的羊角继续有效")
	var physical: Dictionary = stored.snapshot().alpha.items.filter(func(item: Dictionary): return item.id==boots)[0]
	check.call(physical.glyphs.size()==1 and physical.glyphs[0].name=="鼠毫", "换下装备保留已嵌实物符且不可拆回仓库")
	heal_layout.camps=[Vector2(400,600),Vector2(620,600)]
	var camps: TrainingRoom = Room.new(heal_layout)
	intent(camps,{"action":"depart"})
	camps.update({"moveX":1},1)
	intent(camps,{"action":"camp"})
	check.call(camps.snapshot().alpha.camp, "玩法允许在配置的真实营地整理而非仅出生点")
