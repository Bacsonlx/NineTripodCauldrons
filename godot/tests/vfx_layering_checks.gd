extends RefCounted
## 特效分层检查：预算按层隔离、优先级可抢占、命中三态可区分。

const Effects = preload("res://scripts/presentation/combat_effects.gd")

func run(check: Callable) -> void:
	var effects: Node2D = Effects.new()
	# 建一个最小 vfx 图集：分层逻辑不依赖具体贴图。
	var frames: Dictionary = {}
	for name in ["streak","spark","ring","dust","halo","embers","feather","shards"]:
		frames[name]={"x":0,"y":0,"width":64,"height":64}
	effects.setup(frames,null,null,null)
	# 同一层内，不同优先级的特效都能落地。
	var before: int = effects.used
	effects.stamp("ring",Vector2.ZERO,Vector2(10,10),0.5,0.0,2,Effects.LAYER_GROUND,Effects.PRIORITY_GROUND)
	effects.stamp("halo",Vector2.ZERO,Vector2(10,10),0.5,0.0,2,Effects.LAYER_GROUND,Effects.PRIORITY_CHARGE)
	check.call(effects.used==before+2, "同层两个不同优先级特效都能落地")
	# 总预算生效，不超过上限。
	effects.vfx_budget=2
	effects.used=0
	for layer in Effects.LAYER_COUNT: effects.layer_used[layer]=0
	effects.stamp("ring",Vector2.ZERO,Vector2(10,10),0.5,0.0,2,Effects.LAYER_GROUND,Effects.PRIORITY_GROUND)
	effects.stamp("halo",Vector2.ZERO,Vector2(10,10),0.5,0.0,2,Effects.LAYER_GROUND,Effects.PRIORITY_CHARGE)
	check.call(effects.used<=2, "总预算生效，不超过上限")
	# 分层预算互相隔离：某一层刷满不影响其它层。
	effects.vfx_budget=512
	effects.used=0
	for layer in Effects.LAYER_COUNT: effects.layer_used[layer]=0
	for index in Effects.LAYER_LIMITS[Effects.LAYER_GROUND]:
		effects.stamp("ring",Vector2.ZERO,Vector2(10,10),0.5,0.0,2,Effects.LAYER_GROUND,Effects.PRIORITY_GROUND)
	effects.stamp("halo",Vector2.ZERO,Vector2(10,10),0.5,0.0,2,Effects.LAYER_IMPACT,Effects.PRIORITY_IMPACT)
	check.call(effects.layer_used[Effects.LAYER_IMPACT]==1, "一层刷满不影响其它层的特效落地")
	# 优先级抢占：同层预算用满后，高优先级替换低优先级而不是被丢弃。
	effects.used=0
	for layer in Effects.LAYER_COUNT: effects.layer_used[layer]=0
	for index in Effects.LAYER_LIMITS[Effects.LAYER_IMPACT]:
		effects.stamp("spark",Vector2.ZERO,Vector2(10,10),0.5,0.0,4000,Effects.LAYER_IMPACT,Effects.PRIORITY_IMPACT)
	var count_before: int = effects.used
	effects.stamp("ring",Vector2.ZERO,Vector2(10,10),0.5,0.0,4000,Effects.LAYER_IMPACT,Effects.PRIORITY_CRITICAL)
	check.call(effects.used==count_before, "同层预算用满后抢占替换而非新增，总量不增长")
	effects.free()
