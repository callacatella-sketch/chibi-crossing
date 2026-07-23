shader_type sky;

// Il cielo di Chibi Crossing: gradiente pilotato dal DayNight, sole e
// luna disegnati qui, e NUVOLE procedurali — cumuli soffici a due
// ottave che derivano piano, con la pancia in ombra e il bordo
// argenteo verso il sole. I colori arrivano ogni frame dal DayNight:
// candide di giorno, rosa alla golden hour, ardesia la notte, gonfie
// e grigie quando piove.

uniform vec4 top_color : source_color = vec4(0.4, 0.62, 0.87, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.9, 0.84, 0.72, 1.0);
uniform vec4 ground_color : source_color = vec4(0.5, 0.58, 0.48, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.76, 0.80, 0.90, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;

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
	return vnoise(p) * 0.52 + vnoise(p * 2.13 + 11.0) * 0.30
			+ vnoise(p * 4.7 + 47.0) * 0.18;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	// il gradiente: orizzonte caldo che sale verso lo zenit
	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(h, 0.55));
	// sotto l'orizzonte: il colore-terra sfumato
	if (dir.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb,
				smoothstep(0.0, 0.12, -dir.y));
	}

	// --- il sole: disco morbido + alone che si gonfia all'orizzonte ---
	if (LIGHT0_ENABLED) {
		float sd = dot(dir, LIGHT0_DIRECTION);
		float disc = smoothstep(0.99930, 0.99965, sd);
		float halo = pow(clamp(sd, 0.0, 1.0), 30.0) * 0.20
				+ pow(clamp(sd, 0.0, 1.0), 6.0) * 0.05;
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (disc * 1.15 + halo);
	}

	// --- la luna: piccolo disco freddo con un velo di alone ---
	if (LIGHT1_ENABLED) {
		float md = dot(dir, LIGHT1_DIRECTION);
		float mdisc = smoothstep(0.99950, 0.99977, md);
		col += vec3(0.86, 0.92, 1.0) * LIGHT1_ENERGY
				* (mdisc * 2.6 + pow(clamp(md, 0.0, 1.0), 60.0) * 0.35);
	}

	// --- le nuvole: proiezione sul soffitto del mondo, due strati in
	// deriva a velocità diverse (la profondità del cielo vero) ---
	if (dir.y > 0.005) {
		vec2 cuv = dir.xz / (dir.y + 0.18) * 0.85;
		float n = fbm(cuv * 1.5 + vec2(TIME * 0.0060, TIME * 0.0024)) * 0.70
				+ fbm(cuv * 3.9 + 31.0 + vec2(TIME * 0.0104, -TIME * 0.0036)) * 0.30;
		float horizon_fade = smoothstep(0.015, 0.16, dir.y);
		float thr = 1.0 - cloud_cover;
		float cl = smoothstep(thr, thr + 0.22, n) * horizon_fade;
		float thick = smoothstep(thr, thr + 0.55, n);

		// pancia in ombra, e il bordo che si accende verso il sole
		float sun_side = 0.5;
		if (LIGHT0_ENABLED) {
			sun_side = clamp(dot(dir, LIGHT0_DIRECTION) * 0.5 + 0.5, 0.0, 1.0);
		}
		vec3 ccol = mix(cloud_shade.rgb, cloud_color.rgb,
				0.30 + 0.70 * pow(sun_side, 1.6));
		ccol *= mix(1.04, 0.84, thick); // il cuore del cumulo è più cupo
		col = mix(col, ccol, cl * 0.92);
	}

	COLOR = col;
}
