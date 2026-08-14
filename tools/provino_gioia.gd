extends SceneTree
## «SI ILLUMINA» — la gioia, con la coda guardinga addosso e senza.
##
##   CHIBI_GIOIA=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_gioia.gd
##
## ⚠️ **NON --headless: qui si GUARDA.** La suite non dice niente su questo, e
## il numero da solo nemmeno: «orecchie +0,164 invece di −0,045» è un segno
## che cambia, e cosa voglia dire quel segno lo decide l'occhio.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ TRE CORPI E NON DUE CORSE
## ────────────────────────────────────────────────────────────────────────
##
## Due corse dello stesso provino sono due villaggi: luce diversa, fotogramma
## diverso, fase del respiro diversa — e la differenza misurata non è più
## della cosa che si sta provando. Qui i tre corpi hanno **lo stesso genoma,
## la stessa imbardata, la stessa distanza dalla camera, e stanno nello
## STESSO FOTOGRAMMA**:
##
##   A · IERI     la posa della gioia + la coda somatica accesa
##   B · OGGI     la posa della gioia, e basta
##   C · a riposo il termine di paragone muto
##
## Il corpo A rifà il cablaggio di ieri con **le stesse due chiamate di
## produzione, nello stesso ordine** in cui `Visitors._tick_sussulti` le
## faceva (`somatico(forza)` e poi il meta della postura): non c'è nessuna
## posa scritta a mano, e la forza non è inventata — esce da un `Limbico`
## VERO a cui è stato voluto bene sei volte, dalla porta vera (`rivaluta`
## su «incontro», che è quella che chiama `_tick_riconoscimenti`).
##
## ────────────────────────────────────────────────────────────────────────
## LE REGOLE DI RIPRESA sono quelle di `provino_vocabolario`
## ────────────────────────────────────────────────────────────────────────
##
## 1. **La camera è quella vera** (2,70 m sopra Mochi, 3,70 dietro, fov 50,
##    nessuna imbardata): una macchina piazzata a un metro dal muso risponde
##    a una domanda che nessun giocatore si fa.
## 2. **La distanza è quella del cuoricino**: `_tick_sussulti` non guarda
##    nessuno oltre 3,2 m, quindi questa scena si vede da lì e da nessun
##    altro posto.
## 3. **L'azimut si calcola** fra «camera → corpo» e il muso, non si scrive.
## 4. **Il tempo si rallenta** (`Engine.time_scale`), o l'istante del
##    cuoricino — 0,17 s — a venticinque fotogrammi al secondo non esiste.
## 5. **Il ritaglio è di pixel FISSI**: il corpo è grande quanto è grande.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

const SEME := 7331
## ⚠️ **LA FORZA DI IERI È UNA MISURA, e va scritta qui perché oggi non
## esiste più.** La prima stesura di questo provino la chiedeva al `Limbico`
## vivo — e dopo la cura si è messa a rispondere **0,000**, perché una gioia
## non ha forza d'allarme: il corpo A riceveva `somatico(0)`, cioè niente, e
## la lastra mostrava due corpi identici. Un provino che chiede al codice
## curato di rifare il difetto misura la cura, non il difetto.
##
## Questo numero l'ha misurato `Limbico.percepisci` PRIMA della cura, su un
## amico dopo sei «incontro» a 0,55 e un arrivo tranquillo — cioè la stessa
## scena che questa lastra mette in fila. Gli ingredienti si leggono ancora
## oggi, e il provino li stampa: carica 0,509 · reattività 0,875 · arousal
## 0,580 (che la gioia si era pompata da sola) → (0,509 + 0) × 0,875 × 1,348.
const FORZA_DI_IERI := 0.600
## Gli istanti della posa. `si_illumina` dura 1,8 s e il suo inviluppo sale
## in 0,22: 0,17 è il cuoricino appena partito, 0,45 il colmo.
const ISTANTI := [0.0, 0.17, 0.45, 0.90, 1.40]
## 0° = il muso guarda VIA dalla camera, 180° = in faccia.
const AZIMUT := {"trequarti": 135.0, "fronte": 180.0, "profilo": 90.0}
const DIST := 3.2        # il raggio del sussulto: più in là non succede
const PASSO := 1.15      # quanto stanno distanti i tre corpi
const TILE := 260
const RALL := 0.30

var _dove := ""
var _liv: Node = null
var _player: Node3D = null
var _visitors: Node = null
var _cam: Camera3D = null
var _corpi: Array[Node3D] = []
var _vp: SubViewport = null
var _lab: Label = null
var _cache := {}
var _py := 0.0
var _forza := 0.0
var _log: Array = []


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_GIOIA")
	if _dove == "":
		_dove = "/tmp/gioia"
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
	var hud := _liv.get_node_or_null("HUD")
	if _player == null or _visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	if hud != null:
		hud.set("visible", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout
	_py = _player.global_position.y
	_cam = get_root().get_camera_3d()
	if _cam == null:
		print("GUASTO: nessuna camera — la GDExtension non si e' caricata?")
		quit(1)
		return

	_forza_di_un_amico()
	_forza = FORZA_DI_IERI
	print("")
	print("█".repeat(72))
	print("LA GIOIA, CON LA CODA ADDOSSO E SENZA")
	print("  la forza che il cablaggio di IERI passava a `somatico`: %.3f" % _forza)
	print("  a quella forza la coda scrive orecchie %+.3f rad (GIÙ) contro"
			% float(GESTI.coda_canali(GESTI.coda_ampiezza(_forza, 0.0), 0.0, 0.0)["ear"])
			+ " una posa che le vuole a −0,600 (SU)")
	print("█".repeat(72))

	for i in 3:
		var v := VS.new()
		v.set("species", "chibi")
		v.set("dna", DNAG.generate(SEME))
		_visitors.add_child(v)
		v.set("greet_enabled", false)
		_corpi.append(v)
	await create_timer(1.2).timeout
	for v in _corpi:
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
	await create_timer(0.6).timeout

	for vista in AZIMUT:
		await _lastra(str(vista))
	for vista in ["trequarti", "profilo"]:
		await _lastra_sollievo(str(vista))
	print("")
	print("LA PELLICOLA, fotogramma per fotogramma (ear applicato al rig):")
	for r in _log:
		print("  " + str(r))
	print("")
	print("  scatti in %s" % _dove)
	quit(0)


## LA FORZA NON SI INVENTA. Sei riconoscimenti veri — è la porta che
## `Visitors._tick_riconoscimenti` usa per chi ti vuole bene (`friend >= 3`
## vale 0,55) — e poi la stessa `percepisci` del gioco, con l'arrivo
## TRANQUILLO che è la condizione di `si_illumina`.
func _forza_di_un_amico() -> void:
	var l = LIMBICO.new()
	l.setup({})
	for _i in 6:
		l.rivaluta("incontro", "giocatore", 0.55)
	var s: Dictionary = l.percepisci("giocatore", "", 0.0)
	print("  IL LIMBICO DI OGGI, sulla stessa scena: %s · carica %.3f ·"
			% [str(s.get("reazione", "")), float(s.get("carica", 0.0))]
			+ " reattività %.3f · arousal %.3f · corpo «%s»"
			% [l.reattivita, l.arousal, str(l.stato_corpo())])
	print("    forza d'allarme %.3f · calore %.3f   (ieri, con una moneta"
			% [float(s.get("forza", 0.0)), float(s.get("calore", 0.0))]
			+ " sola, era %.3f — ed è quella che accendeva la coda)" % FORZA_DI_IERI)


func _lastra(vista: String) -> void:
	# 1) DOVE STANNO I CORPI. In fila, e Mochi davanti a quello di mezzo: la
	#    camera del gioco è dietro di lei, quindi l'inquadratura è quella che
	#    si ha andando da qualcuno.
	var centro := Vector3.ZERO
	_player.global_position = Vector3(0.0, _py, DIST)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	var dir := centro - cam_pos
	var phi := atan2(dir.x, dir.z)
	var yaw := wrapf(phi + PI + deg_to_rad(float(AZIMUT[vista])), -PI, PI)
	for i in _corpi.size():
		var v := _corpi[i]
		v.global_position = centro + Vector3((float(i) - 1.0) * PASSO, 0.0, 0.0)
		v.set("_yaw", yaw)
		v.rotation.y = yaw
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)
		v.set_meta("postura", "sereno")
	await create_timer(0.8).timeout

	# 2) LO SCATTO. Il rallentatore, e poi i due corpi si accendono nello
	#    STESSO fotogramma con le porte vere.
	Engine.time_scale = RALL
	# A · IERI: le stesse due chiamate, nello stesso ordine di
	# `Visitors._tick_sussulti` (la riga 2681 e poi il ramo del match)
	_corpi[0].call("somatico", _forza)
	_corpi[0].set_meta("postura", "si_illumina")
	_corpi[0].call("chat_bubble", "♥")
	# B · OGGI: solo la gioia
	_corpi[1].set_meta("postura", "si_illumina")
	_corpi[1].call("chat_bubble", "♥")

	var celle := {}
	var righe: Array = []
	var t := 0.0
	var i := 0
	var ms := Time.get_ticks_msec()
	var guardia := 0
	while i < ISTANTI.size() and guardia < 4000:
		guardia += 1
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt * Engine.time_scale
		if t < float(ISTANTI[i]):
			continue
		var img := await _scatta()
		for c in _corpi.size():
			celle[[i, c]] = _ritaglia(img, _cam.unproject_position(
					_corpi[c].global_position + Vector3(0, 0.52, 0)), TILE, TILE)
		righe.append("%.2f s" % float(ISTANTI[i]))
		_log.append("%-9s t=%.2f  A ear=%+.4f (coda %.3f)   B ear=%+.4f   C ear=%+.4f"
				% [vista, float(ISTANTI[i]),
				_ear(_corpi[0]), GESTI.coda_ampiezza(float(_corpi[0].get("_gs_soma")),
						float(_corpi[0].get("_gs_soma_t"))),
				_ear(_corpi[1]), _ear(_corpi[2])])
		i += 1
	Engine.time_scale = 1.0

	await _foglio("«si illumina» · %s · la forza dell'amico e' %.3f"
			% [vista, _forza],
			righe, ["A · IERI (posa + coda)", "B · OGGI (solo la posa)",
			"C · a riposo"], celle, TILE, TILE,
			"%s/gioia_%s.jpg" % [_dove.rstrip("/"), vista])
	for v in _corpi:
		v.set_meta("postura", "sereno")
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)
	await create_timer(0.5).timeout


## LA SECONDA LASTRA: «AH… SEI TU», cioè il momento in cui il corpo MOLLA.
##
## Stessa aritmetica del confronto di sopra e stessa scena: tutti e tre
## sussultano davvero (`somatico`, la porta di `_tick_sussulti`), e quattro
## decimi di secondo dopo — `Visitors.ATTESA_RICONOSCIMENTO`, la strada lenta
## — a UNO solo arriva il riconoscimento. Gli altri due restano guardinghi,
## che è quello che facevano tutti prima.
##
##   A · riconosciuto   il Rialzo del sollievo, e la coda che si scioglie
##   B · nessuno l'ha riconosciuto (com'era per tutti)
##   C · a riposo
const SOLL_ISTANTI := [0.0, 0.12, 0.30, 0.55, 1.10]


func _lastra_sollievo(vista: String) -> void:
	var centro := Vector3.ZERO
	_player.global_position = Vector3(0.0, _py, DIST)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	var dir := centro - cam_pos
	var yaw := wrapf(atan2(dir.x, dir.z) + PI + deg_to_rad(float(AZIMUT[vista])),
			-PI, PI)
	for i in _corpi.size():
		var v := _corpi[i]
		v.global_position = centro + Vector3((float(i) - 1.0) * PASSO, 0.0, 0.0)
		v.set("_yaw", yaw)
		v.rotation.y = yaw
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)
		v.set_meta("postura", "sereno")
	await create_timer(0.8).timeout
	# IL SUSSULTO, per tutti e due. `0.8` è la forza di uno spavento vero
	# (`Limbico` su uno sconosciuto che ti arriva addosso di corsa nel buio).
	_corpi[0].call("somatico", 0.8)
	_corpi[1].call("somatico", 0.8)
	Engine.time_scale = RALL
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var partito := false
	var celle := {}
	var righe: Array = []
	var i := 0
	var guardia := 0
	while i < SOLL_ISTANTI.size() and guardia < 4000:
		guardia += 1
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt * Engine.time_scale
		if not partito:
			if t < 0.4:
				continue           # `ATTESA_RICONOSCIMENTO`
			partito = true
			# LA PORTA VERA: se il corpo dicesse di no, la lastra lo direbbe
			var ok: bool = bool(_corpi[0].call("frase", "sollievo"))
			_corpi[0].set_meta("postura", "si_illumina")
			_corpi[0].call("chat_bubble", "♥")
			print("  il sollievo è partito? %s  (in scena: %s)"
					% [str(ok), str(_corpi[0].call("in_scena"))])
			t = 0.0
		if t < float(SOLL_ISTANTI[i]):
			continue
		var img := await _scatta()
		for c in _corpi.size():
			celle[[i, c]] = _ritaglia(img, _cam.unproject_position(
					_corpi[c].global_position + Vector3(0, 0.52, 0)), TILE, TILE)
		righe.append("%.2f s" % float(SOLL_ISTANTI[i]))
		_log.append("SOLLIEVO %-9s t=%.2f  A ear=%+.4f soma=%.3f   B ear=%+.4f soma=%.3f"
				% [vista, float(SOLL_ISTANTI[i]), _ear(_corpi[0]),
				float(_corpi[0].get("_gs_soma")), _ear(_corpi[1]),
				float(_corpi[1].get("_gs_soma"))])
		i += 1
	Engine.time_scale = 1.0
	await _foglio("«ah… sei tu» · %s · il corpo MOLLA la coda guardinga" % vista,
			righe, ["A · riconosciuto", "B · ancora guardingo", "C · a riposo"],
			celle, TILE, TILE, "%s/sollievo_%s.jpg" % [_dove.rstrip("/"), vista])
	for v in _corpi:
		v.set_meta("postura", "sereno")
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)
	await create_timer(0.5).timeout


## Quello che è ARRIVATO al rig, non quello che qualcuno ha chiesto.
func _ear(v: Node3D) -> float:
	var appl: Dictionary = v.get("_rc_appl")
	return float(appl.get("ear", 0.0))


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
	var LM := 110
	var TT := 44
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
		var tr := await _testo(str(righe[r]), LM - 8, th, 18)
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
