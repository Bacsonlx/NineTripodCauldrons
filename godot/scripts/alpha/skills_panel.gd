extends VBoxContainer

var summary: Label

func setup(room: TrainingRoom) -> void:
	if summary!=null: return
	var title: Label = Label.new(); title.text="技能来源 · 穿戴即获得"; add_child(title)
	summary=Label.new(); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(summary)
	refresh(room.snapshot())

func refresh(snapshot: Dictionary) -> void:
	var alpha: Dictionary = snapshot.get("alpha",{})
	visible=alpha.get("camp",false) and alpha.has("skills")
	if not visible: return
	var lines: PackedStringArray = ["左键普攻、空格闪避为人物基础操作；主动技能无须另行启用。"]
	for kind in alpha.skills:
		var skill: Dictionary = alpha.skills[kind]
		lines.append("%s %s 来源 %s · %s" % [skill.key,skill.name,skill.source,"已获得" if skill.active else skill.reason])
	summary.text="\n".join(lines)
