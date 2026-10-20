extends RefCounted

const Room = preload("res://scripts/combat/training_room.gd")

func run(check: Callable) -> void:
	var room: TrainingRoom = Room.new({"mode":"alpha"})
	check.call(room.snapshot().get("alpha",{}).get("camp",false), "初版从安全营地开始并公开构筑状态")

	var drop: Dictionary = room.snapshot().alpha.items.back()
	room.update({"alpha":{"action":"pickup","id":drop.id}},0)
	var picked: Dictionary = room.snapshot().alpha.items.back()
	check.call(picked.region=="warehouse" and picked.rotated, "两格实物在一行仓库自动旋转入仓，实例不复制")
	room.update({"alpha":{"action":"place","id":drop.id,"cell":Vector2i(6,0),"rotated":false}},0)
	check.call(room.snapshot().alpha.items.back().cell==Vector2i(6,0), "营地可把实物旋转放入祭坛")
	room.update({"alpha":{"action":"place","id":drop.id,"cell":Vector2i(9,3)}},0)
	check.call(room.snapshot().alpha.items.back().cell==Vector2i(6,0) and room.snapshot().alpha.message.contains("跨区"), "跨区拒绝后保留原物与原位置")
	room.update({"alpha":{"action":"place","id":drop.id,"cell":Vector2i(0,0)}},0)
	check.call(room.snapshot().alpha.message.contains("占用"), "与训练弓重叠被拒绝并给出原因")
	room.update({"moveX":1,"fire":true},3)
	check.call(room.snapshot().player.x==400 and room.snapshot().alpha.elapsed==0 and room.snapshot().shots==0, "营地冻结规则时间、移动和攻击")
	room.update({"alpha":{"action":"depart"}},0)
	room.update({"moveX":1},0.1)
	check.call(is_equal_approx(room.snapshot().player.x,422) and room.snapshot().alpha.elapsed>0, "出发后沿用后羿每秒220的既有移动")
	var blocked: TrainingRoom = Room.new({"mode":"alpha","obstacle":Rect2(425,580,10,40)})
	blocked.update({"alpha":{"action":"pickup","id":blocked.snapshot().alpha.items.back().id}},0)
	check.call(blocked.snapshot().alpha.items.back().region=="ground" and blocked.snapshot().alpha.message.contains("遮挡"), "80半径内隔墙实物仍留地")
