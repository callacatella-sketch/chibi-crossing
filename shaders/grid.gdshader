shader_type spatial;
render_mode unshaded, depth_draw_never;

// Griglia di costruzione: linee sulle giunzioni delle celle (i bordi sono
// ai mezzi interi, le celle sono centrate sugli interi), che sfumano
// dolcemente allontanandosi dal cursore.
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);

varying vec3 wpos;
varying vec3 lpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
}

void fragment() {
	vec2 g = abs(fract(wpos.xz + 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.012, 0.045, min(g.x, g.y));
	float fade = 1.0 - smoothstep(1.8, 3.9, length(lpos.xz));
	ALBEDO = line_color.rgb;
	ALPHA = line * line_color.a * fade;
}
