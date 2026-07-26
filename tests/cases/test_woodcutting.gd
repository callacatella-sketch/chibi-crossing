## Test per il taglio della legna (scenes/interact/Woodcutting.gd): il
## costo dei pezzi, la borsa della legna, e il round-trip di salvataggio.
## Il preload in testa fa anche da parse-gate: se Woodcutting non compila,
## questo caso non si istanzia e il runner lo segnala.
##
## Woodcutting è un Node: lo si crea con .new() SENZA aggiungerlo all'albero
## (così _ready non parte e non pianta il boschetto) e si chiama .free().

extends RefCounted

const WOOD := preload("res://scenes/interact/Woodcutting.gd")
const GEO := preload("res://scenes/world/WorldGeo.gd")


func run(t) -> void:
	_test_parse_gate(t)
	_test_notch_shape(t)
	_test_carved_mesh(t)
	_test_winding_come_l_originale(t)
	_test_ceppo_persistito(t)
	_test_fili_del_ceppo(t)
	_test_costs(t)
	_test_wallet(t)
	_test_afford(t)
	_test_save_roundtrip(t)


func _test_parse_gate(t) -> void:
	var wc = WOOD.new()
	t.ok(wc is Node, "Woodcutting è un Node")
	t.eq(WOOD.HITS_TO_FELL, 3, "servono 3 colpi per abbattere")
	t.eq(WOOD.WOOD_PER_TREE, 3, "un albero dona 3 legna")
	t.eq(WOOD.NOTCH_DEPTH.size(), WOOD.HITS_TO_FELL,
			"c'è una profondità di tacca per ogni colpo")
	wc.free()


# La tacca è geometria SOTTRATTA: la prova è che la profondità cresce a ogni
# colpo e che il cuneo si spegne fuori dalla sua zona (sopra, sotto e ai lati),
# così il tronco resta intatto ovunque tranne che nel morso.
func _test_notch_shape(t) -> void:
	var wc = WOOD.new()
	# 1) ogni colpo affonda più del precedente, e mai oltre il raggio
	var prev := 0.0
	for d in WOOD.NOTCH_DEPTH:
		t.ok(d > prev, "la tacca del colpo dopo è più profonda (%.2f > %.2f)" % [d, prev])
		prev = d
	t.ok(prev < 1.0, "nemmeno l'ultimo colpo taglia il tronco da parte a parte")

	# 2) il cuneo morde al centro e si spegne ai bordi
	var depth := 0.1
	var centro = wc._notch_cut(WOOD.NOTCH_T, PI, PI, depth)
	t.almost(centro, depth, "al centro della tacca si toglie tutta la profondità")
	t.eq(wc._notch_cut(WOOD.NOTCH_T, 0.0, PI, depth), 0.0,
			"dalla parte opposta del tronco non si toglie niente")
	t.eq(wc._notch_cut(WOOD.NOTCH_T - WOOD.NOTCH_HALF - 0.01, PI, PI, depth), 0.0,
			"sotto la tacca il tronco è intatto")
	t.eq(wc._notch_cut(WOOD.NOTCH_T + WOOD.NOTCH_HALF, PI, PI, depth), 0.0,
			"sopra la tacca il tronco è intatto")
	# 3) la parete alta è più corta di quella bassa: è la "bocca" del taglio
	var sopra = wc._notch_cut(WOOD.NOTCH_T + WOOD.NOTCH_HALF * 0.3, PI, PI, depth)
	var sotto = wc._notch_cut(WOOD.NOTCH_T - WOOD.NOTCH_HALF * 0.3, PI, PI, depth)
	t.ok(sotto > sopra, "sotto il taglio scende in pendenza, sopra è netto")
	wc.free()


# Il tronco intagliato è una mesh vera, con DUE superfici: la corteccia e il
# legno vivo esposto dal taglio.
func _test_carved_mesh(t) -> void:
	var wc = WOOD.new()
	var spec = [1.35, 0.19, 0.115, 12345]
	var intatto = wc._carved_trunk_mesh(spec, PI, 0.0)
	t.eq(intatto.get_surface_count(), 1, "il tronco intatto è tutto corteccia")
	var inciso = wc._carved_trunk_mesh(spec, PI, 0.6)
	t.eq(inciso.get_surface_count(), 2, "il tronco inciso espone il legno vivo")
	# il taglio toglie materiale: la mesh incisa sta in un volume più stretto
	var a_intatto = intatto.get_aabb()
	var a_inciso = inciso.get_aabb()
	t.ok(a_inciso.size.x <= a_intatto.size.x + 0.001,
			"la tacca non fa CRESCERE il tronco: lo scava")
	wc.free()


# L'AVVOLGIMENTO dei triangoli deve combaciare con WorldGeo.grid_commit (il
# tronco originale, provato a schermo): con l'ordine invertito la mesh
# rigenerata nasceva dentro-fuori e il tronco intagliato diventava
# TRASPARENTE dal lato della camera (facce frontali cullate). Qui si
# confronta triangolo per triangolo il tronco "inciso a profondità zero"
# con il tronco vero di WorldGeo: stessa forma E stesso verso.
func _test_winding_come_l_originale(t) -> void:
	var wc = WOOD.new()
	var spec = [1.35, 0.19, 0.115, 12345]
	var nostro: ArrayMesh = wc._carved_trunk_mesh(spec, PI, 0.0)
	var originale: ArrayMesh = GEO.trunk_mesh(1.35, 0.19, 0.115, 12345,
			0.07, WOOD.TRUNK_SEGS)
	var tri_n := _triangoli(nostro, 0)
	var tri_o := _triangoli(originale, 0)
	t.eq(tri_n.size(), tri_o.size(), "stessi triangoli del tronco originale")
	var uguali := true
	for i in mini(tri_n.size(), tri_o.size()):
		if (tri_n[i] as Vector3).distance_to(tri_o[i]) > 0.001:
			uguali = false
			break
	t.ok(uguali, "stesso ORDINE dei vertici (winding): niente tronco dentro-fuori")
	wc.free()


# i triangoli di una superficie, espansi dagli indici, come lista di vertici
# (una mesh non indicizzata ha ARRAY_INDEX nullo: si prendono i vertici così)
func _triangoli(mesh: ArrayMesh, surf: int) -> Array:
	var arrays: Array = mesh.surface_get_arrays(surf)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx = arrays[Mesh.ARRAY_INDEX]
	var out: Array = []
	if idx == null or (idx as PackedInt32Array).is_empty():
		for v in verts:
			out.append(v)
	else:
		for i in (idx as PackedInt32Array):
			out.append(verts[i])
	return out


# Il ceppo che resta è MEMORIA: va e torna dal salvataggio, separato dai
# posti già liberati (tagliati) — se finisse lì, al riavvio sparirebbe.
func _test_ceppo_persistito(t) -> void:
	var wc = WOOD.new()
	wc._ceppi = [Vector2(3.0, -2.0)]
	var data = wc.save_extra()
	t.ok(data.has("ceppi"), "il salvataggio porta con sé i ceppi a terra")
	t.eq((data["ceppi"] as Array).size(), 1, "il ceppo è nella riga giusta")
	var wc2 = WOOD.new()
	wc2.load_extra(data)
	t.eq((wc2._pending_rows as Array).size(), 3,
			"il caricamento consegna anche la riga dei ceppi")
	t.eq(((wc2._pending_rows as Array)[2] as Array).size(), 1,
			"e il ceppo è lì dentro, in attesa dell'adozione degli alberi")
	# un salvataggio vecchio (senza ceppi) non esplode
	var wc3 = WOOD.new()
	wc3.load_extra({"legna": 5})
	t.eq(((wc3._pending_rows as Array)[2] as Array).size(), 0,
			"salvataggio senza ceppi: riga vuota, nessun errore")
	wc.free()
	wc2.free()
	wc3.free()


# I fili nei sorgenti: l'abbattimento REGISTRA il ceppo (non lo sprofonda),
# le molle rispettano l'albero a terra, e solo l'estirpo libera il posto.
func _test_fili_del_ceppo(t) -> void:
	var give := _body("_give_wood")
	t.ok(give.contains("_stumps.append"), "l'abbattimento registra il ceppo")
	t.ok(not give.contains("root.queue_free"),
			"il nodo NON se ne va più da solo: il ceppo resta col suo posto")
	t.ok(_body("_update_springs").contains("down"),
			"le molle lasciano in pace l'albero a terra (niente resurrezioni)")
	var fine := _body("_finish_pull")
	t.ok(fine.contains("queue_free") and fine.contains("_felled.append"),
			"solo l'estirpo libera davvero il posto")
	t.ok(_body("_update_prompt").contains("estirpa"),
			"il prompt offre l'estirpo al giocatore")
	t.ok(_body("_build_spots").contains("_stumps"),
			"il bosco nuovo non rinasce sopra un ceppo")


# il corpo di una funzione di Woodcutting.gd (dal func alla func successiva)
func _body(fn: String) -> String:
	var f := FileAccess.open("res://scenes/interact/Woodcutting.gd", FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)


func _test_costs(t) -> void:
	var wc = WOOD.new()
	# i pezzi di legno costano; quelli che non sono di legno sono gratis
	t.ok(wc.cost_for("Pavimento") > 0, "il pavimento costa legna")
	t.ok(wc.cost_for("Muro") > 0, "il muro costa legna")
	t.ok(wc.cost_for("Muro") >= wc.cost_for("Pavimento"),
			"un muro non costa meno di un pavimento")
	t.eq(wc.cost_for("Aiuola"), 0, "l'aiuola non è di legno: gratis")
	t.eq(wc.cost_for("pezzo inventato"), 0, "pezzo sconosciuto: gratis, mai errore")
	wc.free()


func _test_wallet(t) -> void:
	var wc = WOOD.new()
	t.eq(wc.wood, WOOD.START_WOOD, "si comincia con la catasta iniziale")
	t.ok(WOOD.START_WOOD > 0, "la catasta iniziale non è vuota: si può già costruire")
	wc.add_wood(-WOOD.START_WOOD)          # si parte da zero per i conti
	wc.add_wood(5)
	t.eq(wc.wood, 5, "5 legna raccolte")
	t.ok(wc.spend_wood(3), "si spendono 3 legna")
	t.eq(wc.wood, 2, "ne restano 2")
	t.ok(not wc.spend_wood(99), "non si può spendere legna che non c'è")
	t.eq(wc.wood, 2, "e il fallimento non intacca la borsa")
	t.ok(wc.spend_wood(0), "spendere zero riesce sempre")
	wc.add_wood(-99)
	t.eq(wc.wood, 0, "la borsa non va mai sotto zero")
	wc.free()


func _test_afford(t) -> void:
	var wc = WOOD.new()
	wc.add_wood(-WOOD.START_WOOD)          # a mani vuote
	var costo = wc.cost_for("Muro")
	t.ok(not wc.can_afford_piece("Muro"), "senza legna non si costruisce il muro")
	t.ok(wc.can_afford_piece("Aiuola"), "l'aiuola si fa anche a mani vuote")
	wc.add_wood(costo)
	t.ok(wc.can_afford_piece("Muro"), "con la legna giusta, il muro si può fare")
	t.ok(wc.pay_for_piece("Muro"), "il muro si paga")
	t.eq(wc.wood, 0, "e la legna se n'è andata")
	t.ok(not wc.pay_for_piece("Muro"), "il secondo muro non si può pagare")
	wc.free()


func _test_save_roundtrip(t) -> void:
	var wc = WOOD.new()
	wc.add_wood(-WOOD.START_WOOD)          # dalla catasta iniziale a zero
	wc.add_wood(7)
	var data = wc.save_extra()
	t.eq(int(data["legna"]), 7, "il salvataggio porta con sé la legna")
	t.ok(data.has("tagliati"), "e la memoria degli alberi abbattuti")
	t.ok(data.has("debito"), "e il debito col bosco (quanti devono rinascere)")
	t.ok(data.has("piantati"), "e dove sono nati quelli nuovi")

	var wc2 = WOOD.new()
	wc2.load_extra(data)
	t.eq(wc2.wood, 7, "ricaricando, la legna torna")
	# un salvataggio vecchio (senza la chiave) non deve far esplodere nulla
	wc2.load_extra({})
	t.eq(wc2.wood, WOOD.START_WOOD,
			"salvataggio senza legna: si riceve la catasta iniziale, senza errori")
	wc.free()
	wc2.free()
