extends RefCounted
## I FESTONI: la grammatica dei pali che si passano il filo.
##
## Qui si prova la REGOLA, su un dizionario finto e senza albero della
## scena: chi si vede con chi, chi tiene il filo, e che il filo faccia
## quello che il commento del sorgente promette. La resa e il cablaggio
## col BuildSystem vero li prova `tools/prova_festoni.gd`, che pianta i
## pali nel MainLevel e li fotografa.
##
## Le affermazioni scritte nei commenti sono test, non prosa: la regola
## dei quattro metri e l'altezza della pancia sono MISURATE qui sotto.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const SYS = preload("res://scenes/build/BuildSystem.gd")


func _palo(nome := "Palo lucine") -> Node3D:
	var n := Node3D.new()
	n.set_meta("item_name", nome)
	return n


func _mondo(celle: Dictionary) -> Dictionary:
	var d := {}
	for c: Vector2i in celle:
		d[c] = _palo(str(celle[c]))
	return d


func _libera(d: Dictionary) -> void:
	for c in d:
		(d[c] as Node3D).free()


## Quante campate nascono in tutto da un mondo: la somma di quelle che
## ogni palo si prende in carico.
func _campate(d: Dictionary) -> int:
	var q := 0
	for c: Vector2i in d:
		for v: Vector2i in SYS.vicini_festone(d, c):
			if SYS._prima_di(c, v):
				q += 1
	return q


func run(t) -> void:
	_solo_il_primo(t)
	_quattro_metri(t)
	_una_campata_sola(t)
	_pali_toccati(t)
	_ricostruzione(t)
	_veste_del_padrone(t)
	_piu_lungo_piu_luci(t)
	_ci_si_passa_sotto(t)
	_non_e_un_palo(t)


## Il PRIMO palo in ogni direzione, non tutti: senza questa regola una
## fila di sei pali diventa un ventaglio invece di una collana.
func _solo_il_primo(t) -> void:
	var d := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(1, 0): "Palo lucine",
			Vector2i(2, 0): "Palo lucine", Vector2i(3, 0): "Palo lucine"})
	var v = SYS.vicini_festone(d, Vector2i(0, 0))
	t.eq(v.size(), 1, "il palo di testa vede solo il primo dopo di sé")
	t.ok(Vector2i(1, 0) in v, "e quello che vede è il vicino, non il lontano")
	var vm = SYS.vicini_festone(d, Vector2i(1, 0))
	t.eq(vm.size(), 2, "un palo in mezzo alla fila ne vede due, uno per verso")
	t.eq(_campate(d), 3, "quattro pali in fila fanno TRE fili, non sei")
	_libera(d)


## LA REGOLA DEI QUATTRO METRI, che è tutto il controllo che ha il
## giocatore: si misura in metri veri, non in celle. Se si contassero le
## celle, la diagonale di un quadrato di lato tre sarebbe «tre passi»
## come i lati, e il quadrato uscirebbe sempre con la X dentro.
func _quattro_metri(t) -> void:
	var dritto := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(4, 0): "Palo lucine"})
	t.eq(_campate(dritto), 1, "quattro celle in linea: 4.0 m, il filo ci arriva")
	_libera(dritto)

	var diag2 := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(2, 2): "Palo lucine"})
	t.eq(_campate(diag2), 1, "due celle in diagonale: 2.83 m, si annoda")
	_libera(diag2)

	var diag3 := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(3, 3): "Palo lucine"})
	t.eq(_campate(diag3), 0, "tre celle in diagonale: 4.24 m, il filo NON ci arriva")
	_libera(diag3)

	# ed è questo che fa restare un quadrato un quadrato
	var quadrato := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(3, 0): "Palo lucine",
			Vector2i(3, 3): "Palo lucine", Vector2i(0, 3): "Palo lucine"})
	t.eq(_campate(quadrato), 4, "quattro pali a lato tre: un quadrato, senza la X")
	_libera(quadrato)

	# e a due celle di lato, invece, l'intreccio c'è
	var fitto := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(2, 0): "Palo lucine",
			Vector2i(2, 2): "Palo lucine", Vector2i(0, 2): "Palo lucine"})
	t.eq(_campate(fitto), 6, "a lato due le diagonali (2.83 m) si annodano: 4 + 2")
	_libera(fitto)


## Il filo lo disegna UNO solo dei due pali, se no sono due mezzi fili
## che si compenetrano (stessa regola del montante fra due serre).
func _una_campata_sola(t) -> void:
	var a := Vector2i(2, 5)
	var b := Vector2i(4, 5)
	t.ok(SYS._prima_di(a, b), "chi ha la x minore tiene il filo")
	t.ok(not SYS._prima_di(b, a), "e l'altro no: mai tutti e due")
	t.ok(SYS._prima_di(Vector2i(3, 1), Vector2i(3, 2)),
			"a parità di x decide la y")
	t.ok(not SYS._prima_di(a, a), "un palo non tiene un filo con se stesso")


## Chi va rifatto quando si tocca una cella. Deve comprendere anche il
## palo FUORI portata: quello che gli è comparso davanti può avergli
## tolto la vista di un altro.
func _pali_toccati(t) -> void:
	var d := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(3, 3): "Palo lucine"})
	var toccati = SYS.pali_toccati(d, Vector2i(1, 1))
	t.ok(Vector2i(0, 0) in toccati, "il palo dietro va rifatto")
	t.ok(Vector2i(3, 3) in toccati,
			"e anche quello a 4.24 m, che il filo non raggiunge: la vista sì")
	var lontano = SYS.pali_toccati(d, Vector2i(9, 9))
	t.eq(lontano.size(), 0, "in mezzo al niente non si rifà nessuno")
	_libera(d)


## La ricostruzione: quante corde vive nascono, e che rifarla due volte
## non le raddoppi (la trappola del nodo in coda che tiene il nome).
func _ricostruzione(t) -> void:
	var d := _mondo({Vector2i(0, 0): "Palo lucine", Vector2i(2, 0): "Palo lucine",
			Vector2i(4, 0): "Palo lucine"})
	SYS.ricostruisci_festoni(d, Vector2i(0, 0))
	var capo = d[Vector2i(0, 0)] as Node3D
	var casa = capo.get_node_or_null("Festoni")
	t.ok(casa != null, "il palo si ritrova la casa dei suoi festoni")
	t.eq(casa.get_child_count(), 1, "e dentro UNA campata: quella verso destra")

	SYS.ricostruisci_festoni(d, Vector2i(0, 0))
	var case := 0
	for f in capo.get_children():
		if str(f.name).begins_with("Festoni"):
			case += 1
	t.eq(case, 1, "rifatta due volte resta UNA casa, non due")
	t.eq((capo.get_node("Festoni") as Node3D).get_child_count(), 1,
			"e una campata sola: il nome non è scivolato a «Festoni2»")

	# il palo di mezzo ne tiene una sola (l'altra è del palo di sinistra)
	SYS.ricostruisci_festoni(d, Vector2i(2, 0))
	var mezzo = d[Vector2i(2, 0)] as Node3D
	t.eq((mezzo.get_node("Festoni") as Node3D).get_child_count(), 1,
			"il palo di mezzo tiene solo il filo verso destra")
	_libera(d)


## La veste del filo è quella del palo che lo tiene: è la leva con cui
## il giocatore alterna i festoni invece di posarli e basta.
func _veste_del_padrone(t) -> void:
	var d := _mondo({Vector2i(0, 0): "Palo bandierine", Vector2i(2, 0): "Palo lucine"})
	t.eq(SYS.veste_palo(d, Vector2i(0, 0)), CAT.FESTONE_BANDIERINE,
			"il palo dice la sua veste")
	t.eq(SYS.veste_palo(d, Vector2i(2, 0)), CAT.FESTONE_BULBI, "e l'altro la sua")
	t.eq(SYS.veste_palo(d, Vector2i(9, 9)), -1, "dove non c'è palo, -1")
	_libera(d)


## «Allungo la corda e ci stanno più luci»: è la promessa del sistema, e
## qui si misura invece di crederci.
func _piu_lungo_piu_luci(t) -> void:
	var corto = CAT.festone(Vector3(0, 1.92, 0), Vector3(1, 1.92, 0), CAT.FESTONE_BULBI, 7)
	var lungo = CAT.festone(Vector3(0, 1.92, 0), Vector3(4, 1.92, 0), CAT.FESTONE_BULBI, 7)
	# `var x = ...` e non `:=`: il valore viene da un meta non tipizzato,
	# e l'inferenza fallisce in fase di parse (convenzione dei test)
	var na = (corto.get_node("CordaViva") as Node3D).get_meta("corda")["appesi"].size()
	var nb = (lungo.get_node("CordaViva") as Node3D).get_meta("corda")["appesi"].size()
	t.ok(nb > na, "quattro metri di filo portano più luci di uno")
	t.ok(nb >= 2 * na, "e non una in più: quattro volte il filo, molte più luci")
	corto.free()
	lungo.free()


## «Il filo lungo resta abbastanza alto da passarci sotto»: la pancia
## cresce con la campata, e senza questa misura la prima ritaratura
## dell'abbondanza rimetterebbe il filo in faccia a Mochi.
func _ci_si_passa_sotto(t) -> void:
	for campata: float in [1.0, 2.0, 3.0, 4.0]:
		var f = CAT.festone(Vector3(0, CAT.FESTONE_CIMA, 0),
				Vector3(campata, CAT.FESTONE_CIMA, 0), CAT.FESTONE_BULBI, 3)
		var posa: Array = (f.get_node("CordaViva") as Node3D).get_meta("posa")
		var fondo := 99.0
		for p: Vector3 in posa:
			fondo = minf(fondo, p.y)
		# le lampadine pendono sotto il filo: si conta anche quello
		t.ok(fondo - 0.20 > 1.0,
				"a %.0f m il filo resta sopra la testa (misurato %.2f)"
						% [campata, fondo])
		t.ok(fondo < CAT.FESTONE_CIMA - 0.10,
				"ma una pancia ce l'ha: a %.0f m scende di %.2f"
						% [campata, CAT.FESTONE_CIMA - fondo])
		f.free()


## La guardia: i rinfresca ricevono il dizionario del LAYER, non del
## nome. Una sedia in mezzo ai pali non deve tendere nessun filo.
func _non_e_un_palo(t) -> void:
	var d := _mondo({Vector2i(0, 0): "Sedia", Vector2i(2, 0): "Sedia"})
	t.eq(_campate(d), 0, "due sedie non fanno un festone")
	t.eq(SYS.vicini_festone(d, Vector2i(0, 0)).size(), 0,
			"e una sedia non ha vicini di festone")
	SYS.ricostruisci_festoni(d, Vector2i(0, 0))
	t.ok((d[Vector2i(0, 0)] as Node3D).get_node_or_null("Festoni") == null,
			"e non le si appende nemmeno la casa vuota")
	_libera(d)
