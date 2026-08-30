extends SceneTree
## IL CARATTERE ADDOSSO A UN CORPO — e la deriva, guardata invece che contata.
##
##   CHIBI_CAR=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_carattere.gd
##
## ⚠️ **NON --headless: qui si GUARDA.** La deriva è stata misurata (δ fino a
## 0,25 di tratto) e non è mai stata vista: un tratto che si muove e non si
## vede addosso a nessuno non è un tratto che deriva, è un numero che cambia.
##
## ────────────────────────────────────────────────────────────────────────
## LA DOMANDA, in due lastre
## ────────────────────────────────────────────────────────────────────────
##
## 1. **IL CARATTERE.** Cinque corpi con lo STESSO genoma, la stessa imbardata,
##    la stessa distanza, nello stesso fotogramma, che differiscono per una
##    cosa sola: la codardia (0,15 · 0,35 · 0,50 · 0,70 · 0,90 — gli estremi
##    che il generatore produce davvero). Un codardo si vede che è un codardo?
## 2. **LA DERIVA.** Due corpi: la stessa persona com'è nata e dopo una
##    stagione di gentilezza. I due numeri non sono inventati — sono quelli
##    che `misura_deriva_vera` ha letto su un residente vero (Cannella,
##    `0,724 → 0,534`), e la lealtà quelli di `misura_insieme` (`0,386 →
##    0,631`). Si vede che quella persona è cambiata?
##
## ⚠️ **E LA CATENA È QUELLA VERA, dal tratto al pixel.** Nessun canale del
## rig è scritto a mano: si costruisce un `Animo` col carattere, e da lì
## `limbico.setup` → `tinta_carattere` → `sincronizza_neuro` →
## `passo_neuro` (fatto girare finché il livello non ha raggiunto il suo
## punto di riposo) → `Visitor.indossa_neuro` → `FaceController` e
## `Andatura`. Se una sola di quelle righe non ci fosse, la lastra
## mostrerebbe cinque corpi identici — che è esattamente com'era prima.
##
## ────────────────────────────────────────────────────────────────────────
## LE REGOLE DI RIPRESA, da `provino_vocabolario` e `provino_gioia`
## ────────────────────────────────────────────────────────────────────────
##
## 1. La camera è quella VERA (2,70 sopra Mochi, 3,70 dietro, fov 50, nessuna
##    imbardata). Una macchina a un metro dal muso risponde a una domanda che
##    nessun giocatore si fa.
## 2. Le distanze sono quelle a cui il progetto ha già misurato che un LIVELLO
##    si legge: 2 m sì, 6 m debole, 9 m no. Un carattere è un livello.
## 3. Il ritaglio è di **pixel fissi**: a 6 m il corpo è piccolo, ed è quello
##    che vede chi gioca.
## 4. L'azimut si CALCOLA fra «camera → corpo» e il muso.
## 5. Il tempo si ferma (`cycle_seconds`) o a metà provino vanno a dormire, e
##    `resident_sleep` li rimpicciolisce a scala 0,03.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

const SEME := 7331
## I cinque caratteri. Non sono cinque numeri comodi: 0,15 e 0,90 sono i
## dintorni degli estremi che `ChibiDNA` produce (la distribuzione è
## triangolare: i caratteri estremi devono essere RARI), e 0,50 è il neutro,
## che per costruzione somma zero alla tinta — è il termine di paragone muto.
const CARATTERI := [0.15, 0.35, 0.50, 0.70, 0.90]
## ⚠️ **I DUE NUMERI DELLA DERIVA SONO MISURE, non scelte.** Vengono da
## `tools/misura_deriva_vera.gd` (Cannella: codardia 0,724 → 0,534 dopo una
## stagione di gesti del giocatore) e da `tools/misura_insieme.gd` sez. 11
## (lealtà 0,3856 → 0,6314 dopo una stagione di co-presenza). Chi li cambia
## sta provinando una deriva che il gioco non produce.
const DERIVA_COD := [0.724, 0.534]
const DERIVA_LEA := [0.3856, 0.6314]

const AZIMUT := {"fronte": 180.0, "trequarti": 135.0, "profilo": 90.0,
		"spalle": 0.0}
const DISTANZE := [2.0, 6.0]
const PASSO := 1.05
const TILE := 240
## ⚠️ Il ritaglio e' piu' ALTO che largo: a due metri un chibi non ci sta in
## un quadrato, e la prima stesura gli tagliava i piedi — cioe' proprio la
## meta' in cui vive il portamento del busto e il rimbalzo.
const TILE_H := 310

var _dove := ""
var _liv: Node = null
var _player: Node3D = null
var _visitors: Node = null
var _cam: Camera3D = null
var _corpi: Array[Node3D] = []
var _animi: Array = []
var _vp: SubViewport = null
var _lab: Label = null
var _cache := {}
var _py := 0.0
var _log: Array = []
var _estranei: Array = []


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_CAR")
	if _dove == "":
		_dove = "/tmp/carattere"
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
	# ⚠️ **E OGNI ALTRO STRATO DI INTERFACCIA.** I cartellini («E — dormi»,
	# «E / Tab — regala a…») non stanno nell'HUD ne' fra i figli del livello:
	# sono `CanvasLayer` sparsi nell'albero, e nella prima stesura
	# attraversavano la lastra in mezzo ai corpi. La regola per trovarli
	# tutti la sa gia' il gioco — e' quella della Modalita' Foto, che esiste
	# per la stessa ragione: si legge di la', non si riscrive.
	for layer in get_root().find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	# ⚠️ **E MOCHI SI TOGLIE DI MEZZO — il corpo, non la camera.** La camera
	# del gioco sta 3,70 m dietro di lei, quindi qualunque cosa si inquadri
	# ce l'ha davanti: la sua testona copriva **esattamente** il corpo di
	# mezzo (e' la stessa trappola gia' pagata in `provino_vocabolario`).
	# Si nasconde il solo modello: la macchina resta dov'e', con la stessa
	# altezza, la stessa inclinazione e lo stesso fov — cioe' l'inquadratura
	# resta quella vera, che e' l'unica cosa che questa lastra sta provando.
	var mochi := _player.get_node_or_null("Mochi") as Node3D
	if mochi != null:
		mochi.visible = false
	# ⚠️ **E GLI ABITANTI VERI SI TOLGONO DALL'INQUADRATURA.** Uno di loro ha
	# attraversato la quinta colonna della controprova: un corpo estraneo in
	# una lastra affiancata non e' rumore di sfondo, e' una colonna persa.
	for n in _visitors.get_children():
		if n is Node3D:
			(n as Node3D).visible = false
	_estranei = _visitors.get_children()
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

	print("")
	print("█".repeat(74))
	print("IL CARATTERE ADDOSSO A UN CORPO")
	print("█".repeat(74))

	await _scena_controllo()
	await _scena_carattere()
	await _scena_deriva()
	await _scena_sussulto()

	print("")
	print("  scatti in %s" % _dove)
	quit(0)


## ⚠️ **LA CONTROPROVA, E VA GUARDATA PER PRIMA.**
##
## Cinque corpi con lo STESSO identico carattere, fotografati con la stessa
## procedura. Se in questa lastra i cinque si somigliano, allora le differenze
## della lastra dopo sono del carattere; se invece anche qui si vedono cinque
## facce diverse, questo provino sta misurando la fase dell'ammicco e delle
## micro-espressioni, e qualunque cosa io creda di leggere nell'altra e' una
## storia che mi sto raccontando.
##
## Non e' pignoleria: le ampiezze in gioco sono minuscole — il canale del
## sopracciglio e' `(serotonina − 0.5) * 0.08`, cioe' **0,7 gradi** su TUTTO
## il campo del carattere. E' esattamente la scala a cui un oracolo sbagliato
## produce undici asserzioni rosse su un codice sano (`test_gesti`, la
## trappola dell'oracolo gemello).
func _scena_controllo() -> void:
	var etich: Array = []
	var tratti: Array = []
	for i in CARATTERI.size():
		tratti.append({"codardia": 0.5})
		etich.append("identici\n(controprova %d)" % (i + 1))
	await _monta(tratti)
	print("\n0. LA CONTROPROVA — cinque corpi con lo STESSO carattere")
	_stampa_chimica(etich)
	await _lastra("controllo", "fronte", 2.0, etich)
	await _lastra("controllo", "fronte", 2.0, etich, true)


## ─────────────────────────────────────────────────────────── il carattere
func _scena_carattere() -> void:
	var etich: Array = []
	var tratti: Array = []
	for c in CARATTERI:
		tratti.append({"codardia": float(c)})
		etich.append("codardia %.2f%s" % [float(c),
				"\n(il neutro)" if is_equal_approx(float(c), 0.5) else ""])
	await _monta(tratti)
	print("\n1. IL CARATTERE — cinque corpi, un tratto solo di differenza")
	_stampa_chimica(etich)
	for vista in AZIMUT:
		for d in DISTANZE:
			await _lastra("carattere", str(vista), float(d), etich)
	# ⚠️ **IL DETTAGLIO**, perche' il cortisolo lavora sul corrugatore e sulle
	# pupille: a due metri, dentro un ritaglio che tiene tutto il corpo, la
	# faccia e' ottanta pixel. Non e' una distanza nuova — e' la STESSA foto,
	# ritagliata sulla testa: dice se il segnale c'e', e la lastra intera dice
	# se si vede giocando.
	await _lastra("carattere", "fronte", 2.0, etich, true)


## ─────────────────────────────────────────────────────────────── la deriva
func _scena_deriva() -> void:
	var etich := [
		"com'e' NATA\ncod %.3f  lea %.3f" % [DERIVA_COD[0], DERIVA_LEA[0]],
		"dopo una stagione\ncod %.3f  lea %.3f" % [DERIVA_COD[1], DERIVA_LEA[1]],
	]
	await _monta([
		{"codardia": DERIVA_COD[0], "lealta": DERIVA_LEA[0]},
		{"codardia": DERIVA_COD[1], "lealta": DERIVA_LEA[1]},
	])
	print("\n2. LA DERIVA — la stessa persona, prima e dopo una stagione")
	_stampa_chimica(etich)
	for vista in AZIMUT:
		for d in DISTANZE:
			await _lastra("deriva", str(vista), float(d), etich)
	await _lastra("deriva", "fronte", 2.0, etich, true)


## ⚠️ **I CORPI SI RIFANNO A OGNI SCENA**, invece di riscrivere il carattere
## di quelli di prima: `neuro` è uno stato ricorsivo, e un corpo che è già
## stato un codardo per venti secondi ci arriva da un'altra parte. Rifarli
## costa un secondo e toglie di mezzo una variabile.
func _monta(tratti: Array) -> void:
	for v in _corpi:
		v.queue_free()
	_corpi.clear()
	_animi.clear()
	await create_timer(0.4).timeout
	var genoma: Dictionary = DNAG.generate(SEME)
	for t in tratti:
		var v := VS.new()
		v.set("species", "chibi")
		v.set("dna", genoma.duplicate(true))
		_visitors.add_child(v)
		v.set("greet_enabled", false)
		_corpi.append(v)
		# LA CATENA VERA, dal tratto in giù. `setup` prende i tratti dal
		# genoma: si scrive il carattere LÌ, non dopo, o `tinta_carattere`
		# riceverebbe quelli di serie.
		var g2: Dictionary = genoma.duplicate(true)
		var tt: Dictionary = (g2["tratti"] as Dictionary).duplicate()
		for k in (t as Dictionary):
			tt[str(k)] = float((t as Dictionary)[k])
		g2["tratti"] = tt
		var a = ANIMO.new()
		a.setup(g2)
		_animi.append(a)
	await create_timer(1.2).timeout
	for n in _visitors.get_children():
		if n is Node3D and not _corpi.has(n):
			(n as Node3D).visible = false
	for v in _corpi:
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
	# IL LIVELLO DEVE ARRIVARE AL SUO PUNTO DI RIPOSO. `neuro` ci torna con
	# la sua costante di tempo: un provino che fotografa il transitorio
	# misura da quanto sta girando il banco, non il carattere.
	for a in _animi:
		for _i in 600:
			a.limbico.passo_neuro(1.0, {}, false)
	await create_timer(0.3).timeout


func _stampa_chimica(etich: Array) -> void:
	# ⚠️ **E L'ULTIMA COLONNA E' QUELLA CHE GIUSTIFICA TUTTO IL RESTO.**
	# `bersaglio_umore()` legge la chimica A RIPOSO, e l'umore ha lettori veri
	# (`stato_corpo()`, il capo che pende, il vocabolario del corpo): e' la
	# prova che la tinta non e' un numero senza consumatori — che e' la forma
	# di guasto che questo provino ha appena trovato di la'.
	print("   %-34s %8s %9s %8s %9s %8s" % ["", "cortis.", "serot.", "ossit.",
			"reatt.", "umore→"])
	for i in _animi.size():
		var n: Dictionary = _animi[i].limbico.neuro
		print("   %-34s %8.4f %9.4f %8.4f %9.4f %+8.4f" % [
				str(etich[i]).replace("\n", " · "), float(n["cortisolo"]),
				float(n["serotonina"]), float(n["ossitocina"]),
				float(_animi[i].limbico.reattivita),
				float(_animi[i].limbico.bersaglio_umore())])


## In fila, alla distanza chiesta, con l'azimut CALCOLATO fra «camera → corpo»
## e il muso: «di profilo» rispetto alla camera non e' `yaw = 90°`, ed e' un
## errore di dieci-diciassette gradi — cioe' si porta via proprio la colonna
## che si sta misurando.
func _posiziona(vista: String, dist: float) -> void:
	# ⚠️ **L'INTERFACCIA SI RISPEGNE PRIMA DI OGNI SCATTO**: il gioco crea
	# `CanvasLayer` nuovi mentre il provino gira (il cartellino del Nascondino
	# e' ricomparso a meta' corsa), e spegnerli una volta sola all'avvio non
	# basta.
	for layer in get_root().find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var centro := Vector3.ZERO
	_player.global_position = Vector3(0.0, _py, dist)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	var dir := centro - cam_pos
	var yaw := wrapf(atan2(dir.x, dir.z) + PI + deg_to_rad(float(AZIMUT[vista])),
			-PI, PI)
	var mezzo := (float(_corpi.size()) - 1.0) * 0.5
	# ⚠️ **LA FILA SI APRE CON LA DISTANZA.** Il ritaglio e' di pixel fissi
	# (deve esserlo: a sei metri il corpo dev'essere piccolo come lo vede chi
	# gioca), ma con la fila stretta a sei metri in ogni cella ci finiscono
	# DUE corpi — e una lastra affiancata in cui le colonne si mangiano a
	# vicenda non e' un confronto. Il passo tiene costante l'ANGOLO, cosi'
	# ogni cella contiene un soggetto solo a qualunque distanza.
	var passo: float = PASSO * (dist + 3.7) / (2.0 + 3.7)
	for i in _corpi.size():
		var v := _corpi[i]
		v.global_position = centro + Vector3((float(i) - mezzo) * passo, 0.0, 0.0)
		v.set("_yaw", yaw)
		v.rotation.y = yaw
		v.call("_enter_state", "r_idle")
		v.set("_timer", 999999.0)
		v.call("gesto_spegni", true)
		v.set_meta("postura", "sereno")
	await create_timer(0.6).timeout


func _lastra(nome: String, vista: String, dist: float, etich: Array,
		dettaglio := false) -> void:
	await _posiziona(vista, dist)
	# LA CHIMICA SI INDOSSA A OGNI FOTOGRAMMA, come la indossa `Visitors`.
	for _f in 30:
		for i in _corpi.size():
			_corpi[i].call("indossa_neuro", _animi[i].limbico.neuro)
		await process_frame

	var img := await _scatta()
	var celle := {}
	var w := 130 if dettaglio else TILE
	var h := 130 if dettaglio else TILE_H
	var alto := 0.62 if dettaglio else 0.42
	for i in _corpi.size():
		var cel := _ritaglia(img, _cam.unproject_position(
				_corpi[i].global_position + Vector3(0, alto, 0)), w, h)
		if dettaglio:
			# si INGRANDISCE il ritaglio, non si avvicina la camera: la foto
			# resta quella che il gioco disegna, e i pixel sono quelli veri
			cel.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
		celle[[0, i]] = cel
	var tw := w * 3 if dettaglio else w
	var th := h * 3 if dettaglio else h
	await _foglio("%s · %s · %.0f m%s (camera VERA del gioco)"
			% [nome, vista, dist, " · DETTAGLIO 3x" if dettaglio else ""],
			["a riposo"], etich, celle, tw, th,
			"%s/%s_%s_%.0fm%s.jpg" % [_dove.rstrip("/"), nome, vista, dist,
					"_dett" if dettaglio else ""])


## ⚠️ **DOVE IL CARATTERE SI VEDE DAVVERO: NEL MOMENTO, non nella posa.**
##
## Le due lastre di sopra dicono che a riposo il carattere non si legge, e che
## non deve leggersi: per renderlo visibile fermo bisognerebbe tenere un
## codardo a cortisolo alto **sempre**, cioe' cucirgli addosso in permanenza
## la faccia della paura — che e' il difetto che il capitolo «LA GIOIA NON
## PORTA LA FACCIA DELLA PAURA» esiste per impedire, ed e' un'etichetta
## clinica su una persona.
##
## Il posto giusto e' la REAZIONE, e li' l'ampiezza c'e' gia': `reattivita`
## va da **0,51 a 1,18** fra il coraggioso e il codardo — piu' del doppio — e
## la deriva di una stagione la porta da 1,02 a 0,85.
##
## Questa lastra da' a tutti e cinque lo STESSO spavento, con la catena vera
## di `Visitors._tick_sussulti`: `indizio_grezzo` → `percepisci` → la forza
## che ne esce → `somatico`. Nessun numero e' scritto a mano, e la differenza
## fra le colonne e' tutta e sola il carattere.
func _scena_sussulto() -> void:
	var etich: Array = []
	var tratti: Array = []
	for c in CARATTERI:
		tratti.append({"codardia": float(c)})
		etich.append("codardia %.2f" % float(c))
	await _monta(tratti)
	# ⚠️ LO STESSO IDENTICO MARCHIO PER TUTTI, o non si starebbe misurando il
	# carattere ma la storia. Un marchio negativo modesto: il minimo perche'
	# l'evento sia uno spavento e non un incontro qualunque.
	for a in _animi:
		a.limbico.marchi["chi|giocatore"] = {"carica": -0.45, "ultimo": 0}
	var grezzo: float = VISITORS.indizio_grezzo(6.0, false, 0.9)
	var forze: Array = []
	print("\n3. IL SUSSULTO — lo stesso spavento, cinque guadagni diversi")
	print("   (indizio grezzo %.3f, uguale per tutti; marchio −0,45 per tutti)"
			% grezzo)
	print("   %-18s %9s %8s %s" % ["", "reatt.", "forza", "reazione"])
	for i in _animi.size():
		var lim = _animi[i].limbico
		var st: Dictionary = lim.percepisci("giocatore", "", grezzo)
		forze.append(float(st.get("forza", 0.0)))
		print("   %-18s %9.4f %8.4f %s" % [str(etich[i]), lim.reattivita,
				float(st.get("forza", 0.0)), str(st.get("reazione", ""))])
	await _lastra_sussulto("sussulto", "fronte", 2.0, etich, forze)
	await _lastra_sussulto("sussulto", "trequarti", 2.0, etich, forze)
	await _lastra_sussulto("sussulto", "spalle", 2.0, etich, forze)
	await _lastra_sussulto("sussulto", "fronte", 6.0, etich, forze)
	await _lastra_sussulto("sussulto", "fronte", 9.0, etich, forze)

	# ⚠️ **E LA CONTROPROVA ANCHE QUI**: cinque corpi con lo stesso carattere e
	# lo stesso spavento. Se questa lastra mostrasse la stessa progressione
	# dell'altra, la progressione non sarebbe della forza.
	var e2: Array = []
	var t2: Array = []
	for i in CARATTERI.size():
		t2.append({"codardia": 0.5})
		e2.append("identici\n(controprova %d)" % (i + 1))
	await _monta(t2)
	for a2 in _animi:
		a2.limbico.marchi["chi|giocatore"] = {"carica": -0.45, "ultimo": 0}
	var f2: Array = []
	for a2 in _animi:
		f2.append(float((a2.limbico.percepisci("giocatore", "", grezzo) as Dictionary)
				.get("forza", 0.0)))
	print("   controprova: forze %s" % str(f2))
	await _lastra_sussulto("sussulto_controllo", "fronte", 2.0, e2, f2)

	# ⚠️ **E LA DERIVA, che e' la domanda per cui questo provino esiste.**
	# Una stagione di gentilezza porta la reattivita' da 1,02 a 0,85: si vede?
	var e3 := [
		"com'e' NATA\ncod %.3f" % DERIVA_COD[0],
		"dopo una stagione\ncod %.3f" % DERIVA_COD[1],
	]
	await _monta([
		{"codardia": DERIVA_COD[0], "lealta": DERIVA_LEA[0]},
		{"codardia": DERIVA_COD[1], "lealta": DERIVA_LEA[1]},
	])
	for a3 in _animi:
		a3.limbico.marchi["chi|giocatore"] = {"carica": -0.45, "ultimo": 0}
	var f3: Array = []
	print("\n4. LA DERIVA SOTTO SPAVENTO — lo stesso spavento, prima e dopo")
	for i in _animi.size():
		var lim3 = _animi[i].limbico
		var st3: Dictionary = lim3.percepisci("giocatore", "", grezzo)
		f3.append(float(st3.get("forza", 0.0)))
		print("   %-34s reatt %.4f  forza %.4f  %s"
				% [str(e3[i]).replace("\n", " · "), lim3.reattivita,
				float(st3.get("forza", 0.0)), str(st3.get("reazione", ""))])
	await _lastra_sussulto("deriva_sussulto", "fronte", 2.0, e3, f3)
	await _lastra_sussulto("deriva_sussulto", "trequarti", 2.0, e3, f3)


func _lastra_sussulto(nome: String, vista: String, dist: float, etich: Array,
		forze: Array) -> void:
	await _posiziona(vista, dist)
	for i in _corpi.size():
		_corpi[i].call("indossa_neuro", _animi[i].limbico.neuro)
	await create_timer(0.3).timeout
	# le stesse due chiamate di `Visitors._tick_sussulti`, nello stesso ordine
	for i in _corpi.size():
		_corpi[i].call("somatico", float(forze[i]))
		_corpi[i].set_meta("postura", "trasalisce")
	Engine.time_scale = 0.35
	var t := 0.0
	var ms := Time.get_ticks_msec()
	while t < 0.30:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt > 0.0 and dt < 0.5:
			t += dt * Engine.time_scale
	var img := await _scatta()
	Engine.time_scale = 1.0
	var celle := {}
	for i in _corpi.size():
		celle[[0, i]] = _ritaglia(img, _cam.unproject_position(
				_corpi[i].global_position + Vector3(0, 0.42, 0)), TILE, TILE_H)
	await _foglio("%s · %s · %.0f m · al colmo (camera VERA)"
			% [nome, vista, dist], ["trasalisce"], etich, celle, TILE, TILE_H,
			"%s/%s_%s_%.0fm.jpg" % [_dove.rstrip("/"), nome, vista, dist])
	for v in _corpi:
		v.set_meta("postura", "sereno")
		v.call("gesto_spegni", true)
		v.set("_gs_soma", 0.0)
		v.set("_gs_soma_t", 0.0)


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
