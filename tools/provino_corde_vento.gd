extends SceneTree
## LE CORDE NEL TEMPORALE — il provino che la suite non sa dare.
##
## Le corde vive leggevano il vento da una porta murata
## (`RenderingServer.global_shader_parameter_get`, che fuori dall'editor
## fallisce) e ricevevano SEMPRE 1.0: il vento del sereno. Col temporale
## — che il cielo tira a 1.8, cioe' tre volte la spinta — il bucato e le
## altalene del villaggio pendevano come in una giornata di bonaccia.
##
## Questo rende TRE pellicole, con la stessa camera, lo stesso istante di
## partenza e la stessa posa di riposo:
##
##   1  BONACCIA          sereno, il cielo tira 1.0
##   2  TEMPORALE (PRIMA) piove, ma le corde sentono 1.0 — il guasto
##   3  TEMPORALE (ORA)   piove, e le corde sentono 1.8
##
## La riga 2 si ottiene con `vento_forzato = 1.0`, che e' *esattamente*
## quello che il codice vecchio faceva: la sua unica risposta possibile
## fuori dall'editor era 1.0 (misurato: «vento che arriva alle corde:
## 1.000» col cielo a 1.800). Righe 2 e 3 differiscono per UNA COSA
## SOLA — quanto vento arriva alle corde — quindi la pioggia, la luce e
## il grigiore non possono prendersi il merito di niente.
##
##   CHIBI_CORDE_PROVINO=/dove Godot --path . \
##       --script res://tools/provino_corde_vento.gd
##
## E accanto alle immagini stampa i NUMERI: di quanto si scosta il
## sedile dell'altalena dalla sua verticale, in ciascuna delle tre.

const FISICA := preload("res://scenes/world/CordaFisica.gd")

const SCATTI := 5           # quanti fotogrammi per pellicola
const PASSO := 0.5          # ogni quanti secondi si scatta
const ASSESTA := 2.2        # quanto si lascia stabilire il moto prima
## LA STRISCIA SI RITAGLIA, NON SI RIMPICCIOLISCE. Una campata da tre
## metri che ondeggia di quattro centimetri, in un fotogramma ridotto a
## un quarto, si sposta di mezzo pixel: la pellicola direbbe «fermo» su
## un movimento che c'e'. Si ritaglia invece una finestra a piena
## risoluzione attorno alla pancia della campata — la stessa finestra
## per tutte e tre le righe, calcolata una volta sulla posa di riposo,
## o le righe non sarebbero piu' confrontabili.
const CELLA := Vector2i(620, 360)

## IL SOGGETTO sono i FESTONI, e la scelta e' misurata: sono le uniche
## corde del gioco che il vento ha il permesso di muovere per davvero
## (`vento` = 1.0, campate da tre metri, ventisei punti). La corda del
## bucato lo prende al 15% apposta — i teli hanno un'onda loro e una
## corda che ballasse li lascerebbe a mezz'aria — e le funi
## dell'altalena sono ancorate a tutti e due i capi, quindi il sedile
## non si sposta di un millimetro comunque tiri (misurato: 0.8 mm a
## vento 1.8; vedi la nota nella relazione).
##
## LA GEOMETRIA DELLA RIPRESA, e non c'e' scelta: e' aritmetica. Una
## campata si legge se e' TRASVERSALE all'obiettivo; il vento si vede se
## e' TRASVERSALE all'obiettivo; e la campata deve stare di traverso al
## vento, o invece di dondolare si limita a sbilenchirsi. Tre condizioni
## che, con la camera orizzontale, non stanno insieme: campata e vento
## finirebbero tutti e due lungo l'unica direzione trasversale che c'e'
## — cioe' paralleli fra loro. E' per questo che le prime due
## inquadrature erano sbagliate, non per il gusto della camera.
##
## La quarta direzione la da' l'ALTO. Con la camera in alto che guarda
## in giu' a 39 gradi, il verticale dello schermo ha una componente
## orizzontale: le campate stanno lungo Z (attraversano il quadro da
## sinistra a destra), il vento soffia lungo X (verso il fondo del
## quadro) e il suo scarto si legge come un movimento verso l'ALTO
## dell'immagine, al 63% della sua misura vera. Misurato: 165 pixel per
## metro a questa distanza, quindi i 12,6 cm di differenza fra le due
## righe del temporale valgono 13 pixel di corda spostata.
const DIR_VENTO := 0.0
## Dove guarda la camera, e quindi quale campata e' il soggetto.
const MIRA := Vector3(10.0, 1.45, 11.5)

var _cam: Camera3D
var _eti: Label
var _ritaglio := Rect2i()
var _corde: Node
var _weather: Node
var _build: Node


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _go() -> void:
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 30:
		await process_frame

	_build = _trova("build_system")
	_weather = _trova("weather")
	_corde = get_root().get_node_or_null("MainLevel/CordeVive")
	var dn := _trova("daynight")
	if _build == null or _weather == null or _corde == null:
		push_error("villaggio incompleto")
		quit(1)
		return
	_build.set("_persist", false)
	if dn != null:
		dn.call("set_time", 0.42)     # mattina piena: si vede tutto

	# IL PALCOSCENICO: quattro pali in fila lungo X, cioe' tre campate di
	# festone da tre metri — piu' uno stendino e un'altalena, che ci
	# stanno per confronto (loro il vento quasi non lo sentono, ed e'
	# voluto: vedi la nota in cima).
	for cz in [7, 10, 13, 16]:
		_build.call("place_cell", Vector2i(10, cz), "Palo lucine", 0, false, 0, "")
	_build.call("place_cell", Vector2i(13, 9), "Stendino", 0, false, 0, "")
	_build.call("place_cell", Vector2i(13, 14), "Altalena", 0, false, 0, "")
	_build.call("aggiorna_festoni_ora")
	for _i in 8:
		await process_frame
	_corde.call("_censisci")

	# LA PIOGGIA SEGUE IL GIOCATORE (particelle in spazio mondo): senza
	# portare Mochi qui dietro, il temporale cade dove sta lei e le due
	# righe bagnate non si vedono bagnate. Le si mette DIETRO l'obiettivo:
	# fuori campo, e a otto metri dalle corde — il suo fianco le scosta
	# entro 42 cm (RAGGIO_MOCHI) e falserebbe la misura.
	var mochi := get_root().get_node_or_null("MainLevel/Player") as Node3D
	if mochi != null:
		mochi.global_position = Vector3(3.0, mochi.global_position.y, 4.0)

	_cam = Camera3D.new()
	_cam.fov = 54.0
	_cam.current = true
	# IN ALTO, e non solo per la geometria: a (5, 2.7, 5) un albero del
	# villaggio copriva un terzo del quadro e a (9, 2.3, 4.8) la camera
	# stava DENTRO la sua chioma — cinque fotogrammi di fogliame verde.
	# Visto, non supposto: e' la ragione per cui si guardano le immagini.
	_cam.position = Vector3(5.0, 5.4, 11.5)
	get_root().add_child(_cam)
	_cam.look_at(MIRA, Vector3.UP)

	var strato := CanvasLayer.new()
	get_root().add_child(strato)
	_eti = Label.new()
	_eti.add_theme_font_size_override("font_size", 27)
	_eti.add_theme_color_override("font_color", Color(1, 1, 1))
	_eti.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_eti.add_theme_constant_override("outline_size", 7)
	# la scritta va DENTRO il ritaglio, o la pellicola esce senza nomi:
	# la si posa quando il ritaglio e' noto (vedi `_mira`)
	_eti.position = Vector2(36, 985)
	strato.add_child(_eti)

	var dove := OS.get_environment("CHIBI_CORDE_PROVINO")
	if dove == "":
		dove = "docs/catalogo/provini-corde-vento"
	DirAccess.make_dir_recursive_absolute(dove)

	var righe: Array = []
	var nude: Array = []
	var misure: Array = []
	for cond in [
			{"id": "1-bonaccia", "eti": "BONACCIA — il cielo tira 1.0",
				"pioggia": false, "forzato": -1.0},
			{"id": "2-temporale-prima", "eti": "TEMPORALE, PRIMA — le corde sentono 1.0",
				"pioggia": true, "forzato": 1.0},
			{"id": "3-temporale-ora", "eti": "TEMPORALE, ORA — le corde sentono 1.8",
				"pioggia": true, "forzato": -1.0}]:
		var r: Array = await _pellicola(cond, dove)
		righe.append(r[0])
		misure.append(r[1])
		nude.append(r[2])

	_monta(righe, dove + "/pellicola.jpg")
	if nude.size() >= 3:
		_sovrapponi(nude[1], nude[2], dove + "/confronto.jpg")
	print("=== LA PANCIA DELLA CAMPATA (m) ===")
	for i in misure.size():
		print("%-22s  spinta %+.4f   onda (picco-picco) %.4f   scarto max %.4f   vento visto %.2f"
				% [str(misure[i]["id"]), float(misure[i]["spinta"]),
					float(misure[i]["pp"]), float(misure[i]["max"]),
					float(misure[i]["forza"])])
	print("provino in %s" % dove)
	quit(0)


## Una pellicola: rimette le corde alla posa di riposo, riporta indietro
## gli orologi, lascia stabilire il moto e poi scatta a intervalli fissi.
func _pellicola(cond: Dictionary, dove: String) -> Array:
	if bool(cond["pioggia"]):
		_weather.call("_start_rain")
		_weather.set("_snowing", false)
		_weather.call("_apply_precip_look")
		_weather.set("_gloom_target", 1.0)
		_weather.set("_vento", 1.8)
	else:
		_weather.call("_stop_rain")
		_weather.set("_state", "clear")
		_weather.set("_gloom_target", 0.0)
		_weather.set("_vento", 1.0)
	_weather.set("_timer", 9999.0)
	_corde.set("vento_forzato", float(cond["forzato"]))

	# TUTTE E TRE PARTONO DALLO STESSO ISTANTE E DALLA STESSA POSA: la
	# turbolenza e la direzione del vento sono funzioni dell'orologio, e
	# confrontare tre spezzoni presi in tre momenti diversi vorrebbe dire
	# confrontare tre venti diversi.
	_corde.set("_clock", 0.0)
	_corde.set("_dir_vento", DIR_VENTO)
	for c in _corde.get("_corde"):
		var nodo: Node = c["nodo"]
		if not is_instance_valid(nodo) or not nodo.has_meta("posa"):
			continue
		var posa: Array = nodo.get_meta("posa")
		c["punti"] = posa.duplicate()
		c["prev"] = posa.duplicate()

	var t := 0.0
	while t < ASSESTA:
		await process_frame
		t += 1.0 / 60.0

	# LA PANCIA DELLA CAMPATA PIU' LUNGA: e' lei che dice se il vento
	# c'e'. Si guarda il punto a meta' corda, contro la sua posa di
	# riposo — la stessa lettura (`campiona`) che usano il gestore e i
	# builder, mai una formula parallela.
	# SI SCEGLIE LA CAMPATA INQUADRATA, non «la piu' lunga del mondo»: il
	# villaggio ne ha gia' di sue (il Ponticello ne ha tre, e i suoi
	# parapetti battevano i festoni) e il ritaglio finiva sull'erba, a
	# fotografare un movimento che non c'era in quadro. Si prende il
	# festone piu' vicino al punto in cui guarda la camera.
	var lunga: Dictionary = {}
	var vicino := 1e20
	for c in _corde.get("_corde"):
		if not is_instance_valid(c["nodo"]):
			continue
		var nodo := c["nodo"] as Node3D
		if nodo.get_parent() == null or not str(nodo.get_parent().name).begins_with("Festone"):
			continue
		var m: Dictionary = nodo.get_meta("corda")
		var meta_mondo: Vector3 = nodo.global_transform \
				* FISICA.campiona(nodo.get_meta("posa"), 0.5)
		var d: float = meta_mondo.distance_to(MIRA)
		if d < vicino:
			vicino = d
			lunga = c
	if not lunga.is_empty() and _ritaglio.size == Vector2i.ZERO:
		var mm: Dictionary = (lunga["nodo"] as Node).get_meta("corda")
		print("campata scelta: %s   %.2f m   vento %.2f   a %.2f m dalla mira"
				% [str((lunga["nodo"] as Node).get_parent().name),
					(mm["a"] as Vector3).distance_to(mm["b"]),
					float(mm.get("vento", 1.0)), vicino])
	var riposo := Vector3.ZERO
	if not lunga.is_empty():
		riposo = FISICA.campiona((lunga["nodo"] as Node).get_meta("posa"), 0.5)
		_mira(lunga["nodo"] as Node3D, riposo)
	# L'ONDA SI MISURA SULL'ASSE DEL VENTO, non su un asse a caso: la
	# prima stesura leggeva sempre Z e, quando l'inquadratura ha portato
	# il vento su X, dichiarava «1,6 mm» su una corda che si muoveva.
	var asse := Vector3(cos(DIR_VENTO), 0.0, sin(DIR_VENTO))
	var lungo_min := 9.0e9
	var lungo_max := -9.0e9
	var scarto := 0.0

	var fotogrammi: Array = []
	var nudi: Array = []          # gli stessi scatti SENZA la scritta
	for k in SCATTI:
		var fine := Time.get_ticks_usec() + int(PASSO * 1000000.0)
		while Time.get_ticks_usec() < fine:
			await process_frame
			if not lunga.is_empty():
				var p: Vector3 = FISICA.campiona(lunga["punti"], 0.5)
				scarto = maxf(scarto, p.distance_to(riposo))
				var u: float = (p - riposo).dot(asse)
				lungo_min = minf(lungo_min, u)
				lungo_max = maxf(lungo_max, u)
		_eti.text = "%s   +%.1f s" % [str(cond["eti"]), float(k) * PASSO]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_jpg("%s/%s-%d.jpg" % [dove, str(cond["id"]), k], 0.93)
		fotogrammi.append(img.get_region(_ritaglio))
		# e lo stesso scatto SENZA scritta: nella sovrapposizione due
		# didascalie diverse si sdoppierebbero, e l'unica cosa che ha il
		# diritto di sdoppiarsi li' dentro e' la corda
		_eti.visible = false
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		nudi.append(get_root().get_texture().get_image().get_region(_ritaglio))
		_eti.visible = true

	return [fotogrammi, {"id": str(cond["id"]), "max": scarto,
			"pp": lungo_max - lungo_min, "spinta": (lungo_max + lungo_min) * 0.5,
			"forza": float(_corde.call("_forza_vento"))}, nudi]


## La finestra di ritaglio: centrata sulla pancia della campata, in
## coordinate di schermo. Si calcola UNA volta sola (alla prima riga) e
## poi non si tocca piu': tre righe ritagliate in tre punti diversi non
## sono una pellicola, sono tre fotografie.
func _mira(nodo: Node3D, pancia_locale: Vector3) -> void:
	if _ritaglio.size != Vector2i.ZERO:
		return
	var mondo: Vector3 = nodo.global_transform * pancia_locale
	var p := _cam.unproject_position(mondo)
	var viewport := Vector2i(get_root().get_texture().get_size())
	var org := Vector2i(int(p.x) - CELLA.x / 2, int(p.y) - CELLA.y / 2)
	org.x = clampi(org.x, 0, maxi(viewport.x - CELLA.x, 0))
	org.y = clampi(org.y, 0, maxi(viewport.y - CELLA.y, 0))
	_ritaglio = Rect2i(org, CELLA)
	_eti.position = Vector2(float(org.x) + 14.0, float(org.y) + 8.0)
	print("mira sullo schermo: %s   quadro %s   ritaglio %s" % [str(p), str(viewport), str(_ritaglio)])


## LA SOVRAPPOSIZIONE: gli stessi istanti delle due righe del temporale,
## mescolati a meta'. Tutto il resto del quadro e' identico — stessa
## camera, stessa pioggia, stesso cielo, stessi pali — quindi l'unica
## cosa che puo' sdoppiarsi e' la corda. Chi guarda non deve confrontare
## due immagini con la memoria: le vede tutte e due insieme.
func _sovrapponi(prima: Array, ora: Array, dove: String) -> void:
	var colonne: int = mini(prima.size(), ora.size())
	if colonne == 0:
		return
	var foglio := Image.create(CELLA.x * colonne, CELLA.y, false, Image.FORMAT_RGB8)
	for c in colonne:
		var a: Image = prima[c]
		var b: Image = ora[c]
		var mix := Image.create(CELLA.x, CELLA.y, false, Image.FORMAT_RGB8)
		for y in CELLA.y:
			for x in CELLA.x:
				mix.set_pixel(x, y, a.get_pixel(x, y).lerp(b.get_pixel(x, y), 0.5))
		foglio.blit_rect(mix, Rect2i(Vector2i.ZERO, CELLA), Vector2i(c * CELLA.x, 0))
	foglio.save_jpg(dove, 0.95)


func _monta(righe: Array, dove: String) -> void:
	if righe.is_empty():
		return
	var colonne: int = (righe[0] as Array).size()
	var foglio := Image.create(CELLA.x * colonne, CELLA.y * righe.size(), false,
			Image.FORMAT_RGB8)
	foglio.fill(Color(0.06, 0.06, 0.07))
	for r in righe.size():
		for c in colonne:
			var img: Image = righe[r][c]
			img.convert(foglio.get_format())
			foglio.blit_rect(img, Rect2i(Vector2i.ZERO, CELLA),
					Vector2i(c * CELLA.x, r * CELLA.y))
	foglio.save_jpg(dove, 0.93)
