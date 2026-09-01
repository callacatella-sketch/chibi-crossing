extends SceneTree
## IL PRATO NEL MONDO VERO: fiori e farfalle dentro il MainLevel, con la
## luce vera, il vento vero e la camera del gioco.
##
##   CHIBI_PRATO=/dove/salvare Godot --path . --resolution 1280x720 \
##       --script res://tools/prova_prato_vivo.gd
##
## Quattro parti (CHIBI_PARTI=DVFC):
##  D — le DISTANZE: 0.9 m (Mochi che cammina), 2.7 m (la camera VERA del
##      gioco: 2.70 sopra e 3.70 dietro), 8 m, 16 m;
##  V — la PELLICOLA DEL VENTO: sei fotogrammi a intervalli fissi con
##      `vento_forza` a 1.0 e a 1.775 (l'acquazzone). È l'unica lastra
##      che dice se la folata arriva ai fiori — e se la TESTA arriva in
##      ritardo sullo stelo, che è tutto il peso del fiore;
##  F — le FARFALLE vere del prato, quelle nominate, da vicino;
##  C — il CONTO: quanti fiori, quanti triangoli, quante draw call;
##  P — il PREZZO del fotogramma, A/B nella stessa corsa.
##
## ⚠️ IL BANCO EREDITA IL SALVATAGGIO: senza fissare giorno, ora e
## stagione si fotografa un mondo in inverno di sera e si giudica la neve
## credendola il prato. (Trappola già pagata da `provino_terreno`.)

var _cam: Camera3D
var _dove := ""


func _init() -> void:
	_go()


func _scatta(nome: String, pos: Vector3, mira: Vector3) -> void:
	_cam.position = pos
	_cam.look_at(mira, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(_dove + "/" + nome, 0.93)


func _conta_mesh(n: Node, acc: Dictionary) -> void:
	if n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null:
			var t := 0
			for si in mm.mesh.get_surface_count():
				var arr := mm.mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				t += (idx.size() / 3) if idx.size() > 0 else (vtx.size() / 3)
			acc["mm"] = int(acc.get("mm", 0)) + 1
			acc["ist"] = int(acc.get("ist", 0)) + mm.instance_count
			acc["tri"] = int(acc.get("tri", 0)) + t * mm.instance_count
			acc["sup"] = int(acc.get("sup", 0)) + mm.mesh.get_surface_count()
	for f in n.get_children():
		_conta_mesh(f, acc)


## Il nodo dell'ecosistema (fiori selvatici e farfalle del MultiMesh):
## è un figlio runtime di CozyWorld, non sta in `_flower_fields`.
func _ecosistema(cw: Node) -> Node:
	if cw == null:
		return null
	for f in cw.get_children():
		if (f as Node).get_script() != null \
				and str((f as Node).get_script().resource_path).ends_with(
						"Ecosystem.gd"):
			return f
	return null


func _go() -> void:
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 24:
		await process_frame
	var dn := root.find_child("DayNight", true, false)
	if dn:
		dn.set("day", 12)
		dn.set("time", 0.40)
		# l'orologio si FERMA: un giorno dura quattro minuti, il banco di
		# più, e a metà prova si fotograferebbe il tramonto
		dn.set("cycle_seconds", 100000.0)
	var cw := root.find_child("CozyWorld", true, false)
	var stag := int(OS.get_environment("CHIBI_STAG"))
	if cw and cw.has_method("set_season"):
		cw.call("set_season", stag, 0.85 if stag == 3 else 0.0, false)
	for _i in 40:
		await process_frame

	_dove = OS.get_environment("CHIBI_PRATO")
	if _dove == "":
		_dove = "/tmp/prato"
	DirAccess.make_dir_recursive_absolute(_dove)
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "DVFC"
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.current = true
	root.add_child(_cam)

	# --- C: il CONTO
	if "C" in parti:
		var acc := {}
		if cw:
			for f in (cw.get("_flower_fields") as Array):
				_conta_mesh(f as Node, acc)
		# ⚠️ E L'ECOSISTEMA, che è l'altra metà del lavoro: i 380 fiori
		# selvatici sono passati da 16 a ~250 triangoli l'uno e le 90
		# farfalle da 4 a 232. Vivono sotto un nodo LORO, fuori da
		# `_flower_fields`: contare solo lì dentro dà il prezzo del
		# PRATO, non il prezzo del lavoro.
		var eco := _ecosistema(cw)
		var acc2 := {}
		if eco:
			_conta_mesh(eco, acc2)
			print("ECOSISTEMA: %d MultiMesh · %d istanze · %d triangoli"
					% [int(acc2.get("mm", 0)), int(acc2.get("ist", 0)),
							int(acc2.get("tri", 0))])
		print("CAMPI DI FIORI: %d MultiMesh · %d istanze · %d triangoli"
				% [int(acc.get("mm", 0)), int(acc.get("ist", 0)),
						int(acc.get("tri", 0))])
		print("   superfici per mesh: %.2f (1.00 = una draw call per campo)"
				% (float(acc.get("sup", 0)) / maxf(float(acc.get("mm", 1)), 1.0)))
		if cw:
			print("FARFALLE nominate: %d"
					% (cw.get("_butterflies") as Array).size())

	# --- D: le DISTANZE, e la seconda è la camera VERA del gioco
	if "D" in parti:
		var c := Vector3(2.0, 0.12, 3.0)
		for v in [["1-vicino-90cm.jpg", Vector3(2.0, 0.42, 3.85), 0.9],
				["2-camera-del-gioco.jpg", Vector3(2.0, 2.82, 6.70), 2.7],
				["3-otto-metri.jpg", Vector3(2.0, 3.20, 10.6), 8.0],
				["4-sedici-metri.jpg", Vector3(2.0, 5.0, 18.5), 16.0]]:
			await _scatta(str(v[0]), v[1] as Vector3, c)

	# --- V: la PELLICOLA DEL VENTO
	if "V" in parti:
		var we := root.find_child("Weather", true, false)
		if we:
			# Weather riscrive `vento_forza` a ogni frame: per forzarlo
			# bisogna spegnerle il passo, non solo scrivere il globale
			we.set_process(false)
		for forza: float in [1.0, 1.775]:
			RenderingServer.global_shader_parameter_set("vento_forza", forza)
			var tag := "brezza" if forza < 1.2 else "acquazzone"
			for k in 6:
				# riquadro FERMO sul mondo: il vento si giudica su una
				# pellicola, non in una posa
				await _scatta("5-vento-%s-%d.jpg" % [tag, k],
						Vector3(2.0, 0.40, 3.75), Vector3(2.0, 0.14, 3.0))
				for _w in 9:
					await process_frame
		if we:
			we.set_process(true)

	# --- F: le FARFALLE vere
	if "F" in parti and cw:
		var bs: Array = cw.get("_butterflies")
		for i in mini(bs.size(), 3):
			var b: Dictionary = bs[i]
			var n := b["node"] as Node3D
			n.position = Vector3(2.0, 0.85, 3.0)
			await _scatta("6-farfalla-%d-%s.jpg" % [i, str(b["kind"])],
					Vector3(2.0, 0.95, 3.55), Vector3(2.0, 0.85, 3.0))
	# --- P: IL FOTOGRAMMA, A/B nella STESSA corsa
	# ⚠️ Due processi diversi non sono confrontabili (compilazione degli
	# shader, cache, e soprattutto le altre sessioni di agente). Si
	# alternano finestre con i campi accesi e spenti, e si contano i
	# fotogrammi a orologio.
	if "P" in parti:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_cam.position = Vector3(2.0, 2.82, 6.70)
		_cam.look_at(Vector3(2.0, 0.12, 3.0), Vector3.UP)
		var sec := 5.0
		if OS.get_environment("CHIBI_FPS_SEC") != "":
			sec = float(OS.get_environment("CHIBI_FPS_SEC"))
		var giri := 3
		if OS.get_environment("CHIBI_FPS_GIRI") != "":
			giri = int(OS.get_environment("CHIBI_FPS_GIRI"))
		var eco2 := _ecosistema(cw)
		# TRE stati, non due: «tutto», «senza il prato», «senza niente».
		# ⚠️ Con due soli stati non si sa DOVE va il costo — e il nodo
		# dell'ecosistema porta anche le lucciole, che questo lavoro non
		# ha toccato: spegnerlo tutto insieme al prato attribuisce al
		# lavoro anche quello che non è suo.
		var somma := {"tutto": 0.0, "senza_prato": 0.0, "niente": 0.0}
		var conta := {"tutto": 0, "senza_prato": 0, "niente": 0}
		# ⚠️ L'ORDINE SI ROVESCIA A OGNI GIRO. Con tre stati sempre nella
		# stessa sequenza, qualunque DERIVA della macchina — un'altra
		# sessione che parte, il termico, la cache che si scalda — si
		# alias sullo stato, e si legge come costo. Alternando
		# A-B-C / C-B-A la deriva lineare si cancella.
		var ordini: Array = [["tutto", "senza_prato", "niente"],
				["niente", "senza_prato", "tutto"]]
		for g in giri:
			for stato: String in ordini[g % 2]:
				var prato := stato == "tutto"
				var eco_on := stato != "niente"
				if cw:
					for f in (cw.get("_flower_fields") as Array):
						(f as Node3D).visible = prato
				if eco2:
					(eco2 as Node3D).visible = eco_on
				# la prima mezza finestra si butta: è quella in cui il
				# renderer si riassesta dopo il cambio
				var t0 := Time.get_ticks_usec()
				while float(Time.get_ticks_usec() - t0) < sec * 250000.0:
					await process_frame
				t0 = Time.get_ticks_usec()
				var n := 0
				while float(Time.get_ticks_usec() - t0) < sec * 1000000.0:
					await process_frame
					n += 1
				var dt := float(Time.get_ticks_usec() - t0) / 1000000.0
				somma[stato] = float(somma[stato]) + dt
				conta[stato] = int(conta[stato]) + n
		if cw:
			for f in (cw.get("_flower_fields") as Array):
				(f as Node3D).visible = true
		if eco2:
			(eco2 as Node3D).visible = true
		var ms := func(k: String) -> float:
			return float(somma[k]) * 1000.0 / maxf(float(conta[k]), 1.0)
		print("   (carico della macchina: %s — se il divario fra gli stati "
				% str(OS.get_static_memory_usage() > 0)
				+ "è dell'ordine del rumore, la misura non è pronta)")
		print("FOTOGRAMMA (A/B nella stessa corsa, %d giri da %.0f s)"
				% [giri, sec])
		for k: String in ["tutto", "senza_prato", "niente"]:
			print("   %-12s %.2f ms (%.1f fps, %d fotogrammi)"
					% [k, ms.call(k), 1000.0 / ms.call(k), int(conta[k])])
		print("   il PRATO costa      %+.2f ms (%+.1f%%)"
				% [ms.call("tutto") - ms.call("senza_prato"),
						(ms.call("tutto") / ms.call("senza_prato") - 1.0) * 100.0])
		print("   l'ECOSISTEMA costa  %+.2f ms (%+.1f%%)"
				% [ms.call("senza_prato") - ms.call("niente"),
						(ms.call("senza_prato") / ms.call("niente") - 1.0) * 100.0])
		print("   insieme             %+.2f ms (%+.1f%%)"
				% [ms.call("tutto") - ms.call("niente"),
						(ms.call("tutto") / ms.call("niente") - 1.0) * 100.0])

	print("PRATO -> ", _dove)
	quit()
