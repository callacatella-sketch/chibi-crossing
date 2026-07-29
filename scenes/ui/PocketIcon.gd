extends Control

## L'icona di un oggetto delle Tasche, disegnata a mano col vettoriale di
## Godot — nessun asset, come tutto il resto del gioco. Stessa routine per la
## cella piccola e per l'anteprima grande: disegna in uno spazio 0..1 scalato
## sul lato più corto, così resta nitida a ogni dimensione.
##
## kind: "carota","zucca","bacca","fungo" · "zuppa","vellutata","risotto",
## "crumble","te" · "bacca_lucida","funghetto","foglia","piuma","semino",
## "fiocco" · "farfalla","lucciola","pesce" (questi ultimi due usano `tint`).

var kind := "carota"
var tint := Color("b04a7a")

var _U := 1.0
var _o := Vector2.ZERO


func set_item(p_kind: String, p_tint := Color(0, 0, 0, 0)) -> void:
	kind = p_kind
	if p_tint.a > 0.0:
		tint = p_tint
	queue_redraw()


# punto in spazio 0..1 -> pixel (centrato, quadrato)
func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _U


func _ellf(cx: float, cy: float, rx: float, ry: float, segs := 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(_p(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func _ell(cx: float, cy: float, rx: float, ry: float, col: Color,
		oc := Color(0, 0, 0, 0), ow := 0.0) -> void:
	var pts := _ellf(cx, cy, rx, ry)
	draw_colored_polygon(pts, col)
	if oc.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, oc, ow * _U, true)


func _circle(cx: float, cy: float, r: float, col: Color) -> void:
	draw_circle(_p(cx, cy), r * _U, col)


func _stroke(pts_n: Array, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for q in pts_n:
		pts.append(_p(q.x, q.y))
	draw_polyline(pts, col, w * _U, true)


func _draw() -> void:
	_U = minf(size.x, size.y)
	_o = (size - Vector2(_U, _U)) * 0.5
	match kind:
		"carota": _carota()
		"zucca": _zucca()
		"bacca": _bacca()
		"fungo": _fungo()
		"zuppa": _bowl(Color("e8944a"), Color("f4a85e"), Color("b56a2a"))
		"vellutata": _bowl(Color("e07f38"), Color("ef9a52"), Color("b0611f"))
		"risotto": _risotto()
		"crumble": _crumble()
		"te": _te()
		"bacca_lucida": _bacca_lucida()
		"funghetto": _funghetto()
		"foglia": _foglia()
		"piuma": _piuma()
		"semino": _semino()
		"fiocco": _fiocco()
		"conchiglia": _conchiglia()
		"campanella": _campanella()
		"sasso": _sasso()
		"porcino": _porcino()
		"farfalla": _jar_farfalla()
		"lucciola": _jar_lucciola()
		"pesce": _jar_pesce()
		"bestiola": _jar_bestiola()
		"sagoma": _jar_sagoma()
		_: _bacca()


# ---------------------------------------------------------------- dispensa

func _carota() -> void:
	var body := Color("f0913c")
	var dark := Color("d97a2a")
	var leaf := Color("5e9c48")
	var pts := [Vector2(0.5, 0.14), Vector2(0.6, 0.4), Vector2(0.56, 0.72),
			Vector2(0.5, 0.9), Vector2(0.44, 0.72), Vector2(0.4, 0.4)]
	var pp := PackedVector2Array()
	for q in pts:
		pp.append(_p(q.x, q.y))
	draw_colored_polygon(pp, body)
	pp.append(pp[0])
	draw_polyline(pp, dark, 0.03 * _U, true)
	for yy in [0.34, 0.5, 0.64]:
		draw_line(_p(0.47, yy), _p(0.55, yy), Color(1, 0.86, 0.65, 0.7), 0.02 * _U, true)
	_stroke([Vector2(0.5, 0.16), Vector2(0.4, 0.05), Vector2(0.34, 0.08)], leaf, 0.05)
	_stroke([Vector2(0.5, 0.16), Vector2(0.5, 0.0)], leaf, 0.05)
	_stroke([Vector2(0.5, 0.16), Vector2(0.6, 0.05), Vector2(0.66, 0.08)], leaf, 0.05)


func _zucca() -> void:
	var skin := Color("e8813a")
	var rib := Color("cf6a28")
	_ell(0.5, 0.56, 0.38, 0.32, skin, rib, 0.03)
	for dx in [-0.16, 0.0, 0.16]:
		var col := Color(rib, 0.6)
		_stroke([Vector2(0.5 + dx, 0.26), Vector2(0.5 + dx * 1.5, 0.56),
				Vector2(0.5 + dx, 0.86)], col, 0.022)
	_stroke([Vector2(0.5, 0.26), Vector2(0.56, 0.14), Vector2(0.6, 0.16)],
			Color("62823e"), 0.05)


func _bacca() -> void:
	var a := Color("b04a7a")
	var b := Color("c25a8a")
	var c := Color("a03d6d")
	var oc := Color("8e3862")
	_ell(0.38, 0.6, 0.19, 0.19, a, oc, 0.028)
	_ell(0.62, 0.55, 0.17, 0.17, b, oc, 0.028)
	_ell(0.52, 0.73, 0.14, 0.14, c, oc, 0.028)
	_circle(0.33, 0.52, 0.04, Color(1, 0.82, 0.9, 0.8))
	_stroke([Vector2(0.5, 0.4), Vector2(0.4, 0.18), Vector2(0.34, 0.2)], Color("6a8a4e"), 0.038)
	_stroke([Vector2(0.56, 0.4), Vector2(0.66, 0.22), Vector2(0.72, 0.26)], Color("6a8a4e"), 0.038)


func _fungo() -> void:
	var stem := Color("efe0c4")
	var stem_o := Color("c8ab7e")
	var cap := Color("d0553f")
	var cap_o := Color("a53f2f")
	var pts := PackedVector2Array([_p(0.3, 0.58), _p(0.7, 0.58), _p(0.7, 0.64),
			_p(0.64, 0.82), _p(0.5, 0.86), _p(0.36, 0.82), _p(0.3, 0.64)])
	draw_colored_polygon(pts, stem)
	pts.append(pts[0])
	draw_polyline(pts, stem_o, 0.028 * _U, true)
	var cp := PackedVector2Array()
	for i in 20:
		var a := PI * float(i) / 19.0
		cp.append(_p(0.5 - cos(a) * 0.32, 0.6 - sin(a) * 0.34))
	cp.append(_p(0.82, 0.6))
	cp.append(_p(0.18, 0.6))
	draw_colored_polygon(cp, cap)
	draw_polyline(cp, cap_o, 0.028 * _U, true)
	_circle(0.38, 0.4, 0.05, Color("ffeede"))
	_circle(0.6, 0.36, 0.06, Color("ffeede"))
	_circle(0.52, 0.52, 0.04, Color("ffeede"))


func _porcino() -> void:
	# il porcino d'autunno: gambo panciuto e cappella bruna, senza puntini
	var stem := Color("efe0c4")
	var stem_o := Color("c8ab7e")
	var cap := Color("b0794a")
	var cap_o := Color("8a5c34")
	var pts := PackedVector2Array([_p(0.34, 0.56), _p(0.66, 0.56), _p(0.7, 0.66),
			_p(0.64, 0.86), _p(0.5, 0.9), _p(0.36, 0.86), _p(0.3, 0.66)])
	draw_colored_polygon(pts, stem)
	pts.append(pts[0])
	draw_polyline(pts, stem_o, 0.028 * _U, true)
	var cp := PackedVector2Array()
	for i in 20:
		var a := PI * float(i) / 19.0
		cp.append(_p(0.5 - cos(a) * 0.36, 0.58 - sin(a) * 0.3))
	cp.append(_p(0.86, 0.58))
	cp.append(_p(0.14, 0.58))
	draw_colored_polygon(cp, cap)
	draw_polyline(cp, cap_o, 0.028 * _U, true)
	_ell(0.42, 0.4, 0.08, 0.05, Color("c99a6a"))


# ---------------------------------------------------------------- cucina

func _bowl(broth: Color, top: Color, rim: Color) -> void:
	_steam()
	var pts := PackedVector2Array()
	for i in 20:
		var a := PI * float(i) / 19.0
		pts.append(_p(0.5 - cos(a) * 0.34, 0.46 + sin(a) * 0.34))
	draw_colored_polygon(pts, broth)
	pts.append(_p(0.16, 0.46))
	draw_polyline(pts, rim, 0.03 * _U, true)
	_ell(0.5, 0.46, 0.34, 0.1, top, rim, 0.03)


func _risotto() -> void:
	_bowl(Color("efe6cf"), Color("f5eeda"), Color("c3ad86"))
	for q in [Vector2(0.42, 0.44), Vector2(0.55, 0.45), Vector2(0.48, 0.48)]:
		_circle(q.x, q.y, 0.02, Color("b98a5a"))


func _crumble() -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := PI * float(i) / 19.0
		pts.append(_p(0.5 - cos(a) * 0.3, 0.46 + sin(a) * 0.34))
	draw_colored_polygon(pts, Color("a8386a"))
	pts.append(_p(0.2, 0.46))
	draw_polyline(pts, Color("7e2850"), 0.03 * _U, true)
	_ell(0.5, 0.45, 0.3, 0.09, Color("e0b878"), Color("c39a58"), 0.028)
	_circle(0.4, 0.43, 0.03, Color("8e3862"))
	_circle(0.6, 0.42, 0.03, Color("8e3862"))


func _te() -> void:
	_steam()
	var china := Color("fff6ea")
	var cup := PackedVector2Array([_p(0.28, 0.42), _p(0.72, 0.42), _p(0.66, 0.78),
			_p(0.34, 0.78)])
	draw_colored_polygon(cup, china)
	draw_polyline(PackedVector2Array([_p(0.28, 0.42), _p(0.34, 0.78), _p(0.66, 0.78),
			_p(0.72, 0.42)]), Color("c8ab7e"), 0.03 * _U, true)
	_ell(0.5, 0.44, 0.22, 0.05, tint, Color("c8ab7e"), 0.022)
	draw_arc(_p(0.72, 0.55), 0.1 * _U, -1.1, 1.1, 12, Color("c8ab7e"), 0.03 * _U, true)


func _steam() -> void:
	for dx in [-0.1, 0.1]:
		_stroke([Vector2(0.5 + dx, 0.28), Vector2(0.5 + dx - 0.04, 0.2),
				Vector2(0.5 + dx, 0.12)], Color(1, 1, 1, 0.8), 0.03)


# ---------------------------------------------------------------- tesori

func _bacca_lucida() -> void:
	_ell(0.5, 0.55, 0.26, 0.26, Color("b04a7a"), Color("8e3862"), 0.03)
	_ell(0.4, 0.44, 0.09, 0.06, Color(1, 0.82, 0.9, 0.9))
	_stroke([Vector2(0.5, 0.3), Vector2(0.4, 0.12), Vector2(0.34, 0.16)],
			Color("6a8a4e"), 0.04)
	# scintilla dorata
	var g := Color("fff3c9")
	_stroke([Vector2(0.76, 0.24), Vector2(0.8, 0.3)], g, 0.03)
	_stroke([Vector2(0.73, 0.27), Vector2(0.83, 0.27)], g, 0.03)


func _funghetto() -> void:
	var pts := PackedVector2Array([_p(0.34, 0.58), _p(0.66, 0.58), _p(0.62, 0.8),
			_p(0.5, 0.82), _p(0.38, 0.8)])
	draw_colored_polygon(pts, Color("efe0c4"))
	pts.append(pts[0])
	draw_polyline(pts, Color("c8ab7e"), 0.026 * _U, true)
	var cp := PackedVector2Array()
	for i in 18:
		var a := PI * float(i) / 17.0
		cp.append(_p(0.5 - cos(a) * 0.26, 0.6 - sin(a) * 0.3))
	cp.append(_p(0.76, 0.6))
	cp.append(_p(0.24, 0.6))
	draw_colored_polygon(cp, Color("d0a060"))
	draw_polyline(cp, Color("a8814a"), 0.026 * _U, true)
	_circle(0.42, 0.44, 0.04, Color("fff3e0"))
	_circle(0.6, 0.4, 0.05, Color("fff3e0"))


func _foglia() -> void:
	var leaf := Color("7cbf5e")
	var vein := Color("4d7a2f")
	var pts := PackedVector2Array()
	for i in 22:
		var t := float(i) / 21.0
		var a := PI * t
		pts.append(_p(0.5 + sin(a) * 0.28, 0.84 - t * 0.66))
	for i in 22:
		var t := float(i) / 21.0
		var a := PI * t
		pts.append(_p(0.5 - sin(a) * 0.28, 0.18 + t * 0.66))
	draw_colored_polygon(pts, leaf)
	draw_polyline(PackedVector2Array([_p(0.5, 0.82), _p(0.5, 0.24)]), vein, 0.025 * _U, true)
	for yy in [0.4, 0.55]:
		draw_line(_p(0.5, yy), _p(0.36, yy - 0.06), vein, 0.02 * _U, true)
		draw_line(_p(0.5, yy), _p(0.64, yy - 0.06), vein, 0.02 * _U, true)
	# cuoricino in punta
	_circle(0.46, 0.2, 0.045, Color("e79bb0"))
	_circle(0.54, 0.2, 0.045, Color("e79bb0"))
	draw_colored_polygon(PackedVector2Array([_p(0.42, 0.22), _p(0.58, 0.22),
			_p(0.5, 0.32)]), Color("e79bb0"))


func _piuma() -> void:
	var body := Color("f3e2c8")
	var spine := Color("c8ab7e")
	var pts := PackedVector2Array([_p(0.7, 0.2), _p(0.5, 0.34), _p(0.36, 0.54),
			_p(0.28, 0.8), _p(0.5, 0.7), _p(0.66, 0.5), _p(0.76, 0.28)])
	draw_colored_polygon(pts, body)
	pts.append(pts[0])
	draw_polyline(pts, spine, 0.024 * _U, true)
	draw_line(_p(0.72, 0.24), _p(0.34, 0.74), spine, 0.03 * _U, true)
	for t in [0.32, 0.46, 0.6]:
		draw_line(_p(0.72 - t * 0.5, 0.24 + t * 0.5), _p(0.72 - t * 0.5 - 0.14, 0.24 + t * 0.5 + 0.05),
				Color("dcc9a4"), 0.02 * _U, true)


func _semino() -> void:
	var a := Color("d9b36a")
	var b := Color("e8c884")
	var oc := Color("b8934a")
	_ell(0.42, 0.54, 0.1, 0.15, a, oc, 0.028)
	_ell(0.6, 0.58, 0.09, 0.14, b, oc, 0.028)


func _fiocco() -> void:
	_circle(0.5, 0.55, 0.26, Color("fff8ea"))
	draw_arc(_p(0.5, 0.55), 0.26 * _U, 0, TAU, 30, Color("e6d4b0"), 0.026 * _U, true)
	for yy in [0.48, 0.56, 0.66]:
		draw_arc(_p(0.5, yy - 0.1), 0.2 * _U, 0.3, PI - 0.3, 14, Color("efe0c0"), 0.024 * _U, true)


func _conchiglia() -> void:
	# la spirale di fiume: un guscio chiaro con le volute in penombra
	var guscio := Color("efe3d2")
	var ombra := Color("c9ab8a")
	_ell(0.5, 0.58, 0.3, 0.26, guscio, ombra, 0.03)
	for r in [0.22, 0.15, 0.08]:
		draw_arc(_p(0.54, 0.56), r * _U, -0.6, PI * 1.4, 18, ombra, 0.024 * _U, true)
	_circle(0.56, 0.55, 0.035, ombra)
	# il riflesso freddo dell'acqua
	_ell(0.38, 0.47, 0.07, 0.045, Color(0.85, 0.93, 0.95, 0.8))


func _sasso() -> void:
	# il sasso da rimbalzello: un disco appena ovale, visto di tre quarti,
	# con la faccia levigata piu' chiara e i cerchi dell'acqua sotto
	var pietra := Color("8e9299")
	var scuro := Color("6d7278")
	var chiaro := Color("b4b9bf")
	_ell(0.5, 0.56, 0.34, 0.19, pietra, scuro, 0.03)
	_ell(0.46, 0.51, 0.2, 0.09, chiaro)
	# i cerchi sull'acqua, sotto: dicono a cosa serve
	var acqua := Color(0.62, 0.78, 0.86, 0.75)
	draw_arc(_p(0.5, 0.8), 0.2 * _U, 0.15, PI - 0.15, 18, acqua, 0.024 * _U, true)
	draw_arc(_p(0.5, 0.8), 0.31 * _U, 0.35, PI - 0.35, 18,
			Color(acqua, 0.45), 0.02 * _U, true)


func _campanella() -> void:
	# la campanella di coccio: la sagoma a campana e il batacchio
	var coccio := Color("c08a5a")
	var bordo := Color("94643a")
	var pts := PackedVector2Array()
	for i in 16:
		var a := PI * float(i) / 15.0
		pts.append(_p(0.5 - cos(a) * 0.24, 0.62 - sin(a) * 0.34))
	pts.append(_p(0.78, 0.66))
	pts.append(_p(0.22, 0.66))
	draw_colored_polygon(pts, coccio)
	draw_polyline(pts, bordo, 0.028 * _U, true)
	# la sbeccatura (è vissuta) e il batacchio
	_ell(0.66, 0.36, 0.045, 0.03, Color(0.99, 0.96, 0.89))
	_circle(0.5, 0.72, 0.05, bordo)
	_stroke([Vector2(0.5, 0.24), Vector2(0.5, 0.16)], bordo, 0.045)


# ---------------------------------------------------------------- collezione (barattoli)

func _jar_glass() -> void:
	var glass := Color(0.87, 0.94, 0.95, 0.92)
	var go := Color("bcd6d8")
	var r := PackedVector2Array([_p(0.32, 0.36), _p(0.68, 0.36), _p(0.7, 0.78),
			_p(0.66, 0.86), _p(0.34, 0.86), _p(0.3, 0.78)])
	draw_colored_polygon(r, glass)
	r.append(r[0])
	draw_polyline(r, go, 0.026 * _U, true)
	# tappo di sughero
	draw_colored_polygon(PackedVector2Array([_p(0.3, 0.28), _p(0.7, 0.28),
			_p(0.68, 0.36), _p(0.32, 0.36)]), Color("c89a6b"))


func _jar_farfalla() -> void:
	_jar_glass()
	_ell(0.43, 0.6, 0.09, 0.13, tint)
	_ell(0.57, 0.6, 0.09, 0.13, tint)
	draw_line(_p(0.5, 0.5), _p(0.5, 0.72), Color("5a4636"), 0.02 * _U, true)


func _jar_lucciola() -> void:
	_jar_glass()
	_circle(0.5, 0.62, 0.14, Color(0.85, 1.0, 0.63, 0.4))
	_circle(0.5, 0.62, 0.08, Color("e8ffa8"))


func _jar_pesce() -> void:
	_jar_glass()
	_ell(0.5, 0.66, 0.2, 0.14, Color(0.56, 0.75, 0.85, 0.5))
	_ell(0.53, 0.62, 0.12, 0.075, tint)
	draw_colored_polygon(PackedVector2Array([_p(0.41, 0.62), _p(0.33, 0.56),
			_p(0.33, 0.68)]), tint)
	_circle(0.58, 0.6, 0.018, Color("2a1d1d"))


func _jar_bestiola() -> void:
	# la bestiola nel barattolo: corpicino tondo, capino e antennine
	_jar_glass()
	_ell(0.5, 0.66, 0.11, 0.085, tint)
	_circle(0.5, 0.55, 0.05, Color(tint.darkened(0.25), 1.0))
	var feeler := Color(tint.darkened(0.4), 0.9)
	_stroke([Vector2(0.47, 0.52), Vector2(0.43, 0.45)], feeler, 0.018)
	_stroke([Vector2(0.53, 0.52), Vector2(0.57, 0.45)], feeler, 0.018)


func _jar_sagoma() -> void:
	# la specie MAI vista: una sagoma grigia dietro il vetro e un punto di
	# domanda — l'indizio nel dettaglio dice dove e quando cercarla
	_jar_glass()
	var grigio := Color(0.62, 0.6, 0.57, 0.85)
	_ell(0.5, 0.64, 0.12, 0.1, grigio)
	_circle(0.5, 0.52, 0.055, grigio)
	var font := ThemeDB.fallback_font
	var fsize := int(0.24 * _U)
	var qs := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	draw_string(font, _p(0.5, 0.68) - Vector2(qs.x * 0.5, 0), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 0.98, 0.93, 0.95))
