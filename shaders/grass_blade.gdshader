shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

// L'erba del prato, filo per filo. I trucchi da gioco grosso, in ordine
// d'importanza: radici in ombra e punte accese (l'occlusione finta che
// dà volume al manto), folate di vento che ATTRAVERSANO il campo come
// onde, i fili che si scostano e si abbassano al passaggio di Mochi,
// tinte per-filo che seguono le stesse chiazze del terreno (così suolo
// ed erba sono un unico dipinto), e la rugiada che brilla dopo la
// pioggia. INSTANCE_CUSTOM: x fase del vento, y tinta, w bioma foresta.

// gli stessi tre verdi del manto (ground.gdshader): il filo li usa per
// calcolare il colore ESATTO del terreno sotto di sé
uniform vec4 grass_a : source_color = vec4(0.55, 0.74, 0.43, 1.0);
uniform vec4 grass_b : source_color = vec4(0.36, 0.57, 0.33, 1.0);
uniform vec4 grass_c : source_color = vec4(0.70, 0.84, 0.47, 1.0);
uniform vec4 tint_warm : source_color = vec4(0.74, 0.86, 0.42, 1.0);
uniform vec4 tint_cool : source_color = vec4(0.44, 0.72, 0.52, 1.0);
uniform vec2 wind_dir = vec2(0.78, 0.45);

global uniform vec3 mochi_pos;
global uniform float erba_bagnata;
// l'inverno: gli stessi fili corti spariscono sotto la coltre, le punte
// spuntano imbiancate (stesso globale che imbianca manto e chiome)
global uniform float snow_amount;

varying vec3 wpos;
varying float v_h;
varying float v_hue;
varying float v_forest;

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
	return vnoise(p) * 0.6 + vnoise(p * 2.7 + 13.0) * 0.4;
}

float fbm3(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.3 + 7.0) * 0.3 + vnoise(p * 5.1 + 23.0) * 0.2;
}

void vertex() {
	v_h = UV.y;
	v_hue = INSTANCE_CUSTOM.y;
	v_forest = INSTANCE_CUSTOM.a;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float bendw = UV.y * UV.y;   // la radice resta piantata, la punta balla

	// la brezza personale del filo + la folata che viaggia sul prato
	float sway = sin(TIME * 1.7 + ph) * 0.5 + sin(TIME * 2.9 + ph * 1.7) * 0.18;
	vec2 wdir = normalize(wind_dir);
	float wave = sin(dot(world.xz, wdir) * 0.30 - TIME * 1.25
			+ vnoise(world.xz * 0.15) * 2.2);
	float gust = smoothstep(0.10, 0.95, wave);
	vec2 off = wdir * (sway * 0.030 + gust * 0.13) * bendw;

	// Mochi passa: i fili si scostano e si accucciano (solo a terra)
	float a_terra = 1.0 - step(1.2, mochi_pos.y);
	vec2 away = world.xz - mochi_pos.xz;
	float d = max(length(away), 0.001);
	float push = smoothstep(1.05, 0.15, d) * a_terra;
	off += (away / d) * push * 0.30 * bendw;

	vec3 disp = vec3(off.x, -(gust * 0.035 + push * 0.14) * bendw, off.y);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * disp;
	wpos = world;

	// tutti i fili condividono la normale del prato: il manto si illumina
	// come una superficie sola, niente coriandoli scuri
	NORMAL = inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float t = v_h;
	// IL COLORE DEL MANTO, con la stessa identica formula a tre scale
	// di ground.gdshader: alla radice il filo È il terreno sotto di sé.
	// È questo che fonde erba e suolo in un tappeto unico.
	mat2 rot = mat2(vec2(0.819, -0.574), vec2(0.574, 0.819));
	float macro = fbm(wpos.xz * 0.16);
	float meso = fbm3(rot * wpos.xz * 0.55 + 5.0);
	float micro = fbm(rot * wpos.xz * 0.85 + 31.0);
	float streak = vnoise(vec2(wpos.x * 0.4 + wpos.z * 0.07, wpos.z * 0.06));
	vec3 mantle = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.22, 0.88, macro));
	mantle = mix(mantle, grass_c.rgb, smoothstep(0.55, 0.85, meso) * 0.30);
	mantle = mix(mantle, grass_b.rgb * 0.93, smoothstep(0.60, 0.88, micro) * 0.28);
	mantle *= 1.0 - 0.05 * smoothstep(0.5, 0.9, streak);

	// radice affondata nell'ombra del ciuffo, punta che si accende:
	// la stessa pianta dal suolo alla cima, mai due materiali
	vec3 col = mantle * mix(0.82, 1.16, smoothstep(0.05, 0.9, t));
	// la tinta personale del filo: solo un soffio, e solo in punta
	col = mix(col, mix(tint_cool.rgb, tint_warm.rgb, v_hue), 0.14 * t);
	// il bioma foresta: fili più cupi e freddi tra gli alberi
	col *= mix(vec3(1.0), vec3(0.55, 0.66, 0.60), v_forest);

	// pioggia: stesso scurimento del manto (-18%), rugiada in punta
	col *= 1.0 - 0.18 * erba_bagnata;
	float glint = step(0.992, hash12(floor(wpos.xz * 30.0) + floor(TIME * 2.0)));
	EMISSION = vec3(0.55, 0.65, 0.52) * glint * erba_bagnata * 0.5 * t
			+ grass_c.rgb * 0.04 * pow(t, 3.0);

	// neve: la coltre inghiotte i fili, le punte restano imbiancate; un
	// filo di dormienza (grigio-verde) traspare alla radice
	if (snow_amount > 0.001) {
		float cover = mix(0.62, 1.0, smoothstep(0.05, 0.85, t)) * snow_amount;
		col = mix(col, vec3(0.95, 0.965, 1.0), clamp(cover, 0.0, 1.0));
		EMISSION += vec3(0.58, 0.64, 0.78) * glint * snow_amount * 0.3 * t;
	}

	ALBEDO = col;
	ROUGHNESS = 0.95 - 0.4 * erba_bagnata;
	SPECULAR = 0.04 + 0.26 * erba_bagnata;
}
