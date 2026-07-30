extends RefCounted
## I SOGNI — la prova di ciò che il sogno SCEGLIE, e di ciò che salva.
##
## La messa in scena si giudica con gli occhi e non con un test. Ma sotto la
## scena c'è una meccanica precisa, e questa si prova headless: il sogno va
## a prendere IL RICORDO CHE STAVI PER PERDERE, e sognarlo lo salva dalla
## potatura gentile. Su una partita lunga, i momenti che sopravvivono sono
## quelli che hai sognato — e nessuno te lo dice mai.
##
## Il test tiene chiuse quattro porte:
##  1. la SCELTA guarda chi è partito prima di chi c'è ancora, e non
##     ripesca la stessa persona due notti di fila;
##  2. il momento sognato diventa INTOCCABILE, e resta tale attraverso il
##     salvataggio (che è JSON: il giorno torna float, e un `is int`
##     sbaglierebbe in silenzio);
##  3. il sogno SBAGLIA, ma non abbastanza da rendere irriconoscibile chi
##     hai sognato — è la riga che separa un sogno da un archivio, e anche
##     quella che, tirata troppo, spegne l'unico canale che dice CHI era;
##  4. la CADENZA: mai due notti di fila.

const SOGNI := preload("res://scenes/interact/Sogni.gd")
const LEG := preload("res://scenes/world/Legami.gd")


func run(t) -> void:
	_test_la_cadenza(t)
	_test_prende_cio_che_stavi_per_perdere(t)
	_test_la_scelta(t)
	_test_il_sognato_non_si_pota(t)
	_test_il_sogno_sbaglia(t)
	_test_le_grammatiche(t)
	_test_il_verbo_e_le_guardie(t)


## MAI DUE NOTTI DI FILA. Un sogno che arriva ogni volta che ti corichi è
## una schermata di fine giornata con un'altra grafica: è la trappola,
## travestita da frequenza.
func _test_la_cadenza(t) -> void:
	t.ok(not SOGNI.si_sogna(5, 5, 0.0), "la notte stessa non si sogna due volte")
	t.ok(not SOGNI.si_sogna(6, 5, 0.0),
			"e nemmeno la notte dopo: fra un sogno e l'altro passa del tempo")
	t.ok(SOGNI.si_sogna(5 + SOGNI.RIPOSO_NOTTI, 5, 0.0),
			"passato il riposo, si può sognare")
	# e non ogni notte utile: l'attesa fa parte del dono
	t.ok(not SOGNI.si_sogna(99, 5, 0.999),
			"ma non è automatico: c'è un dado, e a volte non si sogna")
	t.ok(SOGNI.PROBABILITA < 1.0,
			"la probabilità è sotto 1: se fosse 1 sarebbe un rendiconto notturno")


## IL CUORE. Il sogno prende esattamente il momento che la potatura gentile
## sacrificherebbe per primo — quello che stavi per perdere.
func _test_prende_cio_che_stavi_per_perdere(t) -> void:
	# un filo abbastanza lungo perché la potatura abbia qualcosa da mangiare
	var momenti: Array = []
	for i in 20:
		momenti.append({"d": 1 + i * 3, "t": "piatto", "x": ""})
	# un momento raro e isolato in mezzo: costa molto, non deve essere scelto
	momenti[10] = {"d": 31, "t": "onsen", "x": ""}
	var vittima: int = LEG.indice_da_potare(momenti)
	t.ok(vittima >= 0, "la potatura ha qualcosa da sacrificare")
	t.eq(SOGNI.indice_da_sognare(momenti), vittima,
			"IL SOGNO PRENDE PROPRIO QUELLO: sognare è ciò che lo salva")
	t.ok(vittima != 10,
			"e non è il momento raro e isolato: quello la potatura non lo toccherebbe")

	# se quel ricordo è già stato sognato, il sogno passa al prossimo che
	# non lo è stato: non si racconta due volte la stessa cosa
	momenti[vittima]["sognato"] = 7
	var secondo: int = SOGNI.indice_da_sognare(momenti)
	t.ok(secondo != vittima, "un momento già sognato non si risogna")
	t.ok(secondo >= 0, "…e ce n'è un altro da prendere")

	# quando è tutto già sognato, non si inventa niente
	for m in momenti:
		(m as Dictionary)["sognato"] = 7
	t.eq(SOGNI.indice_da_sognare(momenti), -1,
			"e se hai già sognato tutto, non si sogna: non si ripete per riempire")
	t.eq(SOGNI.indice_da_sognare([]), -1, "un filo vuoto non dà sogni")


## LA SCELTA fra le persone. Chi è partito pesa di più, perché chi c'è
## ancora lo puoi vedere domani.
func _test_la_scelta(t) -> void:
	var m := [{"d": 1, "t": "piatto", "x": ""}]
	var fili := [
		{"nome": "Vivo", "partito": false, "momenti": m.duplicate(true)},
		{"nome": "Partito", "partito": true, "momenti": m.duplicate(true)},
	]
	# col peso di chi è partito, la maggior parte dei tiri lo pesca
	var partiti := 0
	for i in 40:
		var s: Dictionary = SOGNI.scegli(fili, "", float(i) / 40.0)
		if str(s.get("nome", "")) == "Partito":
			partiti += 1
	t.ok(partiti > 20,
			"chi è partito si sogna più spesso (%d/40): non tornerà da sé" % partiti)
	t.ok(partiti < 40, "…ma non sempre: si sognano anche i vivi")
	t.ok(SOGNI.PESO_PARTITO > 1.0, "e il peso è dichiarato, non nascosto in un tiro")

	# NON DUE NOTTI LA STESSA PERSONA, se c'è altro
	var ripetuti := 0
	for i in 40:
		var s2: Dictionary = SOGNI.scegli(fili, "Partito", float(i) / 40.0)
		if str(s2.get("nome", "")) == "Partito":
			ripetuti += 1
	t.ok(ripetuti < partiti,
			"chi hai sognato ieri torna più raramente (%d < %d)" % [ripetuti, partiti])

	# un filo senza momenti non entra nella scelta: non c'è niente da sognare
	t.ok(SOGNI.scegli([{"nome": "Muto", "partito": true, "momenti": []}], "", 0.5).is_empty(),
			"chi non ha momenti con te non si sogna")
	t.ok(SOGNI.scegli([], "", 0.5).is_empty(), "e senza fili non si sogna")
	# la scelta porta con sé tutto quello che serve alla scena
	var s3: Dictionary = SOGNI.scegli(fili, "", 0.9)
	for k in ["nome", "partito", "indice", "tipo", "giorno", "grammatica"]:
		t.ok(s3.has(k), "la scelta porta '%s'" % k)


## IL MOMENTO SOGNATO NON SI POTA. È l'unica conseguenza del sogno, e non
## si vede: nessun segno, nessun fiore acceso, nessuna riga in grassetto.
## Si scopre cento giorni dopo, accorgendosi che quel ricordo c'è ancora.
func _test_il_sognato_non_si_pota(t) -> void:
	# un momento in mezzo al filo, di un tipo comune: la potatura lo
	# mangerebbe senza pensarci
	var momenti: Array = []
	for i in 20:
		momenti.append({"d": 1 + i * 2, "t": "piatto", "x": ""})
	var i_pot: int = LEG.indice_da_potare(momenti)
	t.ok(not LEG.intoccabile(momenti, i_pot),
			"prima del sogno quel ricordo è sacrificabile")
	momenti[i_pot]["sognato"] = 12
	t.ok(LEG.intoccabile(momenti, i_pot),
			"DOPO IL SOGNO È INTOCCABILE: sognare qualcuno è ciò che lo tiene")
	# e la potatura lo rispetta davvero, non solo a parole
	var potato: Array = LEG.pota(momenti, 10)
	var trovato := false
	for m in potato:
		if (m as Dictionary).has("sognato"):
			trovato = true
	t.ok(trovato, "…e sopravvive a una potatura fino a dieci momenti")

	# IL SALVATAGGIO È JSON: al ritorno da disco il giorno è un float. Un
	# controllo su `is int` direbbe «non l'hai mai sognato» e la potatura
	# se lo mangerebbe — in silenzio, dopo un riavvio.
	var dopo_disco: Array = momenti.duplicate(true)
	(dopo_disco[i_pot] as Dictionary)["sognato"] = 12.0
	t.ok(LEG.intoccabile(dopo_disco, i_pot),
			"e resta intoccabile anche col giorno tornato float dal JSON")
	# la guardia sul sorgente: la protezione sta in `intoccabile`, cioè in
	# UN posto, e non sparsa nei chiamanti
	t.ok(_corpo("res://scenes/world/Legami.gd", "intoccabile").contains("sognato"),
			"la protezione vive dentro `intoccabile`: una sola porta")
	# LA CHIAVE È SORELLA DI `x`, NON DENTRO. `x` è una String (tutti i
	# chiamanti di `momento()` passano stringhe), quindi un contrassegno
	# messo dentro `x` esploderebbe proprio dentro la potatura, al
	# trentunesimo momento annodato. Si prova COL COMPORTAMENTO: un momento
	# con `x` pieno e `sognato` addosso deve essere intoccabile e non
	# deve far esplodere niente.
	#
	# (La prima stesura di questa prova cercava la stringa `"x"` nel
	# sorgente della funzione — e diventava rossa per un COMMENTO. È
	# esattamente il source-check che resta verde anche cancellando il
	# codice, al contrario.)
	var con_extra: Array = momenti.duplicate(true)
	for k in con_extra.size():
		(con_extra[k] as Dictionary)["x"] = "un pezzo di testo qualunque"
	(con_extra[i_pot] as Dictionary)["sognato"] = 12
	t.ok(LEG.intoccabile(con_extra, i_pot),
			"funziona anche con `x` pieno di testo: il contrassegno gli sta accanto")
	t.eq(LEG.pota(con_extra, 8).size() >= 1, true,
			"…e la potatura gira su quel filo senza andare in errore")


## IL SOGNO SBAGLIA — ma con misura. Un ricordo riprodotto senza errori è
## un replay, cioè un montaggio dei momenti migliori. Sbagliato troppo, è
## un'altra persona: e allora non commuove, perché non hai sognato NESSUNO.
func _test_il_sogno_sbaglia(t) -> void:
	var dna := {"name": "Nocciola", "fur": "d9a86c", "size": 1.0,
			"ear_ang": 0.1, "archetype": "orsetto", "sogno": "cuoco"}
	var a: Dictionary = SOGNI.dna_sognato(dna, 3)
	t.eq(str(a["name"]), "Nocciola", "il sogno non cambia chi è")
	t.eq(str(a["sogno"]), "cuoco", "…né cosa sognava")
	t.eq(str(dna["fur"]), "d9a86c", "ed è PURA: il genoma vero non si tocca")
	# lo stesso seme dà lo stesso sogno: la stessa notte, la stessa persona
	t.eq(str(SOGNI.dna_sognato(dna, 3)), str(a), "lo stesso seme, lo stesso sogno")

	# QUALCOSA cambia sempre — o è un archivio
	var cambia := 0
	for i in 30:
		var v: Dictionary = SOGNI.dna_sognato(dna, i)
		if str(v["fur"]) != str(dna["fur"]) \
				or not is_equal_approx(float(v["size"]), float(dna["size"])) \
				or not is_equal_approx(float(v["ear_ang"]), float(dna["ear_ang"])):
			cambia += 1
	t.eq(cambia, 30, "in ogni sogno qualcosa è fuori posto: è quello che lo rende un sogno")

	# MA NON TROPPO. Il colore resta riconoscibilmente il suo: schiarirlo
	# verso il bianco spegneva l'unico canale che dice CHI hai sognato, e
	# un sogno irriconoscibile è solo una dissolvenza colorata.
	var vero := Color(str(dna["fur"]))
	for i in 30:
		var v2: Dictionary = SOGNI.dna_sognato(dna, i)
		var c := Color(str(v2["fur"]))
		var scarto: float = absf(c.r - vero.r) + absf(c.g - vero.g) + absf(c.b - vero.b)
		t.ok(scarto < 0.30,
				"il pelo resta il suo (scarto %.3f): irriconoscibile non commuove" % scarto)
		t.ok(float(v2["size"]) > 0.7 * float(dna["size"]),
				"e non diventa un'altra creatura di taglia")
	# e MAI due cose insieme: due errori non sono un sogno, sono un altro
	# personaggio
	for i in 30:
		var v3: Dictionary = SOGNI.dna_sognato(dna, i)
		var quanti := 0
		if str(v3["fur"]) != str(dna["fur"]):
			quanti += 1
		if not is_equal_approx(float(v3["size"]), float(dna["size"])):
			quanti += 1
		if not is_equal_approx(float(v3["ear_ang"]), float(dna["ear_ang"])):
			quanti += 1
		t.eq(quanti, 1, "una cosa fuori posto per volta, non due")


## LE QUATTRO GRAMMATICHE, e la copertura: ogni tipo di momento che il
## Filo Rosso sa annodare deve avere un modo di essere sognato, o quel
## ricordo cadrebbe su un verbo a caso.
func _test_le_grammatiche(t) -> void:
	var verbi := {}
	for tipo in SOGNI.GRAMMATICA:
		verbi[str(SOGNI.GRAMMATICA[tipo])] = true
	t.ok(verbi.size() >= 3,
			"i verbi del corpo sono più di uno: ci sono %d grammatiche" % verbi.size())
	# ogni tipo del Filo Rosso ha una grammatica — quelli non elencati
	# cadono su «accanto», che è un verbo vero e non un ripiego vuoto
	for tipo in LEG.TIPI:
		var g := str(SOGNI.grammatica_di(str(tipo)))
		t.ok(g != "", "il momento '%s' si sa sognare" % tipo)
		t.ok(g in verbi or g == SOGNI.GRAMMATICA_DEFAULT,
				"…con un verbo che esiste ('%s')" % g)
	t.eq(SOGNI.grammatica_di("un-tipo-inventato"), SOGNI.GRAMMATICA_DEFAULT,
			"e un tipo che non conosco cade su «accanto», non nel vuoto")
	# venti tipi, non venti coreografie
	t.ok(verbi.size() < LEG.TIPI.size() * 0.5,
			"i verbi sono molti meno dei tipi: non si scrivono venti scene")


## IL VERBO E LE GUARDIE. «Vai a dormire» esiste solo nel proprio letto, e
## nessun pannello deve poter comparire sopra la tenda del sonno: un sogno
## la cui prima regola è non avere parole non può avere una scritta
## italiana in mezzo.
func _test_il_verbo_e_le_guardie(t) -> void:
	var inter := _sorgente("res://scenes/interact/Interactions.gd")
	t.ok(inter.contains('L10n.t("E — vai a dormire")'),
			"nel proprio letto il verbo è «vai a dormire», non «dormi»")
	t.ok(_corpo("res://scenes/interact/Interactions.gd", "_e_il_mio_letto").contains("is_home"),
			"…e «il proprio» lo decide Home, non una coordinata a mano")
	t.ok(inter.contains("func is_sleeping"),
			"chi dorme lo può dire agli altri sistemi")
	# il sogno sta nel BUIO, fra la tenda chiusa e il «Buongiorno»
	var corpo := _corpo("res://scenes/interact/Interactions.gd", "_sleep_until_morning")
	var i_tenda := corpo.find('"color:a", 1.0')
	var i_sogno := corpo.find('"sogna"')
	var i_giorno := corpo.find("set_time")
	t.ok(i_tenda >= 0 and i_sogno > i_tenda and i_giorno > i_sogno,
			"e sta nel buio: dopo la tenda, prima del mattino")
	# le due guardie che i critici hanno stanato
	t.ok(_corpo("res://scenes/interact/PhotoMode.gd", "_unhandled_input").contains("is_sleeping"),
			"la modalità foto non si accende nel sonno: spegnerebbe la tenda stessa")
	t.ok(_corpo("res://scenes/world/Nascite.gd", "_aggiorna_prompt").contains("is_sleeping"),
			"e il cartellino del cucciolo (livello 12, sopra la tenda) tace")
	# NIENTE SEGNO AL RISVEGLIO: nessun regalo, nessun toast, nessun fiore
	var sog := _sorgente("res://scenes/interact/Sogni.gd")
	t.ok(not sog.contains("queue_letter"), "il sogno non manda lettere")
	t.ok(not sog.contains("show_toast") and not sog.contains("_show_toast"),
			"e non annuncia niente: la conseguenza è invisibile")
	t.ok(not sog.contains("accendi_fiore"),
			"…e non accende il fiore sul Prato Eterno: sarebbe un marcatore su una tomba")
	t.ok(sog.contains("segna_sognato"),
			"l'unica cosa che fa, al risveglio, è salvare quel ricordo")


func _corpo(path: String, nome: String) -> String:
	var src := _sorgente(path)
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
