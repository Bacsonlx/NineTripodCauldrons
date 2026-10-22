extends Node2D

func get_layout() -> Dictionary:
	return preload("res://scripts/combat/boss_room.gd").arena_layout()
