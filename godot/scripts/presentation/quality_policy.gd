extends RefCounted

# 低配机器的性能自适应策略：只调整非玩法关键的特效叠加数量。
# 不改变碰撞、伤害、冷却、输入或规则时间；默认 high 与已批准画面一致。
# auto 需显式 --quality=auto 开启，避免在未获用户确认时改动正式表现。
const TIERS: Array[Dictionary] = [
	{"name":"high","vfxBudget":512},
	{"name":"medium","vfxBudget":256},
	{"name":"low","vfxBudget":96},
]
const SLOW_SECONDS: float = 0.022   # 低于约 45 FPS 时累计降档
const FAST_SECONDS: float = 0.0172  # 高于约 58 FPS 时累计升档
const SLOW_SAMPLES: int = 90
const FAST_SAMPLES: int = 240

var mode: String = "high"
var tier: int = 0
var frame: int = 0
var slow_frames: int = 0
var fast_frames: int = 0
var last_frame_ms: float = 0.0

func configure(arguments: Array) -> void:
	for argument in arguments:
		var text: String = str(argument)
		if not text.begins_with("--quality="): continue
		var value: String = text.trim_prefix("--quality=")
		if value=="auto":
			mode="auto"; tier=0
		elif value in ["high","medium","low"]:
			mode=value; tier=["high","medium","low"].find(value)
	return

func begin_frame(frame_seconds: float) -> void:
	frame+=1
	last_frame_ms=frame_seconds*1000.0
	if mode!="auto" or frame_seconds<=0.0: return
	if frame_seconds>SLOW_SECONDS:
		slow_frames+=1; fast_frames=0
	elif frame_seconds<FAST_SECONDS:
		fast_frames+=1; slow_frames=0
	else:
		slow_frames=0; fast_frames=0
	if slow_frames>=SLOW_SAMPLES and tier<TIERS.size()-1:
		tier+=1; slow_frames=0; fast_frames=0
	elif fast_frames>=FAST_SAMPLES and tier>0:
		tier-=1; slow_frames=0; fast_frames=0

func vfx_budget() -> int:
	return int(TIERS[tier].vfxBudget)
func tier_name() -> String:
	return str(TIERS[tier].name)
func report() -> Dictionary:
	return {"mode":mode,"tier":tier_name(),"vfxBudget":vfx_budget(),"frames":frame,"lastFrameMs":last_frame_ms}
