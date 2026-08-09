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
## Il villaggio finto ma VIVO (case vere, Veglia vera, Affetti vero in
## scena) sta in un posto solo: due copie dello stesso banco si scollano in
## silenzio esattamente come due copie di una tabella.
const GESTI := preload("res://tests/cases/test_gesti_veri.gd")


func run(t) -> void:
	_test_la_scala_dei_gesti(t)
	_test_essere_cercati_conta_di_piu(t)
	_test_la_lealta_allunga_la_memoria(t)
	_test_la_coppia_e_reciproca(t)
	_test_la_prossimita_non_e_affetto(t)
	_test_una_coppia_alla_volta(t)
	_test_il_carattere_decide(t)
	_test_la_rottura_costa_quanto_il_legame(t)
	_test_la_risposta_esce_dal_carattere(t)
	_test_ogni_ferita_ha_una_porta(t)
	_test_la_porta_e_chiusa_a_uno_solo(t)
	_test_nessuna_risposta_e_morta(t)
	_test_l_isteresi_regge_le_coppie(t)
	_test_i_gesti_veri_li_emette_qualcuno(t)
	_test_la_valvola_dell_abitudine(t)
	_test_la_veglia_non_annega_il_giocatore(t)
	_test_la_valvola_si_ricorda_dopo_il_salvataggio(t)


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


# ============================================================ la rottura

## LA ROTTURA NON È UN EVENTO: è il predicato che smette di essere vero.
##
## È la risposta alla critica più dura ricevuta in fase di progetto —
## «formare è limitato dal mondo, rompere non è limitato da niente». Qui le
## due cose costano la stessa moneta, perché sono la stessa cosa letta in
## due giorni diversi: non esiste nessuna tassa giornaliera, nessuna
## pazienza che scende da sola, nessuna macchina del divorzio.
func _test_la_rottura_costa_quanto_il_legame(t) -> void:
	var tutti := ["Anna", "Bruno", "Carla"]
	var righe: Array = []
	for i in 6:
		righe.append(_riga("Anna", "Bruno", "consolazione", i))
		righe.append(_riga("Bruno", "Anna", "consolazione", i))
	t.ok(AFF.coppia(righe, "Anna", "Bruno", tutti, 6), "prima sono una coppia")

	# IL TEMPO DA SOLO NON ROMPE NIENTE. Passano cento giorni in cui non
	# succede assolutamente nulla: sono ancora una coppia.
	t.ok(AFF.coppia(righe, "Anna", "Bruno", tutti, 100),
			"cento giorni di niente non li separano: il tempo non è una tassa")

	# SERVONO GESTI VERI ALTROVE, la stessa moneta con cui si erano messi
	# insieme. Carla si fa scegliere da Bruno, e viceversa, per giorni.
	var dopo: Array = righe.duplicate(true)
	for i in range(100, 112):
		dopo.append(_riga("Carla", "Bruno", "consolazione", i))
		dopo.append(_riga("Bruno", "Carla", "coraggio", i))
	t.ok(not AFF.coppia(dopo, "Anna", "Bruno", tutti, 112),
			"con abbastanza gesti veri altrove, la coppia non c'è più")
	t.ok(AFF.coppia(dopo, "Bruno", "Carla", tutti, 112),
			"…ed è diventata un'altra, per gli stessi fatti")


## LA RISPOSTA ESCE DAL CARATTERE. È la prova che separa il libero arbitrio
## da un dado travestito: davanti alla STESSA rottura, due persone diverse
## fanno cose diverse — e la differenza si può risalire.
func _test_la_risposta_esce_dal_carattere(t) -> void:
	var orgogliosa: RefCounted = ANIMO.new()
	orgogliosa.setup({"name": "Fiera", "seed": 3, "tratti":
			{"orgoglio": 0.95, "lealta": 0.5, "grinta": 0.6,
			"codardia": 0.05, "ambizione": 0.5}})
	var timida: RefCounted = ANIMO.new()
	timida.setup({"name": "Timida", "seed": 3, "tratti":
			{"orgoglio": 0.05, "lealta": 0.5, "grinta": 0.3,
			"codardia": 0.95, "ambizione": 0.5}})
	# stessi bisogni, esattamente: cambia solo chi sono
	for a in [orgogliosa, timida]:
		for d in ANIMO.DRIVES:
			a.drive[d] = 0.65

	var possibili: Array = ANIMO.REAZIONI.keys()
	var p_org: float = orgogliosa.punteggio("chiudo_la_porta", "ex")
	var p_tim: float = timida.punteggio("chiudo_la_porta", "ex")
	t.ok(p_org > p_tim,
			"chiudere la porta pesa di più su chi è orgogliosa (%.3f contro %.3f)"
			% [p_org, p_tim])
	t.ok(float(timida.punteggio("mi_ritiro", "ex")) > float(orgogliosa.punteggio("mi_ritiro", "ex")),
			"e ritirarsi pesa di più su chi ha paura")

	# e la differenza ARRIVA nella scelta, non resta nei punteggi
	var scelte_org := {}
	var scelte_tim := {}
	for i in 40:
		scelte_org[orgogliosa.decide(possibili, "ex", ANIMO.NITIDEZZA_VITA)] = true
		scelte_tim[timida.decide(possibili, "ex", ANIMO.NITIDEZZA_VITA)] = true
	t.ok(scelte_org.keys() != scelte_tim.keys() or scelte_org.size() != scelte_tim.size(),
			"quaranta rotture: le due donne non fanno lo stesso ventaglio di cose")
	# NON è un dado a sette facce: la nitidezza alta tiene la scelta stretta
	t.ok(scelte_org.size() <= 3,
			"e nessuna delle due sceglie a caso fra tutte e sette (%d risposte)"
			% scelte_org.size())


## OGNI FERITA HA UNA CHIAVE A FORMA DI GIOCATORE. È la regola che il
## progetto si è dato per non creare stati permanenti la cui unica chiave
## sia in mano a un altro NPC: la porta è sempre il giocatore, come in
## `Visitors._filtra_luogo`.
func _test_ogni_ferita_ha_una_porta(t) -> void:
	for r in ANIMO.REAZIONI:
		t.ok(AFF.MOMENTI_CHIAVE.has(str(r)),
				"la risposta '%s' ha la sua chiave: quanti momenti col"
				% r + " giocatore servono per richiuderla")
		t.ok(int(AFF.MOMENTI_CHIAVE.get(str(r), 0)) > 0,
				"…e la chiave non è zero (una ferita che si chiude da sola"
				+ " non è una ferita) né infinita (sarebbe uno stato permanente)")
		t.ok(int(AFF.MOMENTI_CHIAVE.get(str(r), 99)) <= 5,
				"…né così cara da essere irraggiungibile ('%s')" % r)
	# e nessuna risposta è priva del suo peso sui bisogni: senza, il
	# punteggio varrebbe zero e `decide` diventerebbe un dado
	for r2 in ANIMO.REAZIONI:
		var v: Dictionary = ANIMO.REAZIONI[r2]
		t.ok(not v.is_empty(),
				"'%s' pesa su qualche bisogno, o non si potrebbe sceglierla" % r2)
		var tocca := 0
		for d in ANIMO.DRIVES:
			if v.has(d):
				tocca += 1
		t.ok(tocca >= 2,
				"'%s' tocca almeno due bisogni: una risposta a una cosa così"
				% r2 + " non muove una leva sola")


## LA PORTA CHIUSA È CHIUSA A UNO SOLO. Una ferita non rende scontrosi con
## tutto il villaggio: il giocatore deve vedere una persona ferita, non una
## persona cattiva.
func _test_la_porta_e_chiusa_a_uno_solo(t) -> void:
	var aff: Node = t.stage(AFF.new())
	aff.set("_ferite", {"Anna": {"reazione": "chiudo_la_porta", "ex": "Bruno",
			"dal": 3, "momenti": 0}})
	t.ok(not aff.call("apre_a", "Anna", "Bruno"),
			"ad Anna la porta di casa non si apre più per Bruno")
	t.ok(aff.call("apre_a", "Anna", "Carla"),
			"…ma per Carla sì: non è diventata scontrosa, è ferita")
	t.ok(aff.call("apre_a", "Bruno", "Anna"),
			"e Bruno non ha chiuso niente a nessuno")
	# la chiave: dopo abbastanza momenti col giocatore, la ferita si richiude
	for i in int(AFF.MOMENTI_CHIAVE["chiudo_la_porta"]):
		aff.call("momento_del_giocatore", "Anna")
	aff.call("_le_ferite_si_richiudono", 10)
	t.ok(aff.call("apre_a", "Anna", "Bruno"),
			"e quando il giocatore le è stato vicino abbastanza, la porta si riapre")


## NESSUNA RISPOSTA È MORTA, E NESSUNA DOMINA. È la prova che una revisione
## avversariale ha reso necessaria: prima di questa taratura, MISURATO,
##  · i sette punteggi valevano esattamente 0.000000 per un vicino che sta
##    bene (cioè nel caso NORMALE), perché l'unico termine vivo era
##    moltiplicato per `malessere()`, che `passa_giorno` porta a zero;
##  · il softmax su tre pareggi dava un dado uniforme sulle prime tre chiavi
##    NELL'ORDINE IN CUI LA TABELLA È SCRITTA, identico per un orgoglioso e
##    per un codardo;
##  · `resto_e_aspetto` — «l'unica che può finire bene» — non era prima per
##    NESSUN carattere, mai;
##  · `sto_col_piccolo` vinceva più di tutte le altre sei messe insieme.
##
## Serviva un termine che NON passasse dal malessere: il tiro del carattere,
## della stessa scala del tiro del sogno.
func _test_nessuna_risposta_e_morta(t) -> void:
	var DNA := load("res://scenes/npc/ChibiDNA.gd")
	var reaz: Array = ANIMO.REAZIONI.keys()
	var vinte := {}
	var ventagli := {}
	for i in 240:
		var a: RefCounted = ANIMO.new()
		a.setup(DNA.generate(1000 + i))
		# UN VICINO CHE STA BENE: è il caso comune, ed era quello degenere
		for d in ANIMO.DRIVES:
			a.drive[d] = 0.0 if d in ANIMO.MALESSERI else 1.0
		var c := {}
		for k in 30:
			var sc := str(a.decide(reaz, "ex", ANIMO.NITIDEZZA_VITA))
			c[sc] = int(c.get(sc, 0)) + 1
		var top := ""
		var topn := 0
		for k2 in c:
			if int(c[k2]) > topn:
				topn = int(c[k2])
				top = str(k2)
		vinte[top] = int(vinte.get(top, 0)) + 1
		ventagli[c.size()] = int(ventagli.get(c.size(), 0)) + 1

	# NESSUNA MORTA: ogni risposta è la preferita di qualcuno
	for r in reaz:
		var q := int(vinte.get(str(r), 0))
		t.ok(q > 0,
				"'%s' è la risposta di qualcuno (%d caratteri su 240)" % [r, q])
	# NESSUNA DOMINANTE: nemmeno la più scelta arriva a un terzo
	var massimo := 0
	for v in vinte.values():
		massimo = maxi(massimo, int(v))
	t.ok(float(massimo) / 240.0 < 0.34,
			"e nessuna domina: la più scelta è il %d%% (era il 52%%)"
			% roundi(float(massimo) / 2.4))

	# E NON È UN DADO: lo STESSO carattere non gira su tutte e sette. Se
	# `decide` tornasse casuale, quasi tutti darebbero 5+ risposte diverse.
	var stretti := 0
	for n in ventagli:
		if int(n) <= 3:
			stretti += int(ventagli[n])
	t.ok(float(stretti) / 240.0 > 0.9,
			"e resta STRETTA: il %d%% dei caratteri sceglie fra tre risposte,"
			% roundi(float(stretti) / 2.4)
			+ " non fra sette — imprevedibile per chi guarda, riconducibile"
			+ " a chi è")


## IL TEMPO NON ROMPE NIENTE. `coppia()` chiede la soglia assoluta per
## FORMARSI, e il conto decade: senza isteresi una coppia nata sul filo si
## scioglieva in quattro giorni di niente — sedici minuti reali — cioè il
## decadimento faceva da solo il lavoro che dovevano fare i gesti.
func _test_l_isteresi_regge_le_coppie(t) -> void:
	var tutti := ["Anna", "Bruno"]
	var righe: Array = []
	for i in AFF.GESTI_VERI_MIN:
		righe.append(_riga("Anna", "Bruno", "veglia", 0))
		righe.append(_riga("Bruno", "Anna", "veglia", 0))
	t.ok(AFF.coppia(righe, "Anna", "Bruno", tutti, 0), "al giorno zero sono una coppia")
	# duecento giorni in cui non succede NIENTE: il conto è quasi svanito…
	t.ok(AFF.conto(righe, "Anna", "Bruno", 200) < AFF.SOGLIA_COPPIA,
			"dopo duecento giorni il conto è sotto la soglia di formazione")
	t.ok(not AFF.coppia(righe, "Anna", "Bruno", tutti, 200),
			"…e non basterebbe più a farli MEttere insieme oggi")
	# …ma restano insieme, perché nessun altro è diventato il loro massimo
	t.ok(AFF.ancora_coppia(righe, "Anna", "Bruno", tutti, 200),
			"E RESTANO INSIEME LO STESSO: formarsi costa, restare no — ci vuole"
			+ " qualcuno altro per non esserlo più, non il calendario")
	# e con qualcuno altro, si lasciano
	var terzo: Array = righe.duplicate(true)
	for i in range(200, 214):
		terzo.append(_riga("Carla", "Bruno", "consolazione", i))
		terzo.append(_riga("Bruno", "Carla", "coraggio", i))
	t.ok(not AFF.ancora_coppia(terzo, "Anna", "Bruno", ["Anna", "Bruno", "Carla"], 214),
			"…e con qualcun altro diventato il suo massimo, sì")


## I GESTI VERI LI EMETTE QUALCUNO — e qui si guarda EMETTERE, non si cerca
## una parola nel sorgente.
##
## Senza gesti pesanti, `coppia()` non può essere vera MAI: è già successo —
## dei tredici tipi il gioco ne emetteva tre, tutti sotto `PESO_VERO`, e le
## sette risposte alla rottura erano codice morto in partita con la suite
## verde su un villaggio che non esiste.
##
## LA VERSIONE PRECEDENTE DI QUESTA PROVA CERCAVA IL LETTERALE `"veglia"`
## DENTRO `Lavori.gd`. Sarebbe rimasta verde con quel nome scritto in un
## commento; ed è rimasta verde per tutto il tempo in cui quella riga,
## emessa VERSO TUTTI in un colpo solo, sterilizzava gli affetti dell'intero
## villaggio. Un controllo sul sorgente non sa distinguere un gesto da una
## parola. Adesso il villaggio gira davvero (banco condiviso con
## `test_gesti_veri`, che è il posto in cui vive tutta la messa in scena) e
## si legge il libro mastro che ne esce.
func _test_i_gesti_veri_li_emette_qualcuno(t) -> void:
	var b := GESTI.banco(t)
	# due mesi di notti vere: la ronda parte, arriva in fondo, e al mattino
	# il rendiconto scrive — nessuna riga messa a mano in questo test
	for giorno in 60:
		GESTI.notte(b)
		GESTI.domani(b)
	var righe := GESTI.righe_di(b)
	t.ok(not righe.is_empty(),
			"facendo girare il gioco, qualcuno EMETTE gesti (%d righe)" % righe.size())

	var pesanti := 0
	var tipi := {}
	for r in righe:
		var tipo := str((r as Dictionary).get("t", ""))
		if absf(float(AFF.GESTI.get(tipo, 0.0))) >= AFF.PESO_VERO:
			pesanti += 1
			tipi[tipo] = true
	t.ok(pesanti >= AFF.GESTI_VERI_MIN,
			"…e ne emette almeno %d di peso VERO (%d): sotto questa soglia"
			% [AFF.GESTI_VERI_MIN, pesanti]
			+ " nessuna coppia potrebbe formarsi e tutto il sistema sarebbe"
			+ " codice morto in partita")
	t.ok(tipi.has("veglia"),
			"la veglia arriva nel libro mastro da chi la fa (Veglia.gd), non"
			+ " più da un giro «verso tutti» nel registro dei lavori")

	# e le righe che sono ARRIVATE bastano davvero a fare una coppia: è la
	# differenza fra un sistema vivo e sette risposte alla rottura che nessuno
	# raggiungerà mai
	var oggi := int((b["dn"] as Node3D).get("day"))
	var coppie := AFF.coppie(righe, GESTI.NOMI, oggi)
	t.ok(coppie.size() >= 1,
			"e da quelle righe — quelle vere, non quelle scritte dal test —"
			+ " nasce almeno una coppia")


# ----------------------------------------------------- la valvola dell'abitudine

## L'ABITUDINE NON È UN GESTO.
##
## Tolto il broadcast, restava il secondo modo di annegare il libro mastro:
## la stessa riga pesante riscritta ogni notte fra le stesse due persone.
## MISURATO: una riga da 0,80 al giorno va a regime a ~41,9 — diciassette
## volte `SOGLIA_COPPIA` — e a quel punto qualunque cosa faccia il giocatore
## (`coraggio` vale 1,20, e succede una volta sola) è rumore di fondo.
##
## ⚠️ QUESTA PROVA HA UN MODO SILENZIOSO DI NON PROVARE NIENTE.
## `Affetti._giorno()` ritorna 1 quando non trova un DayNight: su un banco
## che non fa avanzare il giorno, la valvola sarebbe chiusa SEMPRE, ogni
## asserzione «una riga sola» passerebbe per il motivo sbagliato e nessuno
## si accorgerebbe che `GIORNI_RIPETIZIONE` non è mai stato messo alla
## prova. Perciò la prima cosa che si verifica è che il calendario giri.
func _test_la_valvola_dell_abitudine(t) -> void:
	var b := GESTI.banco(t)
	var aff = b["aff"]
	var dn = b["dn"]
	t.eq(int(aff.call("_giorno")), 1, "il banco parte dal giorno uno")
	dn.day = 5
	t.eq(int(aff.call("_giorno")), 5,
			"IL CALENDARIO GIRA DAVVERO: senza questo, tutto il resto di"
			+ " questa prova passerebbe per il motivo sbagliato")
	dn.day = 1
	(aff.get("_righe") as Array).clear()

	# due volte la stessa notte: una riga sola
	aff.call("gesto", "Anice", "Basilio", "veglia")
	aff.call("gesto", "Anice", "Basilio", "veglia")
	t.eq((aff.get("_righe") as Array).size(), 1,
			"lo stesso gesto pesante due volte nello stesso giorno: UNA riga")

	# un tipo diverso in mezzo NON è una ripetizione: la chiave è la terna
	aff.call("gesto", "Anice", "Basilio", "piatto")
	t.eq((aff.get("_righe") as Array).size(), 2,
			"un «piatto» fra due «veglia» passa: è un altro gesto, non"
			+ " un'abitudine")

	# il verso conta: essere cercati non è cercare
	aff.call("gesto", "Basilio", "Anice", "veglia")
	t.eq((aff.get("_righe") as Array).size(), 3,
			"la veglia nel verso opposto passa: la chiave è la TERNA col verso")

	# sei giorni non bastano, sette sì
	dn.day = 1 + AFF.GIORNI_RIPETIZIONE - 1
	aff.call("gesto", "Anice", "Basilio", "veglia")
	t.eq((aff.get("_righe") as Array).size(), 3,
			"a sei giorni la veglia sulla stessa porta è ancora un'abitudine")
	dn.day = 1 + AFF.GIORNI_RIPETIZIONE
	aff.call("gesto", "Anice", "Basilio", "veglia")
	t.eq((aff.get("_righe") as Array).size(), 4,
			"a sette giorni esatti torna a essere una notizia")

	# I GESTI LEGGERI NON PASSANO MAI DALLA VALVOLA: cento chiacchiere
	# devono poter restare cento chiacchiere (valgono 0,05 l'una apposta)
	var prima := (aff.get("_righe") as Array).size()
	for i in 5:
		aff.call("gesto", "Cedro", "Dalia", "chiacchiera")
	t.eq((aff.get("_righe") as Array).size(), prima + 5,
			"cinque chiacchiere nello stesso giorno restano cinque righe")

	# e la valvola non è un tetto sul villaggio: la stessa notte, verso
	# un'altra persona, la riga si scrive
	prima = (aff.get("_righe") as Array).size()
	aff.call("gesto", "Anice", "Cedro", "veglia")
	t.eq((aff.get("_righe") as Array).size(), prima + 1,
			"…e vegliare su qualcun ALTRO la stessa notte si scrive:"
			+ " la valvola frena l'abitudine, non la persona")


## LA TARATURA, che è il vero motivo per cui la valvola esiste: contare le
## righe non basta, perché il numero che conta è quanto PESANO.
##
## Un mese di luce accesa sulla stessa porta DEVE contare — sarebbe assurdo
## il contrario. Ma deve contare sulla scala dei gesti del giocatore, non
## diciassette volte sopra: `coraggio` vale 1,20 e succede una volta sola,
## e se un'abitudine automatica arrivasse a 40 nessuna cosa fatta dal
## giocatore sposterebbe più niente. Qui si fanno passare trenta notti VERE
## e si misura quanto pesano.
func _test_la_veglia_non_annega_il_giocatore(t) -> void:
	var b := GESTI.banco(t)
	for notte in 30:
		GESTI.notte(b)
		GESTI.domani(b)
	var righe := GESTI.righe_di(b)
	var oggi := int((b["dn"] as Node3D).get("day"))
	var chi := ""
	for r in righe:
		chi = str((r as Dictionary).get("b", ""))
	var quanto := AFF.conto(righe, chi, GESTI.NOMI[0], oggi)
	t.ok(quanto > AFF.SOGLIA_COPPIA,
			"trenta notti di luce accesa contano DAVVERO (%.2f, sopra la"
			% quanto + " soglia della coppia): la valvola frena, non spegne")
	t.ok(quanto < AFF.SOGLIA_COPPIA * 3.0,
			"…ma restano sulla scala dei gesti del giocatore (%.2f contro"
			% quanto
			+ " %.2f): senza la valvola una riga al giorno andava a regime"
			% (AFF.SOGLIA_COPPIA * 3.0)
			+ " a ~41,9, e tutto quello che fa il giocatore diventava rumore")


## LA MEMORIA DELLA VALVOLA STA NELLE RIGHE, non in un campo nuovo — e
## quindi sopravvive gratis al salvataggio. Ma dal JSON il giorno torna
## `float`, e il «mai successo» non può essere un giorno sentinella: con
## `-1` al posto di un booleano, una riga datata a un giorno <= -1 si
## leggerebbe come inesistente e la valvola si aprirebbe di soppiatto.
func _test_la_valvola_si_ricorda_dopo_il_salvataggio(t) -> void:
	var righe := [_riga("Anna", "Bruno", "veglia", 10)]
	t.eq(AFF.giorni_dall_ultimo(righe, "Anna", "Bruno", "veglia", 10), 0,
			"scritta oggi: zero giorni fa")
	t.eq(AFF.giorni_dall_ultimo(righe, "Anna", "Bruno", "veglia", 17), 7,
			"sette giorni dopo: sette")
	t.eq(AFF.giorni_dall_ultimo(righe, "Bruno", "Anna", "veglia", 17), -1,
			"nell'altro verso non è mai successo")
	t.eq(AFF.giorni_dall_ultimo(righe, "Anna", "Bruno", "piatto", 17), -1,
			"e di un altro tipo nemmeno")
	# il giorno che torna dal disco è un float
	var dal_disco := [{"a": "Anna", "b": "Bruno", "t": "veglia", "d": 23.0}]
	t.eq(AFF.giorni_dall_ultimo(dal_disco, "Anna", "Bruno", "veglia", 25), 2,
			"il giorno riletto dal JSON è un float, e la valvola lo legge lo stesso")
	# il giorno ZERO e i giorni negativi non devono farsi passare per «mai»
	t.eq(AFF.giorni_dall_ultimo([_riga("Anna", "Bruno", "veglia", 0)],
			"Anna", "Bruno", "veglia", 3), 3,
			"il giorno zero è un giorno, non un «mai successo»")
	t.eq(AFF.giorni_dall_ultimo([_riga("Anna", "Bruno", "veglia", -5)],
			"Anna", "Bruno", "veglia", 0), 5,
			"…e nemmeno un giorno negativo (col sentinella -1 la valvola si"
			+ " apriva di soppiatto)")
	# fra più righe vince la PIÙ RECENTE
	var tante := [_riga("Anna", "Bruno", "veglia", 2),
			_riga("Anna", "Bruno", "veglia", 30),
			_riga("Anna", "Bruno", "veglia", 11)]
	t.eq(AFF.giorni_dall_ultimo(tante, "Anna", "Bruno", "veglia", 31), 1,
			"fra tante righe conta l'ultima, non la prima trovata")
