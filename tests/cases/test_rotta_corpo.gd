extends RefCounted
## IL CORPO SEGUE LA ROTTA, NON LA RETTA — e la spezzata che cammina è
## ESATTAMENTE quella che il villaggio ha giudicato libera.
##
## Fino a ieri i vicini sapevano dov'era il muro e ci camminavano dentro
## lo stesso: `Varchi` rispondeva «di là non si passa», il pianificatore
## cambiava idea, e poi `_walk_to` metteva UN punto solo e il corpo ci
## andava dritto — attraverso la staccionata. Poi è arrivata la coda delle
## tappe, e con lei un difetto più sottile: il villaggio giudicava una
## spezzata (centro cella → centro cella) e il corpo ne camminava
## un'altra (da dov'era, smussando gli angoli, fino al punto chiesto).
##
## ## PERCHÉ QUESTO FILE USA COORDINATE SFASATE
##
## La prima stesura di questo caso provava un solo viaggio, e i suoi
## estremi erano numeri interi: (−4,0,0) → (4,0,0). È l'unico caso in cui
## le due spezzate coincidono — cioè l'unico in cui la garanzia valeva
## davvero. Rifacendo lo STESSO scenario con la partenza spostata dentro
## la sua cella, 24 viaggi su 81 attraversavano il recinto, con la suite
## verde. Un test che sceglie l'unico punto in cui il codice è giusto non
## è un test: è un ritratto.
##
## Qui invece si sfasano partenza E arrivo su una griglia dentro la cella,
## e si pretende zero attraversamenti su tutti.
##
## ## E L'ORACOLO NON È `VARCHI`
##
## Chiedere a `Varchi.filo_libero` se il corpo ha attraversato un muro
## vuol dire chiedere al giudice se è d'accordo con sé stesso: la stessa
## funzione ha deciso la strada. Qui i muri diventano i SEGMENTI veri che
## occupano sul confine fra due celle, ogni spostamento di un frame è un
## segmento a sua volta, e la domanda è se i due si tagliano — aritmetica
## di orientamento, indipendente, esatta.
##
## E si guarda il movimento di OGNI FRAME, non la traiettoria campionata:
## un corpo che entra ed esce da un muro fra due campioni non lascia
## traccia in una scia, ed è proprio il caso che si vuole contare.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const VARCHI := preload("res://scenes/build/Varchi.gd")
const BUILD := preload("res://scenes/build/BuildSystem.gd")

## La scena: una cella chiusa dentro quattro staccionate, e due punti ai
## suoi lati. La retta fra i due passa esattamente nel mezzo.
const MURATA := Vector2i(0, 0)
const PARTENZA := Vector3(-4, 0, 0)
const ARRIVO := Vector3(4, 0, 0)

const DT := 1.0 / 60.0
## Quanto si concede al viaggio. Otto metri in linea d'aria, un giro da
## dieci-undici, a 1.3 m/s: venti secondi sono il triplo del necessario, e
## servono a distinguere «arriva lungo» da «non arriva».
const SECONDI := 20.0


func run(t) -> void:
	_senza_muro(t)
	_col_muro(t)
	_senza_villaggio(t)
	_la_meta_non_e_la_tappa(t)
	_il_muro_impossibile(t)
	_la_tratta_corta(t)
	_la_griglia_degli_sfasamenti(t)
	_la_politica_della_deviazione(t)
	_la_cella_di_un_punto(t)
	_la_coda_non_e_orfana(t)
	_il_turno_sfalsa_le_ricerche(t)
	_il_turno_non_puo_inchiodare(t)
	_il_corpo_non_smussa(t)
	_la_deviazione_conosce_il_mondo(t)


# --------------------------------------------------------------- il banco

## Un villager vero, in scena, fermo dove gli si dice.
func _villager(t, dove: Vector3):
	var v = VISITOR.new()
	v.dna = DNA.generate(4242)
	t.stage(v)
	v.position = dove
	return v


## Il recinto attorno a una cella (le quattro staccionate).
func _recinto(c: Vector2i) -> Dictionary:
	var muri := {}
	for d: Vector2i in VARCHI.INTORNO:
		muri[VARCHI.bordo_fra(c, c + d)] = true
	return muri


## Fa camminare il villager e riporta la traiettoria campionata (una
## posizione per frame) più lo stato in cui è finito.
func _cammina(v, secondi: float) -> Dictionary:
	var scia: Array[Vector3] = []
	var frames := int(secondi / DT)
	for f in frames:
		v._process(DT)
		scia.append(v.position)
		if str(v._state) != "walk":
			break
	return {"scia": scia, "stato": str(v._state)}


## Le celle attraversate dalla scia, in ordine.
func _celle(scia: Array[Vector3]) -> Array[Vector2i]:
	var fuori: Array[Vector2i] = []
	for p in scia:
		var c := VARCHI.cella(Vector2(p.x, p.z))
		if fuori.is_empty() or fuori[fuori.size() - 1] != c:
			fuori.append(c)
	return fuori


# ------------------------------------------------------------- l'oracolo
#
# Indipendente da `Varchi`: i muri come segmenti veri di mondo, e il
# taglio fra due segmenti deciso per orientamento.

## Il confine fra due celle è un metro di retta, e sta sui mezzi interi.
func _muri_segmenti(muri: Dictionary) -> Array:
	var fuori := []
	for k: Vector2i in muri:
		if posmod(k.y, 2) == 1:
			@warning_ignore("integer_division")
			var cy := (k.y - 1) / 2
			@warning_ignore("integer_division")
			var cx := k.x / 2
			fuori.append([Vector2(cx - 0.5, cy + 0.5), Vector2(cx + 0.5, cy + 0.5)])
		else:
			@warning_ignore("integer_division")
			var cx2 := (k.x - 1) / 2
			@warning_ignore("integer_division")
			var cy2 := k.y / 2
			fuori.append([Vector2(cx2 + 0.5, cy2 - 0.5), Vector2(cx2 + 0.5, cy2 + 0.5)])
	return fuori


static func _orient(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


## I due segmenti si TAGLIANO davvero? Sfiorarsi a un capo non conta: il
## rasente lo spigolo è il passaggio, non il guasto.
static func _taglia(p0: Vector2, p1: Vector2, q0: Vector2, q1: Vector2) -> bool:
	var e := 1e-9
	var d1 := _orient(q0, q1, p0)
	var d2 := _orient(q0, q1, p1)
	var d3 := _orient(p0, p1, q0)
	var d4 := _orient(p0, p1, q1)
	if absf(d1) < e or absf(d2) < e or absf(d3) < e or absf(d4) < e:
		return false
	return (d1 > 0.0) != (d2 > 0.0) and (d3 > 0.0) != (d4 > 0.0)


## Quante gambe di questa spezzata attraversano un muro? (Vale sia per la
## traiettoria di un corpo, sia per una rotta appena consegnata.)
func _sfondamenti(segs: Array, punti: Array) -> int:
	var quanti := 0
	for i in range(1, punti.size()):
		var p0: Vector3 = punti[i - 1]
		var p1: Vector3 = punti[i]
		for s in segs:
			if _taglia(Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), s[0], s[1]):
				quanti += 1
				break
	return quanti


# ------------------------------------------------------------- gli scenari

## LA CONTROPROVA. Senza muri il villaggio non ha niente da dire, la coda
## delle tappe resta vuota, e il corpo cammina dritto come ha sempre fatto
## — attraverso la cella che nel prossimo caso sarà murata.
func _senza_muro(t) -> void:
	var finto = _finto_villaggio(t, {})
	var v = _villager(t, PARTENZA)
	v._walk_to(ARRIVO, "r_idle")
	t.ok(v._tappe.is_empty(), "senza muri non c'è nessuna deviazione da fare")
	var esito := _cammina(v, SECONDI)
	var celle := _celle(esito["scia"])
	t.ok(celle.has(MURATA),
			"e la retta passa proprio per %s: è la scena del prossimo caso" % MURATA)
	t.eq(esito["stato"], "r_idle", "il viaggio finisce (dritto) nello stato chiesto")
	t.ok(v.position.distance_to(ARRIVO) < 0.2,
			"e il corpo è arrivato (%.2f m dalla meta)" % v.position.distance_to(ARRIVO))
	finto.chiudi()


## LA SCENA. La stessa identica camminata, con la cella di mezzo chiusa in
## un recinto: il corpo deve arrivare lo stesso, e non esserci mai stato
## dentro.
func _col_muro(t) -> void:
	var muri := _recinto(MURATA)
	var finto = _finto_villaggio(t, muri)
	var v = _villager(t, PARTENZA)
	v._walk_to(ARRIVO, "r_idle")
	t.ok(not v._tappe.is_empty() or v._target != ARRIVO,
			"col muro in mezzo il villaggio detta una strada (%d tappe)" % v._tappe.size())

	var esito := _cammina(v, SECONDI)
	var scia: Array[Vector3] = esito["scia"]
	var celle := _celle(scia)

	# 1) È ARRIVATO. Il degrado che questa fase vieta è il corpo piantato
	#    a metà strada: prima ancora che «gira attorno», si pretende
	#    «arriva».
	t.eq(esito["stato"], "r_idle", "il viaggio finisce nello stato chiesto")
	t.ok(v.position.distance_to(ARRIVO) < 0.2,
			"e il corpo è arrivato davvero (%.2f m dalla meta)"
			% v.position.distance_to(ARRIVO))

	# 2) E NON È MAI STATO DENTRO. La cella è chiusa da quattro
	#    staccionate: esserci stato vuol dire averne attraversata una.
	var dentro := 0
	for p in scia:
		if VARCHI.cella(Vector2(p.x, p.z)) == MURATA:
			dentro += 1
	t.eq(dentro, 0, "IL CORPO NON È MAI ENTRATO nella cella murata")

	# 3) e nemmeno di sguincio: nessuno SPOSTAMENTO di un frame taglia un
	#    muro. Lo chiede l'oracolo indipendente, sul movimento vero.
	var partendo: Array = [PARTENZA]
	partendo.append_array(scia)
	t.eq(_sfondamenti(_muri_segmenti(muri), partendo), 0,
			"e nessuno spostamento taglia un muro (%d celle toccate)" % celle.size())

	# 4) IL GIRO SI VEDE. La retta fra i due punti sta tutta a z = 0: se il
	#    corpo se ne è scostato di più di mezzo metro, ha girato attorno —
	#    e mezzo metro è la distanza dal centro della cella al suo muro.
	var scostamento := 0.0
	for p in scia:
		scostamento = maxf(scostamento, absf(p.z))
	t.ok(scostamento > 0.5,
			"e si è scostato dalla retta per passare di fianco (%.2f m)" % scostamento)

	# 5) …ma senza fare il giro largo: il filo teso costa qualche
	#    centimetro, non un viaggio. (Il giro attorno a una cella da un
	#    metro, passando per lo spigolo largo, è 8.3 m contro 8.0.)
	var percorsa := PARTENZA.distance_to(scia[0])
	for i in range(1, scia.size()):
		percorsa += scia[i].distance_to(scia[i - 1])
	var retta := PARTENZA.distance_to(ARRIVO)
	t.ok(percorsa > retta + 0.1 and percorsa < retta + 1.5,
			"e la strada è più lunga della retta ma non è un giro largo (%.2f m invece di %.2f)"
			% [percorsa, retta])
	finto.chiudi()


## FUORI DAL VILLAGGIO. Il bosco, il prologo, il diorama del menù: lì il
## BuildSystem non esiste. Si cammina dritto — mai «si resta fermi».
func _senza_villaggio(t) -> void:
	var v = _villager(t, PARTENZA)
	v._walk_to(ARRIVO, "r_idle")
	t.ok(v._tappe.is_empty(), "senza BuildSystem non c'è nessuna deviazione")
	var esito := _cammina(v, SECONDI)
	t.eq(esito["stato"], "r_idle", "e il viaggio finisce comunque")
	t.ok(v.position.distance_to(ARRIVO) < 0.2, "il corpo arriva lo stesso")


## LA META NON È LA TAPPA. Da quando c'è la coda, `_target` è il passo:
## chi vuole sapere dove uno è diretto chiede `meta_cammino()`. È la
## distinzione da cui dipende ogni verifica futura.
##
## E la meta è un punto QUALUNQUE, non il centro di una cella: è lì che
## «dove sto andando» e «l'ultimo centro di cella della rotta» divergono,
## ed è la stessa differenza che mandava il corpo dentro il muro
## nell'ultima gamba.
func _la_meta_non_e_la_tappa(t) -> void:
	var finto = _finto_villaggio(t, _recinto(MURATA))
	var meta := Vector3(3.62, 0, 0.41)
	var v = _villager(t, Vector3(-3.7, 0, -0.28))
	v._walk_to(meta, "r_idle")
	t.ok(not v._tappe.is_empty(), "c'è almeno una tappa di passaggio")
	t.ok(v._target.distance_to(meta) > 0.5,
			"e la prossima tappa NON è la meta (è un angolo da girare)")
	t.almost(v.meta_cammino().distance_to(meta), 0.0,
			"ma la meta del viaggio resta quella chiesta, al millimetro", 1e-5)
	# e a viaggio finito la meta è ancora la meta
	_cammina(v, SECONDI)
	t.almost(v.meta_cammino().distance_to(meta), 0.0,
			"anche a coda vuota, a fine viaggio", 1e-5)
	t.ok(v.position.distance_to(meta) < 0.02,
			"e il corpo si posa sul punto chiesto, non nei paraggi (%.3f m)"
			% v.position.distance_to(meta))
	finto.chiudi()


## IL MURO IMPOSSIBILE. Una meta chiusa dentro il recinto: strada non ce
## n'è. Il corpo deve andarci dritto **come prima**, perché l'alternativa
## è un vicino che si pianta — e chi non doveva partire è già stato
## fermato prima, dal pianificatore.
func _il_muro_impossibile(t) -> void:
	var finto = _finto_villaggio(t, _recinto(MURATA))
	var v = _villager(t, PARTENZA)
	v._walk_to(Vector3(MURATA.x, 0, MURATA.y), "r_idle")
	t.ok(v._tappe.is_empty(), "verso una meta murata non c'è nessuna strada da dare")
	var esito := _cammina(v, SECONDI)
	t.eq(esito["stato"], "r_idle", "e il corpo non resta impiantato")
	t.ok(v.position.distance_to(Vector3(MURATA.x, 0, MURATA.y)) < 0.2,
			"ci arriva dritto, esattamente come faceva prima")
	finto.chiudi()


## LA TRATTA CORTA. Due passi dentro la stessa cella non hanno una strada
## da chiedere: il cancello a monte esiste perché una BFS costa mezzo
## millisecondo e i vicini cambiano meta tutto il giorno.
func _la_tratta_corta(t) -> void:
	var finto = _finto_villaggio(t, _recinto(MURATA))
	var v = _villager(t, Vector3(-4.2, 0, 0.1))
	v._walk_to(Vector3(-3.8, 0, -0.1), "r_idle")
	t.ok(v._tappe.is_empty(), "nella stessa cella non si chiede nessuna rotta")
	t.almost(v._target.distance_to(Vector3(-3.8, 0, -0.1)), 0.0,
			"e la meta è quella chiesta", 1e-5)
	finto.chiudi()


# ------------------------------------------------- [T1] gli sfasamenti

## LA GRIGLIA DEGLI SFASAMENTI — il caso per cui esiste questa riparazione.
##
## Stessa scena di `_col_muro`, più la testata di una staccionata (che è
## il posto dove il filo teso rasenta il palo, cioè dove lo smusso
## d'angolo faceva danno). Ma partenza e arrivo si spostano DENTRO le loro
## celle: sette posizioni per asse, quarantanove viaggi, e nessuno dei due
## estremi è mai un centro di cella.
##
## È la condizione normale in partita — un vicino non sta mai esattamente
## sul centro della sua cella — e sul codice di prima ne sfondava una
## fetta. Il conto lo tiene l'oracolo indipendente, spostamento per
## spostamento.
func _la_griglia_degli_sfasamenti(t) -> void:
	var muri := _recinto(MURATA)
	for z in range(2, 6):
		muri[VARCHI.bordo_fra(Vector2i(2, z), Vector2i(3, z))] = true
	var segs := _muri_segmenti(muri)
	var finto = _finto_villaggio(t, muri)

	var sfondati := 0
	var non_arrivati := 0
	var viaggi := 0
	var deviati := 0
	var peggio := ""
	var scarti: Array[float] = [-0.44, -0.29, -0.15, 0.0, 0.15, 0.29, 0.44]
	for ix in scarti.size():
		for iz in scarti.size():
			viaggi += 1
			# partenza e arrivo si sfasano con due combinazioni diverse:
			# nessuno dei due cade mai su un centro di cella
			var da := Vector3(-3.0 + scarti[ix], 0, scarti[iz])
			var a := Vector3(3.0 + scarti[iz], 0, scarti[scarti.size() - 1 - ix])
			var v = _villager(t, da)
			v._walk_to(a, "r_idle")
			if not v._tappe.is_empty():
				deviati += 1
			var esito := _cammina(v, SECONDI)
			var punti: Array = [da]
			punti.append_array(esito["scia"])
			if _sfondamenti(segs, punti) > 0:
				sfondati += 1
				if peggio == "":
					peggio = "da (%.2f,%.2f) a (%.2f,%.2f)" % [da.x, da.z, a.x, a.z]
			if str(esito["stato"]) != "r_idle" or v.position.distance_to(a) > 0.2:
				non_arrivati += 1
			v.free()

	t.eq(viaggi, 49, "il banco è pieno: quarantanove partenze e arrivi sfasati")
	t.eq(deviati, 49, "e tutti e quarantanove hanno davvero una strada da seguire")
	t.eq(sfondati, 0,
			"NESSUN viaggio sfasato attraversa un muro%s"
			% ("" if peggio == "" else " (il primo: %s)" % peggio))
	t.eq(non_arrivati, 0, "e arrivano tutti, senza piantarsi a metà strada")
	finto.chiudi()


# --------------------------------------- [T4] la politica della deviazione

## LA DEVIAZIONE HA UN CONTRATTO, e va provato.
##
## `BuildSystem.deviazione` toglie la prima tappa della rotta. Cancellare
## quella riga lasciava la suite completamente verde: una politica
## documentata per venti righe e non provata da nessuno. E soprattutto,
## toglierla è LECITO solo perché adesso la prima tappa è il punto vero da
## cui si parte — con la stesura di prima (che cominciava dal centro della
## cella) toglierla lasciava scoperta tutta la prima gamba, ed è da lì che
## venivano 25 sfondamenti su mille.
##
## Le tre cose che si pretendono, su villaggi a caso e con l'oracolo
## indipendente:
##
##   1. la prima tappa NON è dove si è già (è stata tolta);
##   2. la spezzata `da → tappe…` non taglia nessun muro — **cominciando
##      dal punto di partenza vero**, che è la gamba che il codice di
##      prima non giudicava;
##   3. l'ultima tappa è la meta chiesta, al millimetro: chi devia non
##      cambia dove si va.
func _la_politica_della_deviazione(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var chiesti := 0
	var doppioni := 0
	var sfondati := 0
	var mete_storte := 0
	for giro in 30:
		var muri := {}
		for i in 14:
			var c := Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			var d: Vector2i = VARCHI.INTORNO[rng.randi() % 4]
			muri[VARCHI.bordo_fra(c, c + d)] = true
		var segs := _muri_segmenti(muri)
		var bs = BUILD.new()
		bs.set("_muri_cache", muri)
		bs.set("_varchi_sporchi", false)
		for prova in 40:
			var da := Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
			var a := Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
			var tappe: Array = bs.deviazione(da, a)
			if tappe.is_empty():
				continue
			chiesti += 1
			if (tappe[0] as Vector3).distance_to(da) < 1e-6:
				doppioni += 1
			var punti: Array = [da]
			punti.append_array(tappe)
			sfondati += _sfondamenti(segs, punti)
			if (tappe[tappe.size() - 1] as Vector3).distance_to(
					Vector3(a.x, 0.0, a.z)) > 1e-6:
				mete_storte += 1
		bs.free()
	t.ok(chiesti > 150, "il banco è pieno: %d deviazioni consegnate" % chiesti)
	t.eq(doppioni, 0, "la prima tappa non è mai il punto da cui si parte: è tolta")
	t.eq(sfondati, 0,
			"e la spezzata da → tappe non taglia MAI un muro, prima gamba compresa")
	t.eq(mete_storte, 0, "l'ultima tappa è la meta chiesta, al millimetro")


# ------------------------------------------------------- [T2] la cella

## LA CELLA DI UN PUNTO. Una riga sola, e nessun test la copriva:
## sostituendo `roundi` con `floori` la suite restava verde su
## sessantunmila asserzioni. È la conversione che lega il corpo al grafo —
## se sbaglia, il villaggio giudica una cella e il corpo ne cammina
## un'altra.
##
## Si prova il COMPORTAMENTO che la definisce: la cella è quella il cui
## CENTRO è più vicino, quindi il confine sta sui mezzi interi — non sugli
## interi, che è dove lo metterebbe `floori`.
func _la_cella_di_un_punto(t) -> void:
	var bs = BUILD.new()
	# la mezza cella dopo il centro appartiene ancora al centro
	t.eq(bs.cella_di(Vector3(0.49, 0, 0.49)), Vector2i(0, 0),
			"mezzo metro oltre il centro si è ancora nella cella zero")
	# e la mezza cella prima del centro successivo appartiene già a lui:
	# è QUI che `floori` sbaglia, e sbaglia di una cella intera
	t.eq(bs.cella_di(Vector3(0.51, 0, 0.51)), Vector2i(1, 1),
			"oltre il confine si è già nella cella uno")
	t.eq(bs.cella_di(Vector3(2.7, 0, -1.8)), Vector2i(3, -2),
			"e vale anche in negativo: si arrotonda al centro più vicino")
	t.eq(bs.cella_di(Vector3(-0.4, 0, 0.4)), Vector2i(0, 0),
			"attorno all'origine la cella zero è larga un metro, non mezzo")
	# la regola è UNA: la porta in tre dimensioni e quella pura del filo
	# devono dire la stessa cosa, o il giudice e il corpo vedono due griglie
	for p: Vector3 in [Vector3(1.4, 0, -2.6), Vector3(-3.49, 0, 7.5),
			Vector3(0.0, 0, 0.0), Vector3(6.5, 0, -0.2)]:
		t.eq(bs.cella_di(p), VARCHI.cella(Vector2(p.x, p.z)),
				"la cella di %s è la stessa per il BuildSystem e per Varchi" % p)
	bs.free()


# --------------------------------------------- [C4] il canale non è orfano

## LA CODA NON RESTA APPESA. Un viaggio si interrompe da undici parti
## diverse — il pasto, il concerto, il congedo, il nascondino — e nessuna
## di quelle passa da un posto solo: se la coda si svuotasse soltanto in
## `_walk_to`, `meta_cammino()` di un vicino seduto racconterebbe la meta
## del viaggio PRECEDENTE, e chi legge l'intenzione la prenderebbe per
## buona.
##
## Qui il viaggio si interrompe come lo interrompe il gioco — imponendo
## uno stato da fuori, senza chiedere permesso — e si pretende che al
## primo frame utile la coda sia vuota e la meta sia tornata onesta.
func _la_coda_non_e_orfana(t) -> void:
	var finto = _finto_villaggio(t, _recinto(MURATA))
	var v = _villager(t, PARTENZA)
	v._walk_to(ARRIVO, "r_idle")
	t.ok(not v._tappe.is_empty(), "il viaggio parte con una coda di tappe")
	for f in 30:
		v._process(DT)
	t.ok(not v._tappe.is_empty(), "e a metà strada la coda è ancora piena")
	var meta_prima: Vector3 = v.meta_cammino()
	# l'interruzione: uno degli undici sistemi impone il proprio stato
	v._state = "r_pasto"
	v._process(DT)
	t.ok(v._tappe.is_empty(), "interrotto il viaggio, la coda si svuota da sola")
	t.ok(v.meta_cammino().distance_to(meta_prima) > 0.5,
			"e la meta non è più quella del viaggio interrotto")
	t.almost(v.meta_cammino().distance_to(v._target), 0.0,
			"è l'ultimo punto vero verso cui il corpo stava andando", 1e-5)
	finto.chiudi()


## IL TURNO SFALSA LE RICERCHE, E NON PERDE NESSUNO.
##
## La sera del falò ventotto vicini si alzano insieme, e ognuno chiede una
## strada. Con una staccionata di traverso sul tragitto quella domanda
## costa un millisecondo e mezzo: quattro nello stesso frame farebbero sei
## millisecondi, un singhiozzo nella scena più guardata della giornata.
## Il villaggio quindi ne serve uno scampolo per frame
## (`BuildSystem.BUDGET_ROTTE_US`) e agli altri dice «fra un frame».
##
## **Il rischio di quel «fra un frame» è che diventi «mai»**, e sarebbe il
## guasto peggiore dei due: un vicino che cammina dritto attraverso la
## staccionata perché nessuno gli ha più risposto. Qui si prova esattamente
## quello, ed è una prova sul CORPO: turno chiuso → si parte lo stesso, e si
## parte verso la meta; turno riaperto → un frame dopo la strada c'è.
func _il_turno_sfalsa_le_ricerche(t) -> void:
	var finto = _finto_villaggio(t, _recinto(MURATA))
	finto.turno_aperto = false          # il villaggio sta già cercando per un altro
	var v = _villager(t, PARTENZA)
	v._walk_to(ARRIVO, "r_idle")
	t.ok(v._tappe.is_empty(), "col turno occupato non si riceve nessuna strada")
	t.ok(v._rotta_attesa, "ma la domanda resta in piedi: si riprova")
	t.ok(str(v._state) == "walk", "e lo stato resta «walk»: il viaggio non si perde")

	# CHI ASPETTA NON AVANZA, ed è la regola per cui questo caso esiste.
	#
	# La prima stesura faceva camminare dritto «per un frame, quattro
	# centimetri». Sembra innocuo e non lo è: senza strada, dritto vuol
	# dire VERSO LA META — cioè esattamente contro il muro da aggirare.
	# MISURATO nel MainLevel vero: venti corpi a tre centimetri da una
	# staccionata che chiedono insieme, fino a UNDICI la attraversavano. E
	# chi la attraversa ci resta, perché la domanda dopo riparte da oltre
	# il muro. Il verso dell'errore era pure il peggiore: il budget è in
	# microsecondi VERI, quindi più la macchina è carica più corpi
	# venivano rimandati — il guasto peggiorava proprio quando il gioco
	# stava già arrancando.
	var fermo: Vector3 = v.position
	for _f in 3:
		v._process(DT)
	t.almost(v.position.distance_to(fermo), 0.0,
			"CHI ASPETTA UNA STRADA STA FERMO: non cammina contro il muro", 1e-6)
	t.ok(v._rotta_attesa, "e la domanda è ancora in piedi")
	t.ok(v._tappe.is_empty(), "e la strada ancora non c'è")

	# il turno si riapre: la strada arriva, e arriva DA DOVE IL CORPO È ORA
	finto.turno_aperto = true
	var dove: Vector3 = v.position
	v._process(DT)
	t.ok(not v._tappe.is_empty(), "riaperto il turno, la strada arriva")
	t.ok(not v._rotta_attesa, "e la domanda si spegne")
	t.ok(v._target.distance_to(ARRIVO) > 0.5,
			"la prossima tappa è un angolo da girare, non più la meta")
	t.almost(dove.distance_to(PARTENZA), 0.0,
			"e nel frattempo non si era mosso di un millimetro", 1e-6)

	# e il corpo arriva davvero, senza attraversare il recinto
	var esito := _cammina(v, SECONDI)
	t.ok(v.position.distance_to(ARRIVO) < 0.05,
			"il viaggio finisce sul punto chiesto (%.3f m)"
			% v.position.distance_to(ARRIVO))
	t.eq(_sfondamenti(_muri_segmenti(_recinto(MURATA)), esito["scia"]), 0,
			"e la strada arrivata in ritardo non gli ha fatto tagliare niente")
	finto.chiudi()


## IL TURNO NON PUÒ INCHIODARE NESSUNO.
##
## Fermarsi ad aspettare una strada cura l'attraversamento, ma apre il
## guasto opposto: se il turno non si riaprisse mai — una macchina molto
## carica, un villaggio pieno la sera del falò — il corpo resterebbe lì
## per sempre. Il turno serve a spalmare una spesa, non a decidere chi ha
## il permesso di rispettare un muro: dopo `ATTESA_MAX` frame la strada si
## prende comunque, saltandolo.
##
## Il degrado va SEMPRE verso «si cammina, e si cammina bene»: un
## microsecondo in più non lo vede nessuno, un chibi dentro la staccionata
## sì.
func _il_turno_non_puo_inchiodare(t) -> void:
	var muri := _recinto(MURATA)
	var finto = _finto_villaggio(t, muri)
	finto.turno_aperto = false          # e non si riaprirà mai
	var v = _villager(t, PARTENZA)
	v._walk_to(ARRIVO, "r_idle")
	t.ok(v._rotta_attesa, "col turno chiuso si aspetta")

	# ATTESA_MAX frame fermi, e poi la strada arriva LO STESSO
	for _f in VISITOR.ATTESA_MAX:
		v._process(DT)
	t.ok(not v._rotta_attesa,
			"dopo %d frame la strada si prende comunque" % VISITOR.ATTESA_MAX)
	t.ok(not v._tappe.is_empty(), "e la strada c'è, col turno ancora chiuso")

	var esito := _cammina(v, SECONDI)
	t.eq(esito["stato"], "r_idle", "il viaggio finisce")
	t.ok(v.position.distance_to(ARRIVO) < 0.05,
			"sul punto chiesto (%.3f m)" % v.position.distance_to(ARRIVO))
	var partendo: Array = [PARTENZA]
	partendo.append_array(esito["scia"])
	t.eq(_sfondamenti(_muri_segmenti(muri), partendo), 0,
			"e senza tagliare niente, nemmeno col turno perennemente chiuso")
	# il fermo dura un decimo di secondo: non si legge come un'esitazione
	t.ok(VISITOR.ATTESA_MAX * DT < 0.15,
			"e l'attesa è troppo corta perché si veda (%.0f ms)"
			% (VISITOR.ATTESA_MAX * DT * 1000.0))
	finto.chiudi()


## IL CORPO CAMMINA LA SPEZZATA CHE GLI È STATA DATA — non una parallela.
##
## È l'invariante che tiene in piedi tutta la fase, ed è quello che la
## prima stesura violava: il villaggio giudicava un filo (teso fino a
## rasentare gli spigoli, PER COSTRUZIONE) e il corpo ne camminava un
## altro, perché smussava gli angoli 25 cm prima. Venticinque centimetri
## di scorciatoia dove il filo passa a diciassette dal muro fanno un chibi
## dentro la staccionata: misurato, il 7,3% dei viaggi, il 14,2% uscendo
## di casa.
##
## Qui non si conta quante volte è successo: si misura **quanto il corpo
## si è scostato dalla spezzata**, e si pretende che sia zero a meno
## dell'arrotondamento. Così qualunque scorciatoia futura — un altro
## smusso, un'interpolazione, uno sterzo «per fare più bello» — diventa
## rossa il giorno che la si scrive, invece che il mese dopo in partita.
func _il_corpo_non_smussa(t) -> void:
	var muri := _recinto(MURATA)
	var finto = _finto_villaggio(t, muri)
	var v = _villager(t, Vector3(-4.31, 0, -0.28))   # MAI un centro cella
	var meta := Vector3(4.19, 0, 0.37)
	v._walk_to(meta, "r_idle")

	# la spezzata come il villaggio l'ha dettata, prima di camminarla
	var filo: Array[Vector3] = [v.position, v._target]
	filo.append_array(v._tappe)
	t.ok(filo.size() >= 3, "il villaggio ha dettato una spezzata (%d punti)" % filo.size())

	var esito := _cammina(v, SECONDI)
	var lontano := 0.0
	for p in esito["scia"]:
		lontano = maxf(lontano, _dal_filo(filo, p))
	t.ok(lontano < 0.01,
			"IL CORPO NON SI SCOSTA DALLA SPEZZATA (%.5f m di scarto massimo)" % lontano)
	var partendo: Array = [Vector3(-4.31, 0, -0.28)]
	partendo.append_array(esito["scia"])
	t.eq(_sfondamenti(_muri_segmenti(muri), partendo), 0,
			"e quindi non taglia niente")
	finto.chiudi()


## La distanza di un punto dalla spezzata (il minimo fra i suoi segmenti).
func _dal_filo(filo: Array[Vector3], p: Vector3) -> float:
	var m := 1.0e30
	for i in range(1, filo.size()):
		var a := Vector2(filo[i - 1].x, filo[i - 1].z)
		var b := Vector2(filo[i].x, filo[i].z)
		var q := Vector2(p.x, p.z)
		var ab := b - a
		var l2 := ab.length_squared()
		var proj := a if l2 < 1e-12 else a + ab * clampf((q - a).dot(ab) / l2, 0.0, 1.0)
		m = minf(m, q.distance_to(proj))
	return m


## LA DEVIAZIONE CONOSCE IL MONDO — e l'invariante che la governa.
##
## **Il corpo o cammina la retta di sempre, oppure una spezzata che non
## tocca né un muro né l'acqua.** Non esiste una terza risposta, e da lì
## discende tutto: il cancello della retta guarda SOLO i muri, perché la
## deviazione non deve mai mettere il corpo in un posto peggiore di quello
## in cui lo metterebbe la retta.
##
## Il fiume qui è finto — una colonna di celle vietate — perché quello che
## si prova sono i cancelli. La geografia vera ha `test_terreno.gd`, la
## scena vera `tools/prova_fiume.gd`.
func _la_deviazione_conosce_il_mondo(t) -> void:
	var acqua := {}
	for z in range(-8, 9):
		acqua[Vector2i(2, z)] = true

	# 1) IL GIRO NON GUADA. Recinto attorno a (0,0), acqua sulla colonna
	#    x=2: la strada esiste, e passa dall'altra parte.
	var finto = _finto_villaggio(t, _recinto(MURATA))
	finto.vero.set("_suolo_cache",
			VARCHI.Suolo.new(func(c: Vector2i) -> bool: return acqua.has(c)))
	var tappe: Array = finto.deviazione(PARTENZA, ARRIVO)
	t.ok(not tappe.is_empty(), "col recinto davanti il villaggio detta una strada")
	var punti: Array = [PARTENZA]
	for p: Vector3 in tappe:
		punti.append(p)
	t.eq(_gambe_nellacqua(punti, acqua), 0,
			"e nessuna gamba di quella strada passa nell'acqua")
	t.eq(_sfondamenti(_muri_segmenti(_recinto(MURATA)), punti), 0,
			"né attraverso il recinto")

	# 2) LA META NELL'ACQUA. Che la risposta sia «vai dritto» è vero anche
	#    senza il cancello — la ricerca in quella cella non ci entra
	#    comunque, e torna vuota lo stesso. Quello che il cancello compra
	#    è il PREZZO, e il prezzo si misura: senza, ogni singolo viaggio
	#    verso un pezzo posato sulla riva pagherebbe una ricerca esaurita
	#    fino al tetto per sentirsi dire di no.
	#
	#    Il testimone non è un cronometro (che su una macchina diversa
	#    direbbe un'altra cosa): sono le domande fatte al MONDO, che una
	#    ricerca esaurita moltiplica per mille.
	var terra = finto.vero.suolo()
	var prima: int = terra.domande
	t.ok((finto.deviazione(PARTENZA, Vector3(2, 0, 0)) as Array).is_empty(),
			"una meta dentro l'acqua non fa nascere nessuna strada")
	t.ok(terra.domande - prima <= 2,
			"e non si esaurisce una ricerca intera per scoprirlo (%d domande al mondo)"
			% (terra.domande - prima))
	finto.chiudi()

	# 3) L'INVARIANTE. Senza muri sulla retta, si va DRITTI — anche se la
	#    retta rasenta l'acqua. Chiedere una strada anche per schivare
	#    l'acqua sembra più bello e non lo è: le mete di questo gioco sono
	#    spesso in riva, e la ricerca finirebbe per pagare millisecondi e
	#    ridare comunque la retta.
	var lontano := {}
	lontano[VARCHI.bordo_fra(Vector2i(30, 30), Vector2i(31, 30))] = true
	var finto2 = _finto_villaggio(t, lontano)
	finto2.vero.set("_suolo_cache",
			VARCHI.Suolo.new(func(c: Vector2i) -> bool: return acqua.has(c)))
	t.ok((finto2.deviazione(PARTENZA, ARRIVO) as Array).is_empty(),
			"senza muri davanti si va dritti, acqua o no: la retta di sempre")
	finto2.chiudi()


## Quante gambe di questa spezzata entrano in una cella d'acqua. Esatto,
## non campionato: si guarda se il segmento taglia uno dei quattro lati del
## quadretto, o se ci finisce dentro. (Campionare a passetti perderebbe
## proprio il caso interessante — la gamba che tocca lo spigolo.)
func _gambe_nellacqua(punti: Array, acqua: Dictionary) -> int:
	var quante := 0
	for i in range(1, punti.size()):
		var p0 := Vector2(punti[i - 1].x, punti[i - 1].z)
		var p1 := Vector2(punti[i].x, punti[i].z)
		for c: Vector2i in acqua:
			var lo := Vector2(c.x - 0.5, c.y - 0.5)
			var hi := Vector2(c.x + 0.5, c.y + 0.5)
			var dentro := p1.x > lo.x and p1.x < hi.x and p1.y > lo.y and p1.y < hi.y
			if not dentro:
				for lato: Array in [[lo, Vector2(hi.x, lo.y)],
						[Vector2(hi.x, lo.y), hi], [hi, Vector2(lo.x, hi.y)],
						[Vector2(lo.x, hi.y), lo]]:
					if _taglia(p0, p1, lato[0], lato[1]):
						dentro = true
						break
			if dentro:
				quante += 1
				break
	return quante


# ------------------------------------------------- il villaggio, ridotto

## IL BANCO. Serve un nodo nel gruppo «build_system» che sappia rispondere
## `deviazione()`, e serve che sia il BuildSystem **VERO** — la risposta
## dipende da come lui converte metri in celle, taglia la prima tappa e
## tira il filo, e una seconda copia di quelle regole in un finto sarebbe
## la tabella parallela che questo progetto ha già pagato due volte.
##
## Ma un BuildSystem messo in scena fa il suo `_ready`: costruisce l'UI e
## soprattutto **carica il village.json vero dell'utente**, cioè porta
## dentro il banco i muri di una partita che non c'entra niente. Quindi:
## il BuildSystem vero si crea con `.new()` e NON si mette mai in scena
## (senza albero, niente `_ready`), gli si consegnano i muri a mano, e in
## scena ci va un usciere di tre righe che gli passa le domande.
func _finto_villaggio(t, muri: Dictionary):
	var vero = BUILD.new()
	vero.set("_muri_cache", muri)
	vero.set("_varchi_sporchi", false)
	var usciere := _Usciere.new()
	usciere.vero = vero
	t.stage(usciere)
	return usciere


class _Usciere:
	extends Node
	var vero: Node3D

	func _ready() -> void:
		add_to_group("build_system")

	func deviazione(da: Vector3, a: Vector3) -> Array[Vector3]:
		var tappe: Array[Vector3] = vero.deviazione(da, a)
		return tappe

	## IL TURNO È APERTO QUI, ed è l'unica bugia del banco. In partita il
	## villaggio ne concede uno scampolo per frame (vedi
	## `BuildSystem.BUDGET_ROTTE_US`), ma un caso di prova fa decine di
	## viaggi dentro UN frame del motore: col turno vero, dal secondo in
	## poi nessuno avrebbe più una strada e il banco proverebbe un gioco
	## che non esiste. La leva serve a `_il_turno_sfalsa_le_ricerche`, che
	## è il caso in cui il turno lo si prova sul serio.
	var turno_aperto := true

	func turno_rotte_libero() -> bool:
		return turno_aperto

	## Il BuildSystem vero non è figlio di nessuno: nessuno lo libererebbe.
	## E si ESCE DAL GRUPPO: l'usciere resta in scena fino a fine caso, e
	## uno scenario che si aspetta un mondo senza villaggio troverebbe
	## questo, con dentro un BuildSystem già liberato.
	func chiudi() -> void:
		remove_from_group("build_system")
		if vero != null and is_instance_valid(vero):
			vero.free()
			vero = null
