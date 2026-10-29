extends RefCounted

const OPPOSITE: Dictionary = {"金":"火","火":"金","木":"雷","雷":"木","水":"土","土":"水","塔":"场","场":"塔","草":"镜","镜":"草"}
const BASE: Dictionary = {"残":1,"常":1,"良":2,"珍":3,"异":4,"凡":1,"精":1,"仙":2,"神":3,"专属":4}

static func cells(item: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = Vector2i(item.size.y,item.size.x) if item.rotated else item.size
	for x in size.x:
		for y in size.y: result.append(item.cell+Vector2i(x,y))
	return result

static func choose(candidates: Array, previous: String, earliest: Dictionary) -> String:
	if candidates.has(previous): return previous
	var result: String = ""
	for candidate in candidates:
		if result.is_empty() or earliest[candidate]<earliest[result]: result=candidate
	return result

static func calculate(items: Array[Dictionary], previous: Dictionary) -> Dictionary:
	var aura: Array[Vector2i] = []
	for item in items:
		if item.kind=="神兽" and item.region=="equipment":
			for x in range(item.cell.x-1,item.cell.x+3):
				for y in range(item.cell.y-1,item.cell.y+3):
					var cell: Vector2i = Vector2i(x,y)
					if not cells(item).has(cell): aura.append(cell)
	var totals: Dictionary = {}
	var earliest: Dictionary = {}
	var earliest_eligible: Dictionary = {}
	for key in OPPOSITE: totals[key]=0; earliest[key]=2147483647; earliest_eligible[key]=2147483647
	var records: Array[Dictionary] = []
	for item in items:
		if item.region!="altar": continue
		var eligible: bool = (item.kind!="装备" or item.get("mainGlyph",false)) and OPPOSITE.has(item.container) and item.kind!="神兽" and item.state=="normal" and item.get("eligible",true)
		var weighted: bool = false
		if eligible and item.container=="木":
			for cell in cells(item):
				if aura.has(cell): weighted=true; break
		var base: int = 1 if item.get("shadow",false) else BASE.get(item.quality,0)
		var multiplier: float = (2.0 if weighted else 1.0)*item.get("fixture_multiplier",1.0)
		var points: int = int(floor(base*multiplier)) if eligible else 0
		records.append({"id":item.id,"container":item.container,"base":base,"multiplier":multiplier,"weighted":points,"opposition":0,"total":points,"eligible":eligible,"aura":weighted,"order":item.order,"cells":cells(item)})
		if OPPOSITE.has(item.container): earliest[item.container]=mini(earliest[item.container],item.order)
		if eligible: earliest_eligible[item.container]=mini(earliest_eligible[item.container],item.order)
	for i in records.size():
		for j in range(i+1,records.size()):
			var first: Dictionary = records[i]
			var second: Dictionary = records[j]
			if not first.eligible or not second.eligible or OPPOSITE[first.container]!=second.container: continue
			var adjacent: bool = false
			for a in first.cells:
				for b in second.cells:
					if absi(a.x-b.x)+absi(a.y-b.y)==1: adjacent=true; break
				if adjacent: break
			if adjacent: first.opposition+=1; second.opposition+=1
	var highest: int = 0
	for record in records:
		record.total=maxi(0,record.total-record.opposition)
		if record.eligible: totals[record.container]+=record.total; highest=maxi(highest,totals[record.container])
	var winner: String = ""
	var harm: String = ""
	var reason: String = "全零票，显灵／作祟停止"
	if highest>0:
		var leaders: Array = []
		for key in totals:
			if totals[key]==highest: leaders.append(key)
		winner=choose(leaders,previous.get("winner",""),earliest)
		var second_points: int = 0
		for key in totals:
			if key!=winner: second_points=maxi(second_points,totals[key])
		if leaders.size()>1 or second_points==0:
			harm=OPPOSITE[winner]; reason="最高并列／无正票第二，由对冲补位"
		else:
			var seconds: Array = []
			for key in totals:
				if key!=winner and totals[key]==second_points: seconds.append(key)
			harm=choose(seconds,previous.get("harm",""),earliest_eligible); reason="第一显灵、正票第二作祟"
	var sealed: Array[Vector2i] = []
	if harm=="金": sealed.assign([Vector2i(6,0),Vector2i(7,0)])
	return {"votes":totals,"breakdown":records,"winner":winner,"harm":harm,"reason":reason,"sealed":sealed,"auraCells":aura}
