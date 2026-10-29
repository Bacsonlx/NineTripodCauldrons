extends Control

const Art = preload("res://scripts/presentation/item_art.gd")
const Alpha = preload("res://scripts/alpha/alpha_state.gd")
const Geometry = preload("res://scripts/alpha/altar_geometry.gd")
const FontSong = preload("res://assets/fonts/NineTripodsHudSong.ttf")

var cells: Array[Button] = []
var items: Array = []
var altar_analysis: Dictionary = {}
var selected_id: int = -1
var aura_cells: Array = []
var hover_preview: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	if cells.is_empty(): return

	# 1. 空白格暗纹与青龙光环底衬
	for index in cells.size():
		var cell: Vector2i = Vector2i(index % 10, index / 10)
		var cell_btn: Button = cells[index]
		var center: Vector2 = cell_btn.position + cell_btn.size * 0.5

		# 青龙气息底衬
		if aura_cells.has(cell):
			var aura_rect: Rect2 = Rect2(cell_btn.position, cell_btn.size).grow(-1)
			draw_rect(aura_rect, Color(0.24, 0.42, 0.30, 0.35), true)
			draw_rect(aura_rect, Color(0.45, 0.70, 0.52, 0.55), false, 1.0)

		# 空白格中心微弱菱形暗纹
		var is_occupied: bool = false
		for item in items:
			if Alpha.REGIONS.has(item.region) and Rect2i(item.cell, Alpha.shape(item, item.rotated)).has_point(cell):
				is_occupied = true
				break
		if not is_occupied:
			var diamond_points: PackedVector2Array = [
				center + Vector2(0, -3),
				center + Vector2(3, 0),
				center + Vector2(0, 3),
				center + Vector2(-3, 0)
			]
			draw_colored_polygon(diamond_points, Color(0.64, 0.64, 0.48, 0.18))

	# 2. 祭坛 4x4 中主位 2x2 (7,1) 到 (8,2) 的专属主位底板
	var core_start: int = 1 * 10 + 7
	var core_end: int = 2 * 10 + 8
	if core_start < cells.size() and core_end < cells.size():
		var core_rect: Rect2 = Rect2(cells[core_start].position, cells[core_end].position + cells[core_end].size - cells[core_start].position).grow(-1)
		draw_rect(core_rect, Color(0.16, 0.12, 0.10, 0.85), true)
		draw_rect(core_rect, Color("d8cfc0"), false, 1.5)
		draw_string(FontSong, Vector2(core_rect.position.x, core_rect.position.y + 14), "主位 · 器", HORIZONTAL_ALIGNMENT_CENTER, core_rect.size.x, 11, Color(0.85, 0.81, 0.75, 0.65))

	# 3. 通电能量连线 (Power Flow)
	var energized_edges: Array = altar_analysis.get("energized_edges", [])
	for edge in energized_edges:
		var ca: Vector2i = edge.get("cell_a", Vector2i.ZERO)
		var cb: Vector2i = edge.get("cell_b", Vector2i.ZERO)
		var idx_a: int = ca.y * 10 + ca.x
		var idx_b: int = cb.y * 10 + cb.x
		if idx_a < cells.size() and idx_b < cells.size():
			var pt_a: Vector2 = cells[idx_a].position + cells[idx_a].size * 0.5
			var pt_b: Vector2 = cells[idx_b].position + cells[idx_b].size * 0.5
			var is_core: bool = edge.get("is_core", false)
			var flow_color: Color = Color("e6c27a") if is_core else Color("98c8ae")
			draw_line(pt_a, pt_b, flow_color * Color(1, 1, 1, 0.9), 3.0, true)
			draw_circle(pt_a, 3.5, flow_color)
			draw_circle(pt_b, 3.5, flow_color)

	# 4. 绘制实物
	var energized_ids: Array = altar_analysis.get("energized_ids", [])
	for item in items:
		if not Alpha.REGIONS.has(item.region): continue
		var image: Texture2D = Art.texture(item.name)
		if image == null: continue
		var shape: Vector2i = Alpha.shape(item, item.rotated)
		var start: int = item.cell.y * 10 + item.cell.x
		var end: int = (item.cell.y + shape.y - 1) * 10 + item.cell.x + shape.x - 1
		if start >= cells.size() or end >= cells.size(): continue
		var bounds: Rect2 = Rect2(cells[start].position, cells[end].position + cells[end].size - cells[start].position).grow(-2)

		# 实物底板背景与边框
		var base_bg: Color = Color(0.12, 0.16, 0.13, 0.92)
		var base_border: Color = Color(0.55, 0.48, 0.32, 0.75)
		if item.region == "altar":
			base_bg = Color(0.18, 0.16, 0.10, 0.92)
			base_border = Color(0.65, 0.55, 0.32, 0.80)
		elif item.region == "warehouse":
			base_bg = Color(0.20, 0.15, 0.11, 0.92)
			base_border = Color(0.62, 0.48, 0.30, 0.80)
		draw_rect(bounds, base_bg, true)
		draw_rect(bounds, base_border, false, 1.0)

		var is_energized: bool = item.region == "altar" and energized_ids.has(item.id)
		if is_energized:
			var glow_color: Color = Color("e6c27a") if Geometry.is_core_item(item) else Color("98c8ae")
			draw_rect(bounds.grow(1.5), glow_color * Color(1, 1, 1, 0.75), false, 1.8)

		# 选中高亮边框与角标
		if item.id == selected_id:
			draw_rect(bounds.grow(1.5), Color("ead29a"), false, 2.0)
			var corner_pt: Vector2 = Vector2(bounds.end.x - 5, bounds.position.y + 5)
			draw_colored_polygon([corner_pt + Vector2(0, -3), corner_pt + Vector2(3, 0), corner_pt + Vector2(0, 3), corner_pt + Vector2(-3, 0)], Color("e6c989"))

		# 物品贴图区域
		var label_height: float = 15.0
		var area: Rect2 = Rect2(bounds.position + Vector2(2, 2), bounds.size - Vector2(4, label_height + 4))
		if item.rotated:
			draw_set_transform(area.get_center(), PI / 2)
			var turned: Rect2 = Rect2(-Vector2(area.size.y, area.size.x) / 2, Vector2(area.size.y, area.size.x))
			draw_texture_rect(image, Art.fit(image, turned), false, Art.tint(item))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(image, Art.fit(image, area), false, Art.tint(item))

		# 底部半透明金字品名标签横条
		var label_rect: Rect2 = Rect2(bounds.position.x + 1, bounds.end.y - label_height, bounds.size.x - 2, label_height - 1)
		draw_rect(label_rect, Color(0.06, 0.09, 0.07, 0.85), true)
		var prefix: String = ""
		if item.state == "burning": prefix = "燃·"
		elif item.state == "ash": prefix = "灰·"
		elif is_energized: prefix = "⚡"
		var title: String = prefix + item.name.trim_prefix("灰烬·")
		var title_color: Color = Color("e6c27a") if is_energized else (Color("f7e8c7") if item.id == selected_id else Color("d5c7a6"))
		draw_string(FontSong, Vector2(bounds.position.x, bounds.end.y - 3), title, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 10, title_color)

		# 嵌符角标
		var glyph_count: int = item.get("glyphs", []).size()
		if glyph_count > 0:
			draw_string(FontSong, Vector2(bounds.position.x + 3, bounds.position.y + 11), "符%d" % glyph_count, HORIZONTAL_ALIGNMENT_LEFT, 30, 9, Color("c5a363"))

	# 5. 拟放预览覆盖在物品之上，确保非法目标格始终可见为红色
	if hover_preview.get("active", false):
		var prev_rect: Rect2 = hover_preview.get("rect", Rect2())
		var is_valid: bool = hover_preview.get("valid", true)
		var fill_col: Color = Color(0.40, 0.68, 0.48, 0.35) if is_valid else Color(0.70, 0.30, 0.24, 0.50)
		var border_col: Color = Color(0.60, 0.85, 0.62, 0.85) if is_valid else Color(0.95, 0.30, 0.24, 1.0)
		var preview_cells: Array = hover_preview.get("cells", [])
		if preview_cells.is_empty():
			draw_rect(prev_rect, fill_col, true)
			draw_rect(prev_rect, border_col, false, 1.5)
		else:
			for cell in preview_cells:
				var preview_index: int = cell.y * 10 + cell.x
				if preview_index < 0 or preview_index >= cells.size(): continue
				var preview_cell: Button = cells[preview_index]
				var preview_cell_rect: Rect2 = Rect2(preview_cell.position, preview_cell.size).grow(-1)
				draw_rect(preview_cell_rect, fill_col, true)
				draw_rect(preview_cell_rect, border_col, false, 1.8)
