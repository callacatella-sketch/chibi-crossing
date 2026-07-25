extends Node3D

## Il ponte dell'ecosistema: la simulazione vive in C++
## (EcosystemManager, GDExtension), qui vive l'arte e il cablaggio.
## Le farfalle impollinano le aiuole fiorite e dove impollinano nascono
## fiori selvatici; più fiori attirano più farfalle; le lucciole
## depongono vicino all'acqua dello stagno; i passerotti calano sui semi
## che dimentichi piantando e raccogliendo. Il prato risponde davvero a
## come giochi — e lo stato si salva nel JSON del villaggio.

const BUTTERFLY_SHADER := preload("res://shaders/butterfly.gdshader")
const FIREFLY_SHADER := preload("res://shaders/firefly.gdshader")
const WILDFLOWER_SHADER := preload("res://shaders/wildflower.gdshader")
const TOON := preload("res://shaders/toon.gdshader")

var eco: EcosystemManager
var _daynight: Node3D
var _garden: Node
var _build: Node3D
var _bloom_acc := 0.0
var _sparrow_vis: Array[Node3D] = []

# i materiali della fauna, tenuti per ridipingerli con la stagione (le ali
# color ruggine d'autunno, il bagliore ambrato delle lucciole)
var _butterfly_mat: ShaderMaterial
var _firefly_mat: ShaderMaterial
var _wildflower_mat: ShaderMaterial
var _season := 0


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("ecosystem")
	add_to_group("season_listener")
	eco = EcosystemManager.new()
	add_child(eco)
	eco.configure(_butterfly_mesh(), _firefly_mesh(), _flower_mesh())
	var cozy := get_parent()
	eco.set_pond(cozy.POND_CENTER, cozy.POND_R)
	eco.set_meadow(Vector3(-13, 0, -13.5), Vector3(13, 0, 12))
	eco.set_ground_validator(_ground_ok)
	_build_sparrows()
	# i fratelli del CozyWorld entrano in scena dopo: lookup a fine frame
	(func():
		_daynight = get_node_or_null("../../DayNight")
		_garden = get_node_or_null("../../Garden")
		_build = get_tree().get_first_node_in_group("build_system")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_on_day_changed)).call_deferred()


# metodo, non lambda: la disconnessione è automatica se il nodo muore
func _on_day_changed(_d: int) -> void:
	eco.on_new_day()


# ---------------------------------------------------------------- stagioni

# le ali delle farfalle, i fiori selvatici e il bagliore delle lucciole,
# una veste per stagione (d'inverno la fauna è comunque rada/assente)
const BF_SEASON := [
	[Color("f6b3cc"), Color("9ec9f2"), Color("fae499")],  # primavera: pastello
	[Color("f79ec0"), Color("7fb0f0"), Color("ffe07a")],  # estate: vivido
	[Color("e79a5e"), Color("d6a94e"), Color("c86a3c")],  # autunno: ruggine, oro, rame
	[Color("d3dceb"), Color("b8c6de"), Color("dbe0e8")],  # inverno: gelide
]
const WF_SEASON := [
	[Color("fff7ea"), Color("f7bcd2"), Color("c7b3ef"), Color("fcdb8c")],
	[Color("fffdf2"), Color("ffb0cc"), Color("bfa6ef"), Color("ffd97a")],
	[Color("f3e6c8"), Color("e29a5e"), Color("caa06a"), Color("f0c05a")],
	[Color("e8ecf2"), Color("d8c0cc"), Color("c4bcd8"), Color("e6d8b0")],
]
const FF_SEASON := [
	Color(0.80, 1.0, 0.52),   # primavera: verde-lime
	Color(0.86, 1.0, 0.50),   # estate: caldo
	Color(1.0, 0.82, 0.42),   # autunno: ambra
	Color(0.72, 0.86, 1.0),   # inverno: freddo
]


## Il regista delle stagioni ridipinge la fauna del prato.
func set_season(season: int, _snow: float, _transition: bool) -> void:
	_season = clampi(season, 0, 3)
	if _butterfly_mat:
		var bf: Array = BF_SEASON[_season]
		_butterfly_mat.set_shader_parameter("col_a", bf[0])
		_butterfly_mat.set_shader_parameter("col_b", bf[1])
		_butterfly_mat.set_shader_parameter("col_c", bf[2])
	if _wildflower_mat:
		var wf: Array = WF_SEASON[_season]
		_wildflower_mat.set_shader_parameter("tint_a", wf[0])
		_wildflower_mat.set_shader_parameter("tint_b", wf[1])
		_wildflower_mat.set_shader_parameter("tint_c", wf[2])
		_wildflower_mat.set_shader_parameter("tint_d", wf[3])
	if _firefly_mat:
		_firefly_mat.set_shader_parameter("glow_color", FF_SEASON[_season])


func _process(delta: float) -> void:
	if _daynight:
		eco.set_night(_daynight.is_night())
	# ogni pochi secondi l'ecosistema rilegge quali aiuole sono in fiore
	_bloom_acc -= delta
	if _bloom_acc <= 0.0:
		_bloom_acc = 3.0
		if _garden:
			eco.set_flower_sources(_garden.bloomed_positions())
	_sync_sparrows(delta)


## I semi dimenticati (semina e raccolto li spargono attorno alle aiuole).
func drop_seeds(pos: Vector3, n: int) -> void:
	eco.drop_seeds(pos, n)


# un fiore selvatico può nascere solo su prato libero (niente pavimenti,
# aiuole o mobili nella cella)
func _ground_ok(pos: Vector3) -> bool:
	if not is_instance_valid(_build):
		_build = get_tree().get_first_node_in_group("build_system")
		if _build == null:
			return true
	var cell := Vector2i(roundi(pos.x), roundi(pos.z))
	for layer in [0, 1, 2]:
		if (_build.get("_placed")[layer] as Dictionary).has(cell):
			return false
	return true


# ---------------------------------------------------------------- mesh

# farfalla: due ali a quadrilatero, il battito lo fa il vertex shader
func _butterfly_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var quad: Array[Vector3] = [
			Vector3(side * 0.01, 0, 0.055), Vector3(side * 0.105, 0, 0.075),
			Vector3(side * 0.115, 0, -0.055), Vector3(side * 0.01, 0, -0.045),
		]
		var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
		for k in order:
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k])
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = BUTTERFLY_SHADER
	mesh.surface_set_material(0, mat)
	_butterfly_mat = mat
	return mesh


# lucciola: un quad billboard col bagliore additivo
func _firefly_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	var mat := ShaderMaterial.new()
	mat.shader = FIREFLY_SHADER
	quad.material = mat
	_firefly_mat = mat
	return quad


# fiore selvatico: gambo a croce, cinque petali e il cuoricino giallo.
# Il gambo ha COLOR.a = 0 (resta verde), i petali 1 (prendono la tinta).
func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color(0.45, 0.62, 0.34, 0.0)
	var petal := Color(1, 1, 1, 1.0)
	var heart := Color(0.98, 0.85, 0.4, 0.0)

	var add_quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color):
		for v in [a, b, c, a, c, d]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)

	# gambo: due lame incrociate
	for a in [0.0, PI * 0.5]:
		var dir := Vector3(cos(a) * 0.016, 0, sin(a) * 0.016)
		add_quad.call(-dir, dir, dir + Vector3(0, 0.24, 0), -dir + Vector3(0, 0.24, 0), stem)
	# petali: cinque quadretti inclinati a corolla
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a)) * 0.035
		var base := out * 0.02 + Vector3(0, 0.24, 0)
		var tip := out * 0.085 + Vector3(0, 0.275, 0)
		add_quad.call(base - side, base + side, tip + side * 0.6, tip - side * 0.6, petal)
	# il cuoricino
	var hs := 0.028
	add_quad.call(Vector3(-hs, 0.252, -hs), Vector3(hs, 0.252, -hs),
			Vector3(hs, 0.252, hs), Vector3(-hs, 0.252, hs), heart)

	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = WILDFLOWER_SHADER
	mat.set_shader_parameter("tint_a", Color("fff7ea"))
	mat.set_shader_parameter("tint_b", Color("f7bcd2"))
	mat.set_shader_parameter("tint_c", Color("c7b3ef"))
	mat.set_shader_parameter("tint_d", Color("fcdb8c"))
	mesh.surface_set_material(0, mat)
	_wildflower_mat = mat
	return mesh


# ---------------------------------------------------------------- passerotti

# i passerotti sono pochi (max 7): corpi veri disegnati qui, posizioni
# e stati letti dalla simulazione C++
func _build_sparrows() -> void:
	for i in 7:
		var bird := Node3D.new()
		bird.visible = false
		add_child(bird)
		var brown := _toon(Color("9a7a58"))
		var cream := _toon(Color("e8d5b8"))
		_ball(bird, 0.085, brown, Vector3(0, 0.09, 0.01), Vector3(1, 0.9, 1.25))
		_ball(bird, 0.055, cream, Vector3(0, 0.075, -0.045), Vector3(1, 0.75, 0.7))
		_ball(bird, 0.062, brown, Vector3(0, 0.16, -0.06))
		var beak := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.0
		bm.bottom_radius = 0.016
		bm.height = 0.05
		beak.mesh = bm
		beak.material_override = _toon(Color("e8a24a"))
		beak.position = Vector3(0, 0.155, -0.12)
		beak.rotation.x = -PI * 0.5
		bird.add_child(beak)
		var tail := _ball(bird, 0.05, brown, Vector3(0, 0.1, 0.12), Vector3(0.6, 0.25, 1.3))
		tail.rotation.x = 0.35
		for side: float in [-1.0, 1.0]:
			_ball(bird, 0.05, brown, Vector3(side * 0.07, 0.095, 0.02), Vector3(0.35, 0.6, 1.0))
		_sparrow_vis.append(bird)


# i corpi si mappano sull'id stabile del passerotto (non sull'indice):
# quando uno centrale sparisce, gli altri non si teletrasportano
var _sparrow_by_id := {}  # id -> indice del corpo nel pool


func _sync_sparrows(delta: float) -> void:
	var n: int = eco.sparrow_count()
	var alive := {}
	for i in n:
		alive[eco.sparrow_id(i)] = i
	# i corpi degli id spariti tornano liberi
	for id in _sparrow_by_id.keys():
		if not alive.has(id):
			_sparrow_vis[_sparrow_by_id[id]].visible = false
			_sparrow_by_id.erase(id)
	# un corpo libero per ogni id nuovo
	for id in alive:
		if _sparrow_by_id.has(id):
			continue
		for b in _sparrow_vis.size():
			if b not in _sparrow_by_id.values():
				_sparrow_by_id[id] = b
				_sparrow_vis[b].position = eco.sparrow_pos(alive[id])
				break
	for id in _sparrow_by_id:
		var i: int = alive[id]
		var bird := _sparrow_vis[_sparrow_by_id[id]]
		bird.visible = true
		bird.position = eco.sparrow_pos(i)
		var dir: Vector3 = eco.sparrow_dir(i)
		if Vector2(dir.x, dir.z).length() > 0.1:
			bird.rotation.y = lerp_angle(bird.rotation.y, atan2(-dir.x, -dir.z),
					1.0 - exp(-8.0 * delta))
		# beccata a terra, oppure alette che vibrano in volo
		if eco.sparrow_state(i) == 1:
			bird.rotation.x = maxf(sin(Time.get_ticks_msec() * 0.008) * 0.55, 0.0)
		else:
			bird.rotation.x = 0.0


func _toon(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo_color", color)
	return mat


func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 9
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"eco": eco.save_state()}


func load_extra(data: Dictionary) -> void:
	if data.has("eco"):
		eco.load_state(data["eco"])
