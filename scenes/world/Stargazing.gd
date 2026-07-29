extends Node3D

## Le costellazioni di Mochi. Di notte, E sull'erba libera: Mochi si
## sdraia a pancia in su e la camera sale piano verso il cielo. Le 260
## stelle della cupola si uniscono come un puntini-da-collegare: clic
## su una stella, poi la prossima, e la tua costellazione prende forma;
## dalle un nome e da quella notte ESISTE PER SEMPRE — linee sottili
## che si accendono al crepuscolo, il nome sospeso tra le stelle, e
## l'evento inciso negli anelli del Grande Albero. Ogni tanto una
## stella cadente attraversa il cielo: SPAZIO per esprimere un
## desiderio… e qualche mattina dopo, nella posta, qualcosa arriva.

const UI_BROWN := Color("6a4a3a")
const STAR_R := 52.0
const LINE_COL := Color(1.0, 0.94, 0.72)

var _daynight: Node3D
var _player: Node3D
var _mochi: Node3D
var _build: Node3D
var _mail: Node
var _sfx

# {name: String, stars: Array[int]} — per sempre
var _constellations: Array = []
var _lines_root: Node3D
var _line_meshes: Array[MeshInstance3D] = []
var _lines_alpha := 0.0

# la sessione di osservazione
var _mode := false
var _chain: Array[int] = []
var _hovered := -1
var _cam: Camera3D
var _prev_cam: Camera3D

# la stella cadente e il desiderio
var _meteor: Node3D
var _meteor_t := -1.0
var _meteor_from := Vector3.ZERO
var _meteor_to := Vector3.ZERO
var _next_meteor := 30.0
var _wish_day := -1

var _overlay: Control
var _prompt: PanelContainer
var _prompt_label: Label
var _name_panel: PanelContainer
var _name_edit: LineEdit


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("stelle")
	_sfx = get_node_or_null(^"/root/Sfx")
	_lines_root = Node3D.new()
	add_child(_lines_root)
	_build_ui()
	(func():
		_player = get_node_or_null("../../Player")
		_daynight = get_node_or_null("../../DayNight")
		_build = get_tree().get_first_node_in_group("build_system")
		_mail = get_node_or_null("../../Mail")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		if _daynight:
			_daynight.day_changed.connect(_on_new_day)).call_deferred()


func _star_pos(i: int) -> Vector3:
	return (_daynight.star_dirs[i] as Vector3) * STAR_R


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	# le linee si accendono al crepuscolo, come le stelle
	var want := 1.0 if (_daynight and _daynight.is_night()) else 0.0
	_lines_alpha = lerpf(_lines_alpha, want, 1.0 - exp(-2.5 * delta))
	_lines_root.visible = _lines_alpha > 0.02
	for mi in _line_meshes:
		mi.transparency = 1.0 - _lines_alpha

	_update_meteor(delta)
	_update_prompt()
	if _mode:
		_update_hover()
		_overlay.queue_redraw()


func _can_start() -> bool:
	if _daynight == null or not _daynight.is_night() or _player == null:
		return false
	# se Mochi è già impegnata (onsen, cucina, dormita), niente stelle
	if not _player.is_physics_processing():
		return false
	if _player.global_position.y > 0.5:
		return false
	if _build and _build.call("is_active"):
		return false
	if _build and _build.call("surface_at", _player.global_position) != "grass":
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _mode:
		_mode_input(event)
		return
	# arriva qui solo se nessun altro sistema ha voluto la E
	if event.is_action_pressed("interact") and _can_start():
		_enter_mode()
		get_viewport().set_input_as_handled()


func _mode_input(event: InputEvent) -> void:
	if _name_panel.visible:
		return
	if event.is_action_pressed("interact"):
		if _chain.size() >= 3:
			_open_name_panel()
		else:
			_exit_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _meteor_t >= 0.0 and _wish_day < 0:
		# il desiderio alla stella cadente (e si salva subito: un desiderio
		# non si perde per un'uscita dal gioco)
		_wish_day = _day() + 2 + randi() % 2
		if _build:
			_build.request_save()
		_toast(L10n.t("Hai espresso un desiderio… la stella l'ha sentito."))
		_sparkle_at(_player.global_position + Vector3(0, 1.2, 0))
		if _sfx:
			_sfx.build_open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _hovered >= 0:
			if _chain.is_empty() or _chain[-1] != _hovered:
				_chain.append(_hovered)
				if _sfx:
					_sfx.play("tick", -16.0, 1.0 + _chain.size() * 0.06)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not _chain.is_empty():
			_chain.pop_back()
			if _sfx:
				_sfx.play("tick", -18.0, 0.8)
			get_viewport().set_input_as_handled()


func _enter_mode() -> void:
	_mode = true
	_chain.clear()
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	if _mochi:
		_mochi.call("set_pose", "stargaze")
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 58.0
	_cam.global_transform = _prev_cam.global_transform
	_cam.current = true
	# la camera sale piano e si volta verso la cupola
	var target_pos: Vector3 = _player.global_position + Vector3(0, 1.5, 2.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cam, "global_position", target_pos, 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var look := Transform3D(Basis.looking_at(
			(_player.global_position + Vector3(0, 34, -26)) - target_pos, Vector3.UP), target_pos)
	tw.tween_property(_cam, "global_transform", look, 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_overlay.visible = true
	# la prima stella cadente non si fa aspettare troppo
	_next_meteor = minf(_next_meteor, randf_range(8.0, 16.0))
	if _sfx:
		_sfx.build_open()


func _exit_mode() -> void:
	_mode = false
	_overlay.visible = false
	_name_panel.visible = false
	if _mochi:
		_mochi.call("set_pose", "stand")
	if _prev_cam:
		_prev_cam.make_current()
	if _cam:
		_cam.queue_free()
		_cam = null
	_player.set_physics_process(true)
	if _sfx:
		_sfx.build_close()


# ---------------------------------------------------------------- disegno

func _update_hover() -> void:
	_hovered = -1
	if _daynight == null or _cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var best := 26.0
	for i in _daynight.star_dirs.size():
		var wp := _star_pos(i)
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		var d := sp.distance_to(mouse)
		if d < best:
			best = d
			_hovered = i


func _draw_overlay() -> void:
	if not _mode or _cam == null or _daynight == null:
		return
	# la catena già tracciata
	for k in maxi(_chain.size() - 1, 0):
		var a := _cam.unproject_position(_star_pos(_chain[k]))
		var b := _cam.unproject_position(_star_pos(_chain[k + 1]))
		_overlay.draw_line(a, b, Color(LINE_COL, 0.85), 2.0, true)
	# dal capo della catena al mouse
	if not _chain.is_empty() and not _name_panel.visible:
		var a := _cam.unproject_position(_star_pos(_chain[-1]))
		_overlay.draw_line(a, get_viewport().get_mouse_position(), Color(LINE_COL, 0.32), 1.5, true)
	# le stelle scelte e quella sotto il mouse
	for idx in _chain:
		_overlay.draw_circle(_cam.unproject_position(_star_pos(idx)), 5.0, Color(LINE_COL, 0.9))
	if _hovered >= 0 and not _cam.is_position_behind(_star_pos(_hovered)):
		_overlay.draw_arc(_cam.unproject_position(_star_pos(_hovered)), 10.0,
				0.0, TAU, 24, Color(1, 1, 1, 0.85), 2.0, true)


# ---------------------------------------------------------------- il nome

func _open_name_panel() -> void:
	_name_panel.visible = true
	_name_edit.text = ""
	_name_edit.placeholder_text = L10n.tf("Costellazione %d", [_constellations.size() + 1])
	_name_edit.grab_focus()


func _confirm_name() -> void:
	var cname := _name_edit.text.strip_edges()
	if cname == "":
		cname = _name_edit.placeholder_text
	_constellations.append({"name": cname, "stars": _chain.duplicate()})
	get_tree().call_group("regista", "note", "stelle")
	# la prima costellazione battezzata è un ricordo indossabile
	get_tree().call_group("guardaroba", "unlock", "cerchietto_stelle")
	_rebuild_lines()
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree:
		gtree.engrave("★", "nasce la costellazione «%s»" % cname)
	_toast(L10n.tf("«%s» brilla nel cielo, da stanotte e per sempre.", [cname]))
	if _build:
		_build.request_save()
	if _sfx:
		_sfx.place_ok()
	_exit_mode()


# le linee vere, sottili, dentro la cupola: nastri emissivi rivolti
# verso il prato, con il nome sospeso al centro
func _rebuild_lines() -> void:
	for c in _lines_root.get_children():
		c.queue_free()
	_line_meshes.clear()
	if _daynight == null:
		return
	for con: Dictionary in _constellations:
		var stars: Array = con["stars"]
		if stars.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var centroid := Vector3.ZERO
		for k in stars.size() - 1:
			var a := _star_pos(int(stars[k])) * 0.985
			var b := _star_pos(int(stars[k + 1])) * 0.985
			centroid += a
			var side := (b - a).cross(a.normalized()).normalized() * 0.12
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				st.set_normal(-a.normalized())
				st.add_vertex(v)
		centroid = (centroid + _star_pos(int(stars[-1])) * 0.985) / float(stars.size())
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(LINE_COL, 0.5)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lines_root.add_child(mi)
		_line_meshes.append(mi)

		var label := Label3D.new()
		label.text = str(con["name"])
		label.font_size = 96
		label.pixel_size = 0.02
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 0.96, 0.8, 0.85)
		label.outline_size = 10
		label.outline_modulate = Color(0.2, 0.2, 0.4, 0.4)
		label.position = centroid.normalized() * STAR_R * 0.94 + Vector3(0, 1.6, 0)
		_lines_root.add_child(label)


# ---------------------------------------------------------------- la cadente

func _update_meteor(delta: float) -> void:
	if _daynight == null or not _daynight.is_night():
		# l'alba a meteora in volo: si dissolve, non resta inchiodata in cielo
		if _meteor_t >= 0.0:
			_meteor_t = -1.0
			if _meteor:
				_meteor.queue_free()
				_meteor = null
		return
	if _meteor_t < 0.0:
		_next_meteor -= delta
		if _next_meteor <= 0.0:
			_next_meteor = randf_range(40.0, 90.0)
			_spawn_meteor()
		return
	_meteor_t += delta / 2.2
	if _meteor_t >= 1.0:
		_meteor_t = -1.0
		if _meteor:
			_meteor.queue_free()
			_meteor = null
		return
	if _meteor:
		var p := _meteor_from.slerp(_meteor_to, _meteor_t)
		_meteor.global_position = p


func _spawn_meteor() -> void:
	var a := randf() * TAU
	var b := a + randf_range(0.7, 1.3)
	_meteor_from = Vector3(cos(a) * 0.8, randf_range(0.55, 0.9), sin(a) * 0.8).normalized() * (STAR_R * 0.96)
	_meteor_to = Vector3(cos(b) * 0.9, randf_range(0.25, 0.5), sin(b) * 0.9).normalized() * (STAR_R * 0.96)
	_meteor = Node3D.new()
	add_child(_meteor)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.34
	hm.height = 0.68
	head.mesh = hm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.98, 0.88)
	head.material_override = mat
	_meteor.add_child(head)
	# la scia
	var trail := _make_trail()
	_meteor.add_child(trail)
	_meteor.global_position = _meteor_from
	_meteor_t = 0.0
	if _sfx:
		_sfx.play("tick", -20.0, 2.0)


func _make_trail() -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.97, 0.85, 0.9), Color(1.0, 0.9, 0.7, 0.4), Color(1.0, 0.85, 0.6, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.ZERO
	pm.spread = 0.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var trail := GPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 1.1
	trail.local_coords = false
	trail.process_material = pm
	trail.draw_pass_1 = quad
	return trail


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


func _on_new_day(day: int) -> void:
	# il desiderio maturato arriva con la posta del mattino
	if _wish_day >= 0 and day >= _wish_day and _mail:
		_mail.call("queue_letter", {
			"from_key": "La stella cadente",
			"text_key": "Quella notte ti ho sentito, sai?\nI desideri sussurrati nell'erba\narrivano sempre, prima o poi.",
			"gift": true,
		})
		_wish_day = -1
		if _build:
			_build.request_save()


# ---------------------------------------------------------------- UI

func _toast(text: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", text)


func _sparkle_at(pos: Vector3) -> void:
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree:
		gtree.call("_sparkle", pos, 16)


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if _mode:
		_prompt_label.text = L10n.t("clic — unisci le stelle  ·  destro — annulla  ·  E — dai il nome") \
				if _chain.size() >= 3 else \
				L10n.tf("clic — unisci le stelle (%d/3)  ·  E — torna giù", [_chain.size()])
		if _meteor_t >= 0.0 and _wish_day < 0:
			_prompt_label.text += "  ·  " + L10n.t("SPAZIO — esprimi un desiderio!")
		_prompt.reset_size()
		_prompt.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 \
				- _prompt.size.x * 0.5, 40)
		_prompt.visible = not _name_panel.visible
		return
	if cam == null or not _can_start():
		_prompt.visible = false
		return
	var wp: Vector3 = _player.global_position + Vector3(0, 1.35, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.t("E — sdraiati a guardare le stelle")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.draw.connect(_draw_overlay)
	layer.add_child(_overlay)

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
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)

	# il pannellino del battesimo
	_name_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fdf6e3")
	ms.set_corner_radius_all(14)
	ms.border_color = Color(0.62, 0.46, 0.34, 0.55)
	ms.set_border_width_all(2)
	ms.content_margin_left = 20.0
	ms.content_margin_right = 20.0
	ms.content_margin_top = 12.0
	ms.content_margin_bottom = 12.0
	_name_panel.add_theme_stylebox_override("panel", ms)
	_name_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_name_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_name_panel.add_child(vbox)
	var title := Label.new()
	title.text = L10n.t("Come si chiama la tua costellazione?")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(280, 0)
	_name_edit.max_length = 28
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	vbox.add_child(_name_edit)
	var hint := Label.new()
	hint.text = L10n.t("Invio — battezzala")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for c: Dictionary in _constellations:
		rows.append([str(c["name"]), (c["stars"] as Array).duplicate()])
	return {"constellations": rows, "wish_day": _wish_day}


func load_extra(data: Dictionary) -> void:
	_wish_day = int(data.get("wish_day", -1))
	var rows: Array = data.get("constellations", [])
	if rows.is_empty():
		return
	_constellations.clear()
	for r in rows:
		if r is Array and r.size() == 2:
			_constellations.append({"name": str(r[0]), "stars": r[1]})
	(func(): _rebuild_lines()).call_deferred()


# una catena di stelle vicine, a partire da una stella data
func _catena_da(start: int) -> Array[int]:
	var chain: Array[int] = [start]
	var used := {start: true}
	for step in 5:
		var last := _star_pos(chain[-1])
		var best := -1
		var best_d := 24.0
		for i in _daynight.star_dirs.size():
			if used.has(i):
				continue
			var d := last.distance_to(_star_pos(i))
			if d < best_d:
				best_d = d
				best = i
		if best < 0:
			break
		chain.append(best)
		used[best] = true
	return chain


## La costellazione di chi è partito per il Grande Prato (Fase 5 del Filo
## Rosso): le stelle le sceglie il SUO DNA (seed), il nome resta in cielo
## per sempre, persistito con le costellazioni di Mochi.
func memorial(cname: String, seed_v: int) -> void:
	for c: Dictionary in _constellations:
		if str(c["name"]) == cname:
			return  # è già lassù
	var start := absi(seed_v) % maxi(1, _daynight.star_dirs.size())
	_constellations.append({"name": cname, "stars": _catena_da(start)})
	_rebuild_lines()
	_toast(L10n.tf("✨ %s adesso abita lassù: guarda il cielo, stanotte.", [cname]))
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree:
		gtree.engrave("★", "la costellazione di %s è apparsa in cielo" % cname)
	if _build:
		_build.request_save()


# ---------------------------------------------------------------- debug CLI

## Traccia una costellazione d'ufficio: una catena di stelle vicine.
func debug_add(cname: String) -> void:
	_constellations.append({"name": cname, "stars": _catena_da(40)})
	_rebuild_lines()


func debug_enter() -> void:
	_enter_mode()


func debug_exit() -> void:
	_exit_mode()
