extends Control

## VitalHUD — i "charm viventi" dei bisogni di Mochi, disegnati interamente a
## mano (nessun asset esterno, come tutto il resto del gioco).
##
## Tre piccoli ciondoli — una goccia (acqua), un pesciolino (fame), una
## zampina (energia) — ciascuno con la sua fiala liquida. Non sono barre: sono
## creaturine. Respirano piano, la superficie del liquido ondeggia, e quando il
## bisogno cala il ciondolo si tinge di corallo e comincia a battere come un
## cuoricino. Quando tutto va bene si fanno da parte, quasi trasparenti: una UI
## che parla solo quando ha qualcosa da dire.
##
## È un puro RENDERER pilotato da HUD.gd: riceve valore (0..1) e livello
## d'allarme (0 sereno · 1 basso · 2 critico) per ciascun bisogno, e ci mette
## del suo tutta la vita (easing, respiro, battito, festa del refill, quiete).

const COUNT := 3

# --- geometria (coordinate LOCALI, relative al centro del ciondolo) ---
const MARGIN_X := 26.0
const MARGIN_Y := 26.0
const CAP_R := 19.0          # raggio del ciondolo-medaglione a sinistra
const BAR_H := 22.0          # altezza della fiala
const BAR_W := 190.0         # lunghezza della fiala
const ROW_GAP := 17.0
const BX0 := CAP_R - 6.0     # dove parte la fiala (un filo sotto il medaglione)
const BR := BAR_H * 0.5
const FILL_PAD := 2.5        # margine tra binario e liquido (fa vedere il bordo)

# --- estetica ---
const CORAL := Color("ff7a86")          # il tono d'allarme, caldo
const INK := Color("4a3b52")            # inchiostro delle iconcine
const TRACK := Color(0.24, 0.20, 0.29, 0.34)
const SHADOW := Color(0.09, 0.07, 0.13, 0.24)
const GLOSS := Color(1, 1, 1, 0.20)
const QUIET_ALPHA := 0.66               # opacità da "riposo", quando è sereno
const POP_DUR := 0.9                    # durata della festa del refill
const HB_PERIOD := 1.15                 # periodo del battito (secondi)

# ogni bisogno: colore del liquido e nome dell'iconcina
const NEEDS := [
	{"color": Color("a2d2ff"), "icon": "drop"},   # acqua
	{"color": Color("ffc8dd"), "icon": "fish"},   # fame
	{"color": Color("b9fbc0"), "icon": "paw"},    # energia
]

# --- stato animato ---
var _t := 0.0
var _val: Array[float] = [1.0, 1.0, 1.0]     # obiettivo (0..1) da HUD
var _shown: Array[float] = [1.0, 1.0, 1.0]   # valore mostrato (insegue _val)
var _alert: Array[int] = [0, 0, 0]           # 0 sereno · 1 basso · 2 critico
var _alert_mix: Array[float] = [0.0, 0.0, 0.0]  # quanto corallo, addolcito
var _attn: Array[float] = [0.0, 0.0, 0.0]    # "sveglio" (0..1) -> opacità
var _awake: Array[float] = [0.0, 0.0, 0.0]   # timer di attenzione residua
var _pop: Array[float] = [0.0, 0.0, 0.0]     # festa del refill (1 -> 0)
var _wake_ref: Array[float] = [1.0, 1.0, 1.0]  # valore all'ultimo risveglio


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# un piccolo saluto all'avvio: i ciondoli si mostrano e poi si acquietano
	for i in COUNT:
		_awake[i] = 2.2


## Aggiorna un bisogno: valore normalizzato e livello d'allarme (0/1/2).
## Il resto (risveglio, festa del refill) lo deduce da sé.
func update_need(i: int, v01: float, level: int) -> void:
	if i < 0 or i >= COUNT:
		return
	v01 = clampf(v01, 0.0, 1.0)
	# un balzo netto verso l'alto = qualcuno ha mangiato / si è immerso: si festeggia
	var refill := v01 - _val[i] > 0.12
	if refill:
		_pop[i] = 1.0
	# il risveglio scatta sugli EVENTI, non a ogni goccia: il drenaggio C++
	# emette a ogni frame e svegliarsi sempre teneva acqua e fame a piena
	# opacità per sempre (la "quiete" non arrivava mai). Si sveglia per:
	# refill, cambio di fascia, o una deriva accumulata percepibile (>10%:
	# la corsa lo tiene sveglio, il lento sorseggiare no).
	var woke := refill or level != _alert[i] \
			or absf(v01 - _wake_ref[i]) > 0.10
	_val[i] = v01
	_alert[i] = level
	if woke:
		_wake_ref[i] = v01
		_awake[i] = maxf(_awake[i], 2.6)


func _process(delta: float) -> void:
	_t += delta
	var kf := 1.0 - exp(-10.0 * delta)   # coefficiente di easing frame-rate independent
	var ka := 1.0 - exp(-6.0 * delta)
	for i in COUNT:
		_shown[i] = lerpf(_shown[i], _val[i], kf)
		if _awake[i] > 0.0:
			_awake[i] -= delta
		var want_attn := 1.0 if (_awake[i] > 0.0 or _alert[i] > 0) else 0.0
		_attn[i] = lerpf(_attn[i], want_attn, ka)
		var want_mix := 0.0
		if _alert[i] == 1:
			want_mix = 0.45
		elif _alert[i] == 2:
			want_mix = 0.85
		_alert_mix[i] = lerpf(_alert_mix[i], want_mix, ka)
		if _pop[i] > 0.0:
			_pop[i] = maxf(0.0, _pop[i] - delta / POP_DUR)
	queue_redraw()


# battito a due colpi ("lub-dub") su un ciclo; ritorna 0..1
func _heartbeat() -> float:
	var p := fmod(_t, HB_PERIOD) / HB_PERIOD
	var lub := exp(-pow((p - 0.06) / 0.055, 2.0))
	var dub := 0.62 * exp(-pow((p - 0.24) / 0.05, 2.0))
	return clampf(lub + dub, 0.0, 1.0)


func _draw() -> void:
	var hb := _heartbeat()
	var row := maxf(CAP_R * 2.0, BAR_H) + ROW_GAP
	for i in COUNT:
		var pivot := Vector2(MARGIN_X + CAP_R, MARGIN_Y + CAP_R + i * row)
		var crit := clampf((_alert_mix[i] - 0.45) / 0.4, 0.0, 1.0)   # 0..1 solo nel critico
		# respiro lento + battito quando è in crisi; da quieto rimpicciolisce un
		# soffio invece di sparire, così resta presente ma discreto
		var s := 1.0 + sin(_t * 1.5 + i * 1.7) * 0.012 + hb * 0.055 * crit
		s *= lerpf(0.9, 1.0, _attn[i])
		draw_set_transform(pivot, 0.0, Vector2(s, s))
		_draw_charm(i, hb, crit)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_charm(i: int, hb: float, crit: float) -> void:
	var need: Dictionary = NEEDS[i]
	var base: Color = need["color"]
	var mix: float = _alert_mix[i]
	var fill_col: Color = base.lerp(CORAL, mix)
	var bead_col: Color = base.lerp(CORAL, mix * 0.75).lightened(0.05)
	var a := lerpf(QUIET_ALPHA, 1.0, _attn[i])   # opacità del ciondolo intero
	var frac := clampf(_shown[i], 0.0, 1.0)
	var bx1 := BX0 + BAR_W

	# --- alone pulsante quando è critico ---
	if crit > 0.01:
		var halo := _a(CORAL, a * (0.14 + 0.30 * hb) * crit)
		_caps(BX0 - 6.0, bx1 + 6.0, 0.0, BR + 7.0, halo)
		draw_circle(Vector2.ZERO, CAP_R + 7.0, halo, true, -1.0, true)

	# --- ombre morbide (ancorano i ciondoli allo schermo) ---
	_caps(BX0, bx1, 3.0, BR + 1.0, _a(SHADOW, a))
	draw_circle(Vector2(0, 3.0), CAP_R + 1.0, _a(SHADOW, a), true, -1.0, true)

	# --- il binario vuoto della fiala ---
	# quando il bisogno cala, il vuoto non è un buco nero: si scalda verso il
	# corallo, così una fiala scarica "brilla" d'avviso con dolcezza
	var track_col: Color = TRACK.lerp(Color(0.42, 0.17, 0.20, TRACK.a + 0.06), mix * 0.6)
	_caps(BX0, bx1, 0.0, BR, _a(track_col, a))

	# --- il liquido, con superficie che ondeggia ---
	var fill_r := BR - FILL_PAD
	var fx0 := BX0 + FILL_PAD
	var fx_max := bx1 - FILL_PAD
	var fx := fx0 + frac * (fx_max - fx0)
	# un lieve sciabordio: la superficie sale e scende di un soffio
	var slosh := sin(_t * 2.3 + i * 1.1) * 1.1 * frac
	fx = clampf(fx + slosh, fx0, fx_max)
	if fx > fx0 + 0.5:
		_caps(fx0, fx, 0.0, fill_r, _a(fill_col, a))
		# gloss: una lucina morbida lungo la parte alta del liquido
		_caps(fx0 + 1.0, fx, -fill_r * 0.46, fill_r * 0.4, _a(GLOSS, a))
		# glint sul pelo del liquido: un piccolo riflesso morbido, non un anello
		draw_circle(Vector2(fx - fill_r * 0.6, -fill_r * 0.28), fill_r * 0.34,
				_a(Color(1, 1, 1, 0.5), a), true, -1.0, true)

	# --- festa del refill: scintille che si aprono dal medaglione ---
	if _pop[i] > 0.0:
		var pr: float = _pop[i]
		var spark := _a(bead_col.lightened(0.35), a * pr)
		for k in 7:
			var ang := TAU * (float(k) / 7.0) + i * 0.6
			var rr := CAP_R + (1.0 - pr) * 22.0
			draw_circle(Vector2(cos(ang), sin(ang)) * rr, 2.6 + pr * 1.8, spark, true, -1.0, true)

	# --- il medaglione-ciondolo ---
	var pop_bump := 1.0 + _pop[i] * 0.12
	draw_circle(Vector2.ZERO, CAP_R * pop_bump, _a(bead_col, a), true, -1.0, true)
	# bordino interno appena più scuro, per dare volume
	draw_circle(Vector2.ZERO, CAP_R * pop_bump, _a(bead_col.darkened(0.22), a), false, 1.6, true)
	# lucina in alto a sinistra: il medaglione sembra lucido
	draw_circle(Vector2(-CAP_R * 0.32, -CAP_R * 0.36), CAP_R * 0.30,
			_a(Color(1, 1, 1, 0.28), a), true, -1.0, true)
	# l'iconcina
	_draw_icon(need["icon"], _a(INK, a))


# ---------------------------------------------------------------- primitive

# capsula (pillola arrotondata) tra x0..x1, centrata su cy, raggio r.
# Disegnata come UN SOLO poligono a stadio: con un rettangolo + due cerchi le
# zone di sovrapposizione raddoppierebbero l'alpha (bande scure sui colori
# traslucidi); un unico poligono riempie una volta sola.
func _caps(x0: float, x1: float, cy: float, r: float, col: Color) -> void:
	if r <= 0.0 or x1 <= x0:
		return
	var cxl := x0 + r
	var cxr := x1 - r
	if cxr <= cxl:
		# troppo corta per la parte dritta: solo una gocciolina tonda
		var rr := (x1 - x0) * 0.5
		if rr > 0.3:
			draw_circle(Vector2((x0 + x1) * 0.5, cy), rr, col, true, -1.0, true)
		return
	var pts := PackedVector2Array()
	var seg := 12
	for k in seg + 1:   # cap destro: da -90° a +90°
		var ang := -PI * 0.5 + PI * float(k) / float(seg)
		pts.append(Vector2(cxr + cos(ang) * r, cy + sin(ang) * r))
	for k in seg + 1:   # cap sinistro: da +90° a +270°
		var ang := PI * 0.5 + PI * float(k) / float(seg)
		pts.append(Vector2(cxl + cos(ang) * r, cy + sin(ang) * r))
	draw_colored_polygon(pts, col)


func _draw_icon(kind: String, col: Color) -> void:
	match kind:
		"drop":
			# goccia: pancia tonda + puntina in su
			draw_circle(Vector2(0, 3.2), 6.6, col, true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([
					Vector2(0, -9.2), Vector2(-5.4, 1.4), Vector2(5.4, 1.4)]), col)
		"fish":
			# pesciolino: corpo ovale + codina + occhietto
			draw_colored_polygon(_ellipse(Vector2(-1.5, 0), 7.6, 5.0, 20), col)
			draw_colored_polygon(PackedVector2Array([
					Vector2(5.5, 0), Vector2(10.5, -4.2), Vector2(10.5, 4.2)]), col)
			draw_circle(Vector2(-4.4, -1.2), 1.5, Color(1, 1, 1, col.a * 0.9), true, -1.0, true)
		"paw":
			# zampina: cuscinetto grande + tre fagiolini
			draw_colored_polygon(_ellipse(Vector2(0, 3.6), 6.2, 5.2, 20), col)
			draw_circle(Vector2(-5.0, -3.6), 2.6, col, true, -1.0, true)
			draw_circle(Vector2(0, -5.8), 2.8, col, true, -1.0, true)
			draw_circle(Vector2(5.0, -3.6), 2.6, col, true, -1.0, true)


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var ang := TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


# colore con alpha scalato (per far sfumare l'intero ciondolo nella quiete)
func _a(col: Color, k: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * k)
