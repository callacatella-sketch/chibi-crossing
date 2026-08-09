class_name BuildSystem
extends Node3D

## Modalità costruzione stile Animal Crossing.
##
## B entra/esce · rotella o 1-9 scegli · R ruota il pezzo · F ruota un
## oggetto già piazzato · clic piazza · X rimuovi. La griglia è del
## GridManager C++ (1 cella = 1 metro, celle centrate sugli interi).
##
## I pezzi "cell" occupano una cella su 3 layer sovrapponibili
## (pavimento / tappeto / oggetto). I pezzi "edge" (muri, staccionate,
## porte, finestre) stanno sui BORDI tra le celle, come in AC: il cursore
## aggancia il bordo più vicino e l'orientamento segue il bordo.
## Ogni pezzo piazzato riceve le sue collisioni (StaticBody3D).
##
## Il villaggio si salva da solo (user://village.json) a ogni piazzamento,
## rimozione o rotazione, e riappare al prossimo avvio.

signal mode_changed(active: bool)
## Il villaggio è cambiato (pezzo piazzato/rimosso, o caricamento finito):
## i sistemi che tengono cache di pezzi (Garden, Mail, Calendar…) si
## rinfrescano qui invece di riscandire tutto a ogni frame.
signal placed_changed

# preload esplicito: non dipende dalla cache globale delle class_name
const CATALOG := preload("res://scenes/build/BuildCatalog.gd")
const GRID_SHADER := preload("res://shaders/grid.gdshader")

const VALID_TINT := Color(0.45, 0.9, 0.5, 0.38)
const INVALID_TINT := Color(0.95, 0.35, 0.3, 0.42)
const UI_BROWN := Color("6a4a3a")
const CAT_NAMES := ["Struttura", "Arredo", "Giardino", "Palestra", "Chiesa",
		"Boutique"]

var _grid: GridManager
var _items: Array[Dictionary] = []
var _index := 0
var _rot := 0
var _active := false
var _valid := false

# cursore corrente
var _cursor_key := Vector2i.ZERO      # celle: coordinate cella · bordi: coordinate raddoppiate
var _cursor_pos := Vector3.ZERO
var _cursor_yaw := 0.0
var _hover_cell := Vector2i.ZERO
var _mouse_world := Vector3.ZERO

var _ghost: Node3D
var _overlay: StandardMaterial3D
var _grid_plane: MeshInstance3D
var _placed_root: Node3D
# celle per layer (3 = tetti) + bordi, chiave -> StaticBody3D/Node3D
var _placed := {0: {}, 1: {}, 2: {}, 3: {}, "edge": {}}

# il piano di sopra: stesse chiavi, quota +FLOOR_H. Il tasto V alterna
# il piano attivo in modalità costruzione.
const FLOOR_H := 2.15
const UP_AUTO := ["Solaio", "Ponticello"]
var _level := 0
var _placed_up := {0: {}, 1: {}, 2: {}, 3: {}, "edge": {}}

# offset locali della Casa albero (base scala, cima, trespolo ospiti)
const TH_BASE := Vector3(0, 0, 2.35)
const TH_TOP := Vector3(0, 2.62, 0.85)
const TH_PERCH := Vector3(-0.72, 2.62, 0.72)

# porte animate, tetti e muri (nodo -> mesh per le dissolvenze), demolizione
var _player: Node3D
var _doors: Array[Dictionary] = []
var _roofs := {}
var _roof_fade := 0.0
var _walls := {}
# pezzi del piano di sopra (solai, ponticelli, arredo): dissolvono
# quando Mochi è al piano terra, sotto di loro
var _ups := {}
var _up_fade := 0.0
# le lanterne che dondolano (Casa albero)
var _lanterns: Array[Node3D] = []
var _sway_t := 0.0

const WALL_ITEMS := ["Muro", "Finestra", "Porta"]
var _demolish := false
var _demo_btn: Button
var _demo_target: Node3D
var _demo_overlay: StandardMaterial3D

const INTERACTABLE := ["Sedia", "Sgabello", "Panchina", "Letto"]

# L'autoload viene registrato a metà della prima scansione del filesystem,
# quindi al primo avvio non è ancora visibile al parser: lo risolviamo a
# runtime (var non tipizzata = chiamate dinamiche, nessun errore di parse).
var _sfx
# il CozyWorld: sa dove scorre il fiume (lì non si costruisce)
var _cozy: Node3D

var _ui: CanvasLayer
var _panel: PanelContainer
var _idle_hint: Label
var _items_row: HBoxContainer
var _cat_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _cat := 0

# --- recinto degli "Ordini del Gufo" ---------------------------------------
# Il catalogo si apre a poco a poco: è GufoOrders che, sbloccando gli Ordini,
# passa qui l'insieme dei pezzi disponibili (apply_unlocks). Di DEFAULT il
# recinto è spento (_locks_active = false) e tutto è libero: così i test, la
# CLI degli screenshot e i salvataggi antecedenti agli Ordini restano a
# catalogo pieno, senza sapere niente di questa meccanica.
var _unlocked := {}
var _locks_active := false
var _order_banner: Label

# --- economia: varianti di colore comprate dal mercante (vedi Economy.gd) ---
# _variant è il colore scelto per il PROSSIMO pezzo da piazzare ("" = originale)
var _variant := ""
var _eco: Node
var _variant_bar: PanelContainer
var _variant_row: HBoxContainer

## Per gli screenshot da CLI: se impostato, il fantasma usa questa
## posizione invece del mouse.
var debug_ghost_pos := Vector3.INF

# persistenza: il villaggio si risalva da solo a ogni modifica
# (var e non const: la verifica CLI lo punta a un file di prova)
var save_path := "user://village.json"
var _persist := true
var _loading := false


func _ready() -> void:
	add_to_group("build_system")
	_sfx = get_node_or_null(^"/root/Sfx")
	_player = get_node_or_null("%Player")
	_cozy = get_node_or_null("../CozyWorld")

	_demo_overlay = StandardMaterial3D.new()
	_demo_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_demo_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_demo_overlay.albedo_color = Color(0.95, 0.3, 0.25, 0.45)
	_demo_overlay.render_priority = 10

	_grid = GridManager.new()
	_grid.grid_size = 1.0
	add_child(_grid)

	_placed_root = Node3D.new()
	_placed_root.name = "Placed"
	add_child(_placed_root)

	_items = CATALOG.items()

	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = VALID_TINT
	_overlay.render_priority = 10

	_build_grid_plane()
	_build_ui()
	_build_variant_bar()
	_refresh_ghost()

	# in modalità screenshot CLI la demo costruisce una casetta di prova:
	# niente caricamento né salvataggio, il villaggio vero resta intatto
	_persist = OS.get_environment("CHIBI_SHOT") == ""
	if _persist:
		# i persistable che nascono dopo il load (mondo differito) si servono
		# da soli via node_added: vedi _on_node_added
		get_tree().node_added.connect(_on_node_added)
		_load_village.call_deferred()
	_hook_economy.call_deferred()


func is_active() -> bool:
	return _active


func item_index(piece: String) -> int:
	for i in _items.size():
		if _items[i]["name"] == piece:
			return i
	return -1  # nome sconosciuto: mai trasformarlo in silenzio nel pezzo 0


# --------------------------------------------------- Ordini del Gufo: API
# GufoOrders guida il recinto e interroga il villaggio da qui. Tutto ciò
# che serve alla progressione passa per questi metodi: BuildSystem non sa
# nulla del contenuto degli Ordini (zero accoppiamento col loro testo).

## True se il pezzo è disponibile — o se il recinto è spento (catalogo pieno).
func is_unlocked(piece: String) -> bool:
	# i pezzi del NEGOZIO si sbloccano SOLO comprandoli (a parte dagli Ordini)
	var eco := _economy()
	if eco and eco.has_method("is_shop_piece") and eco.is_shop_piece(piece):
		return eco.is_piece_unlocked(piece)
	# I COMPAGNI DI CORREDO. Un corredo si paga in blocco (240-700
	# noccioline) e `Economy.unlock_piece` sblocca il capo INSIEME ai suoi
	# compagni — ma qui l'economia veniva interrogata solo per i 24 nomi di
	# `SHOP_PIECES`, e i compagni non ci sono. Restavano sotto chiave con la
	# promessa di un Ordine del Gufo che per loro non arriva MAI
	# (l'intersezione fra i compagni e i pezzi della campagna è VUOTA):
	# pagavi la caserma e ricevevi l'autopompa da sola, il bar e ti arrivava
	# il bancone in una stanza vuota.
	# Si INTERROGA l'economia, non si sostituisce il recinto: se il corredo
	# non è stato comprato si ricade sulla regola normale, così a recinto
	# spento (catalogo pieno: veterani, CLI, provini, catalogo visivo) i
	# compagni restano liberi esattamente come prima.
	if eco and eco.has_method("is_piece_unlocked") and _padrone_corredo(piece) != "" \
			and eco.is_piece_unlocked(piece):
		return true
	return not _locks_active or _unlocked.has(piece)


## GufoOrders passa qui l'insieme dei pezzi sbloccati. active=false spegne il
## recinto (catalogo pieno: veterani, CLI, test). Ricostruisce la UI e, se il
## pezzo selezionato è finito sotto chiave, scivola al primo libero.
func apply_unlocks(names: Array, active: bool) -> void:
	_locks_active = active
	_unlocked.clear()
	for n in names:
		_unlocked[str(n)] = true
	if _items.is_empty():
		return  # UI/catalogo non ancora pronti: si riapplica da _build_ui
	if _locks_active and not is_unlocked(str(_items[_index]["name"])):
		var first := _first_unlocked_index()
		if first >= 0:
			_index = first
			_cat = int(_items[_index]["cat"])
			_refresh_ghost()
	if not _item_buttons.is_empty():
		_rebuild_item_row()
		_sync_ui_selection()


func _first_unlocked_index() -> int:
	for i in _items.size():
		if is_unlocked(str(_items[i]["name"])):
			return i
	return -1


# il vicino sbloccato nella direzione data (per la rotella), saltando i pezzi
# ancora sotto chiave; se non ce n'è, resta dov'è
func _next_unlocked(dir: int) -> int:
	var n := _items.size()
	for step in range(1, n + 1):
		var i := posmod(_index + dir * step, n)
		if is_unlocked(str(_items[i]["name"])):
			return i
	return _index


## Conteggio dei pezzi piazzati per nome (tutti i piani e i layer): il
## vocabolario con cui GufoOrders valuta gli Ordini.
func piece_counts() -> Dictionary:
	var out := {}
	for dicts in [_placed, _placed_up]:
		for layer in [0, 1, 2, 3, "edge"]:
			for node in (dicts[layer] as Dictionary).values():
				var nm: String = (node as Node3D).get_meta("item_name", "")
				out[nm] = int(out.get(nm, 0)) + 1
	return out


## C'è un Letto con un tetto/solaio sopra la sua cella? (Ordine "una stanza
## per un ospite" — è la stessa condizione del trasloco dei Visitatori.)
func has_bed_under_roof() -> bool:
	for bed in get_placed_by_name("Letto"):
		var cell := Vector2i(roundi(bed.position.x), roundi(bed.position.z))
		if has_cover(cell):
			return true
	return false


## Il testo dell'Ordine in corso, in cima al pannello di costruzione (o "" per
## nasconderlo). Lo aggiorna GufoOrders.
func set_order_banner(text: String) -> void:
	if _order_banner == null:
		return
	_order_banner.text = text
	_order_banner.visible = text != ""


# i dizionari del piano richiesto (0 = terra, 1 = sopra)
func _dicts(lvl: int) -> Dictionary:
	return _placed_up if lvl == 1 else _placed


## C'è qualcosa sopra la testa in questa cella? Tetto a terra, solaio o
## tetto del piano di sopra. Usato dal trasloco ("un letto col tetto").
func has_cover(cell: Vector2i) -> bool:
	return (_placed[3] as Dictionary).has(cell) \
			or (_placed_up[0] as Dictionary).has(cell) \
			or (_placed_up[3] as Dictionary).has(cell)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		_set_active(not _active)
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return

	if event.is_action_pressed("build_level"):
		_set_level(1 - _level)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_rotate"):
		if not _demolish:
			_rot = (_rot + 1) % 4
			_bounce(_ghost)
			if _sfx: _sfx.rotate_tick()
	elif event.is_action_pressed("build_rotate_placed"):
		_rotate_placed()
	elif event.is_action_pressed("build_place"):
		if _demolish:
			_try_remove()
		else:
			_try_place()
	elif event.is_action_pressed("build_remove"):
		_try_remove()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_next_unlocked(-1))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_next_unlocked(1))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var i: int = event.keycode - KEY_1
			var cat_items := _cat_item_indices(_cat)
			if i < cat_items.size():
				if is_unlocked(str(_items[cat_items[i]]["name"])):
					_select(cat_items[i])
				elif _sfx:
					_sfx.place_deny()


func _set_active(active: bool) -> void:
	_active = active
	if not active:
		_set_demolish(false)
	_ghost.visible = active and not _demolish
	_grid_plane.visible = active
	_panel.visible = active
	_idle_hint.visible = not active
	_update_variant_bar()
	if _sfx:
		if active:
			_sfx.build_open()
		else:
			_sfx.build_close()
	mode_changed.emit(active)


## Attiva la modalità build con fantasma in una posizione fissa (per debug/CLI).
func set_active_for_debug(active: bool, ghost_world_pos: Vector3, item_name := "") -> void:
	debug_ghost_pos = ghost_world_pos
	if item_name != "" and item_index(item_name) >= 0:
		_select(item_index(item_name))
	_set_active(active)


# ---------------------------------------------------------------- selezione

func _cat_item_indices(cat: int) -> Array[int]:
	var out: Array[int] = []
	for i in _items.size():
		if _items[i]["cat"] == cat:
			out.append(i)
	return out


func _select(i: int) -> void:
	# un pezzo ancora sotto chiave non si seleziona: piccolo diniego
	if _locks_active and not is_unlocked(str(_items[i]["name"])):
		if _sfx: _sfx.place_deny()
		return
	_set_demolish(false)
	_index = i
	if _items[i]["cat"] != _cat:
		_cat = _items[i]["cat"]
		_rebuild_item_row()
	# i pezzi del piano di sopra portano il cursore su da soli
	if bool(_items[i].get("up", false)) and _level == 0:
		_set_level(1)
	_refresh_ghost()
	_sync_ui_selection()
	if _sfx: _sfx.ui_select()


# alterna il piano di costruzione: la griglia sale a quota solaio
func _set_level(lvl: int) -> void:
	if _level == lvl:
		return
	_level = lvl
	if _ghost:
		_bounce(_ghost)
	if _sfx:
		_sfx.rotate_tick()


func _sync_ui_selection() -> void:
	for j in _cat_buttons.size():
		_cat_buttons[j].set_pressed_no_signal(j == _cat)
	var cat_items := _cat_item_indices(_cat)
	for j in _item_buttons.size():
		_item_buttons[j].set_pressed_no_signal(cat_items[j] == _index)


func _refresh_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	var builder: Callable = _items[_index]["builder"]
	_ghost = builder.call()
	_ghost.visible = _active
	add_child(_ghost)
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).transparency = 0.45
		(mi as MeshInstance3D).material_overlay = _overlay
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for light in _ghost.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false
	for part in _ghost.find_children("*", "GPUParticles3D", true, false):
		(part as GPUParticles3D).emitting = false
	# il ghost del Tetto non deve fermare la pioggia a mezz'aria
	for pc in _ghost.find_children("*", "GPUParticlesCollision3D", true, false):
		(pc as GPUParticlesCollision3D).cull_mask = 0
	# tinge il fantasma col colore scelto e aggiorna la barra dei colori
	_apply_ghost_variant()
	_update_variant_bar()


# ---------------------------------------------------------------- cursore

func _process(delta: float) -> void:
	_update_doors()
	_update_roof_fade(delta)
	_update_up_fade(delta)
	_update_wall_fade(delta)

	# le lanterne delle case sull'albero dondolano piano nel vento
	_sway_t += delta
	for pivot in _lanterns:
		if is_instance_valid(pivot):
			pivot.rotation.z = sin(_sway_t * 1.35) * 0.15
			pivot.rotation.x = sin(_sway_t * 0.9 + 1.3) * 0.09

	if not _active or _ghost == null:
		return

	# un pezzo del piano di sopra (Solaio, Ponticello…) vive sempre al
	# piano 1: cursore e validazione lo seguono anche col piano attivo a 0
	var eff := _level
	if not _demolish and bool(_items[_index].get("up", false)):
		eff = 1
	var lvl_y := FLOOR_H * float(eff)
	var world_pos: Vector3
	if debug_ghost_pos != Vector3.INF:
		world_pos = debug_ghost_pos
	else:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var mouse := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mouse)
		var dir := cam.project_ray_normal(mouse)
		if absf(dir.y) < 0.0001 or (lvl_y - from.y) / dir.y < 0.0:
			return
		world_pos = from + dir * ((lvl_y - from.y) / dir.y)

	_mouse_world = world_pos
	# lo snap alla cella lo fa il GridManager (C++)
	var cell_pos: Vector3 = _grid.snap_to_grid(world_pos)
	_hover_cell = Vector2i(roundi(cell_pos.x), roundi(cell_pos.z))
	_grid_plane.position = Vector3(_hover_cell.x, 0.015 + lvl_y, _hover_cell.y)

	# modalità demolizione: evidenzia in rosso il pezzo sotto il cursore
	if _demolish:
		_update_demolish_target()
		return

	var item := _items[_index]
	if item["type"] == "edge":
		_update_edge_cursor(world_pos)
	else:
		_cursor_key = _hover_cell
		_cursor_pos = Vector3(_hover_cell.x, lvl_y, _hover_cell.y)
		_cursor_yaw = -_rot * PI * 0.5
		_valid = not (_dicts(eff)[item["layer"]] as Dictionary).has(_cursor_key)
		if eff == 1:
			_valid = _valid and _up_supported(item, _cursor_key)
		# sul fiume non si costruisce (i ponti ci sono già, e sono belli)
		if _valid and _cozy \
				and bool(_cozy.call("is_river", Vector3(_cursor_key.x, 0, _cursor_key.y))):
			_valid = false

	_ghost.position = _ghost.position.lerp(_cursor_pos, 1.0 - exp(-22.0 * delta))
	_ghost.rotation.y = lerp_angle(_ghost.rotation.y, _cursor_yaw, 1.0 - exp(-18.0 * delta))
	_overlay.albedo_color = VALID_TINT if _valid else INVALID_TINT


# bordo più vicino al cursore: orizzontale (lungo X) o verticale (lungo Z)
func _update_edge_cursor(p: Vector3) -> void:
	var lvl_y := FLOOR_H * float(_level)
	var hz := floorf(p.z) + 0.5
	var h_center := Vector3(roundf(p.x), lvl_y, hz)
	var vx := floorf(p.x) + 0.5
	var v_center := Vector3(vx, lvl_y, roundf(p.z))
	var flip := PI if _rot % 2 == 1 else 0.0
	if absf(p.z - hz) <= absf(p.x - vx):
		_cursor_pos = h_center
		_cursor_yaw = 0.0 + flip
	else:
		_cursor_pos = v_center
		_cursor_yaw = PI * 0.5 + flip
	_cursor_key = Vector2i(roundi(_cursor_pos.x * 2.0), roundi(_cursor_pos.z * 2.0))
	_valid = not (_dicts(_level)["edge"] as Dictionary).has(_cursor_key)
	# di sopra, un muro vuole un solaio in una delle due celle che separa
	if _valid and _level == 1:
		var ok := false
		for cell in _edge_neighbor_cells(_cursor_key):
			if (_placed_up[0] as Dictionary).has(cell):
				ok = true
		_valid = ok


# le due celle separate da un bordo (chiave raddoppiata)
func _edge_neighbor_cells(key: Vector2i) -> Array[Vector2i]:
	if posmod(key.y, 2) == 1:
		# bordo orizzontale: celle a nord e sud
		@warning_ignore("integer_division")
		var cy := (key.y - 1) / 2
		@warning_ignore("integer_division")
		return [Vector2i(key.x / 2, cy), Vector2i(key.x / 2, cy + 1)]
	@warning_ignore("integer_division")
	var cx := (key.x - 1) / 2
	@warning_ignore("integer_division")
	return [Vector2i(cx, key.y / 2), Vector2i(cx + 1, key.y / 2)]


# regola di sostegno del piano di sopra: un solaio vuole un appoggio
# (muro a terra sul perimetro, solaio/ponticello vicino, o una Scala o
# Casa albero in una cella adiacente); tutto il resto vuole un solaio.
func _up_supported(item: Dictionary, cell: Vector2i) -> bool:
	if not str(item["name"]) in UP_AUTO:
		return (_placed_up[0] as Dictionary).has(cell)
	# muri a terra sul perimetro della cella
	var edges := [
		Vector2i(cell.x * 2, cell.y * 2 - 1), Vector2i(cell.x * 2, cell.y * 2 + 1),
		Vector2i(cell.x * 2 - 1, cell.y * 2), Vector2i(cell.x * 2 + 1, cell.y * 2),
	]
	for e in edges:
		var wall = (_placed["edge"] as Dictionary).get(e)
		if wall and str((wall as Node3D).get_meta("item_name", "")) in WALL_ITEMS:
			return true
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var near := cell + off
		if (_placed_up[0] as Dictionary).has(near):
			return true
		var ground = (_placed[2] as Dictionary).get(near)
		if ground == null:
			ground = (_placed[2] as Dictionary).get(cell)
		if ground and str((ground as Node3D).get_meta("item_name", "")) in ["Scala", "Casa albero"]:
			return true
	return false


func _edge_key_to_transform(key: Vector2i) -> Array:
	var pos := Vector3(key.x * 0.5, 0, key.y * 0.5)
	var yaw := 0.0 if posmod(key.y, 2) == 1 else PI * 0.5
	return [pos, yaw]


# ------------------------------------------------------- porte e tetti

# Da che parte si apre l'anta: una porta VERA si spinge, quindi ruota
# VIA da chi la sta attraversando. z_locale è la posizione del passante
# nello spazio della porta (l'anta chiusa vive sul piano z=0).
static func verso_porta(z_locale: float) -> float:
	return 1.95 if z_locale > 0.0 else -1.95


# Le porte si aprono da sole al passaggio — di Mochi E dei residenti
# (gruppo "passanti"): prima gli abitanti le attraversavano da fantasmi.
# L'anta recita da anta: spinta con un piccolo overshoot che si assesta
# (il legno ha peso), richiusa più lenta che accelera come per gravità
# e AGGANCIA col chiavistello sull'ultimo grado. Cigolio in apertura,
# cigolio corto + tonfo e scatto in chiusura, ogni volta a pitch diverso.
func _update_doors() -> void:
	if _doors.is_empty():
		return
	var passanti := get_tree().get_nodes_in_group("passanti")
	for d in _doors:
		var hinge := d["hinge"] as Node3D
		if hinge == null or not is_instance_valid(hinge):
			continue
		# il più vicino tra Mochi e i passanti (la soglia è sul CARDINE,
		# non sulla base del nodo: la porta della casa sull'albero sta in quota)
		var qui := hinge.global_position
		var vicino: Node3D = null
		var best := 1.35
		if _player != null:
			var dp := _player.global_position.distance_to(qui)
			if dp < best:
				best = dp
				vicino = _player
		for w in passanti:
			if w is Node3D and is_instance_valid(w):
				var dw := (w as Node3D).global_position.distance_to(qui)
				if dw < best:
					best = dw
					vicino = w
		var open := vicino != null
		if open == bool(d["open"]):
			continue
		d["open"] = open
		if d.has("tw") and d["tw"] != null and (d["tw"] as Tween).is_valid():
			(d["tw"] as Tween).kill()
		var tw := create_tween()
		d["tw"] = tw
		if open:
			# via da chi spinge: il lato lo dice la posizione locale
			# rispetto al PIANO dell'anta (nella casa sull'albero il
			# varco non sta sull'origine del nodo)
			var girata := verso_porta((d["node"] as Node3D).to_local(
					vicino.global_position).z - float(d.get("piano_z", 0.0)))
			d["girata"] = girata
			# la spinta: oltre il segno di un soffio, poi si assesta
			tw.tween_property(hinge, "rotation:y", girata * 1.07, 0.34) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(hinge, "rotation:y", girata, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if _sfx:
				_sfx.play("cigolio", -12.0, randf_range(0.9, 1.14))
				_sfx.play("door_open", -20.0)   # il fiato d'aria sotto il cigolio
		else:
			var girata := float(d.get("girata", -1.95))
			# ricade come per gravità fin quasi al telaio...
			tw.tween_property(hinge, "rotation:y", girata * 0.05, 0.5) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# ...e il chiavistello la tira dentro con lo scatto
			if _sfx:
				tw.tween_callback(_sfx.play.bind("door_close", -14.0))
			tw.tween_property(hinge, "rotation:y", 0.0, 0.1) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if _sfx:
				_sfx.play("cigolio", -19.0, 1.35)   # il lamento corto del rientro


# quando Mochi è sotto un tetto (a terra o in quota), i tetti dissolvono
var _roof_fade_applied := -1.0
var _up_fade_applied := -1.0


func _update_roof_fade(delta: float) -> void:
	if _roofs.is_empty():
		return
	var target := 0.0
	if _player:
		var cell := Vector2i(roundi(_player.global_position.x), roundi(_player.global_position.z))
		if (_placed[3] as Dictionary).has(cell) or (_placed_up[3] as Dictionary).has(cell):
			target = 0.85
	_roof_fade = lerpf(_roof_fade, target, 1.0 - exp(-9.0 * delta))
	if absf(_roof_fade - target) < 0.001:
		_roof_fade = target  # converso: da qui in poi niente riscritture
	if is_equal_approx(_roof_fade, _roof_fade_applied):
		return
	_roof_fade_applied = _roof_fade
	for meshes in _roofs.values():
		for mi in meshes:
			mi.transparency = _roof_fade


# quando Mochi è al piano terra sotto un solaio, il piano di sopra
# intero (solai, ponticelli, arredo) si dissolve per lasciarla vedere
func _update_up_fade(delta: float) -> void:
	if _ups.is_empty():
		return
	var target := 0.0
	if _player and _player.global_position.y < FLOOR_H - 0.7:
		var cell := Vector2i(roundi(_player.global_position.x), roundi(_player.global_position.z))
		if (_placed_up[0] as Dictionary).has(cell):
			target = 0.85
	_up_fade = lerpf(_up_fade, target, 1.0 - exp(-9.0 * delta))
	if absf(_up_fade - target) < 0.001:
		_up_fade = target
	if is_equal_approx(_up_fade, _up_fade_applied):
		return
	_up_fade_applied = _up_fade
	for meshes in _ups.values():
		for mi in meshes:
			mi.transparency = _up_fade


func _register_special(item_name: String, node: Node3D) -> void:
	node.set_meta("item_name", item_name)
	var lvl := int(node.get_meta("lvl", 0))
	if item_name == "Porta":
		var hinge := node.find_child("Hinge", true, false)
		if hinge:
			_doors.append({"node": node, "hinge": hinge, "open": false})
	if item_name == "Casa albero":
		var pivot := node.find_child("LanternaPivot", true, false)
		if pivot:
			_lanterns.append(pivot)
		# anche la casetta lassù ha la sua anta col cardine (il piano
		# dell'anta sta a z=0.32 nello spazio del nodo, non sull'origine)
		var anta := node.find_child("Hinge", true, false)
		if anta:
			_doors.append({"node": node, "hinge": anta, "open": false,
					"piano_z": 0.32})
		# una casa sull'albero nuova di zecca merita gli anelli
		if not _loading:
			var gtree := get_tree().get_first_node_in_group("grande_albero")
			if gtree:
				gtree.engrave_once("casa_albero", "★", "è nata una casa sull'albero")
	if item_name == "Tetto":
		var meshes: Array[MeshInstance3D] = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			(mi as MeshInstance3D).transparency = _roof_fade
		_roofs[node] = meshes
	elif item_name in WALL_ITEMS:
		var meshes: Array[MeshInstance3D] = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
		_walls[node] = {"meshes": meshes, "fade": 0.0}
	elif lvl == 1:
		# solai, ponticelli e arredo del piano di sopra: dissolvono
		# quando Mochi sta sotto di loro
		var meshes: Array[MeshInstance3D] = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			(mi as MeshInstance3D).transparency = _up_fade
		_ups[node] = meshes


func _unregister_special(node: Node3D) -> void:
	var item_name: String = node.get_meta("item_name", "")
	if item_name == "Porta":
		_doors = _doors.filter(func(d): return d["node"] != node)
	if item_name == "Casa albero":
		var pivot := node.find_child("LanternaPivot", true, false)
		_lanterns.erase(pivot)
	if item_name == "Tetto":
		_roofs.erase(node)
	elif item_name in WALL_ITEMS:
		_walls.erase(node)
	else:
		_ups.erase(node)


# muri "cutaway" alla The Sims: quando un muro sta tra la camera e Mochi
# (cioè quando lei è dietro o dentro casa), si dissolve per lasciarti vedere
func _update_wall_fade(delta: float) -> void:
	if _walls.is_empty() or _player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pp := _player.global_position
	pp.y = 0.0
	var cp := cam.global_position
	cp.y = 0.0
	var seg := pp - cp
	var seg_len2 := seg.length_squared()
	var k := 1.0 - exp(-10.0 * delta)
	for node in _walls:
		var w: Dictionary = _walls[node]
		var wp: Vector3 = (node as Node3D).global_position
		wp.y = 0.0
		var target := 0.0
		if seg_len2 > 0.01:
			var t := (wp - cp).dot(seg) / seg_len2
			if t > 0.15 and t < 0.97 and wp.distance_to(cp + seg * t) < 1.15:
				target = 0.82
		var f := lerpf(w["fade"], target, k)
		w["fade"] = f
		# i muri del piano di sopra seguono anche la dissolvenza dei solai
		if int((node as Node3D).get_meta("lvl", 0)) == 1:
			f = maxf(f, _up_fade)
		if absf(f - float(w.get("shown", -1.0))) > 0.0004:
			w["shown"] = f
			for mi in w["meshes"]:
				(mi as MeshInstance3D).transparency = f
				(mi as MeshInstance3D).cast_shadow = \
						GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if f > 0.4 \
						else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Superficie sotto una posizione: "wood" sul pavimento, "stone" sul
## sentiero, altrimenti "grass". Usata per i suoni dei passi.
func surface_at(pos: Vector3) -> String:
	var cell := Vector2i(roundi(pos.x), roundi(pos.z))
	# al piano di sopra si cammina sull'assito
	if pos.y > 1.2 and (_placed_up[0] as Dictionary).has(cell):
		return "wood"
	var floor_node = (_placed[0] as Dictionary).get(cell)
	if floor_node:
		var n: String = (floor_node as Node3D).get_meta("item_name", "")
		return "stone" if n == "Sentiero" else "wood"
	return "grass"


## Tutti i pezzi piazzati con un certo nome (es. "Cassetta posta"),
## su qualunque layer e piano.
func get_placed_by_name(item_name: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for dicts in [_placed, _placed_up]:
		for layer in [0, 1, 2, 3, "edge"]:
			for node in (dicts[layer] as Dictionary).values():
				if (node as Node3D).get_meta("item_name", "") == item_name:
					out.append(node)
	return out


## I pezzi su cui ci si può sedere o dormire (per il sistema di interazione).
func get_interactables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dicts in [_placed, _placed_up]:
		for node in (dicts[2] as Dictionary).values():
			var n: String = (node as Node3D).get_meta("item_name", "")
			if n in INTERACTABLE:
				out.append({"node": node, "name": n})
				continue
			# I POSTI DICHIARATI. Un pezzo grande non e' una seduta sola nel
			# suo centro: il gazebo e la serra dichiarano DOVE ci si siede,
			# col nodo «Posto*» e il meta «seduta» (l'ancoraggio E' il
			# posto). Prima li trovavano solo i vicini — il giocatore
			# poteva guardare due sedie da giardino e non sedersi.
			for posto in (node as Node3D).find_children("Posto*", "Node3D", true, false):
				if (posto as Node3D).has_meta("seduta"):
					out.append({"node": posto, "name": "Posto"})
	return out


# ---------------------------------------------------------------- azioni

func _try_place() -> void:
	# rete di sicurezza: il pezzo selezionato dev'essere sbloccato
	if _locks_active and not is_unlocked(str(_items[_index]["name"])):
		_shake(_ghost)
		if _sfx: _sfx.place_deny()
		return
	if not _valid:
		_shake(_ghost)
		if _sfx: _sfx.place_deny()
		return
	var item := _items[_index]
	# i pezzi di legno si pagano in legna tagliata (se il boschetto c'è)
	var wc := get_tree().get_first_node_in_group("woodcutting")
	if wc and not wc.can_afford_piece(str(item["name"])):
		_shake(_ghost)
		if _sfx: _sfx.place_deny()
		wc.deny_toast(str(item["name"]))   # dice QUANTA legna manca
		return
	var v := _variant_for_current()
	if item["type"] == "edge":
		place_edge(_cursor_key, item["name"], _rot % 2 == 1, true, _level, v)
	else:
		place_cell(_cursor_key, item["name"], _rot, true, _level, v)
	if wc:
		wc.pay_for_piece(str(item["name"]))
	if _sfx: _sfx.place_ok()
	get_tree().call_group("regista", "note", "costruzione")


## LA FILA CONTINUA. Piu' gradinate affiancate nella stessa direzione
## sono UNA platea: il bracciolo di pietra vive solo sui fianchi liberi.
## Qui, a ogni piazzamento o rimozione, la cella toccata e le sue vicine
## si guardano intorno: chi ha una gradinata di pari rotazione sul fianco
## spegne il bracciolo da quel lato, chi resta capofila lo tiene.
## Statica e senza stato (lavora sul dizionario cella->nodo di un layer):
## i test la fanno girare su un dizionario finto, senza scena.
static func rinfresca_braccioli(dict: Dictionary, cell: Vector2i) -> void:
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var nodo := dict.get(cell + d) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Gradinata":
			continue
		var rot := posmod(int(nodo.get_meta("rot", 0)), 4)
		var passo := passo_fila(rot)
		_bracciolo_acceso(nodo, "BraccioloDx",
				not _fila_continua(dict, cell + d + passo, rot))
		_bracciolo_acceso(nodo, "BraccioloSx",
				not _fila_continua(dict, cell + d - passo, rot))


## IL SENTIERO CHE SI RICONOSCE: quando si posa (o si toglie) un
## Sentiero, la sua cella e le quattro vicine si RICOSTRUISCONO le pietre
## chiedendo al catalogo la posa giusta per i vicini che hanno adesso —
## e due celle affiancate diventano UNA passata continua. Stesso patto
## della Gradinata coi braccioli: statico e guidato dal dizionario, così
## si prova a occhi chiusi.
static func rinfresca_sentieri(dict: Dictionary, cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var c := cell + d
		var nodo := dict.get(c) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Sentiero":
			continue
		var vicini := {
			"e": _e_sentiero(dict, c + Vector2i(1, 0)),
			"o": _e_sentiero(dict, c + Vector2i(-1, 0)),
			"s": _e_sentiero(dict, c + Vector2i(0, 1)),
			"n": _e_sentiero(dict, c + Vector2i(0, -1)),
		}
		# il seme è della CELLA: la stessa cella rifà sempre le stesse
		# pietre, e i salvataggi non ballano da un caricamento all'altro
		var nuovo: Node3D = BuildCatalog.sentiero_cella(vicini,
				int(hash(c)) & 0x7fffffff)
		var vecchie := nodo.get_node_or_null("Pietre")
		if vecchie:
			vecchie.name = "PietreVecchie"
			vecchie.queue_free()
		var pietre: Node3D = nuovo.get_node("Pietre")
		nuovo.remove_child(pietre)
		nodo.add_child(pietre)
		# i vicini sono in coordinate MONDO, ma il nodo può essere stato
		# posato ruotato (R): il wrapper annulla la rotazione del pezzo
		pietre.rotation.y = -nodo.rotation.y
		nuovo.free()


static func _e_sentiero(dict: Dictionary, c: Vector2i) -> bool:
	var nodo := dict.get(c) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Sentiero"


## L'AIUOLA CHE SI UNISCE: posata (o tolta) un'Aiuola, la sua cella e le
## quattro vicine si RIFANNO la terra chiedendo al catalogo la forma
## giusta per i vicini che hanno adesso — e due aiuole affiancate
## diventano UNA striscia di terra continua. Stesso patto del Sentiero:
## statico e guidato dal dizionario, si prova a occhi chiusi. Si scambia
## solo il figlio «Terra»: il velo d'acqua e i germogli del Garden
## stanno appesi alla radice del pezzo e non si toccano.
static func rinfresca_aiuole(dict: Dictionary, cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var c := cell + d
		var nodo := dict.get(c) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Aiuola":
			continue
		var vicini := {
			"e": _e_aiuola(dict, c + Vector2i(1, 0)),
			"o": _e_aiuola(dict, c + Vector2i(-1, 0)),
			"s": _e_aiuola(dict, c + Vector2i(0, 1)),
			"n": _e_aiuola(dict, c + Vector2i(0, -1)),
		}
		# il seme è della CELLA: la stessa cella rifà sempre le stesse
		# zolle, e i salvataggi non ballano da un caricamento all'altro
		var nuovo: Node3D = BuildCatalog.aiuola_cella(vicini,
				int(hash(c)) & 0x7fffffff)
		var vecchia := nodo.get_node_or_null("Terra")
		if vecchia:
			vecchia.name = "TerraVecchia"
			vecchia.queue_free()
		var terra: Node3D = nuovo.get_node("Terra")
		nuovo.remove_child(terra)
		nodo.add_child(terra)
		# i vicini sono in coordinate MONDO, ma il nodo può essere stato
		# posato ruotato (R): il wrapper annulla la rotazione del pezzo
		terra.rotation.y = -nodo.rotation.y
		nuovo.free()


## LE SERRE CHE SI FONDONO. Due serre vicine non sono due serre: sono una
## serra piu' grande. Il gruppo e' 8-CONNESSO (due che si toccano d'angolo
## sono un edificio solo: i loro gusci si compenetrerebbero comunque), e da
## quello escono la pianta e la geometria di ogni campata — BuildCatalog fa
## il disegno, qui si decide solo CHI va rifatto.
##
## Non si tocca MAI: la chiave nel dizionario, l'identita' del nodo, i meta
## item_name/rot/variant/lvl. Percio' il salvataggio non cambia di un byte e
## get_placed_by_name("Serra") continua a contare N celle per N serre.
static func e_serra(dict: Dictionary, c: Vector2i) -> bool:
	var nodo := dict.get(c) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Serra"


## Il gruppo di serre attaccate a `c` (flood fill 8-connesso). `viste` e'
## condiviso fra piu' chiamate cosi' una cella non finisce in due giri.
static func gruppo_serra(dict: Dictionary, c: Vector2i, viste := {}) -> Array:
	if not e_serra(dict, c) or viste.has(c):
		return []
	var fuori: Array = []
	var coda: Array = [c]
	viste[c] = true
	while not coda.is_empty():
		var q: Vector2i = coda.pop_back()
		fuori.append(q)
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var v := q + Vector2i(dx, dz)
				if not viste.has(v) and e_serra(dict, v):
					viste[v] = true
					coda.append(v)
	return fuori


## Rifa' la geometria e le collisioni di un gruppo intero. Il figlio
## «Vetreria» si RINOMINA prima di liberarlo: un nodo in coda tiene occupato
## il nome fino a fine frame, e il nuovo diventerebbe «Vetreria2» — al
## rinfresco dopo non lo troveresti piu'.
static func ricostruisci_serra(dict: Dictionary, celle: Array) -> void:
	if celle.is_empty():
		return
	var pianta := BuildCatalog.serra_pianta(celle)
	for c: Vector2i in celle:
		var nodo := dict.get(c) as Node3D
		if nodo == null:
			continue
		var vecchia := nodo.find_child("Vetreria", true, false)
		var ospite: Node3D = nodo
		if vecchia != null:
			ospite = vecchia.get_parent() as Node3D
			vecchia.name = "VetreriaVecchia"
			ospite.remove_child(vecchia)
			vecchia.queue_free()
		var radice: Node3D = BuildCatalog.serra_cella(pianta, c)
		var campata: Node3D = radice.get_node("Vetreria")
		radice.remove_child(campata)
		ospite.add_child(campata)
		# la pianta e' in coordinate MONDO: si annulla la rotazione con cui
		# il giocatore ha posato il pezzo (F), come fa l'aiuola
		campata.rotation.y -= nodo.rotation.y
		radice.free()
		_riscrivi_scatole(nodo, campata)


## Le collisioni si rifanno SEMPRE a parte: le CollisionShape3D sono figlie
## dirette dello StaticBody3D, e una shape dentro un contenitore non viene
## registrata affatto (senza errori). Si tolgono con remove_child, che
## sparisce NEL FRAME: con queue_free resterebbero attive un frame di piu' e
## il varco della porta sarebbe tappato proprio mentre la serra si fonde.
static func _riscrivi_scatole(corpo: Node3D, campata: Node3D) -> void:
	if corpo is not StaticBody3D:
		return
	for f in corpo.get_children():
		if f is CollisionShape3D:
			corpo.remove_child(f)
			f.queue_free()
	var scatole: Array = campata.get_meta("scatole", [])
	var giro := campata.rotation.y
	var base := Basis(Vector3.UP, giro)
	for sc: Array in scatole:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sc[0]
		shape.shape = box
		shape.position = base * (sc[1] as Vector3)
		shape.rotation.y = giro
		corpo.add_child(shape)


static func _e_aiuola(dict: Dictionary, c: Vector2i) -> bool:
	var nodo := dict.get(c) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Aiuola"


## Il passo di una cella lungo la fila: l'asse X locale del pezzo,
## ruotato come lo ruota place_cell (rotation.y = -rot * PI/2).
static func passo_fila(rot: int) -> Vector2i:
	match posmod(rot, 4):
		0: return Vector2i(1, 0)
		1: return Vector2i(0, 1)
		2: return Vector2i(-1, 0)
		_: return Vector2i(0, -1)


static func _fila_continua(dict: Dictionary, c: Vector2i, rot: int) -> bool:
	var nodo := dict.get(c) as Node3D
	if nodo == null or str(nodo.get_meta("item_name", "")) != "Gradinata":
		return false
	# stessa rotazione o niente: due file che si voltano le spalle
	# (o si incrociano) non sono una platea
	return posmod(int(nodo.get_meta("rot", 0)), 4) == rot


static func _bracciolo_acceso(nodo: Node3D, nome: String, on: bool) -> void:
	var br := nodo.find_child(nome, true, false) as Node3D
	if br:
		br.visible = on


## LA STACCIONATA CONTINUA. Stessa regola della gradinata, portata sui
## BORDI: i segmenti in fila sulla stessa retta fanno UN recinto, e il
## palo vive solo ai capi. Il verso del pezzo (rotazione + flip) si
## legge dal nodo: il palo da spegnere e' quello che GUARDA il vicino.
## Statica e senza stato: i test la fanno girare su un dizionario finto.
static func rinfresca_pali(dict: Dictionary, key: Vector2i) -> void:
	var passo := passo_bordo(key)
	for d in [Vector2i.ZERO, passo, -passo]:
		var k: Vector2i = key + d
		var nodo := dict.get(k) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Staccionata":
			continue
		# l'asse X locale del pezzo, nel mondo (il flip e' gia' nel yaw)
		var avanti := Vector3(cos(nodo.rotation.y), 0, -sin(nodo.rotation.y))
		var verso := Vector3(float(passo.x), 0, float(passo.y)).normalized()
		var continua_piu := _stessa_stecca(dict, k + passo)
		var continua_meno := _stessa_stecca(dict, k - passo)
		if avanti.dot(verso) > 0.0:
			_bracciolo_acceso(nodo, "PaloDx", not continua_piu)
			_bracciolo_acceso(nodo, "PaloSx", not continua_meno)
		else:
			_bracciolo_acceso(nodo, "PaloDx", not continua_meno)
			_bracciolo_acceso(nodo, "PaloSx", not continua_piu)


## Il passo fra due bordi COLLINEARI: le chiavi dei bordi sono raddoppiate,
## e un bordo con la y dispari corre lungo X (sta fra una cella e la sua
## vicina in z), uno con la x dispari corre lungo Z.
static func passo_bordo(key: Vector2i) -> Vector2i:
	return Vector2i(2, 0) if posmod(key.y, 2) == 1 else Vector2i(0, 2)


static func _stessa_stecca(dict: Dictionary, k: Vector2i) -> bool:
	var nodo := dict.get(k) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Staccionata"


## Piazza un pezzo "cell" nella cella data (lvl 1 = piano di sopra).
## Usato anche dalla demo CLI.
func place_cell(cell: Vector2i, piece: String, rot := 0, animate := true, lvl := 0, variant := "") -> void:
	var index := item_index(piece)
	if index < 0:
		push_warning("BuildSystem: pezzo sconosciuto nel salvataggio: %s" % piece)
		return
	var item := _items[index]
	if bool(item.get("up", false)):
		lvl = 1
	var dict := _dicts(lvl)[item["layer"]] as Dictionary
	if dict.has(cell):
		return
	if _cozy and bool(_cozy.call("is_river", Vector3(cell.x, 0, cell.y))):
		return  # il letto del fiume resta del fiume
	var node := _build_placed(index, variant)
	node.position = Vector3(cell.x, FLOOR_H * lvl, cell.y)
	node.rotation.y = -rot * PI * 0.5
	_placed_root.add_child(node)
	dict[cell] = node
	node.set_meta("lvl", lvl)
	_register_special(piece, node)
	node.set_meta("rot", rot)
	node.set_meta("variant", variant)
	# la fila continua: la gradinata nuova e le sue vicine si accordano
	# su chi tiene il bracciolo (vedi rinfresca_braccioli)
	rinfresca_braccioli(dict, cell)
	# e il sentiero nuovo tende le pietre verso i sentieri vicini
	rinfresca_sentieri(dict, cell)
	# e l'aiuola nuova si unisce alle aiuole accanto in una striscia sola
	rinfresca_aiuole(dict, cell)
	# e le serre vicine diventano UN edificio (a fine frame, una volta sola)
	_segna_serre(dict, cell)
	# pavimenti, sentieri e tappeti a terra schiacciano l'erba sotto di sé
	if lvl == 0 and int(item["layer"]) <= 1:
		get_tree().call_group("cozy_world", "flatten_cell", cell)
	if animate:
		_pop_in(node)
	if not _loading:
		placed_changed.emit()
	request_save()


## Piazza un pezzo "edge" sul bordo con chiave raddoppiata data.
func place_edge(key: Vector2i, piece: String, flip := false, animate := true, lvl := 0, variant := "") -> void:
	var index := item_index(piece)
	if index < 0:
		push_warning("BuildSystem: pezzo sconosciuto nel salvataggio: %s" % piece)
		return
	var dict := _dicts(lvl)["edge"] as Dictionary
	if dict.has(key):
		return
	var tf := _edge_key_to_transform(key)
	var node := _build_placed(index, variant)
	node.position = tf[0] + Vector3(0, FLOOR_H * lvl, 0)
	# micro-sfalsamento verticale deterministico (±3 mm): le modanature di
	# pezzi adiacenti non condividono mai lo stesso piano -> niente z-fighting
	node.position.y += 0.0015 * float(posmod(key.x * 7 + key.y * 13, 5) - 2)
	node.rotation.y = tf[1] + (PI if flip else 0.0)
	_placed_root.add_child(node)
	dict[key] = node
	node.set_meta("lvl", lvl)
	_register_special(piece, node)
	node.set_meta("flip", flip)
	node.set_meta("variant", variant)
	# il recinto continuo: il segmento nuovo e i collineari si accordano
	# su chi tiene il palo (vedi rinfresca_pali)
	rinfresca_pali(dict, key)
	if animate:
		_pop_in(node)
	if not _loading:
		placed_changed.emit()
	request_save()


# visual del catalogo + StaticBody3D con le collisioni del pezzo
# (il terzo elemento opzionale di una collisione è la rotazione X: rampe)
func _build_placed(index: int, variant := "") -> Node3D:
	var item := _items[index]
	var builder: Callable = item["builder"]
	var visual: Node3D = builder.call()
	if variant != "":
		var eco := _economy()
		if eco and eco.piece_takes_variant(str(item["name"])):
			eco.apply_variant(visual, variant)
	var cols: Array = item["cols"]
	if cols.is_empty():
		return visual
	var body := StaticBody3D.new()
	body.add_child(visual)
	for c in cols:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[0]
		shape.shape = box
		shape.position = c[1]
		if c.size() > 2:
			shape.rotation.x = float(c[2])
		body.add_child(shape)
	return body


func _pop_in(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.55
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_poof(node.position + Vector3(0, 0.35, 0), Color(1.0, 0.9, 0.55))


# cerca il pezzo rimovibile sotto il cursore, per priorità:
# tetto, poi oggetti, poi bordi, poi tappeti e pavimenti — sul piano attivo
func _find_removable() -> Array:
	for layer in [3, 2, "edge", 1, 0]:
		var key: Vector2i = _hover_cell
		if layer is String:
			var near := _nearest_edge_key()
			if near == Vector2i.MAX:
				continue
			key = near
		var dict := _dicts(_level)[layer] as Dictionary
		if dict.has(key):
			return [layer, key, dict[key]]
	return []


func _try_remove() -> void:
	var found := _find_removable()
	if found.is_empty():
		return
	_remove_at(found[0], found[1], _level)


func _remove_at(layer, key, lvl := 0) -> void:
	var dict := _dicts(lvl)[layer] as Dictionary
	if not dict.has(key):
		return
	var node := dict[key] as Node3D
	dict.erase(key)
	# se in mezzo alla fila c'era una gradinata, i vicini si riprendono
	# il bracciolo sul fianco tornato libero — e i sentieri accanto
	# ritirano le pietre dal varco
	if key is Vector2i:
		rinfresca_braccioli(dict, key)
		rinfresca_pali(dict, key)
		rinfresca_sentieri(dict, key)
		rinfresca_aiuole(dict, key)
		# tolta una campata, il gruppo si richiude — o si spezza in due
		_segna_serre(dict, key)
	_unregister_special(node)
	if node == _demo_target:
		_demo_target = null
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.02, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)
	_spawn_poof(node.position + Vector3(0, 0.3, 0), Color(0.9, 0.85, 0.8))
	if _sfx: _sfx.remove_item()
	# se la cella a terra è tornata libera (né pavimento né tappeto),
	# l'erba rinasce
	if lvl == 0 and layer is int and int(layer) <= 1 and key is Vector2i:
		if not (_placed[0] as Dictionary).has(key) and not (_placed[1] as Dictionary).has(key):
			get_tree().call_group("cozy_world", "unflatten_cell", key)
	placed_changed.emit()
	request_save()


# ------------------------------------------------------- salvataggio

# Il villaggio vive in user://village.json: una riga per pezzo, celle come
# [layer, x, z, nome, rot] e bordi come [kx, ky, nome, flip]. Il file è
# minuscolo, quindi si riscrive per intero: niente "vuoi salvare?", il
# villaggio c'è e basta.

# --- API PUBBLICA: chiedere un salvataggio --------------------------------
# Chi cambia stato persistente (economia, collezione, giardino, Ordini…)
# chiama `request_save()`. NON chiamare `_save_village()` da fuori: è il
# writer interno, e usarlo da mezzo progetto è ciò che aveva reso il
# salvataggio un dettaglio implementativo pubblico — con l'effetto che ogni
# singola nocciolina scriveva il file INTERO due volte (una l'economia, una
# chi l'aveva fatta guadagnare).
#
# `request_save()` è idempotente dentro il frame: quante che siano le
# richieste, il file si scrive UNA volta sola, a fine frame. Chi sta per
# uscire (pausa → titolo, quit, CLI) usa `save_now()`, che scrive subito:
# un salvataggio differito, a scena morta, non verrebbe mai eseguito.
var _save_pending := false

# lo stato extra parsato dal salvataggio (per servire i persistable tardivi)
# e chi è già stato servito (instance_id -> true): mai servire due volte
var _loaded_extra := {}
var _served_extra := {}

## Le chiavi che il salvataggio SCRIVE DA SÉ (il villaggio costruito): si
## ricalcolano dalla griglia viva a ogni scrittura e non vanno mai conservate
## dal file precedente.
const CHIAVI_PROPRIE := ["cells", "edges", "up_cells", "up_edges", "variants"]

## LE CHIAVI ORFANE: quelle lette dal salvataggio di cui, in questo momento,
## NESSUN nodo in scena risponde.
##
## Perché esistono: il mondo nasce differito (CozyWorld crea GrandTree,
## Memories, Coop, Stargazing, Legami, Regista… tre frame dopo l'avvio). Il
## payload si ricostruisce DA ZERO e ci si fondono solo i persistable già
## nati: la chiave di un sistema non ancora sveglio spariva dal file. In
## sessione non si vede (la scrittura dopo la rimette), ma se il giocatore
## chiude subito, quel file mutilato È il salvataggio — e il .bak buono se
## l'è già mangiato la rotazione. Andavano perduti Filo Rosso, lutto,
## congedo, contatori del Regista, guardaroba, costellazioni, compleanni,
## ecosistema.
##
## Perché NON si conservano tutte le chiavi vecchie: alcune DEVONO poter
## sparire, ed è il loro sparire a essere lo stato. `mail_current` quando la
## busta è stata aperta (e dentro c'è il REGALO: conservarla lo
## rimaterializzerebbe a ogni avvio), `inv_dishes`/`inv_treasures` quando la
## dispensa si svuota, `home` quando la casa si disfa. Quelle hanno un
## proprietario VIVO in scena, e il censimento le toglie da qui: si conserva
## solo ciò di cui, adesso, nessuno risponde.
var _chiavi_orfane := {}


## Un persistable entrato in scena DOPO il load (generazione differita del
## mondo) reclama qui la sua fetta di salvataggio, una volta sola.
func _on_node_added(node: Node) -> void:
	if _loaded_extra.is_empty():
		return
	if not node.has_method("load_extra") or not node.has_method("save_extra"):
		return
	if _served_extra.has(node.get_instance_id()):
		return
	# il suo load_extra può toccare @onready/figli: aspetta il suo _ready
	if node.is_node_ready():
		_serve_late(node)
	else:
		node.ready.connect(_serve_late.bind(node), CONNECT_ONE_SHOT)


func _serve_late(node: Node) -> void:
	if not is_instance_valid(node) or _served_extra.has(node.get_instance_id()):
		return
	_served_extra[node.get_instance_id()] = true
	node.load_extra(_loaded_extra)


## Chi è in scena si prende la RESPONSABILITÀ delle chiavi che emette: da qui
## in poi quelle possono anche sparire dal file (è il giocatore che le ha
## svuotate), e non vanno più conservate dal salvataggio precedente.
func _rivendica(emesse: Dictionary) -> void:
	for k in emesse:
		_chiavi_orfane.erase(k)


## Il censimento dopo il caricamento: tutti i persistable già svegli
## dichiarano le loro chiavi, e ciò che resta orfano appartiene a un sistema
## che deve ancora nascere. Gira su uno stack SUO (call_deferred da
## _finish_load): un errore dentro un save_extra non deve poter srotolare la
## fine del caricamento e lasciare `_loading` incastrato a true — cioè il
## salvataggio spento in silenzio per sempre.
func _censimento_orfane() -> void:
	for node in get_tree().get_nodes_in_group("persistable"):
		if node.has_method("save_extra"):
			_rivendica(node.save_extra())


## Chiede un salvataggio: si scrive una volta sola a fine frame.
func request_save() -> void:
	if not _persist or _loading or _save_pending:
		return
	_save_pending = true
	_flush_save.call_deferred()


## Scrive SUBITO, in modo sincrono (uscita dal gioco, CLI, cambio scena).
func save_now() -> void:
	_save_pending = false
	_save_village()


## Spegne (o riaccende) le SCRITTURE per l'harness di verifica da riga di
## comando. Il caricamento non passa di qui: `_load_village` è già stato messo
## in coda da `_ready` e non guarda `_persist`, quindi il villaggio del
## giocatore si carica ancora — si blocca solo la riscrittura del file.
func set_persist_for_debug(on: bool) -> void:
	_persist = on
	if not on:
		_save_pending = false


func _flush_save() -> void:
	if not _save_pending:
		return
	_save_pending = false
	_save_village()


# la finestra si chiude col salvataggio ancora in coda: scrivilo adesso o
# il differito muore con la scena
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_pending:
		save_now()


# --- LE SERRE: una ricostruzione a fine frame, non una per pezzo posato ---
# Il caricamento piazza le celle una per una: un rinfresco ingenuo rifarebbe
# il gruppo 1+2+3+4 volte, le prime tre di forma SBAGLIATA e buttate via
# subito. Si accoda e si rifa' una volta sola, con l'idioma gia' in casa
# (_save_pending + _flush_save.call_deferred).
var _serre_da_rifare: Array = []
var _serre_pending := false


func _segna_serre(dict: Dictionary, cell: Vector2i) -> void:
	# GUARDIA OBBLIGATORIA: i rinfresca ricevono il dizionario del LAYER, non
	# del nome. Senza questa uscita, posare una Sedia accanto a una serra
	# ricostruirebbe un edificio intero.
	var tocca := false
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if e_serra(dict, cell + Vector2i(dx, dz)):
				tocca = true
	if not tocca:
		return
	_serre_da_rifare.append([dict, cell])
	if _serre_pending:
		return
	_serre_pending = true
	_flush_serre.call_deferred()


func _flush_serre() -> void:
	_serre_pending = false
	var lavoro := _serre_da_rifare
	_serre_da_rifare = []
	var viste := {}
	for voce: Array in lavoro:
		var dict: Dictionary = voce[0]
		var cell: Vector2i = voce[1]
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var gruppo := gruppo_serra(dict, cell + Vector2i(dx, dz), viste)
				if not gruppo.is_empty():
					ricostruisci_serra(dict, gruppo)


## Il flush SINCRONO: per chi costruisce e guarda nello stesso frame
## (l'harness, i fotografi del catalogo, la CLI). Un differito, a scena
## gia' fotografata, non servirebbe a niente.
func aggiorna_serre_ora() -> void:
	if _serre_pending or not _serre_da_rifare.is_empty():
		_flush_serre()


func _save_village() -> void:
	if not _persist or _loading:
		return
	var cells := []
	var up_cells := []
	for layer in [0, 1, 2, 3]:
		for lvl in 2:
			var dict := _dicts(lvl)[layer] as Dictionary
			var rows := cells if lvl == 0 else up_cells
			for cell: Vector2i in dict:
				var node := dict[cell] as Node3D
				rows.append([layer, cell.x, cell.y,
						node.get_meta("item_name", ""), int(node.get_meta("rot", 0))])
	var edges := []
	var up_edges := []
	for lvl in 2:
		var edict := _dicts(lvl)["edge"] as Dictionary
		var rows := edges if lvl == 0 else up_edges
		for key: Vector2i in edict:
			var node := edict[key] as Node3D
			rows.append([key.x, key.y,
					node.get_meta("item_name", ""), bool(node.get_meta("flip", false))])
	# SI PARTE DA CIÒ DI CUI NESSUNO RISPONDE. Le chiavi orfane (vedi
	# _chiavi_orfane) sono di sistemi che il mondo differito non ha ancora
	# creato: se non le riportassimo qui, un salvataggio nei primissimi frame
	# le cancellerebbe dal file. Ordine di precedenza, dal più debole al più
	# forte: orfane del file < ciò che i persistable vivi dichiarano adesso <
	# le chiavi del villaggio costruito.
	var payload := {}
	for k in _chiavi_orfane:
		if _loaded_extra.has(k):
			payload[k] = _loaded_extra[k]
	# stato extra (giorno del calendario, giardino…) dai nodi "persistable".
	# Cintura di sicurezza: un ritardatario non ancora servito viene servito
	# ADESSO, prima del merge — il suo stato vergine non deve mai
	# sovrascrivere quello salvato.
	for node in get_tree().get_nodes_in_group("persistable"):
		if not _loaded_extra.is_empty() and not _served_extra.has(node.get_instance_id()):
			_serve_late(node)
		var extra: Dictionary = node.save_extra()
		# il proprietario è arrivato: la sua chiave smette di essere orfana
		_rivendica(extra)
		# `true`: chi è in scena ADESSO batte sempre la copia vecchia del file
		payload.merge(extra, true)
	payload.merge({"cells": cells, "edges": edges,
			"up_cells": up_cells, "up_edges": up_edges,
			"variants": _collect_variants()}, true)
	# SCRITTURA BLINDATA: prima su un file temporaneo, poi la versione
	# precedente diventa .bak e il temporaneo prende il suo posto. Un crash
	# a metà scrittura (o il disco pieno) non può mai lasciare mezzo
	# villaggio su disco, e c'è sempre la copia di un attimo fa da cui
	# rialzarsi (_load_village la usa da solo se il .json è rotto).
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		printerr("BuildSystem: salvataggio fallito (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(payload))
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp, save_path)


## Legge e interpreta un salvataggio: null se manca o non è JSON valido.
func _leggi_salvataggio(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _load_village() -> void:
	var data: Variant = _leggi_salvataggio(save_path)
	if data is not Dictionary:
		# ATTENZIONE alla differenza fra "manca" e "è rotto".
		# Il file che MANCA è un villaggio NUOVO: si comincia da zero.
		# Il ripiego sulla copia vale SOLO se il file c'è ma è illeggibile.
		# Prima non distingueva i due casi, e siccome «Nuovo villaggio»
		# archivia il .json lasciando il .bak, il villaggio nuovo
		# RESUSCITAVA quello vecchio: case, residenti, noccioline,
		# collezione, Ordini del Gufo — tutto tornava, con l'unico
		# avviso in una riga di console che il giocatore non vede mai.
		if not FileAccess.file_exists(save_path):
			return
		data = _leggi_salvataggio(save_path + ".bak")
		if data is Dictionary:
			printerr("BuildSystem: village.json illeggibile — ripristinato dalla copia .bak")
		else:
			return
	_loading = true
	var vmap: Dictionary = data.get("variants", {})
	for c in data.get("cells", []):
		if c is Array and c.size() == 5:
			var cell := Vector2i(int(c[1]), int(c[2]))
			place_cell(cell, str(c[3]), int(c[4]), false, 0, str(vmap.get(_pkey(0, int(c[0]), cell), "")))
	for e in data.get("edges", []):
		if e is Array and e.size() == 4:
			var key := Vector2i(int(e[0]), int(e[1]))
			place_edge(key, str(e[2]), bool(e[3]), false, 0, str(vmap.get(_pkey(0, "edge", key), "")))
	for c in data.get("up_cells", []):
		if c is Array and c.size() == 5:
			var ucell := Vector2i(int(c[1]), int(c[2]))
			place_cell(ucell, str(c[3]), int(c[4]), false, 1, str(vmap.get(_pkey(1, int(c[0]), ucell), "")))
	for e in data.get("up_edges", []):
		if e is Array and e.size() == 4:
			var ukey := Vector2i(int(e[0]), int(e[1]))
			place_edge(ukey, str(e[2]), bool(e[3]), false, 1, str(vmap.get(_pkey(1, "edge", ukey), "")))
	# Lo stato extra resta in _loaded_extra per i persistable RITARDATARI:
	# la generazione differita di CozyWorld aggiunge Calendar, Wardrobe,
	# Legami, Ecosystem… qualche frame DOPO questo dispatch. Senza il modello
	# "pull" (vedi _on_node_added) non riceverebbero mai load_extra e il loro
	# stato vergine cancellerebbe il salvataggio alla prima scrittura.
	_loaded_extra = data
	# All'inizio è orfano TUTTO ciò che non è del villaggio costruito: il
	# censimento (dopo i load_extra) toglie da qui le chiavi di chi è già in
	# scena. Partire dal massimo è la posizione prudente — fra il
	# caricamento e il censimento nessuno ha ancora avuto modo di svuotare
	# niente, quindi conservare tutto è esattamente ciò che serve.
	_chiavi_orfane.clear()
	for k in data:
		if not CHIAVI_PROPRIE.has(k):
			_chiavi_orfane[str(k)] = true
	# ogni load_extra su uno stack separato (call_deferred): un errore di
	# runtime in UN sistema non deve srotolare il load e lasciare _loading
	# incastrato a true (= salvataggio disattivato in silenzio per sempre)
	for node in get_tree().get_nodes_in_group("persistable"):
		_served_extra[node.get_instance_id()] = true
		node.load_extra.call_deferred(data)
	_finish_load.call_deferred()


func _finish_load() -> void:
	_loading = false
	placed_changed.emit()
	# il censimento su uno stack a parte: vedi _censimento_orfane
	_censimento_orfane.call_deferred()


## Dove il villaggio occupa il terreno: [Vector3(x, raggio, z)] per ogni
## pezzo piazzato. La usa il taglio della legna: un albero non deve rinascere
## dentro casa, sul pavimento o in mezzo all'orto.
func occupied_spots() -> Array:
	var out := []
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			for key in (_dicts(lvl)[layer] as Dictionary).keys():
				var k: Vector2i = key
				out.append(Vector3(k.x * 0.5, 1.1, k.y * 0.5))
	return out


## Per la verifica CLI: quanti pezzi ci sono nel villaggio (tutti i piani).
func piece_count() -> int:
	var n := 0
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			n += (_dicts(lvl)[layer] as Dictionary).size()
	return n


## Per la verifica CLI: rimuove tutti i pezzi piazzati.
func debug_clear() -> void:
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			for key in (_dicts(lvl)[layer] as Dictionary).keys():
				_remove_at(layer, key, lvl)


# ------------------------------------------------------- demolizione

func _set_demolish(on: bool) -> void:
	if _demolish == on:
		return
	_demolish = on
	if _demo_btn:
		_demo_btn.set_pressed_no_signal(on)
	if _ghost:
		_ghost.visible = _active and not on
	if not on:
		_clear_demolish_target()


func _clear_demolish_target() -> void:
	if _demo_target and is_instance_valid(_demo_target):
		for mi in _demo_target.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null
	_demo_target = null


func _update_demolish_target() -> void:
	var found := _find_removable()
	var node: Node3D = found[2] if not found.is_empty() else null
	if node == _demo_target:
		return
	_clear_demolish_target()
	_demo_target = node
	if node:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _demo_overlay


func _nearest_edge_key() -> Vector2i:
	var p := _mouse_world
	var hz := floorf(p.z) + 0.5
	var vx := floorf(p.x) + 0.5
	var h_d := absf(p.z - hz)
	var v_d := absf(p.x - vx)
	if minf(h_d, v_d) > 0.45:
		return Vector2i.MAX
	if h_d <= v_d:
		return Vector2i(roundi(roundf(p.x) * 2.0), roundi(hz * 2.0))
	return Vector2i(roundi(vx * 2.0), roundi(roundf(p.z) * 2.0))


# F: ruota di 90° l'oggetto già piazzato sotto il cursore (del piano attivo)
func _rotate_placed() -> void:
	var dict := _dicts(_level)[2] as Dictionary
	if not dict.has(_hover_cell):
		return
	var node := dict[_hover_cell] as Node3D
	node.set_meta("rot", posmod(int(node.get_meta("rot", 0)) + 1, 4))
	# pressioni ravvicinate: si mira sempre al bersaglio assoluto accumulato,
	# uccidendo il tween in volo (niente derive di 90° persi per strada)
	var target := float(node.get_meta("rot_target", node.rotation.y)) - PI * 0.5
	node.set_meta("rot_target", target)
	var old_tw = node.get_meta("rot_tw", null)
	if old_tw is Tween and (old_tw as Tween).is_valid():
		(old_tw as Tween).kill()
	var tween := create_tween()
	node.set_meta("rot_tw", tween)
	tween.tween_property(node, "rotation:y", target, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce(node)
	if _sfx: _sfx.rotate_tick()
	request_save()


func _spawn_poof(pos: Vector3, color: Color) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([color, Color(color, 0.6), Color(color, 0.0)])
	tex.gradient = grad

	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -3.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var poof := GPUParticles3D.new()
	poof.amount = 16
	poof.lifetime = 0.55
	poof.one_shot = true
	poof.explosiveness = 1.0
	poof.local_coords = false
	poof.process_material = pm
	poof.draw_pass_1 = quad
	poof.position = pos
	add_child(poof)
	poof.emitting = true
	get_tree().create_timer(1.2).timeout.connect(poof.queue_free)


func _bounce(node: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.12, 0.07)
	tween.tween_property(node, "scale", Vector3.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(node: Node3D) -> void:
	var origin := node.position
	var tween := create_tween()
	tween.tween_property(node, "position:x", origin.x + 0.06, 0.04)
	tween.tween_property(node, "position:x", origin.x - 0.06, 0.05)
	tween.tween_property(node, "position:x", origin.x, 0.05)


# ---------------------------------------------------------------- griglia

func _build_grid_plane() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GRID_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	_grid_plane = MeshInstance3D.new()
	_grid_plane.mesh = plane
	_grid_plane.material_override = mat
	_grid_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_plane.visible = false
	add_child(_grid_plane)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 3
	add_child(_ui)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.94)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", sb)
	var dock := CenterContainer.new()
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -172.0
	dock.offset_bottom = -14.0
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)
	dock.add_child(_panel)
	_panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# la voce del Gufo in cima al pannello: l'Ordine in corso ("" = nascosto)
	_order_banner = Label.new()
	_order_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_order_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_order_banner.custom_minimum_size = Vector2(380, 0)
	_order_banner.add_theme_font_size_override("font_size", 13)
	_order_banner.add_theme_color_override("font_color", Color("8a5a3a"))
	_order_banner.visible = false
	vbox.add_child(_order_banner)

	# riga delle categorie
	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 6)
	cats.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cats)
	var cat_group := ButtonGroup.new()
	for c in CAT_NAMES.size():
		var btn := _make_button(L10n.t(CAT_NAMES[c]), cat_group, 12)
		btn.pressed.connect(_on_cat_pressed.bind(c))
		cats.add_child(btn)
		_cat_buttons.append(btn)

	# lo strumento demolizione: evidenzia in rosso, clic per abbattere
	_demo_btn = _make_button(L10n.t("✕ Demolisci"), null, 12)
	_demo_btn.add_theme_color_override("font_color", Color("a83a3a"))
	_demo_btn.add_theme_color_override("font_hover_color", Color("a83a3a"))
	_demo_btn.add_theme_color_override("font_pressed_color", Color("7a1f1f"))
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.95, 0.55, 0.5, 0.75)
	dsb.set_corner_radius_all(10)
	dsb.content_margin_left = 10.0
	dsb.content_margin_right = 10.0
	_demo_btn.add_theme_stylebox_override("pressed", dsb)
	_demo_btn.add_theme_stylebox_override("hover_pressed", dsb)
	_demo_btn.toggled.connect(func(on: bool): _set_demolish(on))
	cats.add_child(_demo_btn)

	# riga dei pezzi della categoria corrente
	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 6)
	_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_items_row)

	var hint := Label.new()
	hint.text = L10n.t("B esci  ·  rotella / 1-9 scegli  ·  R ruota  ·  V piano su/giù  ·  F ruota piazzato  ·  clic piazza  ·  X rimuovi")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.75))
	vbox.add_child(hint)

	_rebuild_item_row()
	_sync_ui_selection()

	_idle_hint = Label.new()
	_idle_hint.text = L10n.t("B — modalità costruzione")
	_idle_hint.add_theme_font_size_override("font_size", 13)
	_idle_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_idle_hint.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.15, 0.5))
	_idle_hint.add_theme_constant_override("shadow_offset_y", 1)
	_idle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_idle_hint)
	_idle_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_idle_hint.offset_left = -260.0
	_idle_hint.offset_right = -16.0
	_idle_hint.offset_top = -36.0
	_idle_hint.offset_bottom = -12.0


func _make_button(text: String, group: ButtonGroup, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	if group:
		btn.button_group = group
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", UI_BROWN)
	btn.add_theme_color_override("font_pressed_color", Color("a83a5c"))
	btn.add_theme_color_override("font_hover_color", UI_BROWN)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.35)
	bsb.set_corner_radius_all(10)
	bsb.content_margin_left = 10.0
	bsb.content_margin_right = 10.0
	btn.add_theme_stylebox_override("normal", bsb)
	btn.add_theme_stylebox_override("hover", bsb)
	var psb := bsb.duplicate() as StyleBoxFlat
	psb.bg_color = Color(0.96, 0.72, 0.8, 0.85)
	btn.add_theme_stylebox_override("pressed", psb)
	btn.add_theme_stylebox_override("hover_pressed", psb)
	return btn


func _on_cat_pressed(cat: int) -> void:
	if cat == _cat:
		return
	_set_demolish(false)  # cambiare categoria esce dalla demolizione
	_cat = cat
	_rebuild_item_row()
	# seleziona il primo pezzo SBLOCCATO della categoria (se ce n'è)
	var cat_items := _cat_item_indices(cat)
	var pick := -1
	for ci in cat_items:
		if is_unlocked(str(_items[ci]["name"])):
			pick = ci
			break
	if pick >= 0:
		_index = pick
		_refresh_ghost()
	_sync_ui_selection()
	if _sfx: _sfx.ui_select()


func _rebuild_item_row() -> void:
	for btn in _item_buttons:
		btn.queue_free()
	_item_buttons.clear()
	var group := ButtonGroup.new()
	var cat_items := _cat_item_indices(_cat)
	for j in cat_items.size():
		var i := cat_items[j]
		var piece := str(_items[i]["name"])
		var locked := not is_unlocked(piece)
		# Due lucchetti diversi meritano due promesse diverse.
		#   · Ordini del Gufo: restano un "?" grigio, come i ricordi non ancora
		#     vissuti del Guardaroba — lì la rivelazione È il premio.
		#   · Mercante: sono MERCE IN VETRINA, non un segreto. Si mostrano col
		#     nome e col prezzo, così sai per cosa stai risparmiando. (Prima
		#     erano "?" con la didascalia del Gufo: un Ordine che per loro non
		#     sarebbe mai arrivato, perché si comprano e basta.)
		var offer := _shop_offer(piece) if locked else {}
		var in_vetrina := not offer.is_empty()
		# `piece` è la chiave del salvataggio: si traduce solo l'etichetta
		var label: String
		if in_vetrina:
			label = "%s · %d" % [L10n.t(piece), int(offer.get("cost", 0))]
		elif locked:
			label = "?"
		else:
			label = str(j + 1) + " " + L10n.t(piece)
		var btn := _make_button(label, group, 13)
		btn.custom_minimum_size = Vector2(0, 38)
		if locked:
			btn.disabled = true
			if in_vetrina:
				# leggibile, non spenta: si vede cosa ti aspetta al carretto.
				# Il prezzo prende il colore della sua valuta, come nel negozio.
				btn.modulate = Color(1, 1, 1, 0.88)
				btn.add_theme_color_override("font_disabled_color",
						CozyUI.NUT if str(offer.get("cur", "nut")) == "nut" \
						else CozyUI.HONEY.darkened(0.1))
				btn.set_meta("shop_offer", offer)
				btn.tooltip_text = _shop_tooltip(offer)
			else:
				btn.modulate = Color(1, 1, 1, 0.5)
				# Il Gufo non porta i compagni di corredo: quelli arrivano
				# tutti insieme al pezzo che si compra al carretto. Dirgli
				# «lo porterà un Ordine» era una promessa falsa — un Ordine
				# per loro non arriva mai.
				var padrone := _padrone_corredo(piece)
				if padrone.is_empty():
					btn.tooltip_text = L10n.t("Un Ordine del Gufo lo porterà")
				else:
					btn.tooltip_text = L10n.tf("Arriva col corredo di %s",
							[L10n.t(padrone)])
		else:
			btn.pressed.connect(_select.bind(i))
		_items_row.add_child(btn)
		_item_buttons.append(btn)


# ============================================================ economia colori
# Le varianti di colore comprate al mercante: qui si tinge il fantasma e il
# pezzo piazzato, si sceglie il colore con una barra di campioni, e la tinta
# per-pezzo viaggia nel salvataggio (chiave "variants", additiva: i vecchi
# salvataggi e l'altra progressione non ne sanno nulla).

func _economy() -> Node:
	if _eco == null or not is_instance_valid(_eco):
		_eco = get_tree().get_first_node_in_group("economy")
	return _eco


## Il pezzo da negozio che porta con sé questo compagno di corredo ("" se il
## pezzo non fa parte di nessun corredo). La tabella è UNA sola —
## `Economy.CORREDO` — e qui si LEGGE dalla sua fonte, non si ricopia: un
## corredo nuovo (o un compagno in più) funziona da solo, senza toccare
## niente qui dentro. Si legge dalla mappa delle costanti dello script
## perché `_eco` è un `Node` non tipizzato (l'autoload dell'economia si
## risolve a runtime) e la costante non è raggiungibile per nome.
var _compagni_corredo := {}
var _corredo_letto := false


func _padrone_corredo(piece: String) -> String:
	if not _corredo_letto:
		var eco := _economy()
		if eco == null:
			return ""      # economia non ancora in scena: si riproverà
		var sc := eco.get_script() as GDScript
		if sc == null:
			return ""
		var tabella: Variant = sc.get_script_constant_map().get("CORREDO")
		if tabella is Dictionary:
			for capo in (tabella as Dictionary):
				for compagno in (tabella as Dictionary)[capo]:
					_compagni_corredo[str(compagno)] = str(capo)
		_corredo_letto = true
	return str(_compagni_corredo.get(piece, ""))


## L'offerta del mercante per un pezzo, o {} se non è merce da negozio.
## Serve al catalogo per distinguere «lo porterà il Gufo» da «si compra».
func _shop_offer(piece: String) -> Dictionary:
	var eco := _economy()
	if eco == null or not eco.has_method("piece_offer"):
		return {}
	return eco.piece_offer(piece)


## La didascalia della vetrina: dove si compra, quanto costa, cos'è — e se
## oggi te lo puoi permettere (il borsellino lo sa già).
func _shop_tooltip(offer: Dictionary) -> String:
	var cur := str(offer.get("cur", "nut"))
	var soldi := L10n.t("noccioline") if cur == "nut" else L10n.t("stelline")
	var cost := int(offer.get("cost", 0))
	var txt := L10n.tf("Dal carretto del mercante · %d %s", [cost, soldi])
	var desc := str(offer.get("desc", ""))
	if desc != "":
		txt += "\n%s" % L10n.t(desc)
	var eco := _economy()
	if eco and eco.has_method("can_afford"):
		txt += "\n%s" % (L10n.t("Puoi permettertelo!") if eco.can_afford(cost, cur) \
				else L10n.t("Mettine da parte ancora un po'."))
	return txt


func _hook_economy() -> void:
	var eco := _economy()
	if eco and eco.has_signal("shop_changed") and not eco.shop_changed.is_connected(_on_shop_changed):
		eco.shop_changed.connect(_on_shop_changed)
	# il borsellino cambia -> le didascalie della vetrina si riallineano:
	# «puoi permettertelo» non deve mai restare a mentire
	if eco:
		for sig in ["nuts_changed", "stars_changed"]:
			if eco.has_signal(sig) and not eco.is_connected(sig, _on_wallet_changed):
				eco.connect(sig, _on_wallet_changed)
	# recupera lo stato caricato dopo _load_village: i pezzi già comprati
	# devono comparire nel catalogo (la riga era stata costruita con eco vuota)
	_on_shop_changed()


# il gruzzolo è cambiato: solo le didascalie, niente ricostruzioni
func _on_wallet_changed(_total: int) -> void:
	for btn in _item_buttons:
		if is_instance_valid(btn) and btn.has_meta("shop_offer"):
			btn.tooltip_text = _shop_tooltip(btn.get_meta("shop_offer"))


# comprato qualcosa: rinfresca la fila dei pezzi (nuovi sblocchi) e i colori
func _on_shop_changed() -> void:
	if not _item_buttons.is_empty():
		_rebuild_item_row()
		_sync_ui_selection()
	_update_variant_bar()


func _apply_ghost_variant() -> void:
	if _ghost == null or _variant == "":
		return
	var eco := _economy()
	if eco and eco.piece_takes_variant(str(_items[_index]["name"])):
		eco.apply_variant(_ghost, _variant)


# la variante valida per il pezzo corrente ("" se non è tingibile)
func _variant_for_current() -> String:
	var eco := _economy()
	if eco and eco.piece_takes_variant(str(_items[_index]["name"])):
		return _variant
	return ""


# ------------------------------------------------------- barra dei colori
func _build_variant_bar() -> void:
	if _ui == null:
		return
	var dock := CenterContainer.new()
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -214.0
	dock.offset_bottom = -180.0
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dock)
	_variant_bar = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.94)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	_variant_bar.add_theme_stylebox_override("panel", sb)
	_variant_bar.visible = false
	dock.add_child(_variant_bar)
	_variant_row = HBoxContainer.new()
	_variant_row.add_theme_constant_override("separation", 6)
	_variant_bar.add_child(_variant_row)


func _update_variant_bar() -> void:
	if _variant_bar == null or _variant_row == null:
		return
	var eco := _economy()
	var piece: String = str(_items[_index]["name"]) if _index < _items.size() else ""
	var takes: bool = eco != null and eco.piece_takes_variant(piece)
	var owned: Array = eco.owned_variants() if eco else []
	if not (_active and takes and not owned.is_empty()):
		_variant_bar.visible = false
		return
	# se il colore scelto non è (più) posseduto, torna all'originale
	if _variant != "" and not owned.has(_variant):
		_variant = ""
	for c in _variant_row.get_children():
		c.queue_free()
	_variant_row.add_child(_variant_swatch("", Color("efe0c6"), L10n.t("Originale")))
	for vid in owned:
		var def: Dictionary = eco.variant_def(vid)
		_variant_row.add_child(_variant_swatch(str(vid), def.get("tint", Color.WHITE), L10n.t(str(def.get("label", vid)))))
	_variant_bar.visible = true


func _variant_swatch(vid: String, color: Color, label: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(30, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = label
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(15)
	var on := _variant == vid
	sb.border_color = Color("6a4a3a") if on else Color(0.62, 0.46, 0.34, 0.35)
	sb.set_border_width_all(3 if on else 1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(_pick_variant.bind(vid))
	return b


func _pick_variant(vid: String) -> void:
	_variant = vid
	if _sfx: _sfx.ui_select()
	_refresh_ghost()


# ------------------------------------------------------- persistenza colori
func _pkey(lvl, layer, key: Vector2i) -> String:
	return "%d:%s:%d:%d" % [int(lvl), str(layer), key.x, key.y]


func _collect_variants() -> Dictionary:
	var out := {}
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			var dict := _dicts(lvl)[layer] as Dictionary
			for key in dict:
				var node := dict[key] as Node3D
				var v := str(node.get_meta("variant", ""))
				if v != "":
					out[_pkey(lvl, layer, key)] = v
	return out
