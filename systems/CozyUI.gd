class_name CozyUI
extends RefCounted

## Il "kit" UI condiviso di Chibi Crossing: una sola lingua visiva per tutti i
## menu nuovi (titolo, pausa, impostazioni, negozio). Estrae ed eleva la
## ricetta pastello "carta calda" già sparsa nei pannelli di gioco, e la rende
## coerente e spettacolare: pannelli morbidi con ombra, bottoni che si sollevano
## al passaggio del mouse con un plin, titoli con ombra gentile, animazioni di
## entrata/uscita, e le monetine disegnate a mano.
##
## Tutto statico: nessun autoload. Le funzioni restituiscono nodi Godot già
## vestiti, pronti da appendere. Rispetta "Riduci animazioni" (Settings).

# ---------------------------------------------------------------- palette
const PAPER := Color("fdf6e3")
const PAPER_WARM := Color("f7ecd2")
const PAPER_EDGE := Color(0.62, 0.46, 0.34, 0.55)
const INK := Color("6a4a3a")
const INK_SOFT := Color(0.416, 0.29, 0.227, 0.6)
const TITLE := Color("8a5a3a")
const PINK := Color("f4a9bc")
const PINK_DEEP := Color("e88aa4")
const PINK_TEXT := Color("c25a7a")
const HOVER_PINK := Color("a83a5c")
const MINT := Color("bfe6c8")
const SKY := Color("bcdcf3")
const GOLD := Color("ffd257")
const HONEY := Color("f2c27a")
const LAVENDER := Color("d9c8ef")
const PEACH := Color("f7c9a8")
const NUT := Color("c68a54")
const CREAM := Color("fff3e0")
const DANGER := Color("e39a92")


# ---------------------------------------------------------------- pannelli
static func paper_panel(radius := 26.0, opacity := 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER, opacity)
	sb.set_corner_radius_all(int(radius))
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.32, 0.2, 0.14, 0.34)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 12)
	sb.content_margin_left = 32.0
	sb.content_margin_right = 32.0
	sb.content_margin_top = 26.0
	sb.content_margin_bottom = 26.0
	return sb


static func soft_card(bg := PAPER_WARM, radius := 16.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.border_color = Color(PAPER_EDGE, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


static func pill(bg: Color, radius := 16.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	return sb


# un pannello che riempie lo schermo e centra il suo unico figlio
static func center_root() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


# tende scura dietro un modale (parte trasparente: sfumala con fade_to)
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.06, 0.045, 0.09, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func fade_to(r: ColorRect, a: float, dur := 0.3) -> void:
	if not r.is_inside_tree():
		r.color.a = a   # robusto: se il nodo non è ancora nell'albero, niente tween
		return
	var t := r.create_tween()
	t.tween_property(r, "color:a", a, dur).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- testi
static func title_label(text: String, size := 40) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TITLE)
	l.add_theme_color_override("font_shadow_color", Color(0.5, 0.32, 0.2, 0.28))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func body_label(text: String, size := 16, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func hint_label(text: String, size := 13) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(INK, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- bottoni
static func cozy_button(text: String, accent := PINK, font_size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 52)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", HOVER_PINK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.4))

	var normal := pill(Color(1, 1, 1, 0.5), 16)
	_pad(normal, 22, 12)
	var hover := pill(Color(accent, 0.96), 16)
	_pad(hover, 22, 12)
	hover.shadow_color = Color(0.4, 0.25, 0.3, 0.3)
	hover.shadow_size = 12
	hover.shadow_offset = Vector2(0, 5)
	var pressed := pill(accent.darkened(0.08), 16)
	_pad(pressed, 22, 12)
	var disabled := pill(Color(0.82, 0.78, 0.72, 0.3), 16)
	_pad(disabled, 22, 12)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", pill(Color(1, 1, 1, 0.0), 16))
	_animate_button(b)
	return b


# bottone-scheda per le linguette (Vendi / Compra, categorie…)
static func tab_button(text: String, group: ButtonGroup, accent := PINK) -> Button:
	var b := cozy_button(text, accent, 17)
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(150, 46)
	var on := pill(Color(accent, 0.95), 16)
	_pad(on, 18, 10)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", INK)
	return b


static func _pad(sb: StyleBoxFlat, h: float, v: float) -> void:
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v


# un solo tween di scala per bottone alla volta: quello vecchio si uccide, così
# hover ed exit ravvicinati non lasciano il bottone incastrato a 1.05
static func _btween(b: Button) -> Tween:
	# has_meta PRIMA di get_meta: il valore di default di get_meta e' gia'
	# `null`, quindi passargli `null` non lo distingue da «nessun default» e
	# Godot urla la prima volta, quando il meta non c'e' ancora.
	var old: Variant = b.get_meta("_hovtw") if b.has_meta("_hovtw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var t := b.create_tween()
	b.set_meta("_hovtw", t)
	return t


static func _animate_button(b: Button) -> void:
	b.mouse_entered.connect(func() -> void:
		var sfx := b.get_node_or_null(^"/root/Sfx")
		if sfx: sfx.call("play", "tick", -24.0, 1.35)
		if _reduced(b): return
		b.pivot_offset = b.size * 0.5
		var t := _btween(b).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2(1.05, 1.05), 0.14))
	b.mouse_exited.connect(func() -> void:
		if _reduced(b): return
		b.pivot_offset = b.size * 0.5
		var t := _btween(b).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.14))
	b.pressed.connect(func() -> void:
		var sfx := b.get_node_or_null(^"/root/Sfx")
		if sfx: sfx.call("ui_select")
		if _reduced(b): return
		b.pivot_offset = b.size * 0.5
		var hovered := b.get_global_rect().has_point(b.get_global_mouse_position())
		var t := _btween(b)
		t.tween_property(b, "scale", Vector2(0.95, 0.95), 0.06)
		t.tween_property(b, "scale", Vector2(1.05, 1.05) if hovered else Vector2.ONE, 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


# ---------------------------------------------------------------- icone
static func nut(px := 22.0) -> CozyIcon:
	var i := CozyIcon.new()
	i.kind = "nut"
	i.px = px
	return i


static func star(px := 22.0) -> CozyIcon:
	var i := CozyIcon.new()
	i.kind = "star"
	i.px = px
	return i


static func icon(kind: String, px := 22.0) -> CozyIcon:
	var i := CozyIcon.new()
	i.kind = kind
	i.px = px
	return i


static func petals(amount := 26, soft := true) -> CozyPetals:
	var p := CozyPetals.new()
	p.petal_amount = amount
	p.soft = soft
	return p


# ---------------------------------------------------------------- animazioni
static func appear(c: Control, dur := 0.34) -> void:
	if _reduced(c):
		c.modulate.a = 1.0
		c.scale = Vector2.ONE
		return
	c.modulate.a = 0.0
	c.scale = Vector2(0.92, 0.92)
	var t := c.create_tween()
	t.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)
	t.parallel().tween_property(c, "modulate:a", 1.0, dur * 0.8)
	t.parallel().tween_property(c, "scale", Vector2.ONE, dur) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func dismiss(c: Control, then := Callable(), dur := 0.2) -> void:
	if _reduced(c):
		if then.is_valid(): then.call()
		return
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween()
	t.set_parallel(true)
	t.tween_property(c, "modulate:a", 0.0, dur)
	t.tween_property(c, "scale", Vector2(0.94, 0.94), dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if then.is_valid():
		t.chain().tween_callback(then)


static func _reduced(node: Node) -> bool:
	var s := node.get_node_or_null(^"/root/Settings")
	return s != null and bool(s.get("reduce_motion"))
