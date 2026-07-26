extends RefCounted
## L'ECONOMIA VIVA: il mercante a rotazione e i lavori che producono.
##
## Due difetti si risolvevano a vicenda (2026-07-26): il negozio si esauriva
## (comprato tutto, le noccioline non servivano più) e i lavori erano solo un
## rubinetto di rancore senza guadagno. Questi test tengono chiuso il cerchio:
##  1. il banco del mercante ruota: 3-4 pezzi a visita, un raro del giorno,
##     stessa pesca nello stesso giorno (ricaricare non rimescola);
##  2. i sogni da 500+ noccioline esistono e i loro builder costruiscono;
##  3. la resa dei lavori segue la scala della ribellione per NOME, copre
##     TUTTI i gradini e cala senza mai risalire;
##  4. i temi del carillon sono dati sani e il ciclo è coperto;
##  5. i fili restano attaccati nei sorgenti (spawn -> rotazione,
##     mattino -> produzione, carillon -> musica, serra -> inverno).

const ECO := preload("res://scenes/ui/Economy.gd")
const LAV := preload("res://scenes/npc/Lavori.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const SFX := preload("res://audio/Sfx.gd")
const INTER := preload("res://scenes/interact/Interactions.gd")
const CAT := preload("res://scenes/build/BuildCatalog.gd")


func run(t) -> void:
	_test_pesca_stock_pura(t)
	_test_rotazione_su_istanza(t)
	_test_sogni_costosi(t)
	_test_builder_dei_sogni(t)
	_test_resa_su_tutta_la_scala(t)
	_test_temi_del_carillon(t)
	_test_render_dei_temi_nuovi(t)
	_test_fili_attaccati(t)


# ------------------------------------------------------------ il banco

func _test_pesca_stock_pura(t) -> void:
	var stock: Array = ECO.pesca_stock(ECO.SHOP_PIECES, 42)
	t.ok(stock.size() >= 3 and stock.size() <= 4,
			"a listino pieno il banco porta 3-4 pezzi (%d)" % stock.size())
	# il primo è il raro del giorno: costoso o in stelline
	var raro: Dictionary = {}
	for p in ECO.SHOP_PIECES:
		if str(p["name"]) == str(stock[0]):
			raro = p
	t.ok(not raro.is_empty(), "il raro del giorno esiste a listino")
	t.ok(str(raro.get("cur", "nut")) == "star"
			or int(raro.get("cost", 0)) >= ECO.RARO_SOGLIA,
			"il raro del giorno è davvero un pezzo raro (%s)" % str(stock[0]))
	# nomi unici, tutti presi dal listino
	var visti := {}
	for n in stock:
		t.ok(not visti.has(n), "nessun doppione sul banco (%s)" % n)
		visti[n] = true
	# deterministica dato il seme; semi diversi possono pescare diversamente
	t.eq(ECO.pesca_stock(ECO.SHOP_PIECES, 42), stock,
			"stesso seme, stessa pesca")
	t.eq(ECO.pesca_stock([], 42), [], "listino vuoto, banco vuoto")
	# con soli pezzi economici non si inventa un raro: si porta quel che c'è
	var economici := [{"name": "A", "cost": 10, "cur": "nut"},
			{"name": "B", "cost": 20, "cur": "nut"}]
	var piccolo: Array = ECO.pesca_stock(economici, 7)
	t.ok(piccolo.size() <= 2, "con due pezzi in croce il banco resta piccolo")


func _test_rotazione_su_istanza(t) -> void:
	var eco = ECO.new()
	eco.rotate_stock(10)
	var prima: Array = eco.stock.duplicate()
	t.ok(not prima.is_empty(), "dopo la visita il banco non è vuoto")
	eco.rotate_stock(10)
	t.eq(eco.stock, prima, "stesso giorno, stesso banco (ricaricare non rimescola)")
	# la stessa pesca è riproducibile su un altro villaggio nello stesso giorno
	var eco2 = ECO.new()
	eco2.rotate_stock(10)
	t.eq(eco2.stock, prima, "la rotazione è deterministica nel giorno")
	# un pezzo comprato sparisce dalle offerte, anche a metà giornata
	var comprato := str(prima[0])
	eco.unlock_piece(comprato)
	for offer in eco.stock_offers():
		t.ok(str(offer["name"]) != comprato, "il pezzo comprato lascia il banco")
	# e il banco persiste col villaggio
	var dati: Dictionary = eco.save_extra()
	var eco3 = ECO.new()
	eco3.load_extra(dati)
	t.eq(eco3.stock, eco.stock, "il banco sopravvive a save -> load")
	t.eq(int(eco3.stock_day), int(eco.stock_day), "e ricorda il giorno della pesca")
	eco.free()
	eco2.free()
	eco3.free()


func _test_sogni_costosi(t) -> void:
	# i sogni da risparmio lungo: almeno tre pezzi da 500+ noccioline,
	# perché le noccioline restino desiderabili per sempre
	var sogni := 0
	for p in ECO.SHOP_PIECES:
		if str(p.get("cur", "nut")) == "nut" and int(p["cost"]) >= 500:
			sogni += 1
	t.ok(sogni >= 3, "almeno tre sogni da 500+ noccioline (%d)" % sogni)
	for nome in ["Carillon", "Serra", "Mongolfiera"]:
		var trovato := false
		for p in ECO.SHOP_PIECES:
			if str(p["name"]) == nome:
				trovato = true
		t.ok(trovato, "il sogno '%s' è a listino" % nome)


func _test_builder_dei_sogni(t) -> void:
	# i tre builder nuovi costruiscono davvero un pezzo con dentro qualcosa
	for coppia in [["Carillon", CAT._musicbox], ["Serra", CAT._greenhouse],
			["Mongolfiera", CAT._balloon]]:
		var nodo: Node3D = (coppia[1] as Callable).call()
		t.ok(nodo != null and nodo.get_child_count() > 0,
				"il builder di '%s' produce un pezzo non vuoto" % coppia[0])
		nodo.free()


# ------------------------------------------------------------ la resa

func _test_resa_su_tutta_la_scala(t) -> void:
	# la resa copre TUTTI i gradini della scala e non risale mai: se un
	# gradino nuovo si infila in mezzo e la resa non lo conosce, la
	# monotonia si rompe e questo test si accende
	var attese := {"lavoro": 1.0, "svogliato": 0.55, "attrezzi": 0.35}
	var prec := 2.0
	for gradino in ANIMO.SCALA:
		var r: float = LAV.resa(str(gradino))
		if attese.has(gradino):
			t.almost(r, float(attese[gradino]),
					"resa di '%s'" % gradino, 0.001)
		else:
			t.almost(r, 0.0, "dal rifiuto in poi non si produce ('%s')" % gradino, 0.001)
		t.ok(r <= prec + 0.001, "la resa non risale lungo la scala ('%s')" % gradino)
		prec = r
	# il bonus del sogno: il boscaiolo alla catasta rende una volta e mezza
	t.almost(LAV.resa("lavoro", "boscaiolo", "taglia_legna"), 1.5,
			"chi fa il lavoro che sognava produce di più", 0.001)
	t.almost(LAV.resa("lavoro", "guerriero", "taglia_legna"), 1.0,
			"gli altri producono la base", 0.001)
	t.almost(LAV.resa("rifiuto", "boscaiolo", "taglia_legna"), 0.0,
			"nemmeno il sogno giusto fa lavorare chi si rifiuta", 0.001)
	# ogni lavoro del registro che produce ha il suo sogno in COMPITI
	for lavoro in LAV.ORDINE:
		if str(lavoro) == "":
			continue
		t.ok(ANIMO.COMPITI.has(lavoro),
				"il lavoro '%s' esiste in Animo.COMPITI" % lavoro)
	# le quantità: 3 col sogno, 2 sereno, 1 stanco o distratto, 0 in rivolta
	t.eq(LAV.quanti(2, 1.5), 3, "il boscaiolo sereno porta 3 legna")
	t.eq(LAV.quanti(2, 1.0), 2, "il sereno porta 2 legna")
	t.eq(LAV.quanti(2, 0.55), 1, "lo svogliato ne porta 1")
	t.eq(LAV.quanti(2, 0.35), 1, "il distratto ne porta 1")
	t.eq(LAV.quanti(2, 0.0), 0, "chi si rifiuta non porta niente")


# ------------------------------------------------------------ i temi

func _test_temi_del_carillon(t) -> void:
	t.ok(SFX.TEMI.has(SFX.TEMA_DEFAULT), "il tema di default esiste")
	t.eq(str(INTER.CARILLON_CICLO[0]), str(SFX.TEMA_DEFAULT),
			"il ciclo del carillon parte dal tema di sempre")
	for tema in INTER.CARILLON_CICLO:
		t.ok(SFX.TEMI.has(tema), "il tema '%s' del ciclo esiste in Sfx" % tema)
		t.ok(INTER.CARILLON_LABEL.has(tema),
				"il tema '%s' ha il suo annuncio nel toast" % tema)
	for tema in SFX.TEMI:
		var dati: Dictionary = SFX.TEMI[tema]
		var beats := float(dati["beats"])
		t.ok(float(dati["bpm"]) > 0.0 and beats > 0.0, "'%s': tempo sano" % tema)
		t.ok(not (dati["melody"] as Array).is_empty(), "'%s': ha una melodia" % tema)
		t.ok(not (dati["bass"] as Array).is_empty(), "'%s': ha un basso" % tema)
		for m in dati["melody"]:
			t.ok(float(m[0]) >= 0.0 and float(m[0]) < beats,
					"'%s': nota dentro il giro (beat %s)" % [tema, str(m[0])])
			t.ok(int(m[1]) >= 30 and int(m[1]) <= 110, "'%s': nota udibile" % tema)
			t.ok(float(m[2]) > 0.0 and float(m[2]) <= 1.0, "'%s': velocità sana" % tema)
		for b in dati["bass"]:
			t.ok(float(b[0]) >= 0.0 and float(b[0]) < beats,
					"'%s': basso dentro il giro" % tema)


func _test_render_dei_temi_nuovi(t) -> void:
	# i due temi nuovi cuociono davvero: buffer pieno, in loop senza cuciture
	# (Sfx fuori dall'albero: _ready non parte, _render_music è pura)
	var sfx = SFX.new()
	for tema in ["ninnananna", "valzer"]:
		var wav: AudioStreamWAV = sfx._render_music(str(tema))
		t.ok(wav.data.size() > 0, "il tema '%s' renderizza un wav pieno" % tema)
		t.eq(int(wav.loop_mode), int(AudioStreamWAV.LOOP_FORWARD),
				"il tema '%s' gira in loop" % tema)
	sfx.free()


# ------------------------------------------------------------ i fili

func _test_fili_attaccati(t) -> void:
	t.ok(_body("res://scenes/world/Calendar.gd", "_spawn_merchant")
			.contains("rotate_stock"),
			"l'arrivo del mercante rifà il banco")
	t.ok(_body("res://scenes/ui/Shop.gd", "_build_buy").contains("stock_offers"),
			"la vetrina COMPRA mostra il banco di oggi, non il listino intero")
	t.ok(_body("res://scenes/npc/Lavori.gd", "_on_nuovo_giorno")
			.contains("_produzione_del_giorno"),
			"il nuovo giorno fa produrre i lavori")
	var prod := _body("res://scenes/npc/Lavori.gd", "_produzione_del_giorno")
	for filo in ["add_wood", "villager_water", "cook_by_villager", "add_treasure"]:
		t.ok(prod.contains(filo), "la produzione arriva fino a '%s'" % filo)
	t.ok(_body("res://scenes/interact/Garden.gd", "_on_new_day").contains("Serra"),
			"la Serra tiene sveglio l'orto anche d'inverno")
	t.ok(_body("res://scenes/interact/Interactions.gd", "_gira_carillon")
			.contains("set_music_theme"),
			"il carillon arriva fino alla musica")


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
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
