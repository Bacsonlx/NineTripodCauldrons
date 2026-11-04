extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("首页背包检查超时"); quit(1))
	run.call_deferred()

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found: Button=find_button(child,prefix)
		if found!=null: return found
	return null

func visible_text(node: Node) -> String:
	var result: String=node.text if node is Label or node is Button else ""
	for child in node.get_children():
		if child is Control and child.visible: result+="\n"+visible_text(child)
	return result

func run() -> void:
	var home: Control=load("res://scenes/home.tscn").instantiate()
	root.add_child(home); current_scene=home
	await process_frame
	await process_frame

	check(find_button(home,"完整征程")!=null and find_button(home,"自选起点")!=null,"首页提供正式征程与自选起点入口")
	var text_value: String=visible_text(home)
	for forbidden in ["仓库","试装","原型","快速测试","未接入","不带入战斗"]:
		check(not text_value.contains(forbidden),"正式首页不显示开发态词汇："+forbidden)
	var prepared: RefCounted=home.get("prepared_alpha")
	check(prepared!=null and prepared.items.size()==6,"首页使用六件真实起始物品")
	check(home.get("backpack_cells").size()==50,"首页背包与局内保持50格空间")
	var names: Array[String]=[]
	for item in prepared.items: names.append(item.name)
	for expected in ["训练弓","布履","青龙","羊角","鼠毫","素食"]:
		check(names.has(expected),"首页起始背包包含真实物品："+expected)
	var bag_button: Button=find_button(home,"整 理 背 包")
	check(bag_button!=null,"首页提供正式背包入口")
	if bag_button!=null: bag_button.pressed.emit()
	await process_frame
	check(home.get_node("Layout/Sections/Bag").visible,"点击首页背包入口打开背包空间")
	check(str(home.get("bag_count").text).contains("6 件"),"首页背包显示真实携带数量")
	var grid: GridContainer=home.get("backpack_grid")
	check(grid!=null and grid.columns==10 and grid.get_child_count()==50,"首页背包绘制装备、祭坛、收纳三段空间")
	var home_rect: Rect2=home.get_global_rect()
	var bag_rect: Rect2=home.get_node("Layout/Sections/Bag").get_global_rect()
	check(home_rect.encloses(bag_rect),"首页背包面板完整收纳在当前窗口内")
	check(home_rect.encloses(grid.get_global_rect()),"首页背包网格不溢出当前窗口")
	var compact_cells: bool=true
	for cell in home.get("backpack_cells"):
		if cell.size.x>64.0 or cell.size.y>64.0:
			compact_cells=false
			break
	check(compact_cells,"首页背包格子保持紧凑尺寸，不被物品贴图原始尺寸撑大")
	var hovered: Button=null
	for cell in home.get("backpack_cells"):
		if str(cell.tooltip_text).contains("素食"): hovered=cell; break
	check(hovered!=null,"首页背包格悬停显示物品名称")
	if hovered!=null:
		check(hovered.tooltip_text.split("\n").size()<=2 and hovered.tooltip_text.length()<80,"首页背包悬停说明压缩为摘要，不铺满屏幕")
	home.call("choose_item","talis_goat")
	home.call("home_grid_cell",Vector2i(6,0))
	var goat: Dictionary={}
	for item in prepared.items:
		if item.name=="羊角": goat=item
	check(goat.get("region","")=="altar" and goat.get("cell",Vector2i(-1,-1))==Vector2i(6,0),"首页摆放结果写入真实背包布局")
	home.call("show_bag_panel",false)
	var start: Button=find_button(home,"踏入汤谷")
	check(start!=null,"首页保留正式出发入口")
	if start!=null: start.pressed.emit()
	await process_frame
	var dialog: Node=home.get_node_or_null("HomeDialog")
	check(dialog!=null and visible_text(dialog).contains("真实物品与空间布局"),"出发确认说明背包会进入本局")
	home.queue_free(); current_scene=null
	await process_frame
	print(JSON.stringify({"home_ui_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
