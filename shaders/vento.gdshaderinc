// L'ARIA DEL MONDO — una folata sola, per tutto ciò che il vento tocca.
//
// Prima ogni cosa aveva il suo vento per conto suo: l'erba una folata
// vera che ATTRAVERSA il prato, il bucato un'oscillazione tutta sua, e le
// chiome degli alberi... niente — stavano immobili, e si muovevano solo
// quando il taglialegna le colpiva. Bastava guardare un albero in mezzo
// all'erba che ondeggiava per sentire che l'aria non era la stessa aria.
//
// Adesso la folata è UNA e sta qui. È un'onda che viaggia sul terreno
// nella direzione del vento: quando passa, prima si piegano i fili
// d'erba di là, poi la chioma dell'albero, poi l'erba di qua. È quel
// RITARDO a far sembrare vivo il vento — molto più dell'ampiezza.
//
// Chi la usa: shaders/grass_blade.gdshader (i fili) e
// shaders/handpaint.gdshader (le chiome). Toccare i numeri qui dentro
// cambia il vento di tutto il mondo insieme, ed è esattamente il punto.

// La direzione da cui tira, sul piano del terreno.
const vec2 VENTO_DIR = vec2(0.78, 0.45);
// Quanto è LUNGA l'onda sul terreno: piccolo = folate ampie e pigre che
// coprono mezzo prato, grande = raffiche corte e nervose.
const float VENTO_SPAZIO = 0.30;
// Quanto in fretta la folata attraversa il mondo.
const float VENTO_TEMPO = 1.25;

// La forza del momento: 1 = brezza di un giorno sereno. La alza il Weather
// quando il cielo si copre, e tutto il mondo se ne accorge insieme —
// l'erba, il bucato e le chiome nello stesso istante.
global uniform float vento_forza;


float vento_hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vento_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(vento_hash12(i), vento_hash12(i + vec2(1.0, 0.0)), u.x),
			mix(vento_hash12(i + vec2(0.0, 1.0)), vento_hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec2 vento_direzione() {
	return normalize(VENTO_DIR);
}

// L'onda grezza (-1..1) nel punto del mondo dato. Il rumore che si somma
// alla fase spezza il fronte: senza, la folata arriverebbe come un muro
// dritto, e si vedrebbe.
float vento_onda(vec2 world_xz, float t) {
	return sin(dot(world_xz, vento_direzione()) * VENTO_SPAZIO - t * VENTO_TEMPO
			+ vento_vnoise(world_xz * 0.15) * 2.2);
}

// La folata, da 0 (aria ferma) a 1 (in pieno). Sta in alto poco e in
// basso a lungo: il vento non soffia sempre, arriva a ondate.
float vento_folata(vec2 world_xz, float t) {
	return smoothstep(0.10, 0.95, vento_onda(world_xz, t)) * max(vento_forza, 0.0);
}

// La fase personale di una pianta, dal punto in cui è piantata: due alberi
// vicini non respirano MAI all'unisono (è la prima cosa che tradisce
// un'animazione fatta a macchina).
float vento_fase(vec2 radici) {
	return vento_hash12(floor(radici * 7.31)) * 6.2831853;
}
