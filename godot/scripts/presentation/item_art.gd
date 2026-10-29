extends RefCounted

const TEXTURES: Dictionary = {
	"快马":preload("res://assets/items/first-level-v1/swift-horse.tres"),
	"司晨":preload("res://assets/items/first-level-v1/dawn-rooster.tres"),
	"豕涉":preload("res://assets/items/first-level-v1/water-boar.tres"),
	"守冢":preload("res://assets/items/first-level-v1/grave-guard.tres"),
	"囤积":preload("res://assets/items/first-level-v1/hoard-pact.tres"),
	"素食":preload("res://assets/items/first-level-v1/herb-pact.tres"),
	"涂炭":preload("res://assets/items/first-level-v1/charcoal-pact.tres"),
	"焚书":preload("res://assets/items/first-level-v1/burning-pact.tres"),
	"鼠毫":preload("res://assets/items/first-level-v1/rat-whisker.tres"),
	"虎牙":preload("res://assets/items/first-level-v1/tiger-fang.tres"),
	"羊角":preload("res://assets/items/first-level-v1/ram-horn.tres"),
	"燧火":preload("res://assets/items/first-level-v1/flint-fire.tres"),
	"训练弓":preload("res://assets/items/first-level-v1/training-bow.tres"),
	"布履":preload("res://assets/items/first-level-v1/cloth-shoes.tres"),
	"青龙":preload("res://assets/items/first-level-v1/azure-dragon.tres"),
	"白虎":preload("res://assets/items/first-level-v1/tiger-fang.tres"),
	"朱雀":preload("res://assets/items/first-level-v1/flint-fire.tres")
}

static func texture(title: String) -> Texture2D:
	return TEXTURES.get(title.trim_prefix("灰烬·"))

static func tint(item: Dictionary) -> Color:
	if item.get("state","")=="ash": return Color(0.28,0.28,0.28,0.7)
	if item.get("state","")=="burning": return Color(1.0,0.5,0.25)
	return Color.WHITE

static func fit(image: Texture2D, bounds: Rect2) -> Rect2:
	var dimensions: Vector2 = image.get_size()
	var fitted: Vector2 = dimensions*minf(bounds.size.x/dimensions.x,bounds.size.y/dimensions.y)
	return Rect2(bounds.get_center()-fitted/2,fitted)
