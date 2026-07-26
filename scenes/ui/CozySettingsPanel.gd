class_name CozySettingsPanel
extends PanelContainer

## Il pannello Impostazioni, condiviso tra il menu di pausa e la schermata del
## titolo. Legge e scrive l'autoload Settings; ogni modifica si applica e si
## salva all'istante. Emette `closed` quando si torna indietro.

signal closed

var _settings: Node


func _ready() -> void:
	_settings = get_node_or_null(^"/root/Settings")
	add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	custom_minimum_size = Vector2(520, 0)
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	col.add_child(CozyUI.title_label("Impostazioni", 30))
	col.add_child(_sep())

	col.add_child(_slider_row("Volume generale", "master_volume", 0.0, 1.0, 0.05,
			CozyUI.HONEY, func(v): _settings.set_master_volume(v)))
	col.add_child(_slider_row("Musica", "music_volume", 0.0, 1.0, 0.05,
			CozyUI.SKY, func(v): _settings.set_music_volume(v)))
	col.add_child(_slider_row("Effetti", "sfx_volume", 0.0, 1.0, 0.05,
			CozyUI.MINT, func(v): _settings.set_sfx_volume(v)))
	col.add_child(_sep())
	col.add_child(_slider_row("Velocità di Mochi", "move_speed", 0.6, 1.5, 0.05,
			CozyUI.PINK, func(v): _settings.set_move_speed(v)))
	col.add_child(_toggle_row("Schermo intero", "fullscreen",
			func(on): _settings.set_fullscreen(on)))
	col.add_child(_toggle_row("Riduci animazioni", "reduce_motion",
			func(on): _settings.set_reduce_motion(on)))
	# «Prato Eterno»: nessun vicino parte mai per il Grande Prato — il
	# gioco resta intero anche senza (regola cozy del Filo Rosso)
	col.add_child(_toggle_row("Prato Eterno (nessuna partenza)", "prato_eterno",
			func(on): _settings.set_prato_eterno(on)))
	if _settings and _settings.quality_available():
		col.add_child(_quality_row())

	col.add_child(_sep())
	var back := CozyUI.cozy_button("Indietro", CozyUI.PINK, 18)
	back.custom_minimum_size = Vector2(200, 52)
	back.pressed.connect(func(): closed.emit())
	var wrap := CenterContainer.new()
	wrap.add_child(back)
	col.add_child(wrap)


# ---------------------------------------------------------------- righe
func _slider_row(label: String, key: String, lo: float, hi: float, step: float,
		accent: Color, setter: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var l := CozyUI.body_label(label, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := CozyUI.body_label("", 15, CozyUI.INK_SOFT)
	head.add_child(val)
	row.add_child(head)

	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(_settings.get(key)) if _settings else hi
	s.custom_minimum_size = Vector2(0, 26)
	_style_slider(s, accent)
	var pct := func(v: float) -> String:
		return "%d%%" % roundi((v - lo) / (hi - lo) * 100.0)
	val.text = pct.call(s.value)
	s.value_changed.connect(func(v):
		val.text = pct.call(v)
		if _settings: setter.call(v))
	row.add_child(s)
	return row


func _toggle_row(label: String, key: String, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := CozyUI.body_label(label, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var cb := CheckButton.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(_settings.get(key)) if _settings else false
	cb.add_theme_color_override("font_color", CozyUI.INK)
	cb.toggled.connect(func(on):
		if _settings: setter.call(on))
	row.add_child(cb)
	return row


func _quality_row() -> Control:
	var row := HBoxContainer.new()
	var l := CozyUI.body_label("Qualità grafica", 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var g := ButtonGroup.new()
	var cur := int(_settings.get_quality()) if _settings else 0
	for i in 2:
		var b := CozyUI.tab_button("Basso" if i == 0 else "Alto", g, CozyUI.SKY)
		b.custom_minimum_size = Vector2(96, 40)
		if i == cur:
			b.set_pressed_no_signal(true)
		b.pressed.connect(func():
			if _settings: _settings.set_quality(i))
		row.add_child(b)
	return row


func _style_slider(s: HSlider, accent: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.84, 0.79, 0.7, 0.7)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	s.add_theme_stylebox_override("slider", track)
	var area := StyleBoxFlat.new()
	area.bg_color = accent
	area.set_corner_radius_all(6)
	s.add_theme_stylebox_override("grabber_area", area)
	s.add_theme_stylebox_override("grabber_area_highlight", area)


func _sep() -> Control:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CozyUI.PAPER_EDGE, 0.25)
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	s.add_theme_stylebox_override("separator", sb)
	return s
