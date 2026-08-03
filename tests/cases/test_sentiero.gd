extends RefCounted
## IL SENTIERO CHE SI RICONOSCE — le pietre, e le celle che si parlano.
##
## Si prova quello che, sbagliato, non darebbe nessun errore:
##  · il patto del confine (la pietra a cavallo la mette UNA cella sola,
##    quella che guarda in direzione positiva: doppiarla è z-fighting,
##    non metterla è un buco nella passata);
##  · la continuità: due celle affiancate coprono il confine senza varco;
##  · il determinismo: lo stesso seme rifà le stesse pietre (i
##    salvataggi non devono ballare da un caricamento all'altro);
##  · il rinfresco di BuildSystem: posata la vicina, la cella si rifà le
##    pietre e tende verso di lei — e il wrapper compensa la rotazione.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const SYS := preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_test_da_sola(t)
	_test_il_patto_del_confine(t)
	_test_continuita(t)
	_test_determinismo(t)
	_test_rinfresco(t)
	_test_rotazione_compensata(t)


func _test_da_sola(t) -> void:
	var cella = CAT.sentiero_cella({}, 42)
	var pietre := cella.get_node("Pietre") as Node3D
	t.ok(pietre != null, "le pietre vivono nel wrapper «Pietre»")
	var mesh := _mesh_di(pietre)
	t.ok(mesh.size() >= 8, "una cella sola ha le sue lastre e i sassolini (%d mesh)" % mesh.size())
	var a := _ingombro(pietre)
	t.ok(a.size.x < 1.1 and a.size.z < 1.1, "e sta nella sua cella")
	t.ok(a.position.y > -0.05 and a.size.y < 0.25, "raso terra, come un sentiero")


## Verso EST la cella mette la pietra del confine (arriva a x=0.5);
## verso OVEST no: là il confine è del vicino.
func _test_il_patto_del_confine(t) -> void:
	var est = CAT.sentiero_cella({"e": true}, 7)
	var ae := _ingombro(est.get_node("Pietre"))
	t.ok(ae.position.x + ae.size.x > 0.5,
			"verso est la pietra del confine c'è (arriva a %.2f)" % (ae.position.x + ae.size.x))
	est.free()
	var ovest = CAT.sentiero_cella({"o": true}, 7)
	var ao := _ingombro(ovest.get_node("Pietre"))
	t.ok(ao.position.x > -0.48,
			"verso ovest NO: il confine è del vicino (si ferma a %.2f)" % ao.position.x)
	t.ok(ao.position.x < -0.30,
			"ma il passo interno tende comunque verso di lui")
	ovest.free()


## Due celle affiancate: la passata copre il confine senza varco.
func _test_continuita(t) -> void:
	var a = CAT.sentiero_cella({"e": true}, 11)     # cella (0,0)
	var b = CAT.sentiero_cella({"o": true}, 23)     # cella (1,0)
	var ia := _ingombro(a.get_node("Pietre"))
	var ib := _ingombro(b.get_node("Pietre"))
	# nel mondo: a copre fino a (ia.max), b comincia a 1.0 + ib.min
	var fine_a := ia.position.x + ia.size.x
	var inizio_b := 1.0 + ib.position.x
	t.ok(fine_a >= inizio_b - 0.06,
			"la passata è continua sul confine (varco %.3f m)" % (inizio_b - fine_a))
	a.free()
	b.free()


func _test_determinismo(t) -> void:
	var a = CAT.sentiero_cella({"e": true, "n": true}, 99)
	var b = CAT.sentiero_cella({"e": true, "n": true}, 99)
	var pa := _posizioni(a.get_node("Pietre"))
	var pb := _posizioni(b.get_node("Pietre"))
	t.eq(pa.size(), pb.size(), "stesso seme, stesse pietre")
	var peggio := 0.0
	for i in pa.size():
		peggio = maxf(peggio, (pa[i] as Vector3).distance_to(pb[i]))
	t.ok(peggio < 0.0001, "identiche al millimetro: i salvataggi non ballano")
	a.free()
	b.free()


## Il rinfresco di BuildSystem: due Sentieri affiancati nel dizionario,
## e dopo il rinfresco la cella tende verso la vicina.
func _test_rinfresco(t) -> void:
	var dict := {}
	for c in [Vector2i(0, 0), Vector2i(1, 0)]:
		var nodo = CAT.items()[1]["builder"].call()    # il Sentiero del catalogo
		nodo.set_meta("item_name", "Sentiero")
		nodo.set_meta("rot", 0)
		dict[c] = nodo
	SYS.rinfresca_sentieri(dict, Vector2i(0, 0))
	var pietre_a := _pietre_vive(dict[Vector2i(0, 0)])
	var pietre_b := _pietre_vive(dict[Vector2i(1, 0)])
	t.ok(pietre_a != null and pietre_b != null, "il rinfresco ha rifatto le pietre")
	var ia := _ingombro(pietre_a)
	var ib := _ingombro(pietre_b)
	t.ok(ia.position.x + ia.size.x > 0.5,
			"la cella tende verso la vicina a est (%.2f)" % (ia.position.x + ia.size.x))
	t.ok(ib.position.x < -0.30,
			"e la vicina risponde col passo interno (%.2f)" % ib.position.x)
	for c2 in dict:
		(dict[c2] as Node).free()


## Un Sentiero posato ruotato (R): il wrapper annulla la rotazione, e la
## pietra del confine resta a est NEL MONDO.
func _test_rotazione_compensata(t) -> void:
	var dict := {}
	for c in [Vector2i(0, 0), Vector2i(1, 0)]:
		var nodo = CAT.items()[1]["builder"].call()
		nodo.set_meta("item_name", "Sentiero")
		nodo.set_meta("rot", 1)
		nodo.rotation.y = -1.0 * PI * 0.5     # come lo ruota place_cell
		dict[c] = nodo
	SYS.rinfresca_sentieri(dict, Vector2i(0, 0))
	var pietre := _pietre_vive(dict[Vector2i(0, 0)]) as Node3D
	t.almost(pietre.rotation.y, PI * 0.5, "il wrapper compensa la rotazione", 0.001)
	# l'ingombro nello spazio del NODO ruotato: la x mondo è la -z locale…
	# più semplice: il punto più a est nel MONDO, passando dalla trasformata
	var est := -99.0
	for mi in _mesh_di(pietre):
		var aabb: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		for k in 8:
			var v := aabb.position + Vector3(aabb.size.x * float(k % 2),
					aabb.size.y * float((k / 2) % 2), aabb.size.z * float(k / 4))
			var mondo: Vector3 = (dict[Vector2i(0, 0)] as Node3D).transform \
					* (_trasformata(mi, dict[Vector2i(0, 0)]) * v)
			est = maxf(est, mondo.x)
	t.ok(est > 0.5, "e la pietra del confine sta a est NEL MONDO (%.2f)" % est)
	for c2 in dict:
		(dict[c2] as Node).free()


# ------------------------------------------------------------------ helper

## Il wrapper VIVO delle pietre (quello vecchio, rinominato e in coda per
## la liberazione, non conta).
func _pietre_vive(nodo: Node) -> Node3D:
	return nodo.get_node_or_null("Pietre") as Node3D


func _mesh_di(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for f in n.get_children():
		out.append_array(_mesh_di(f))
	return out


func _posizioni(n: Node3D) -> Array:
	var out: Array = []
	for mi in _mesh_di(n):
		out.append(_trasformata(mi, n) * Vector3.ZERO)
	return out


func _trasformata(nodo: Node, radice: Node) -> Transform3D:
	var tr := Transform3D.IDENTITY
	var cur := nodo as Node3D
	while cur != null and cur != radice:
		tr = cur.transform * tr
		cur = cur.get_parent() as Node3D
	return tr


func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in _mesh_di(n):
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var mondo := _trasformata(mi, n) * a
		if primo:
			out = mondo
			primo = false
		else:
			out = out.merge(mondo)
	return out
