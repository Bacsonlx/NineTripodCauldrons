class_name TrainingRoom
extends RefCounted

const WORLD_SIZE: Vector2 = Vector2(1280, 900)
const GRIPS: Array[Vector2] = [Vector2(27, -51), Vector2(24, -48), Vector2(-21, -48), Vector2(-22, -53)]
const SKILL_GRIPS: Dictionary = {
	"pierce": [Vector2(31,-44), Vector2(17,-43), Vector2(-28,-45), Vector2(-24,-48)],
	"rain": [Vector2(14,-68), Vector2(21,-70), Vector2(-21,-67), Vector2(-20,-68)],
	"dodge": [Vector2(16,-39), Vector2(-3,-39), Vector2(-13,-37), Vector2(-8,-45)]
}
const ATTACKS: Dictionary = {"normal":{"damage":15,"distance":14,"duration":0.10}, "pierce":{"damage":40,"distance":36,"duration":0.14}, "rain":{"damage":15,"distance":8,"duration":0.08},"burn":{"damage":2,"distance":0,"duration":1.0}}
const AlphaState = preload("res://scripts/alpha/alpha_state.gd")
const ENERGY_COSTS: Dictionary = {"pierce":12,"rain":28,"dodge":25,"backwind":12,"charge":16,"wind":16}
# 只在正式独立房间启用；冻结迁移参照和旧小样保留原规则。
var energy_enabled: bool = false
var mana: int = 100
var stamina: float = 100.0
var stamina_delay: float = 0.0
var pending_mana: int = 0
var potion_drops: bool = false
var drops: Array[Dictionary] = []
var blue_waves: Dictionary = {}
var drop_random: RandomNumberGenerator = RandomNumberGenerator.new()
var alpha: RefCounted = null
const ENEMY_RULES: Dictionary = {
	"bird":{"health":60,"speed":120.0,"damage":20,"range":70.0,"warn":0.45,"swing":0.10,"recover":0.65},
	"paper":{"health":45,"speed":90.0,"damage":10,"range":300.0,"warn":0.75,"swing":0.0,"recover":1.25},
	"wood":{"health":150,"speed":85.0,"damage":25,"range":90.0,"warn":0.70,"swing":0.12,"recover":0.90}
}
var paper_arrows: Array[Dictionary] = []
var next_paper_arrow: int = 0
var special_held: Array[bool] = [false,false]
var special_cooldowns: Dictionary = {"backwind":0.0,"charge":0.0,"wind":0.0}
var skill_dash_remaining: float = 0.0
var skill_dash_direction: Vector2 = Vector2.ZERO
var skill_dash_kind: String = ""
var charge_remaining: float = 0.0
var charge_layers: int = 0
var beast_held: bool = false
var wind_path: Dictionary = {}
var item_aim: Vector2 = Vector2.ZERO
var gameplay: bool = false
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
var health_max: int = 100
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
	potion_drops=options.get("potionDrops",false)
	gameplay=options.get("gameplay",false) or options.get("mode","")=="gameplay"
	if options.has("width"):
		layout = options.duplicate(true)
	else:
		# 保留已批准小样；正式汤谷和编辑器场景使用同一个公开布局合同。
		obstacle = options.get("obstacle", obstacle)
		var bounds: Rect2 = options.get("bounds", Rect2(100,180,1080,640))
		var center: Vector2 = obstacle.get_center()
		layout = {"width":1280,"height":900,"floor":[Vector2.ZERO,Vector2(1280,0),Vector2(1280,900),Vector2(0,900)], "spawn":options.get("spawn",Vector2(400,600)), "walkableAreas":[{"left":bounds.position.x,"top":bounds.position.y,"right":bounds.end.x,"bottom":bounds.end.y}], "pillars":[],"pillarBody":[],"targets":[],"shoulderHeight":52,"grips":GRIPS,"targetFace":{}, "obstacles":[{"x":center.x,"y":center.y,"halfWidth":obstacle.size.x/2,"halfHeight":obstacle.size.y/2,"height":120,"kind":"root"}], "encounters":[{"x":point(options.get("encounter",Vector2(740,600))).x,"y":point(options.get("encounter",Vector2(740,600))).y,"enemies":[options.get("enemy",Vector2(840,600))]}]}
	if options.get("mode","") in ["alpha","gameplay"]: alpha=AlphaState.new(options.get("seed",1),gameplay,options.get("initialItems",[]))
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
			if gameplay:
				var role: String = location.get("role",location.get("appearance","bird")) if location is Dictionary else "bird"
				enemies.back().merge({"role":role,"health":ENEMY_RULES[role].health,"maxHealth":ENEMY_RULES[role].health},true)
			index += 1
	arrows.clear(); effects.clear(); rains.clear(); flashes.clear()
	paper_arrows.clear(); next_paper_arrow=0
	special_held=[false,false]; special_cooldowns={"backwind":0.0,"charge":0.0,"wind":0.0}
	skill_dash_remaining=0; charge_remaining=0; charge_layers=0; beast_held=false; wind_path={}
	for target in layout.targets: flashes.append(0.0)
	health=100; health_max=100; hurt=0; protection=0; status="running"; encounter=0
	pending_mana=0; mana=100; stamina=100; stamina_delay=0
	drops.clear(); blue_waves.clear()
	if layout.has("dropSeed"): drop_random.seed=int(layout.dropSeed)
	else: drop_random.randomize()
	cooldown=0; shots=0; hits=0; next_effect=0
	dodge_time=0; dodge_invulnerability=0; dodge_cooldown=0; dodge_held=run_id>0
	piercing=-1; pierce_cooldown=0; pierce_held=run_id>0; skill_recovery=0; last_skill=""
	raining={}; rain_cooldown=0; rain_held=run_id>0; invalid={}
	exploration={"steleRead":false,"altarUsed":false,"gateOpen":false}
	feedback={}; interact_held=run_id>0; gate_opening=0
	cancel_pending(); needs_release=run_id>0
	if alpha!=null: alpha.reset(spawn,layout.get("roomId",""))

func update(input: Dictionary, seconds: float) -> void:
	item_aim=point(input.get("aim",point(player)+Vector2.from_angle(player.angle)*100))
	if alpha!=null:
		if input.has("alpha"):
			alpha.command(input.alpha,self)
			alpha.recount()
			if alpha.gameplay and not alpha.camp:
				health_max=alpha.max_health()
				health=mini(health,health_max)
		if not paused and not reading and status!="failed":
			alpha.burn_input(input.get("burn",false))
		if alpha.camp: return
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
	if alpha!=null and alpha.gameplay and not paused and status!="failed" and seconds>0:
		alpha.auto_pickup(self); refresh_item_stats()

func step(input: Dictionary, seconds: float) -> void:
	if paused or status=="failed": return
	if alpha!=null:
		alpha.advance(seconds,self)
		if alpha.gameplay: alpha.runtime.advance(self,seconds)
	if energy_enabled:
		var recovering: float = maxf(0,seconds-stamina_delay)
		stamina_delay=maxf(0,stamina_delay-seconds)
		stamina=minf(100,stamina+recovering*10)
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
	var special_pressed: Array[bool] = [false,false]
	var beast_pressed: bool = false
	if has_loadout_skills():
		input=input.duplicate()
		beast_pressed=input.get("beast",false) and not beast_held
		beast_held=input.get("beast",false)
		if not wind_path.is_empty():
			wind_path.remaining=maxf(0,wind_path.remaining-seconds)
			if wind_path.remaining<=0: wind_path={}
		for key in special_cooldowns: special_cooldowns[key]=maxf(0,special_cooldowns[key]-seconds)
		charge_remaining=maxf(0,charge_remaining-seconds)
		if charge_remaining<=0: charge_layers=0
		for index in 2:
			var held: bool = input.get("special%d" % (index+1),false)
			special_pressed[index]=held and not special_held[index]
			special_held[index]=held
			if special_pressed[index] and alpha.special_skill(index)=="rain": input.rain=true
		if alpha.special_skill(0)!="rain" and alpha.special_skill(1)!="rain": input.rain=false
	var rain_pressed: bool = input.get("rain",false) and not rain_held
	rain_held=input.get("rain",false); rain_cooldown=maxf(0,rain_cooldown-seconds)
	if not invalid.is_empty():
		invalid.remaining-=seconds
		if invalid.remaining<=0: invalid={}
	var pierce_pressed: bool = input.get("pierce",false) and not pierce_held
	pierce_held=input.get("pierce",false); pierce_cooldown=maxf(0,pierce_cooldown-seconds)
	skill_recovery=maxf(0,skill_recovery-seconds); dodge_cooldown=maxf(0,dodge_cooldown-seconds)
	var movement: Vector2 = Vector2(input.get("moveX",0),input.get("moveY",0)).limit_length()
	if has_loadout_skills(): movement*=alpha.runtime.movement_multiplier(self)
	if input.get("dodge",false) and not dodge_held and dodge_cooldown==0 and hurt==0 and dodge_time==0 and skill_dash_remaining==0:
		if spend_energy("dodge"):
			dodge_direction=movement.normalized() if movement.length()>0 else Vector2.from_angle(player.angle)
			dodge_time=0.20; dodge_invulnerability=0.12; dodge_cooldown=1.0; cancel_pending()
	dodge_held=input.get("dodge",false)
	var dashing: bool = dodge_time>0
	if has_loadout_skills() and not dashing and hurt==0 and input.get("pointerInside",true):
		var beast_started: bool = beast_pressed and cast_wind(input,movement)
		if beast_started: pierce_pressed=false; rain_pressed=false
		for index in (0 if beast_started else 2):
			if not special_pressed[index]: continue
			var kind: String = alpha.special_skill(index)
			if kind=="backwind" and special_cooldowns.backwind<=0:
				var direction: Vector2 = movement.normalized() if movement.length()>0 else -skill_aim(input)
				if start_skill_dash("backwind",direction):
					special_cooldowns.backwind=5.0; pierce_pressed=false; rain_pressed=false
			elif kind=="charge" and special_cooldowns.charge<=0 and charge_layers==0 and skill_dash_remaining==0 and windup<0 and piercing<0 and raining.is_empty() and skill_recovery==0:
				if spend_instant("charge"):
					charge_layers=2; charge_remaining=4.0; special_cooldowns.charge=10.0; pierce_pressed=false; rain_pressed=false
			break
	var skill_dashing: bool = skill_dash_remaining>0
	var start: Vector2 = Vector2(player.x,player.y)
	var divisions: int = maxi(1,ceili(seconds*(600.0 if dashing or skill_dashing else 220.0)/2.0))
	var interval: float = seconds/divisions
	for index in divisions:
		var dash: float = maxf(0,minf(interval,dodge_time-index*interval)) if dashing else 0.0
		var dx: float = 0.0 if hurt>0 else dodge_direction.x*600*dash+movement.x*220*(interval-dash)
		var dy: float = 0.0 if hurt>0 else dodge_direction.y*600*dash+movement.y*220*(interval-dash)
		if skill_dashing:
			var duration: float = maxf(0,minf(interval,skill_dash_remaining-index*interval))
			dx=skill_dash_direction.x*600*duration+movement.x*220*(interval-duration)
			dy=skill_dash_direction.y*600*duration+movement.y*220*(interval-duration)
		if can_walk(Vector2(player.x+dx,player.y)): player.x+=dx
		if can_walk(Vector2(player.x,player.y+dy)): player.y+=dy
	if skill_dashing and skill_dash_kind=="wind" and not wind_path.is_empty():
		wind_path.to=point(player)
		if point(player).distance_to(wind_path.points[-1])>0.000001: wind_path.points.append(point(player))
	skill_dash_remaining=maxf(0,skill_dash_remaining-seconds)
	player.moving=start.distance_to(Vector2(player.x,player.y))>0.01
	var aim: Vector2 = point(input.get("aim",Vector2(player.x+100,player.y-52)))
	if input.get("pointerInside",true) and aim.distance_to(Vector2(player.x,player.y-layout.shoulderHeight))>4:
		var reference: float = (aim-Vector2(player.x,player.y-layout.shoulderHeight)).angle()
		if absf(angle_difference(player.facing*PI/2,reference))>PI/4+0.08:
			player.facing=posmod(floori(reference/(PI/2)+0.5),4)
		if aim.distance_to(grip())>4: player.angle=(aim-grip()).angle()
	update_enemies(seconds,protection_at_start,dodge_invulnerability)
	if gameplay: update_paper_arrows(seconds)
	dodge_invulnerability=maxf(0,dodge_invulnerability-seconds)
	if health<=0: return
	var live_effects: Array[Dictionary] = []
	for effect in effects:
		effect.remaining-=seconds; effect.age+=seconds
		if effect.remaining>0: live_effects.append(effect)
	effects=live_effects
	for index in flashes.size(): flashes[index]=maxf(0,flashes[index]-seconds)
	cooldown=maxf(0,cooldown-seconds)
	var can_start: bool = not dashing and not skill_dashing and hurt==0 and windup<0 and piercing<0 and raining.is_empty() and skill_recovery==0 and not (attack_released and cooldown>0.12)
	if can_start and pierce_pressed and pierce_cooldown==0 and input.get("pointerInside",true):
		if spend_energy("pierce"):
			piercing=0.18; pierce_cooldown=4; last_skill="pierce"; attack_released=false
	if can_start and piercing<0 and rain_pressed and rain_cooldown==0 and input.get("pointerInside",true):
		if aim.distance_to(Vector2(player.x,player.y))<=480 and rain_target_valid(aim):
			if spend_energy("rain"):
				raining={"remaining":0.45,"point":aim}; rain_cooldown=8; last_skill="rain"; attack_released=false; invalid={}
		else: invalid={"x":aim.x,"y":aim.y,"remaining":0.35}
	if not raining.is_empty():
		raining.remaining-=seconds
		if raining.remaining<=0:
			pending_mana=0
			rains.append({"x":raining.point.x,"y":raining.point.y,"age":-raining.remaining-seconds,"pulse":0})
			raining={}; skill_recovery=0.12
	if piercing>=0:
		piercing-=seconds
		if piercing<=0:
			pending_mana=0
			var remainder: float = -piercing
			piercing=0 # 离弦时仍使用穿透箭握点；随后才退出技能动作。
			launch("pierce",remainder); piercing=-1; skill_recovery=0.12
	if not dashing and not skill_dashing and piercing<0 and raining.is_empty() and skill_recovery==0 and hurt<=0 and input.get("fire",false) and not needs_release and cooldown<=0.000001 and input.get("pointerInside",true):
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
			impact(hit,arrow.kind,arrow.angle,arrow)
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
	var multiplier: float = 1.0
	if has_loadout_skills() and kind=="normal" and charge_layers>0:
		multiplier=1.5; charge_layers-=1
		if charge_layers==0: charge_remaining=0
	var attack: Dictionary = alpha.runtime.attack(self,kind) if has_loadout_skills() else {}
	attack.chargeMultiplier=multiplier
	var muzzle: Vector2 = grip()
	var blocked: Dictionary = contact(Vector2(player.x,player.y-layout.shoulderHeight),muzzle)
	var hit_enemies: Array = []
	if not blocked.is_empty():
		impact(blocked,kind,player.angle,attack)
		if kind!="pierce" or not blocked.has("enemy"): return
		hit_enemies.append(blocked.enemy)
	arrows.append({"id":next_arrow,"x":muzzle.x,"y":muzzle.y,"angle":player.angle,"age":0.0,"kind":kind,"initialStep":initial_step,"hitEnemies":hit_enemies})
	if has_loadout_skills(): arrows.back().merge(attack)
	next_arrow+=1

func rain_target_valid(position: Vector2) -> bool:
	return can_walk(position)

func impact(hit: Dictionary, kind: String, angle: float, attack: Dictionary = {}) -> void:
	var damage: int = 0
	var damage_position: Variant = null
	if hit.get("target")!=null:
		hits+=1; flashes[int(hit.target)]=0.1
	if hit.has("enemy"):
		for enemy in enemies:
			if enemy.id!=hit.enemy or enemy.phase=="dead": continue
			damage_position=Vector2(enemy.x,enemy.y)
			var stats: Dictionary = ATTACKS[kind]
			damage=mini(enemy.health,roundi(stats.damage*damage_multiplier(kind,attack))); enemy.health-=damage
			enemy.flash=0.12; hits+=1
			apply_item_hit(enemy,kind,attack)
			if kind!="burn":
				enemy.knockX=cos(angle)*stats.distance/stats.duration; enemy.knockY=sin(angle)*stats.distance/stats.duration; enemy.knockTime=stats.duration
			enemy.route=[]; enemy.repath=0
			if enemy.health==0:
				enemy.phase="dead"; enemy.timer=0.6
				if alpha!=null and alpha.gameplay: alpha.enemy_defeated(enemy,self)
				if potion_drops: drop_potion(enemy)
				elif energy_enabled: restore_mana(4)
			break
	var effect: Dictionary = hit.duplicate()
	if has_loadout_skills(): effect.critical=attack.get("critical",false)
	effect.merge({"id":next_effect,"kind":kind,"remaining":0.15,"age":0.0,"damage":damage,"angle":angle,"damagePosition":damage_position})
	effects.append(effect); next_effect+=1

func update_enemies(seconds: float, protection_at_start: float, dodge_at_start: float) -> void:
	var groups: Array = layout.get("encounters",[])
	if encounter<groups.size():
		var inactive: bool = true
		for enemy in enemies:
			if enemy.group==encounter and enemy.phase!="inactive": inactive=false
		if inactive and encounter_ready(groups[encounter]):
			for enemy in enemies:
				if enemy.group==encounter: enemy.phase="chase"
	for enemy in enemies:
		if enemy.get("boss",false): continue
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
		if has_loadout_skills() and enemy.get("stopped",0.0)>0:
			enemy.stopped=maxf(0,enemy.stopped-seconds); continue
		var target: Dictionary = alpha.runtime.target(self,enemy) if has_loadout_skills() else player
		var rules: Dictionary = ENEMY_RULES[enemy.role] if gameplay else ENEMY_RULES.bird
		var ranged: bool = gameplay and enemy.role=="paper"
		var swing_until: float = -1.0
		if enemy.phase=="swing": swing_until=minf(seconds,enemy.timer)
		elif enemy.phase=="warn" and seconds>enemy.timer: swing_until=minf(seconds,enemy.timer+rules.swing)
		enemy.timer-=seconds
		var dx: float = target.x-enemy.x
		var dy: float = target.y-enemy.y
		var distance: float = sqrt(dx*dx+dy*dy)
		var toward: float = atan2(dy,dx)
		if enemy.phase=="chase":
			enemy.angle=toward
			if distance<=rules.range:
				enemy.phase="warn"; enemy.timer=rules.warn; enemy.struck=false
			elif not pushed:
				var destination: Variant = target
				enemy.repath-=seconds
				if not clear_path(enemy,target):
					if enemy.repath<=0:
						enemy.route=find_route(enemy,target); enemy.repath=0.35
					while enemy.route.size()>1 and clear_path(enemy,enemy.route[1]): enemy.route.pop_front()
					if not enemy.route.is_empty() and sqrt(pow(enemy.x-enemy.route[0].x,2)+pow(enemy.y-enemy.route[0].y,2))<3: enemy.route.pop_front()
					if enemy.route.is_empty(): continue
					destination=enemy.route[0]
				var goal_x: float = destination.x
				var goal_y: float = destination.y
				enemy.angle=atan2(goal_y-enemy.y,goal_x-enemy.x)
				var travel: float = minf(sqrt(pow(goal_x-enemy.x,2)+pow(goal_y-enemy.y,2)),rules.speed*(alpha.runtime.enemy_speed(self,enemy) if has_loadout_skills() else 1.0)*seconds)
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
			if enemy.phase=="warn" and enemy.timer<=0:
				if ranged:
					paper_arrows.append({"id":next_paper_arrow,"source":enemy.id,"x":enemy.x,"y":enemy.y,"angle":enemy.angle,"age":0.0,"initialStep":-enemy.timer})
					next_paper_arrow+=1
				enemy.phase="swing"; enemy.timer+=rules.swing
			if enemy.phase=="swing" and enemy.timer<=0: enemy.phase="recover"; enemy.timer+=rules.recover
			if enemy.phase=="recover" and enemy.timer<=0: enemy.phase="chase"; enemy.timer=0.0
		if not ranged and swing_until>=0 and not enemy.struck and distance<=rules.range and absf(angle_difference(enemy.angle,toward))<=PI/4 and (target.get("tomb",false) or protection_at_start<swing_until and dodge_at_start<swing_until and protection<=0):
			enemy.struck=true
			if target.get("tomb",false): alpha.runtime.hit_tomb(rules.damage)
			else: receive_hit(rules.damage)
			if health==0: return
	if encounter<groups.size():
		var cleared: bool = true
		for enemy in enemies:
			if enemy.group==encounter and enemy.phase!="dead": cleared=false
		if cleared:
			if energy_enabled and not potion_drops: restore_mana(12)
			encounter+=1
			if encounter==groups.size(): status="complete"

func encounter_ready(group: Dictionary) -> bool:
	return point(group).distance_to(Vector2(player.x,player.y))<=170

func cancel_pending() -> void:
	skill_dash_remaining=0
	if energy_enabled and pending_mana>0: mana=mini(100,mana+pending_mana)
	pending_mana=0
	windup=-1; piercing=-1; raining={}; attack_released=false; needs_release=false

func spend_energy(action: String) -> bool:
	if not energy_enabled: return true
	var cost: int = ENERGY_COSTS[action]
	if (stamina+0.000001<cost if action=="dodge" else mana<cost):
		feedback={"text":"精力不足" if action=="dodge" else "蓝量不足","remaining":0.8,"healed":false}
		return false
	if action=="dodge": stamina=maxf(0,stamina-cost); stamina_delay=1.2
	else: mana-=cost; pending_mana=cost
	return true

func restore_mana(amount: int) -> void:
	var restored: int = mini(amount,100-mana)
	mana+=restored
	if restored>0:
		var previous: int = int(feedback.get("mana",0))
		feedback={"text":"蓝量 +%d" % (previous+restored),"mana":previous+restored,"remaining":0.8,"healed":false}

func drop_potion(enemy: Dictionary) -> void:
	var last: bool = true
	for other in enemies:
		if other.group==enemy.group and other.phase!="dead": last=false; break
	var roll: float = drop_random.randf()
	var guaranteed: bool = last and not blue_waves.has(enemy.group)
	var kind: String = "mana" if guaranteed or roll<0.30 else "health" if roll<0.42 else ""
	if kind.is_empty(): return
	var location: Vector2 = potion_location(point(enemy))
	if kind=="mana": blue_waves[enemy.group]=true
	var id: String = "%s:%d:%d" % [layout.get("roomId","room"),run_id,enemy.id]
	drops.append({"id":id,"kind":kind,"x":location.x,"y":location.y,"wave":enemy.group,"enemy":enemy.id,"guaranteed":guaranteed})

func potion_location(origin: Vector2) -> Vector2:
	if can_walk(origin): return origin
	for radius in range(16,ceili(maxf(layout.width,layout.height)),16):
		for direction in 16:
			var location: Vector2 = origin+Vector2.from_angle(direction*TAU/16)*radius
			if can_walk(location) and not find_route(player,location).is_empty(): return location
	push_error("药瓶无合法落点："+str(origin))
	return origin

func nearest_potion() -> Dictionary:
	var closest: Dictionary = {}
	var distance: float = INF
	for item in drops:
		var location: Vector2 = point(item)
		var gap: float = point(player).distance_to(location)
		if gap>80 or not can_walk(location) or not clear_path(player,location): continue
		var reason: Variant = "影散后无法拾取" if status=="failed" else "暂停中无法拾取" if paused or reading else "生命已满" if item.kind=="health" and health==health_max else "蓝量已满" if item.kind=="mana" and mana==100 else null
		# 可用瓶优先；同距保留生成顺序，满值瓶仅作无其他目标时的提示。
		if not closest.is_empty() and (closest.reason==null and reason!=null or (closest.reason==null)==(reason==null) and gap>=distance): continue
		closest={"id":"potion:"+item.id,"dropId":item.id,"point":location,"label":"拾取血瓶" if item.kind=="health" else "拾取蓝瓶","reason":reason}
		distance=gap
	return closest

func cancel_input() -> void:
	special_held=[false,false]; beast_held=false
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
	var offsets: Array = SKILL_GRIPS.dodge if dodge_time>0 or skill_dash_remaining>0 else SKILL_GRIPS.rain if not raining.is_empty() else SKILL_GRIPS.pierce if piercing>=0 else layout.grips
	return Vector2(player.x,player.y)+point(offsets[player.facing])

func obstacles() -> Array:
	return layout.get("obstacles",[]).filter(func(item: Dictionary): return (item.kind!="gate" or not exploration.gateOpen) and encounter<=int(item.get("opensAfterEncounter",2147483647)))
func can_walk(position: Vector2) -> bool:
	return can_walk_xy(position.x,position.y)
func can_walk_xy(x: float,y: float) -> bool:
	if layout.has("walkablePolygons"):
		for offset in [Vector2.ZERO,Vector2(12,0),Vector2(-12,0),Vector2(0,12),Vector2(0,-12)]:
			var inside: bool = false
			for polygon in layout.walkablePolygons:
				if Geometry2D.is_point_in_polygon(Vector2(x,y)+offset,polygon): inside=true; break
			if not inside: return false
	elif layout.has("walkableAreas"):
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
		var center: Vector2 = point(from) if layout.has("walkablePolygons") and current==start else (Vector2(current)+Vector2.ONE*0.5)*32
		if sqrt(pow(center.x-to.x,2)+pow(center.y-to.y,2))<=48 and clear_path(center,to):
			# 终点保持玩家位置引用，与参照一致；路径有效期间玩家仍可移动。
			var result: Array = [to]
			while current!=start:
				result.append((Vector2(current)+Vector2.ONE*0.5)*32); current=previous[current]
			result.reverse(); return result
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+offset
			if next.x<0 or next.y<0 or next.x>=columns or next.y>=rows or previous.has(next): continue
			var next_point: Vector2 = (Vector2(next)+Vector2.ONE*0.5)*32
			if layout.has("walkablePolygons") and not clear_path(center,next_point): continue
			if can_walk(next_point): previous[next]=current; queue.append(next)
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
		if not item.get("blocksProjectiles",true): continue
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
	var potion: Dictionary = nearest_potion() if potion_drops else {}
	if not potion.is_empty() and potion.reason==null: return potion
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
	return potion
func interact() -> void:
	var target: Dictionary = nearest_interaction()
	if target.is_empty(): return
	if target.reason!=null: feedback={"text":target.reason,"remaining":1.6,"healed":false}; return
	if target.has("dropId"):
		for index in drops.size():
			var item: Dictionary = drops[index]
			if item.id!=target.dropId: continue
			var amount: int = mini(20,(health_max-health) if item.kind=="health" else (100-mana))
			if item.kind=="health": health+=amount
			else: mana+=amount
			feedback={"text":("生命" if item.kind=="health" else "蓝量")+" +%d" % amount,"remaining":1.2,"healed":item.kind=="health"}
			drops.remove_at(index)
			return
	if target.id=="stele":
		reading=true; exploration.steleRead=true; player.moving=false; dodge_time=0; dodge_invulnerability=0; cancel_pending(); needs_release=true
	elif target.id=="altar":
		if health==health_max: feedback={"text":"无需恢复","remaining":1.6,"healed":false}
		else:
			var amount: int = mini(40,health_max-health)
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
	var result: Dictionary = {"runId":run_id,"player":player.duplicate(),"grip":grip(),"hits":hits,"windup":windup if windup>=0 else null,"paused":paused or reading,"reading":reading,"gateOpening":gate_opening,"exploration":exploration.duplicate(),"interaction":nearest_interaction() if not nearest_interaction().is_empty() else null,"feedback":feedback.duplicate() if not feedback.is_empty() else null,"attack":attack_phase(),"health":health,"healthMax":health_max,"hurt":hurt,"protection":protection,"status":status,"dodge":dodge_time,"dodgeDirection":dodge_direction,"dodgeInvulnerability":dodge_invulnerability,"cooldowns":{"dodge":dodge_cooldown,"pierce":pierce_cooldown,"rain":rain_cooldown},"skill":skill,"rainPreview":raining.point if not raining.is_empty() else null,"rains":rains.duplicate(true),"invalid":invalid.duplicate() if not invalid.is_empty() else null,"encounter":encounter,"totalEncounters":layout.get("encounters",[]).size(),"enemies":visible_enemies,"arrows":arrows.duplicate(true),"effects":effects.duplicate(true),"targets":targets,"shots":shots}

	if gameplay: result.paperArrows=paper_arrows.duplicate(true)
	if has_loadout_skills():
		result.itemEffects=alpha.runtime.snapshot(self)
		result.cooldowns.merge(special_cooldowns)
		result.skillDash={"kind":skill_dash_kind,"remaining":skill_dash_remaining,"direction":skill_dash_direction}
		result.windPath=wind_path.duplicate(true)
		result.windExtraReady=wind_extra_ready()
		result.charge={"remaining":charge_remaining,"layers":charge_layers}
	if alpha!=null:
		result.alpha=alpha.snapshot()
		result.paused=result.paused or alpha.camp
	if energy_enabled:
		result.resources={"mana":mana,"stamina":stamina,"staminaDelay":stamina_delay,"pendingMana":pending_mana,"costs":ENERGY_COSTS.duplicate()}
	if potion_drops:
		result.drops=drops.duplicate(true)
	return result


func update_paper_arrows(seconds: float) -> void:
	var active: Array[Dictionary] = []
	for arrow in paper_arrows:
		var elapsed: float = minf(arrow.get("initialStep",seconds),1.5-arrow.age)
		arrow.erase("initialStep")
		var origin: Vector2 = Vector2(arrow.x,arrow.y)
		var target: Vector2 = origin+Vector2.from_angle(arrow.angle)*360*elapsed
		var contact_time: float = segment_rectangle(origin,target,Rect2(player.x-12,player.y-12,24,24))
		var decoy_hit: bool = false
		if has_loadout_skills() and alpha.runtime.active(self,alpha.runtime.tomb):
			var t: float = segment_rectangle(origin,target,Rect2(alpha.runtime.tomb.point-Vector2(14,14),Vector2(28,28)))
			if t>=0 and (contact_time<0 or t<contact_time): contact_time=t; decoy_hit=true
		var destination: Vector2 = origin.lerp(target,contact_time) if contact_time>=0 else target
		var ignored: Array = enemies.map(func(enemy: Dictionary): return enemy.id)
		if not contact(origin-Vector2(0,40),destination-Vector2(0,40),ignored).is_empty(): continue
		if contact_time>=0:
			if decoy_hit: alpha.runtime.hit_tomb(10)
			elif protection<=0 and dodge_invulnerability<=0: receive_hit(10)
			continue
		arrow.x=target.x; arrow.y=target.y; arrow.age+=elapsed
		if arrow.age<1.5-0.000001: active.append(arrow)
	paper_arrows=active


func receive_hit(amount: int) -> int:
	var damage: int = mini(health,maxi(0,roundi(amount*(0.9 if has_loadout_skills() and alpha.active_pact("涂炭") else 1.0))))
	if damage==0: return 0
	health-=damage; hurt=0.12; protection=0.6; cancel_pending(); needs_release=true
	if gameplay:
		effects.append({"id":next_effect,"kind":"hurt","remaining":0.15,"age":0.0,"x":player.x,"y":player.y-40,"enemy":null,"angle":0.0,"damage":damage,"damagePosition":Vector2(player.x,player.y)})
		next_effect+=1
	if health==0:
		status="failed"; player.moving=false; clear_skill_effects()
	return damage

func has_loadout_skills() -> bool:
	return alpha!=null and alpha.gameplay

func skill_aim(input: Dictionary) -> Vector2:
	var delta: Vector2 = point(input.get("aim",Vector2(player.x+100,player.y-layout.shoulderHeight)))-Vector2(player.x,player.y-layout.shoulderHeight)
	return delta.normalized() if delta.length()>0.001 else Vector2.from_angle(player.angle)

func spend_instant(kind: String) -> bool:
	if energy_enabled and mini(100,mana+pending_mana)<ENERGY_COSTS[kind]:
		feedback={"text":"蓝量不足","remaining":0.8,"healed":false}; return false
	cancel_pending()
	if energy_enabled: mana-=ENERGY_COSTS[kind]
	return true

func start_skill_dash(kind: String, direction: Vector2, pay: bool = true) -> bool:
	if skill_dash_remaining>0: return false
	var origin: Vector2 = point(player)
	if not ((absf(direction.x)>0.001 and can_walk(origin+Vector2(direction.x*2,0))) or (absf(direction.y)>0.001 and can_walk(origin+Vector2(0,direction.y*2)))):
		feedback={"text":"无合法位移，不扣蓝或冷却","remaining":0.8,"healed":false}; return false
	if pay:
		if not spend_instant(kind): return false
	else: cancel_pending()
	skill_dash_kind=kind; skill_dash_direction=direction; skill_dash_remaining=0.2
	return true

func cast_wind(input: Dictionary, movement: Vector2) -> bool:
	var beast: bool = alpha.items.any(func(item: Dictionary): return item.name=="青龙" and item.region=="equipment" and item.state=="normal" and not item.get("shadow",false))
	var book: bool = alpha.items.any(func(item: Dictionary): return item.name=="引风书" and item.region=="meridian" and item.state=="normal")
	if not beast or not book: return false
	var direction: Vector2 = movement.normalized() if movement.length()>0 else skill_aim(input)
	if special_cooldowns.wind<=0:
		var origin: Vector2 = point(player)
		if not start_skill_dash("wind",direction): return false
		special_cooldowns.wind=8.0
		wind_path={"from":origin,"to":origin,"remaining":3.0,"extra":1,"width":40.0,"points":[origin]}
		return true
	if not wind_extra_ready(): return false
	if not start_skill_dash("wind_extra",direction,false): return false
	wind_path.extra=0
	return true

func wind_extra_ready() -> bool:
	if status=="failed" or health<=0 or wind_path.is_empty() or wind_path.extra<=0 or skill_dash_remaining>0: return false
	for index in range(1,wind_path.points.size()):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point(player),wind_path.points[index-1],wind_path.points[index])
		if point(player).distance_to(nearest)<=20.000001: return true
	return false

func clear_skill_effects() -> void:
	charge_layers=0; charge_remaining=0; skill_dash_remaining=0; wind_path={}
	if has_loadout_skills(): alpha.runtime.clear()

func refresh_item_stats() -> void:
	if not has_loadout_skills(): return
	health_max=alpha.max_health(); health=mini(health,health_max)

func damage_multiplier(kind: String, attack: Dictionary) -> float:
	if not has_loadout_skills() or kind=="burn": return 1.0
	return attack.get("chargeMultiplier",1.0)*attack.get("criticalMultiplier",1.0)*attack.get("pactMultiplier",alpha.attack_bonus())

func apply_item_hit(enemy: Dictionary, kind: String, attack: Dictionary) -> void:
	if not has_loadout_skills() or kind not in ["normal","pierce"] or enemy.health<=0: return
	if attack.get("applyBurn",false) and alpha.applied_equipment.effects.has("燧火"):
		if enemy.get("burnRemaining",0.0)<=0: enemy.burnTick=0.0
		enemy.burnRemaining=3.0
