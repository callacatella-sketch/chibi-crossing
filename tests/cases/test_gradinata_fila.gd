extends RefCounted
## LA FILA CONTINUA — le gradinate affiancate perdono il bracciolo sul
## fianco condiviso, e lo riprendono quando la vicina se ne va.
##
## Perche' questi test: il refresh lavora sui meta ("item_name", "rot")
## che place_cell scrive in momenti diversi, e l'asse della fila dipende
## dalla ROTAZIONE del pezzo. Sbagliare il passo di una sola rotazione
## significa braccioli che guardano il vicino sbagliato — e non lo vede
## nessuna suite che provi solo rot=0.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const BS := preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_test_il_pezzo_ha_i_braccioli(t)
	_test_passo_fila(t)
	_test_fila_di_tre(t)
	_test_rotazioni_e_estranei(t)
	_test_cablaggio(t)


## Il pezzo nasce coi DUE braccioli, per nome, accesi, dalla parte
## giusta, e alti abbastanza da essere braccioli (sopra la seduta) senza
## invadere i posti.
func _test_il_pezzo_ha_i_braccioli(t) -> void:
	var n := _gradinata_finta(0)
	for nome in ["BraccioloSx", "BraccioloDx"]:
		var br = n.find_child(str(nome), true, false)
		t.ok(br != null, "la gradinata ha '%s'" % nome)
		if br == null:
			continue
		t.ok(bool(br.visible), "'%s' nasce acceso: da solo il pezzo e' completo" % nome)
		var segno := -1.0 if nome == "BraccioloSx" else 1.0
		var cima := -99.0
		for mi in br.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var a: AABB = (br as Node3D).transform * (m.transform * m.mesh.get_aabb())
			t.ok(a.get_center().x * segno > 0.40,
					"'%s': le mesh stanno sul fianco (%+.3f), non sui posti" %
					[nome, a.get_center().x])
			cima = maxf(cima, a.position.y + a.size.y)
		t.ok(cima > 0.60,
				"'%s' sale sopra la seduta alta (cima %.3f): e' un bracciolo,"
				% [nome, cima] + " non un cordolo")
	n.free()


## Il passo della fila e' l'asse X locale, ruotato come ruota place_cell
## (rotation.y = -rot * PI/2) — e regge anche i giri completi del cursore.
func _test_passo_fila(t) -> void:
	t.eq(BS.passo_fila(0), Vector2i(1, 0), "rot 0: la fila corre lungo +X")
	t.eq(BS.passo_fila(1), Vector2i(0, 1), "rot 1: lungo +Z")
	t.eq(BS.passo_fila(2), Vector2i(-1, 0), "rot 2: lungo -X")
	t.eq(BS.passo_fila(3), Vector2i(0, -1), "rot 3: lungo -Z")
	t.eq(BS.passo_fila(4), BS.passo_fila(0),
			"il cursore che ha fatto un giro intero non cambia la fila")
	t.eq(BS.passo_fila(-1), BS.passo_fila(3),
			"…e nemmeno un giro all'indietro")


## Tre affiancate, piazzate UNA ALLA VOLTA come fa il giocatore: i fianchi
## condivisi si spengono via via, le estremita' restano. Poi via quella di
## mezzo: le superstiti si riprendono il bracciolo.
func _test_fila_di_tre(t) -> void:
	var dict := {}
	var pezzi: Array = []
	for k in 3:
		var g := _gradinata_finta(0)
		pezzi.append(g)
		dict[Vector2i(k, 0)] = g
		BS.rinfresca_braccioli(dict, Vector2i(k, 0))
	t.ok(_acceso(pezzi[0], "BraccioloSx"), "capofila: il bracciolo esterno resta")
	t.ok(not _acceso(pezzi[0], "BraccioloDx"), "capofila: il fianco condiviso si spegne")
	t.ok(not _acceso(pezzi[1], "BraccioloSx") and not _acceso(pezzi[1], "BraccioloDx"),
			"quella in mezzo e' TUTTA seduta: nessun bracciolo")
	t.ok(not _acceso(pezzi[2], "BraccioloSx"), "chiusura: il fianco condiviso si spegne")
	t.ok(_acceso(pezzi[2], "BraccioloDx"), "chiusura: il bracciolo esterno resta")

	# via quella di mezzo: le due superstiti tornano pezzi interi
	dict.erase(Vector2i(1, 0))
	BS.rinfresca_braccioli(dict, Vector2i(1, 0))
	t.ok(_acceso(pezzi[0], "BraccioloDx"),
			"tolta quella in mezzo, la prima si riprende il bracciolo")
	t.ok(_acceso(pezzi[2], "BraccioloSx"), "…e anche l'ultima")
	for g in pezzi:
		(g as Node3D).free()


## La fila segue la ROTAZIONE: due pezzi girati a rot 1 si accordano lungo
## Z. E il fianco NON si spegne per un estraneo: ne' per una gradinata
## girata diversa, ne' per un pezzo qualunque, ne' oltre il bordo della
## fila. (rot 4 e rot 0 sono la stessa direzione: il giro intero conta.)
func _test_rotazioni_e_estranei(t) -> void:
	# fila lungo Z (rot 1)
	var dict := {}
	var a := _gradinata_finta(1)
	var b := _gradinata_finta(1)
	dict[Vector2i(0, 0)] = a
	dict[Vector2i(0, 1)] = b
	BS.rinfresca_braccioli(dict, Vector2i(0, 1))
	t.ok(not _acceso(a, "BraccioloDx") and not _acceso(b, "BraccioloSx"),
			"rot 1: la fila corre lungo Z e i fianchi condivisi si spengono")
	t.ok(_acceso(a, "BraccioloSx") and _acceso(b, "BraccioloDx"),
			"rot 1: le estremita' tengono il bracciolo")
	a.free()
	b.free()

	# una gradinata girata all'incontrario NON continua la fila
	var dict2 := {}
	var c := _gradinata_finta(0)
	var d := _gradinata_finta(2)
	dict2[Vector2i(0, 0)] = c
	dict2[Vector2i(1, 0)] = d
	BS.rinfresca_braccioli(dict2, Vector2i(1, 0))
	t.ok(_acceso(c, "BraccioloDx") and _acceso(d, "BraccioloDx"),
			"rotazioni diverse: ognuna resta un pezzo intero")

	# un pezzo qualunque accanto non e' una fila
	var e := Node3D.new()
	e.set_meta("item_name", "Panchina")
	e.set_meta("rot", 0)
	var dict3 := {Vector2i(0, 0): c, Vector2i(1, 0): e}
	BS.rinfresca_braccioli(dict3, Vector2i(0, 0))
	t.ok(_acceso(c, "BraccioloDx"),
			"una Panchina accanto non spegne il bracciolo")

	# il giro intero del cursore (rot 4) e' la stessa direzione di rot 0
	var f := _gradinata_finta(4)
	var dict4 := {Vector2i(0, 0): c, Vector2i(1, 0): f}
	BS.rinfresca_braccioli(dict4, Vector2i(1, 0))
	t.ok(not _acceso(c, "BraccioloDx") and not _acceso(f, "BraccioloSx"),
			"rot 4 e rot 0 sono la stessa fila: i fianchi condivisi si spengono")
	c.free()
	d.free()
	e.free()
	f.free()


## Senza il cablaggio la logica pura e' lettera morta: place_cell e
## _remove_at DEVONO chiamare il refresh, o i braccioli restano accesi
## per sempre con la suite verde.
func _test_cablaggio(t) -> void:
	var src := _sorgente("res://scenes/build/BuildSystem.gd")
	t.ok(_corpo(src, "place_cell").contains("rinfresca_braccioli("),
			"place_cell rinfresca la fila (o affiancare non fa niente)")
	t.ok(_corpo(src, "_remove_at").contains("rinfresca_braccioli("),
			"_remove_at rinfresca la fila (o il bracciolo non torna mai)")


# ------------------------------------------------------------ attrezzi

## Una gradinata come la lascia place_cell: visual costruito e meta scritti.
func _gradinata_finta(rot: int) -> Node3D:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	var n: Node3D = (per_nome["Gradinata"]["builder"] as Callable).call()
	n.set_meta("item_name", "Gradinata")
	n.set_meta("rot", rot)
	return n


func _acceso(n, nome: String) -> bool:
	var br = (n as Node3D).find_child(nome, true, false)
	return br != null and bool(br.visible)


func _corpo(src: String, fn: String) -> String:
	var i := src.find("func %s(" % fn)
	if i < 0:
		return ""
	var j := src.find("\nfunc ", i)
	return src.substr(i, (j - i) if j > i else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
