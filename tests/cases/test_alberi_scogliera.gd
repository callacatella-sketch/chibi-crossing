extends RefCounted
## ⚠️ GLI ALBERI DEL BOSCO RESTAVANO SOSPESI SOPRA LA PARETE.
##
## `_build_forest` solleva a `CLIFF_H` gli alberi che stanno «oltre la
## parete», perché lassù c'è il ripiano d'erba. Ma la soglia era
## `cliff_x(z) − 2.5`, cioè **due metri e mezzo PRIMA** della parete — e quel
## `2.5` era `CLIFF_H`, un'**altezza** usata come ascissa.
##
## Il ripiano invece comincia a `cliff_x(z) + 0.05` (il primo scalino di
## `xoff` in `_build_cliff`, l'unico suolo che stia a `CLIFF_H`). Gli alberi
## nella fascia in mezzo venivano alzati a 2,5 m **con niente sotto**.
##
## MISURATO rifacendo la semina vera (stessa griglia, stesso dado): **7
## alberi su 55 sollevati — il 12,7% — erano sospesi**, il peggiore a
## **2,47 m** dal ripiano. È il pezzo di mondo che si guarda dalla cascata.
##
## La cura è una FONTE UNICA: `CLIFF_CAP_X0`, letta dal ripiano e dalla
## soglia. Due numeri che si inseguono a mano divergono al primo che ritocca
## la scogliera.

const MATH := preload("res://scenes/world/WorldMath.gd")
const CW := preload("res://scenes/world/CozyWorld.gd")


func run(t) -> void:
	_nessun_albero_sospeso(t)
	_la_costante_ha_DUE_lettori(t)


## L'INVARIANTE, sulla semina VERA e con la LEGGE VERA: chi viene sollevato
## deve avere il ripiano sotto. La legge sta in `CozyWorld.sopra_il_ripiano`
## — estratta apposta per poterla INTERROGARE: finché viveva dentro il ciclo
## di `_build_forest` nessun test poteva chiederle niente, ed è rimasta
## sbagliata di due metri e mezzo.
##
## L'oracolo NON è la legge: è il ripiano, cioè il primo scalino del cap.
func _nessun_albero_sospeso(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var sollevati := 0
	var sospesi := 0
	var ieri := 0
	var peggio := 0.0
	for gx in range(-50, 51, 4):
		for gz in range(-50, -13, 4):
			var pos := Vector3(gx + rng.randf_range(-1.8, 1.8), 0.0,
					gz + rng.randf_range(-1.8, 1.8))
			if pos.z > -15.0:
				continue
			var rx: float = MATH.river_x(pos.z)
			if absf(pos.x - rx) < 5.2:
				continue
			var cx: float = MATH.cliff_x(pos.z)
			# IL RIPIANO, cioè il suolo vero a CLIFF_H: l'oracolo
			var ha_suolo: bool = pos.x >= cx + CW.CLIFF_CAP_X0
			# LA LEGGE VERA del gioco
			if CW.sopra_il_ripiano(pos.x, pos.z):
				sollevati += 1
				if not ha_suolo:
					sospesi += 1
			# …e la legge di IERI, per dire quanti ne prendeva
			if pos.x > cx - CW.CLIFF_H and not ha_suolo:
				ieri += 1
				peggio = maxf(peggio, cx + CW.CLIFF_CAP_X0 - pos.x)

	t.ok(sollevati > 20,
			"la scena esiste: qualcuno viene sollevato davvero (%d)" % sollevati)
	t.eq(sospesi, 0, "nessun albero sollevato senza il ripiano sotto")
	# ⚠️ LA CONTROPROVA CHE LA SCENA È VERA: la legge di ieri ne prendeva
	# sette. Senza, «zero sospesi» sarebbe vero anche se la fascia fosse
	# vuota, e il caso non direbbe niente.
	t.eq(ieri, 7,
			"e la legge di ieri ne sollevava 7 nel vuoto, fino a %.2f m dal ripiano"
					% peggio)


## ⚠️ IL CABLAGGIO: le due metà devono leggere la STESSA costante, o
## tornano a divergere. Sorgente spogliato dei commenti — la cura nomina
## apposta il numero che ha tolto.
func _la_costante_ha_DUE_lettori(t) -> void:
	var util := load("res://tests/test_util.gd")
	var src: String = util.codice("res://scenes/world/CozyWorld.gd")
	t.ok(src.length() > 10000, "CozyWorld.gd si legge (%d byte)" % src.length())
	t.ok(src.contains("if sopra_il_ripiano(pos.x, pos.z):"),
			"la semina del bosco chiede alla LEGGE, non a una soglia sua")
	t.ok(src.contains("x > MATH.cliff_x(z) + CLIFF_CAP_X0"),
			"e la legge parte da dove comincia il ripiano")
	t.ok(src.contains("[CLIFF_CAP_X0, 6.0"),
			"…e il ripiano comincia esattamente lì: una fonte, due lettori")
