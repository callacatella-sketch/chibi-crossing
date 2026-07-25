class_name CozyIcon
extends Control

## Icone disegnate a mano (nessun font: gli emoji 🌰⭐ non esistono nel font di
## default di Godot e uscirebbero come quadratini). Qui una ghianda, una
## stellina, una fogliolina e uno scintillio, dipinti con lo stesso gusto
## pastello del resto del gioco. Si ridimensionano da sole e si possono tingere.
##
## Uso:  var i := CozyIcon.new(); i.kind = "nut"; i.px = 22

@export var kind := "nut"   # "nut" | "star" | "leaf" | "spark" | "coin"
@export var px := 22.0:
	set(v):
		px = v
		custom_minimum_size = Vector2(px, px)
		queue_redraw()
@export var tint := Color(1, 1, 1, 1):
	set(v):
		tint = v
		queue_redraw()
## Un alone morbido dietro l'icona (per le monete che "brillano" nell'HUD).
@export var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()

const NUT_BODY := Color("d59a5f")
const NUT_BODY_HI := Color("f0bd82")
const NUT_TIP := Color("b97f49")
const CAP := Color("7f5433")
const CAP_HI := Color("946237")
const STEM := Color("5f3f26")

const STAR_GOLD := Color("ffd257")
const STAR_GOLD_HI := Color("fff0b0")
const STAR_GOLD_LO := Color("f0a83c")

const LEAF_A := Color("8fce6e")
const LEAF_B := Color("6fb050")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 0.0:
		s = px
	match kind:
		"nut": _draw_nut(s)
		"star": _draw_star(s)
		"leaf": _draw_leaf(s)
		"spark": _draw_spark(s)
		"coin": _draw_coin(s)


# ---------------------------------------------------------------- ghianda
func _draw_nut(s: float) -> void:
	var cx := s * 0.5
	if glow > 0.0:
		draw_circle(Vector2(cx, s * 0.55), s * 0.55, Color(NUT_BODY_HI, 0.18 * glow))
	# corpo: ovale che si appuntisce verso il basso
	var body := _ellipse(cx, s * 0.62, s * 0.30, s * 0.31, 30)
	draw_colored_polygon(body, _t(NUT_BODY))
	# la punta
	var tip := PackedVector2Array([
		Vector2(cx - s * 0.15, s * 0.78), Vector2(cx + s * 0.15, s * 0.78),
		Vector2(cx, s * 0.965)])
	draw_colored_polygon(tip, _t(NUT_TIP))
	# luce sul corpo (alto-sinistra)
	draw_circle(Vector2(cx - s * 0.10, s * 0.5), s * 0.11, Color(_t(NUT_BODY_HI), 0.75))
	# cappuccio
	var cap := _ellipse(cx, s * 0.36, s * 0.33, s * 0.20, 26)
	draw_colored_polygon(cap, _t(CAP))
	draw_colored_polygon(_ellipse(cx, s * 0.30, s * 0.30, s * 0.14, 24), _t(CAP_HI))
	# la scodella bitorzoluta del cappuccio
	for i in 5:
		var x := cx - s * 0.26 + s * 0.13 * float(i)
		draw_circle(Vector2(x, s * 0.44), s * 0.055, _t(CAP))
	# picciolo
	draw_circle(Vector2(cx, s * 0.16), s * 0.05, _t(STEM))
	draw_rect(Rect2(cx - s * 0.03, s * 0.10, s * 0.06, s * 0.10), _t(STEM))


# ---------------------------------------------------------------- stellina
func _draw_star(s: float) -> void:
	var c := Vector2(s * 0.5, s * 0.52)
	var ro := s * 0.47
	var ri := ro * 0.44
	if glow > 0.0:
		draw_circle(c, ro * 1.25, Color(STAR_GOLD_HI, 0.22 * glow))
	# ombra dorata dietro, per un filo di volume
	draw_colored_polygon(_star(c + Vector2(0, s * 0.02), ro, ri), _t(STAR_GOLD_LO))
	draw_colored_polygon(_star(c, ro * 0.96, ri * 0.96), _t(STAR_GOLD))
	# scintilla centrale
	draw_colored_polygon(_star(c - Vector2(0, s * 0.03), ro * 0.44, ri * 0.5), Color(_t(STAR_GOLD_HI), 0.9))


# ---------------------------------------------------------------- fogliolina
func _draw_leaf(s: float) -> void:
	var pts := PackedVector2Array()
	var n := 22
	for i in n:
		var t := float(i) / float(n - 1)
		var x := s * (0.2 + 0.6 * t)
		var y := s * (0.85 - 0.7 * t)
		var w := sin(t * PI) * s * 0.16
		pts.append(Vector2(x - w * 0.4, y - w))
	for i in range(n - 1, -1, -1):
		var t := float(i) / float(n - 1)
		var x := s * (0.2 + 0.6 * t)
		var y := s * (0.85 - 0.7 * t)
		var w := sin(t * PI) * s * 0.16
		pts.append(Vector2(x + w * 0.4, y + w))
	draw_colored_polygon(pts, _t(LEAF_A))
	draw_line(Vector2(s * 0.24, s * 0.82), Vector2(s * 0.78, s * 0.2), _t(LEAF_B), s * 0.03, true)


# ---------------------------------------------------------------- scintillio
func _draw_spark(s: float) -> void:
	var c := Vector2(s * 0.5, s * 0.5)
	var col := _t(Color("fff2c0"))
	for a in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
		var d := Vector2(cos(a), sin(a)) * s * 0.46
		draw_line(c - d, c + d, Color(col, 0.9), s * 0.05, true)
	draw_circle(c, s * 0.1, col)


# ---------------------------------------------------------------- monetina
func _draw_coin(s: float) -> void:
	var c := Vector2(s * 0.5, s * 0.5)
	if glow > 0.0:
		draw_circle(c, s * 0.55, Color(STAR_GOLD_HI, 0.2 * glow))
	draw_circle(c, s * 0.46, _t(STAR_GOLD_LO))
	draw_circle(c, s * 0.4, _t(STAR_GOLD))
	draw_circle(c - Vector2(s * 0.1, s * 0.1), s * 0.12, Color(_t(STAR_GOLD_HI), 0.7))


# ---------------------------------------------------------------- util
func _t(c: Color) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a)


func _ellipse(cx: float, cy: float, rx: float, ry: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		p.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return p


func _star(c: Vector2, ro: float, ri: float, n := 5) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n * 2:
		var r := ro if i % 2 == 0 else ri
		var a := -PI * 0.5 + PI * float(i) / float(n)
		p.append(Vector2(c.x + cos(a) * r, c.y + sin(a) * r))
	return p
