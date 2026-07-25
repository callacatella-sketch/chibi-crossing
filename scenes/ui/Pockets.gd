extends Node

## Le Tasche — la vetrina delle cose di Mochi, e il gesto del regalo.
## Tab (o E vicino a un amico) apre un taccuino di carta con quattro
## segnalibri: Dispensa (orto e bosco), Cucina (le porzioni avanzate),
## Tesori (i doni del bosco) e Collezione (farfalle e pesci, in mostra).
## Finalmente si vede COSA si ha e QUANTO — e, vicino a un amico, si sceglie
## COSA regalargli: gli oggetti che adorerebbe si accendono di un cuoricino.
##
## Il modello-dati (piatti, tesori, affinità) è in Inventory.gd; qui c'è solo
## la vista e la navigazione. Segue l'idioma dei menu del gioco: mette in pausa
## il player, si chiude con Tab/Esc, e non si apre se un altro menu ha già la
## scena (guardia is_physics_processing).

const ICON := preload("res://scenes/ui/PocketIcon.gd")
const INV := preload("res://scenes/ui/Inventory.gd")

const UI_BROWN := Color("6a4a3a")
const UI_BROWN2 := Color("8a5a3a")
const PAPER := Color("fdf6e3")
const EDGE := Color(0.62, 0.46, 0.34, 0.5)
const PINK := Color("c25a7a")

# --- schede degli ingredienti (la dispensa vive in Cooking, qui la si mostra) ---
const INGREDIENTS := {
	"carota": {"name": "Carota", "icon": "carota", "src": "dall'orto",
		"desc": "Croccante e dolce. La base di zuppe che scaldano."},
	"zucca": {"name": "Zucca", "icon": "zucca", "src": "dall'orto",
		"desc": "Panciuta e vellutata. Il cuore dell'autunno."},
	"bacca": {"name": "Bacche", "icon": "bacca", "src": "dai cespugli",
		"desc": "Violacee e succose. Dolci da crumble."},
	"fungo": {"name": "Funghi", "icon": "fungo", "src": "dal bosco",
		"desc": "Profumo di sottobosco. Perfetti nel risotto."},
}
const ING_ORDER := ["carota", "zucca", "bacca", "fungo"]

# nome leggibile delle etichette di gusto (per i chip nel dettaglio)
const TAG_LABEL := {"caldo": "Caldo", "fresco": "Fresco", "dolce": "Dolce",
	"terroso": "Terroso", "morbido": "Morbido", "floreale": "Floreale",
	"orto": "Orto", "bosco": "Bosco"}

const TABS := [
	{"id": "dispensa", "name": "Dispensa", "sub": "orto e bosco"},
	{"id": "cucina", "name": "Cucina", "sub": "porzioni avanzate"},
	{"id": "tesori", "name": "Tesori", "sub": "doni del bosco"},
	{"id": "collezione", "name": "Collezione", "sub": "in mostra"},
]
const GRID_COLS := 4
const GRID_SLOTS := 8   # celle sempre visibili (le vuote restano tratteggiate)

var _player: Node3D
var _inventory: Node
var _cooking: Node
var _collection: Node
var _visitors: Node
var _sfx

var _open := false
var _cur := "dispensa"
var _sel := 0
var _entries: Array[Dictionary] = []
var _gift_target: Dictionary = {}   # residente a cui regalare ({} = solo sfoglio)

# --- nodi UI ---
var _layer: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _giftbar: PanelContainer
var _gift_who: RichTextLabel
var _gift_taste: Label
var _tab_btns: Array[Button] = []
var _tab_subs: Array[Label] = []
var _grid: GridContainer
var _detail: VBoxContainer
var _footer: RichTextLabel
var _cells: Array[Button] = []
var _toast: PanelContainer
var _toast_label: Label


func _ready() -> void:
	_player = get_node("%Player")
	_sfx = get_node_or_null(^"/root/Sfx")
	(func():
		_inventory = get_node_or_null("../Inventory")
		_cooking = get_node_or_null("../Cooking")
		_collection = get_node_or_null("../Collection")
		_visitors = get_node_or_null("../Visitors")).call_deferred()
	_build_ui()


func is_open() -> bool:
	return _open


# ---------------------------------------------------------------- apertura

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed("tasche"):
			toggle()
			get_viewport().set_input_as_handled()
		return

	# --- col taccuino aperto la tastiera è tutta sua (modale) ---
	if event.is_action_pressed("tasche") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_move_sel(-1)
	elif event.is_action_pressed("ui_right"):
		_move_sel(1)
	elif event.is_action_pressed("ui_up"):
		_move_sel(-GRID_COLS)
	elif event.is_action_pressed("ui_down"):
		_move_sel(GRID_COLS)
	elif event.is_action_pressed("interact"):
		_confirm()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).is_echo():
		var kc: int = (event as InputEventKey).keycode
		if kc >= KEY_1 and kc <= KEY_4:
			_select_tab(TABS[kc - KEY_1]["id"])
		# comunque: da qui in poi nessun tasto sfugge ad altri menu
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


## Chiamata dai Visitors quando premi E accanto a un amico: apre già in
## modalità regalo su quel residente.
func open_for_gift(resident: Dictionary) -> void:
	if _open:
		return
	_do_open(resident)


func toggle() -> void:
	if _open:
		_close()
	else:
		_do_open(_auto_target())


# il residente più vicino a cui potresti regalare qualcosa, o {}
func _auto_target() -> Dictionary:
	if _visitors == null or _inventory == null or not _inventory.has_giftable():
		return {}
	if _visitors.has_method("nearest_giftable_resident"):
		return _visitors.nearest_giftable_resident(_player.global_position, 2.0)
	return {}


func _do_open(target: Dictionary) -> void:
	# non rubare la scena a un altro menu (cucina, onsen, guardaroba…)
	if not _player.is_physics_processing():
		return
	_open = true
	_gift_target = target
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	# in regalo si parte dalla pagina con qualcosa da dare
	if not _gift_target.is_empty():
		_cur = "cucina" if (_inventory and not _inventory.dishes.is_empty()) else "tesori"
	_sel = 0
	_refresh()
	_panel.visible = true
	if _sfx:
		_sfx.build_open()


func _close() -> void:
	_open = false
	_panel.visible = false
	_gift_target = {}
	if not _player.is_physics_processing():
		_player.set_physics_process(true)
	if _sfx:
		_sfx.build_close()


# ---------------------------------------------------------------- dati

func _select_tab(id: String) -> void:
	if id == _cur:
		return
	_cur = id
	_sel = 0
	if _sfx:
		_sfx.ui_select()
	_refresh()


func _move_sel(step: int) -> void:
	if _entries.is_empty():
		return
	_sel = clampi(_sel + step, 0, _entries.size() - 1)
	if _sfx:
		_sfx.ui_select()
	_paint_selection()
	_build_detail()


# raccoglie le voci della pagina corrente
func _gather() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match _cur:
		"dispensa":
			var pantry: Dictionary = _cooking.pantry if _cooking else {}
			for id in ING_ORDER:
				var n := int(pantry.get(id, 0))
				if n <= 0:
					continue
				var e: Dictionary = (INGREDIENTS[id] as Dictionary).duplicate()
				e["id"] = id
				e["count"] = n
				e["tags"] = INV.dish_tags(false, {id: 1})
				e["kind"] = "ingredient"
				e["giftable"] = false
				out.append(e)
		"cucina":
			if _inventory:
				for e in _inventory.dishes_grouped():
					e["src"] = "porzione avanzata"
					e["giftable"] = true
					e["desc"] = e.get("desc", "Ancora profumata. Un amico ne sarebbe felice.")
					out.append(e)
		"tesori":
			if _inventory:
				for e in _inventory.treasure_list():
					e["giftable"] = true
					out.append(e)
		"collezione":
			out = _gather_collection()
	return out


func _gather_collection() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _collection == null:
		return out
	var counts: Dictionary = _collection.counts() if _collection.has_method("counts") else {}
	var order: Array = _collection.JAR_ORDER
	var labels: Dictionary = _collection.KIND_LABEL
	var cols: Dictionary = _collection.JAR_COLORS
	var fish: Array = _collection.FISH_KINDS
	for kind in order:
		var n := int(counts.get(kind, 0))
		if n <= 0:
			continue
		var icon := "farfalla"
		if kind == "lucciola":
			icon = "lucciola"
		elif kind in fish:
			icon = "pesce"
		out.append({"id": kind, "name": str(labels.get(kind, kind)).capitalize(),
			"count": n, "icon": icon, "tint": cols.get(kind, Color.WHITE),
			"src": "nella Libreria", "kind": "collection", "giftable": false,
			"tags": [], "desc": "In un barattolo sullo scaffale. Nessuna fretta."})
	return out


# ---------------------------------------------------------------- render

func _refresh() -> void:
	_entries = _gather()
	_sel = clampi(_sel, 0, maxi(0, _entries.size() - 1))
	# segnalibri
	for i in _tab_btns.size():
		var on: bool = TABS[i]["id"] == _cur
		_style_tab(_tab_btns[i], on)
		_tab_subs[i].add_theme_color_override("font_color", Color(UI_BROWN2, 0.75 if on else 0.5))
	# barra regalo
	_giftbar.visible = not _gift_target.is_empty()
	if not _gift_target.is_empty():
		var label := str(_gift_target.get("label", "un amico"))
		_gift_who.text = "[color=#8a5a3a]Regala a[/color] [color=#c23a60]%s[/color]" % label
		_gift_taste.text = "♨ ama il calduccio" if _prefers_cozy(_gift_target) else "✿ ama l'orto"
	_build_grid()
	_build_detail()
	_footer.text = _footer_text()


func _build_grid() -> void:
	for c in _cells:
		c.queue_free()
	_cells.clear()
	for i in maxi(GRID_SLOTS, _entries.size()):
		var cell := _make_cell(i)
		_grid.add_child(cell)
		_cells.append(cell)
	_paint_selection()


func _make_cell(i: int) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(74, 74)
	cell.focus_mode = Control.FOCUS_NONE
	cell.flat = true
	if i < _entries.size():
		cell.pressed.connect(_on_cell.bind(i))
		var e: Dictionary = _entries[i]
		var ic := ICON.new()
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 11; ic.offset_top = 9
		ic.offset_right = -11; ic.offset_bottom = -13
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_item(str(e.get("icon", "bacca")), e.get("tint", Color(0, 0, 0, 0)))
		cell.add_child(ic)
		# quantità
		if int(e.get("count", 1)) > 0:
			var q := Label.new()
			q.text = "×%d" % int(e.get("count", 1))
			q.add_theme_font_size_override("font_size", 13)
			q.add_theme_color_override("font_color", Color("fff6e6"))
			var qs := StyleBoxFlat.new()
			qs.bg_color = UI_BROWN2
			qs.set_corner_radius_all(9)
			qs.content_margin_left = 5; qs.content_margin_right = 5
			qs.content_margin_top = 1; qs.content_margin_bottom = 1
			q.add_theme_stylebox_override("normal", qs)
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			q.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			q.offset_left = -30; q.offset_top = -24
			q.offset_right = -2; q.offset_bottom = -2
			cell.add_child(q)
		# cuoricino: lo adorerebbe (solo in regalo, sugli oggetti regalabili)
		if _loves(e):
			var h := Label.new()
			h.text = "♥"
			h.add_theme_font_size_override("font_size", 15)
			h.add_theme_color_override("font_color", Color("d4537e"))
			var hs := StyleBoxFlat.new()
			hs.bg_color = Color("ffe3ec")
			hs.set_corner_radius_all(11)
			hs.set_border_width_all(2)
			hs.border_color = PAPER
			hs.content_margin_left = 4; hs.content_margin_right = 4
			h.add_theme_stylebox_override("normal", hs)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.set_anchors_preset(Control.PRESET_TOP_LEFT)
			h.offset_left = -4; h.offset_top = -4
			cell.add_child(h)
	return cell


func _paint_selection() -> void:
	for i in _cells.size():
		var empty := i >= _entries.size()
		var selected := i == _sel and not empty
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(15)
		if empty:
			sb.bg_color = Color(0.95, 0.9, 0.79, 0.55)
			sb.draw_center = true
			sb.set_border_width_all(2)
			sb.border_color = Color(EDGE, 0.5)
		else:
			sb.bg_color = Color("f6ead0")
			sb.set_border_width_all(2)
			sb.border_color = EDGE
		if selected:
			sb.border_color = PINK
			sb.set_border_width_all(3)
			sb.shadow_color = Color(0.85, 0.4, 0.5, 0.35)
			sb.shadow_size = 6
		for st in ["normal", "hover", "pressed", "focus"]:
			_cells[i].add_theme_stylebox_override(st, sb)


func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = "Le tasche sono leggere:\nl'orto e il bosco ti aspettano."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(UI_BROWN, 0.7))
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_detail.add_child(empty)
		return
	var e: Dictionary = _entries[_sel]

	var big := ICON.new()
	big.custom_minimum_size = Vector2(96, 96)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	big.set_item(str(e.get("icon", "bacca")), e.get("tint", Color(0, 0, 0, 0)))
	_detail.add_child(big)

	var name_l := Label.new()
	name_l.text = str(e.get("name", "?"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", UI_BROWN2)
	_detail.add_child(name_l)

	var src := str(e.get("src", ""))
	if int(e.get("count", 1)) > 1:
		src += " · ne hai %d" % int(e["count"])
	var src_l := Label.new()
	src_l.text = src
	src_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	src_l.add_theme_font_size_override("font_size", 11)
	src_l.add_theme_color_override("font_color", Color("a98a55"))
	_detail.add_child(src_l)

	var desc := Label.new()
	desc.text = str(e.get("desc", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UI_BROWN)
	_detail.add_child(desc)

	# chip di gusto
	var tags: Array = e.get("tags", [])
	if not tags.is_empty():
		var chips := HBoxContainer.new()
		chips.alignment = BoxContainer.ALIGNMENT_CENTER
		chips.add_theme_constant_override("separation", 5)
		for tag in tags:
			if not TAG_LABEL.has(tag):
				continue
			var chip := Label.new()
			chip.text = TAG_LABEL[tag]
			chip.add_theme_font_size_override("font_size", 11)
			chip.add_theme_color_override("font_color", UI_BROWN2)
			var cs := StyleBoxFlat.new()
			cs.bg_color = Color("f3e6c6")
			cs.set_corner_radius_all(10)
			cs.set_border_width_all(1)
			cs.border_color = EDGE
			cs.content_margin_left = 8; cs.content_margin_right = 8
			cs.content_margin_top = 2; cs.content_margin_bottom = 2
			chip.add_theme_stylebox_override("normal", cs)
			chips.add_child(chip)
		_detail.add_child(chips)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)

	var cta := Label.new()
	cta.text = _cta_text(e)
	cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cta.add_theme_font_size_override("font_size", 12)
	var cs2 := StyleBoxFlat.new()
	cs2.set_corner_radius_all(11)
	cs2.content_margin_left = 10; cs2.content_margin_right = 10
	cs2.content_margin_top = 8; cs2.content_margin_bottom = 8
	var giftable := bool(e.get("giftable", false))
	if not _gift_target.is_empty() and giftable:
		cs2.bg_color = Color("ffcfe0")
		cs2.border_color = Color("e79bb0")
		cta.add_theme_color_override("font_color", Color("9a3a58"))
	elif giftable or str(e.get("kind", "")) == "ingredient":
		cs2.bg_color = Color("ffe6a8")
		cs2.border_color = Color("e9c46a")
		cta.add_theme_color_override("font_color", Color("8a5a2a"))
	else:
		cs2.bg_color = Color("f3e6c6")
		cs2.border_color = EDGE
		cta.add_theme_color_override("font_color", UI_BROWN2)
	cs2.set_border_width_all(2)
	cta.add_theme_stylebox_override("normal", cs2)
	_detail.add_child(cta)


func _cta_text(e: Dictionary) -> String:
	var giftable := bool(e.get("giftable", false))
	if not _gift_target.is_empty() and giftable:
		return "E — regala (la adorerà! ♥)" if _loves(e) else "E — regala"
	match str(e.get("kind", "")):
		"ingredient":
			return "Cucina al camino per usarla"
		"dish", "treasure":
			return "Avvicìnati a un amico per regalarlo"
		"collection":
			return "In mostra sugli scaffali"
	return ""


# ---------------------------------------------------------------- azione

func _on_cell(i: int) -> void:
	if i == _sel:
		_confirm()
		return
	_sel = i
	if _sfx:
		_sfx.ui_select()
	_paint_selection()
	_build_detail()


func _confirm() -> void:
	if _entries.is_empty():
		return
	var e: Dictionary = _entries[_sel]
	var giftable := bool(e.get("giftable", false))
	if not _gift_target.is_empty() and giftable:
		_give(e)
		return
	# fuori regalo (o oggetto non regalabile): un suggerimento gentile
	match str(e.get("kind", "")):
		"ingredient":
			_show_toast("Portala al camino: E apre il ricettario.")
		"dish", "treasure":
			_show_toast("Avvicìnati a un amico e riapri le tasche per regalarlo.")
		"collection":
			_show_toast("È già in mostra sugli scaffali della Libreria.")
	if _sfx:
		_sfx.ui_select()


func _give(e: Dictionary) -> void:
	if _inventory == null or _visitors == null:
		return
	var item: Dictionary = _inventory.take_gift(e)
	if item.is_empty():
		return
	var target := _gift_target
	_close()
	if _visitors.has_method("offer_item"):
		_visitors.offer_item(target, item)


# ---------------------------------------------------------------- gusto

func _prefers_cozy(r: Dictionary) -> bool:
	var w: Dictionary = (r.get("dna", {}) as Dictionary).get("weights", {})
	return float(w.get("warmth", 0.5)) + 0.5 * float(w.get("comfort", 0.5)) \
			>= float(w.get("garden", 0.5))


func _loves(e: Dictionary) -> bool:
	if _gift_target.is_empty() or not bool(e.get("giftable", false)) or _inventory == null:
		return false
	var w: Dictionary = (_gift_target.get("dna", {}) as Dictionary).get("weights", {})
	return _inventory.affinity(e.get("tags", []), w) == INV.REACT_LOVES


# ---------------------------------------------------------------- costruzione UI

func _footer_text() -> String:
	var act := "regala a %s" % str(_gift_target.get("label", "")) if not _gift_target.is_empty() \
			else "usa / cucina"
	return "[center][color=#9a7a52]1–4 pagine   ·   ↑↓←→ scorri   ·   E %s   ·   Tab chiudi[/color][/center]" % act


func _sb(bg: Color, border: Color, radius: int, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	return sb


func _style_tab(btn: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf5") if on else Color("f0e0b8")
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_color = EDGE
	sb.border_width_left = 2; sb.border_width_right = 2; sb.border_width_top = 2
	sb.border_width_bottom = 0
	sb.content_margin_left = 4; sb.content_margin_right = 4
	sb.content_margin_top = 8; sb.content_margin_bottom = 6
	if on:
		sb.shadow_color = Color(0.91, 0.77, 0.42, 0.35)
		sb.shadow_size = 4
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, sb)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)

	_panel = PanelContainer.new()
	var ps := _sb(PAPER, EDGE, 20, 2)
	ps.shadow_color = Color(0.29, 0.18, 0.13, 0.32)
	ps.shadow_size = 16
	ps.content_margin_left = 22; ps.content_margin_right = 22
	ps.content_margin_top = 16; ps.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.visible = false
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	_title = Label.new()
	_title.text = "✿   Le tasche   ✿"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", UI_BROWN2)
	col.add_child(_title)

	_build_giftbar(col)
	_build_tabs(col)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_grid)

	var det_panel := PanelContainer.new()
	det_panel.add_theme_stylebox_override("panel", _sb(Color("fffdf5"), EDGE, 15, 2))
	det_panel.custom_minimum_size = Vector2(222, 330)
	body.add_child(det_panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	var dm := MarginContainer.new()
	dm.add_theme_constant_override("margin_left", 12)
	dm.add_theme_constant_override("margin_right", 12)
	dm.add_theme_constant_override("margin_top", 12)
	dm.add_theme_constant_override("margin_bottom", 12)
	det_panel.add_child(dm)
	dm.add_child(_detail)

	_footer = RichTextLabel.new()
	_footer.bbcode_enabled = true
	_footer.fit_content = true
	_footer.scroll_active = false
	_footer.add_theme_font_size_override("normal_font_size", 12)
	_footer.custom_minimum_size = Vector2(0, 20)
	col.add_child(_footer)

	_build_toast()


func _build_giftbar(col: VBoxContainer) -> void:
	_giftbar = PanelContainer.new()
	var gs := _sb(Color("ffdce8"), Color("f0a8c2"), 13, 2)
	gs.content_margin_left = 14; gs.content_margin_right = 14
	gs.content_margin_top = 8; gs.content_margin_bottom = 8
	_giftbar.add_theme_stylebox_override("panel", gs)
	_giftbar.visible = false
	col.add_child(_giftbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_giftbar.add_child(row)
	var box := ICON.new()
	box.custom_minimum_size = Vector2(26, 26)
	box.set_item("fiocco")
	row.add_child(box)
	_gift_who = RichTextLabel.new()
	_gift_who.bbcode_enabled = true
	_gift_who.fit_content = true
	_gift_who.scroll_active = false
	_gift_who.add_theme_font_size_override("normal_font_size", 14)
	_gift_who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_gift_who)
	_gift_taste = Label.new()
	_gift_taste.add_theme_font_size_override("font_size", 12)
	_gift_taste.add_theme_color_override("font_color", UI_BROWN2)
	var ts := _sb(Color("fff3e0"), EDGE, 20, 1)
	ts.content_margin_left = 11; ts.content_margin_right = 11
	ts.content_margin_top = 3; ts.content_margin_bottom = 3
	_gift_taste.add_theme_stylebox_override("normal", ts)
	row.add_child(_gift_taste)


func _build_tabs(col: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for i in TABS.size():
		var t: Dictionary = TABS[i]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 0)
		var nm := Label.new()
		nm.text = t["name"]
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", UI_BROWN2)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nm)
		var sub := Label.new()
		sub.text = t["sub"]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", Color(UI_BROWN2, 0.5))
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sub)
		btn.add_child(inner)
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_select_tab.bind(t["id"]))
		_style_tab(btn, t["id"] == _cur)
		tabs.add_child(btn)
		_tab_btns.append(btn)
		_tab_subs.append(sub)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	var ts := _sb(Color(0.99, 0.96, 0.9, 0.97), EDGE, 12, 2)
	ts.content_margin_left = 16; ts.content_margin_right = 16
	ts.content_margin_top = 8; ts.content_margin_bottom = 8
	_toast.add_theme_stylebox_override("panel", ts)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(0, 90)
	_layer.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_color", Color("8a5a3a"))
	_toast.add_child(_toast_label)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.modulate.a = 0.0
	_toast.visible = true
	var vp_w := get_viewport().get_visible_rect().size.x
	_toast.position = Vector2(vp_w * 0.5 - _toast.size.x * 0.5, 96)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast.visible = false)


# ---------------------------------------------------------------- debug CLI

func debug_open() -> void:
	_do_open({})


func debug_open_gift(r: Dictionary) -> void:
	_do_open(r)


func debug_close() -> void:
	_close()
