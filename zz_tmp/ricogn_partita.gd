extends SceneTree
## DOVE STA UN VICINO, IN PARTITA — la distribuzione vera, non un'ipotesi.
##
##   CHIBI_MIN=6 ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://zz_tmp/ricogn_partita.gd        # SENZA --headless
##
## Ventotto residenti veri nel MainLevel vero, Mochi che cammina come cammina
## un giocatore, e un campione ogni 6 fotogrammi: per ogni vicino IN QUADRO
## si registra quanto è lontano, quanto è grande sullo schermo, dove cade nel
## fotogramma e DA CHE PARTE È GIRATO (di fronte, di tre quarti, di profilo,
## di spalle). È la tabella che decide quanto deve essere ampio un gesto.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

const QUANTI := 28
const MOCHI_PASSO := 3.0
const PASSO := 0.1

var _vis: Node = null
var _player: Node3D = null
var _res: Array = []

# i campioni
var _d_mochi := PackedFloat32Array()
var _d_cam := PackedFloat32Array()
var _testa_px := PackedFloat32Array()
var _alt_px := PackedFloat32Array()
var _sx := PackedFloat32Array()
var _sy := PackedFloat32Array()
var _viste := {"fronte": 0, "trequarti": 0, "profilo": 0, "spalle": 0}
## L'ANGOLO CRUDO, in bidoni UGUALI da 30°: i quattro nomi hanno larghezze
## diverse (fronte 22,5° contro spalle 67,5°) e confrontarli fra loro senza
## questo è confrontare la larghezza dei bidoni.
var _ang := PackedFloat32Array()
var _ang_vic := PackedFloat32Array()   # solo i vicini entro 12 m
var _piu_vicino := PackedFloat32Array()
var _testa_vicino := PackedFloat32Array()
var _quanti_in_quadro := PackedInt32Array()
var _frame := 0
var _visti_almeno_uno := 0


func _init() -> void:
	_go()


func _cam() -> Camera3D:
	return get_root().get_camera_3d()


func _perc(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var v := Array(a)
	v.sort()
	return float(v[clampi(int(v.size() * q), 0, v.size() - 1)])


func _media(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += x
	return s / float(a.size())


func _isto(a: PackedFloat32Array, bordi: Array, unita: String) -> void:
	var conta := []
	for _i in bordi.size() + 1:
		conta.append(0)
	for x in a:
		var messo := false
		for i in bordi.size():
			if x < float(bordi[i]):
				conta[i] += 1
				messo = true
				break
		if not messo:
			conta[bordi.size()] += 1
	var tot := maxi(a.size(), 1)
	for i in conta.size():
		var et := ""
		if i == 0:
			et = "< %.0f" % float(bordi[0])
		elif i == bordi.size():
			et = "≥ %.0f" % float(bordi[bordi.size() - 1])
		else:
			et = "%.0f – %.0f" % [float(bordi[i - 1]), float(bordi[i])]
		var p := 100.0 * float(conta[i]) / float(tot)
		print("    %-12s %s  %5.1f%%  (%d)" % [et + " " + unita,
				"█".repeat(int(p * 0.6)).rpad(34, "·"), p, int(conta[i])])


func _cella(k: int) -> Vector2i:
	return Vector2i(-6 + (k % 7) * 2, 3 + (k / 7) * 2)


func _go() -> void:
	var minuti := 6.0
	if OS.get_environment("CHIBI_MIN") != "":
		minuti = float(OS.get_environment("CHIBI_MIN"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	_vis = liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		# metà pomeriggio, e l'orologio quasi fermo: di notte sono tutti in
		# casa e la domanda «quanto è lontano un vicino» non ha soggetto
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	# il mondo deve avere dei POSTI, o nessuno va da nessuna parte
	for k in 4:
		var z := 3 + k * 2
		for x in [-9, 9]:
			build.call("place_cell", Vector2i(x, z), "Cespuglio", 0, false)
		for x in [-3, 3]:
			build.call("place_cell", Vector2i(x, z), "Panchina", 0, false)
	build.call("aggiorna_varchi_ora")

	var residenti: Array = _vis.get("_residents")
	for k in QUANTI:
		var c := _cella(k)
		var v = VS.new()
		v.dna = DNAG.generate(9000 + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(c.x), 0.0, float(c.y))
		v._enter_state("r_idle")
		var r := {"node": v, "label": "Prova%02d" % k, "dna": v.dna,
				"cell": c, "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for _i in 8:
		await process_frame
	_res = residenti
	print("")
	print("═".repeat(74))
	print("  DOVE STA UN VICINO, IN PARTITA — %d residenti, %.0f minuti" % [QUANTI, minuti])
	print("═".repeat(74))

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260813
	var mete := []
	for r in _res:
		mete.append(((r as Dictionary)["node"] as Node3D).global_position)
	var meta: Vector3 = mete[rng.randi() % mete.size()]
	var sosta := 0.0
	var t := 0.0
	var fine := minuti * 60.0
	while t < fine:
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= PASSO
		elif p.distance_to(Vector3(meta.x, p.y, meta.z)) < 0.6:
			sosta = rng.randf_range(2.0, 6.0)
			meta = mete[rng.randi() % mete.size()]
		else:
			var dd := (Vector3(meta.x, p.y, meta.z) - p).normalized()
			_player.global_position = p + dd * MOCHI_PASSO * PASSO
		_campiona()
		await create_timer(PASSO).timeout
		t += PASSO
	_rapporto()
	quit(0)


func _campiona() -> void:
	_frame += 1
	var c := _cam()
	var quanti := 0
	for r in _res:
		var n := ((r as Dictionary)["node"]) as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if bool(n.call("is_hidden")):
			continue
		var testa := n.global_position + Vector3(0, 0.64, 0)
		if c.is_position_behind(testa):
			continue
		var s := c.unproject_position(testa)
		if s.x < 0.0 or s.x > 1920.0 or s.y < 0.0 or s.y > 1080.0:
			continue
		quanti += 1
		var dm := _player.global_position.distance_to(n.global_position)
		var dc := c.global_position.distance_to(testa)
		var prof := (testa - c.global_position).dot(-c.global_transform.basis.z)
		_d_mochi.append(dm)
		_d_cam.append(dc)
		# il diametro apparente della testa: 0,574 m di testona (genoma medio)
		_testa_px.append(1158.03 * 0.574 / maxf(prof, 0.1))
		_alt_px.append(1158.03 * 0.89 / maxf(prof, 0.1))
		_sx.append(s.x)
		_sy.append(s.y)
		# DA CHE PARTE È GIRATO: l'angolo fra il suo muso (−Z) e la direzione
		# camera→lui. 0° = ci dà le spalle, 180° = ci guarda in faccia.
		var avanti: Vector3 = -n.global_transform.basis.z
		avanti.y = 0.0
		var verso: Vector3 = testa - c.global_position
		verso.y = 0.0
		var a := rad_to_deg(avanti.normalized().angle_to(verso.normalized()))
		_ang.append(a)
		if dm < 12.0:
			_ang_vic.append(a)
		if a >= 157.5:
			_viste["fronte"] += 1
		elif a >= 112.5:
			_viste["trequarti"] += 1
		elif a >= 67.5:
			_viste["profilo"] += 1
		else:
			_viste["spalle"] += 1
	_quanti_in_quadro.append(quanti)
	if quanti > 0:
		_visti_almeno_uno += 1
	# IL PIÙ VICINO IN QUADRO: è quello che il giocatore sta guardando, e la
	# media su tutti e ventotto direbbe soltanto quanto è grande il villaggio.
	var mind := 1e9
	var mint := 0.0
	for r in _res:
		var n := ((r as Dictionary)["node"]) as Node3D
		if n == null or not is_instance_valid(n) or bool(n.call("is_hidden")):
			continue
		var testa := n.global_position + Vector3(0, 0.64, 0)
		if c.is_position_behind(testa):
			continue
		var s := c.unproject_position(testa)
		if s.x < 0.0 or s.x > 1920.0 or s.y < 0.0 or s.y > 1080.0:
			continue
		var dm := _player.global_position.distance_to(n.global_position)
		if dm < mind:
			mind = dm
			mint = 1158.03 * 0.574 / maxf((testa - c.global_position).dot(
					-c.global_transform.basis.z), 0.1)
	if mind < 1e8:
		_piu_vicino.append(mind)
		_testa_vicino.append(mint)


func _rapporto() -> void:
	print("")
	print("  campioni: %d fotogrammi, %d apparizioni di un vicino in quadro"
			% [_frame, _d_mochi.size()])
	var somma := 0
	var maxq := 0
	for q in _quanti_in_quadro:
		somma += q
		maxq = maxi(maxq, q)
	print("  vicini IN QUADRO nello stesso istante: media %.2f, massimo %d"
			% [float(somma) / maxf(float(_frame), 1.0), maxq])
	print("  fotogrammi con almeno un vicino in quadro: %.1f%%"
			% [100.0 * float(_visti_almeno_uno) / maxf(float(_frame), 1.0)])
	print("")
	print("  ── QUANTO È LONTANO (da MOCHI) ──")
	print("     mediana %.1f m · media %.1f m · quartili %.1f / %.1f m · 10%% più vicini < %.1f m"
			% [_perc(_d_mochi, 0.5), _media(_d_mochi), _perc(_d_mochi, 0.25),
			_perc(_d_mochi, 0.75), _perc(_d_mochi, 0.10)])
	_isto(_d_mochi, [2, 4, 6, 9, 12, 15, 20, 30], "m")
	print("")
	print("  ── E DALLA CAMERA (che è quello che conta per i pixel) ──")
	print("     mediana %.1f m · quartili %.1f / %.1f m"
			% [_perc(_d_cam, 0.5), _perc(_d_cam, 0.25), _perc(_d_cam, 0.75)])
	print("")
	print("  ── QUANTO È GRANDE: il diametro della TESTA sullo schermo ──")
	print("     mediana %.0f px · quartili %.0f / %.0f px · il 10%% più grande > %.0f px"
			% [_perc(_testa_px, 0.5), _perc(_testa_px, 0.75), _perc(_testa_px, 0.25),
			_perc(_testa_px, 0.90)])
	_isto(_testa_px, [20, 30, 40, 55, 70, 90, 120], "px")
	print("")
	print("  ── e il CORPO INTERO, in altezza ──")
	print("     mediana %.0f px · quartili %.0f / %.0f px"
			% [_perc(_alt_px, 0.5), _perc(_alt_px, 0.75), _perc(_alt_px, 0.25)])
	print("")
	print("  ── DA CHE PARTE È GIRATO (0° = ci dà le spalle) ──")
	var tot := 0
	for k in _viste:
		tot += int(_viste[k])
	for k in ["fronte", "trequarti", "profilo", "spalle"]:
		var p := 100.0 * float(_viste[k]) / maxf(float(tot), 1.0)
		print("     %-11s %s %5.1f%%" % [k, "█".repeat(int(p * 0.6)).rpad(34, "·"), p])
	print("")
	print("  ── IL PIÙ VICINO IN QUADRO (quello che il giocatore guarda) ──")
	print("     distanza da Mochi: mediana %.1f m · quartili %.1f / %.1f m"
			% [_perc(_piu_vicino, 0.5), _perc(_piu_vicino, 0.25), _perc(_piu_vicino, 0.75)])
	_isto(_piu_vicino, [2, 4, 6, 9, 12, 15, 20], "m")
	print("     la sua testa: mediana %.0f px · quartili %.0f / %.0f px"
			% [_perc(_testa_vicino, 0.5), _perc(_testa_vicino, 0.75),
			_perc(_testa_vicino, 0.25)])
	print("")
	print("  ── L'ANGOLO CRUDO, bidoni UGUALI da 30° (0° = ci dà le spalle) ──")
	print("     tutti in quadro:")
	_isto(_ang, [30, 60, 90, 120, 150], "°")
	print("     solo quelli entro 12 m (cioè quelli che si possono leggere):")
	_isto(_ang_vic, [30, 60, 90, 120, 150], "°")
	print("")
	print("  ── DOVE CADE NEL FOTOGRAMMA (1920×1080) ──")
	print("     x: mediana %.0f (centro 960) · y: mediana %.0f (centro 540)"
			% [_perc(_sx, 0.5), _perc(_sy, 0.5)])
	print("     y: quartili %.0f / %.0f — un vicino sta quasi sempre nella metà alta"
			% [_perc(_sy, 0.25), _perc(_sy, 0.75)])
