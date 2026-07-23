extends Node

## Il ricettario del camino. La dispensa raccoglie carote, zucche e
## bacche dall'Orto e i funghi del bosco; davanti al Camino, E apre il
## menu delle ricette: il pentolino sobbolle, la ciotola passa tra le
## zampine di Mochi, lei ci soffia sopra a occhi socchiusi e poi —
## finalmente — MANGIA: tre morsetti con le briciole e il "gnam".
## Ogni piatto ricarica le sue barre, e ne avanza sempre una porzione
## da regalare ai residenti. Dispensa persistita nel JSON.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const UI_BROWN := Color("6a4a3a")

const ING_PLURAL := {"carota": "carote", "zucca": "zucche", "bacca": "bacche", "fungo": "funghi"}

const RECIPES := [
	{"name": "Tè del prato", "need": {}, "warm": false, "art": "il",
		"fill": ["water"], "col": Color("c88a4a")},
	{"name": "Zuppa di carote", "need": {"carota": 2}, "warm": true, "art": "la",
		"fill": ["hunger", "water"], "col": Color("e8944a")},
	{"name": "Vellutata di zucca", "need": {"zucca": 1, "carota": 1}, "warm": true, "art": "la",
		"fill": ["hunger", "water", "stamina"], "col": Color("e07f38")},
	{"name": "Risotto ai funghi", "need": {"fungo": 2}, "warm": true, "art": "il",
		"fill": ["hunger", "stamina"], "col": Color("f0e2c8")},
	{"name": "Spiedini di bosco", "need": {"fungo": 1, "carota": 1}, "warm": true, "art": "gli",
		"fill": ["hunger"], "col": Color("c98a5a")},
	{"name": "Crumble di bacche", "need": {"bacca": 3}, "warm": false, "art": "il",
		"fill": ["hunger"], "col": Color("a8386a")},
	{"name": "Tè alle bacche", "need": {"bacca": 1}, "warm": false, "art": "il",
		"fill": ["water", "stamina"], "col": Color("b04a6a")},
]

var _build: Node3D
var _player: Node3D
var _mochi: Node3D
var _survival: Node
var _sfx
var _weather: Node

## La dispensa del villaggio: {"carota": n, …}. Persistita.
var pantry := {}

## La porzione avanzata: {"name", "art", "warm"} — da regalare.
var held_dish := {}

var _near: Node3D
var _busy := false
var _menu_open := false

var _prompt: PanelContainer
var _prompt_label: Label
var _menu: PanelContainer
var _menu_buttons: Array[Button] = []
var _pantry_label: Label


func _ready() -> void:
	add_to_group("persistable")
	_player = get_node("%Player")
	_mochi = _player.get_node("Mochi")
	_build = get_node("../BuildSystem")
	_survival = _player.get_node_or_null("SurvivalComponent")
	_sfx = get_node_or_null(^"/root/Sfx")
	_weather = get_tree().get_first_node_in_group("weather")
	if _build.has_signal("placed_changed"):
		_build.connect("placed_changed", func(): _caminos_dirty = true)
	_build_ui()


func has_dish() -> bool:
	return not held_dish.is_empty()


func take_dish() -> Dictionary:
	var d := held_dish
	held_dish = {}
	return d


## La dispensa cresce (orto, funghi del bosco…). Ritorna il totale.
func add_ingredient(kind: String, n: int) -> int:
	pantry[kind] = int(pantry.get(kind, 0)) + n
	_build._save_village()
	return int(pantry[kind])


func _can_cook(recipe: Dictionary) -> bool:
	for kind in recipe["need"]:
		if int(pantry.get(kind, 0)) < int(recipe["need"][kind]):
			return false
	return true


# ---------------------------------------------------------------- ciclo

func _process(_delta: float) -> void:
	_update_near()
	_update_prompt()


# la cache dei camini si rinfresca solo quando il villaggio cambia
var _caminos: Array[Node3D] = []
var _caminos_dirty := true


func _update_near() -> void:
	if _busy or _menu_open:
		return
	if _caminos_dirty:
		_caminos_dirty = false
		_caminos = _build.get_placed_by_name("Camino")
	_near = null
	var best := 1.5
	for node in _caminos:
		if not is_instance_valid(node):
			continue
		var d: float = _player.global_position.distance_to((node as Node3D).global_position)
		if d < best:
			best = d
			_near = node


func _unhandled_input(event: InputEvent) -> void:
	# col ricettario aperto, i tasti 1-7 scelgono il piatto
	if _menu_open and event is InputEventKey and event.pressed and not event.is_echo():
		var idx: int = (event as InputEventKey).keycode - KEY_1
		if idx >= 0 and idx < RECIPES.size():
			_choose_recipe(idx)
			get_viewport().set_input_as_handled()
			return
	if not event.is_action_pressed("interact"):
		return
	if _menu_open:
		_close_menu()
		get_viewport().set_input_as_handled()
	elif _near and not _busy:
		_open_menu()
		get_viewport().set_input_as_handled()


func _open_menu() -> void:
	_menu_open = true
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	_refresh_menu()
	_menu.visible = true
	if _sfx:
		_sfx.build_open()


func _close_menu() -> void:
	_menu_open = false
	_menu.visible = false
	if not _busy:
		_player.set_physics_process(true)
	if _sfx:
		_sfx.build_close()


func _refresh_menu() -> void:
	# dispensa in testa, ricette sotto: accese solo se cucinabili
	var parts: Array[String] = []
	for kind in ING_PLURAL:
		var n := int(pantry.get(kind, 0))
		if n > 0:
			parts.append("%d %s" % [n, kind if n == 1 else ING_PLURAL[kind]])
	_pantry_label.text = "Dispensa: " + (" · ".join(parts) if not parts.is_empty() else "vuota (orto e bosco ti aspettano)")
	for i in _menu_buttons.size():
		var recipe: Dictionary = RECIPES[i]
		var need_parts: Array[String] = []
		for kind in recipe["need"]:
			var n := int(recipe["need"][kind])
			need_parts.append("%d %s" % [n, kind if n == 1 else ING_PLURAL[kind]])
		var need_txt := " · ".join(need_parts) if not need_parts.is_empty() else "senza ingredienti"
		_menu_buttons[i].text = "%d.  %s   —   %s" % [i + 1, recipe["name"], need_txt]
		_menu_buttons[i].disabled = not _can_cook(recipe)


func _choose_recipe(i: int) -> void:
	var recipe: Dictionary = RECIPES[i]
	if not _can_cook(recipe) or _near == null:
		return
	for kind in recipe["need"]:
		pantry[kind] = int(pantry.get(kind, 0)) - int(recipe["need"][kind])
	get_tree().call_group("regista", "note", "cucina")
	_menu_open = false
	_menu.visible = false
	if _sfx:
		_sfx.ui_select()
	_ritual(_near, recipe)


# ---------------------------------------------------------------- rituale

func _ritual(camino: Node3D, recipe: Dictionary) -> void:
	_busy = true
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO

	var dir := ((camino.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	_mochi.set("_yaw", atan2(-dir.x, -dir.z))

	# il pentolino sobbolle davanti alla bocca del fuoco
	var pot := _make_pot(recipe["col"])
	pot.position = camino.global_transform * Vector3(0, 0.45, 0.34)
	add_child(pot)
	_pop_in(pot)
	var pot_steam := _make_steam(0.14, 0.5)
	pot_steam.position = pot.position + Vector3(0, 0.16, 0)
	add_child(pot_steam)
	if _sfx:
		get_tree().create_timer(0.35).timeout.connect(func():
			if _sfx: _sfx.boil())
	await get_tree().create_timer(2.0).timeout

	# la ciotola (o la tazza, per i tè) passa tra le zampine
	_fade_out(pot)
	pot_steam.emitting = false
	get_tree().create_timer(2.5).timeout.connect(pot_steam.queue_free)

	var solid: bool = "hunger" in (recipe["fill"] as Array)
	var cup := _make_cup(recipe["col"], solid)
	_mochi.add_child(cup)
	# la tazza va a sedersi TRA le zampine: la presa sale ad accoglierla
	_mochi.call("hold_cup", true)
	cup.position = Vector3(0, 0.45, -0.3)
	_pop_in(cup)
	var cup_steam := _make_steam(0.07, 0.35)
	cup.add_child(cup_steam)
	cup_steam.position = Vector3(0, 0.1, 0)

	# soffia per raffreddare… (la tazza sale verso il musetto)
	_mochi.call("start_blowing")
	var raise := create_tween()
	raise.tween_property(cup, "position", Vector3(0, 0.52, -0.33), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in 2:
		await get_tree().create_timer(0.7).timeout
		_blow_puff()
	await get_tree().create_timer(0.4).timeout

	# …e MANGIA: tre morsetti, la tazza fa su e giù tra zampe e musetto
	if solid:
		if _sfx:
			_sfx.munch()
		for i in 3:
			var tw := create_tween()
			tw.tween_property(cup, "position:y", 0.62, 0.14) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(cup, "position:y", 0.5, 0.12) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			if i == 1:
				_crumbs(recipe["col"])
			await get_tree().create_timer(0.32).timeout
	_mochi.call("stop_blowing")

	# il calore dentro: ogni ricetta ricarica le sue barre
	if _survival:
		var fills: Array = recipe["fill"]
		if "hunger" in fills:
			_survival.set_hunger(_survival.get_max_hunger())
		if "water" in fills:
			_survival.set_water(_survival.get_max_water())
		if "stamina" in fills:
			_survival.set_stamina(_survival.get_max_stamina())
	if _sfx:
		_sfx.place_ok()
	_heart_burst(_player.global_position + Vector3(0, 1.1, 0))

	await get_tree().create_timer(0.6).timeout
	cup_steam.emitting = false
	# la presa si scioglie mentre la tazza svanisce
	_mochi.call("hold_cup", false)
	_fade_out(cup)
	_player.set_physics_process(true)
	_busy = false

	# ne avanza sempre una porzione: la cucina cozy non spreca niente
	held_dish = {"name": recipe["name"].to_lower(), "art": recipe["art"], "warm": recipe["warm"]}
	var visitors := get_node_or_null("../Visitors")
	if visitors:
		visitors.call("_show_toast", "Ne è avanzata una porzione: regalala a un amico!")
	_build._save_village()


# le briciole del morso, giù dalla ciotola
func _crumbs(col: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col.darkened(0.15)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, -2.4, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var crumbs := GPUParticles3D.new()
	crumbs.amount = 7
	crumbs.lifetime = 0.5
	crumbs.one_shot = true
	crumbs.explosiveness = 1.0
	crumbs.local_coords = false
	crumbs.process_material = pm
	crumbs.draw_pass_1 = quad
	crumbs.position = _mochi.to_global(Vector3(0, 0.82, -0.42))
	add_child(crumbs)
	crumbs.emitting = true
	get_tree().create_timer(1.1).timeout.connect(crumbs.queue_free)


# ---------------------------------------------------------------- props

func _pm_mat(a: Color, b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", 5.0)
	mat.set_shader_parameter("noise_amount", 0.45)
	return mat


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _make_pot(col: Color) -> Node3D:
	var pot := Node3D.new()
	var iron := _pm_mat(Color("4a4440"), Color("3a3530"))
	var body := CylinderMesh.new()
	body.top_radius = 0.11
	body.bottom_radius = 0.09
	body.height = 0.13
	_mesh(pot, body, iron, Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.095
	rim.outer_radius = 0.12
	_mesh(pot, rim, iron, Vector3(0, 0.065, 0))
	var soup := CylinderMesh.new()
	soup.top_radius = 0.095
	soup.bottom_radius = 0.095
	soup.height = 0.015
	var soup_mat := StandardMaterial3D.new()
	soup_mat.albedo_color = col
	soup_mat.emission_enabled = true
	soup_mat.emission = col.darkened(0.2)
	soup_mat.emission_energy_multiplier = 0.4
	_mesh(pot, soup, soup_mat, Vector3(0, 0.06, 0))
	return pot


func _make_cup(col: Color, solid: bool) -> Node3D:
	var cup := Node3D.new()
	var china := _pm_mat(Color("fff3e0"), Color("f3e2c8"))
	var body := CylinderMesh.new()
	body.top_radius = 0.075
	body.bottom_radius = 0.055
	body.height = 0.09
	var b := _mesh(cup, body, china, Vector3.ZERO)
	if solid:
		b.scale = Vector3(1.35, 0.85, 1.35)
	var tea := CylinderMesh.new()
	tea.top_radius = 0.062
	tea.bottom_radius = 0.062
	tea.height = 0.012
	var tea_mat := StandardMaterial3D.new()
	tea_mat.albedo_color = col
	tea_mat.emission_enabled = true
	tea_mat.emission = col.darkened(0.25)
	tea_mat.emission_energy_multiplier = 0.3
	var t := _mesh(cup, tea, tea_mat, Vector3(0, 0.038 if solid else 0.042, 0))
	if solid:
		t.scale = Vector3(1.35, 1.0, 1.35)
	else:
		var handle := TorusMesh.new()
		handle.inner_radius = 0.018
		handle.outer_radius = 0.036
		var h := _mesh(cup, handle, china, Vector3(0.085, 0, 0))
		h.rotation.z = PI * 0.5
	return cup


# vapore: sbuffi soffici che salgono ondeggiando e si dissolvono
func _make_steam(size: float, rise: float) -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = rise * 0.6
	pm.initial_velocity_max = rise
	pm.gravity = Vector3(0, 0.12, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_speed = Vector3(0.4, 0.2, 0.4)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var steam := GPUParticles3D.new()
	steam.amount = 12
	steam.lifetime = 1.6
	steam.process_material = pm
	steam.draw_pass_1 = quad
	return steam


# lo sbuffo del soffio: piccole nuvolette dalla bocca verso la tazza
func _blow_puff() -> void:
	var mouth: Vector3 = _mochi.to_global(Vector3(0, 0.86, -0.42))
	var forward: Vector3 = -(_mochi.global_transform.basis.z).normalized()
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.015
	pm.direction = forward + Vector3(0, -0.5, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var puff := GPUParticles3D.new()
	puff.amount = 6
	puff.lifetime = 0.6
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.local_coords = false
	puff.process_material = pm
	puff.draw_pass_1 = quad
	puff.position = mouth
	add_child(puff)
	puff.emitting = true
	get_tree().create_timer(1.2).timeout.connect(puff.queue_free)
	if _sfx:
		_sfx.play("step_grass3", -22.0, 1.6)


func _heart_burst(pos: Vector3) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.6, 0.7, 0.95), Color(1.0, 0.6, 0.7, 0.5), Color(1.0, 0.6, 0.7, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
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
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var burst := GPUParticles3D.new()
	burst.amount = 12
	burst.lifetime = 1.2
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.8).timeout.connect(burst.queue_free)


func _pop_in(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fade_out(node: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 0.03, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


# ---------------------------------------------------------------- UI

func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if _near == null or cam == null or _busy or _menu_open:
		_prompt.visible = false
		return
	var wp: Vector3 = _near.global_position + Vector3(0, 1.3, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = "E — ricettario del camino" \
			if not (_weather and _weather.is_raining()) else "E — cucinare al riparo dalla pioggia"
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
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)

	# il menu del ricettario, al centro
	_menu = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fdf6e3")
	ms.set_corner_radius_all(16)
	ms.border_color = Color(0.62, 0.46, 0.34, 0.55)
	ms.set_border_width_all(2)
	ms.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	ms.shadow_size = 12
	ms.content_margin_left = 22.0
	ms.content_margin_right = 22.0
	ms.content_margin_top = 14.0
	ms.content_margin_bottom = 14.0
	_menu.add_theme_stylebox_override("panel", ms)
	_menu.custom_minimum_size = Vector2(440, 0)
	_menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_menu)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_menu.add_child(vbox)

	var title := Label.new()
	title.text = "~ Ricettario del camino ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)

	_pantry_label = Label.new()
	_pantry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pantry_label.add_theme_font_size_override("font_size", 13)
	_pantry_label.add_theme_color_override("font_color", Color("c25a7a"))
	vbox.add_child(_pantry_label)

	for i in RECIPES.size():
		var btn := Button.new()
		btn.toggle_mode = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 34)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", UI_BROWN)
		btn.add_theme_color_override("font_hover_color", Color("a83a5c"))
		btn.add_theme_color_override("font_disabled_color", Color(UI_BROWN, 0.35))
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(1, 1, 1, 0.4)
		bsb.set_corner_radius_all(10)
		bsb.content_margin_left = 12.0
		bsb.content_margin_right = 12.0
		btn.add_theme_stylebox_override("normal", bsb)
		btn.add_theme_stylebox_override("hover", bsb)
		var dsb := bsb.duplicate() as StyleBoxFlat
		dsb.bg_color = Color(0.8, 0.76, 0.7, 0.25)
		btn.add_theme_stylebox_override("disabled", dsb)
		btn.pressed.connect(_choose_recipe.bind(i))
		vbox.add_child(btn)
		_menu_buttons.append(btn)

	var hint := Label.new()
	hint.text = "E — chiudi il ricettario"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	if pantry.is_empty():
		return {}
	return {"pantry": pantry}


func load_extra(data: Dictionary) -> void:
	pantry = data.get("pantry", {})


# ---------------------------------------------------------------- debug CLI

func debug_fill_pantry() -> void:
	for kind in ING_PLURAL:
		pantry[kind] = 3


func debug_open_menu() -> void:
	_open_menu()


func debug_close_menu() -> void:
	_close_menu()


func debug_cook() -> void:
	var caminos: Array[Node3D] = _build.get_placed_by_name("Camino")
	if caminos.is_empty():
		return
	debug_fill_pantry()
	var camino := caminos[0]
	# in diagonale rispetto al fuoco, così la camera vede il visetto
	_player.global_position = camino.global_position + Vector3(0.7, 0, 0.35)
	_ritual(camino, RECIPES[3])
