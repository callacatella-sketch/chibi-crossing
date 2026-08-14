extends SceneTree
## IL PROVINO DELLE DUE METÀ — e della rampa dei livelli.
##
##   CHIBI_ASIM=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_asimmetrie.gd
##
##   CHIBI_PARTI=RLCV   # Raccolto · Largo · Coda · rampa dei liVelli
##   CHIBI_VISTE=trequarti,fronte
##
## Quattro numeri non si scelgono a tavolino, e `misura_asimmetrie` sa dire
## soltanto **se** le due metà sono sullo stesso filo — non se il risultato
## sembra un corpo. Qui si guarda, con le varianti affiancate e l'etichetta
## addosso: scegliere fra due immagini che si somigliano SENZA l'etichetta è
## peggio che non guardare, perché si sceglie e si crede di aver scelto.
##
## Le regole di ripresa sono quelle già pagate da `provino_vocabolario`:
##
##  1. **Il MONDO VERO** e la **CAMERA VERA** (incollata a Mochi, 2,70 m
##     sopra e 3,70 dietro): un braccio che si legge da un metro dal muso
##     risponde a una domanda che nessun giocatore si fa.
##  2. **DA VICINO, e lo dice il file che si sta curando**: braccia e
##     orecchie sono canali di PROSSIMITÀ (≤ 4 m, dichiarato in `Gesti`).
##     Giudicarli a nove metri vorrebbe dire bocciarli tutti.
##  3. **UNA PELLICOLA, non una posa.** Un'asimmetria di TEMPO in un
##     fotogramma solo **non esiste per definizione** — è la differenza fra
##     due istanti. Questa è la ragione per cui il difetto era passato.
##  4. **IL RALLENTATORE** (`Engine.time_scale`), o l'istante a 0,18 s
##     dall'inizio non esiste.
##  5. **DI TRE QUARTI E DI FRONTE.** Di profilo un braccio copre l'altro:
##     la vista in cui il difetto è invisibile non è la vista in cui si
##     giudica la cura.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const SEME := 7331
## 0° = il muso guarda VIA dalla camera, 180° = in faccia.
const AZIMUT := {"fronte": 180.0, "trequarti": 135.0, "spalle": 0.0}
const DIST := 2.6            # dove sta il vicino più vicino
const OFF_ANG := 0.42        # di quanto Mochi sta di lato (o copre tutto)
const TILE := 300
## Quanto mondo entra in una tessera, e a che altezza è centrata. DUE
## inquadrature per gesto: il CORPO (le braccia si giudicano sul corpo, o non
## si sa nemmeno di chi sono) e la TESTA (due orecchie a 300 pixel di
## corpo intero sono venti pixel — cioè la misura in cui il difetto era
## invisibile).
const VISTA_CORPO := [0.98, 0.52]
const VISTA_TESTA := [1.02, 0.98]
const RALL := 0.30
const VEL_STIMA := 1.45

## LE VARIANTI. `mezza` è il secondo orologio (ritardo + costanti di tempo +
## tremolio), `quota` la differenza di ampiezza delle orecchie (c'era già),
## `quota_ax` quella delle braccia (è nuova). Servono tutte e tre: «com'è
## oggi» non è una coppia di valori.
const VARIANTI := [
	["A · com'è oggi\n(orecchie a due quote,\nbraccia identiche)",
		{"mezza": 0.0, "quota": 1.0, "quota_ax": 0.0}],
	["B · solo il TEMPO\n(stesse quote,\ndue orologi)",
		{"mezza": 1.0, "quota": 0.0, "quota_ax": 0.0}],
	["C · solo la QUOTA\n(due quote,\nun orologio solo)",
		{"mezza": 0.0, "quota": 1.0, "quota_ax": 1.0}],
	["D · LA CURA\n(tempo + quota)",
		{"mezza": 1.0, "quota": 1.0, "quota_ax": 1.0}],
	["E · forte ×1,7",
		{"mezza": 1.7, "quota": 1.5, "quota_ax": 1.5}],
]

## GLI ISTANTI STANNO TUTTI NELL'ATTACCO E NEL RILASCIO, e non è per
## risparmiare colonne: **è lì che vive un'asimmetria di tempo**. Dentro la
## tenuta le due metà sono per forza quasi ferme — una lastra fatta di
## istanti della tenuta mostrerebbe cinque righe identiche e farebbe
## concludere che la cura non serve.
const T_RACCOLTO := [0.08, 0.18, 0.30, 0.45, 0.70, 3.05, 3.35]
const T_LARGO := [0.06, 0.14, 0.24, 0.38, 0.60, 2.20, 2.50]
const T_CODA := [0.05, 0.50, 1.20, 2.00, 3.00, 4.20, 5.50, 7.00]
## La rampa dei livelli: l'istante 0 è quello in cui la scena si apre.
const T_RAMPA := [-0.10, 0.08, 0.20, 0.35, 0.55, 0.80, 1.20, 1.80]
const RAMPE := [0.25, 0.35, 0.55, 0.80, 1.10]

var _dove := ""
var _liv: Node = null
var _player: Node3D = null
var _visitors: Node = null
var _v: Node3D = null
var _cam: Camera3D = null
var _vp: SubViewport = null
var _lab: Label = null
var _cache := {}
var _fogli := 0
var _py := 0.0


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_ASIM")
	if _dove == "":
		_dove = "/tmp/asimmetrie"
	DirAccess.make_dir_recursive_absolute(_dove)
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "RLCV"
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
	# l'orologio si FERMA: un giorno dura quattro minuti, e a metà provino i
	# vicini andrebbero a dormire (scala 0,03, dentro casa, al buio)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	var hud := _liv.get_node_or_null("HUD")
	if hud != null:
		hud.set("visible", false)
	await create_timer(1.5).timeout
	_py = _player.global_position.y
	_cam = get_root().get_camera_3d()
	if _cam == null:
		print("GUASTO: nessuna camera — la GDExtension non si è caricata?")
		quit(1)
		return

	_v = VS.new()
	_v.set("species", "chibi")
	_v.set("dna", DNAG.generate(SEME))
	_visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 999999.0)
	await create_timer(0.5).timeout

	var viste: Array = ["trequarti", "fronte"]
	if OS.get_environment("CHIBI_VISTE") != "":
		viste = OS.get_environment("CHIBI_VISTE").split(",")

	if parti.contains("R"):
		await _lastra_evento("rinuncia", "IL RACCOLTO — «vorrei, e non lo faccio»",
				T_RACCOLTO, false, viste)
	if parti.contains("L"):
		await _lastra_evento("evitamento", "IL LARGO — «quel posto lì, no»",
				T_LARGO, true, viste)
	if parti.contains("C"):
		await _lastra_coda(viste)
	if parti.contains("V"):
		await _lastra_rampa(viste)
	print("\n  fogli: %d in %s" % [_fogli, _dove])
	quit(0)


# =========================================================================
# LE LASTRE
# =========================================================================

func _lastra_evento(frase: String, titolo: String, istanti: Array,
		cammina: bool, viste: Array) -> void:
	print("\n" + "█".repeat(70))
	print("  %s" % titolo)
	print("█".repeat(70))
	for vista: String in viste:
		for quadro: String in ["busto", "testa"]:
			var zoom: Array = VISTA_CORPO if quadro == "busto" else VISTA_TESTA
			var celle := {}
			var righe: Array = []
			for i in VARIANTI.size():
				righe.append(str((VARIANTI[i] as Array)[0]))
				var extra: Dictionary = ((VARIANTI[i] as Array)[1] as Dictionary).duplicate()
				var tiles: Array = await _presa(vista, cammina, istanti,
						func(): return bool(_v.call("frase", frase, extra)),
						Callable(), zoom)
				for c in tiles.size():
					celle[[i, c]] = tiles[c]
			var col: Array = []
			for t: float in istanti:
				col.append("t %+.2f" % t)
			await _foglio("%s   ·   %s a %.1f m — LE DUE METÀ (%s)"
					% [titolo, vista, DIST, quadro], righe, col, celle,
					"%s/%s_%s_%s.jpg" % [_dove, frase, vista, quadro])


func _lastra_coda(viste: Array) -> void:
	print("\n" + "█".repeat(70))
	print("  LA CODA SOMATICA — «sono ancora guardingo» (un LIVELLO)")
	print("█".repeat(70))
	# per un livello che dura otto secondi la domanda non è «le due metà
	# partono insieme» (non c'è nessuna partenza): è «dopo cinque secondi
	# quel corpo è ancora vivo o è un adesivo?»
	var quali := [
		["A · com'è oggi\n(due quote, ferme)", {"mezza": 0.0, "quota": 1.0, "quota_ax": 0.0}],
		["B · + tremolio\ne due τ", {"mezza": 1.0, "quota": 1.0, "quota_ax": 1.0,
				"scatto": 0.0}],
		["C · + LO SCATTO\ndell'orecchio", {"mezza": 1.0, "quota": 1.0, "quota_ax": 1.0}],
		["D · forte ×1,7", {"mezza": 1.7, "quota": 1.5, "quota_ax": 1.5}],
	]
	for vista: String in viste:
		for quadro: String in ["busto", "testa"]:
			var zoom: Array = VISTA_CORPO if quadro == "busto" else VISTA_TESTA
			var celle := {}
			var righe: Array = []
			for i in quali.size():
				righe.append(str((quali[i] as Array)[0]))
				var d: Dictionary = (quali[i] as Array)[1]
				var tiles: Array = await _presa(vista, false, T_CODA,
						func():
							_v.set("debug_gesti", d)
							_v.call("somatico", 1.0)
							return true, Callable(), zoom)
				for c in tiles.size():
					celle[[i, c]] = tiles[c]
			var col: Array = []
			for t: float in T_CODA:
				col.append("t %+.2f" % t)
			await _foglio("LA CODA SOMATICA   ·   %s a %.1f m — otto secondi di livello (%s)"
					% [vista, DIST, quadro], righe, col, celle,
					"%s/coda_%s_%s.jpg" % [_dove, vista, quadro])


func _lastra_rampa(viste: Array) -> void:
	print("\n" + "█".repeat(70))
	print("  LA RAMPA DEI LIVELLI — la scena scritta a mano si apre a t = 0")
	print("█".repeat(70))
	for vista: String in viste:
		var celle := {}
		var righe: Array = []
		for i in RAMPE.size():
			var r: float = RAMPE[i]
			righe.append("%.2f s%s" % [r, "\n(il gioco)"
					if absf(r - GESTI.LIVELLI_RAMPA) < 0.001 else ""])
			var tiles: Array = await _presa(vista, false, T_RAMPA,
					func():
						_v.set("debug_gesti", {"rampa": r})
						_v.call("somatico", 1.0)
						_v.call("capo_pende", true)
						return true,
					func(): _v.call("apri_scena", 6.0), VISTA_TESTA)
			for c in tiles.size():
				celle[[i, c]] = tiles[c]
		var col: Array = []
		for t: float in T_RAMPA:
			col.append("t %+.2f" % t)
		await _foglio("LA RAMPA DEI LIVELLI   ·   %s — il corpo passa di mano"
				% vista, righe, col, celle,
				"%s/rampa_%s.jpg" % [_dove, vista])
	_v.set("debug_gesti", {})


# =========================================================================
# LA PRESA
# =========================================================================

## Posa il corpo, accende quel che va acceso con `accendi` (che deve tornare
## `false` se il corpo si rifiuta: una presa buttata è un provino onesto), e
## scatta gli istanti. `dopo` è il gesto che si fa a t = 0 quando l'accensione
## è una PREMESSA e non l'evento (la rampa: prima il livello, poi la scena).
func _presa(vista: String, cammina: bool, istanti: Array, accendi: Callable,
		dopo := Callable(), zoom := VISTA_CORPO) -> Array:
	Engine.time_scale = 1.0
	_ripulisci()
	var ancora := Vector3.ZERO
	var lato := OFF_ANG * (DIST + 3.7)
	_player.global_position = Vector3(lato, _py, DIST)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	var dir := (ancora - cam_pos)
	var phi := atan2(dir.x, dir.z)
	var yaw := wrapf(phi + PI + deg_to_rad(float(AZIMUT[vista])), -PI, PI)
	var muso := Vector3(-sin(yaw), 0.0, -cos(yaw))
	if cammina:
		var pre := 0.9 + 0.35 + absf(float(istanti[0]))
		_v.global_position = ancora - muso * (VEL_STIMA * pre)
		_v.set("_yaw", yaw)
		_v.rotation.y = yaw
		_v.call("_walk_to", ancora + muso * 60.0, "r_idle")
	else:
		_v.global_position = ancora
		_v.set("_yaw", yaw)
		_v.rotation.y = yaw
		_v.call("_enter_state", "r_idle")
		_v.set("_timer", 999999.0)
	await create_timer(0.9).timeout

	# se c'è un `dopo`, l'accensione è la PREMESSA e va fatta prima del
	# pre-rullo: il livello deve essere già a regime quando la scena si apre
	if dopo.is_valid():
		if not accendi.call():
			return []
		await create_timer(1.2).timeout

	Engine.time_scale = RALL
	var out: Array = []
	var tg := float(istanti[0]) - 0.30
	var acceso := false
	var ms := Time.get_ticks_msec()
	var i := 0
	var fine := float(istanti[istanti.size() - 1]) + 0.05
	var guardia := 0
	while tg < fine and guardia < 9000:
		guardia += 1
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		_player.global_position = Vector3(lato, _py, DIST)
		tg += dt * Engine.time_scale
		if not acceso and tg >= 0.0:
			acceso = true
			if dopo.is_valid():
				dopo.call()
			elif not accendi.call():
				print("   ⚠ %s — IL CORPO HA DETTO DI NO" % vista)
				Engine.time_scale = 1.0
				return []
			tg = 0.0
		while i < istanti.size() and tg >= float(istanti[i]):
			var im := await _scatta()
			var centro: Vector3 = _v.global_position \
					+ Vector3(0, float(zoom[1]), 0)
			out.append(_ritaglia_m(im, centro, float(zoom[0])))
			i += 1
	Engine.time_scale = 1.0
	while out.size() < istanti.size():
		out.append(_vuota())
	_ripulisci()
	return out


func _ripulisci() -> void:
	_v.call("gesto_spegni", true)
	_v.call("capo_pende", false)
	_v.call("chiudi_scena")
	_v.set("_gs_soma", 0.0)
	_v.set("_gs_soma_t", 0.0)
	_v.set("_gs_capo_x", 0.0)
	_v.set("_gs_capo_v", 0.0)
	_v.set("_gs_liv", 1.0)
	_v.set("_tst_t", 0.0)
	_v.set("_gs_viaggio", false)
	_v.set("debug_gesti", {})


# =========================================================================
# GLI SCATTI, I RITAGLI E LE ETICHETTE
# =========================================================================

func _scatta() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()


## Il riquadro è di METRI FISSI attorno al corpo, riscalato alla tessera: due
## righe della stessa lastra sono confrontabili anche se il corpo non è
## esattamente dov'era.
func _ritaglia_m(img: Image, centro: Vector3, finestra: float) -> Image:
	var c := _cam.unproject_position(centro)
	var alto := _cam.unproject_position(centro + Vector3(0, 1.0, 0))
	var pxm := maxf(8.0, absf(c.y - alto.y))
	var lato := int(finestra * pxm)
	var t := _ritaglia(img, c, lato, lato)
	if t.get_width() != TILE:
		t.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
	return t


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


func _vuota() -> Image:
	var im := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.35, 0.05, 0.05))
	return im


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
		percorso: String) -> void:
	var LM := 200
	var TT := 46
	var TM := 40
	var W := LM + colonne.size() * TILE
	var H := TT + TM + righe.size() * TILE
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.12, 1.0))
	var t := await _testo(titolo, W - 10, TT - 8, 22)
	img.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(5, 4))
	for c in colonne.size():
		var tc := await _testo(str(colonne[c]), TILE - 6, TM - 8, 17)
		img.blend_rect(tc, Rect2i(Vector2i.ZERO, tc.get_size()),
				Vector2i(LM + c * TILE + 3, TT + 4))
	for r in righe.size():
		var tr := await _testo(str(righe[r]), LM - 8, TILE, 18)
		img.blend_rect(tr, Rect2i(Vector2i.ZERO, tr.get_size()),
				Vector2i(4, TT + TM + r * TILE))
		for c in colonne.size():
			if not celle.has([r, c]):
				continue
			var cel: Image = celle[[r, c]]
			cel.convert(Image.FORMAT_RGBA8)
			img.blit_rect(cel, Rect2i(Vector2i.ZERO, cel.get_size()),
					Vector2i(LM + c * TILE, TT + TM + r * TILE))
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(percorso, 0.95)
	_fogli += 1
	print("   → %s   (%dx%d)" % [percorso, W, H])
