extends Node

## LA BANCARELLA DI MOCHI — l'economia al contrario.
##
## Finora vendere voleva dire aspettare il carretto del mercante. Con la
## Bancarella (pezzo del suo listino, ironia compresa) è Mochi ad aprire
## bottega: TRE piedistalli su cui esporre farfalle, pesci e raccolti
## della bisaccia, ognuno col suo CARTELLINO — quattro tacche, mai numeri
## da digitare: economico, giusto, caro, carissimo.
##
## E poi il villaggio fa il resto: i vicini di passaggio guardano il
## banco e comprano CIÒ CHE IL LORO DNA ADORA — chi ha il pollice verde
## sogna farfalle e fiori (merce "fresca"), chi ama il focolare compra i
## raccolti da mettere in pentola (merce "calda"). Il gusto decide anche
## il portafoglio: ciò che si adora si paga fino a carissimo, ciò che è
## solo gradito fino a caro, il resto solo a prezzo onesto. Conoscere i
## propri vicini, qui, RENDE.
##
## La merce resta nella bisaccia finché qualcuno non compra (il banco
## espone, non sequestra): se nel frattempo la vendi al mercante, il
## piedistallo si svuota da sé, senza drammi. Tutto persistito.

const CRIT := preload("res://scenes/world/Critters.gd")
const CATALOG := preload("res://scenes/build/BuildCatalog.gd")

## Le quattro tacche del cartellino: moltiplicatore sul valore del
## bestiario. CARTELLINI e PREZZI camminano insieme (un test li allinea).
const PREZZI := [0.8, 1.0, 1.5, 2.0]
const CARTELLINI := ["economico", "giusto", "caro", "carissimo"]
## I colori dei cartellini in vetrina: dal verde gentile all'oro
const TAG_COLORI := [Color("9fd8cf"), Color("fff3e0"), Color("f2cf7e"), Color("e8b04a")]
## Dove stanno i tre piedistalli sul banco (gli stessi del builder)
const POSTI := [Vector3(-0.38, 0.94, 0.02), Vector3(0.0, 0.94, 0.02),
		Vector3(0.38, 0.94, 0.02)]
## Ogni quanto qualcuno si ferma a guardare il banco (secondi di gioco)
const VISITA_MIN := 40.0
const VISITA_MAX := 85.0

var _build: Node3D
var _player: Node3D
var _daynight: Node3D
var _visitors: Node
var _collection: Node
var _cooking: Node
var _economy: Node
var _sfx

# nodo del banco -> {"slots": [null | {kind, source, tag}] x3,
#                    "vetrina": Node3D, "visita": float}
var _banchi := {}
var _dirty := true
var _pending := {}         # dal salvataggio, in attesa dei banchi veri
var _tick := 0.0

# il pannello
var _ui: CanvasLayer
var _panel: PanelContainer
var _righe: VBoxContainer
var _aperto := false
var _banco_aperto: Node3D
var _sel := 0
var _vicino: Node3D
var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("bancarella")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_prompt()
	_build_panel()
	(func() -> void:
		_player = get_tree().get_first_node_in_group("player_controller")
		_daynight = get_node_or_null("../DayNight")
		_visitors = get_node_or_null("../Visitors")
		_collection = get_node_or_null("../Collection")
		_cooking = get_node_or_null("../Cooking")
		_economy = get_tree().get_first_node_in_group("economy")
		_build = get_tree().get_first_node_in_group("build_system")
		if _build and _build.has_signal("placed_changed"):
			_build.connect("placed_changed", func() -> void: _dirty = true)
	).call_deferred()


# ------------------------------------------------------------ il cuore puro

## La merce "fresca" (farfalle, lucciole, pesci, bestiole) parla a chi ha
## il pollice verde; i raccolti sono merce "calda", da focolare. PURA.
static func merce_fresca(classe: String) -> bool:
	return classe in ["farfalla", "lucciola", "pesce", "bestiola"]


## Quanto un DNA desidera questa merce: 2 = la adora, 1 = gradita,
## 0 = indifferente. I pesi sono quelli veri del carattere (garden ama il
## fresco, warmth il caldo). PURA: la verifica il test.
static func gradimento(fresca: bool, pesi: Dictionary) -> int:
	var voglia := float(pesi.get("garden", 0.0)) if fresca \
			else float(pesi.get("warmth", 0.0))
	if voglia >= 0.6:
		return 2
	if voglia >= 0.35:
		return 1
	return 0


## Fino a che cartellino si allunga la zampa: ciò che si adora si paga
## carissimo, il gradito fino a caro, il resto solo a prezzo onesto. PURA.
static func cartellino_massimo(grad: int) -> int:
	return [1, 2, 3][clampi(grad, 0, 2)]


## Le noccioline che entrano in tasca a Mochi per una vendita. PURA.
static func prezzo_in_noccioline(valore: int, tag: int) -> int:
	return maxi(1, roundi(float(valore) * PREZZI[clampi(tag, 0, PREZZI.size() - 1)]))


# ------------------------------------------------------------ il censimento

func _process(delta: float) -> void:
	_update_prompt()
	_tick += delta
	if _tick < 1.0:
		return
	var dt := _tick
	_tick = 0.0
	if _build == null:
		return
	if _dirty:
		_rebuild()
	_giro_dei_clienti(dt)


func _rebuild() -> void:
	_dirty = false
	for banco in _banchi.keys():
		if not is_instance_valid(banco):
			_banchi.erase(banco)
	for banco in _build.get_placed_by_name("Bancarella"):
		if _banchi.has(banco):
			continue
		var slots := [null, null, null]
		var chiave := _chiave(banco)
		if _pending.has(chiave):
			var righe: Array = _pending[chiave]
			for i in mini(3, righe.size()):
				if righe[i] is Array and (righe[i] as Array).size() >= 3:
					slots[i] = {"kind": str(righe[i][0]), "source": str(righe[i][1]),
							"tag": int(righe[i][2])}
			_pending.erase(chiave)
		_banchi[banco] = {"slots": slots, "vetrina": null,
				"visita": randf_range(VISITA_MIN, VISITA_MAX)}
		_refresh_vetrina(banco)


func _chiave(banco: Node3D) -> String:
	return "%d|%d" % [roundi(banco.position.x), roundi(banco.position.z)]


# ------------------------------------------------------------ la vetrina

## La merce ESPOSTA: sul piedistallo la creatura col suo colore vero e il
## cartellino tinto della sua tacca. Il banco racconta cosa vende da lontano.
func _refresh_vetrina(banco: Node3D) -> void:
	var b: Dictionary = _banchi[banco]
	var vecchia: Node3D = b["vetrina"]
	if vecchia and is_instance_valid(vecchia):
		vecchia.queue_free()
	var vetrina := Node3D.new()
	banco.add_child(vetrina)
	b["vetrina"] = vetrina
	for i in 3:
		var slot = b["slots"][i]
		if slot == null:
			continue
		var kind := str(slot["kind"])
		var col: Color = CRIT.colore(kind)
		var merce := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 12
		sm.rings = 7
		merce.mesh = sm
		merce.material_override = CATALOG._mat(col, col.darkened(0.2), 4.0, 0.45)
		merce.position = POSTI[i] + Vector3(0, 0.06, 0)
		merce.scale = Vector3(1.15, 0.85, 1.0)
		vetrina.add_child(merce)
		# il cartellino piantato accanto, tinto della sua tacca
		var tag := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.09, 0.06, 0.012)
		tag.mesh = tm
		var tcol: Color = TAG_COLORI[clampi(int(slot["tag"]), 0, 3)]
		tag.material_override = CATALOG._mat(tcol, tcol.darkened(0.18), 5.0, 0.35)
		tag.position = POSTI[i] + Vector3(0.1, 0.03, 0.09)
		tag.rotation.y = -0.3
		vetrina.add_child(tag)


# ------------------------------------------------------------ i clienti

## Il giro dei clienti: ogni tanto un vicino di passaggio guarda il banco
## e — se il cartellino non supera il suo desiderio — compra.
func _giro_dei_clienti(dt: float) -> void:
	if _visitors == null or _daynight == null or _daynight.is_night():
		return
	for banco in _banchi:
		if not is_instance_valid(banco):
			continue
		var b: Dictionary = _banchi[banco]
		b["visita"] = float(b["visita"]) - dt
		if float(b["visita"]) > 0.0:
			continue
		b["visita"] = randf_range(VISITA_MIN, VISITA_MAX)
		_prova_una_vendita(banco, b)


func _prova_una_vendita(banco: Node3D, b: Dictionary) -> void:
	var residenti: Array = (_visitors.get("_residents") as Array).filter(
			func(r) -> bool:
				var node := r.get("node") as Node3D
				return node != null and is_instance_valid(node) \
						and not bool(node.call("is_hidden")))
	if residenti.is_empty():
		return
	var r: Dictionary = residenti[randi() % residenti.size()]
	var pesi: Dictionary = (r.get("dna", {}) as Dictionary).get("weights", {})
	# lo slot più desiderato che il cartellino permette (a parità, il primo)
	var scelto := -1
	var meglio := 0
	for i in 3:
		var slot = b["slots"][i]
		if slot == null or not _in_bisaccia(slot):
			continue
		var grad := gradimento(merce_fresca(_classe(str(slot["kind"]))), pesi)
		if int(slot["tag"]) <= cartellino_massimo(grad) and grad + 1 > meglio:
			meglio = grad + 1
			scelto = i
	if scelto < 0:
		return
	# il cliente si avvicina al banco, annusa la merce… e compra
	var node := r.get("node") as Node3D
	var davanti: Vector3 = banco.global_position \
			+ banco.global_transform.basis.z.normalized() * 0.9
	node.call("do_routine", "sniff", davanti, banco.global_position)
	var label := str(r.get("label", L10n.t("un vicino")))
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		_finalizza_vendita(banco, scelto, label, node))


func _finalizza_vendita(banco: Node3D, i: int, label: String, node: Node3D) -> void:
	if not _banchi.has(banco) or not is_instance_valid(banco):
		return
	var b: Dictionary = _banchi[banco]
	var slot = b["slots"][i]
	if slot == null or not _in_bisaccia(slot):
		return   # venduto altrove nel frattempo: il piedistallo tace
	var kind := str(slot["kind"])
	var incasso := prezzo_in_noccioline(CRIT.vendita(kind), int(slot["tag"]))
	# la merce esce DAVVERO dalla bisaccia solo adesso
	if str(slot["source"]) == "critter" and _collection:
		_collection.remove_catch(kind, 1)
	elif _cooking:
		_cooking.add_ingredient(kind, -1)
	if _economy:
		_economy.add_nuts(incasso)
	b["slots"][i] = null
	_refresh_vetrina(banco)
	if node and is_instance_valid(node):
		node.call("speak", ["grazie", "regalo", "felice"], "felice")
		node.call("_spawn_heart")
	_toast(L10n.tf("%s ha comprato %s: +%d 🌰 alla bancarella!",
			[label, CRIT.con_articolo(kind), incasso]))
	if _sfx:
		_sfx.place_ok()
	var saver := get_tree().get_first_node_in_group("build_system")
	if saver and saver.has_method("request_save"):
		saver.request_save()


# la merce è ancora nella bisaccia? (il banco espone, non sequestra)
func _in_bisaccia(slot: Dictionary) -> bool:
	var kind := str(slot["kind"])
	if str(slot["source"]) == "critter":
		return _collection != null and int(_collection.count_of(kind)) > 0
	return _cooking != null and int((_cooking.get("pantry") as Dictionary).get(kind, 0)) > 0


func _classe(kind: String) -> String:
	return str((CRIT.SPECIE.get(kind, {}) as Dictionary).get("classe", "raccolto"))


# ------------------------------------------------------------ il pannello

func _sellables() -> Array:
	var out: Array = []
	if _collection and _collection.has_method("owned_kinds"):
		for k in _collection.owned_kinds():
			if int(_collection.count_of(k)) > 0:
				out.append({"kind": str(k), "source": "critter"})
	if _cooking:
		var pantry: Dictionary = _cooking.get("pantry")
		for k in pantry:
			if int(pantry[k]) > 0:
				out.append({"kind": str(k), "source": "pantry"})
	return out


func _update_prompt() -> void:
	if _prompt == null or _player == null or _build == null or _aperto:
		if _prompt and _aperto:
			_prompt.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	_vicino = null
	if cam == null:
		_prompt.visible = false
		return
	var best := 1.6
	for banco in _banchi:
		if not is_instance_valid(banco):
			continue
		var d: float = _player.global_position.distance_to((banco as Node3D).global_position)
		if d < best:
			best = d
			_vicino = banco
	if _vicino == null:
		_prompt.visible = false
		return
	var pieni := 0
	for slot in (_banchi[_vicino] as Dictionary)["slots"]:
		if slot != null:
			pieni += 1
	_prompt_label.text = L10n.t("E — sistema la bancarella") if pieni == 0 \
			else L10n.tf("E — sistema la bancarella (%d in vendita)", [pieni])
	_prompt.reset_size()
	var wp: Vector3 = _vicino.global_position + Vector3(0, 1.9, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _aperto:
		_input_panel(event)
		return
	if not event.is_action_pressed("interact") or _vicino == null:
		return
	if _player == null or not _player.is_physics_processing():
		return
	_apri(_vicino)
	get_viewport().set_input_as_handled()


func _input_panel(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_chiudi()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		_sel = posmod(_sel + (1 if event.is_action_pressed("ui_down") else -1), 3)
		if _sfx:
			_sfx.ui_select()
		_riempi_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		_cicla_merce(1 if event.is_action_pressed("ui_right") else -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_cicla_cartellino()
		get_viewport().set_input_as_handled()


## ←→ scorre la bisaccia sul piedistallo scelto (il vuoto è in lista:
## si può sempre ritirare la merce).
func _cicla_merce(passo: int) -> void:
	var b: Dictionary = _banchi[_banco_aperto]
	var lista := _sellables()
	var slot = b["slots"][_sel]
	var idx := -1   # -1 = vuoto
	if slot != null:
		for i in lista.size():
			if str(lista[i]["kind"]) == str(slot["kind"]) \
					and str(lista[i]["source"]) == str(slot["source"]):
				idx = i
				break
	idx = posmod(idx + passo + 1, lista.size() + 1) - 1
	if idx < 0:
		b["slots"][_sel] = null
	else:
		var tag := 1 if slot == null else int(slot["tag"])
		b["slots"][_sel] = {"kind": str(lista[idx]["kind"]),
				"source": str(lista[idx]["source"]), "tag": tag}
	if _sfx:
		_sfx.rotate_tick()
	_refresh_vetrina(_banco_aperto)
	_riempi_panel()


## SPAZIO gira il cartellino: economico → giusto → caro → carissimo.
func _cicla_cartellino() -> void:
	var b: Dictionary = _banchi[_banco_aperto]
	var slot = b["slots"][_sel]
	if slot == null:
		return
	slot["tag"] = (int(slot["tag"]) + 1) % CARTELLINI.size()
	if _sfx:
		_sfx.rotate_tick()
	_refresh_vetrina(_banco_aperto)
	_riempi_panel()


func _apri(banco: Node3D) -> void:
	_aperto = true
	_banco_aperto = banco
	_sel = 0
	if _player:
		_player.set_physics_process(false)
		_player.set("velocity", Vector3.ZERO)
	_riempi_panel()
	_ui.visible = true
	CozyUI.appear(_panel, 0.3)
	if _sfx:
		_sfx.build_open()


func _chiudi() -> void:
	_aperto = false
	_banco_aperto = null
	_ui.visible = false
	if _player and not _player.is_physics_processing():
		_player.set_physics_process(true)
	if _sfx:
		_sfx.build_close()
	var saver := get_tree().get_first_node_in_group("build_system")
	if saver and saver.has_method("request_save"):
		saver.request_save()


func _riempi_panel() -> void:
	for c in _righe.get_children():
		c.queue_free()
	if _banco_aperto == null or not _banchi.has(_banco_aperto):
		return
	var b: Dictionary = _banchi[_banco_aperto]
	for i in 3:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", CozyUI.soft_card())
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		card.add_child(h)
		var freccia := CozyUI.body_label("▸" if i == _sel else " ", 18, CozyUI.TITLE)
		h.add_child(freccia)
		var slot = b["slots"][i]
		if slot == null:
			var vuoto := CozyUI.body_label(L10n.t("— piedistallo vuoto —"), 16, CozyUI.INK_SOFT)
			vuoto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(vuoto)
		else:
			var kind := str(slot["kind"])
			var nome := CozyUI.body_label(CRIT.etichetta(kind), 17,
					CozyUI.TITLE if i == _sel else CozyUI.INK)
			nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(nome)
			var tag := int(slot["tag"])
			var incasso := prezzo_in_noccioline(CRIT.vendita(kind), tag)
			h.add_child(CozyUI.body_label("%s · %d" % [L10n.t(CARTELLINI[tag]), incasso], 16,
					CozyUI.NUT))
			h.add_child(CozyUI.icon("nut", 20))
			if not _in_bisaccia(slot):
				h.add_child(CozyUI.body_label(L10n.t("(finita!)"), 13, CozyUI.DANGER))
		_righe.add_child(card)


func _toast(text: String) -> void:
	if _visitors:
		_visitors.call("_show_toast", text)


# ------------------------------------------------------------ le interfacce

func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
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
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt.add_child(_prompt_label)


func _build_panel() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 6
	_ui.visible = false
	add_child(_ui)
	var center := CozyUI.center_root()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", CozyUI.paper_panel(26))
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	col.add_child(CozyUI.title_label(L10n.t("La bancarella di Mochi"), 26))
	var sotto := CozyUI.body_label(L10n.t("tre tesori in vetrina, al prezzo che dici tu"), 13,
			CozyUI.INK_SOFT)
	sotto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sotto)
	_righe = VBoxContainer.new()
	_righe.add_theme_constant_override("separation", 8)
	col.add_child(_righe)
	col.add_child(CozyUI.hint_label(L10n.t(
			"↑↓ piedistallo · ←→ merce · SPAZIO cartellino · E chiudi"), 13))


# ------------------------------------------------------------ persistenza

func save_extra() -> Dictionary:
	var fuori := {}
	for banco in _banchi:
		if not is_instance_valid(banco):
			continue
		var righe := []
		for slot in (_banchi[banco] as Dictionary)["slots"]:
			if slot == null:
				righe.append(null)
			else:
				righe.append([str(slot["kind"]), str(slot["source"]), int(slot["tag"])])
		fuori[_chiave(banco)] = righe
	# i banchi non ancora adottati (salvataggio caricato, mondo in costruzione)
	for chiave in _pending:
		if not fuori.has(chiave):
			fuori[chiave] = _pending[chiave]
	return {"bancarelle": fuori}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("bancarelle")
	if d is Dictionary:
		_pending = (d as Dictionary).duplicate(true)
		_dirty = true
