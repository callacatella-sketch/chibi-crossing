extends SceneTree
## IL PROVINO DELL'AFFONDO — «il Capo si legge a due metri e non a nove».
##
##   CHIBI_AFFONDO=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_capo_affondo.gd
##
## Il rollio del capo è il LIVELLO che dice «ci sto pensando», e il suo
## difetto dichiarato è la distanza: sei gradi su una testona sono
## quattrocento pixel a due metri e sedici a nove.
##
## ⚠️ **LA CURA OVVIA È SBAGLIATA, ED È NELLA STESSA LASTRA.** Ingrandire il
## rollio compra rilevabilità e perde LEGGIBILITÀ (misurato: verso 1,74–1,86
## a 0,08 rad · 1,10–1,17 a 0,24), perché una rotazione attorno a un perno,
## crescendo, spazza regioni che si sovrappongono sempre di più alla sagoma
## di partenza. La strada giusta è un'altra grandezza: la SAGOMA — la testa
## che scende fra le spalle e chiude la tacca del collo.
##
## Qui si GUARDA, che è l'unica cosa che i numeri non fanno. Tre lastre:
##
##   I    LE PROFONDITÀ — sette varianti etichettate, a 2 · 6 · 9 metri
##   II   I QUATTRO AZIMUT a nove metri (di spalle un vicino si guarda il
##        49,6% delle volte, ed è lì che i gesti muoiono)
##   III  IL TRASFERIMENTO — la pellicola vera della molla, col tuffo:
##        passando da una parte all'altra il capo risale e riscende, e a
##        nove metri quello si vede quando il rollio no
##
## ⚠️ **LA CAMERA È QUELLA DEL GIOCO** (incollata a Mochi, 2,70 sopra e 3,70
## dietro, fov 50, nessuna imbardata) e **il riquadro è di PIXEL FISSI**: a
## nove metri il chibi deve restare cinquanta pixel, che è quello che vede
## chi gioca. Un ritaglio che scala col corpo mostrerebbe un gesto leggibile
## a nove metri che nella partita non esiste.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const SEME := 7331
const DISTANZE := [2.0, 6.0, 9.0]
## 0° = il muso guarda VIA dalla camera (le spalle), 180° = in faccia.
const AZIMUT := {"fronte": 180.0, "trequarti": 135.0, "profilo": 90.0,
		"spalle": 0.0}
## Di quanto sta di lato il vicino, in frazione della distanza dalla camera:
## così sta sempre nello stesso punto dello schermo, e fuori dalla testona
## di Mochi.
const OFF_ANG := 0.42
const TILE := 210

var _dove := ""
var _player: Node3D = null
var _v: Node3D = null
var _py := 0.0
var _vp: SubViewport = null
var _lab: Label = null
var _cache := {}


func _init() -> void:
	_go()


# ------------------------------------------------------------- le varianti

## Le sette pose, e ognuna è una domanda diversa. `hz` al colmo del
## trasferimento (l'ampiezza massima che la molla raggiunge davvero).
func _varianti() -> Array:
	var out := []
	out.append(["riposo", GESTI.riposo()])
	var oggi := GESTI.riposo()
	oggi["hz"] = GESTI.CAPO_AMP_MAX
	out.append(["CAPO com'era\n(rollio 6°)", oggi])
	for gr: float in [0.18, 0.24]:
		var c := GESTI.riposo()
		c["hz"] = gr
		out.append(["la strada SBAGLIATA\nrollio %.0f°" % rad_to_deg(gr), c])
	for aff: float in [0.02, 0.035, 0.05, 0.07]:
		var c2 := GESTI.riposo()
		c2["hz"] = GESTI.CAPO_AMP_MAX
		c2["hpy"] = -aff
		out.append(["+ affondo %.1f cm" % (aff * 100.0), c2])
	# e la somma che il gioco può produrre davvero: il capo storto SOPRA la
	# coda somatica, che affonda già di suo (−2,5 cm). Se qui la testa entra
	# nelle spalle, il numero è sbagliato — ed è una cosa che nessun conto
	# dice e una foto sì.
	var somma := GESTI.riposo()
	somma["hz"] = GESTI.CAPO_AMP_MAX
	somma["hpy"] = GESTI.capo_affondo(GESTI.CAPO_AMP_MAX) - 0.025
	somma["ear"] = -0.20
	out.append(["affondo %.1f + coda somatica"
			% (-GESTI.capo_affondo(GESTI.CAPO_AMP_MAX) * 100.0), somma])
	return out


# ------------------------------------------------------------- il ritaglio

func _cam() -> Camera3D:
	return get_root().get_camera_3d()


func _scatta() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()


## Un riquadro di PIXEL FISSI centrato sul corpo. Il centro si prende dalla
## proiezione del petto, non dal centro dello schermo: a due metri e a nove
## il corpo sta in punti diversi.
func _tessera(img: Image, px: int) -> Image:
	var c := _cam().unproject_position(_v.global_position + Vector3(0, 0.62, 0))
	var r := Rect2i(Vector2i(int(c.x) - px / 2, int(c.y) - px / 2),
			Vector2i(px, px))
	var w := img.get_width()
	var h := img.get_height()
	r.position.x = clampi(r.position.x, 0, maxi(0, w - px))
	r.position.y = clampi(r.position.y, 0, maxi(0, h - px))
	return img.get_region(r.intersection(Rect2i(Vector2i.ZERO, Vector2i(w, h))))


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
	var LM := 190
	var TT := 46
	var TM := 46
	var W := LM + colonne.size() * tw
	var H := TT + TM + righe.size() * th
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.12, 1.0))
	var t := await _testo(titolo, W - 10, TT - 8, 21)
	img.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(5, 4))
	for c in colonne.size():
		var tc := await _testo(str(colonne[c]), tw - 6, TM - 8, 16)
		img.blend_rect(tc, Rect2i(Vector2i.ZERO, tc.get_size()),
				Vector2i(LM + c * tw + 3, TT + 4))
	for r in righe.size():
		var tr := await _testo(str(righe[r]), LM - 8, th, 17)
		img.blend_rect(tr, Rect2i(Vector2i.ZERO, tr.get_size()),
				Vector2i(4, TT + TM + r * th))
		for c in colonne.size():
			if not celle.has([r, c]):
				continue
			var cel: Image = celle[[r, c]]
			cel.convert(Image.FORMAT_RGBA8)
			img.blit_rect(cel, Rect2i(Vector2i.ZERO, cel.get_size()),
					Vector2i(LM + c * tw, TT + TM + r * th))
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(percorso, 0.95)
	print("   → %s   (%dx%d)" % [percorso, W, H])


# ------------------------------------------------------------------ scena

func _posa_corpo(vista: String, dist: float) -> void:
	var lato := OFF_ANG * (dist + 3.7)
	_player.global_position = Vector3(lato, _py, dist)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	# L'AZIMUT SI CALCOLA: «di profilo» rispetto alla camera NON è yaw 90°,
	# e sbagliarlo di dieci gradi porta via proprio la colonna che si misura.
	var dir := (Vector3.ZERO - cam_pos)
	var phi := atan2(dir.x, dir.z)
	var yaw := wrapf(phi + PI + deg_to_rad(float(AZIMUT[vista])), -PI, PI)
	_v.global_position = Vector3.ZERO
	_v.set("_yaw", yaw)
	_v.rotation.y = yaw


func _go() -> void:
	_dove = OS.get_environment("CHIBI_AFFONDO")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	var visitors := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	var hud := liv.get_node_or_null("HUD")
	if _player == null or visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	# l'orologio si ferma: la luce non deve cambiare fra una variante e
	# l'altra, o si confronta l'ora invece del gesto
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	if hud != null:
		hud.set("visible", false)
	await create_timer(1.5).timeout
	_py = _player.global_position.y

	_v = VS.new()
	_v.set("species", "chibi")
	_v.set("dna", DNAG.generate(SEME))
	visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 999999.0)
	await create_timer(0.6).timeout

	# CHIBI_PARTI sceglie le lastre: "1" le profondità · "2" gli azimut ·
	# "3" il trasferimento. Quando si sta tarando UNA cosa non si rifanno le
	# altre due.
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "123"
	if parti.contains("1"):
		await _le_profondita()
	if parti.contains("2"):
		await _gli_azimut()
	if parti.contains("3"):
		await _il_trasferimento()
	quit(0)


# =========================================================================
# I · LE PROFONDITÀ — sette varianti, tre distanze
# =========================================================================

func _le_profondita() -> void:
	print("\n  ── I · le profondità, vista di tre quarti ──")
	# il corpo si ferma: le pose si confrontano ferme, o si misura il respiro
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame
	var varianti := _varianti()
	var celle := {}
	var righe: Array = []
	for i in varianti.size():
		righe.append(str((varianti[i] as Array)[0]))
	var colonne: Array = []
	for dist: float in DISTANZE:
		colonne.append("%.0f m" % dist)
	for c in DISTANZE.size():
		_posa_corpo("trequarti", float(DISTANZE[c]))
		for _i in 3:
			await process_frame
		for r in varianti.size():
			_v.call("debug_posa", ((varianti[r] as Array)[1] as Dictionary))
			_v.force_update_transform()
			for _i in 2:
				await process_frame
			var img := await _scatta()
			celle[[r, c]] = _tessera(img, TILE)
	_v.call("debug_posa", GESTI.riposo())
	Engine.time_scale = 1.0
	_v.set_process(true)
	if _dove == "":
		return
	await _foglio("L'AFFONDO DEL CAPO — sette varianti, vista di tre quarti, "
			+ "riquadro di pixel FISSI (quello che vede chi gioca)",
			righe, colonne, celle, TILE, TILE,
			"%s/I_profondita.jpg" % _dove)


# =========================================================================
# II · I QUATTRO AZIMUT a nove metri
# =========================================================================

func _gli_azimut() -> void:
	print("\n  ── II · i quattro azimut a nove metri ──")
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame
	var varianti := _varianti()
	var celle := {}
	var righe: Array = []
	for i in varianti.size():
		righe.append(str((varianti[i] as Array)[0]))
	var colonne: Array = []
	var c := 0
	for vista in AZIMUT:
		colonne.append(str(vista))
		_posa_corpo(str(vista), 9.0)
		for _i in 3:
			await process_frame
		for r in varianti.size():
			_v.call("debug_posa", ((varianti[r] as Array)[1] as Dictionary))
			_v.force_update_transform()
			for _i in 2:
				await process_frame
			var img := await _scatta()
			celle[[r, c]] = _tessera(img, 150)
		c += 1
	_v.call("debug_posa", GESTI.riposo())
	Engine.time_scale = 1.0
	_v.set_process(true)
	if _dove == "":
		return
	await _foglio("L'AFFONDO A NOVE METRI — i quattro azimut "
			+ "(di spalle un vicino si guarda il 49,6% delle volte)",
			righe, colonne, celle, 150, 150, "%s/II_azimut.jpg" % _dove)


# =========================================================================
# III · IL TRASFERIMENTO — la molla vera, col tuffo
# =========================================================================
#
# ⚠️ **UNA LASTRA DI POSE NON PUÒ GIUDICARE UN EVENTO.** Il rollio è una
# sequenza di TRASFERIMENTI: fra l'uno e l'altro non succede niente, ed è
# l'immobilità a rendere leggibile il trasferimento. L'affondo ci mette
# dentro un TUFFO — passando da una parte all'altra la testa risale (il
# quadrato normalizzato passa per lo zero) e riscende — e quello è ciò che
# a nove metri si vede quando il rollio non si vede più.
#
# Qui non si posa niente a mano: si accende il livello VERO (`capo_pende`) e
# si fotografa la molla mentre gira, al rallentatore.

const TR_T := [-0.12, 0.0, 0.08, 0.16, 0.24, 0.34, 0.50, 0.80]
const RALL := 0.30


## ⚠️ **IL TUFFO NON STA NEL PRIMO TRASFERIMENTO, e la prima stesura di
## questa scena l'ha mancato.** Acceso il livello, il capo va da zero a un
## lato: non attraversa niente, e la sagoma scende e basta. Il tuffo è nel
## trasferimento SUCCESSIVO — da un lato all'altro — dove la molla passa per
## il dritto e la testa risale prima di riscendere. Bisogna aspettarlo (4,5–9
## secondi), e si riconosce dal bersaglio della molla che cambia segno.
func _aspetta_il_giro() -> bool:
	var b0 := signf(float(_v.get("_gs_capo_b")))
	var guardia := 0
	while guardia < 20000:
		guardia += 1
		await process_frame
		var b := signf(float(_v.get("_gs_capo_b")))
		if b != 0.0 and b0 != 0.0 and b != b0:
			return true
		if b0 == 0.0:
			b0 = b
	return false


func _il_trasferimento() -> void:
	print("\n  ── III · il trasferimento vero (la molla, al rallentatore) ──")
	var celle := {}
	var righe: Array = []
	var r := 0
	for dist: float in [2.0, 9.0]:
		righe.append("%.0f m" % dist)
		_posa_corpo("trequarti", dist)
		_v.call("capo_pende", false)
		for _i in 6:
			await process_frame
		await create_timer(0.6).timeout
		_v.call("capo_pende", true)
		# si aspetta che la molla si sia posata da una parte…
		await create_timer(1.2).timeout
		# …e poi IL GIRO: il bersaglio cambia segno, e da lì si filma
		Engine.time_scale = RALL
		if not await _aspetta_il_giro():
			print("    (nessun trasferimento in tempo utile)")
			Engine.time_scale = 1.0
			continue
		var t := float(TR_T[0])
		var ms := Time.get_ticks_msec()
		var i := 0
		var guardia := 0
		var traccia: Array = []
		while i < TR_T.size() and guardia < 8000:
			guardia += 1
			await process_frame
			var ora := Time.get_ticks_msec()
			var dt := float(ora - ms) / 1000.0
			ms = ora
			if dt <= 0.0 or dt > 0.5:
				continue
			t += dt * Engine.time_scale
			var x := float(_v.get("_gs_capo_x"))
			traccia.append([t, x, GESTI.capo_affondo(x)])
			while i < TR_T.size() and t >= float(TR_T[i]):
				var img := await _scatta()
				# riquadro di PIXEL FISSI anche qui: a nove metri il corpo deve
				# restare piccolo, o si giudica un ingrandimento
				celle[[r, i]] = _tessera(img, 260)
				ms = Time.get_ticks_msec()
				i += 1
		Engine.time_scale = 1.0
		_v.call("capo_pende", false)
		# LA TRACCIA NUMERICA: senza, «la testa risale» resta un'opinione su
		# otto tessere piccole. Qui si legge il rollio e la quota della testa
		# fotogramma per fotogramma, ed è il tuffo scritto in cifre.
		if dist > 5.0:
			print("    la traccia del giro (t · rollio rad · quota testa m):")
			var passo := maxi(1, traccia.size() / 22)
			var k := 0
			for riga in traccia:
				if k % passo == 0:
					print("      t %+0.3f   rollio %+0.4f   testa %+0.4f"
							% [float((riga as Array)[0]), float((riga as Array)[1]),
							float((riga as Array)[2])])
				k += 1
		r += 1
	if _dove == "":
		return
	var colonne: Array = []
	for x: float in TR_T:
		colonne.append("t %.2f" % x)
	await _foglio("IL TRASFERIMENTO — la molla VERA dal riposo al colmo "
			+ "(rallentatore 0,30; la riga di sopra è il dettaglio, quella di "
			+ "sotto è quello che vede chi gioca)",
			righe, colonne, celle, 260, 260, "%s/III_trasferimento.jpg" % _dove)
