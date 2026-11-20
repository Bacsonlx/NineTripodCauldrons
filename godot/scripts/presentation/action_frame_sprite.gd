extends Sprite2D
## 只采样已注册图集，不自行播放或推进规则时间。

const DIRECTORY: String = "res://assets/characters/action-redraw-v1/"
var directory: String = DIRECTORY
var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"clips.json"))
var textures: Dictionary = {}
var clip: String = ""
var frame_index: int = 0
var flipped: bool = false

func use_directory(path: String) -> void:
	directory=path
	clips=JSON.parse_string(FileAccess.get_file_as_string(directory+"clips.json"))
	textures.clear()

func _init() -> void:
	centered=false
	region_enabled=true
	region_filter_clip_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func sample(action: String,index: int,flip: bool = false) -> void:
	clip=action; frame_index=index
	if not textures.has(action): textures[action]=load(directory+action+".png")
	var data: Dictionary = clips[action]
	var size: Vector2 = Vector2(data.size[0],data.size[1])
	var root: Array = data.roots[index] if data.has("roots") else data.root
	var anchor: Vector2 = Vector2(root[0],root[1])
	texture=textures[action]
	region_rect=Rect2(Vector2(index%int(data.columns),index/int(data.columns))*size,size)
	# 镜像只用负缩放；若同时置 flip_h 会翻转两次，等于没有镜像。
	if flip!=flipped:
		flipped=flip
	scale=Vector2.ONE*float(data.scale)*Vector2(-1.0 if flip else 1.0,1.0)
	# 把图集的根锚点移到节点原点，负缩放自然绕该点镜像。
	offset=-anchor

## 当前帧的根锚点（clip 像素）。
func root_anchor() -> Vector2:
	var data: Dictionary = clips[clip]
	var root: Array = data.roots[frame_index] if data.has("roots") else data.root
	return Vector2(root[0],root[1])

## 当前帧的腰带线（clip 像素的绝对 y）。
##
## 各剪辑的 root 语义并不一致：下身剪辑的 root 落在腰线附近，
## 上身剪辑的 root 落在躯干内部。两者不能直接比较偏移量，
## 必须先换算成「相对 root 的像素差」。
##
## clips.json 里记录的是 waistLine（绝对像素）。旧数据里也可能是
## waist_y（相对 root 的偏移），两种都能换算成绝对像素。
func waist_pixel() -> float:
	var data: Dictionary = clips[clip]
	var root: Array = data.roots[frame_index] if data.has("roots") else data.root
	if data.has("waistLine"):
		var values: Array = data.waistLine
		if frame_index>=0 and frame_index<values.size(): return float(values[frame_index])
	if data.has("waist_px"):
		var legacy: Array = data.waist_px
		if frame_index>=0 and frame_index<legacy.size(): return float(legacy[frame_index])
	if data.has("waist_y"):
		var offsets: Array = data.waist_y
		if frame_index>=0 and frame_index<offsets.size(): return float(root[1])+float(offsets[frame_index])
	return float(root[1])

## 腰带线相对根锚点的像素差（clip 像素，向下为正）。
func waist_delta() -> float:
	return waist_pixel()-root_anchor().y

func waist_parent_point() -> Vector2:
	var data: Dictionary = clips[clip]
	var point: Vector2 = Vector2(root_anchor().x,waist_pixel())
	if data.has("waistPoints"):
		var value: Array = data.waistPoints[frame_index]
		point=Vector2(value[0],value[1])
	return transform.basis_xform(offset+point)

func waist_world_point() -> Vector2:
	return get_parent().to_global(position+waist_parent_point())

## 腰带线在父节点坐标系里的偏移（父节点单位，向下为正）。
func waist_parent_offset() -> float:
	return transform.basis_xform(Vector2(offset.x+root_anchor().x,offset.y+waist_pixel())).y

## 从实际绘制的腰线像素换算世界 y，供新旧素材混用时对齐。
func waist_world_y() -> float:
	return to_global(offset+Vector2(root_anchor().x,waist_pixel())).y
