shader_type canvas_item;

// Vignettatura calda e delicata: chiude l'inquadratura come
// l'angolo di un'illustrazione.
uniform float strength : hint_range(0.0, 1.0) = 0.22;
uniform vec4 tint : source_color = vec4(0.36, 0.24, 0.2, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.42, 0.98, length(uv) * 1.35);
	COLOR = vec4(tint.rgb, v * strength);
}
