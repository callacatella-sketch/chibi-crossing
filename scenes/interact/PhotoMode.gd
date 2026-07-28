extends Node

## Modalità foto. P nasconde tutta la UI e libera la camera: WASD per
## volare, mouse per guardare, Q/E per scendere e salire, rotella per lo
## zoom, clic per scattare — flash, click e la foto finisce in
## user://photos. P (o Esc) per tornare al gioco. Il mondo continua a
## vivere davanti all'obiettivo: Mochi respira, le foglie cadono.

var _active := false
var _cam: Camera3D
var _prev_cam: Camera3D
var _hidden_layers: Array[CanvasLayer] = []
var _player: Node3D
var _sfx

var _yaw := 0.0
var _pitch := 0.0

var _layer: CanvasLayer
var _flash: ColorRect
var _hint: Label
var _toast: Label


func _ready() -> void:
	_player = get_node("%Player")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()


func is_active() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	# qui vive solo l'ACCENSIONE (così rispetta i modali che consumano prima);
	# da attiva, la modalità foto ascolta in _input e vince su tutti
	if event.is_action_pressed("photo_mode") and not _active:
		_set_active(true)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# ATTIVA, la modalità foto è un modale assoluto: intercetta in _input,
	# PRIMA di ogni _unhandled_input — i fratelli aggiunti a runtime (negozio,
	# pausa) ricevono l'unhandled prima di noi e si rubavano E/ESC dietro
	# la macchina fotografica (chiudendo pannelli e scongelando Mochi)
	if not _active:
		return
	if event.is_action_pressed("photo_mode"):
		_set_active(false)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_active(false)
	elif event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.0032
		_pitch = clampf(_pitch - event.relative.y * 0.0032, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_snap()
			MOUSE_BUTTON_WHEEL_UP:
				_cam.fov = clampf(_cam.fov - 3.0, 15.0, 90.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cam.fov = clampf(_cam.fov + 3.0, 15.0, 90.0)
	# in modalità foto il resto del gioco non ascolta i tasti
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return
	# se qualcun altro ha scongelato Mochi a metà volo (risveglio dal letto,
	# fine di un tween di alzata), in modalità foto si resta fermi: il
	# congelamento diventa NOSTRO e all'uscita verrà tolto
	if _player and _player.is_physics_processing():
		_player.set_physics_process(false)
		_player_was_frozen = false
	_cam.rotation = Vector3(_pitch, _yaw, 0)
	var speed := 6.0 * (2.5 if Input.is_action_pressed("ui_accept") else 1.0)
	var dir := Vector3.ZERO
	var basis := _cam.global_transform.basis
	if Input.is_action_pressed("ui_up"):
		dir -= basis.z
	if Input.is_action_pressed("ui_down"):
		dir += basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= basis.x
	if Input.is_action_pressed("ui_right"):
		dir += basis.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	if dir.length_squared() > 0.001:
		_cam.global_position += dir.normalized() * speed * delta
	_cam.global_position.y = maxf(_cam.global_position.y, 0.15)


var _player_was_frozen := false


func _set_active(active: bool) -> void:
	_active = active
	if active:
		_prev_cam = get_viewport().get_camera_3d()
		_cam = Camera3D.new()
		add_child(_cam)
		_cam.global_transform = _prev_cam.global_transform
		_cam.fov = _prev_cam.fov
		var e := _cam.global_transform.basis.get_euler()
		_pitch = e.x
		_yaw = e.y
		_cam.current = true
		# se il player era già congelato (seduto, a nanna…) il congelamento
		# non è nostro: all'uscita non va tolto
		_player_was_frozen = not _player.is_physics_processing()
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_hide_ui()
		_hint.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(_hint, "modulate:a", 0.0, 0.8)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_restore_ui()
		if _prev_cam:
			_prev_cam.make_current()
		if _cam:
			_cam.queue_free()
			_cam = null
		if not _player_was_frozen:
			_player.set_physics_process(true)


# via tutta la UI, tranne la vignetta (fa parte del look) e il nostro layer
func _hide_ui() -> void:
	_hidden_layers.clear()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl == _layer or cl.get_parent().name == "Vignette" or cl.name == "Vignette":
			continue
		if cl.visible:
			cl.visible = false
			_hidden_layers.append(cl)


func _restore_ui() -> void:
	for cl in _hidden_layers:
		if is_instance_valid(cl):
			cl.visible = true
	_hidden_layers.clear()


func _snap() -> void:
	# la foto dev'essere DAVVERO pulita: via le etichette (le nostre e
	# quelle delle richieste foto), un frame di render senza UI, e solo
	# allora si cattura — niente scritte cotte dentro i ricordi
	_layer.visible = false
	get_tree().call_group("richieste_foto", "nascondi_hud")
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_layer.visible = true
	DirAccess.make_dir_recursive_absolute("user://photos")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	img.save_png("user://photos/foto_%s.png" % stamp)
	get_tree().call_group("regista", "note", "foto")
	# le richieste fotografiche: se lo scatto esaudisce il sogno di un
	# residente, la foto finisce incorniciata in casa sua
	get_tree().call_group("richieste_foto", "scatto", img)
	if _sfx:
		_sfx.camera_click()
	_flash.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, 0.28)
	_toast.text = L10n.t("Foto salvata!  (user://photos)")
	_toast.modulate.a = 1.0
	var tt := create_tween()
	tt.tween_interval(1.6)
	tt.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1)
	_flash.modulate.a = 0.0
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)

	_hint = Label.new()
	_hint.text = L10n.t("WASD vola · mouse guarda · Q/E giù/su · rotella zoom · clic scatta · P esci")
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hint.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.1, 0.6))
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -46.0
	_hint.offset_bottom = -22.0
	_hint.offset_left = -320.0
	_hint.offset_right = 320.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	_layer.add_child(_hint)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 15)
	_toast.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_toast.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.1, 0.6))
	_toast.add_theme_constant_override("shadow_offset_y", 1)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 40.0
	_toast.offset_bottom = 66.0
	_toast.offset_left = -220.0
	_toast.offset_right = 220.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_layer.add_child(_toast)


# ---------------------------------------------------------------- debug CLI

func debug_enter(cam_pos: Vector3, look_at_pos: Vector3) -> void:
	_set_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam.global_position = cam_pos
	_cam.look_at(look_at_pos)
	var e := _cam.global_transform.basis.get_euler()
	_pitch = e.x
	_yaw = e.y


func debug_exit() -> void:
	_set_active(false)
