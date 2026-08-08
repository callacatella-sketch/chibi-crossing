extends RefCounted
## LE AIUOLE CHE SI UNISCONO: due celle affiancate, UNA striscia di terra.
##
## Il patto è lo stesso del Sentiero (rinfresca_* statico guidato dal
## dizionario), e queste prove tengono chiuse le porte che si romperebbero
## in silenzio: la palizzata che non si apre verso la vicina (due muri di
## tronchetti in mezzo alla striscia), la lingua di terra che manca (un
## fosso fra le aiuole), il rinfresco che non torna indietro quando una
## delle due si toglie, e il Garden che perde velo e germogli perché il
## rinfresco butta via la radice invece del solo figlio «Terra».

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const BUILD = preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_test_la_sola_resta_quella_di_prima(t)
	_test_verso_la_vicina_ci_si_apre(t)
	_test_la_striscia_in_mezzo(t)
	_test_l_angolo_della_elle(t)
	_test_il_rinfresco_va_e_torna(t)
	_test_il_garden_non_perde_niente(t)
	_test_stesso_seme_stessa_aiuola(t)


func _terra(vicini: Dictionary, seme := 7) -> Array:
	var radice = CAT.aiuola_cella(vicini, seme)
	return [radice, radice.get_node("Terra")]


## L'aiuola senza vicine: 30 tronchetti, l'etichetta, nessuna lingua.
func _test_la_sola_resta_quella_di_prima(t) -> void:
	var coppia := _terra({})
	var terra: Node3D = coppia[1]
	t.eq(terra.get_node("Palizzata").get_child_count(), 30,
			"da sola la palizzata è chiusa: trenta tronchetti")
	t.ok(terra.get_node_or_null("Etichetta") != null,
			"da sola ha l'etichetta segna-semi")
	for lato in ["E", "O", "S", "N"]:
		t.ok(terra.get_node_or_null("Estensione" + lato) == null,
				"da sola nessuna lingua di terra verso %s" % lato)
	(coppia[0] as Node3D).free()


## Con una vicina a est: la palizzata si apre di là, la terra si allunga
## fino al confine, i solchi proseguono, l'etichetta sparisce.
func _test_verso_la_vicina_ci_si_apre(t) -> void:
	var coppia := _terra({"e": true})
	var terra: Node3D = coppia[1]
	var palizzata: Node3D = terra.get_node("Palizzata")
	t.ok(palizzata.get_child_count() < 30,
			"verso la vicina l'arco si apre (%d tronchetti)" % palizzata.get_child_count())
	for tronco in palizzata.get_children():
		var p: Vector3 = (tronco as Node3D).position
		t.ok(not (p.x > 0.1 and absf(p.z) < 0.35),
				"nessun tronchetto in mezzo alla terra unita (%.2f, %.2f)" % [p.x, p.z])
	var lingua = terra.get_node_or_null("EstensioneE")
	t.ok(lingua != null, "la lingua di terra verso est c'è")
	# la lingua arriva OLTRE il confine di cella (0.5): il tappo muore
	# dentro la terra della vicina, mai complanare sul confine
	if lingua != null:
		var aabb := _ingombro(lingua)
		t.ok(aabb.position.x + aabb.size.x > 0.5,
				"la terra supera il confine (x max %.3f)" % (aabb.position.x + aabb.size.x))
	var segmenti := 0
	for f in terra.get_children():
		if str(f.name).begins_with("SolcoE"):
			segmenti += 1
	t.eq(segmenti, 3, "i tre solchi proseguono sulla lingua")
	t.ok(terra.get_node_or_null("Etichetta") == null,
			"in una striscia niente etichetta per cella (sarebbe un cimitero di cartellini)")
	(coppia[0] as Node3D).free()


## La cella in MEZZO alla striscia: niente arco, solo i fianchi dritti.
func _test_la_striscia_in_mezzo(t) -> void:
	var coppia := _terra({"e": true, "o": true})
	var terra: Node3D = coppia[1]
	var palizzata: Node3D = terra.get_node("Palizzata")
	for tronco in palizzata.get_children():
		t.ok(absf(((tronco as Node3D).position as Vector3).z) > 0.4,
				"in mezzo alla striscia i tronchetti stanno SOLO sui fianchi")
	t.eq(palizzata.get_child_count(), 20,
			"cinque tronchetti per fianco per lato: venti in tutto")
	t.ok(terra.get_node_or_null("EstensioneE") != null
			and terra.get_node_or_null("EstensioneO") != null,
			"la terra si allunga da tutte e due le parti")
	(coppia[0] as Node3D).free()


## L'angolo della L (vicine a est e a sud): il fianco che guarda la terra
## unita resta APERTO — niente tronchetti piantati in mezzo all'aiuola.
func _test_l_angolo_della_elle(t) -> void:
	var coppia := _terra({"e": true, "s": true})
	var terra: Node3D = coppia[1]
	for tronco in terra.get_node("Palizzata").get_children():
		var p: Vector3 = (tronco as Node3D).position
		t.ok(not (p.x > 0.1 and p.z > 0.1),
				"il quadrante interno della L è terra aperta (%.2f, %.2f)" % [p.x, p.z])
	t.ok(terra.get_node_or_null("EstensioneE") != null
			and terra.get_node_or_null("EstensioneS") != null,
			"le due lingue della L ci sono")
	(coppia[0] as Node3D).free()


## Il rinfresco vero di BuildSystem: si posa la vicina e le due si
## uniscono; si toglie, e ognuna torna intera. Guidato dal dizionario,
## come in partita.
func _test_il_rinfresco_va_e_torna(t) -> void:
	var a := _finta_aiuola()
	var b := _finta_aiuola()
	var dict := {Vector2i(0, 0): a, Vector2i(1, 0): b}
	BUILD.rinfresca_aiuole(dict, Vector2i(1, 0))
	t.ok((a.get_node("Terra") as Node3D).get_node_or_null("EstensioneE") != null,
			"posata la vicina, la prima si allunga verso est")
	t.ok((b.get_node("Terra") as Node3D).get_node_or_null("EstensioneO") != null,
			"…e la nuova verso ovest: la striscia è una")
	# la vicina se ne va: il rinfresco richiude la palizzata
	dict.erase(Vector2i(1, 0))
	BUILD.rinfresca_aiuole(dict, Vector2i(1, 0))
	var terra_a := a.get_node("Terra") as Node3D
	t.ok(terra_a.get_node_or_null("EstensioneE") == null,
			"tolta la vicina, la lingua di terra si ritira")
	t.eq((terra_a.get_node("Palizzata") as Node3D).get_child_count(), 30,
			"…e la palizzata torna chiusa, trenta tronchetti")
	a.free()
	b.free()


## IL GARDEN NON PERDE NIENTE: velo d'acqua e germogli stanno appesi alla
## RADICE del pezzo, e il rinfresco scambia solo il figlio «Terra».
func _test_il_garden_non_perde_niente(t) -> void:
	var a := _finta_aiuola()
	var velo := MeshInstance3D.new()
	velo.name = "VeloDelGarden"
	a.add_child(velo)
	var dict := {Vector2i(0, 0): a, Vector2i(0, 1): _finta_aiuola()}
	BUILD.rinfresca_aiuole(dict, Vector2i(0, 1))
	t.ok(a.get_node_or_null("VeloDelGarden") != null,
			"il velo d'acqua del Garden sopravvive al rinfresco")
	t.ok((a.get_node("Terra") as Node3D).get_node_or_null("EstensioneS") != null,
			"…mentre la terra si è comunque rifatta (lingua verso sud)")
	(dict[Vector2i(0, 1)] as Node3D).free()
	a.free()


## Stesso seme, stessa aiuola: i salvataggi non ballano fra un
## caricamento e l'altro.
func _test_stesso_seme_stessa_aiuola(t) -> void:
	var prima := _terra({"e": true}, 42)
	var dopo := _terra({"e": true}, 42)
	var pal1: Node3D = (prima[1] as Node3D).get_node("Palizzata")
	var pal2: Node3D = (dopo[1] as Node3D).get_node("Palizzata")
	t.eq(pal1.get_child_count(), pal2.get_child_count(),
			"stesso seme, stessi tronchetti")
	if pal1.get_child_count() > 0:
		var p1: Vector3 = (pal1.get_child(0) as Node3D).position
		var p2: Vector3 = (pal2.get_child(0) as Node3D).position
		t.almost((p1 - p2).length(), 0.0, "…negli stessi posti esatti", 0.0001)
	(prima[0] as Node3D).free()
	(dopo[0] as Node3D).free()


## Un'aiuola come la vede il dizionario di BuildSystem: la radice del
## builder con il meta che place_cell le appiccica.
func _finta_aiuola() -> Node3D:
	var nodo = CAT.aiuola_cella({}, 3)
	nodo.set_meta("item_name", "Aiuola")
	return nodo


func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in _mesh_di(n):
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var tr := Transform3D.IDENTITY
		var cur := mi as Node3D
		while cur != null and cur != n:
			tr = cur.transform * tr
			cur = cur.get_parent() as Node3D
		var mondo := tr * a
		if primo:
			out = mondo
			primo = false
		else:
			out = out.merge(mondo)
	return out


func _mesh_di(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for f in n.get_children():
		out.append_array(_mesh_di(f))
	return out
