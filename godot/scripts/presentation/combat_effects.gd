extends Node2D

var atlas: Dictionary
var texture: Texture2D
var stamps: Array[Sprite2D] = []
var used: int = 0
var run_id: int = -1
var last_impact: int = -1
var bursts: Array[Dictionary] = []
var damage: Array[Dictionary] = []
var labels: Array[Label] = []
var trails: Dictionary = {}
var ghosts: Array[Dictionary] = []
var ghost_timer: float = 0.0
var was_dodging: bool = false
var lower: Sprite2D
var upper: Sprite2D

func setup(frames: Dictionary,image: Texture2D,legs: Sprite2D,torso: Sprite2D) -> void:
	atlas=frames; texture=image; lower=legs; upper=torso
	for index in 4:
		var pair: Dictionary = {"age":1.0,"lower":Sprite2D.new(),"upper":Sprite2D.new()}
		for key in ["lower","upper"]: add_child(pair[key]); pair[key].visible=false
		ghosts.append(pair)

func stamp(frame_name: String,position: Vector2,size: Vector2,alpha: float,angle: float = 0.0,depth: int = 4000) -> void:
	if used>=512: return
	if used==stamps.size():
		var body: Sprite2D = Sprite2D.new()
		body.texture=texture; body.region_enabled=true; add_child(body); stamps.append(body)
	var body: Sprite2D = stamps[used]
	used+=1
	var frame: Dictionary = atlas[frame_name]
	body.region_rect=Rect2(frame.x,frame.y,frame.width,frame.height)
	body.position=position; body.scale=size/Vector2(frame.width,frame.height)
	body.modulate=Color(1,1,1,alpha); body.rotation=angle; body.z_index=depth; body.visible=true

func falling(position: Vector2,progress: float) -> void:
	for index in 10:
		var angle: float = index*2.39996
		var radius: float = 18+sqrt(index/10.0)*76
		var height: float = (1-progress*progress)*210
		stamp("streak",position+Vector2(cos(angle)*radius-height*0.17,sin(angle)*radius-height-16),Vector2(68,10),0.85,PI/2-0.17)

func update(state: Dictionary,seconds: float,clock: float) -> void:
	var dt: float = 0.0 if state.paused or state.status=="failed" else seconds
	used=0
	if run_id!=state.runId:
		run_id=state.runId; last_impact=-1; bursts.clear(); damage.clear(); trails.clear(); was_dodging=false; ghost_timer=0
		for ghost in ghosts: ghost.age=1; ghost.lower.visible=false; ghost.upper.visible=false
	var live_bursts: Array[Dictionary] = []
	for burst in bursts:
		burst.age+=dt
		if burst.age<(0.3 if burst.kind=="dust" else 0.32): live_bursts.append(burst)
	bursts=live_bursts
	for number in damage: number.age+=dt
	for hit in state.effects:
		if hit.id<=last_impact: continue
		var killed: bool = false
		if hit.get("enemy")!=null:
			for enemy in state.enemies:
				if enemy.id==hit.enemy and enemy.health==0: killed=true
		bursts.append({"x":hit.x,"y":hit.y,"kind":hit.kind,"age":0.0,"enemy":hit.get("enemy"),"angle":hit.angle,"killed":killed})
		if bursts.size()>64: bursts.pop_front()
		if hit.has("enemy") and hit.damage>0 and hit.damagePosition!=null:
			var stack: int = 0
			var slot: int = -1
			for index in damage.size():
				if damage[index].enemy==hit.enemy and damage[index].age<0.65: stack+=1
				if damage[index].age>=0.65 and slot<0: slot=index
			if slot<0 and damage.size()<32:
				slot=damage.size(); damage.append({})
			if slot<0:
				slot=0
				for index in damage.size():
					if damage[index].age>damage[slot].age: slot=index
			damage[slot]={"age":0.0,"enemy":hit.enemy,"damage":hit.damage,"kind":hit.kind,"position":hit.damagePosition+Vector2(14 if stack%2 else -8,-100-(stack%3)*16)}
		last_impact=hit.id
	for arrow in state.arrows:
		if trails.has(arrow.id): continue
		trails[arrow.id]=[]
		if arrow.kind=="pierce":
			var origin: Vector2 = Vector2(arrow.x,arrow.y)-Vector2.from_angle(arrow.angle)*900*arrow.age
			bursts.append({"x":origin.x,"y":origin.y,"kind":"launch","age":0.0,"enemy":null,"angle":arrow.angle})
	for label in labels: label.visible=false
	for index in damage.size():
		var number: Dictionary = damage[index]
		if number.age>=0.65: continue
		if index==labels.size():
			var label: Label = Label.new()
			label.add_theme_font_size_override("font_size",24); label.add_theme_constant_override("outline_size",4); label.add_theme_color_override("font_outline_color",Color("241c17"))
			label.z_index=4090; add_child(label); labels.append(label)
		var progress: float = number.age/0.65
		var label: Label = labels[index]
		var eased: float = 1-pow(1-progress,3)
		label.text=str(number.damage); label.position=number.position-Vector2(0,44*eased); label.visible=true
		label.modulate=Color("ffe5a0" if number.kind=="pierce" else "f6e8cd"); label.modulate.a=minf(1,(1-progress)*3); label.scale=Vector2.ONE*(1+0.5*pow(maxf(0,1-progress/0.24),2))
	for burst in bursts:
		var progress: float = burst.age/(0.3 if burst.kind=="dust" else 0.32)
		var spread: float = 1-pow(1-progress,3)
		var alpha: float = 1-progress
		var position: Vector2 = Vector2(burst.x,burst.y)
		if burst.kind=="dust": stamp("dust",position+Vector2(0,3),Vector2(30+progress*35,15+progress*12),alpha*0.26,0,3); continue
		if burst.kind=="launch":
			stamp("halo",position,Vector2.ONE*(60+spread*64),alpha*alpha*0.45,burst.angle)
			stamp("streak",position+Vector2.from_angle(burst.angle)*spread*24,Vector2(100+spread*40,20*alpha),alpha*0.75,burst.angle)
			continue
		var strong: bool = burst.kind=="pierce"
		var size: float = 1.6 if burst.enemy!=null else 1.0
		stamp("spark",position,Vector2.ONE*((52 if strong else 40)+spread*28)*size,alpha*alpha*0.9,burst.age*2)
		for index in 5:
			var angle: float = burst.angle+(index-2)*0.9
			stamp("shards",position+Vector2.from_angle(angle)*(8+spread*(52 if strong else 36))+Vector2(0,progress*16),Vector2(15,10)*alpha,alpha*0.8,angle+progress)
		if burst.enemy!=null:
			stamp("halo",position,Vector2.ONE*(38+spread*(96 if strong else 68)),alpha*alpha*0.55)
			stamp("streak",position,Vector2((120 if strong else 78)+spread*30,14*alpha),alpha*0.9,burst.angle)
			stamp("streak",position,Vector2(16*alpha,64+spread*24),alpha*0.8,burst.angle)
			if burst.get("killed",false):
				stamp("ring",position,Vector2.ONE*(46+spread*130),alpha*alpha*0.55,progress*0.6)
			for index in 5:
				var angle: float = burst.angle+(index-2)*0.48
				stamp("embers",position+Vector2(cos(angle),sin(angle))*(9+spread*(82 if strong else 54))+Vector2(0,progress*14),Vector2.ONE*(11-index*0.7)*alpha,alpha*0.9,angle)
	var active: Dictionary = {}
	for arrow in state.arrows:
		active[arrow.id]=true
		var trail: Array = trails[arrow.id]
		var position: Vector2 = Vector2(arrow.x,arrow.y)
		if dt>0 and (trail.is_empty() or position.distance_to(trail.back())>7):
			trail.append(position)
			if trail.size()>(8 if arrow.kind=="pierce" else 4): trail.pop_front()
		for index in range(1,trail.size()):
			stamp("feather",(trail[index-1]+trail[index])/2,Vector2(trail[index-1].distance_to(trail[index])+16,26 if arrow.kind=="pierce" else 9),float(index)/trail.size()*(0.8 if arrow.kind=="pierce" else 0.4),arrow.angle)
		stamp("streak",position-Vector2.from_angle(arrow.angle)*18,Vector2(142,27) if arrow.kind=="pierce" else Vector2(42,8),0.85 if arrow.kind=="pierce" else 0.6,arrow.angle)
	for id in trails.keys():
		if not active.has(id): trails.erase(id)
	var charging: bool = state.windup!=null or (state.skill!=null and state.skill.phase=="windup" and state.skill.kind=="pierce")
	if charging:
		var strong: bool = state.skill!=null and state.skill.kind=="pierce"
		var progress: float = 1-(state.skill.remaining/0.18 if strong else state.windup/0.08)
		stamp("halo",state.grip,Vector2.ONE*((58 if strong else 16)+progress*(64 if strong else 16)),0.25+progress*0.4,clock*0.6)
		if strong:
			for index in 6:
				stamp("embers",state.grip+Vector2.from_angle(index*TAU/6+clock*2.5)*(48*(1-progress)+12),Vector2(14,9),0.7,index*TAU/6+clock*2.5)
	if state.attack=="release": stamp("spark",state.grip,Vector2(17,17),0.45,state.player.angle)
	if state.rainPreview!=null:
		var charge: float = clampf(1-state.skill.remaining/0.45,0,1)
		stamp("ring",state.rainPreview,Vector2.ONE*220,0.22+charge*0.2,clock*0.3,2)
		stamp("halo",state.rainPreview,Vector2.ONE*(280-charge*60),0.12+charge*0.12,-clock*0.6,2)
		for index in 6:
			var angle: float = index*TAU/6+clock*0.8
			stamp("embers",state.rainPreview+Vector2.from_angle(angle)*(140-charge*42),Vector2(18,8),0.45,angle)
		if state.skill.remaining<=0.16: falling(state.rainPreview,1-state.skill.remaining/0.16)
	for rain in state.rains:
		var position: Vector2 = Vector2(rain.x,rain.y)
		for pulse in 3:
			var until: float = pulse*0.18-rain.age
			if pulse>0 and until>0 and until<=0.16: falling(position,1-until/0.16)
			var age: float = rain.age-pulse*0.18
			if age>=0 and age<0.18:
				var progress: float = age/0.18
				var spread: float = 1-pow(1-progress,3)
				stamp("ring",position,Vector2.ONE*(90+spread*130),(1-progress)*0.65,0,2)
				stamp("halo",position,Vector2.ONE*(160+spread*120),pow(1-progress,2)*0.2,0,2)
				for index in 10:
					stamp("spark",position+Vector2.from_angle(index*2.39996)*(20+sqrt(index/10.0)*75),Vector2.ONE*(34-14*progress),(1-progress)*0.65,index*2.39996)
	var dodging: bool = state.dodge>0
	if dt>0:
		ghost_timer+=dt
		if dodging!=was_dodging: bursts.append({"x":state.player.x,"y":state.player.y,"kind":"dust","age":0.0,"enemy":null,"angle":0.0})
		for ghost in ghosts: ghost.age+=dt
		if dodging and ghost_timer>=0.035:
			var oldest: Dictionary = ghosts[0]
			for ghost in ghosts:
				if ghost.age>oldest.age: oldest=ghost
			oldest.age=0; ghost_timer=0
			for pair in [[oldest.lower,lower],[oldest.upper,upper]]:
				var copy: Sprite2D = pair[0]
				var body: Sprite2D = pair[1]
				copy.texture=body.texture; copy.region_enabled=true; copy.region_rect=body.region_rect; copy.centered=body.centered; copy.offset=body.offset; copy.position=body.position; copy.scale=body.scale; copy.z_index=int(state.player.y)-1
		was_dodging=dodging
	for ghost in ghosts:
		for key in ["lower","upper"]:
			ghost[key].visible=ghost.age<0.22
			ghost[key].modulate=Color(0.8,0.65,0.32,pow(maxf(0,1-ghost.age/0.22),2)*0.5)
	# 下一波的地面预告不代表已激活敌人，也不参与碰撞。
	if state.get("waveDelay",0)>0:
		for enemy in state.enemies:
			if enemy.group==state.encounter and enemy.phase=="inactive":
				var progress: float = 1-state.waveDelay/1.2
				stamp("ring",Vector2(enemy.x,enemy.y),Vector2(64,32)*(1.2-progress*0.2),0.3+progress*0.3,0,2)
				stamp("embers",Vector2(enemy.x,enemy.y-16),Vector2(16,24)*(0.7+progress*0.3),0.4+progress*0.3,0,2)
	for index in range(used,stamps.size()): stamps[index].visible=false
