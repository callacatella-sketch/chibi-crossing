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
	_il_filo_e_esatto(t)
	_lo_spigolo_col_palo(t)
	_il_filo_continuo(t)
	_la_luce_dello_spigolo(t)
	_la_resa(t)
	# --- il MONDO, non solo i muri costruiti -------------------------
	_il_suolo_toglie_la_cella_di_arrivo(t)
	_la_rotta_non_guada(t)
	_il_filo_non_scavalca_lacqua(t)
	_da_dentro_lacqua_si_esce_sempre(t)
	_le_componenti_non_guardano_il_mondo(t)
	# --- la ricerca guidata, e il falò -------------------------------
	_la_strada_e_la_piu_corta(t)
	_la_ricerca_arriva_al_falo(t)


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


## IL FILO È ESATTO, non campionato. `filo_libero` è stato riscritto —
## dai campioni ogni 5 cm all'aritmetica intera — perché sugli SPIGOLI il
## campionamento decideva a caso, e da quando il corpo dei vicini cammina
## su questo filo «a caso» vuol dire che ogni tanto attraversa una
## staccionata. Una riscrittura così non si prova con tre casi scelti a
## mano: si prova con una PROPRIETÀ, ripetuta su muri a caso.
##
## La proprietà è questa: **se il filo dice «libero», allora fra quelle due
## celle non c'è niente da schivare** — cioè la BFS ci arriva in esattamente
## la distanza di Manhattan, senza un passo di troppo. Un filo che
## attraversasse un muro lo direbbe subito: la strada vera costerebbe di
## più, o non ci sarebbe affatto.
func _il_filo_e_esatto(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260810
	var bugie := 0
	var liberi := 0
	var senza_strada := 0
	for giro in 25:
		var muri := {}
		for i in 16:
			var c := Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
			var d: Vector2i = VARCHI.INTORNO[rng.randi() % 4]
			muri[VARCHI.bordo_fra(c, c + d)] = true
		for prova in 120:
			var da := Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
			var a := Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
			if not VARCHI.filo_libero_celle(muri, da, a):
				continue
			liberi += 1
			var strada: Array[Vector2i] = VARCHI.rotta(muri, da, a)
			if strada.is_empty():
				senza_strada += 1
				continue
			var manhattan := float(absi(a.x - da.x) + absi(a.y - da.y))
			if absf(VARCHI.lunghezza(strada) - manhattan) > 0.001:
				bugie += 1
	t.ok(liberi > 800, "il banco è pieno: %d fili dichiarati liberi" % liberi)
	t.eq(senza_strada, 0, "un filo libero ha sempre una strada sotto")
	t.eq(bugie, 0, "e non c'è MAI niente da schivare lungo un filo libero")

	# e su prato aperto è libero sempre, in tutte le direzioni
	var storti := 0
	for prova in 400:
		var da := Vector2i(rng.randi_range(-30, 30), rng.randi_range(-30, 30))
		var a := Vector2i(rng.randi_range(-30, 30), rng.randi_range(-30, 30))
		if not VARCHI.filo_libero_celle({}, da, a):
			storti += 1
	t.eq(storti, 0, "senza muri ogni filo è libero, in qualunque direzione")


## LO SPIGOLO COL PALO. La fine di una staccionata è il punto in cui il
## filo sbagliava: la retta fra le due celle diagonali passa ESATTAMENTE
## per il palo. Nel grafo si poteva dire «ci si passa accanto»; addosso a
## un corpo che cammina in linea retta, «accanto» è dentro.
func _lo_spigolo_col_palo(t) -> void:
	# una staccionata che finisce: bordo fra (0,0) e (0,1), e basta
	var muri := {}
	muri[VARCHI.bordo_fra(Vector2i(0, 0), Vector2i(0, 1))] = true
	t.ok(not VARCHI.filo_libero_celle(muri, Vector2i(0, 0), Vector2i(0, 1)),
			"attraverso la staccionata non si passa")
	t.ok(not VARCHI.filo_libero_celle(muri, Vector2i(0, 0), Vector2i(1, 1)),
			"e nemmeno di sguincio per lo spigolo dove finisce")
	t.ok(not VARCHI.filo_libero_celle(muri, Vector2i(0, 0), Vector2i(-1, 1)),
			"né dall'altro capo")
	# ma appena ci si scosta di una cella, si passa: il filo non diventa
	# una scaletta, si limita a girare largo attorno al palo
	t.ok(VARCHI.filo_libero_celle(muri, Vector2i(0, 0), Vector2i(2, 1)),
			"passata la testata, il filo torna dritto")
	t.ok(VARCHI.filo_libero_celle(muri, Vector2i(1, 0), Vector2i(1, 1)),
			"e di fianco alla staccionata si passa senza storie")


## IL FILO È CONTINUO, e non è la stessa domanda del filo fra celle.
##
## Da quando il corpo cammina sul filo, la domanda vera non è più «fra il
## centro di questa cella e il centro di quella si passa?» — è «fra QUESTO
## punto e QUEL punto si passa?». Sono due domande diverse, e finché
## coincidevano solo sui centri di cella il villaggio giudicava un
## segmento e il corpo ne camminava un altro.
##
## Qui si mostra un caso in cui le due risposte sono OPPOSTE, e in cui
## quella giusta è la continua. Una staccionata sola, sul bordo fra (0,0) e
## (1,0): occupa il segmento x = 0.5 da z = −0.5 a z = +0.5.
func _il_filo_continuo(t) -> void:
	var muri := {}
	muri[VARCHI.bordo_fra(Vector2i(0, 0), Vector2i(1, 0))] = true

	# fra i due CENTRI di cella la diagonale passa esattamente per la
	# testata della staccionata: non si passa, ed è giusto
	t.ok(not VARCHI.filo_libero_celle(muri, Vector2i(0, 0), Vector2i(1, 1)),
			"fra i due centri di cella la diagonale batte sulla testata")

	# ma un corpo che parte venti centimetri più in su fa un segmento che
	# scavalca la staccionata BEN SOPRA la sua testata: la attraversa in un
	# punto in cui la staccionata non c'è. La risposta giusta è «si passa»,
	# e la sa dare solo il filo continuo.
	t.ok(VARCHI.filo_libero(muri, Vector2(0.0, 0.2), Vector2(1.0, 1.2)),
			"ma lo stesso viaggio spostato di 20 cm passa sopra la testata")

	# e il contrario esiste eccome: due punti nelle stesse due celle, ma
	# messi in modo che il segmento tagli la staccionata nel mezzo
	t.ok(not VARCHI.filo_libero(muri, Vector2(0.0, -0.2), Vector2(1.0, 0.2)),
			"e due punti nelle stesse celle, più in basso, ci sbattono contro")

	# la coerenza con la cella: su coordinate intere le due devono dire la
	# stessa identica cosa, o `tira_filo` e il corpo divergono di nuovo
	var storti := 0
	for x in range(-3, 4):
		for z in range(-3, 4):
			var a := Vector2i(x, z)
			for x2 in range(-3, 4):
				for z2 in range(-3, 4):
					var b := Vector2i(x2, z2)
					if VARCHI.filo_libero_celle(muri, a, b) \
							!= VARCHI.filo_libero(muri, Vector2(a), Vector2(b)):
						storti += 1
	t.eq(storti, 0, "sui centri di cella le due domande danno la stessa risposta")


## LA LUCE ATTORNO ALLO SPIGOLO. Un muro non è una retta senza spessore:
## la Staccionata chiude i correnti con una pallina di raggio 3 cm centrata
## ESATTAMENTE sullo spigolo, ad altezze 0.315 e 0.585 — in mezzo alla
## fascia in cui cammina un chibi. Un filo che passasse a due centimetri
## dallo spigolo sarebbe libero sul grafo e dentro il legno sullo schermo.
##
## `SPIGOLO_LUCE` è la fascia entro cui un passaggio conta come «per lo
## spigolo» (e quindi pretende tutti e due i giri aperti). Serve anche a
## una seconda cosa: un filo teso passa per gli spigoli veri per
## costruzione, e in virgola mobile «esattamente sullo spigolo» diventa «a
## 10⁻¹⁶ dallo spigolo», cioè di qua o di là a caso.
func _la_luce_dello_spigolo(t) -> void:
	var muri := {}
	muri[VARCHI.bordo_fra(Vector2i(0, 0), Vector2i(1, 0))] = true
	# un filo che sfiora la testata a due centimetri: NON si passa
	t.ok(not VARCHI.filo_libero(muri, Vector2(0.0, 0.03), Vector2(1.0, 1.03)),
			"a due centimetri dalla testata si passa dentro il legno: no")
	# uno che se ne tiene quaranta: si passa, e il filo resta dritto
	t.ok(VARCHI.filo_libero(muri, Vector2(0.0, 0.42), Vector2(1.0, 1.42)),
			"tenendosene quaranta si passa, e senza fare la scaletta")
	# la fascia non è larga a caso: deve tenere fuori la pallina del
	# corrente (3 cm) anche nel caso peggiore, che è il filo a 45 gradi —
	# dove la distanza vera dallo spigolo è metà della fascia
	t.ok(VARCHI.SPIGOLO_LUCE * 0.5 > 0.03,
			"e la fascia tiene fuori la pallina del corrente anche a 45 gradi")


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


# ====================================================== IL MONDO, NON I MURI
#
# Il grafo dei varchi era fatto dei soli BORDI costruiti, e aveva un buco a
# forma di fiume: `BuildSystem.place_cell` **rifiuta** una cella nel letto,
# quindi lì un muro non ci può essere per costruzione — il letto era il
# corridoio più sgombro della mappa, e la ricerca ci si infilava dentro ogni
# volta che doveva aggirare un recinto vicino alla riva. Misurato nel
# MainLevel vero: tre metri di strada diventavano nove, di cui 2,54 dentro
# l'acqua, con il corpo sospeso quarantacinque centimetri sopra il pelo.
#
# Qui il fiume è finto — una colonna di celle vietate — perché quello che si
# prova è il GRAFO, non la geografia. La geografia ha il suo caso in
# `test_terreno.gd`, e la scena vera `tools/prova_fiume.gd`.

## Un suolo di prova: vietate le celle di un insieme, e basta.
func _suolo(vietate: Array) -> Object:
	var elenco := {}
	for c: Vector2i in vietate:
		elenco[c] = true
	return VARCHI.Suolo.new(func(c: Vector2i) -> bool: return elenco.has(c))


## Una colonna d'acqua verticale, da z0 a z1 sulla colonna x.
func _fiume(x: int, z0: int, z1: int) -> Array:
	var celle: Array = []
	for z in range(z0, z1 + 1):
		celle.append(Vector2i(x, z))
	return celle


## IL SUOLO TOGLIE UNA CELLA, NON UN BORDO — e toglie quella di ARRIVO.
##
## È la differenza che tiene in piedi tutto il resto: i pezzi costruiti
## bloccano un arco del grafo (il bordo fra due celle), il mondo toglie un
## nodo (la cella non ha pavimento). Chi le fondesse dovrebbe inventarsi
## quattro muri attorno a ogni cella d'acqua, e si ritroverebbe un recinto
## chiuso dove c'è solo una riva.
##
## E si guarda solo dove si ARRIVA: da dentro il guado si deve poter
## uscire, sempre. Il degrado va verso «si cammina».
func _il_suolo_toglie_la_cella_di_arrivo(t) -> void:
	var acqua := _suolo([Vector2i(1, 0)])
	t.ok(not VARCHI.passa({}, Vector2i(0, 0), Vector2i(1, 0), acqua),
			"non si entra in una cella senza pavimento")
	t.ok(VARCHI.passa({}, Vector2i(1, 0), Vector2i(2, 0), acqua),
			"ma da dentro l'acqua si esce (la cella di partenza non si guarda)")
	t.ok(VARCHI.passa({}, Vector2i(0, 0), Vector2i(1, 0), null),
			"e senza suolo non cambia niente: si passa come sempre")
	# il bordo resta il bordo: un muro fra due celle asciutte sbarra lo stesso
	var muri := {VARCHI.bordo_fra(Vector2i(0, 0), Vector2i(0, 1)): true}
	t.ok(not VARCHI.passa(muri, Vector2i(0, 0), Vector2i(0, 1), acqua),
			"e le due domande restano due: il muro sbarra anche sull'asciutto")


## LA ROTTA NON GUADA. La scena del difetto, ridotta all'osso: una
## staccionata dal villaggio fino alla riva, e il giro più corto è quello
## che finisce nell'acqua.
##
## Il muro corre lungo z fra le righe 0 e 1, da x=0 a x=5; il fiume è la
## colonna x=6. Chi sta in (5,0) e vuole andare in (5,1) ha il capo est del
## muro a una cella e quello ovest a cinque: senza il suolo la ricerca sceglie
## l'est, cioè l'acqua.
func _la_rotta_non_guada(t) -> void:
	var muri := {}
	for x in range(0, 6):
		muri[VARCHI.bordo_fra(Vector2i(x, 0), Vector2i(x, 1))] = true
	var acqua := _fiume(6, -4, 5)
	var terra := _suolo(acqua)
	var da := Vector2i(5, 0)
	var a := Vector2i(5, 1)

	# 1) SENZA il suolo: la strada passa dall'acqua. (È la misura del
	#    difetto, non un capriccio: se un giorno non fosse più vero, questo
	#    caso non proverebbe più niente e va riscritto.)
	var senza := VARCHI.rotta(muri, da, a)
	t.ok(_tocca(senza, acqua),
			"senza il suolo, il giro più corto passa per il letto del fiume")

	# 2) CON il suolo: la strada c'è ancora, ed è asciutta.
	var con := VARCHI.rotta(muri, da, a, VARCHI.MAX_CELLE, terra)
	t.ok(not con.is_empty(), "col suolo una strada si trova lo stesso")
	t.ok(not _tocca(con, acqua), "e non tocca NESSUNA cella d'acqua")
	t.ok(con.size() > senza.size(),
			"ed è più lunga, perché il giro asciutto è quello lungo (%d contro %d)"
			% [con.size(), senza.size()])
	# ogni passo della strada è un passo lecito: niente salti, niente muri
	var rotti := 0
	for i in range(1, con.size()):
		if VARCHI.manhattan(con[i - 1], con[i]) != 1 \
				or not VARCHI.passa(muri, con[i - 1], con[i], terra):
			rotti += 1
	t.eq(rotti, 0, "e ogni suo passo è un passo che si può fare")

	# 3) e se l'acqua chiude l'ULTIMO varco, non si inventa un guado: si
	#    torna vuoti, cioè «vai dritto come hai sempre fatto». (Le due
	#    colonne vanno LUNGHE: un fiume che finisce è un fiume che si gira,
	#    e la ricerca lo troverebbe — giustamente.)
	var chiuso := _fiume(6, -200, 200)
	for c: Vector2i in _fiume(-1, -200, 200):
		chiuso.append(c)
	var murato := VARCHI.rotta(muri, da, a, VARCHI.MAX_CELLE, _suolo(chiuso))
	t.ok(murato.is_empty(),
			"e con tutt'e due i capi nell'acqua la risposta è «non c'è strada»")


## IL FILO TESO non deve rimettere dentro l'acqua una strada che l'aveva
## appena schivata. È il guasto più insidioso della coppia, perché la rotta
## sarebbe giusta: è la scorciatoia a rovinarla, e il corpo cammina la
## scorciatoia.
func _il_filo_non_scavalca_lacqua(t) -> void:
	var acqua := _fiume(0, -3, 3)
	var terra := _suolo(acqua)
	# la retta da (-2,0) a (2,0) attraversa la colonna d'acqua in pieno
	t.ok(VARCHI.filo_libero({}, Vector2(-2, 0), Vector2(2, 0)),
			"senza suolo la retta è libera: di muri non ce n'è")
	t.ok(not VARCHI.filo_libero({}, Vector2(-2, 0), Vector2(2, 0), terra),
			"col suolo no: quella retta passa nell'acqua")
	# e la scorciatoia di una spezzata che gira attorno non si tira dritta
	var spina: Array[Vector2] = [Vector2(-2, 0), Vector2(-2, 4), Vector2(2, 4),
			Vector2(2, 0)]
	var teso := VARCHI.tira_filo_mondo({}, spina, terra)
	var dentro := 0
	for i in range(1, teso.size()):
		if not VARCHI.filo_libero({}, teso[i - 1], teso[i], terra):
			dentro += 1
	t.eq(dentro, 0, "e nessuna gamba del filo teso rientra nell'acqua")
	t.ok(teso.size() >= 3, "il filo resta una spezzata, non diventa una retta")


## DA DENTRO L'ACQUA SI ESCE SEMPRE. Un corpo può trovarsi in una cella
## vietata — il ponte, un salvataggio vecchio, un banco di prova, la riva
## che il fiume ha sfiorato — e la regola non ammette eccezioni: **il
## degrado va sempre verso «si cammina»**. Se la ricerca guardasse anche la
## cella di partenza, quel vicino resterebbe piantato lì per sempre.
func _da_dentro_lacqua_si_esce_sempre(t) -> void:
	var terra := _suolo([Vector2i(0, 0), Vector2i(0, 1)])
	var via := VARCHI.rotta({}, Vector2i(0, 0), Vector2i(3, 0), VARCHI.MAX_CELLE, terra)
	t.ok(not via.is_empty(), "chi è nell'acqua trova comunque la via d'uscita")
	t.eq(via[0], Vector2i(0, 0), "che comincia da dove è davvero")
	var dentro := 0
	for i in range(1, via.size()):
		if via[i] == Vector2i(0, 0) or via[i] == Vector2i(0, 1):
			dentro += 1
	t.eq(dentro, 0, "e non ci rimette piede")


## LE COMPONENTI NON GUARDANO IL MONDO, ed è una decisione — non una
## dimenticanza.
##
## `componenti()` risponde a «mi hanno chiuso dentro?», e la sua risposta
## finisce in `raggiungibile()`, con cui un vicino decide di RINUNCIARE a un
## posto. Il fiume non è una porta che qualcuno ha chiuso: è attraversato da
## due ponti che vivono nella geometria del mondo, non in questo grafo.
## Metterlo qui dichiarerebbe prigioniera l'intera riva est.
##
## Il residuo è dichiarato: un recinto appoggiato alla riva non viene
## riconosciuto come chiusura. Chi ci abita ci si incammina, la rotta non
## trova strada e va dritto — cioè la resa che c'era già.
func _le_componenti_non_guardano_il_mondo(t) -> void:
	# tre lati di staccionata attorno a (0,0); il quarto lato è "acqua"
	var muri := {}
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		muri[VARCHI.bordo_fra(Vector2i(0, 0), Vector2i(0, 0) + d)] = true
	var mappa: Dictionary = VARCHI.componenti(muri)
	t.eq(VARCHI.isola(mappa, Vector2i(0, 0)), 0,
			"un recinto che si appoggia all'acqua NON è una prigione per il grafo")
	t.ok(VARCHI.raggiungibile(mappa, Vector2i(0, 0), Vector2i(5, 5)),
			"e chi ci abita non si crede murato")
	# e la rotta, che il mondo lo conosce, dice l'altra verità: non passa
	var terra := _suolo([Vector2i(-1, 0)])
	t.ok(VARCHI.rotta(muri, Vector2i(0, 0), Vector2i(3, 0),
			VARCHI.MAX_CELLE, terra).is_empty(),
			"ma la ROTTA, che il mondo lo conosce, non gli inventa un guado")


# ================================================ LA RICERCA GUIDATA, E IL FALÒ

## LA STRADA È LA PIÙ CORTA. La ricerca è guidata dalla distanza che manca
## (A\*), non più in ampiezza, e una guida sbagliata accorcerebbe il conto
## allungando la strada: un vicino che fa il giro largo quando ce n'era uno
## corto è un difetto che nessuna asserzione booleana vede.
##
## L'oracolo è una BFS scritta QUI, non quella del gioco: in ampiezza pura
## la prima strada trovata è per costruzione la più corta.
##
## **I MURI VANNO FITTI**, e non è un dettaglio di gusto: il modo in cui una
## ricerca guidata perde l'ottimo è chiudere una cella quando la SCOPRE
## invece di quando la spende, e quell'errore si vede solo dove due
## percorsi di costo diverso arrivano alla stessa cella nello stesso
## strato. Misurato guastando apposta quella riga: con muri radi il difetto
## esce 4 volte su 200, con muri fitti **15 su 200**. Un banco rado sarebbe
## stato verde su un codice sbagliato.
func _la_strada_e_la_piu_corta(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260810
	var diverse := 0
	var provate := 0
	var con_strada := 0
	for _v in 200:
		var muri := {}
		for _k in rng.randi_range(60, 120):
			var c := Vector2i(rng.randi_range(-7, 7), rng.randi_range(-7, 7))
			muri[c * 2 + ([Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2])] = true
		var vietate: Array = []
		for _k in rng.randi_range(0, 14):
			vietate.append(Vector2i(rng.randi_range(-7, 7), rng.randi_range(-7, 7)))
		var terra := _suolo(vietate)
		var da := Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var a := Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		if vietate.has(a):
			continue    # la meta nell'acqua non è raggiungibile per costruzione
		provate += 1
		var mia := VARCHI.rotta(muri, da, a, VARCHI.MAX_CELLE, terra)
		var sua := _bfs(muri, da, a, terra)
		if mia.size() != sua.size():
			diverse += 1
		if not mia.is_empty():
			con_strada += 1
	t.eq(diverse, 0, "su %d villaggi a caso, mai una strada più lunga della BFS"
			% provate)
	t.ok(con_strada > provate / 2,
			"e i casi con una strada vera sono la maggioranza (%d su %d)"
			% [con_strada, provate])


## LA RICERCA ARRIVA AL FALÒ, ed è tutto il punto di [C3].
##
## La radura sta a **cinquantasei celle** dalla piazza. In ampiezza, una
## meta così lontana vuole ~2·d² espansioni — cinquemila e passa — e il
## tetto di un viaggio ne concede duemila: la strada non si sarebbe trovata
## MAI, e infatti prima c'era un raggio di ventiquattro celle che tagliava
## corto e mandava ventotto vicini dritti attraverso la staccionata, ogni
## sera.
##
## Qui la stessa scena in piccolo, con i numeri veri del tetto: un muro di
## traverso a metà strada, la meta a cinquantasei celle. La ricerca guidata
## la trova; quella in ampiezza, col medesimo tetto, no.
func _la_ricerca_arriva_al_falo(t) -> void:
	var muri := {}
	for x in range(-8, 7):
		muri[VARCHI.bordo_fra(Vector2i(x, -20), Vector2i(x, -19))] = true
	var da := Vector2i(2, 6)
	var a := Vector2i(-1, -46)
	t.eq(VARCHI.manhattan(da, a), 55, "la radura è lontana com'è lontana")

	var via := VARCHI.rotta(muri, da, a, VARCHI.ROTTA_TETTO)
	t.ok(not via.is_empty(),
			"col tetto VERO di un viaggio, la strada per il falò si trova")
	t.ok(via.size() > 56, "e gira attorno alla staccionata (%d celle)" % via.size())
	var tocca_muro := 0
	for i in range(1, via.size()):
		if not VARCHI.passa(muri, via[i - 1], via[i]):
			tocca_muro += 1
	t.eq(tocca_muro, 0, "senza attraversarla")

	# e la controprova, che è la ragione per cui la ricerca è stata
	# riscritta: in ampiezza, con lo stesso tetto, non ci si arriva
	t.ok(_bfs_col_tetto(muri, da, a, VARCHI.ROTTA_TETTO).is_empty(),
			"mentre in ampiezza, con lo stesso tetto, non ci si arriva")
	# quanto costa: il numero è quello che ha permesso di togliere il raggio
	t.ok(_quante_espande(muri, da, a) < VARCHI.ROTTA_TETTO / 2,
			"e le celle espanse (%d) stanno in metà tetto"
			% _quante_espande(muri, da, a))


# ------------------------------------------------------------ gli oracoli

## Vero se la strada mette piede in una di quelle celle.
func _tocca(via: Array, celle: Array) -> bool:
	for c: Vector2i in via:
		if celle.has(c):
			return true
	return false


## LA BFS DI RIFERIMENTO, scritta qui: se il giudice fosse la stessa
## funzione che cerca, misurerebbe la propria coerenza invece della verità.
## In ampiezza pura, quindi la prima strada trovata è la più corta.
func _bfs(muri: Dictionary, da: Vector2i, a: Vector2i, terra) -> Array:
	return _bfs_col_tetto(muri, da, a, 1 << 24, terra)


func _bfs_col_tetto(muri: Dictionary, da: Vector2i, a: Vector2i, tetto: int,
		terra = null) -> Array:
	if da == a:
		return [da]
	var padre := {da: da}
	var coda: Array = [da]
	var i := 0
	while i < coda.size() and i < tetto:
		var c: Vector2i = coda[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if padre.has(n) or muri.has(c * 2 + d):
				continue
			if terra != null and bool(terra.vietata(n)):
				continue
			padre[n] = c
			if n == a:
				var giu: Array = [a]
				var cur := a
				while cur != da:
					cur = padre[cur]
					giu.append(cur)
				giu.reverse()
				return giu
			coda.append(n)
	return []


## Quante celle espande la ricerca per questa domanda: il più piccolo tetto
## con cui trova ancora la strada, per bisezione. Il tetto È il numero di
## espansioni concesse, quindi il risultato è esatto e non serve
## strumentare il codice di produzione.
func _quante_espande(muri: Dictionary, da: Vector2i, a: Vector2i) -> int:
	var lo := 1
	var hi := VARCHI.ROTTA_TETTO
	while lo < hi:
		@warning_ignore("integer_division")
		var mid := (lo + hi) / 2
		if VARCHI.rotta(muri, da, a, mid).is_empty():
			lo = mid + 1
		else:
			hi = mid
	return lo
