extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var hud: Control = load("res://scripts/presentation/combat_hud.gd").new()
	root.add_child(hud)
	await process_frame
	check(hud.has_method("set_inscription"),"阅读面板可按当前房间呈现独立碑文")
	if hud.has_method("set_inscription"):
		hud.set_inscription("残碑幽径 · 根下余字","一段环境线索。\n\n一段已有记忆。")
		var label: Label = hud.reading.get_child(0)
		check(label.text.contains("根下余字") and label.text.contains("一段已有记忆。") and label.text.contains("F / Esc"),"旁支阅读显示本房标题正文并保留关闭提示")
		hud.set_inscription("","")
		check(label.text.contains("风过残碑") and not label.text.contains("根下余字"),"返回主线碑林恢复既有正式碑文，不残留旁支文本")
	hud.free()
	print(JSON.stringify({"expanded_reading_checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
