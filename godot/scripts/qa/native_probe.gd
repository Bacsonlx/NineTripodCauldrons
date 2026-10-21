# Run the exported native binary with: -- --native-probe <output.json>
# This drives the public input adapter for repeatable rendering load, not OS keyboard validation.
extends Node
var game: Node2D
var output: String
var phase: String = "waiting_for_focus"
var phase_started: int = 0
var previous_tick: int = 0
var frames: Array[float] = []
var performance: Dictionary = {}
var resets: int = 0
var moving_frames: int = 0
var samples: int = 0
var next_target: int = 0
var route: Array[Vector2] = [Vector2(800,820),Vector2(920,820),Vector2(920,940),Vector2(800,940)]
var finished: bool = false
var last_shots: int = 0
var last_run: int = -1
var shot_buckets: Dictionary = {}
var device: Dictionary = {}
var resources: Array[Dictionary] = []
var last_resource_second: int = -1
func _ready() -> void:
	output=OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--native-probe")+1]
	if DisplayServer.get_name()=="headless":
		push_error("Native acceptance requires an actual window and rendering driver")
		get_tree().quit(1); return
	game=get_parent()
	prepare.call_deferred()
func prepare() -> void:
	get_window().mode=Window.MODE_WINDOWED; get_window().size=Vector2i(1920,1080)
	device={"os":OS.get_name(),"version":OS.get_version(),"processor":OS.get_processor_name(),"memory_bytes":OS.get_memory_info().physical,"display_server":DisplayServer.get_name(),"refresh_hz":DisplayServer.screen_get_refresh_rate(),"screen_scale":DisplayServer.screen_get_scale(),"screen_size":DisplayServer.screen_get_size(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().string,"executable":OS.get_executable_path()}
	write_result("waiting_for_focus")
func start_phase(value: String) -> void:
	phase=value; phase_started=Time.get_ticks_usec(); previous_tick=phase_started; frames.clear(); moving_frames=0; samples=0; shot_buckets.clear()
func _physics_process(_delta: float) -> void:
	if finished or not is_instance_valid(game) or not is_instance_valid(game.controls) or phase=="waiting_for_focus": return
	if not get_window().has_focus(): return
	var state: Dictionary = game.room.snapshot()
	if state.status=="failed": game.controls.key_down(KEY_R); resets+=1
	if state.paused: game.controls.key_down(KEY_ESCAPE)
	var target: Vector2 = route[next_target]
	var position: Vector2 = Vector2(game.room.snapshot().player.x,game.room.snapshot().player.y)
	if position.distance_to(target)<12: next_target=(next_target+1)%route.size(); target=route[next_target]
	for key in [KEY_W,KEY_A,KEY_S,KEY_D]: game.controls.key_up(key)
	var delta: Vector2 = target-position
	if absf(delta.x)>8: game.controls.key_down(KEY_D if delta.x>0 else KEY_A)
	if absf(delta.y)>8: game.controls.key_down(KEY_S if delta.y>0 else KEY_W)
	game.controls.pointer_down(true)
	return
func _process(_delta: float) -> void:
	if finished or device.is_empty(): return
	if phase=="waiting_for_focus":
		if get_window().has_focus(): start_phase("warmup")
		return
	if not get_window().has_focus():
		write_result("invalid_focus_lost"); finished=true; get_tree().quit(1); return
	var now: int = Time.get_ticks_usec()
	var interval: float = (now-previous_tick)/1000000.0
	previous_tick=now
	var elapsed: float = (now-phase_started)/1000000.0
	if phase=="warmup":
		if elapsed>=5: start_phase("performance")
		return
	frames.append(interval); samples+=1
	if floori(elapsed/10)!=last_resource_second:
		last_resource_second=floori(elapsed/10)
		resources.append({"phase":phase,"seconds":elapsed,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	var state: Dictionary = game.room.snapshot()
	if state.runId!=last_run: last_run=state.runId; last_shots=0
	var bucket: int = floori(elapsed)
	shot_buckets[bucket]=shot_buckets.get(bucket,0)+maxi(0,state.shots-last_shots)
	last_shots=state.shots
	if state.player.moving: moving_frames+=1
	if phase=="performance" and elapsed>=60:
		var sorted: Array[float] = frames.duplicate(); sorted.sort()
		var fast: int = 0
		for frame in frames:
			if frame<=0.020: fast+=1
		var active_shooting: bool = true
		for second in 60:
			if shot_buckets.get(second,0)==0: active_shooting=false
		performance={"load_valid":active_shooting and float(moving_frames)/samples>=0.9,"load_rule":"每个完整秒观察到离弦，至少90%采样帧移动；这是跑射场景有效性检查","shot_buckets":shot_buckets,"duration_seconds":elapsed,"frames":frames.size(),"average_fps":frames.size()/elapsed,"fraction_le_20ms":float(fast)/frames.size(),"p95_frame_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.95)-1)]*1000,"moving_frame_fraction":float(moving_frames)/samples,"resets":resets}
		write_frames("performance"); write_result("performance_complete"); start_phase("stability"); last_resource_second=-1
	elif phase=="stability" and elapsed>=300:
		performance.stability_seconds=elapsed; performance.stability_frames=frames.size(); performance.total_resets=resets
		write_frames("stability"); write_result("completed"); finished=true; get_tree().quit()
	return
func write_result(status: String) -> void:
	var viewport_size: Vector2i = get_window().get_texture().get_size()
	var result: Dictionary = {"status":status,"device":device,"window_size":{"width":get_window().size.x,"height":get_window().size.y},"viewport_texture_size":{"width":viewport_size.x,"height":viewport_size.y},"focused":get_window().has_focus(),"scenario":"完整汤谷原生渲染；公开输入适配层驱动第一庭院跑射、正常死亡后R重试；不代替原生键鼠操作验证","performance":performance,"resource_trend":resources,"passed":status=="completed" and viewport_size==Vector2i(1920,1080) and performance.get("load_valid",false) and performance.get("average_fps",0)>=58 and performance.get("fraction_le_20ms",0)>=0.95}
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")+"\n")

func write_frames(label: String) -> void:
	var file: FileAccess = FileAccess.open(output+"."+label+".frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase":label,"unit":"seconds","intervals":frames})+"\n")
