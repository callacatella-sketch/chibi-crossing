extends SceneTree

## BANCO TEMPORANEO (lente «rovina») — LA DISTANZA FRA LA PREMESSA E LA
## CONSEGUENZA, misurata sul villaggio vero e senza modello.
##
## La ricevuta punta il posto di un RICORDO (dove Mochi ha fatto qualcosa);
## il corpo, dopo, va dove lo manda la messa in scena dell'obiettivo (il
## cespuglio, l'aiuola, la panchina, il posto bello). Qui si misura quanto
## distano, per ogni ricordo vivo e per ognuno dei quattro provvedimenti.
##
##   Godot --headless --path . --script res://tools/_rovina_geo.gd

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")

const CASE := [Vector2i(2, 4), Vector2i(14, 4), Vector2i(4, 15),
	Vector2i(15, 14), Vector2i(9, 3), Vector2i(3, 10)]
const CESPUGLIO := Vector2i(12, 9)
const PANCA := Vector2i(9, 13)
const PANCA2 := Vector2i(6, 6)


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		quit(1)
		return
	for _i in 60:
		await process_frame
	# ⚠️ SU UNA MACCHINA CARICA IL MONDO CI METTE: si aspetta il bus della
	# percezione invece di contare i frame (la prima stesura usciva zitta).
	for _i in 200:
		if root.get_tree().get_first_node_in_group("percezione") != null:
			break
		await create_timer(0.1).timeout
	var liv := current_scene
	var build := liv.get_node_or_null("BuildSystem")
	var vis := liv.get_node_or_null("Visitors")
	var dn := liv.get_node_or_null("DayNight")
	var player := liv.get_node_or_null("Player") as Node3D
	if build == null or vis == null:
		print("GUASTO: la scena non si e' aperta (build=%s vis=%s)" % [build, vis])
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	dn.call("set_time", 0.42)
	await create_timer(1.2).timeout
	vis.call("debug_reset")
	for c in CASE:
		build.call("place_cell", c, "Letto", 0, false)
		build.call("place_cell", c, "Tetto", 0, false)
	build.call("place_cell", CESPUGLIO, "Cespuglio", 0, false)
	build.call("place_cell", PANCA, "Panchina", 0, false)
	build.call("place_cell", PANCA2, "Panchina", 0, false)
	build.call("aggiorna_varchi_ora")
	for i in CASE.size():
		vis.call("debug_settle", 4242 + i * 1013, CASE[i])
		await create_timer(0.7).timeout
	var res: Array = vis.get("_residents")
	var cuore = vis.call("cuore")
	# i gesti di Mochi, dal bus vero, accanto a ognuno
	var verbi := ["annaffia", "raccoglie", "costruisce", "cucina", "taglia", "semina"]
	for i in res.size():
		var r: Dictionary = res[i]
		var n := r.get("node") as Node3D
		if n == null:
			continue
		var dove: Vector3 = n.global_position + Vector3(1.6, 0.0, 1.2)
		for _k in 2:
			call_group("percezione", "accaduto", str(verbi[i % verbi.size()]), dove, "")
			await create_timer(0.3).timeout
		print("  gesto %s a %s — testimoni %d" % [str(verbi[i % verbi.size()]), dove,
				(vis.call("testimoni", dove, PERCEZIONE.RAGGIO) as Array).size()])
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 1.0).timeout
	if player != null:
		player.global_position = Vector3(-26, 0, -20)
	for _i in 60:
		await process_frame
	await create_timer(1.0).timeout

	print("\nDOVE GUARDA (il ricordo) → DOVE VA (il provvedimento), in metri")
	print("%-24s %-34s %8s %8s %8s %8s" % ["vicino", "ricordo", "pancino",
			"cura", "energia", "meraviglia"])
	var tutte := []
	for r0 in res:
		var r: Dictionary = r0
		var luoghi: Array = r.get("luoghi", [])
		if luoghi.size() < PIANI.LUOGHI.size():
			print("  %s: niente luoghi" % str(r.get("label", "?")))
			continue
		var g: Dictionary = cuore.call("debug_grafo", int(r["ecs"]))
		var ric: Array = g.get("ricordi", [])
		# ⚠️ `debug_grafo` NON restituisce i pesi: si chiedono riga per riga
		# all'oracolo, come fa `Suggeritore.ritratto`.
		var ritmo: Dictionary = cuore.call("debug_ritmo")
		var ora := float(ritmo.get("tempo", 0.0))
		var mezza := float(ritmo.get("mezza_vita", 0.0))
		for i in ric.size():
			var p := float(cuore.call("debug_grafo_peso", ric[i], ora, mezza))
			if p <= 0.35:
				continue
			var rr: Dictionary = ric[i]
			var a := Vector2(float(rr.get("px", 0.0)), float(rr.get("pz", 0.0)))
			var d := []
			for k in 4:
				var l: Dictionary = luoghi[k]
				if not bool(l.get("ok", false)):
					d.append(-1.0)
					continue
				var pos: Vector3 = l["pos"]
				d.append(a.distance_to(Vector2(pos.x, pos.z)))
			print("%-24s %-34s %8s %8s %8s %8s" % [str(r.get("label", "?")),
					"%s @ (%.0f,%.0f)" % [str(cuore.call("nome_verbo", int(rr.get("verbo", 0)))), a.x, a.y],
					_m(d[0]), _m(d[1]), _m(d[2]), _m(d[3])])
			for x in d:
				if float(x) >= 0.0:
					tutte.append(float(x))
	tutte.sort()
	if not tutte.is_empty():
		print("\n%d coppie (ricordo, provvedimento): mediana %.1f m · minimo %.1f m · massimo %.1f m"
				% [tutte.size(), tutte[tutte.size() / 2], tutte[0], tutte[-1]])
		var sotto := 0
		for x in tutte:
			if float(x) <= 2.0:
				sotto += 1
		print("coppie in cui la premessa e la meta distano meno di 2 m: %d su %d (%.0f%%)"
				% [sotto, tutte.size(), 100.0 * float(sotto) / float(tutte.size())])
	quit(0)


func _m(x: float) -> String:
	return "—" if x < 0.0 else "%.1f" % x
