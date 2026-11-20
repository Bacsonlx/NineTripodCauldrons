extends RefCounted
## 挂件端到端检查：真实背包数据 -> 外观描述 -> 挂件上身 -> 过渡 -> 移除。

const AlphaState = preload("res://scripts/alpha/alpha_state.gd")
const GearRig = preload("res://scripts/presentation/gear_rig.gd")

func run(check: Callable) -> void:
	# 真实背包：把训练弓与布履放进装备区。
	var alpha: RefCounted = AlphaState.new()
	alpha.items.clear()
	alpha.add_item("训练弓","equipment",Vector2i(0,0))
	alpha.add_item("布履","equipment",Vector2i(3,0))
	var appearance: Dictionary = alpha.snapshot().get("appearance",{})
	check.call(appearance.get("slots",{}).has("weapon"), "真实背包里的训练弓进入武器槽位")
	check.call(appearance.get("slots",{}).has("feet"), "真实背包里的布履进入鞋履槽位")
	# 挂件层：应用外观后应生成对应槽位的精灵。
	var rig: Node2D = GearRig.new()
	rig.set_context("hero-archery-upper",false,0.172,Vector2(272,409))
	rig.set_appearance(appearance)
	rig.update(0.5)
	check.call(rig.slots.has("weapon") and rig.slots.has("feet"), "挂件层按槽位生成精灵")
	check.call(rig.slots.size()==2, "只生成有装备的槽位，不多生成")
	# 淡入完成后不透明度应为 1。
	for slot in rig.slots.keys():
		var node: Sprite2D = rig.slots[slot]
		if node!=null: check.call(is_equal_approx(node.modulate.a,1.0), "挂件淡入完成")
	# 同一签名重复应用不触发过渡（幂等）。
	var count_before: int = rig.slots.size()
	rig.set_appearance(appearance)
	rig.update(0.1)
	check.call(rig.slots.size()==count_before, "相同签名重复下发不新增挂件")
	rig.set_context("shadow-attack-upper",false,0.75,Vector2(12,40),1,{"head":[[16,24],[28,32]]})
	check.call(rig.anchor_point("head").is_equal_approx(Vector2(12,-6)),"挂件使用当前帧的语义挂点，不固定读取第一帧")
	rig.integrated_slots.assign(["weapon","feet"])
	rig.update(0)
	check.call(not rig.slots.weapon.visible and not rig.slots.feet.visible,"新身体已联绘的武器和鞋不再重复显示")
	# 移除装备后挂件应淡出消失。
	alpha.items.clear()
	var cleared: Dictionary = alpha.snapshot().get("appearance",{})
	rig.set_appearance(cleared)
	rig.update(0.5)
	check.call(rig.slots.is_empty(), "装备移除后挂件淡出清除")
	rig.free()
