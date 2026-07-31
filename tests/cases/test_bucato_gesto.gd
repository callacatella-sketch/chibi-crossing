extends RefCounted
## IL GESTO DEL BUCATO: niente più teli per magia. Mochi si volta verso
## la corda, si china sul cestello e si ALLUNGA (hold_reach: pour 0 giù,
## pour 1 su) — un telo per allungata, che si spiega con le sue due
## mollette (tic, tic). Il ritiro è una tirata per telo. Il cablaggio:
## il giocatore resta fermo per il gesto e viene SEMPRE liberato, la E
## non si accavalla, e anche i panni dei residenti si spiegano uno alla
## volta invece di comparire in blocco.

func run(t) -> void:
	var vita := _sorgente("res://scenes/world/VitaSecondaria.gd")

	# lo stendere è un gesto, non un interruttore
	t.ok(vita.contains("_stendi_con_gesto") and vita.contains("_ritira_con_gesto"),
			"la E passa dai gesti, non dall'istante")
	t.ok(vita.contains("hold_reach"),
			"il gesto usa hold_reach (giù al cestello, su alla corda)")
	t.ok(vita.contains("tween_property(mochi, \"pour\""),
			"l'allungata e' il tween di pour, come la raccolta")
	t.ok(vita.contains("tween_property(mochi, \"crouch\""),
			"la chinata sul cestello c'e' (crouch animato)")
	t.ok(vita.contains("_appendi_telo"),
			"un telo per allungata, non tre in blocco")
	t.ok(vita.contains("telo.scale = Vector3(1, 0.06, 1)"),
			"il telo nasce piegato e si SPIEGA sulla corda")

	# le mollette si sentono: tic, tic
	var appendi := _corpo(vita, "_appendi_telo")
	t.ok(appendi.count("\"tick\"") >= 2,
			"le due mollette fanno tic, tic (due suoni)")

	# il giocatore: fermo durante il gesto, SEMPRE liberato dopo
	t.ok(vita.contains("set_physics_process(false)"),
			"durante il gesto il giocatore resta fermo")
	var congeda := _corpo(vita, "_congeda_gesto")
	t.ok(congeda.contains("set_physics_process(true)")
			and congeda.contains("_gesto_in_corso = false"),
			"_congeda_gesto libera sempre giocatore e flag")
	t.ok(vita.contains("or _gesto_in_corso"),
			"la E non si accavalla a un gesto in corso")

	# IL RIPIEGO SENZA CORPO IN SCENA (harness/headless). La prova cercava
	# «il vecchio istante, senza gesto», che in VitaSecondaria vive SOLO
	# dentro un commento: restava verde cancellando il codice e diventava
	# rossa riformulando una frase. Si guarda il CODICE: il ramo «niente
	# Mochi» dentro `_stendi_con_gesto`, e la funzione di ritiro — che era
	# del tutto scoperta.
	var con_gesto := _corpo(vita, "_stendi_con_gesto")
	t.ok(con_gesto.contains("mochi == null"),
			"senza Mochi in scena il bucato ha il suo ramo di ripiego")
	t.ok(con_gesto.contains("_stendi(nodo"),
			"…e quel ramo stende i panni lo stesso, senza il gesto")
	t.ok(vita.contains("func _stendini_fallback_ritira"),
			"e il ritiro ha il suo ripiego, che nessuno provava")
	t.ok(_corpo(vita, "_ritira_con_gesto").contains("_stendini_fallback_ritira("),
			"…ed è davvero chiamato dal ritiro col gesto")

	# anche i panni dei residenti si spiegano uno alla volta
	var stendi := _corpo(vita, "_stendi")
	t.ok(stendi.contains("tween_interval(0.16 * float(i))"),
			"i panni dei residenti si spiegano in cascata, mai in blocco")


# il corpo di una funzione: dal suo 'func nome' al 'func' successivo
func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
