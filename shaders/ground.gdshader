shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Il manto del prato, ridipinto da zero. Tre scale di chiazze (macro
// stagionali, meso a ciuffi, micro pennellate), trifogli e margheritine
// dipinti direttamente nel manto, la lettiera della foresta a nord, la
// pioggia che scurisce e fa scintillare la rugiada — e oltre i confini
// del villaggio il piano si solleva in colline morbide: l'orizzonte di
// un mondo, non il bordo di un pavimento.

uniform vec4 grass_a : source_color = vec4(0.55, 0.74, 0.43, 1.0);
uniform vec4 grass_b : source_color = vec4(0.36, 0.57, 0.33, 1.0);
uniform vec4 grass_c : source_color = vec4(0.70, 0.84, 0.47, 1.0);
uniform vec4 clover_color : source_color = vec4(0.33, 0.56, 0.33, 1.0);
uniform vec4 daisy_color : source_color = vec4(0.97, 0.95, 0.89, 1.0);
// sottobosco della foresta (a nord): verdi più cupi e lettiera di foglie
uniform vec4 forest_a : source_color = vec4(0.30, 0.43, 0.27, 1.0);
uniform vec4 forest_b : source_color = vec4(0.22, 0.33, 0.20, 1.0);
uniform vec4 forest_litter : source_color = vec4(0.45, 0.37, 0.24, 1.0);
// 0..1: quando piove il prato si scurisce e prende un velo lucido
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
// 0..1: quanta acqua si è RACCOLTA nelle conche (le pozzanghere-specchio;
// lo pilota il Weather da wetness: si riempiono piovendo, si ritirano
// asciugando — la soglia arretra e gli specchi si restringono dagli orli)
uniform float pozzanghere : hint_range(0.0, 1.0) = 0.0;
// 1 mentre la pioggia CADE: l'acqua raccolta si increspa ad anelli;
// appena smette torna specchio calmo
uniform float pioggia_cade : hint_range(0.0, 1.0) = 0.0;
// il cielo di adesso, per il riflesso a gradiente (li scrive DayNight
// ogni frame: le pozzanghere riflettono LO STESSO tramonto del giocatore)
global uniform vec4 cielo_alto;
global uniform vec4 cielo_orizzonte;
// 0..1: l'inverno stende la neve sul manto (globale, pilotato dal regista
// delle stagioni: lo stesso valore che imbianca chiome e tetti)
global uniform float snow_amount;
// il campo dei ciuffi, cotto dal CozyWorld: il manto si scurisce
// esattamente dove l'erba affonda le radici — un tappeto unico
uniform sampler2D tuft_map : filter_linear, repeat_disable, hint_default_black;
uniform vec2 tuft_origin = vec2(-16.0, -19.0);
uniform vec2 tuft_size = vec2(32.0, 33.0);
// i sentieri consumati: la tela dell'usura dipinta dai passi (Sentieri.gd,
// stesso patto di tuft_map). Dove i passi si ripetono l'erba prima si
// spegne calpestata, poi cede alla terra battuta: il mondo ricorda.
uniform sampler2D sentieri_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 sentieri_origin = vec2(-22.0, -26.0);
uniform vec2 sentieri_size = vec2(44.0, 44.0);
uniform vec4 terra_battuta : source_color = vec4(0.63, 0.53, 0.37, 1.0);
uniform vec4 terra_orlo : source_color = vec4(0.47, 0.39, 0.28, 1.0);

varying vec3 wpos;
varying float v_hill;
varying float v_river;

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
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// L'INTERA area di gioco è una tavola: piatta fino a ±45 m (prato,
	// foresta, radure, e tutto lo spazio dove si costruisce). Solo in
	// LONTANANZA ESTREMA il mondo si solleva: prima colline morbide,
	// poi montagne pastello che delimitano l'orizzonte.
	vec2 dc = abs(w.xz - vec2(0.0, -12.0)) - vec2(45.0, 55.0);
	float fuori = length(max(dc, vec2(0.0)));
	float m_colline = smoothstep(12.0, 48.0, fuori);
	float m_monti = smoothstep(42.0, 90.0, fuori);
	v_hill = (fbm(w.xz * 0.035) * 5.5 + fbm(w.xz * 0.09 + 11.0) * 1.5) * m_colline
			+ pow(fbm(w.xz * 0.022 + 31.0), 1.6) * 34.0 * m_monti;
	VERTEX.y += v_hill;

	// il fiume scava il suo letto nel prato. La STESSA curva vive in
	// CozyWorld._river_x: GDScript e shader disegnano lo stesso corso
	// (seni di argomenti piccoli: niente divergenze di precisione)
	float rx = 18.6 + sin(w.z * 0.061) * 1.35 + sin(w.z * 0.023 + 2.0) * 0.85;
	float rd = abs(w.x - rx);
	float carve = smoothstep(3.3, 1.5, rd) * 1.15 * (1.0 - m_colline);
	VERTEX.y -= carve;
	v_river = carve;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// seconda scala ruotata di ~35°: rompe la griglia del value noise
	mat2 rot = mat2(vec2(0.819, -0.574), vec2(0.574, 0.819));
	float macro = fbm(wpos.xz * 0.16);
	float meso = fbm3(rot * wpos.xz * 0.55 + 5.0);
	float micro = fbm(rot * wpos.xz * 0.85 + 31.0);
	float streak = vnoise(vec2(wpos.x * 0.4 + wpos.z * 0.07, wpos.z * 0.06));

	// tre scale di verde: le stagioni del prato in un colpo d'occhio
	vec3 col = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.22, 0.88, macro));
	col = mix(col, grass_c.rgb, smoothstep(0.55, 0.85, meso) * 0.30);
	col = mix(col, grass_b.rgb * 0.93, smoothstep(0.60, 0.88, micro) * 0.28);
	col *= 1.0 - 0.05 * smoothstep(0.5, 0.9, streak);

	// il bioma foresta sfuma dentro il prato con un bordo irregolare
	float fmask = smoothstep(14.0, 22.0, -wpos.z + (vnoise(wpos.xz * 0.12) - 0.5) * 9.0);
	vec3 fcol = mix(forest_a.rgb, forest_b.rgb, smoothstep(0.3, 0.75, macro));
	fcol = mix(fcol, forest_litter.rgb, smoothstep(0.55, 0.85, micro) * 0.5);
	col = mix(col, fcol, fmask);

	// l'ombra dei ciuffi: dove l'erba si addensa il manto si scurisce
	// (stesso campo che decide dove nascono i fili) — le radici hanno
	// una casa scura in cui affondare, non un pavimento chiaro
	float tuft = texture(tuft_map, (wpos.xz - tuft_origin) / tuft_size).r;
	col *= 1.0 - 0.13 * tuft * (1.0 - fmask * 0.6);

	// le sponde del fiume: una battigia sabbiosa STRETTA (l'erba arriva
	// quasi all'acqua), poi il fondo bruno punteggiato di sassolini
	float bankm = smoothstep(0.28, 0.62, v_river);
	col = mix(col, vec3(0.74, 0.66, 0.48), bankm * 0.7);
	col = mix(col, vec3(0.33, 0.36, 0.31), smoothstep(0.5, 1.05, v_river));
	vec2 pb = wpos.xz * 5.0;
	vec2 pid = floor(pb);
	float pr = hash12(pid + 3.0);
	vec2 pj = vec2(hash12(pid + 13.0), hash12(pid + 29.0)) - 0.5;
	float pd = length(fract(pb) - 0.5 - pj * 0.5);
	float peb = smoothstep(0.32, 0.18, pd) * step(pr, 0.4) * smoothstep(0.5, 0.9, v_river);
	col = mix(col, vec3(0.56, 0.55, 0.51) * (0.8 + 0.4 * hash12(pid)), peb * 0.9);

	// --- i sentieri consumati: il manto ricorda i passi ---
	// L'usura letta dalla tela dei passi; il rumore del manto sgrana il
	// contorno (mai un bordo a pennarello) e il letto del fiume non si
	// consuma. Due soglie: erba calpestata, poi terra battuta.
	vec2 suv = (wpos.xz - sentieri_origin) / sentieri_size;
	float dentro = step(0.0, suv.x) * step(suv.x, 1.0)
			* step(0.0, suv.y) * step(suv.y, 1.0);
	float usura = texture(sentieri_tex, suv).r * dentro
			* (1.0 - smoothstep(0.25, 0.6, v_river));
	float sgrana = fbm3(rot * wpos.xz * 1.7 + 47.0) - 0.5;
	float calpestio = smoothstep(0.10, 0.45, usura + sgrana * 0.18);
	float battuta = smoothstep(0.48, 0.85, usura + sgrana * 0.26);

	// trifogli e margheritine dipinti nel manto (solo su prato aperto,
	// e MAI sul sentiero: dove si cammina i fiorellini non attecchiscono)
	vec2 cellp = wpos.xz * 2.6;
	vec2 cid = floor(cellp);
	float r1 = hash12(cid);
	vec2 jitter = vec2(hash12(cid + 7.0), hash12(cid + 19.0)) - 0.5;
	float dd = length(fract(cellp) - 0.5 - jitter * 0.55);
	float dotm = smoothstep(0.17, 0.10, dd);
	float aperto = (1.0 - fmask) * (1.0 - smoothstep(0.5, 3.0, v_hill))
			* (1.0 - smoothstep(0.05, 0.3, v_river)) * (1.0 - calpestio);
	col = mix(col, clover_color.rgb, dotm * step(r1, 0.11) * 0.75 * aperto);
	col = mix(col, daisy_color.rgb, dotm * step(0.986, r1) * 0.85 * aperto);

	// prima l'erba si spegne e ingiallisce (calpestata ogni giorno)…
	col = mix(col, col * vec3(0.90, 0.86, 0.70), calpestio * 0.55);
	// …poi affiora la terra battuta: chiara al colmo del sentiero, più
	// bruna verso l'orlo, con granelli radi che la sporcano di vivo
	vec3 terra = mix(terra_orlo.rgb, terra_battuta.rgb,
			smoothstep(0.45, 0.95, usura + sgrana * 0.2));
	vec2 gb = wpos.xz * 7.0;
	vec2 gid = floor(gb);
	float gr = hash12(gid + 51.0);
	vec2 gj = vec2(hash12(gid + 63.0), hash12(gid + 71.0)) - 0.5;
	float gd = length(fract(gb) - 0.5 - gj * 0.5);
	float granello = smoothstep(0.24, 0.12, gd) * step(gr, 0.3);
	terra = mix(terra, terra * (0.82 + 0.36 * hash12(gid)), granello);
	col = mix(col, terra, battuta);

	// prospettiva aerea: più il rilievo sale, più si vela di foschia
	// verde-azzurra, e le cime delle montagne sfumano in crema pastello.
	// D'inverno la foschia e le cime virano al bianco-cielo: l'orizzonte
	// innevato, non solo il prato.
	float aria = clamp(v_hill * 0.045, 0.0, 0.55);
	vec3 haze = mix(vec3(0.78, 0.87, 0.81), vec3(0.90, 0.94, 1.0), snow_amount);
	vec3 peak = mix(vec3(0.96, 0.95, 0.90), vec3(0.97, 0.98, 1.0), snow_amount);
	col = mix(col, haze, aria);
	col = mix(col, peak, smoothstep(15.0, 27.0, v_hill) * 0.8);

	// pioggia: manto scuro e lucido, rugiada che scintilla
	col *= 1.0 - 0.18 * wetness;
	float glint = step(0.993, hash12(floor(wpos.xz * 22.0) + floor(TIME * 2.5)));
	EMISSION = vec3(0.50, 0.60, 0.55) * glint * wetness * 0.4;

	// --- la neve dell'inverno: la coltre bianca sul prato ---
	// due scale di rumore danno cumuli e conche sgombre — mai un lenzuolo
	// piatto; l'acqua del fiume non si copre (le sponde sì)
	if (snow_amount > 0.001) {
		float drift = fbm(wpos.xz * 0.6 + 20.0) * 0.6 + fbm(wpos.xz * 2.1 + 4.0) * 0.4;
		float cover = smoothstep(0.32, 0.78, drift + snow_amount * 0.55 - 0.08) * snow_amount;
		cover *= 1.0 - smoothstep(0.5, 0.95, v_river);
		cover = clamp(cover, 0.0, 0.93);
		col = mix(col, vec3(0.93, 0.95, 1.0), cover);
		// cristalli radi che scintillano al sole
		float sglint = step(0.9, hash12(floor(wpos.xz * 26.0))) * step(0.42, drift);
		EMISSION += vec3(0.60, 0.66, 0.80) * sglint * cover * 0.22;
	}

	// --- LE POZZANGHERE: gli specchi che la pioggia lascia nel prato ---
	// Una sola verità fisica, imitata bene: l'acqua si raccoglie nelle
	// CONCHE (un campo fbm stabile in spazio-mondo) e ancora di più sulla
	// terra battuta dei sentieri, che non beve. Dentro lo specchio: il
	// cielo VERO del DayNight in gradiente (più cupola col fresnel) sopra
	// il fondo scurito del manto — e la roughness crolla, così il
	// radiance della cupola ci si riflette davvero, come nello stagno.
	// L'orlo bagnato scurisce un anello attorno; mentre piove, anelli di
	// gocce increspano la superficie; appena smette, specchio calmo.
	float pozza = 0.0;
	if (pozzanghere > 0.001 && snow_amount < 0.5) {
		// la banda della soglia è STRETTA apposta: a specchi pieni l'acqua
		// copre ~un decimo del prato (conche vere), mai una piana allagata
		float conca = fbm(rot * wpos.xz * 0.5 + 3.7);
		float livello = mix(0.12, 0.30, pozzanghere) + 0.05 * battuta;
		float adatto = (1.0 - smoothstep(0.3, 1.4, v_hill))
				* (1.0 - smoothstep(0.25, 0.55, v_river))
				* (1.0 - fmask * 0.65) * (1.0 - snow_amount);
		pozza = smoothstep(livello, livello - 0.10, conca) * adatto;
		float orlo = smoothstep(livello + 0.09, livello, conca) * adatto
				* (1.0 - pozza);
		col *= 1.0 - 0.16 * orlo;
		if (pozza > 0.001) {
			// l'acqua respira: deriva calma sempre (lo stesso passo dello
			// stagno), anelli di pioggia solo mentre cade
			float w1 = fbm(wpos.xz * 1.6 + vec2(TIME * 0.10, TIME * 0.07));
			float w2 = fbm(wpos.xz * 1.6 - vec2(TIME * 0.08, -TIME * 0.11) + 7.0);
			vec2 rp = wpos.xz * 1.8;
			vec2 rid = floor(rp);
			float rh = hash12(rid);
			float rph = fract(TIME * 0.8 + rh);
			vec2 roff = (vec2(hash12(rid + 5.0), hash12(rid + 9.0)) - 0.5) * 0.5;
			float rdst = length(fract(rp) - 0.5 - roff);
			float anello = smoothstep(0.055, 0.0, abs(rdst - rph * 0.42))
					* (1.0 - rph) * pioggia_cade;
			NORMAL = normalize(NORMAL + vec3((w1 - 0.5) * 0.10 + anello * 0.30, 0.0,
					(w2 - 0.5) * 0.10 - anello * 0.25) * pozza);
			// il cielo dentro l'acqua: all'incidenza radente lo specchio
			// vince (fresnel), a piombo si vede il fondo scuro del manto
			float fresp = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
			vec3 cielo = mix(cielo_orizzonte.rgb, cielo_alto.rgb, 0.25 + 0.5 * fresp);
			col = mix(col, mix(col * 0.45, cielo, 0.38 + 0.45 * fresp), pozza);
			// gli anelli si leggono anche come luce, non solo come rilievo
			EMISSION += cielo * anello * 0.12 * pozza;
		}
	}

	ALBEDO = col;
	ROUGHNESS = mix(1.0 - 0.4 * wetness, 0.045, pozza);
	SPECULAR = mix(0.05 + 0.3 * wetness, 0.75, pozza);
}
