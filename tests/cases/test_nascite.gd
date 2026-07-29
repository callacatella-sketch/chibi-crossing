extends RefCounted
## LE NUOVE LEVE: nascere, crescere, e portarsi addosso qualcosa di chi
## è partito.
##
## Tutto quello che DECIDE una nascita è puro apposta: farlo a mano
## vorrebbe dire giocare quattro stagioni con le dita incrociate. Qui si
## prova in un secondo, e si prova la cosa che conta davvero — che le
## regole cozy (una primavera, una coppia vera, un lettino libero, mai
## nel lutto) non si possano aggirare per sbaglio.

const DNA = preload("res://scenes/npc/ChibiDNA.gd")
const NASCITE = preload("res://scenes/world/Nascite.gd")
const CHIBIESE = preload("res://audio/Chibiese.gd")
const LEGAMI = preload("res://scenes/world/Legami.gd")
const MAIL = preload("res://scenes/interact/Mail.gd")
const CONGEDO = preload("res://scenes/world/Congedo.gd")


func run(t) -> void:
	_test_sesso_dal_nome(t)
	_test_incrocio_somiglia_a_entrambi(t)
	_test_incrocio_deterministico(t)
	_test_incrocio_ha_tutte_le_chiavi(t)
	_test_lentiggini_recessive(t)
	_test_orecchie_rinormalizzate(t)
	_test_eredita_di_chi_e_partito(t)
	_test_quando_si_nasce(t)
	_test_la_coppia(t)
	_test_il_verso_della_crescita(t)
	_test_la_parola_storta(t)
	_test_voce_da_cucciolo(t)
	_test_tabelle_allineate(t)
	_test_fili_attaccati(t)


## Il sesso si LEGGE dal nome, non è un gene: così vale anche per i
## residenti salvati prima che il villaggio sapesse cosa fosse una
## nascita, e non cambia mai — nemmeno dopo un giro in JSON, che
## sarebbe successo derivandolo dal seed (i float grossi perdono cifre).
func _test_sesso_dal_nome(t) -> void:
	t.eq(DNA.sesso({"name": "Fragolina"}), "f", "Fragolina è una bambina")
	t.eq(DNA.sesso({"name": "Timo"}), "m", "Timo è un bambino")
	t.eq(DNA.sesso({}), "m", "senza nome non si esplode: si risponde qualcosa")
	# e i due elenchi non si contraddicono
	var f := 0
	for n in DNA.NAMES:
		if n in DNA.NOMI_F:
			f += 1
	t.ok(f > 0 and f < DNA.NAMES.size(),
			"fra i ventotto nomi ci sono sia bambine sia bambini (%d femmine)" % f)
	var fn := 0
	for n in DNA.NAMES_NATI:
		if n in DNA.NOMI_F:
			fn += 1
	t.ok(fn > 0 and fn < DNA.NAMES_NATI.size(),
			"e anche fra i nomi di chi nasce qui (%d femmine su %d)"
			% [fn, DNA.NAMES_NATI.size()])
	# i nomi di chi nasce sono NUOVI: se pescassero dai ventotto posti,
	# a villaggio pieno non resterebbe un nome per il primo che nasce
	for n in DNA.NAMES_NATI:
		t.ok(not n in DNA.NAMES, "«%s» non ruba un nome dei residenti" % n)


## Un figlio somiglia a entrambi: i caratteri continui devono cadere
## FRA i due genitori (più lo scarto), mai fuori dal mondo.
func _test_incrocio_somiglia_a_entrambi(t) -> void:
	var a := DNA.generate(101)
	var b := DNA.generate(202)
	var vicini := 0
	for s in 40:
		var c = DNA.incrocia(a, b, 1000 + s)
		for k in ["eye_r", "eye_gap", "size", "head_scale", "blush"]:
			var lo: float = minf(float(a[k]), float(b[k]))
			var hi: float = maxf(float(a[k]), float(b[k]))
			var v := float(c[k])
			# dentro l'intervallo dei genitori, o appena fuori per lo
			# scarto: mai il doppio, mai la metà
			t.ok(v >= lo - 0.2 and v <= hi + 0.2,
					"%s del figlio (%.3f) sta fra i genitori [%.3f, %.3f]"
					% [k, v, lo, hi])
		if str(c["archetype"]) == str(a["archetype"]) \
				or str(c["archetype"]) == str(b["archetype"]):
			vicini += 1
	t.eq(vicini, 40, "l'archetipo è SEMPRE di uno dei due: non esistono terze specie")


## Stesso seme, stesso figlio. Senza questo, un cucciolo salvato
## rinascerebbe con un'altra faccia al primo riavvio.
func _test_incrocio_deterministico(t) -> void:
	var a := DNA.generate(7)
	var b := DNA.generate(8)
	var c1 = DNA.incrocia(a, b, 4242)
	var c2 = DNA.incrocia(a, b, 4242)
	for k in c1:
		t.eq(str(c1[k]), str(c2[k]), "il gene «%s» è deterministico" % k)


## Il figlio deve avere TUTTE le chiavi di un genoma vero: ChibiBuilder
## ne legge una dozzina senza rete (dna["fur"], non dna.get) e un cucciolo
## con una chiave in meno farebbe crashare la costruzione del corpo.
func _test_incrocio_ha_tutte_le_chiavi(t) -> void:
	var atteso := DNA.generate(3)
	var c = DNA.incrocia(DNA.generate(1), DNA.generate(2), 99, "Ribes")
	for k in atteso:
		t.ok(c.has(k), "il figlio ha la chiave «%s»" % k)
	t.eq(str(c["name"]), "Ribes", "il nome scelto è quello che gli resta")
	t.eq(str(c["label"]), "%s Ribes" % DNA.DESCR[str(c["archetype"])],
			"la label è DERIVATA: nome + specie, ricalcolata e non copiata")
	t.eq(str(c["tail"]), {"gatto": "ricciolo", "coniglio": "ponpon",
			"orsetto": "ponpon", "volpina": "volpe",
			"topolino": "filo"}[str(c["archetype"])],
			"la coda è derivata dall'archetipo, non ereditata a caso")
	# e i colori derivati devono discendere dal manto VERO del figlio
	var fur := Color(str(c["fur"]))
	t.eq(str(c["fur2"]), fur.darkened(0.22).to_html(false),
			"fur2 è ricalcolato dal manto del figlio")
	t.eq(str(c["belly"]), fur.lightened(0.18).to_html(false),
			"belly è ricalcolato dal manto del figlio")


## Le lentiggini sono recessive, come si deve: due genitori lentigginosi
## le passano sempre, da due senza riaffiorano di rado.
func _test_lentiggini_recessive(t) -> void:
	var due := DNA.generate(11).duplicate()
	var due_b := DNA.generate(12).duplicate()
	due["freckles"] = true
	due_b["freckles"] = true
	var sempre := true
	for s in 30:
		if not bool(DNA.incrocia(due, due_b, s)["freckles"]):
			sempre = false
	t.ok(sempre, "due genitori lentigginosi le passano sempre")
	due["freckles"] = false
	due_b["freckles"] = false
	var quanti := 0
	for s in 200:
		if bool(DNA.incrocia(due, due_b, s)["freckles"]):
			quanti += 1
	t.ok(quanti > 0 and quanti < 60,
			"da due genitori senza, riaffiorano di rado (%d su 200)" % quanti)


## Le orecchie del coniglio valgono 1.6 volte: se il gene passasse
## grezzo, un cucciolo di topo nato da una coniglietta si ritroverebbe
## le orecchie lunghe il doppio del suo corpo.
func _test_orecchie_rinormalizzate(t) -> void:
	var mamma := DNA.generate(21).duplicate()
	var papa := DNA.generate(22).duplicate()
	mamma["archetype"] = "coniglio"
	mamma["ear_len"] = 1.2 * 1.6
	papa["archetype"] = "topolino"
	papa["ear_len"] = 1.0
	for s in 60:
		var c = DNA.incrocia(mamma, papa, s)
		var atteso_max: float = 1.3 * (1.6 if str(c["archetype"]) == "coniglio" else 1.0)
		t.ok(float(c["ear_len"]) <= atteso_max + 0.01,
				"orecchie nel range della PROPRIA specie (%.2f <= %.2f)"
				% [float(c["ear_len"]), atteso_max])


## Il colpo della meccanica: un cucciolo può portare addosso il gene di
## chi è partito, e quel gene dev'essere IDENTICO all'originale — se
## fosse solo «simile», il giocatore non lo riconoscerebbe mai.
func _test_eredita_di_chi_e_partito(t) -> void:
	var timo := DNA.generate(31)
	var partiti := [["Timo", {"dna_ricordo": timo, "n": 12,
			"momenti": [], "partito": true}]]
	var er = NASCITE.eredita_possibile(partiti, 555)
	t.eq(str(er["da"]), "Timo", "il gene torna da chi è partito")
	t.ok(DNA.EREDITABILI.has(str(er["cosa"])),
			"e riguarda un carattere che si riconosce a occhio")
	var c = DNA.incrocia(DNA.generate(41), DNA.generate(42), 77, "Ribes", er)
	for k in DNA.EREDITABILI[str(er["cosa"])]:
		t.eq(str(c[k]), str(timo[k]),
				"«%s» è identico a quello di Timo (non somigliante: identico)" % k)
	t.eq(str(c["eredita"]["da"]), "Timo", "e il figlio si ricorda da chi")
	# la frase che il villaggio dice esiste per ogni carattere
	for cosa in DNA.EREDITABILI:
		t.ok(NASCITE.frase_eredita(str(cosa), "Timo").length() > 5,
				"«%s» ha la sua frase" % cosa)
	# senza partiti, nessuna eredità (e nessun crash)
	t.ok(NASCITE.eredita_possibile([], 1).is_empty(),
			"in un villaggio che non ha ancora salutato nessuno, niente eredità")
	t.ok(NASCITE.eredita_possibile([["X", {"n": 3}]], 1).is_empty(),
			"un partito senza corpo salvato non lascia geni")
	# e non torna SEMPRE: se tornasse sempre, in tre generazioni il
	# villaggio sarebbe un museo di chi non c'è più
	var quante := 0
	for s in 200:
		if NASCITE.eredita_stavolta(s):
			quante += 1
	t.ok(quante > 40 and quante < 160,
			"il gene torna qualche volta, non sempre (%d su 200)" % quante)


## Le regole cozy del calendario, tutte insieme.
func _test_quando_si_nasce(t) -> void:
	t.ok(NASCITE.quando(30, 0, -999, false, false, true, false),
			"in primavera, senza lutti e con un lettino libero: si nasce")
	t.ok(not NASCITE.quando(30, 1, -999, false, false, true, false),
			"d'estate no")
	t.ok(not NASCITE.quando(30, 3, -999, false, false, true, false),
			"d'inverno no")
	t.ok(not NASCITE.quando(30, 0, -999, true, false, true, false),
			"mai durante un congedo: il villaggio fa una cosa per volta")
	t.ok(not NASCITE.quando(30, 0, -999, false, true, true, false),
			"mai nel lutto")
	t.ok(not NASCITE.quando(30, 0, -999, false, false, false, false),
			"e mai senza un lettino libero: è il cancello")
	t.ok(not NASCITE.quando(30, 0, -999, false, false, true, true),
			"e non due volte: se ce n'è già uno in arrivo, si aspetta lui")
	t.ok(not NASCITE.quando(30, 0, 29, false, false, true, false),
			"una sola nascita per primavera (ieri no)")
	t.ok(NASCITE.quando(30, 0, 2, false, false, true, false),
			"ma un anno dopo sì")


## La coppia: un lui e una lei, che si vogliono bene DA TUTTI E DUE i
## lati, senza già una famiglia numerosa.
func _test_la_coppia(t) -> void:
	var lui := DNA.generate(51).duplicate()
	lui["name"] = "Timo"
	var lei := DNA.generate(52).duplicate()
	lei["name"] = "Pepita"
	var lei2 := DNA.generate(53).duplicate()
	lei2["name"] = "Malva"
	var adulti := [["Timo", "L_timo", lui], ["Pepita", "L_pepita", lei],
			["Malva", "L_malva", lei2]]
	var aff := {"L_timo|L_pepita": 20, "L_pepita|L_timo": 20,
			"L_timo|L_malva": 40, "L_malva|L_timo": 1}
	var f_aff := func(a, b): return int(aff.get("%s|%s" % [a, b], 0))
	var f_zero := func(_a, _b): return 0
	var c := NASCITE.coppia_migliore(adulti, f_aff, f_zero)
	t.eq(str(c[0]), "Timo", "il padre è il maschio, sempre per primo")
	t.eq(str(c[1]), "Pepita",
			"vince chi si ricambia (20/20), non chi è ricambiato poco (40/1)")
	# due dello stesso sesso non fanno coppia
	var solo_lei := [["Pepita", "L_pepita", lei], ["Malva", "L_malva", lei2]]
	t.ok(NASCITE.coppia_migliore(solo_lei,
			func(_a, _b): return 99, f_zero).is_empty(),
			"due femmine non formano una coppia da cui nasce un cucciolo")
	# sotto la soglia dell'affetto, niente
	t.ok(NASCITE.coppia_migliore(adulti,
			func(_a, _b): return NASCITE.AFFINITA_MINIMA - 1, f_zero).is_empty(),
			"chi si conosce appena non ha figli")
	# e una famiglia già numerosa non cresce oltre
	t.ok(NASCITE.coppia_migliore(adulti, f_aff,
			func(_a, _b): return NASCITE.MAX_FIGLI).is_empty(),
			"al terzo figlio la famiglia si ferma")


## La crescita e il corpo: la taglia del cucciolo deve essere una
## FRAZIONE di quella da adulto, e la testa restare grande più a lungo.
func _test_il_verso_della_crescita(t) -> void:
	const VISITOR = preload("res://scenes/npc/Visitor.gd")
	t.ok(VISITOR.TAGLIA_CUCCIOLO > 0.2 and VISITOR.TAGLIA_CUCCIOLO < 0.7,
			"appena nato è piccolo, non microscopico (%.2f)" % VISITOR.TAGLIA_CUCCIOLO)
	t.ok(VISITOR.TESTA_CUCCIOLO > 1.0,
			"e la testa gli resta grande in proporzione (%.2f)" % VISITOR.TESTA_CUCCIOLO)


## La parola storta. Sono le due tappe vere di ogni lingua umana:
## prima si raddoppia la sillaba, poi si armonizzano le consonanti.
func _test_la_parola_storta(t) -> void:
	# «grazie» = ta-ki
	t.eq(str(CHIBIESE.storpia(["ta", "ki"], 1.0)), str(["ta", "ta"]),
			"appena nato: «ta-ki» esce «ta-ta» (raddoppio)")
	t.eq(str(CHIBIESE.storpia(["ta", "ki"], 0.45)), str(["ta", "ti"]),
			"poi torna la vocale giusta ma non la consonante: «ta-ti»")
	t.eq(str(CHIBIESE.storpia(["ta", "ki"], 0.05)), str(["ta", "ki"]),
			"e alla fine la dice bene")
	t.eq(str(CHIBIESE.storpia(["mu"], 0.9)), str(["mu", "mu"]),
			"una sillaba sola si raddoppia: è il «pa-pa» di tutti")
	# i digrammi non si spezzano a metà
	t.eq(str(CHIBIESE.storpia(["sha", "ki"], 0.45)), str(["sha", "shi"]),
			"«sh» resta intero: non esistono sillabe con mezza consonante")
	# una vocale nuda non manda in crisi la divisione
	t.eq(str(CHIBIESE.storpia(["o", "ki"], 0.45)), str(["o", "i"]),
			"una sillaba senza consonante non inventa consonanti")
	# la lunghezza non cambia mai (a parte il raddoppio di una sola)
	for q in [0.0, 0.2, 0.4, 0.7, 1.0]:
		t.eq(CHIBIESE.storpia(["ta", "ki"], q).size(), 2,
				"una parola di due sillabe resta di due sillabe (q=%.1f)" % q)


## La voce del cucciolo è l'opposto di quella di chi invecchia — e
## soprattutto porta con sé una CHIAVE diversa, o la cache delle frasi
## gli restituirebbe per sempre la voce che aveva ieri.
func _test_voce_da_cucciolo(t) -> void:
	var v := CHIBIESE.voice(DNA.generate(61))
	var piccolo := CHIBIESE.bimbo(v, 1.0)
	t.ok(float(piccolo["pitch"]) > float(v["pitch"]),
			"un cucciolo ha la voce più acuta")
	t.ok(float(piccolo["rough"]) < float(v["rough"]) + 0.001,
			"e non ha una traccia di raucedine")
	t.ok(int(piccolo["key"]) != int(v["key"]),
			"la chiave della cache cambia: niente frasi riciclate da grande")
	t.almost(float(piccolo.get("bimbo", 0.0)), 1.0,
			"la storpiatura viaggia DENTRO la voce, così say() la trova da sé")
	t.eq(int(CHIBIESE.bimbo(v, 0.0)["key"]), int(v["key"]),
			"a crescita finita la voce torna esattamente quella di prima")
	# invecchiare e crescere si compongono senza litigare
	var anziano_bimbo := CHIBIESE.bimbo(CHIBIESE.invecchia(v, 1.0), 0.0)
	t.ok(float(anziano_bimbo["pitch"]) < float(v["pitch"]),
			"un adulto anziano resta anziano (la crescita a 0 non lo ringiovanisce)")


## Le tabelle che devono restare allineate quando si aggiunge un tipo di
## momento: è la classe di bug che il progetto ha già pagato due volte.
func _test_tabelle_allineate(t) -> void:
	for tipo in ["nascita", "battesimo", "prima_parola"]:
		t.ok(LEGAMI.TIPI.has(tipo), "«%s» è un momento del Filo" % tipo)
		t.ok(MAIL.MOMENTI_TESTO.has(tipo), "«%s» ha la sua lettera" % tipo)
		t.ok(str(MAIL.MOMENTI_TESTO.get(tipo, "")).contains("%d"),
				"«%s» cita il giorno" % tipo)
		t.ok(tipo in LEGAMI.INTOCCABILI,
				"«%s» non si pota mai: capita una volta sola in una vita" % tipo)
	# il desiderio di rivedere chi è nato: se sta fra i luoghi, deve
	# avere anche il suo testo (il test del Filo lo pretende, ma qui si
	# dice PERCHÉ)
	t.ok(CONGEDO.LUOGHI.has("nascita") and CONGEDO.DESIDERI_TESTO.has("nascita"),
			"chi lascia dei figli può chiedere, per ultima cosa, di rivederli")


## I fili nei sorgenti: le regole cozy devono restare cablate dove
## contano, e i cuccioli fuori dai posti degli adulti.
func _test_fili_attaccati(t) -> void:
	t.ok(_body("res://scenes/npc/Lavori.gd", "_scelte_di_giornata")
			.contains("e_cucciolo"),
			"nessuno manda un bambino alla catasta")
	t.ok(_body("res://scenes/npc/Commissioni.gd", "_appendi_nuova")
			.contains("e_cucciolo"),
			"un cucciolo non appende commissioni alla lavagna")
	t.ok(_body("res://scenes/npc/Lavori.gd", "_righe").contains("e_cucciolo")
			or _body("res://scenes/npc/Lavori.gd", "_residenti").contains("e_cucciolo"),
			"e nel registro dei lavori non compare proprio")
	var nascite := _sorgente("res://scenes/world/Nascite.gd")
	t.ok(nascite.contains("accogli_nato"),
			"il cucciolo entra fra i residenti dall'unica porta prevista")
	t.ok(nascite.contains("\"battesimo\"") and nascite.contains("\"nascita\""),
			"e i momenti si annodano: il suo nome, e il mattino dei genitori")
	t.ok(_sorgente("res://scenes/world/CozyWorld.gd").contains("Nascite.gd"),
			"il sistema è appeso al mondo, o non gira mai")
	t.ok(_body("res://scenes/npc/Visitors.gd", "_apply_eta").contains("set_cucciolo"),
			"il corpo piccolo torna addosso anche dopo un riavvio")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
