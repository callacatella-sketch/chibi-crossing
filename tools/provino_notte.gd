extends SceneTree
## «STA ARRIVANDO LA MIA SERA» — le varianti affiancate, e il confronto con la
## parola che il corpo dice già.
##
##   CHIBI_NOTTE=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_notte.gd
##
## ⚠️ **NON --headless: qui si SCEGLIE un numero guardando.** `Gesti.NOTTE_SY`
## non si indovina: il progetto ha già misurato che la scala porta il verso
## fino a −10% e che a −13% cade, e quella banda va guardata sul corpo vero.
##
## ────────────────────────────────────────────────────────────────────────
## LE TRE LASTRE
## ────────────────────────────────────────────────────────────────────────
##
## 1. **LE VARIANTI.** Cinque corpi identici nello stesso fotogramma, al
##    livello PIENO, con cinque guadagni diversi. Si sceglie il più piccolo
##    che si legge.
## 2. **LA CONTROPROVA.** Gli stessi cinque corpi a livello ZERO. Se questa
##    lastra mostra la stessa progressione, quella di sopra è rumore — è la
##    lezione che il provino del carattere ha già pagato: cinque corpi con
##    chimica bit-identica avevano sopracciglia visibilmente diverse.
## 3. **LA PAROLA DOPPIA.** La notte accanto alla CODA SOMATICA, che è
##    l'altro livello di silhouette del vocabolario. Se le due pose si
##    leggono uguali, questo canale non si aggiunge: consegnerebbe una parola
##    che il corpo dice già. È la domanda che il progetto non ha mai dovuto
##    farsi finora, e va guardata prima di consegnare.
##
## Le regole di ripresa sono quelle di `provino_carattere`: camera VERA, la
## fila che si apre con la distanza, Mochi tolta dall'inquadratura (la sua
## testona copre il corpo di mezzo), i CanvasLayer rispenti prima di ogni
## scatto, e il ritaglio a pixel fissi.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const SEME := 7331
## I cinque guadagni: a livello pieno danno −4%, −7%, −10%, −15%, −22% di
## altezza. Il terzo è il limite noto del verso; il quinto è fuori apposta,
## per vedere dov'è troppo.
const VARIANTI := [0.04, 0.07, 0.10, 0.15, 0.22]
const AZIMUT := {"fronte": 180.0, "trequarti": 135.0, "profilo": 90.0,
		"spalle": 0.0}
const DISTANZE := [2.0, 6.0]
const PASSO := 1.05
const TILE := 240
const TILE_H := 310

var _dove := ""
var _liv: Node
var _player: Node3D
var _visitors: Node
var _cam: Camera3D
var _corpi: Array[Node3D] = []
var _vp: SubViewport = null
var _lab: Label = null
var _cache := {}
var _py := 0.0


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_NOTTE")
	if _dove == "":
		_dove = "/tmp/notte"
	DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	_liv = current_scene
	_player = _liv.get_node_or_null("Player") as Node3D
	_visitors = _liv.get_node_or_null("Visitors")
	var build := _liv.get_node_or_null("BuildSystem")
	var dn := _liv.get_node_or_null("DayNight")
	if _player == null or _visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout
	_py = _player.global_position.y
	_cam = get_root().get_camera_3d()
	if _cam == null:
		print("GUASTO: nessuna camera")
		quit(1)
		return
	var mochi := _player.get_node_or_null("Mochi") as Node3D
	if mochi != null:
		mochi.visible = false
	for n in _visitors.get_children():
		if n is Node3D:
			(n as Node3D).visible = false

	print("")
	print("█".repeat(74))
	print("«STA ARRIVANDO LA MIA SERA» — le varianti, e la parola doppia")
	print("  soglia %.2f · pieno %.2f (il picco MISURATO in partita e' 0.25–0.45)"
			% [GESTI.NOTTE_SOGLIA, GESTI.NOTTE_PIENA])
	print("  di serie: sy −%.1f%% · hpy %+.3f m"
			% [GESTI.NOTTE_SY * 100.0, GESTI.NOTTE_HPY])
	print("█".repeat(74))

	await _monta(5)
	for vista in AZIMUT:
		for d in DISTANZE:
			await _lastra_varianti(str(vista), float(d), 1.0,
					"varianti_%s_%.0fm" % [vista, d])
	# la CONTROPROVA: gli stessi cinque a livello zero
	await _lastra_varianti("fronte", 2.0, 0.0, "controprova_fronte_2m")
	await _lastra_varianti("trequarti", 6.0, 0.0, "controprova_trequarti_6m")

	await _monta(3)
	for vista2 in ["fronte", "trequarti", "profilo", "spalle"]:
		await _lastra_doppia(str(vista2), 2.0)
		await _lastra_doppia(str(vista2), 6.0)
	print("\n  scatti in %s" % _dove)
	quit(0)


func _monta(quanti: int) -> void:
	for v in _corpi:
		v.queue_free()
	_corpi.clear()
	await create_timer(0.4).timeout
	var genoma: Dictionary = DNAG.generate(SEME)
	for _i in quanti:
		var v := VS.new()
		v.set("species", "chibi")
		v.set("dna", genoma.duplicate(true))
		_visitors.add_child(v)
		v.set("greet_enabled", false)
		_corpi.append(v)
	await create_timer(1.2).timeout
	for n in _visitors.get_children():
		if n is Node3D and not _corpi.has(n):
			(n as Node3D).visible = false
	for v2 in _corpi:
		v2.call("_enter_state", "r_idle")
		v2.set("_timer", 999999.0)


func _posiziona(vista: String, dist: float) -> void:
	for layer in get_root().find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var centro := Vector3.ZERO
	_player.global_position = Vector3(0.0, _py, dist)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	var dir := centro - cam_pos
	var yaw := wrapf(atan2(dir.x, dir.z) + PI + deg_to_rad(float(AZIMUT[vista])),
			-PI, PI)
	var mezzo := (float(_corpi.size()) - 1.0) * 0.5
	var passo: float = PASSO * (dist + 3.7) / (2.0 + 3.7)
	for i in _corpi.size():
		var v := _corpi[i]
		v.global_position = centro + Vector3((float(i) - mezzo) * passo, 0.0, 0.0)
		v.set("_yaw", yaw)
		v.rotation.y = yaw
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)
		v.set("_gs_notte", 0.0)
		v.set("_notte_mel", 0.0)
		v.set_meta("postura", "sereno")
	await create_timer(0.6).timeout


## ⚠️ Il livello si posa passando la MELATONINA dalla porta vera
## (`indossa_neuro`) e lasciando girare `_process`: nessun canale del rig
## scritto a mano, o la lastra proverebbe il proprio disegnatore.
func _lastra_varianti(vista: String, dist: float, livello: float,
		nome: String) -> void:
	await _posiziona(vista, dist)
	var etich: Array = []
	for k in VARIANTI:
		etich.append("sy −%.0f%%\n(hpy %+.3f)" % [float(k) * 100.0,
				GESTI.NOTTE_HPY])
	for _f in 40:
		for i in _corpi.size():
			_corpi[i].call("indossa_neuro",
					{"melatonina": GESTI.NOTTE_PIENA * livello})
			# la variante si posa scrivendo il guadagno del canale: e' la
			# sola cosa che questo provino cambia fra una colonna e l'altra
			_corpi[i].set("_gs_notte_prova", float(VARIANTI[i]))
		await process_frame
	var img := await _scatta()
	var celle := {}
	for i2 in _corpi.size():
		celle[[0, i2]] = _ritaglia(img, _cam.unproject_position(
				_corpi[i2].global_position + Vector3(0, 0.42, 0)), TILE, TILE_H)
	await _foglio("la notte · %s · %.0f m · livello %.0f%% (camera VERA)"
			% [vista, dist, livello * 100.0],
			["a riposo"], etich, celle, TILE, TILE_H,
			"%s/%s.jpg" % [_dove.rstrip("/"), nome])


## LA PAROLA DOPPIA: la notte, la coda somatica, e il riposo.
func _lastra_doppia(vista: String, dist: float) -> void:
	await _posiziona(vista, dist)
	for _f in 30:
		_corpi[0].call("indossa_neuro", {"melatonina": GESTI.NOTTE_PIENA})
		await process_frame
	# la coda somatica alla sua forza tipica, dalla porta vera
	_corpi[1].call("somatico", 0.8)
	for _f2 in 12:
		await process_frame
	var img := await _scatta()
	var celle := {}
	for i in _corpi.size():
		celle[[0, i]] = _ritaglia(img, _cam.unproject_position(
				_corpi[i].global_position + Vector3(0, 0.42, 0)), TILE, TILE_H)
	await _foglio("la parola doppia · %s · %.0f m" % [vista, dist],
			["a confronto"],
			["LA NOTTE\n(melatonina piena)", "LA CODA SOMATICA\n(sussulto 0,8)",
			"a riposo"], celle, TILE, TILE_H,
			"%s/doppia_%s_%.0fm.jpg" % [_dove.rstrip("/"), vista, dist])
	for v in _corpi:
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)
		v.set("_gs_notte", 0.0)
		v.set("_notte_mel", 0.0)


func _scatta() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()


func _ritaglia(img: Image, centro: Vector2, w: int, h: int) -> Image:
	var r := Rect2i(Vector2i(int(centro.x) - w / 2, int(centro.y) - h / 2),
			Vector2i(w, h))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.06, 0.06, 0.07))
	var dentro := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if dentro.size.x > 4 and dentro.size.y > 4:
		var pezzo := img.get_region(dentro)
		pezzo.convert(Image.FORMAT_RGBA8)
		out.blit_rect(pezzo, Rect2i(Vector2i.ZERO, pezzo.get_size()),
				dentro.position - r.position)
	return out


func _testo(s: String, w: int, h: int, dim := 17) -> Image:
	var k := "%s|%d|%d|%d" % [s, w, h, dim]
	if _cache.has(k):
		return _cache[k]
	if _vp == null:
		_vp = SubViewport.new()
		_vp.transparent_bg = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_lab = Label.new()
		_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vp.add_child(_lab)
		get_root().add_child(_vp)
	_vp.size = Vector2i(w, h)
	_lab.size = Vector2(w, h)
	_lab.position = Vector2.ZERO
	_lab.text = s
	_lab.add_theme_font_size_override("font_size", dim)
	_lab.add_theme_color_override("font_color", Color(1, 1, 1))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	_cache[k] = img
	return img


func _foglio(titolo: String, righe: Array, colonne: Array, celle: Dictionary,
		tw: int, th: int, percorso: String) -> void:
	var LM := 90
	var TT := 44
	var TM := 52
	var W := LM + colonne.size() * tw
	var H := TT + TM + righe.size() * th
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.12, 1.0))
	var t := await _testo(titolo, W - 10, TT - 8, 21)
	img.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(5, 4))
	for c in colonne.size():
		var tc := await _testo(str(colonne[c]), tw - 6, TM - 8, 15)
		img.blend_rect(tc, Rect2i(Vector2i.ZERO, tc.get_size()),
				Vector2i(LM + c * tw + 3, TT + 4))
	for r in righe.size():
		var tr := await _testo(str(righe[r]), LM - 8, th, 17)
		img.blend_rect(tr, Rect2i(Vector2i.ZERO, tr.get_size()),
				Vector2i(4, TT + TM + r * th))
		for c2 in colonne.size():
			if not celle.has([r, c2]):
				continue
			var cel: Image = celle[[r, c2]]
			cel.convert(Image.FORMAT_RGBA8)
			img.blit_rect(cel, Rect2i(Vector2i.ZERO, cel.get_size()),
					Vector2i(LM + c2 * tw, TT + TM + r * th))
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(percorso, 0.95)
	print("   → %s   (%dx%d)" % [percorso, W, H])
