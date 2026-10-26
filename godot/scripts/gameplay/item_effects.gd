extends RefCounted

var haste: float = 0.0
var morning_uses: int = 0
var puddle: Dictionary = {}
var tomb: Dictionary = {}
var random: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_value: int) -> void:
	random.seed=seed_value

func use(item: Dictionary, room: RefCounted) -> bool:
	match item.name:
		"快马":
			if haste>0: room.alpha.message="快马尚在生效，不叠加、不刷新"; return false
			haste=3.0
		"司晨":
			if morning_uses>=3: room.alpha.message="司晨本局最多三次"; return false
			var affected: bool = false
			for enemy in room.enemies:
				if enemy.get("boss",false) or enemy.phase in ["inactive","dead"]: continue
				enemy.phase="chase"; enemy.timer=0; enemy.struck=false; enemy.route=[]; enemy.repath=0; enemy.stopped=1.0; affected=true
			if not affected: room.alpha.message="没有可受司晨影响的普通敌，首领免疫"; return false
			morning_uses+=1
		"豕涉":
			var target: Vector2 = room.item_aim
			if room.point(room.player).distance_to(target)>240 or not room.rain_target_valid(target): room.alpha.message="水洼需在240内合法地面"; return false
			puddle={"point":target,"remaining":6.0,"roomId":room.layout.get("roomId","")}
		"守冢":
			var origin: Vector2 = room.point(room.player)
			var found: bool = false
			for distance in range(36,241,4):
				var target: Vector2 = origin+Vector2.from_angle(room.player.angle)*distance
				if room.can_walk(target) and room.clear_path(origin,target):
					tomb={"point":target,"health":80,"remaining":8.0,"roomId":room.layout.get("roomId","")}; found=true; break
			if not found: room.alpha.message="前方没有合法墓碑落点"; return false
		_: return false
	room.alpha.message="已使用 "+item.name
	return true

func active(room: RefCounted, effect: Dictionary) -> bool:
	return not effect.is_empty() and effect.roomId==room.layout.get("roomId","")

func enemy_speed(room: RefCounted, enemy: Dictionary) -> float:
	return 0.6 if active(room,puddle) and room.point(enemy).distance_to(puddle.point)<=90 else 1.0

func target(room: RefCounted, enemy: Dictionary) -> Dictionary:
	if active(room,tomb) and room.point(enemy).distance_to(tomb.point)<=240:
		return {"x":tomb.point.x,"y":tomb.point.y,"tomb":true}
	return room.player

func hit_tomb(amount: int) -> void:
	if tomb.is_empty(): return
	tomb.health=maxi(0,tomb.health-amount)
	if tomb.health==0: tomb={}

func movement_multiplier(room: RefCounted) -> float:
	return (1.4 if haste>0 else 1.0)*(0.9 if room.alpha.active_pact("涂炭") else 1.0)

func advance(room: RefCounted, seconds: float) -> void:
	haste=maxf(0,haste-seconds)
	for effect in [puddle,tomb]:
		if not effect.is_empty(): effect.remaining=maxf(0,effect.remaining-seconds)
	if not puddle.is_empty() and puddle.remaining<=0: puddle={}
	if not tomb.is_empty() and tomb.remaining<=0: tomb={}
	room.refresh_item_stats()
	room.alpha.advance_pacts(room,seconds)
	for enemy in room.enemies:
		if enemy.phase in ["inactive","dead"] or enemy.get("burnRemaining",0.0)<=0: continue
		var elapsed: float = minf(seconds,enemy.burnRemaining)
		enemy.burnRemaining=maxf(0,enemy.burnRemaining-seconds)
		enemy.burnTick=enemy.get("burnTick",0.0)+elapsed
		while enemy.burnTick>=1.0-0.000001 and enemy.phase!="dead":
			enemy.burnTick=maxf(0,enemy.burnTick-1.0)
			room.impact({"x":enemy.x,"y":enemy.y-35,"target":null,"enemy":enemy.id},"burn",0)


func snapshot(room: RefCounted) -> Dictionary:
	return {"haste":haste,"morningUses":morning_uses,"puddle":puddle.duplicate(true) if active(room,puddle) else {},"tomb":tomb.duplicate(true) if active(room,tomb) else {},"movementMultiplier":movement_multiplier(room),"attackMultiplier":room.alpha.attack_bonus(),"criticalChance":0.16 if room.alpha.applied_equipment.effects.has("虎牙") else 0.10}

func clear() -> void:
	haste=0; puddle={}; tomb={}

func attack(room: RefCounted, kind: String) -> Dictionary:
	var glyphs: Array = room.alpha.applied_equipment.effects
	var chance: float = 0.16 if glyphs.has("虎牙") else 0.10
	var critical: bool = kind in ["normal","pierce"] and random.randf()<chance
	return {"critical":critical,"criticalMultiplier":1.5 if critical else 1.0,"pactMultiplier":room.alpha.attack_bonus(),"applyBurn":kind in ["normal","pierce"] and glyphs.has("燧火")}
