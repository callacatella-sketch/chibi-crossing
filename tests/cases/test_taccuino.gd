extends RefCounted
## IL TACCUINO DEL GUFO — la prova che il gioco guarda, e che NON inventa.
##
## Questa meccanica ha una modalità di guasto sola, ed è catastrofica: una
## frase citata a vuoto. «Ti ho vista fermarti davanti a una farfalla» detto
## a chi stava cercando il menu non attenua l'effetto, LO INVERTE — e da
## quel momento il giocatore non crede più a nessuna lettera del gioco.
##
## Perciò questo test è scritto al rovescio rispetto al solito: la maggior
## parte delle prove verifica che il taccuino STIA ZITTO. Per ogni
## condizione del giudizio si prende una finestra buona e si guasta QUELLA
## SOLA cosa: se il taccuino parla comunque, quella condizione era
## decorativa e il falso positivo è già in casa.
##
## E la macchina a stati non si prova dalla facciata: si fabbricano un
## giocatore, un arbitro e un mondo finti, e si fa girare `_process` a mano
## recitando il gesto — camminare verso, fermarsi, ripartire. Un test che
## si accontentasse di chiamare i giudizi puri resterebbe verde anche se il
## `_process` non li chiamasse mai.

const TAC := preload("res://scenes/npc/Taccuino.gd")
const DIR := preload("res://scenes/npc/Director.gd")


## Il giocatore finto: un corpo vero, così `velocity` e
## `is_physics_processing()` sono quelli del motore e non una finzione mia.
class PlayerFinto extends CharacterBody3D:
	func _init() -> void:
		set_physics_process(true)


class ArbitroFinto extends Node:
	var risposta := {}
	func candidato() -> Dictionary:
		return risposta


class RegistaFinto extends Node:
	var pagine: Array = []
	func annota(p: Dictionary) -> void:
		pagine.append(p)


class BuildFinto extends Node3D:
	var superficie := "grass"
	var vicino := false
	var celle := 0
	func surface_at(p: Vector3) -> String:
		# «accanto» si chiede con un offset di un metro: si risponde a quello
		if not is_zero_approx(p.x) or not is_zero_approx(p.z):
			return "stone" if vicino else "grass"
		return superficie
	func get_placed_by_name(_n: String) -> Array:
		var out: Array = []
		for i in celle:
			out.append(self)
		return out


class MailFinta extends Node:
	var coda: Array = []
	func queue_letter(l: Dictionary) -> void:
		coda.append(l)


## Node3D e non Node: `_daynight` e' tipizzato Node3D sia nel Regista sia
## nel taccuino, e una `set()` col tipo sbagliato scivola via IN SILENZIO —
## il campo resta null e il sistema tace senza dire perche'.
class GiornoFinto extends Node3D:
	var day := 5
	var time := 0.5
	func is_night() -> bool:
		return false


func run(t) -> void:
	_test_esitazione_vera(t)
	_test_esitazione_ogni_valvola(t)
	_test_sentiero(t)
	_test_sosta(t)
	_test_contesto(t)
	_test_le_pagine(t)
	_test_le_lettere(t)
	_test_la_consegna(t)
	_test_il_gesto_vero(t)
	_test_il_gesto_smentito(t)


# ---------------------------------------------------------- i giudizi puri

## La finestra perfetta: ci si è andati, si è stati fermi, si è ripartiti a
## piedi, non si è premuto niente. Questa DEVE parlare.
func _finestra_buona() -> Dictionary:
	return {
		"fermo": TAC.ESITA_FERMA + 0.4,
		"durata": TAC.ESITA_FERMA + 1.0,
		"avvicinamento": TAC.ESITA_AVVICINAMENTO + 0.3,
		"riparte": TAC.ESITA_RIPARTE + 0.2,
		"premuto": false,
		"guasta": false,
		"vivo": true,
	}


func _test_esitazione_vera(t) -> void:
	t.ok(TAC.giudica_esitazione(_finestra_buona()),
			"la finestra piena è un'esitazione: ci sei andata, ti sei fermata, sei ripartita")


## OGNI VALVOLA, UNA PER UNA. Si guasta una cosa sola e si pretende
## silenzio: è l'unico modo di sapere che quella condizione serve davvero.
func _test_esitazione_ogni_valvola(t) -> void:
	var casi := {
		"premuto": {"premuto": true},
		"guasta": {"guasta": true},
		"fermo": {"fermo": TAC.ESITA_FERMA - 0.1},
		"durata": {"durata": TAC.ESITA_MAX + 1.0},
		"avvicinamento": {"avvicinamento": TAC.ESITA_AVVICINAMENTO - 0.1},
		"riparte": {"riparte": TAC.ESITA_RIPARTE - 0.1},
		"vivo": {"vivo": false},
	}
	var perche := {
		"premuto": "ha premuto il tasto: non è una rinuncia, è un gesto",
		"guasta": "una valvola l'ha annullata (pannello, salto, congelamento)",
		"fermo": "ha solo rallentato: fermarsi è un'altra cosa",
		"durata": "è stata lì troppo: è una sosta, la racconta un'altra pagina",
		"avvicinamento": "le è capitato davanti, non ci è andata",
		"riparte": "non se n'è andata camminando (teletrasporto, congelamento)",
		"vivo": "la cosa non c'è più: gliel'ha presa qualcun altro",
	}
	for k in casi:
		var f := _finestra_buona()
		for campo in (casi[k] as Dictionary):
			f[campo] = (casi[k] as Dictionary)[campo]
		t.ok(not TAC.giudica_esitazione(f),
				"TACE se %s — %s" % [k, perche[k]])
	# e una finestra VUOTA non parla per default (i campi mancanti valgono 0)
	t.ok(not TAC.giudica_esitazione({}), "una finestra vuota non è un'esitazione")


func _test_sentiero(t) -> void:
	var n: int = TAC.SENT_CAMPIONI
	var celle: int = TAC.SENT_CELLE_MIN
	t.eq(TAC.giudica_sentiero(n, n, celle), "sentiero_fedele",
			"tutti i passi sul selciato: ci cammini sempre")
	t.eq(TAC.giudica_sentiero(0, n, celle), "sentiero_ignorato",
			"nessun passo sul selciato: l'hai fatto e non lo usi")
	# LA FASCIA GRIGIA, che è la risposta normale: chi cammina un po' sopra
	# e un po' accanto non ha nessuna abitudine da farsi raccontare
	t.eq(TAC.giudica_sentiero(n / 2, n, celle), "",
			"a metà e metà il taccuino TACE: non c'è niente da dire")
	t.eq(TAC.giudica_sentiero(int(float(n) * 0.7), n, celle), "",
			"…e anche al 70%: sotto la soglia non è un'abitudine")
	# non si giudica con pochi passi
	t.eq(TAC.giudica_sentiero(n - 1, n - 1, celle), "",
			"con pochi campioni non si giudica nessuno")
	# né con una piastrella al posto di un sentiero
	t.eq(TAC.giudica_sentiero(n, n, celle - 1), "",
			"e senza un sentiero vero non c'è niente da essere fedeli a")


func _test_sosta(t) -> void:
	var buona: float = (TAC.SOSTA_MIN + TAC.SOSTA_MAX) * 0.5
	t.ok(TAC.giudica_sosta(buona, 0, 200, true, false),
			"ferma a lungo, arrivata camminando: è una sosta")
	t.ok(not TAC.giudica_sosta(TAC.SOSTA_MIN - 1.0, 0, 100, true, false),
			"TACE sotto il minimo: è un rallentamento, non una sosta")
	# LA TAZZA DI CAFFÈ: sopra il tetto non è contemplazione, è la vita vera
	t.ok(not TAC.giudica_sosta(TAC.SOSTA_MAX + 1.0, 0, 400, true, false),
			"TACE sopra il tetto: è andata a fare altro, e il Gufo non lo sa")
	# INCASTRATA IN UN MURO: tiene premuta una direzione e non si muove
	t.ok(not TAC.giudica_sosta(buona, 100, 200, true, false),
			"TACE se spingeva contro un muro: non era ferma, era bloccata")
	t.ok(TAC.giudica_sosta(buona, 5, 200, true, false),
			"…ma qualche campione di spinta è l'inerzia, e si tollera")
	t.ok(not TAC.giudica_sosta(buona, 0, 200, false, false),
			"TACE se non ci è arrivata camminando: la sosta è una SCELTA")
	t.ok(not TAC.giudica_sosta(buona, 0, 200, true, true),
			"TACE se una valvola l'ha guastata")


## Il contesto ha un ORDINE, e non è arbitrario: se piove, quello che hai
## davanti è la pioggia, anche di notte e anche in riva all'acqua.
func _test_contesto(t) -> void:
	t.eq(TAC.contesto(true, true, true, 0.9), "la pioggia",
			"se piove, guardavi la pioggia — batte tutto il resto")
	t.eq(TAC.contesto(true, false, true, 0.9), "le stelle",
			"di notte e sereno: le stelle")
	t.eq(TAC.contesto(false, false, true, 0.5), "l'acqua",
			"di giorno in riva: l'acqua")
	t.eq(TAC.contesto(false, false, false, 0.2), "la luce che si alzava",
			"all'alba: la luce")
	t.eq(TAC.contesto(false, false, false, 0.8), "le ombre che si allungavano",
			"al tramonto: le ombre")
	t.eq(TAC.contesto(false, false, false, 0.5), "il prato",
			"e a mezzogiorno in mezzo al prato: il prato")


# ------------------------------------------------------------- le pagine

func _test_le_pagine(t) -> void:
	t.eq(DIR.quando(0), "stamattina", "una pagina di oggi è di stamattina")
	t.eq(DIR.quando(1), "ieri", "una di un giorno fa è di ieri")
	t.eq(DIR.quando(3), "l'altro giorno", "e una più vecchia è dell'altro giorno")

	var oggi := 10
	# LA SCADENZA. Questo è il dettaglio che smaschererebbe tutto: il Gufo
	# che cita come «l'altro giorno» una cosa di due settimane fa.
	var vecchia := {"oss": "esitazione", "giorno": oggi - TAC.PAGINE_GIORNI - 1}
	t.ok(DIR.pagina_da_citare([vecchia], oggi).is_empty(),
			"una pagina scaduta non si cita: il ricordo deve essere fresco")
	var fresca := {"oss": "esitazione", "giorno": oggi - 1}
	t.eq(str(DIR.pagina_da_citare([fresca], oggi).get("giorno", -1)), str(oggi - 1),
			"una pagina di ieri si cita")
	var usata := {"oss": "esitazione", "giorno": oggi, "usata": true}
	t.ok(DIR.pagina_da_citare([usata], oggi).is_empty(),
			"una pagina già spedita non si spedisce due volte")
	# dal futuro non arriva niente (un salvataggio riaperto indietro nel tempo)
	var futura := {"oss": "esitazione", "giorno": oggi + 3}
	t.ok(DIR.pagina_da_citare([futura], oggi).is_empty(),
			"e da un giorno che non è ancora arrivato non si cita nulla")
	# LA PIÙ RECENTE VINCE: un gesto di stamattina è più vivo di uno di ieri
	var scelta: Dictionary = DIR.pagina_da_citare([fresca,
			{"oss": "sosta", "giorno": oggi}], oggi)
	t.eq(str(scelta.get("oss", "")), "sosta",
			"fra due pagine buone si cita la più recente")
	t.ok(DIR.pagina_da_citare([], oggi).is_empty(), "senza pagine, niente")


## LE LETTERE. Un segnaposto di troppo non è un difetto estetico: è un
## crash al primo `%` — e siccome la lettera si compone all'APERTURA della
## busta, crasherebbe in faccia al giocatore nel momento più delicato.
func _test_le_lettere(t) -> void:
	for oss in DIR.TACCUINO_LETTERE:
		var voce: Dictionary = DIR.TACCUINO_LETTERE[oss]
		var testo := str(voce["text_key"])
		var quanti := testo.count("%s")
		var attesi := 2 if bool(voce["cita"]) else 0
		t.eq(quanti, attesi,
				"la lettera '%s' ha %d segnaposto, quanti sono gli argomenti" % [oss, attesi])
		t.eq(testo.count("%d"), 0,
				"…e nessun %%d: il taccuino non conta niente, cita")
		# il campo si chiama `text_key` perche' cosi' il guardiano della
		# localizzazione lo trova: con un altro nome queste lettere
		# uscirebbero in italiano dentro la versione inglese, e la suite
		# resterebbe verde
		t.ok(voce.has("text_key"),
				"la lettera '%s' sta sotto `text_key`: e' cosi' che il test delle traduzioni la vede" % oss)
		t.ok(testo.length() > 60,
				"…e non è una battuta: '%s' ha il respiro di una lettera" % oss)
	# ogni osservazione che il taccuino sa scrivere ha la sua lettera, e
	# viceversa: una pagina senza busta resterebbe muta per sempre
	var scritte := ["esitazione", "regola_tua", "sentiero_fedele",
			"sentiero_ignorato", "sosta"]
	for s in scritte:
		t.ok(DIR.TACCUINO_LETTERE.has(s), "l'osservazione '%s' ha la sua lettera" % s)
	t.eq(DIR.TACCUINO_LETTERE.size(), scritte.size(),
			"e non ci sono lettere orfane che nessuno spedirà mai")


## LA CONSEGNA, per davvero: si fa girare il Regista vero con una posta
## finta e si guarda cosa esce dalla busta.
func _test_la_consegna(t) -> void:
	# il Regista vive dentro CozyWorld (`_cozy = get_parent()`): messo alla
	# radice prenderebbe la Window per un Node3D e morirebbe in `_ready`
	var casa: Node3D = t.stage(Node3D.new())
	var d: Node = DIR.new()
	casa.add_child(d)
	var mail := MailFinta.new()
	var dn := GiornoFinto.new()
	dn.day = 7
	d.add_child(mail)
	d.add_child(dn)
	d.set("_mail", mail)
	d.set("_daynight", dn)
	# c'è del movimento anche nei contatori: così si prova che il taccuino
	# VINCE, e non solo che parla quando l'altro canale è muto
	d.set("_contatori", {"costruzione": 9})
	d.set("_ieri", {"costruzione": 1})
	d.call("annota", {"oss": "esitazione", "cosa": "una farfalla dorata",
			"classe": "creatura", "giorno": 7, "usata": false})
	d.call("_sorpresa_del_giorno")

	t.eq(mail.coda.size(), 1, "il Gufo ha scritto una lettera sola")
	var l: Dictionary = mail.coda[0]
	t.eq(str(l["from_key"]), "Il Gufo", "e la firma è la sua")
	# L'IDENTITÀ SI CHIEDE ALLA TABELLA, non a un pezzo di frase: un test che
	# cerca «fermarti davanti» diventa rosso il giorno in cui qualcuno
	# riscrive la lettera per farla stare meglio nella busta — ed è quello
	# che è successo, la prima volta.
	var testi: Array = []
	for oss in DIR.TACCUINO_LETTERE:
		testi.append(str((DIR.TACCUINO_LETTERE[oss] as Dictionary)["text_key"]))
	t.ok(str(l["text_key"]) in testi,
			"È LA LETTERA DEL TACCUINO, non il ritratto col contatore: un istante batte un totale")
	t.ok(not str(l["text_key"]).contains("%d"),
			"…e non c'è nessun numero dentro")
	# IL REGALO NO: un pacco trasformerebbe l'osservazione in una ricompensa
	t.ok(not bool(l.get("gift", false)),
			"il taccuino non porta regali: il momento vale quanto non viene pagato")
	# GLI ARGOMENTI SONO CHIAVI ANNIDATE, non testo già composto: la posta
	# va su disco in italiano e si traduce quando la busta si apre
	var args: Array = l["args"]
	t.eq(args.size(), 2, "la lettera porta il quando e la cosa")
	for a in args:
		t.ok(a is Dictionary and (a as Dictionary).has("k"),
				"…come chiave annidata, così si traduce all'apertura")
	t.eq(str((args[1] as Dictionary)["k"]), "una farfalla dorata",
			"e la cosa citata è la SPECIE, non «una creaturina»")

	# la pagina è bruciata: la stessa osservazione non si racconta due volte
	d.set("_ultima_sorpresa", -1)
	d.call("_sorpresa_del_giorno")
	t.eq(mail.coda.size(), 2, "il giorno dopo il Gufo scrive di nuovo")
	t.ok(not str((mail.coda[1] as Dictionary)["text_key"]) in testi,
			"…ma stavolta col ritratto: la pagina era già stata spedita")

	# e una pagina di un'osservazione che non esiste non entra nel taccuino
	var prima: int = (d.get("_pagine") as Array).size()
	d.call("annota", {"oss": "inventata", "giorno": 7})
	t.eq((d.get("_pagine") as Array).size(), prima,
			"un'osservazione senza lettera non si annota: resterebbe muta")

	# la persistenza: le pagine tornano dal salvataggio, e un salvataggio
	# fatto prima che il taccuino esistesse riparte da vuoto senza rompersi
	var salvato: Dictionary = d.call("save_extra")
	t.ok((salvato["regista"] as Dictionary).has("pagine"),
			"le pagine si salvano")
	d.call("load_extra", {"regista": {"contatori": {}}})
	t.ok((d.get("_pagine") as Array).is_empty(),
			"e un salvataggio vecchio, senza la chiave, non fa danni")


# ------------------------------------------------- la macchina a stati vera

## Prepara un taccuino con un mondo finto attorno, già cablato.
func _banco(t) -> Dictionary:
	var tac: Node = t.stage(TAC.new())
	var pl := PlayerFinto.new()
	var arb := ArbitroFinto.new()
	var reg := RegistaFinto.new()
	var bld := BuildFinto.new()
	var dn := GiornoFinto.new()
	for n in [pl, arb, reg, bld, dn]:
		tac.add_child(n)
	tac.set("_player", pl)
	tac.set("_arbitro", arb)
	tac.set("_regista", reg)
	tac.set("_build", bld)
	tac.set("_daynight", dn)
	return {"tac": tac, "pl": pl, "arb": arb, "reg": reg, "bld": bld}


## Un campione: si mette la posizione e la velocità, e si fa girare il
## `_process` per il tempo di un campionamento.
func _passo(b: Dictionary, pos: Vector3, vel: float, d: float) -> void:
	var pl: CharacterBody3D = b["pl"]
	pl.global_position = pos
	pl.velocity = Vector3(vel, 0, 0)
	var arb: ArbitroFinto = b["arb"]
	if d >= 0.0:
		arb.risposta = {"nome": "retino", "chi": arb, "gradino": 0, "distanza": d}
	else:
		arb.risposta = {}
	(b["tac"] as Node).call("_process", TAC.CAMPIONE)


## IL GESTO, RECITATO: cammina verso la creatura, si ferma davanti, e
## riparte senza premere. Il taccuino deve scriverne una pagina.
func _test_il_gesto_vero(t) -> void:
	var b := _banco(t)
	# si avvicina: la distanza scende di più di un metro
	for i in 6:
		_passo(b, Vector3(2.0 - float(i) * 0.3, 0, 0), 1.6, 2.2 - float(i) * 0.3)
	# si ferma davanti, per più di ESITA_FERMA secondi
	var fermi := int(TAC.ESITA_FERMA / TAC.CAMPIONE) + 3
	for i in fermi:
		_passo(b, Vector3(0.2, 0, 0), 0.0, 0.4)
	# riparte camminando…
	for i in int(TAC.ESITA_RIPARTE / TAC.CAMPIONE) + 2:
		_passo(b, Vector3(0.2 + float(i) * 0.3, 0, 0), 1.6, 0.4)
	# …e la creatura esce dal raggio: la finestra si chiude
	_passo(b, Vector3(3.0, 0, 0), 1.6, -1.0)

	var reg: RegistaFinto = b["reg"]
	t.eq(reg.pagine.size(), 1,
			"IL GESTO È STATO VISTO: una pagina, dal `_process` vero")
	var p: Dictionary = reg.pagine[0]
	t.eq(str(p["oss"]), "esitazione", "e l'osservazione è l'esitazione")
	t.eq(str(p["classe"]), "creatura", "con la classe della cosa lasciata lì")
	t.ok(str(p["cosa"]) != "", "e un nome da citare")


## LO STESSO GESTO, SMENTITO. Tre sessioni plausibili in cui il taccuino
## deve restare muto — e sono i tre modi in cui la magia crollerebbe.
func _test_il_gesto_smentito(t) -> void:
	# (a) HA PREMUTO. Ha raccolto: non ha rinunciato a niente.
	var b := _banco(t)
	for i in 6:
		_passo(b, Vector3(2.0 - float(i) * 0.3, 0, 0), 1.6, 2.2 - float(i) * 0.3)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	(b["tac"] as Node).call("_input", ev)
	for i in int(TAC.ESITA_FERMA / TAC.CAMPIONE) + 3:
		_passo(b, Vector3(0.2, 0, 0), 0.0, 0.4)
	for i in 4:
		_passo(b, Vector3(0.5 + float(i) * 0.3, 0, 0), 1.6, 0.4)
	_passo(b, Vector3(3.0, 0, 0), 1.6, -1.0)
	t.eq((b["reg"] as RegistaFinto).pagine.size(), 0,
			"TACE se ha premuto: ha raccolto, non ha lasciato lì niente")

	# (b) LE È CAPITATO DAVANTI. Si è fermata, sì, ma senza andarci: la
	# creatura le è volata addosso mentre stava già lì.
	var b2 := _banco(t)
	for i in int(TAC.ESITA_FERMA / TAC.CAMPIONE) + 6:
		_passo(b2, Vector3(0.2, 0, 0), 0.0, 0.5)
	for i in 4:
		_passo(b2, Vector3(0.5 + float(i) * 0.3, 0, 0), 1.6, 0.5)
	_passo(b2, Vector3(3.0, 0, 0), 1.6, -1.0)
	t.eq((b2["reg"] as RegistaFinto).pagine.size(), 0,
			"TACE se non ci è andata: passare accanto non è fermarsi davanti")

	# (c) IL PANNELLO. Ha aperto un menu a metà gesto — ed è il falso
	# positivo che ucciderebbe la meccanica, perché è ciò che i giocatori
	# fanno di continuo.
	var b3 := _banco(t)
	for i in 6:
		_passo(b3, Vector3(2.0 - float(i) * 0.3, 0, 0), 1.6, 2.2 - float(i) * 0.3)
	for i in int(TAC.ESITA_FERMA / TAC.CAMPIONE) + 3:
		_passo(b3, Vector3(0.2, 0, 0), 0.0, 0.4)
	(b3["pl"] as CharacterBody3D).set_physics_process(false)   # pannello aperto
	_passo(b3, Vector3(0.2, 0, 0), 0.0, 0.4)
	(b3["pl"] as CharacterBody3D).set_physics_process(true)
	for i in 4:
		_passo(b3, Vector3(0.5 + float(i) * 0.3, 0, 0), 1.6, 0.4)
	_passo(b3, Vector3(3.0, 0, 0), 1.6, -1.0)
	t.eq((b3["reg"] as RegistaFinto).pagine.size(), 0,
			"TACE se Mochi non era in mano al giocatore: quello non era un gesto suo")

	# (d) IL SALTO. Una dormita, un caricamento, una seduta: la posizione
	# balza, e quello che c'era in corso non è più prova di niente.
	var b4 := _banco(t)
	for i in 6:
		_passo(b4, Vector3(2.0 - float(i) * 0.3, 0, 0), 1.6, 2.2 - float(i) * 0.3)
	for i in int(TAC.ESITA_FERMA / TAC.CAMPIONE) + 3:
		_passo(b4, Vector3(0.2, 0, 0), 0.0, 0.4)
	_passo(b4, Vector3(40.0, 0, 40.0), 0.0, 0.4)              # teletrasporto
	for i in 4:
		_passo(b4, Vector3(40.5 + float(i) * 0.3, 0, 40.0), 1.6, 0.4)
	_passo(b4, Vector3(44.0, 0, 40.0), 1.6, -1.0)
	t.eq((b4["reg"] as RegistaFinto).pagine.size(), 0,
			"TACE dopo un salto di posizione: non era un passo, era un caricamento")
