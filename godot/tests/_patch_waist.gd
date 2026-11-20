extends SceneTree
func _init() -> void:
	var clips_path: String = "res://assets/characters/action-redraw-v1/clips.json"
	var measured_path: String = "res://tools_measured_anchors.json"
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(clips_path))
	var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(measured_path))
	var updated: Array[String] = []
	for name in measured.keys():
		if not clips.has(name): continue
		var entry: Dictionary = clips[name]
		entry["waistLine"] = measured[name]["waist_px"]
		entry.erase("waist_y")
		entry["anchor_kind"] = "waist line measured from alpha bounds"
		updated.append(str(name))
	FileAccess.open(clips_path,FileAccess.WRITE).store_string(JSON.stringify(clips,"  ")+"\n")
	print("updated ",updated.size()," clips")
	quit(0)
