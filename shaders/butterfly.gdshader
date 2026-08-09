shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Le ali delle farfalle dell'ecosistema: il battito vive nel vertex
// shader (costo zero per CPU), lo sfasamento e la specie arrivano per
// istanza dal MultiMesh (INSTANCE_CUSTOM = sfasamento, specie, velocità).
//
// ATTENZIONE: INSTANCE_CUSTOM.x dev'essere una COSTANTE 0..1 (serve solo a
// far battere le ali fuori sincrono l'una dall'altra). Se ci arrivasse
// l'orologio interno del C++, che accumula, la sua derivata ×6.283 si
// sommerebbe alla frequenza del battito e tutte accelererebbero insieme.
uniform vec3 col_a: source_color = vec3(0.96, 0.70, 0.80);
uniform vec3 col_b: source_color = vec3(0.62, 0.79, 0.95);
uniform vec3 col_c: source_color = vec3(0.98, 0.89, 0.60);

varying float body_k;
varying float kind;

void vertex() {
	float sfasamento = INSTANCE_CUSTOM.x;
	float speed = INSTANCE_CUSTOM.z; // 1 in volo, giù quando sorseggia
	kind = INSTANCE_CUSTOM.y;
	float a = sin(TIME * (15.0 * speed + 2.5) + sfasamento * 6.283) * (0.45 + 0.5 * speed);
	float w = abs(VERTEX.x);
	VERTEX.x = sign(VERTEX.x) * w * cos(a);
	VERTEX.y += w * abs(sin(a)) * 0.9;
	body_k = 1.0 - clamp(w * 14.0, 0.0, 1.0);
}

void fragment() {
	vec3 wing = kind < 0.5 ? col_a : (kind < 1.5 ? col_b : col_c);
	ALBEDO = mix(wing, wing * 0.4, body_k);
	// un filo di luce propria: leggibili anche nell'ombra del bosco
	EMISSION = wing * 0.22 * (1.0 - body_k);
}
