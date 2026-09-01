shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Materiale "dipinto a mano": due colori mescolati da un lavaggio
// pittorico (fbm), cel-shading morbido, rim light e vento opzionale
// per erba e fogliame.
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.92, 0.88, 0.82, 1.0);
uniform float noise_scale = 4.0;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.45;
uniform bool use_world_noise = false;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform float wind_strength = 0.0;
uniform float wind_speed = 1.4;

// --- LE CHIOME NEL VENTO ---------------------------------------------
// `wind_strength` qui sopra è l'ondina locale di erbette e bucato: sale
// col quadrato dell'altezza e non ha idea di dove sia il mondo. Per una
// CHIOMA non basta: un albero non oscilla per conto suo, si piega quando
// la folata arriva fin lì — la stessa folata che un istante prima ha
// piegato l'erba di là (shaders/vento.gdshaderinc).
//   chioma       l'ampiezza del piegamento (0 = non è fogliame)
//   chioma_base  sotto questa quota LOCALE nulla si muove: è l'attaccatura
//                al ramo, e deve restare inchiodata o le foglie si
//                staccano dal tronco
//   chioma_span  in quanta altezza si arriva al piegamento pieno
uniform float chioma = 0.0;
uniform float chioma_base = 0.0;
uniform float chioma_span = 1.0;
#include "res://shaders/vento.gdshaderinc"
// 0 = opaco; > 0 = il controluce attraversa la materia (fronde, petali):
// il sole alle spalle di una chioma la accende di verde-oro
uniform float translucency : hint_range(0.0, 1.0) = 0.0;

// --- I FIORI: TRE ORGANI IN UNA SUPERFICIE SOLA ----------------------
// Un fiore è largo otto centimetri: tre superfici erano tre draw call
// per niente. La maschera d'organo viaggia nel COLOR dei vertici —
// r petalo, g cuore, b verde — e `a` porta la FASE personale del
// petalo, perché una corolla che si muove tutta insieme è un palloncino.
// Tutto spento di serie: nessun altro materiale dipinto a mano cambia
// di un bit.
uniform bool usa_organi = false;
uniform vec4 organo_cuore : source_color = vec4(1.0);
uniform vec4 organo_verde : source_color = vec4(1.0);
// IL COLLETTO: quanto si scurisce la base della pianta. Le radici in
// ombra e le punte accese sono ciò che fa sembrare un fiore PIANTATO
// invece che appoggiato — è la stessa regola con cui il filo d'erba si
// fonde col suolo.
uniform float colletto : hint_range(0.0, 1.0) = 0.0;
// IL RITARDO DELLA TESTA. Sopra `testa_base` la corolla campiona la
// STESSA folata un filo indietro nel tempo: arriva dopo lo stelo e
// torna dopo. Non è un secondo seno da tarare — è il peso del fiore,
// e costa una seconda valutazione della folata che c'è già.
uniform float testa = 0.0;
uniform float testa_base = 0.0;
uniform float testa_ritardo = 0.14;
// il fremito del singolo petalo, in metri: minuscolo apposta
uniform float fremito = 0.0;
// L'ORLO SCURO DI UN'ALA. `COLOR.r` porta la distanza dalla cerniera, e
// il margine si scurisce: è il segno che a sei metri distingue una
// farfalla da un coriandolo colorato.
// ⚠️ Serve QUI perché le cinque farfalle NOMINATE — quelle che il
// retino cattura e che si posano sul naso di Mochi — sono dipinte da
// questo shader, mentre le novanta del MultiMesh hanno il loro
// (`butterfly.gdshader`). Senza, i due montaggi della STESSA sagoma
// renderebbero in modo diverso, che è esattamente ciò che avere una
// sagoma sola serve a impedire.
// (Non convive con `usa_organi`: là `COLOR.r` è la maschera del petalo.
// Nessun materiale accende tutti e due, e non deve cominciare.)
uniform float orlo = 0.0;
// LA VARIAZIONE PER ISTANZA. In un prato non ci sono due fiori dello
// stesso identico colore: qui la tinta si sposta di poco, e lo
// spostamento arriva dal MultiMesh (`INSTANCE_CUSTOM.x`, un numero fisso
// per istanza). ⚠️ Non passa da `use_colors`: il COLOR dei vertici è la
// maschera d'organo, e Godot ci moltiplicherebbe dentro il colore
// d'istanza — i petali diventerebbero del colore del gambo.
// Zero vuol dire «nessun dato»: un fiore non istanziato non si sposta.
uniform float varia_tinta = 0.0;

// L'INVERNO che copre il mondo: la neve si posa sulle facce rivolte al
// cielo di tutto ciò che è dipinto a mano — chiome, cespugli, sassi,
// tetti, tumuli dell'orto. Un solo globale pilota l'intera nevicata
// (come mochi_pos/erba_bagnata), acceso dal regista delle stagioni.
global uniform float snow_amount;
// il mondo si copre di neve, i personaggi no: il guardaroba di Mochi
// (cappelli, sciarpe, l'impermeabile) alza questo flag per non innevarsi
uniform bool no_snow = false;

varying vec3 v_pos;
// l'altezza LOCALE del vertice: v_pos per i fiori è in spazio-mondo
// (use_world_noise), e il colletto vuole sapere quanto si è alti sopra
// le proprie radici, non sopra il livello del mare
varying float v_alt;
// il numero personale di questa istanza (0 = non è istanziata)
varying float v_varia;
// la componente verticale della normale in spazio-mondo: quanto una
// faccia guarda il cielo, e quindi quanta neve ci si posa sopra
varying float v_up;

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
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_pos = use_world_noise ? wp : VERTEX;
	v_alt = VERTEX.y;
	v_varia = INSTANCE_CUSTOM.x;
	// dove punta la faccia, in spazio-mondo: la neve cade dall'alto
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	if (wind_strength > 0.0) {
		float h = max(VERTEX.y, 0.0);
		float sway = sin(TIME * wind_speed + wp.x * 0.9 + wp.z * 0.7) * wind_strength * h * h;
		VERTEX.x += sway;
		VERTEX.z += sway * 0.5;
	}

	// --- la chioma che respira ---
	if (chioma > 0.0) {
		// quanto questo vertice appartiene alla FRANGIA: all'attaccatura
		// del ramo niente, in cima tutto. Lo smoothstep evita lo scalino
		// (un peso lineare fa "piegare" la chioma da un punto preciso, e
		// si vede una cerniera)
		float w = clamp((VERTEX.y - chioma_base) / max(chioma_span, 0.001), 0.0, 1.0);
		w = w * w * (3.0 - 2.0 * w);
		// e i lobi esterni ballano più del cuore: una chioma che si sposta
		// tutta insieme sembra un palloncino, non fogliame
		w *= 0.55 + 0.45 * clamp(length(VERTEX.xz) * 0.7, 0.0, 1.0);

		vec2 dir = vento_direzione();
		float folata = vento_folata(wp.xz, TIME);
		// la brezza personale dell'albero: nessuna chioma è mai ferma del
		// tutto, e la fase viene da DOVE È PIANTATO — due alberi vicini non
		// respirano mai all'unisono (è la prima cosa che tradisce
		// un'animazione fatta a macchina)
		float fase = vento_fase(MODEL_MATRIX[3].xz);
		float brezza = sin(TIME * 0.9 + fase) * 0.35 + sin(TIME * 1.37 + fase * 1.7) * 0.15;

		float piega = (folata + brezza * 0.35) * chioma * w;
		VERTEX.xz += dir * piega;

		// --- il RITARDO della testa: il peso del fiore ---
		// la corolla non è un adesivo sullo stelo: la folata la raggiunge
		// dopo, e la lascia dopo. Si campiona la stessa folata a
		// TIME − testa_ritardo e si somma la DIFFERENZA, così quando il
		// vento è fermo la testa non si sposta di un millimetro.
		if (testa > 0.0) {
			float ht = smoothstep(testa_base, testa_base + 0.055, VERTEX.y);
			float dietro = vento_folata(wp.xz, TIME - testa_ritardo);
			VERTEX.xz += dir * (dietro - folata) * chioma * w * ht * testa;
		}
		// --- il fremito del singolo PETALO ---
		// la fase viene da COLOR.a, che è personale di ogni petalo: due
		// petali della stessa corolla non si muovono mai insieme, ed è
		// la differenza fra una corolla e una girandola
		if (fremito > 0.0) {
			float fp = COLOR.a * 6.283 + fase;
			float viv = (0.45 + 0.55 * folata) * COLOR.r;
			VERTEX.x += sin(TIME * 3.7 + fp) * fremito * viv;
			VERTEX.y += sin(TIME * 4.9 + fp * 1.7) * fremito * 0.7 * viv;
			VERTEX.z += cos(TIME * 4.3 + fp * 1.3) * fremito * viv;
		}
		// piegandosi la chioma SCENDE un poco: è una rotazione attorno al
		// ramo, non una traslazione — senza questo sembra che scivoli via
		VERTEX.y -= abs(piega) * 0.35;

		// il fremito delle foglie: frequenza alta, ampiezza minuscola, e
		// vivo soprattutto quando la folata è in pieno
		float viva = 0.35 + 0.65 * folata;
		VERTEX.x += sin(TIME * 7.3 + wp.x * 3.1 + wp.z * 2.7 + fase) * chioma * 0.07 * w * viva;
		VERTEX.z += cos(TIME * 6.1 + wp.z * 2.9 + fase * 1.3) * chioma * 0.06 * w * viva;
	}
}

void fragment() {
	vec2 uv = v_pos.xz + vec2(v_pos.y * 0.7, v_pos.y * 0.3);
	float n = fbm(uv * noise_scale + 3.1);
	float wash = smoothstep(0.32, 0.78, n);
	ALBEDO = mix(color_a.rgb, color_b.rgb, wash * noise_amount);
	if (usa_organi) {
		// ogni organo prende il PROPRIO lavaggio: un cuore dorato lavato
		// col bianco dei petali diventa un uovo al tegamino
		float k = wash * noise_amount;
		ALBEDO = ALBEDO * COLOR.r
				+ mix(organo_cuore.rgb, organo_cuore.rgb * 0.76, k) * COLOR.g
				+ mix(organo_verde.rgb, organo_verde.rgb * 0.72, k) * COLOR.b;
		ALBEDO *= mix(1.0 - colletto, 1.0, smoothstep(0.0, 0.06, v_alt));
		if (varia_tinta > 0.0 && v_varia > 0.001) {
			float d = (v_varia - 0.53) * 2.13;
			// caldo/freddo più un filo di valore: i due assi lungo cui
			// varia un fiore vero. Il caso puro fa sale e pepe; queste
			// due leve, piccole, fanno un dipinto
			ALBEDO *= vec3(1.0 + 0.085 * d, 1.0 + 0.018 * d, 1.0 - 0.070 * d)
					* (1.0 + 0.075 * (fract(v_varia * 7.31) - 0.5)) * varia_tinta
					+ vec3(1.0 - varia_tinta);
		}
	}
	if (orlo > 0.0) {
		ALBEDO = mix(ALBEDO, ALBEDO * 0.52,
				smoothstep(0.68, 1.0, COLOR.r) * orlo);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
	// base minima di rim, sempre accesa: leggibilità notturna delle
	// silhouette. Il rim VERO, direzionale, vive in light().
	float rim = 1.0 - dot(normalize(NORMAL), normalize(VIEW));
	rim = smoothstep(0.6, 0.95, rim);
	EMISSION = rim_color.rgb * rim * rim_strength * 0.35;

	// --- la neve dell'inverno ---
	// si posa sulle facce rivolte al cielo, a chiazze irregolari (un fbm
	// rompe il bordo: cumuli, non un velo uniforme); più il globale sale,
	// più il manto bianco scende lungo i fianchi delle chiome
	if (snow_amount > 0.001 && !no_snow) {
		float drift = fbm(v_pos.xz * 2.3 + v_pos.y * 0.6 + 5.0) - 0.5;
		float cover = smoothstep(0.28, 0.72, clamp(v_up, 0.0, 1.0) + drift * 0.4) * snow_amount;
		vec3 snow_col = vec3(0.95, 0.965, 1.0);
		ALBEDO = mix(ALBEDO, snow_col, cover);
		ROUGHNESS = mix(ROUGHNESS, 1.0, cover);
		// un brillio freddo e sparso sui cumuli — i cristalli al sole
		float sparkle = step(0.86, fbm(v_pos.xz * 30.0 + 3.0)) * cover;
		EMISSION += vec3(0.55, 0.62, 0.75) * sparkle * 0.25;
	}
}

// Lo stesso gradino di luce del toon dei chibi: mondo e personaggi
// rispondono alla stessa regola. Il lato in ombra resta spento: lo
// dipinge l'ambiente freddo del DayNight (l'ombra "di un altro colore").
void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	float lit = smoothstep(0.03, 0.42, dot(n, l) * ATTENUATION);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * lit;

	// rim DIREZIONALE: il bordo si accende solo sul lato della luce,
	// col colore della luce — è luce vera, non un effetto appiccicato
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	float side = smoothstep(-0.15, 0.55, dot(n, l));
	DIFFUSE_LIGHT += rim_color.rgb * LIGHT_COLOR * fres * side
			* rim_strength * 1.3 * clamp(ATTENUATION, 0.0, 1.0);

	// controluce (fronde, petali): la luce che ATTRAVERSA la materia,
	// con la normale che devia il fascio (SSS economico ma credibile).
	// Vivo anche in mezz'ombra: è la frangia della chioma a brillare.
	if (translucency > 0.001) {
		vec3 lt = normalize(l + n * 0.35);
		float back = pow(clamp(dot(v, -lt), 0.0, 1.0), 3.0);
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * back * translucency
				* (0.35 + 0.65 * clamp(ATTENUATION, 0.0, 1.0));
	}
}
