extends RefCounted
## IL POSTO DI GUARDIA: i tredici pezzi e il loro corredo.
##
## In un gioco che non punisce nessuno la stazione non è autorità: è il
## posto dove le cose perse tornano da chi le ha perse. Questi test
## tengono insieme le tre cose che si romperebbero in silenzio: che ogni
## pezzo si costruisca davvero (un builder che esplode si scopre solo
## piazzandolo), che il corredo non prometta pezzi inesistenti, e che i
## nomi restino ITALIANI — sono chiavi di village.json, non testo.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const ECONOMY = preload("res://scenes/ui/Economy.gd")

const PEZZI := ["Guardiola", "Insegna guardia", "Sbarra", "Bancone guardia",
		"Armadio smarriti", "Bacheca avvisi", "Attaccapanni", "Brandina",
		"Lanterna blu", "Cono", "Transenna", "Bicicletta", "Cassetta smarriti"]


func run(t) -> void:
	_test_i_pezzi_esistono(t)
	_test_si_costruiscono_davvero(t)
	_test_il_corredo(t)
	_test_nomi_e_collisioni(t)


func _test_i_pezzi_esistono(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		t.ok(per_nome.has(n), "«%s» è nel catalogo" % n)
	t.eq(PEZZI.size(), 13, "tredici pezzi: un posto di guardia intero")


## Un builder si rompe solo quando qualcuno lo piazza — cioè in mano al
## giocatore. Qui si costruiscono TUTTI davvero, e si controlla che
## producano geometria vera invece di un nodo vuoto.
func _test_si_costruiscono_davvero(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		var voce: Dictionary = per_nome.get(n, {})
		if voce.is_empty():
			continue
		var nodo = (voce["builder"] as Callable).call()
		t.ok(nodo != null, "«%s» costruisce un nodo" % n)
		if nodo == null:
			continue
		var mesh := _conta_mesh(nodo)
		t.ok(mesh >= 3, "«%s» ha geometria vera (%d mesh)" % [n, mesh])
		# niente pezzi che sprofondano o galleggiano: l'aabb deve toccare
		# terra e restare dentro una cella e mezza
		var aabb := _ingombro(nodo)
		t.ok(aabb.position.y > -0.35,
				"«%s» non sprofonda sottoterra (y=%.2f)" % [n, aabb.position.y])
		t.ok(aabb.size.x < 2.2 and aabb.size.z < 2.2,
				"«%s» sta nel villaggio (%.1f x %.1f)" % [n, aabb.size.x, aabb.size.z])
		nodo.free()


## Il corredo: comprare la guardiola porta con sé le sue cose. Se una
## voce del corredo non esiste nel catalogo, il giocatore paga e sblocca
## un pezzo fantasma — e non se ne accorge nessuno.
func _test_il_corredo(t) -> void:
	var per_nome := _catalogo()
	t.ok(ECONOMY.CORREDO.has("Guardiola"),
			"la guardiola ha un corredo: un posto arriva con le sue cose")
	var corredo: Array = ECONOMY.CORREDO["Guardiola"]
	for n in corredo:
		t.ok(per_nome.has(str(n)),
				"il corredo promette «%s», e il catalogo ce l'ha" % n)
	t.eq(corredo.size(), PEZZI.size() - 1,
			"tutto il posto tranne la guardiola stessa (%d pezzi)" % corredo.size())
	t.ok(not "Guardiola" in corredo,
			"la guardiola non è nel proprio corredo (si sbloccherebbe da sola)")
	# e la guardiola dev'essere comprabile, o il corredo non arriva mai
	var in_negozio := false
	for p in ECONOMY.SHOP_PIECES:
		if str(p["name"]) == "Guardiola":
			in_negozio = true
			t.ok(int(p["cost"]) > 0, "la guardiola ha un prezzo")
	t.ok(in_negozio, "la guardiola sta sul banco del mercante")


## I nomi dei pezzi sono ID: finiscono in village.json e nelle chiavi del
## corredo. Restano italiani per sempre — si traduce solo il display.
func _test_nomi_e_collisioni(t) -> void:
	var visti := {}
	var doppioni: Array = []
	for v in CAT.items():
		var n := str(v["name"])
		if visti.has(n):
			doppioni.append(n)
		visti[n] = true
	t.eq(doppioni.size(), 0,
			"nessun nome di pezzo doppio nel catalogo (%s)" % str(doppioni))
	for n in PEZZI:
		t.ok(n == n.strip_edges() and not n.contains("  "),
				"«%s» è un id pulito" % n)


func _catalogo() -> Dictionary:
	var out := {}
	for v in CAT.items():
		out[str(v["name"])] = v
	return out


func _conta_mesh(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		c += 1
	for f in n.get_children():
		c += _conta_mesh(f)
	return c


## L'ingombro reale del pezzo, unendo gli aabb di tutte le sue mesh nello
## spazio del pezzo (le trasformate dei figli comprese).
func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in _tutte_le_mesh(n):
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var t := _trasformata_relativa(mi, n)
		var mondo := t * a
		if primo:
			out = mondo
			primo = false
		else:
			out = out.merge(mondo)
	return out


func _tutte_le_mesh(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for f in n.get_children():
		out.append_array(_tutte_le_mesh(f))
	return out


func _trasformata_relativa(nodo: Node3D, radice: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := nodo
	while cur != null and cur != radice:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t
