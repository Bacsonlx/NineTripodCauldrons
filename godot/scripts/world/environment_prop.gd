@tool
extends "res://scripts/world/map_item.gd"

@export var texture_asset: Texture2D:
	set(value): texture_asset=value; refresh()
@export var render_width: float = 160.0:
	set(value): render_width=value; refresh()
@export var art_offset: Vector2 = Vector2.ZERO:
	set(value): art_offset=value; refresh()
@export var mirror_art: bool = false:
	set(value): mirror_art=value; refresh()
@export var depth_offset: int = 0:
	set(value): depth_offset=value; refresh()
@export var flat: bool = false:
	set(value): flat=value; refresh()
@export var ground_axis: Vector2 = Vector2.RIGHT:
	set(value): ground_axis=value; refresh()

func _ready() -> void:
	set_notify_transform(true)
	refresh()

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED:
		z_index=-20 if flat else clampi(int(position.y)+depth_offset,0,4080)

func layout_changed() -> void:
	refresh()

func refresh() -> void:
	var body: Sprite2D = get_node_or_null("Sprite")
	if body==null or texture_asset==null: return
	body.texture=texture_asset
	body.flip_h=mirror_art
	body.offset=Vector2(-texture_asset.get_width()/2.0,-texture_asset.get_height())
	body.scale=Vector2.ONE*render_width/texture_asset.get_width()
	body.position=art_offset+(Vector2(0,size.y/2) if category=="obstacle" else Vector2.ZERO)
	# 改变墙面在地面的投影方向，竖直石柱仍保持竖直。
	var unit: float = render_width/texture_asset.get_width()
	body.transform=Transform2D(ground_axis*unit,Vector2(0,unit),body.position)
	body.self_modulate=material_tint()
	var contact: Node2D = get_node_or_null("GroundContact")
	if contact==null:
		contact=Node2D.new()
		contact.name="GroundContact"
		contact.set_script(preload("res://scripts/world/prop_ground_contact.gd"))
		add_child(contact)
	contact.configure(self)
	z_index=-20 if flat else clampi(int(position.y)+depth_offset,0,4080)

func material_tint() -> Color:
	var asset: String = texture_asset.resource_path.get_file().get_basename()
	if asset.begins_with("wall") or asset in ["pillar","stele","altar","gateway","gate"]:
		return Color(0.88,0.9,0.8)
	if asset=="camp": return Color(0.9,0.88,0.8)
	return Color.WHITE

func update_state(state: Dictionary,clock: float) -> void:
	visible=(opens_after_encounter<0 or state.encounter<=opens_after_encounter) and (obstacle_kind!="gate" or category!="obstacle" or not state.exploration.gateOpen)
	var body: Sprite2D = $Sprite
	var point: Vector2 = Vector2(state.player.x,state.player.y)
	var bounds: Rect2 = body.get_rect()
	var local_point: Vector2 = body.to_local(point+Vector2(0,-45))
	body.modulate.a=0.38 if not flat and point.y<position.y and bounds.has_point(local_point) else 1.0
	if obstacle_kind=="brazier": body.self_modulate=material_tint()*Color(1.0,0.96+0.04*sin(clock*5),0.9+0.1*sin(clock*5))

func _draw() -> void:
	# 美术与脚点都由本场景承担；编辑器选中节点后可用 Inspector 调整碰撞尺寸。
	pass
