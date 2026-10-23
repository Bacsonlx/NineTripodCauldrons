extends "res://scripts/presentation/boss_view.gd"

func _ready() -> void:
	super._ready()
	character=preload("res://scripts/presentation/thor_puppet.gd").new()
	add_child(character)

func update(snapshot: Dictionary,clock: float) -> void:
	super.update(snapshot,clock)
	character.update_state(snapshot)
