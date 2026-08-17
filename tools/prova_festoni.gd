extends SceneTree
## I FESTONI, NEL MONDO VERO.
##
## `test_festoni.gd` prova la grammatica su un dizionario finto; questo
## prova il CABLAGGIO: che piantando i pali col BuildSystem vero, in una
## partita vera, i fili si tendano davvero — e poi lo fotografa, perché
## la suite verde non dice niente sulla resa.
##
## Conta anche le campate, che è l'unica misura che dice se la
## grammatica ha fatto quello che il giocatore si aspetta: una fila di
## quattro pali fa TRE fili (una collana), non sei (un ventaglio).
##
##   CHIBI_FESTONI=/dove Godot --path . \
##       --script res://tools/prova_festoni.gd
##
## CHIBI_ORA=notte per fotografarli accesi.

const CAT = preload("res://scenes/build/BuildCatalog.gd")

## I disegni che si provano. Sono i gesti che farebbe un giocatore:
## una collana dritta, un angolo, un quadrato attorno a una piazzetta,
## una stella, e una griglia (l'intreccio vero, con le diagonali).
const DISEGNI := [
	{"nome": "fila", "attese": 3, "pali": "Palo lucine",
		"celle": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(6, 0)]},
	{"nome": "quadrato", "attese": 4, "pali": "Palo lanterne",
		"celle": [Vector2i(0, 0), Vector2i(3, 0), Vector2i(3, 3),
				Vector2i(0, 3), Vector2i(0, 0)]},
	# l'ipotenusa di questo triangolo misura 4.24 m: il filo non ci
	# arriva, e restano i due cateti. È la regola dei quattro metri.
	{"nome": "triangolo", "attese": 2, "pali": "Palo bandierine",
		"celle": [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3)]},
	{"nome": "intreccio", "attese": -1, "pali": "Palo lucine",
		"celle": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0),
				Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2),
				Vector2i(0, 4), Vector2i(2, 4), Vector2i(4, 4)]},
]
const NOTTE := 0.97

var _build: Node = null
var _cam: Camera3D = null


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


## Quante campate esistono davvero: si contano le corde vive nate sotto
## i pali, non i nodi «Festoni» (che c'è sempre, anche vuoto).
func _campate(nodi: Array) -> int:
	var q := 0
	for p in nodi:
		var casa := (p as Node3D).find_child("Festoni", false, false)
		if casa == null:
			continue
		for f in casa.get_children():
			if f.find_child("CordaViva", true, false) != null:
				q += 1
	return q


func _scatta(centro: Vector3, dist: float, dove: String) -> void:
	_cam.position = centro + Vector3(0.75, 0.62, 0.75).normalized() * dist
	_cam.look_at(centro, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(dove, 0.92)


func _go() -> void:
	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 20:
		await process_frame
	_build = _trova("build_system")
	var dn := _trova("daynight")
	if _build == null:
		push_error("BuildSystem non trovato")
		quit(1)
		return
	_build.set("_persist", false)
	var notte := OS.get_environment("CHIBI_ORA") == "notte"
	if dn != null and notte:
		dn.call("set_time", NOTTE)

	var dove := OS.get_environment("CHIBI_FESTONI")
	if dove == "":
		dove = "docs/catalogo/provini-festoni"
	DirAccess.make_dir_recursive_absolute(dove)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam.current = true
	root.add_child(_cam)

	var guasti := 0
	var origine := Vector2i(8, 8)
	for d in DISEGNI:
		var celle: Array = []
		for c: Vector2i in d["celle"]:
			var v: Vector2i = origine + c
			if not v in celle:
				celle.append(v)
		for v: Vector2i in celle:
			_build.call("place_cell", v, str(d["pali"]), 0, false, 0, "")
		# il rinfresco è DIFFERITO apposta (una ricostruzione a fine
		# frame, non una per palo piantato): qui si fotografa subito
		_build.call("aggiorna_festoni_ora")
		for _i in 3:
			await process_frame
		var nodi: Array = _build.call("get_placed_by_name", str(d["pali"]))
		var q := _campate(nodi)
		var atteso := int(d["attese"])
		var esito := "ok" if (atteso < 0 or q == atteso) else "!! ATTESE %d" % atteso
		if atteso >= 0 and q != atteso:
			guasti += 1
		print("%-11s pali %2d · campate %2d   %s" % [str(d["nome"]),
				celle.size(), q, esito])

		var mx := 0.0
		var mz := 0.0
		for v: Vector2i in celle:
			mx += float(v.x)
			mz += float(v.y)
		var centro := Vector3(mx / float(celle.size()), 1.0,
				mz / float(celle.size()))
		if dn != null and notte:
			dn.call("set_time", NOTTE)
		await _scatta(centro, 9.5, dove.rstrip("/") + "/" + str(d["nome"]) + ".jpg")

		# si smonta tutto prima del disegno dopo: due disegni sovrapposti
		# non dicono niente su nessuno dei due
		for v: Vector2i in celle:
			_build.call("_remove_at", 2, v, 0)
		_build.call("aggiorna_festoni_ora")
		for _i in 3:
			await process_frame
		var rimasti: Array = _build.call("get_placed_by_name", str(d["pali"]))
		if _campate(rimasti) != 0:
			print("  !! restano campate dopo lo smontaggio")
			guasti += 1

	print("FESTONI -> ", dove, "   guasti: ", guasti)
	quit(1 if guasti > 0 else 0)
