shader_type spatial;

// L'ACQUA FERMA CHE PERÒ VIVE — lo stagno del prato, la vasca dell'onsen
// e il taglio delle ninfee vestono TUTTI questo shader (una fonte sola:
// ogni manopola nuova ha un default che lascia gli altri due come erano).
//
// Un'acqua senza corrente non è un'acqua senza vita: quello che la fa
// leggere come acqua, e non come vetro smerigliato, sono quattro cose,
// in ordine di importanza percettiva:
//   1. LE CAPILLARI. Increspature FINI (non le nuvole larghe di prima):
//      sono loro a spezzare la riflessione speculare del sole in mille
//      scintille — il "sentiero di luce". Il luccichio non lo dipingiamo
//      noi: gli diamo le normali giuste e ci pensa la luce vera.
//   2. IL CIELO DENTRO L'ACQUA. Non il grigio della cupola ma il cielo
//      VERO del DayNight (cielo_alto/cielo_orizzonte, riscritti ogni
//      frame), pesato col fresnel: a piombo si vede il fondo, di
//      striscio si vede il tramonto. È gratis e vale metà dell'effetto.
//   3. IL RESPIRO LUNGO. Tre treni d'onda incrociati sui vertici, con
//      periodi incommensurabili (mai un battito riconoscibile), che si
//      SPENGONO sulla riva: l'acqua non si stacca mai dalla sabbia.
//   4. LA BATTIGIA. Dove l'acqua tocca la terra, un velo chiaro che
//      respira con le onde e si fa più trasparente: si intravede il
//      fondo, e il disco smette di sembrare un coperchio appoggiato.
//
// Nota di geometria: le onde sui vertici hanno senso solo su una mesh
// TASSELLATA (WorldGeo.disco_acqua). Il cappello del CylinderMesh è un
// ventaglio con un solo vertice al centro: lì l'onda fa il cono, non
// l'onda. Onsen e ninfee usano ancora cilindri/box, e per loro le onde
// restano il bobbing minimo di sempre — nessuna regressione.
uniform vec4 shallow_col : source_color = vec4(0.5, 0.78, 0.74, 1.0);
uniform vec4 deep_col : source_color = vec4(0.16, 0.42, 0.52, 1.0);
uniform float radius = 3.6;
// quanto l'acqua è increspata: 1 = stagno all'aperto, 0 = specchio
uniform float increspatura : hint_range(0.0, 2.0) = 1.0;
// quanto il cielo vero ci si specchia dentro (l'onsen fuma, riflette meno)
uniform float specchio : hint_range(0.0, 1.0) = 1.0;
// il velo chiaro della battigia (0 = il bordo resta netto)
uniform float battigia : hint_range(0.0, 1.0) = 1.0;
// il colore di CIÒ CHE STA INTORNO allo specchio (la fila scura degli
// alberi, le sponde): è quello che il raggio riflesso incontra quando
// punta basso, e senza di lui l'acqua a mezzogiorno diventa latte
uniform vec4 intorno_col : source_color = vec4(0.20, 0.30, 0.26, 1.0);

// il cielo del DayNight, già scritto ogni frame per tutto il mondo
global uniform vec4 cielo_alto;
global uniform vec4 cielo_orizzonte;
// d'inverno l'acqua si fa lastra: meno increspature, più riflesso freddo
global uniform float snow_amount;

varying vec3 wpos;
varying vec2 luv;
varying float v_onda;   // la quota dell'onda: serve alla schiuma di cresta

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

// quanta luce c'è nell'ora corrente (0 notte fonda, 1 pieno giorno):
// la legge dal cielo del DayNight, senza bisogno di cablaggi
float luce_giorno() {
	return clamp(dot(cielo_alto.rgb, vec3(0.4)), 0.0, 1.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	luv = VERTEX.xz;
	float rr = clamp(length(luv) / radius, 0.0, 1.0);
	// sulla riva l'onda muore: l'acqua bassa non ha dove ondeggiare
	float orlo = 1.0 - smoothstep(0.80, 1.0, rr);
	// tre treni incrociati: direzioni sghembe e periodi incommensurabili,
	// così il moto non torna MAI su se stesso in modo riconoscibile
	float a = sin(TIME * 1.35 + dot(wpos.xz, vec2(0.92, 0.39)) * 3.1);
	float b = sin(TIME * 0.98 - dot(wpos.xz, vec2(-0.42, 0.91)) * 4.7);
	float c = sin(TIME * 1.77 + dot(wpos.xz, vec2(0.31, -0.95)) * 7.3);
	float ghiaccio = 1.0 - snow_amount * 0.75;
	v_onda = (a * 0.52 + b * 0.31 + c * 0.17) * orlo * increspatura * ghiaccio;
	VERTEX.y += v_onda * 0.016;
}

void fragment() {
	float r = clamp(length(luv) / radius, 0.0, 1.0);
	// il fondo si alza SOLO vicino alla sponda: se il verde-riva sale
	// troppo presto il bacino intero sbianca e sembra una scodella
	vec3 col = mix(deep_col.rgb, shallow_col.rgb, smoothstep(0.68, 1.0, r));

	float viva = increspatura * (1.0 - snow_amount * 0.7);
	// IL LOD DELLE INCRESPATURE. Le capillari sono fini: da lontano un
	// pixel ne contiene decine, si impastano e l'acqua diventa un velo
	// lattiginoso uniforme (l'aliasing speculare, il difetto numero uno
	// dell'acqua stilizzata). Quindi le spegniamo con la distanza: da
	// vicino l'acqua è brillante e minuta, da lontano resta il respiro
	// largo — che è anche ciò che l'occhio vero coglie.
	float vicino = 1.0 - smoothstep(4.0, 15.0, length(VERTEX));

	// due strati LARGHI e lenti: il respiro dello specchio (sono quelli
	// di sempre, che da soli però facevano solo nuvole di latte)
	float n1 = fbm(wpos.xz * 1.35 + vec2(TIME * 0.11, TIME * 0.08));
	float n2 = fbm(wpos.xz * 1.35 - vec2(TIME * 0.09, -TIME * 0.12) + 7.0);
	// e due FINI e svelti: le capillari. Sono queste a spezzare il
	// riflesso del sole in scintille — la differenza fra acqua e vetro
	float c1 = vnoise(wpos.xz * 7.4 + vec2(TIME * 0.44, -TIME * 0.27));
	float c2 = vnoise(wpos.xz * 11.9 - vec2(TIME * 0.33, TIME * 0.49) + 3.3);
	float c3 = vnoise(wpos.xz * 19.5 + vec2(-TIME * 0.21, TIME * 0.62) + 11.0);

	float fine = viva * vicino;
	// DUE normali, non una. Il riflesso del mondo è un fenomeno a LARGA
	// scala: se lo si calcola sulle capillari, cielo e bosco si scambiano
	// pixel per pixel e l'acqua diventa un mosaico di coriandoli. Perciò
	// il riflesso legge solo le onde larghe (macchie coerenti, come in
	// uno stagno vero) e le capillari restano a fare il luccichio.
	vec3 n_largo = normalize(NORMAL
			+ vec3((n1 - 0.5) * 0.30, 0.0, (n2 - 0.5) * 0.30) * viva);
	// Le capillari toccano la normale con MOLTA parsimonia. L'acqua è una
	// superficie speculare: la sua forma la racconta il riflesso, non
	// l'ombreggiatura. Con un rilievo fine marcato, la luce radente del
	// tramonto ci disegna sopra un dentellato di chiari e scuri — una
	// grattugia, non uno specchio. Il luccichio lo porta l'emissione, che
	// non ha questo problema perché si SOMMA e non spegne mai nulla.
	vec3 nrm = n_largo;
	nrm.x += ((c1 - 0.5) * 0.11 + (c3 - 0.5) * 0.05) * fine;
	nrm.z += ((c2 - 0.5) * 0.11 + (c3 - 0.5) * 0.05) * fine;
	NORMAL = normalize(nrm);

	// IL CIELO DENTRO L'ACQUA: a piombo si vede il fondo, di striscio
	// vince lo specchio. Lo stesso fresnel del prato bagnato: uno solo
	// in tutto il gioco.
	// MA uno specchio non riflette SOLO il cielo: riflette ciò che il
	// raggio incontra. Dove il raggio riflesso punta in ALTO trova il
	// cielo; dove punta BASSO trova la fila scura degli alberi e le
	// sponde. È questo contrasto — acqua cupa con squarci di cielo — che
	// fa leggere l'acqua a mezzogiorno, quando il cielo è tutto bianco e
	// specchiarlo puro faceva del bacino una scodella di latte.
	// Ed è gratis: la direzione riflessa è quattro istruzioni, e le
	// increspature la fanno saltare fra cielo e bosco pixel per pixel.
	// anche QUANTO riflette si misura sulla normale larga: sulla fine, la
	// quantità di specchio sfarfallava alla frequenza delle capillari e
	// acqua scura e cielo si dentellavano in una scacchiera. Alle
	// capillari resta il loro mestiere: il luccichio (che passa da NORMAL,
	// quella che la luce del motore legge davvero).
	float fres = pow(1.0 - clamp(dot(n_largo, VIEW), 0.0, 1.0), 2.0);
	vec3 cielo = mix(cielo_orizzonte.rgb, cielo_alto.rgb, 0.25 + 0.5 * fres);
	vec3 su_mondo = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, n_largo), 0.0)).xyz;
	// il passaggio bosco→cielo è LARGO: stretto, le due tinte si tagliano
	// a coltello e lo specchio diventa una mimetica; largo, sono le
	// sfumature morbide dell'acqua vera
	float verso_alto = smoothstep(-0.06, 0.62, su_mondo.y);
	// il bosco riflesso è ILLUMINATO DAL CIELO di quell'ora: al tramonto
	// è bruno caldo, non verde freddo — altrimenti nello specchio corallo
	// resta una scacchiera di due colori che si combattono
	vec3 intorno = intorno_col.rgb
			* mix(vec3(0.55), cielo_orizzonte.rgb * 1.7, 0.65)
			* (0.75 + 1.0 * luce_giorno());
	vec3 riflesso = mix(intorno, cielo, verso_alto);
	// e comunque resta ACQUA: un terzo di profondità sempre dentro
	riflesso = mix(riflesso, deep_col.rgb * 1.2, 0.30);
	col = mix(col, riflesso, (0.16 + 0.54 * fres) * specchio);

	// LA BATTIGIA: dove l'acqua lambisce la terra, un velo che respira
	// con l'onda — il bordo smette di essere un taglio netto. Tenue:
	// è un velo, non una spuma di risacca (lo stagno non ha onde vere)
	float lambire = smoothstep(0.88, 1.0, r + v_onda * 0.03);
	col = mix(col, mix(shallow_col.rgb, vec3(1.0), 0.32),
			lambire * 0.30 * battigia);

	ALBEDO = col;
	METALLIC = 0.0;
	// più liscia al centro (specchio), appena più opaca sulla riva mossa
	ROUGHNESS = mix(0.05, 0.16, smoothstep(0.55, 1.0, r) * viva);
	SPECULAR = 0.7;

	// l'acqua bassa lascia intravedere il fondo di sabbia: è questo che
	// la fa leggere BASSA sulla riva e profonda nel mezzo
	ALPHA = mix(0.95, 0.66, smoothstep(0.70, 1.0, r)) + fres * 0.05;
	ALPHA = clamp(ALPHA, 0.0, 1.0);

	// IL SENTIERO DI LUCE: le scintille non sono coriandoli sparsi sul
	// piatto — il glitter del sole esiste solo dove lo sguardo è RADENTE
	// (è riflessione speculare, non vernice). Perciò pesa col fresnel: a
	// piombo l'acqua è quasi liscia, di striscio si accende. E sono RARE,
	// perché nascono dal PRODOTTO di due capillari: solo dove due creste
	// coincidono — mai una grandinata uniforme.
	float creste = smoothstep(0.56, 0.86, c1 * c2 * 2.1 + (c3 - 0.5) * 0.5);
	float luce_cielo = clamp(dot(cielo_alto.rgb, vec3(0.33)), 0.0, 1.0);
	EMISSION = mix(vec3(0.95, 0.98, 1.0), cielo.rgb, 0.45)
			* creste * fine * (0.06 + 0.30 * luce_cielo) * (0.18 + 0.82 * fres);
}
