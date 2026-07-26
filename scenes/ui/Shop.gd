extends Node

## Il carretto del mercante 🌰⭐ — il negozio del villaggio.
##
## Si apre con E davanti al mercante (lo chiama Calendar._merchant_trade).
## Due scaffali:
##   VENDI  — farfalle, pesci e raccolti diventano noccioline.
##   COMPRA — mobili nuovi (noccioline/stelline) e varianti di colore.
##
## Congela solo Mochi (come il calendario/la cucina), non tutto il mondo, così
## resta un'interazione cozy in mezzo alla piazza. UI col kit CozyUI.

var _ui: CanvasLayer
var _backdrop: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _nut_lbl: Label
var _star_lbl: Label
var _tab := "vendi"
var _tab_group: ButtonGroup

var _player: Node3D
var _economy: Node
var _collection: Node
var _cooking: Node
var _sfx
var _open := false


func _ready() -> void:
	add_to_group("shop")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func() -> void:
		# %Player non si risolve dai nodi creati a runtime (owner null): gruppo
		_player = get_tree().get_first_node_in_group("player_controller")
		_economy = get_tree().get_first_node_in_group("economy")
		_collection = get_node_or_null("../Collection")
		_cooking = get_node_or_null("../Cooking")
		if _economy:
			_economy.nuts_changed.connect(func(_t): _refresh_wallet())
			_economy.stars_changed.connect(func(_t): _refresh_wallet())
	).call_deferred()


func is_open() -> bool:
	return _open


## Apre il negozio (chiamato dal mercante). `_merchant` è solo di contesto.
func open(_merchant: Node = null) -> void:
	if _open or _economy == null:
		return
	_open = true
	if _player and _player.has_method("set_physics_process"):
		_player.set_physics_process(false)
		_player.set("velocity", Vector3.ZERO)
	_ui.visible = true
	_refresh_wallet()
	_show_tab(_tab)
	CozyUI.fade_to(_backdrop, 0.42, 0.28)
	CozyUI.appear(_panel, 0.34)
	if _sfx: _sfx.build_open()


func close() -> void:
	if not _open:
		return
	_open = false
	if _player and _player.has_method("set_physics_process"):
		_player.set_physics_process(true)
	CozyUI.fade_to(_backdrop, 0.0, 0.22)
	CozyUI.dismiss(_panel, _hide_ui, 0.2)
	if _sfx: _sfx.build_close()


func _hide_ui() -> void:
	_ui.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


# ================================================================ UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 6
	_ui.visible = false
	add_child(_ui)

	_backdrop = CozyUI.backdrop()
	_backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	_ui.add_child(_backdrop)

	_ui.add_child(CozyUI.petals(18))

	var center := CozyUI.center_root()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	_panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	# --- intestazione: titolo + borsellino ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)

	var title := CozyUI.title_label("Il carretto del mercante", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	header.add_child(_wallet_chip("nut"))
	_nut_lbl = _chip_label()
	header.add_child(_nut_lbl)
	header.add_child(_wallet_chip("star"))
	_star_lbl = _chip_label()
	header.add_child(_star_lbl)

	# --- linguette ---
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(tabs)
	_tab_group = ButtonGroup.new()
	var vendi := CozyUI.tab_button("Vendi", _tab_group, CozyUI.MINT)
	vendi.set_pressed_no_signal(true)
	vendi.pressed.connect(func(): _show_tab("vendi"))
	tabs.add_child(vendi)
	var compra := CozyUI.tab_button("Compra", _tab_group, CozyUI.PINK)
	compra.pressed.connect(func(): _show_tab("compra"))
	tabs.add_child(compra)

	# --- contenuto scorrevole ---
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(640, 400)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	col.add_child(CozyUI.hint_label("E o Esc — chiudi il carretto", 13))


func _wallet_chip(kind: String) -> CozyIcon:
	return CozyUI.icon(kind, 24)


func _chip_label() -> Label:
	var l := Label.new()
	l.text = "0"
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", CozyUI.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(38, 0)
	return l


func _refresh_wallet() -> void:
	if _economy == null:
		return
	if _nut_lbl: _nut_lbl.text = str(_economy.nuts)
	if _star_lbl: _star_lbl.text = str(_economy.stars)


func _show_tab(which: String) -> void:
	_tab = which
	for c in _content.get_children():
		c.queue_free()
	if which == "vendi":
		_build_sell()
	else:
		_build_buy()


# ---------------------------------------------------------------- VENDI
func _build_sell() -> void:
	var rows := _sellables()
	if rows.is_empty():
		_content.add_child(_empty_note(
			"La bisaccia è vuota.\nAcchiappa farfalle e pesci, coltiva l'orto,\npoi torna a vendere!"))
		return
	_content.add_child(_section("La tua bisaccia"))
	var total := 0
	for r in rows:
		total += int(r["count"]) * int(r["value"])
		_content.add_child(_sell_row(r))
	var foot := CozyUI.hint_label("Vendendo tutto: %d noccioline" % total, 14)
	_content.add_child(foot)


func _sellables() -> Array:
	var out := []
	if _collection and _collection.has_method("owned_kinds"):
		for k in _collection.owned_kinds():
			out.append({"kind": k, "count": int(_collection.count_of(k)),
				"value": _economy.sell_value(k), "source": "critter"})
	if _cooking:
		var pantry: Dictionary = _cooking.get("pantry")
		if pantry:
			for k in pantry:
				if int(pantry[k]) > 0:
					out.append({"kind": k, "count": int(pantry[k]),
						"value": _economy.sell_value(k), "source": "pantry"})
	return out


func _sell_row(r: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyUI.soft_card())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)

	h.add_child(_dot(_economy.kind_color(r["kind"])))
	var lbl := CozyUI.body_label("%s  ×%d" % [_economy.label_for(r["kind"]), r["count"]], 17)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lbl)

	h.add_child(_price_chip(int(r["value"]), "nut", "cad."))

	var one := CozyUI.cozy_button("Vendi 1", CozyUI.MINT, 15)
	one.custom_minimum_size = Vector2(96, 44)
	one.pressed.connect(_sell.bind(r["kind"], r["source"], 1))
	h.add_child(one)

	var all := CozyUI.cozy_button("Tutti", CozyUI.HONEY, 15)
	all.custom_minimum_size = Vector2(88, 44)
	all.pressed.connect(_sell.bind(r["kind"], r["source"], int(r["count"])))
	h.add_child(all)
	return card


func _sell(kind: String, source: String, n: int) -> void:
	if n <= 0 or _economy == null:
		return
	var have := 0
	if source == "critter" and _collection:
		have = int(_collection.count_of(kind))
	elif source == "pantry" and _cooking:
		have = int((_cooking.get("pantry") as Dictionary).get(kind, 0))
	n = mini(n, have)
	if n <= 0:
		return
	if source == "critter" and _collection:
		_collection.remove_catch(kind, n)
	elif source == "pantry" and _cooking:
		_cooking.add_ingredient(kind, -n)
	_economy.add_nuts(_economy.sell_value(kind) * n)
	if _sfx: _sfx.place_ok()
	_show_tab("vendi")


# ---------------------------------------------------------------- COMPRA
func _build_buy() -> void:
	# mobili nuovi
	_content.add_child(_section("Mobili nuovi"))
	var any_piece := false
	for offer in _economy.SHOP_PIECES:
		if _economy.is_piece_unlocked(offer["name"]):
			continue
		any_piece = true
		_content.add_child(_piece_row(offer))
	if not any_piece:
		_content.add_child(CozyUI.hint_label("Hai già tutti i mobili del carretto!", 14))

	# varianti di colore
	_content.add_child(_section("Colori dei mobili"))
	var any_col := false
	for v in _economy.VARIANTS:
		if _economy.is_variant_unlocked(v["id"]):
			continue
		any_col = true
		_content.add_child(_variant_row(v))
	if not any_col:
		_content.add_child(CozyUI.hint_label("Hai già tutti i colori!", 14))
	_content.add_child(CozyUI.hint_label(
		"I colori tingono i mobili: in costruzione scegli la tinta dai campioni.", 13))


func _piece_row(offer: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyUI.soft_card())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	col.add_child(CozyUI.body_label(str(offer["name"]), 18, CozyUI.TITLE))
	col.add_child(CozyUI.body_label(str(offer.get("desc", "")), 13, CozyUI.INK_SOFT))

	var cur := str(offer.get("cur", "nut"))
	h.add_child(_price_chip(int(offer["cost"]), cur, ""))
	h.add_child(_buy_button(int(offer["cost"]), cur, _buy_piece.bind(offer)))
	return card


func _variant_row(v: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyUI.soft_card())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)

	h.add_child(_dot(v.get("tint", CozyUI.PINK), 30))
	var lbl := CozyUI.body_label(str(v["label"]), 18, CozyUI.TITLE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lbl)

	var cur := str(v.get("cur", "nut"))
	h.add_child(_price_chip(int(v["cost"]), cur, ""))
	h.add_child(_buy_button(int(v["cost"]), cur, _buy_variant.bind(v)))
	return card


func _buy_piece(offer: Dictionary) -> void:
	if _economy.spend(int(offer["cost"]), str(offer.get("cur", "nut"))):
		_economy.unlock_piece(str(offer["name"]))
		if _sfx: _sfx.place_ok()
	else:
		if _sfx: _sfx.place_deny()
	_show_tab("compra")


func _buy_variant(v: Dictionary) -> void:
	if _economy.spend(int(v["cost"]), str(v.get("cur", "nut"))):
		_economy.unlock_variant(str(v["id"]))
		if _sfx: _sfx.place_ok()
	else:
		if _sfx: _sfx.place_deny()
	_show_tab("compra")


func _buy_button(cost: int, cur: String, cb: Callable) -> Button:
	var afford: bool = _economy.can_afford(cost, cur)
	var b := CozyUI.cozy_button("Compra", CozyUI.PINK if afford else CozyUI.DANGER, 15)
	b.custom_minimum_size = Vector2(110, 44)
	b.disabled = not afford
	if afford:
		b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- pezzetti
func _section(text: String) -> Label:
	var l := CozyUI.body_label(text, 20, CozyUI.TITLE)
	return l


func _dot(color: Color, px := 26) -> Control:
	var dot := _RoundDot.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(px, px)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


func _price_chip(cost: int, cur: String, suffix: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(CozyUI.icon(cur, 22))
	var l := CozyUI.body_label(str(cost) + ("  " + suffix if suffix != "" else ""), 17,
		CozyUI.NUT if cur == "nut" else CozyUI.HONEY.darkened(0.1))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


func _empty_note(text: String) -> Control:
	var l := CozyUI.body_label(text, 16, CozyUI.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 120)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


# un pallino tondo disegnato (colore-spia delle merci)
class _RoundDot extends Control:
	var color := Color.WHITE
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, color)
		draw_arc(size * 0.5, r - 1.0, 0.0, TAU, 24, Color(0.4, 0.3, 0.24, 0.5), 1.5, true)
