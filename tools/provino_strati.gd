extends SceneTree
## IL PROVINO DELLA STRATIGRAFIA (progetto §5.3, REGOLA ZERO) — si GUARDA:
## la suite verde non dice niente sulla resa.
##
##  1. I MODELLINI di _fai_reperto affiancati ed etichettati: la scheggia
##     della demolizione, la sferetta del ricordo in CINQUE tinte di pelo
##     (si deve riconoscere CHI era dal colore, come nei sogni), i quattro
##     segni di stagione. Fronte, profilo e tre quarti: di profilo si
##     smascherano i trucchi.
##  2. L'ICONA «reperto» di PocketIcon (il piccolo involto), a tre taglie e
##     accanto alla bacca del ripiego: si vede da lontano che È un'altra
##     cosa?
##  3. IL LUCCICHIO-STRATO nel MainLevel VERO, accanto a un luccichio
##     normale: devono essere INDISTINGUIBILI (niente rovine in superficie)
##     — fronte, profilo, tre quarti per entrambi.
##  4. LO SCAVO COMPLETO col toast del reperto a fine volo.
##
##   CHIBI_STRATI=<cartella>  dove mettere le foto (senza, non si scatta)
##   Godot --path . --resolution 1280x720 --script res://tools/provino_strati.gd
##
## ⚠️ **SENZA `--headless`**: non c'è niente da guardare in un rendering che
## non avviene.

const STRATI_S := preload("res://scenes/world/Strati.gd")
const SCAVI_S := preload("res://scenes/interact/Scavi.gd")
const DN_S := preload("res://scenes/world/DayNight.gd")
const ICONA := preload("res://scenes/ui/PocketIcon.gd")

## Cinque peli veri del villaggio: panna, miele, cioccolato, grigio
## nuvola, rosa — la sferetta deve dire CHI era in mezzo agli altri.
const TINTE := ["f7e6d0", "d9a066", "8a5a3a", "b8c4cc", "e8b4b8"]

var _dove := ""
var _n := 0


func _init() -> void:
	_go()


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [_dove, _n, nome])
	print("   → %02d_%s.png" % [_n, nome])


func _etichetta(radice: Node3D, testo: String, dove: Vector3) -> void:
	var l := Label3D.new()
	l.text = testo
	l.font_size = 22
	l.pixel_size = 0.0016
	l.modulate = Color(0.25, 0.18, 0.12)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = dove
	radice.add_child(l)


func _go() -> void:
	_dove = OS.get_environment("CHIBI_STRATI")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	await process_frame

	# ------------------------------------------- 1) lo studio dei modellini
	print("1 · i modellini di _fai_reperto, affiancati")
	var radice := Node3D.new()
	get_root().add_child(radice)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-42, -35, 0)
	luce.light_energy = 1.5
	luce.light_color = Color(1.0, 0.96, 0.9)
	radice.add_child(luce)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.76, 0.58)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.78, 0.85)
	e.ambient_light_energy = 0.9
	env.environment = e
	radice.add_child(env)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	suolo.mesh = pm
	var matS := StandardMaterial3D.new()
	matS.albedo_color = Color(0.45, 0.62, 0.36)
	suolo.material_override = matS
	radice.add_child(suolo)
	var cam := Camera3D.new()
	radice.add_child(cam)
	cam.current = true

	var scavi_inst = SCAVI_S.new()   # solo per _fai_reperto: non entra in scena
	# fila davanti: la scheggia + i quattro segni di stagione
	var davanti: Array = [STRATI_S.riga_demolizione([0, 0], "Ponte", 1)]
	for segno in ["petalo_pressato", "spiga_dorata", "foglia_d_oro", "fiocco_intatto"]:
		davanti.append({"tipo": "stagione", "cella": [0, 0], "g": 1, "segno": segno})
	for i in davanti.size():
		var strato: Dictionary = davanti[i]
		var m: Node3D = scavi_inst._fai_reperto(strato)
		m.position = Vector3(-0.8 + 0.4 * i, 0.1, 0.0)
		radice.add_child(m)
		var nome := str(strato.get("segno", "scheggia"))
		_etichetta(radice, nome, m.position + Vector3(0, 0.22, 0))
	# fila dietro: la sferetta del ricordo in cinque tinte di pelo
	for i in TINTE.size():
		var riga := STRATI_S.riga_ricordo([0, 0], "Provino", "",
				{"fur": TINTE[i]}, "", 1)
		var m2: Node3D = scavi_inst._fai_reperto(riga)
		m2.position = Vector3(-0.8 + 0.4 * i, 0.1, -0.55)
		radice.add_child(m2)
		_etichetta(radice, str(TINTE[i]), m2.position + Vector3(0, 0.22, 0))
	scavi_inst.free()
	await process_frame
	var mira := Vector3(0, 0.08, -0.27)
	for vista in [[Vector3(0, 0.75, 1.35), "fronte"],
			[Vector3(1.7, 0.5, -0.27), "profilo"],
			[Vector3(1.15, 0.75, 0.9), "tre_quarti"]]:
		cam.position = vista[0]
		cam.look_at(mira)
		await _scatta("modellini_%s" % str(vista[1]))

	# ------------------------------------------------ 2) l'icona delle Tasche
	print("2 · l'icona «reperto» di PocketIcon, a tre taglie")
	var strato_ui := CanvasLayer.new()
	get_root().add_child(strato_ui)
	var fondo := ColorRect.new()
	fondo.color = Color(0.97, 0.93, 0.85)
	fondo.size = Vector2(560, 220)
	fondo.position = Vector2(30, 30)
	strato_ui.add_child(fondo)
	var x := 60.0
	for lato in [32, 64, 128]:
		var ic = ICONA.new()
		ic.set("kind", "reperto")
		ic.position = Vector2(x, 60.0 + (128 - lato) * 0.5)
		ic.size = Vector2(lato, lato)
		strato_ui.add_child(ic)
		x += lato + 30.0
	# accanto, la bacca del ripiego: si devono distinguere al volo
	var confronto = ICONA.new()
	confronto.set("kind", "bacca")
	confronto.position = Vector2(x + 20.0, 92.0)
	confronto.size = Vector2(64, 64)
	strato_ui.add_child(confronto)
	await _scatta("icona_reperto")
	strato_ui.queue_free()
	radice.queue_free()
	await process_frame

	# --------------------------- 3) il luccichio-strato nel MainLevel VERO
	print("3 · il luccichio-strato accanto a uno normale (MainLevel vero)")
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	var build := livello.get_node_or_null("BuildSystem")
	var cozy := livello.get_node_or_null("CozyWorld")
	var scavi := livello.get_node_or_null("Scavi")
	var strati := livello.get_node_or_null("Strati")
	var daynight := livello.get_node_or_null("DayNight")
	if build == null or cozy == null or scavi == null or strati == null:
		print("GUASTO: mancano i nodi del MainLevel")
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	await create_timer(2.0).timeout
	var ostacoli: Array = cozy.call("obstacle_circles")
	# un giorno non di confine in cui il dado del mattino dice sì
	var giorno := -1
	for d in range(2, 400):
		if (d - 1) % DN_S.SEASON_DAYS == 0:
			continue
		if not (STRATI_S.strato_affiorante(d,
				[STRATI_S.riga_demolizione([0, 0], "Sonda", d - 1)]) as Dictionary).is_empty():
			giorno = d
			break
	var punti: Array = SCAVI_S.punti_del_giorno(giorno, ostacoli)
	var cella_buona: Array = []
	for xx in range(-12, 13):
		for zz in range(-14, 8):
			var c := [xx, zz]
			if not STRATI_S.valida_cella(c, ostacoli):
				continue
			if bool(build.call("has_cover", Vector2i(xx, zz))):
				continue
			var stretto := false
			for q in punti:
				if Vector2(float(q.x) - float(xx), float(q.z) - float(zz)).length() \
						< SCAVI_S.DIST_MIN + 0.6:
					stretto = true
					break
			if not stretto:
				cella_buona = c
				break
		if not cella_buona.is_empty():
			break
	if cella_buona.is_empty():
		print("GUASTO: nessuna cella per lo strato")
		quit(1)
		return
	strati.set("_strati", [STRATI_S.riga_ricordo(cella_buona, "Nocciola",
			"il gattino Cannella",
			{"quirk": "colleziona_sassolini", "fur": "f7e6d0"}, "", giorno - 1)])
	strati.set("_g_aff", -1)
	strati.set("_g_pota", -1)
	daynight.set("day", giorno)
	scavi.set("_giorno", giorno)
	scavi.set("_scavati", [])
	scavi.call("_rigenera")
	# il tempo del mattino, fermo su una luce che si giudica
	daynight.set("time", 0.35)
	var spots: Array = scavi.get("_spots")
	var spot_strato: Dictionary = {}
	var spot_normale: Dictionary = {}
	for s in spots:
		if (s as Dictionary).has("strato"):
			spot_strato = s
		elif spot_normale.is_empty():
			spot_normale = s
	if spot_strato.is_empty() or spot_normale.is_empty():
		print("GUASTO: mancano i due luccichii da confrontare (strato=%s, normali=%d)"
				% [not spot_strato.is_empty(), spots.size()])
		quit(1)
		return
	var cam2 := Camera3D.new()
	get_root().add_child(cam2)
	cam2.current = true
	await create_timer(1.2).timeout   # le scintille devono aver preso fiato
	for coppia in [[spot_strato, "strato"], [spot_normale, "normale"]]:
		var pos: Vector3 = (coppia[0] as Dictionary)["pos"]
		for vista in [[Vector3(0, 0.85, 1.6), "fronte"],
				[Vector3(1.8, 0.7, 0.0), "profilo"],
				[Vector3(1.25, 0.85, 1.25), "tre_quarti"]]:
			cam2.position = pos + (vista[0] as Vector3)
			cam2.look_at(pos + Vector3(0, 0.15, 0))
			await _scatta("luccichio_%s_%s" % [str(coppia[1]), str(vista[1])])

	# --------------------------------------- 4) lo scavo completo col toast
	print("4 · lo scavo completo, fino al toast")
	var player := livello.get_node_or_null("%Player")
	if player != null:
		(player as Node3D).global_position = \
				(spot_strato["pos"] as Vector3) + Vector3(0.7, 0.0, 0.7)
	var k := spots.find(spot_strato)
	var posa: Vector3 = spot_strato["pos"]
	cam2.position = posa + Vector3(1.4, 1.1, 1.9)
	cam2.look_at(posa + Vector3(0, 0.45, 0))
	scavi.call("_scava", k)
	await create_timer(0.5).timeout
	await _scatta("scavo_zampate")
	await create_timer(1.0).timeout
	await _scatta("scavo_volo_e_toast")
	await create_timer(0.8).timeout
	await _scatta("scavo_toast")
	print("FATTO: %d foto in %s" % [_n, _dove])
	quit(0)
