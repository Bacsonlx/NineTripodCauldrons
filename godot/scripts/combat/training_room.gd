class_name TrainingRoom
extends RefCounted

const WORLD_SIZE: Vector2 = Vector2(1280, 900)
const GRIPS: Array[Vector2] = [Vector2(27, -51), Vector2(24, -48), Vector2(-21, -48), Vector2(-22, -53)]
const SKILL_GRIPS: Dictionary = {
	"pierce": [Vector2(31,-44), Vector2(17,-43), Vector2(-28,-45), Vector2(-24,-48)],
	"rain": [Vector2(14,-68), Vector2(21,-70), Vector2(-21,-67), Vector2(-20,-68)],
	"dodge": [Vector2(16,-39), Vector2(-3,-39), Vector2(-13,-37), Vector2(-8,-45)]
}
const ATTACKS: Dictionary = {"normal":{"damage":15,"distance":14,"duration":0.10}, "pierce":{"damage":40,"distance":36,"duration":0.14}, "rain":{"damage":15,"distance":8,"duration":0.08}}
var layout: Dictionary = {}
var obstacle: Rect2 = Rect2(720,430,80,36)
var player: Dictionary = {}
var arrows: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var flashes: Array[float] = []
var shots: int = 0
var hits: int = 0
var next_arrow: int = 0
var next_effect: int = 0
var cooldown: float = 0.0
var windup: float = -1.0
var attack_released: bool = false
var needs_release: bool = false
var paused: bool = false
var reading: bool = false
var run_id: int = -1
var health: int = 100
var hurt: float = 0.0
var protection: float = 0.0
var status: String = "running"
var encounter: int = 0
var dodge_time: float = 0.0
var dodge_invulnerability: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_held: bool = false
var dodge_direction: Vector2 = Vector2.RIGHT
var piercing: float = -1.0
var pierce_cooldown: float = 0.0
var pierce_held: bool = false
var skill_recovery: float = 0.0
var last_skill: String = ""
var raining: Dictionary = {}
var rain_cooldown: float = 0.0
var rain_held: bool = false
var rains: Array[Dictionary] = []
var invalid: Dictionary = {}
var gate_opening: float = 0.0
var interact_held: bool = false
var exploration: Dictionary = {}
var feedback: Dictionary = {}

static func point(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(value.x, value.y)

func _init(options: Dictionary = {}) -> void:
	if options.has("width"):
		layout = options.duplicate(true)
	else:
		# 保留已批准小样；正式汤谷和编辑器场景使用同一个公开布局合同。
		obstacle = options.get("obstacle", obstacle)
		var bounds: Rect2 = options.get("bounds", Rect2(100,180,1080,640))
		var center: Vector2 = obstacle.get_center()
		layout = {"width":1280,"height":900,"floor":[Vector2.ZERO,Vector2(1280,0),Vector2(1280,900),Vector2(0,900)], "spawn":options.get("spawn",Vector2(400,600)), "walkableAreas":[{"left":bounds.position.x,"top":bounds.position.y,"right":bounds.end.x,"bottom":bounds.end.y}], "pillars":[],"pillarBody":[],"targets":[],"shoulderHeight":52,"grips":GRIPS,"targetFace":{}, "obstacles":[{"x":center.x,"y":center.y,"halfWidth":obstacle.size.x/2,"halfHeight":obstacle.size.y/2,"height":120,"kind":"root"}], "encounters":[{"x":point(options.get("encounter",Vector2(740,600))).x,"y":point(options.get("encounter",Vector2(740,600))).y,"enemies":[options.get("enemy",Vector2(840,600))]}]}
	reset()

func reset() -> void:
	if paused or reading: return
	run_id += 1
	var spawn: Vector2 = point(layout.get("spawn",Vector2(400,440)))
	player = {"x":float(spawn.x),"y":float(spawn.y),"moving":false,"angle":0.0,"facing":0}
	enemies.clear()
	for group in layout.get("encounters",[]).size():
		var index: int = 0
		for location in layout.encounters[group].enemies:
			var position: Vector2 = point(location)
			enemies.append({"id":group*100+index,"group":group,"appearance":location.get("appearance","bird") if location is Dictionary else "bird","x":float(position.x),"y":float(position.y),"health":60,"phase":"inactive","timer":0.0,"angle":0.0,"struck":false,"flash":0.0,"route":[],"repath":0.0,"knockX":0.0,"knockY":0.0,"knockTime":0.0})
			index += 1
	arrows.clear(); effects.clear(); rains.clear(); flashes.clear()
	for target in layout.targets: flashes.append(0.0)
	health=100; hurt=0; protection=0; status="running"; encounter=0
	cooldown=0; shots=0; hits=0; next_effect=0
	dodge_time=0; dodge_invulnerability=0; dodge_cooldown=0; dodge_held=run_id>0
	piercing=-1; pierce_cooldown=0; pierce_held=run_id>0; skill_recovery=0; last_skill=""
	raining={}; rain_cooldown=0; rain_held=run_id>0; invalid={}
	exploration={"steleRead":false,"altarUsed":false,"gateOpen":false}
	feedback={}; interact_held=run_id>0; gate_opening=0
	cancel_pending(); needs_release=run_id>0

func update(input: Dictionary, seconds: float) -> void:
	var pressed: bool = input.get("interact",false) and not interact_held
	interact_held=input.get("interact",false)
	if pressed and reading:
		close_reading(); return
	if pressed:
		interact()
		if reading: return
	if reading: return
	var steps: int = maxi(1,ceili(seconds/0.01))
	for index in steps: step(input,seconds/steps)

func step(input: Dictionary, seconds: float) -> void:
	if paused or status=="failed": return
	if not feedback.is_empty():
		feedback.remaining-=seconds
		if feedback.remaining<=0: feedback={}
	if gate_opening>0:
		gate_opening=maxf(0,gate_opening-seconds)
		if gate_opening==0:
			exploration.gateOpen=true
			for enemy in enemies: enemy.route=[]; enemy.repath=0
			feedback={"text":"栅门已开启 · 可返回主路","remaining":1.6,"healed":false}
	var protection_at_start: float = protection
	hurt=maxf(0,hurt-seconds); protection=maxf(0,protection-seconds)
	if not input.get("fire",false): needs_release=false
	if not input.get("pointerInside",true):
		cancel_pending(); needs_release=input.get("fire",false)
	var rain_pressed: bool = input.get("rain",false) and not rain_held
	rain_held=input.get("rain",false); rain_cooldown=maxf(0,rain_cooldown-seconds)
	if not invalid.is_empty():
		invalid.remaining-=seconds
		if invalid.remaining<=0: invalid={}
	var pierce_pressed: bool = input.get("pierce",false) and not pierce_held
	pierce_held=input.get("pierce",false); pierce_cooldown=maxf(0,pierce_cooldown-seconds)
	skill_recovery=maxf(0,skill_recovery-seconds); dodge_cooldown=maxf(0,dodge_cooldown-seconds)
	var movement: Vector2 = Vector2(input.get("moveX",0),input.get("moveY",0)).limit_length()
	if input.get("dodge",false) and not dodge_held and dodge_cooldown==0 and hurt==0 and dodge_time==0:
		dodge_direction=movement.normalized() if movement.length()>0 else Vector2.from_angle(player.angle)
		dodge_time=0.20; dodge_invulnerability=0.12; dodge_cooldown=1.0; cancel_pending()
	dodge_held=input.get("dodge",false)
	var dashing: bool = dodge_time>0
	var start: Vector2 = Vector2(player.x,player.y)
	var divisions: int = maxi(1,ceili(seconds*(600.0 if dashing else 220.0)/2.0))
	var interval: float = seconds/divisions
	for index in divisions:
		var dash: float = maxf(0,minf(interval,dodge_time-index*interval)) if dashing else 0.0
		var dx: float = 0.0 if hurt>0 else dodge_direction.x*600*dash+movement.x*220*(interval-dash)
		var dy: float = 0.0 if hurt>0 else dodge_direction.y*600*dash+movement.y*220*(interval-dash)
		if can_walk(Vector2(player.x+dx,player.y)): player.x+=dx
		if can_walk(Vector2(player.x,player.y+dy)): player.y+=dy
	player.moving=start.distance_to(Vector2(player.x,player.y))>0.01
	var aim: Vector2 = point(input.get("aim",Vector2(player.x+100,player.y-52)))
	if input.get("pointerInside",true) and aim.distance_to(Vector2(player.x,player.y-layout.shoulderHeight))>4:
		var reference: float = (aim-Vector2(player.x,player.y-layout.shoulderHeight)).angle()
		if absf(angle_difference(player.facing*PI/2,reference))>PI/4+0.08:
			player.facing=posmod(floori(reference/(PI/2)+0.5),4)
		if aim.distance_to(grip())>4: player.angle=(aim-grip()).angle()
	update_enemies(seconds,protection_at_start,dodge_invulnerability)
	dodge_invulnerability=maxf(0,dodge_invulnerability-seconds)
	if health<=0: return
	var live_effects: Array[Dictionary] = []
	for effect in effects:
		effect.remaining-=seconds; effect.age+=seconds
		if effect.remaining>0: live_effects.append(effect)
	effects=live_effects
	for index in flashes.size(): flashes[index]=maxf(0,flashes[index]-seconds)
	cooldown=maxf(0,cooldown-seconds)
	var can_start: bool = not dashing and hurt==0 and windup<0 and piercing<0 and raining.is_empty() and skill_recovery==0 and not (attack_released and cooldown>0.12)
	if can_start and pierce_pressed and pierce_cooldown==0 and input.get("pointerInside",true):
		piercing=0.18; pierce_cooldown=4; last_skill="pierce"; attack_released=false
	if can_start and piercing<0 and rain_pressed and rain_cooldown==0 and input.get("pointerInside",true):
		if aim.distance_to(Vector2(player.x,player.y))<=480 and can_walk(aim):
			raining={"remaining":0.45,"point":aim}; rain_cooldown=8; last_skill="rain"; attack_released=false; invalid={}
		else: invalid={"x":aim.x,"y":aim.y,"remaining":0.35}
	if not raining.is_empty():
		raining.remaining-=seconds
		if raining.remaining<=0:
			rains.append({"x":raining.point.x,"y":raining.point.y,"age":-raining.remaining-seconds,"pulse":0})
			raining={}; skill_recovery=0.12
	if piercing>=0:
		piercing-=seconds
		if piercing<=0:
			var remainder: float = -piercing
			piercing=0 # 离弦时仍使用穿透箭握点；随后才退出技能动作。
			launch("pierce",remainder); piercing=-1; skill_recovery=0.12
	if not dashing and piercing<0 and raining.is_empty() and skill_recovery==0 and hurt<=0 and input.get("fire",false) and not needs_release and cooldown<=0.000001 and input.get("pointerInside",true):
		windup=0.08; last_skill=""; attack_released=false; cooldown=0.35
	if windup>=0:
		windup-=seconds
		if windup<=0:
			launch("normal",-windup); shots+=1; windup=-1; attack_released=true
	var active: Array[Dictionary] = []
	for arrow in arrows:
		var lifetime: float = 1.4 if arrow.kind=="pierce" else 2.0
		var elapsed: float = maxf(0,minf(arrow.get("initialStep",seconds),lifetime-arrow.age))
		arrow.erase("initialStep")
		var from: Vector2 = Vector2(arrow.x,arrow.y)
		var speed: float = 900.0 if arrow.kind=="pierce" else 700.0
		var next_x: float = arrow.x+cos(arrow.angle)*speed*elapsed
		var next_y: float = arrow.y+sin(arrow.angle)*speed*elapsed
		var to: Vector2 = Vector2(next_x,next_y)
		var hit: Dictionary = contact(from,to,arrow.hitEnemies)
		var stopped: bool = false
		while not hit.is_empty():
			impact(hit,arrow.kind,arrow.angle)
			if arrow.kind!="pierce" or not hit.has("enemy"):
				stopped=true; break
			arrow.hitEnemies.append(hit.enemy)
			hit=contact(from,to,arrow.hitEnemies)
		if stopped: continue
		arrow.x=next_x; arrow.y=next_y; arrow.age+=elapsed
		if arrow.age<lifetime-0.000001: active.append(arrow)
	arrows=active
	var live_rains: Array[Dictionary] = []
	for rain in rains:
		rain.age+=seconds
		while rain.pulse<3 and rain.age>=rain.pulse*0.18:
			for enemy in enemies:
				var delta: Vector2 = Vector2(enemy.x-rain.x,enemy.y-rain.y)
				if enemy.phase!="inactive" and enemy.phase!="dead" and delta.length()<=110:
					impact({"x":enemy.x,"y":enemy.y-35,"target":null,"enemy":enemy.id},"rain",delta.angle() if delta.length()>0.01 else player.angle)
			rain.pulse+=1
		if rain.age<0.65: live_rains.append(rain)
	rains=live_rains
	dodge_time=maxf(0,dodge_time-seconds)

func launch(kind: String, initial_step: float) -> void:
	var muzzle: Vector2 = grip()
	var blocked: Dictionary = contact(Vector2(player.x,player.y-layout.shoulderHeight),muzzle)
	var hit_enemies: Array = []
	if not blocked.is_empty():
		impact(blocked,kind,player.angle)
		if kind!="pierce" or not blocked.has("enemy"): return
		hit_enemies.append(blocked.enemy)
	arrows.append({"id":next_arrow,"x":muzzle.x,"y":muzzle.y,"angle":player.angle,"age":0.0,"kind":kind,"initialStep":initial_step,"hitEnemies":hit_enemies})
	next_arrow+=1

func impact(hit: Dictionary, kind: String, angle: float) -> void:
	var damage: int = 0
	var damage_position: Variant = null
	if hit.get("target")!=null:
		hits+=1; flashes[int(hit.target)]=0.1
	if hit.has("enemy"):
		for enemy in enemies:
			if enemy.id!=hit.enemy: continue
			damage_position=Vector2(enemy.x,enemy.y)
			var stats: Dictionary = ATTACKS[kind]
			damage=mini(enemy.health,stats.damage); enemy.health-=damage
			enemy.flash=0.12; hits+=1
			enemy.knockX=cos(angle)*stats.distance/stats.duration; enemy.knockY=sin(angle)*stats.distance/stats.duration; enemy.knockTime=stats.duration
			enemy.route=[]; enemy.repath=0
			if enemy.health==0: enemy.phase="dead"; enemy.timer=0.6
			break
	var effect: Dictionary = hit.duplicate()
	effect.merge({"id":next_effect,"kind":kind,"remaining":0.15,"age":0.0,"damage":damage,"angle":angle,"damagePosition":damage_position})
	effects.append(effect); next_effect+=1

func update_enemies(seconds: float, protection_at_start: float, dodge_at_start: float) -> void:
	var groups: Array = layout.get("encounters",[])
	if encounter<groups.size():
		var inactive: bool = true
		for enemy in enemies:
			if enemy.group==encounter and enemy.phase!="inactive": inactive=false
		if inactive and point(groups[encounter]).distance_to(Vector2(player.x,player.y))<=170:
			for enemy in enemies:
				if enemy.group==encounter: enemy.phase="chase"
	for enemy in enemies:
		enemy.flash=maxf(0,enemy.flash-seconds)
		if enemy.phase=="inactive": continue
		var pushed: bool = enemy.knockTime>0
		if pushed:
			var elapsed: float = minf(seconds,enemy.knockTime)
			var divisions: int = maxi(1,ceili(Vector2(enemy.knockX,enemy.knockY).length()*elapsed/2))
			for index in divisions:
				var x: float = enemy.x+enemy.knockX*elapsed/divisions
				var y: float = enemy.y+enemy.knockY*elapsed/divisions
				if can_walk(Vector2(x,enemy.y)): enemy.x=x
				if can_walk(Vector2(enemy.x,y)): enemy.y=y
			enemy.knockTime=maxf(0,enemy.knockTime-seconds)
		if enemy.phase=="dead":
			enemy.timer=maxf(0,enemy.timer-seconds); continue
		var swing_until: float = -1.0
		if enemy.phase=="swing": swing_until=minf(seconds,enemy.timer)
		elif enemy.phase=="warn" and seconds>enemy.timer: swing_until=minf(seconds,enemy.timer+0.10)
		enemy.timer-=seconds
		var dx: float = player.x-enemy.x
		var dy: float = player.y-enemy.y
		var distance: float = sqrt(dx*dx+dy*dy)
		var toward: float = atan2(dy,dx)
		if enemy.phase=="chase":
			enemy.angle=toward
			if distance<=70:
				enemy.phase="warn"; enemy.timer=0.45; enemy.struck=false
			elif not pushed:
				var destination: Variant = player
				enemy.repath-=seconds
				if not clear_path(enemy,player):
					if enemy.repath<=0:
						enemy.route=find_route(enemy,player); enemy.repath=0.35
					while enemy.route.size()>1 and clear_path(enemy,enemy.route[1]): enemy.route.pop_front()
					if not enemy.route.is_empty() and sqrt(pow(enemy.x-enemy.route[0].x,2)+pow(enemy.y-enemy.route[0].y,2))<3: enemy.route.pop_front()
					if enemy.route.is_empty(): continue
					destination=enemy.route[0]
				var goal_x: float = destination.x
				var goal_y: float = destination.y
				enemy.angle=atan2(goal_y-enemy.y,goal_x-enemy.x)
				var travel: float = minf(sqrt(pow(goal_x-enemy.x,2)+pow(goal_y-enemy.y,2)),120*seconds)
				var x: float = enemy.x+cos(enemy.angle)*travel
				var y: float = enemy.y+sin(enemy.angle)*travel
				if can_walk(Vector2(x,enemy.y)): enemy.x=x
				if can_walk(Vector2(enemy.x,y)): enemy.y=y
				for other in enemies:
					if other.id==enemy.id or other.phase=="inactive" or other.phase=="dead": continue
					var gap_x: float = enemy.x-other.x
					var gap_y: float = enemy.y-other.y
					var gap: float = sqrt(gap_x*gap_x+gap_y*gap_y)
					if gap<26:
						var angle: float = atan2(gap_y,gap_x) if gap>0.01 else enemy.id*2.4
						var push: float = minf((26-gap)/2,60*seconds)
						var next_x: float = enemy.x+cos(angle)*push
						var next_y: float = enemy.y+sin(angle)*push
						if can_walk(Vector2(next_x,next_y)): enemy.x=next_x; enemy.y=next_y
		else:
			if enemy.phase=="warn" and enemy.timer<=0: enemy.phase="swing"; enemy.timer+=0.10
			if enemy.phase=="swing" and enemy.timer<=0: enemy.phase="recover"; enemy.timer+=0.65
			if enemy.phase=="recover" and enemy.timer<=0: enemy.phase="chase"; enemy.timer=0.0
		if swing_until>=0 and not enemy.struck and distance<=70 and absf(angle_difference(enemy.angle,toward))<=PI/4 and protection_at_start<swing_until and dodge_at_start<swing_until and protection<=0:
			enemy.struck=true; health=maxi(0,health-20); hurt=0.12; protection=0.6; cancel_pending(); needs_release=true
			if health==0: status="failed"; player.moving=false; return
	if encounter<groups.size():
		var cleared: bool = true
		for enemy in enemies:
			if enemy.group==encounter and enemy.phase!="dead": cleared=false
		if cleared:
			encounter+=1
			if encounter==groups.size(): status="complete"

func cancel_pending() -> void:
	windup=-1; piercing=-1; raining={}; attack_released=false; needs_release=false
func cancel_input() -> void:
	cancel_pending(); pierce_held=false; rain_held=false; dodge_held=false; interact_held=false
func set_paused(value: bool) -> void:
	paused=value; cancel_pending(); needs_release=true; dodge_time=0; dodge_invulnerability=0; player.moving=false
	dodge_held=true; pierce_held=true; rain_held=true
func close_reading() -> void:
	reading=false; needs_release=true; pierce_held=true; rain_held=true; dodge_held=true
func attack_phase() -> String:
	if windup>=0: return "draw"
	if attack_released and cooldown>0.22: return "release"
	if attack_released and cooldown>0.12: return "recover"
	return "idle"
func grip() -> Vector2:
	var offsets: Array = SKILL_GRIPS.dodge if dodge_time>0 else SKILL_GRIPS.rain if not raining.is_empty() else SKILL_GRIPS.pierce if piercing>=0 else layout.grips
	return Vector2(player.x,player.y)+point(offsets[player.facing])

func obstacles() -> Array:
	return layout.get("obstacles",[]).filter(func(item: Dictionary): return item.kind!="gate" or not exploration.gateOpen)
func can_walk(position: Vector2) -> bool:
	return can_walk_xy(position.x,position.y)
func can_walk_xy(x: float,y: float) -> bool:
	if layout.has("walkableAreas"):
		var inside: bool = false
		for area in layout.walkableAreas:
			if x>=area.left+12 and x<=area.right-12 and y>=area.top+12 and y<=area.bottom-12: inside=true; break
		if not inside: return false
	for index in layout.floor.size():
		var from: Vector2 = point(layout.floor[index])
		var to: Vector2 = point(layout.floor[(index+1)%layout.floor.size()])
		if (to.x-from.x)*(y-from.y)-(to.y-from.y)*(x-from.x)<12*from.distance_to(to): return false
	for pillar in layout.pillars:
		if absf(x-pillar.x)<40 and absf(y-pillar.y)<30: return false
	for item in obstacles():
		if absf(x-item.x)<item.halfWidth+12 and absf(y-item.y)<item.halfHeight+12: return false
	return true
func clear_path(from: Variant,to: Variant) -> bool:
	var dx: float = to.x-from.x
	var dy: float = to.y-from.y
	var steps: int = ceili(sqrt(dx*dx+dy*dy)/10)
	for index in range(1,steps+1):
		if not can_walk_xy(from.x+dx*index/steps,from.y+dy*index/steps): return false
	return true
func find_route(from: Variant,to: Variant) -> Array:
	var columns: int = ceili(layout.width/32.0)
	var rows: int = ceili(layout.height/32.0)
	var start: Vector2i = Vector2i(clampi(floori(from.x/32),0,columns-1),clampi(floori(from.y/32),0,rows-1))
	var previous: Dictionary = {start:start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head<queue.size():
		var current: Vector2i = queue[head]; head+=1
		var center: Vector2 = (Vector2(current)+Vector2.ONE*0.5)*32
		if sqrt(pow(center.x-to.x,2)+pow(center.y-to.y,2))<=48 and clear_path(center,to):
			# 终点保持玩家位置引用，与参照一致；路径有效期间玩家仍可移动。
			var result: Array = [to]
			while current!=start:
				result.append((Vector2(current)+Vector2.ONE*0.5)*32); current=previous[current]
			result.reverse(); return result
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+offset
			if next.x<0 or next.y<0 or next.x>=columns or next.y>=rows or previous.has(next): continue
			if can_walk((Vector2(next)+Vector2.ONE*0.5)*32): previous[next]=current; queue.append(next)
	return []

func segment_rectangle(from: Vector2,to: Vector2,rectangle: Rect2) -> float:
	var entry: float = 0.0
	var exit_time: float = 1.0
	for axis in 2:
		var delta: float = to[axis]-from[axis]
		if absf(delta)<0.00001:
			if from[axis]<rectangle.position[axis] or from[axis]>rectangle.end[axis]: return -1
		else:
			var first: float = (rectangle.position[axis]-from[axis])/delta
			var last: float = (rectangle.end[axis]-from[axis])/delta
			entry=maxf(entry,minf(first,last)); exit_time=minf(exit_time,maxf(first,last))
			if entry>exit_time: return -1
	return entry
func target_contact(from: Vector2,to: Vector2,target: Dictionary) -> float:
	var face: Dictionary = layout.targetFace
	var origin: Vector2 = (from-Vector2(target.x,target.y+face.offsetY))/Vector2(face.radiusX,face.radiusY)
	var delta: Vector2 = (to-from)/Vector2(face.radiusX,face.radiusY)
	var c: float = origin.length_squared()-1
	if c<=0: return 0
	var a: float = delta.length_squared()
	var b: float = 2*origin.dot(delta)
	var discriminant: float = b*b-4*a*c
	if a==0 or discriminant<0: return -1
	var t: float = (-b-sqrt(discriminant))/(2*a)
	return t if t>=0 and t<=1 else -1
func contact(from: Vector2,to: Vector2,ignored: Array = []) -> Dictionary:
	var first: float = INF
	var hit: Dictionary = {}
	for pillar in layout.pillars:
		for body in layout.pillarBody:
			var t: float = segment_rectangle(from,to,Rect2(pillar.x-body[0],pillar.y+body[1],body[0]*2,body[2]-body[1]))
			if t>=0 and t<first: first=t; hit={"target":null}
	for item in obstacles():
		var t: float = segment_rectangle(from,to,Rect2(item.x-item.halfWidth,item.y-item.height,item.halfWidth*2,item.height+item.halfHeight))
		if t>=0 and t<first: first=t; hit={"target":null}
	for index in layout.targets.size():
		var t: float = target_contact(from,to,layout.targets[index])
		if t>=0 and t<first: first=t; hit={"target":index}
	for enemy in enemies:
		if enemy.phase=="inactive" or enemy.phase=="dead" or ignored.has(enemy.id): continue
		var t: float = segment_rectangle(from,to,Rect2(enemy.x-18,enemy.y-82,36,74))
		if t>=0 and t<first: first=t; hit={"target":null,"enemy":enemy.id}
	for index in layout.floor.size():
		var a: Vector2 = point(layout.floor[index])
		var b: Vector2 = point(layout.floor[(index+1)%layout.floor.size()])
		var before: float = (b-a).cross(from-a)
		var after: float = (b-a).cross(to-a)
		if after<0:
			var t: float = 0.0 if before<=0 else before/(before-after)
			if t<first: first=t; hit={"target":null}
	if first>1: return {}
	var position: Vector2 = from.lerp(to,first)
	hit.x=position.x; hit.y=position.y
	return hit

func nearest_interaction() -> Dictionary:
	var candidates: Array[Dictionary] = []
	var gate: Dictionary = {}
	for item in layout.get("obstacles",[]):
		if item.kind=="gate": gate=item; break
	for item in layout.get("exploration",[]):
		var outside: bool = item.id=="gate" and not gate.is_empty() and player.y<=gate.y
		var position: Vector2 = Vector2(item.x,gate.y-gate.halfHeight-40) if outside else point(item)
		var distance: float = position.distance_to(Vector2(player.x,player.y))
		if distance<=80: candidates.append({"id":item.id,"point":position,"outside":outside,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance<b.distance)
	for candidate in candidates:
		if not can_walk(candidate.point) or not clear_path(Vector2(player.x,player.y),candidate.point): continue
		var active: bool = false
		for enemy in enemies:
			if enemy.phase!="inactive" and enemy.phase!="dead": active=true
		var labels: Dictionary = {"stele":"再读残碑 · 已读" if exploration.steleRead else "阅读残碑","altar":"祭火恢复","gate":"开启栅门"}
		var reason: Variant = "影散后无法互动" if status=="failed" else "暂停中无法互动" if paused else "先清除已苏醒的影偶" if active else "需从祭坛支路内侧开启" if candidate.outside else "祭火已熄灭" if candidate.id=="altar" and exploration.altarUsed else "栅门正在开启" if candidate.id=="gate" and gate_opening>0 else "栅门已开启" if candidate.id=="gate" and exploration.gateOpen else null
		return {"id":candidate.id,"point":candidate.point,"label":labels[candidate.id],"reason":reason}
	return {}
func interact() -> void:
	var target: Dictionary = nearest_interaction()
	if target.is_empty(): return
	if target.reason!=null: feedback={"text":target.reason,"remaining":1.6,"healed":false}; return
	if target.id=="stele":
		reading=true; exploration.steleRead=true; player.moving=false; dodge_time=0; dodge_invulnerability=0; cancel_pending(); needs_release=true
	elif target.id=="altar":
		if health==100: feedback={"text":"无需恢复","remaining":1.6,"healed":false}
		else:
			var amount: int = mini(40,100-health)
			health+=amount; exploration.altarUsed=true; feedback={"text":"生命恢复 +%d" % amount,"remaining":1.6,"healed":true}
	else:
		gate_opening=0.28; feedback={"text":"栅门正在开启","remaining":1.6,"healed":false}

func snapshot() -> Dictionary:
	var visible_enemies: Array[Dictionary] = []
	for enemy in enemies:
		var visible: Dictionary = enemy.duplicate(true)
		visible.erase("route"); visible.erase("repath"); visible_enemies.append(visible)
	var targets: Array[Dictionary] = []
	for index in layout.targets.size():
		var target: Dictionary = layout.targets[index].duplicate(); target.flash=flashes[index]; targets.append(target)
	var skill: Variant = {"kind":"rain","phase":"windup","remaining":raining.remaining} if not raining.is_empty() else {"kind":"pierce","phase":"windup","remaining":piercing} if piercing>=0 else {"kind":last_skill,"phase":"recover","remaining":skill_recovery} if skill_recovery>0 and not last_skill.is_empty() else null
	return {"runId":run_id,"player":player.duplicate(),"grip":grip(),"hits":hits,"windup":windup if windup>=0 else null,"paused":paused or reading,"reading":reading,"gateOpening":gate_opening,"exploration":exploration.duplicate(),"interaction":nearest_interaction() if not nearest_interaction().is_empty() else null,"feedback":feedback.duplicate() if not feedback.is_empty() else null,"attack":attack_phase(),"health":health,"hurt":hurt,"protection":protection,"status":status,"dodge":dodge_time,"dodgeDirection":dodge_direction,"dodgeInvulnerability":dodge_invulnerability,"cooldowns":{"dodge":dodge_cooldown,"pierce":pierce_cooldown,"rain":rain_cooldown},"skill":skill,"rainPreview":raining.point if not raining.is_empty() else null,"rains":rains.duplicate(true),"invalid":invalid.duplicate() if not invalid.is_empty() else null,"encounter":encounter,"totalEncounters":layout.get("encounters",[]).size(),"enemies":visible_enemies,"arrows":arrows.duplicate(true),"effects":effects.duplicate(true),"targets":targets,"shots":shots}
