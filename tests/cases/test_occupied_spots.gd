extends RefCounted
## ⚠️ `occupied_spots()` DIMEZZAVA LE COORDINATE DELLE CELLE.
##
## Questo villaggio ha DUE convenzioni di chiave, e il file le tiene separate
## dappertutto tranne qui:
##
##  · i layer **0-3** sono celle in METRI 1:1 — `place_cell` scrive
##    `node.position = Vector3(cell.x, FLOOR_H * lvl, cell.y)`;
##  · i **bordi** hanno la chiave RADDOPPIATA, e `_edge_key_to_transform` è
##    l'unico posto del file che moltiplica per mezzo.
##
## `occupied_spots` applicava quel mezzo a TUTTI i layer. Il suo unico
## lettore è `Woodcutting._semina` («dove c'è un pezzo, non cresce niente»),
## quindi ogni pezzo costruito veniva dichiarato a **metà della propria
## distanza dall'origine**: un albero poteva ricrescere dentro casa, e
## restava un divieto fantasma a mezza strada verso il centro. Più il pezzo
## è lontano, più il divieto è lontano dal pezzo.
##
## ⚠️ E il confronto si scrive `str(layer) == "edge"`: il ciclo tipizza la
## variabile come **int** sul primo elemento, e confrontarla con una String
## è un errore a runtime — che non fa fallire niente, interrompe la funzione.

const BUILD := preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_le_celle_sono_metri(t)
	_i_bordi_restano_dimezzati(t)


func _spots(layer, chiave: Vector2i) -> Array:
	var b = BUILD.new()
	var d: Dictionary = b.get("_placed")
	(d[layer] as Dictionary)[chiave] = Node3D.new()
	var out: Array = b.call("occupied_spots")
	b.free()
	return out


func _le_celle_sono_metri(t) -> void:
	for layer in [0, 1, 2, 3]:
		var out := _spots(layer, Vector2i(10, -8))
		t.eq(out.size(), 1, "layer %s: un pezzo, un divieto" % str(layer))
		if out.is_empty():
			continue
		var p: Vector3 = out[0]
		t.almost(p.x, 10.0,
				"layer %s: la x è quella della CELLA, non la metà" % str(layer),
				0.0001)
		t.almost(p.z, -8.0,
				"layer %s: e la z pure" % str(layer), 0.0001)


## ⚠️ LA CONTROPROVA, e serve: una cura che togliesse il mezzo a tutti
## sposterebbe i divieti dei BORDI al doppio, cioè romperebbe l'altra metà.
func _i_bordi_restano_dimezzati(t) -> void:
	var out := _spots("edge", Vector2i(10, -8))
	t.eq(out.size(), 1, "un bordo, un divieto")
	if out.is_empty():
		return
	var p: Vector3 = out[0]
	t.almost(p.x, 5.0,
			"i BORDI hanno la chiave raddoppiata: il divieto sta a metà chiave",
			0.0001)
	t.almost(p.z, -4.0, "…e la z pure", 0.0001)
