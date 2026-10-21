# Native rendering acceptance through public rule snapshots and visible UI output.
extends Node
const Room = preload("res://scripts/combat/training_room.gd")
const Controls = preload("res://scripts/input/player_controls.gd")
var failures: Array[String] = []
var results: Array[Dictionary] = []
var host: Node2D
var output: String
func _ready() -> void:
	host=get_parent(); output=OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--native-suite")+1]
	if DisplayServer.get_name()=="headless": push_error("Native suite requires a real window / GPU"); get_tree().quit(1); return
	run.call_deferred()
func check(condition: bool,id: String,description: String) -> void:
	results.append({"id":id,"description":description,"passed":condition})
	if not condition: failures.append(id+": "+description)
func visible_numbers(view: Node2D) -> Array:
	var values: Array = []
	for label in view.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and label.text.is_valid_int():
			var position: Vector2 = label.get_global_transform_with_canvas().origin
			values.append({"text":label.text,"x":position.x,"y":position.y,"alpha":label.modulate.a})
	return values
func fixture(layout: Dictionary) -> Node2D:
	var view: Node2D = load("res://scenes/sample.tscn").instantiate()
	view.room=Room.new(layout); view.controls=Controls.new(view.room)
	get_tree().root.add_child(view); view.set_physics_process(false); view.camera.make_current()
	return view
func run() -> void:
	host.set_physics_process(false); host.visible=false
	var window: Window = get_window()
	var layout: Dictionary = host.room.layout.duplicate(true)
	layout.spawn={"x":900,"y":820}
	var view: Node2D = fixture(layout)
	window.mode=Window.MODE_WINDOWED; window.size=Vector2i(1280,720)
	await get_tree().process_frame
	view.update_camera(); await get_tree().process_frame
	var screen_point: Vector2 = Vector2(100,200)
	var before: Vector2 = view.get_viewport().get_canvas_transform().affine_inverse()*screen_point
	view.controls.key_down(KEY_D); view.controls.update(Vector2(1000,768),true,0.5); view.controls.key_up(KEY_D)
	view.update_camera(); await get_tree().process_frame
	var after: Vector2 = view.get_viewport().get_canvas_transform().affine_inverse()*screen_point
	check(absf(after.x-before.x-110)<0.01 and absf(after.y-before.y)<0.01,"B001","原生相机移动后固定屏幕指针重新映射110世界单位")
	view.queue_free(); await get_tree().process_frame
	layout.spawn={"x":2300,"y":870}; view=fixture(layout)
	window.mode=Window.MODE_WINDOWED; window.size=Vector2i(2560,1080)
	await get_tree().process_frame
	view.update_camera(); await get_tree().process_frame
	var transform: Transform2D = view.get_viewport().get_canvas_transform()
	var visible: Vector2 = view.get_viewport_rect().size
	var right: Vector2 = transform.affine_inverse()*Vector2(visible.x,visible.y/2)
	check(absf(right.x-2560)<0.1 and absf(transform.x.length()-transform.y.length())<0.0001,"B002","原生超宽窗口保持比例，相机右边界不越过地图")
	window.size=Vector2i(4000,450)
	await get_tree().process_frame
	view.update_camera(); await get_tree().process_frame
	transform=view.get_viewport().get_canvas_transform(); visible=view.get_viewport_rect().size
	var left: Vector2 = transform.affine_inverse()*Vector2.ZERO
	right=transform.affine_inverse()*Vector2(visible.x,visible.y/2)
	check(absf(left.x)<0.1 and absf(right.x-2560)<0.1,"B002","极宽原生窗口受世界宽度约束，完整显示横向世界且不拉伸")
	view.queue_free(); await get_tree().process_frame
	layout=host.room.layout.duplicate(true); layout.spawn={"x":1080,"y":730}
	view=fixture(layout); await get_tree().process_frame
	var branch_text: String = ""
	for label in view.find_children("*","Label",true,false):
		if label.is_visible_in_tree(): branch_text+=label.text+"\n"
	check(branch_text.contains("碑林幽径"),"B043","通路重叠时原生HUD优先显示支路区域")
	view.queue_free(); await get_tree().process_frame
	layout=Room.new().layout.duplicate(true)
	layout.spawn=Vector2(400,600); layout.obstacles=[]; layout.encounters=[{"x":400,"y":600,"enemies":[{"x":455,"y":600}]}]
	view=fixture(layout); window.mode=Window.MODE_WINDOWED; window.size=Vector2i(1920,1080)
	await get_tree().process_frame
	view.room.update({"aim":Vector2(1000,549),"fire":true},0.01)
	view.room.update({"aim":Vector2(1000,549)},0.12)
	var hit: Dictionary = view.room.snapshot(); view.present(hit,0)
	await get_tree().process_frame
	var first: Array = visible_numbers(view)
	view.room.update({"aim":Vector2(1000,549)},0.03); view.present(view.room.snapshot(),0.03)
	await get_tree().process_frame
	check(first.size()==1 and visible_numbers(view).size()==1 and absf(visible_numbers(view)[0].x-first[0].x)<0.1,"B016","飘字使用命中记录位置，不跟随目标受击后的位移")
	view.present(hit,0.1); view.present(hit,0.1)
	await get_tree().process_frame
	check(first.size()==1 and visible_numbers(view).size()==1,"B016","同一命中快照不重复生成原生伤害数字")
	view.room.set_paused(true); var paused: Dictionary = view.room.snapshot()
	var frozen: Array = visible_numbers(view)
	view.present(paused,1); await get_tree().process_frame
	check(visible_numbers(view)==frozen,"B018","原生反馈在暂停中冻结位置、透明度和寿命；失败使用同一冻结条件")
	view.room.set_paused(false); view.present(hit,0.6)
	await get_tree().process_frame
	check(visible_numbers(view).is_empty(),"B016","反复读取旧事件不会在反馈寿命结束后重播")
	view.room.reset(); view.room.update({},0)
	view.room.update({"aim":Vector2(1000,549),"fire":true},0.01); view.room.update({"aim":Vector2(1000,549)},0.12)
	view.present(view.room.snapshot(),0); await get_tree().process_frame
	check(visible_numbers(view).size()==1,"B017","重试清空旧反馈后，低序号新命中可以再次播放")
	frozen=visible_numbers(view)
	view.room.update({"aim":Vector2(1000,549)},12)
	view.present(view.room.snapshot(),1); await get_tree().process_frame
	check(view.room.snapshot().status=="failed" and visible_numbers(view)==frozen,"B018","正常近战造成失败后，原生反馈不继续消耗寿命")
	view.queue_free(); await get_tree().process_frame
	layout.encounters[0].enemies=[]
	for index in 33: layout.encounters[0].enemies.append({"x":600+index%3,"y":600+index%3})
	view=fixture(layout); await get_tree().process_frame
	view.room.update({"aim":Vector2(600,600),"rain":true},0)
	var peak: int = 0
	for frame in 90:
		view.room.update({"aim":Vector2(600,600)},0.01); view.present(view.room.snapshot(),0.01)
		await get_tree().process_frame
		peak=maxi(peak,visible_numbers(view).size())
	check(peak==32,"B019","33个受伤目标的原生飘字最多使用32个可见槽")
	view.room.update({"aim":Vector2(1000,549)},0.7); view.present(view.room.snapshot(),0.7)
	await get_tree().process_frame
	view.room.update({"aim":Vector2(1000,549),"fire":true},0.25); view.present(view.room.snapshot(),0)
	await get_tree().process_frame
	check(not visible_numbers(view).is_empty() and visible_numbers(view).size()<=32,"B019","反馈结束后槽位仍可复用，不丢弃新命中")
	view.queue_free(); await get_tree().process_frame
	host.visible=true; host.camera.make_current(); host.update_camera()
	var text: String = ""
	for label in host.find_children("*","Label",true,false):
		if label.is_visible_in_tree(): text+=label.text+"\n"
	check(text.contains("扶桑残径") and text.contains("扶桑石庭"),"B043","原生HUD从实际通路和遭遇显示当前区域与下一地标")
	var final_state: Dictionary = host.room.snapshot()
	# 完成状态来自公开规则输入：三组同位遭遇通过正常连射依次完成。
	var completion: Dictionary = Room.new().layout.duplicate(true)
	completion.obstacles=[]; completion.encounters=[]
	for group in 3: completion.encounters.append({"x":400,"y":600,"enemies":[{"x":620,"y":600}]})
	var runner: TrainingRoom = Room.new(completion)
	runner.update({"aim":Vector2(1000,549),"fire":true},5.8)
	host.present(runner.snapshot(),0)
	text=""
	for label in host.find_children("*","Label",true,false):
		if label.is_visible_in_tree(): text+=label.text+"\n"
	check(runner.snapshot().status=="complete" and text.contains("主路已肃清") and text.contains("可回头探索"),"B044","完成后原生地标提示使用完成状态并允许继续探索")
	host.present(final_state,0)
	var route_ok: bool = true
	for index in range(1,host.room.layout.mainRoute.size()):
		var a: Vector2 = Room.point(host.room.layout.mainRoute[index-1]); var b: Vector2 = Room.point(host.room.layout.mainRoute[index])
		for step in 21:
			var position: Vector2 = a.lerp(b,step/20.0)
			var inside: bool = false
			for area in host.room.layout.walkableAreas:
				if position.x>=area.left and position.x<=area.right and position.y>=area.top and position.y<=area.bottom: inside=true
			if not inside: route_ok=false
	check(route_ok,"B045","原生场景铺路折线的所有分段由实际通路覆盖，地图与参照已逐项一致")
	host.set_physics_process(true)
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"checks":results,"failures":failures,"passed":failures.is_empty(),"scope":"原生GPU中的公开规则状态→相机与可见UI输出；不代替真实键鼠、用户编辑器调整和最终双平台实测"},"  ")+"\n")
