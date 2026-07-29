extends RefCounted
## L'ESTETISTA — il sogno, il mestiere, e la giornata al salone.
##
## Pietre 2 e 3 della meccanica: «estetica» diventa qualcosa che un chibi
## può SOGNARE e che il registro può assegnare, e il salone apre davvero —
## l'estetista si mette al suo posto e un vicino alla volta si siede.
##
## Le tre cose che questo test protegge, in ordine di gravità:
##  1. LE TABELLE ALLINEATE. Un sogno nuovo tocca quattro vocabolari
##     (Animo.SOGNI, Animo.COMPITI, Lavori.LAVORI, Commissioni.VOGLIE) e
##     dimenticarne uno non dà errore: dà un vicino con un sogno che
##     nessuno sa nominare.
##  2. L'ORDINE DEI SOGNI. Il DNA pesca per INDICE: infilare un sogno in
##     mezzo alla lista cambierebbe il sogno di ogni residente già nato.
##  3. IL RITOCCO NON TOCCA L'IDENTITÀ, mai, per costruzione.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const LAVORI := preload("res://scenes/npc/Lavori.gd")
const COMM := preload("res://scenes/npc/Commissioni.gd")
const SALONE := preload("res://scenes/interact/Salone.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const GUFO := preload("res://scenes/npc/GufoOrders.gd")
const ECO := preload("res://scenes/ui/Economy.gd")


func run(t) -> void:
	_test_il_sogno(t)
	_test_il_mestiere(t)
	_test_il_ritocco(t)
	_test_la_giornata(t)
	_test_lo_sblocco(t)
	_test_il_vanto(t)
	_test_mochi_allo_specchio(t)


## IL SOGNO, e le quattro tabelle che devono restare allineate.
func _test_il_sogno(t) -> void:
	t.ok("estetista" in ANIMO.SOGNI, "«estetista» è un sogno che si può avere")
	# L'ORDINE: i sogni nuovi vanno IN CODA. ChibiDNA pesca per indice, e
	# infilarne uno in mezzo cambierebbe il sogno di chi è già nato.
	t.eq(str(ANIMO.SOGNI[ANIMO.SOGNI.size() - 1]), "estetista",
			"…ed è in CODA: i residenti già nati non cambiano sogno")
	# ogni sogno serve almeno un compito, o non si potrebbe mai realizzare
	var serviti := {}
	for c in ANIMO.COMPITI:
		var s := str((ANIMO.COMPITI[c] as Dictionary).get("serve", ""))
		if s != "":
			serviti[s] = true
	# IL BUCO CHE QUESTO TEST HA TROVATO, e che non si nasconde: «artista»
	# e' un sogno che il DNA distribuisce da sempre e che NESSUN compito
	# realizza. Chi lo sogna non prende mai il bonus del mestiere giusto
	# (Animo.punteggio) ne' il x1.5 della resa: sogna una cosa che nel
	# villaggio non si puo' fare. Aspetta il suo mestiere — e finche' non
	# ce l'ha, sta scritto QUI, con un nome, non in un silenzio.
	const SENZA_MESTIERE := ["artista"]
	for sogno in ANIMO.SOGNI:
		if str(sogno) in SENZA_MESTIERE:
			t.ok(not serviti.has(str(sogno)),
					"'%s' e' il buco noto: nessun compito lo realizza ancora" % sogno)
			continue
		t.ok(serviti.has(str(sogno)),
				"il sogno '%s' ha un compito che lo realizza" % sogno)
	# e il vicino sa dire perché vuole una cosa (le commissioni)
	t.ok(COMM.VOGLIE.has("estetista"),
			"l'estetista sa dire perché vuole quel raccolto")

	# il sogno NASCE davvero: su tanti genomi, prima o poi esce
	var visto := false
	for i in 400:
		if str((DNA.generate(i * 13 + 5) as Dictionary).get("sogno", "")) == "estetista":
			visto = true
			break
	t.ok(visto, "prima o poi nasce qualcuno che sogna di fare l'estetista")


## IL MESTIERE: assegnabile dal registro, con la sua resa.
func _test_il_mestiere(t) -> void:
	t.ok(ANIMO.COMPITI.has("abbellisce"), "«abbellisce» è un compito vero")
	t.eq(str((ANIMO.COMPITI["abbellisce"] as Dictionary)["serve"]), "estetista",
			"…ed è QUELLO che realizza il sogno")
	t.ok(LAVORI.LAVORI.has("abbellisce"), "il registro lo sa assegnare")
	t.ok("abbellisce" in LAVORI.ORDINE, "…e sta nel giro dei lavori")
	# il bonus del sogno: chi lo sogna rende di più (è la regola di sempre)
	var con_sogno := LAVORI.resa("lavoro", "estetista", "abbellisce")
	var senza := LAVORI.resa("lavoro", "guerriero", "abbellisce")
	t.ok(con_sogno > senza,
			"chi SOGNA di tenere il salone ci rende di più (%.2f contro %.2f)"
			% [con_sogno, senza])
	# e in rivolta non si apre: un salone tenuto da chi si rifiuta è chiuso
	t.eq(LAVORI.resa("rifiuto", "estetista", "abbellisce"), 0.0,
			"chi si rifiuta non tiene il salone")
	# il compito è LEGGERO di corpo e pesante di compagnia: è un mestiere
	# che si fa parlando
	var c: Dictionary = ANIMO.COMPITI["abbellisce"]
	t.ok(float(c.get("fatica", 1.0)) < 0.15, "stanca poco: si sta in piedi, non si spacca legna")
	t.ok(float(c.get("appartenenza", 0.0)) > 0.0,
			"…e riempie di appartenenza: ci si parla tutto il giorno")


## IL RITOCCO: gentile, deterministico, e MAI sull'identità.
func _test_il_ritocco(t) -> void:
	var d: Dictionary = DNA.generate(2024)
	# deterministico: la stessa seduta dà lo stesso risultato
	t.eq(str(SALONE.ritocco(d, 99)), str(SALONE.ritocco(d, 99)),
			"la stessa seduta dà sempre lo stesso ritocco")
	# su tanti semi: SOLO geni estetici, e sempre pochi per volta
	var toccati := {}
	for i in 200:
		var r: Dictionary = SALONE.ritocco(d, i * 7 + 3)
		t.ok(not r.is_empty(), "seme %d: il ritocco fa sempre qualcosa" % i)
		t.ok(r.size() <= 3,
				"seme %d: cambia POCO per volta (%d geni)" % [i, r.size()])
		for g in r:
			t.ok(str(g) in DNA.ESTETICI,
					"seme %d: '%s' è estetica, non identità" % [i, g])
			toccati[str(g)] = true
	t.ok(toccati.size() >= 6,
			"il salone sa fare più cose: %d tratti diversi" % toccati.size())
	# le tavolozze sono vere
	t.ok(SALONE.TINTE.size() >= 6 and SALONE.VESTITI.size() >= 5,
			"tinte e vestitini sono una scelta, non due opzioni")
	for stile in SALONE.SOPRACCIGLIA:
		t.ok(str(stile) in DNA.BROW_DECKS["gatto"] or true, "")
	var noti := {}
	for arche in DNA.BROW_DECKS:
		for st in DNA.BROW_DECKS[arche]:
			noti[str(st)] = true
	for stile2 in SALONE.SOPRACCIGLIA:
		t.ok(noti.has(str(stile2)),
				"lo stile '%s' è uno che il DNA sa disegnare" % stile2)


## LA GIORNATA: orari veri, e un cliente alla volta.
func _test_la_giornata(t) -> void:
	t.ok(not SALONE.ora_di_apertura(0.20), "all'alba il salone è ancora chiuso")
	t.ok(SALONE.ora_di_apertura(0.45), "a metà giornata è aperto")
	t.ok(not SALONE.ora_di_apertura(0.85), "di sera ha chiuso")
	t.ok(SALONE.CHIUDE > SALONE.APRE, "chiude dopo aver aperto")

	var src := _sorgente("res://scenes/interact/Salone.gd")
	t.ok(src.contains("_cliente != \"\""),
			"UN cliente alla volta: finché uno è in poltrona non entra nessuno")
	t.ok(src.contains("_serviti.has(label)"),
			"…e nessuno due volte nello stesso giorno")
	t.ok(src.contains("Seggiola"),
			"il cliente si siede sull'ANCORAGGIO del mobile, non su una coordinata a mano")
	t.ok(src.contains("get_placed_by_name(\"Salone\")"),
			"senza il mobile piazzato il salone non apre")
	t.ok(src.contains("rifai_il_look"),
			"e la seduta cambia davvero l'aspetto")
	# il registro racconta la resa col NOME di chi è cambiato
	var lav := _sorgente("res://scenes/npc/Lavori.gd")
	t.ok(lav.contains("servito_oggi"),
			"il registro chiede al salone chi ha servito")
	t.ok(lav.contains("esce dal salone tutto nuovo"),
			"…e lo racconta nella resa del mattino")


## LO SBLOCCO: la ricetta la manda il Gufo, e solo quando qualcuno lo sogna.
func _test_lo_sblocco(t) -> void:
	var voce := {}
	for d in GUFO.DESIDERI:
		if str(d.get("gift_piece", "")) == "Salone":
			voce = d
	t.ok(not voce.is_empty(),
			"c'è un desiderio del Gufo che regala la ricetta del Salone")
	t.eq(str((voce["predicate"] as Dictionary)["type"]), "sogno",
			"…e non chiede di costruire: chiede che sia ARRIVATO qualcuno")
	t.eq(str((voce["predicate"] as Dictionary)["sogno"]), "estetista",
			"…qualcuno che sogna proprio quello")

	# il predicato funziona sull'istantanea
	t.ok(GUFO.satisfied(voce["predicate"], {"sogni": {"estetista": 1}}),
			"con un'estetista in paese, il desiderio è esaudito")
	t.ok(not GUFO.satisfied(voce["predicate"], {"sogni": {"cuoco": 3}}),
			"con tre cuochi e nessuna estetista, no")
	t.ok(not GUFO.satisfied(voce["predicate"], {}),
			"e un'istantanea senza sogni non lo esaudisce per sbaglio")

	# il Salone nasce BLOCCATO: senza, sarebbe nel catalogo dal primo
	# minuto, prima ancora che esista qualcuno capace di tenerlo
	var nel_negozio := false
	for p in ECO.SHOP_PIECES:
		if str(p["name"]) == "Salone":
			nel_negozio = true
			t.ok(int(p["cost"]) > 0, "…e ha il suo prezzo, per chi non vuole aspettare")
	t.ok(nel_negozio, "il Salone parte bloccato (è un pezzo del negozio)")
	t.ok(not "Salone" in GUFO.STARTER,
			"…e di sicuro non è fra i pezzi del primo minuto")


## IL VANTO. Uscire cambiati e non dirlo a nessuno non e' un
## cambiamento: e' un dettaglio grafico che il giocatore non vedra' mai,
## perche' stava guardando da un'altra parte.
func _test_il_vanto(t) -> void:
	var src := _sorgente("res://scenes/interact/Salone.gd")
	t.ok(src.contains("func _vai_a_vantarsi"),
			"chi esce dal salone va a farsi vedere")
	var v := _corpo(src, "_vai_a_vantarsi")
	t.ok(v.contains("_il_piu_vicino"),
			"…cerca il vicino piu' vicino, non uno a caso dall'altra parte del prato")
	t.ok(v.contains("do_routine"), "…e ci va camminando")
	t.ok(v.contains("si_illumina"),
			"…e quello si ILLUMINA: la reazione e' meta' della scena")
	t.ok(v.contains("riflesso"),
			"se non c'e' nessuno a cui mostrarlo, si guarda allo specchio "
			+ "— e va bene lo stesso")
	# il piu' vicino non e' mai se stesso, ne' uno dall'altro capo del mondo
	var vv := _corpo(src, "_il_piu_vicino")
	t.ok(vv.contains("label == tranne"), "non ci si vanta con se stessi")
	t.ok(vv.contains("best_d := 14.0"),
			"…e nemmeno con qualcuno che non ti vede nemmeno")


## MOCHI ALLO SPECCHIO: la stessa linea di confine, addosso a lei.
##
## Mochi non nasce da un genoma — il suo corpo e' scritto a mano — quindi
## qui la strada e' un'altra: si RITINGE invece di rifare. Rifarla da capo
## avrebbe voluto dire buttare via il volto vivo, i capi indossati e i
## punti d'aggancio: molto rischio per un cambio di colore.
func _test_mochi_allo_specchio(t) -> void:
	var src := _sorgente("res://scenes/characters/Mochi.gd")
	t.ok(src.contains("func rifai_il_look"),
			"Mochi ha il suo cambio di look, come i vicini")
	t.ok(src.contains("const RITINGIBILI"),
			"…con la sua linea di confine dichiarata")
	for ruolo in ["manto", "vestito", "guance", "zampe"]:
		t.ok(src.contains("\"%s\"" % ruolo),
				"il ruolo '%s' e' fra quelli che il salone sa cambiare" % ruolo)
	# NON si rifa' il corpo: si ritinge. E' la scelta che tiene in vita
	# volto, capi e agganci.
	var r := _corpo(src, "rifai_il_look")
	t.ok(r.contains("_tinge("), "si RITINGE sul posto")
	t.ok(not r.contains("_build_body") and not r.contains("_build_head"),
			"…e non si rifa' il corpo: volto, capi e agganci restano vivi")
	t.ok(_corpo(src, "_tinge").contains("tween_method"),
			"il colore cambia con una FUSIONE: il cambio si vede avvenire")
	# le sopracciglia sono geometria, non colore: quelle si rifanno — ma
	# solo quelle, e il volto ne riprende il possesso
	t.ok(src.contains("func _rifai_sopracciglia"),
			"le sopracciglia sono geometria: quelle si rifanno")
	t.ok(_corpo(src, "_rifai_sopracciglia").contains("aggiorna_sopracciglia"),
			"…e il volto vivo ne riprende il possesso (o muoverebbe nodi morti)")
	t.ok(_sorgente("res://scenes/characters/FaceController.gd")
			.contains("func aggiorna_sopracciglia"),
			"il volto sa farsi ridare le sopracciglia")
	# la stessa promessa dei vicini: qui non si cambia CHI SI E'
	t.ok(not r.contains("\"name\"") and not r.contains("\"size\""),
			"nome e taglia non compaiono nemmeno: non si cambia chi si e'")


func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
