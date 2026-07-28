extends Node3D

## Il timelapse dei ricordi. Ogni mattina, poco dopo l'alba, il gioco
## scatta UNA foto del villaggio — sempre dalla stessa inquadratura,
## senza mai interrompere il gioco (un SubViewport dedicato che
## condivide il mondo renderizza un solo frame). Le foto si accumulano
## in user://ricordi/, e vicino al Grande Albero il tasto R monta IL
## FILM: il tuo villaggio che nasce, giorno per giorno, in dissolvenza.

const FRAME_POS := Vector3(8.0, 6.2, 10.0)
const FRAME_AT := Vector3(-0.5, 0.8, -0.8)
const UI_BROWN := Color("6a4a3a")

var _vp: SubViewport
var _cam: Camera3D
var _daynight: Node3D
var _player: Node3D
var _sfx
var _captured := {}

# il proiettore
var _film_layer: CanvasLayer
var _film_photo: TextureRect
var _film_label: Label
var _film_title: Label
var _playing := false
var _film_days: Array[int] = []


func _ready() -> void:
	add_to_group("ricordi")
	_sfx = get_node_or_null(^"/root/Sfx")
	(func(): _player = get_node_or_null("../../Player")).call_deferred()

	# la macchina fotografica nascosta: un viewport che condivide il
	# mondo e renderizza solo quando serve
	_vp = SubViewport.new()
	_vp.size = Vector2i(768, 432)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 46.0
	_vp.add_child(_cam)
	_cam.global_position = FRAME_POS
	_cam.look_at(FRAME_AT, Vector3.UP)

	_build_film_ui()
	(func():
		_daynight = get_node_or_null("../../DayNight")
		if _daynight:
			_daynight.day_changed.connect(_on_new_day)).call_deferred()


func _dir() -> String:
	var shot := OS.get_environment("CHIBI_SHOT")
	return shot.path_join("ricordi") if shot != "" else "user://ricordi"


func _on_new_day(day: int) -> void:
	# aspetta che il sipario del "Buongiorno" si apra, poi scatta
	await get_tree().create_timer(3.0).timeout
	capture(day)


## Scatta la foto del giorno (se non è già stata scattata).
func capture(day: int) -> void:
	if _captured.has(day):
		return
	DirAccess.make_dir_recursive_absolute(_dir())
	var path := _dir().path_join("giorno_%03d.png" % day)
	if FileAccess.file_exists(path):
		_captured[day] = true
		return
	_cam.global_position = FRAME_POS
	_cam.look_at(FRAME_AT, Vector3.UP)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img:
		img.save_png(path)
		_captured[day] = true
		if _sfx:
			_sfx.play("tick", -14.0, 1.4)


# ---------------------------------------------------------------- il film

func _unhandled_input(event: InputEvent) -> void:
	if _playing:
		if event.is_action_pressed("interact") or event.is_action_pressed("ricordi"):
			_stop_film()
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ricordi") or _player == null:
		return
	# la R in modalità build ruota il ghost: lì il proiettore non ascolta
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.call("is_active"):
		return
	# e se il player è congelato da un'altra modalità, nemmeno
	if not _player.is_physics_processing():
		return
	# il proiettore si accende solo ai piedi del Grande Albero
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree and _player.global_position.distance_to((gtree as Node3D).global_position) < 3.2:
		_play_film()
		get_viewport().set_input_as_handled()


func _film_list() -> Array[int]:
	var out: Array[int] = []
	var dir := DirAccess.open(_dir())
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("giorno_") and f.ends_with(".png"):
			out.append(int(f.substr(7, 3)))
	out.sort()
	return out


func _play_film() -> void:
	_film_days = _film_list()
	if _film_days.size() < 2:
		var visitors := get_node_or_null("../../Visitors")
		if visitors:
			visitors.call("_show_toast",
					L10n.t("Il proiettore aspetta almeno due mattine di ricordi…"))
		return
	_playing = true
	if _player:
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
	_film_layer.visible = true
	_film_title.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_film_title, "modulate:a", 1.0, 0.6)
	if _sfx:
		_sfx.build_open()
	_film_session += 1
	_run_film(_film_session)


# il token di sessione: se il film viene fermato e riavviato entro un
# await, la vecchia coroutine si accorge di non essere più lei e muore
var _film_session := 0


func _run_film(session: int) -> void:
	for day in _film_days:
		if not _playing or session != _film_session:
			return
		var img := Image.load_from_file(_dir().path_join("giorno_%03d.png" % day))
		if img == null:
			continue
		_film_photo.texture = ImageTexture.create_from_image(img)
		_film_label.text = L10n.tf("Giorno %d", [day])
		_film_photo.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_film_photo, "modulate:a", 1.0, 0.3)
		if _sfx:
			_sfx.play("tick", -18.0, 1.1)
		await get_tree().create_timer(1.1).timeout
	if not _playing or session != _film_session:
		return
	_film_label.text = L10n.t("…e la storia continua")
	await get_tree().create_timer(1.6).timeout
	if _playing and session == _film_session:
		_stop_film()


func _stop_film() -> void:
	_playing = false
	_film_layer.visible = false
	if _player:
		_player.set_physics_process(true)
	if _sfx:
		_sfx.build_close()


func _build_film_ui() -> void:
	_film_layer = CanvasLayer.new()
	_film_layer.layer = 6
	_film_layer.visible = false
	add_child(_film_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.06, 0.08, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film_layer.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	_film_title = Label.new()
	_film_title.text = L10n.t("~ I ricordi del villaggio ~")
	_film_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_film_title.add_theme_font_size_override("font_size", 20)
	_film_title.add_theme_color_override("font_color", Color("f2e8d5"))
	vbox.add_child(_film_title)

	# la foto in una cornice di carta crema
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fdf6e3")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	frame.add_theme_stylebox_override("panel", sb)
	vbox.add_child(frame)
	_film_photo = TextureRect.new()
	_film_photo.custom_minimum_size = Vector2(768, 432)
	_film_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_film_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_film_photo)

	_film_label = Label.new()
	_film_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_film_label.add_theme_font_size_override("font_size", 16)
	_film_label.add_theme_color_override("font_color", Color("f2e8d5"))
	vbox.add_child(_film_label)

	var hint := Label.new()
	hint.text = L10n.t("E — chiudi il proiettore")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.95, 0.91, 0.84, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- debug CLI

func debug_capture(day: int) -> void:
	await capture(day)


func debug_film() -> void:
	_play_film()
