extends RefCounted
## LE DUE SOGLIE CHE DEVONO ESSERE UNA SOLA.
## (Fase 5 — il contratto fra il Suggeritore, il Giudice e il ponte.)
##
## Una deduzione attraversa QUATTRO cancelli prima di diventare un nodo del
## grafo, e i primi tre stanno in GDScript mentre il quarto sta in C++:
##
##   1. `Suggeritore.grammatica_deduzione()` — cosa il modello può campionare;
##   2. `Suggeritore._blocco_ricordi_numerati()` — cosa il foglio gli mostra;
##   3. `Giudice.utile()` — cosa il gioco accetta;
##   4. `chibi::inserisci_deduzione` — cosa il mondo incassa.
##
## Fino al 2026-08-12 il quarto aveva una soglia (`!(forza > p_soglia)`) e i
## primi tre no: potavano a `p > 0`, che è la potatura giusta per una LETTERA
## (una lettera che cita un ricordo sbiadito è vera, e `_forza` ha una
## etichetta apposta per dirlo) e quella sbagliata per una deduzione.
## Misurato: a 240 s di età un ricordo pesa 0.250 — passava i primi tre e
## veniva rifiutato dal quarto; su una partita lunga vera **34 deduzioni
## scelte su 118 non entravano**. Il costo non è per il giocatore (il
## silenzio è l'esito buono): è una generazione intera pagata per essere
## buttata, e **la seconda bocciatura è muta** — chi chiama vede «il ponte
## l'ha rifiutata» e nient'altro.
##
## QUESTO FILE NON GUARDA IL SORGENTE. Fa invecchiare un ricordo vero dentro
## un registro vero e confronta i VERDETTI: quello che il gioco promette e
## quello che il mondo incassa devono dire la stessa cosa sulla stessa riga,
## a ogni età. E ha la sua controprova — sopra la soglia i quattro cancelli
## si aprono tutti, o questo file misurerebbe soltanto una porta chiusa.
##
## ⚠️ IL RESIDUO CHE NON SI PROVA QUI, ed è dichiarato in `Suggeritore.gd`:
## fra il foglio e l'incasso c'è la generazione, e in quei secondi il ricordo
## decade ancora. Un ricordo che al foglio pesava appena sopra la soglia può
## scendere sotto mentre il modello scrive. L'ultima parola resta del ponte —
## e la fascia a rischio si misura, non si copre con un margine inventato.

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")

## Il ciclo del villaggio vero: `imposta_ritmo` ne fa la mezza vita (120 s).
const CICLO := 240.0

## La soglia con cui il villaggio decide che un ricordo non conta più. È
## `Visitors.AMMIRA_SOGLIA`; `test_suggeritore._le_soglie_sono_quelle_del_villaggio`
## la lega a `SUG.SOGLIA_TIEPIDO`, e qui si usa QUELLA — se un domani le due
## divergessero, questo file starebbe provando un'altra cosa.
const SOGLIA := SUG.SOGLIA_TIEPIDO

## Le età a cui si guarda. Scelte perché ci cascano dentro i due lati del
## filo: a 180 s un ricordo pesa 0.354 (sopra), a 240 s pesa 0.250 (sotto).
const ETA := [5.0, 60.0, 120.0, 180.0, 240.0, 300.0, 420.0, 600.0]


func run(t) -> void:
	# GUARDIA DURA: senza GDExtension non c'è nessun ponte da far combaciare,
	# e un `return` silenzioso direbbe «tutto bene» di un contratto che non è
	# stato guardato.
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return

	_i_quattro_cancelli_dicono_la_stessa_cosa(t)
	_il_giudice_dice_fra_quante_ha_scelto(t)
	_un_ricordo_sbiadito_si_puo_ancora_RACCONTARE(t)
	_chi_e_sotto_soglia_non_si_offre_e_non_si_mostra(t)
	_il_peso_della_catena_e_una_formula_sola(t)
	_la_catena_vale_il_suo_anello_piu_debole(t)
	_senza_pesi_non_si_pota_niente(t)


# =========================================================================
# IL BANCO — un registro nudo, un ricordo, e il tempo che passa
# =========================================================================

## Un mondo con un vicino e UN ricordo vecchio di `eta` secondi. Si torna
## anche il ritratto, costruito con la funzione vera (`SUG.ritratto`), cioè
## coi pesi che il binario calcola riga per riga.
func _banco(eta: float) -> Dictionary:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(CICLO)
	var id = m.registra(PackedStringArray(["curioso"]), "")
	var costanti: Dictionary = m.debug_grafo_costanti()
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), int(costanti["sogg_nessuno"]))
	_passano(m, eta)
	var rit: Dictionary = SUG.ritratto(m, id, {
		"nome": "la volpina Papavero", "eta": "giovane",
		"indole": ["curioso"], "quirk": "",
		"casa": Vector3(4, 0, 6), "azione": "gironzola", "obiettivo": "",
	}, {"protagonista": "Mochi", "nomi": {}, "compito": "pensiero",
		"stagione": "primavera", "momento": "pomeriggio", "ciclo": CICLO})
	return {"m": m, "id": id, "rit": rit}


## Il tempo passa col passo vero del registro, mai con un timbro finto: il
## tempo dei ricordi lo tiene lui.
func _passano(m, sec: float) -> void:
	var fatto := 0.0
	while fatto < sec - 1e-6:
		var dt: float = minf(0.5, sec - fatto)
		m.avanza(dt, 0.5)
		fatto += dt


# =========================================================================
# IL CASO CHE DEFINISCE IL CONTRATTO
# =========================================================================

## I QUATTRO VERDETTI SULLA STESSA RIGA, a otto età diverse. Il ponte è
## interrogato per ultimo e su un registro APPENA nato ogni volta, così
## l'unica ragione per cui può dire di no è il peso (non una gemella viva,
## non l'anello pieno): se dicesse di no per un'altra ragione, questo caso
## proverebbe un'altra cosa.
##
## E si contano tutti e due i lati: senza almeno un «sì» e almeno un «no»
## questo confronto sarebbe verde anche su un gioco che tace sempre.
func _i_quattro_cancelli_dicono_la_stessa_cosa(t) -> void:
	var aperti := 0
	var chiusi := 0
	for eta in ETA:
		var b := _banco(float(eta))
		var m = b["m"]
		var rit: Dictionary = b["rit"]
		var peso := SUG.peso_riga(rit, 0)

		var offerta := SUG.righe_vive(rit).has(0)
		var mostrata := str(SUG.parti_deduzione(rit).get("utente", "")).contains("  0) ")
		var esito: Dictionary = GIU.utile({"obiettivo": "provvedi_cura", "perche": [0]}, rit, {})
		var incassata := int(m.deduci(int(b["id"]), int(m.maschera_obiettivo("provvedi_cura")),
				PackedInt32Array([0]), SOGLIA)) >= 0

		t.eq(offerta, incassata,
				"a %d s (peso %.3f) la grammatica e il ponte dicono lo stesso" % [int(eta), peso])
		t.eq(bool(esito["ok"]), incassata,
				"a %d s (peso %.3f) il Giudice e il ponte dicono lo stesso" % [int(eta), peso])
		t.eq(mostrata, incassata,
				"a %d s (peso %.3f) il foglio mostra solo ciò che si può incassare"
				% [int(eta), peso])
		if incassata:
			aperti += 1
			t.ok(peso > SOGLIA, "e quando entra, il ricordo pesa più della soglia")
		else:
			chiusi += 1
			t.ok(not (peso > SOGLIA), "e quando non entra, pesa meno")
			t.ok(str(esito["motivo"]).contains("troppo debole"),
					"e il motivo lo DICE: «%s»" % str(esito["motivo"]))
		m.free()
	# LA CONTROPROVA: il filo passa in mezzo alle otto età, non fuori.
	t.ok(aperti >= 3, "ci sono età in cui tutti e quattro dicono di sì (%d)" % aperti)
	t.ok(chiusi >= 3, "e età in cui dicono tutti di no (%d)" % chiusi)


## FRA QUANTE HA SCELTO DAVVERO. «Si genera molto e si tiene poco» ha senso
## solo se c'era molto, e per le deduzioni **non c'è**: misurato su un banco
## appaiato col modello vero, cinque copie danno 1.3 proposte diverse, e
## nessuna delle tre leve provate (l'ordine nella grammatica, la temperatura,
## il top_p) sposta quel numero. Perché il conto non resti invisibile, il
## Giudice lo dice nel motivo.
##
## Qui non serve nessun modello: cinque bozze scritte a mano, di cui tre
## identiche fra loro.
func _il_giudice_dice_fra_quante_ha_scelto(t) -> void:
	var b := _banco(30.0)
	var m = b["m"]
	var rit: Dictionary = b["rit"]
	# un secondo ricordo, così ci sono due righe vive e due catene possibili
	var costanti: Dictionary = m.debug_grafo_costanti()
	m.osserva(int(b["id"]), m.V_PESCA, Vector3(9, 0, 2), int(costanti["sogg_nessuno"]))
	rit = SUG.ritratto(m, int(b["id"]), {
		"nome": "la volpina Papavero", "eta": "giovane", "indole": ["curioso"],
		"quirk": "", "casa": Vector3(4, 0, 6), "azione": "gironzola", "obiettivo": "",
	}, {"protagonista": "Mochi", "nomi": {}, "compito": "pensiero",
		"stagione": "primavera", "momento": "pomeriggio", "ciclo": CICLO})
	t.eq(SUG.righe_vive(rit).size(), 2, "due ricordi reggono una deduzione")

	var uguali := []
	for k in 5:
		uguali.append({"obiettivo": "provvedi_cura", "perche": [1]})
	t.eq(GIU.quante_diverse(uguali), 1, "cinque copie identiche sono UNA proposta")
	var scelta: Dictionary = GIU.scegli_deduzione(uguali, rit, {})
	t.ok(str(scelta["motivo"]).contains("1 proposte diverse su 5"),
			"e il motivo lo dice: «%s»" % str(scelta["motivo"]))
	t.eq(int(scelta["diverse"]), 1, "e il numero esce anche fuori dal testo")

	# LA CONTROPROVA: se le bozze sono davvero diverse, il numero sale — senza
	# di lei questo caso sarebbe verde anche su una funzione che torna sempre 1.
	var varie := [
		{"obiettivo": "provvedi_cura", "perche": [1]},
		{"obiettivo": "provvedi_pancino", "perche": [1]},
		{"obiettivo": "provvedi_cura", "perche": [0]},
		{"obiettivo": "provvedi_cura", "perche": [1, 0]},
		{"obiettivo": "provvedi_cura", "perche": [1]},
	]
	t.eq(GIU.quante_diverse(varie), 4, "quattro proposte diverse su cinque bozze")
	t.ok(str((GIU.scegli_deduzione(varie, rit, {}) as Dictionary)["motivo"])
			.contains("4 proposte diverse su 5"), "e anche questo si legge nel motivo")
	# e l'obiettivo conta quanto i ricordi: due bozze che chiedono cose diverse
	# appoggiandosi allo STESSO ricordo restano due proposte
	t.eq(GIU.quante_diverse([varie[0], varie[1]]), 2,
			"stesso ricordo, obiettivo diverso: due proposte")
	m.free()


## ⚠️ E LA LETTERA NON È CAMBIATA. Questa è la ragione per cui la potatura
## sta in `righe_vive` e non dentro `fatti()`: un ricordo che sbiadisce non è
## una bugia, è un ricordo che sbiadisce — il Gufo lo può ancora raccontare, e
## `_forza` ha una parola apposta per dirlo. Se qualcuno «aggiustasse» la
## soglia spostandola in `fatti()`, questo caso diventerebbe rosso e il gioco
## perderebbe una delle sue quattro etichette del peso.
func _un_ricordo_sbiadito_si_puo_ancora_RACCONTARE(t) -> void:
	var b := _banco(240.0)
	var rit: Dictionary = b["rit"]
	rit["compito"] = "lettera"
	var f: Array = SUG.fatti(rit)
	t.eq(f.size(), 1, "il ricordo sbiadito è ancora un fatto")
	t.eq(str((f[0] as Dictionary)["forza"]), "sta già sbiadendo",
			"e il foglio dice quanto pesa, con la parola giusta")
	t.ok(SUG.citazioni(rit).size() > 0, "e c'è ancora qualcosa di vero da dire")
	t.ok(str(SUG.grammatica(rit)) != "", "e una grammatica con cui dirlo")
	# ma non c'è niente da DEDURRE
	t.eq(SUG.righe_vive(rit).size(), 0, "mentre non regge nessuna deduzione")
	(b["m"] as Object).free()


## COSA NON SI OFFRE E COSA NON SI MOSTRA. Sono due cancelli diversi e vanno
## guardati tutti e due: un ricordo elencato col suo numero ma non ammesso
## dalla grammatica è una trappola per un modello piccolo — lo legge, lo
## sceglie, e il campionatore glielo nega a metà riga.
func _chi_e_sotto_soglia_non_si_offre_e_non_si_mostra(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(CICLO)
	var id = m.registra(PackedStringArray(["curioso"]), "")
	var costanti: Dictionary = m.debug_grafo_costanti()
	var nessuno := int(costanti["sogg_nessuno"])
	# il VECCHIO per primo, così prende l'indice 0 e il nuovo l'indice 1
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), nessuno)
	_passano(m, 300.0)
	m.osserva(id, m.V_PESCA, Vector3(9, 0, 2), nessuno)
	var rit: Dictionary = SUG.ritratto(m, id, {
		"nome": "la volpina Papavero", "eta": "giovane", "indole": ["curioso"],
		"quirk": "", "casa": Vector3(4, 0, 6), "azione": "gironzola", "obiettivo": "",
	}, {"protagonista": "Mochi", "nomi": {}, "compito": "pensiero",
		"stagione": "primavera", "momento": "pomeriggio", "ciclo": CICLO})

	t.eq(SUG.fatti(rit).size(), 2, "due ricordi, tutti e due vivi per una lettera")
	var vive := SUG.righe_vive(rit)
	t.eq(vive.size(), 1, "ma uno solo regge una deduzione")
	t.eq(int(vive[0]), 1, "ed è quello fresco")

	var g := str(SUG.grammatica_deduzione(rit))
	t.ok(g.contains("\"1\""), "la grammatica offre la riga fresca")
	t.ok(not g.contains("\"0\""), "e non offre quella sbiadita")

	var foglio: Dictionary = SUG.parti_deduzione(rit)
	var utente := str(foglio.get("utente", ""))
	t.ok(utente.contains("  1) "), "il foglio mostra la riga fresca")
	t.ok(not utente.contains("  0) "), "e non mostra quella sbiadita")

	# il giro chiuso: TUTTO ciò che la grammatica ammette, il Giudice lo prende
	for combo in SUG._sottoinsiemi(vive, SUG.PERCHE_MAX):
		var esito: Dictionary = GIU.utile({"obiettivo": "provvedi_cura",
				"perche": combo}, rit, {})
		t.ok(bool(esito["ok"]), "%s è azionabile (%s)" % [str(combo), str(esito["motivo"])])
	# e la riga sbiadita, se un modello la scrivesse lo stesso, viene detta
	var no: Dictionary = GIU.utile({"obiettivo": "provvedi_cura", "perche": [0, 1]}, rit, {})
	t.ok(not bool(no["ok"]), "una catena che ne cita una sbiadita non passa")
	t.ok(str(no["motivo"]).contains("troppo debole"), "e il motivo lo dice: «%s»"
			% str(no["motivo"]))
	m.free()


## UNA FORMULA SOLA, DUE LETTURE. `Suggeritore.peso_catena()` di qua e
## `chibi::peso_deduzione` di là devono dare lo STESSO numero sullo stesso
## istante: il primo ordina le bozze, il secondo pota l'anello. Erano due
## implementazioni (il Giudice ne aveva una sua, riga per riga) e nessuna
## sapeva dell'altra.
func _il_peso_della_catena_e_una_formula_sola(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(CICLO)
	var id = m.registra(PackedStringArray(["curioso"]), "")
	var costanti: Dictionary = m.debug_grafo_costanti()
	var nessuno := int(costanti["sogg_nessuno"])
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), nessuno)
	_passano(m, 40.0)
	m.osserva(id, m.V_PESCA, Vector3(9, 0, 2), nessuno)
	_passano(m, 25.0)
	m.osserva(id, m.V_CUCINA, Vector3(2, 0, 8), nessuno)
	var rit: Dictionary = SUG.ritratto(m, id, {
		"nome": "la volpina Papavero", "eta": "giovane", "indole": ["curioso"],
		"quirk": "", "casa": Vector3(4, 0, 6), "azione": "gironzola", "obiettivo": "",
	}, {"protagonista": "Mochi", "nomi": {}, "compito": "pensiero",
		"stagione": "primavera", "momento": "pomeriggio", "ciclo": CICLO})

	var righe := PackedInt32Array([0, 1, 2])
	var i := int(m.deduci(id, int(m.maschera_obiettivo("provvedi_cura")), righe, SOGLIA))
	t.ok(i >= 0, "la catena entra")
	var dd: Array = (m.debug_deduzioni(id) as Dictionary)["deduzioni"]
	t.eq(dd.size(), 1, "e c'è, nel grafo")
	# NIENTE TEMPO IN MEZZO: `debug_deduzioni` legge all'istante di adesso, e
	# il ritratto è stato fotografato allo stesso istante.
	t.almost(SUG.peso_catena(rit, righe), float((dd[0] as Dictionary)["peso"]),
			"il peso della catena è lo stesso numero di qua e di là", 1e-9)
	# e la scheda del Giudice riporta QUEL numero, non un altro
	var scelta: Dictionary = GIU.scegli_deduzione(
			[{"obiettivo": "provvedi_cura", "perche": [0, 1, 2]}], rit, {})
	t.eq(int(scelta["scelta"]), 0, "il Giudice la sceglie")
	t.almost(float((scelta["schede"][0] as Dictionary)["punti"]),
			float((dd[0] as Dictionary)["peso"]),
			"e il punteggio con cui la ordina è quello del ponte", 1e-9)
	m.free()


## L'ANELLO PIÙ DEBOLE, e non la media né la somma: citare tutto quello che
## si può non deve convenire. Si prova sul VALORE, non sulla forma.
func _la_catena_vale_il_suo_anello_piu_debole(t) -> void:
	var rit := {"pesi": PackedFloat64Array([2.0, 0.9, 1.5])}
	t.almost(SUG.peso_catena(rit, [0]), 2.0, "una catena di uno vale quello", 1e-9)
	t.almost(SUG.peso_catena(rit, [0, 2]), 1.5, "di due, il minore", 1e-9)
	t.almost(SUG.peso_catena(rit, [0, 1, 2]), 0.9, "di tre, il più debole", 1e-9)
	t.almost(SUG.peso_catena(rit, []), 0.0, "una catena vuota non vale niente", 1e-9)
	t.almost(SUG.peso_catena(rit, [7]), 0.0, "e una riga che non c'è nemmeno", 1e-9)
	# citare di più non fa salire il punteggio, mai
	t.ok(SUG.peso_catena(rit, [0, 1, 2]) <= SUG.peso_catena(rit, [0, 1]),
			"aggiungere un anello non rende una catena più forte")


## UN RITRATTO SENZA PESI non si pota: è il caso del dizionario scritto a
## mano e del clone senza GDExtension, e il degrado va verso «si può dire».
## Senza questa riga, un banco di prova senza pesi vedrebbe sparire tutte le
## sue righe e il test successivo passerebbe per il motivo sbagliato.
func _senza_pesi_non_si_pota_niente(t) -> void:
	var rit := {
		"nome": "un vicino", "compito": "pensiero", "protagonista": "Mochi",
		"verbi": ["annaffia"], "cose": [], "nomi": {},
		"bandiere": {"sentito": 1, "su_di_me": 2, "detto": 4, "nessuno": -1},
		"ricordi": [{"verbo": 0, "bandiere": 0, "quante": 1,
				"px": 0.0, "pz": 0.0, "quando": 0.0, "soggetto": -1}],
	}
	t.almost(SUG.peso_riga(rit, 0), SUG.PESO_OCCHIATA,
			"un ricordo non misurato vale un'occhiata", 1e-9)
	t.ok(SUG.regge_una_deduzione(rit, 0), "e un'occhiata regge una deduzione")
	t.eq(SUG.righe_vive(rit).size(), 1, "quindi la riga si offre lo stesso")
	# ...ma una riga che non c'è non vale un'occhiata: quello è il degrado
	# opposto, e sarebbe una riga offerta al modello e rifiutata dal ponte.
	t.almost(SUG.peso_riga({"pesi": PackedFloat64Array([1.0])}, 3), 0.0,
			"una riga fuori dall'elenco dei pesi non vale niente", 1e-9)
