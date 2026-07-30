extends RefCounted
## La chiesa del paese: i quindici pezzi e i sette attrezzi di geometria che
## li tengono in piedi.
##
## Non prova la bellezza (quella si guarda), prova le cose che si rompono in
## silenzio: un pezzo che affonda o che vola, una collisione dimenticata, un
## nome senza traduzione inglese, un pezzo del corredo che finisce anche in
## vendita da solo. E soprattutto gli HELPER: l'arco a tutto sesto, il rosone
## e la fabbrica dei vetri sono usati da mezzo set — se si storce uno di
## quelli si storcono nove pezzi insieme, e nessun errore lo dice.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const CH := preload("res://scenes/build/BuildChiesa.gd")
const ECO := preload("res://scenes/ui/Economy.gd")
const EN_UI := preload("res://locale/en/ui.gd")
const BUILD := preload("res://scenes/build/BuildSystem.gd")

const ANCORA := "Campanile"
const CORREDO := ["Muro di pietra", "Lastricato", "Vetrata", "Banco", "Volta",
		"Sagrato", "Arcata", "Portale", "Frontone", "Abside", "Altare",
		"Candeliere", "Fonte dei nomi", "Armonium"]

## I pezzi che stanno in alto: la volta e un soffitto, il suo posto e il
## soffitto. Tutti gli altri devono toccare terra.
const IN_ALTO := ["Volta"]


func run(t) -> void:
	var voci := _voci()
	_test_pezzi_nel_catalogo(t, voci)
	_test_geometria(t, voci)
	_test_categoria(t)
	_test_corredo(t)
	_test_traduzioni(t)
	_test_arco(t)
	_test_rosone(t)
	_test_vetri(t)
	_test_movimento(t, voci)


func _tutti() -> Array:
	return [ANCORA] + CORREDO


func _voci() -> Dictionary:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	return per_nome


# ------------------------------------------------------------- catalogo

func _test_pezzi_nel_catalogo(t, voci: Dictionary) -> void:
	for nome in _tutti():
		t.ok(voci.has(nome), "la chiesa ha il pezzo «%s»" % nome)
		if not voci.has(nome):
			continue
		var v: Dictionary = voci[nome]
		t.eq(int(v["cat"]), 4, "%s sta nella categoria Chiesa" % nome)
		t.ok(str(v["type"]) in ["cell", "edge"], "%s ha un tipo valido" % nome)
		t.ok(v["builder"] is Callable, "%s ha un builder" % nome)


func _test_geometria(t, voci: Dictionary) -> void:
	for nome in _tutti():
		if not voci.has(nome):
			continue
		var v: Dictionary = voci[nome]
		var node: Node3D = v["builder"].call()
		t.ok(node != null and node.get_child_count() > 0,
				"%s costruisce qualcosa" % nome)
		if node == null:
			continue
		var box := _ingombro(node, Transform3D.IDENTITY)
		t.ok(box.position.y > -0.06, "%s non affonda nel terreno" % nome)
		if nome in IN_ALTO:
			# la volta nasce dal filo di sopra dei muri: se scendesse a terra
			# sarebbe una gobba in mezzo alla navata
			t.ok(box.position.y > 1.5, "%s sta all'altezza del soffitto" % nome)
		elif str(v["type"]) == "cell":
			t.ok(box.position.y < 0.32, "%s tocca terra" % nome)
		else:
			t.ok(box.position.y + box.size.y < 3.3,
					"%s non sfonda l'altezza di una facciata" % nome)
		# in scala col villaggio: una cella e un metro
		t.ok(box.size.x < 2.2 and box.size.z < 2.2,
				"%s sta nel suo ingombro" % nome)
		t.ok(box.size.y < 4.0, "%s non e piu alto di quattro metri" % nome)
		for c in v.get("cols", []):
			var dim: Vector3 = c[0]
			t.ok(dim.x > 0.0 and dim.y > 0.0 and dim.z > 0.0,
					"%s: collisione con misure positive" % nome)
		node.free()


func _ingombro(node: Node3D, sopra: Transform3D) -> AABB:
	var mio := sopra * node.transform
	var box := AABB()
	var primo := true
	if node is MeshInstance3D and node.mesh != null:
		box = mio * node.mesh.get_aabb()
		primo = false
	for figlio in node.get_children():
		if figlio is not Node3D:
			continue
		var sotto := _ingombro(figlio, mio)
		if sotto.size == Vector3.ZERO:
			continue
		if primo:
			box = sotto
			primo = false
		else:
			box = box.merge(sotto)
	return box


func _test_categoria(t) -> void:
	# la riga delle categorie e costruita con un ciclo su CAT_NAMES: se la
	# voce non c'e, i pezzi della chiesa esistono ma non si possono scegliere
	t.ok(BUILD.CAT_NAMES.size() > 4, "c'e la quinta categoria")
	t.eq(str(BUILD.CAT_NAMES[4]), "Chiesa", "la quinta categoria e la Chiesa")
	# le scorciatoie da tastiera sono 1-9: i pezzi che si piazzano a decine
	# devono stare nei primi nove, o restano senza tasto
	var in_ordine := []
	for v in CAT.items():
		if int(v["cat"]) == 4:
			in_ordine.append(str(v["name"]))
	for muratura in ["Muro di pietra", "Lastricato", "Vetrata", "Banco"]:
		t.ok(in_ordine.find(muratura) < 9,
				"«%s» sta nei primi nove: ha una scorciatoia" % muratura)


# --------------------------------------------------------------- corredo

func _test_corredo(t) -> void:
	var corredo: Array = ECO.CORREDO.get(ANCORA, [])
	t.eq(corredo.size(), CORREDO.size(), "il corredo della chiesa e completo")
	for pezzo in CORREDO:
		t.ok(pezzo in corredo, "il corredo porta «%s»" % pezzo)
	var in_vendita := {}
	for offerta in ECO.SHOP_PIECES:
		in_vendita[str(offerta["name"])] = true
	t.ok(in_vendita.has(ANCORA), "il campanile e al banco del mercante")
	for pezzo in CORREDO:
		t.ok(not in_vendita.has(pezzo),
				"«%s» arriva col corredo, non si vende da solo" % pezzo)


# ------------------------------------------------------------ traduzione

func _test_traduzioni(t) -> void:
	var en: Dictionary = EN_UI.tabella()
	t.ok(en.has("Chiesa"), "la categoria ha il suo nome inglese")
	for nome in _tutti():
		t.ok(en.has(nome), "«%s» ha il suo nome inglese" % nome)
		if en.has(nome):
			t.ok(str(en[nome]).strip_edges() != "",
					"«%s» non ha una traduzione vuota" % nome)
	for offerta in ECO.SHOP_PIECES:
		if str(offerta["name"]) != ANCORA:
			continue
		var desc := str(offerta.get("desc", ""))
		t.ok(en.has(desc), "la descrizione del campanile e tradotta")
		if en.has(desc):
			t.eq(str(en[desc]).count("\n"), desc.count("\n"),
					"la descrizione inglese ha le stesse righe")


# --------------------------------------------------------- gli attrezzi

func _test_arco(t) -> void:
	# l'arco a tutto sesto: mezzo set lo usa. Deve fare un SEMICERCHIO —
	# i conci tutti alla stessa distanza dal centro, e il primo e l'ultimo
	# alle due reni, non uno a mezz'aria.
	var n := Node3D.new()
	var mat := CAT._mat(Color.WHITE, Color.GRAY)
	var arco: Node3D = CH.arco_conci(n, mat, mat, 0.30, 0.14, 0.20, 11,
			Vector3(0, 1.0, 0))
	t.eq(arco.get_child_count(), 11, "l'arco ha tutti i suoi conci")
	var raggio := 0.30 + 0.14 * 0.5
	var minima := 9.9
	var massima := -9.9
	for c in arco.get_children():
		var nodo := c as Node3D
		var p: Vector3 = nodo.position
		t.almost(p.length(), raggio, "il concio sta sul cerchio", 0.001)
		t.ok(p.y > -0.001, "nessun concio scende sotto l'imposta")
		# L'ORIENTAMENTO, che e la meta che si dimentica: la lunghezza del
		# concio deve stare sulla TANGENTE, cioe perpendicolare al raggio.
		# Con questo controllo mancante l'arco passava i test da rotto —
		# i conci erano tutti sul cerchio, ma girati dalla parte sbagliata,
		# e a schermo era una manciata di sassi per aria.
		var lungo := nodo.transform.basis.x.normalized()
		var raggiale := Vector3(p.x, p.y, 0).normalized()
		t.almost(absf(lungo.dot(raggiale)), 0.0,
				"il concio e disposto sulla tangente, non di sbieco", 0.002)
		minima = minf(minima, p.x)
		massima = maxf(massima, p.x)
	# le due reni: l'arco copre tutta la semicirconferenza, non un pezzetto
	t.ok(massima > raggio * 0.9, "l'arco arriva alla rene destra")
	t.ok(minima < -raggio * 0.9, "l'arco arriva alla rene sinistra")
	n.free()


func _test_rosone(t) -> void:
	var n := Node3D.new()
	var vetri := [CH.vetro(CH.VETRO_RUBINO), CH.vetro(CH.VETRO_COBALTO)]
	var r: Node3D = CH.rosa(n, 12, 0.23, vetri, CH.piombo(),
			CH.vetro(CH.VETRO_AMBRA), Vector3.ZERO)
	# dodici petali + dodici piombi + due anelli + il cuore
	t.eq(r.get_child_count(), 27, "il rosone ha petali, piombi, anelli e cuore")
	# il numero di petali si stringe fra sei e sedici: sotto sembra una ruota
	# di carro, sopra diventa poltiglia
	var pochi: Node3D = CH.rosa(n, 2, 0.2, vetri, CH.piombo(), vetri[0], Vector3.ZERO)
	t.ok(pochi.get_child_count() >= 15, "sotto i sei petali il rosone si difende")
	n.free()


func _test_vetri(t) -> void:
	# la banda di sicurezza sta DENTRO l'helper: un'emissione alta su un
	# colore chiaro sbianca il vetro e la vetrata diventa una fila di
	# lampadine (la lezione del faro della caserma)
	var caldo: StandardMaterial3D = CH.vetro(CH.VETRO_RUBINO, 9.0)
	t.almost(caldo.emission_energy_multiplier, 1.0,
			"l'emissione di un vetro non sale oltre uno", 0.001)
	var freddo: StandardMaterial3D = CH.vetro(CH.VETRO_COBALTO, 0.0)
	t.almost(freddo.emission_energy_multiplier, 0.4,
			"un vetro non si spegne mai del tutto", 0.001)
	var v: StandardMaterial3D = CH.vetro(CH.VETRO_SMERALDO, 0.7)
	t.almost(v.albedo_color.r, CH.VETRO_SMERALDO.r,
			"il vetro non schiarisce il suo colore", 0.001)
	t.ok(v.emission_enabled, "il vetro si accende")
	# i vetri sono UNA tavolozza sola: la stessa che usano vetrata, portale,
	# frontone, abside e la lampada della volta
	for c in [CH.VETRO_RUBINO, CH.VETRO_COBALTO, CH.VETRO_AMBRA,
			CH.VETRO_SMERALDO, CH.VETRO_VIOLA, CH.VETRO_LATTE]:
		t.ok(c.s >= 0.0 and c.v > 0.3, "il vetro %s ha luce da attraversare" % c)


func _test_movimento(t, voci: Dictionary) -> void:
	# i pezzi piazzati sono nodi nudi: quello che si muove lo muove un
	# AnimationPlayer in loop. Se sparisse, la campana resterebbe ferma e
	# le candele spente senza che un solo errore lo dica.
	var campanile: Node3D = voci[ANCORA]["builder"].call()
	t.ok(_trova(campanile, "Campana") != null, "il campanile ha la sua campana")
	t.ok(_player(campanile) != null, "la campana ha il suo AnimationPlayer")
	campanile.free()

	var cand: Node3D = voci["Candeliere"]["builder"].call()
	t.ok(_trova(cand, "Fiamma0") != null or _trova(cand, "Fiamma1") != null,
			"il candeliere ha le sue fiamme")
	var p := _player(cand)
	t.ok(p != null, "le fiamme hanno il loro AnimationPlayer")
	if p != null:
		t.ok(p.autoplay != "", "il respiro delle fiamme parte da solo")
	cand.free()


func _trova(n: Node, nome: String) -> Node:
	if n.name == nome:
		return n
	for f in n.get_children():
		var t := _trova(f, nome)
		if t != null:
			return t
	return null


func _player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for f in n.get_children():
		var p := _player(f)
		if p != null:
			return p
	return null
