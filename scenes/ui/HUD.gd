extends CanvasLayer

## HUD — il "cervello" dei bisogni: ascolta il SurvivalComponent (C++), traduce
## i valori grezzi in uno stato (sereno / basso / critico) con isteresi, e pilota
## il renderer VitalHUD (i ciondoli viventi) e i cue audio.
##
## Il musetto di Mochi reagisce a parte (MainLevel), in ascolto degli stessi
## segnali: qui teniamo solo la UI e il suono.

## Scatta quando un bisogno cambia fascia. kind: "water"|"hunger"|"stamina",
## level: 0 sereno · 1 basso · 2 critico. MainLevel lo usa per il musetto.
signal need_state_changed(kind: String, level: int)

const VITAL := preload("res://scenes/ui/VitalHUD.gd")
const KINDS := ["water", "hunger", "stamina"]

# soglie con isteresi: si ENTRA in allarme prima, si ESCE dopo, così le fasce
# non sfarfallano quando il valore oscilla sul confine
const LOW_ENTER := 0.35
const LOW_EXIT := 0.42
const CRIT_ENTER := 0.15
const CRIT_EXIT := 0.22
const ALERT_COOLDOWN := 0.7   # secondi tra due cue d'allarme, per non spammare

var _vital: Control
var _sfx
var _level := [0, 0, 0]
var _max := [100.0, 100.0, 100.0]
var _last_alert := -99.0

# il borsellino in alto a destra (economia): noccioline 🌰 e stelline ⭐
var _wallet: PanelContainer
var _nut_icon: CozyIcon
var _star_icon: CozyIcon
var _nut_label: Label
var _star_label: Label
var _fx_layer: Control
var _economy: Node


func _ready() -> void:
	# l'autoload Sfx potrebbe non essere ancora visibile al parser al primo
	# avvio: risoluzione a runtime (come fa Mochi)
	_sfx = get_node_or_null(^"/root/Sfx")
	_vital = VITAL.new()
	_vital.name = "VitalHUD"
	add_child(_vital)
	_build_wallet()
	# l'Economy è un fratello nell'albero: la agganciamo appena tutto è pronto
	_hook_economy.call_deferred()


# Chiamata dal MainLevel quando il Player è pronto, per collegare i segnali.
func connect_survival_component(survival_comp: Node) -> void:
	if not survival_comp:
		return

	_max[0] = maxf(1.0, survival_comp.get_max_water())
	_max[1] = maxf(1.0, survival_comp.get_max_hunger())
	_max[2] = maxf(1.0, survival_comp.get_max_stamina())

	survival_comp.water_changed.connect(_on_need_changed.bind(0))
	survival_comp.hunger_changed.connect(_on_need_changed.bind(1))
	survival_comp.stamina_changed.connect(_on_need_changed.bind(2))

	# stato iniziale (senza cue: è solo il primo disegno)
	_sync(0, survival_comp.get_water(), _max[0], false)
	_sync(1, survival_comp.get_hunger(), _max[1], false)
	_sync(2, survival_comp.get_stamina(), _max[2], false)


# i segnali C++ passano (new_value, max_value); .bind aggiunge l'indice in coda
func _on_need_changed(new_value: float, max_value: float, idx: int) -> void:
	_sync(idx, new_value, max_value, true)


func _sync(idx: int, value: float, max_value: float, allow_cue: bool) -> void:
	_max[idx] = maxf(1.0, max_value)
	var frac := clampf(value / _max[idx], 0.0, 1.0)
	var level := _next_level(_level[idx], frac)
	if _vital:
		_vital.update_need(idx, frac, level)
	if level != _level[idx]:
		var prev: int = _level[idx]
		_level[idx] = level
		need_state_changed.emit(KINDS[idx], level)
		if allow_cue:
			_cue(prev, level)


# calcola la nuova fascia partendo dalla corrente (isteresi)
func _next_level(current: int, frac: float) -> int:
	match current:
		2:
			return 2 if frac < CRIT_EXIT else (1 if frac < LOW_EXIT else 0)
		1:
			if frac < CRIT_ENTER:
				return 2
			return 1 if frac < LOW_EXIT else 0
		_:
			if frac < CRIT_ENTER:
				return 2
			return 1 if frac < LOW_ENTER else 0


# suono discreto: un battito d'allarme quando si scivola nel critico, un
# campanellino di sollievo quando si risale
func _cue(prev: int, level: int) -> void:
	if not _sfx:
		return
	if level == 2 and prev < 2:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_alert >= ALERT_COOLDOWN:
			_last_alert = now
			_sfx.need_alert()
	elif prev == 2 and level < 2:
		_sfx.need_relief()


# ---------------------------------------------------------------- borsellino
func _build_wallet() -> void:
	# strato per i "+N" che volano via quando guadagni
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.anchor_left = 1.0
	margin.anchor_right = 1.0
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_wallet = PanelContainer.new()
	var sb := CozyUI.paper_panel(20, 0.94)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_size = 14
	_wallet.add_theme_stylebox_override("panel", sb)
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_wallet)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_wallet.add_child(row)

	_nut_icon = CozyUI.nut(26)
	row.add_child(_nut_icon)
	_nut_label = _coin_label("0")
	row.add_child(_nut_label)

	var sep := VSeparator.new()
	row.add_child(sep)

	_star_icon = CozyUI.star(26)
	row.add_child(_star_icon)
	_star_label = _coin_label("0")
	row.add_child(_star_label)

	_wallet.modulate.a = 0.0   # appare in dissolvenza quando l'economia c'è


func _coin_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", CozyUI.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(24, 0)
	return l


func _hook_economy() -> void:
	_economy = get_tree().get_first_node_in_group("economy")
	if _economy == null:
		return
	if not _economy.nuts_changed.is_connected(_on_nuts_changed):
		_economy.nuts_changed.connect(_on_nuts_changed)
	if not _economy.stars_changed.is_connected(_on_stars_changed):
		_economy.stars_changed.connect(_on_stars_changed)
	_nut_label.text = str(_economy.nuts)
	_star_label.text = str(_economy.stars)
	var t := create_tween()
	t.tween_property(_wallet, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _on_nuts_changed(total: int) -> void:
	var delta := (total - int(_nut_label.text)) if _nut_label.text.is_valid_int() else 0
	_nut_label.text = str(total)
	_pop(_nut_icon)
	if delta > 0:
		_float_gain("+%d" % delta, CozyUI.NUT, false)


func _on_stars_changed(total: int) -> void:
	var delta := (total - int(_star_label.text)) if _star_label.text.is_valid_int() else 0
	_star_label.text = str(total)
	_pop(_star_icon)
	if delta > 0:
		_float_gain("+%d" % delta, CozyUI.GOLD, true)


func _pop(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var t := create_tween()
	t.tween_property(node, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)


# un piccolo "+N" dorato/marrone che sale dal borsellino e svanisce
func _float_gain(text: String, color: Color, star: bool) -> void:
	if _fx_layer == null or _wallet == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.1, 0.4))
	l.add_theme_constant_override("shadow_offset_y", 1)
	_fx_layer.add_child(l)
	var wr := _wallet.get_global_rect()
	var fx := wr.position.x + (wr.size.x * 0.72 if star else wr.size.x * 0.22)
	l.global_position = Vector2(fx, wr.position.y + wr.size.y)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", l.global_position.y + 42.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.9)
	t.chain().tween_callback(l.queue_free)
