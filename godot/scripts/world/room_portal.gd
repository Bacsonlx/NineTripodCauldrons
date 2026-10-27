@tool
extends Node2D

@export var portal_id: String = ""
@export var target_room: String = ""
@export var target_portal: String = ""
@export var target_title: String = ""

var _last_text: String = ""
var open_tint: Color = Color("dae8b4")
var sealed_tint: Color = Color("ba9377")

func definition() -> Dictionary:
	var origin: Vector2 = get_parent().position+position
	var approach: Vector2 = origin+$Approach.position
	var arrival: Vector2 = origin+$Arrival.position
	return {"id":portal_id,"target":target_room,"targetDoor":target_portal,"title":target_title,"point":{"x":approach.x,"y":approach.y},"arrival":{"x":arrival.x,"y":arrival.y},"facing":0 if $Arrival.position.x>0 else 2,"x":origin.x,"y":origin.y-25,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"}

func _ready() -> void:
	set_notify_transform(true)
	z_index=int(global_position.y)
	$Destination.text=target_title
	$Passage.position=$Approach.position

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
	var text: String = ("可通行 · " if state.roomComplete else "封印中 · ")+target_title
	if state.roomComplete and usable and not state.paused and state.status!="failed": text+="\nF · 前往房间"
	if text!=_last_text:
		$Destination.text=text; _last_text=text
	var tint: Color = open_tint if state.roomComplete else sealed_tint
	if $Destination.modulate!=tint: $Destination.modulate=tint
