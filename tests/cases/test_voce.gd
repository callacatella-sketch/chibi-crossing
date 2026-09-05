extends RefCounted
## LA VOCE: il verbo che porta qualcosa fra due persone.
##
## Questi test tengono chiuse le porte che, aperte, non farebbero rumore:
## una confidenza che scatta a caso (o mai), una famiglia pescata dal
## sistema sbagliato, un destinatario giusto che il codice giudica
## sbagliato (il puzzle diventerebbe una lotteria), la lettera del Gufo
## senza voce in tabella (annota la scarterebbe IN SILENZIO), e le
## tabelle-ponte che puntano a lavori o drive inesistenti.

const VOCE := preload("res://scenes/npc/Voce.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const DIRECTOR := preload("res://scenes/npc/Director.gd")
const LAVORI := preload("res://scenes/npc/Lavori.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const EN_NPC := preload("res://locale/en/npc.gd")


func run(t) -> void:
	_test_le_tre_porte_della_confidenza(t)
	_test_pesca_partenza(t)
	_test_pesca_paura(t)
	_test_pesca_torto(t)
	_test_pesca_affetto(t)
	_test_pesca_desiderio(t)
	_test_la_priorita_e_il_silenzio(t)
	_test_la_scadenza(t)
	_test_destinatario_giusto(t)
	_test_il_piu_caro(t)
	_test_le_tabelle_ponte(t)
	_test_la_lettera_del_gufo(t)
	_test_persistenza(t)
	_test_i_gesti_entrano_col_nome_giusto(t)


## Le tre porte: la fiducia (giorni di Filo), il bisogno (umore +
## regolazione), il corpo che trabocca (arousal). Nessuna da sola basta.
func _test_le_tre_porte_della_confidenza(t) -> void:
	# senza fiducia non si apre NIENTE, nemmeno chi sta malissimo
	t.ok(not VOCE.si_confida(-0.9, 0.9, 0.0, 0),
			"senza giorni di Filo non si confida nessuno")
	t.ok(not VOCE.si_confida(-0.9, 0.9, 0.0, VOCE.FIDUCIA_GIORNI - 1),
			"un giorno sotto la soglia è ancora sotto la soglia")
	# il bisogno: umore a terra E regolazione a terra
	t.ok(VOCE.si_confida(-0.5, 0.0, 0.2, VOCE.FIDUCIA_GIORNI),
			"umore basso e regolazione a terra: ha bisogno di dirlo")
	t.ok(not VOCE.si_confida(-0.5, 0.0, 0.9, VOCE.FIDUCIA_GIORNI),
			"con la regolazione piena si tiene tutto dentro")
	t.ok(not VOCE.si_confida(0.3, 0.0, 0.2, VOCE.FIDUCIA_GIORNI),
			"di buon umore non c'è niente che pesi")
	# il corpo che trabocca: arousal alto parla anche senza bisogno
	t.ok(VOCE.si_confida(0.3, 0.8, 0.9, VOCE.FIDUCIA_GIORNI),
			"con l'arousal alto non riesce a stare zitto")
	# il riserbo premiato: ogni voce taciuta abbassa la porta
	t.ok(VOCE.si_confida(-0.5, 0.0, 0.2, VOCE.FIDUCIA_GIORNI - 1, 1),
			"chi ha già taciuto una voce si merita la confidenza prima")
	t.ok(not VOCE.si_confida(-0.5, 0.0, 0.2, 0, 99),
			"ma nemmeno il riserbo apre la porta il giorno dell'arrivo")


## La paura di partire: la scala a un passo dalla diserzione, ed è una
## MICCIA — se non fai niente, simula_giorno fa il suo lavoro.
func _test_pesca_partenza(t) -> void:
	var idx = ANIMO.indice(VOCE.GRADINO_PARTENZA)
	t.ok(idx >= 0, "il gradino della partenza esiste sulla scala")
	t.ok(idx < ANIMO.indice("diserzione"),
			"…ed è PRIMA della diserzione: novanta secondi non bastano a nessuno")
	var voce = VOCE.pesca_voce("riccio-1", {"gradino": idx}, 10)
	t.eq(str(voce.get("famiglia", "")), "partenza",
			"al gradino del confronto la voce è la partenza")
	t.ok(bool(voce.get("miccia", false)), "la partenza è una miccia")
	t.eq(int(voce.get("giorno", -1)), 10, "la voce porta il giorno in cui è nata")
	voce = VOCE.pesca_voce("riccio-1", {"gradino": idx - 1}, 10)
	t.ok(str(voce.get("famiglia", "")) != "partenza",
			"un gradino sotto, la partenza non è ancora nell'aria")


## Una paura: il marchio di luogo più carico oltre la soglia
## dell'evitamento. I marchi sulle persone non c'entrano.
func _test_pesca_paura(t) -> void:
	var dati = {"marchi": {"luogo|catasta": {"carica": -0.6}}}
	var voce = VOCE.pesca_voce("riccio-1", dati, 3)
	t.eq(str(voce.get("famiglia", "")), "paura", "un marchio forte diventa una paura")
	t.eq(str(voce.get("dettaglio", "")), "catasta", "…e dice DOVE")
	t.ok(not bool(voce.get("miccia", true)), "una paura non è una miccia")
	# sotto la soglia non è una confidenza: è una giornata storta
	voce = VOCE.pesca_voce("riccio-1", {"marchi": {"luogo|orto": {"carica": -0.3}}}, 3)
	t.ok(voce.is_empty(), "un marchio tiepido non si confida")
	# fra due paure si dice la più grossa
	dati = {"marchi": {"luogo|orto": {"carica": -0.5}, "luogo|bosco": {"carica": -0.8}}}
	voce = VOCE.pesca_voce("riccio-1", dati, 3)
	t.eq(str(voce.get("dettaglio", "")), "bosco", "fra due paure vince la più carica")
	# i marchi sulle PERSONE non sono luoghi: non escono da questa porta
	voce = VOCE.pesca_voce("riccio-1", {"marchi": {"chi|giocatore": {"carica": -0.9}}}, 3)
	t.ok(voce.is_empty(), "un marchio su una persona non è una paura di luogo")


## Un torto: il lavoro che TRADISCE il sogno (Animo.COMPITI), non un
## semplice «non è quello che sognavo».
func _test_pesca_torto(t) -> void:
	# "artista" è nella lista `tradisce` della guardia
	var voce = VOCE.pesca_voce("riccio-1", {"lavoro": "guardia", "sogno": "artista"}, 3)
	t.eq(str(voce.get("famiglia", "")), "torto", "il lavoro che tradisce il sogno è un torto")
	t.eq(str(voce.get("dettaglio", "")), "guardia", "…e il dettaglio è il lavoro")
	# chi sognava proprio quello non ha nessun torto
	voce = VOCE.pesca_voce("riccio-1", {"lavoro": "guardia", "sogno": "guerriero"}, 3)
	t.ok(voce.is_empty(), "il lavoro sognato non è mai un torto")
	# un mestiere che non tradisce nessuno (esplora) non produce torti
	voce = VOCE.pesca_voce("riccio-1", {"lavoro": "esplora", "sogno": "artista"}, 3)
	t.ok(voce.is_empty(), "un lavoro che non tradisce non è un torto")
	# senza lavoro assegnato non c'è torto possibile
	voce = VOCE.pesca_voce("riccio-1", {"lavoro": "", "sogno": "artista"}, 3)
	t.ok(voce.is_empty(), "senza incarico nessun torto")


## Un affetto non detto: io ci tengo tanto, lui non lo sa.
func _test_pesca_affetto(t) -> void:
	var dati = {"amici_miei": {"riccio-2": 0.7}, "amici_loro": {"riccio-2": 0.05}}
	var voce = VOCE.pesca_voce("riccio-1", dati, 3)
	t.eq(str(voce.get("famiglia", "")), "affetto", "l'amicizia non reciproca è un affetto non detto")
	t.eq(str(voce.get("dettaglio", "")), "riccio-2", "…e dice PER CHI")
	# se è reciproca non c'è niente da dire: lo sanno già
	dati = {"amici_miei": {"riccio-2": 0.7}, "amici_loro": {"riccio-2": 0.5}}
	voce = VOCE.pesca_voce("riccio-1", dati, 3)
	t.ok(voce.is_empty(), "un'amicizia reciproca non è una confidenza")
	# e un affetto tiepido nemmeno
	dati = {"amici_miei": {"riccio-2": 0.3}, "amici_loro": {}}
	voce = VOCE.pesca_voce("riccio-1", dati, 3)
	t.ok(voce.is_empty(), "un affetto tiepido non pesa abbastanza da confidarlo")


## Un desiderio: il drive più a terra fra quelli che un mestiere sa colmare.
func _test_pesca_desiderio(t) -> void:
	var voce = VOCE.pesca_voce("riccio-1", {"drive_male": {"noia": 0.8}}, 3)
	t.eq(str(voce.get("famiglia", "")), "desiderio", "un drive a terra è un desiderio")
	t.eq(str(voce.get("dettaglio", "")), "noia", "…e dice QUALE")
	voce = VOCE.pesca_voce("riccio-1", {"drive_male": {"noia": 0.5}}, 3)
	t.ok(voce.is_empty(), "un drive così così non si confida")
	# fra due mancanze si dice la più grossa
	voce = VOCE.pesca_voce("riccio-1",
			{"drive_male": {"noia": 0.7, "sicurezza": 0.9}}, 3)
	t.eq(str(voce.get("dettaglio", "")), "sicurezza", "fra due mancanze vince la peggiore")
	# la stima e l'autonomia non passano da qui: non si regalano per
	# interposta persona
	voce = VOCE.pesca_voce("riccio-1", {"drive_male": {"stima": 0.99}}, 3)
	t.ok(voce.is_empty(), "la stima non è un desiderio che un mestiere colma")


## La priorità è il peso: partenza > paura > torto > affetto > desiderio.
## E chi non ha niente da dire non dice niente.
func _test_la_priorita_e_il_silenzio(t) -> void:
	var tutto = {
		"gradino": ANIMO.indice("confronto"),
		"marchi": {"luogo|catasta": {"carica": -0.9}},
		"lavoro": "guardia", "sogno": "artista",
		"amici_miei": {"riccio-2": 0.9}, "amici_loro": {},
		"drive_male": {"noia": 0.99},
	}
	var voce = VOCE.pesca_voce("riccio-1", tutto, 3)
	t.eq(str(voce.get("famiglia", "")), "partenza",
			"la paura di partire pesa più di tutte")
	tutto.erase("gradino")
	voce = VOCE.pesca_voce("riccio-1", tutto, 3)
	t.eq(str(voce.get("famiglia", "")), "paura", "poi viene la paura")
	tutto.erase("marchi")
	voce = VOCE.pesca_voce("riccio-1", tutto, 3)
	t.eq(str(voce.get("famiglia", "")), "torto", "poi il torto")
	tutto["lavoro"] = ""
	voce = VOCE.pesca_voce("riccio-1", tutto, 3)
	t.eq(str(voce.get("famiglia", "")), "affetto", "poi l'affetto non detto")
	tutto["amici_loro"] = {"riccio-2": 0.5}
	voce = VOCE.pesca_voce("riccio-1", tutto, 3)
	t.eq(str(voce.get("famiglia", "")), "desiderio", "e per ultimo il desiderio")
	t.ok(VOCE.pesca_voce("riccio-1", {}, 3).is_empty(),
			"chi sta bene non ha niente da confidare — e il sistema tace")


## Quattro giorni, come le pagine del Taccuino: poi «l'altro giorno» non
## si può più dire.
func _test_la_scadenza(t) -> void:
	var voce = {"famiglia": "paura", "giorno": 3}
	t.ok(not VOCE.scaduta(voce, 3), "il giorno stesso è viva")
	t.ok(not VOCE.scaduta(voce, 3 + VOCE.GIORNI_VOCE), "l'ultimo giorno è ancora viva")
	t.ok(VOCE.scaduta(voce, 4 + VOCE.GIORNI_VOCE), "il giorno dopo è scaduta")
	t.ok(VOCE.scaduta({}, 0), "una voce senza giorno è scaduta da sempre")
	t.eq(VOCE.GIORNI_VOCE, DIRECTOR.TACCUINO_GIORNI,
			"la voce vive quanto una pagina del taccuino: è la stessa memoria")


## Il destinatario giusto sta DENTRO i sistemi, famiglia per famiglia.
func _test_destinatario_giusto(t) -> void:
	# paura → un amico vero di chi si è confidato
	var voce = {"famiglia": "paura", "da": "riccio-1", "dettaglio": "catasta"}
	var ctx = {"amici_di_da": {"riccio-2": 0.6, "riccio-3": 0.2}}
	t.ok(VOCE.destinatario_giusto(voce, "riccio-2", ctx),
			"la paura si porta all'amico vero")
	t.ok(not VOCE.destinatario_giusto(voce, "riccio-3", ctx),
			"un conoscente non basta: non lo accompagnerebbe")
	# torto → chi SOGNA proprio quel lavoro
	voce = {"famiglia": "torto", "da": "riccio-1", "dettaglio": "guardia"}
	t.ok(VOCE.destinatario_giusto(voce, "riccio-2", {"sogno_dest": "guerriero"}),
			"il torto si porta a chi sogna quel lavoro")
	t.ok(not VOCE.destinatario_giusto(voce, "riccio-2", {"sogno_dest": "cuoco"}),
			"a chi sogna altro il lavoro non interessa")
	# desiderio → chi FA il mestiere che colma quel drive
	voce = {"famiglia": "desiderio", "da": "riccio-1", "dettaglio": "sicurezza"}
	t.ok(VOCE.destinatario_giusto(voce, "riccio-2", {"incarico_dest": "guardia"}),
			"la paura della notte si porta a chi fa la guardia")
	t.ok(not VOCE.destinatario_giusto(voce, "riccio-2", {"incarico_dest": "cucina"}),
			"il cuoco non può vegliare su nessuno")
	voce = {"famiglia": "desiderio", "da": "riccio-1", "dettaglio": "fatica"}
	t.ok(VOCE.destinatario_giusto(voce, "riccio-2", {"incarico_dest": "cucina"}),
			"la stanchezza si porta a chi cucina")
	# affetto → l'altro in persona
	voce = {"famiglia": "affetto", "da": "riccio-1", "dettaglio": "riccio-2"}
	t.ok(VOCE.destinatario_giusto(voce, "riccio-2", {}),
			"l'affetto si porta all'altro in persona")
	t.ok(not VOCE.destinatario_giusto(voce, "riccio-3", {}),
			"…e a nessun altro")
	# partenza → il più caro fra i suoi
	voce = {"famiglia": "partenza", "da": "riccio-1", "dettaglio": ""}
	t.ok(VOCE.destinatario_giusto(voce, "riccio-2", {"piu_caro": "riccio-2"}),
			"la partenza si porta al più caro")
	t.ok(not VOCE.destinatario_giusto(voce, "riccio-3", {"piu_caro": "riccio-2"}),
			"chiunque altro è quello sbagliato")
	# una famiglia sconosciuta non ha destinatari giusti
	t.ok(not VOCE.destinatario_giusto({"famiglia": "boh"}, "riccio-2", {}),
			"una famiglia ignota non premia nessuno")


func _test_il_piu_caro(t) -> void:
	t.eq(VOCE.piu_caro({}), "", "chi non ha amici non ha un più caro")
	t.eq(VOCE.piu_caro({"a": 0.3, "b": 0.8, "c": 0.5}), "b",
			"il più caro è l'arco più pesante")


## Le tabelle-ponte: se puntano a un lavoro o a un drive che non esiste,
## il puzzle ha una porta che non si apre MAI — e nessun errore lo dice.
func _test_le_tabelle_ponte(t) -> void:
	for drive in VOCE.LAVORO_PER_DRIVE:
		t.ok(drive in ANIMO.DRIVES,
				"il drive «%s» esiste nell'Animo" % drive)
		var lavoro = str(VOCE.LAVORO_PER_DRIVE[drive])
		t.ok(LAVORI.LAVORI.has(lavoro),
				"il mestiere «%s» esiste nel registro dei lavori" % lavoro)
		t.ok(ANIMO.COMPITI.has(lavoro),
				"…e l'Animo sa cosa fa il mestiere «%s»" % lavoro)
	# ogni luogo che il limbico può marchiare si sa anche DIRE
	for lavoro in VISITORS.LUOGO_DEL_LAVORO:
		var luogo = str(VISITORS.LUOGO_DEL_LAVORO[lavoro])
		t.ok(VOCE.LUOGO_DETTO.has(luogo),
				"il luogo «%s» si sa dire dentro una confidenza" % luogo)
	# e ogni modo di dirlo ha la sua voce inglese: LUOGO_DETTO passa da
	# L10n.t() con chiave DINAMICA, che il guardiano dei letterali non vede
	for luogo in VOCE.LUOGO_DETTO:
		var detto = str(VOCE.LUOGO_DETTO[luogo])
		t.ok(EN_NPC.T.has(detto),
				"«%s» ha la sua traduzione inglese" % detto)


## La lettera del silenzio: se "voce_taciuta" non sta in TACCUINO_LETTERE,
## Director.annota la scarta IN SILENZIO e il Gufo non scrive mai.
func _test_la_lettera_del_gufo(t) -> void:
	t.ok(DIRECTOR.TACCUINO_LETTERE.has("voce_taciuta"),
			"la voce taciuta ha la sua pagina nel taccuino del Gufo")
	var lettera = DIRECTOR.TACCUINO_LETTERE.get("voce_taciuta", {})
	t.ok(not bool(lettera.get("cita", true)),
			"la lettera non cita niente: il Gufo non chiede cos'era")
	var testo = str(lettera.get("text_key", ""))
	t.ok(testo.length() > 40, "la lettera è una lettera, non un'etichetta")
	t.ok(EN_NPC.T.has(testo), "…e ha la sua traduzione inglese")


## Il salvataggio è JSON: il giorno torna float e va rimesso intero, o la
## scadenza si romperebbe al primo ricaricamento.
func _test_persistenza(t) -> void:
	var v = VOCE.new()
	v._voce = {"famiglia": "paura", "da": "riccio-1", "dettaglio": "catasta",
			"giorno": 7, "miccia": false}
	v._riserbo = {"riccio-2": 2}
	var salvato = v.save_extra()
	# il giro su disco: stringify e riparse, come fa il salvataggio vero
	var tornato = JSON.parse_string(JSON.stringify(salvato))
	var v2 = VOCE.new()
	v2.load_extra(tornato)
	var voce = v2.voce_attiva()
	t.eq(str(voce.get("famiglia", "")), "paura", "la voce sopravvive al disco")
	t.ok(voce.get("giorno") is int, "il giorno torna INTERO dopo il JSON")
	t.eq(int(voce.get("giorno", 0)), 7, "…e vale quello che valeva")
	t.eq(int(v2._riserbo.get("riccio-2", 0)), 2, "il riserbo sopravvive")
	t.ok(not VOCE.scaduta(voce, 7 + VOCE.GIORNI_VOCE),
			"la scadenza funziona anche sulla voce ricaricata")
	v.free()
	v2.free()


## ⚠️ I GESTI DELLA VOCE ENTRANO NEL MASTRO CON L'ANAGRAFE GIUSTA.
##
## Tutta la Voce lavora per ETICHETTA («la volpina Pepita»), il libro
## mastro degli Affetti per NOME del DNA («Pepita»). Fino al 2026-09-04
## `_gesto_affetti` passava la label cruda, e i TRE GESTI PIÙ PESANTI che
## il giocatore possa provocare — `coraggio` (1.20), `consolazione` (1.00),
## `fianco` (0.35) — finivano nel mastro con una chiave che nessun lettore
## usa mai: `conto()` non li vedeva, `GESTI_VERI_MIN` non li contava, e
## nessuna coppia poteva nascere da lì. Righe fantasma che occupavano
## anche il posto nella potatura.
##
## ⚠️ E LA SUITE ERA VERDE. Nessuna asserzione, in tutto il progetto,
## guardava che cosa la Voce SCRIVE: si provava che cosa PESCA (le cinque
## famiglie) e che cosa DICE (le tabelle-ponte), mai dove finisce quello
## che fa. La mutazione che rende rosso questo caso è rimettere la label:
## `_affetti.call("gesto", da, verso, tipo)`.
func _test_i_gesti_entrano_col_nome_giusto(t) -> void:
	var AFFETTI := load("res://scenes/npc/Affetti.gd")
	# un registro finto che si limita a REGISTRARE cosa gli arriva: non
	# ri-implementa niente di quello che si sta provando (la lezione del
	# `Corpo` di test_deduzioni), dice solo con quale chiave è stato chiamato
	var spia := Node.new()
	spia.set_script(GDScript.new())
	var libro: Array = []
	spia.set_meta("libro", libro)

	var voce := VOCE.new()
	var vis := VISITORS.new()
	# ⚠️ `_residents` è `Array[Dictionary]`, e un `set()` con un Array NUDO
	# non assegna e NON DICE NIENTE (la trappola è già scritta nel CLAUDE.md,
	# a proposito del finto BuildSystem di `test_insieme`): il fixture
	# restava vuoto, `_nome_da_label` ripiegava sul suo `return label`, e il
	# caso falliva accusando la cura invece del proprio banco.
	var abitanti: Array[Dictionary] = [
		{"label": "la volpina Pepita", "dna": {"name": "Pepita"}},
		{"label": "il gattino Mirtillo", "dna": {"name": "Mirtillo"}},
	]
	vis.set("_residents", abitanti)
	voice_cabla(voce, vis)

	# la conversione è quella VERA di Visitors, non una copia del test
	t.eq(vis._nome_da_label("la volpina Pepita"), "Pepita",
			"la label si converte nel nome del DNA")
	t.eq(vis._nome_da_label("il gattino Mirtillo"), "Mirtillo",
			"e vale per tutti e due")

	# e quello che la Voce manda agli Affetti dev'essere il NOME
	var visto: Array = []
	voce.set("_affetti", _spia_affetti(visto))
	voce.call("_gesto_affetti", "la volpina Pepita", "il gattino Mirtillo",
			"coraggio")
	t.eq(visto.size(), 1, "il gesto arriva agli Affetti")
	if visto.size() == 1:
		var g: Dictionary = visto[0]
		t.eq(str(g.get("da", "")), "Pepita",
				"e chi lo fa è il NOME, non l'etichetta (%s)" % str(g.get("da", "")))
		t.eq(str(g.get("verso", "")), "Mirtillo",
				"e chi lo riceve pure (%s)" % str(g.get("verso", "")))
		t.eq(str(g.get("tipo", "")), "coraggio", "e il tipo passa intatto")

	# LA CONTROPROVA CHE CONTA: con quelle chiavi il conto le VEDE, e con
	# le label no. Senza questa metà, il caso sopra proverebbe una
	# conversione senza dire perché serve.
	var aff = AFFETTI.new()
	var oggi := 0
	var righe_nome: Array = [
		{"a": "Mirtillo", "b": "Pepita", "t": "coraggio", "d": oggi},
		{"a": "Mirtillo", "b": "Pepita", "t": "consolazione", "d": oggi},
		{"a": "Mirtillo", "b": "Pepita", "t": "piatto", "d": oggi},
	]
	var righe_label: Array = [
		{"a": "il gattino Mirtillo", "b": "la volpina Pepita", "t": "coraggio", "d": oggi},
		{"a": "il gattino Mirtillo", "b": "la volpina Pepita", "t": "consolazione", "d": oggi},
		{"a": "il gattino Mirtillo", "b": "la volpina Pepita", "t": "piatto", "d": oggi},
	]
	var c_nome: float = AFFETTI.conto(righe_nome, "Pepita", "Mirtillo", oggi, 0.5)
	var c_label: float = AFFETTI.conto(righe_label, "Pepita", "Mirtillo", oggi, 0.5)
	t.ok(c_nome > 0.0, "col nome il conto vede i gesti (%.3f)" % c_nome)
	t.almost(c_label, 0.0,
			"con le label il conto non vede NIENTE — ed è il difetto che c'era", 0.0001)
	aff.free()
	voce.free()
	vis.free()


## Un registro che REGISTRA e basta: appende quel che gli arriva.
func _spia_affetti(dove: Array) -> Node:
	var n := Node.new()
	var sc := GDScript.new()
	sc.source_code = """
extends Node
var visto: Array = []
func gesto(da: String, verso: String, tipo: String) -> void:
	visto.append({"da": da, "verso": verso, "tipo": tipo})
"""
	sc.reload()
	n.set_script(sc)
	n.set("visto", dove)
	return n


func voice_cabla(voce, vis) -> void:
	voce.set("_visitors", vis)
