extends Node2D

var standalone_environment: bool = true

func _ready() -> void:
	if standalone_environment:
		add_child(preload("res://scenes/world/boss_environment.tscn").instantiate())
