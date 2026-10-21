extends SceneTree

func _initialize() -> void:
	var image: Image = Image.load_from_file("res://assets/world/terrain.png")
	var side: int = image.get_width()/2
	var names: Array[String] = ["forest","path","stone","water"]
	for index in 4:
		var tile: Image = image.get_region(Rect2i((index%2)*side,(index/2)*side,side,side))
		if tile.save_png("res://assets/world/"+names[index]+".png")!=OK: quit(1); return
	print("Four material atlas regions extracted losslessly; no resampling")
	quit()
