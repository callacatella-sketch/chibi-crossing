extends RefCounted
## GLI ECHI COME PRESENZE: durante il lutto, dove il momento accadde,
## non un luccichio ma la sagoma traslucida di chi è partito — seduta un
## attimo, rivolta a Mochi, poi sciolta nel luccichio di congedo.
## Guardie:
##  1. il DNA parte col filo (segna_partito lo custodisce, dna_ricordo lo
##     ritrova) e sopravvive al salvataggio;
##  2. il fantasma di ripiego è PURO e deterministico: i salvataggi di
##     prima degli echi-presenza rigenerano SEMPRE lo stesso corpo, tinto
##     coi colori del fiore-ricordo;
##  3. i fili sono attaccati: l'eco del lutto invoca la presenza (non più
##     lo sparkle diretto), il materiale è additivo e senza ombre, la
##     partenza consegna il DNA.

const LEGAMI := preload("res://scenes/world/Legami.gd")
const CONGEDO := preload("res://scenes/world/Congedo.gd")


func run(t) -> void:
	_test_dna_col_filo(t)
	_test_fantasma_puro(t)
	_test_fili_attaccati(t)


func _test_dna_col_filo(t) -> void:
	var lg = LEGAMI.new()
	var fiore := {"x": 1.0, "z": 2.0, "dress": "f2a9bc", "fur": "e8d5b8", "petali": 6}
	var dna := {"name": "Nocciola", "archetype": "coniglio", "dress": "f2a9bc"}
	lg.segna_partito("Nocciola", fiore, dna)
	t.eq(str((lg.dna_ricordo("Nocciola") as Dictionary).get("archetype", "")),
			"coniglio", "il DNA parte col filo")
	t.eq(str((lg.fiore_di("Nocciola") as Dictionary).get("dress", "")),
			"f2a9bc", "e il fiore custodisce i colori")
	# il viaggio nel salvataggio
	var lg2 = LEGAMI.new()
	lg2.load_extra(lg.save_extra())
	t.eq(str((lg2.dna_ricordo("Nocciola") as Dictionary).get("name", "")),
			"Nocciola", "il corpo del ricordo sopravvive a save -> load")
	# la firma vecchia (senza dna) resta valida: nessun fantasma, nessun errore
	lg2.segna_partito("Miele", fiore)
	t.ok((lg2.dna_ricordo("Miele") as Dictionary).is_empty(),
			"un salvataggio senza DNA risponde col vuoto, senza errori")
	lg.free()
	lg2.free()


func _test_fantasma_puro(t) -> void:
	# col DNA salvato: la presenza È quel corpo, non un altro
	var salvato := {"name": "Timo", "archetype": "gatto"}
	t.eq(str((CONGEDO.dna_fantasma("Timo", {}, salvato) as Dictionary).get("archetype", "")),
			"gatto", "il DNA salvato comanda")
	# senza: si rigenera dal nome, tinto coi colori del fiore
	var fiore := {"dress": "aabbcc", "fur": "ddeeff"}
	var a: Dictionary = CONGEDO.dna_fantasma("Nocciola", fiore, {})
	var b: Dictionary = CONGEDO.dna_fantasma("Nocciola", fiore, {})
	t.eq(str(a.get("dress", "")), "aabbcc", "il fantasma veste i colori del fiore")
	t.eq(str(a.get("fur", "")), "ddeeff", "e il suo pelo")
	t.eq(str(a.get("name", "")), "Nocciola", "e porta il suo nome")
	t.eq(a, b, "stessa partenza, SEMPRE la stessa presenza (deterministico)")
	var c: Dictionary = CONGEDO.dna_fantasma("Miele", fiore, {})
	t.ok(str(c.get("seed", "")) != str(a.get("seed", "")) or c != a,
			"nomi diversi, presenze diverse")


func _test_fili_attaccati(t) -> void:
	var tick := _body("res://scenes/world/Congedo.gd", "_tick_lutto")
	t.ok(tick.contains("_eco_presenza"), "l'eco del lutto invoca la PRESENZA")
	t.ok(not tick.contains("_sparkle("),
			"niente più luccichio diretto: il luccichio ora è il congedo")
	var eco := _body("res://scenes/world/Congedo.gd", "_eco_presenza")
	for filo in ["BLEND_MODE_ADD", "find_children", "SHADOW_CASTING_SETTING_OFF",
			"queue_free", "dna_fantasma"]:
		t.ok(eco.contains(filo), "la presenza arriva fino a '%s'" % filo)
	t.ok(_body("res://scenes/world/Congedo.gd", "_partenza")
			.contains("fiore, dna"), "la partenza consegna il DNA al filo")


func _body(path: String, fn: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
