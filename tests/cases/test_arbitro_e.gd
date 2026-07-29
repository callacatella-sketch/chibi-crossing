extends RefCounted
## L'ARBITRO DELLA E — chi vince quando il tasto è uno e le cose sono tante.
##
## Trentanove ascoltatori si contendevano "interact", trentadue
## consumavano l'evento, e a decidere era l'ORDINE DELL'ALBERO: cioè
## quale riga di `_ready` aveva istanziato quel sistema. Il giocatore lo
## vedeva così: con un semino in tasca ogni E piantava un albero (sopra
## la panchina, sopra la posta); premevi E per pescare e calava
## un'asciata; il guardaroba non vinceva mai, nemmeno una volta.
##
## Qui si prova la REGOLA, non l'implementazione:
##   «Vince chi ti tira FUORI da dove sei; poi ciò che sta per SCAPPARE;
##    poi chi ha un VOLTO; poi il GESTO; poi i MOBILI. A parità, il più
##    vicino.»
## e la proprietà che rende la migrazione sicura: se nessun iscritto è in
## gioco l'arbitro TACE, e i non ancora migrati funzionano come sempre.

const ARB := preload("res://systems/ArbitroE.gd")


class FintoSito:
	extends Node
	var d := -1.0
	var fatto := 0
	func distanza_e() -> float:
		return d
	func agisci_e() -> void:
		fatto += 1


func run(t) -> void:
	_test_la_regola(t)
	_test_tace_se_nessuno(t)
	_test_igiene(t)
	_test_prima_ondata(t)


func _iscrivi(t, a, nome: String, gradino: int) -> FintoSito:
	var s := FintoSito.new()
	s.name = nome
	t.stage(s)
	a.iscrivi(s, nome, gradino, Callable(s, "distanza_e"), Callable(s, "agisci_e"))
	return s


func _test_la_regola(t) -> void:
	var a = t.stage(ARB.new())
	var uscita := _iscrivi(t, a, "alzati", ARB.USCITA)
	var fugace := _iscrivi(t, a, "retino", ARB.FUGACE)
	var volto := _iscrivi(t, a, "regalo", ARB.VOLTO)
	var gesto := _iscrivi(t, a, "ascia", ARB.GESTO)
	var arredo := _iscrivi(t, a, "siediti", ARB.ARREDO)

	# IL GRADINO viene prima della distanza: anche se l'uscita è
	# lontanissima e il mobile ti sta addosso, vince l'uscita — restare
	# intrappolati è il male peggiore
	uscita.d = 9.0
	fugace.d = 0.1
	volto.d = 0.1
	gesto.d = 0.1
	arredo.d = 0.1
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "alzati",
			"l'USCITA vince su tutto, anche da lontano")

	uscita.d = -1.0
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "retino",
			"…poi ciò che sta per scappare (una farfalla non ripassa)")
	fugace.d = -1.0
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "regalo",
			"…poi chi ha un volto")
	volto.d = -1.0
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "ascia",
			"…poi il gesto sul mondo")
	gesto.d = -1.0
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "siediti",
			"…e per ultimi i mobili, che domani sono ancora lì")

	# A PARITÀ DI GRADINO decide la distanza, e nient'altro: l'ordine di
	# iscrizione (che è l'ordine dell'albero) non deve contare
	var g2 := _iscrivi(t, a, "semina", ARB.GESTO)
	gesto.d = 2.5
	g2.d = 0.4
	arredo.d = -1.0
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "semina",
			"a parità di gradino vince il PIÙ VICINO")
	gesto.d = 0.2
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "ascia",
			"…e cambia se cambia la distanza, non l'ordine di iscrizione")

	# e il verdetto si sa raccontare (serve al registro e alle prove)
	var v: Dictionary = a.ultimo_verdetto()
	t.eq(str(v.get("nome", "")), "ascia", "l'arbitro dice chi ha vinto")
	t.ok(int(v.get("contesi", 0)) >= 2, "…e quanti se la contendevano")


## LA PROPRIETÀ CHE RENDE SICURA LA MIGRAZIONE A ONDATE: se nessuno degli
## iscritti è in gioco, l'arbitro non tocca l'evento — e i trentacinque
## siti non ancora migrati si comportano ESATTAMENTE come prima.
func _test_tace_se_nessuno(t) -> void:
	var a = t.stage(ARB.new())
	t.ok((a.scegli() as Dictionary).is_empty(),
			"senza iscritti l'arbitro tace: la E prosegue com'è sempre stata")
	var s := _iscrivi(t, a, "qualcosa", ARB.GESTO)
	t.ok((a.scegli() as Dictionary).is_empty(),
			"iscritto ma non in gioco (distanza < 0): tace lo stesso")
	s.d = 1.0
	t.ok(not (a.scegli() as Dictionary).is_empty(), "in gioco: assegna")
	# e l'azione la fa DAVVERO chi ha vinto
	var vinto: Dictionary = a.scegli()
	(vinto["agisci"] as Callable).call()
	t.eq(s.fatto, 1, "il vincitore agisce una volta sola")


func _test_igiene(t) -> void:
	var a = t.stage(ARB.new())
	var s := _iscrivi(t, a, "doppio", ARB.GESTO)
	a.iscrivi(s, "doppio", ARB.GESTO, Callable(s, "distanza_e"), Callable(s, "agisci_e"))
	t.eq(a.quanti_iscritti(), 1,
			"iscriversi due volte non raddoppia (i nodi rinascono a ogni alba)")
	# un iscritto con la risposta rotta (Callable non valida: il metodo
	# non c'è più, il nodo è a metà smontaggio) non blocca la contesa —
	# viene semplicemente saltato
	var rotto := _iscrivi(t, a, "rotto", ARB.USCITA)
	a.dimentica(rotto)
	a.iscrivi(rotto, "rotto", ARB.USCITA, Callable(), Callable())
	s.d = 5.0
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "doppio",
			"un iscritto che non sa rispondere viene saltato, non vince per inerzia")

	# e chi se ne va lo dice: `dimentica` toglie tutti i suoi rami
	a.dimentica(rotto)
	a.dimentica(s)
	t.eq(a.quanti_iscritti(), 0, "chi si smonta si toglie dalla contesa")
	t.ok((a.scegli() as Dictionary).is_empty(),
			"…e l'arbitro torna a tacere")


## LA PRIMA ONDATA: i quattro che nella mappa rubavano di più.
func _test_prima_ondata(t) -> void:
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("ArbitroE.gd"),
			"l'arbitro vive nella scena principale")
	for terna: Array in [
			["res://scenes/interact/Frutteto.gd", "GESTO", "il frutteto"],
			["res://scenes/interact/Woodcutting.gd", "GESTO", "l'ascia"],
			["res://scenes/interact/Collection.gd", "FUGACE", "il retino"],
			["res://scenes/interact/Scavi.gd", "FUGACE", "la vanga"]]:
		var src := _sorgente(str(terna[0]))
		t.ok(src.contains("arb.iscrivi(self"),
				"%s si iscrive all'arbitro" % str(terna[2]))
		t.ok(src.contains("arb.%s" % str(terna[1])),
				"%s dichiara il gradino %s" % [str(terna[2]), str(terna[1])])
		t.ok(src.contains("func distanza_e") and src.contains("func agisci_e"),
				"%s risponde alle due domande dell'arbitro" % str(terna[2]))
		# LA MIGRAZIONE È ADDITIVA: il vecchio ascoltatore resta come rete.
		# Toglierlo sarebbe stato il modo di rompere tutto in un colpo solo.
		t.ok(src.contains("func _unhandled_input"),
				"%s tiene la sua vecchia via come rete" % str(terna[2]))

	# le due FUGACI battono i due GESTI: è la contesa che il giocatore
	# incontrava di più (semino in tasca + farfalla che passa)
	var a = t.stage(ARB.new())
	var semina := _iscrivi(t, a, "frutteto", ARB.GESTO)
	var retino := _iscrivi(t, a, "retino", ARB.FUGACE)
	semina.d = 3.0
	retino.d = 1.4
	t.eq(str((a.scegli() as Dictionary).get("nome", "")), "retino",
			"semino in tasca + farfalla di passaggio: vince la farfalla")

	# LE DUE CORREZIONI CHE IL PIANO HA TROVATO NELL'ARBITRO STESSO
	var src := _sorgente("res://systems/ArbitroE.gd")
	t.ok(src.contains("PROCESS_MODE_PAUSABLE"),
			"a gioco in pausa l'arbitro TACE: la pausa la governa il menu di pausa")
	t.ok(src.contains("is_physics_processing()"),
			"e tace anche se un pannello non migrato ha congelato Mochi — "
			+ "senza, gli si ruberebbe la E e il giocatore resterebbe chiuso dentro")
	t.ok(src.contains("esito is bool and not esito"),
			"un vincitore che non ce l'ha fatta lascia proseguire l'evento")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
