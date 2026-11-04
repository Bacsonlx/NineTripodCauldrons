@tool
extends Node2D

const BEAST_BASE_COLORS: Dictionary = {
	"青龙": Color("78d6e2"),
	"白虎": Color("eef7f2"),
	"朱雀": Color("c82d24")
}
const NIGHT_STONE: Color = Color("25332d")

@export_enum("beast", "tier") var layer: String = "beast":
	set(value):
		layer = value
		queue_redraw()

var blessing_beast: String = ""
var blessing_tier: int = 0
var sealed: bool = true
var hovered: bool = false
var usable: bool = false

func configure(beast: String, tier: int, is_sealed: bool, is_hovered: bool, is_usable: bool) -> void:
	blessing_beast = beast
	blessing_tier = clampi(tier, 0, 3)
	sealed = is_sealed
	hovered = is_hovered
	usable = is_usable
	queue_redraw()

func matches_blessing(beast: String, tier: int) -> bool:
	return blessing_beast == beast and blessing_tier == clampi(tier, 0, 3)

func theme_key() -> Dictionary:
	return {
		"beast": blessing_beast,
		"tier": blessing_tier,
		"baseColor": BEAST_BASE_COLORS.get(blessing_beast, Color("d4c8a5")),
		"color": theme_color(),
		"layer": layer
	}

func theme_color() -> Color:
	var base: Color = BEAST_BASE_COLORS.get(blessing_beast, Color("d4c8a5"))
	return base.lerp(NIGHT_STONE, 0.18)

func _draw() -> void:
	if blessing_beast.is_empty() or blessing_tier <= 0:
		return
	var tone: Color = theme_color()
	tone.a = (0.42 if sealed else 0.70) + (0.16 if hovered else 0.0) + (0.08 if usable else 0.0)
	var outline: Color = Color("101812")
	outline.a = tone.a * 0.88
	if layer == "beast":
		_draw_beast_pattern(tone, outline)
	else:
		_draw_tier_overlay(tone, outline)

func _draw_beast_pattern(tone: Color, outline: Color) -> void:
	match blessing_beast:
		"青龙": _draw_dragon(tone, outline)
		"白虎": _draw_tiger(tone, outline)
		"朱雀": _draw_phoenix(tone, outline)

func _draw_dragon(tone: Color, outline: Color) -> void:
	var points := PackedVector2Array([
		Vector2(-48, -165), Vector2(-30, -185), Vector2(-3, -193), Vector2(25, -184),
		Vector2(41, -164), Vector2(28, -145), Vector2(4, -139), Vector2(-16, -148),
		Vector2(-28, -164), Vector2(-15, -176), Vector2(4, -171)
	])
	draw_polyline(points, outline, 7.0, true)
	draw_polyline(points, tone, 3.2, true)
	var head := PackedVector2Array([Vector2(25, -184), Vector2(48, -190), Vector2(39, -174)])
	draw_colored_polygon(head, outline)
	draw_colored_polygon(PackedVector2Array([Vector2(27, -184), Vector2(44, -188), Vector2(38, -177)]), tone)
	draw_line(Vector2(-48, -165), Vector2(-59, -177), outline, 6.0, true)
	draw_line(Vector2(-48, -165), Vector2(-59, -177), tone, 2.4, true)

func _draw_tiger(tone: Color, outline: Color) -> void:
	var head := PackedVector2Array([Vector2(-17, -194), Vector2(17, -194), Vector2(25, -167), Vector2(0, -146), Vector2(-25, -167)])
	draw_colored_polygon(head, outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -190), Vector2(14, -190), Vector2(19, -168), Vector2(0, -151), Vector2(-19, -168)]), tone)
	for x in [-14.0, 0.0, 14.0]:
		draw_line(Vector2(x - 4.0, -188), Vector2(x + 3.0, -174), outline, 5.0, true)
		draw_line(Vector2(x - 4.0, -188), Vector2(x + 3.0, -174), tone, 2.0, true)
	for side in [-1.0, 1.0]:
		var stripe := PackedVector2Array([Vector2(side * 24, -183), Vector2(side * 42, -170), Vector2(side * 25, -158)])
		draw_polyline(stripe, outline, 6.0, true)
		draw_polyline(stripe, tone, 2.4, true)

func _draw_phoenix(tone: Color, outline: Color) -> void:
	var body := PackedVector2Array([Vector2(0, -199), Vector2(13, -177), Vector2(8, -151), Vector2(0, -140), Vector2(-8, -151), Vector2(-13, -177)])
	draw_colored_polygon(body, outline)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -194), Vector2(8, -176), Vector2(5, -153), Vector2(0, -146), Vector2(-5, -153), Vector2(-8, -176)]), tone)
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side * 8, -181), Vector2(side * 36, -197), Vector2(side * 54, -176), Vector2(side * 31, -181), Vector2(side * 18, -160)])
		draw_polyline(wing, outline, 8.0, true)
		draw_polyline(wing, tone, 3.0, true)
	var crest := PackedVector2Array([Vector2(-5, -194), Vector2(-18, -211), Vector2(0, -202), Vector2(18, -211), Vector2(5, -194)])
	draw_polyline(crest, outline, 6.0, true)
	draw_polyline(crest, tone, 2.3, true)

func _draw_tier_overlay(tone: Color, outline: Color) -> void:
	# 两侧刻痕把“念级”变成远近都能读的密度，而不依赖文字。
	for index in blessing_tier:
		var y: float = -118.0 + float(index) * 18.0
		for side in [-1.0, 1.0]:
			var center := Vector2(side * 61.0, y)
			var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)])
			draw_colored_polygon(diamond, outline)
			var inset := PackedVector2Array([center + Vector2(0, -3), center + Vector2(3, 0), center + Vector2(0, 3), center + Vector2(-3, 0)])
			draw_colored_polygon(inset, tone)
	var ring_radius: float = 24.0 + float(blessing_tier) * 5.0
	draw_arc(Vector2(0, -170), ring_radius, -PI * 0.78, -PI * 0.22, 18, outline, 5.0, true)
	draw_arc(Vector2(0, -170), ring_radius, -PI * 0.78, -PI * 0.22, 18, tone, 2.0, true)
	if sealed:
		draw_line(Vector2(-31, -171), Vector2(31, -171), outline, 5.0, true)
		draw_line(Vector2(-31, -171), Vector2(31, -171), Color("c7b99a", tone.a * 0.72), 2.0, true)
	if hovered:
		var hover_color: Color = tone
		hover_color.a = minf(1.0, tone.a + 0.12)
		draw_arc(Vector2(0, -170), ring_radius + 9.0, -PI, 0.0, 24, hover_color, 2.5 if usable else 1.5, true)
