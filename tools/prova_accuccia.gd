extends SceneTree
## I FIORI SI ACCUCCIANO SOTTO UN PAVIMENTO? Nel MainLevel VERO, col
## BuildSystem vero, guardando l'ALTEZZA DEI CORPI — non un contatore.
##
##   Godot --path . --resolution 640x400 \
##       --script res://tools/prova_accuccia.gd
##
## Due scene, e la seconda è quella che il difetto vero aveva:
##  1. si posa un pezzo a mondo GIÀ COSTRUITO (il caso facile);
##  2. si posa, si RICARICA la scena, e si guarda PRIMA di toccare
##     niente — perché `BuildSystem._load_village` piazza tutte le celle
##     salvate dentro il frame 0, senza un `await`, mentre l'indice dei
##     fiori nasce in fondo a un `_ready` che ne attraversa sette. Al
##     caricamento `flatten_cell` trovava l'indice VUOTO, non accucciava
##     niente, e timbrava comunque `_grass_flat`: per via del `return`
##     in testa non ci sarebbe tornata MAI più.
##
## ⚠️ NON GIRA IN `--headless`, e si rifiuta invece di mentire:
## `MultiMesh.get_instance_transform()` torna l'IDENTITÀ col renderer
## fittizio, quindi un banco headless stamperebbe tre volte lo stesso
## numero ed uscirebbe 0 su un gioco rotto.
##
## ⚠️ E L'ORACOLO È INDIPENDENTE: la cella da colpire e i fiori da
## guardare si ricavano da `_flower_base` — le trasformate VERE tenute
## in GDScript — ricalcolando la cella NEL BANCO. Chiedere tutte e due
## le cose a `_flower_cells` vuol dire chiedere al giudice se è
## d'accordo con sé stesso: con `roundi` mutato in `floori` il banco
## resterebbe verde mentre nel mondo si accuccia un'altra cella.

var _rossi := 0
## I byte del salvataggio dell'autore, messi al riparo prima della
## scena 2 e rimessi dov'erano qualunque cosa succeda.
## ⚠️ Un altro banco di questo progetto si è già portato via dei dati
## veri: qui si tocca `user://village.json` perché il difetto da provare
## vive nel CARICAMENTO, e non c'è altro modo di provarlo.
var _salvataggio: PackedByteArray = PackedByteArray()
var _cera_salvataggio := false


func _init() -> void:
	_go()


func _dice(ok: bool, testo: String) -> void:
	if not ok:
		_rossi += 1
	print(("  ok   " if ok else "  ROSSO ") + testo)


## La cella (x, z) di una trasformata, ricalcolata QUI.
func _cella_di(tf: Transform3D) -> Vector2i:
	return Vector2i(roundi(tf.origin.x), roundi(tf.origin.z))


## L'altezza a cui arriva l'asse di un fiore, in metri di mondo.
## ⚠️ NON `basis.get_scale().y`: `Basis.scaled()` moltiplica le RIGHE,
## cioè schiaccia lungo la y del MONDO — e su una base inclinata
## `get_scale()` non lo vede.
func _altezza(tf: Transform3D) -> float:
	return absf((tf.basis * Vector3.UP).y)


## Le altezze VERE, lette dal MultiMesh, dei fiori che secondo
## `_flower_base` stanno in quella cella.
func _altezze(cw: Node, cella: Vector2i) -> Array:
	var out: Array = []
	var basi: Array = cw.get("_flower_base")
	var campi: Array = cw.get("_flower_fields")
	for c in basi.size():
		var tfs: Array = basi[c]
		for i in tfs.size():
			var tf: Transform3D = tfs[i]
			if absf(tf.origin.y) > 0.5 or _cella_di(tf) != cella:
				continue
			out.append(_altezza((campi[c] as MultiMeshInstance3D)
					.multimesh.get_instance_transform(i)))
	return out


## La cella con più fiori fra quelle su cui si può DAVVERO costruire.
func _cella_grassa(cw: Node, bs: Node) -> Vector2i:
	var conta := {}
	var basi: Array = cw.get("_flower_base")
	for c in basi.size():
		for tf: Transform3D in (basi[c] as Array):
			if absf(tf.origin.y) > 0.5:
				continue
			var k := _cella_di(tf)
			conta[k] = int(conta.get(k, 0)) + 1
	var scelta := Vector2i.ZERO
	var meglio := 0
	var occupate: Dictionary = (bs.get("_placed") as Array)[0]
	for k in conta:
		if int(conta[k]) <= meglio:
			continue
		if occupate.has(k):
			continue  # `place_cell` esce subito se la cella è già presa
		if not cw.call("suolo_libero", Vector3(float((k as Vector2i).x), 0.0,
				float((k as Vector2i).y)), 0.4):
			continue
		meglio = int(conta[k])
		scelta = k
	return scelta


func _metti_al_riparo(bs: Node) -> void:
	var via := str(bs.get("save_path"))
	_cera_salvataggio = FileAccess.file_exists(via)
	if _cera_salvataggio:
		_salvataggio = FileAccess.get_file_as_bytes(via)
	print("salvataggio dell'autore: %s (%d byte)"
			% ["messo al riparo" if _cera_salvataggio else "non c'era",
					_salvataggio.size()])


func _rimetti(bs: Node) -> void:
	var via := str(bs.get("save_path"))
	if _cera_salvataggio:
		var f := FileAccess.open(via, FileAccess.WRITE)
		if f:
			f.store_buffer(_salvataggio)
			f.close()
	elif FileAccess.file_exists(via):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(via))
	print("salvataggio dell'autore: rimesso dov'era")


func _trova(nome: String) -> Node:
	for n in get_nodes_in_group(nome):
		return n
	return null


func _apri() -> Array:
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		return []
	for _i in 60:
		await process_frame
	return [root.find_child("CozyWorld", true, false), _trova("build_system")]


func _go() -> void:
	if DisplayServer.get_name() == "headless":
		print("!! questo banco NON gira in --headless: "
				+ "`MultiMesh.get_instance_transform()` torna l'identità e "
				+ "il banco misurerebbe tre volte lo stesso numero. "
				+ "Rilancialo con --resolution 640x400.")
		quit(1)
		return

	# ---------------- SCENA 1: si posa a mondo già costruito
	var nodi: Array = await _apri()
	if nodi.is_empty() or nodi[0] == null or nodi[1] == null:
		print("!! manca CozyWorld o BuildSystem")
		quit(1)
		return
	var cw: Node = nodi[0]
	var bs: Node = nodi[1]
	bs.set("_persist", false)
	var cella := _cella_grassa(cw, bs)
	var prima := _altezze(cw, cella)
	print("--- scena 1: si posa a mondo costruito ---")
	print("cella %s · %d fiori" % [cella, prima.size()])
	_dice(prima.size() >= 3, "la cella scelta ha almeno tre fiori")
	_dice(prima.max() > 0.5, "in piedi PRIMA (%.4f)" % prima.max())
	bs.call("place_cell", cella, "Pavimento", 0, false, 0, "")
	await process_frame
	var dopo := _altezze(cw, cella)
	_dice(dopo.max() < 0.10, "accucciati DOPO la posa (%.4f)" % dopo.max())
	bs.call("_remove_at", 0, cella, 0)
	await process_frame
	var poi := _altezze(cw, cella)
	_dice(poi.max() > 0.5, "in piedi dopo la RIMOZIONE (%.4f)" % poi.max())

	# ---------------- SCENA 2: si salva, si RICARICA, e si guarda
	# È il caso che il difetto vero aveva: ogni partita riaperta.
	print("--- scena 2: si posa, si salva, si RICARICA ---")
	_metti_al_riparo(bs)
	bs.set("_persist", true)
	bs.call("place_cell", cella, "Pavimento", 0, false, 0, "")
	bs.call("save_now")
	await process_frame
	var nodi2: Array = await _apri()
	if nodi2.is_empty() or nodi2[0] == null:
		print("!! il MainLevel non si riapre")
		quit(1)
		return
	var cw2: Node = nodi2[0]
	var bs2: Node = nodi2[1]
	var ric := _altezze(cw2, cella)
	print("cella %s · %d fiori dopo il ricaricamento" % [cella, ric.size()])
	_dice(ric.size() >= 3, "i fiori di quella cella ci sono ancora")
	_dice(ric.max() < 0.10,
			"ACCUCCIATI su una partita CARICATA (%.4f) — è il difetto vero"
			% ric.max())
	# e si rimette il salvataggio dell'autore esattamente com'era
	bs2.set("_persist", false)
	_rimetti(bs2)

	print("==== ACCUCCIAMENTO: %s ====" % ("tutto ok" if _rossi == 0
			else "%d ROSSI" % _rossi))
	quit(1 if _rossi > 0 else 0)
