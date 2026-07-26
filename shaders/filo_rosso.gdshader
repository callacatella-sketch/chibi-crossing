shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// IL FILO ROSSO DEL DESTINO, reso visibile — il nastro che appare per due
// secondi tra la zampa di Mochi e quella del vicino nei momenti che si
// annodano. La leggenda giapponese: un filo rosso lega chi è destinato a
// incontrarsi; si tende, si aggroviglia, ma non si spezza mai.
//
// Il nastro è una ImmediateMesh ricostruita ogni frame (FiloRosso.gd);
// qui vive la sua luce:
//  · si DISEGNA dalla zampa di Mochi verso l'amico (progresso 0..1);
//  · un BRILLIO corre lungo il filo, come una scintilla sul legame;
//  · i bordi del nastro sfumano (UV.y): un filo, non una striscia;
//  · il desiderio d'ORO del congedo lo tinge di dorato (oro 0..1);
//  · quando il momento è passato, si DISSOLVE piano (dissolvenza 0..1).

uniform float progresso : hint_range(0.0, 1.0) = 1.0;
uniform float dissolvenza : hint_range(0.0, 1.0) = 0.0;
uniform float oro : hint_range(0.0, 1.0) = 0.0;
uniform float intensita : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec3 rosso = vec3(1.0, 0.16, 0.24);
	vec3 dorato = vec3(1.0, 0.78, 0.32);
	vec3 base = mix(rosso, dorato, oro);

	// il filo, non una striscia: i bordi del nastro respirano via
	float attraverso = 1.0 - abs(UV.y * 2.0 - 1.0);
	float alpha = smoothstep(0.0, 0.55, attraverso);

	// il disegno: la testa del filo corre da Mochi (UV.x=0) all'amico,
	// con una piccola punta luminosa che fa da ago
	float testa = smoothstep(progresso, progresso - 0.05, UV.x);
	float ago = smoothstep(0.055, 0.0, abs(UV.x - progresso)) * step(progresso, 0.999);

	// il brillio che corre lungo il filo: la scintilla del legame
	float corsa = 0.5 + 0.5 * sin((UV.x - TIME * 0.65) * 12.6);
	float brillio = pow(corsa, 7.0);

	vec3 col = base * (1.35 + brillio * 1.8) + vec3(1.0, 0.95, 0.9) * ago * 1.8;
	EMISSION = col * intensita;
	ALBEDO = base * 0.35;
	ALPHA = clamp(alpha * testa * (1.0 - dissolvenza) * min(intensita, 1.0)
			+ ago * (1.0 - dissolvenza), 0.0, 1.0);
}
