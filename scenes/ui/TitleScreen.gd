extends Node3D

## La schermata del titolo: Mochi aspetta seduta sotto il Grande Albero, in una
## golden hour infinita, mentre i petali scendono piano e la camera respira.
## Da qui si entra nel villaggio: Continua (se c'è un salvataggio), Nuovo
## villaggio, Impostazioni, Esci.
##
## Il mondo del titolo è un piccolo diorama costruito in codice: albero
## decorativo, prato, fiori, una Mochi vera in posa "sit". Nessuna dipendenza
## dal mondo di gioco, così carica sempre pulito.

const MAIN_SCENE := "res://scenes/levels/MainLevel.tscn"
const SAVE_PATH := "user://village.json"

var _cam: Camera3D
var _cam_base := Vector3(1.4, 1.9, 4.6)
var _look := Vector3(-0.6, 1.1, -0.4)
var _t := 0.0

var _ui: CanvasLayer
var _menu: Control
var _settings: CozySettingsPanel
var _confirm: Control
var _sfx


func _ready() -> void:
	# Le verifiche da riga di comando entrano dritte nel villaggio: da quando
	# il gioco parte dal titolo, un menù che aspetta un clic bloccherebbe
	# CHIBI_SHOT (gli screenshot documentati nel README), CHIBI_LEGNA e
	# CHIBI_MAKESAVE — che girano senza nessuno alla tastiera.
	for v in ["CHIBI_SHOT", "CHIBI_LEGNA", "CHIBI_LAVORI", "CHIBI_FESTA", "CHIBI_FILO", "CHIBI_FRUTTETO", "CHIBI_COMMISSIONI", "CHIBI_NIDO", "CHIBI_FACCE", "CHIBI_PORTE", "CHIBI_PIOGGIA", "CHIBI_BUCATO", "CHIBI_SALUTI", "CHIBI_STAGNO", "CHIBI_CARTA", "CHIBI_MAKESAVE"]:
		if OS.get_environment(v) != "":
			_enter.call_deferred()
			return
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_world()
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	if _cam:
		_cam.position = _cam_base + Vector3(sin(_t * 0.13) * 0.7, sin(_t * 0.19) * 0.18, 0.0)
		_cam.look_at(_look + Vector3(sin(_t * 0.11) * 0.15, 0, 0), Vector3.UP)


# ================================================================ diorama
func _build_world() -> void:
	# --- cielo e luce da golden hour ---
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.56, 0.82)
	sky_mat.sky_horizon_color = Color(1.0, 0.78, 0.55)
	sky_mat.ground_horizon_color = Color(1.0, 0.82, 0.62)
	sky_mat.ground_bottom_color = Color(0.62, 0.5, 0.44)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.8, 0.62)
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(-52.0), 0.0)
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.light_energy = 1.7
	sun.light_angular_distance = 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	add_child(sun)

	# --- prato ---
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.53, 0.67, 0.42)
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	# --- l'albero e i suoi fiori ---
	var tree := _make_tree()
	tree.position = Vector3(-1.3, 0, -1.6)
	add_child(tree)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.2, 6.0)
		var f := _make_flower([Color("ff9ec0"), Color("ffe6a8"), Color("cdbff0"), Color("bfe6c8")][rng.randi() % 4])
		f.position = Vector3(-1.3 + cos(a) * d, 0, -1.6 + sin(a) * d)
		f.rotation.y = rng.randf() * TAU
		add_child(f)

	# --- Mochi, seduta sotto l'albero, rivolta alla camera ---
	var mochi_scene: PackedScene = load("res://scenes/characters/Mochi.tscn")
	if mochi_scene:
		var mochi := mochi_scene.instantiate() as Node3D
		mochi.position = Vector3(-0.5, 0.0, 0.2)
		mochi.rotation.y = -0.5
		mochi.scale = Vector3(0.95, 0.95, 0.95)
		add_child(mochi)
		if mochi.has_method("set_pose"):
			mochi.call_deferred("set_pose", "sit")

	# --- camera ---
	_cam = Camera3D.new()
	_cam.position = _cam_base
	_cam.fov = 46.0
	_cam.attributes = _dof()
	add_child(_cam)
	_cam.look_at(_look, Vector3.UP)


func _dof() -> CameraAttributesPractical:
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = 9.0
	a.dof_blur_far_transition = 5.0
	a.dof_blur_amount = 0.08
	return a


# un albero decorativo: tronco svasato, chioma a grappoli, due fioriture rosa
func _make_tree() -> Node3D:
	var n := Node3D.new()
	var bark := _sm(Color("9a6b4f"))
	var leaf := _sm(Color("7fbc62"))
	var leaf_d := _sm(Color("5f9c48"))
	var blossom := _sm(Color("f6b8ce"))

	var trunk := _cyl(0.42, 0.68, 3.4, bark)
	trunk.position = Vector3(0, 1.7, 0)
	n.add_child(trunk)
	for i in 5:
		var ang := float(i) / 5.0 * TAU + 0.3
		var root := _cyl(0.1, 0.22, 0.9, bark)
		root.position = Vector3(cos(ang) * 0.55, 0.2, sin(ang) * 0.55)
		root.rotation = Vector3(cos(ang) * 0.6, 0, sin(ang) * 0.6)
		n.add_child(root)
	for i in 3:
		var ang := float(i) / 3.0 * TAU
		var branch := _cyl(0.1, 0.18, 1.6, bark)
		branch.position = Vector3(cos(ang) * 0.5, 3.2, sin(ang) * 0.5)
		branch.rotation = Vector3(0, -ang, 0.9)
		n.add_child(branch)

	# chioma: grappolo di sfere
	var canopy := [
		[Vector3(0, 4.3, 0), 2.1, leaf], [Vector3(1.6, 3.9, 0.4), 1.5, leaf_d],
		[Vector3(-1.5, 4.0, -0.5), 1.6, leaf], [Vector3(0.2, 4.2, -1.6), 1.4, leaf_d],
		[Vector3(-0.3, 5.1, 0.6), 1.5, leaf], [Vector3(1.0, 4.6, 1.2), 1.2, leaf_d],
	]
	for c in canopy:
		var s := _ball((c[1] as float), c[2])
		s.position = c[0]
		n.add_child(s)
	for bp in [Vector3(1.2, 4.4, 0.9), Vector3(-1.0, 4.5, -0.2), Vector3(0.1, 5.3, 0.3)]:
		var b := _ball(0.7, blossom)
		b.position = bp
		n.add_child(b)
	return n


func _make_flower(col: Color) -> Node3D:
	var n := Node3D.new()
	var stem := _cyl(0.015, 0.015, 0.22, _sm(Color("6fae52")))
	stem.position = Vector3(0, 0.11, 0)
	n.add_child(stem)
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var petal := _ball(0.05, _sm(col))
		petal.position = Vector3(cos(a) * 0.06, 0.24, sin(a) * 0.06)
		petal.scale = Vector3(1, 0.5, 1)
		n.add_child(petal)
	var heart := _ball(0.04, _sm(Color("ffe08a")))
	heart.position = Vector3(0, 0.25, 0)
	n.add_child(heart)
	return n


func _sm(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _cyl(top: float, bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


# ================================================================ UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_ui.add_child(CozyUI.petals(30, false))

	_menu = _build_menu()
	_ui.add_child(_menu)

	_settings = CozySettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	var scenter := CozyUI.center_root()
	scenter.name = "SettingsCenter"
	scenter.visible = false
	scenter.add_child(_settings)
	_ui.add_child(scenter)

	CozyUI.appear(_menu, 0.6)


func _build_menu() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 90.0
	box.offset_top = -170.0
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(box)

	var title := Label.new()
	title.text = "Chibi Crossing"
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color("fff3e0"))
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.2, 0.15, 0.55))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_offset_x", 2)
	box.add_child(title)

	var sub := Label.new()
	sub.text = L10n.t("Un villaggio ti aspetta sotto il Grande Albero.")
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("fff3e0"))
	sub.add_theme_color_override("font_shadow_color", Color(0.35, 0.2, 0.15, 0.5))
	sub.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	box.add_child(gap)

	if FileAccess.file_exists(SAVE_PATH):
		box.add_child(_title_button(L10n.t("Continua"), CozyUI.MINT, _continue))
		box.add_child(_title_button(L10n.t("Nuovo villaggio"), CozyUI.PINK, _ask_new))
	else:
		box.add_child(_title_button(L10n.t("Nuovo villaggio"), CozyUI.MINT, _start_new))
	box.add_child(_title_button(L10n.t("Impostazioni"), CozyUI.SKY, _open_settings))
	box.add_child(_title_button(L10n.t("Esci"), CozyUI.HONEY, func(): get_tree().quit()))
	return root


func _title_button(text: String, accent: Color, cb: Callable) -> Button:
	var b := CozyUI.cozy_button(text, accent, 22)
	b.custom_minimum_size = Vector2(340, 60)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- azioni
func _continue() -> void:
	_enter()


func _start_new() -> void:
	# il vecchio villaggio NON si cancella: si archivia con data e ora.
	# Con l'investimento emotivo del Filo Rosso, un "Nuovo villaggio" per
	# sbaglio non deve costare una storia intera — per tornare indietro
	# basta rinominare l'archivio in village.json.
	# SI ARCHIVIA ANCHE LA COPIA .bak, e non per pignoleria: lasciata lì,
	# il villaggio nuovo la ripescava e resuscitava il vecchio (il
	# caricamento non distingueva "manca" da "è rotto"). Adesso la
	# distinzione c'è in BuildSystem, e questa è la seconda cintura.
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, "user://village_%s.json" % stamp)
	if FileAccess.file_exists(SAVE_PATH + ".bak"):
		DirAccess.rename_absolute(SAVE_PATH + ".bak",
				"user://village_%s.json.bak" % stamp)
	# GLI ALTRI DEPOSITI. Il villaggio non vive tutto dentro village.json:
	# tre cose si salvano per conto loro, e restavano in piedi nel
	# villaggio nuovo — le cornici sopra letti che non esistono più e i
	# sentieri consumati dai passi di un'altra storia.
	# Si ARCHIVIANO con lo stesso timbro del villaggio (mai cancellati:
	# «una storia non si butta» — e chi rinomina l'archivio indietro se
	# li ritrova tutti insieme, coerenti fra loro).
	for deposito: String in ["user://foto_ricordi.json",
			"user://sentieri_consumati.png"]:
		if FileAccess.file_exists(deposito):
			var pezzi := deposito.trim_prefix("user://").split(".")
			DirAccess.rename_absolute(deposito,
					"user://%s_%s.%s" % [pezzi[0], stamp, pezzi[1]])
	# anche il rullino del timelapse riparte: senza, il "film" del villaggio
	# nuovo proietterebbe le foto del vecchio (e capture() salta i giorni
	# i cui PNG esistono già). L'album personale user://photos resta.
	var dir := DirAccess.open("user://ricordi")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	_enter()


func _enter() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _ask_new() -> void:
	if _confirm and is_instance_valid(_confirm):
		return
	_confirm = _build_confirm()
	_ui.add_child(_confirm)
	CozyUI.fade_to(_confirm, 0.5, 0.25)   # dopo l'add_child: il tween ha l'albero
	CozyUI.appear(_confirm, 0.3)


func _build_confirm() -> Control:
	var dim := CozyUI.backdrop()
	var center := CozyUI.center_root()
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CozyUI.paper_panel(26))
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(CozyUI.title_label(L10n.t("Ricominciare da capo?"), 26))
	col.add_child(CozyUI.hint_label(L10n.t(
		"Il villaggio attuale sarà sostituito da uno nuovo.\nQuesta scelta non si può annullare."), 15))
	var rowc := HBoxContainer.new()
	rowc.add_theme_constant_override("separation", 12)
	rowc.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(rowc)
	var no := CozyUI.cozy_button(L10n.t("Annulla"), CozyUI.MINT, 18)
	no.custom_minimum_size = Vector2(180, 52)
	no.pressed.connect(_close_confirm)
	rowc.add_child(no)
	var yes := CozyUI.cozy_button(L10n.t("Nuovo villaggio"), CozyUI.DANGER, 18)
	yes.custom_minimum_size = Vector2(200, 52)
	yes.pressed.connect(_start_new)
	rowc.add_child(yes)
	return dim


func _close_confirm() -> void:
	if _confirm and is_instance_valid(_confirm):
		_confirm.queue_free()
		_confirm = null
	if _sfx: _sfx.build_close()


func _open_settings() -> void:
	_menu.visible = false
	var sc := _ui.get_node_or_null("SettingsCenter")
	if sc:
		sc.visible = true
	CozyUI.appear(_settings, 0.34)


func _close_settings() -> void:
	var sc := _ui.get_node_or_null("SettingsCenter")
	if sc:
		sc.visible = false
	_menu.visible = true
	CozyUI.appear(_menu, 0.34)
