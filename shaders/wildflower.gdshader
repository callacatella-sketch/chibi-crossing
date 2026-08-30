shader_type spatial;
render_mode cull_disabled;

// I fiori selvatici nati dall'impollinazione: la specie arriva per
// istanza (INSTANCE_CUSTOM.x sceglie la tinta dei petali), il gambo
// resta verde (COLOR.a = 0 nel vertice), e il vento li fa ondeggiare.
uniform vec3 tint_a: source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 tint_b: source_color = vec3(0.97, 0.74, 0.83);
uniform vec3 tint_c: source_color = vec3(0.78, 0.70, 0.94);
uniform vec3 tint_d: source_color = vec3(0.99, 0.86, 0.55);
// quanto la folata piega questa pianta (l'altezza è ~0.27 m)
uniform float chioma = 0.055;
#include "res://shaders/vento.gdshaderinc"

varying vec4 vcol;
varying float kind;

void vertex() {
	vcol = COLOR;
	kind = INSTANCE_CUSTOM.x;
	// ⚠️ LA FASE VENIVA DALLE COORDINATE OGGETTO — `VERTEX.x·2 +
	// VERTEX.z·2` — che sono IDENTICHE in ogni istanza: trecentottanta
	// fiori che ondeggiavano nello stesso identico istante, dentro
	// un'erba che invece ha la folata del mondo. Bastava guardarli per
	// sentire che l'aria non era la stessa aria.
	// Adesso prendono la STESSA folata di erba, chiome e fiori del
	// prato, e la fase dal punto in cui sono piantati.
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = clamp(VERTEX.y / 0.27, 0.0, 1.0);
	w = w * w * (3.0 - 2.0 * w);
	float fase = vento_fase(MODEL_MATRIX[3].xz);
	float folata = vento_folata(wp.xz, TIME);
	float brezza = sin(TIME * 0.9 + fase) * 0.35 + sin(TIME * 1.37 + fase * 1.7) * 0.15;
	float piega = (folata + brezza * 0.35) * chioma * w;
	VERTEX.xz += vento_direzione() * piega;
	// piegandosi la pianta SCENDE un poco: è una rotazione attorno alle
	// radici, non una traslazione
	VERTEX.y -= abs(piega) * 0.35;
}

void fragment() {
	vec3 petal = kind < 0.5 ? tint_a : (kind < 1.5 ? tint_b : (kind < 2.5 ? tint_c : tint_d));
	ALBEDO = mix(vcol.rgb, petal, vcol.a);
	ROUGHNESS = 1.0;
}
