extends SceneTree
## IL METRO DELL'OCCLUSIONE — e il METRO DELLA FOLLA, sulla stessa corsa.
##
##   CHIBI_OCC=/dove/le/foto CHIBI_MINUTI=12 CHIBI_QUANTI=28 \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --resolution 1280x720 --script res://tools/misura_occlusione.gd
##
## ⚠️ **NIENTE `--headless`.** Metà di questo banco sono PIXEL: senza
## rendering l'oracolo non esiste e resterebbe solo la regola che giudica
## sé stessa.
##
## ────────────────────────────────────────────────────────────────────────
## DUE RESIDUI DICHIARATI, UNA SOLA PARTITA
## ────────────────────────────────────────────────────────────────────────
##
## **[1] IL CANCELLO PROVAVA IL FRUSTUM, NON L'OCCLUSIONE.** «Dentro
## l'inquadratura» dice DOVE sta un corpo, non se lo si vede: un gesto
## concesso a chi è dietro un muro brucia il gettone del villaggio (dodici
## secondi) e il riposo di quella persona (cinque minuti), e li toglie a uno
## che si sarebbe visto.
##
## **[2] IN MEZZO A UNA FOLLA UN CORPO FERMO NON SPICCA.** Il Punto è un
## contrasto di MOTO, e presuppone che gli altri si muovano. Quanti vicini
## camminano DAVVERO dentro l'inquadratura, in un villaggio da ventotto?
##
## ────────────────────────────────────────────────────────────────────────
## L'ORACOLO SONO I PIXEL, E NON PUÒ ESSERE ALTRO
## ────────────────────────────────────────────────────────────────────────
##
## Chiedere a `Visitors._gesto_coperto` se quel corpo si vedeva è chiedere
## al giudice se è d'accordo con sé stesso — l'errore che
## `tools/misura_cammino.gd` esiste per non commettere. Qui, nell'istante in
## cui un gesto parte, si **spegne il corpo per un fotogramma** e si conta di
## quanto cambia il quadro dentro il suo riquadro di schermo: quello è
## esattamente il numero di pixel che di quel vicino arrivano all'occhio di
## chi gioca. È la stessa tecnica di `provino_verso.gd` (le maschere contro
## una lastra di fondo), applicata a un villaggio vivo.
##
## E si misura anche il RUMORE (due fotogrammi consecutivi col corpo acceso:
## l'erba ondeggia, gli altri camminano), o «il corpo vale 40 px» non
## vorrebbe dire niente.
##
## ────────────────────────────────────────────────────────────────────────
## IL PRIMA E IL DOPO STANNO NELLA STESSA CORSA
## ────────────────────────────────────────────────────────────────────────
##
## `Visitors.debug_occlusione` si alterna a blocchi: **spento** i raggi si
## tirano lo stesso e il verdetto si annota, ma il gesto parte comunque — è
## il «prima», e l'oracolo dei pixel dice quanti di quei gesti erano buttati.
## **Acceso** è il gioco vero. Due corse diverse sarebbero due villaggi (la
## lezione di `GESTO_PASSO`: 383 richieste contro 175, e nessun confronto
## possibile).
##
## ────────────────────────────────────────────────────────────────────────
## COSA HA MISURATO (28 residenti, 14 minuti, blocchi da 45 s)
## ────────────────────────────────────────────────────────────────────────
##
##   | | cancello spento | cancello ACCESO |
##   |---|---|---|
##   | gesti partiti | 12 | 10 |
##   | ...con l'oracolo leggibile | 6 | 7 |
##   | **INVISIBILI** | **2 (33%)** | **0** |
##   | gesti concessi a un corpo con tutte e tre le quote coperte | 1 | **0** |
##
## e **56 richieste respinte con la parola «coperto»** nei soli blocchi
## accesi (sette minuti): ognuna aveva già passato il gettone, il palco, il
## riposo, il corpo, il raggio e l'inquadratura, e sarebbe costata dodici
## secondi di villaggio più cinque minuti di quella persona.
##
## Dei DUE invisibili a cancello spento, il cancello ne avrebbe preso **uno**
## (maschera 7); l'altro aveva maschera 0 ed è il residuo delle chiome e dei
## tetti, che collisioni non ne hanno (vedi `Visitors._gesto_coperto`).
##
## LA SONDA, 124 campioni: maschera **tutta o niente** (74 a zero, 47 a tre,
## tre soli in mezzo) — cioè fra «due quote» e «tre» la misura non decide.
##
## ⚠️ **E UN LIMITE DELL'ORACOLO, dichiarato:** su 22 gesti, **9** non hanno un
## numero (il riquadro di schermo del corpo esce vuoto: succede quando la
## sagoma straddia il piano vicino della camera, cioè da vicinissimo). Per
## questo la taratura la porta la SONDA, che di campioni ne ha centoventiquattro
## e tutti validi, e non i gesti.

const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Quanto dura un blocco. Il gettone del villaggio è dodici secondi: sotto
## il minuto un blocco non conterrebbe nemmeno un gesto.
const BLOCCO := 45.0
## Sotto questa frazione del proprio riquadro di schermo, di quel corpo non
## arriva abbastanza per leggerci un gesto. Il numero NON è scelto qui: è
## la soglia con cui si legge l'istogramma che questo banco stampa, e la
## corsa vera lo ha trovato bimodale con un vuoto largo in mezzo.
const INVISIBILE := 0.06
## Quanto deve differire un pixel dal fondo per contare come «corpo». È la
## stessa soglia di `provino_verso.gd`.
const SOGLIA := 24
## I verbi del ciclo di gioco che il ponte della percezione conosce.
const VERBI := ["annaffia", "semina", "raccoglie", "costruisce", "pesca"]

var _liv: Node = null
var _vis: Node = null
var _build: Node = null
var _player: Node3D = null
var _cam: Camera3D = null
var _dove := ""

# --- [1] l'occlusione ---
var _eventi := []            # una riga per gesto partito
var _scatti := 0

# --- [2] la folla ---
var _camp := 0
var _somma_quadro := 0.0
var _somma_camm := 0.0
var _somma_moti := 0.0
var _isto_quadro := {}
var _isto_camm := {}
var _isto_moti := {}
var _pos_prec := {}
var _senza_camm := 0
## Quanti camminavano nell'inquadratura NELL'ISTANTE in cui un Punto è
## partito — che è la domanda vera: il riferimento c'era, per quel gesto?
var _folla_al_punto := []

# --- la SONDA: la regola contro i pixel, su tutti i corpi giudicabili ---
#
# ⚠️ **I GESTI SONO TROPPO POCHI PER TARARE UNA REGOLA.** Il gettone ne
# concede al massimo cinque al minuto e il mondo molti meno: una corsa da
# dodici minuti ne dà una ventina, e venti campioni non decidono una soglia.
# Ma la domanda che la regola si fa — «di quel corpo, lì dove sta adesso,
# arriva abbastanza allo schermo?» — si può fare a CHIUNQUE, in qualunque
# istante, e non ha bisogno che un gesto stia partendo. La sonda la fa a
# tutta la popolazione che il cancello giudica (dentro l'inquadratura, entro
# nove metri), una volta ogni quattro secondi.
var _sonde := []
var _sonda_acc := 0.0
var _sonda_giro := 0
var _disaccordi := 0


func _init() -> void:
	_go()


# =========================================================================
# L'ORACOLO DEI PIXEL
# =========================================================================

func _mesh(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_mesh(c, out)


## Il rettangolo di schermo che contiene il corpo, dalle AABB VERE delle sue
## mesh. Non è una stima: è dove quel corpo starebbe se niente lo coprisse,
## ed è il denominatore della frazione.
func _bbox(corpo: Node3D) -> Rect2:
	var mm := []
	_mesh(corpo, mm)
	var r := Rect2()
	var primo := true
	for m in mm:
		var mi: MeshInstance3D = m
		var ab := mi.get_aabb()
		var xf := mi.global_transform
		for i in 8:
			var q: Vector3 = xf * (ab.position + Vector3(
					ab.size.x * float(i & 1), ab.size.y * float((i >> 1) & 1),
					ab.size.z * float((i >> 2) & 1)))
			if _cam.is_position_behind(q):
				continue
			var s := _cam.unproject_position(q)
			if primo:
				r = Rect2(s, Vector2.ZERO)
				primo = false
			else:
				r = r.expand(s)
	return r


## Il lato più lungo del ritaglio su cui si conta. Un riquadro da 470×470 è
## un quarto di milione di pixel, e due differenze in GDScript su quella
## roba sono duecento millisecondi per campione: la sonda costerebbe più
## della partita. Rimpicciolire non sposta la FRAZIONE (che è un rapporto),
## e la domanda è bimodale — 0,00 contro 0,42 — non al terzo decimale.
const RIT_MAX := 120


func _leggi(rr: Rect2i) -> PackedByteArray:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var reg := img.get_region(rr.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	var lungo := maxi(reg.get_width(), reg.get_height())
	if lungo > RIT_MAX:
		var k := float(RIT_MAX) / float(lungo)
		reg.resize(maxi(2, int(reg.get_width() * k)),
				maxi(2, int(reg.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	return reg.get_data()


func _diversi(a: PackedByteArray, b: PackedByteArray) -> int:
	var n := mini(a.size(), b.size()) / 3
	var c := 0
	for i in n:
		var j := i * 3
		var d := absi(int(a[j]) - int(b[j])) \
				+ absi(int(a[j + 1]) - int(b[j + 1])) \
				+ absi(int(a[j + 2]) - int(b[j + 2]))
		if d > SOGLIA:
			c += 1
	return c


## Quanti pixel di QUESTO corpo arrivano allo schermo, adesso. Tre letture:
## acceso · spento · acceso. La prima coppia è il corpo, la seconda è il
## RUMORE del mondo che si muove fra due fotogrammi — senza, «40 px» non
## vorrebbe dire niente.
##
## ⚠️ **E IL MONDO SI FERMA, o si misura il moto invece del corpo.** Con la
## partita che gira, fra due fotogrammi la CAMERA si sposta (Mochi corre a
## sei metri al secondo) e cambia tutto il riquadro: misurato nella prima
## stesura, **rumore 43384 su un corpo da 64882** — due terzi del segnale.
## `Engine.time_scale = 0` congela camera, corpi e andature; resta il solo
## TIME degli shader, ed è quello che il rumore misura adesso.
func _pixel_del_corpo(nodo: Node3D) -> Dictionary:
	var corpo := nodo.get("_corpo") as Node3D
	if corpo == null or _cam == null:
		return {}
	var scala := Engine.time_scale
	Engine.time_scale = 0.0
	var out := await _pixel_fermo(corpo)
	Engine.time_scale = scala
	return out


func _pixel_fermo(corpo: Node3D) -> Dictionary:
	var r := _bbox(corpo).grow(6.0)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return {}
	var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
			Vector2i(ceili(r.size.x), ceili(r.size.y)))
	rr = rr.intersection(Rect2i(Vector2i.ZERO, get_root().size))
	if rr.size.x < 2 or rr.size.y < 2:
		return {}
	# ⚠️ **SI ASPETTA CHE IL MONDO SI FERMI DAVVERO.** Il fotogramma che sta
	# per essere disegnato quando `time_scale` va a zero è ancora quello di
	# prima: leggerlo subito significa confrontare un fotogramma in moto con
	# due fermi, e la differenza che ne esce è il MOTO, non il corpo.
	# MISURATO nella prima stesura: «pixel 15914, rumore 15871» su un
	# riquadro da 21600 — il 73% del quadro, cioè tutto. Con quattro
	# fotogrammi di attesa il pavimento va a ZERO (provato: col tempo fermo,
	# quattro letture consecutive dell'intero schermo differiscono di 0 px su
	# 921600). Le due tessere dopo servono al TAA, che deve smettere di
	# accumulare il corpo appena sparito.
	for _i in 4:
		await process_frame
	var acceso := await _leggi(rr)
	corpo.visible = false
	await process_frame
	var spento := await _leggi(rr)
	corpo.visible = true
	await process_frame
	var acceso2 := await _leggi(rr)
	# l'AREA è quella su cui si è contato davvero (il ritaglio rimpicciolito),
	# non quella del rettangolo di schermo: il denominatore deve essere lo
	# stesso insieme di pixel del numeratore
	var area := float(acceso.size() / 3)
	var px := _diversi(acceso, spento)
	var rumore := _diversi(acceso, acceso2)
	return {"px": px, "rumore": rumore, "area": area,
			"frazione": float(maxi(0, px - rumore)) / maxf(1.0, area),
			"rett": rr}


# =========================================================================
# I TRE PAVIMENTI DI RUMORE — la lezione di `provino_verso._il_moto`
# =========================================================================
#
# ⚠️ **QUESTO BANCO L'HA RIPAGATA DA CAPO, e vale la pena scriverlo.** Nella
# prima stesura un corpo perfettamente visibile dava «pixel 6471, rumore
# 6089»: il rumore era grande quanto il corpo, e la frazione — che è la
# differenza dei due — raccontava che quel vicino non si vedeva. Non è la
# fisica che sbagliava: era l'oracolo.
#
# I pavimenti sono tre, e vanno spenti tutti e tre:
#
#  1. **il MOTO del mondo.** Fra due fotogrammi la camera si sposta (Mochi
#     corre a sei metri al secondo) e cambia tutto il riquadro. Lo chiude
#     `Engine.time_scale = 0` attorno alle tre letture.
#  2. **l'ANTIALIASING.** TAA e FXAA fanno ballare OGNI pixel di bordo a
#     ogni fotogramma, e il bordo di un chibi a sei metri sono qualche
#     centinaio di pixel — lo stesso ordine di grandezza del segnale.
#  3. **il VENTO.** L'erba e le fronde ondeggiano dentro gli shader, che
#     hanno un orologio loro e non guardano `time_scale`.
#
# Spegnerli non cambia di un capello CHI copre CHI: la geometria è la
# stessa, ed è l'unica cosa che questo banco misura.
func _ferma_i_pavimenti() -> void:
	var vp := get_root()
	vp.use_taa = false
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	var meteo := _liv.get_node_or_null("Weather")
	if meteo != null:
		meteo.set_process(false)
	RenderingServer.global_shader_parameter_set("vento_forza", 0.0)


# =========================================================================
# LA SCENA
# =========================================================================

func _go() -> void:
	_dove = OS.get_environment("CHIBI_OCC")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	_liv = current_scene
	_player = _liv.get_node_or_null("Player") as Node3D
	_vis = _liv.get_node_or_null("Visitors")
	_build = _liv.get_node_or_null("BuildSystem")
	var dn := _liv.get_node_or_null("DayNight")
	var hud := _liv.get_node_or_null("HUD")
	if _player == null or _vis == null or _build == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# L'OROLOGIO SI FERMA a metà pomeriggio: di notte i ventotto sono tutti
	# dentro casa e non gesticola nessuno — si misurerebbe il buio.
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	if hud != null:
		hud.set("visible", false)
	_ferma_i_pavimenti()
	await create_timer(1.5).timeout
	_cam = get_root().get_camera_3d()

	var minuti := 12.0
	if OS.get_environment("CHIBI_MINUTI") != "":
		minuti = float(OS.get_environment("CHIBI_MINUTI"))
	var quanti := 28
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))

	var residenti := await _costruisci(quanti)
	print("\n" + "█".repeat(72))
	print("  L'OCCLUSIONE E LA FOLLA — %d residenti, %.0f minuti, blocchi da %.0f s"
			% [residenti.size(), minuti, BLOCCO])
	print("█".repeat(72))
	await _gira(minuti * 60.0, residenti)
	_referto()
	quit(0)


## ⚠️ **IL VILLAGGIO SI COSTRUISCE COME LO COSTRUISCE CHI GIOCA, o non c'è
## niente dietro cui stare.** Case coi MURI (che sono l'unico pezzo di
## struttura con delle collisioni vere), tetti, staccionate, e il bosco che
## il MainLevel ha già. Un prato nudo risponderebbe «nessuno era coperto» —
## e sarebbe vero, e non direbbe niente.
func _costruisci(quanti: int) -> Array:
	_vis.call("debug_reset")
	var celle: Array[Vector2i] = []
	for gx in range(-7, 8):
		for gz in range(-7, 8):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	var letti := 0
	var i := 0
	var celle_letto: Array[Vector2i] = []
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		letti += 1
		celle_letto.append(c)
		# I QUATTRO MURI della casa, meno la porta: sono loro a coprire.
		# Il bordo si indirizza con la chiave raddoppiata (il verso del
		# muro è nel segno), come vuole `BuildSystem.place_edge`.
		_build.call("place_edge", Vector2i(c.x * 2, c.y * 2 - 1), "Muro", false, false)
		_build.call("place_edge", Vector2i(c.x * 2, c.y * 2 + 1), "Muro", false, false)
		_build.call("place_edge", Vector2i(c.x * 2 - 1, c.y * 2), "Finestra", false, false)
		_build.call("place_edge", Vector2i(c.x * 2 + 1, c.y * 2), "Porta", false, false)
	var extra := 0
	while extra < 22 and i < celle.size():
		var c2: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c2,
				["Cespuglio", "Panchina", "Aiuola", "Lampada"][extra % 4], 0, false)
		extra += 1
	_build.call("aggiorna_varchi_ora")
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])
	await create_timer(1.5).timeout
	var residenti: Array = _vis.get("_residents")
	for k in residenti.size():
		var cc: Vector2i = (residenti[k] as Dictionary)["cell"]
		_vis.call("debug_stage_resident", k, Vector3(cc.x, 0, cc.y))
	await create_timer(1.0).timeout
	_prepara(residenti)
	return residenti


## Le occasioni non si inventano: si semina lo stato interiore che il gioco
## legge già (la stessa preparazione di `provino_vocabolario`).
func _prepara(residenti: Array) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var k := 0
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var animo: RefCounted = animi[lab]
		if k % 3 == 0:
			for _i in 4:
				animo.limbico.rivaluta("spavento", "", -0.9, "cucina", true)
		if k % 3 == 1:
			for _i in 2:
				animo.limbico.trattieni()
			r["gradino"] = maxi(int(r.get("gradino", 0)), 2)
			animo.set("gradino", maxi(int(animo.get("gradino")), 2))
		if k % 3 == 2:
			r["friend"] = maxi(int(r.get("friend", 0)), 3)
		k += 1


# =========================================================================
# LA PARTITA
# =========================================================================

func _gira(secondi: float, residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var meta := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var lavoro := 2.0
	var verbo := 0
	var sosta := 0.0
	var camp_acc := 0.0
	var in_corso := {}
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0:
			continue
		# ⚠️ **UN FOTOGRAMMA LENTO NON SI BUTTA, SI LIMITA.** La sonda ferma
		# il mondo e legge tre fotogrammi: sotto carico un giro del ciclo
		# supera il mezzo secondo, e la regola «più di mezzo secondo non
		# conta» faceva stare fermo l'orologio del banco — dodici minuti di
		# partita non arrivavano mai. Si limita il passo (il mondo non deve
		# fare salti) e si va avanti.
		dt = minf(dt, 0.25)
		t += dt
		# IL BLOCCO: il cancello acceso e spento a turno, nella stessa corsa
		var blocco := int(t / BLOCCO)
		var acceso := (blocco % 2) == 0
		_vis.set("debug_occlusione", acceso)

		# --- Mochi cammina e lavora come cammina e lavora chi gioca ---
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= dt
		elif Vector2(p.x - meta.x, p.z - meta.z).length() < 1.0:
			sosta = 2.0
			if rng.randf() < 0.5 and not residenti.is_empty():
				var q: Dictionary = residenti[rng.randi() % residenti.size()]
				var qn := q.get("node") as Node3D
				meta = qn.global_position if qn != null and is_instance_valid(qn) \
						else Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			else:
				meta = Vector3(rng.randf_range(-13, 13), 0, rng.randf_range(-13, 13))
		var verso := (meta - p)
		verso.y = 0.0
		if sosta <= 0.0 and verso.length() > 0.01:
			var lontano: bool = verso.length() > 8.0
			var vel: float = float(_player.get("run_speed") if lontano
					else _player.get("walk_speed"))
			if vel <= 0.0:
				vel = 6.0 if lontano else 3.0
			_player.global_position = p + verso.normalized() * vel * dt
		lavoro -= dt
		if lavoro <= 0.0:
			lavoro = 2.6
			var perc := _liv.get_node_or_null("Percezione")
			if perc != null:
				for _k in 2 + (verbo % 3):
					perc.call("accaduto", VERBI[verbo % VERBI.size()],
							_player.global_position)
				verbo += 1

		# --- [2] LA FOLLA, quattro volte al secondo ---
		camp_acc -= dt
		if camp_acc <= 0.0:
			camp_acc = 0.25
			_campiona_folla(residenti, 0.25)

		# --- LA SONDA: la regola contro i pixel, su un corpo giudicabile ---
		_sonda_acc -= dt
		if _sonda_acc <= 0.0:
			_sonda_acc = 4.0
			await _sonda(residenti)
			ms = Time.get_ticks_msec()

		# --- [1] chi ha appena cominciato a parlare ---
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n == null or not is_instance_valid(n) \
					or not n.has_method("gesto_in_corso"):
				continue
			# ⚠️ LA CHIAVE È IL CORPO, NON IL NOME: con ventotto residenti
			# due etichette si ripetono, e un omonimo faceva ricontare lo
			# stesso gesto a ogni fotogramma.
			var chiave := n.get_instance_id()
			var g := str(n.call("gesto_in_corso"))
			if g == "":
				in_corso.erase(chiave)
				continue
			if in_corso.has(chiave):
				continue
			in_corso[chiave] = 1
			await _annota(t, acceso, r, n, g, residenti)
			ms = Time.get_ticks_msec()


## Quanti corpi ci sono nell'inquadratura, e quanti di quelli CAMMINANO.
## Due misure del cammino, e servono tutte e due: quella dello STATO (la
## stessa condizione che il Punto pretende) e quella dello SPOSTAMENTO —
## perché un corpo può essere in «walk» e stare fermo in coda a una rotta,
## e l'occhio guarda lo spostamento.
func _campiona_folla(residenti: Array, dt: float) -> void:
	if _cam == null:
		return
	var quadro := 0
	var camm := 0
	var moti := 0
	for r in residenti:
		var n := (r as Dictionary).get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var pos := n.global_position
		var prec: Vector3 = _pos_prec.get(n.get_instance_id(), pos)
		_pos_prec[n.get_instance_id()] = pos
		if bool(n.call("is_hidden")):
			continue
		if not _cam.is_position_in_frustum(pos + Vector3(0, 0.55, 0)):
			continue
		if _player.global_position.distance_to(pos) > VISITORS.GESTO_RAGGIO:
			continue
		quadro += 1
		var and_ = n.get("_andatura")
		if str(n.get("_state")) == "walk" and and_ != null \
				and float(and_.blend) > 0.6:
			camm += 1
		if Vector2(pos.x - prec.x, pos.z - prec.z).length() / maxf(dt, 0.001) > 0.35:
			moti += 1
	_camp += 1
	_somma_quadro += float(quadro)
	_somma_camm += float(camm)
	_somma_moti += float(moti)
	_isto_quadro[quadro] = int(_isto_quadro.get(quadro, 0)) + 1
	_isto_camm[camm] = int(_isto_camm.get(camm, 0)) + 1
	_isto_moti[moti] = int(_isto_moti.get(moti, 0)) + 1
	if camm == 0:
		_senza_camm += 1


## UN CORPO A GIRO fra quelli che il cancello giudicherebbe: la maschera
## della regola e i pixel veri, sullo stesso istante. È la stessa domanda
## del cancello, fatta a chi non sta gesticolando — l'unico modo di averne
## abbastanza per tarare una soglia.
func _sonda(residenti: Array) -> void:
	if _cam == null:
		return
	var buoni := []
	for r in residenti:
		var n := (r as Dictionary).get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if bool(n.call("is_hidden")):
			continue
		var pos := n.global_position
		if _player.global_position.distance_to(pos) > VISITORS.GESTO_RAGGIO:
			continue
		if not _cam.is_position_in_frustum(pos + Vector3(0, VISITORS.GESTO_QUOTA, 0)):
			continue
		buoni.append(n)
	if buoni.is_empty():
		return
	# a giro, non il più vicino: il più vicino è sempre quello scoperto
	var n2: Node3D = buoni[_sonda_giro % buoni.size()]
	_sonda_giro += 1
	var maschera := int(_vis.call("debug_quote_coperte", n2.global_position))
	var dentro := _occhio_dentro()
	var occhi: Dictionary = await _pixel_del_corpo(n2)
	if occhi.is_empty():
		return
	var quante := 0
	for i in 3:
		if maschera & (1 << i):
			quante += 1
	_sonde.append({"maschera": maschera, "quante": quante,
			"frazione": float(occhi["frazione"]), "px": int(occhi["px"]),
			"rumore": int(occhi["rumore"]), "area": float(occhi["area"]),
			"dentro": dentro,
			"dist": _player.global_position.distance_to(n2.global_position)})
	# ⚠️ **I DISACCORDI SI GUARDANO.** Un numero che dice «la regola ha
	# sbagliato» non dice PERCHÉ, e le due ragioni possibili sono opposte
	# (un occluso senza collisioni, o un raggio che ha preso un palo). Le
	# foto sono l'unico posto in cui la differenza si vede.
	var occhio: bool = float(occhi["frazione"]) < INVISIBILE
	var regola: bool = quante >= VISITORS.GESTO_COPERTO_MIN
	if _dove == "" or regola == occhio or _disaccordi >= 16:
		return
	_disaccordi += 1
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var rr: Rect2i = occhi["rett"]
	_riquadra(img, rr)
	img.save_jpg("%s/DISACCORDO_%02d_%s_m%d_f%03d.jpg"
			% [_dove, _disaccordi,
			"regola-dice-coperto" if regola else "pixel-dicono-coperto",
			maschera, int(float(occhi["frazione"]) * 1000.0)], 0.94)


## Un rettangolo bianco attorno al corpo in questione. È un'immagine di
## DIAGNOSI, non un provino di leggibilità: qui il segno serve, perché la
## domanda è «chi è quello lì e cosa aveva davanti», non «si nota».
func _riquadra(img: Image, rr: Rect2i) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in range(maxi(0, rr.position.x), mini(w, rr.position.x + rr.size.x)):
		for dy: int in [0, 1]:
			var y0: int = rr.position.y + dy
			var y1: int = rr.position.y + rr.size.y - dy
			if y0 >= 0 and y0 < h:
				img.set_pixel(x, y0, Color.WHITE)
			if y1 >= 0 and y1 < h:
				img.set_pixel(x, y1, Color.WHITE)
	for y in range(maxi(0, rr.position.y), mini(h, rr.position.y + rr.size.y)):
		for dx: int in [0, 1]:
			var x0: int = rr.position.x + dx
			var x1: int = rr.position.x + rr.size.x - dx
			if x0 >= 0 and x0 < w:
				img.set_pixel(x0, y, Color.WHITE)
			if x1 >= 0 and x1 < w:
				img.set_pixel(x1, y, Color.WHITE)


## LA MACCHINA DA PRESA STA DENTRO QUALCOSA? Un raggio lungo un centimetro
## che parte dall'occhio: se torna pieno, la camera è finita dentro un solido
## — e in questo gioco succede, perché segue Mochi a distanza fissa e non
## schiva niente (il tronco del Grande Albero).
##
## ⚠️ Non reimplementa la regola: fa una domanda che la regola non fa. Serve
## a CONTARE quella famiglia di casi, non a giudicarla.
func _occhio_dentro() -> bool:
	if _cam == null:
		return false
	var ss := get_root().find_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_cam.global_position,
			_cam.global_position + Vector3(0.0, 0.01, 0.0))
	q.hit_from_inside = true
	return not ss.intersect_ray(q).is_empty()


## Un gesto è partito: si chiede alla REGOLA cosa ne pensa, e ai PIXEL cosa
## è successo davvero. Le due risposte finiscono affiancate nella stessa
## riga, sullo stesso istante, sullo stesso corpo.
func _annota(t: float, cancello: bool, r: Dictionary, n: Node3D, g: String,
		residenti: Array) -> void:
	var pos := n.global_position
	var maschera := int(_vis.call("debug_quote_coperte", pos))
	var quante := 0
	for i in 3:
		if maschera & (1 << i):
			quante += 1
	# quanti altri camminavano nell'inquadratura in QUESTO istante
	var altri := 0
	for r2 in residenti:
		var n2 := (r2 as Dictionary).get("node") as Node3D
		if n2 == null or not is_instance_valid(n2) or n2 == n:
			continue
		if bool(n2.call("is_hidden")):
			continue
		if not _cam.is_position_in_frustum(n2.global_position + Vector3(0, 0.55, 0)):
			continue
		var a2 = n2.get("_andatura")
		if str(n2.get("_state")) == "walk" and a2 != null and float(a2.blend) > 0.6:
			altri += 1
	var occhi: Dictionary = await _pixel_del_corpo(n)
	var riga := {
		"t": t, "cancello": cancello, "gesto": g,
		"label": str(r.get("label", "")),
		"dist": _player.global_position.distance_to(pos),
		"maschera": maschera, "quante": quante,
		"frazione": float(occhi.get("frazione", -1.0)),
		"px": int(occhi.get("px", -1)), "rumore": int(occhi.get("rumore", -1)),
		"area": float(occhi.get("area", 0.0)),
		"altri_camminano": altri,
	}
	_eventi.append(riga)
	if g == "punto":
		_folla_al_punto.append(altri)
	print("   %s t=%5.0f  %-9s %-10s  %.1f m  maschera %d (%d/3)  "
			% ["ON " if cancello else "off", t, g, riga["label"], riga["dist"],
			maschera, quante]
			+ "pixel %5d (rumore %4d) su %6.0f → %.3f  · altri che camminano %d"
			% [riga["px"], riga["rumore"], riga["area"], riga["frazione"], altri])
	# la FOTO dei casi interessanti: quelli che i pixel dicono invisibili, e
	# i primi comunque, per avere il termine di paragone sott'occhio
	if _dove == "" or _scatti >= 24:
		return
	var invisibile: bool = riga["frazione"] >= 0.0 \
			and float(riga["frazione"]) < INVISIBILE
	if not invisibile and _scatti >= 8:
		return
	_scatti += 1
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg("%s/%02d_%s_%s_f%03d_m%d.jpg"
			% [_dove, _scatti, "COPERTO" if invisibile else "visto", g,
			int(float(riga["frazione"]) * 1000.0), maschera], 0.94)


# =========================================================================
# IL REFERTO
# =========================================================================

func _mediana(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _isto(d: Dictionary, tot: int) -> String:
	var k := d.keys()
	k.sort()
	var s := ""
	for x in k:
		s += "%d:%d (%.0f%%)  " % [int(x), int(d[x]),
				100.0 * float(d[x]) / maxf(1.0, float(tot))]
	return s


func _referto() -> void:
	print("\n" + "═".repeat(72))
	print("  [1] L'OCCLUSIONE — %d gesti partiti" % _eventi.size())
	print("═".repeat(72))
	var frazioni := []
	for e in _eventi:
		if float(e["frazione"]) >= 0.0:
			frazioni.append(float(e["frazione"]))
	frazioni.sort()
	print("  la frazione di riquadro che il corpo DIPINGE davvero:")
	var secchi := [0.0, 0.01, 0.02, 0.04, 0.06, 0.10, 0.15, 0.25, 1.01]
	for i in secchi.size() - 1:
		var n := 0
		for f in frazioni:
			if float(f) >= float(secchi[i]) and float(f) < float(secchi[i + 1]):
				n += 1
		if n > 0:
			print("    %.2f – %.2f : %s (%d)" % [secchi[i], secchi[i + 1],
					"█".repeat(n), n])
	if not frazioni.is_empty():
		print("    mediana %.3f · minima %.3f · massima %.3f"
				% [_mediana(frazioni), float(frazioni[0]),
				float(frazioni[frazioni.size() - 1])])

	print("\n" + "═".repeat(72))
	print("  LA SONDA — %d campioni: la REGOLA contro i PIXEL" % _sonde.size())
	print("═".repeat(72))
	var fs := []
	for s in _sonde:
		fs.append(float(s["frazione"]))
	fs.sort()
	print("  la frazione di riquadro DIPINTA, su tutti i corpi giudicabili:")
	for i in secchi.size() - 1:
		var n2 := 0
		for f2 in fs:
			if float(f2) >= float(secchi[i]) and float(f2) < float(secchi[i + 1]):
				n2 += 1
		if n2 > 0:
			print("    %.2f – %.2f : %s (%d)" % [secchi[i], secchi[i + 1],
					"█".repeat(mini(60, n2)), n2])
	if not fs.is_empty():
		print("    mediana %.3f · minima %.3f · massima %.3f"
				% [_mediana(fs), float(fs[0]), float(fs[fs.size() - 1])])
	# quanto dipinge un corpo a maschera zero (nessuna quota coperta) — è il
	# metro di «scoperto», e la soglia si legge da qui e non a occhio
	for q in [0, 1, 2, 3]:
		var a := []
		for s in _sonde:
			if int(s["quante"]) == q:
				a.append(float(s["frazione"]))
		if a.is_empty():
			continue
		a.sort()
		print("    quote coperte = %d : %3d campioni · frazione mediana %.3f "
				% [q, a.size(), _mediana(a)]
				+ "· minima %.3f · massima %.3f"
				% [float(a[0]), float(a[a.size() - 1])])
	var dentro_n := 0
	var dentro_vis := 0
	for s2 in _sonde:
		if bool((s2 as Dictionary).get("dentro", false)):
			dentro_n += 1
			if float((s2 as Dictionary)["frazione"]) >= INVISIBILE:
				dentro_vis += 1
	print("    l'occhio era DENTRO un solido in %d campioni su %d "
			% [dentro_n, _sonde.size()]
			+ "(e in %d di quelli del corpo si vedeva ancora qualcosa)"
			% dentro_vis)
	# LA MATRICE: la regola contro i pixel — sui gesti veri E sulla sonda
	for dove in [["i gesti", _eventi], ["la sonda", _sonde]]:
		for soglia_regola in [1, 2, 3]:
			var vp := 0   # la regola dice «coperto» e i pixel confermano
			var fp := 0   # la regola dice «coperto» e il corpo si vedeva
			var fn := 0   # la regola lascia passare un corpo invisibile
			var vn := 0
			for e in (dove[1] as Array):
				var f := float((e as Dictionary)["frazione"])
				if f < 0.0:
					continue
				var regola: bool = int((e as Dictionary)["quante"]) >= soglia_regola
				var occhio: bool = f < INVISIBILE
				if regola and occhio:
					vp += 1
				elif regola and not occhio:
					fp += 1
				elif not regola and occhio:
					fn += 1
				else:
					vn += 1
			print("  %s · regola «≥%d coperte»: presi %d · FALSI ALLARMI %d · "
					% [str(dove[0]), soglia_regola, vp, fp]
					+ "SFUGGITI %d · lasciati passare %d" % [fn, vn])

	# IL PRIMA E IL DOPO, a blocchi alternati
	for acceso in [false, true]:
		var n := 0
		var invis := 0
		for e in _eventi:
			if bool(e["cancello"]) != acceso:
				continue
			n += 1
			if float(e["frazione"]) >= 0.0 and float(e["frazione"]) < INVISIBILE:
				invis += 1
		print("  cancello %s: %d gesti, di cui INVISIBILI %d (%.0f%%)"
				% ["ACCESO" if acceso else "spento", n, invis,
				100.0 * float(invis) / maxf(1.0, float(n))])
	print("  i NO dell'usciere: %s" % str(_vis.call("debug_gesti_contatori")))

	print("\n" + "═".repeat(72))
	print("  [2] LA FOLLA — %d campioni (quattro al secondo)" % _camp)
	print("═".repeat(72))
	print("  corpi nell'inquadratura (entro %d m):  media %.2f   %s"
			% [int(VISITORS.GESTO_RAGGIO), _somma_quadro / maxf(1.0, float(_camp)),
			_isto(_isto_quadro, _camp)])
	print("  …di cui CAMMINANO (stato):            media %.2f   %s"
			% [_somma_camm / maxf(1.0, float(_camp)), _isto(_isto_camm, _camp)])
	print("  …di cui SI SPOSTANO (>0,35 m/s):      media %.2f   %s"
			% [_somma_moti / maxf(1.0, float(_camp)), _isto(_isto_moti, _camp)])
	print("  fotogrammi con NESSUNO che cammina nell'inquadratura: %.0f%%"
			% [100.0 * float(_senza_camm) / maxf(1.0, float(_camp))])
	if not _folla_al_punto.is_empty():
		var zero := 0
		for x in _folla_al_punto:
			if int(x) == 0:
				zero += 1
		print("  NELL'ISTANTE di un Punto, altri che camminavano in quadro: "
				+ "mediana %.0f · nessuno %d volte su %d (%.0f%%)"
				% [_mediana(_folla_al_punto), zero, _folla_al_punto.size(),
				100.0 * float(zero) / float(_folla_al_punto.size())])
	if _dove != "":
		print("\n  → %d foto in %s" % [_scatti, _dove])
