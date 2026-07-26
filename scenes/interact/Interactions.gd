extends Node

## Interazioni cozy: avvicinati a una sedia, sgabello o panchina e premi E
## per sederti; sul letto, E per dormire (con tanto di "zzz"). Un altro E
## per alzarti. Mentre Mochi è seduta il PlayerController C++ è in pausa.
##
## Di notte il letto fa di più: Mochi si addormenta, lo schermo sfuma nel
## buio, un "Buongiorno!" e il sole è di nuovo alto — la notte è saltata,
## la stamina è piena e lei si rialza da sola pronta per un altro giorno.

# offset locale del punto in cui va la RADICE di Mochi: più basso del piano
# di seduta, così il vestitino affonda sul cuscino invece di starci in piedi.
# Nel letto la radice va verso i piedi del materasso: la posa "sleep" la
# reclina all'indietro col capo sul cuscino.
const SEATS := {
	"Sedia": Vector3(0, 0.36, 0.08),
	"Sgabello": Vector3(0, 0.33, 0.0),
	"Panchina": Vector3(0, 0.35, 0.08),
	"Letto": Vector3(0, 0.3, 0.26),
}

var _player: Node3D
var _mochi: Node3D
var _build: Node3D
var _sfx

var _prompt: PanelContainer
var _prompt_label: Label
var _target: Node3D
var _target_name := ""
var _seated := false
var _return_pos := Vector3.ZERO

# il sonno notturno: velo di dissolvenza, saluto del mattino, stato
var _daynight: Node3D
var _fade: ColorRect
var _wake_label: Label
var _sleeping := false


func _ready() -> void:
	_player = get_node("%Player")
	_mochi = _player.get_node("Mochi")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_prompt()
	_build_fade()


func is_seated() -> bool:
	return _seated


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
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


# il sipario della notte: un velo blu-notte sopra a tutto, con al centro
# il saluto del mattino che appare solo a schermo buio
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	_wake_label = Label.new()
	_wake_label.text = "Buongiorno!"
	_wake_label.add_theme_font_size_override("font_size", 30)
	_wake_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	_wake_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wake_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wake_label.modulate.a = 0.0
	_fade.add_child(_wake_label)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _sleeping:
		_prompt.visible = false
		return

	if _seated:
		_show_prompt("E — alzati", _player.global_position + Vector3(0, 1.4, 0), cam)
		return

	# il pezzo interagibile più vicino, entro un passetto
	_target = null
	var best := 1.45
	for it in _build.get_interactables():
		var node := it["node"] as Node3D
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best:
			best = d
			_target = node
			_target_name = it["name"]

	if _target:
		var text := "E — siediti"
		if _target_name == "Letto":
			text = "E — dormi fino al mattino" if _is_night() else "E — dormi"
			var home := get_node_or_null("../Home")
			if home:
				var cell := Vector2i(roundi(_target.position.x), roundi(_target.position.z))
				if not home.call("is_home", cell):
					text += "  ·  H — imposta casa"
		_show_prompt(text, _target.global_position + Vector3(0, 1.25, 0), cam)
	else:
		_prompt.visible = false


func _is_night() -> bool:
	return _daynight != null and _daynight.is_night()


func _show_prompt(text: String, world_pos: Vector3, cam: Camera3D) -> void:
	if cam.is_position_behind(world_pos):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(world_pos)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _sleeping:
		return
	if _seated:
		# la seduta è NOSTRA: alzarsi funziona anche a fisica congelata
		_stand_up()
		get_viewport().set_input_as_handled()
	elif _target and is_instance_valid(_target):
		# ma non ci si siede sopra il congelamento di un altro sistema
		# (onsen, lavagna, cucina…): scongelarlo dopo sarebbe un furto
		if not _player.is_physics_processing():
			return
		_sit_down(_target, _target_name)
		get_viewport().set_input_as_handled()


# il tween sit/stand corrente: uno solo alla volta, o il callback
# ritardato di _stand_up riattiva la fisica mentre Mochi si è già riseduta
var _move_tw: Tween


func _sit_down(seat: Node3D, kind: String) -> void:
	_seated = true
	_return_pos = _player.global_position
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO

	var dest: Vector3 = seat.global_transform * (SEATS[kind] as Vector3)
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	_move_tw.tween_property(_player, "global_position", dest, 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Mochi si gira dando le spalle allo schienale e si raccoglie
	_mochi.set("_yaw", seat.rotation.y + PI)
	_mochi.call("set_pose", "sleep" if kind == "Letto" else "sit")
	if _sfx:
		_sfx.play("step_wood2", -16.0, 0.7)

	# a letto di notte non è un pisolino: si dorme fino al mattino
	if kind == "Letto" and _is_night():
		_sleep_until_morning()


func _stand_up() -> void:
	_seated = false
	_mochi.call("set_pose", "stand")
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	_move_tw.tween_property(_player, "global_position", _return_pos, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tw.tween_callback(func():
		if not _seated:
			_player.set_physics_process(true))
	if _sfx:
		_sfx.play("step_wood1", -16.0, 0.8)


## La notte scivola via: qualche "z", il sipario cala, il sole torna al
## mattino con la stamina piena, e Mochi si rialza da sola.
func _sleep_until_morning() -> void:
	_sleeping = true
	get_tree().call_group("regista", "note", "dormita")
	await get_tree().create_timer(2.1).timeout

	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	await tw.finished

	_daynight.set_time(_daynight.MORNING)
	var sc: Node = _player.get_node_or_null("SurvivalComponent")
	if sc:
		sc.set_stamina(sc.get_max_stamina())
	_wake_label.text = "Buongiorno!\nGiorno %d" % _daynight.day
	if _sfx:
		_sfx.wake_up()

	# "Buongiorno!" sul buio, poi il sipario si riapre sul nuovo giorno
	var lt := create_tween()
	lt.tween_property(_wake_label, "modulate:a", 1.0, 0.5)
	lt.tween_interval(1.1)
	lt.tween_property(_wake_label, "modulate:a", 0.0, 0.5)
	await lt.finished

	var ft := create_tween()
	ft.tween_property(_fade, "color:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	await ft.finished

	_sleeping = false
	_stand_up()


## Per la verifica CLI: teletrasporta il player vicino al primo pezzo
## del tipo dato e lo fa sedere/dormire.
func debug_sit(kind: String) -> void:
	if _seated:
		_seated = false
		_mochi.call("set_pose", "stand")
	for it in _build.get_interactables():
		if it["name"] == kind:
			var node := it["node"] as Node3D
			_player.global_position = node.global_position + Vector3(0, 0, 0.8)
			_sit_down(node, kind)
			return
