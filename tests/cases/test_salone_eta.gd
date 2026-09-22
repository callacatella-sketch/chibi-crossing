extends RefCounted
## IL SALONE NON CANCELLA LA VECCHIAIA.
##
## `rifai_il_look()` rifà il corpo da zero — `_monta_corpo()` costruisce un
## chibi GIOVANE — e i segni dell'autunno (baffetti e sopracciglia d'argento,
## la barbetta, il bastoncino di ciliegio) sono figli di `_vis`: se ne vanno
## col `queue_free()` di tutti i figli.
##
## ⚠️ **E per un pezzo non tornavano più.** `_vesti_autunno()` ha il ramo
## `if f >= 0.5 and not _eta_dressed`, e `_eta_dressed` restava acceso: il
## bastoncino non tornava MAI, per nessuno. Le rughe e l'argento tornavano al
## primo cambio di età — ma `set_eta` esce subito se il valore non è cambiato
## di 0,005, e per un anziano con `eta_f` satura a 1.0 quel valore non cambia
## più: non tornavano nemmeno quelli.
##
## È un danno PERMANENTE che causa il giocatore mandando qualcuno
## dall'estetista, e senza una chiave a forma di giocatore per ripararlo:
## la prima domanda della REGOLA SACRA.
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func run(t) -> void:
	_test_il_salone_non_ringiovanisce(t)


func _anziano(t, seme: int) -> Node3D:
	var v: Node3D = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)
	v.call("set_eta", 1.0)     # pieno autunno: bastoncino e argento
	return v


## ⚠️ **L'ORACOLO GUARDA L'ALBERO, non `is_queued_for_deletion()`.**
## `rifai_il_look` fa `_vis.remove_child(c)` + `c.queue_free()` sui figli
## diretti: i DISCENDENTI (i ciuffi appesi a `_head`) non vengono marcati uno
## per uno, e dentro un caso di test il fotogramma non avanza mai — quindi
## col contrassegno di cancellazione cinque segni su sei risultavano ancora
## vivi e la mutazione non mordeva. Un segno c'è se è ancora **dentro il
## corpo di adesso**: si risale la catena dei genitori fino a `_vis`.
func _segni_vivi(v: Node3D) -> int:
	var vis := v.get("_vis") as Node3D
	if vis == null:
		return -1
	var n := 0
	for nodo in (v.get("_autunno") as Array):
		if nodo == null or not is_instance_valid(nodo):
			continue
		var p: Node = nodo as Node
		while p != null and p != vis:
			p = p.get_parent()
		if p == vis:
			n += 1
	return n


func _test_il_salone_non_ringiovanisce(t) -> void:
	var v := _anziano(t, 4242)
	var prima := _segni_vivi(v)
	t.ok(prima > 0, "un anziano porta addosso i segni dell'autunno (%d)" % prima)
	t.ok(bool(v.get("_eta_dressed")), "…e il corpo lo sa")

	# la seduta dall'estetista: SOLO un gene estetico, l'identità non si tocca
	var cambiato: bool = v.call("rifai_il_look", {"fur": "e8b4a0"})
	t.ok(cambiato, "il Salone ha cambiato qualcosa")

	var dopo := _segni_vivi(v)
	t.ok(dopo > 0,
			"dopo il Salone i segni dell'autunno ci sono ancora (%d)" % dopo)
	t.eq(dopo, prima, "e sono gli stessi di prima, non di meno")
	t.ok(bool(v.get("_eta_dressed")),
			"il corpo sa ancora di essere vestito d'autunno")
	t.almost(float(v.get("_eta")), 1.0,
			"e l'età non è tornata indietro", 1e-6)

	# ⚠️ LA CONTROPROVA: un GIOVANE non deve ritrovarsi vecchio. Senza,
	# «rimetti i segni» potrebbe essere una riga che li mette a chiunque.
	var giovane := _anziano(t, 777)
	giovane.call("set_eta", 0.0)
	t.eq(_segni_vivi(giovane), 0, "un giovane non ha segni d'autunno")
	giovane.call("rifai_il_look", {"fur": "b8d4e8"})
	t.eq(_segni_vivi(giovane), 0, "…e il Salone non gliene mette")
