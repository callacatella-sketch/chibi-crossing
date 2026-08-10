extends RefCounted
## I VARCHI: la prova che il recinto è un recinto, e la casa non è una
## prigione.
##
## Tutto qui dentro è statico e puro: nessun nodo, nessun albero della
## scena, nessun salvataggio. È lo stesso banco su cui girano `gruppo_serra`
## e `rinfresca_pali` — un dizionario finto e una funzione che non sa da
## dove viene.

const VARCHI := preload("res://scenes/build/Varchi.gd")
const CATALOG := preload("res://scenes/build/BuildCatalog.gd")
const BUILD := preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_la_luce(t)
	_il_catalogo_vero(t)
	_il_bordo_fra(t)
	_il_prato_aperto(t)
	_il_recinto(t)
	_la_casa_non_e_una_prigione(t)
	_lo_spigolo(t)
	_la_rotta_gira_attorno(t)
	_il_filo_non_buca(t)
	_la_resa(t)


# ------------------------------------------------------------ la luce

## La regola in sé, su scatole inventate: mezzo metro di luce e si passa.
func _la_luce(t) -> void:
	t.almost(VARCHI.luce([]), 1.0, "senza collisioni il bordo è tutto aperto", 1e-9)

	var muro := [[Vector3(1.0, 2.1, 0.14), Vector3(0, 1.05, 0)]]
	t.almost(VARCHI.luce(muro), 0.0, "una lastra piena non lascia niente", 1e-9)
	t.ok(not VARCHI.e_varco(muro), "e quindi non è un varco")

	var porta := [
		[Vector3(0.16, 2.1, 0.14), Vector3(-0.42, 1.05, 0)],
		[Vector3(0.16, 2.1, 0.14), Vector3(0.42, 1.05, 0)],
	]
	t.almost(VARCHI.luce(porta), 0.68, "due stipiti lasciano la porta in mezzo", 1e-6)
	t.ok(VARCHI.e_varco(porta), "e ci si passa")

	# LA SOGLIA: una vetrina ha un gradino basso, e un gradino si scavalca
	var soglia := [[Vector3(1.0, 0.15, 0.38), Vector3(0, 0.07, 0)]]
	t.almost(VARCHI.luce(soglia), 1.0, "un gradino sotto i 20 cm non è un muro", 1e-9)
	# e una tenda che passa sopra la testa nemmeno
	var tenda := [[Vector3(1.0, 0.4, 0.5), Vector3(0, 1.6, 0)]]
	t.almost(VARCHI.luce(tenda), 1.0, "e una tenda alta nemmeno", 1e-9)
	# ma qualcosa all'altezza del petto sì, anche se sotto è vuoto
	var mensola := [[Vector3(0.98, 1.0, 0.24), Vector3(0, 0.9, 0)]]
	t.ok(not VARCHI.e_varco(mensola), "una mensola all'altezza del petto sbarra")

	# UNA FESSURA NON È UNA PORTA: 0.4 m fra due stipiti larghi
	var fessura := [
		[Vector3(0.3, 2.0, 0.2), Vector3(-0.35, 1.0, 0)],
		[Vector3(0.3, 2.0, 0.2), Vector3(0.35, 1.0, 0)],
	]
	t.almost(VARCHI.luce(fessura), 0.4, "la fessura è larga 40 cm", 1e-6)
	t.ok(not VARCHI.e_varco(fessura), "e 40 cm non bastano")

	# LO SPECCHIO: ribaltare il pezzo non cambia se ci si passa
	var storto := [[Vector3(0.3, 2.0, 0.2), Vector3(-0.35, 1.0, 0)]]
	var storto_flip := [[Vector3(0.3, 2.0, 0.2), Vector3(0.35, 1.0, 0)]]
	t.almost(VARCHI.luce(storto), VARCHI.luce(storto_flip),
			"la luce è la stessa a destra e a sinistra", 1e-9)

	# L'INCLINAZIONE alza l'ingombro: una lastra sottile messa di piatto
	# in alto, se la si corica, scende nella fascia di cammino
	var piatta := [[Vector3(1.0, 0.1, 1.2), Vector3(0, 0.95, 0)]]
	t.ok(VARCHI.e_varco(piatta), "di piatto a 95 cm ci si passa sotto")
	var coricata := [[Vector3(1.0, 0.1, 1.2), Vector3(0, 0.95, 0), PI * 0.5]]
	t.ok(not VARCHI.e_varco(coricata), "coricata, la stessa lastra sbarra")


## E LO STESSO GIUDIZIO SUL CATALOGO VERO. Non c'è una tabella da tenere
## allineata: la risposta viene dalle `cols`, cioè da dove il pezzo pianta
## davvero i piedi. Qui si fissano solo i quattro casi da cui dipende tutto
## il resto del gioco — più l'invariante che vale per ognuno.
func _il_catalogo_vero(t) -> void:
	var per_nome := {}
	var quanti_bordi := 0
	for it in CATALOG.items():
		if str(it.get("type", "")) != "edge":
			continue
		quanti_bordi += 1
		per_nome[str(it["name"])] = it["cols"] as Array
	t.ok(quanti_bordi >= 20, "il catalogo ha i suoi pezzi di bordo (%d)" % quanti_bordi)

	for nome in per_nome:
		var l: float = VARCHI.luce(per_nome[nome])
		t.ok(l >= -1e-9 and l <= 1.0 + 1e-9,
				"«%s» ha una luce dentro il metro del bordo (%.3f)" % [nome, l])
		t.eq(VARCHI.e_varco(per_nome[nome]), l >= VARCHI.VARCO_MIN,
				"«%s»: varco e luce dicono la stessa cosa" % nome)

	# I QUATTRO CHE REGGONO LA FASE
	t.ok(per_nome.has("Porta") and VARCHI.e_varco(per_nome["Porta"]),
			"dalla Porta si passa — altrimenti ogni casa sarebbe una cella")
	t.ok(per_nome.has("Portale") and VARCHI.e_varco(per_nome["Portale"]),
			"e dal Portale della chiesa pure")
	t.ok(per_nome.has("Muro") and not VARCHI.e_varco(per_nome["Muro"]),
			"il Muro sbarra")
	t.ok(per_nome.has("Staccionata") and not VARCHI.e_varco(per_nome["Staccionata"]),
			"e la Staccionata sbarra: è il pezzo con cui si chiude il recinto")


# ------------------------------------------------------------ il grafo

func _il_bordo_fra(t) -> void:
	var a := Vector2i(3, -2)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var b: Vector2i = a + d
		var k: Vector2i = VARCHI.bordo_fra(a, b)
		t.eq(VARCHI.bordo_fra(b, a), k, "il bordo fra due celle è uno solo (%s)" % d)
		# e combacia con la chiave che BuildSystem usa davvero: il passo di
		# un bordo dice per quale asse corre
		var passo: Vector2i = BUILD.passo_bordo(k)
		var atteso := Vector2i(2, 0) if d.y != 0 else Vector2i(0, 2)
		t.eq(passo, atteso, "e corre lungo l'asse giusto (%s)" % d)


func _il_prato_aperto(t) -> void:
	var mappa: Dictionary = VARCHI.componenti({})
	t.eq(int(mappa["isole"]), 0, "senza muri non c'è nessuna isola")
	t.ok((mappa["celle"] as Dictionary).is_empty(), "e nessuna cella da ricordare")
	t.ok(VARCHI.raggiungibile(mappa, Vector2i(-40, 12), Vector2i(90, -7)),
			"su un prato senza muri ci si arriva ovunque")


## IL RECINTO: la scena della Fase 3. Un quadrato di staccionate attorno
## alla cella (0,0), e quella cella smette di essere del mondo.
func _il_recinto(t) -> void:
	var muri := _recinto(Vector2i(0, 0))
	t.eq(muri.size(), 4, "quattro segmenti chiudono una cella")
	var mappa: Dictionary = VARCHI.componenti(muri)
	t.eq(int(mappa["isole"]), 1, "e nasce un'isola")
	t.ok(VARCHI.isola(mappa, Vector2i(0, 0)) != 0, "dentro non è più il fuori")
	t.eq(VARCHI.isola(mappa, Vector2i(5, 5)), 0, "fuori è il fuori")
	t.ok(not VARCHI.raggiungibile(mappa, Vector2i(5, 5), Vector2i(0, 0)),
			"e da fuori NON si arriva dentro: È LA SCENA DELLA FASE 3")
	t.ok(VARCHI.rotta(muri, Vector2i(5, 5), Vector2i(0, 0)).is_empty(),
			"e infatti non esiste nessuna strada")

	# TOLTO UN SEGMENTO, il recinto è di nuovo un pezzo di prato
	var aperto := muri.duplicate()
	aperto.erase(aperto.keys()[0])
	var m2: Dictionary = VARCHI.componenti(aperto)
	t.eq(int(m2["isole"]), 0, "tolto un segmento non resta nessuna isola")
	t.ok(VARCHI.raggiungibile(m2, Vector2i(5, 5), Vector2i(0, 0)),
			"e ci si torna dentro")


## E LA CASA NON È UNA PRIGIONE. Lo stesso quadrato, ma di Muri con una
## Porta: la porta è un varco, quindi non entra fra i muri del grafo, e
## chi ci abita esce di casa la mattina.
func _la_casa_non_e_una_prigione(t) -> void:
	var muri := _recinto(Vector2i(0, 0))
	# la parete a nord è una Porta: si toglie dai muri, com'è la regola
	muri.erase(VARCHI.bordo_fra(Vector2i(0, 0), Vector2i(0, -1)))
	var mappa: Dictionary = VARCHI.componenti(muri)
	t.eq(int(mappa["isole"]), 0, "una stanza con la porta non è un'isola")
	t.ok(VARCHI.raggiungibile(mappa, Vector2i(0, 0), Vector2i(9, 9)),
			"e da dentro si esce")
	var strada: Array = VARCHI.rotta(muri, Vector2i(0, 0), Vector2i(0, -3))
	t.eq(strada.size(), 4, "e la strada esce dalla porta, dritta")


## LO SPIGOLO. Due staccionate che si toccano d'angolo non si attraversano
## in diagonale: se la BFS lo permettesse, ogni recinto avrebbe quattro
## buchi invisibili agli angoli.
func _lo_spigolo(t) -> void:
	var muri := _recinto(Vector2i(0, 0))
	var mappa: Dictionary = VARCHI.componenti(muri)
	for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		t.ok(not VARCHI.raggiungibile(mappa, Vector2i(0, 0), d),
				"non si sguscia per lo spigolo %s" % d)


func _la_rotta_gira_attorno(t) -> void:
	# un muro lungo cinque celle, e una sola via: girarci intorno
	var muri := {}
	for x in range(-2, 3):
		muri[VARCHI.bordo_fra(Vector2i(x, 0), Vector2i(x, 1))] = true
	var strada: Array = VARCHI.rotta(muri, Vector2i(0, 0), Vector2i(0, 1))
	t.ok(not strada.is_empty(), "una strada c'è")
	t.ok(strada.size() > 2, "ma non è il passo dritto attraverso il muro (%d tappe)"
			% strada.size())
	t.eq(strada[0], Vector2i(0, 0), "parte da dove si è")
	t.eq(strada[strada.size() - 1], Vector2i(0, 1), "e arriva dove si voleva")
	# e nessuna tappa scavalca un muro
	for i in range(1, strada.size()):
		t.ok(VARCHI.passa(muri, strada[i - 1], strada[i]),
				"la tappa %d non attraversa niente" % i)
	# il giro costa: sette metri invece di uno
	t.almost(VARCHI.lunghezza(strada), 7.0, "e il giro largo costa sette metri", 1e-9)


## IL FILO TIRATO non deve inventare scorciatoie dentro i muri: si tira il
## filo sulla stessa rotta e si ripete la domanda su OGNI segmento.
func _il_filo_non_buca(t) -> void:
	var muri := {}
	for x in range(-2, 3):
		muri[VARCHI.bordo_fra(Vector2i(x, 0), Vector2i(x, 1))] = true
	var strada: Array = VARCHI.rotta(muri, Vector2i(0, 0), Vector2i(0, 1))
	var teso: Array = VARCHI.tira_filo(muri, strada)
	t.ok(teso.size() >= 2, "il filo tiene almeno partenza e arrivo")
	t.ok(teso.size() <= strada.size(), "e non allunga mai la strada")
	t.eq(teso[0], strada[0], "parte da dove si parte")
	t.eq(teso[teso.size() - 1], strada[strada.size() - 1], "e arriva dove si arriva")
	# ogni segmento del filo si percorre davvero: lo si ricontrolla passo
	# passo sul grafo, non sulla fiducia
	for i in range(1, teso.size()):
		var pezzo: Array = VARCHI.rotta(muri, teso[i - 1], teso[i])
		t.ok(not pezzo.is_empty(), "il segmento %d del filo è percorribile" % i)
		# SENZA DEVIAZIONI: la rotta a quattro vicini fra due tappe del filo
		# dev'essere lunga esattamente quanto la distanza di Manhattan. Se un
		# muro si mettesse in mezzo, il giro costerebbe di più — ed è così che
		# si smaschera un filo teso dentro la pietra. (Non si confronta con la
		# linea d'aria: una BFS a quattro vicini non fa mai la diagonale.)
		var passo: Vector2i = teso[i] - teso[i - 1]
		t.almost(VARCHI.lunghezza(pezzo), float(absi(passo.x) + absi(passo.y)),
				"e senza deviazioni: il filo non è teso dentro un muro", 0.001)

	# e su prato aperto il filo si tende del tutto: due tappe, non la scaletta
	var libero: Array = VARCHI.rotta({}, Vector2i(0, 0), Vector2i(4, 4))
	t.eq(libero.size(), 9, "la BFS a quattro vicini fa la scaletta")
	t.eq(VARCHI.tira_filo({}, libero).size(), 2,
			"ma il filo la tira dritta: un vicino non cammina a gradini")


## LA RESA. Un villaggio più grande del tetto non blocca nessuno: si
## rinuncia dichiarando che tutto è raggiungibile, mai il contrario.
func _la_resa(t) -> void:
	var muri := {}
	var lato := 120
	for x in range(-lato, lato):
		muri[VARCHI.bordo_fra(Vector2i(x, -lato), Vector2i(x, -lato + 1))] = true
		muri[VARCHI.bordo_fra(Vector2i(x, lato), Vector2i(x, lato + 1))] = true
	var mappa: Dictionary = VARCHI.componenti(muri)
	t.ok(bool(mappa["troncato"]), "oltre il tetto si dichiara la resa")
	t.eq(int(mappa["isole"]), 0, "e non si inventa nessuna prigione")
	t.ok(VARCHI.raggiungibile(mappa, Vector2i(0, 0), Vector2i(0, 1)),
			"il degrado va sempre verso «nessuno è in trappola»")


func _recinto(c: Vector2i) -> Dictionary:
	var muri := {}
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		muri[VARCHI.bordo_fra(c, c + d)] = true
	return muri
