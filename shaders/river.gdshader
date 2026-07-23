shader_type spatial;
render_mode cull_disabled;

// L'acqua del fiume: SCORRE. Due strati di noise che scivolano a valle
// a velocità diverse (le lame di luce si stirano lungo la corrente),
// fondo scuro al centro e sponde chiare, schiuma morbida che respira
// sui bordi e scintille che corrono via. UV: x attraverso il corso
// (0 sponda ovest, 1 est), y lungo il corso, verso valle.

uniform vec4 shallow_color : source_color = vec4(0.47, 0.76, 0.78, 0.55);
uniform vec4 deep_color : source_color = vec4(0.15, 0.40, 0.54, 0.86);
uniform vec4 foam_color : source_color = vec4(0.97, 1.0, 1.0, 0.9);
uniform float flow_speed = 0.16;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * flow_speed;

	// profondità: chiaro sulle sponde, cupo nel mezzo
	float center = 1.0 - abs(uv.x - 0.5) * 2.0;
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 0.75, center));
	float alpha = mix(shallow_color.a, deep_color.a, smoothstep(0.0, 0.7, center));

	// la corrente: streaks stirati lungo il corso, due velocità
	float s1 = vnoise(vec2(uv.x * 9.0, uv.y * 3.0 - t * 2.6));
	float s2 = vnoise(vec2(uv.x * 17.0 + 5.0, uv.y * 6.0 - t * 4.4));
	float streak = smoothstep(0.60, 0.95, s1 * 0.6 + s2 * 0.4);
	col += vec3(0.10, 0.14, 0.13) * streak;

	// schiuma alle sponde: un bordo bianco irregolare che respira
	float bank = min(uv.x, 1.0 - uv.x)
			+ (vnoise(vec2(uv.y * 7.0 - t * 1.8, uv.x * 4.0)) - 0.5) * 0.07;
	float foam = smoothstep(0.12, 0.02, bank);
	col = mix(col, foam_color.rgb, foam * 0.85);
	alpha = max(alpha, foam * foam_color.a);

	// scintille che filano a valle (rade e irregolari: mai una griglia)
	vec2 gc = vec2(uv.x * 26.0, uv.y * 58.0 - TIME * 2.2);
	float g = step(0.9965, hash12(floor(gc) + floor(hash12(floor(gc.yx)) * 7.0)));
	EMISSION = vec3(0.45, 0.56, 0.56) * g * 0.5;

	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.25;
	SPECULAR = 0.4;
}
