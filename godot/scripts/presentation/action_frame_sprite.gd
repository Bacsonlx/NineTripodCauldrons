extends Sprite2D
## 只采样已注册图集，不自行播放或推进规则时间。

const DIRECTORY: String = "res://assets/characters/action-redraw-v1/"
## 主角按统一纹素密度重采样并带 mipmap；Boss 等仍读原图集。
const RUNTIME_DIRECTORY: String = "res://assets/characters/hero-runtime-v1/"
static var shared_clips: Dictionary = {}
static var runtime_clips: Dictionary = {}
var clips: Dictionary = load_clips()
var textures: Dictionary = {}
var clip: String = ""
var frame_index: int = 0

func _init() -> void:
	centered=false
	region_enabled=true
	region_filter_clip_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static func load_clips() -> Dictionary:
	if shared_clips.is_empty():
		shared_clips=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"clips.json"))
		runtime_clips=JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_DIRECTORY+"clips.json"))
		shared_clips.merge(runtime_clips,true)
	return shared_clips

func sample(action: String,index: int) -> void:
	clip=action; frame_index=index
	if not textures.has(action): textures[action]=load((RUNTIME_DIRECTORY if runtime_clips.has(action) else DIRECTORY)+action+".png")
	var data: Dictionary = clips[action]
	var size: Vector2 = Vector2(data.size[0],data.size[1])
	var root: Array = data.roots[index] if data.has("roots") else data.root
	var anchor: Vector2 = Vector2(root[0],root[1])
	texture=textures[action]
	region_rect=Rect2(Vector2(index%int(data.columns),index/int(data.columns))*size,size)
	offset=-anchor
	scale=Vector2.ONE*float(data.scale)
