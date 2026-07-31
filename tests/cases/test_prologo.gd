extends RefCounted
## IL PROLOGO E LE SUE CONSEGUENZE.
##
## Il Prologo promette una cosa difficile: che tre minuti senza nessun
## bivio annunciato lascino segni VERI nel gioco che viene dopo. È una
## promessa che si rompe in silenzio — se i semi non arrivano al Regista,
## se il marchio sbiadisce prima che il giocatore lo noti, se la lettera
## racconta cose che non sono successe, nessuno se ne accorge: il gioco
## gira lo stesso e sembra tutto a posto.
##
## Perciò qui non si controlla che le funzioni esistano: si fa vivere la
## catena intera. Si «gioca» un Prologo (numeri alla mano), si applicano i
## semi a un Regista vero, si mette il marchio in un Limbico vero e lo si
## spegne davvero, giorno per giorno.

const TACCUINO := preload("res://scenes/prologo/Taccuino.gd")
const PROLOGO := preload("res://scenes/prologo/Prologo.gd")
const CUORE := preload("res://scenes/world/CuoreDiMochi.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const DIRECTOR := preload("res://scenes/npc/Director.gd")
const L := preload("res://systems/L10n.gd")


func run(t) -> void:
	_test_le_misure_sono_frazioni(t)
	_test_le_tre_letture(t)
	_test_i_semi_non_decidono(t)
	_test_i_semi_esistono_davvero(t)
	_test_il_marchio(t)
	_test_la_paura_non_sbiadisce_da_sola(t)
	_test_la_paura_si_spegne_tornandoci(t)
	_test_i_vicini_invece_dimenticano(t)
	_test_la_lettera_dice_quel_che_e_successo(t)
	_test_la_lettera_parla_due_lingue(t)
	_test_una_sola_casa_per_gli_appunti(t)
	_test_i_semi_aspettano_il_regista(t)


## Un dizionario di semi ridotto a testo confrontabile, coi conti interi.
static func _conti(semi: Dictionary) -> String:
	var chiavi := semi.keys()
	chiavi.sort()
	var pezzi := PackedStringArray()
	for k in chiavi:
		pezzi.append("%s=%d" % [k, int(semi[k])])
	return " ".join(pezzi)


## Un taccuino «giocato»: i secondi, non le frazioni.
static func _giocato(riparo_s: float, vicinanza: float, fermo_s: float,
		durata_s := 120.0) -> RefCounted:
	var tac := TACCUINO.new()
	tac.riparo = riparo_s
	tac.vicinanza = vicinanza
	tac.fermo = fermo_s
	tac.durata = durata_s
	return tac


# ------------------------------------------------------------- le misure

## IL DIFETTO CHE C'ERA. `riparo` sono SECONDI e le soglie sono FRAZIONI:
## confrontarli direttamente dichiarava «si è messa al riparo» a chiunque
## ci fosse passata sotto un secondo e mezzo, e la lettera del Gufo
## raccontava una notte che non era successa.
func _test_le_misure_sono_frazioni(t) -> void:
	var sfiorato := _giocato(1.5, 0.0, 0.0, 120.0)
	t.eq(sfiorato.scelta_riparo(), "acqua",
			"un secondo e mezzo sotto la foglia su due minuti NON è ripararsi")
	t.almost(sfiorato.frazione_al_riparo(), 0.0125,
			"la frazione al riparo è secondi/durata", 0.001)
	var dentro := _giocato(60.0, 0.0, 0.0, 120.0)
	t.eq(dentro.scelta_riparo(), "riparo", "mezza tempesta al coperto sì")
	# e la stessa mezz'ora dentro una tempesta lunga il triplo non basta
	t.eq(_giocato(60.0, 0.0, 0.0, 400.0).scelta_riparo(), "",
			"la stessa mezz'ora in una tempesta tre volte più lunga non decide")
	# una durata a zero non deve far esplodere niente
	var vuoto := TACCUINO.new()
	t.ok(vuoto.scelta_riparo() != null and vuoto.semi() != null,
			"un taccuino vuoto non fa danni")


func _test_le_tre_letture(t) -> void:
	t.eq(_giocato(0.0, 0.0, 0.0).scelta_riparo(), "acqua", "zero riparo -> acqua")
	t.eq(_giocato(30.0, 0.0, 0.0).scelta_riparo(), "", "un quarto: non si giudica")
	t.eq(_giocato(0.0, 0.9, 0.0).scelta_erba(), "vicino", "col naso addosso -> vicino")
	t.eq(_giocato(0.0, 0.1, 0.0).scelta_erba(), "indietro", "da lontano -> indietro")
	t.eq(_giocato(0.0, 0.4, 0.0).scelta_erba(), "", "a metà strada: non si giudica")
	t.ok(_giocato(0.0, 0.0, 40.0).e_stata_a_guardare(), "un terzo ferma -> guardava")
	t.ok(not _giocato(0.0, 0.0, 10.0).e_stata_a_guardare(), "dieci secondi no")


# --------------------------------------------------- i semi del Regista

## «Inclinati, mai decisi». Il Prologo mette il pollice sulla bilancia; a
## dire chi sei ci deve arrivare il gioco vero. Qui si prende un Regista
## VERO, gli si danno i semi e gli si chiede il profilo: deve ancora dire
## «curioso». Poi basta un gesto solo perché penda.
func _test_i_semi_non_decidono(t) -> void:
	for tac in [_giocato(90.0, 0.9, 60.0), _giocato(0.0, 0.0, 0.0),
			_giocato(90.0, 0.0, 0.0), _giocato(0.0, 0.9, 60.0)]:
		var regista = DIRECTOR.new()
		for evento in tac.semi():
			for i in int(tac.semi()[evento]):
				regista.note(evento)
		t.eq(regista.profilo(), "curioso",
				"dopo il Prologo il gioco non ha ancora deciso chi sei")
		# ...e il primo gesto vero nel villaggio fa pendere la bilancia
		var piu_alto := ""
		var quanti := 0
		for evento in tac.semi():
			if int(tac.semi()[evento]) > quanti:
				quanti = int(tac.semi()[evento])
				piu_alto = str(evento)
		if piu_alto != "":
			regista.note(piu_alto)
			t.ok(regista.profilo() != "curioso",
					"ma un gesto solo, dopo, basta a farla pendere (%s)" % piu_alto)
		regista.free()


## FONTE UNICA: i semi nominano contatori che devono esistere in
## `Director.ASSI`. Un asse rinominato lì deve diventare rosso QUI, non
## scollegare il Prologo in silenzio (i suoi eventi finirebbero in un
## contatore che nessun asse guarda, e il seme non peserebbe mai).
func _test_i_semi_esistono_davvero(t) -> void:
	var noti := {}
	for asse in DIRECTOR.ASSI:
		for evento in DIRECTOR.ASSI[asse]:
			noti[str(evento)] = true
	var visti := {}
	for tac in [_giocato(90.0, 0.9, 60.0), _giocato(0.0, 0.0, 0.0),
			_giocato(90.0, 0.0, 0.0), _giocato(0.0, 0.9, 60.0)]:
		for evento in tac.semi():
			visti[str(evento)] = true
			t.ok(noti.has(str(evento)),
					"il seme '%s' è un contatore vero di Director.ASSI" % evento)
			t.ok(int(tac.semi()[evento]) <= 2,
					"nessun seme supera i due (o deciderebbe il profilo)")
	t.ok(visti.size() >= 3, "il Prologo semina su più assi (%d)" % visti.size())


# ------------------------------------------------------------- il marchio

func _test_il_marchio(t) -> void:
	var peggio: Dictionary = _giocato(0.0, 0.0, 0.0).marchio()
	var meglio: Dictionary = _giocato(90.0, 0.9, 60.0).marchio()
	t.ok(float(peggio["carica"]) < float(meglio["carica"]),
			"la notte passata sotto l'acqua e da sola pesa più di tutte")
	for m: Dictionary in [peggio, meglio]:
		t.ok(float(m["carica"]) <= -0.25 and float(m["carica"]) >= -1.0,
				"il marchio resta fra -1 e -0.25: una paura c'è sempre")
		t.ok(int(m["conferme"]) >= 2,
				"nasce già confermato, o la prima pioggia se lo porterebbe via")
	# e la paura vera che ne esce fa TRASALIRE, che è il punto
	var lim = LIMBICO.new()
	lim.setup({})
	lim.marchi["luogo|" + CUORE.MARCHIO] = peggio
	var sussulto: Dictionary = lim.percepisci("", CUORE.MARCHIO)
	t.eq(str(sussulto["reazione"]), "trasalisce",
			"alle prime gocce il corpo parte prima della testa")


## Il marchio del temporale NON deve spegnersi da solo. Con lo sbiadimento
## normale dei marchi (0.12 al giorno) una paura da -0.85 sparisce in
## sette giorni: il giocatore non farebbe in tempo ad accorgersi che
## c'era, e non ci sarebbe niente da spegnere.
func _test_la_paura_non_sbiadisce_da_sola(t) -> void:
	var lim = LIMBICO.new()
	lim.setup({})
	lim.marchi["luogo|" + CUORE.MARCHIO] = _giocato(0.0, 0.0, 0.0).marchio()
	var prima: float = absf(lim.carica_di(CUORE.MARCHIO))
	for giorno in 60:
		lim.passa_giorno(true, false)
	t.almost(absf(lim.carica_di(CUORE.MARCHIO)), prima,
			"dopo due mesi senza pioggia la paura è ancora tutta lì", 0.001)
	t.ok(absf(lim.carica_di(CUORE.MARCHIO)) > CUORE.GUARITA,
			"e trasalisce ancora")


## …e si spegne TORNANDOCI SOTTO. Una seduta al giorno, come nel gioco:
## si contano i giorni che servono davvero.
func _test_la_paura_si_spegne_tornandoci(t) -> void:
	var lim = LIMBICO.new()
	lim.setup({})
	lim.marchi["luogo|" + CUORE.MARCHIO] = _giocato(0.0, 0.0, 0.0).marchio()
	var giorni := 0
	while absf(lim.carica_di(CUORE.MARCHIO)) > CUORE.GUARITA and giorni < 100:
		lim.passa_giorno(true, false)
		lim.visita_serena(CUORE.MARCHIO)     # una sola seduta, come in gioco
		giorni += 1
	t.ok(giorni >= 4 and giorni <= 12,
			"ci vogliono parecchi giorni di pioggia stando fuori (%d)" % giorni)
	t.ok(absf(lim.carica_di(CUORE.MARCHIO)) <= CUORE.GUARITA,
			"ma alla fine si spegne davvero")
	# e da lì in poi NON trasalisce più: è la prova che la guarigione si vede
	t.ok(str(lim.percepisci("", CUORE.MARCHIO)["reazione"]) != "trasalisce",
			"e alle gocce non fa più quel mezzo passo indietro")


## La deroga vale per Mochi e per nessun altro: le paure dei vicini
## devono continuare a consumarsi col tempo, come hanno sempre fatto.
func _test_i_vicini_invece_dimenticano(t) -> void:
	var lim = LIMBICO.new()
	lim.setup({})
	lim.marchi["luogo|catasta"] = {"carica": -0.85, "conferme": 2}
	for giorno in 10:
		lim.passa_giorno()
	t.almost(lim.carica_di("catasta"), 0.0,
			"il vicino spaventato dalla catasta, in dieci giorni, se ne dimentica", 0.001)


# -------------------------------------------------------------- la lettera

## La lettera deve raccontare LA NOTTE CHE È SUCCESSA. Una lettera che
## dice «ti sei riparata» a chi è rimasta sotto l'acqua è peggio di
## nessuna lettera: dice al giocatore che il gioco non stava guardando.
func _test_la_lettera_dice_quel_che_e_successo(t) -> void:
	var prima := L.lingua_corrente()
	L.imposta("it")
	var riparata := L.rendi(CUORE._lettera(_giocato(90.0, 0.9, 60.0)))
	var bagnata := L.rendi(CUORE._lettera(_giocato(0.0, 0.05, 0.0)))
	t.ok(riparata.contains("sotto la foglia grande"),
			"a chi si è riparata dice della foglia")
	t.ok(bagnata.contains("Non ci sei andata"),
			"a chi è rimasta fuori dice che non ci è andata")
	t.ok(riparata.contains("VICINO"), "e che è andata a vedere cos'era")
	t.ok(bagnata.contains("passo indietro"), "o che ha fatto un passo indietro")
	t.ok(riparata.contains("sei stata ferma"), "e che è stata a guardare")
	t.ok(not bagnata.contains("sei stata ferma"), "…solo se è successo")
	# non rimprovera MAI: è la regola del Prologo
	for rimprovero in ["dovevi", "avresti dovuto", "hai sbagliato", "peccato"]:
		for lettera in [riparata, bagnata]:
			t.ok(not lettera.to_lower().contains(rimprovero),
					"il Gufo non rimprovera («%s»)" % rimprovero)
	# e firma sempre, comunque sia andata
	for lettera in [riparata, bagnata]:
		t.ok(lettera.strip_edges().ends_with("Il Gufo"), "la lettera è firmata")
		t.ok(lettera.length() > 200, "ed è una lettera vera, non due righe")
	L.imposta(prima)


## La prova che conta per la posta: la lettera nasce nel Prologo, passa da
## una coda su disco e si apre il mattino dopo. Deve parlare la lingua di
## CHI LA APRE (vedi Mail.rendi e test_posta_lingua).
func _test_la_lettera_parla_due_lingue(t) -> void:
	var prima := L.lingua_corrente()
	var tac := _giocato(90.0, 0.9, 60.0)
	L.imposta("it")
	var italiano := L.rendi(CUORE._lettera(tac))
	L.imposta("en")
	var inglese := L.rendi(CUORE._lettera(tac))
	t.ok(italiano != inglese, "la lettera del Prologo si traduce")
	t.ok(not inglese.contains("Ti ho vista arrivare"),
			"in inglese non resta un pezzo d'italiano")
	t.ok(inglese.contains("The Owl"), "ed è firmata dal Gufo inglese")
	t.ok(inglese.contains("big leaf"), "coi fatti giusti dentro")
	L.imposta(prima)


# ------------------------------------------------------------ il passaggio

## Il Prologo scrive gli appunti in un file e il villaggio li va a
## prendere. Le due stringhe stanno in due file che non si conoscono (ed
## è voluto: il villaggio non deve caricare la scena del Prologo). Se
## divergono, il passaggio si rompe e nessuno se ne accorge — il gioco
## parte lo stesso, semplicemente senza il Prologo dentro.
func _test_una_sola_casa_per_gli_appunti(t) -> void:
	var cuore = CUORE.new()
	t.eq(cuore._percorso_appunti(), PROLOGO.APPUNTI,
			"il Prologo scrive dove il villaggio va a leggere")
	cuore.free()
	# e il giro completo su disco: quello che il Prologo salva, il
	# villaggio lo rilegge uguale (interi e float compresi)
	var tac := _giocato(37.5, 0.83, 21.25, 118.0)
	var scritto := JSON.stringify(tac.da_salvare())
	var riletto = TACCUINO.da_dizionario(JSON.parse_string(scritto))
	t.eq(riletto.scelta_riparo(), tac.scelta_riparo(), "il riparo sopravvive al disco")
	t.eq(riletto.scelta_erba(), tac.scelta_erba(), "e così l'erba")
	t.eq(riletto.e_stata_a_guardare(), tac.e_stata_a_guardare(), "e l'attesa")
	t.eq(_conti(riletto.semi()), _conti(tac.semi()), "e i semi vengono identici")


## I SEMI ASPETTANO. Il Regista nasce figlio runtime di CozyWorld, che
## costruisce il mondo su più frame: quando il cuore di Mochi si sveglia,
## il gruppo "regista" è ancora VUOTO. La prima versione consegnava lì per
## lì e i semi finivano nel niente — marchio e lettera arrivavano, i
## contatori restavano a zero, e non lo diceva nessuno.
##
## Quindi si mettono in attesa e si consegnano appena c'è qualcuno. Qui si
## controlla il primo pezzo (che vengano PARCHEGGIATI, non buttati) e che
## sopravvivano al salvataggio, che è dove finiscono se il giocatore
## chiude il gioco proprio in quei tre frame.
func _test_i_semi_aspettano_il_regista(t) -> void:
	var cuore = CUORE.new()
	cuore.limbico = LIMBICO.new()
	cuore.limbico.setup({})
	var tac := _giocato(90.0, 0.9, 60.0)
	cuore._appunti = tac.da_salvare()
	cuore._applica_appunti()

	t.ok(not cuore.limbico.marchi.is_empty(), "il marchio si mette subito")
	t.eq(_conti(cuore._semi_in_attesa), _conti(tac.semi()),
			"i semi restano in attesa invece di essere consegnati a nessuno")
	t.ok(cuore._consegnato, "e il Prologo risulta consegnato una volta sola")

	# il giro dal salvataggio: i semi non consegnati non si perdono
	var dopo = CUORE.new()
	dopo.limbico = LIMBICO.new()
	dopo.load_extra(JSON.parse_string(JSON.stringify(cuore.save_extra())))
	# si confrontano i CONTI, non la scrittura: il giro dal JSON riporta
	# indietro dei float (2 diventa 2.0), ed è tutto a posto — chi li
	# consegna li legge con int()
	t.eq(_conti(dopo._semi_in_attesa), _conti(tac.semi()),
			"e sopravvivono a un gioco chiuso prima che il Regista nascesse")
	t.ok(dopo._consegnato,
			"riaprendo il villaggio il Prologo non si riapplica da capo")
	t.almost(absf(dopo.limbico.carica_di(CUORE.MARCHIO)),
			absf(cuore.limbico.carica_di(CUORE.MARCHIO)),
			"e la paura è quella di ieri, non una nuova", 0.001)
	cuore.free()
	dopo.free()
