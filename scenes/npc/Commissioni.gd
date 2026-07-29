extends Node

## Le COMMISSIONI della lavagna — il loop che dirige il giocatore verso
## il contenuto stagionale.
##
## Ogni mattina (al più una al giorno, mai più di tre appese) un vicino
## appende una richiesta alla Lavagna, generata dal SUO DNA e dal
## bestiario: «Sogno una carpa foglia d'oro» — e la carpa foglia d'oro
## abbocca solo d'autunno; «tre bacche per la mia marmellata». È il
## MOLTIPLICATORE delle specie condizionali: d'inverno la lavagna chiede
## la farfalla di neve, e si esce col retino sotto la nevicata.
##
## La consegna è DI PERSONA: con la merce addosso (il barattolo della
## Collection per le creature, la dispensa per i raccolti) ci si avvicina
## al vicino e compare «E — consegna». Ricompense: noccioline (il doppio
## del mercante: il desiderio vale più del bancone) e un MOMENTO sul
## Filo Rosso («il desiderio esaudito»). Nessuna scadenza punitiva: una
## richiesta ignorata a lungo si ricambia in silenzio.
##
## La generazione è PURA (genera/di_stagione) e testata senza SceneTree.

const CRIT := preload("res://scenes/world/Critters.gd")
const UI_BROWN := Color("6a4a3a")

const MAX_ATTIVE := 3
## Dopo quanti giorni una richiesta ignorata lascia il posto a una nuova.
const GIORNI_RICAMBIO := 6

## Il colore della richiesta secondo il SOGNO del vicino (Animo.SOGNI):
## è il DNA a scrivere il biglietto, non un generatore anonimo.
const VOGLIE := {
	"cuoco": "mi serve per la mia ricetta segreta",
	"artista": "voglio ritrarla prima che voli via",
	"esploratore": "l'ho inseguita per tutto il bosco, invano",
	"giardiniere": "dicono porti fortuna ai giardini",
	"boscaiolo": "mi ricorda il bosco dov'era la mia tana",
	"guerriero": "solo il tuo retino può riuscirci",
}

## Il piatto che giustifica i raccolti richiesti, per ingrediente.
const PIATTI := {
	"bacca": "la mia marmellata", "mela": "la mia torta",
	"pera": "la mia composta", "carota": "la mia zuppa",
	"zucca": "la mia vellutata", "fungo": "il mio risotto",
}

# le richieste appese: {chi (label), nome, id (specie), n, testo,
#   giorno (di affissione), premio (noccioline)}
var _attive: Array[Dictionary] = []

var _player: Node3D
var _daynight: Node3D
var _visitors: Node
var _collection: Node
var _cooking: Node
var _build: Node3D
var _sfx

var _prompt: PanelContainer
var _prompt_label: Label
var _consegnabile := -1      # indice della commissione consegnabile qui e ora
var _check_cd := 0.0


func _ready() -> void:
	add_to_group("commissioni")
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		_player = get_node_or_null("../Player")
		_daynight = get_node_or_null("../DayNight")
		_visitors = get_node_or_null("../Visitors")
		_collection = get_node_or_null("../Collection")
		_cooking = get_node_or_null("../Cooking")
		_build = get_node_or_null("../BuildSystem")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)).call_deferred()


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


func _stagione() -> int:
	if _daynight and _daynight.has_method("get_season"):
		return int(_daynight.call("get_season"))
	return 0


# ------------------------------------------------------------ il cuore puro
# (testato senza SceneTree in tests/cases/test_commissioni.gd)

## La specie esiste in QUALCHE momento della stagione data? Si scandisce
## la giornata (alba, mattina, giorno, sera/notte) con ogni meteo: è così
## che la farfalla di neve entra nelle commissioni d'inverno e la carpa
## foglia d'oro in quelle d'autunno — il moltiplicatore delle condizioni.
static func di_stagione(id: String, stagione: int) -> bool:
	for tempo in [0.1, 0.32, 0.5, 0.75]:
		for meteo in ["sereno", "pioggia", "neve", "nebbia"]:
			if CRIT.disponibile(id, CRIT.contesto(stagione, float(tempo),
					float(tempo) < 0.2, str(meteo))):
				return true
	return false


## Genera una richiesta: PURA e deterministica dato il seed. `chi` è la
## scheda del vicino ({label, nome, sogno}); la stagione decide il menù.
## Metà delle volte una CREATURA di stagione (il retino, la canna), metà
## un cestino di RACCOLTI. Il premio paga il doppio del mercante.
static func genera(seed_v: int, stagione: int, chi: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sogno := str(chi.get("sogno", ""))
	if rng.randf() < 0.5:
		# una creatura che ESISTE in questa stagione: è la lavagna a
		# mandarti fuori col retino nel momento giusto
		var pool := []
		for id in CRIT.collezionabili():
			if di_stagione(str(id), stagione):
				pool.append(str(id))
		if not pool.is_empty():
			var id: String = pool[rng.randi() % pool.size()]
			var voglia := str(VOGLIE.get(sogno, "ci penso da giorni e giorni"))
			var voce: Dictionary = CRIT.voce(id)
			return {"chi": str(chi.get("label", "")), "nome": str(chi.get("nome", "")),
					"id": id, "n": 1, "voglia": voglia,
					# `testo` è la copia ITALIANA che finisce nel salvataggio: si
					# compone con la creatura grezza (mai con_articolo, che a
					# gioco in inglese tradurrebbe e salverebbe una frase mista).
					# Quello che il giocatore legge lo compone biglietto().
					"testo": "Sogno %s %s: %s." % [str(voce.get("articolo", "una")),
							str(voce.get("nome", id)), voglia],
					"premio": CRIT.vendita(id) * 2 + 8}
	# il cestino di raccolti: 2-4 pezzi per un piatto che ha senso
	var raccolti := ["carota", "zucca", "bacca", "fungo", "mela", "pera"]
	var id2: String = raccolti[rng.randi() % raccolti.size()]
	var n := 2 + rng.randi() % 3
	var piatto := str(PIATTI.get(id2, "la mia cena"))
	return {"chi": str(chi.get("label", "")), "nome": str(chi.get("nome", "")),
			"id": id2, "n": n, "piatto": piatto,
			"testo": "%d %s per %s!" % [n, _plurale(id2, n), piatto],
			"premio": CRIT.vendita(id2) * n * 2 + 4}


## IL BIGLIETTO COME LO LEGGE IL GIOCATORE — composto adesso, nella lingua
## di adesso. Il dato salvato (`testo`) resta italiano per sempre: un
## villaggio salvato in inglese si riapre in italiano senza biglietti
## mezzi tradotti. Se una commissione vecchia non ha i pezzi separati,
## si ricade sul testo salvato (meglio italiano che vuoto).
static func biglietto(c: Dictionary) -> String:
	var id := str(c.get("id", ""))
	if c.has("voglia"):
		return L10n.tf("Sogno %s: %s.",
				[CRIT.con_articolo(id), L10n.t(str(c["voglia"]))])
	if c.has("piatto"):
		var n := int(c.get("n", 1))
		return L10n.tf("%d %s per %s!",
				[n, L10n.t(_plurale(id, n)), L10n.t(str(c["piatto"]))])
	return str(c.get("testo", ""))


static func _plurale(id: String, n: int) -> String:
	if n == 1:
		return CRIT.nome(id)
	var nome := CRIT.nome(id)
	# l'italiano vero: bacca -> bacche, zucca -> zucche, fungo -> funghi
	if nome.ends_with("ca") or nome.ends_with("ga"):
		return nome.substr(0, nome.length() - 1) + "he"
	if nome.ends_with("co") or nome.ends_with("go"):
		return nome.substr(0, nome.length() - 1) + "hi"
	if nome.ends_with("a"):
		return nome.substr(0, nome.length() - 1) + "e"
	if nome.ends_with("o") or nome.ends_with("e"):
		return nome.substr(0, nome.length() - 1) + "i"
	return nome


# ------------------------------------------------------------- il calendario

func _nuovo_giorno(_d: int) -> void:
	# le richieste ignorate a lungo si ricambiano, senza drammi
	for i in range(_attive.size() - 1, -1, -1):
		if _day() - int(_attive[i]["giorno"]) >= GIORNI_RICAMBIO:
			_attive.remove_at(i)
	# al più UNA nuova al mattino: la lavagna respira, non tempesta
	if _attive.size() < MAX_ATTIVE:
		_appendi_nuova()


func _appendi_nuova() -> void:
	if _visitors == null:
		return
	# un vicino senza già una richiesta appesa, a caso
	var candidati := []
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "" or str(r.get("species", "")) != "chibi":
			continue
		# un cucciolo non appende richieste alla lavagna: non sa ancora
		# scrivere, e soprattutto non sa ancora volere niente da te
		if bool(_visitors.call("e_cucciolo", label)):
			continue
		var occupato := false
		for c in _attive:
			if str(c["chi"]) == label:
				occupato = true
				break
		if not occupato:
			candidati.append(r)
	if candidati.is_empty():
		return
	var r: Dictionary = candidati[randi() % candidati.size()]
	var dna: Dictionary = r.get("dna", {})
	var chi := {"label": str(r.get("label", "")),
			"nome": str(dna.get("name", "")), "sogno": str(dna.get("sogno", ""))}
	var c := genera(randi(), _stagione(), chi)
	if c.is_empty():
		return
	c["giorno"] = _day()
	_attive.append(c)
	_toast(L10n.tf("📌 %s ha appeso una richiesta alla lavagna:\n«%s» (%d🌰)",
			[c["chi"], biglietto(c), c["premio"]]))
	if _sfx:
		_sfx.ui_select()
	if _build:
		_build.request_save()


# ------------------------------------------------------------- la consegna

## Il giocatore HA la merce di questa commissione?
func _ho_la_merce(c: Dictionary) -> bool:
	var id := str(c["id"])
	if CRIT.classe(id) == "raccolto":
		if _cooking == null:
			return false
		return int((_cooking.get("pantry") as Dictionary).get(id, 0)) >= int(c["n"])
	return _collection != null and int(_collection.call("count_of", id)) >= int(c["n"])


## Consegna la commissione `i` (di persona, al vicino): consuma la merce,
## paga le noccioline, annoda il momento e fa festa.
func consegna(i: int) -> bool:
	if i < 0 or i >= _attive.size():
		return false
	var c: Dictionary = _attive[i]
	if not _ho_la_merce(c):
		return false
	var id := str(c["id"])
	# la merce passa di zampa in zampa (remove_catch è lo stesso canale
	# della vendita al mercante: un solo modo di uscire dal barattolo)
	if CRIT.classe(id) == "raccolto":
		_cooking.call("add_ingredient", id, -int(c["n"]))
	else:
		_collection.call("remove_catch", id, int(c["n"]))
	# il premio: il doppio del mercante, più il momento sul Filo
	var eco := get_tree().get_first_node_in_group("economy")
	if eco:
		eco.call("add_nuts", int(c["premio"]))
	get_tree().call_group("legami", "momento", str(c["nome"]), "desiderio", "")
	get_tree().call_group("regista", "note", "socievole")
	var node: Node3D = _visitors.call("node_di", str(c["chi"])) if _visitors else null
	if node and is_instance_valid(node):
		if _player:
			node.call("face_towards", _player.global_position)
		node.call("speak", ["grazie", "felice", "~"], "felice")
		node.call("_spawn_heart")
		if node.has_method("celebrate"):
			node.call("celebrate")
	_toast(L10n.tf("✔ Consegnato! %s è al settimo cielo: +%d🌰 (e un momento sul filo)",
			[c["chi"], c["premio"]]))
	if _sfx:
		_sfx.place_ok()
	_attive.remove_at(i)
	if _build:
		_build.request_save()
	return true


# ---------------------------------------------------------------- interazione

func _process(delta: float) -> void:
	_check_cd -= delta
	if _check_cd <= 0.0:
		_check_cd = 0.2
		_ricontrolla()
	_update_prompt()


func _ricontrolla() -> void:
	_consegnabile = -1
	if _player == null or _visitors == null:
		return
	for i in _attive.size():
		if not _ho_la_merce(_attive[i]):
			continue
		var node: Node3D = _visitors.call("node_di", str(_attive[i]["chi"]))
		if node and is_instance_valid(node) and not bool(node.call("is_hidden")) \
				and node.global_position.distance_to(_player.global_position) < 1.9:
			_consegnabile = i
			return


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _consegnabile < 0:
		return
	if _player == null or not _player.is_physics_processing():
		return
	if consegna(_consegnabile):
		_ricontrolla()
		get_viewport().set_input_as_handled()


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null or _consegnabile < 0 \
			or _consegnabile >= _attive.size():
		_prompt.visible = false
		return
	var c: Dictionary = _attive[_consegnabile]
	var node: Node3D = _visitors.call("node_di", str(c["chi"])) if _visitors else null
	if node == null or not is_instance_valid(node):
		_prompt.visible = false
		return
	var wp: Vector3 = node.global_position + Vector3(0, 1.35, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.tf("E — consegna: %s", [_cosa(c)])
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _cosa(c: Dictionary) -> String:
	if int(c["n"]) == 1:
		return CRIT.con_articolo(str(c["id"]))
	# il plurale nasce in italiano (è il dato): si traduce qui, che è il
	# punto in cui la parola va davvero a schermo
	return "%d %s" % [int(c["n"]), L10n.t(_plurale(str(c["id"]), int(c["n"])))]


# --------------------------------------------------- la pagina della lavagna
# (Calendar la interroga per il pannello e per la riga di gessetto)

## Le righe per il pannello del calendario: [chi, testo, premio, pronto].
func per_lavagna() -> Array:
	var out := []
	for c in _attive:
		out.append([str(c["chi"]), biglietto(c), int(c["premio"]),
				_ho_la_merce(c)])
	return out


func quante() -> int:
	return _attive.size()


# ---------------------------------------------------------------- servizi

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
	for c in _attive:
		# in coda i due PEZZI della frase (voglia · piatto): il biglietto si
		# ricompone nella lingua di chi riapre il villaggio, invece di
		# restare congelato in quella di chi l'ha appeso
		rows.append([str(c["chi"]), str(c["nome"]), str(c["id"]), int(c["n"]),
				str(c["testo"]), int(c["giorno"]), int(c["premio"]),
				str(c.get("voglia", "")), str(c.get("piatto", ""))])
	return {"commissioni": rows}


func load_extra(data: Dictionary) -> void:
	for r in data.get("commissioni", []):
		# le righe da 7 sono i salvataggi di prima della traduzione: si
		# leggono lo stesso, e il loro biglietto resta quello scritto allora
		if r is Array and r.size() >= 7:
			var c := {"chi": str(r[0]), "nome": str(r[1]), "id": str(r[2]),
					"n": int(r[3]), "testo": str(r[4]), "giorno": int(r[5]),
					"premio": int(r[6])}
			if r.size() >= 9:
				if str(r[7]) != "":
					c["voglia"] = str(r[7])
				if str(r[8]) != "":
					c["piatto"] = str(r[8])
			_attive.append(c)


# ---------------------------------------------------------------- debug CLI

func debug_stato() -> Array:
	var out := []
	for c in _attive:
		out.append("%s chiede %s (%d🌰) — merce pronta: %s"
				% [c["chi"], _cosa(c), c["premio"], _ho_la_merce(c)])
	return out


## Appende una commissione d'ufficio (per la verifica CLI).
func debug_appendi(seed_v := -1) -> void:
	if seed_v >= 0:
		# deterministica: primo residente, seed dato
		var residenti: Array = _visitors.get("_residents")
		if residenti.is_empty():
			return
		var r: Dictionary = residenti[0]
		var dna: Dictionary = r.get("dna", {})
		var c := genera(seed_v, _stagione(), {"label": str(r.get("label", "")),
				"nome": str(dna.get("name", "")), "sogno": str(dna.get("sogno", ""))})
		c["giorno"] = _day()
		_attive.append(c)
	else:
		_appendi_nuova()
