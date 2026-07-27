extends RefCounted
## Il Filo Rosso fino in fondo: congedo, lutto, ricordi e la posta dei
## momenti (Fasi 3-6 di docs/SISTEMA_EMOZIONALE.md). Si prova il cuore
## PURO (regole del congedo, desideri del giorno, lettere dai momenti) e
## i contratti tra le tabelle: ogni tipo di momento ha il suo racconto,
## il suo luogo e il suo template di lettera — o niente parte.

const CONGEDO := preload("res://scenes/world/Congedo.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")
const MAIL := preload("res://scenes/interact/Mail.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func run(t) -> void:
	_test_regole_del_congedo(t)
	_test_desiderio_del_giorno(t)
	_test_contratti_tabelle(t)
	_test_lutto_sui_dati(t)
	_test_partito_sui_dati(t)
	_test_lettere_dai_momenti(t)
	_test_densita_e_varieta(t)
	_test_tocchi_di_luce(t)
	_test_luci_e_palpebre(t)


func _m(tipo: String, giorno := 1) -> Dictionary:
	return {"d": giorno, "t": tipo, "x": ""}


## I tocchi di luce della Fascia 3: il catchlight vivo, le lanterne del
## congedo, la timidezza delle creature — i fili che li tengono cablati.
func _test_tocchi_di_luce(t) -> void:
	# il catchlight: il rig passa i dischi, il motore condiviso li anima
	t.ok(_corpo("res://scenes/characters/FaceController.gd", "_apply_glints")
			.contains("_glint_base"), "il FaceController anima i catchlight")
	t.ok(_corpo("res://scenes/characters/FaceController.gd", "_aggiorna_luce")
			.contains("luce_calda"),
			"una lanterna calda a due passi vince sul cielo")
	t.ok(_sorgente("res://scenes/npc/ChibiBuilder.gd").contains("\"glints\": glints"),
			"i chibi passano i dischi-luce al motore")
	t.ok(_sorgente("res://scenes/characters/Mochi.gd").contains("\"glints\": _glints"),
			"Mochi pure")
	var dn = load("res://scenes/world/DayNight.gd").new()
	var v: Vector3 = dn.luce_verso()
	t.almost(v.length(), 1.0, "luce_verso e' un versore anche senza sole", 0.01)
	dn.free()
	# le lanterne dell'ultima sera
	t.ok(_corpo("res://scenes/world/Congedo.gd", "_lanterna")
			.contains("luce_calda"), "le lanterne entrano tra le luci calde")
	t.ok(_corpo("res://scenes/world/Congedo.gd", "_tick_congedo")
			.contains("_accendi_lanterne"), "l'ultima sera si accendono da sole")
	t.ok(_corpo("res://scenes/world/Congedo.gd", "_partenza")
			.contains("_spegni_lanterne"), "e all'alba della partenza si spengono")
	t.ok(_corpo("res://scenes/world/Congedo.gd", "_posti_lanterne")
			.contains("Sentiero"), "le lanterne seguono i sentieri del giocatore")
	# la timidezza delle creature
	t.ok(_sorgente("res://scenes/world/CozyWorld.gd").contains("\"dodge\""),
			"le farfalle sanno scansarsi al passaggio")
	t.ok(_corpo("res://scenes/interact/Collection.gd", "_update_fireflies")
			.contains("dodge"), "le lucciole pure")


## Le luci degli occhi seguono la PALPEBRA (il bug segnalato: Mochi
## socchiudeva gli occhi e le palline bianche restavano lì, piene): a
## occhio socchiuso si schiacciano con la superficie, riaperto tornano.
## Prova COMPORTAMENTALE su un rig minimo, senza SceneTree.
func _test_luci_e_palpebre(t) -> void:
	var FC = load("res://scenes/characters/FaceController.gd")
	var head := Node3D.new()
	var eyes: Array[Node3D] = []
	var balls: Array[MeshInstance3D] = []
	var irises: Array[Node3D] = []
	for side in 2:
		var eye := Node3D.new()
		head.add_child(eye)
		var ball := MeshInstance3D.new()
		eye.add_child(ball)
		var iris := Node3D.new()
		eye.add_child(iris)
		eyes.append(eye)
		balls.append(ball)
		irises.append(iris)
	var face = FC.new()
	face.setup({"head": head, "eyes": eyes, "eyeballs": balls, "irises": irises})
	face.freeze_blink(99.0)   # niente ammicchi casuali durante la misura
	var base_y: float = irises[0].scale.y
	# occhio SOCCHIUSO (beato, apertura 0.42): le luci si schiacciano
	face.set_expression("beato", 1.0, 999.0)
	for i in 60:
		face.update(0.05)
	t.ok(irises[0].scale.y < base_y * 0.6,
			"socchiuso: le luci si schiacciano con la palpebra (y=%.2f)"
			% irises[0].scale.y)
	t.ok(irises[0].scale.x < base_y * 0.99,
			"e si stringono un filo anche in larghezza")
	t.ok(irises[0].visible, "ma a occhio socchiuso si vedono ancora")
	# occhio RIAPERTO: tornano piene
	face.set_expression("neutro", 1.0, 999.0)
	for i in 60:
		face.update(0.05)
	t.ok(irises[0].scale.y > base_y * 0.9,
			"riaperto: le luci tornano piene (y=%.2f)" % irises[0].scale.y)
	t.ok(irises[0].visible, "e ben visibili")
	head.free()


## L'intero sorgente di uno script.
func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
func _corpo(path: String, fn: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)


## Le regole cozy della mortalità, una per una.
func _test_regole_del_congedo(t) -> void:
	# il caso buono: anziano da tanto, mai partenze, villaggio popolato
	t.ok(CONGEDO.pronto_al_congedo(60, 100, -1, 3, false, false),
			"60 giorni di amicizia, 3 residenti: e' tempo")
	t.ok(not CONGEDO.pronto_al_congedo(60, 100, -1, 3, true, false),
			"Prato Eterno: nessuna partenza, mai")
	t.ok(not CONGEDO.pronto_al_congedo(60, 100, -1, 3, false, true),
			"un congedo gia' in corso: uno alla volta")
	t.ok(not CONGEDO.pronto_al_congedo(60, 100, -1, 1, false, false),
			"il villaggio non resta mai vuoto (serve piu' di un residente)")
	t.ok(not CONGEDO.pronto_al_congedo(CONGEDO.ETA_PARTENZA - 1, 100, -1, 3, false, false),
			"troppo presto: la partenza arriva solo dopo una lunga vita")
	t.ok(not CONGEDO.pronto_al_congedo(60, 100, 100 - CONGEDO.DISTANZA_PARTENZE + 1,
			3, false, false), "mai due partenze vicine (meno di un ciclo)")
	t.ok(CONGEDO.pronto_al_congedo(60, 100, 100 - CONGEDO.DISTANZA_PARTENZE,
			3, false, false), "passato un ciclo intero, si puo' di nuovo")
	# l'eta' del congedo viene DOPO l'autunno del filo
	t.ok(CONGEDO.ETA_PARTENZA > LEGAMI.GIORNI_ANZIANO,
			"si parte solo ben oltre l'autunno (%d > %d)"
			% [CONGEDO.ETA_PARTENZA, LEGAMI.GIORNI_ANZIANO])


## L'ultimo desiderio del giorno: deterministico, nell'ordine vissuto.
func _test_desiderio_del_giorno(t) -> void:
	var momenti := [_m("onsen", 3), _m("festa", 5), _m("onsen", 8), _m("piatto", 9)]
	var d0: Dictionary = CONGEDO.desiderio_del_giorno(momenti, 0)
	t.eq(str(d0["tipo"]), "onsen", "giorno 0: il primo tipo vissuto (onsen)")
	t.eq(str(CONGEDO.desiderio_del_giorno(momenti, 1)["tipo"]), "festa",
			"giorno 1: il secondo tipo vissuto (i doppioni non contano)")
	t.eq(str(CONGEDO.desiderio_del_giorno(momenti, 2)["tipo"]), "piatto",
			"giorno 2: il terzo tipo")
	t.eq(str(CONGEDO.desiderio_del_giorno(momenti, 3)["tipo"]), "onsen",
			"giorno 3: la rotazione ricomincia")
	t.eq(str(CONGEDO.desiderio_del_giorno(momenti, 0)["tipo"]),
			str(d0["tipo"]), "stesso giorno, stesso desiderio (deterministico)")
	# i tipi che non sono luoghi da rivivere restano fuori
	var strani := [_m("oro"), _m("addio"), _m("partenza")]
	t.eq(str(CONGEDO.desiderio_del_giorno(strani, 0)["tipo"]), "trasloco",
			"oro/addio/partenza non generano desideri: si sogna casa")
	t.eq(str(CONGEDO.desiderio_del_giorno([], 4)["tipo"]), "trasloco",
			"filo vuoto: si sogna comunque casa sua")
	for i in 7:
		var d: Dictionary = CONGEDO.desiderio_del_giorno(momenti, i)
		t.ok(str(d["luogo"]) != "" and str(d["testo"]) != "",
				"giorno %d: luogo e racconto sempre pieni" % i)


## I contratti fra le tabelle: se qualcuno aggiunge un tipo di momento e
## dimentica una tabella, qui si accende una spia.
func _test_contratti_tabelle(t) -> void:
	t.ok(LEGAMI.TIPI.has("oro"), "il momento d'oro esiste nel Filo")
	t.ok(LEGAMI.TIPI.has("partenza"), "la partenza gentile esiste nel Filo")
	for tipo in CONGEDO.LUOGHI:
		t.ok(LEGAMI.TIPI.has(str(tipo)),
				"il luogo del congedo '%s' e' un tipo vero del Filo" % tipo)
		t.ok(CONGEDO.DESIDERI_TESTO.has(str(tipo)),
				"il tipo '%s' ha il racconto dell'ultimo desiderio" % tipo)
	for tipo in LEGAMI.TIPI:
		t.ok(MAIL.MOMENTI_TESTO.has(str(tipo)),
				"il tipo '%s' ha il template della lettera" % tipo)
		t.ok(str(MAIL.MOMENTI_TESTO.get(str(tipo), "")).contains("%d"),
				"il template di '%s' cita il giorno del momento" % tipo)
	# il congedo convive con la scala dell'Animo: se l'anziana DISERTA a
	# meta' settimana, niente memoriale dorato (il filo del sorgente)
	var giorno := _corpo("res://scenes/world/Congedo.gd", "_nuovo_giorno")
	t.ok(giorno.contains("dna_di"),
			"il congedo si accorge della diserzione e si annulla")


## Il lutto sui DATI (Legami): apre, consola, chiude — e chi non ha mai
## ricevuto un pensiero torna indietro alla chiusura.
func _test_lutto_sui_dati(t) -> void:
	var lg = LEGAMI.new()
	t.ok(not lg.lutto_attivo(), "all'inizio nessun lutto")
	lg.inizia_lutto("Nocciola", ["il gattino Miele", "la volpina Pepita"])
	t.ok(lg.lutto_attivo(), "il lutto si apre")
	var l = lg.lutto()
	t.ok(int(l["giorni"]) >= 3 and int(l["giorni"]) <= 8,
			"la durata del lutto sta fra 3 e 8 giorni (%s)" % l["giorni"])
	t.ok(lg.consola("il gattino Miele"), "la zampina alzata consola chi aspettava")
	t.ok(not lg.consola("il gattino Miele"), "ma una volta sola")
	t.ok(not lg.consola("uno sconosciuto"), "gli estranei non erano in lista")
	var ignorati = lg.fine_lutto()
	t.eq(ignorati.size(), 1, "alla chiusura resta chi non ha avuto un pensiero")
	t.eq(str(ignorati[0]), "la volpina Pepita", "ed e' proprio lei")
	t.ok(not lg.lutto_attivo(), "il lutto chiuso e' chiuso")
	lg.free()


## La partenza sui DATI: il filo resta, cambia solo forma.
func _test_partito_sui_dati(t) -> void:
	var lg = LEGAMI.new()
	lg.momento("Nocciola", "onsen")
	t.ok(not lg.e_partito("Nocciola"), "prima della partenza il filo e' vivo")
	lg.segna_partito("Nocciola", {"x": 1.0, "z": 2.0, "dress": "f2a9bc",
			"fur": "e8d5b8", "petali": 6})
	t.ok(lg.e_partito("Nocciola"), "dopo, il filo ricorda la partenza")
	var partiti = lg.partiti()
	t.eq(partiti.size(), 1, "un partito nel registro")
	var filo: Dictionary = partiti[0][1]
	t.ok(not (filo.get("fiore", {}) as Dictionary).is_empty(),
			"la scheda del fiore-ricordo viaggia col filo")
	t.eq((filo.get("momenti", []) as Array).size(), 1,
			"i momenti NON si cancellano: la perdita trasforma")
	lg.free()


## Le lettere nate dai momenti: deterministiche, datate, firmate.
func _test_lettere_dai_momenti(t) -> void:
	t.ok((MAIL.componi_lettera("il gattino Miele", [], 0) as Dictionary).is_empty(),
			"filo vuoto: nessuna lettera")
	var momenti := [_m("onsen", 12), _m("festa", 20)]
	var l1: Dictionary = MAIL.componi_lettera("il gattino Miele", momenti, 0)
	t.eq(str(l1["from"]), "il gattino Miele", "la lettera e' firmata")
	t.ok(str(l1["text"]).contains("12"), "e cita il giorno del momento")
	var l2: Dictionary = MAIL.componi_lettera("il gattino Miele", momenti, 1)
	t.ok(str(l2["text"]).contains("20"), "pick diverso, momento diverso")
	t.eq(str(MAIL.componi_lettera("x", momenti, 0)["text"]),
			str(l1["text"]), "stesso pick, stessa lettera (deterministica)")
	# ogni tipo del Filo produce una lettera vera
	for tipo in LEGAMI.TIPI:
		var l: Dictionary = MAIL.componi_lettera("qualcuno", [_m(str(tipo), 7)], 1)
		t.ok(not l.is_empty() and str(l["text"]).length() > 20,
				"il tipo '%s' produce una lettera vera" % tipo)
	# un filo ricco lo dice
	var tanti := []
	for i in 7:
		tanti.append(_m("piatto", i + 1))
	t.ok(str(MAIL.componi_lettera("x", tanti, 1)["text"]).contains("7"),
			"un filo ricco conta i suoi momenti")


## La densita' e la varieta': ventotto posti, cinque archetipi garantiti.
func _test_densita_e_varieta(t) -> void:
	t.eq(VISITORS.MAX_RESIDENTS, 28, "ventotto residenti: il villaggio brulica")
	t.ok(DNA.NAMES.size() >= VISITORS.MAX_RESIDENTS,
			"un nome per ogni posto: le etichette restano uniche (%d nomi)"
			% DNA.NAMES.size())
	# i posti al falo' non si pestano: ognuno il suo, anche in ventotto
	var v = VISITORS.new()
	var visti := {}
	var vicini := 0
	for i in VISITORS.MAX_RESIDENTS:
		var p: Vector3 = v._posto_al_falo(i)
		for altro in visti:
			if p.distance_to(visti[altro]) < 0.55:
				vicini += 1
		visti[i] = p
	t.eq(vicini, 0, "al falo' nessuno siede in braccio a un altro (28 posti)")
	v.free()
	t.eq(VISITORS.archetipi_mancanti([]).size(), DNA.ARCHETYPES.size(),
			"villaggio vuoto: mancano tutti e cinque")
	var m = VISITORS.archetipi_mancanti(["gatto", "gatto", "coniglio"])
	t.eq(m.size(), 3, "con gatti e conigli ne mancano tre")
	t.ok("orsetto" in m and "volpina" in m and "topolino" in m,
			"e sono proprio orsetto, volpina e topolino")
	t.eq(VISITORS.archetipi_mancanti(
			["gatto", "coniglio", "orsetto", "volpina", "topolino"]).size(), 0,
			"al gran completo non manca nessuno")
