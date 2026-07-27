shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// LA POZZA DI LUCE DALLA FINESTRA — il rettangolo caldo che una finestra
// accesa versa sull'erba, la sera. Un quad appoggiato al prato (additivo:
// LUCE vera, non vernice) con la fisica giusta della luce vera:
//   • trapezio: il fascio si ALLARGA allontanandosi dalla parete;
//   • la croce del telaio in ombra dentro la pozza — nitida vicino al
//     muro, sempre più sfocata in fondo (la penombra cresce con la
//     distanza, come al vero);
//   • il manto la "afferra" in modo irregolare (i fili d'erba pescano la
//     luce a ciuffi, mai una piastra uniforme);
//   • lo sfarfallio del focolare: un tremito minimo, mai a tempo con le
//     altre finestre (uniform fase per istanza);
//   • modalità LUTTO: la candela di chi non c'è più — più ambrata, più
//     fioca, e respira lenta invece di sfarfallare.
// UV: y=0 alla parete, y=1 in fondo alla pozza. Pilotato da PozzeDiLuce.gd.

uniform float intensita : hint_range(0.0, 1.0) = 0.0;   // 0 giorno → 1 notte
uniform float lutto : hint_range(0.0, 1.0) = 0.0;
uniform float fase = 0.0;
uniform vec4 calore : source_color = vec4(1.0, 0.80, 0.45, 1.0);
uniform vec4 calore_lutto : source_color = vec4(1.0, 0.66, 0.34, 1.0);
uniform float energia : hint_range(0.0, 2.0) = 0.55;

varying vec3 wpos;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	float lungo = uv.y;                    // 0 = parete, 1 = fondo pozza
	float dx = abs(uv.x - 0.5);

	// il trapezio: mezzo-vano alla parete, si allarga in fondo; il bordo
	// laterale è netto vicino e penombra morbida lontano
	float mezza = mix(0.20, 0.44, lungo);
	float orlo = 0.035 + 0.16 * lungo;
	float fascio = 1.0 - smoothstep(mezza - orlo, mezza + orlo, dx);

	// la corsa della luce: piena sotto il davanzale, svanisce in fondo
	float corsa = pow(clamp(1.0 - lungo, 0.0, 1.0), 1.35);
	corsa *= 0.75 + 0.25 * smoothstep(0.22, 0.0, lungo);   // il cuore al muro
	// e l'attacco alla parete non parte mai a filo zero
	corsa *= smoothstep(0.0, 0.03, lungo) * 0.2 + 0.8;

	// la croce del telaio: il montante e la traversa in ombra, con la
	// penombra che CRESCE con la distanza dalla finestra
	float pen_v = 0.018 + 0.10 * lungo;
	float sbarra_v = smoothstep(0.030 + 0.02 * lungo, 0.030 + 0.02 * lungo + pen_v,
			abs(uv.x - 0.5));
	float pen_h = 0.030 + 0.14 * lungo;
	float sbarra_h = smoothstep(0.026 + 0.02 * lungo, 0.026 + 0.02 * lungo + pen_h,
			abs(uv.y - 0.42));
	float telaio = (0.40 + 0.60 * sbarra_v) * (0.50 + 0.50 * sbarra_h);

	// l'erba afferra la luce a ciuffi: rottura organica, mai una piastra
	float ciuffi = 0.80 + 0.30 * vnoise(wpos.xz * 3.1 + 17.0);

	// il tremito: focolare vivo per le case, respiro lento per il lutto
	float focolare = 1.0 + 0.05 * (vnoise(vec2(TIME * 1.7 + fase, fase * 3.1)) - 0.5) * 2.0;
	float respiro = 0.86 + 0.14 * sin(TIME * 0.75 + fase)
			+ 0.03 * (vnoise(vec2(TIME * 2.3 + fase, 7.0)) - 0.5);
	float vita = mix(focolare, respiro, lutto);

	float luce = fascio * corsa * telaio * ciuffi * vita * intensita;
	vec3 tinta = mix(calore.rgb, calore_lutto.rgb, lutto);
	// il lutto è una candela, non un focolare: più fioca
	float forza = energia * mix(1.0, 0.72, lutto);

	ALBEDO = vec3(0.0);
	EMISSION = tinta * luce * forza;
	ALPHA = clamp(luce, 0.0, 1.0);
}
