extends RefCounted
## IL REGISTRO ECS — la prima autorità C++ del villaggio.
##
## Qui non si cerca una stringa nei file: il gioco obbedisce alla .dylib,
## non al .cpp, quindi si interroga il BINARIO. Si chiedono i metodi
## all'oggetto vero, si fanno girare i passi veri, e si misura.
##
## La prova più importante è quella di EQUIVALENZA: la finestra del sonno
## è stata TOLTA dal GDScript e messa in C++, e `tests/oracolo_sonno.gd`
## conserva com'era. Se le due divergono anche di un millesimo d'ora su un
## solo profilo, questo test diventa rosso — che è l'unico modo di
## migrare una formula senza fidarsi.

const ORACOLO := preload("res://tests/oracolo_sonno.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")


func run(t) -> void:
	# GUARDIA DURA, non molle: se la GDExtension non è caricata questo test
	# deve essere ROSSO. Un `return` silenzioso qui direbbe «tutto bene» a
	# un villaggio senza cuore.
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_api(t, m)
	_costanti(t, m)
	_tabelle_indoli(t, m)
	_tabelle_quirk(t, m)
	_equivalenza(t, m)
	_giornata(t, m)
	_porta_chiusa(t, m)
	_la_notte_fuori_finisce(t, m)
	_corpo_occupato(t, m)
	_corpo_occupato_da_fuori(t, m)
	_riconciliazione(t, m)
	_anagrafe(t, m)
	_niente_pose(t, m)
	_la_finestra_si_legge(t, m)
	_nottambulo_e_lo_stesso_in_due_lingue(t, m)
	m.free()
	_motore_spento(t)


## Il binario ha davvero i metodi? `has_method` interroga l'oggetto vivo:
## un controllo sul sorgente resterebbe verde anche svuotando la funzione.
func _api(t, m) -> void:
	for nome in ["registra", "dimentica", "dimentica_tutti", "conosce", "quanti",
			"riferisci", "avanza", "stato", "da_quanto", "in_finestra",
			"maschera_indole", "indice_quirk", "debug_entita",
			"debug_in_finestra", "debug_quante_pose"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)


## Il GDScript non deve scrivere 0/1/2 a mano da nessuna parte.
func _costanti(t, m) -> void:
	t.eq(m.STATO_SVEGLIO, 0, "STATO_SVEGLIO vale 0")
	t.eq(m.STATO_DORME, 1, "STATO_DORME vale 1")
	t.eq(m.STATO_FUORI, 2, "STATO_FUORI vale 2")


## LE INDOLI SONO ANCORA UNA FONTE UNICA. La tabella dei nomi vive in
## GDScript; il C++ ne tiene solo la traduzione in bit. Aggiungere
## un'indole di là senza insegnarla di qua fa diventare ROSSO questo test —
## è l'unico modo di impedire che due tabelle divergano in silenzio, com'è
## già successo in questo progetto con la scala della ribellione.
func _tabelle_indoli(t, m) -> void:
	var viste := {}
	var somma := 0
	for k in BRAIN.INDOLI:
		var bit: int = m.maschera_indole(PackedStringArray([str(k)]))
		t.ok(bit != 0, "l'indole «%s» ha il suo bit anche in C++" % k)
		t.ok(not viste.has(bit), "e il bit di «%s» non è di nessun altro" % k)
		viste[bit] = true
		somma |= bit
	var accesi := 0
	for i in 32:
		if somma & (1 << i):
			accesi += 1
	t.eq(accesi, BRAIN.INDOLI.size(),
			"le indoli conosciute dal C++ sono ESATTAMENTE quelle del GDScript")
	t.eq(m.maschera_indole(PackedStringArray(["indole_che_non_esiste"])), 0,
			"un nome inventato non accende niente")
	# e la maschera composta è l'OR delle singole
	t.eq(m.maschera_indole(PackedStringArray(["mattiniero", "goloso"])),
			m.maschera_indole(PackedStringArray(["mattiniero"]))
					| m.maschera_indole(PackedStringArray(["goloso"])),
			"due indoli insieme sono l'OR delle loro")


## I quirk vanno per INDICE, e l'ordine conta davvero: `nottambulo` dipende
## da «canta_alla_luna», quindi chi inserisse un quirk in mezzo alla lista
## renderebbe nottambulo il ballerino.
func _tabelle_quirk(t, m) -> void:
	for i in BRAIN.QUIRKS.size():
		t.eq(m.indice_quirk(str(BRAIN.QUIRKS[i])), i,
				"il quirk «%s» è il numero %d anche in C++" % [BRAIN.QUIRKS[i], i])
	t.eq(m.indice_quirk("quirk_inventato"), -1, "un quirk ignoto vale -1")
	t.eq(m.indice_quirk(""), -1, "e nessun quirk pure")


## LA PROVA DI EQUIVALENZA: mille ore della giornata, sei profili, e la
## formula nuova contro quella congelata. Zero divergenze.
func _equivalenza(t, m) -> void:
	var profili := [
		{"nome": "nessuna indole", "ind": [], "q": ""},
		{"nome": "mattiniero", "ind": ["mattiniero"], "q": ""},
		{"nome": "dormiglione", "ind": ["dormiglione"], "q": ""},
		# il caso dell'`elif`: insieme, il mattiniero VINCE
		{"nome": "mattiniero+dormiglione", "ind": ["mattiniero", "dormiglione"], "q": ""},
		{"nome": "sognatore (nottambulo)", "ind": ["sognatore"], "q": ""},
		{"nome": "canta alla luna (nottambulo)", "ind": [], "q": "canta_alla_luna"},
	]
	for p in profili:
		var masc: int = m.maschera_indole(PackedStringArray(p["ind"]))
		var qi: int = m.indice_quirk(str(p["q"]))
		var divergenze := 0
		var veri := 0
		var falsi := 0
		for i in 1001:
			var ora := float(i) / 1000.0
			var nuovo: bool = m.debug_in_finestra(masc, qi, ora)
			var vecchio: bool = ORACOLO.finestra(p["ind"], str(p["q"]), ora)
			if nuovo != vecchio:
				divergenze += 1
			if nuovo:
				veri += 1
			else:
				falsi += 1
		t.eq(divergenze, 0,
				"«%s»: la finestra in C++ è identica a quella di prima" % p["nome"])
		# senza questa, una funzione che torna sempre false passerebbe
		t.ok(veri > 0 and falsi > 0,
				"«%s»: e la finestra si apre E si chiude (%d sì, %d no)"
						% [p["nome"], veri, falsi])


## Una giornata intera, un residente che può entrare e non ha niente da
## fare: deve dormire UNA volta sola, e alle ore giuste.
##
## SI PASSA DA `registra()`, e con profili che cambiano DAVVERO la finestra.
## La prova di equivalenza qui sopra interroga `debug_in_finestra`, che salta
## il componente: con la sola equivalenza, `registra` avrebbe potuto buttare
## via i suoi argomenti e la suite sarebbe rimasta verde. Qui l'indole
## attraversa maschera_indole → DnaComponent → `vista.get<DnaComponent>()`
## dentro `avanza`, che è la catena che il gioco usa davvero.
func _giornata(t, m) -> void:
	_una_giornata(t, m, [], "", 0.80, 0.295, "profilo base")
	_una_giornata(t, m, ["sognatore"], "", 0.92, 0.295, "sognatore (nottambulo)")
	_una_giornata(t, m, [], "canta_alla_luna", 0.92, 0.295, "canta alla luna")
	_una_giornata(t, m, ["mattiniero"], "", 0.80, 0.262, "mattiniero")
	_una_giornata(t, m, ["dormiglione"], "", 0.80, 0.36, "dormiglione")


func _una_giornata(t, m, ind: Array, q: String, atteso_da: float,
		atteso_a: float, nome: String) -> void:
	var id: int = m.registra(PackedStringArray(ind), q)
	var dorme_da := -1.0
	var dorme_a := -1.0
	var passaggi := 0
	var prima: int = m.STATO_SVEGLIO
	var mai_strano := true
	for i in 1000:
		var ora := float(i) / 1000.0
		# il corpo riferisce: nascosto SE stava dormendo (è la marionetta)
		m.riferisci(id, prima == m.STATO_DORME, true, true)
		m.avanza(1.0 / 60.0, ora)
		var st: int = m.stato(id)
		if st != prima:
			passaggi += 1
			if st == m.STATO_DORME:
				dorme_da = ora
			elif prima == m.STATO_DORME:
				dorme_a = ora
		if ora >= 0.40 and ora <= 0.79 and st != m.STATO_SVEGLIO:
			mai_strano = false
		prima = st
	t.ok(mai_strano, "«%s»: in pieno giorno non dorme e non resta fuori" % nome)
	t.almost(dorme_da, atteso_da,
			"«%s»: si addormenta all'ora giusta" % nome, 0.003)
	t.almost(dorme_a, atteso_a,
			"«%s»: e si sveglia all'ora giusta" % nome, 0.003)
	# TRE passaggi, non due, e il motivo è che la finestra ATTRAVERSA la
	# mezzanotte: una giornata 0.000→0.999 comincia già dentro la notte.
	# Quindi: dorme subito (coda della notte prima) → si sveglia a 0.295 →
	# si riaddormenta a 0.80. Se ne contasse di più sarebbe un lampeggio, che
	# è il difetto vero da cui questa asserzione fa la guardia.
	t.eq(passaggi, 3,
			"«%s»: tre passaggi in una giornata che comincia a mezzanotte, e nessun lampeggio"
					% nome)
	m.dimentica(id)


## LA PORTA PUÒ NON APRIRSI. Chi divide la casa con lui gliel'ha chiusa:
## non sparisce dentro, resta fuori. È una scena, non un errore.
func _porta_chiusa(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	var mai_dentro := true
	for _i in 600:
		m.riferisci(id, false, true, false)
		m.avanza(1.0 / 60.0, 0.85)
		if m.stato(id) == m.STATO_DORME:
			mai_dentro = false
	t.eq(m.stato(id), m.STATO_FUORI, "con la porta chiusa resta FUORI")
	t.ok(mai_dentro, "e non entra nemmeno per un frame")
	m.riferisci(id, false, true, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_DORME, "riaperta la porta, entra")
	m.dimentica(id)


## IL CANALE ORFANO CHIUSO: chi una sera non è entrato non deve restare
## curvo per sempre. Passata la notte, torna sveglio (e chi applica gli
## toglie la posa).
func _la_notte_fuori_finisce(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	m.riferisci(id, false, true, false)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_FUORI, "è rimasto fuori")
	m.riferisci(id, false, true, false)
	m.avanza(1.0 / 60.0, 0.50)
	t.eq(m.stato(id), m.STATO_SVEGLIO, "finita la notte, la posa va tolta")
	m.dimentica(id)


## IL CORPO OCCUPATO NON SI STRAPPA VIA. Chi sta suonando al concerto non
## viene spedito a letto a metà pezzo.
func _corpo_occupato(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	for _i in 300:
		m.riferisci(id, false, false, true)
		m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_SVEGLIO, "col corpo occupato non va a dormire")
	m.riferisci(id, false, true, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_DORME, "finito quel che faceva, va a dormire")
	m.dimentica(id)


## E lo stesso da FUORI: con la porta ancora chiusa resta fuori e si tiene
## la sua posa; con la porta riaperta la posa va tolta, ma NON lo si
## spedisce a letto mentre sta facendo qualcosa.
func _corpo_occupato_da_fuori(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	m.riferisci(id, false, true, false)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_FUORI, "rimasto fuori")
	m.riferisci(id, false, false, false)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_FUORI,
			"col corpo occupato e la porta ancora chiusa, resta fuori")
	m.riferisci(id, false, false, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_SVEGLIO,
			"riaperta la porta la posa va tolta, ma a letto ci va quando ha finito")
	m.dimentica(id)


## RICONCILIAZIONE: il CORPO è la verità. Se una promessa lo sveglia, il
## registro lo accetta invece di rimetterlo a dormire un frame dopo.
func _riconciliazione(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	m.riferisci(id, false, true, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_DORME, "dorme")
	# un altro sistema lo sveglia e gli dà da fare (è quel che fa Promesse)
	m.riferisci(id, false, false, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(id), m.STATO_SVEGLIO,
			"il registro ACCETTA la sveglia di un altro sistema")
	m.dimentica(id)


## L'anagrafe, e la versione dell'handle: quello di un congedato non deve
## MAI risolvere a un residente nuovo che ne ha riciclato lo slot.
func _anagrafe(t, m) -> void:
	m.dimentica_tutti()
	t.eq(m.quanti(), 0, "si comincia da zero")
	var a: int = m.registra(PackedStringArray(["goloso"]), "")
	var b: int = m.registra(PackedStringArray(["timido"]), "")
	t.ok(a != b, "due residenti, due handle diversi")
	t.eq(m.quanti(), 2, "e il registro ne conta due")
	# lo si porta a dormire, così lo stato NON è vergine
	m.riferisci(a, false, true, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.stato(a), m.STATO_DORME, "il primo dorme")
	m.dimentica(a)
	t.ok(not m.conosce(a), "congedato: il registro non lo conosce più")
	t.eq(m.stato(a), -1, "e non ha più uno stato")
	t.almost(m.da_quanto(a), -1.0, "né un da-quanto", 0.0001)
	t.eq(m.quanti(), 1, "ne resta uno")
	var c: int = m.registra(PackedStringArray([]), "")
	t.ok(c != a, "il residente nuovo NON riusa l'handle del congedato")
	t.eq(m.stato(c), m.STATO_SVEGLIO, "e nasce sveglio, non nel letto dell'altro")
	m.dimentica_tutti()
	t.eq(m.quanti(), 0, "dimentica_tutti svuota il registro")


## In Fase 1 nessuna entità porta una posa: un componente scritto ogni
## frame e letto da nessuno è un motore acceso a vuoto. Il giorno in cui
## arriva il primo lettore vero, questa asserzione si capovolge APPOSTA.
func _niente_pose(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	m.riferisci(id, false, true, true)
	m.avanza(1.0 / 60.0, 0.85)
	t.eq(m.debug_quante_pose(), 0,
			"nessuna posa istanziata: il TransformComponent è dichiarato, non acceso")
	m.dimentica_tutti()


## `in_finestra()` regge il gate di TUTTE le stravaganze del villaggio
## (Visitors._ciclo_sonno), e finora nessuna asserzione la toccava: se
## regredisse a sempre-vero — per esempio perché `_ultima_ora` smette di
## essere aggiornata e resta a 0.0, che è DENTRO la finestra base — il ciclo
## del sonno continuerebbe a funzionare e i quirk non partirebbero più.
func _la_finestra_si_legge(t, m) -> void:
	var base: int = m.registra(PackedStringArray([]), "")
	var notte: int = m.registra(PackedStringArray(["sognatore"]), "")
	m.riferisci(base, false, true, true)
	m.riferisci(notte, false, true, true)
	m.avanza(1.0 / 60.0, 0.50)
	t.ok(not m.in_finestra(base), "a mezzogiorno la finestra è chiusa")
	t.ok(not m.in_finestra(notte), "per tutti e due")
	m.avanza(1.0 / 60.0, 0.85)
	t.ok(m.in_finestra(base), "alle 0.85 il profilo base è nella sua finestra")
	t.ok(not m.in_finestra(notte),
			"ma il nottambulo NO: la sua comincia alle 0.92")
	m.avanza(1.0 / 60.0, 0.95)
	t.ok(m.in_finestra(notte), "e alle 0.95 sì")
	m.dimentica(base)
	m.dimentica(notte)


## NOTTAMBULO VIVE IN DUE LINGUE: `VillagerBrain.nottambulo()` è rimasta in
## GDScript (la usa l'attività «stella», VillagerBrain.gd:180) e la stessa
## regola è in C++ (chibi::nottambulo). Due implementazioni della stessa
## frase sono esattamente il modo in cui questo progetto ha già visto
## divergere una tabella. Qui si legano: si interroga il cervello VIVO e si
## pretende che il registro la pensi uguale, su TUTTE le indoli e TUTTI i
## quirk.
func _nottambulo_e_lo_stesso_in_due_lingue(t, m) -> void:
	var casi: Array = [[[], ""]]
	for k in BRAIN.INDOLI:
		casi.append([[str(k)], ""])
	for q in BRAIN.QUIRKS:
		casi.append([[], str(q)])
	var divergenze := 0
	var nottambuli := 0
	for c in casi:
		var b: RefCounted = BRAIN.new()
		b.indole = c[0]
		b.quirk = str(c[1])
		var vivo: bool = b.nottambulo()
		if vivo:
			nottambuli += 1
		# un nottambulo va a letto alle 0.92, gli altri alle 0.80: alle 0.85
		# la finestra li separa, ed è l'unico modo di chiederlo al C++ senza
		# aggiungergli un metodo che esiste solo per il test
		var masc: int = m.maschera_indole(PackedStringArray(c[0]))
		var qi: int = m.indice_quirk(str(c[1]))
		if m.debug_in_finestra(masc, qi, 0.85) == vivo:
			divergenze += 1
	t.eq(divergenze, 0,
			"GDScript e C++ sono d'accordo su chi è nottambulo, su tutte le indoli e i quirk")
	t.ok(nottambuli >= 2,
			"e i nottambuli esistono davvero nel campione (%d)" % nottambuli)


## IL MOTORE NON GIRA DA SOLO. Se un domani qualcuno aggiunge un
## _physics_process al C++, la simulazione girerebbe due volte per frame e
## nessun altro test se ne accorgerebbe.
func _motore_spento(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	t.stage(m)
	var id: int = m.registra(PackedStringArray([]), "")
	m.riferisci(id, false, true, true)
	# NIENTE `await`: il runner chiama `run(t)` senza attenderlo
	# (tests/test_runner.gd), quindi una coroutine finirebbe di girare DOPO
	# il rapporto e le sue asserzioni non conterebbero. La prima stesura di
	# questo test faceva `for _i in 20: pass`, che non fa passare un bel
	# niente e non poteva accorgersi di nulla — l'ha trovato una revisione
	# avversariale.
	# Si misura la stessa cosa dal motore: Godot accende il processo di un
	# nodo SOLO se la sua classe sovrascrive `_process`/`_physics_process`.
	# Se un domani qualcuno li aggiunge a EcsMondo, il ciclo del sonno
	# girerebbe due volte per frame e nessun altro test se ne accorgerebbe.
	t.ok(not m.is_processing(),
			"EcsMondo NON ha un _process: il passo lo dà Visitors, e uno solo")
	t.ok(not m.is_physics_processing(),
			"e nemmeno un _physics_process")
	t.almost(m.da_quanto(id), 0.0,
			"in scena e senza `avanza`, il tempo dell'entità non si muove", 0.0001)
	t.eq(m.stato(id), m.STATO_SVEGLIO, "e lo stato non cambia da solo")
	m.dimentica_tutti()
