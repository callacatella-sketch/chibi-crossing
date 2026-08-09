extends SceneTree
## LE SERRE CHE SI FONDONO, NEL MONDO VERO.
##
## I test di `test_serre.gd` provano la logica pura; questo prova il
## CABLAGGIO: che posando la seconda serra col BuildSystem vero, in una
## partita vera, l'edificio si fonda davvero — geometria E collisioni — e
## che togliendone una si richiuda. Poi lo fotografa, perché la suite verde
## non dice niente sulla resa.
##
##   CHIBI_SERRE_VIVE=/dove/salvare Godot --path . \
##       --script res://tools/prova_serre_vive.gd

const CELLE := [Vector2i(10, 10), Vector2i(11, 10), Vector2i(10, 11), Vector2i(11, 11)]

var _build: Node = null
var _cam: Camera3D = null


func _init() -> void:
	_go()


func _trova_build() -> Node:
	for n in get_nodes_in_group("build_system"):
		return n
	return null


func _scatole_di(nodo: Node3D) -> Array:
	var out: Array = []
	for f in nodo.get_children():
		if f is CollisionShape3D and (f as CollisionShape3D).shape is BoxShape3D:
			var sh := (f as CollisionShape3D)
			out.append([(sh.shape as BoxShape3D).size, sh.position, sh.rotation.y])
	return out


func _dentro(p: Vector3, nodo: Node3D) -> bool:
	for sc: Array in _scatole_di(nodo):
		var size: Vector3 = sc[0]
		var giro: float = sc[2]
		var d: Vector3 = Basis(Vector3.UP, -giro) * (p - nodo.global_position - (sc[1] as Vector3))
		if absf(d.x) <= size.x * 0.5 and absf(d.y) <= size.y * 0.5 \
				and absf(d.z) <= size.z * 0.5:
			return true
	return false


func _bloccato(p: Vector3) -> bool:
	var serre: Array = _build.call("get_placed_by_name", "Serra")
	for n in serre:
		if _dentro(p, n as Node3D):
			return true
	return false


func _go() -> void:
	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 12:
		await process_frame
	_build = _trova_build()
	if _build == null:
		push_error("BuildSystem non trovato nel gruppo build_system")
		quit(1)
		return
	# niente scritture su disco: questa e' una prova, non una partita
	_build.set("_persist", false)

	print("--- posa: quattro serre a quadrato, una per volta ---")
	for c: Vector2i in CELLE:
		_build.call("place_cell", c, "Serra", 0, false, 0, "")
	# il rinfresco e' DIFFERITO apposta (una ricostruzione a fine frame, non
	# una per pezzo posato): qui lo si forza, perche' si fotografa subito
	_build.call("aggiorna_serre_ora")
	await process_frame
	await process_frame

	var serre: Array = _build.call("get_placed_by_name", "Serra")
	print("serre piazzate: %d (attese %d)" % [serre.size(), CELLE.size()])
	if serre.size() != CELLE.size():
		print("!! qualche cella era gia' occupata: la prova non vale")
	var con_vetreria := 0
	var scatole_tot := 0
	for n in serre:
		var v := (n as Node3D).find_child("Vetreria", true, false)
		if v != null:
			con_vetreria += 1
		scatole_tot += _scatole_di(n as Node3D).size()
	print("campate ricostruite: %d/%d · scatole di collisione: %d"
			% [con_vetreria, serre.size(), scatole_tot])

	# LE SEDUTE: il giocatore le trova? (get_interactables) e i vicini?
	var sedute := 0
	for it in _build.call("get_interactables"):
		if str(it["name"]) == "Posto":
			var nodo := it["node"] as Node3D
			if nodo.global_position.distance_to(Vector3(10.5, 0.4, 10.5)) < 4.0:
				sedute += 1
	print("posti a sedere che il giocatore puo' usare nella serra: %d" % sedute)

	# SI PASSA FRA LE CAMPATE? il punto di mezzo di ogni confine condiviso
	var passaggi := 0
	var bloccati := 0
	for c: Vector2i in CELLE:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not (c + d) in CELLE:
				continue
			var p := Vector3(float(c.x) + float(d.x) * 0.5, 0.45,
					float(c.y) + float(d.y) * 0.5)
			passaggi += 1
			if _bloccato(p):
				bloccati += 1
				print("  BLOCCATO il confine %s -> %s" % [c, c + d])
	print("confini interni: %d, bloccati: %d (deve essere 0)" % [passaggi, bloccati])

	# IL GUSCIO E' CHIUSO? il muro esterno di ogni campata
	var muri := 0
	var aperti := 0
	for c: Vector2i in CELLE:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			if (c + d) in CELLE:
				continue
			muri += 1
			var p := Vector3(float(c.x) + float(d.x) * 0.95, 0.45,
					float(c.y) + float(d.y) * 0.95)
			if not _bloccato(p):
				aperti += 1
				print("  BUCO nel muro %s di %s" % [d, c])
	print("muri esterni: %d, bucati: %d (deve essere 0)" % [muri, aperti])

	# LA FOTO, nel mondo vero
	var dove := OS.get_environment("CHIBI_SERRE_VIVE")
	if dove == "":
		dove = "docs/catalogo/provini-serre-vive"
	DirAccess.make_dir_recursive_absolute(dove)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.current = true
	root.add_child(_cam)
	var centro := Vector3(10.5, 1.0, 10.5)
	for v in [{"n": "1-di-fronte.jpg", "a": 0.0, "e": 0.55, "d": 8.5},
			{"n": "2-tre-quarti.jpg", "a": 0.9, "e": 0.45, "d": 8.5},
			{"n": "3-dalla-porta.jpg", "a": 0.1, "e": 0.10, "d": 5.0}]:
		var az := float(v["a"])
		var dist := float(v["d"])
		_cam.position = centro + Vector3(sin(az), float(v["e"]), -cos(az)).normalized() * dist
		_cam.look_at(centro, Vector3.UP)
		for _k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_jpg(dove + "/" + str(v["n"]), 0.92)
	print("FOTO -> ", dove)

	# ---- E ORA SI TOGLIE UNA CAMPATA: il guscio deve RICHIUDERSI
	print("--- si toglie la campata %s ---" % CELLE[3])
	_build.call("_remove_at", 2, CELLE[3], 0)
	_build.call("aggiorna_serre_ora")
	await process_frame
	await process_frame
	var rimaste: Array = _build.call("get_placed_by_name", "Serra")
	print("serre rimaste: %d" % rimaste.size())
	var richiuso := false
	for n in rimaste:
		var nn := n as Node3D
		if nn.position.x == float(CELLE[2].x) and nn.position.z == float(CELLE[2].y):
			richiuso = _dentro(Vector3(float(CELLE[2].x) + 0.95, 0.45,
					float(CELLE[2].y)), nn)
	print("il muro tornato dove c'era la vicina: %s (deve essere true)"
			% str(richiuso))
	quit()
