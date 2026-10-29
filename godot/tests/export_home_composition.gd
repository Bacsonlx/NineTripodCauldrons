# Export real Control geometry for offline visual review, without opening a window.
extends SceneTree

var parts: Array = []

func _initialize() -> void:
	export_home.call_deferred()

func find_button(node: Node,caption: String) -> Button:
	if node is Button and node.text.begins_with(caption): return node
	for child in node.get_children():
		var result: Button = find_button(child,caption)
		if result!=null: return result
	return null

func collect(node: Node) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Control:
		var rect: Rect2 = node.get_global_rect()
		var item: Dictionary = {"kind":node.get_class(),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}
		if node is PanelContainer or node is Button:
			var style: StyleBox = node.get_theme_stylebox("panel" if node is PanelContainer else "pressed" if node.button_pressed else "normal")
			if style is StyleBoxFlat: item.background=style.bg_color.to_html(); item.border=style.border_color.to_html()
		if node is ColorRect: item.background=node.color.to_html(); item.border=node.color.to_html()
		if node is TextureRect and node.texture!=null:
			item.image=node.texture.resource_path; item.stretch=node.stretch_mode
		if node is Label or node is Button:
			item.text=node.text
			item.fontSize=node.get_theme_font_size("font_size")
			item.color=node.get_theme_color("font_color").to_html()
			item.alignment=node.horizontal_alignment if node is Label else node.alignment
			item.centered=node is Button or node.vertical_alignment==VERTICAL_ALIGNMENT_CENTER
		parts.append(item)
	for child in node.get_children(): collect(child)

func export_home() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var home: Control = load("res://scenes/home.tscn").instantiate()
	var viewport_size: Vector2i = Vector2i(1920,1080)
	if arguments.size()>3:
		viewport_size=Vector2i(int(arguments[2]),int(arguments[3]))
	root.size=viewport_size
	root.add_child(home); current_scene=home
	await process_frame
	await process_frame
	if arguments.size()>1 and arguments[1]=="quick":
		var quick: Button = find_button(home,"自选起点")
		if quick!=null: quick.pressed.emit()
		await process_frame
		await process_frame
	collect(home)
	var file: FileAccess = FileAccess.open(arguments[0],FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[viewport_size.x,viewport_size.y],"contentSize":[home.size.x,home.size.y],"source":"Godot headless Control geometry; offline composition, not GPU screenshot","parts":parts},"  ")+"\n")
	home.free(); current_scene=null
	print("Exported home Control geometry")
	quit()
