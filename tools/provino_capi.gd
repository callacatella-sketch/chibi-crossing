extends SceneTree
## IL PROVINO DEL CAPO — tre teste inclinate insieme, e una che non si
## raddrizza più.
##
##   CHIBI_CAPI=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_capi.gd
##
## `Visitors.CAPO_MAX` dice DUE, e la ragione scritta è estetica: «tre teste
## inclinate insieme sono una posa di gruppo, non tre pensieri». Una regola
## estetica si giudica **guardando**, non contando — e finché nessuno l'aveva
## guardata, il numero due era un'opinione.
##
## Tre scene, tutte nel MainLevel vero e dalla camera VERA del gioco
## (incollata a Mochi, 2,7 m sopra e 3,7 dietro: una macchina piazzata a un
## metro dal muso mostrerebbe una cosa che il giocatore non vedrà mai):
##
##   I    TRE teste inclinate insieme — la posa di gruppo
##   II   DUE, che è il tetto — lo stesso quadro, una testa in meno
##   III  L'ESTETISTA: la testa che dopo uno spegnimento secco resta storta
##
## ⚠️ Il rollio è una SEQUENZA DI TRASFERIMENTI, non un seno: fra un
## trasferimento e l'altro il capo sta fermo, e i tre orologi sono
## incommensurabili apposta. Quindi non esiste «lo scatto giusto»: si prende
## una PELLICOLA e sotto ogni fotogramma si stampano i tre angoli VERI, così
## chi guarda sa cosa sta guardando.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

## Tre genomi diversi: il rollio prende fase e ampiezza dal genoma, e tre
## copie dello stesso chibi penderebbero all'unisono — cioè mostrerebbero un
## difetto che il gioco non ha.
const SEMI := [7331, 5119, 2087]
## Sei metri: la distanza a cui un giocatore vede un vicino passandogli
## accanto, ed è quella su cui è stato tarato tutto il vocabolario.
const DIST := 7.0
const PASSO := 1.45

var _dove := ""
var _player: Node3D = null
var _corpi: Array = []
var _scatti := 0


func _init() -> void:
	_go()


## Il riquadro racchiude TUTTI E TRE i corpi: qui non si giudica una posa, si
## giudica un quadro d'insieme — quante teste storte si vedono in una volta.
func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var cam := get_root().get_camera_3d()
	if cam != null and not _corpi.is_empty():
		var minv := Vector2(1e9, 1e9)
		var maxv := Vector2(-1e9, -1e9)
		for c in _corpi:
			for q in [Vector3(0, 0, 0), Vector3(0, 1.25, 0)]:
				var p := cam.unproject_position((c as Node3D).global_position + q)
				minv = Vector2(minf(minv.x, p.x), minf(minv.y, p.y))
				maxv = Vector2(maxf(maxv.x, p.x), maxf(maxv.y, p.y))
		var m := 60.0
		var r := Rect2i(Vector2i(int(minv.x - m), int(minv.y - m)),
				Vector2i(int(maxv.x - minv.x + m * 2), int(maxv.y - minv.y + m * 2)))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 32 and r.size.y > 32:
			img = img.get_region(r)
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_scatti += 1


func _angoli() -> String:
	var s := ""
	for c in _corpi:
		s += "%6.2f° " % rad_to_deg(float((c as Node3D).get("_gs_capo_x")))
	return s


func _quante_storte(soglia := 0.02) -> int:
	var n := 0
	for c in _corpi:
		if absf(float((c as Node3D).get("_gs_capo_x"))) >= soglia:
			n += 1
	return n


func _go() -> void:
	_dove = OS.get_environment("CHIBI_CAPI")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	var visitors := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	if _player == null or visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	# tre corpi in fila, di TRE QUARTI: di fronte il rollio si legge sul
	# muso, di profilo sulla nuca, e i due non si somigliano affatto.
	for i in SEMI.size():
		var v = VS.new()
		v.set("species", "chibi")
		v.set("dna", DNAG.generate(int(SEMI[i])))
		visitors.add_child(v)
		v.set("greet_enabled", false)
		_corpi.append(v)
	await create_timer(1.2).timeout
	for i in _corpi.size():
		var v: Node3D = _corpi[i]
		v.global_position = Vector3((float(i) - 1.0) * PASSO, 0.0, 0.0)
		v.set("_yaw", deg_to_rad(150.0))
		v.rotation.y = deg_to_rad(150.0)
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
	# Mochi si mette DI LATO: la camera è incollata a lei e la sua testona
	# coprirebbe il vicino di mezzo.
	_player.global_position = Vector3(3.1, _player.global_position.y, DIST)
	await create_timer(1.6).timeout

	print("")
	print("█".repeat(72))
	print("SCENA I — TRE teste inclinate insieme (il mondo di prima)")
	print("█".repeat(72))
	for v in _corpi:
		(v as Node3D).call("capo_pende", true)
	await _pellicola("tre", 20)

	print("")
	print("█".repeat(72))
	print("SCENA II — DUE, che è il tetto")
	print("█".repeat(72))
	(_corpi[1] as Node3D).call("capo_pende", false)
	await create_timer(1.5).timeout
	await _pellicola("due", 20)

	print("")
	print("█".repeat(72))
	print("SCENA III — L'ESTETISTA: lo spegnimento secco sotto una frase")
	print("█".repeat(72))
	await _estetista()

	print("\n  scatti: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	quit(0)


## Una PELLICOLA: il rollio è fatto di attese, e in un fotogramma solo può
## capitare che tutte e tre le teste siano dritte. Sotto ogni scatto ci sono
## i tre angoli veri.
func _pellicola(nome: String, quanti: int) -> void:
	var t0 := Time.get_ticks_msec()
	var migliore := -1
	var mig_n := -1
	for i in quanti:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(i) * 1.4:
			await process_frame
		var n := _quante_storte()
		print("   t=%5.1f  %s  → %d teste storte" % [float(i) * 1.4, _angoli(), n])
		await _scatta("%s_%02d" % [nome, i])
		if n > mig_n:
			mig_n = n
			migliore = i
	print("   il fotogramma con più teste storte è %s_%02d (%d)"
			% [nome, migliore, mig_n])


## LA TESTA CHE NON SI RADDRIZZA PIÙ. `rifai_il_look` — il Salone di
## bellezza — rimonta il corpo e per farlo chiama `gesto_spegni(true)`, il
## taglio netto. Il capo acceso da una frase è del gesto: se il gesto non
## c'è più e la testa resta storta, è un canale orfano.
func _estetista() -> void:
	var v: Node3D = _corpi[0]
	(v as Node3D).call("capo_pende", false)
	await create_timer(1.5).timeout
	# la frase vuole un corpo che cammina: si parte indietro e si mira lontano
	var yaw: float = deg_to_rad(150.0)
	var muso := Vector3(-sin(yaw), 0.0, -cos(yaw))
	v.global_position = -muso * 1.1 + Vector3(-PASSO, 0, 0)
	v.call("_walk_to", v.global_position + muso * 60.0, "r_idle")
	await create_timer(0.8).timeout
	var ok: bool = bool(v.call("frase", "pensiero"))
	print("   la frase del pensiero è partita: %s (capo %s)"
			% [str(ok), str(bool(v.get("_gs_capo")))])
	await create_timer(0.6).timeout
	await _scatta("estetista_0_frase")
	print("   t=  0.0  prima dell'estetista: %6.2f°"
			% rad_to_deg(float(v.get("_gs_capo_x"))))
	v.call("rifai_il_look", {"fur": "e8b4a0", "belly": "f6d8cc"})
	# il corpo è nuovo: si rimette in cammino, come farebbe il mondo
	await create_timer(0.6).timeout
	v.call("_enter_state", "r_idle")
	v.set("_timer", 999999.0)
	var t0 := Time.get_ticks_msec()
	for i in 8:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(i) * 5.0:
			await process_frame
		print("   t=%5.1f  dopo l'estetista: %6.2f°   livello acceso: %s"
				% [float(i) * 5.0, rad_to_deg(float(v.get("_gs_capo_x"))),
						str(bool(v.get("_gs_capo")))])
		await _scatta("estetista_%d_t%02d" % [i + 1, int(float(i) * 5.0)])
