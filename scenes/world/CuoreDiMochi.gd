extends Node

## IL CUORE DI MOCHI — l'unico pezzo di apparato affettivo che appartiene
## a chi gioca, e non a un vicino.
##
## Fino a ieri il Limbico era roba da NPC: i residenti avevano marchi,
## sorprese, umore, e Mochi era l'unica creatura del villaggio senza niente
## sotto. Adesso ne ha un pezzo — uno solo, e non per completezza: perché
## il Prologo gliel'ha messo dentro.
##
## LA CATENA, per intero:
##   1. Nel Prologo c'è un temporale vero (l'unico del gioco: nel villaggio
##      non ce ne sono mai, ed è una regola — vedi Weather.gd). Quella
##      notte, a seconda di come l'hai passata, le lascia un MARCHIO più o
##      meno pesante (Taccuino.marchio()).
##   2. Nel villaggio non tuona mai. Ma piove. E il corpo non fa le
##      distinzioni che fa la testa: la pioggia È il temporale, per lei.
##      Alle prime gocce trasalisce — orecchie giù, un passo indietro — e
##      non c'è nessuna scritta che spieghi perché.
##   3. I vicini se ne accorgono e vengono a starle vicino: quel sistema
##      c'era già (Visitors.conforta_mochi("pioggia")) e non aveva un
##      motivo. Adesso ce l'ha.
##   4. E si può GUARIRE. Stare sotto la pioggia senza che succeda niente
##      spegne il marchio un po' per volta — è l'estinzione, la stessa che
##      vale per i residenti (Limbico.visita_serena). Ci vogliono mesi. Il
##      giorno in cui non trasalisce più, il Gufo se ne accorge.
##
## Nessuno di questi quattro passaggi viene mai spiegato al giocatore. Il
## solo posto in cui il gioco ne parla è la prima lettera, e parla del
## PRIMO — di quella notte lì, non di quello che ha prodotto.

const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const TACCUINO := preload("res://scenes/prologo/Taccuino.gd")

## La chiave del marchio. È il temporale, non la pioggia: la pioggia è
## solo quello che glielo ricorda.
const MARCHIO := "temporale"

## Sotto questa carica (in valore assoluto) la paura è passata: non
## trasalisce più, e il Gufo scrive.
const GUARITA := 0.09

## Quanti secondi di pioggia serena, in una volta sola, per una seduta di
## estinzione. Venticinque come la premura dei vicini: chi resta fuori
## sotto l'acqua abbastanza da farsi raggiungere è anche chi sta
## disimparando ad avere paura, ed è giusto che siano lo stesso gesto.
const SEDUTA := 25.0

## QUANTO CI VUOLE, e perché è scritto qui invece che sperato.
##
## Una seduta al giorno, non una ogni venticinque secondi: `visita_serena`
## toglie il 38% alla volta, e senza il tetto giornaliero una paura nata
## per durare mesi si spegneva in un minuto e quaranta di pioggia, tutta
## di fila, il primo giorno.
##
## Col tetto: da -0.85 servono sei giorni di pioggia in cui sei rimasta
## fuori (0.85 × 0.62⁶ = 0.077, sotto GUARITA). Sei giorni in cui piove E
## in cui il giocatore, senza sapere di star facendo qualcosa, si ferma
## sotto l'acqua invece di correre al riparo. Nel gioco vero sono
## settimane, spesso mesi.
const SEDUTE_AL_GIORNO := 1

var limbico: RefCounted

var _player: Node3D
var _mochi: Node3D
var _weather: Node3D
var _daynight: Node3D
var _build: Node3D
var _mail: Node
var _sfx

var _pioggia_prima := false
var _sereno_acc := 0.0
var _sedute_oggi := 0
var _trasalito_oggi := false
var _guarigione_detta := false
var _appunti := {}            # le misure del Prologo, se ce ne sono
var _consegnato := false      # semi e lettera si applicano UNA volta sola
var _semi_in_attesa := {}     # i contatori da dare al Regista appena nasce


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("cuore_di_mochi")
	limbico = LIMBICO.new()
	# Mochi non ha un carattere in tabella come i vicini: la sua reattività
	# è quella media, e quello che la rende lei è il marchio, non i tratti
	limbico.setup({})
	(func() -> void:
		_player = get_node_or_null("../Player")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_weather = get_node_or_null("../Weather")
		_daynight = get_node_or_null("../DayNight")
		_build = get_tree().get_first_node_in_group("build_system")
		_mail = get_node_or_null("../Mail")
		_sfx = get_node_or_null(^"/root/Sfx")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_on_nuovo_giorno)
		_raccogli_il_prologo()).call_deferred()


# ============================================================== il Prologo

## Gli appunti di quella notte, se il Prologo li ha lasciati. Si leggono
## una volta sola: da lì in poi vivono dentro il salvataggio del villaggio,
## e il file su disco non serve più a nessuno.
func _raccogli_il_prologo() -> void:
	if _consegnato or not _appunti.is_empty():
		_applica_appunti()
		return
	if not FileAccess.file_exists(_percorso_appunti()):
		return
	var f := FileAccess.open(_percorso_appunti(), FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is not Dictionary:
		return
	_appunti = d
	_applica_appunti()


## Il percorso degli appunti. Scritto qui e non importato dal Prologo di
## proposito: il villaggio non deve caricare la scena del Prologo per
## sapere dove guardare, e se un domani il Prologo sparisse qui non si
## romperebbe niente (il file non c'è, e il villaggio parte com'è sempre
## partito). Un test tiene le due stringhe allineate.
func _percorso_appunti() -> String:
	return "user://prologo.json"


func _applica_appunti() -> void:
	if _consegnato or _appunti.is_empty():
		return
	_consegnato = true
	var t: RefCounted = TACCUINO.da_dizionario(_appunti)

	# 1. IL MARCHIO. Non lo si «imposta»: glielo si mette dentro come se
	#    quella notte l'avesse appena vissuta.
	limbico.marchi["luogo|" + MARCHIO] = t.marchio()

	# 2. I SEMI DEL REGISTA. I suoi contatori partono inclinati — mai
	#    decisi (Taccuino.semi() garantisce il massimo di due per asse).
	#    Il giocatore non lo sa e non lo saprà mai: si accorgerà solo che
	#    i vicini, il primo giorno, gli girano intorno in un certo modo.
	#
	#    Si mettono IN ATTESA e non si consegnano adesso: il Regista nasce
	#    figlio runtime di CozyWorld, che costruisce il mondo su più
	#    frame, e quando questo nodo si sveglia lui non c'è ancora. La
	#    prima versione li dava «a tutti quelli del gruppo regista», il
	#    gruppo era vuoto, e i semi finivano nel niente in perfetto
	#    silenzio: il marchio e la lettera arrivavano, i contatori no.
	_semi_in_attesa = t.semi()

	# 3. LA LETTERA. Arriva col primo mattino, come tutta la posta: non
	#    c'è un momento speciale, non c'è una cutscene. È solo la prima
	#    cosa che trovi nella cassetta — e ti racconta te.
	if _mail and _mail.has_method("queue_letter"):
		_mail.call("queue_letter", {
			"from_key": "Il Gufo",
			"text_key": _lettera(t),
			"gift": false,
		})
	if _build and _build.has_method("request_save"):
		_build.call("request_save")


## La lettera del Prologo: l'apertura, quello che il Gufo ha visto
## (Taccuino.righe()), e la firma.
static func _lettera(t: RefCounted) -> Array:
	var parti: Array = [{"k": "Ti ho vista arrivare, l'altra notte.\nEri piccola e pioveva come non piove mai.\nNon ti ho aiutata: volevo vedere cosa facevi.\n\n"}]
	parti.append_array(t.righe())
	return parti


# ============================================================ la pioggia

func _process(delta: float) -> void:
	_consegna_i_semi()
	if _weather == null or _mochi == null or _player == null:
		return
	var piove: bool = bool(_weather.call("is_raining"))
	if piove and not _pioggia_prima:
		_prime_gocce()
	if not piove:
		_sereno_acc = 0.0
	elif not _al_coperto():
		# LA SEDUTA. Restare sotto l'acqua mentre NON succede niente è
		# esattamente ciò che spegne una paura appresa. Non serve un
		# oggetto, non serve un vicino, non serve saperlo.
		_sereno_acc += delta
		if _sereno_acc >= SEDUTA and _sedute_oggi < SEDUTE_AL_GIORNO:
			_sereno_acc = 0.0
			_sedute_oggi += 1
			_seduta_serena()
	else:
		# al coperto non si guarisce: si sta al riparo, che è un'altra cosa
		_sereno_acc = 0.0
	_pioggia_prima = piove


## I semi aspettano che il Regista nasca, e appena c'è glieli si dà. Una
## volta sola: `_semi_in_attesa` si svuota, e non viene più riempito
## (`_consegnato` resta true anche nei salvataggi).
func _consegna_i_semi() -> void:
	if _semi_in_attesa.is_empty():
		return
	var registi := get_tree().get_nodes_in_group("regista")
	if registi.is_empty():
		return
	for regista in registi:
		for evento in _semi_in_attesa:
			for i in int(_semi_in_attesa[evento]):
				regista.call("note", evento)
	_semi_in_attesa = {}
	if _build and _build.has_method("request_save"):
		_build.call("request_save")


## Le prime gocce del giorno. Il corpo parte prima della testa: è la
## strada veloce del Limbico, la stessa dei vicini.
func _prime_gocce() -> void:
	if _trasalito_oggi or _al_coperto():
		return
	var sussulto: Dictionary = limbico.percepisci("", MARCHIO)
	if str(sussulto.get("reazione", "")) != "trasalisce":
		return
	_trasalito_oggi = true
	var forza := float(sussulto.get("forza", 0.0))
	_mochi.call("forza_espressione", "spavento", clampf(forza * 1.3, 0.4, 1.0))
	# un passo indietro che non toglie il controllo a nessuno: due decimi
	# di secondo di corpo, e poi si torna a giocare
	var tw := create_tween()
	tw.tween_property(_mochi, "position:z", 0.10 * forza, 0.09) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mochi, "position:z", 0.0, 0.5) \
			.set_trans(Tween.TRANS_SINE)
	if _sfx:
		_sfx.play("heartbeat", -20.0, 1.15)


## Venticinque secondi sotto l'acqua senza che sia successo niente. Il
## marchio si spegne di un altro pezzo (Limbico.visita_serena), e prima o
## poi si spegne del tutto.
func _seduta_serena() -> void:
	limbico.visita_serena(MARCHIO)
	if _guarigione_detta or paura() > GUARITA:
		return
	_guarigione_detta = true
	# IL GIORNO IN CUI NON HA PIÙ PAURA. Nessun trionfo, nessuna medaglia,
	# nessun risultato sbloccato: una riga del Gufo, che se n'è accorto
	# perché guarda. Il giocatore, quasi sempre, non saprà nemmeno di aver
	# fatto qualcosa — saprà solo che una cosa è finita.
	if _mail and _mail.has_method("queue_letter"):
		_mail.call("queue_letter", {
			"from_key": "Il Gufo",
			"text_key": "Oggi pioveva e tu non hai fatto quella cosa\nche facevi sempre, quel mezzo passo indietro.\nCredo che tu non te ne sia neanche accorta.\n\nCi hai messo dei mesi. Nessuno ti aveva chiesto niente.",
			"gift": false,
		})
	if _build and _build.has_method("request_save"):
		_build.call("request_save")


func _al_coperto() -> bool:
	if _build == null or _player == null:
		return false
	var cella := Vector2i(roundi(_player.global_position.x),
			roundi(_player.global_position.z))
	return bool(_build.call("has_cover", cella))


func _on_nuovo_giorno(_giorno: int) -> void:
	_trasalito_oggi = false
	_sedute_oggi = 0
	# `false`: il marchio del temporale NON sbiadisce da solo. Si spegne
	# solo tornandoci sotto (vedi Limbico.passa_giorno).
	limbico.passa_giorno(1.0, false)


# ============================================================== letture

## Quanta paura del temporale le è rimasta, 0..1. La leggono i test, e
## potrebbe leggerla un domani chiunque voglia raccontarla.
func paura() -> float:
	return absf(limbico.carica_di(MARCHIO))


## Ne ha ancora abbastanza da trasalire?
func ha_ancora_paura() -> bool:
	return paura() > GUARITA


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"cuore_mochi": {
		"marchi": limbico.marchi,
		"umore": limbico.umore,
		"prologo": _appunti,
		"consegnato": _consegnato,
		"guarigione_detta": _guarigione_detta,
		# se il gioco si chiude fra la consegna e la nascita del Regista,
		# i semi non si perdono: aspettano nel salvataggio
		"semi_in_attesa": _semi_in_attesa,
	}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("cuore_mochi")
	if d is not Dictionary:
		return
	limbico.marchi = d.get("marchi", {})
	limbico.umore = float(d.get("umore", 0.0))
	_appunti = d.get("prologo", {})
	_consegnato = bool(d.get("consegnato", false))
	_guarigione_detta = bool(d.get("guarigione_detta", false))
	_semi_in_attesa = d.get("semi_in_attesa", {})
