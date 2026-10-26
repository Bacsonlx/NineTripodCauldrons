extends Sprite2D
## 只采样已注册图集，不自行播放或推进规则时间。

const DIRECTORY: String = "res://assets/characters/action-redraw-v1/"
var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"clips.json"))
var textures: Dictionary = {}
var clip: String = ""
var frame_index: int = 0

func _init() -> void:
	centered=false
	region_enabled=true
	region_filter_clip_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func sample(action: String,index: int) -> void:
	clip=action; frame_index=index
	if not textures.has(action): textures[action]=load(DIRECTORY+action+".png")
	var data: Dictionary = clips[action]
	var size: Vector2 = Vector2(data.size[0],data.size[1])
	var root: Array = data.roots[index] if data.has("roots") else data.root
	var anchor: Vector2 = Vector2(root[0],root[1])
	texture=textures[action]
	region_rect=Rect2(Vector2(index%int(data.columns),index/int(data.columns))*size,size)
	offset=-anchor
	scale=Vector2.ONE*float(data.scale)
