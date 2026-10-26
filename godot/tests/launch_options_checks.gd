extends RefCounted

func run(check: Callable) -> void:
	var parser: Script = load("res://scripts/input/play_options.gd")
	check.call(parser!=null,"快捷启动参数解析器可加载")
	if parser==null: return
	var normal: Dictionary = parser.parse([])
	check.call(normal.startRoom=="entry" and normal.potionDrops and normal.health==100 and normal.mana==100,"无参数是含药瓶的正常首关")
	var boss: Dictionary = parser.parse(["--test=boss","--health=40","--mana=0","--stamina=0","--seed=13"])
	check.call(boss.startRoom=="boss" and boss.health==40 and boss.mana==0 and boss.stamina==0 and boss.dropSeed==13,"Boss专项支持低资源和固定种子")
	check.call(parser.parse(["--test=drops"]).startRoom=="court1","掉落专项从实际第一战斗庭开始")
	check.call(parser.parse(["--test=drops","--room=court2"]).startRoom=="court2","掉落专项可切换其他实际房间")
	check.call(parser.parse(["--test=alpha"]).mode=="alpha","背包白盒只作为专项内容选择")
	check.call(not parser.parse(["--layout-audit","/tmp/layout.json"]).has("error"),"保留现有布局读取诊断参数")
	check.call(not parser.parse(["--native-suite","/tmp/suite.json"]).has("error"),"保留现有原生诊断参数")
	check.call(parser.parse(["--quality=auto"]).quality=="auto","画质档位作为独立启动参数传入")
	check.call(parser.parse(["--test=alpha","--quality=low"]).mode=="alpha","画质档位不扩大背包白盒的玩法参数范围")
	check.call(parser.parse(["--quality=ultra"]).has("error"),"未知画质档位明确拒绝")
	for arguments in [["--man=0"],["--mana"],["unexpected"],["--layout-audit"],["--native-probe","--test=boss"]]:
		check.call(parser.parse(arguments).has("error"),"未知或缺值原生参数明确拒绝："+str(arguments))
	for arguments in [["--test=missing"],["--room=missing"],["--health=0"],["--health=101"],["--mana=-1"],["--seed=oops"],["--seed=-1"],["--test=boss","--room=court2"],["--test=alpha","--mana=0"]]:
		check.call(parser.parse(arguments).has("error"),"非法启动条件明确拒绝："+str(arguments))
	var journey: Script = load("res://scripts/journey/room_journey.gd")
	var run: RefCounted = journey.new(journey.read_maps(),boss)
	check.call(run.snapshot().roomId=="boss" and run.snapshot().health==40 and run.snapshot().resources.mana==0 and run.snapshot().resources.stamina==0,"启动条件进入实际Boss房并应用低资源")
	run.update({"restart":true},0)
	check.call(run.snapshot().roomId=="boss" and run.snapshot().health==40 and run.snapshot().resources.mana==0,"专项R从相同房间与初始条件重试")
