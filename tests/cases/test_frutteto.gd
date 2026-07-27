extends RefCounted
## Il frutteto (scenes/interact/Frutteto.gd): il ciclo di crescita PURO
## (stadio/pronto), i frutti nel bestiario (fonte unica: vendita, colore,
## etichette derivate), le ricette nuove del camino e i fili del cablaggio
## (il semino del passerotto, il consumo dalle Tasche, la persistenza).

const FRUTTETO := preload("res://scenes/interact/Frutteto.gd")
const CRIT := preload("res://scenes/world/Critters.gd")
const COOKING := preload("res://scenes/interact/Cooking.gd")
const INVENTORY := preload("res://scenes/ui/Inventory.gd")
const DN := preload("res://scenes/world/DayNight.gd")


func run(t) -> void:
	_test_ciclo_di_crescita(t)
	_test_frutti_nel_bestiario(t)
	_test_ricette(t)
	_test_fili_del_frutteto(t)


## Una stagione per crescere, frutti ogni due giorni: il calendario puro.
func _test_ciclo_di_crescita(t) -> void:
	# "in una stagione diventa melo/pero": la crescita dura ESATTAMENTE
	# una stagione del calendario — le due costanti non devono divergere
	t.eq(FRUTTETO.GIORNI_CRESCITA, DN.SEASON_DAYS,
			"la crescita dura una stagione intera (%d giorni)" % DN.SEASON_DAYS)
	t.eq(FRUTTETO.stadio(0), "germoglio", "giorno 0: germoglio")
	t.eq(FRUTTETO.stadio(1), "germoglio", "giorno 1: ancora germoglio")
	t.eq(FRUTTETO.stadio(2), "alberello", "giorno 2: alberello")
	t.eq(FRUTTETO.stadio(4), "giovane", "giorno 4: albero giovane")
	t.eq(FRUTTETO.stadio(6), "fioritura",
			"giorno 6: la FIORITURA, la vigilia della maturita'")
	t.eq(FRUTTETO.stadio(7), "maturo", "giorno 7: maturo, una stagione dopo")
	t.eq(FRUTTETO.stadio(40), "maturo", "e maturo resta, per sempre")
	# il raccolto ogni due giorni
	t.ok(not FRUTTETO.pronto(6, 6), "in fioritura niente frutti")
	t.ok(FRUTTETO.pronto(7, 7), "alla maturita' il primo raccolto e' pronto")
	t.ok(not FRUTTETO.pronto(8, 1), "il giorno dopo il raccolto: niente")
	t.ok(FRUTTETO.pronto(9, 2), "due giorni dopo: rifruttato")
	t.ok(FRUTTETO.pronto(20, 13), "trascurato a lungo: i frutti aspettano")


## Mela e pera vivono nel bestiario come ogni altro raccolto: il mercante
## le paga, i nomi si derivano, il colore e' UNO.
func _test_frutti_nel_bestiario(t) -> void:
	for id in ["mela", "pera"]:
		t.ok(CRIT.SPECIE.has(id), "il bestiario conosce la %s" % id)
		t.eq(CRIT.classe(id), "raccolto", "la %s e' un raccolto" % id)
		t.ok(CRIT.vendita(id) > 0, "il mercante paga la %s" % id)
	t.eq(CRIT.etichetta("mela"), "Mela", "etichetta derivata dal nome")
	t.eq(CRIT.con_articolo("pera"), "una pera", "articolo giusto")
	t.ok(CRIT.vendita("pera") > CRIT.vendita("bacca"),
			"un frutto d'albero vale piu' di una bacca raccattata")


## Le ricette nuove esistono, e OGNI ingrediente di OGNI ricetta e' un
## raccolto vero del bestiario: niente ingredienti fantasma.
func _test_ricette(t) -> void:
	var nomi := []
	for r in COOKING.RECIPES:
		nomi.append(str(r["name"]))
		for ing in (r.get("need", {}) as Dictionary):
			t.ok(CRIT.SPECIE.has(str(ing)) and CRIT.classe(str(ing)) == "raccolto",
					"«%s»: l'ingrediente '%s' e' un raccolto del bestiario"
					% [r["name"], ing])
	t.ok("Torta di mele" in nomi, "la torta di mele e' nel ricettario")
	t.ok("Pere al miele" in nomi, "le pere al miele pure")
	t.ok(COOKING.RECIPES.size() <= 9,
			"il ricettario sta nei tasti 1-9 (%d ricette)" % COOKING.RECIPES.size())


## I fili: il semino arriva dal passerotto (Tasche), il frutteto lo
## consuma da li', vive nella scena e la CLI non tocca il salvataggio.
func _test_fili_del_frutteto(t) -> void:
	t.ok("semino" in INVENTORY.PASSEROTTO_GIFTS,
			"il passerotto puo' regalare il semino raro")
	t.ok(INVENTORY.TREASURES.has("semino"), "il semino e' un Tesoro vero")
	t.ok(str((INVENTORY.TREASURES["semino"] as Dictionary)["desc"]).contains("ianta"),
			"e la sua scheda dice che si pianta")
	var fonte := _sorgente("res://scenes/interact/Frutteto.gd")
	t.ok(fonte.contains("take_treasure"),
			"piantare CONSUMA il semino dalle Tasche (fonte unica)")
	t.ok(fonte.contains("add_ingredient"),
			"il raccolto finisce nella dispensa del camino")
	t.ok(fonte.contains("save_extra") and fonte.contains("\"frutteto\""),
			"gli alberi si salvano col villaggio")
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("Frutteto.gd"),
			"il frutteto vive nella scena principale")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
