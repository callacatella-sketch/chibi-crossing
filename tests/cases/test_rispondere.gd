extends RefCounted
## RISPONDERE — la cassetta che si può anche riempire.
##
## Chiude il buco più grave del progetto: la posta era il canale più
## intimo del gioco ed era A SENSO UNICO (loro scrivevano, tu no), e il
## Filo Rosso — il sistema più profondo — non aveva UNA schermata dove
## guardarlo. Un ledger che nessuno legge è un ledger che non esiste.
## Rispondere è la stessa porta per entrambe le cose: per scegliere cosa
## dire devi sfogliare la vostra storia.
##
## Qui si prova la LOGICA PURA (chi si può scrivere, la pagina del filo,
## le parole, il testo) e i fili del cablaggio.

const R := preload("res://scenes/interact/Rispondere.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")
const MAIL := preload("res://scenes/interact/Mail.gd")
const CHB := preload("res://audio/Chibiese.gd")

const FILI := {
	"Nocciola": {"giorno_arrivo": 3, "momenti": [
		{"t": "benvenuto", "d": 3}, {"t": "piatto", "d": 9},
		{"t": "nascondino", "d": 14}]},
	"Mirtillo": {"giorno_arrivo": 1, "partito": true, "momenti": [
		{"t": "benvenuto", "d": 1}, {"t": "oro", "d": 96},
		{"t": "partenza", "d": 99}]},
	"Appena arrivato": {"giorno_arrivo": 40, "momenti": []},
}


func run(t) -> void:
	_test_a_chi(t)
	_test_pagina_del_filo(t)
	_test_le_parole(t)
	_test_la_lettera(t)
	_test_grammatica(t)
	_test_cablaggio(t)


## A CHI si può scrivere: serve almeno un momento (non si scrive a uno
## sconosciuto, e la pagina del filo sarebbe vuota), e chi è partito sta
## in fondo — non lo si incontra per caso scorrendo la lista dei vivi.
func _test_a_chi(t) -> void:
	var d := R.destinatari(FILI)
	t.eq(d.size(), 2, "chi non ha ancora un momento non compare")
	t.eq(str(d[0]["nome"]), "Nocciola", "prima i vicini che ci sono")
	t.eq(str(d[1]["nome"]), "Mirtillo", "e in fondo chi è al Grande Prato")
	t.ok(bool(d[1]["partito"]), "…marcato come partito, per dirlo alla schermata")
	t.eq(int(d[0]["momenti"]), 3, "il conto dei momenti è quello vero")
	t.ok(R.destinatari({}).is_empty(), "villaggio senza storie: nessun destinatario")


## LA PAGINA DEL FILO: la schermata che non c'era. I momenti in ordine,
## col giorno e col loro racconto.
func _test_pagina_del_filo(t) -> void:
	var p := R.pagina_del_filo(FILI["Nocciola"]["momenti"])
	t.eq(p.size(), 3, "la pagina mostra tutti i momenti del filo")
	t.eq(int(p[0]["d"]), 3, "…col giorno in cui è successo")
	t.eq(str(p[0]["racconto"]), "il primo benvenuto sulla soglia",
			"…e col racconto che il filo gli dà")
	# OGNI tipo del filo dev'essere raccontabile: un tipo nuovo senza
	# racconto lascerebbe una riga muta nella pagina più intima del gioco
	for tipo in LEGAMI.TIPI:
		var una := R.pagina_del_filo([{"t": tipo, "d": 1}])
		t.ok(str(una[0]["racconto"]) != "" and str(una[0]["racconto"]) != "un momento insieme",
				"il tipo '%s' ha il suo racconto nella pagina" % tipo)
	# un tipo sconosciuto non rompe niente: degrada
	var ignoto := R.pagina_del_filo([{"t": "boh", "d": 1}])
	t.eq(ignoto.size(), 1, "un tipo sconosciuto non fa sparire la riga")


## LE DUE PAROLE: le suggerisce il momento, e sono sempre scrivibili.
func _test_le_parole(t) -> void:
	for tipo in LEGAMI.TIPI:
		var m: Dictionary = (R.pagina_del_filo([{"t": tipo, "d": 1}]) as Array)[0]
		var par := R.parole_suggerite(m)
		t.eq(par.size(), R.QUANTE_PAROLE,
				"'%s': suggerisce esattamente due parole" % tipo)
		for p in par:
			t.ok(str(p) in R.PAROLE,
					"'%s': la parola '%s' è scrivibile in una lettera" % [tipo, p])
			t.ok(CHB.VOCAB.has(str(p)),
					"'%s': la parola '%s' esiste nel Chibiese" % [tipo, p])
		t.ok(par[0] != par[1], "'%s': due parole DIVERSE, non una ripetuta" % tipo)
	# la tavolozza intera dice cose che si possono dire a qualcuno
	for p in R.PAROLE:
		t.ok(CHB.VOCAB.has(str(p)),
				"la parola '%s' della tavolozza esiste nel Chibiese" % p)


## LA LETTERA: deterministica, cita il momento, e porta le sillabe vere.
func _test_la_lettera(t) -> void:
	var m: Dictionary = (R.pagina_del_filo([{"t": "nascondino", "d": 14}]) as Array)[0]
	var a := R.testo_lettera(m, ["amico", "grazie"])
	var b := R.testo_lettera(m, ["amico", "grazie"])
	t.eq(a, b, "la stessa lettera, dagli stessi ingredienti, per sempre")
	t.ok(a.contains("nascondino"), "la lettera cita il momento scelto")
	t.ok(a.contains("mi-ka") and a.contains("ta-ki"),
			"…e porta le SILLABE vere del Chibiese, non i nomi italiani")
	t.ok(a.contains("amico") and a.contains("grazie"),
			"…con la traduzione sotto, per chi ancora non le sa")
	t.ok(a.contains("Mochi"), "ed è firmata")


## LA GRAMMATICA. I racconti cominciano col loro articolo e in italiano
## «di la partita» non esiste: la lettera più intima del gioco non può
## sembrare scritta da una macchina.
func _test_grammatica(t) -> void:
	t.eq(R.con_di("la partita a nascondino"), "della partita a nascondino",
			"di + la = della")
	t.eq(R.con_di("il primo benvenuto"), "del primo benvenuto", "di + il = del")
	t.eq(R.con_di("quel piatto fumante"), "di quel piatto fumante",
			"i dimostrativi restano staccati")
	t.eq(R.con_di("quell'ultimo desiderio"), "di quell'ultimo desiderio",
			"…anche quelli elisi")
	t.eq(R.con_di("un dono scelto"), "di un dono scelto", "di + un resta staccato")
	# su OGNI racconto vero del filo non deve restare un «di il/di la»
	for tipo in LEGAMI.TIPI:
		var frase: String = R.con_di(str((LEGAMI.TIPI[tipo] as Array)[0]))
		for storpio in ["di il ", "di la ", "di i ", "di le ", "di lo ", "di gli ", "di l'"]:
			t.ok(not frase.begins_with(storpio),
					"'%s' -> «Mi ricordo %s»: nessuna preposizione storpia" % [tipo, frase])
	# una lingua senza quegli articoli (l'inglese tradotto) passa intatta
	t.eq(R.con_di("the game of hide-and-seek"), "di the game of hide-and-seek",
			"su una frase che non ha articoli italiani non fonde nulla")


func _test_cablaggio(t) -> void:
	# il nuovo momento del filo, e la garanzia che non si poti: è l'unico
	# che il GIOCATORE ha scelto a mano
	t.ok(LEGAMI.TIPI.has("risposta"), "«risposta» è un momento vero del filo")
	t.ok("risposta" in LEGAMI.INTOCCABILI,
			"…e non si pota MAI: è l'unica cosa che ha scritto lui")
	t.ok(MAIL.MOMENTI_TESTO.has("risposta"),
			"…e quando riaffiora ha la sua lettera")

	# LA CASSETTA NON È PIÙ SOLO UNA BOCCA CHE DÀ
	var mail := _sorgente("res://scenes/interact/Mail.gd")
	t.ok(mail.contains("if want_open and not _reading:"),
			"ci si può stare davanti anche SENZA posta da leggere")
	t.ok(mail.contains("E — rispondi"), "e il prompt lo dice")
	t.ok(mail.contains("get_first_node_in_group(\"rispondere\")"),
			"la E senza posta apre la risposta")

	# le due destinazioni, che sono due cose diverse
	var r := _sorgente("res://scenes/interact/Rispondere.gd")
	t.ok(r.contains("func _al_vicino") and r.contains("queue_letter"),
			"al vicino che c'è: la lettera arriva e lui RISPONDE")
	t.ok(r.contains("grazie_per_la_lettera"),
			"…e viene a ringraziarti col corpo")
	t.ok(r.contains("func _al_grande_prato") and r.contains("accendi_fiore"),
			"a chi è partito: nessuno risponde, ma il suo fiore si accende")
	t.ok(not _corpo(r, "_al_grande_prato").contains("queue_letter"),
			"…e NESSUNA lettera finta torna dal Grande Prato: sarebbe una bugia")
	t.ok(_sorgente("res://scenes/npc/Visitors.gd").contains("func grazie_per_la_lettera"),
			"il vicino sa cosa fare quando trova la tua lettera")
	var cong := _sorgente("res://scenes/world/Congedo.gd")
	t.ok(cong.contains("func accendi_fiore") and cong.contains("luce_calda"),
			"la lucina del fiore è una luce calda vera (la trovano gli occhi)")
	t.ok(cong.contains("_spegni_luci_lettera"),
			"…e all'alba si spegne: la notte in cui hai scritto è passata")

	# una al giorno per ciascuno: non è una macchina per l'amicizia
	t.ok(r.contains("func puo_scrivere"), "una lettera al giorno per ciascuno")
	t.ok(r.contains("func save_extra") and r.contains("lettere_spedite"),
			"…e il conto si salva col villaggio")
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("Rispondere.gd"),
			"il sistema vive nella scena principale")


func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
