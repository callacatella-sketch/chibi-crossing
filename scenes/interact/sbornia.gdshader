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
uniform sampler2D schermo_mip : hint_screen_texture, filter_linear_mipmap;
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

		// il colore dal MIP dello schermo: una sfocatura VERA (cinque
		// tappi sparsi non lo erano: ogni tappo beccava ancora i singoli
		// fili d'erba). A lod 2 il prato e' un campo piatto di colore.
		vec3 c = textureLod(schermo_mip, uvq, mix(0.5, 2.2, sbronza)).rgb;
		// la DOPPIA VISIONE: un secondo disegno, spostato, che gira piano
		vec2 sdoppio = vec2(sin(TIME * 0.47), cos(TIME * 0.31)) * 0.011 * sbronza;
		c = mix(c, textureLod(schermo_mip, uvq + sdoppio, 2.0).rgb, 0.30 * sbronza);

		// 3) il CONTORNO a inchiostro, a DUE scale:
		//  - le FORME GRANDI, dal mip profondo (a lod 4 l'erba non esiste
		//    piu': la penna passa solo su Mochi, i tronchi, i pezzi);
		//  - i CIUFFETTI, dal mip fine ma RAZIONATI: scattano solo in un
		//    blocco su otto, scelto dal caso — sono le V dell'erba dei
		//    disegni fatti col mouse, poche apposta
		// (il gradiente si misura a DIFFERENZE FINITE alla scala del mip:
		// le derivate per-pixel di un'immagine cosi' sfocata sono briciole
		// e l'inchiostro non scattava mai)
		float lodg = mix(1.0, 3.8, sbronza);
		float dl = mix(0.003, 0.0075, sbronza);
		float glx = lum(textureLod(schermo_mip, uvq + vec2(dl, 0.0), lodg).rgb)
				- lum(textureLod(schermo_mip, uvq - vec2(dl, 0.0), lodg).rgb);
		float gly = lum(textureLod(schermo_mip, uvq + vec2(0.0, dl * 1.78), lodg).rgb)
				- lum(textureLod(schermo_mip, uvq - vec2(0.0, dl * 1.78), lodg).rgb);
		float bordo = smoothstep(0.115, 0.15, abs(glx) + abs(gly));
		vec2 gcel = floor(uv * res / 5.0);
		float raro = step(0.88, bava(gcel * 0.37 + floor(t6 * 3.0) * 0.11));
		float cfx = lum(textureLod(schermo_mip, uvq + vec2(0.0016, 0.0), 1.3).rgb)
				- lum(textureLod(schermo_mip, uvq - vec2(0.0016, 0.0), 1.3).rgb);
		float cfy = lum(textureLod(schermo_mip, uvq + vec2(0.0, 0.0028), 1.3).rgb)
				- lum(textureLod(schermo_mip, uvq - vec2(0.0, 0.0028), 1.3).rgb);
		float ciuffo = smoothstep(0.09, 0.20, abs(cfx) + abs(cfy)) * raro;
		bordo = max(bordo, ciuffo * 0.85);

		// cosa c'era DAVVERO li' (saturazione e luce prima del trucco):
		// serve alla modalita' foglio per decidere cosa disegnare
		float sat0 = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
		float lu0 = lum(c);

		// 4) i colori da PROGRAMMA DI DISEGNO: pochi livelli, dither
		//    sgranato, saturazione da pennarello nuovo
		float livelli = mix(24.0, 6.0, sbronza);
		float bayer = mod(cella.x + 2.0 * mod(cella.y, 2.0), 4.0) / 4.0 - 0.375;
		c = floor(c * livelli + bayer * 0.5 * sbronza) / livelli;
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
		float banda = fract((uv.x * 1.55 + uv.y) * 12.0
				+ bava(vec2(floor((uv.x * 1.55 + uv.y) * 12.0), t6)) * 0.7);
		float svogliato = smoothstep(0.62, 0.80, banda) * (1.0 - foglio);
		c = mix(c, mix(c, vec3(0.96), 0.45),
				svogliato * sbronza * sbronza * 0.55 * (1.0 - smoothstep(0.5, 0.9, sbronza)));

		// 7) la MODALITA' FOGLIO: e' qui che il disegno diventa QUELLO —
		//    stilizzato e con pochissimi dettagli. Da meta' sbronza in su
		//    quasi tutto si cancella nella carta bianca: si disegna solo
		//    cio' che si nota — le macchie di colore FORTE, riempite a
		//    scarabocchio con le striature bianche di chi colora di
		//    fretta. Tutto il resto: foglio.
		float carta = smoothstep(0.5, 0.95, sbronza);
		float macchia = smoothstep(0.38, 0.58, sat0)
				* (1.0 - smoothstep(0.75, 0.92, lu0));
		vec3 penna = clamp(mix(vec3(lu0), c, 2.2), 0.0, 1.0);
		float fitto = smoothstep(0.25, 0.5,
				fract(banda * 2.7 + bava(cella * 0.13 + t6)));
		vec3 riempi = mix(vec3(0.988, 0.988, 0.978), penna,
				macchia * (0.55 + 0.45 * fitto));
		c = mix(c, riempi, carta);

		// l'inchiostro sopra tutto, come nel disegno vero
		c = mix(c, vec3(0.06, 0.05, 0.09), bordo * min(1.0, sbronza * 1.35));

		COLOR = vec4(mix(orig, c, smoothstep(0.0, 0.22, sbronza)), 1.0);
	}
}
