extends SceneTree
## LE RASTRELLIERE IN FILA, NEL MONDO VERO. I test provano la logica; questo
## prova il CABLAGGIO: che posando la seconda col BuildSystem vero la fila si
## fonda davvero — e che togliendo quella di mezzo le due tronche si
## richiudano con la loro testata.
##
##   CHIBI_RAST_VIVE=/dove/salvare Godot --path . \
##       --script res://tools/prova_rastrelliere_vive.gd

const CELLE := [Vector2i(10, 14), Vector2i(11, 14), Vector2i(12, 14)]
const NOMI := ["Rastrelliera", "Rastrelliera dischi", "Rastrelliera pietre"]

var _build: Node = null


func _init() -> void:
	_go()


## Il piede a slitta è il segno della TESTATA: basso, largo in Z, a terra.
func _piedi(nodo: Node3D) -> int:
	var q := 0
	for mi in nodo.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh is not BoxMesh:
			continue
		var bm := m.mesh as BoxMesh
		if bm.size.y < 0.06 and bm.size.z > 0.5 and m.global_position.y < 0.08:
			q += 1
	return q


func _go() -> void:
	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		quit(1)
		return
	for _i in 12:
		await process_frame
	for n in get_nodes_in_group("build_system"):
		_build = n
		break
	if _build == null:
		push_error("BuildSystem non trovato")
		quit(1)
		return
	_build.set("_persist", false)
	print("--- posa: tre rastrelliere in fila, tre varianti diverse ---")
	for i in CELLE.size():
		_build.call("place_cell", CELLE[i], NOMI[i], 0, false, 0, "")
	_build.call("aggiorna_serre_ora")
	await process_frame
	await process_frame

	var tot := 0
	var piedi_tot := 0
	var per_cella: Array = []
	for nome in NOMI:
		for n in _build.call("get_placed_by_name", nome):
			var nn := n as Node3D
			if Vector2i(roundi(nn.position.x), roundi(nn.position.z)) in CELLE:
				tot += 1
				var p := _piedi(nn)
				piedi_tot += p
				per_cella.append("%d,%d:%d piedi" % [roundi(nn.position.x),
						roundi(nn.position.z), p])
	print("campate in fila: %d · piedi a slitta TOTALI: %d (attesi 2)"
			% [tot, piedi_tot])
	print("  " + " · ".join(per_cella))

	# LA FOTO
	var dove := OS.get_environment("CHIBI_RAST_VIVE")
	if dove == "":
		dove = "docs/catalogo/provini-rastrelliere-vive"
	DirAccess.make_dir_recursive_absolute(dove)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.current = true
	root.add_child(cam)
	var centro := Vector3(11.0, 0.5, 14.0)
	cam.position = centro + Vector3(1.6, 1.5, -3.4)
	cam.look_at(centro, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(dove + "/fila.jpg", 0.92)
	print("FOTO -> ", dove)

	# ---- TOLTA QUELLA DI MEZZO: le due tronche devono richiudersi
	print("--- si toglie la campata di mezzo ---")
	_build.call("_remove_at", 2, CELLE[1], 0)
	_build.call("aggiorna_serre_ora")
	await process_frame
	await process_frame
	var piedi2 := 0
	for nome in NOMI:
		for n in _build.call("get_placed_by_name", nome):
			var nn := n as Node3D
			if Vector2i(roundi(nn.position.x), roundi(nn.position.z)) in CELLE:
				piedi2 += _piedi(nn)
	print("piedi a slitta dopo: %d (attesi 4: due mobili, due testate l'uno)"
			% piedi2)
	quit()
