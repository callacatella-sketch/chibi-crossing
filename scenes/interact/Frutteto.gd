extends Node

## Il FRUTTETO — il semino raro del passerotto, piantabile.
##
## Il passerotto ogni tanto lascia "il semino raro" (un Tesoro vero delle
## Tasche: Inventory, PASSEROTTO_GIFTS). Con un semino in tasca, su un
## prato libero compare il prompt: E — pianta. Da lì il tempo fa il suo
## mestiere: in UNA STAGIONE (7 giorni) il semino diventa un MELO o un
## PERO — germoglio, alberello, albero giovane, la FIORITURA (un giorno
## di petali bianchi alla deriva) e infine l'albero maturo, che frutta
## OGNI DUE GIORNI. Le mele e le pere vanno nella dispensa del camino
## (nuove ricette: la torta di mele, le pere al miele) e nel bestiario
## come raccolti: il mercante le paga, come carote e zucche.
##
## Tutto procedurale nello stile del mondo (WorldGeo: tronchi piegati,
## chiome a grumi, petali alla deriva), tutto persistito, e il ciclo di
## crescita è logica PURA (stadio/pronto) testata senza SceneTree.

const GEO := preload("res://scenes/world/WorldGeo.gd")
const UI_BROWN := Color("6a4a3a")

## Una stagione intera per crescere: il semino piantato oggi è un albero
## maturo tra GIORNI_CRESCITA mattine. La fioritura è la vigilia.
const GIORNI_CRESCITA := 7
## L'albero maturo frutta ogni due giorni.
const GIORNI_FRUTTA := 2
## Quanti frutti pendono da un albero pronto.
const FRUTTI := 4

## I colori del frutteto: la mela di Critters e la pera di Critters sono
## LA fonte (bestiario); qui solo i toni di legno e foglia.
const CRIT := preload("res://scenes/world/Critters.gd")

# gli alberi piantati: {x, z, specie ("melo"|"pero"), nato (giorno),
#   raccolto (ultimo giorno di raccolta), seed} — i nodi vivono a parte
var _alberi: Array[Dictionary] = []
var _nodi: Array = []            # Node3D per albero (stesso indice)
var _frutti_nodi: Array = []     # Array di frutti appesi per albero

var _player: Node3D
var _build: Node3D
var _daynight: Node3D
var _inventory: Node
var _cooking: Node
var _visitors: Node
var _sfx

var _prompt: PanelContainer
var _prompt_label: Label
var _vicino := -1               # indice dell'albero a portata (-1 = nessuno)
var _puo_piantare := false
var _check_cd := 0.0


func _ready() -> void:
	add_to_group("frutteto")
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		_player = get_node_or_null("%Player")
		_build = get_node_or_null("../BuildSystem")
		_daynight = get_node_or_null("../DayNight")
		_inventory = get_node_or_null("../Inventory")
		_cooking = get_node_or_null("../Cooking")
		_visitors = get_node_or_null("../Visitors")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)).call_deferred()


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


# ------------------------------------------------------------ il cuore puro
# (testato senza SceneTree in tests/cases/test_frutteto.gd)

## Lo stadio di crescita a `giorni` dall'impianto. La fioritura è la
## vigilia della maturità: un giorno solo, e va vissuto.
static func stadio(giorni: int) -> String:
	if giorni >= GIORNI_CRESCITA:
		return "maturo"
	if giorni == GIORNI_CRESCITA - 1:
		return "fioritura"
	if giorni >= 4:
		return "giovane"
	if giorni >= 2:
		return "alberello"
	return "germoglio"


## L'albero ha frutti pronti? Maturo, e sono passati almeno GIORNI_FRUTTA
## dall'ultimo raccolto (il primo raccolto arriva CON la maturità).
static func pronto(giorni_eta: int, giorni_da_raccolto: int) -> bool:
	return giorni_eta >= GIORNI_CRESCITA and giorni_da_raccolto >= GIORNI_FRUTTA


# ------------------------------------------------------------- il calendario

func _nuovo_giorno(_d: int) -> void:
	for i in _alberi.size():
		_aggiorna_albero(i, true)


# ------------------------------------------------------------------ piantare

## Quanti semini rari ci sono nelle Tasche (la fonte è l'Inventory).
func _semini() -> int:
	if _inventory == null:
		return 0
	return int((_inventory.get("treasures") as Dictionary).get("semino", 0))


# il posto è degno di un albero? Erba vera, lontano dai pezzi del
# villaggio, dagli alberi del bosco e dagli altri alberi da frutto
func _posto_libero(pos: Vector3) -> bool:
	if _build == null or str(_build.call("surface_at", pos)) != "grass":
		return false
	if bool(_build.call("has_cover", Vector2i(roundi(pos.x), roundi(pos.z)))):
		return false
	for a in _alberi:
		if Vector2(pos.x - float(a["x"]), pos.z - float(a["z"])).length() < 2.0:
			return false
	for t in get_tree().get_nodes_in_group("albero"):
		if t is Node3D and (t as Node3D).global_position.distance_to(pos) < 2.2:
			return false
	return true


## Pianta un semino nel punto dato: lo consuma dalle Tasche, decide la
## specie (melo o pero, per sempre) e mette a dimora il germoglio con la
## sua zolla. Ritorna false se non c'è semino o il posto non va.
func pianta(pos: Vector3) -> bool:
	if _semini() <= 0 or not _posto_libero(pos):
		return false
	_inventory.call("take_treasure", "semino")
	var seed_v := randi() % 100000
	var specie := "melo" if seed_v % 2 == 0 else "pero"
	var riga := {"x": pos.x, "z": pos.z, "specie": specie,
			"nato": _day(), "raccolto": _day(), "seed": seed_v}
	_alberi.append(riga)
	_nodi.append(null)
	_frutti_nodi.append([])
	_aggiorna_albero(_alberi.size() - 1, false)
	# la zolla smossa e le scintille della speranza
	var nodo := _nodi[_alberi.size() - 1] as Node3D
	if nodo:
		_zolla(nodo)
		_sparkle(pos + Vector3(0, 0.35, 0), Color(0.8, 1.0, 0.6))
	_toast("Il semino raro è a dimora. Chissà cosa nasconde…")
	if _sfx:
		_sfx.place_ok()
	if _build:
		_build.request_save()
	return true


# ------------------------------------------------------- la crescita visiva

# (ri)costruisce l'albero `i` per lo stadio di oggi. Con `festeggia` i
# passaggi si vedono: il pop di crescita, i petali della fioritura, il
# toast del primo frutto.
func _aggiorna_albero(i: int, festeggia: bool) -> void:
	var a: Dictionary = _alberi[i]
	var eta := _day() - int(a["nato"])
	var st := stadio(eta)
	var prima := str(a.get("stadio_visto", ""))
	a["stadio_visto"] = st
	var vecchio := _nodi[i] as Node3D
	if vecchio and is_instance_valid(vecchio):
		vecchio.queue_free()
	var nodo := _costruisci(a, st)
	nodo.position = Vector3(float(a["x"]), 0, float(a["z"]))
	add_child(nodo)
	_nodi[i] = nodo
	# i frutti, se è il momento
	_frutti_nodi[i] = []
	if st == "maturo" and pronto(eta, _day() - int(a["raccolto"])):
		_appendi_frutti(i, nodo, a)
	if not festeggia or prima == st or prima == "":
		return
	# il passaggio di stadio SI VEDE: pop di crescita e scintille
	var base_scale := nodo.scale
	nodo.scale = base_scale * 0.7
	var tw := create_tween()
	tw.tween_property(nodo, "scale", base_scale, 0.7) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sparkle(nodo.position + Vector3(0, 0.8, 0), Color(0.75, 1.0, 0.55))
	match st:
		"fioritura":
			_toast("🌸 Il piccolo %s è in fiore: domani i primi frutti!"
					% str(a["specie"]))
		"maturo":
			_toast("Il %s è cresciuto: i primi %s pendono dai rami!"
					% [str(a["specie"]), _nome_frutti(a)])


func _nome_frutto(a: Dictionary) -> String:
	return "mela" if str(a["specie"]) == "melo" else "pera"


func _nome_frutti(a: Dictionary) -> String:
	return "mele" if str(a["specie"]) == "melo" else "pere"


func _costruisci(a: Dictionary, st: String) -> Node3D:
	var n := Node3D.new()
	var seed_v := int(a["seed"])
	var legno := GEO.paint_mat(Color("9a7148"), Color("7c5836"), 5.0, 0.5)
	var foglia := GEO.paint_mat(Color("7fb95e"), Color("5f9a44"), 5.0, 0.5, 0.35)
	match st:
		"germoglio":
			# due foglioline tenere su uno stelo, appena nate
			var stelo := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.012
			cm.bottom_radius = 0.018
			cm.height = 0.16
			stelo.mesh = cm
			stelo.material_override = GEO.paint_mat(Color("8fbf6a"), Color("6fa050"))
			stelo.position = Vector3(0, 0.08, 0)
			n.add_child(stelo)
			for lato: float in [-1.0, 1.0]:
				var fogliolina := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.05
				sm.height = 0.1
				fogliolina.mesh = sm
				fogliolina.material_override = foglia
				fogliolina.scale = Vector3(1.4, 0.35, 0.7)
				fogliolina.position = Vector3(lato * 0.055, 0.17, 0)
				fogliolina.rotation.z = lato * 0.5
				n.add_child(fogliolina)
		"alberello":
			_tronco(n, 0.5, 0.045, 0.028, seed_v, legno)
			_chioma(n, 0.26, 0.62, seed_v, foglia)
		"giovane":
			_tronco(n, 0.85, 0.07, 0.04, seed_v, legno)
			_chioma(n, 0.42, 1.05, seed_v, foglia)
		"fioritura":
			_tronco(n, 1.05, 0.085, 0.05, seed_v, legno)
			_chioma(n, 0.5, 1.3, seed_v, foglia)
			_fiori(n, seed_v)
		_:
			# il MATURO: tronco pieno, chioma a due grumi come i suoi
			# fratelli del bosco — ma coi frutti che lo distinguono
			_tronco(n, 1.2, 0.1, 0.06, seed_v, legno)
			_chioma(n, 0.58, 1.5, seed_v, foglia)
			_chioma(n, 0.4, 1.85, seed_v + 7, foglia)
	return n


func _tronco(n: Node3D, h: float, rb: float, rt: float, seed_v: int,
		mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = GEO.trunk_mesh(h, rb, rt, seed_v)
	mi.material_override = mat
	n.add_child(mi)


func _chioma(n: Node3D, r: float, y: float, seed_v: int, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = GEO.puff_mesh(r, seed_v, 0.8, 0.11, 14, 8)
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	n.add_child(mi)


# la FIORITURA: la chioma si copre di boccioli bianco-rosa e per tutto il
# giorno i petali vanno alla deriva — è la vigilia, e si deve vedere
func _fiori(n: Node3D, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var petalo := GEO.paint_mat(Color("fbeff2"), Color("f2d8e2"), 6.0, 0.4)
	for i in 9:
		var a := rng.randf() * TAU
		var el := rng.randf_range(0.15, 1.1)
		var r := 0.5 * sqrt(1.0 - pow(el / 1.4, 2.0) * 0.5)
		var bocciolo := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.05, 0.08)
		sm.height = sm.radius * 2.0
		bocciolo.mesh = sm
		bocciolo.material_override = petalo
		bocciolo.scale = Vector3(1, 0.75, 1)
		bocciolo.position = Vector3(cos(a) * r, 1.3 + el * 0.35, sin(a) * r)
		n.add_child(bocciolo)
	var deriva := GEO.drift_emitter(GEO.soft_circle(Color(1.0, 0.93, 0.96), 0.5),
			10, 0.05, Vector3(1.4, 1.0, 1.4), Vector3(0, -0.22, 0), 5.0, true)
	deriva.position = Vector3(0, 1.6, 0)
	n.add_child(deriva)


# i frutti appesi: mele tonde col picciolo, pere a goccia (lathe), ognuna
# al suo posto sotto la chioma — deterministiche dal seed dell'albero
func _appendi_frutti(i: int, nodo: Node3D, a: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a["seed"]) + 31
	var lista := []
	for k in FRUTTI:
		var frutto := _frutto(a)
		# i frutti pendono SOTTO l'orlo del fogliame (la chioma sta a
		# y≈1.05..1.95): dentro il volume verde non si vedrebbero affatto
		var ang := rng.randf() * TAU + float(k) * TAU / float(FRUTTI)
		var r := rng.randf_range(0.34, 0.52)
		frutto.position = Vector3(cos(ang) * r,
				rng.randf_range(0.92, 1.1), sin(ang) * r)
		frutto.rotation.y = rng.randf() * TAU
		# un dondolio impercettibile, ognuno col suo tempo: sono VIVI
		var tw := frutto.create_tween().set_loops()
		var fase := rng.randf_range(1.8, 2.6)
		tw.tween_property(frutto, "rotation:z", 0.06, fase) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(frutto, "rotation:z", -0.06, fase) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		nodo.add_child(frutto)
		lista.append(frutto)
	_frutti_nodi[i] = lista


func _frutto(a: Dictionary) -> Node3D:
	var n := Node3D.new()
	var id := _nome_frutto(a)
	var col: Color = CRIT.colore(id)
	var polpa := GEO.paint_mat(col, col.darkened(0.18), 4.0, 0.4)
	if id == "mela":
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.062
		sm.height = 0.124
		mi.mesh = sm
		mi.material_override = polpa
		mi.scale = Vector3(1, 0.92, 1)
		n.add_child(mi)
	else:
		# la PERA è una pera: superficie di rivoluzione a goccia
		var profilo := [Vector2(0.0, 0.0), Vector2(0.042, 0.012),
				Vector2(0.058, 0.045), Vector2(0.05, 0.085),
				Vector2(0.03, 0.115), Vector2(0.016, 0.135), Vector2(0.0, 0.148)]
		preload("res://scenes/npc/ChibiBuilder.gd").lathe(
				n, profilo, polpa, Vector3(0, -0.075, 0), 16)
	# picciolo e fogliolina, per entrambi
	var picciolo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.008
	cm.height = 0.05
	picciolo.mesh = cm
	picciolo.material_override = GEO.paint_mat(Color("6e5138"), Color("55402c"))
	picciolo.position = Vector3(0, 0.075, 0)
	n.add_child(picciolo)
	var fogl := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.03
	fm.height = 0.06
	fogl.mesh = fm
	fogl.material_override = GEO.paint_mat(Color("7fb95e"), Color("5f9a44"))
	fogl.scale = Vector3(1.4, 0.3, 0.7)
	fogl.position = Vector3(0.03, 0.095, 0)
	fogl.rotation.z = -0.5
	n.add_child(fogl)
	return n


# la zolla di terra smossa ai piedi del nuovo nato
func _zolla(nodo: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.2
	cm.height = 0.05
	mi.mesh = cm
	mi.material_override = GEO.paint_mat(Color("8a6a4a"), Color("6e5138"), 6.0, 0.55)
	mi.position = Vector3(0, 0.025, 0)
	nodo.add_child(mi)


# ------------------------------------------------------------- il raccolto

## Raccoglie i frutti dell'albero `i`: ognuno si stacca, rimbalza a terra
## con uno spruzzo succoso e vola in dispensa. Poi due giorni di attesa.
func raccogli(i: int) -> void:
	if i < 0 or i >= _alberi.size():
		return
	var a: Dictionary = _alberi[i]
	if not pronto(_day() - int(a["nato"]), _day() - int(a["raccolto"])):
		return
	a["raccolto"] = _day()
	var id := _nome_frutto(a)
	var col: Color = CRIT.colore(id)
	# la coreografia: i frutti si staccano uno dopo l'altro
	var lista: Array = _frutti_nodi[i]
	for k in lista.size():
		var frutto := lista[k] as Node3D
		if frutto == null or not is_instance_valid(frutto):
			continue
		var tw := create_tween()
		tw.tween_interval(0.12 * float(k))
		tw.tween_property(frutto, "position:y", frutto.position.y - 0.9, 0.45) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(frutto, "rotation:z", 0.7, 0.45)
		var fpos: Vector3 = (_nodi[i] as Node3D).position + frutto.position
		tw.tween_callback(func():
			if is_instance_valid(self):
				_sparkle(fpos * Vector3(1, 0, 1) + Vector3(0, 0.3, 0), col)
			if is_instance_valid(frutto):
				frutto.queue_free())
	_frutti_nodi[i] = []
	if _cooking and _cooking.has_method("add_ingredient"):
		_cooking.call("add_ingredient", id, FRUTTI)
	_toast("+%d %s nella dispensa! (il %s rifrutta tra %d giorni)"
			% [FRUTTI, _nome_frutti(a), str(a["specie"]), GIORNI_FRUTTA])
	if _sfx:
		_sfx.place_ok()
	if _build:
		_build.request_save()


# ---------------------------------------------------------------- interazione

func _process(delta: float) -> void:
	_check_cd -= delta
	if _check_cd <= 0.0:
		_check_cd = 0.2
		_ricontrolla()
	_update_prompt()


func _ricontrolla() -> void:
	_vicino = -1
	_puo_piantare = false
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	for i in _alberi.size():
		var a: Dictionary = _alberi[i]
		if Vector2(pp.x - float(a["x"]), pp.z - float(a["z"])).length() < 1.7 \
				and pronto(_day() - int(a["nato"]), _day() - int(a["raccolto"])):
			_vicino = i
			return
	if _semini() > 0 and pp.y < 0.5 and _posto_libero(pp):
		_puo_piantare = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _player == null:
		return
	# il player congelato da un'altra modalità: non ci si intromette
	if not _player.is_physics_processing():
		return
	if _vicino >= 0:
		raccogli(_vicino)
		_ricontrolla()
		get_viewport().set_input_as_handled()
	elif _puo_piantare:
		if pianta(_player.global_position):
			_ricontrolla()
			get_viewport().set_input_as_handled()


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		_prompt.visible = false
		return
	var testo := ""
	var anchor := _player.global_position
	if _vicino >= 0:
		var a: Dictionary = _alberi[_vicino]
		testo = "E — raccogli le %s" % _nome_frutti(a)
		anchor = Vector3(float(a["x"]), 0, float(a["z"]))
	elif _puo_piantare:
		testo = "E — pianta il semino raro"
	if testo == "":
		_prompt.visible = false
		return
	var wp := anchor + Vector3(0, 1.9, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = testo
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


# ---------------------------------------------------------------- servizi

func _sparkle(pos: Vector3, color: Color) -> void:
	var mail := get_node_or_null("../Mail")
	if mail and mail.has_method("_sparkle"):
		mail.call("_sparkle", pos, color)


func _toast(text: String) -> void:
	if _visitors:
		_visitors.call("_show_toast", text)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for a in _alberi:
		rows.append([float(a["x"]), float(a["z"]), str(a["specie"]),
				int(a["nato"]), int(a["raccolto"]), int(a["seed"])])
	return {"frutteto": rows}


func load_extra(data: Dictionary) -> void:
	for r in data.get("frutteto", []):
		if r is Array and r.size() == 6:
			_alberi.append({"x": float(r[0]), "z": float(r[1]),
					"specie": str(r[2]), "nato": int(r[3]),
					"raccolto": int(r[4]), "seed": int(r[5])})
			_nodi.append(null)
			_frutti_nodi.append([])
	(func():
		for i in _alberi.size():
			_aggiorna_albero(i, false)).call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_stato() -> Array:
	var out := []
	for a in _alberi:
		out.append("%s: eta %d (%s), frutti pronti = %s" % [a["specie"],
				_day() - int(a["nato"]), stadio(_day() - int(a["nato"])),
				pronto(_day() - int(a["nato"]), _day() - int(a["raccolto"]))])
	return out


## Pianta d'ufficio (per la verifica CLI): specie forzata, niente semino.
func debug_pianta(pos: Vector3, specie := "melo") -> void:
	var seed_v := randi() % 100000
	if specie == "melo" and seed_v % 2 == 1:
		seed_v += 1
	elif specie == "pero" and seed_v % 2 == 0:
		seed_v += 1
	_alberi.append({"x": pos.x, "z": pos.z, "specie": specie,
			"nato": _day(), "raccolto": _day(), "seed": seed_v})
	_nodi.append(null)
	_frutti_nodi.append([])
	_aggiorna_albero(_alberi.size() - 1, false)


func debug_raccogli(i: int) -> void:
	raccogli(i)
