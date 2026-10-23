shader_type canvas_item;

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV) * vec2(1440.0, 1040.0);
	vec4 surface = COLOR;
	surface.a *= smoothstep(0.0, 48.0, min(edge.x, edge.y));
	COLOR = surface;
}
