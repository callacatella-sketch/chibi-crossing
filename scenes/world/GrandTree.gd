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
const GEO_ALBERO := preload("res://scenes/world/AlberoGeo.gd")

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

# le maniglie della chioma, tenute vive: la stagione le ridipinge senza
# ricostruire l'albero (che si rifà solo quando cresce di un anello)
var _leaf_mat: ShaderMaterial
var _leaf2_mat: ShaderMaterial
var _blossom_mat: ShaderMaterial
var _season_tw: Tween

var _near := false
var _open := false
var _prompt: PanelContainer
var _prompt_label: Label
var _panel: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("grande_albero")
	add_to_group("season_listener")
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
	return GEO_ALBERO.stage_per_giorno(day)


# ---------------------------------------------------------------- incisioni

## Incide un evento sugli anelli: un segno sul tronco, una riga nella
## cronaca. La linfa fa una piccola festa di scintille dorate.
## `text` È LA CHIAVE ITALIANA, e `args` i suoi pezzi: la cronaca vive nel
## SALVATAGGIO e si legge anni dopo, magari in un'altra lingua. Chi
## formattava prima (`"nasce la costellazione «%s»" % nome`) incideva una
## riga che in tabella non c'è, e restava italiana per sempre; chi traduceva
## prima incideva la lingua di quel momento, per sempre. Si traduce solo
## dove si MOSTRA, ed è scritto anche là.
func engrave(icon: String, text: String, args: Array = []) -> void:
	_events.append({"d": _day(), "i": icon, "t": text, "a": args})
	if _events.size() > 40:
		_events = _events.slice(_events.size() - 40)
	_refresh_marks()
	_sparkle(global_position + Vector3(0, 1.3, 0), 14)
	if _sfx:
		_sfx.rotate_tick()
	var build := get_tree().get_first_node_in_group("build_system")
	if build:
		build.request_save()


## Come engrave, ma al massimo una volta al giorno per etichetta
## (le fioriture non riempiono il tronco).
func engrave_once(tag: String, icon: String, text: String, args: Array = []) -> void:
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

	# la forma vive in AlberoGeo: la costruisce anche il diorama del menù,
	# che deve mostrare l'albero VERO di questo salvataggio (vedi
	# scenes/world/AlberoGeo.gd)
	var mats := GEO_ALBERO.materiali(_season())
	_leaf_mat = mats["leaf"]
	_leaf2_mat = mats["leaf2"]
	_blossom_mat = mats["blossom"]
	var fatto := GEO_ALBERO.costruisci(_tree_root, s, mats)
	var h: float = fatto["h"]
	var r: float = fatto["r"]
	_swing = fatto["swing"]

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


# ---------------------------------------------------------------- stagioni

func _season() -> int:
	if _daynight and _daynight.has_method("get_season"):
		return int(_daynight.get_season())
	return 0


# la tinta della chioma del Grande Albero secondo la stagione (stessa
# logica del bosco: il valore si conserva, così gli strati restano leggibili)
func _leaf_col(c: Color, season: int, is_blossom: bool) -> Color:
	return GEO_ALBERO.colore_foglia(c, season, is_blossom)


## Il regista delle stagioni chiama qui: ridipinge la chioma già costruita.
func set_season(season: int, _snow: float, transition: bool) -> void:
	if _leaf_mat == null:
		return  # non ancora costruito: _rebuild nascerà già col colore giusto
	var targets := [
		[_leaf_mat, "color_a", _leaf_col(Color("7fbc62"), season, false)],
		[_leaf_mat, "color_b", _leaf_col(Color("5f9c48"), season, false)],
		[_leaf2_mat, "color_a", _leaf_col(Color("97cc74"), season, false)],
		[_leaf2_mat, "color_b", _leaf_col(Color("74b05c"), season, false)],
		[_blossom_mat, "color_a", _leaf_col(Color("ffc2d4"), season, true)],
		[_blossom_mat, "color_b", _leaf_col(Color("f5a8c0"), season, true)],
	]
	if not transition:
		for t in targets:
			(t[0] as ShaderMaterial).set_shader_parameter(t[1], t[2])
		return
	var froms := []
	for t in targets:
		var cur = (t[0] as ShaderMaterial).get_shader_parameter(t[1])
		froms.append(cur if cur is Color else t[2])
	if _season_tw and _season_tw.is_valid():
		_season_tw.kill()
	_season_tw = create_tween()
	_season_tw.tween_method(
			func(x: float) -> void:
				for i in targets.size():
					(targets[i][0] as ShaderMaterial).set_shader_parameter(
							targets[i][1], (froms[i] as Color).lerp(targets[i][2], x)),
			0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE)






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
		row.text = L10n.t("Il legno è ancora giovane e liscio.\nGli anelli aspettano la vostra storia.")
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color(UI_BROWN, 0.7))
		_rows.add_child(row)
		return
	var latest: Array = _events.slice(maxi(0, _events.size() - 12))
	latest.reverse()
	for ev: Dictionary in latest:
		var row := Label.new()
		# il testo dell'incisione è salvato in italiano (viaggia nel villaggio):
		# si traduce solo qui, quando la riga si disegna
		row.text = L10n.tf("Giorno %d   %s  %s",
				[int(ev["d"]), str(ev["i"]),
				L10n.rendi({"k": str(ev["t"]), "args": ev.get("a", [])})])
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
	_prompt_label.text = L10n.t("E — gli anelli del Grande Albero")
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
	title.text = L10n.t("~ Gli anelli del Grande Albero ~")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)
	var hint := Label.new()
	hint.text = L10n.t("E — chiudi")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for ev: Dictionary in _events:
		rows.append([int(ev["d"]), str(ev["i"]), str(ev["t"]), ev.get("a", [])])
	return {"tree_events": rows}


func load_extra(data: Dictionary) -> void:
	var rows: Array = data.get("tree_events", [])
	if rows.is_empty():
		return
	_events.clear()
	for r in rows:
		if r is Array and r.size() >= 3:
			# le cronache incise prima degli argomenti hanno tre colonne:
			# si riaprono senza rompersi, con la lista vuota
			_events.append({"d": int(r[0]), "i": str(r[1]), "t": str(r[2]),
					"a": (r[3] as Array) if r.size() > 3 and r[3] is Array else []})
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
