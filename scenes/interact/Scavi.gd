extends Node

## I LUCCICHII DEL MATTINO — ogni giorno la terra nasconde piccoli segreti.
##
## Al risveglio, due o tre punti del prato scintillano d'oro: lì sotto c'è
## qualcosa. Con E Mochi si accuccia e scava con le zampine (sbuffi di
## terra, tre scavate) e il trovamento salta fuori in un arco: un
## sacchettino di noccioline, un ingrediente per la dispensa, la
## campanella di coccio che qualcuno perse tanto tempo fa, o — di rado —
## una stellina. La mattina dopo, altri luccichii, altrove: insieme alla
## posta e alla foto dei ricordi, un motivo in più per cui OGNI mattina
## conta.
##
## I punti del giorno sono DETERMINISTICI nel giorno (stesso giorno,
## stessi punti): il salvataggio ricorda solo quali sono già stati
## scavati. La generazione e i trovamenti sono funzioni pure, provate
## headless in tests/cases/test_scavi.gd.

const CRIT := preload("res://scenes/world/Critters.gd")
const UI_BROWN := Color("6a4a3a")

# il rettangolo del prato dove la terra può luccicare (lontano da fiume e
# scogliera, che stanno a est di x=16; stagno, radura, Grande Albero e
# massi arrivano da obstacle_circles)
const RECT := Rect2(-13.0, -15.0, 26.0, 24.0)
const RAGGIO_SCAVO := 1.3
const DIST_MIN := 4.0          # i luccichii non si ammucchiano


## I punti di oggi: deterministici nel giorno, fuori dagli ostacoli,
## distanziati tra loro. `ostacoli` è l'elenco di CozyWorld.obstacle_circles()
## ([Vector3(x, raggio, z)]). Puro: lo prova il test.
static func punti_del_giorno(giorno: int, ostacoli: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("luccichii_%d" % giorno)
	var quanti := 2 + int(rng.randi() % 2)
	var out: Array = []
	var tentativi := 0
	while out.size() < quanti and tentativi < 240:
		tentativi += 1
		var p := Vector3(
			rng.randf_range(RECT.position.x, RECT.position.x + RECT.size.x),
			0.0,
			rng.randf_range(RECT.position.y, RECT.position.y + RECT.size.y))
		if not punto_libero(p, ostacoli):
			continue
		var stretto := false
		for q in out:
			if p.distance_to(q) < DIST_MIN:
				stretto = true
				break
		if stretto:
			continue
		out.append(p)
	return out


## Il punto è abbastanza lontano da ogni cerchio occupato? (x, raggio, z)
static func punto_libero(p: Vector3, ostacoli: Array) -> bool:
	for o in ostacoli:
		var c: Vector3 = o
		if Vector2(p.x - c.x, p.z - c.z).length() < c.y + 1.0:
			return false
	return true


## Cosa c'è sotto il luccichio i-esimo del giorno. Puro e deterministico:
## ricaricare il salvataggio non cambia il tesoro.
static func trovamento(giorno: int, indice: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("trovamento_%d_%d" % [giorno, indice])
	var caso := rng.randf()
	if caso < 0.45:
		return {"tipo": "noccioline", "n": 8 + int(rng.randi() % 13)}   # 8..20
	if caso < 0.70:
		var scelte := ["carota", "zucca", "bacca", "fungo"]
		return {"tipo": "ingrediente", "id": scelte[rng.randi() % scelte.size()]}
	if caso < 0.88:
		return {"tipo": "tesoro", "id": "campanella_coccio"}
	return {"tipo": "stellina", "n": 1}


var _player: Node3D
var _mochi: Node3D
var _cozy: Node3D
var _daynight: Node3D
var _build: Node3D
var _sfx

var _giorno := 0
var _scavati: Array = []        # indici già scavati oggi
var _spots: Array = []          # {"i": int, "pos": Vector3, "node": Node3D}
var _busy := false
var _t := 0.0

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func() -> void:
		_iscrivi_alla_e()
		_player = get_node_or_null("%Player")
		_mochi = _player.get_node("Mochi") if _player else null
		_cozy = get_node_or_null("../CozyWorld")
		_daynight = get_node_or_null("../DayNight")
		_build = get_tree().get_first_node_in_group("build_system")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_su_nuovo_giorno)
		# il mondo si costruisce differito: i luccichii aspettano gli ostacoli
		if _cozy and _cozy.has_signal("world_built"):
			_cozy.world_built.connect(func() -> void:
				if _giorno == 0:
					_giorno = int(_daynight.get("day")) if _daynight else 1
				_rigenera())
	).call_deferred()


func _su_nuovo_giorno(giorno: int) -> void:
	_giorno = giorno
	_scavati = []
	_rigenera()
	_salva()


# ---------------------------------------------------------------- i luccichii

func _rigenera() -> void:
	for s in _spots:
		if is_instance_valid(s["node"]):
			(s["node"] as Node3D).queue_free()
	_spots = []
	if _cozy == null:
		return
	var ostacoli: Array = _cozy.call("obstacle_circles")
	var punti := punti_del_giorno(_giorno, ostacoli)
	for i in punti.size():
		if i in _scavati:
			continue
		var p: Vector3 = punti[i]
		# niente luccichii sotto un tetto o dentro casa: la terra coperta dorme
		if _build and bool(_build.call("has_cover", Vector2i(roundi(p.x), roundi(p.z)))):
			continue
		var node := _fai_luccichio()
		node.position = p
		add_child(node)
		_spots.append({"i": i, "pos": p, "node": node})


func _fai_luccichio() -> Node3D:
	var node := Node3D.new()
	# la chiazza di terra smossa
	var patch := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.26
	pm.bottom_radius = 0.3
	pm.height = 0.03
	patch.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.36, 0.27, 0.9)
	mat.roughness = 1.0
	patch.material_override = mat
	patch.position = Vector3(0, 0.015, 0)
	node.add_child(patch)
	# le scintille dorate che salgono piano (GPU, AABB piccolo)
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.9, 0.55, 0.9), Color(1.0, 0.9, 0.55, 0.4), Color(1.0, 0.9, 0.55, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_texture = tex
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	quad.material = qm
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.22
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 12.0
	proc.initial_velocity_min = 0.12
	proc.initial_velocity_max = 0.3
	proc.gravity = Vector3.ZERO
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	proc.color_ramp = ramp_tex
	var fx := GPUParticles3D.new()
	fx.amount = 10
	fx.lifetime = 1.6
	fx.local_coords = true
	fx.process_material = proc
	fx.draw_pass_1 = quad
	fx.visibility_aabb = AABB(Vector3(-0.6, -0.2, -0.6), Vector3(1.2, 1.6, 1.2))
	node.add_child(fx)
	return node


# ---------------------------------------------------------------- lo scavo

func _spot_vicino() -> int:
	if _player == null:
		return -1
	var pp: Vector3 = _player.global_position
	for k in _spots.size():
		if pp.distance_to(_spots[k]["pos"]) < RAGGIO_SCAVO:
			return k
	return -1


# ---------------------------------------------------- l'arbitro della E
# Il luccichio del giorno è FUGACE: sono due o tre in tutto il prato e
# quando li scavi finiscono. Prima l'asciata e la semina glielo rubavano
# — e piantavano un albero proprio sopra il punto da scavare.

## La distanza dal luccichio a portata, o -1 se non ce n'è nessuno.
func distanza_e() -> float:
	if _busy or _player == null or not _player.is_physics_processing():
		return -1.0
	var k := _spot_vicino()
	if k < 0:
		return -1.0
	return float(_player.global_position.distance_to(_spots[k]["pos"]))


func agisci_e() -> void:
	var k := _spot_vicino()
	if k >= 0:
		_scava(k)


func _iscrivi_alla_e() -> void:
	var arb := get_tree().get_first_node_in_group("arbitro_e")
	if arb:
		arb.iscrivi(self, "scavo", arb.FUGACE,
				Callable(self, "distanza_e"), Callable(self, "agisci_e"))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _busy:
		return
	if _player == null or not _player.is_physics_processing():
		return
	var k := _spot_vicino()
	if k < 0:
		return
	_scava(k)
	get_viewport().set_input_as_handled()


func _scava(k: int) -> void:
	_busy = true
	var spot: Dictionary = _spots[k]
	_spots.remove_at(k)
	var node := spot["node"] as Node3D
	var pos: Vector3 = spot["pos"]
	_scavati.append(int(spot["i"]))
	# Mochi si volta e si accuccia a scavare con le zampine
	var dir := ((pos - _player.global_position) * Vector3(1, 0, 1)).normalized()
	_mochi.set("_yaw", atan2(-dir.x, -dir.z))
	_mochi.call("hold_reach", true)
	var tw := create_tween()
	tw.tween_property(_mochi, "crouch", 1.0, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# tre scavate: sbuffo di terra e zampata, in ritmo
	for colpo in 3:
		tw.tween_interval(0.24)
		tw.tween_callback(func() -> void:
			_sbuffo(pos + Vector3(0, 0.08, 0))
			if _sfx:
				_sfx.play("step_grass%d" % (1 + randi() % 2), -13.0, 0.7 + randf() * 0.2))
	tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
		_estrai(int(spot["i"]), pos))


func _estrai(indice: int, pos: Vector3) -> void:
	var dono := trovamento(_giorno, indice)
	var pepita := _fai_trovamento(dono)
	pepita.position = pos + Vector3(0, 0.05, 0)
	add_child(pepita)
	# il trovamento salta in un arco fino al petto di Mochi (come il fungo)
	var dest: Vector3 = _player.global_position + Vector3(0, 1.2, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pepita, "global_position:x", dest.x, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pepita, "global_position:z", dest.z, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pepita, "global_position:y", dest.y + 0.45, 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(pepita, "global_position:y", dest.y, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(pepita, "rotation:y", TAU, 0.4)
	tw.chain().tween_callback(func() -> void:
		if _sfx:
			_sfx.place_ok()
		_consegna(dono)
		var st := create_tween()
		st.tween_property(pepita, "scale", Vector3.ONE * 0.02, 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		st.tween_callback(pepita.queue_free)
		var mt := create_tween()
		mt.tween_property(_mochi, "crouch", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		mt.tween_callback(func() -> void:
			_mochi.call("hold_reach", false)
			_busy = false)
		_salva())


func _consegna(dono: Dictionary) -> void:
	var visitors := get_node_or_null("../Visitors")
	var eco := get_tree().get_first_node_in_group("economy")
	var testo := ""
	match str(dono["tipo"]):
		"noccioline":
			var n := int(dono["n"])
			if eco:
				eco.add_nuts(n)
			testo = L10n.tf("Sotto terra: %d noccioline! 🌰", [n])
		"ingrediente":
			var id := str(dono["id"])
			var cucina := get_node_or_null("../Cooking")
			if cucina:
				cucina.add_ingredient(id, 1)
			testo = L10n.tf("Sotto terra: %s, dritta in dispensa!", [CRIT.con_articolo(id)])
		"tesoro":
			var inv := get_node_or_null("../Inventory")
			if inv:
				inv.add_treasure(str(dono["id"]), 1)
			testo = L10n.t("Sotto terra: una campanella di coccio. Suona ancora!")
		_:
			if eco:
				eco.add_stars(1)
			testo = L10n.t("Sotto terra… una stellina! ⭐")
	if visitors:
		visitors.call("_show_toast", testo)


## Il modellino di ciò che esce dalla terra: un sacchettino, una carotina,
## la campanella o la stellina — abbastanza da leggersi in un arco di volo.
func _fai_trovamento(dono: Dictionary) -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	match str(dono["tipo"]):
		"noccioline":
			var sm := SphereMesh.new()
			sm.radius = 0.09
			sm.height = 0.16
			mi.mesh = sm
			mat.albedo_color = Color("d9b36a")
		"ingrediente":
			var sm := SphereMesh.new()
			sm.radius = 0.08
			sm.height = 0.16
			mi.mesh = sm
			mat.albedo_color = CRIT.colore(str(dono["id"]))
		"tesoro":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.075
			cm.height = 0.11
			mi.mesh = cm
			mat.albedo_color = Color("c08a5a")
		_:
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			mi.mesh = sm
			mat.albedo_color = Color("fff3c9")
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.9, 0.5)
			mat.emission_energy_multiplier = 1.4
	mi.material_override = mat
	node.add_child(mi)
	return node


# lo sbuffo di terra della zampata
func _sbuffo(pos: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(0.55, 0.44, 0.32, 0.85), Color(0.55, 0.44, 0.32, 0.4),
		Color(0.55, 0.44, 0.32, 0.0)])
	tex.gradient = grad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, -3.2, 0)
	var burst := GPUParticles3D.new()
	burst.amount = 10
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)


# ---------------------------------------------------------------- UI

func _process(_delta: float) -> void:
	_t += _delta
	_aggiorna_prompt()


func _aggiorna_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _busy:
		_prompt.visible = false
		return
	var k := _spot_vicino()
	if k < 0:
		_prompt.visible = false
		return
	var wp: Vector3 = (_spots[k]["pos"] as Vector3) + Vector3(0, 0.55, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.t("E — scava!")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
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


# ---------------------------------------------------------------- persistenza

func _salva() -> void:
	var build := get_tree().get_first_node_in_group("build_system")
	if build:
		build.call("request_save")


func save_extra() -> Dictionary:
	return {"scavi": {"giorno": _giorno, "scavati": _scavati}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("scavi")
	if not (d is Dictionary):
		return
	var giorno_salvato := int(d.get("giorno", 0))
	# gli scavi contano solo se il salvataggio è di OGGI: un giorno nuovo
	# rigenera tutto (i punti sono deterministici nel giorno)
	var oggi := int(_daynight.get("day")) if _daynight else giorno_salvato
	_giorno = oggi
	_scavati = []
	if giorno_salvato == oggi:
		for i in d.get("scavati", []):
			_scavati.append(int(i))
	(func() -> void: _rigenera()).call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_state() -> Dictionary:
	return {"giorno": _giorno, "spots": _spots.size(), "scavati": _scavati.size()}
