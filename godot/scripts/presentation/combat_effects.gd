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
		var height: float = (1-progress)*140
		stamp("streak",position+Vector2(cos(angle)*radius-height*0.17,sin(angle)*radius-height-16),Vector2(42,6),0.72,PI/2-0.17)

func update(state: Dictionary,seconds: float,clock: float) -> void:
	var dt: float = 0.0 if state.paused or state.status=="failed" else seconds
	used=0
	if run_id!=state.runId:
		run_id=state.runId; last_impact=-1; bursts.clear(); damage.clear(); trails.clear(); was_dodging=false; ghost_timer=0
		for ghost in ghosts: ghost.age=1; ghost.lower.visible=false; ghost.upper.visible=false
	var live_bursts: Array[Dictionary] = []
	for burst in bursts:
		burst.age+=dt
		if burst.age<(0.3 if burst.kind=="dust" else 0.24): live_bursts.append(burst)
	bursts=live_bursts
	for number in damage: number.age+=dt
	for hit in state.effects:
		if hit.id<=last_impact: continue
		bursts.append({"x":hit.x,"y":hit.y,"kind":hit.kind,"age":0.0,"enemy":hit.get("enemy"),"angle":hit.angle})
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
		label.text=str(number.damage); label.position=number.position-Vector2(0,30*progress); label.visible=true
		label.modulate=Color("ffe5a0" if number.kind=="pierce" else "f6e8cd"); label.modulate.a=minf(1,(1-progress)*3); label.scale=Vector2.ONE*(1+0.22*maxf(0,1-progress/0.2))
	for burst in bursts:
		var progress: float = burst.age/(0.3 if burst.kind=="dust" else 0.24)
		var alpha: float = 1-progress
		var position: Vector2 = Vector2(burst.x,burst.y)
		if burst.kind=="dust": stamp("dust",position+Vector2(0,3),Vector2(30+progress*35,15+progress*12),alpha*0.26,0,3); continue
		var strong: bool = burst.kind=="pierce"
		stamp("spark",position,Vector2.ONE*((39 if strong else 25)+progress*17),alpha*0.8,burst.age*2)
		for index in 3:
			var angle: float = index*2.1+0.4
			stamp("shards",position+Vector2(cos(angle),sin(angle))*(8+progress*(30 if strong else 20))+Vector2(0,progress*6),Vector2(12,12),alpha*0.72,angle)
		if burst.enemy!=null:
			stamp("halo",position,Vector2.ONE*(18+progress*42),alpha*alpha*0.48)
			stamp("streak",position,Vector2((60 if strong else 38)+progress*20,8),alpha*0.9,burst.angle)
			stamp("streak",position,Vector2(12,30+progress*12),alpha*0.75,burst.angle)
			for index in 5:
				var angle: float = burst.angle+(index-2)*0.48
				stamp("embers",position+Vector2(cos(angle),sin(angle))*(9+progress*(52 if strong else 34))+Vector2(0,progress*8),Vector2.ONE*(8-index*0.6),alpha*0.85,angle)
	var active: Dictionary = {}
	for arrow in state.arrows:
		active[arrow.id]=true
		if not trails.has(arrow.id): trails[arrow.id]=[]
		var trail: Array = trails[arrow.id]
		var position: Vector2 = Vector2(arrow.x,arrow.y)
		if dt>0 and (trail.is_empty() or position.distance_to(trail.back())>7):
			trail.append(position)
			if trail.size()>(8 if arrow.kind=="pierce" else 4): trail.pop_front()
		for index in range(1,trail.size()):
			stamp("feather",(trail[index-1]+trail[index])/2,Vector2(trail[index-1].distance_to(trail[index])+10,15 if arrow.kind=="pierce" else 7),float(index)/trail.size()*(0.7 if arrow.kind=="pierce" else 0.3),arrow.angle)
		stamp("streak",position-Vector2.from_angle(arrow.angle)*18,Vector2(78,15) if arrow.kind=="pierce" else Vector2(32,6),0.8 if arrow.kind=="pierce" else 0.6,arrow.angle)
	for id in trails.keys():
		if not active.has(id): trails.erase(id)
	var charging: bool = state.windup!=null or (state.skill!=null and state.skill.phase=="windup" and state.skill.kind=="pierce")
	if charging:
		var strong: bool = state.skill!=null and state.skill.kind=="pierce"
		var progress: float = 1-(state.skill.remaining/0.18 if strong else state.windup/0.08)
		stamp("halo",state.grip,Vector2.ONE*((28 if strong else 12)+progress*(30 if strong else 13)),0.25+progress*0.4,clock*0.6)
		if strong:
			for index in 4:
				stamp("embers",state.grip+Vector2.from_angle(index*PI/2+clock*1.7)*(23*(1-progress)+9),Vector2(9,9),0.5)
	if state.attack=="release": stamp("spark",state.grip,Vector2(17,17),0.45,state.player.angle)
	if state.rainPreview!=null:
		stamp("ring",state.rainPreview,Vector2.ONE*220,0.14+(1-state.skill.remaining/0.45)*0.16,clock*0.15,2)
		if state.skill.remaining<=0.16: falling(state.rainPreview,1-state.skill.remaining/0.16)
	for rain in state.rains:
		var position: Vector2 = Vector2(rain.x,rain.y)
		for pulse in 3:
			var until: float = pulse*0.18-rain.age
			if pulse>0 and until>0 and until<=0.16: falling(position,1-until/0.16)
			var age: float = rain.age-pulse*0.18
			if age>=0 and age<0.18:
				var progress: float = age/0.18
				stamp("ring",position,Vector2.ONE*(110+progress*110),(1-progress)*0.42,0,2)
				for index in 6:
					stamp("spark",position+Vector2.from_angle(index*2.39996)*(20+sqrt(index/6.0)*65),Vector2(18,18),(1-progress)*0.45,index*2.39996)
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
			ghost[key].visible=ghost.age<0.16
			ghost[key].modulate=Color(0.56,0.5,0.33,maxf(0,1-ghost.age/0.16)*0.34)
	for index in range(used,stamps.size()): stamps[index].visible=false
