shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Cel-shading pastello: bande morbide e un rim light delicato che stacca
// la silhouette dal fondo, stile Animal Crossing. Con fur_noise > 0 una
// grana sottile a due ottave dà al colore la vibrazione del pelo.
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.14;
uniform vec4 rim_color : source_color = vec4(1.0, 0.93, 0.96, 1.0);
uniform float fur_noise : hint_range(0.0, 1.0) = 0.0;
// L'età SCAVATA nel modello (0 = giovane). Le rughe sono solchi nel
// campo di luce: cadono nell'ombra della banda cel, così è la luce a
// scolpirle — fronte, zampe di gallina, guance. Solo sulla testa dei
// vicini anziani (il materiale viene clonato all'invecchiamento).
uniform float age : hint_range(0.0, 1.0) = 0.0;

varying vec3 vlocal;

void vertex() {
	vlocal = VERTEX;
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = dot(i, vec3(1.0, 57.0, 113.0));
	float a = fract(sin(n) * 43758.55);
	float b = fract(sin(n + 1.0) * 43758.55);
	float c = fract(sin(n + 57.0) * 43758.55);
	float d = fract(sin(n + 58.0) * 43758.55);
	float e = fract(sin(n + 113.0) * 43758.55);
	float f2 = fract(sin(n + 114.0) * 43758.55);
	float g = fract(sin(n + 170.0) * 43758.55);
	float h = fract(sin(n + 171.0) * 43758.55);
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
			mix(mix(e, f2, f.x), mix(g, h, f.x), f.y), f.z);
}

// i solchi del tempo, sulla sfera della testa (faccia verso -Z):
// tre pieghe sulla fronte, le zampe di gallina ai lati degli occhi,
// le pieghette delle guance sotto — linee sottili, mai una griglia
float rughe(vec3 d) {
	float m = 0.0;
	// fronte: solchi orizzontali che seguono la curva
	float fmask = smoothstep(-0.30, -0.62, d.z)
			* smoothstep(0.64, 0.44, d.y) * smoothstep(0.14, 0.30, d.y);
	m += fmask * pow(0.5 + 0.5 * sin(d.y * 40.0 + d.z * 5.0), 7.0);
	// zampe di gallina, a ventaglio dai lati degli occhi
	float side = abs(d.x);
	float cmask = smoothstep(-0.48, -0.72, d.z)
			* smoothstep(0.40, 0.58, side) * smoothstep(0.28, 0.06, abs(d.y - 0.04));
	m += cmask * pow(0.5 + 0.5 * sin((d.y + side * 0.55) * 52.0), 6.0);
	// le pieghette morbide delle guance
	float gmask = smoothstep(-0.55, -0.80, d.z)
			* smoothstep(0.18, 0.34, side) * smoothstep(-0.34, -0.16, d.y)
			* smoothstep(-0.05, -0.18, d.y);
	m += gmask * pow(0.5 + 0.5 * sin((d.y - side * 0.4) * 46.0), 6.0) * 0.7;
	return min(m, 1.0);
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (fur_noise > 0.001) {
		float n = vnoise(vlocal * 46.0) * 0.65 + vnoise(vlocal * 120.0) * 0.35;
		col *= 1.0 - fur_noise * (n - 0.5) * 0.22;
	}
	if (age > 0.001) {
		// il fondo del solco resta leggibile anche in luce piatta
		col *= 1.0 - rughe(normalize(vlocal)) * age * 0.13;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	// base minima sempre accesa (leggibilità notturna); il rim vero,
	// direzionale, vive in light()
	float rim = 1.0 - dot(normalize(NORMAL), normalize(VIEW));
	rim = smoothstep(0.6, 0.95, rim);
	EMISSION = rim_color.rgb * rim * rim_strength * 0.35;
}

// Il gradino di luce art-directed: forma e ombra proiettata cadono nello
// STESSO gradino cel, con un bordo morbido (mai tagliente). Il lato in
// ombra qui resta spento apposta: a dipingerlo ci pensa la luce ambiente
// fredda del DayNight — è così che l'ombra diventa "di un altro colore".
void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	// i solchi delle rughe spingono il campo di luce verso l'ombra:
	// è la banda cel a scolpirle, come farebbe una matita
	float scavo = 0.0;
	if (age > 0.001) {
		scavo = rughe(normalize(vlocal)) * age * 0.33;
	}
	float lit = smoothstep(0.03, 0.42, dot(n, l) * ATTENUATION - scavo);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * lit;

	// rim DIREZIONALE: il pelo di Mochi si accende sul bordo verso il
	// sole (o verso la lampada, la notte), col colore di quella luce
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.0);
	float side = smoothstep(-0.15, 0.55, dot(n, l));
	DIFFUSE_LIGHT += rim_color.rgb * LIGHT_COLOR * fres * side
			* rim_strength * 1.3 * clamp(ATTENUATION, 0.0, 1.0);
}
