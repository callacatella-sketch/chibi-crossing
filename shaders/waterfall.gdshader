shader_type spatial;
render_mode cull_disabled;

// Il velo della cascata: fili d'acqua che precipitano accelerando
// (la y è compressa in alto: l'occhio legge la caduta), si sbiancano
// di schiuma verso la base e si sfrangiano ai bordi. Un soffio di
// luce propria: la cascata brilla anche al chiaro di luna.
// UV: x attraverso il velo, y = 0 al ciglio, 1 alla base.

uniform vec4 water_color : source_color = vec4(0.62, 0.82, 0.86, 0.5);
uniform vec4 foam_color : source_color = vec4(0.98, 1.0, 1.0, 1.0);
uniform float fall_speed = 0.9;

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
	float t = TIME * fall_speed;
	float y = pow(uv.y, 0.72); // compressione in alto = accelerazione visiva

	float n1 = vnoise(vec2(uv.x * 14.0, y * 4.0 - t * 3.0));
	float n2 = vnoise(vec2(uv.x * 27.0 + 9.0, y * 7.0 - t * 5.2));
	float streak = n1 * 0.6 + n2 * 0.4;

	vec3 col = mix(water_color.rgb, foam_color.rgb,
			smoothstep(0.45, 0.8, streak) * 0.5 + smoothstep(0.55, 1.0, uv.y) * 0.45);
	float alpha = water_color.a + smoothstep(0.5, 0.9, streak) * 0.35
			+ smoothstep(0.6, 1.0, uv.y) * 0.3;

	// bordi sfrangiati e ciglio che nasce dal nulla
	float side = smoothstep(0.0, 0.10, uv.x) * smoothstep(1.0, 0.90, uv.x);
	alpha *= side * smoothstep(0.0, 0.06, uv.y);

	EMISSION = col * 0.06;
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
	ROUGHNESS = 0.4;
	SPECULAR = 0.3;
}
