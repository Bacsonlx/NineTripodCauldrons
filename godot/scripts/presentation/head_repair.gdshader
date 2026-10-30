shader_type canvas_item;

uniform vec4 head_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform bool mask_head = true;

void fragment() {
	vec2 inside = step(head_rect.xy, UV) * step(UV, head_rect.xy + head_rect.zw);
	bool is_inside = inside.x * inside.y > 0.5;
	if (mask_head ? is_inside : !is_inside) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, UV) * COLOR;
	}
}
