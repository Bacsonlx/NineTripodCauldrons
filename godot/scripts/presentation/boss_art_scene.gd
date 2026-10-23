extends "res://scripts/presentation/boss_scene.gd"

func create_backdrop() -> Node2D:
	return preload("res://scripts/presentation/boss_art_view.gd").new()
