extends RefCounted
## GLI AFFETTI FRA VICINI — la prova che il legame è GUADAGNATO.
##
## «Libero arbitrio» in una simulazione ha un modo preciso di fallire: il
## giocatore capisce che è un dado. Se due si mettono insieme e lui non può
## in nessun modo risalire al perché, non è profondità — è rumore, e la
## seconda partita lo smaschera.
##
## Perciò tutto ciò che decide è PURO e si prova qui: entra un elenco di
## gesti accaduti, esce un numero. Nessun `randf` da nessuna parte in questo
## file — e se un giorno ce ne fosse uno nel codice, una di queste prove
## diventerebbe intermittente e lo direbbe.

const AFF := preload("res://scenes/npc/Affetti.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")


func run(t) -> void:
	_test_la_scala_dei_gesti(t)
	_test_essere_cercati_conta_di_piu(t)
	_test_la_lealta_allunga_la_memoria(t)
	_test_la_coppia_e_reciproca(t)
	_test_la_prossimita_non_e_affetto(t)
	_test_una_coppia_alla_volta(t)
	_test_il_carattere_decide(t)


func _riga(a: String, b: String, tipo: String, giorno: int) -> Dictionary:
	return {"a": a, "b": b, "t": tipo, "d": giorno}


## LA SCALA NON È GUSTO. Una chiacchiera deve valere una frazione di un
## gesto vero, o il libro mastro diventa una mappa di chi passa più tempo
## vicino a chi — e allora si mettono insieme i due che lavorano accanto.
func _test_la_scala_dei_gesti(t) -> void:
	t.ok(float(AFF.GESTI["coraggio"]) > float(AFF.GESTI["chiacchiera"]) * 15.0,
			"andare per primo in un posto che fa paura vale più di quindici"
			+ " chiacchiere (%.2f contro %.2f)"
			% [AFF.GESTI["coraggio"], AFF.GESTI["chiacchiera"]])
	t.ok(float(AFF.GESTI["nascita"]) == 2.0,
			"e fare una vita insieme è il gesto più grande della tabella")
	t.ok(float(AFF.GESTI["mancanza"]) < 0.0,
			"una promessa mancata TOGLIE: il libro mastro sa anche sottrarre")
	# ogni peso è dichiarato una volta sola
	var visti := {}
	for k in AFF.GESTI:
		t.ok(not visti.has(str(k)), "il gesto '%s' è dichiarato una volta sola" % k)
		visti[str(k)] = true


## ESSERE CERCATI CONTA QUASI IL DOPPIO CHE CERCARE. Senza, un rapporto a
## senso unico si legge uguale dai due lati — e allora chi insegue e chi è
## inseguito sono la stessa cosa, che è falso.
func _test_essere_cercati_conta_di_piu(t) -> void:
	var righe := [_riga("Anna", "Bruno", "piatto", 10)]
	var per_bruno := AFF.conto(righe, "Bruno", "Anna", 10)
	var per_anna := AFF.conto(righe, "Anna", "Bruno", 10)
	t.ok(per_bruno > per_anna,
			"chi ha ricevuto il piatto ci tiene di più di chi l'ha portato"
			+ " (%.3f contro %.3f)" % [per_bruno, per_anna])
	t.almost(per_anna / per_bruno, AFF.ASIMMETRIA,
			"…esattamente nella proporzione dichiarata", 0.001)
	# e un gesto fra altri due non conta per nessuno dei due
	t.almost(AFF.conto([_riga("Carla", "Dino", "piatto", 10)], "Anna", "Bruno", 10),
			0.0, "un gesto fra altri non entra nel loro libro", 0.0001)


## LA LEALTÀ ALLUNGA LA MEMORIA — ed è QUESTA la cosa che rende certe coppie
## inespugnabili, senza nessuna eccezione scritta per proteggerle.
func _test_la_lealta_allunga_la_memoria(t) -> void:
	var righe := [_riga("Bruno", "Anna", "veglia", 0)]
	var fedele := AFF.conto(righe, "Anna", "Bruno", 60, 1.0)
	var volubile := AFF.conto(righe, "Anna", "Bruno", 60, 0.0)
	t.ok(fedele > volubile * 1.5,
			"dopo due mesi, chi non dimentica ricorda molto di più"
			+ " (%.3f contro %.3f)" % [fedele, volubile])
	# e oggi valgono uguale: la lealtà non gonfia il gesto, allunga il ricordo
	t.almost(AFF.conto(righe, "Anna", "Bruno", 0, 1.0),
			AFF.conto(righe, "Anna", "Bruno", 0, 0.0),
			"il giorno stesso valgono uguale: cambia il decadimento, non il peso",
			0.0001)
	# il ricordo sbiadisce davvero
	t.ok(AFF.conto(righe, "Anna", "Bruno", 200, 0.5)
			< AFF.conto(righe, "Anna", "Bruno", 0, 0.5) * 0.1,
			"e dopo duecento giorni di niente, di quel gesto resta quasi nulla")


## LA COPPIA È RECIPROCA. L'amore non ricambiato non è una coppia: è
## un'infatuazione, e il gioco lo sapeva già (il commento di
## `Nascite.coppia_migliore`).
func _test_la_coppia_e_reciproca(t) -> void:
	var tutti := ["Anna", "Bruno", "Carla"]
	# Anna insegue Bruno; ma è CARLA che si fa scegliere da lui — e Carla lo
	# cerca a sua volta. (Prima stesura di questa prova: Anna inseguiva e
	# basta, e il test falliva perché il codice ha ragione — chi ti ricopre
	# di attenzioni conta comunque per te. Per essere non ricambiata, Anna
	# deve perdere il confronto con qualcuno che a Bruno dà di più.)
	var righe: Array = []
	for i in 6:
		righe.append(_riga("Anna", "Bruno", "veglia", i))
		righe.append(_riga("Carla", "Bruno", "consolazione", i))
		righe.append(_riga("Bruno", "Carla", "consolazione", i))
	t.ok(not AFF.coppia(righe, "Anna", "Bruno", tutti, 6),
			"chi non è ricambiata non è una coppia: è un'infatuazione")
	t.ok(AFF.coppia(righe, "Bruno", "Carla", tutti, 6),
			"…e la coppia vera è quella dove i due sono il massimo l'uno dell'altra")
	# e se Bruno ricambia, lo diventano
	var ricambiato: Array = righe.duplicate(true)
	for i in 6:
		ricambiato.append(_riga("Bruno", "Anna", "veglia", i))
		ricambiato.append(_riga("Anna", "Bruno", "consolazione", i))
	t.ok(AFF.coppia(ricambiato, "Anna", "Bruno", ["Anna", "Bruno"], 6),
			"ricambiata e sopra soglia: quella è una coppia")


## LA PROSSIMITÀ NON È AFFETTO. È la valvola che impedisce al sistema di
## sposare i due che lavorano accanto: cento chiacchiere non fanno un legame
## senza qualche gesto vero.
func _test_la_prossimita_non_e_affetto(t) -> void:
	var righe: Array = []
	for i in 200:
		righe.append(_riga("Anna", "Bruno", "chiacchiera", i % 30))
		righe.append(_riga("Bruno", "Anna", "chiacchiera", i % 30))
	t.eq(AFF.gesti_veri(righe, "Anna", "Bruno"), 0,
			"duecento chiacchiere non contengono un solo gesto vero")
	t.ok(not AFF.coppia(righe, "Anna", "Bruno", ["Anna", "Bruno"], 30),
			"e non bastano a fare una coppia, per quanto il conto salga")
	# tre gesti veri sì
	for i in AFF.GESTI_VERI_MIN:
		righe.append(_riga("Anna", "Bruno", "consolazione", 28))
		righe.append(_riga("Bruno", "Anna", "consolazione", 28))
	t.ok(AFF.gesti_veri(righe, "Anna", "Bruno") >= AFF.GESTI_VERI_MIN,
			"con qualche gesto vero, invece, il legame esiste")
	t.ok(AFF.coppia(righe, "Anna", "Bruno", ["Anna", "Bruno"], 30),
			"…e allora sì")


## OGNUNO STA IN UNA COPPIA SOLA, e la coppia si RICALCOLA dai fatti: non
## c'è nessun campo «fidanzati» da tenere sincronizzato, quindi non può
## restare appeso a metà né va migrato nei salvataggi vecchi.
func _test_una_coppia_alla_volta(t) -> void:
	var tutti := ["Anna", "Bruno", "Carla", "Dino"]
	var righe: Array = []
	for i in 6:
		for c in [["Anna", "Bruno"], ["Bruno", "Anna"], ["Carla", "Dino"], ["Dino", "Carla"]]:
			righe.append(_riga(str(c[0]), str(c[1]), "consolazione", i))
	var cs: Array = AFF.coppie(righe, tutti, 6)
	t.eq(cs.size(), 2, "due coppie, non di più")
	var dentro := {}
	for c in cs:
		for n in (c as Array):
			t.ok(not dentro.has(str(n)), "'%s' sta in una coppia sola" % n)
			dentro[str(n)] = true
	t.ok(AFF.coppie([], tutti, 6).is_empty(), "senza gesti non ci sono coppie")


## IL CARATTERE DECIDE. `Animo.punteggio()` era CIECO ai tratti: i pesi per
## carattere vivevano dentro `disagio()` e non venivano mai chiamati, quindi
## due vicini con gli stessi bisogni ricevevano punteggi identici su ogni
## azione, qualunque fosse il loro orgoglio o la loro lealtà.
##
## Finché era così, «libero arbitrio» non poteva essere altro che un dado:
## non c'era nessun canale attraverso cui il carattere potesse entrare in
## una scelta. È la prova che discrimina — rimettendo la costante fissa,
## questa diventa rossa.
func _test_il_carattere_decide(t) -> void:
	var orgoglioso: RefCounted = ANIMO.new()
	orgoglioso.setup({"name": "Orgoglio", "seed": 1, "tratti":
			{"orgoglio": 0.95, "lealta": 0.5, "grinta": 0.5,
			"codardia": 0.05, "ambizione": 0.5}})
	var pauroso: RefCounted = ANIMO.new()
	pauroso.setup({"name": "Paura", "seed": 1, "tratti":
			{"orgoglio": 0.05, "lealta": 0.5, "grinta": 0.5,
			"codardia": 0.95, "ambizione": 0.5}})
	# STESSI BISOGNI, esattamente
	for a in [orgoglioso, pauroso]:
		for d in ANIMO.DRIVES:
			a.drive[d] = 0.6
	t.ok(absf(orgoglioso.peso_drive("stima") - pauroso.peso_drive("stima")) > 0.5,
			"la stima pesa molto di più su chi è orgoglioso")
	t.ok(absf(orgoglioso.peso_drive("sicurezza") - pauroso.peso_drive("sicurezza")) > 0.5,
			"…e la sicurezza su chi è codardo")
	# e la differenza ARRIVA nel punteggio, che è quello che conta
	var azione: String = str(ANIMO.COMPITI.keys()[0])
	var diverso := false
	for k in ANIMO.COMPITI:
		if absf(orgoglioso.punteggio(str(k)) - pauroso.punteggio(str(k))) > 0.02:
			diverso = true
			azione = str(k)
	t.ok(diverso,
			("DAVANTI ALLA STESSA SCELTA, coi bisogni identici, due caratteri"
			+ " diversi danno punteggi diversi (es. '%s'): è l'unico canale"
			+ " attraverso cui il libero arbitrio può passare") % azione)
	# la nitidezza è per decisione: una scelta di vita non è un lancio di moneta
	t.ok(_ha_parametro("res://scenes/npc/Animo.gd", "decide", "nitidezza"),
			"e `decide` accetta una nitidezza: un mestiere può essere una moneta,"
			+ " andarsene dal villaggio no")


func _ha_parametro(path: String, funzione: String, par: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var src := f.get_as_text()
	var i := src.find("func " + funzione + "(")
	if i < 0:
		return false
	return src.substr(i, src.find(")", i) - i).contains(par)
