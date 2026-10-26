extends "res://scripts/presentation/boss_scene.gd"

func create_room(_layout: Dictionary) -> TrainingRoom:
	return BossRoom.new({"spawn":Vector2(840,520),"mana":starting_mana,"health":starting_health,"stamina":starting_stamina})

func create_backdrop() -> Node2D:
	return preload("res://scripts/presentation/thor_rig_pilot_view.gd").new()

func guidance_at(_position: Vector2) -> Dictionary:
	return {"region":"索尔 · AI关节片段试点","landmark":"仅待机／横锤；其他阶段使用待机占位"}
