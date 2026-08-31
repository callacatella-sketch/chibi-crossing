extends SceneTree
## Il difetto: i fiori si accucciano sotto un pavimento? Si posa un pezzo
## col BuildSystem VERO nella cella con più fiori, e si guarda l'ALTEZZA
## dei corpi — non un contatore.
func _init() -> void: _go()
func _go() -> void:
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		quit(1); return
	for _i in 40: await process_frame
	var cw := root.find_child("CozyWorld", true, false)
	var bs: Node = null
	for n in get_nodes_in_group("build_system"): bs = n
	if cw == null or bs == null:
		print("!! manca CozyWorld o BuildSystem"); quit(1); return
	bs.set("_persist", false)
	var celle: Dictionary = cw.get("_flower_cells")
	# la cella con più fiori, fra quelle su cui si può costruire
	var scelta := Vector2i.ZERO
	var meglio := 0
	for c in celle:
		var n: int = (celle[c] as Array).size()
		if n > meglio and cw.call("suolo_libero", Vector3(float((c as Vector2i).x), 0, float((c as Vector2i).y)), 0.5):
			meglio = n; scelta = c
	print("cella scelta %s con %d fiori" % [scelta, meglio])
	var alt := func() -> float:
		var mx := -9.0
		for v in (celle[scelta] as Array):
			var campo: MultiMeshInstance3D = (cw.get("_flower_fields") as Array)[int((v as Array)[0])]
			var tf := campo.multimesh.get_instance_transform(int((v as Array)[1]))
			# ⚠️ NON `basis.get_scale().y`: `Basis.scaled()` moltiplica le
			# RIGHE, cioè schiaccia lungo la y del MONDO (che è quello
			# che serve), e su una base inclinata `get_scale()` non lo
			# vede. Quanto in alto arriva l'asse del fiore, invece, sì.
			mx = maxf(mx, absf((tf.basis * Vector3.UP).y))
		return mx
	print("altezza dell'asse PRIMA: %.4f" % alt.call())
	bs.call("place_cell", scelta, "Pavimento", 0, false, 0, "")
	await process_frame
	print("altezza dell'asse DOPO la posa: %.4f (deve essere ~0.02)" % alt.call())
	bs.call("_remove_at", 0, scelta, 0)
	await process_frame
	print("altezza dell'asse DOPO la rimozione: %.4f" % alt.call())
	quit()
