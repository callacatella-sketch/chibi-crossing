extends RefCounted
## LA BANCARELLA DI MOCHI — l'economia al contrario: esponi tre tesori
## col tuo cartellino, e i vicini comprano ciò che il DNA adora.
## Guardie:
##  1. il cuore è PURO: merce fresca/calda per OGNI specie del bestiario,
##     gradimento a soglie sui pesi veri, cartellino massimo per gusto,
##     prezzo mai sotto la nocciolina;
##  2. cartellini e prezzi camminano insieme (stessa lunghezza, crescenti);
##  3. il banco si costruisce (builder non vuoto) ed è merce del mercante;
##  4. lo stato va e torna dal salvataggio anche PRIMA che i banchi
##     esistano (pending);
##  5. i fili: la vendita arriva a bisaccia, dispensa e borsellino, e la
##     merce esposta resta nella bisaccia finché non è comprata.

const BAN := preload("res://scenes/world/Bancarella.gd")
const CAT := preload("res://scenes/build/BuildCatalog.gd")
const ECO := preload("res://scenes/ui/Economy.gd")
const CRIT := preload("res://scenes/world/Critters.gd")


func run(t) -> void:
	_test_cuore_puro(t)
	_test_cartellini(t)
	_test_asset(t)
	_test_salvataggio(t)
	_test_fili_attaccati(t)


func _test_cuore_puro(t) -> void:
	# ogni specie del bestiario ha una famiglia di merce (nessuna orfana)
	for id in CRIT.SPECIE:
		var classe := str((CRIT.SPECIE[id] as Dictionary).get("classe", ""))
		var fresca: bool = BAN.merce_fresca(classe)
		t.ok(fresca or classe == "raccolto",
				"'%s' (%s) è merce fresca o calda, mai orfana" % [id, classe])
	# il gradimento legge i pesi giusti del carattere
	t.eq(BAN.gradimento(true, {"garden": 0.8}), 2, "il pollice verde ADORA il fresco")
	t.eq(BAN.gradimento(true, {"garden": 0.4}), 1, "e chi lo apprezza, lo gradisce")
	t.eq(BAN.gradimento(true, {"garden": 0.1, "warmth": 0.9}), 0,
			"chi ama il focolare resta freddo davanti alle farfalle")
	t.eq(BAN.gradimento(false, {"warmth": 0.7}), 2, "e ADORA i raccolti da pentola")
	t.eq(BAN.gradimento(false, {}), 0, "senza pesi, nessun desiderio")
	# il gusto decide il portafoglio
	t.eq(BAN.cartellino_massimo(2), 3, "ciò che si adora si paga carissimo")
	t.eq(BAN.cartellino_massimo(1), 2, "il gradito fino a caro")
	t.eq(BAN.cartellino_massimo(0), 1, "l'indifferente solo a prezzo onesto")
	# il prezzo non scende mai sotto la nocciolina
	t.eq(BAN.prezzo_in_noccioline(1, 0), 1, "mai meno di una nocciolina")
	t.eq(BAN.prezzo_in_noccioline(10, 3), 20, "il carissimo raddoppia il valore")
	t.eq(BAN.prezzo_in_noccioline(10, 1), 10, "il giusto è il valore del bestiario")


func _test_cartellini(t) -> void:
	t.eq((BAN.PREZZI as Array).size(), (BAN.CARTELLINI as Array).size(),
			"ogni cartellino ha il suo prezzo")
	t.eq((BAN.TAG_COLORI as Array).size(), (BAN.CARTELLINI as Array).size(),
			"e il suo colore in vetrina")
	var prima := 0.0
	for p in BAN.PREZZI:
		t.ok(float(p) > prima, "i cartellini salgono (%s)" % str(p))
		prima = float(p)
	t.eq((BAN.POSTI as Array).size(), 3, "tre piedistalli, come promesso")


func _test_asset(t) -> void:
	var banco: Node3D = CAT._player_stall()
	t.ok(banco.get_child_count() >= 12,
			"la bancarella si costruisce con tutti i suoi pezzi (%d)"
			% banco.get_child_count())
	banco.free()
	var trovata := false
	for p in ECO.SHOP_PIECES:
		if str(p["name"]) == "Bancarella":
			trovata = true
	t.ok(trovata, "la Bancarella è sul carretto del mercante (ironia compresa)")


func _test_salvataggio(t) -> void:
	var ban = BAN.new()
	# lo stato arriva dal salvataggio PRIMA che i banchi esistano: resta
	# in attesa e si risalva intatto (nessuna perdita al riavvio veloce)
	ban.load_extra({"bancarelle": {"3|-2": [["gialla", "critter", 3], null, null]}})
	var fuori: Dictionary = ban.save_extra()["bancarelle"]
	t.ok(fuori.has("3|-2"), "il banco in attesa non si perde al risalvataggio")
	t.eq(str(((fuori["3|-2"] as Array)[0] as Array)[0]), "gialla",
			"e la merce esposta è ancora la sua")
	t.eq(int(((fuori["3|-2"] as Array)[0] as Array)[2]), 3,
			"col suo cartellino carissimo")
	ban.free()


func _test_fili_attaccati(t) -> void:
	var vendita := _body("res://scenes/world/Bancarella.gd", "_finalizza_vendita")
	for filo in ["remove_catch", "add_ingredient", "add_nuts", "_in_bisaccia",
			"request_save"]:
		t.ok(vendita.contains(filo), "la vendita arriva fino a '%s'" % filo)
	t.ok(_body("res://scenes/world/Bancarella.gd", "_prova_una_vendita")
			.contains("cartellino_massimo"),
			"il cliente compra solo se il cartellino non supera il desiderio")
	t.ok(_body("res://scenes/world/Bancarella.gd", "_refresh_vetrina")
			.contains("colore"),
			"la merce esposta ha il colore vero del bestiario")
	t.ok(_sorgente("res://scenes/levels/MainLevel.tscn").contains("Bancarella"),
			"la bancarella è un nodo della scena principale")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
