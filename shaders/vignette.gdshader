shader_type canvas_item;

// LA CARTA DELL'INQUADRATURA — il post-process che unifica ogni fotogramma
// col linguaggio della UI: una vignetta calda chiude l'angolo come in
// un'illustrazione, e una grana pittorica sottilissima (la STESSA fbm del
// handpaint, estesa allo schermo) fa sembrare tutto dipinto sulla carta
// crema delle lettere e della lavagna.
//
// Scelte da rispettare, se un giorno si ritocca:
//  · la vignetta MOLTIPLICA verso un bruno caldo — mai il nero morto di
//    una vignetta fotografica: la carta ai bordi ingiallisce, non brucia;
//  · la forma è una SUPERELLISSE (segue la cornice, non un ovale da
//    binocolo): gli angoli chiudono, i lati respirano;
//  · la grana è FERMA in spazio-schermo: la carta non striscia sotto il
//    dipinto (una grana animata è pellicola, non carta);
//  · la grana lavora in soft-light: neri e luci restano loro, e affiora
//    appena di più verso i bordi, dove la "pittura" si assottiglia;
//  · chiude un dither da 1/255 contro il banding dei cieli e della nebbia.

uniform sampler2D schermo : hint_screen_texture, filter_linear;

// la vignetta: quanto chiude e di che bruno
uniform float strength : hint_range(0.0, 1.0) = 0.24;
uniform vec4 tint : source_color = vec4(0.6, 0.46, 0.36, 1.0);
// la grana di carta: quanta e quanto fitta (in pixel per fibra)
uniform float grana : hint_range(0.0, 0.2) = 0.045;
uniform float grana_scala : hint_range(1.0, 12.0) = 3.4;
// il soffio caldo che lega il fotogramma al crema della UI
uniform float calore : hint_range(0.0, 1.0) = 0.5;

// --- lo stesso lavaggio del handpaint, portato in spazio-schermo ---

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

void fragment() {
	vec3 scena = texture(schermo, SCREEN_UV).rgb;

	// la vignetta a superellisse: 0 al centro, piena solo negli angoli
	vec2 c = abs(UV - 0.5) * 2.0;
	float d = pow(pow(c.x, 2.5) + pow(c.y, 2.5), 0.4);
	float vig = smoothstep(0.62, 1.25, d);
	scena *= mix(vec3(1.0), tint.rgb, vig * strength);
	// il contro-respiro: al centro un soffio di luce in più, mai piatto
	scena *= 1.0 + (1.0 - vig) * 0.015;

	// la grana: fibra di carta ferma in spazio-schermo. Un lavaggio fbm
	// più le fibre lunghe (lo stesso rumore, stirato in orizzontale)
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 guv = px / grana_scala;
	float carta = fbm(guv) - 0.5;
	carta += (vnoise(guv * vec2(0.22, 1.9) + 7.3) - 0.5) * 0.6;
	float forza = grana * (0.75 + 0.6 * vig);
	scena += carta * forza * (1.0 - abs(2.0 * scena - 1.0));

	// il soffio caldo: lega i bianchi del mondo al crema delle lettere
	scena *= mix(vec3(1.0), vec3(1.028, 1.0, 0.952), calore * 0.5);

	// il dither che salva i tramonti dal banding
	scena += (hash12(px) - 0.5) / 255.0;

	COLOR = vec4(scena, 1.0);
}
