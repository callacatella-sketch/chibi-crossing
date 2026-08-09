shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, depth_draw_never, cull_disabled;

// Lucciole dell'ecosistema: billboard additivi che respirano luce,
// ognuna col suo SFASAMENTO di lampeggio (INSTANCE_CUSTOM.x). Il colore del
// bagliore lo sceglie la stagione: verde-lime d'estate, ambra d'autunno.
//
// ATTENZIONE: INSTANCE_CUSTOM.x dev'essere una COSTANTE 0..1, non un
// orologio. Qui viene moltiplicato per 6.283 solo per sparpagliare le
// lucciole; se il C++ ci mandasse un valore che cresce nel tempo, la sua
// derivata si sommerebbe a 2.4 e il respiro diventerebbe un tremolio.
uniform vec3 glow_color : source_color = vec3(0.80, 1.0, 0.52);

varying float blink;

void vertex() {
	float sfasamento = INSTANCE_CUSTOM.x;
	blink = 0.2 + 0.8 * pow(0.5 + 0.5 * sin(TIME * 2.4 + sfasamento * 6.283), 2.4);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float glow = smoothstep(1.0, 0.0, d);
	glow *= glow;
	ALBEDO = glow_color * glow * blink;
	ALPHA = glow * blink;
}
