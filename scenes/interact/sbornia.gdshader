shader_type canvas_item;
render_mode unshaded;

// LA SBORNIA DI SUCCO DI MELA — il mondo ridisegnato col mouse.
//
// Dopo troppi bicchieri al bar, il gioco smette di essere dipinto e
// diventa uno SCARABOCCHIO da vecchio programma di disegno: pixel
// ciccioni, contorni a inchiostro che tremano come una mano sul mouse,
// colori sparati da pennarello che scappano fuori dai bordi, il cielo
// che torna FOGLIO BIANCO, e tutto che ondeggia piano. Sta SOPRA il
// HUD apposta: anche le barrette e i numeri escono disegnati male.
//
// `sbronza` va da 0 (sobria) a 1 (il mondo fa ridere); la scrive
// Sbornia.gd ogni frame. A 0 lo shader restituisce lo schermo intatto.

uniform sampler2D schermo : hint_screen_texture, filter_nearest;
uniform float sbronza : hint_range(0.0, 1.0) = 0.0;

float bava(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 orig = texture(schermo, SCREEN_UV).rgb;
	if (sbronza < 0.003) {
		COLOR = vec4(orig, 1.0);
	} else {
		// il tempo della MANO: il disegno si ridisegna sei volte al
		// secondo, come un'animazione fatta coi fogli
		float t6 = floor(TIME * 6.0) / 6.0;

		// 1) l'ONDEGGIO: lento e continuo, da ginocchia incerte
		vec2 uv = SCREEN_UV;
		uv.x += sin(uv.y * 3.3 + TIME * 0.7) * 0.007 * sbronza;
		uv.y += sin(uv.x * 2.6 + TIME * 0.53) * 0.005 * sbronza;

		// 2) i PIXEL CICCIONI, col tremito della mano cella per cella
		float chunk = mix(640.0, 168.0, sbronza);
		vec2 res = vec2(chunk, chunk * 0.5625);
		vec2 cella = floor(uv * res);
		vec2 trem = (vec2(bava(cella + t6), bava(cella + t6 + 31.7)) - 0.5)
				* (2.6 / res) * sbronza;
		vec2 uvq = (cella + 0.5) / res + trem;

		vec3 c = texture(schermo, uvq).rgb;
		// la DOPPIA VISIONE: un secondo disegno, spostato, che gira piano
		vec2 sdoppio = vec2(sin(TIME * 0.47), cos(TIME * 0.31)) * 0.011 * sbronza;
		c = mix(c, texture(schermo, uvq + sdoppio).rgb, 0.35 * sbronza);

		// 3) il CONTORNO a inchiostro: dove il colore salta, la penna
		//    passa — e siccome trema la cella, trema anche la linea
		vec2 passo = 1.0 / res;
		float l0 = lum(c);
		float gx = lum(texture(schermo, uvq + vec2(passo.x, 0.0)).rgb) - l0;
		float gy = lum(texture(schermo, uvq + vec2(0.0, passo.y)).rgb) - l0;
		float bordo = smoothstep(0.09, 0.24, abs(gx) + abs(gy));

		// 4) i colori da PROGRAMMA DI DISEGNO: pochi livelli, dither
		//    sgranato, saturazione da pennarello nuovo
		float livelli = mix(24.0, 5.0, sbronza);
		float bayer = mod(cella.x + 2.0 * mod(cella.y, 2.0), 4.0) / 4.0 - 0.375;
		c = floor(c * livelli + bayer * sbronza) / livelli;
		float lu = lum(c);
		c = clamp(mix(vec3(lu), c, 1.0 + 0.9 * sbronza), 0.0, 1.0);

		// 5) il FOGLIO: il chiaro poco saturo torna carta bianca (il
		//    cielo, i muri): nessuno si e' preso la briga di colorarlo
		float satur = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
		float foglio = smoothstep(0.60, 0.85, lu)
				* (1.0 - smoothstep(0.20, 0.45, satur));
		c = mix(c, vec3(0.985, 0.985, 0.975), foglio * sbronza);

		// 6) lo SCARABOCCHIO SVOGLIATO: il riempimento non copre mai
		//    tutto — bande diagonali dove la mano e' passata, e chiazze
		//    lasciate in bianco come in ogni disegno fatto di fretta
		float banda = fract((uv.x * 1.55 + uv.y) * 26.0
				+ bava(vec2(floor((uv.x * 1.55 + uv.y) * 26.0), t6)) * 0.7);
		float svogliato = smoothstep(0.52, 0.72, banda) * (1.0 - foglio);
		c = mix(c, mix(c, vec3(0.96), 0.55), svogliato * sbronza * 0.75);

		// l'inchiostro sopra tutto, come nel disegno vero
		c = mix(c, vec3(0.06, 0.05, 0.09), bordo * min(1.0, sbronza * 1.35));

		COLOR = vec4(mix(orig, c, smoothstep(0.0, 0.22, sbronza)), 1.0);
	}
}
