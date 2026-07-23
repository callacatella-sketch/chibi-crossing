shader_type spatial;
render_mode cull_disabled;

// I fiori selvatici nati dall'impollinazione: la specie arriva per
// istanza (INSTANCE_CUSTOM.x sceglie la tinta dei petali), il gambo
// resta verde (COLOR.a = 0 nel vertice), e il vento li fa ondeggiare.
uniform vec3 tint_a: source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 tint_b: source_color = vec3(0.97, 0.74, 0.83);
uniform vec3 tint_c: source_color = vec3(0.78, 0.70, 0.94);
uniform vec3 tint_d: source_color = vec3(0.99, 0.86, 0.55);

varying vec4 vcol;
varying float kind;

void vertex() {
	vcol = COLOR;
	kind = INSTANCE_CUSTOM.x;
	// brezza: la cima ondeggia, la base resta piantata
	float sway = sin(TIME * 1.6 + VERTEX.x * 2.0 + VERTEX.z * 2.0) * 0.05 * VERTEX.y;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}

void fragment() {
	vec3 petal = kind < 0.5 ? tint_a : (kind < 1.5 ? tint_b : (kind < 2.5 ? tint_c : tint_d));
	ALBEDO = mix(vcol.rgb, petal, vcol.a);
	ROUGHNESS = 1.0;
}
