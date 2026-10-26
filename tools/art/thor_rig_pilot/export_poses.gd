extends SceneTree

const OUTPUT: String = "res://../output/art/BOS-001/2026-10-23-rig-pilot/poses.json"
var frames: Array = []

func _initialize() -> void:
	run.call_deferred()

func collect(node: Node, parts: Array) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			var t: Transform2D = child.global_transform
			var part_name: String = child.get_parent().name if child.name=="Art" else child.name
			parts.append({"name":part_name,"x":[t.x.x,t.x.y],"y":[t.y.x,t.y.y],"origin":[t.origin.x,t.origin.y],"offset":[child.offset.x,child.offset.y],"z":child.z_index})
		collect(child,parts)

func capture(actor: Node2D, variant: String, mode: String, snapshot: Dictionary) -> void:
	actor.update_state(snapshot)
	var parts: Array = []
	collect(actor,parts)
	frames.append({"variant":variant,"mode":mode,"time":snapshot.elapsed,"phase":snapshot.boss.phase,"origin":[snapshot.boss.x,snapshot.boss.y],"parts":parts})

func run() -> void:
	var Room: Script = load("res://scripts/combat/boss_room.gd")
	for mode in ["idle","swing"]:
		var room: TrainingRoom = Room.new({"spawn":Vector2(840,520)})
		var pilot: Node2D = load("res://scenes/prototypes/thor_rig_pilot.tscn").instantiate()
		var old: Node2D = load("res://scripts/presentation/thor_puppet.gd").new()
		root.add_child(pilot); root.add_child(old)
		if mode=="swing": room.update({},1.2)
		for i in (121 if mode=="idle" else 97):
			var snapshot: Dictionary = room.snapshot()
			if mode=="idle":
				snapshot.elapsed=i*0.02
			capture(old,"baseline",mode,snapshot)
			capture(pilot,"pilot",mode,snapshot)
			if mode=="swing": room.update({},0.02)
		pilot.free(); old.free()
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(OUTPUT),FileAccess.WRITE)
	file.store_string(JSON.stringify(frames))
	print("Exported ",frames.size()," baseline/pilot transforms; offline composites only")
	quit()
