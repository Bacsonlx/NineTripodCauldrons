@tool
extends Sprite2D

const BEAST_TEXTURES: Dictionary = {
	"青龙": preload("res://assets/world/portal/beast-azure-dragon.png"),
	"白虎": preload("res://assets/world/portal/beast-white-tiger.png"),
	"朱雀": preload("res://assets/world/portal/beast-vermilion-bird.png"),
}
const TIER_TEXTURES: Dictionary = {
	1: preload("res://assets/world/portal/tier-overlay-1.png"),
	2: preload("res://assets/world/portal/tier-overlay-2.png"),
	3: preload("res://assets/world/portal/tier-overlay-3.png"),
}
const BEAST_TINTS: Dictionary = {
	"青龙": Color("78d6e2"),
	"白虎": Color("eef7f2"),
	"朱雀": Color("c82d24"),
}
const TIER_BASE_TINT: Color = Color("cbbd93")

@export_enum("beast", "tier") var layer: String = "beast"

var blessing_beast: String = ""
var blessing_tier: int = 0
var sealed: bool = true
var hovered: bool = false
var usable: bool = false

func configure(beast: String,tier: int,is_sealed: bool,is_hovered: bool,is_usable: bool) -> void:
	var changed: bool=blessing_beast!=beast or blessing_tier!=clampi(tier,0,3)
	blessing_beast=beast
	blessing_tier=clampi(tier,0,3)
	sealed=is_sealed
	hovered=is_hovered
	usable=is_usable
	if changed: _apply_texture()
	_apply_state()

func matches_blessing(beast: String,tier: int) -> bool:
	return blessing_beast==beast and blessing_tier==clampi(tier,0,3)

func theme_key() -> Dictionary:
	return {"beast":blessing_beast,"tier":blessing_tier,"layer":layer,"texture":texture.resource_path if texture!=null else ""}

func _ready() -> void:
	centered=false
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_texture()
	_apply_state()

func _apply_texture() -> void:
	if layer=="beast":
		texture=BEAST_TEXTURES.get(blessing_beast)
	else:
		texture=TIER_TEXTURES.get(blessing_tier) if BEAST_TEXTURES.has(blessing_beast) else null
	visible=texture!=null

func _apply_state() -> void:
	if texture==null: return
	var alpha: float=0.72 if sealed else 0.96
	if hovered: alpha=minf(1.0,alpha+0.08)
	if usable and not sealed: alpha=1.0
	var base: Color=Color(1.0,1.0,1.0)
	if layer=="tier":
		base=TIER_BASE_TINT.lerp(BEAST_TINTS.get(blessing_beast,base),0.55)
	var target: Color=Color(base.r,base.g,base.b,alpha)
	if modulate!=target: modulate=target
