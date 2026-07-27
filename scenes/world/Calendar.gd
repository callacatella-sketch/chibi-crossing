extends Node3D

## Il calendario del villaggio. Ogni nuovo abitante, appena trasloca,
## va alla Lavagna e ci SCRIVE il suo compleanno col gessetto — così
## Mochi può organizzare le feste a sorpresa: il giorno giusto, regala
## un piatto del camino al festeggiato e il villaggio esplode in
## coriandoli, con tutti che accorrono a ballare. E ogni tanto passa il
## MERCANTE col suo carretto: annunciato sulla lavagna, baratta un
## piatto caldo con un sacchetto di ingredienti rari.
## Con E davanti alla Lavagna: gli eventi in arrivo, in bella copia.
##
## E le FESTE STAGIONALI: una per stagione, nel cuore della settimana,
## ognuna nel suo posto del villaggio — l'hanami sotto il Grande Albero,
## la notte delle lucciole allo stagno, la sagra del raccolto all'orto,
## il pupazzo di neve in piazza. Annunciate la vigilia sulla lavagna,
## il giorno giusto tutti i residenti accorrono (come al falò la sera)
## e la cronaca finisce incisa negli anelli del Grande Albero.

const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const CHIBIESE := preload("res://audio/Chibiese.gd")
const FACE := preload("res://scenes/characters/FaceController.gd")

const UI_BROWN := Color("6a4a3a")
const CYCLE := 14          # i compleanni tornano ogni due settimane
const MERCHANT_EVERY := 6

# il calendario delle stagioni e i posti del mondo: fonti uniche, non copie
const DN := preload("res://scenes/world/DayNight.gd")
const COZY := preload("res://scenes/world/CozyWorld.gd")

## Le quattro feste dell'anno: una per stagione, il 4° dei suoi 7 giorni
## (il cuore della settimana: c'è tempo per prepararsi e tempo per i
## ritardatari). "notte" dice QUANDO scatta nel giorno della festa: solo
## le lucciole aspettano il buio, le altre si fanno col sole. "luogo" è
## risolto da _festa_spot (il mondo può cambiare, il posto si ricalcola).
const FESTE := [
	{"id": "hanami", "season": 0, "day": 4, "nome": "hanami",
		"evento": "hanami sotto il Grande Albero", "notte": false, "luogo": "albero", "icona": "✿",
		"annuncio": "Domani è hanami: picnic sotto il Grande Albero!",
		"toast": "È hanami! Tutti al picnic, sotto la neve rosa dei petali!",
		"cronaca": "l'hanami sotto il Grande Albero, coi petali nel tè"},
	{"id": "lucciole", "season": 1, "day": 4, "nome": "notte delle lucciole",
		"evento": "la notte delle lucciole allo stagno", "notte": true, "luogo": "stagno", "icona": "✧",
		"annuncio": "Domani sera, allo stagno: la notte delle lucciole!",
		"toast": "La notte delle lucciole! Tutti allo stagno, a lume spento!",
		"cronaca": "la notte delle lucciole, contate a bocca aperta"},
	{"id": "sagra", "season": 2, "day": 4, "nome": "sagra del raccolto",
		"evento": "la sagra del raccolto all'orto", "notte": false, "luogo": "orto", "icona": "✦",
		"annuncio": "Domani è la sagra del raccolto: portate le ceste!",
		"toast": "La sagra del raccolto! Tutti all'orto con le ceste piene!",
		"cronaca": "la sagra del raccolto, a pancia piena"},
	{"id": "pupazzo", "season": 3, "day": 4, "nome": "pupazzo di neve",
		"evento": "il pupazzo di neve in piazza", "notte": false, "luogo": "piazza", "icona": "❄",
		"annuncio": "Domani, se nevica ancora: il pupazzo di neve in piazza!",
		"toast": "Il pupazzo di neve! Tutti in piazza a far palle di neve!",
		"cronaca": "il pupazzo di neve in piazza, col naso di carota"},
]


## La festa che cade nel giorno assoluto `day` ({} se è un giorno qualsiasi).
## PURA e statica: la interroga anche il test, senza SceneTree.
static func festa_del_giorno(day: int) -> Dictionary:
	@warning_ignore("integer_division")
	var stagione := ((day - 1) % DN.YEAR_DAYS) / DN.SEASON_DAYS
	var nel_mese := (day - 1) % DN.SEASON_DAYS + 1
	for f in FESTE:
		if int(f["season"]) == stagione and int(f["day"]) == nel_mese:
			return f
	return {}


## La prossima festa da oggi (incluso): [giorno_assoluto, festa]. Per la
## lavagna e il pannello degli eventi.
static func prossima_festa(day: int) -> Array:
	for delta in DN.YEAR_DAYS:
		var f := festa_del_giorno(day + delta)
		if not f.is_empty():
			return [day + delta, f]
	return [day, {}]  # impossibile con FESTE non vuota: difesa

# la stagione sulla lavagna: un colore di gessetto e un annuncio ciascuna
const SEASON_CHALK := [Color(0.86, 0.98, 0.82, 0.92), Color(0.98, 0.95, 0.72, 0.92),
		Color(0.99, 0.82, 0.6, 0.92), Color(0.82, 0.92, 1.0, 0.94)]
const SEASON_TOAST := ["È arrivata la primavera: i ciliegi sono in fiore!",
		"È arrivata l'estate: il prato è di un verde pieno!",
		"È arrivato l'autunno: le foglie si accendono d'oro e di rame!",
		"È arrivato l'inverno: la neve copre il villaggio!"]

var _daynight: Node3D
var _build: Node3D
var _visitors: Node
var _player: Node3D
var _mail: Node
var _sfx

# name -> {"label": String, "anchor": int} — il giorno-ancora del compleanno
var _birthdays := {}
var _merchant_day := 4
var _party_done := {}
var _last_season := -1

# le feste stagionali: quella di oggi in attesa del suo momento, e il
# registro "id|giorno" delle già fatte (persistito: un reload a festa
# avvenuta non la rilancia)
var _festa_pending := {}
var _feste_done := {}
var _snowman: Node3D

# il mercante in visita
var _merchant: Node3D
var _merchant_voice := {}
var _merchant_vp: AudioStreamPlayer3D
var _merchant_face   # il volto vivo del mercante (ammicca, ti guarda, sorride)
var _merchant_mood := "felice"
var _stall: Node3D

var _open := false
var _panel: PanelContainer
var _rows: VBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("calendario")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		_player = get_node_or_null("../../Player")
		_daynight = get_node_or_null("../../DayNight")
		_build = get_tree().get_first_node_in_group("build_system")
		_visitors = get_node_or_null("../../Visitors")
		_mail = get_node_or_null("../../Mail")
		if _daynight:
			_daynight.day_changed.connect(_on_new_day)
			if _daynight.has_method("get_season"):
				_last_season = int(_daynight.get_season())
		if _build and _build.has_signal("placed_changed"):
			_build.connect("placed_changed", _refresh_board_cache)
		_refresh_board_cache()
		_refresh_boards()
		# salvato e uscito col mercante in città: rieccolo al suo posto
		var today := _day()
		if today == _merchant_day and _merchant == null:
			_spawn_merchant()
		elif today > _merchant_day:
			_merchant_day = today + 1 + randi() % 3
		# salvato e riaperto nel giorno di una festa non ancora fatta:
		# la festa aspetta ancora il suo momento
		var festa := festa_del_giorno(today)
		if not festa.is_empty() and not _feste_done.has(_festa_key(festa, today)):
			_festa_pending = festa).call_deferred()


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


# ---------------------------------------------------------------- iscrizioni

## Un nuovo abitante: gli si assegna il compleanno e va a scriverlo
## sulla lavagna col gessetto (se una lavagna esiste).
func register_resident(res_name: String, label: String, node: Node3D) -> void:
	if _birthdays.has(res_name):
		return
	var anchor := _day() + 3 + hash(res_name) % CYCLE
	_birthdays[res_name] = {"label": label, "anchor": anchor}
	var board := _nearest_board(node.global_position if node else Vector3.ZERO)
	if board and node:
		# prima si sistema in casa (la valigia!), poi corre alla lavagna
		var front: Vector3 = board.global_transform * Vector3(0, 0, -0.9)
		front.y = 0.0
		get_tree().create_timer(6.5).timeout.connect(func():
			if is_instance_valid(node):
				node.call("go_write", front, board.global_position))
		# il gessetto stride quando arriva, poi la riga appare
		get_tree().create_timer(11.5).timeout.connect(func():
			_refresh_boards()
			if _sfx:
				_sfx.play("step_stone1", -16.0, 1.7))
	else:
		_refresh_boards()
	var toast_day := next_birthday(res_name)
	_toast(L10n.tf("%s segna il suo compleanno sulla lavagna: Giorno %d!", [label, toast_day]))
	if _build:
		_build.request_save()


## Il prossimo compleanno (giorno assoluto) di un residente.
func next_birthday(res_name: String) -> int:
	var b: Dictionary = _birthdays.get(res_name, {})
	if b.is_empty():
		return -1
	var anchor := int(b["anchor"])
	var today := _day()
	if today <= anchor:
		return anchor
	return anchor + ceili(float(today - anchor) / CYCLE) * CYCLE


func is_birthday(res_name: String) -> bool:
	return next_birthday(res_name) == _day()


## La festa a sorpresa: chiamata dai Visitors quando regali un piatto
## al festeggiato nel giorno giusto.
func throw_party(res_name: String, label: String, node: Node3D) -> void:
	var key := "%s|%d" % [res_name, _day()]
	if _party_done.has(key):
		return
	_party_done[key] = true
	_toast(L10n.tf("FESTA A SORPRESA per %s! Tutto il villaggio accorre!", [label]))
	# la prima festa lascia un ricordo indossabile nel guardaroba
	get_tree().call_group("guardaroba", "unlock", "cappellino_festa")
	_confetti(node.global_position + Vector3(0, 1.0, 0))
	if _sfx:
		_sfx.build_open()
		get_tree().create_timer(0.4).timeout.connect(func():
			if _sfx: _sfx.place_ok())
	node.call("celebrate")
	node.call("speak", ["felice", "amico", "grazie"], "felice")
	# gli altri residenti accorrono a ballare
	if _visitors:
		var residents: Array = _visitors.get("_residents")
		for r in residents:
			var other := r.get("node") as Node3D
			if other == null or other == node or not is_instance_valid(other) \
					or other.call("is_hidden"):
				continue
			var off := Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
			other.call("do_routine", "sniff", node.global_position + off, node.global_position)
			other.call("speak", ["felice", "~"], "felice")
			get_tree().create_timer(randf_range(0.8, 1.6)).timeout.connect(func():
				if is_instance_valid(other):
					other.call("celebrate"))
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree:
		gtree.engrave("★", L10n.tf("la festa a sorpresa di %s", [label]))
	if _mail:
		_mail.call("queue_letter", {
			"from": res_name,
			"text": L10n.t("La festa più bella della mia vita!\nCome facevi a saperlo? Ah già…\nla lavagna. Grazie, di cuore."),
			"gift": true,
		})


func _on_new_day(day: int) -> void:
	_refresh_boards()
	# l'arrivo di una nuova stagione: un annuncio caldo sul villaggio
	if _daynight and _daynight.has_method("get_season"):
		var s := int(_daynight.get_season())
		if s != _last_season:
			_last_season = s
			_toast(L10n.t(SEASON_TOAST[s]))
	# compleanni di oggi: cappellino a cono e annuncio
	if _visitors:
		for r in _visitors.get("_residents"):
			var node := r.get("node") as Node3D
			var dna: Dictionary = r.get("dna", {})
			var res_name := str(dna.get("name", ""))
			if node and is_instance_valid(node) and _birthdays.has(res_name):
				var festa := is_birthday(res_name)
				node.call("set_party_hat", festa)
				if festa:
					_toast(L10n.tf("Oggi è il compleanno di %s! Preparagli una sorpresa…", [r["label"]]))
	# le feste stagionali: annuncio la vigilia, festa il giorno giusto (di
	# giorno o al buio: decide _tick_festa), e il pupazzo si scioglie quando
	# l'inverno finisce
	var domani := festa_del_giorno(day + 1)
	if not domani.is_empty():
		_toast(L10n.t(str(domani["annuncio"])))
	var oggi := festa_del_giorno(day)
	if not oggi.is_empty() and not _feste_done.has(_festa_key(oggi, day)):
		_festa_pending = oggi
	else:
		_festa_pending = {}
	if _snowman and _daynight and _daynight.has_method("get_season") \
			and int(_daynight.get_season()) != 3:
		_melt_snowman()
	# il mercante: annuncio il giorno prima, carretto il giorno giusto
	if day == _merchant_day - 1:
		_toast(L10n.t("Domani arriva il mercante col suo carretto!"))
	if day == _merchant_day:
		if _merchant == null:
			_spawn_merchant()
	elif day > _merchant_day:
		# il suo giorno è passato (anche attraverso un salvataggio):
		# riparte e si fissa la prossima visita
		if _merchant:
			_despawn_merchant()
		_merchant_day = day + MERCHANT_EVERY + randi() % 3 - 1
		if _build:
			_build.request_save()


# ---------------------------------------------------------------- lavagna

# cache delle lavagne piazzate: si rinfresca solo quando il villaggio
# cambia (segnale placed_changed), non a ogni frame di _update_prompt
var _cached_boards: Array[Node3D] = []


func _refresh_board_cache() -> void:
	_cached_boards.clear()
	if _build:
		for b in _build.get_placed_by_name("Lavagna"):
			_cached_boards.append(b)


func _boards() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for b in _cached_boards:
		if is_instance_valid(b):
			out.append(b)
	return out


func _nearest_board(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 999.0
	for b in _boards():
		var d: float = pos.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


# le righe di gessetto sulla lavagna: compleanni e mercante
var _chalk := {}


func _refresh_boards() -> void:
	for board in _boards():
		var old = _chalk.get(board)
		if old and is_instance_valid(old):
			(old as Node3D).queue_free()
		var chalk := Node3D.new()
		_chalk[board] = chalk
		board.add_child(chalk)
		var lines: Array[Array] = [[L10n.t("· il calendario ·"), Color(1, 1, 1, 0.92)]]
		# la stagione in cima, col suo gessetto colorato
		if _daynight and _daynight.has_method("season_name"):
			var s := int(_daynight.get_season())
			lines.append(["~ %s ~" % L10n.t(_daynight.season_name()), SEASON_CHALK[s]])
		# coi 28 posti del villaggio la lavagna non basta per tutti: col
		# gessetto si segnano i PROSSIMI sei compleanni, gli altri aspettano
		# il loro turno (il pannello con E li elenca comunque)
		var prossimi: Array = []
		for res_name in _birthdays:
			prossimi.append([next_birthday(str(res_name)), str(res_name)])
		prossimi.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(prossimi.size(), 6):
			lines.append([L10n.tf("%s · G%d", [str(prossimi[i][1]), int(prossimi[i][0])]),
					Color(0.98, 0.85, 0.9, 0.9)])
		if prossimi.size() > 6:
			lines.append([L10n.tf("…e altri %d", [prossimi.size() - 6]),
					Color(0.98, 0.85, 0.9, 0.6)])
		lines.append([L10n.tf("mercante · G%d", [_merchant_day]), Color(0.85, 0.93, 1.0, 0.9)])
		# le commissioni appese: il conto sta sul gessetto, il dettaglio nel pannello
		var comm_n := get_tree().get_first_node_in_group("commissioni")
		if comm_n and int(comm_n.call("quante")) > 0:
			lines.append([L10n.tf("richieste appese · %d", [int(comm_n.call("quante"))]),
					Color(1.0, 0.93, 0.75, 0.92)])
		# la prossima festa stagionale, col gessetto verde tenue
		var pf := prossima_festa(_day())
		if not (pf[1] as Dictionary).is_empty():
			lines.append([L10n.tf("%s · G%d", [L10n.t(str(pf[1]["nome"])), int(pf[0])]),
					Color(0.86, 0.96, 0.84, 0.9)])
		for i in lines.size():
			var lbl := Label3D.new()
			lbl.text = str(lines[i][0])
			lbl.font_size = 40
			lbl.pixel_size = 0.0042
			lbl.modulate = lines[i][1]
			lbl.outline_size = 0
			lbl.double_sided = false
			lbl.position = Vector3(0, 1.36 - float(i) * 0.17, 0.02)
			lbl.rotation.x = 0.05
			lbl.rotation.y = PI
			chalk.add_child(lbl)


# ---------------------------------------------------------------- mercante

func _spawn_merchant() -> void:
	if _merchant:
		return
	var spot := Vector3(1.0, 0, 1.2)
	var board := _nearest_board(Vector3.ZERO)
	if board:
		spot = board.global_position + Vector3(-1.6, 0, 0.6)
	_stall = _make_stall()
	_stall.position = spot
	add_child(_stall)
	var dna: Dictionary = DNA_GEN.generate(777)
	dna["acc"] = "sciarpina"
	_merchant = Node3D.new()
	_merchant.position = spot + Vector3(1.15, 0, 0.35)
	_merchant.rotation.y = 0.9
	add_child(_merchant)
	var parts: Dictionary = BUILDER.build(dna)
	_merchant.add_child(parts["root"])
	if parts.has("face"):
		var rig: Dictionary = parts["face"]
		rig["head"] = parts["head"]
		_merchant_face = FACE.new()
		_merchant_face.setup(rig)
	_merchant_voice = CHIBIESE.voice(dna)
	_merchant_vp = AudioStreamPlayer3D.new()
	_merchant_vp.position = Vector3(0, 0.8, 0)
	_merchant_vp.max_distance = 14.0
	_merchant_vp.volume_db = -8.0
	_merchant.add_child(_merchant_vp)
	for node in [_stall, _merchant]:
		node.scale = Vector3.ONE * 0.05
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3.ONE, 0.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ogni visita rifà il banco (idempotente nel giorno: la ricarica di un
	# salvataggio con il mercante in piazza ritrova lo stesso stock)
	var eco := get_tree().get_first_node_in_group("economy")
	if eco and eco.has_method("rotate_stock"):
		eco.rotate_stock(_day())
	_toast(L10n.t("Il mercante ha aperto il carretto in piazza!"))


func _despawn_merchant() -> void:
	for node in [_stall, _merchant]:
		if node:
			var tw := create_tween()
			tw.tween_property(node, "scale", Vector3.ONE * 0.03, 0.4)
			tw.tween_callback(node.queue_free)
	_merchant = null
	_merchant_face = null
	_stall = null


func _make_stall() -> Node3D:
	# il carretto: due ruote, il banco e il tendone a strisce
	var n := Node3D.new()
	var wood := _pm(Color("c89a6b"), Color("a87c50"))
	var dark := _pm(Color("a87c50"), Color("8a6440"))
	_box(n, Vector3(1.5, 0.5, 0.8), wood, Vector3(0, 0.55, 0))
	_box(n, Vector3(1.56, 0.06, 0.86), dark, Vector3(0, 0.83, 0))
	for sx: float in [-0.6, 0.6]:
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.26
		wm.bottom_radius = 0.26
		wm.height = 0.08
		wheel.mesh = wm
		wheel.material_override = dark
		wheel.position = Vector3(sx, 0.26, 0.42)
		wheel.rotation.x = PI * 0.5
		n.add_child(wheel)
	for sx: float in [-0.68, 0.68]:
		_box(n, Vector3(0.07, 1.3, 0.07), wood, Vector3(sx, 1.3, 0))
	# tendone a strisce rosa e crema
	for i in 6:
		var stripe := _box(n, Vector3(0.26, 0.05, 0.95),
				_pm(Color("f4b8c8"), Color("eba4b8")) if i % 2 == 0 \
				else _pm(Color("fff3e0"), Color("f0e2cc")), Vector3(-0.65 + i * 0.26, 1.98, 0))
		stripe.rotation.z = 0.08
	# la merce: sacchetti e barattoli
	_box(n, Vector3(0.22, 0.2, 0.22), _pm(Color("d9c4a8"), Color("c4ae90")), Vector3(-0.45, 0.96, 0.1))
	_box(n, Vector3(0.18, 0.26, 0.18), _pm(Color("9fd8cf"), Color("86c2b8")), Vector3(0.1, 0.98, -0.12))
	_box(n, Vector3(0.16, 0.18, 0.16), _pm(Color("ffd76e"), Color("eec254")), Vector3(0.5, 0.94, 0.14))
	return n


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pm(a: Color, b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/handpaint.gdshader")
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", 4.0)
	mat.set_shader_parameter("noise_amount", 0.5)
	return mat


func _merchant_speak(concepts: Array, mood := "neutro") -> void:
	if _merchant_vp == null or _merchant_vp.playing:
		return
	_merchant_mood = mood
	_merchant_vp.stream = CHIBIESE.say(_merchant_voice, concepts, mood)
	_merchant_vp.play()


# il baratto: un piatto caldo per un sacchetto di ingredienti rari
func _merchant_trade() -> void:
	# il carretto ora è un vero negozio: vendi farfalle/pesci/raccolti e compra
	var shop := get_tree().get_first_node_in_group("shop")
	if shop and shop.has_method("open"):
		shop.open(_merchant)
		return
	# fallback (nessun negozio in scena): il vecchio baratto di un piatto
	var cooking := get_node_or_null("../../Cooking")
	if cooking == null:
		return
	if cooking.call("has_dish"):
		var dish: Dictionary = cooking.call("take_dish")
		_merchant_speak(["grazie", "cibo", "felice"], "felice")
		for kind in ["carota", "zucca", "bacca", "fungo"]:
			cooking.call("add_ingredient", kind, 1 + randi() % 2)
		_toast(L10n.tf("Il mercante divora %s e ti riempie la dispensa!",
				[L10n.t(str(dish.get("name", "il piatto")))]))
		_confetti(_merchant.global_position + Vector3(0, 1.0, 0))
		if _sfx:
			_sfx.place_ok()
	else:
		_merchant_speak(["cibo", "casa", "~"], "domanda")
		_toast(L10n.t("«Un piatto caldo del tuo camino, e la dispensa è tua» — cucina qualcosa!"))


# ---------------------------------------------------------------- feste

func _festa_key(f: Dictionary, day: int) -> String:
	return "%s|%d" % [str(f.get("id", "")), day]


# La festa di oggi scatta quando arriva il SUO momento: le lucciole col
# buio, le altre appena c'è luce. Un check a frame, ma solo nei 4 giorni
# di festa dell'anno (negli altri _festa_pending è vuoto).
func _tick_festa() -> void:
	if _festa_pending.is_empty() or _daynight == null:
		return
	var notturna: bool = bool(_festa_pending.get("notte", false))
	if notturna != bool(_daynight.is_night()):
		return
	var f: Dictionary = _festa_pending
	_festa_pending = {}
	_throw_festa(f)


# La festa vera e propria: il posto giusto, i coriandoli del suo colore,
# tutti i residenti che accorrono (come al falò), la cronaca sugli anelli.
func _throw_festa(f: Dictionary) -> void:
	var day := _day()
	_feste_done[_festa_key(f, day)] = true
	var spot := _festa_spot(f)
	_toast(L10n.t(str(f["toast"])))
	_confetti(spot + Vector3(0, 1.2, 0), _festa_colori(f))
	if str(f["id"]) == "pupazzo":
		_spawn_snowman(spot + Vector3(0.9, 0, -0.7))
	if _sfx:
		_sfx.build_open()
		get_tree().create_timer(0.4).timeout.connect(func():
			if _sfx: _sfx.place_ok())
	# tutto il villaggio accorre, si guarda intorno e balla
	if _visitors:
		for r in _visitors.get("_residents"):
			var node := r.get("node") as Node3D
			if node == null or not is_instance_valid(node) or node.call("is_hidden"):
				continue
			var off := Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
			node.call("do_routine", "sniff", spot + off, spot)
			node.call("speak", ["felice", "~"], "felice")
			get_tree().create_timer(randf_range(1.2, 2.6)).timeout.connect(func():
				if is_instance_valid(node):
					node.call("celebrate"))
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree and gtree.has_method("engrave_once"):
		gtree.engrave_once(str(f["id"]), str(f["icona"]), L10n.t(str(f["cronaca"])))
	if _build:
		_build.request_save()


# Dove si festeggia: il luogo si risolve ADESSO (il mondo cambia, il posto
# si ricalcola). Fallback sempre pieni: una festa non va mai a vuoto.
func _festa_spot(f: Dictionary) -> Vector3:
	match str(f.get("luogo", "")):
		"albero":
			var gtree := get_tree().get_first_node_in_group("grande_albero") as Node3D
			if gtree:
				return gtree.global_position + Vector3(1.8, 0, 1.5)
			return Vector3(-4.0, 0, -1.5)
		"stagno":
			return COZY.POND_CENTER + Vector3(0, 0, COZY.POND_R + 1.3)
		"orto":
			if _build:
				var orti: Array = _build.get_placed_by_name("Orto")
				if not orti.is_empty():
					return (orti[0] as Node3D).global_position + Vector3(1.2, 0, 0.8)
			return Vector3(1.5, 0, 4.5)
		"piazza":
			var board := _nearest_board(Vector3.ZERO)
			if board:
				return board.global_position + Vector3(-1.8, 0, 1.4)
			return Vector3(1.0, 0, 1.6)
	return Vector3.ZERO


# i coriandoli col colore della festa: petali rosa all'hanami, scintille
# calde per le lucciole, oro e rame alla sagra, azzurri gelo per la neve
func _festa_colori(f: Dictionary) -> Array:
	match str(f.get("id", "")):
		"hanami":
			return [Color("f8c8d8"), Color("fddce8"), Color("fff0f4")]
		"lucciole":
			return [Color("ffe98a"), Color("d8f2a0"), Color("ffd76e")]
		"sagra":
			return [Color("ffb85c"), Color("e8a03a"), Color("d4643a")]
		"pupazzo":
			return [Color("eaf4ff"), Color("cfe4f8"), Color("ffffff")]
	return [Color("f4b8c8"), Color("9fd8cf"), Color("ffd76e")]


# Il pupazzo di neve in piazza: tre palle, il naso di carota, gli occhi di
# carbone e due rametti. Non è persistito: al disgelo (o a un reload) si è
# "sciolto", com'è giusto per un pupazzo.
func _spawn_snowman(pos: Vector3) -> void:
	if _snowman:
		return
	_snowman = Node3D.new()
	_snowman.position = pos
	add_child(_snowman)
	var neve := _pm(Color("f6faff"), Color("dfeaf6"))
	for palla in [[0.34, 0.30], [0.25, 0.72], [0.18, 1.06]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = palla[0]
		sm.height = palla[0] * 2.0
		mi.mesh = sm
		mi.material_override = neve
		mi.position = Vector3(0, palla[1], 0)
		_snowman.add_child(mi)
	# il naso di carota, dritto in avanti
	var naso := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.035
	cono.height = 0.16
	naso.mesh = cono
	naso.material_override = _pm(Color("f2953a"), Color("d87c28"))
	naso.position = Vector3(0, 1.06, 0.2)
	naso.rotation.x = -PI * 0.5
	_snowman.add_child(naso)
	# gli occhi di carbone
	for sx: float in [-0.06, 0.06]:
		var occhio := MeshInstance3D.new()
		var os := SphereMesh.new()
		os.radius = 0.02
		os.height = 0.04
		occhio.mesh = os
		occhio.material_override = _pm(Color("2c2620"), Color("1c1814"))
		occhio.position = Vector3(sx, 1.12, 0.165)
		_snowman.add_child(occhio)
	# le braccia di rametto
	for lato: float in [-1.0, 1.0]:
		var ramo := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.015
		rm.bottom_radius = 0.025
		rm.height = 0.42
		ramo.mesh = rm
		ramo.material_override = _pm(Color("8a6440"), Color("6e4e30"))
		ramo.position = Vector3(lato * 0.36, 0.78, 0)
		ramo.rotation.z = lato * 1.25
		_snowman.add_child(ramo)
	_snowman.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_snowman, "scale", Vector3.ONE, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _melt_snowman() -> void:
	if _snowman == null:
		return
	var pupazzo := _snowman
	_snowman = null
	var tw := create_tween()
	tw.tween_property(pupazzo, "scale", Vector3(1.2, 0.02, 1.2), 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(pupazzo.queue_free)
	_toast(L10n.t("Il pupazzo di neve si è sciolto. Alla prossima nevicata!"))


func _confetti(pos: Vector3, colori: Array = [Color("f4b8c8"), Color("9fd8cf"), Color("ffd76e")]) -> void:
	for col: Color in colori:
		var tex := GradientTexture2D.new()
		tex.width = 16
		tex.height = 16
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		grad.colors = PackedColorArray([col, Color(col, 0.7), Color(col, 0.0)])
		tex.gradient = grad
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		quad.material = mat
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.3
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 70.0
		pm.initial_velocity_min = 1.4
		pm.initial_velocity_max = 2.6
		pm.gravity = Vector3(0, -2.6, 0)
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -260.0
		pm.angular_velocity_max = 260.0
		var burst := GPUParticles3D.new()
		burst.amount = 24
		burst.lifetime = 1.5
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.local_coords = false
		burst.process_material = pm
		burst.draw_pass_1 = quad
		burst.position = pos
		add_child(burst)
		burst.emitting = true
		get_tree().create_timer(2.2).timeout.connect(burst.queue_free)


# ---------------------------------------------------------------- UI

func _process(delta: float) -> void:
	_update_prompt()
	_tick_festa()
	# il volto vivo del mercante: sorride, ammicca, ti guarda quando ti avvicini
	if _merchant_face:
		if _merchant_vp and _merchant_vp.playing:
			_merchant_face.set_talking(true)
			_merchant_face.set_mood(_merchant_mood)
		else:
			_merchant_face.set_talking(false)
			_merchant_face.set_expression("felice")
		if _player and is_instance_valid(_player) and _merchant \
				and _merchant.global_position.distance_to(_player.global_position) < 4.0:
			_merchant_face.look_at_node(_player)
		else:
			_merchant_face.clear_gaze()
		_merchant_face.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _player == null:
		return
	if _open:
		_open = false
		_panel.visible = false
		_player.set_physics_process(true)
		if _sfx:
			_sfx.build_close()
		get_viewport().set_input_as_handled()
		return
	# player congelato da un'altra modalità (stelle, film, onsen…):
	# niente pannello e soprattutto niente scongelamento altrui
	if not _player.is_physics_processing():
		return
	# il mercante ha la precedenza sulla lavagna
	if _merchant and _player.global_position.distance_to(_merchant.global_position) < 1.6:
		_merchant_trade()
		get_viewport().set_input_as_handled()
		return
	var board := _nearest_board(_player.global_position)
	if board and _player.global_position.distance_to(board.global_position) < 1.6:
		_open = true
		_refresh_panel()
		_panel.visible = true
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
		if _sfx:
			_sfx.build_open()
		get_viewport().set_input_as_handled()


func _refresh_panel() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var events: Array = []
	var today := _day()
	for res_name in _birthdays:
		events.append([next_birthday(str(res_name)),
				L10n.tf("compleanno %s", [_di(str(_birthdays[res_name]["label"]))])])
	events.append([_merchant_day if _merchant_day >= today else _merchant_day + MERCHANT_EVERY,
			L10n.t("arriva il mercante")])
	@warning_ignore("integer_division")
	events.append([(today / 7 + 1) * 7, L10n.t("compleanno del villaggio")])
	# il prossimo cambio di stagione entra tra gli eventi in arrivo
	if _daynight and _daynight.has_method("next_season_day"):
		events.append([int(_daynight.next_season_day()), L10n.t("una nuova stagione")])
	# e la prossima festa stagionale, in bella copia
	var pf := prossima_festa(today)
	if not (pf[1] as Dictionary).is_empty():
		events.append([int(pf[0]), L10n.t(str(pf[1]["evento"]))])
	events.sort_custom(func(a, b): return a[0] < b[0])
	# in cima: la stagione di oggi e il giorno del mese (28 giorni = 1 anno)
	if _daynight and _daynight.has_method("season_name"):
		var hdr := Label.new()
		@warning_ignore("integer_division")
		var into := ((today - 1) % 28) + 1
		hdr.text = L10n.tf("Stagione: %s   ·   giorno %d di 28",
				[L10n.t(_daynight.season_name()), into])
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 13)
		hdr.add_theme_color_override("font_color", Color("8a5a3a"))
		_rows.add_child(hdr)
	# con 28 vicini gli eventi si affollano: il pannello mostra i primi
	# dodici in ordine di arrivo, e conta il resto
	for i in mini(events.size(), 12):
		var ev: Array = events[i]
		var row := Label.new()
		var giorni := int(ev[0]) - today
		var quando := L10n.t("OGGI!") if giorni == 0 \
				else (L10n.t("domani") if giorni == 1 else L10n.tf("tra %d giorni", [giorni]))
		row.text = L10n.tf("Giorno %d · %s  (%s)", [ev[0], ev[1], quando])
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", UI_BROWN)
		_rows.add_child(row)
	if events.size() > 12:
		var resto := Label.new()
		resto.text = L10n.tf("…e altri %d eventi più in là", [events.size() - 12])
		resto.add_theme_font_size_override("font_size", 12)
		resto.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
		_rows.add_child(resto)
	# le COMMISSIONI appese dai vicini: la pagina delle richieste
	var comm := get_tree().get_first_node_in_group("commissioni")
	if comm and int(comm.call("quante")) > 0:
		var titolo_c := Label.new()
		titolo_c.text = L10n.t("~ le commissioni ~")
		titolo_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titolo_c.add_theme_font_size_override("font_size", 14)
		titolo_c.add_theme_color_override("font_color", Color("8a5a3a"))
		_rows.add_child(titolo_c)
		for riga in comm.call("per_lavagna"):
			var rr := Label.new()
			var pronto := ("  " + L10n.t("✔ ce l'hai: consegnala!")) if bool(riga[3]) else ""
			rr.text = "%s: «%s»  +%d🌰%s" % [riga[0], riga[1], riga[2], pronto]
			rr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rr.custom_minimum_size = Vector2(370, 0)
			rr.add_theme_font_size_override("font_size", 12)
			rr.add_theme_color_override("font_color",
					Color("2e7d4f") if bool(riga[3]) else UI_BROWN)
			_rows.add_child(rr)


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null or _open or _build == null:
		_prompt.visible = false
		return
	var anchor: Node3D = null
	var text := ""
	if _merchant and _player.global_position.distance_to(_merchant.global_position) < 1.6:
		anchor = _merchant
		text = L10n.t("E — baratta col mercante")
	else:
		var board := _nearest_board(_player.global_position)
		if board and _player.global_position.distance_to(board.global_position) < 1.6:
			anchor = board
			text = L10n.t("E — il calendario del villaggio")
	if anchor == null:
		_prompt.visible = false
		return
	var wp: Vector3 = anchor.global_position + Vector3(0, 1.8, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


# "la coniglietta X" -> "della coniglietta X", "il topolino Y" -> "del..."
# In inglese le quattro preposizioni articolate collassano tutte in "of":
# la tabella se ne occupa, qui resta solo la scelta italiana.
func _di(label: String) -> String:
	if label.begins_with("il "):
		return L10n.tf("del %s", [label.substr(3)])
	if label.begins_with("la "):
		return L10n.tf("della %s", [label.substr(3)])
	if label.begins_with("l'"):
		return L10n.tf("dell'%s", [label.substr(2)])
	return L10n.tf("di %s", [label])


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

	_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fdf6e3")
	ms.set_corner_radius_all(16)
	ms.border_color = Color(0.62, 0.46, 0.34, 0.55)
	ms.set_border_width_all(2)
	ms.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	ms.shadow_size = 12
	ms.content_margin_left = 26.0
	ms.content_margin_right = 26.0
	ms.content_margin_top = 16.0
	ms.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", ms)
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)
	var title := Label.new()
	title.text = L10n.t("~ Il calendario del villaggio ~")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)
	var hint := Label.new()
	hint.text = L10n.t("E — chiudi")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for res_name in _birthdays:
		var b: Dictionary = _birthdays[res_name]
		rows.append([str(res_name), str(b["label"]), int(b["anchor"])])
	return {"birthdays": rows, "merchant_day": _merchant_day,
			"feste": _feste_done.keys()}


func load_extra(data: Dictionary) -> void:
	_merchant_day = int(data.get("merchant_day", 4))
	for r in data.get("birthdays", []):
		if r is Array and r.size() == 3:
			_birthdays[str(r[0])] = {"label": str(r[1]), "anchor": int(r[2])}
	for k in data.get("feste", []):
		_feste_done[str(k)] = true
	(func(): _refresh_boards()).call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_seed_board() -> void:
	_birthdays["Nocciola"] = {"label": "la coniglietta Nocciola", "anchor": _day() + 2}
	_birthdays["Miele"] = {"label": "l'orsetto Miele", "anchor": _day() + 5}
	_merchant_day = _day() + 3
	_refresh_boards()


func debug_open_panel() -> void:
	_open = true
	_refresh_panel()
	_panel.visible = true


func debug_close_panel() -> void:
	_open = false
	_panel.visible = false
	if _player:
		_player.set_physics_process(true)


func debug_merchant() -> void:
	_spawn_merchant()


func debug_party(i: int) -> void:
	if _visitors == null:
		return
	var r: Dictionary = _visitors.get("_residents")[i]
	var dna: Dictionary = r.get("dna", {})
	var res_name := str(dna.get("name", "Amico"))
	_birthdays[res_name] = {"label": str(r["label"]), "anchor": _day()}
	throw_party(res_name, str(r["label"]), r["node"])


## Fa scattare SUBITO la festa della stagione data (0..3), saltando
## l'attesa del giorno e dell'ora giusta. Ritorna il posto della festa
## (per inquadrarla). Solo per la verifica CLI.
func debug_festa(season: int) -> Vector3:
	for f in FESTE:
		if int(f["season"]) == season:
			_festa_pending = {}
			_throw_festa(f)
			return _festa_spot(f)
	return Vector3.ZERO
