extends SceneTree
## 用 Godot 自己修补 training_scene.gd 的腰线逻辑。
##
## 环境里的字符串编辑工具会吞掉字符，所以用引擎直接做精确替换。
## 旧素材的腰线用实测常量，新素材用各自的实测腰线，两者统一按
## 「腰带在父节点坐标系里的 y」比较。

const TARGET := "res://scripts/presentation/training_scene.gd"

func _init() -> void:
	var source: String = FileAccess.get_file_as_string(TARGET)
	var original: String = source

	# 1) 旧素材腰线常量：实测值（相对 originY，向下为正）。
	source = source.replace(
		"const LEGACY_LOWER_WAIST: float = 6.0\nconst LEGACY_UPPER_WAIST: float = 333.0",
		"const LEGACY_LOWER_WAIST: float = -147.0\nconst LEGACY_UPPER_WAIST: float = 14.0")

	# 2) pose() 里写入旧素材腰线锚点。
	source = source.replace(
		"\tnode.position = point\n\nfunc waist_point",
		"\tnode.position = point\n\t# 旧素材没有实测腰线，用固定腰高换算，与新素材走同一套对齐路径。\n\t# waist_px 相对 originY（脚点）：旧 lower 为负，表示腰线在脚点上方。\n\tvar waist_px: float = LEGACY_LOWER_WAIST if key==\"lower\" else LEGACY_UPPER_WAIST\n\tnode.set_meta(\"waist_anchor\",point.y+waist_px*node.scale.y)\n\nfunc waist_point")

	# 3) 去掉旧的重复常量声明块。
	source = source.replace(
		"# 旧素材的腰线高度（源图像素，向下为正）：lower 的脚点 originY 到腰线，\n# upper 的 originY 到躯干底端。新素材用各自的实测腰线，旧素材用这两个常量。\n",
		"# 旧素材的腰线偏移（源图像素，相对 originY；originY 是脚点）。\n# 旧 lower 的腰线在脚点上方，旧 upper 的腰线在脚点下方。\n")

	if source==original:
		print("NO CHANGE - patterns did not match")
		quit(1)
		return
	FileAccess.open(TARGET,FileAccess.WRITE).store_string(source)
	print("patched training_scene.gd")
	quit(0)
