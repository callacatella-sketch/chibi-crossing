extends RefCounted
## La Stratigrafia (Strati: il ledger degli strati sepolti).
##
## Il salvataggio come sito archeologico di se stesso: le demolizioni del
## giocatore, chi parte per sempre e le stagioni seppelliscono strati che
## un mattino riaffiorano sotto un luccichio di Scavi. Qui si prova la
## parte PURA: il deposito, la stratigrafia per cella (vince il g
## massimo), la potatura che protegge i ricordi, la scelta deterministica
## del giorno, il round-trip JSON (gli int tornano float) e il gate che
## fa restare vero «ogni tanto». Ogni test SA FALLIRE per una regola
## precisa, annotata accanto.

const STRATI := preload("res://scenes/world/Strati.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const LAV := preload("res://scenes/npc/Lavori.gd")
const DN := preload("res://scenes/world/DayNight.gd")

# gli stessi ostacoli finti di test_scavi: lo stagno e un masso, come li
# darebbe CozyWorld.obstacle_circles() — [Vector3(x, raggio, z)]
const OSTACOLI := [Vector3(9.5, 5.2, -10.5), Vector3(-4.0, 2.0, -2.0)]


func run(t) -> void:
	_test_tabelle(t)
	_test_priorita(t)
	_test_tinta(t)
	_test_dedupe_pezzo(t)
	_test_valida_cella(t)
	_test_stagionale(t)
	_test_affiorante(t)
	_test_pota(t)
	_test_sepoltura(t)
	_test_roundtrip(t)
	_test_gate(t)
	_test_scrittori_muti(t)
	_test_scavi_reperto_giusto(t)
	_test_scavi_reperto_scavato_non_torna(t)
	_test_partenze_nome_giusto(t)
	_test_lingua_reperti(t)
	_test_demolizione_giocatore(t)
	_test_demolizione_harness_muta(t)
	_test_toast_e_accredito(t)


# Le tabelle del carattere coprono TUTTO ciò che il gioco può generare:
# ogni quirk di VillagerBrain, ogni mestiere di Lavori, ogni indole.
# (Fallisce se: qualcuno aggiunge un quirk/mestiere/indole senza dargli
# un oggetto — il partito lascerebbe solo il bottone anonimo.)
func _test_tabelle(t) -> void:
	for quirk in BRAIN.QUIRKS:
		var oggetto: String = STRATI.oggetto_del_ricordo({"quirk": quirk}, "")
		t.eq(oggetto, str(STRATI.OGGETTI_QUIRK.get(quirk, "?")),
				"il quirk «%s» ha il suo oggetto" % quirk)
	for mestiere in LAV.LAVORI.keys():
		var oggetto: String = STRATI.oggetto_del_ricordo({}, str(mestiere))
		if str(mestiere) == "":
			t.eq(oggetto, STRATI.OGGETTO_FALLBACK,
					"chi riposava e non ha carattere lascia il bottone")
		else:
			t.eq(oggetto, str(STRATI.OGGETTI_MESTIERE.get(mestiere, "?")),
					"il mestiere «%s» ha il suo oggetto" % mestiere)
	for indole in BRAIN.INDOLI.keys():
		var oggetto: String = STRATI.oggetto_del_ricordo({"indole": [indole]}, "")
		t.eq(oggetto, str(STRATI.OGGETTI_INDOLE.get(indole, "?")),
				"l'indole «%s» ha il suo oggetto" % indole)
	# un segno per ogni stagione del calendario, né uno in più né in meno
	t.eq(STRATI.SEGNI_STAGIONE.size(), DN.SEASON_NAMES.size(),
			"un segno per ogni stagione")
	for s in DN.SEASON_NAMES.size():
		t.ok(STRATI.SEGNI_STAGIONE.has(s), "la stagione %d ha il suo segno" % s)


# La priorità del carattere: quirk batte mestiere batte indole.
# (Fallisce se: l'ordine di derivazione cambia — e la lanternina della
# guardia coprirebbe il sassolino del collezionista.)
func _test_priorita(t) -> void:
	t.eq(STRATI.oggetto_del_ricordo(
			{"quirk": "colleziona_sassolini", "indole": ["goloso"]}, "cucina"),
			"sassolino_lucido", "il quirk batte mestiere e indole")
	t.eq(STRATI.oggetto_del_ricordo({"indole": ["goloso"]}, "cucina"),
			"cucchiaino_di_legno", "il mestiere batte l'indole")
	t.eq(STRATI.oggetto_del_ricordo({"indole": ["goloso"]}, ""),
			"barattolino_di_briciole", "senza quirk né mestiere parla l'indole")
	t.eq(STRATI.oggetto_del_ricordo({}, ""), "bottone_di_legno",
			"dna vuoto: resta il bottone di legno")
	t.eq(STRATI.oggetto_del_ricordo({"quirk": "inesistente", "indole": ["timido"]}, ""),
			"guscio_di_nocciola", "un quirk sconosciuto scivola avanti senza rompere")


# La tinta del reperto viene dal pelo, in tutte le forme in cui "fur"
# può presentarsi (html del DNA, Color in RAM, Array da un giro di JSON).
func _test_tinta(t) -> void:
	var html := STRATI.tinta_da({"fur": "f7e6d0"}) as Array
	t.eq(html.size(), 3, "la tinta è sempre [r, g, b]")
	t.almost(float(html[0]), Color("f7e6d0").r, "tinta html: canale rosso")
	t.almost(float(html[1]), Color("f7e6d0").g, "tinta html: canale verde")
	var col := STRATI.tinta_da({"fur": Color(0.2, 0.4, 0.6)}) as Array
	t.almost(float(col[2]), 0.6, "tinta da Color: canale blu")
	var arr := STRATI.tinta_da({"fur": [0.1, 0.2, 0.3]}) as Array
	t.almost(float(arr[0]), 0.1, "tinta da Array: passa com'è")
	var boh := STRATI.tinta_da({}) as Array
	t.almost(float(boh[0]), 0.82, "senza pelo: il beige caldo di riserva")
	var rotto := STRATI.tinta_da({"fur": "non-un-colore"}) as Array
	t.eq(rotto.size(), 3, "un html rotto non fa crollare la tinta")


# «La trave del PRIMO ponte»: un solo strato per pezzo demolito.
# (Fallisce se: il dedupe sparisce — dieci staccionate, dieci schegge.)
func _test_dedupe_pezzo(t) -> void:
	var strati := [STRATI.riga_demolizione([3, 3], "Ponte", 1)]
	t.ok(STRATI.gia_sepolto_pezzo(strati, "Ponte"), "il Ponte è già sotto terra")
	t.ok(not STRATI.gia_sepolto_pezzo(strati, "Staccionata"),
			"la Staccionata non ancora")
	# il campo "pezzo" conta solo sulle demolizioni, non sugli altri tipi
	var finto := [{"tipo": "ricordo", "cella": [3, 3], "g": 1, "pezzo": "Ponte"}]
	t.ok(not STRATI.gia_sepolto_pezzo(finto, "Ponte"),
			"un ricordo non blocca la sepoltura di un pezzo")


# La cintura del prato: fuori dal RECT o dentro un ostacolo non si
# seppellisce (lì non affiorerebbe mai). Stessi ostacoli di test_scavi.
func _test_valida_cella(t) -> void:
	t.ok(not STRATI.valida_cella([9, -10], OSTACOLI), "lo stagno è occupato")
	t.ok(STRATI.valida_cella([-10, 5], OSTACOLI), "il prato aperto accoglie")
	t.ok(not STRATI.valida_cella([20, 0], OSTACOLI), "fuori dal prato mai")
	t.ok(STRATI.valida_cella([-13, -15], OSTACOLI), "il bordo del prato è prato")
	t.ok(not STRATI.valida_cella([-4, 0], OSTACOLI),
			"il margine del masso (+1.0) tiene lontani")


# Il segno di stagione: solo al confine di giorno, raro, deterministico.
# (Fallisce se: il seme viene riformattato, un consumo rng si sposta, o
# la formula del confine (giorno-1) % SEASON_DAYS si rompe.)
func _test_stagionale(t) -> void:
	for g in range(1, 8):
		var riga: Dictionary = STRATI.riga_stagionale(g, OSTACOLI)
		t.ok(riga.is_empty(), "giorno %d: nessun confine, nessun segno" % g)
	t.ok(STRATI.riga_stagionale(100, OSTACOLI).is_empty(),
			"giorno 100: non è un confine")
	var visti := {}
	var vuoti := 0
	var pieni := 0
	for k in 40:
		var g: int = 8 + 7 * k
		var riga: Dictionary = STRATI.riga_stagionale(g, OSTACOLI)
		if riga.is_empty():
			vuoti += 1
			continue
		pieni += 1
		t.eq(str(riga.get("tipo", "")), "stagione", "g%d: tipo stagione" % g)
		t.eq(int(riga.get("g", 0)), g, "g%d: la riga ricorda il suo giorno" % g)
		@warning_ignore("integer_division")
		var attesa: int = (int((g - 1) / DN.SEASON_DAYS) + 3) % 4
		t.eq(str(riga.get("segno", "")), str(STRATI.SEGNI_STAGIONE[attesa]),
				"g%d: il segno è della stagione FINITA" % g)
		t.ok(STRATI.valida_cella(riga.get("cella", []), OSTACOLI),
				"g%d: la cella del segno è seppellibile" % g)
		visti[str(riga.get("segno", ""))] = true
	t.ok(vuoti >= 1, "il segno è raro: qualche confine resta muto")
	t.ok(pieni >= 1, "ma non sempre: qualche segno arriva")
	for segno in STRATI.SEGNI_STAGIONE.values():
		t.ok(visti.has(str(segno)), "in dieci anni esce anche: %s" % segno)
	# deterministico: al reload il segno non cambia
	var a: Dictionary = STRATI.riga_stagionale(8, OSTACOLI)
	var b: Dictionary = STRATI.riga_stagionale(8, OSTACOLI)
	t.ok(a == b, "stesso confine: stessa riga, cella compresa")


# Il cuore deterministico: cosa affiora oggi non dipende dall'ordine
# dell'array, per cella vince il g massimo, e conta solo g < oggi.
# (Fallisce se: il filtro diventa g <=, il sort delle celle sparisce, la
# stratigrafia per-cella si perde o un consumo rng si sposta.)
func _test_affiorante(t) -> void:
	# ciò che si seppellisce OGGI non muove i luccichii di OGGI — provato su
	# TRENTA giorni, non su uno. Col filtro giusto le celle eleggibili sono
	# vuote e la risposta è {} PRIMA di seminare il dado, quindi il giro è
	# verde su ogni giorno; col filtro rotto (g <=) il dado di PROB_AFFIORA
	# accende ~10 giorni su 30 → rosso certo. L'asserzione su un giorno solo
	# passava PER FORTUNA DI SEME (hash("affiora_5") tira sopra la soglia: il
	# giorno 5 era muto con e senza la riga) e la classe di regressione n.1
	# del progetto restava senza rete, a suite verde.
	for d in range(5, 35):
		t.ok((STRATI.strato_affiorante(d,
				[STRATI.riga_demolizione([3, 3], "Ponte", d)]) as Dictionary).is_empty(),
				"g == oggi (g%d): non eleggibile" % d)
		t.ok((STRATI.strato_affiorante(d,
				[STRATI.riga_demolizione([3, 3], "Ponte", d + 1)]) as Dictionary).is_empty(),
				"g > oggi (g%d): nemmeno" % d)
	var lista := [
		STRATI.riga_demolizione([3, 3], "Ponte", 1),
		STRATI.riga_ricordo([-5, 2], "Momo", "Momo", {"indole": ["timido"]}, "", 2),
		{"tipo": "stagione", "cella": [0, -8], "g": 3, "segno": "petalo_pressato"},
		STRATI.riga_demolizione([6, -3], "Sedia", 4),
	]
	var rovescia := lista.duplicate()
	rovescia.reverse()
	var muti := 0
	var affiorati := 0
	var celle_viste := {}
	for giorno in range(5, 35):
		var r: Dictionary = STRATI.strato_affiorante(giorno, lista)
		var r2: Dictionary = STRATI.strato_affiorante(giorno, lista)
		t.ok(r == r2, "g%d: due chiamate, stessa risposta" % giorno)
		var r3: Dictionary = STRATI.strato_affiorante(giorno, rovescia)
		t.ok(r == r3, "g%d: l'ordine dell'array non conta (celle ordinate)" % giorno)
		if r.is_empty():
			muti += 1
			continue
		affiorati += 1
		celle_viste[str(r.get("cella", []))] = true
		t.ok(r in lista, "g%d: affiora una riga vera" % giorno)
	t.ok(muti >= 1, "il silenzio è il comportamento normale")
	t.ok(affiorati >= 1, "ma ogni tanto la terra restituisce")
	t.ok(celle_viste.size() >= 2, "giorni diversi, strati diversi")
	# il duplicate(true): chi riceve la riga non può sporcare il ledger
	var trovato := false
	for giorno in range(5, 35):
		var r: Dictionary = STRATI.strato_affiorante(giorno, lista)
		if not r.is_empty():
			(r.get("cella", []) as Array)[0] = 999
			trovato = true
			break
	var sporcato := false
	for rr in lista:
		if int(((rr as Dictionary)["cella"] as Array)[0]) == 999:
			sporcato = true
	t.ok(trovato and not sporcato,
			"la riga affiorata è una copia profonda: il ledger resta intatto")
	# STRATIGRAFIA: sulla stessa cella si scava prima lo strato più in alto
	var pila := [
		STRATI.riga_demolizione([3, 3], "Ponte", 1),
		{"tipo": "stagione", "cella": [3, 3], "g": 4, "segno": "petalo_pressato"},
	]
	var visto_g := -1
	for giorno in range(5, 65):
		var r: Dictionary = STRATI.strato_affiorante(giorno, pila)
		if not r.is_empty():
			visto_g = int(r.get("g", -1))
			break
	t.eq(visto_g, 4, "per cella vince il g massimo (lo strato più in alto)")
	# a parità di g, la riga sepolta prima
	var pari := [
		STRATI.riga_demolizione([2, 2], "Ponte", 1),
		STRATI.riga_demolizione([2, 2], "Sedia", 1),
	]
	var visto_pezzo := ""
	for giorno in range(2, 62):
		var r: Dictionary = STRATI.strato_affiorante(giorno, pari)
		if not r.is_empty():
			visto_pezzo = str(r.get("pezzo", ""))
			break
	t.eq(visto_pezzo, "Ponte", "a parità di g resta la riga sepolta prima")


# La potatura gentile: stagioni prima, poi demolizioni, i ricordi per
# ULTIMI — protezione strutturale, non un flag. L'ordine relativo dei
# sopravvissuti si conserva. (Fallisce se: la priorità s'inverte o un
# ricordo cade quando resta altro da lasciar andare.)
func _test_pota(t) -> void:
	var stagioni: Array = []
	for i in 10:
		stagioni.append({"tipo": "stagione", "cella": [i, 0], "g": 1 + i,
				"segno": "petalo_pressato"})
	var demolizioni: Array = []
	for i in 35:
		demolizioni.append(STRATI.riga_demolizione([i, 1], "P%d" % i, 100 + i))
	var ricordi: Array = []
	for i in 15:
		ricordi.append(STRATI.riga_ricordo([i, 2], "N%d" % i, "N%d" % i,
				{}, "", 200 + i))
	# mescolate a mano (deterministico): la potatura non deve dipendere
	# dall'ordine, e i sopravvissuti devono restare nell'ordine loro
	var lista: Array = []
	var code := [demolizioni.duplicate(), stagioni.duplicate(), ricordi.duplicate()]
	var giro := 0
	while lista.size() < 60:
		var coda: Array = code[giro % 3]
		if coda.size() > 0:
			lista.append(coda.pop_front())
		giro += 1
	var potata: Array = STRATI.pota(lista)
	t.eq(potata.size(), STRATI.MAX_STRATI, "60 righe -> il tetto della terra")
	var n_stagioni := 0
	var n_ricordi := 0
	for r in potata:
		match str((r as Dictionary).get("tipo", "")):
			"stagione":
				n_stagioni += 1
			"ricordo":
				n_ricordi += 1
			"demolizione":
				t.ok(int((r as Dictionary).get("g", 0)) >= 110,
						"le demolizioni cadute sono le più antiche")
	t.eq(n_stagioni, 0, "le stagioni si lasciano andare per prime")
	t.eq(n_ricordi, 15, "TUTTI i ricordi sopravvivono finché resta altro")
	# l'ordine relativo si conserva: potata è una sottosequenza di lista
	var j := 0
	for r in potata:
		while j < lista.size() and not (lista[j] == r):
			j += 1
		j += 1
	t.ok(j <= lista.size(), "si filtra, non si riordina")
	t.ok(STRATI.pota(lista) == potata, "la potatura è deterministica")
	# sotto il tetto non si tocca niente
	var poche: Array = lista.slice(0, 5)
	t.ok(STRATI.pota(poche) == poche, "sotto il tetto la lista resta com'è")
	# di soli ricordi: il tetto vale comunque, cadono i più vecchi
	var molti_ricordi: Array = []
	for i in 60:
		molti_ricordi.append(STRATI.riga_ricordo([i, 3], "R%d" % i, "R%d" % i,
				{}, "", 300 + i))
	var rp: Array = STRATI.pota(molti_ricordi)
	t.eq(rp.size(), STRATI.MAX_STRATI, "anche i ricordi rispettano il tetto")
	t.eq(int((rp[0] as Dictionary).get("g", 0)), 320,
			"fra soli ricordi cadono i più vecchi")


# «Vicino a casa sua»: anelli Chebyshev dall'interno, mai il letto (0,0)
# né il fiore-memoriale (+1,+1), dentro il prato, con ripiego seminato.
# (Fallisce se: il fiore non è più escluso, gli anelli si invertono o il
# ripiego perde il seme.)
func _test_sepoltura(t) -> void:
	var celle: Array = STRATI.celle_intorno([0, 0], 7)
	t.eq(celle.size(), 79, "quattro anelli senza letto né fiore: 7+16+24+32")
	var confini := [7, 23, 47, 79]
	for i in celle.size():
		var c: Array = celle[i]
		t.ok(not (int(c[0]) == 0 and int(c[1]) == 0), "mai il letto (0,0)")
		t.ok(not (int(c[0]) == 1 and int(c[1]) == 1), "mai il fiore (+1,+1)")
		var anello: int = maxi(absi(int(c[0])), absi(int(c[1])))
		var atteso := 1
		for k in confini.size():
			if i < confini[k]:
				atteso = k + 1
				break
		t.eq(anello, atteso, "cella %d: l'anello interno viene prima" % i)
	t.ok(STRATI.celle_intorno([0, 0], 7) == celle,
			"stesso seme: stesso giro di celle")
	t.ok(STRATI.celle_intorno([0, 0], 8) != celle,
			"seme diverso: mescolata diversa")
	# nel prato aperto il ricordo sta nell'anello 1
	var libera := func(_c: Array) -> bool: return false
	var casa := [-10, 5]
	var dove: Variant = STRATI.cella_di_sepoltura(casa, 7, 3, OSTACOLI, libera)
	t.ok(dove != null, "nel prato aperto una cella si trova")
	var dist: int = maxi(absi(int(dove[0]) - casa[0]), absi(int(dove[1]) - casa[1]))
	t.eq(dist, 1, "il ricordo sta vicino a casa: anello 1")
	t.ok(STRATI.valida_cella(dove, OSTACOLI), "ed è una cella seppellibile")
	# con l'anello 1 tutto occupato, si allarga
	var anello1_pieno := func(c: Array) -> bool:
		return maxi(absi(int(c[0]) - casa[0]), absi(int(c[1]) - casa[1])) <= 1
	var oltre: Variant = STRATI.cella_di_sepoltura(casa, 7, 3, OSTACOLI, anello1_pieno)
	t.ok(oltre != null, "anello 1 pieno: si trova comunque")
	var dist2: int = maxi(absi(int(oltre[0]) - casa[0]), absi(int(oltre[1]) - casa[1]))
	t.ok(dist2 >= 2, "…ma più in là")
	# tutto occupato: il silenzio è il comportamento normale
	var occupata := func(_c: Array) -> bool: return true
	t.ok(STRATI.cella_di_sepoltura(casa, 7, 3, OSTACOLI, occupata) == null,
			"tutto occupato: null, nessun errore")
	# casa fuori dal prato (999,999 dei senza-casa): parla il ripiego
	var esule: Variant = STRATI.cella_di_sepoltura([999, 999], 7, 3, OSTACOLI, libera)
	t.ok(esule != null, "casa fuori dal prato: il ripiego trova terra")
	t.ok(STRATI.valida_cella(esule, OSTACOLI), "…dentro il prato")
	var esule2: Variant = STRATI.cella_di_sepoltura([999, 999], 7, 3, OSTACOLI, libera)
	t.ok(esule == esule2, "il ripiego è seminato: stesso giorno, stessa cella")
	var determin: Variant = STRATI.cella_di_sepoltura(casa, 7, 3, OSTACOLI, libera)
	t.ok(dove == determin, "stessa casa e seme: stessa sepoltura")


# Round-trip JSON VERO (stringify -> parse -> load_extra): gli int
# tornano float e la rilettura li deve rimettere in riga con int().
# Le righe malformate si saltano senza errore.
func _test_roundtrip(t) -> void:
	var righe := [
		STRATI.riga_demolizione([3, -7], "Ponte", 2),
		STRATI.riga_ricordo([-5, 2], "Momo", "Momo la panettiera",
				{"quirk": "colleziona_sassolini", "fur": "f7e6d0"}, "cucina", 9),
		{"tipo": "stagione", "cella": [0, -8], "g": 15, "segno": "foglia_d_oro"},
	]
	var payload := {"strati": {"righe": righe, "g_aff": 3, "g_pota": 7}}
	var testo := JSON.stringify(payload)
	var redivivo: Dictionary = JSON.parse_string(testo)
	var s = STRATI.new()
	s.load_extra(redivivo)
	var salvati: Array = s._strati
	t.eq(salvati.size(), 3, "le tre righe tornano dal disco")
	for i in salvati.size():
		var r: Dictionary = salvati[i]
		t.ok(typeof(r["g"]) == TYPE_INT, "riga %d: g torna int (dal float JSON)" % i)
		var c: Array = r["cella"]
		t.ok(typeof(c[0]) == TYPE_INT and typeof(c[1]) == TYPE_INT,
				"riga %d: la cella torna [int, int]" % i)
	t.eq(int((salvati[0] as Dictionary)["g"]), 2, "il giorno di sepoltura non cambia")
	t.eq(str((salvati[1] as Dictionary)["oggetto"]), "sassolino_lucido",
			"l'oggetto del ricordo sopravvive al disco")
	t.eq(str((salvati[1] as Dictionary)["nome"]), "Momo",
			"la chiave è il NOME del dna, e resta")
	var g_aff = s._g_aff
	var g_pota = s._g_pota
	t.eq(int(g_aff), 3, "g_aff torna dal disco")
	t.eq(int(g_pota), 7, "g_pota torna dal disco")
	# save_extra -> load_extra si richiudono (il giro intero)
	var eco: Dictionary = s.save_extra()
	var s2 = STRATI.new()
	s2.load_extra(JSON.parse_string(JSON.stringify(eco)))
	t.ok(s2._strati == s._strati, "save_extra e load_extra si richiudono")
	s2.free()
	# qualunque schifezza: righe malformate saltate, mai un crash
	var s3 = STRATI.new()
	s3.load_extra({"strati": {"righe": [
			"ciao", 42,
			{"tipo": "demolizione", "cella": [1], "g": 2, "pezzo": "Zoppo"},
			{"tipo": "stagione", "cella": [2, 3], "g": 4, "segno": "petalo_pressato"},
	], "g_aff": -1, "g_pota": -1}})
	var superstiti: Array = s3._strati
	t.eq(superstiti.size(), 1, "delle righe rotte resta solo quella sana")
	t.eq(str((superstiti[0] as Dictionary).get("segno", "")), "petalo_pressato",
			"…ed è quella giusta")
	s3.free()
	var s4 = STRATI.new()
	s4.load_extra({"altra_chiave": true})
	t.eq((s4._strati as Array).size(), 0, "senza la chiave strati non succede niente")
	s4.free()
	s.free()


# Il gate del giorno: estratto() toglie la riga PER IDENTITÀ (mai per
# indice) e _g_aff tappa la porta fino a domani. (Fallisce se: la
# rimozione torna per indice o il gate sparisce.)
func _test_gate(t) -> void:
	var s = STRATI.new()
	s._strati = [
		STRATI.riga_demolizione([3, 3], "Ponte", 1),
		STRATI.riga_ricordo([-5, 2], "Momo", "Momo", {"indole": ["timido"]}, "", 2),
	]
	t.ok((s.strato_del_giorno(0) as Dictionary).is_empty(),
			"giorno 0: la terra non parla")
	var giorno_buono := -1
	var riga: Dictionary = {}
	for giorno in range(3, 60):
		var r: Dictionary = s.strato_del_giorno(giorno)
		if not r.is_empty():
			giorno_buono = giorno
			riga = r
			break
	t.ok(giorno_buono > 0, "prima o poi uno strato affiora")
	var prima: int = (s._strati as Array).size()
	s.estratto(riga, giorno_buono)
	t.eq((s._strati as Array).size(), prima - 1, "lo scavo toglie UNA riga")
	for r in s._strati:
		t.ok(str((r as Dictionary).get("tipo", "")) != str(riga.get("tipo", "")) \
				or (r as Dictionary).get("cella", []) != riga.get("cella", []),
				"la riga tolta è proprio quella scavata")
	t.eq(int(s._g_aff), giorno_buono, "il giorno dello scavo resta segnato")
	t.ok((s.strato_del_giorno(giorno_buono) as Dictionary).is_empty(),
			"oggi non affiora più niente: «ogni tanto» resta vero")
	s.free()
	# per IDENTITÀ, non «la prima qualunque»: si estrae la SECONDA riga
	var s2 = STRATI.new()
	var x := STRATI.riga_demolizione([2, 2], "Ponte", 1)
	var y := STRATI.riga_demolizione([4, 4], "Sedia", 1)
	s2._strati = [x, y]
	s2.estratto(y.duplicate(true), 5)
	var resti: Array = s2._strati
	t.eq(resti.size(), 1, "una riga sola se ne va")
	t.eq(str((resti[0] as Dictionary).get("pezzo", "")), "Ponte",
			"esce la riga GIUSTA (identità), non la prima dell'array")
	s2.free()


# I tre scrittori a nodo spento (headless, nessun DayNight): il giorno
# vale 0 e nessuno seppellisce — silenzio, non crash.
func _test_scrittori_muti(t) -> void:
	var s = STRATI.new()
	s.su_demolizione(0, Vector2i(2, 2), null, 0)
	s.su_partenza("Momo", "Momo", [1, 2], {}, "")
	s.su_partenza("", "Momo", [1, 2], {}, "cucina")
	s._su_stagione(0)
	t.eq((s._strati as Array).size(), 0,
			"senza un giorno vero nessuno scrive sulla terra")
	var stato: Dictionary = s.debug_state()
	t.eq(int(stato.get("strati", -1)), 0, "debug_state conta gli strati")
	t.eq(int(stato.get("g_aff", 0)), -1, "debug_state espone il gate")
	s.free()


# ------------------------------------------------------------- le partenze
# Il cablaggio delle partenze (Visitors._congeda e parte_per_il_grande_
# prato → _seppellisci_ricordo → Strati.su_partenza), provato dal lato che
# si tiene in mano headless: su_partenza coi dati ESATTAMENTE nella forma
# in cui Visitors li passa — il NOME del dna come chiave, la label solo
# display, la casa [x, z] dalla Vector2i, il mestiere letto PRIMA che
# l'ultima riga di _congeda lo azzeri. Un DayNight finto dà il giorno:
# senza, lo scrittore è muto per regola (già provato in _scrittori_muti).
# (Fallisce se: la riga porta la label al posto del nome, il mestiere
# arriva già azzerato, o due addii nello stesso giorno si sovrappongono.)

## _daynight è tipizzato Node3D e _oggi() legge la proprietà "day": serve
## uno stub VERO generato al volo (un set_meta non basterebbe). Chi lo
## riceve lo deve liberare: è un Node3D, non un RefCounted.
func _test_partenze_daynight_finto(giorno: int) -> Node3D:
	var sorgente := GDScript.new()
	sorgente.source_code = "extends Node3D\nvar day := %d\n" % giorno
	sorgente.reload()
	var dn = sorgente.new()
	return dn


func _test_partenze_nome_giusto(t) -> void:
	var dn = _test_partenze_daynight_finto(5)
	var s = STRATI.new()
	s._daynight = dn
	# la forma di Visitors: nome dal dna, label di display, casa [x, z]
	var dna := {"name": "Nocciola", "quirk": "colleziona_sassolini",
			"indole": ["goloso"], "fur": "f7e6d0"}
	var casa := [-10, 5]
	s.su_partenza("Nocciola", "Nocciola la sarta", casa, dna, "cucina")
	var righe: Array = s._strati
	t.eq(righe.size(), 1, "la partenza seppellisce UNO strato")
	var riga: Dictionary = righe[0]
	t.eq(str(riga.get("tipo", "")), "ricordo", "lo strato è un ricordo")
	t.eq(str(riga.get("nome", "")), "Nocciola",
			"la chiave è il NOME del dna, MAI la label (le due anagrafi)")
	t.eq(str(riga.get("label", "")), "Nocciola la sarta",
			"la label resta accanto, solo per il toast del ritrovamento")
	t.eq(str(riga.get("oggetto", "")), "sassolino_lucido",
			"l'oggetto viene dal carattere (qui il quirk vince)")
	t.eq(int(riga.get("g", 0)), 5, "il giorno di sepoltura è quello del DayNight")
	var cella: Array = riga.get("cella", [])
	t.ok(STRATI.valida_cella(cella, []), "la cella è prato seppellibile")
	t.ok(cella != casa, "mai il letto: la casa resta la casa")
	t.ok(cella != [casa[0] + 1, casa[1] + 1],
			"mai il fiore-memoriale (+1,+1): il reperto non va sotto i petali")
	var dist: int = maxi(absi(int(cella[0]) - casa[0]), absi(int(cella[1]) - casa[1]))
	t.ok(dist >= 1 and dist <= STRATI.RAGGIO_SEPOLTURA,
			"«vicino a casa sua»: dentro gli anelli 1..%d" % STRATI.RAGGIO_SEPOLTURA)
	# due addii lo stesso giorno, stessa casa: il secondo non si
	# sovrappone al primo (il dedupe per cella del giorno in su_partenza)
	s.su_partenza("Biscotto", "Biscotto", casa, {"indole": ["timido"]}, "")
	righe = s._strati
	t.eq(righe.size(), 2, "anche il secondo partito lascia il suo strato")
	t.ok((righe[0] as Dictionary).get("cella", []) != \
			(righe[1] as Dictionary).get("cella", []),
			"due ricordi lo stesso giorno: due celle diverse")
	# il MESTIERE arriva come parametro, letto prima dell'azzeramento: se
	# il cablaggio lo leggesse DOPO (la trappola dell'ultima riga di
	# _congeda) qui uscirebbe il barattolino dell'indole, non la lanterna
	s.su_partenza("Luna", "Luna che veglia", casa, {"indole": ["goloso"]}, "guardia")
	righe = s._strati
	t.eq(str((righe[2] as Dictionary).get("oggetto", "")), "lanternina_spenta",
			"il mestiere passato dal chiamante conta ancora")
	# il seme della sepoltura è il nome: su un'altra istanza (il reload)
	# lo stesso addio sceglie la stessa cella
	var s2 = STRATI.new()
	s2._daynight = dn
	s2.su_partenza("Nocciola", "Nocciola la sarta", casa, dna, "cucina")
	t.ok(((s2._strati as Array)[0] as Dictionary).get("cella", []) == cella,
			"stesso nome, giorno e casa: stessa cella (deterministico)")
	s2.free()
	s.free()
	dn.free()


# ------------------------------------------- il cablaggio del verbo (Scavi)
# Append del cablatore di Scavi: il luccichio nato su uno strato deve
# consegnare il reperto GIUSTO (tabelle chiuse, routing, modellino tinto),
# e un reperto scavato non deve tornare — né oggi, né al reload.

const SCAVI := preload("res://scenes/interact/Scavi.gd")


# Il reperto giusto: ogni oggetto che Strati può seppellire ha la sua
# frase in Scavi, il routing tipo→tesoro è quello del progetto, e il
# modellino del ricordo è TINTO col pelo di chi è partito. (Fallisce se:
# un oggetto nuovo resta senza frase — il toast direbbe il ripiego
# anonimo —, il routing devia, o la tinta si perde per strada.)
func _test_scavi_reperto_giusto(t) -> void:
	var oggetti := {}
	for v in STRATI.OGGETTI_QUIRK.values():
		oggetti[str(v)] = true
	for v in STRATI.OGGETTI_MESTIERE.values():
		oggetti[str(v)] = true
	for v in STRATI.OGGETTI_INDOLE.values():
		oggetti[str(v)] = true
	oggetti[str(STRATI.OGGETTO_FALLBACK)] = true
	for oggetto in oggetti.keys():
		t.ok(SCAVI.TESTO_OGGETTO.has(oggetto),
				"l'oggetto «%s» ha la sua frase nel toast" % oggetto)
	for fr in SCAVI.TESTO_OGGETTO.values():
		t.ok(str((fr as Dictionary).get("k", "")) != "",
				"ogni frase di reperto ha la chiave «k» (il guardiano L10n)")
	for segno in STRATI.SEGNI_STAGIONE.values():
		t.ok(SCAVI.TESTO_SEGNO.has(str(segno)),
				"il segno «%s» ha la sua frase nel toast" % str(segno))
	# il routing: il trovamento È il reperto — l'id delle Tasche per tipo
	var demo := STRATI.riga_demolizione([3, 3], "Ponte", 1)
	t.eq(SCAVI.tesoro_del_reperto(demo), "scheggia_di_casa",
			"una demolizione consegna la scheggia")
	var ricordo := STRATI.riga_ricordo([2, 2], "Momo", "Momo",
			{"quirk": "colleziona_sassolini", "fur": "f7e6d0"}, "", 4)
	t.eq(SCAVI.tesoro_del_reperto(ricordo), "sassolino_lucido",
			"un ricordo consegna l'oggetto del carattere")
	var stagione := {"tipo": "stagione", "cella": [0, -8], "g": 8,
			"segno": "foglia_d_oro"}
	t.eq(SCAVI.tesoro_del_reperto(stagione), "foglia_d_oro",
			"una stagione consegna il suo segno")
	t.eq(SCAVI.tesoro_del_reperto({}), "",
			"uno strato ignoto non consegna niente")
	# il modellino si costruisce per ogni tipo (senza albero: come in gioco
	# prima di add_child), e la sferetta del ricordo porta il pelo
	var scavi = SCAVI.new()
	for strato in [demo, ricordo, stagione]:
		var n = scavi._fai_reperto(strato)
		t.ok(n != null and n.get_child_count() > 0,
				"il modellino «%s» si costruisce" % str((strato as Dictionary)["tipo"]))
		n.free()
	var tinto = scavi._fai_reperto(ricordo)
	var mi = tinto.get_child(0)
	var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
	var tinta: Array = ricordo["tinta"]
	t.almost(col.r, float(tinta[0]), "la sferetta del ricordo ha il pelo: rosso", 0.01)
	t.almost(col.g, float(tinta[1]), "la sferetta del ricordo ha il pelo: verde", 0.01)
	t.almost(col.b, float(tinta[2]), "la sferetta del ricordo ha il pelo: blu", 0.01)
	tinto.free()
	scavi.free()


# Il reperto scavato non torna: _scava chiama estratto() SUBITO (prima
# dell'animazione), quindi la riga è fuori dal ledger anche se si salva a
# metà scavata. (Fallisce se: il gate _g_aff sparisce, la rimozione perde
# l'identità, o il gate non viaggia col salvataggio.)
func _test_scavi_reperto_scavato_non_torna(t) -> void:
	var s = STRATI.new()
	s._strati = [STRATI.riga_ricordo([-10, 5], "Momo", "Momo",
			{"indole": ["timido"]}, "", 1)]
	var giorno := -1
	var riga: Dictionary = {}
	for g in range(2, 120):
		var r: Dictionary = s.strato_del_giorno(g)
		if not r.is_empty():
			giorno = g
			riga = r
			break
	t.ok(giorno > 0, "prima o poi il ricordo affiora")
	s.estratto(riga, giorno)
	t.ok((s.strato_del_giorno(giorno) as Dictionary).is_empty(),
			"scavato: oggi la terra tace")
	t.eq((s._strati as Array).size(), 0, "la riga è uscita dal ledger")
	# il salvataggio a metà scavata: al reload il luccichio non rispunta
	var s2 = STRATI.new()
	s2.load_extra(JSON.parse_string(JSON.stringify(s.save_extra())))
	t.ok((s2.strato_del_giorno(giorno) as Dictionary).is_empty(),
			"al reload di oggi niente doppione: il gate viaggia col save")
	var mai := true
	for g in range(giorno + 1, giorno + 60):
		if not (s2.strato_del_giorno(g) as Dictionary).is_empty():
			mai = false
	t.ok(mai, "nei giorni dopo il reperto scavato non torna mai")
	s2.free()
	s.free()


# --------------------------------------- il cablaggio della demolizione
# Append del cablatore della demolizione: _try_remove (il gesto del
# GIOCATORE) deve seppellire uno strato; l'harness (debug_clear,
# debug_remove_edge) e i caricamenti (_loading) NO. Comportamentale: il
# BuildSystem VERO in scena, pezzi posati davvero e demoliti dal percorso
# vero — un source-check resterebbe verde anche a codice cancellato.


## Il BuildSystem vero con UNA sola cosa spenta: il caricamento del
## villaggio del giocatore (l'idioma del Cantiere di test_siti_gesto:
## `_ready` accoda `_load_village` differito senza guardare `_persist`,
## quindi la porta si chiude qui). Le SCRITTURE le spegne
## set_persist_for_debug(false) appena montato.
class DemolizioneCantiere extends "res://scenes/build/BuildSystem.gd":
	func _ready() -> void:
		super()
		set_process(false)
		set_physics_process(false)

	func _load_village() -> void:
		pass


## A Strati basta un nodo con `day` (Node3D: il campo _daynight è
## tipizzato, e un tipo sbagliato non assegna e non dice niente). Senza
## un giorno > 0 gli scrittori tacciono per regola (_scrittori_muti).
class DemolizioneGiorno extends Node3D:
	var day := 5


## Monta il cantiere: BuildSystem vero + Strati vero IN SCENA (il gruppo
## "strati" si vede solo dall'albero), giorno 5. Prima si sgomberano i
## gruppi dei casi montati in questo stesso frame (l'idioma di
## test_insieme): get_first_node_in_group prenderebbe il più vecchio.
func _test_demolizione_scena(t) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("strati"):
		(vecchio as Node).remove_from_group("strati")
	for vecchio2 in t.tree().get_nodes_in_group("build_system"):
		(vecchio2 as Node).remove_from_group("build_system")
	var cantiere = t.stage(DemolizioneCantiere.new())
	cantiere.call("set_persist_for_debug", false)
	var strati = t.stage(STRATI.new())
	strati.set("_daynight", t.stage(DemolizioneGiorno.new()))
	return {"cantiere": cantiere, "strati": strati}


## Il gesto del giocatore seppellisce; sotto _loading no. (Fallisce se:
## l'hook sparisce da _try_remove, smette di rispettare _loading, o passa
## a su_demolizione una cella o un pezzo sbagliati.)
func _test_demolizione_giocatore(t) -> void:
	var scena := _test_demolizione_scena(t)
	var cantiere = scena["cantiere"]
	var strati = scena["strati"]
	var cella := Vector2i(2, -3)   # dentro SCAVI.RECT: prato seppellibile
	cantiere.call("place_cell", cella, "Sedia", 0, false, 0)
	t.eq((cantiere.call("get_placed_by_name", "Sedia") as Array).size(), 1,
			"premessa: la Sedia è stata posata davvero")
	cantiere.set("_level", 0)
	cantiere.set("_hover_cell", cella)
	cantiere.call("_try_remove")
	t.eq((cantiere.call("get_placed_by_name", "Sedia") as Array).size(), 0,
			"la demolizione è avvenuta davvero (non si prova il silenzio)")
	var righe: Array = strati._strati
	t.eq(righe.size(), 1, "il gesto del giocatore seppellisce UNO strato")
	if righe.size() == 1:
		var riga: Dictionary = righe[0]
		t.eq(str(riga.get("tipo", "")), "demolizione", "lo strato è una demolizione")
		t.eq(str(riga.get("pezzo", "")), "Sedia", "lo strato ricorda il pezzo")
		t.ok(riga.get("cella", []) == [2, -3],
				"la cella è quella demolita, in forma [x, z]")
		t.eq(int(riga.get("g", 0)), 5, "il giorno di sepoltura è oggi")
	# sotto caricamento l'hook tace: _try_remove è input e sotto load non
	# arriva mai, ma se un giorno arrivasse non deve lasciare reperti
	cantiere.call("place_cell", Vector2i(4, -5), "Sgabello", 0, false, 0)
	cantiere.set("_loading", true)
	cantiere.set("_hover_cell", Vector2i(4, -5))
	cantiere.call("_try_remove")
	t.eq((strati._strati as Array).size(), 1,
			"sotto _loading nessuno strato nuovo")
	cantiere.set("_loading", false)
	# controprova: lo stesso gesto fuori dal caricamento seppellisce —
	# quindi a tacere era la guardia, non un'altra valvola
	cantiere.call("place_cell", Vector2i(4, -5), "Sgabello", 0, false, 0)
	cantiere.set("_hover_cell", Vector2i(4, -5))
	cantiere.call("_try_remove")
	var dopo: Array = strati._strati
	t.eq(dopo.size(), 2, "fuori dal caricamento lo Sgabello scende sotto terra")
	if dopo.size() == 2:
		t.eq(str((dopo[1] as Dictionary).get("pezzo", "")), "Sgabello",
				"…ed è proprio lui")
	# IL BORDO: la chiave di un edge è RADDOPPIATA (la staccionata vive a
	# metà fra due celle) e su_demolizione la dimezza col roundi — la
	# scheggia cade nella cella accanto. Va provato dal percorso VERO
	# (_find_removable → ramo "edge"): se il *0.5 sparisse, la scheggia
	# cadrebbe a (2x, 2z) — quasi sempre fuori da SCAVI.RECT → valida_cella
	# false → NESSUNA sepoltura, in silenzio, a suite verde.
	cantiere.call("place_edge", Vector2i(4, -5), "Staccionata", false, false, 0)
	# il bordo lo trova il MOUSE (non _hover_cell): lo si posa sul punto
	# medio della staccionata (2, -2.5), e _hover_cell va su una cella
	# vuota così a parlare è il ramo "edge" e non un layer pieno.
	cantiere.set("_hover_cell", Vector2i(9, 9))
	cantiere.set("_mouse_world", Vector3(2.0, 0.0, -2.5))
	cantiere.call("_try_remove")
	var con_bordo: Array = strati._strati
	t.eq(con_bordo.size(), 3, "anche la staccionata demolita seppellisce")
	if con_bordo.size() == 3:
		var bordo: Dictionary = con_bordo[2]
		t.eq(str(bordo.get("tipo", "")), "demolizione",
				"il bordo sepolto è una demolizione")
		t.eq(str(bordo.get("pezzo", "")), "Staccionata", "…e ricorda il pezzo")
		t.ok(bordo.get("cella", []) == [2, -3],
				"la chiave raddoppiata (4, -5) si dimezza: la scheggia sta in [2, -3]")


## L'harness NON è il giocatore: debug_clear e debug_remove_edge passano
## da _remove_at diretto e la terra resta a ZERO strati. (Fallisce se:
## qualcuno sposta l'hook della Stratigrafia dentro _remove_at, dove
## scatterebbe anche per la CLI e per i caricamenti.)
func _test_demolizione_harness_muta(t) -> void:
	var scena := _test_demolizione_scena(t)
	var cantiere = scena["cantiere"]
	var strati = scena["strati"]
	cantiere.call("place_cell", Vector2i(2, -3), "Sedia", 0, false, 0)
	cantiere.call("place_cell", Vector2i(0, -6), "Panchina", 0, false, 0)
	cantiere.call("place_edge", Vector2i(1, 0), "Staccionata", false, false, 0)
	t.eq(int(cantiere.call("piece_count")), 3, "premessa: tre pezzi in piedi")
	cantiere.call("debug_remove_edge", Vector2i(1, 0), 0)
	t.eq((strati._strati as Array).size(), 0, "debug_remove_edge non seppellisce")
	cantiere.call("debug_clear")
	t.eq(int(cantiere.call("piece_count")), 0,
			"premessa: debug_clear ha spazzato tutto")
	t.eq((strati._strati as Array).size(), 0,
			"debug_clear: ZERO strati — l'harness non è il giocatore")


# --------------------------------------- lo scavo: accredito atomico e toast
# Il gesto VERO di _scava, coi vicini di scena finti che ascoltano: lo
# stato (ledger, Tasche, momento nei Legami) deve muoversi TUTTO nel frame
# dello scavo — l'accredito viveva a fine volo, 1,6 s dopo estratto(), e un
# save_now() dal menu di pausa in quella finestra perdeva il reperto PER
# SEMPRE (il partito non riseppellisce). Il toast invece resta a fine volo,
# e la sua GRAMMATICA si prova con una label vera: le label portano sempre
# l'articolo davanti («il gattino Cannella», ChibiDNA) e un «Era di %s.»
# produceva «Era di il gattino Cannella.» in ogni toast di ricordo.


class ToastVisitors extends Node:
	var toasts: Array = []
	func _show_toast(testo: String) -> void:
		toasts.append(testo)


class ToastTasche extends Node:
	var accrediti: Array = []
	func add_treasure(id: String, n := 1) -> Dictionary:
		accrediti.append([id, n])
		return {"id": id}


class ToastLegami extends Node:
	var momenti: Array = []
	func momento(nome: String, tipo: String, extra := "") -> void:
		momenti.append([nome, tipo, extra])


## Il rig minimo che _scava tocca: crouch (tween), _yaw, hold_reach.
class ToastMochi extends Node3D:
	var crouch := 0.0
	var _yaw := 0.0
	func hold_reach(_su: bool) -> void:
		pass


## (Fallisce se: l'accredito torna a fine volo — atomicità persa —, la
## consegna riprende ad accreditare — doppione —, o il toast del ricordo
## torna alla preposizione slegata «di il».)
func _test_toast_e_accredito(t) -> void:
	# i gruppi dei sotto-test precedenti di questo stesso caso (il cantiere
	# della demolizione) sono ancora in scena: si sgomberano come sempre
	for vecchio in t.tree().get_nodes_in_group("strati"):
		(vecchio as Node).remove_from_group("strati")
	for vecchio2 in t.tree().get_nodes_in_group("legami"):
		(vecchio2 as Node).remove_from_group("legami")
	var visitors = t.stage(ToastVisitors.new())
	visitors.set_name("Visitors")     # Scavi li cerca come fratelli: ../Visitors
	var tasche = t.stage(ToastTasche.new())
	tasche.set_name("Inventory")
	var legami = t.stage(ToastLegami.new())
	legami.add_to_group("legami")
	var strati = t.stage(STRATI.new())
	var scavi = t.stage(SCAVI.new())
	var player = t.stage(Node3D.new())
	var mochi = t.stage(ToastMochi.new())
	scavi.set("_player", player)
	scavi.set("_mochi", mochi)
	scavi.set("_giorno", 6)
	var riga := STRATI.riga_ricordo([-10, 5], "Cannella", "il gattino Cannella",
			{"quirk": "colleziona_sassolini", "fur": "f7e6d0"}, "", 5)
	strati._strati = [riga.duplicate(true)]
	var luccichio = t.stage(Node3D.new())
	(scavi._spots as Array).append({"i": -1, "pos": Vector3(-10, 0, 5),
			"node": luccichio, "strato": riga.duplicate(true)})
	scavi._scava(0)
	# L'ATOMICITÀ: ledger, Tasche e Legami si muovono nello STESSO frame
	# dello scavo — nessun await, nessun frame in mezzo.
	t.eq((strati._strati as Array).size(), 0,
			"nel frame dello scavo la riga è già fuori dal ledger")
	t.eq(int(strati._g_aff), 6, "…e il gate del giorno è già chiuso")
	var accrediti: Array = tasche.accrediti
	t.eq(accrediti.size(), 1, "nel frame dello scavo il tesoro è già in tasca")
	if accrediti.size() == 1:
		t.eq(str((accrediti[0] as Array)[0]), "sassolino_lucido",
				"…ed è l'oggetto del carattere")
	var momenti: Array = legami.momenti
	t.eq(momenti.size(), 1, "nel frame dello scavo il momento è già annodato")
	if momenti.size() == 1:
		t.ok(momenti[0] == ["Cannella", "reperto", "sassolino_lucido"],
				"…sul NOME del dna, tipo reperto, con l'oggetto in mano")
	t.eq((visitors.toasts as Array).size(), 0,
			"il toast invece aspetta il volo: qui non ha ancora parlato")
	# LA CONSEGNA a fine volo: solo scena. Qui la si chiama diretta (il
	# volo è un tween, e nel runner non gira nessun frame).
	scavi._consegna_reperto(riga)
	var toasts: Array = visitors.toasts
	t.eq(toasts.size(), 1, "a fine volo il reperto parla con UN toast")
	var toast := str(toasts[0]) if toasts.size() == 1 else ""
	t.eq(toast, "Sotto terra: un sassolino lucido, scelto fra mille. " +
			"Un pensiero che il gattino Cannella ha lasciato qui.",
			"il toast nomina il partito con la label DA SOGGETTO")
	for rotto in ["di il ", "di lo ", "di la ", "di l'", "di i ", "di gli ", "di le "]:
		t.ok(not (str(rotto) in toast),
				"niente preposizione slegata «%s» nel toast" % str(rotto))
	t.eq((tasche.accrediti as Array).size(), 1,
			"la consegna non accredita una seconda volta: lo stato vive in _accredita_reperto")
	t.eq((legami.momenti as Array).size(), 1,
			"…e non annoda un secondo momento")
	# senza label (schifezze di un salvataggio vecchio): la frase regge da sola
	var anonimo := riga.duplicate(true)
	anonimo["label"] = ""
	scavi._consegna_reperto(anonimo)
	t.eq(str((visitors.toasts as Array)[1]),
			"Sotto terra: un sassolino lucido, scelto fra mille.",
			"senza label la frase sta in piedi senza attribuzione")
# IL PONTE INGLESE DEI REPERTI. Il guardiano dei letterali
# (test_localizzazione) vede le frasi nel campo "k" di Scavi.TESTO_OGGETTO
# e pretende la riga inglese; ma NESSUNO controlla che ogni oggetto che il
# carattere può produrre ABBIA la sua frase (un id senza frase scivola nel
# fallback anonimo «un piccolo ricordo», a suite verde), né che le schede
# TREASURES (name/src/desc — L10n.t su variabile, invisibili al guardiano)
# siano tradotte. Le costanti si leggono da get_script_constant_map(): mai
# un riferimento di parse a ciò che un altro cablatore non ha ancora
# posato — quando le tabelle mancano il giro tace, appena atterrano morde.
# (Fallisce se: un oggetto/segno nuovo resta senza frase, una frase resta
# senza inglese, o una scheda delle Tasche esce in italiano nella EN.)
func _test_lingua_reperti(t) -> void:
	# la tabella inglese, piatta (tutte e quattro le parti)
	var l10n = load("res://systems/L10n.gd")
	var en := {}
	for parte in l10n.TABELLE.get("en", []):
		for chiave in parte.tabella():
			en[str(chiave)] = true
	t.ok(en.size() > 0, "la tabella inglese si carica")

	# tutti gli id che Strati può far riaffiorare
	var oggetti := {}
	for tab in [STRATI.OGGETTI_QUIRK, STRATI.OGGETTI_MESTIERE, STRATI.OGGETTI_INDOLE]:
		for k in (tab as Dictionary):
			oggetti[str((tab as Dictionary)[k])] = true
	oggetti[str(STRATI.OGGETTO_FALLBACK)] = true
	var segni := {}
	for s in STRATI.SEGNI_STAGIONE:
		segni[str(STRATI.SEGNI_STAGIONE[s])] = true

	# ogni oggetto ha la sua frase, e la frase la sua riga inglese
	var scavi_cost: Dictionary = \
			(load("res://scenes/interact/Scavi.gd") as Script).get_script_constant_map()
	if scavi_cost.has("TESTO_OGGETTO"):
		var testo: Dictionary = scavi_cost["TESTO_OGGETTO"]
		for oggetto in oggetti:
			var fr: Dictionary = testo.get(oggetto, {})
			t.ok(fr.has("k"),
					"«%s» ha la sua frase in Scavi.TESTO_OGGETTO" % oggetto)
			t.ok(en.has(str(fr.get("k", ""))),
					"la frase di «%s» ha la sua riga inglese" % oggetto)
	if scavi_cost.has("TESTO_SEGNO"):
		var testo_s: Dictionary = scavi_cost["TESTO_SEGNO"]
		for segno in segni:
			var fs: Dictionary = testo_s.get(segno, {})
			t.ok(fs.has("k"),
					"il segno «%s» ha la sua frase in Scavi.TESTO_SEGNO" % segno)
			t.ok(en.has(str(fs.get("k", ""))),
					"la frase del segno «%s» ha la sua riga inglese" % segno)

	# le schede delle Tasche degli id della Stratigrafia: OGNI id che
	# Strati può far riaffiorare DEVE avere la sua scheda in TREASURES
	# (il cross-check del progetto, §5.1.1: senza scheda add_treasure è
	# un no-op e il reperto è un tesoro fantasma — a suite verde), e la
	# scheda deve avere name/src/desc tradotti. Finché le schede erano di
	# un altro cablatore questo giro le saltava; ora sono atterrate e la
	# porta è CHIUSA: un oggetto nuovo senza scheda è rosso.
	var treas: Dictionary = (load("res://scenes/ui/Inventory.gd") as Script) \
			.get_script_constant_map().get("TREASURES", {})
	var tutti: Array = oggetti.keys() + segni.keys() + ["scheggia_di_casa"]
	for id in tutti:
		t.ok(treas.has(id),
				"l'id «%s» ha la sua scheda in Inventory.TREASURES" % id)
		if not treas.has(id):
			continue
		var scheda: Dictionary = treas[id]
		t.eq(str(scheda.get("icon", "")), "reperto",
				"la scheda di «%s» porta l'icona del piccolo involto" % id)
		for campo in ["name", "src", "desc"]:
			var v := str(scheda.get(campo, ""))
			t.ok(v != "" and en.has(v),
					"la scheda di «%s» ha il campo %s tradotto" % [id, campo])
