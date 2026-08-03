extends RefCounted
## IL RECINTO CONTINUO — i segmenti di staccionata sulla stessa retta
## perdono il palo sul capo condiviso, e lo riprendono quando il vicino
## se ne va.
##
## Perche' questi test: le chiavi dei bordi sono RADDOPPIATE e la retta
## dipende dalla parita' (y dispari = corre lungo X); il verso del pezzo
## include il FLIP (rotazione + PI), e sbagliare la mappa Sx/Dx spegne
## il palo dal lato sbagliato — un recinto coi buchi ai capi e i pali
## doppi in mezzo, l'esatto contrario della richiesta.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const BS := preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_test_il_pezzo_ha_i_pali(t)
	_test_passo_bordo(t)
	_test_fila_di_tre(t)
	_test_flip_e_angoli(t)
	_test_cablaggio(t)


## Il segmento nasce coi DUE pali, per nome, accesi, e ogni palo porta
## con se' le sue legature e la sua erba (spegnerlo non deve lasciare
## anelli di corda a mezz'aria).
func _test_il_pezzo_ha_i_pali(t) -> void:
	var n := _stecca(0.0)
	for nome in ["PaloSx", "PaloDx"]:
		var palo = n.find_child(str(nome), true, false)
		t.ok(palo != null, "la staccionata ha '%s'" % nome)
		if palo == null:
			continue
		t.ok(bool(palo.visible), "'%s' nasce acceso: da solo il pezzo e' completo" % nome)
		var figli: int = palo.find_children("*", "MeshInstance3D", true, false).size()
		t.ok(figli >= 6,
				"'%s' porta con se' collarino, pomello, legature ed erba (%d mesh)"
				% [nome, figli])
	n.free()


## Le chiavi dei bordi sono raddoppiate: y dispari = bordo lungo X
## (passo (2,0)), x dispari = bordo lungo Z (passo (0,2)).
func _test_passo_bordo(t) -> void:
	t.eq(BS.passo_bordo(Vector2i(0, 1)), Vector2i(2, 0),
			"y dispari: il bordo corre lungo X")
	t.eq(BS.passo_bordo(Vector2i(0, -3)), Vector2i(2, 0),
			"…anche con le chiavi negative (posmod, non %)")
	t.eq(BS.passo_bordo(Vector2i(1, 0)), Vector2i(0, 2),
			"x dispari: il bordo corre lungo Z")


## Tre segmenti sulla stessa retta, piazzati UNO ALLA VOLTA: i capi
## condivisi perdono il palo, le estremita' lo tengono. Poi via quello
## di mezzo: i superstiti si riprendono il palo.
func _test_fila_di_tre(t) -> void:
	var dict := {}
	var pezzi: Array = []
	for k in 3:
		var f := _stecca(0.0)
		pezzi.append(f)
		dict[Vector2i(k * 2, 1)] = f
		BS.rinfresca_pali(dict, Vector2i(k * 2, 1))
	t.ok(_acceso(pezzi[0], "PaloSx"), "capofila: il palo esterno resta")
	t.ok(not _acceso(pezzi[0], "PaloDx"), "capofila: il capo condiviso perde il palo")
	t.ok(not _acceso(pezzi[1], "PaloSx") and not _acceso(pezzi[1], "PaloDx"),
			"quello in mezzo e' TUTTO recinto: nessun palo")
	t.ok(not _acceso(pezzi[2], "PaloSx"), "chiusura: il capo condiviso perde il palo")
	t.ok(_acceso(pezzi[2], "PaloDx"), "chiusura: il palo esterno resta")

	dict.erase(Vector2i(2, 1))
	BS.rinfresca_pali(dict, Vector2i(2, 1))
	t.ok(_acceso(pezzi[0], "PaloDx"),
			"tolto quello in mezzo, il primo si riprende il palo")
	t.ok(_acceso(pezzi[2], "PaloSx"), "…e anche l'ultimo")
	for f in pezzi:
		(f as Node3D).free()


## Il FLIP e' dentro il yaw e non deve confondere i lati; e un bordo
## PERPENDICOLARE che tocca il capo non ruba il palo: l'angolo del
## recinto il suo palo lo tiene.
func _test_flip_e_angoli(t) -> void:
	# fila lungo X con quello di mezzo girato di PI (flip)
	var dict := {}
	var a := _stecca(0.0)
	var b := _stecca(PI)
	var c := _stecca(0.0)
	dict[Vector2i(0, 1)] = a
	dict[Vector2i(2, 1)] = b
	dict[Vector2i(4, 1)] = c
	for k in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(4, 1)]:
		BS.rinfresca_pali(dict, k)
	t.ok(not _acceso(b, "PaloSx") and not _acceso(b, "PaloDx"),
			"il segmento flippato in mezzo perde entrambi i pali lo stesso")
	t.ok(_acceso(a, "PaloSx") and _acceso(c, "PaloDx"),
			"e le estremita' tengono il palo esterno")
	a.free()
	b.free()
	c.free()

	# un bordo perpendicolare non continua la retta
	var dict2 := {}
	var d := _stecca(0.0)
	var e := _stecca(PI * 0.5)
	dict2[Vector2i(0, 1)] = d
	dict2[Vector2i(1, 2)] = e
	BS.rinfresca_pali(dict2, Vector2i(1, 2))
	t.ok(_acceso(d, "PaloSx") and _acceso(d, "PaloDx"),
			"l'angolo del recinto tiene tutti e due i pali")
	d.free()
	e.free()


## Senza il cablaggio la logica pura e' lettera morta.
func _test_cablaggio(t) -> void:
	var src := _sorgente("res://scenes/build/BuildSystem.gd")
	t.ok(_corpo(src, "place_edge").contains("rinfresca_pali("),
			"place_edge rinfresca il recinto (o affiancare non fa niente)")
	t.ok(_corpo(src, "_remove_at").contains("rinfresca_pali("),
			"_remove_at rinfresca il recinto (o il palo non torna mai)")


# ------------------------------------------------------------ attrezzi

## Una staccionata come la lascia place_edge: visual, yaw e meta.
func _stecca(yaw: float) -> Node3D:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	var n: Node3D = (per_nome["Staccionata"]["builder"] as Callable).call()
	n.rotation.y = yaw
	n.set_meta("item_name", "Staccionata")
	return n


func _acceso(n, nome: String) -> bool:
	var palo = (n as Node3D).find_child(nome, true, false)
	return palo != null and bool(palo.visible)


func _corpo(src: String, fn: String) -> String:
	var i := src.find("func %s(" % fn)
	if i < 0:
		return ""
	var j := src.find("\nfunc ", i)
	return src.substr(i, (j - i) if j > i else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
