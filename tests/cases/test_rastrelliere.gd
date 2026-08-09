extends RefCounted
## LE RASTRELLIERE IN FILA.
##
## Una rastrelliera accanto a un'altra non sono due mobili: sono una
## scaffalatura più lunga. Questo test guarda le cose che si romperebbero in
## silenzio lasciando la suite verde:
##
##  1. IL MONTANTE CONDIVISO È UNO. Se lo disegnano tutte e due le campate,
##     sul confine c'è due volte lo stesso legno — e da vicino si vede.
##  2. LE TESTATE STANNO SOLO AI CAPI. Il piede a slitta e la croce di
##     controvento in mezzo alla fila sarebbero un mobile che finisce e
##     ricomincia ogni metro: il contrario della fusione.
##  3. LA FILA RISPETTA LA ROTAZIONE. Una rastrelliera girata di traverso
##     non è in fila con te: unirla vorrebbe dire tavole che si incrociano.
##  4. LE TRE VARIANTI SI UNISCONO FRA LORO. Cambia il contenuto, non il
##     mobile: una fila mista dev'essere UNA fila.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const SYS := preload("res://scenes/build/BuildSystem.gd")
const PAL := preload("res://scenes/build/BuildPalestra.gd")


func run(t) -> void:
	_test_le_tre_varianti(t)
	_test_la_fila_si_riconosce(t)
	_test_il_montante_condiviso_e_uno(t)
	_test_le_testate_stanno_ai_capi(t)
	_test_il_contenuto_e_della_cella(t)


## Le tre varianti esistono, si costruiscono, e sono lo STESSO mobile con
## contenuto diverso: il telaio deve pesare uguale.
func _test_le_tre_varianti(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	for nome in PAL.RASTRELLIERE:
		t.ok(per_nome.has(str(nome)), "«%s» è nel catalogo" % nome)
		if not per_nome.has(str(nome)):
			continue
		var n: Node3D = (per_nome[str(nome)]["builder"] as Callable).call()
		t.ok(n != null, "«%s» si costruisce" % nome)
		if n == null:
			continue
		t.ok(n.get_node_or_null("Rastrelliera") != null,
				"«%s» ha il figlio scambiabile: è quello che la fusione"
				% nome + " sostituisce")
		t.ok(n.find_child("posto", true, false) != null,
				"«%s» dice dove ci si mette" % nome)
		n.free()
	# e ognuna dà una variante diversa
	var viste := {}
	for nome in PAL.RASTRELLIERE:
		viste[PAL.variante_rastrelliera(str(nome))] = true
	t.eq(viste.size(), 3, "le tre varianti hanno tre contenuti diversi")


## LA FILA si riconosce lungo l'asse del pezzo, e rispetta la rotazione.
func _test_la_fila_si_riconosce(t) -> void:
	# tre in fila lungo X (rot 0), più una girata: la girata NON entra
	var dict := {}
	for x in 3:
		dict[Vector2i(x, 0)] = _nodo("Rastrelliera", 0)
	dict[Vector2i(3, 0)] = _nodo("Rastrelliera", 1)
	var fila: Array = SYS.fila_rastrelliera(dict, Vector2i(0, 0))
	t.eq(fila.size(), 3, "tre in fila fanno una scaffalatura da tre")
	t.ok(not (Vector2i(3, 0) in fila),
			"…e quella girata di traverso resta fuori: unirla incrocerebbe"
			+ " le tavole")
	# l'ordine è da sinistra a destra: serve a sapere chi ha la testata
	t.eq(str(fila[0]), str(Vector2i(0, 0)), "la fila è in ordine")
	t.eq(str(fila[2]), str(Vector2i(2, 0)), "…fino in fondo")
	_libera(dict)

	# LE VARIANTI SI UNISCONO FRA LORO
	var misto := {}
	misto[Vector2i(0, 0)] = _nodo("Rastrelliera", 0)
	misto[Vector2i(1, 0)] = _nodo("Rastrelliera dischi", 0)
	misto[Vector2i(2, 0)] = _nodo("Rastrelliera pietre", 0)
	t.eq(SYS.fila_rastrelliera(misto, Vector2i(1, 0)).size(), 3,
			"le tre varianti sono lo stesso mobile: la fila mista è UNA fila")
	_libera(misto)

	# ruotata di 90°, la fila corre lungo Z
	var girate := {}
	for z in 2:
		girate[Vector2i(0, z)] = _nodo("Rastrelliera", 1)
	t.eq(SYS.fila_rastrelliera(girate, Vector2i(0, 0)).size(), 2,
			"girato di un quarto, il mobile si allunga lungo Z")
	_libera(girate)


## IL MONTANTE CONDIVISO È UNO SOLO. Si contano i montanti veri (i pali
## verticali alti) di una fila e si pretende che nessuno stia sopra un
## altro: sul confine ce n'è UNO, non due.
func _test_il_montante_condiviso_e_uno(t) -> void:
	var punti := _montanti([["manubri", false, true], ["dischi", true, true],
			["pietre", true, false]])
	var doppi := 0
	for i in punti.size():
		for j in range(i + 1, punti.size()):
			if (punti[i] as Vector3).distance_to(punti[j] as Vector3) < 0.02:
				doppi += 1
	t.eq(doppi, 0, "nessun montante disegnato due volte (%d montanti)" % punti.size())
	# e ce ne sono esattamente quattro coppie: due testate più due confini
	var per_x := {}
	for p: Vector3 in punti:
		per_x[snappedf(p.x, 0.01)] = true
	t.eq(per_x.size(), 4,
			"una fila da tre ha quattro cavalletti, non sei (%d)" % per_x.size())


## LE TESTATE STANNO SOLO AI CAPI. Il piede a slitta è il segno della
## testata: in mezzo alla fila non ce ne devono essere.
func _test_le_testate_stanno_ai_capi(t) -> void:
	var piedi := 0
	var forme := [["manubri", false, true], ["dischi", true, true],
			["pietre", true, false]]
	for i in forme.size():
		var f: Array = forme[i]
		var r: Node3D = PAL.rastrelliera_cella({"sx": f[1], "dx": f[2]},
				str(f[0]), 7 + i * 13)
		for mi in r.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh is not BoxMesh:
				continue
			var bm := m.mesh as BoxMesh
			# il pattino: basso, largo in Z e appoggiato a terra
			if bm.size.y < 0.06 and bm.size.z > 0.5 and _quota(m, r) < 0.06:
				piedi += 1
		r.free()
	t.eq(piedi, 2, "una fila da tre ha DUE piedi a slitta, ai capi (%d)" % piedi)


## IL CONTENUTO È DELLA CELLA. Allungare la fila non deve rimescolare
## quello che c'è sulle campate già posate: il dado è della cella.
func _test_il_contenuto_e_della_cella(t) -> void:
	var a: Node3D = PAL.rastrelliera_cella({"sx": true, "dx": false}, "manubri", 99)
	var b: Node3D = PAL.rastrelliera_cella({"sx": true, "dx": false}, "manubri", 99)
	t.eq(_impronta(a), _impronta(b),
			"lo stesso seme dà la stessa campata, sempre")
	a.free()
	b.free()
	var c: Node3D = PAL.rastrelliera_cella({"sx": true, "dx": false}, "manubri", 100)
	var d: Node3D = PAL.rastrelliera_cella({"sx": true, "dx": false}, "manubri", 99)
	t.ok(_impronta(c) != _impronta(d),
			"…e semi diversi danno campate diverse: una fila lunga non è la"
			+ " stessa cosa ripetuta")
	c.free()
	d.free()


# ------------------------------------------------------------- gli attrezzi

func _nodo(nome: String, rot: int) -> Node3D:
	var n := Node3D.new()
	n.set_meta("item_name", nome)
	n.set_meta("rot", rot)
	return n


func _libera(dict: Dictionary) -> void:
	for c in dict:
		(dict[c] as Node3D).free()


## I montanti veri di una fila, in coordinate mondo.
func _montanti(forme: Array) -> Array:
	var out: Array = []
	for i in forme.size():
		var f: Array = forme[i]
		var r: Node3D = PAL.rastrelliera_cella({"sx": f[1], "dx": f[2]},
				str(f[0]), 7 + i * 13)
		for mi in r.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh is not BoxMesh:
				continue
			var bm := m.mesh as BoxMesh
			if bm.size.y < 0.6 or bm.size.x > 0.12 or bm.size.z > 0.12:
				continue
			# le CROCI di controvento sono alte e sottili come i montanti,
			# ma stanno inclinate — e due bracci che si incrociano hanno per
			# forza lo stesso centro: contarle come doppioni sarebbe
			# accusare la carpenteria di un difetto che non ha
			var su: Vector3 = _trasformata(m, r).basis.y.normalized()
			if su.dot(Vector3.UP) < 0.99:
				continue
			out.append(_posa(m, r) + Vector3(float(i), 0, 0))
		r.free()
	return out


func _trasformata(nodo: Node3D, radice: Node3D) -> Transform3D:
	var tr := Transform3D.IDENTITY
	var cur := nodo
	while cur != null and cur != radice:
		tr = cur.transform * tr
		cur = cur.get_parent() as Node3D
	return tr


func _posa(nodo: Node3D, radice: Node3D) -> Vector3:
	return _trasformata(nodo, radice).origin


func _quota(nodo: Node3D, radice: Node3D) -> float:
	return _posa(nodo, radice).y


func _impronta(n: Node3D) -> String:
	var righe: Array = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var p := _posa(m, n)
		righe.append("%s|%.3f,%.3f,%.3f" % [m.mesh.get_class(), p.x, p.y, p.z])
	righe.sort()
	return "\n".join(righe)
