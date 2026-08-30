shader_type spatial;
render_mode shadows_disabled;

// Le ali delle farfalle dell'ecosistema: il battito vive nel vertex
// shader (costo zero per CPU), lo sfasamento e la specie arrivano per
// istanza dal MultiMesh (INSTANCE_CUSTOM = sfasamento, specie, velocità).
//
// ATTENZIONE: INSTANCE_CUSTOM.x dev'essere una COSTANTE 0..1 (serve solo a
// far battere le ali fuori sincrono l'una dall'altra). Se ci arrivasse
// l'orologio interno del C++, che accumula, la sua derivata ×6.283 si
// sommerebbe alla frequenza del battito e tutte accelererebbero insieme.
//
// LA MESH la fa `scenes/world/FarfalleGeo.gd` ed è chiusa (dorso e
// ventre): niente `cull_disabled` — prima era una LASTRA di quattro
// triangoli e serviva.
//
// ⚠️ E IL COLOR DEI VERTICI È UN CONTRATTO:
//   a = 1 ala · 0 corpo    g = 0 anteriore · 1 posteriore
// Prima il corpo era «tutto ciò che sta entro |x| < 0.0714», una banda
// DIPINTA: un torace modellato verrebbe piegato come un'ala e tinto di
// scuro. Adesso il torace lo dice la mesh, e la cerniera è oltre il suo
// raggio.
uniform vec3 col_a: source_color = vec3(0.96, 0.70, 0.80);
uniform vec3 col_b: source_color = vec3(0.62, 0.79, 0.95);
uniform vec3 col_c: source_color = vec3(0.98, 0.89, 0.60);
// il raggio del torace: la stessa costante di FarfalleGeo.RAGGIO_TORACE
uniform float raggio_torace = 0.014;

varying float body_k;
varying float kind;
// quanto si è lontani dalla cerniera: serve all'orlo scuro
varying float orlo;

// LA BATTUTA, e ce n'è UNA SOLA in tutto il gioco: la trascrizione di
// `FarfalleGeo.battito`. Fronti ripidi e colmo PIATTO — una farfalla
// scende in fretta, risale piano, e in cima si ferma un istante. Un
// `sin()` puro ha salita e discesa identiche e nessuna pausa: è il
// carillon che si smaschera in due cicli.
float battito(float theta) {
	float s = sin(theta);
	return sign(s) * pow(abs(s), 0.62);
}

void vertex() {
	float sfasamento = INSTANCE_CUSTOM.x;
	float speed = INSTANCE_CUSTOM.z; // 1 in volo, giù quando sorseggia
	kind = INSTANCE_CUSTOM.y;
	body_k = 1.0 - COLOR.a;
	orlo = COLOR.r;

	// l'ala POSTERIORE parte in ritardo sull'anteriore: sono quattro ali,
	// non due, e il ritardo è la cosa che lo dice senza doverlo guardare
	float theta = TIME * (15.0 * speed + 2.5) + sfasamento * 6.283
			- COLOR.g * 0.55;
	float sw = battito(theta);
	float a = (0.45 + 0.5 * speed) * abs(sw);

	float sx = sign(VERTEX.x);
	float dentro = min(abs(VERTEX.x), raggio_torace);
	float w = max(abs(VERTEX.x) - raggio_torace, 0.0);
	VERTEX.x = sx * (dentro + w * cos(a));
	VERTEX.y += w * sin(a) * 0.9;
	// il corpo sale sulla battuta in giù: è il rimbalzo di portanza, e
	// senza di lui la farfalla vola come un cartoncino trainato
	VERTEX.y += body_k * sw * -0.004;

	// LE NORMALI GIRANO COL BATTITO. Prima erano tutte UP e nessuno le
	// toccava: in piena battuta l'ala restava illuminata come una lastra
	// orizzontale, cioè la luce non sapeva che si era mossa.
	float phi = sx * a * COLOR.a;
	float cf = cos(phi);
	float sf = sin(phi);
	NORMAL = vec3(NORMAL.x * cf - NORMAL.y * sf,
			NORMAL.x * sf + NORMAL.y * cf, NORMAL.z);
}

void fragment() {
	vec3 wing = kind < 0.5 ? col_a : (kind < 1.5 ? col_b : col_c);
	// L'ORLO SCURO. Le ali di una farfalla hanno il margine più scuro
	// del centro, ed è il segno che a sei metri la distingue da un
	// coriandolo colorato. Costa una `smoothstep`.
	wing = mix(wing, wing * 0.52, smoothstep(0.68, 1.0, orlo));
	ALBEDO = mix(wing, wing * 0.4, body_k);
	// un filo di luce propria: leggibili anche nell'ombra del bosco
	EMISSION = wing * 0.22 * (1.0 - body_k);
}
