extends RefCounted
## IL BAR DEL PAESE: i quindici pezzi del punto di ritrovo.
##
## Stesse tre guardie del posto di guardia, perché sono le tre cose che
## si rompono in silenzio: un builder che esplode si scopre solo quando
## il giocatore piazza il pezzo; un corredo che promette pezzi
## inesistenti fa pagare per sbloccare fantasmi; e i nomi sono ID che
## finiscono in village.json, non testo da tradurre.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const ECONOMY = preload("res://scenes/ui/Economy.gd")

const PEZZI := ["Bancone bar", "Tenda bar", "Insegna bar", "Macchina caffè",
		"Vetrina dolci", "Sgabello alto", "Mensola bottiglie", "Tavolino bar",
		"Sedia vimini", "Lavagnetta", "Biliardino", "Ombrellone", "Fioriera",
		"Lucine", "Frigo gelati"]


func run(t) -> void:
	_test_i_pezzi_esistono(t)
	_test_si_costruiscono_davvero(t)
	_test_il_corredo(t)
	_test_il_bar_ha_le_sue_cose(t)


func _test_i_pezzi_esistono(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		t.ok(per_nome.has(n), "«%s» è nel catalogo" % n)
	t.eq(PEZZI.size(), 15, "quindici pezzi: un bar che si può davvero mettere su")


## Ogni pezzo si costruisce, ha geometria vera, poggia a terra e sta
## dentro la sua cella. L'ingombro è la guardia che ha già beccato un
## tetto da 1,59 m su una cella da un metro (il posto di guardia).
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
		var aabb := _ingombro(nodo)
		t.ok(aabb.position.y > -0.35,
				"«%s» non sprofonda sottoterra (y=%.2f)" % [n, aabb.position.y])
		t.ok(aabb.size.x < 2.2 and aabb.size.z < 2.2,
				"«%s» sta nella sua cella (%.1f x %.1f)" % [n, aabb.size.x, aabb.size.z])
		t.ok(aabb.size.y < 2.6,
				"«%s» non buca il tetto (alto %.1f)" % [n, aabb.size.y])
		nodo.free()


func _test_il_corredo(t) -> void:
	var per_nome := _catalogo()
	t.ok(ECONOMY.CORREDO.has("Bancone bar"),
			"il bancone ha un corredo: un bar o c'è intero, o è una stanza vuota")
	var corredo: Array = ECONOMY.CORREDO["Bancone bar"]
	for n in corredo:
		t.ok(per_nome.has(str(n)),
				"il corredo promette «%s», e il catalogo ce l'ha" % n)
	t.eq(corredo.size(), PEZZI.size() - 1,
			"tutto il bar tranne il bancone stesso (%d pezzi)" % corredo.size())
	t.ok(not "Bancone bar" in corredo,
			"il bancone non è nel proprio corredo")
	var in_negozio := false
	for p in ECONOMY.SHOP_PIECES:
		if str(p["name"]) == "Bancone bar":
			in_negozio = true
			t.ok(int(p["cost"]) > 0, "il bancone ha un prezzo")
	t.ok(in_negozio, "il bancone sta sul banco del mercante")
	# nessun pezzo può stare in due corredi: si sbloccherebbe due volte e
	# il secondo padrone non lo saprebbe mai
	var visto := {}
	for ancora in ECONOMY.CORREDO:
		for pezzo in ECONOMY.CORREDO[ancora]:
			t.ok(not visto.has(str(pezzo)),
					"«%s» sta in un corredo solo (era già di «%s»)"
					% [pezzo, visto.get(str(pezzo), "")])
			visto[str(pezzo)] = str(ancora)


## Un punto di ritrovo ha bisogno di tre cose: dove stare in piedi a
## chiacchierare, dove sedersi, e qualcosa da fare insieme. Se un giorno
## qualcuno togliesse una delle tre, il bar smetterebbe di essere un bar
## e nessun test se ne accorgerebbe.
func _test_il_bar_ha_le_sue_cose(t) -> void:
	var per_nome := _catalogo()
	t.ok(per_nome.has("Bancone bar") and per_nome.has("Sgabello alto"),
			"c'è dove appoggiare il gomito e dove stare in bilico")
	t.ok(per_nome.has("Tavolino bar") and per_nome.has("Sedia vimini"),
			"e c'è dove sedersi in due")
	t.ok(per_nome.has("Biliardino"),
			"e c'è qualcosa da fare INSIEME: è quello che rende un posto un ritrovo")
	# dentro e fuori: il dehors è metà del bar italiano
	t.ok(per_nome.has("Ombrellone") and per_nome.has("Fioriera")
			and per_nome.has("Lucine"),
			"il dehors esiste: ombrellone, fioriera e lucine")
	# e le categorie sono sensate: il bancone è Struttura, i tavolini
	# Arredo, il dehors Giardino — o nel menu di costruzione il bar
	# finisce tutto in un mucchio
	t.eq(int(per_nome["Bancone bar"]["cat"]), 0, "il bancone è Struttura")
	t.eq(int(per_nome["Tavolino bar"]["cat"]), 1, "il tavolino è Arredo")
	t.eq(int(per_nome["Ombrellone"]["cat"]), 2, "l'ombrellone è Giardino")


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


func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in _tutte_le_mesh(n):
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var mondo := _trasformata_relativa(mi, n) * a
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
