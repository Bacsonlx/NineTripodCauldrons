extends Node2D

var props: Array[Node] = []

func setup(_data: Dictionary,_frames: Dictionary,_images: Dictionary) -> void:
	props.clear()
	for item in get_parent().get_node("TangguMap").get_children():
		if item.has_method("update_state"): props.append(item)
	var doors: Node = get_parent().get_node("TangguMap").get_node_or_null("Doors")
	if doors!=null: props.append_array(doors.get_children())

func update(state: Dictionary,clock: float) -> void:
	for item in props: item.update_state(state,clock)
