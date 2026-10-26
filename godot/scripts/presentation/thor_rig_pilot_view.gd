extends "res://scripts/presentation/boss_view.gd"

func _ready() -> void:
	super._ready()
	character=preload("res://scenes/prototypes/thor_rig_pilot.tscn").instantiate()
	add_child(character)

func update(snapshot: Dictionary,clock: float) -> void:
	super.update(snapshot,clock)
	character.update_state(snapshot)
