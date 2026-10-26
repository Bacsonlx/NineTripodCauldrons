@tool
extends Node2D

const Journey = preload("res://scripts/journey/room_journey.gd")

@export var portal_id: String = ""
@export var target_room: String = ""
@export var target_portal: String = ""
@export var target_title: String = ""

func definition() -> Dictionary:
	var origin: Vector2 = get_parent().position+position
	var approach: Vector2 = origin+$Approach.position
	var arrival: Vector2 = origin+$Arrival.position
	return {"id":portal_id,"target":target_room,"targetDoor":target_portal,"title":target_title,"routeLabel":Journey.direction_label(target_room,str(get_parent().get_parent().get("room_id"))),"point":{"x":approach.x,"y":approach.y},"arrival":{"x":arrival.x,"y":arrival.y},"facing":0 if $Arrival.position.x>0 else 2,"x":origin.x,"y":origin.y-25,"halfWidth":24,"halfHeight":76,"height":140,"kind":"wall"}

func _ready() -> void:
	set_notify_transform(true)
	z_index=int(global_position.y)
	$Destination.text=definition().routeLabel+" · "+target_title
	$Passage.position=$Approach.position

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree(): z_index=int(global_position.y)

func update_state(state: Dictionary,clock: float) -> void:
	$Frame.update_state(state,clock)
	var body: Sprite2D = $Frame/Sprite
	body.modulate.a=0.38 if state.player.y<global_position.y and body.get_rect().has_point(body.to_local(Vector2(state.player.x,state.player.y-45))) else 1.0
	$Seal.update_state(state,clock)
	$Seal.visible=not state.roomComplete
	$Passage.visible=state.roomComplete
	$Passage.position=$Approach.position
	if not state.paused and state.status!="failed":
		$Passage/Swirl.rotation=clock*0.24
		$Passage/Swirl.modulate=Color(0.82,0.96,0.85,0.76+0.08*sin(clock*2.0))
	var usable: bool = state.interaction!=null and state.interaction.id=="door:"+portal_id and state.interaction.reason==null
	$Destination.text=("可通行 · " if state.roomComplete else "封印中 · ")+Journey.direction_label(target_room,state.roomId)+" · "+target_title
	if state.roomComplete and usable and not state.paused and state.status!="failed": $Destination.text+="\nF · 前往房间"
	$Destination.modulate=Color("dae8b4") if state.roomComplete else Color("ba9377")
