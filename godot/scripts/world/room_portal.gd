@tool
extends Node2D

const Journey = preload("res://scripts/journey/room_journey.gd")

@export var portal_id: String = ""
@export var target_room: String = ""
@export var target_portal: String = ""
@export var target_title: String = ""
var _blessing_beast: String = ""
var _blessing_tier: int = 0
@export var blessing_beast: String = "":
	get: return _blessing_beast
	set(value):
		_blessing_beast=value
		_sync_blessing_visual()
@export var blessing_tier: int = 0:
	get: return _blessing_tier
	set(value):
		_blessing_tier=value
		_sync_blessing_visual()
var runtime_generated: bool = false

var _last_text: String = ""
var open_tint: Color = Color("dae8b4")
var sealed_tint: Color = Color("ba9377")

func definition() -> Dictionary:
	var origin: Vector2 = get_parent().position+position
	var approach: Vector2 = origin+$Approach.position
	var arrival: Vector2 = origin+$Arrival.position
	var half_w: float = 0.0 if runtime_generated else 24.0
	var half_h: float = 0.0 if runtime_generated else 76.0
	return {"id":portal_id,"target":target_room,"targetDoor":target_portal,"title":target_title,"routeLabel":Journey.direction_label(target_room,str(get_parent().get_parent().get("room_id"))),"point":{"x":approach.x,"y":approach.y},"arrival":{"x":arrival.x,"y":arrival.y},"facing":0 if $Arrival.position.x>0 else 2,"x":origin.x,"y":origin.y-25,"halfWidth":half_w,"halfHeight":half_h,"height":140,"kind":"wall","blocksProjectiles":not runtime_generated,"choice":not blessing_beast.is_empty(),"blessingBeast":blessing_beast,"blessingTier":blessing_tier}

func _ready() -> void:
	set_notify_transform(true)
	z_index=int(global_position.y)
	$Destination.text=target_title
	$Passage.position=$Approach.position
	_sync_blessing_visual()

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree(): z_index=int(global_position.y)

func update_state(state: Dictionary,clock: float) -> void:
	$Frame.update_state(state,clock)
	var body: Sprite2D = $Frame/Sprite
	# 复用门框已缓存的几何，避免每帧 get_rect() + to_local() 矩阵求逆。
	var next_alpha: float = 0.38 if state.player.y<global_position.y and $Frame.occludes(state) else 1.0
	if not is_equal_approx(body.modulate.a,next_alpha): body.modulate.a=next_alpha
	$Seal.update_state(state,clock)
	var sealed: bool = not state.roomComplete
	if $Seal.visible!=sealed: $Seal.visible=sealed
	if $Passage.visible!=state.roomComplete: $Passage.visible=state.roomComplete
	if $Passage.position!=$Approach.position: $Passage.position=$Approach.position
	if not state.paused and state.status!="failed":
		$Passage/Swirl.rotation=clock*0.24
		$Passage/Swirl.modulate=Color(0.82,0.96,0.85,0.76+0.08*sin(clock*2.0))
	var usable: bool = state.interaction!=null and state.interaction.id=="door:"+portal_id and state.interaction.reason==null
	var hovered: bool = state.interaction!=null and state.interaction.id=="door:"+portal_id
	_sync_blessing_visual(not state.roomComplete,hovered,usable)
	var text: String = ("可通行 · " if state.roomComplete else "封印中 · ")+Journey.direction_label(target_room,state.roomId)+" · "+target_title
	if not blessing_beast.is_empty():
		var tier_title: String = ["初念","再念","三念"][clampi(blessing_tier,1,3)-1]
		text+="\n选择祝福 · %s%s" % [blessing_beast,tier_title]
	if state.roomComplete and usable and not state.paused and state.status!="failed": text+="\nF · 前往房间"
	if text!=_last_text:
		$Destination.text=text; _last_text=text
	var tint: Color = open_tint if state.roomComplete else sealed_tint
	if $Destination.modulate!=tint: $Destination.modulate=tint

func visual_theme_matches(beast: String,tier: int) -> bool:
	var pattern: Node = get_node_or_null("BlessingPattern")
	var overlay: Node = get_node_or_null("TierOverlay")
	return pattern!=null and overlay!=null and pattern.matches_blessing(beast,tier) and overlay.matches_blessing(beast,tier)

func visual_theme_key() -> Dictionary:
	var pattern: Node = get_node_or_null("BlessingPattern")
	return pattern.theme_key() if pattern!=null else {}

func _sync_blessing_visual(is_sealed: bool = true,is_hovered: bool = false,is_usable: bool = false) -> void:
	var body: Sprite2D = get_node_or_null("Frame/Sprite")
	for node_name in ["BlessingPattern","TierOverlay"]:
		var visual: Sprite2D = get_node_or_null(node_name)
		if visual!=null:
			if body!=null:
				visual.transform=$Frame.transform*body.transform
				visual.offset=body.offset
				visual.centered=body.centered
				visual.flip_h=body.flip_h
				visual.self_modulate=body.self_modulate*Color(1,1,1,body.modulate.a)
			visual.configure(_blessing_beast,_blessing_tier,is_sealed,is_hovered,is_usable)
