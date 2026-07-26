extends Node

## Giardinaggio vero. Pianta i semi in un'Aiuola, annaffiala (l'acqua
## viene dalla tua barra), e ogni notte dormita — o vissuta — i semi
## crescono di un passo: monticelli, germogli, boccioli, e infine la
## fioritura, festeggiata con petali e campanellini. Mai punitiva:
## un'aiuola non annaffiata semplicemente aspetta.
## L'Orto segue gli stessi stadi ma matura carote, zucche o bacche
## (la coltura dipende dalla cella): il raccolto va nella dispensa
## del Camino. Stadi e annaffiature sono salvati nel JSON.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const UI_BROWN := Color("6a4a3a")
const WATER_COST := 20.0

const PETALS := [Color("f4b8c8"), Color("fff6f9"), Color("c9a8f0"), Color("ffd76e")]
# i fiori del giardino cambiano tavolozza con la stagione: rosa di ciliegio
# a primavera, rosso e oro d'autunno (l'inverno mette in pausa, non uccide)
const PETALS_ESTATE := [Color("ff9ec2"), Color("fff2a8"), Color("b58cf0"), Color("ff8f6e")]
const PETALS_AUTUNNO := [Color("e0705a"), Color("e8a24a"), Color("c9603a"), Color("f0c050")]
const PETALS_INVERNO := [Color("cdbfe0"), Color("eaf0f6"), Color("b8c4dc"), Color("dcd0b0")]

# coltura -> [quanti a raccolto, etichetta raccolto, colore festa]
const CROPS := {
	"carota": [3, "3 carote", Color("f0913c")],
	"zucca": [2, "2 zucche", Color("e8813a")],
	"bacca": [4, "4 bacche", Color("b04a7a")],
}

var _build: Node3D
var _player: Node3D
var _daynight: Node3D
var _survival: Node
var _world: Node3D
var _sfx

# nodo aiuola -> {cell, crop("" fiori), stage(-1 vuota, 0 semi,
# 1 germogli, 2 boccioli, 3 fioritura/maturazione), watered, vis, wet}
var _beds := {}
var _near: Node3D
var _near_shroom := -1
var _busy := false
var _season := 0

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("season_listener")
	_player = get_node("%Player")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_world = get_node_or_null("../CozyWorld")
	_survival = _player.get_node_or_null("SurvivalComponent")
	_sfx = get_node_or_null(^"/root/Sfx")
	if _daynight:
		_daynight.day_changed.connect(_on_new_day)
	if _build.has_signal("placed_changed"):
		_build.connect("placed_changed", func(): _beds_dirty = true)
	_build_ui()


# la cache delle aiuole si ricostruisce solo quando il villaggio cambia,
# non con due scansioni complete a ogni frame
var _beds_dirty := true


func _process(_delta: float) -> void:
	if _beds_dirty:
		_beds_dirty = false
		_refresh_beds()
	_update_near()
	_update_prompt()


# ---------------------------------------------------------------- cache

func _refresh_beds() -> void:
	var flowers: Array[Node3D] = _build.get_placed_by_name("Aiuola")
	var patches: Array[Node3D] = _build.get_placed_by_name("Orto")
	var current: Array[Node3D] = flowers + patches
	for node in _beds.keys():
		if not is_instance_valid(node) or node not in current:
			_beds.erase(node)
	for node in current:
		if not _beds.has(node):
			var cell := Vector2i(roundi(node.position.x), roundi(node.position.z))
			_beds[node] = {
				"cell": cell,
				# la coltura è scritta nella terra: stessa cella, stessa verdura
				"crop": CROPS.keys()[absi(cell.x * 31 + cell.y * 17) % CROPS.size()] \
						if node in patches else "",
				"stage": -1,
				"watered": false,
				"vis": null,
				"wet": _make_wet_overlay(node),
			}


# velo di terra bagnata: si scurisce quando annaffi, svanisce crescendo
func _make_wet_overlay(bed: Node3D) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.4
	m.bottom_radius = 0.4
	m.height = 0.006
	m.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.22, 0.15, 0.1, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = Vector3(0, 0.076, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bed.add_child(mi)
	return mi


func _update_near() -> void:
	_near = null
	_near_shroom = -1
	if _busy:
		return
	var best := 1.3
	for node in _beds:
		if not is_instance_valid(node):
			continue
		var d: float = _player.global_position.distance_to((node as Node3D).global_position)
		if d < best:
			best = d
			_near = node
	if _near == null and _world:
		_near_shroom = _world.nearest_pickup(_player.global_position, 1.2)


# ---------------------------------------------------------------- azioni

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _busy:
		return
	if _near == null:
		if _near_shroom >= 0:
			_pick_mushroom(_near_shroom)
			get_viewport().set_input_as_handled()
		return
	var b: Dictionary = _beds[_near]
	match int(b["stage"]):
		-1:
			_plant(_near)
			get_viewport().set_input_as_handled()
		3:
			_harvest(_near)
			get_viewport().set_input_as_handled()
		_:
			if not b["watered"]:
				_water(_near)
				get_viewport().set_input_as_handled()


func _plant(bed: Node3D, con_mochi := true) -> void:
	_busy = true
	get_tree().call_group("regista", "note", "giardino")
	var b: Dictionary = _beds[bed]
	b["stage"] = 0
	b["watered"] = false
	# seminando qualche seme sfugge sempre: l'ecosistema se ne accorge
	var ecosys := get_tree().get_first_node_in_group("ecosystem")
	if ecosys:
		ecosys.drop_seeds(bed.global_position, 2)

	if not con_mochi:
		# la semina dell'ospite co-op: senza coreografia, solo il risultato
		_rebuild_vis(bed, true)
		_dirt_poof(bed.global_position + Vector3(0, 0.15, 0))
		if _sfx:
			_sfx.play("step_grass1", -14.0, 0.7)
		_save()
		get_tree().create_timer(0.7).timeout.connect(func(): _busy = false)
		return

	# --- la semina di Mochi: si volta, si ACCOVACCIA con la testolina
	# china, e sparge a due archi coi semini che cadono dalla zampa ---
	var mochi := _player.get_node("Mochi")
	var dir := ((bed.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	mochi.set("_yaw", atan2(-dir.x, -dir.z))
	var bag := _make_seed_bag()
	mochi.call("attach_to_paw", bag, false)   # il sacchettino, a sinistra
	bag.scale = Vector3.ONE * 0.05
	mochi.call("hold_sow", true)

	var tw := create_tween()
	tw.tween_property(bag, "scale", Vector3.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mochi, "crouch", 1.0, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# primo arco di spargitura: i semini volano dalla zampa alla terra
	tw.tween_callback(func():
		mochi.set("pour", 0.0)
		_seed_burst(mochi.call("paw_world"), bed.global_position)
		if _sfx:
			_sfx.play("step_grass1", -16.0, 0.8))
	tw.tween_property(mochi, "pour", 1.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# i monticelli sbocciano DOVE i semini sono appena caduti
	tw.tween_callback(func():
		_rebuild_vis(bed, true)
		_dirt_poof(bed.global_position + Vector3(0, 0.15, 0))
		if _sfx:
			_sfx.play("step_grass2", -15.0, 0.65))
	# secondo arco, per la parte d'aiuola rimasta
	tw.tween_callback(func():
		mochi.set("pour", 0.0)
		_seed_burst(mochi.call("paw_world"), bed.global_position))
	tw.tween_property(mochi, "pour", 1.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# risalita col mini-rimbalzo, il sacchettino svanisce
	tw.tween_property(mochi, "crouch", 0.0, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		mochi.call("hold_sow", false)
		var via := create_tween()
		via.tween_property(bag, "scale", Vector3.ONE * 0.03, 0.18) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		via.tween_callback(bag.queue_free))
	_save()
	get_tree().create_timer(2.1).timeout.connect(func(): _busy = false)


# il sacchettino di iuta dei semi, stretto dalla cordicella
func _make_seed_bag() -> Node3D:
	var bag := Node3D.new()
	var iuta := _pm(Color("c9a06a"), Color("ab8452"), 6.0, 0.5)
	_mesh(bag, _ball_mesh(0.07), iuta, Vector3(0, 0.02, 0), Vector3(1, 1.1, 0.85))
	_mesh(bag, _stem_mesh(0.05), _pm(Color("8a6a48"), Color("6f5238"), 5.0, 0.4),
			Vector3(0, 0.1, 0))
	_mesh(bag, _ball_mesh(0.032), iuta, Vector3(0, 0.13, 0), Vector3(1, 0.7, 1))
	return bag


# la manciata di semini: grani dorati che volano ad arco verso la terra,
# sgranati lungo il gesto (mai tutti insieme)
func _seed_burst(from: Vector3, to: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.028, 0.028)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("d9b36a")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	var dirv := (to - from) * Vector3(1, 0, 1)
	pm.direction = (dirv.normalized() + Vector3(0, 0.35, 0)).normalized()
	pm.spread = 22.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, -3.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var semi := GPUParticles3D.new()
	semi.amount = 9
	semi.lifetime = 0.55
	semi.one_shot = true
	semi.explosiveness = 0.25
	semi.local_coords = false
	semi.process_material = pm
	semi.draw_pass_1 = quad
	semi.position = from
	add_child(semi)
	semi.emitting = true
	get_tree().create_timer(1.2).timeout.connect(semi.queue_free)


func _water(bed: Node3D) -> void:
	_busy = true
	get_tree().call_group("regista", "note", "giardino")
	var b: Dictionary = _beds[bed]
	b["watered"] = true
	if _survival:
		_survival.set_water(maxf(0.0, _survival.get_water() - WATER_COST))

	# Mochi si volta verso l'aiuola e il bricco le sboccia IN ZAMPA
	var mochi := _player.get_node("Mochi")
	var dir := ((bed.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	mochi.set("_yaw", atan2(-dir.x, -dir.z))
	var can := _make_can()
	mochi.call("attach_to_paw", can)
	can.rotation.y = PI * 0.5   # beccuccio in avanti
	can.scale = Vector3.ONE * 0.05
	mochi.call("hold_pour", true)

	# la versata: le braccia si piegano col getto, il bricco si inclina,
	# la pioggerella parte solo quando il beccuccio guarda la terra
	var tw := create_tween()
	tw.tween_property(can, "scale", Vector3.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mochi, "pour", 1.0, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(can, "rotation:x", -0.9, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if _sfx:
			_sfx.water()
		_rain_over(bed))
	tw.tween_interval(1.0)
	tw.tween_property(mochi, "pour", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(can, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		mochi.call("hold_pour", false)
		var via := create_tween()
		via.tween_property(can, "scale", Vector3.ONE * 0.03, 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		via.tween_callback(can.queue_free))

	# la terra si scurisce quando il getto la tocca, non prima
	var wet := b["wet"] as MeshInstance3D
	var wtw := create_tween()
	wtw.tween_interval(0.75)
	wtw.tween_property(wet.material_override, "albedo_color:a", 0.42, 0.9)
	_save()
	get_tree().create_timer(2.3).timeout.connect(func(): _busy = false)


func _harvest(bed: Node3D, con_mochi := true) -> void:
	_busy = true
	get_tree().call_group("regista", "note", "giardino")
	var b: Dictionary = _beds[bed]
	var crop := String(b["crop"])
	b["stage"] = -1
	b["watered"] = false
	# nel trambusto del raccolto cadono semi: cibo per i passerotti,
	# o fiori selvatici di domani
	var ecosys := get_tree().get_first_node_in_group("ecosystem")
	if ecosys:
		ecosys.drop_seeds(bed.global_position, 3)
	var vis := b["vis"] as Node3D
	if vis:
		var vtw := create_tween()
		vtw.tween_property(vis, "scale", Vector3.ONE * 0.03, 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		vtw.tween_callback(vis.queue_free)
		b["vis"] = null

	if not con_mochi:
		# il raccolto dell'ospite co-op: senza coreografia
		_premia_raccolto(bed.global_position, crop)
		if _sfx:
			_sfx.place_ok()
		_save()
		get_tree().create_timer(0.8).timeout.connect(func(): _busy = false)
		return

	# --- la raccolta di Mochi: giù ad afferrare, su a sollevare ---
	var mochi := _player.get_node("Mochi")
	var dir := ((bed.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	mochi.set("_yaw", atan2(-dir.x, -dir.z))
	mochi.call("hold_reach", true)
	var tesoro := _make_trophy(crop)
	add_child(tesoro)
	tesoro.global_position = bed.global_position + Vector3(0, 0.12, 0)
	tesoro.scale = Vector3.ONE * 0.05

	var tw := create_tween()
	# le zampine scendono, il tesoro sboccia dalla terra
	tw.tween_property(mochi, "crouch", 1.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tesoro, "scale", Vector3.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if _sfx:
			_sfx.play("step_grass2", -14.0, 0.7))
	# il SOLLEVAMENTO: le zampe salgono e il tesoro CON loro
	tw.tween_property(mochi, "pour", 1.0, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(mochi, "crouch", 0.0, 0.45) \
			.set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(tesoro, "global_position",
			_player.global_position + Vector3(0, 1.32, 0), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# l'esultanza: saltello col trofeo in alto, festa di colori
	tw.tween_callback(func():
		_premia_raccolto(_player.global_position + Vector3(0, 1.1, 0), crop)
		if _sfx:
			_sfx.place_ok()
		var jt := create_tween()
		jt.tween_property(mochi, "joy", 1.0, 0.42) \
				.set_trans(Tween.TRANS_SINE)
		jt.tween_callback(func(): mochi.set("joy", 0.0)))
	tw.tween_interval(0.5)
	# via in dispensa: il tesoro vola su e svanisce
	tw.tween_property(tesoro, "scale", Vector3.ONE * 0.03, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tesoro, "global_position:y",
			_player.global_position.y + 1.9, 0.28)
	tw.tween_callback(func():
		tesoro.queue_free()
		mochi.call("hold_reach", false))
	_save()
	get_tree().create_timer(2.0).timeout.connect(func(): _busy = false)


# la festa e la dispensa del raccolto (petali per i fiori, colore e
# ingredienti per l'orto) — condivisa tra Mochi e ospiti
func _premia_raccolto(pos: Vector3, crop: String) -> void:
	if crop.is_empty():
		_petal_burst(pos, 30)
		return
	var info: Array = CROPS[crop]
	_burst(pos, Color(info[2], 0.95), 26, 1.4, Vector2(0.09, 0.09))
	var cooking := get_node_or_null("../Cooking")
	if cooking:
		cooking.add_ingredient(crop, int(info[0]))
	var visitors := get_node_or_null("../Visitors")
	if visitors:
		visitors.call("_show_toast", "+%s nella dispensa!" % info[1])


# il trofeo del raccolto: l'ortaggio simbolo (o il mazzolino) da
# sollevare al cielo con entrambe le zampine
func _make_trophy(crop: String) -> Node3D:
	var t := Node3D.new()
	match crop:
		"carota":
			var root := _pm(Color("f0913c"), Color("d97a2a"), 5.0, 0.45)
			var cono := CylinderMesh.new()
			cono.top_radius = 0.055
			cono.bottom_radius = 0.0
			cono.height = 0.2
			_mesh(t, cono, root, Vector3(0, 0.1, 0))
			var ciuffo := _pm(Color("7cbf5e"), Color("5e9c48"), 7.0, 0.5)
			for k in 3:
				var a := float(k) / 3.0 * TAU
				var leaf := _mesh(t, _ball_mesh(0.03), ciuffo,
						Vector3(cos(a) * 0.025, 0.23, sin(a) * 0.025), Vector3(0.5, 1.6, 0.5))
				leaf.rotation.x = cos(a) * 0.3
				leaf.rotation.z = sin(a) * 0.3
		"zucca":
			var skin := _pm(Color("e8813a"), Color("cf6a28"), 4.0, 0.5)
			_mesh(t, _ball_mesh(0.12), skin, Vector3(0, 0.1, 0), Vector3(1, 0.82, 1))
			for k in 6:
				var ga := float(k) / 6.0 * TAU
				_mesh(t, _ball_mesh(0.062), skin,
						Vector3(cos(ga) * 0.062, 0.1, sin(ga) * 0.062), Vector3(1, 1.05, 1))
			var st := _mesh(t, _stem_mesh(0.06), _pm(Color("7a9a4e"), Color("62823e"), 5.0, 0.4),
					Vector3(0.01, 0.21, 0))
			st.rotation.z = -0.35
		"bacca":
			var berry := _pm(Color("b04a7a"), Color("8e3862"), 7.0, 0.4)
			_mesh(t, _ball_mesh(0.055), berry, Vector3(-0.04, 0.08, 0))
			_mesh(t, _ball_mesh(0.05), berry, Vector3(0.045, 0.1, 0.02))
			_mesh(t, _ball_mesh(0.045), berry, Vector3(0.0, 0.06, -0.045))
			_mesh(t, _stem_mesh(0.07), _pm(Color("6a8a4e"), Color("55703e"), 5.0, 0.4),
					Vector3(0, 0.15, 0))
		_:
			# il mazzolino di fiori del prato
			var stelo := _pm(Color("7fae6a"), Color("6a9a58"), 8.0, 0.5)
			for k in 3:
				var a := float(k) / 3.0 * TAU + 0.4
				var p := Vector3(cos(a) * 0.03, 0.09, sin(a) * 0.03)
				_mesh(t, _stem_mesh(0.16), stelo, p)
				var col: Color = _petals()[k % 4]
				var pet := _pm(col, col.lightened(0.2), 8.0, 0.5)
				for j in 5:
					var pa := float(j) / 5.0 * TAU
					_mesh(t, _ball_mesh(0.026), pet,
							p + Vector3(cos(pa) * 0.036, 0.17, sin(pa) * 0.036), Vector3(1, 0.55, 1))
				_mesh(t, _ball_mesh(0.02), _pm(Color("ffd76e"), Color("eec254"), 8.0, 0.4),
						p + Vector3(0, 0.175, 0))
	return t


# il fungo si stacca con uno sbuffo di terra, finisce TRA le zampine
# accovacciate, e sale al cielo con l'esultanza
func _pick_mushroom(i: int) -> void:
	_busy = true
	var node: Node3D = _world.collect_pickup(i)
	var mochi := _player.get_node("Mochi")
	var dir := ((node.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	mochi.set("_yaw", atan2(-dir.x, -dir.z))
	mochi.call("hold_reach", true)
	_dirt_poof(node.global_position + Vector3(0, 0.06, 0))
	if _sfx:
		_sfx.play("step_grass2", -13.0, 0.62)

	var tw := create_tween()
	# giù ad afferrare: il fungo salta nelle zampine
	tw.tween_property(mochi, "crouch", 1.0, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var tra_le_zampe: Vector3 = mochi.call("to_global", Vector3(0, 0.5, -0.32))
	var mid := (node.global_position + tra_le_zampe) * 0.5 + Vector3(0, 0.4, 0)
	tw.parallel().tween_property(node, "global_position", mid, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "rotation:x", 0.5, 0.2)
	tw.tween_property(node, "global_position", tra_le_zampe, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# su a sollevarlo, e l'esultanza col saltello
	tw.tween_property(mochi, "pour", 1.0, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(mochi, "crouch", 0.0, 0.45) \
			.set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(node, "global_position",
			_player.global_position + Vector3(0, 1.32, 0), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if _sfx:
			_sfx.place_ok()
		var jt := create_tween()
		jt.tween_property(mochi, "joy", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
		jt.tween_callback(func(): mochi.set("joy", 0.0)))
	tw.tween_interval(0.45)
	tw.tween_property(node, "scale", Vector3.ONE * 0.04, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "global_position:y",
			_player.global_position.y + 1.85, 0.24)
	tw.tween_callback(func():
		node.queue_free()
		mochi.call("hold_reach", false)
		var cooking := get_node_or_null("../Cooking")
		if cooking:
			cooking.add_ingredient("fungo", 1)
		var visitors := get_node_or_null("../Visitors")
		if visitors:
			visitors.call("_show_toast", "+1 fungo nella dispensa!")
		_busy = false)


# la tavolozza dei fiori di questa stagione
func _petals() -> Array:
	match _season:
		1: return PETALS_ESTATE
		2: return PETALS_AUTUNNO
		3: return PETALS_INVERNO
		_: return PETALS


## Il regista delle stagioni: ridipinge i fiori già sbocciati e passa la
## stagione al giardino (che d'inverno riposa).
func set_season(season: int, _snow: float, _transition: bool) -> void:
	_season = clampi(season, 0, 3)
	# le aiuole in bocciolo/fioritura prendono i colori nuovi
	for bed in _beds:
		var b: Dictionary = _beds[bed]
		if String(b["crop"]).is_empty() and int(b["stage"]) >= 2:
			_rebuild_vis(bed, false)


func _on_new_day(_day: int) -> void:
	# d'inverno il giardino riposa sotto la neve: i semi aspettano la
	# primavera. Mai punitivo — niente muore, la crescita si mette in pausa.
	# A meno che il villaggio non abbia una Serra (il sogno del mercante):
	# col suo tepore si cresce anche a gennaio. Una volta al giorno: niente cache
	if _season == 3 and _build.get_placed_by_name("Serra").is_empty():
		return
	for bed in _beds:
		var b: Dictionary = _beds[bed]
		if int(b["stage"]) >= 0 and int(b["stage"]) < 3 and b["watered"]:
			b["stage"] = int(b["stage"]) + 1
			b["watered"] = false
			var wet := b["wet"] as MeshInstance3D
			var tw := create_tween()
			tw.tween_property(wet.material_override, "albedo_color:a", 0.0, 1.2)
			_rebuild_vis(bed, true)
			if int(b["stage"]) == 3:
				# la fioritura (o la maturazione)! festeggiata a dovere,
				# e incisa sugli anelli del Grande Albero
				var gtree := get_tree().get_first_node_in_group("grande_albero")
				if gtree:
					gtree.engrave_once("fioritura", "✿", "una fioritura nel giardino")
				# la prima fioritura regala il cappello di petali
				var wr := get_tree().get_first_node_in_group("guardaroba")
				if wr:
					wr.unlock("cappello_petali")
				var crop := String(b["crop"])
				if crop.is_empty():
					_petal_burst((bed as Node3D).global_position + Vector3(0, 0.4, 0), 40)
				else:
					_burst((bed as Node3D).global_position + Vector3(0, 0.4, 0),
							Color((CROPS[crop] as Array)[2], 0.95), 34, 1.5, Vector2(0.09, 0.09))
				if _sfx:
					_sfx.build_open()
			else:
				_sparkle_ring(bed as Node3D)
	_save()


# ---------------------------------------------------------------- visuali

func _pm(a: Color, b: Color, grain := 5.0, amount := 0.5, wind := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	mat.set_shader_parameter("wind_strength", wind)
	return mat


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _ball_mesh(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


func _stem_mesh(h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.011
	m.bottom_radius = 0.014
	m.height = h
	m.radial_segments = 6
	return m


func _rebuild_vis(bed: Node3D, pop: bool) -> void:
	var b: Dictionary = _beds[bed]
	var old := b["vis"] as Node3D
	if old:
		old.queue_free()
		b["vis"] = null
	var stage := int(b["stage"])
	if stage < 0:
		return

	var vis := Node3D.new()
	bed.add_child(vis)
	b["vis"] = vis

	var cell: Vector2i = b["cell"]
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.x * 131 + cell.y * 517 + 7

	var soil := _pm(Color("5e4534"), Color("50392c"), 3.0, 0.4)
	var sprout := _pm(Color("8fd07a"), Color("6fae5e"), 6.0, 0.5, 0.03)
	var stem := _pm(Color("7fae6a"), Color("6a9a58"), 6.0, 0.5, 0.03)

	var crop := String(b["crop"])
	if not crop.is_empty() and stage >= 2:
		# l'orto matura verdure, non fiori: dallo stadio 2 fa strada sua
		_build_crop_vis(vis, crop, stage, rng, soil, stem)
	else:
		_build_flower_vis(vis, stage, rng, soil, sprout, stem)

	if pop:
		vis.scale = Vector3.ONE * 0.1
		var tw := create_tween()
		tw.tween_property(vis, "scale", Vector3.ONE, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_flower_vis(vis: Node3D, stage: int, rng: RandomNumberGenerator,
		soil: Material, sprout: Material, stem: Material) -> void:
	for i in 5:
		var a := float(i) / 5.0 * TAU + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(0.12, 0.3)
		var p := Vector3(cos(a) * r, 0.07, sin(a) * r)
		match stage:
			0:
				# monticelli di semina
				_mesh(vis, _ball_mesh(0.045), soil, p, Vector3(1, 0.5, 1))
			1:
				# germogli: due foglioline tenere
				_mesh(vis, _stem_mesh(0.09), sprout, p + Vector3(0, 0.045, 0))
				for side: float in [-1.0, 1.0]:
					var leaf := _mesh(vis, _ball_mesh(0.03), sprout,
							p + Vector3(side * 0.028, 0.1, 0), Vector3(1, 0.45, 0.7))
					leaf.rotation.z = side * 0.5
			2:
				# steli con boccioli chiusi
				_mesh(vis, _stem_mesh(0.2), stem, p + Vector3(0, 0.1, 0))
				var bud_col: Color = _petals()[rng.randi() % 4]
				_mesh(vis, _ball_mesh(0.038), _pm(bud_col.darkened(0.15), bud_col.darkened(0.3), 8.0, 0.4),
						p + Vector3(0, 0.22, 0), Vector3(0.8, 1.25, 0.8))
			3:
				# fioritura piena
				_mesh(vis, _stem_mesh(0.24), stem, p + Vector3(0, 0.12, 0))
				var col: Color = _petals()[rng.randi() % 4]
				var pet := _pm(col, col.lightened(0.18), 8.0, 0.5, 0.02)
				for k in 5:
					var pa := float(k) / 5.0 * TAU
					_mesh(vis, _ball_mesh(0.032), pet,
							p + Vector3(cos(pa) * 0.045, 0.25, sin(pa) * 0.045), Vector3(1, 0.55, 1))
				_mesh(vis, _ball_mesh(0.026), _pm(Color("ffd76e"), Color("eec254"), 8.0, 0.4),
						p + Vector3(0, 0.255, 0))


# le verdure dell'orto: stadio 2 acerbe e piccole, stadio 3 mature
func _build_crop_vis(vis: Node3D, crop: String, stage: int,
		rng: RandomNumberGenerator, soil: Material, stem: Material) -> void:
	var ripe := stage >= 3
	var s := 1.0 if ripe else 0.55
	match crop:
		"carota":
			# ciuffi piumati e la puntina arancione che spunta dalla terra
			var tops := _pm(Color("7cbf5e"), Color("5e9c48"), 7.0, 0.5, 0.04)
			var root := _pm(Color("f0913c"), Color("d97a2a"), 5.0, 0.45) if ripe \
					else _pm(Color("e8b06a"), Color("d09a52"), 5.0, 0.45)
			for i in 5:
				var a := float(i) / 5.0 * TAU + rng.randf_range(-0.25, 0.25)
				var r := rng.randf_range(0.14, 0.3)
				var p := Vector3(cos(a) * r, 0.07, sin(a) * r)
				_mesh(vis, _ball_mesh(0.05), soil, p, Vector3(1, 0.4, 1))
				if ripe:
					_mesh(vis, _ball_mesh(0.042), root, p + Vector3(0, 0.028, 0),
							Vector3(1, 0.75, 1))
				for k in 3:
					var ka := float(k) / 3.0 * TAU + rng.randf()
					var leaf := _mesh(vis, _ball_mesh(0.028 * s), tops,
							p + Vector3(cos(ka) * 0.028, 0.05 + 0.07 * s, sin(ka) * 0.028),
							Vector3(0.5, 1.7, 0.5))
					leaf.rotation.x = cos(ka) * 0.35
					leaf.rotation.z = sin(ka) * 0.35
		"zucca":
			# la zucca panciuta a spicchi, col picciolo ricurvo
			var skin := _pm(Color("e8813a"), Color("cf6a28"), 4.0, 0.5) if ripe \
					else _pm(Color("a8b85e"), Color("8fa04c"), 4.0, 0.5)
			var picciolo := _pm(Color("7a9a4e"), Color("62823e"), 5.0, 0.4)
			for gp: Vector3 in [Vector3(-0.14, 0, -0.1), Vector3(0.2, 0, 0.16)]:
				var big := gp.x < 0.0
				var pr := (0.16 if big else 0.11) * s
				var base := gp + Vector3(0, 0.07 + pr * 0.62, 0)
				for k in 6:
					var ga := float(k) / 6.0 * TAU
					_mesh(vis, _ball_mesh(pr * 0.52), skin,
							base + Vector3(cos(ga) * pr * 0.5, 0, sin(ga) * pr * 0.5),
							Vector3(1, 1.15, 1))
				_mesh(vis, _ball_mesh(pr * 0.62), skin, base, Vector3(1, 1.05, 1))
				var st := _mesh(vis, _stem_mesh(0.07 * s), picciolo,
						base + Vector3(0.012, pr * 0.72, 0))
				st.rotation.z = -0.4
			# una fogliona da zucca accanto
			var leaf := _mesh(vis, _ball_mesh(0.06 * s), picciolo,
					Vector3(0.02, 0.1, -0.26), Vector3(1.5, 0.3, 1.2))
			leaf.rotation.y = rng.randf() * TAU
		"bacca":
			# cespuglietti tondi punteggiati di bacche violacee
			var bush := _pm(Color("6fae5e"), Color("578e48"), 5.0, 0.55, 0.03)
			var berry := _pm(Color("b04a7a"), Color("8e3862"), 7.0, 0.4) if ripe \
					else _pm(Color("cc7a9a"), Color("b06484"), 7.0, 0.4)
			for i in 3:
				var a := float(i) / 3.0 * TAU + 0.5 + rng.randf_range(-0.2, 0.2)
				var r := rng.randf_range(0.12, 0.24)
				var p := Vector3(cos(a) * r, 0.07, sin(a) * r)
				var br := 0.1 * s
				_mesh(vis, _stem_mesh(0.05), stem, p + Vector3(0, 0.025, 0))
				_mesh(vis, _ball_mesh(br), bush, p + Vector3(0, 0.05 + br * 0.7, 0))
				_mesh(vis, _ball_mesh(br * 0.7), bush,
						p + Vector3(br * 0.5, 0.05 + br * 0.9, br * 0.3))
				if ripe:
					for k in 4:
						var ba := rng.randf() * TAU
						var bh := 0.05 + br * 0.7 + rng.randf_range(-0.02, 0.05)
						_mesh(vis, _ball_mesh(0.02), berry,
								p + Vector3(cos(ba) * br * 0.85, bh, sin(ba) * br * 0.85))


## Il bricco teal, pronto per una zampa o per fluttuare (co-op).
func _make_can() -> Node3D:
	var can := Node3D.new()
	var teal := _pm(Color("8fc0c8"), Color("74a8b0"), 4.0, 0.45)
	var body_m := CylinderMesh.new()
	body_m.top_radius = 0.08
	body_m.bottom_radius = 0.1
	body_m.height = 0.14
	_mesh(can, body_m, teal, Vector3.ZERO)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.018
	spout.bottom_radius = 0.028
	spout.height = 0.16
	var sp := _mesh(can, spout, teal, Vector3(0.12, 0.03, 0))
	sp.rotation.z = -1.0
	_mesh(can, _ball_mesh(0.032), teal, Vector3(0.2, 0.075, 0), Vector3(1.4, 0.5, 0.9))
	return can


# annaffiatoio che appare, si inclina sull'aiuola e svanisce
# (resta per l'aiuto dell'amico co-op, che non ha la coreografia)
func _spawn_watering_can(bed: Node3D) -> void:
	var can := _make_can()
	add_child(can)
	var dir := ((bed.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	can.position = bed.global_position - dir * 0.45 + Vector3(0, 0.55, 0)
	can.look_at(bed.global_position + Vector3(0, 0.4, 0), Vector3.UP)
	can.rotate_object_local(Vector3.UP, -PI * 0.5)
	can.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(can, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(can, "rotation:z", can.rotation.z - 0.5, 0.3) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.7)
	tw.tween_property(can, "scale", Vector3.ONE * 0.03, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(can.queue_free)


# la pioggerella: goccioline azzurre che cadono sull'aiuola
func _rain_over(bed: Node3D) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(0.62, 0.82, 0.95, 0.9), Color(0.62, 0.82, 0.95, 0.5), Color(0.62, 0.82, 0.95, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.04, 0.3)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, -3.4, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.1
	var drops := GPUParticles3D.new()
	drops.amount = 42
	drops.lifetime = 0.55
	drops.one_shot = true
	drops.explosiveness = 0.0
	drops.local_coords = false
	drops.process_material = pm
	drops.draw_pass_1 = quad
	drops.position = bed.global_position + Vector3(0, 0.75, 0)
	add_child(drops)
	drops.emitting = true
	get_tree().create_timer(2.0).timeout.connect(drops.queue_free)


func _dirt_poof(pos: Vector3) -> void:
	_burst(pos, Color(0.48, 0.36, 0.26, 0.9), 14, 0.9, Vector2(0.1, 0.1))


func _petal_burst(pos: Vector3, amount: int) -> void:
	_burst(pos, Color(0.96, 0.75, 0.83, 0.95), amount, 1.6, Vector2(0.09, 0.09))


func _sparkle_ring(bed: Node3D) -> void:
	_burst(bed.global_position + Vector3(0, 0.3, 0), Color(1.0, 0.94, 0.7, 0.9), 16, 1.1, Vector2(0.12, 0.12))


func _burst(pos: Vector3, color: Color, amount: int, speed: float, size: Vector2) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([color, Color(color, color.a * 0.5), Color(color, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -1.6, 0)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var burst := GPUParticles3D.new()
	burst.amount = amount
	burst.lifetime = 0.9
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.6).timeout.connect(burst.queue_free)


# ---------------------------------------------------------------- UI

func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _busy or (_near == null and _near_shroom < 0):
		_prompt.visible = false
		return
	if _near == null:
		# il tesoro della passeggiata nel bosco
		var sp: Vector3 = _world.get("_pickups")[_near_shroom].global_position + Vector3(0, 0.6, 0)
		if cam.is_position_behind(sp):
			_prompt.visible = false
			return
		_prompt_label.text = "E — raccogli il fungo"
		_prompt.reset_size()
		var spp := cam.unproject_position(sp)
		_prompt.position = spp - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
		_prompt.visible = true
		return
	var b: Dictionary = _beds[_near]
	var crop := String(b["crop"])
	var plural := String((CROPS[crop] as Array)[1]).substr(2) if not crop.is_empty() else ""
	var text := ""
	match int(b["stage"]):
		-1:
			text = "E — pianta i semi" if crop.is_empty() else "E — semina le %s" % plural
		3:
			text = "E — raccogli il mazzolino" if crop.is_empty() else "E — raccogli le %s" % plural
		_:
			text = "cresce stanotte ✿" if b["watered"] else "E — annaffia"
	var wp: Vector3 = _near.global_position + Vector3(0, 0.85, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
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


# ---------------------------------------------------------------- persistenza

func _save() -> void:
	_build.request_save()


func save_extra() -> Dictionary:
	var rows := []
	for node in _beds:
		var b: Dictionary = _beds[node]
		rows.append([b["cell"].x, b["cell"].y, int(b["stage"]), bool(b["watered"])])
	return {"garden": rows}


func load_extra(data: Dictionary) -> void:
	_refresh_beds()
	for r in data.get("garden", []):
		if r is not Array or r.size() != 4:
			continue
		var cell := Vector2i(int(r[0]), int(r[1]))
		for node in _beds:
			var b: Dictionary = _beds[node]
			if b["cell"] == cell:
				b["stage"] = int(r[2])
				b["watered"] = bool(r[3])
				_rebuild_vis(node, false)
				(b["wet"] as MeshInstance3D).material_override.albedo_color.a = \
						0.42 if b["watered"] else 0.0
				break


# ---------------------------------------------------------------- debug CLI

## L'aiuola più vicina a una posizione (per l'amico co-op).
func nearest_bed(pos: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_d
	for node in _beds:
		var d: float = pos.distance_to((node as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## L'aiuto dell'ospite co-op: pianta, annaffia (gratis: gli ospiti non
## consumano la borraccia di Mochi) o raccoglie, con le stesse feste.
func guest_help(bed: Node3D) -> void:
	var b: Dictionary = _beds.get(bed, {})
	if b.is_empty() or _busy:
		return
	match int(b["stage"]):
		-1:
			_plant(bed, false)   # l'ospite semina senza la coreografia di Mochi
		3:
			_harvest(bed, false)
		_:
			if bool(b["watered"]):
				return
			b["watered"] = true
			if _sfx:
				_sfx.water()
			_spawn_watering_can(bed)
			_rain_over(bed)
			var wet := b["wet"] as MeshInstance3D
			var tw := create_tween()
			tw.tween_property(wet.material_override, "albedo_color:a", 0.42, 0.9)
			_save()


## Un'aiuola piantata che aspetta l'acqua, vicino a una posizione:
## è quella che chiama i residenti ordinati (VillagerBrain).
func bed_needing_water(from: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_d
	for node in _beds:
		var b: Dictionary = _beds[node]
		if int(b["stage"]) < 0 or int(b["stage"]) >= 3 or bool(b["watered"]):
			continue
		var d: float = from.distance_to((node as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Un residente annaffia da solo: stesso rito dell'annaffiatoio, zero
## borraccia. L'autosufficienza che aiuta davvero il giocatore.
func villager_water(bed: Node3D) -> void:
	var b: Dictionary = _beds.get(bed, {})
	if b.is_empty() or int(b["stage"]) < 0 or int(b["stage"]) >= 3 or bool(b["watered"]):
		return
	b["watered"] = true
	if _sfx:
		_sfx.water()
	# niente bricco fluttuante: il residente lo tiene in zampa (Visitor)
	_rain_over(bed)
	var wet := b["wet"] as MeshInstance3D
	var tw := create_tween()
	tw.tween_property(wet.material_override, "albedo_color:a", 0.42, 0.9)
	_save()


## Le aiuole in fiore e gli orti maturi: le fonti di nettare
## che l'ecosistema legge per la capacità portante delle farfalle.
func bloomed_positions() -> PackedVector3Array:
	# d'inverno niente fiori aperti: le farfalle non hanno più dove posarsi
	# e sfollano piano dal prato gelato
	if _season == 3:
		return PackedVector3Array()
	var out := PackedVector3Array()
	for bed in _beds:
		if int(_beds[bed]["stage"]) == 3:
			out.append((bed as Node3D).global_position)
	return out


func debug_plant() -> void:
	if not _beds.is_empty():
		_plant(_beds.keys()[0])


## Per il bootstrap del salvataggio: porta un'aiuola allo stadio dato.
func debug_set_stage(cell: Vector2i, stage: int, watered: bool) -> void:
	for node in _beds:
		var b: Dictionary = _beds[node]
		if (b["cell"] as Vector2i) == cell:
			b["stage"] = stage
			b["watered"] = watered
			_rebuild_vis(node, false)
			(b["wet"] as MeshInstance3D).material_override.albedo_color.a = \
					0.42 if watered else 0.0
			return


func debug_plant_cell(cell: Vector2i) -> void:
	for node in _beds:
		if (_beds[node]["cell"] as Vector2i) == cell:
			_busy = false
			_plant(node)
			return


func debug_is_watered(cell: Vector2i) -> bool:
	for node in _beds:
		if (_beds[node]["cell"] as Vector2i) == cell:
			return bool(_beds[node]["watered"])
	return false


func debug_water() -> void:
	if not _beds.is_empty():
		_busy = false
		_water(_beds.keys()[0])


func debug_grow() -> void:
	for bed in _beds:
		_beds[bed]["watered"] = true
	_on_new_day(0)


func debug_plant_all() -> void:
	# in massa e senza coreografia: N sedute di semina sovrapposte
	# litigherebbero sui tween di Mochi
	for bed in _beds:
		if int(_beds[bed]["stage"]) < 0:
			_busy = false
			_plant(bed, false)
	_busy = false


func debug_pick() -> void:
	if _world and not (_world.get("_pickups") as Array).is_empty():
		_busy = false
		_pick_mushroom(0)


## Raccoglie (con coreografia) il primo letto maturo, teletrasportando
## il player accanto — per la verifica CLI.
func debug_harvest() -> void:
	for node in _beds:
		if int(_beds[node]["stage"]) == 3:
			_player.global_position = (node as Node3D).global_position + Vector3(0.9, 0, 0.6)
			_busy = false
			_harvest(node)
			return
