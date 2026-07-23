shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, depth_draw_never, cull_disabled;

// Lucciole dell'ecosistema: billboard additivi che respirano luce,
// ognuna con la sua fase di lampeggio (INSTANCE_CUSTOM.x).

varying float blink;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	blink = 0.2 + 0.8 * pow(0.5 + 0.5 * sin(TIME * 2.4 + phase * 6.283), 2.4);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float glow = smoothstep(1.0, 0.0, d);
	glow *= glow;
	ALBEDO = vec3(0.80, 1.0, 0.52) * glow * blink;
	ALPHA = glow * blink;
}
