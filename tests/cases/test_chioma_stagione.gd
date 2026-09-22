extends RefCounted
## ⚠️ UN ALBERO RICRESCIUTO IN AUTUNNO RESTAVA VERDE.
##
## `CozyWorld._apply_season` è l'**unico** scrittore di `color_a`/`color_b`
## sulle chiome, e gira soltanto quando la stagione CAMBIA. `_register_leaf`
## invece mette il materiale in `_leaf_mats` coi colori di NASCITA e non
## guarda `_season`: una chioma registrata dopo l'ultimo cambio restava coi
## suoi verdi fino al successivo.
##
## Alla generazione non si vede — quei materiali nascono prima di
## `_init_season`, che li ridipinge tutti. Ma un albero **ricresciuto**
## (`Woodcutting._sprout_tree` → `CozyWorld` fa il tronco) nasce a mondo già
## fatto: in autunno restava verde per una stagione intera, e in inverno per
## tre settimane di gioco.
##
## ⚠️ **E IL CANCELLO SU `_season >= 0` NON È PRUDENZA.** `_season` parte da
## **−1**, e il ramo di serie di `GEO.leaf_target` è l'**INVERNO**: senza il
## cancello, tutte le chiome del mondo nascerebbero imbiancate e si
## vedrebbero brinate finché `_init_season` non gira. Alla generazione,
## quindi, questa cura non cambia **un bit**.
##
## La tinta la decide `GEO.leaf_target`, la stessa che usa `_apply_season`:
## una seconda formula sarebbe la tabella gemella.

const CW := preload("res://scenes/world/CozyWorld.gd")
const GEO := preload("res://scenes/world/WorldGeo.gd")

const NATO := Color("6fbf5a")


func run(t) -> void:
	_alla_generazione_non_cambia_niente(t)
	_a_mondo_fatto_la_chioma_nasce_della_stagione(t)


func _tinta(stagione: int, klass := "green") -> Variant:
	var w = CW.new()
	w.set("_season", stagione)
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.set_shader_parameter("color_a", Color.MAGENTA)
	w.call("_register_leaf", m, NATO, NATO, klass)
	var out = m.get_shader_parameter("color_a")
	w.free()
	return out


## `_season == -1` è lo stato in cui gira TUTTA la generazione del mondo:
## lì non si tocca niente, o le chiome nascerebbero invernali.
func _alla_generazione_non_cambia_niente(t) -> void:
	var got = _tinta(-1)
	t.ok(got is Color and (got as Color).is_equal_approx(Color.MAGENTA),
			"con la stagione ancora ignota la chioma non si tocca (%s)" % str(got))


## A mondo fatto, invece, la chioma nasce già della stagione in corso — e
## l'oracolo è `GEO.leaf_target`, cioè quello che `_apply_season` scriverebbe
## al prossimo cambio.
func _a_mondo_fatto_la_chioma_nasce_della_stagione(t) -> void:
	for stagione in [0, 1, 2, 3]:
		var got = _tinta(stagione)
		var atteso: Color = GEO.leaf_target(NATO, "green", stagione)
		t.ok(got is Color and (got as Color).is_equal_approx(atteso),
				"stagione %d: la chioma nasce della tinta giusta (%s contro %s)"
						% [stagione, str(got), str(atteso)])
	# ⚠️ E LA CONTROPROVA CHE NON È UNA COSTANTE: l'autunno dev'essere
	# DIVERSO dalla primavera, o una cura che scrive sempre lo stesso
	# colore passerebbe tutto quanto sopra.
	var primavera: Color = _tinta(0)
	var autunno: Color = _tinta(2)
	t.ok(not primavera.is_equal_approx(autunno),
			"…e l'autunno non è la primavera (%s contro %s)"
					% [str(primavera), str(autunno)])
	# le conifere restano verdi: la classe conta, e passa fino in fondo
	var ago: Color = _tinta(2, "needle")
	t.ok(not ago.is_equal_approx(autunno),
			"la CLASSE arriva a leaf_target: una conifera d'autunno non è una latifoglia")
