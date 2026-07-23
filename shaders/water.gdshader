shader_type spatial;

// Lo stagno: acqua calma e stilizzata. Il cielo si riflette davvero
// (specular sul radiance del ProceduralSky), due strati di noise che
// scorrono perturbano le normali per i luccichii del sole, il colore
// scende dal verde-riva al blu profondo del centro, e il fresnel rende
// il bordo di vista più denso. Piccole onde vere sui vertici.
uniform vec4 shallow_col : source_color = vec4(0.5, 0.78, 0.74, 1.0);
uniform vec4 deep_col : source_color = vec4(0.16, 0.42, 0.52, 1.0);
uniform float radius = 3.6;

varying vec3 wpos;
varying vec2 luv;

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

float fbm(vec2 p) {
	return vnoise(p) * 0.62 + vnoise(p * 2.53 + 17.7) * 0.38;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	luv = VERTEX.xz;
	VERTEX.y += sin(TIME * 1.2 + VERTEX.x * 2.1 + VERTEX.z * 1.7) * 0.012;
}

void fragment() {
	float r = length(luv) / radius;
	vec3 col = mix(deep_col.rgb, shallow_col.rgb, smoothstep(0.45, 0.95, r));

	float n1 = fbm(wpos.xz * 1.35 + vec2(TIME * 0.11, TIME * 0.08));
	float n2 = fbm(wpos.xz * 1.35 - vec2(TIME * 0.09, -TIME * 0.12) + 7.0);
	NORMAL = normalize(NORMAL + vec3((n1 - 0.5) * 0.38, 0.0, (n2 - 0.5) * 0.38));

	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALPHA = mix(0.78, 0.95, fres);

	// coriandoli di sole sull'acqua
	EMISSION = vec3(0.95, 0.98, 1.0) * smoothstep(0.58, 0.78, n1 * n2 * 1.7) * 0.2;
}
