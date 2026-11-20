extends Node2D
## 装备挂件层：按槽位把装备与符挂到角色身上。
##
## 挂点坐标来自 gear_anchors.json（clip 像素），随当前 clip 换算到世界坐标。
## 槽位缺失贴图时降级为纯色剪影占位，并输出一次警告而不是静默消失。
## 装备变更按签名逐槽 diff，只过渡发生变化的槽位。

const GEAR_DIR: String = "res://assets/characters/gear-v1/"
const ANCHOR_FILE: String = "res://assets/characters/action-redraw-v1/gear_anchors.json"
const SLOTS: Array[String] = ["weapon","feet","head","body","hand","back"]
# 过渡时长（秒）：新增淡入、移除淡出。
const FADE_IN: float = 0.16
const FADE_OUT: float = 0.12
# 挂件贴图按世界尺寸裁切，用角色统一的视觉缩放还原到世界比例。
const GEAR_WORLD_SCALE: float = 0.11
var anchors: Dictionary = {}
var textures: Dictionary = {}
var slots: Dictionary = {}
var signature: String = ""
var current_clip: String = ""
var current_flip: bool = false
var clip_scale: float = 1.0
var clip_root: Vector2 = Vector2.ZERO
var frame_index: int = 0
var context_anchors: Dictionary = {}
var integrated_slots: Array[String] = []

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHOR_FILE))
	if parsed is Dictionary: anchors=parsed
	else: push_warning("gear_rig: 无法读取挂点表 %s" % ANCHOR_FILE)

## 由表现层每帧告知当前使用哪个 clip 与其缩放、锚点，挂件据此定位。
func set_context(clip: String,flip: bool,scale_value: float,root: Vector2,index: int = 0,points: Dictionary = {}) -> void:
	current_clip=clip; current_flip=flip; clip_scale=scale_value; clip_root=root
	frame_index=index; context_anchors=points

## 应用一份外观描述。只在签名变化时启动过渡。
func set_appearance(appearance: Dictionary) -> void:
	var incoming: String = str(appearance.get("signature",""))
	if incoming==signature: return
	signature=incoming
	var desired: Dictionary = appearance.get("slots",{})
	for slot in SLOTS:
		var entry: Dictionary = desired.get(slot,{}) as Dictionary
		var current: Sprite2D = slots.get(slot,null) as Sprite2D
		if entry.is_empty():
			# 槽位空出：把现有挂件淡出移除。
			if current!=null: start_fade_out(slot)
			continue
		var current_name: String = ""
		if current!=null: current_name=str((current.get_meta("entry",{}) as Dictionary).get("name",""))
		if current_name==str(entry.get("name","")): continue
		if current!=null: start_fade_out(slot)
		start_fade_in(slot,entry)

func start_fade_in(slot: String,entry: Dictionary) -> void:
	var art: String = str(entry.get("art",""))
	var texture: Texture2D = load_texture(art)
	var node: Sprite2D = Sprite2D.new()
	node.name="Gear_"+slot
	node.centered=true
	if texture!=null:
		node.texture=texture
		node.region_enabled=false
	else:
		# 缺贴图时用纯色剪影占位：明确传达"此处应有挂件但未配图"。
		push_warning("gear_rig: 槽位 %s 缺少贴图 %s，降级为剪影占位" % [slot,art])
	node.set_meta("placeholder",texture==null)
	node.set_meta("entry",entry)
	node.set_meta("phase","in")
	node.set_meta("age",0.0)
	node.set_meta("slot",slot)
	# 背饰在躯干之后（会被身体遮挡），其余挂件在躯干之前。
	node.z_index=-1 if slot=="back" else 3
	# 贴图按世界尺寸裁切，统一用角色视觉缩放还原；弓按其自身 clip 的比例偏大，单独放大。
	node.scale=Vector2.ONE*(GEAR_WORLD_SCALE*1.82 if slot=="weapon" else GEAR_WORLD_SCALE)
	add_child(node)
	slots[slot]=node

func start_fade_out(slot: String) -> void:
	var node: Sprite2D = slots.get(slot,null) as Sprite2D
	if node==null: return
	node.set_meta("phase","out")
	node.set_meta("age",0.0)

func load_texture(art: String) -> Texture2D:
	if art.is_empty(): return null
	if textures.has(art): return textures[art]
	var path: String = GEAR_DIR+art+".png"
	if not ResourceLoader.exists(path):
		push_warning("gear_rig: 找不到挂件贴图 %s" % path)
		textures[art]=null
		return null
	var texture: Texture2D = load(path)
	textures[art]=texture
	return texture

## 当前 clip 下某槽位的挂点（世界坐标，相对本节点原点）。
func anchor_point(slot: String) -> Vector2:
	if context_anchors.is_empty() and not anchors.has(current_clip): return Vector2.ZERO
	var entry: Dictionary = context_anchors if not context_anchors.is_empty() else anchors[current_clip]
	if not entry.has(slot): return Vector2.ZERO
	var value: Variant = entry[slot]
	var point: Vector2 = Vector2.ZERO
	if value is Array:
		var values: Array = value
		if values.is_empty(): return Vector2.ZERO
		var first: Array = values[clampi(frame_index,0,values.size()-1)]
		point = Vector2(float(first[0]),float(first[1]))
	elif value is Vector2:
		point = value
	else:
		return Vector2.ZERO
	var offset: Vector2 = point-clip_root
	if current_flip: offset.x=-offset.x
	return offset*clip_scale

func update(delta: float) -> void:
	for slot in slots.keys():
		var node: Sprite2D = slots[slot]
		if not is_instance_valid(node): continue
		node.visible=not integrated_slots.has(str(slot))
		var age: float = float(node.get_meta("age",0.0))+delta
		node.set_meta("age",age)
		var phase: String = str(node.get_meta("phase","in"))
		var alpha: float = 0.0
		if phase=="in": alpha=clampf(age/FADE_IN,0.0,1.0)
		else: alpha=clampf(1.0-age/FADE_OUT,0.0,1.0)
		var placeholder: bool = bool(node.get_meta("placeholder",false))
		var base: Color = Color(0.85,0.78,0.6) if placeholder else Color.WHITE
		node.modulate=Color(base.r,base.g,base.b,alpha)
		# 位置：挂点相对世界坐标；贴图居中，剪影占位直接落在挂点上。
		var point: Vector2 = anchor_point(slot)
		node.position=point
		if phase=="out" and alpha<=0.0:
			node.queue_free()
			slots.erase(slot)
