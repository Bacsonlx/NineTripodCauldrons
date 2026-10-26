extends Node

const PlayOptions = preload("res://scripts/input/play_options.gd")

func _ready() -> void:
	var arguments: Array = Array(OS.get_cmdline_user_args())
	var options: Dictionary = PlayOptions.parse(arguments)
	if options.has("error"):
		push_error(options.error); get_tree().quit(2); return
	# 显式专项、初始条件与既有诊断参数继续直达旧首关入口。
	var target: String = "res://scenes/home.tscn" if arguments.is_empty() else "res://scenes/tanggu_first_level.tscn"
	get_tree().change_scene_to_file.bind(target).call_deferred()
