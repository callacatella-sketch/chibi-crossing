extends Node3D

## Il Grande Albero: il monumento al centro del prato. Cresce di giorno
## in giorno come un bonsai condiviso — da alberello a gigante in un
## mese di calendario — e sul suo tronco il gioco INCIDE gli eventi del
## villaggio: gli arrivi (♥), le fioriture (✿), i compleanni (★), le
## prime volte della collezione (♦). I segni salgono a spirale col
## passare della vita; con E, ai piedi dell'albero, si leggono gli
## anelli: la cronaca del villaggio. Tutto persistito nel JSON.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")

const POS := Vector3(-4.0, 0.0, -2.0)
const UI_BROWN := Color("6a4a3a")

var _events: Array = []          # [{d, i, t}] in ordine di incisione
var _today_tags := {}            # dedup degli eventi "una volta al giorno"
var _forced_day := -1

var _daynight: Node3D
var _player: Node3D
var _sfx
var _tree_root: Node3D
var _marks_root: Node3D
var _swing: Node3D
var _col_shape: CollisionShape3D
var _stage := -1.0
var _t := 0.0

var _near := false
var _open := false
var _prompt: PanelContainer
var _prompt_label: Label
var _panel: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("grande_albero")
	position = POS
	_sfx = get_node_or_null(^"/root/Sfx")

	var body := StaticBody3D.new()
	_col_shape = CollisionShape3D.new()
	_col_shape.shape = CylinderShape3D.new()
	_col_shape.position = Vector3(0, 1.0, 0)
	body.add_child(_col_shape)
	add_child(body)

	_marks_root = Node3D.new()
	add_child(_marks_root)
	_build_ui()

	(func():
		# figlio runtime di CozyWorld: %Player non risolve, path relativo
		_player = get_node_or_null("../../Player")
		_daynight = get_node_or_null("../../DayNight")
		if _daynight:
			_daynight.day_changed.connect(_on_new_day)
		_rebuild(false)).call_deferred()


func _day() -> int:
	if _forced_day >= 0:
		return _forced_day
	return int(_daynight.get("day")) if _daynight else 1


# da alberello a gigante in circa un mese, con la curva dolce dei bonsai
func _stage_for(day: int) -> float:
	return clampf(pow(float(day) / 30.0, 0.62), 0.12, 1.0)


# ---------------------------------------------------------------- incisioni

## Incide un evento sugli anelli: un segno sul tronco, una riga nella
## cronaca. La linfa fa una piccola festa di scintille dorate.
func engrave(icon: String, text: String) -> void:
	_events.append({"d": _day(), "i": icon, "t": text})
	if _events.size() > 40:
		_events = _events.slice(_events.size() - 40)
	_refresh_marks()
	_sparkle(global_position + Vector3(0, 1.3, 0), 14)
	if _sfx:
		_sfx.rotate_tick()
	var build := get_tree().get_first_node_in_group("build_system")
	if build:
		build._save_village()


## Come engrave, ma al massimo una volta al giorno per etichetta
## (le fioriture non riempiono il tronco).
func engrave_once(tag: String, icon: String, text: String) -> void:
	var key := "%s|%d" % [tag, _day()]
	if _today_tags.has(key):
		return
	# _today_tags non è persistito: dopo un reload il dedup si ricostruisce
	# dalla cronaca stessa (stesso giorno + stesso testo = già inciso)
	for ev in _events:
		if int(ev.get("d", -1)) == _day() and str(ev.get("t", "")) == text:
			_today_tags[key] = true
			return
	_today_tags[key] = true
	engrave(icon, text)


func _on_new_day(day: int) -> void:
	_today_tags.clear()
	# il compleanno del villaggio, una candelina a settimana
	if day > 0 and day % 7 == 0:
		@warning_ignore("integer_division")
		engrave("★", "il villaggio compie %d settimane" % (day / 7))
	_rebuild(true)


# ---------------------------------------------------------------- l'albero

func _pm(a: Color, b: Color, grain := 3.0, amount := 0.5, wind := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	mat.set_shader_parameter("wind_strength", wind)
	return mat


func _rebuild(animate: bool) -> void:
	var s := _stage_for(_day())
	if absf(s - _stage) < 0.001:
		return
	var prev := _stage
	_stage = s
	if _tree_root:
		_tree_root.queue_free()
	_tree_root = Node3D.new()
	add_child(_tree_root)

	var h := 1.7 + 5.0 * s
	var r := 0.30 + 0.55 * s
	var cr := 1.0 + 3.0 * s
	var bark := _pm(Color("8a5f43"), Color("6f4a33"), 2.5, 0.55)
	var leaf := _pm(Color("7fbc62"), Color("5f9c48"), 2.0, 0.6, 0.02)
	var leaf2 := _pm(Color("97cc74"), Color("74b05c"), 2.0, 0.6, 0.02)
	var blossom := _pm(Color("ffc2d4"), Color("f5a8c0"), 2.5, 0.5, 0.02)

	# il tronco possente, coi fianchi che si allargano alla base
	BUILDER.lathe(_tree_root, [Vector2(r * 1.65, 0.0), Vector2(r * 1.12, 0.4),
			Vector2(r * 0.95, h * 0.38), Vector2(r * 0.78, h * 0.72),
			Vector2(r * 0.6, h), Vector2(r * 0.3, h * 1.04)], bark, Vector3.ZERO, 20)
	# radici che artigliano il prato
	for i in 6:
		var a := float(i) / 6.0 * TAU + 0.35
		var dir := Vector3(cos(a), 0, sin(a))
		BUILDER.tube(_tree_root, [dir * r * 0.7 + Vector3(0, 0.34, 0),
				dir * r * 1.5 + Vector3(0, 0.1, 0), dir * r * 2.3],
				[r * 0.3, r * 0.2, r * 0.07], bark, 10, 8)
	# rami che reggono la chioma
	if s > 0.3:
		for i in 4:
			var a := float(i) / 4.0 * TAU + 0.8
			var dir := Vector3(cos(a), 0, sin(a))
			BUILDER.tube(_tree_root, [Vector3(0, h * 0.82, 0) + dir * r * 0.4,
					Vector3(0, h * 0.98, 0) + dir * cr * 0.42,
					Vector3(0, h * 1.12, 0) + dir * cr * 0.62],
					[r * 0.34, r * 0.22, r * 0.1], bark, 10, 8)

	# la chioma: un cumulo di nuvole verdi con due sbuffi in fiore
	var cc := Vector3(0, h + cr * 0.42, 0)
	_ball(_tree_root, cr, leaf, cc)
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.5
		_ball(_tree_root, cr * 0.62, leaf2 if i % 2 == 0 else leaf,
				cc + Vector3(cos(a) * cr * 0.72, randf_range(-0.15, 0.3) * cr, sin(a) * cr * 0.72))
	_ball(_tree_root, cr * 0.55, leaf2, cc + Vector3(0, cr * 0.7, 0))
	_ball(_tree_root, cr * 0.3, blossom, cc + Vector3(cr * 0.55, cr * 0.5, cr * 0.35))
	_ball(_tree_root, cr * 0.26, blossom, cc + Vector3(-cr * 0.6, cr * 0.35, -cr * 0.3))

	# dal ramo basso, l'altalena di corda che aspetta qualcuno
	_swing = null
	if s > 0.5:
		var branch_a := 0.8
		var bdir := Vector3(cos(branch_a), 0, sin(branch_a))
		_swing = Node3D.new()
		_swing.position = Vector3(0, h * 0.98, 0) + bdir * cr * 0.42
		_tree_root.add_child(_swing)
		var rope := _pm(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
		var drop := h * 0.98 - 0.55
		for side: float in [-0.14, 0.14]:
			_cyl(_swing, 0.016, drop, rope, Vector3(side, -drop * 0.5, 0))
		var plank := MeshInstance3D.new()
		var pmsh := BoxMesh.new()
		pmsh.size = Vector3(0.44, 0.04, 0.18)
		plank.mesh = pmsh
		plank.material_override = _pm(Color("c89a6b"), Color("a87c50"), 4.0, 0.5)
		plank.position = Vector3(0, -drop, 0)
		_swing.add_child(plank)

	(_col_shape.shape as CylinderShape3D).radius = r * 1.2
	(_col_shape.shape as CylinderShape3D).height = 2.2

	_refresh_marks()

	# il momento magico: all'alba l'albero si stira di un altro anello
	if animate and prev > 0.0:
		_tree_root.scale = Vector3.ONE * (prev / s)
		var tw := create_tween()
		tw.tween_property(_tree_root, "scale", Vector3.ONE, 1.6) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_sparkle(global_position + Vector3(0, h * 0.7, 0), 26)
		if _sfx:
			_sfx.build_open()


func _ball(parent: Node3D, radius: float, mat: Material, pos: Vector3) -> void:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _cyl(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# i segni incisi: salgono a spirale lungo il tronco, uno per evento
func _refresh_marks() -> void:
	for c in _marks_root.get_children():
		c.queue_free()
	var h := 1.7 + 5.0 * _stage
	var r := 0.30 + 0.55 * _stage
	var visible_events: Array = _events.slice(maxi(0, _events.size() - 20))
	for i in visible_events.size():
		var ev: Dictionary = visible_events[i]
		var a := float(i) * 2.4 + 0.7
		var mh := 0.5 + float(i) * (h * 0.62 - 0.5) / 20.0
		var mr: float = lerpf(r * 1.12, r * 0.75, mh / h) + 0.012
		var mark := Label3D.new()
		mark.text = str(ev["i"])
		mark.font_size = 44
		mark.pixel_size = 0.0034
		mark.modulate = Color("4a3222")
		mark.outline_size = 8
		mark.outline_modulate = Color("9a7050", 0.75)
		mark.position = Vector3(cos(a) * mr, mh, sin(a) * mr)
		mark.rotation.y = PI * 0.5 - a
		_marks_root.add_child(mark)


func _sparkle(pos: Vector3, amount: int) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.93, 0.6, 0.95), Color(1.0, 0.93, 0.6, 0.5), Color(1.0, 0.93, 0.6, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 0.4, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var burst := GPUParticles3D.new()
	burst.amount = amount
	burst.lifetime = 1.3
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	get_tree().current_scene.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)


# ---------------------------------------------------------------- vita

func _process(delta: float) -> void:
	_t += delta
	# l'altalena ondeggia nella brezza
	if _swing:
		_swing.rotation.z = sin(_t * 0.9) * 0.05
		_swing.rotation.x = sin(_t * 0.55 + 1.0) * 0.03
	_update_near()
	_update_prompt()


func _update_near() -> void:
	if _player == null or _open:
		return
	_near = _player.global_position.distance_to(global_position) < 2.8


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _open:
		_close_panel()
		get_viewport().set_input_as_handled()
	elif _near:
		_open_panel()
		get_viewport().set_input_as_handled()


func _open_panel() -> void:
	_open = true
	if _player:
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
	_refresh_panel()
	_panel.visible = true
	if _sfx:
		_sfx.build_open()


func _close_panel() -> void:
	_open = false
	_panel.visible = false
	if _player:
		_player.set_physics_process(true)
	if _sfx:
		_sfx.build_close()


func _refresh_panel() -> void:
	for c in _rows.get_children():
		c.queue_free()
	if _events.is_empty():
		var row := Label.new()
		row.text = "Il legno è ancora giovane e liscio.\nGli anelli aspettano la vostra storia."
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color(UI_BROWN, 0.7))
		_rows.add_child(row)
		return
	var latest: Array = _events.slice(maxi(0, _events.size() - 12))
	latest.reverse()
	for ev: Dictionary in latest:
		var row := Label.new()
		row.text = "Giorno %d   %s  %s" % [int(ev["d"]), str(ev["i"]), str(ev["t"])]
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", UI_BROWN)
		_rows.add_child(row)


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not _near or _open:
		_prompt.visible = false
		return
	var wp := global_position + Vector3(0, 2.4, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _build_ui() -> void:
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
	_prompt_label.text = "E — gli anelli del Grande Albero"
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)

	_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fdf6e3")
	ms.set_corner_radius_all(16)
	ms.border_color = Color(0.62, 0.46, 0.34, 0.55)
	ms.set_border_width_all(2)
	ms.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	ms.shadow_size = 12
	ms.content_margin_left = 26.0
	ms.content_margin_right = 26.0
	ms.content_margin_top = 16.0
	ms.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", ms)
	_panel.custom_minimum_size = Vector2(430, 0)
	_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)
	var title := Label.new()
	title.text = "~ Gli anelli del Grande Albero ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)
	var hint := Label.new()
	hint.text = "E — chiudi"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for ev: Dictionary in _events:
		rows.append([int(ev["d"]), str(ev["i"]), str(ev["t"])])
	return {"tree_events": rows}


func load_extra(data: Dictionary) -> void:
	var rows: Array = data.get("tree_events", [])
	if rows.is_empty():
		return
	_events.clear()
	for r in rows:
		if r is Array and r.size() == 3:
			_events.append({"d": int(r[0]), "i": str(r[1]), "t": str(r[2])})
	_refresh_marks()


# ---------------------------------------------------------------- debug CLI

func debug_showcase(day: int) -> void:
	_forced_day = day
	_events = []
	engrave("✿", "la prima fioritura del giardino")
	_events[0]["d"] = 3
	for sample in [[5, "♥", "Nocciola si è trasferita nel villaggio"],
			[7, "★", "il villaggio compie 1 settimana"],
			[9, "♦", "in collezione: una farfalla rosa"],
			[14, "★", "il villaggio compie 2 settimane"],
			[16, "♥", "Miele si è trasferito nel villaggio"],
			[19, "✿", "una fioritura nel giardino"],
			[22, "♦", "in collezione: una lucciola"],
			[24, "★", "è nata una casa sull'albero"]]:
		_events.append({"d": sample[0], "i": sample[1], "t": sample[2]})
	_stage = -1.0
	_rebuild(false)


func debug_open() -> void:
	_open_panel()


func debug_close() -> void:
	_close_panel()
