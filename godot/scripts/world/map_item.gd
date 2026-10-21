@tool
class_name MapItem
extends Node2D

@export_enum("road","obstacle","spawn","encounter","enemy","interaction","pillar","route","ground") var category: String = "road":
	set(value): category=value; layout_changed()
@export var size: Vector2 = Vector2(100,100):
	set(value): size=value; layout_changed()
@export var body_height: float = 100.0
@export_enum("tree","root","wall","gate","stele","altar","brazier","waystone") var obstacle_kind: String = "wall"
@export var label: String = ""
@export var region: String = "汤谷"
@export_enum("path","stone") var terrain_material: String = "path"
@export var priority: int = 0
@export_enum("bird","paper","wood") var appearance: String = "bird"
@export_enum("stele","altar","gate") var interaction_id: String = "stele"
@export var marker_offset_y: float = NAN
@export var opens_after_encounter: int = -1

func layout_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var color: Color = Color(0.35,0.75,0.45,0.35) if category=="road" else Color(0.85,0.4,0.25,0.55) if category=="obstacle" else Color(0.3,0.65,1,0.8)
	if category in ["road","obstacle","ground"]:
		draw_rect(Rect2(-size/2,size),color)
		draw_rect(Rect2(-size/2,size),Color(color,1),false,2)
	else:
		draw_circle(Vector2.ZERO,14,color)
		if category=="encounter": draw_arc(Vector2.ZERO,170,0,TAU,48,color,2)
	draw_string(ThemeDB.fallback_font,Vector2(16,-12),label if not label.is_empty() else name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
