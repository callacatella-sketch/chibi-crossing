extends SceneTree

## BANCO TEMPORANEO (lente «rovina») — LA RICEVUTA NEL MONDO VERO, senza posa.
##
## `tools/prova_deduzione.gd` POSA il corpo e lo punta a 35° dall'ancora: lì
## la ricevuta si paga in 0,73 s. Qui i vicini fanno la loro vita, e la
## domanda è quella vera: quanto ci mette una deduzione a trovare il suo
## momento — e quante non lo trovano mai prima di scadere?
##
##   Godot --headless --path . --script res://tools/_rovina_ricevuta.gd

const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const DEDUZIONI := preload("res://scenes/npc/Deduzioni.gd")

const CASE := [Vector2i(2, 4), Vector2i(14, 4), Vector2i(4, 15),
	Vector2i(15, 14), Vector2i(9, 3), Vector2i(3, 10)]
const CESPUGLIO := Vector2i(12, 9)
const PANCA := Vector2i(9, 13)
const SOGLIA := 0.35
const TETTO := 150.0


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
	build.call("aggiorna_varchi_ora")
	for i in CASE.size():
		vis.call("debug_settle", 4242 + i * 1013, CASE[i])
		await create_timer(0.7).timeout
	var res: Array = vis.get("_residents")
	var cuore = vis.call("cuore")
	var verbi := ["annaffia", "raccoglie", "costruisce", "cucina", "taglia", "semina"]
	for i in res.size():
		var r: Dictionary = res[i]
		var n := r.get("node") as Node3D
		if n == null:
			continue
		var dove: Vector3 = n.global_position + Vector3(1.6, 0.0, 1.2)
		for _k in 3:
			call_group("percezione", "accaduto", str(verbi[i % verbi.size()]), dove, "")
			await create_timer(0.3).timeout
		print("  gesto %s — testimoni %d" % [str(verbi[i % verbi.size()]),
				(vis.call("testimoni", dove, PERCEZIONE.RAGGIO) as Array).size()])
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 1.0).timeout
	# ⚠️ MOCHI VA VIA: la ricevuta non chiede dove sia il giocatore
	# (`Deduzioni.consegna` passa al `puo_vedere` la posizione del VICINO), e
	# questo banco esiste anche per vedere se si paga lo stesso.
	if player != null:
		player.global_position = Vector3(-40, 0, -40)

	# una deduzione a testa, dal ricordo più forte
	var attesa := {}
	for r0 in res:
		var r: Dictionary = r0
		var id := int(r["ecs"])
		var g: Dictionary = cuore.call("debug_grafo", id)
		var ric: Array = g.get("ricordi", [])
		var ritmo: Dictionary = cuore.call("debug_ritmo")
		var ora := float(ritmo.get("tempo", 0.0))
		var mezza := float(ritmo.get("mezza_vita", 0.0))
		var forte := -1
		var pmax := 0.0
		for i in ric.size():
			var p := float(cuore.call("debug_grafo_peso", ric[i], ora, mezza))
			if p > pmax:
				pmax = p
				forte = i
		print("  %s: %d ricordi, piu forte %d peso %.2f" % [str(r.get("label", "?")),
				ric.size(), forte, pmax])
		if forte < 0:
			continue
		var i_d := int(cuore.call("deduci", id,
				int(cuore.call("maschera_obiettivo", "provvedi_pancino")),
				PackedInt32Array([forte]), SOGLIA))
		print("     deduci -> %d (maschera %d)" % [i_d,
				int(cuore.call("maschera_obiettivo", "provvedi_pancino"))])
		if i_d >= 0:
			attesa[str(r.get("label", "?"))] = {"id": id, "i": i_d, "t": 0.0,
					"pagata": -1.0, "ok": -1.0, "peso": pmax}
	print("deduzioni piantate: %d" % attesa.size())

	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < TETTO:
		await process_frame
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		for k in attesa:
			var a: Dictionary = attesa[k]
			if a["pagata"] < 0.0:
				var dd: Dictionary = cuore.call("debug_deduzioni", a["id"])
				var righe: Array = dd.get("deduzioni", [])
				var bit := int((cuore.call("debug_deduzioni_costanti") as Dictionary)["d_ricevuta"])
				if int(a["i"]) < righe.size() \
						and (int((righe[int(a["i"])] as Dictionary).get("bandiere", 0)) & bit) != 0:
					a["pagata"] = t
			elif a["ok"] < 0.0:
				if int(cuore.call("deduzione_pronta", a["id"], SOGLIA,
						DEDUZIONI.ATTESA, DEDUZIONI.finestra(cuore))) >= 0:
					a["ok"] = t

	print("\n%-24s %8s %12s %12s" % ["vicino", "peso", "ricevuta(s)", "utilizzabile(s)"])
	var pagate := 0
	for k in attesa:
		var a: Dictionary = attesa[k]
		if a["pagata"] >= 0.0:
			pagate += 1
		print("%-24s %8.2f %12s %12s" % [k, float(a["peso"]),
				("%.1f" % float(a["pagata"])) if a["pagata"] >= 0.0 else "MAI",
				("%.1f" % float(a["ok"])) if a["ok"] >= 0.0 else "mai"])
	print("\nricevute pagate entro %.0f s: %d su %d" % [TETTO, pagate, attesa.size()])
	quit(0)
