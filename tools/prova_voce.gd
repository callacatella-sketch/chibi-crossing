extends SceneTree
## La verifica VIVA della Voce (scenes/npc/Voce.gd) nel MainLevel vero —
## la sorella di prova_arrivi.gd.
##
## Carica il gioco, spegne la persistenza, poi percorre il ciclo intero
## sul cablaggio VERO (niente stub): fabbrica il bisogno su un residente,
## controlla che la porta resti CHIUSA senza fiducia, la apre col Filo,
## fa scattare la confidenza, stampa le sette frasi tradotte, consegna al
## destinatario sbagliato (il marchio chi|giocatore nel limbico) e a
## quello giusto (la visita serena, il lavoro che passa di mano), e
## infine lascia scadere una voce per la pagina del Gufo.
##
##   Godot --headless --path . --script res://tools/prova_voce.gd
##
## Esce 0 se tutto a posto, 1 al primo GUASTO. Non tocca il salvataggio.


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 6:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si e caricato")
		quit(1)
		return
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	var voce_sys := livello.get_node_or_null("Voce")
	var lavori := livello.get_node_or_null("Lavori")
	if build == null or visitors == null or voce_sys == null or lavori == null:
		print("GUASTO: build=%s visitors=%s voce=%s lavori=%s"
				% [build, visitors, voce_sys, lavori])
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	print("persistenza: spenta")
	await create_timer(2.0).timeout

	var guasti := 0

	# il cablaggio si e' chiuso?
	for i in 300:
		if bool(voce_sys.get("_cablato")):
			break
		await process_frame
	guasti += _controlla(bool(voce_sys.get("_cablato")), "il cablaggio si chiude")

	# servono almeno due residenti veri: se il salvataggio e' vuoto se ne
	# fanno arrivare due dalla porta di debug (solo in memoria: la
	# persistenza e' spenta, il file su disco non cambia)
	var etichette: Array = visitors.call("etichette")
	if etichette.size() < 2:
		visitors.call("debug_add_resident", 11, Vector3(2, 0, 5))
		visitors.call("debug_add_resident", 12, Vector3(3, 0, 5))
		# l'animo nasce pigro (_ensure_brain nella routine): gli si da tempo
		await create_timer(2.5).timeout
		etichette = visitors.call("etichette")
	print("residenti: ", etichette)
	if etichette.size() < 2:
		print("GUASTO: nemmeno i residenti di debug sono arrivati")
		quit(1)
		return
	var da := str(etichette[0])
	var dest := str(etichette[1])

	# ---- 1. LA CONFIDENZA: si fabbrica il bisogno sullo stato VERO
	var animo: RefCounted = visitors.call("animo_oggetto_di", da)
	guasti += _controlla(animo != null, "l'animo di %s esiste" % da)
	var lim: RefCounted = animo.get("limbico")
	lim.set("umore", -0.6)
	lim.set("regolazione", 0.1)
	lim.set("arousal", 0.0)
	var marchi: Dictionary = lim.get("marchi")
	marchi["luogo|catasta"] = {"carica": -0.7, "conferme": 3, "giorno": 0}
	# la fiducia: il filo deve avere abbastanza giorni. Si bara sul filo
	# vero, dalla porta pubblica dei Legami.
	var legami := livello.get_tree().get_first_node_in_group("legami")
	var giorni := 0
	if legami:
		giorni = int(legami.call("giorni_di_amicizia", da))
	print("giorni di filo per %s: %d" % [da, giorni])
	# PRIMA: senza fiducia la porta DEVE restare chiusa, anche col bisogno
	if giorni < 3:
		voce_sys.call("_prova_confidenza", da)
		guasti += _controlla(
				(voce_sys.call("voce_attiva") as Dictionary).is_empty(),
				"senza giorni di Filo la porta resta chiusa (giusto cosi')")
		(voce_sys.get("_confidato_oggi") as Dictionary).clear()
		# poi si retrodata l'arrivo sul filo VERO, e la porta si apre
		if legami:
			legami.call("registra_arrivo", da)
			var fili: Dictionary = legami.get("_fili")
			for chiave in fili:
				(fili[chiave] as Dictionary)["giorno_arrivo"] = -10
	giorni = int(legami.call("giorni_di_amicizia", da)) if legami else 99
	print("giorni di filo dopo la retrodatazione: %d" % giorni)
	# la confidenza, per la porta vera
	voce_sys.call("_prova_confidenza", da)
	var v: Dictionary = voce_sys.call("voce_attiva")
	print("voce dopo la confidenza: ", v)
	guasti += _controlla(str(v.get("famiglia", "")) == "paura",
			"la confidenza VERA pesca la paura dal limbico (era %s)" % str(v.get("famiglia")))
	guasti += _controlla(str(v.get("dettaglio", "")) == "catasta",
			"…e dice il luogo giusto")
	# le frasi: ogni famiglia deve uscire tradotta e non vuota
	for fam_det in [["paura", "catasta"], ["torto", "guardia"],
			["desiderio", "sicurezza"], ["desiderio", "fatica"],
			["desiderio", "noia"], ["affetto", dest], ["partenza", ""]]:
		var frase: String = voce_sys.call("_frase_confidenza",
				{"famiglia": fam_det[0], "da": da, "dettaglio": fam_det[1]})
		print("    frase %s: %s" % [fam_det[0], frase])
		guasti += _controlla(frase.length() > 10 and not frase.contains("%s"),
				"la frase della famiglia «%s» esce intera" % fam_det[0])

	# ---- 2. LA CONSEGNA SBAGLIATA: il limbico marchia il giocatore.
	# Si abbassa l'amicizia da->dest cosi' il destinatario e' sbagliato
	# PER I SISTEMI, non per costruzione del test.
	visitors.call("lega_vicini", da, dest, 0.2, 0.2)
	var atteso_prima: float = lim.call("carica_di", "", "giocatore")
	voce_sys.call("consegna", dest)   # dest non e' amico stretto: sbagliato
	var marchio_dopo: float = lim.call("carica_di", "", "giocatore")
	print("marchio chi|giocatore: prima %.2f, dopo %.2f" % [atteso_prima, marchio_dopo])
	guasti += _controlla(marchio_dopo < atteso_prima - 0.1,
			"il tradimento marchia il giocatore nel limbico VERO")
	guasti += _controlla((voce_sys.call("voce_attiva") as Dictionary).is_empty(),
			"la voce consegnata non e' piu' addosso")

	# ---- 3. LA CONSEGNA GIUSTA: l'amico accompagna, il marchio si attenua
	var amici: Dictionary = visitors.call("amici_di", da)
	print("amici di %s: %s" % [da, amici])
	# si rende dest amico vero (dalla porta pubblica)
	visitors.call("lega_vicini", dest, da, 0.7, 0.7)
	var carica_prima: float = lim.call("carica_di", "catasta", "")
	voce_sys.set("_voce", {"famiglia": "paura", "da": da,
			"dettaglio": "catasta", "giorno": int(voce_sys.get("_oggi")),
			"miccia": false})
	voce_sys.call("consegna", dest)
	var carica_dopo: float = lim.call("carica_di", "catasta", "")
	print("carica catasta: prima %.2f, dopo %.2f" % [carica_prima, carica_dopo])
	guasti += _controlla(carica_dopo > carica_prima + 0.05,
			"la visita serena attenua la paura nel limbico VERO")

	# ---- 4. IL TORTO: il lavoro passa di mano nel registro VERO
	lavori.call("assegna", da, "guardia")
	animo.set("sogno", "artista")
	var animo_dest: RefCounted = visitors.call("animo_oggetto_di", dest)
	animo_dest.set("sogno", "guerriero")
	voce_sys.set("_voce", {"famiglia": "torto", "da": da,
			"dettaglio": "guardia", "giorno": int(voce_sys.get("_oggi")),
			"miccia": false})
	voce_sys.call("consegna", dest)
	print("incarichi dopo il torto: %s='%s'  %s='%s'" % [da,
			lavori.call("incarico", da), dest, lavori.call("incarico", dest)])
	guasti += _controlla(str(lavori.call("incarico", dest)) == "guardia",
			"il lavoro e' passato a chi lo sognava")
	guasti += _controlla(str(lavori.call("incarico", da)) == "",
			"e chi lo subiva e' libero")

	# ---- 5. IL SILENZIO: la voce scade e il Gufo scrive la pagina
	voce_sys.set("_voce", {"famiglia": "desiderio", "da": da,
			"dettaglio": "noia", "giorno": 0, "miccia": false})
	voce_sys.call("_nuovo_giorno", 99)
	var regista := livello.get_tree().get_first_node_in_group("regista")
	guasti += _controlla(regista != null, "il regista c'e'")
	var pagine: Array = regista.get("_pagine")
	var trovata := false
	for p in pagine:
		if str((p as Dictionary).get("oss", "")) == "voce_taciuta":
			trovata = true
	print("pagine del regista: ", pagine)
	guasti += _controlla(trovata, "la pagina «voce_taciuta» e' nel taccuino del Gufo")
	guasti += _controlla(int((voce_sys.get("_riserbo") as Dictionary).get(da, 0)) >= 1,
			"il riserbo per %s e' salito" % da)
	guasti += _controlla((voce_sys.call("voce_attiva") as Dictionary).is_empty(),
			"la voce scaduta non pesa piu' addosso")

	if guasti == 0:
		print("PROVA VIVA: tutto a posto")
	else:
		print("PROVA VIVA: %d GUASTI" % guasti)
	quit(1 if guasti > 0 else 0)


func _controlla(ok: bool, cosa: String) -> int:
	print(("  OK  " if ok else "  GUASTO  ") + cosa)
	return 0 if ok else 1
