extends Node3D

## Il ponte dell'ecosistema: la simulazione vive in C++
## (EcosystemManager, GDExtension), qui vive l'arte e il cablaggio.
## Le farfalle impollinano le aiuole fiorite e dove impollinano nascono
## fiori selvatici; più fiori attirano più farfalle; le lucciole
## depongono vicino all'acqua dello stagno; i passerotti calano sui semi
## che dimentichi piantando e raccogliendo. Il prato risponde davvero a
## come giochi — e lo stato si salva nel JSON del villaggio.

const BUTTERFLY_SHADER := preload("res://shaders/butterfly.gdshader")
## La sagoma delle farfalle: una fonte, due montaggi.
const FARF := preload("res://scenes/world/FarfalleGeo.gd")
## Gli organi di un fiore: la stessa casa dei fiori del prato.
const FIO := preload("res://scenes/world/FioriGeo.gd")
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
	add_to_group("calma_listener")
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
			_daynight.day_changed.connect(_on_day_changed)
		# l'Ecosystem nasce differito, DENTRO la costruzione del bosco: quando
		# arriva qui il regista ha già diffuso la stagione a un gruppo di cui
		# non facevamo ancora parte. Ci auto-inizializziamo dal DayNight, o un
		# salvataggio non-primaverile terrebbe la fauna coi colori di primavera
		if _daynight and _daynight.has_method("get_season"):
			set_season(int(_daynight.get_season()), float(_daynight.snow_amount()), false)).call_deferred()


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


## Il Fiato Sospeso pubblica la calma: di qui passa al C++, che la usa
## per le novanta farfalle del prato fitto e per i passerotti — che prima
## non sapevano nemmeno che il giocatore esistesse.
func set_calma(q: float, pos: Vector3) -> void:
	if eco:
		eco.set_osservatore(pos, q)


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

# LA FARFALLA delle novanta: la SAGOMA la fa FarfalleGeo, la stessa che
# monta i cinque rig nominati di CozyWorld — se divergessero, quella che
# catturi nel retino non sarebbe quella che hai visto volare.
#
# ⚠️ Erano DUE QUADRILATERI: quattro triangoli in tutto, con
# `set_normal(Vector3.UP)` su ogni vertice, e il torace era una BANDA
# DIPINTA dal fragment. Adesso ci sono quattro ali con l'intaglio, un
# corpo vero e le antenne — e il contratto col vertex shader viaggia nel
# COLOR (a = ala, g = posteriore) invece che in una soglia su |x|.
#
# ⚠️ UNA SUPERFICIE SOLA, e non è un vezzo: `_butterfly_mat` cattura il
# materiale della SUPERFICIE 0, e con due superfici il ritinto stagionale
# si spegnerebbe in silenzio.
func _butterfly_mesh() -> ArrayMesh:
	var mesh := FARF.piatta(0.230, 0.168)
	var mat := ShaderMaterial.new()
	mat.shader = BUTTERFLY_SHADER
	mat.set_shader_parameter("raggio_torace", FARF.RAGGIO_TORACE)
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


# IL FIORE SELVATICO nato dall'impollinazione. È il fiore più numeroso
# del prato (fino a 380 istanze) ed era anche il più squadrato del
# gioco: gambo = DUE LAME INCROCIATE, cinque petali = UN quadrilatero
# ciascuno, cuore = un QUADRATO orizzontale di 5.6 cm — sedici triangoli
# in tutto, e ogni vertice con `set_normal(Vector3.UP)`, cioè la luce ci
# cadeva sopra costante, senza nessun volume.
#
# Adesso usa gli stessi organi dei fiori del prato ([FioriGeo]).
#
# ⚠️ TRE COSE CHE NON SI TOCCANO, e ognuna si romperebbe in silenzio:
#  1. `COLOR.a` resta la maschera petalo/verde — `wildflower.gdshader` fa
#     `mix(vcol.rgb, petal, vcol.a)`, e con la maschera storta i petali
#     diventano verdi;
#  2. le tinte restano QUATTRO: `kind` 0..3 è PERSISTITO nel village.json
#     e riletto con un CLAMP(0,3), quindi tre tinte ricolorerebbero i
#     salvataggi vecchi;
#  3. UNA superficie sola: `_wildflower_mat` cattura il materiale della
#     SUPERFICIE 0, e con due superfici il ritinto stagionale si spegne.
func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# la maschera: `a` = 1 prende la tinta della specie, 0 resta verde.
	# `rgb` è il colore di chi NON prende la tinta.
	var stem := Color(0.42, 0.60, 0.32, 0.0)
	var petal := Color(1, 1, 1, 1.0)
	var heart := Color(0.98, 0.82, 0.36, 0.0)

	var cima := Vector3(0, 0.235, 0)
	FIO.stelo_su(st, Transform3D.IDENTITY,
			[Vector3.ZERO, Vector3(0.004, 0.11, -0.006), cima],
			[0.0040, 0.0031, 0.0025], 4, 4, FIO.VERDE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 2:
		var a := 1.1 + float(i) * PI + rng.randf_range(-0.3, 0.3)
		FIO.lamina_su(st, Transform3D(
				Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.36),
				Vector3(cos(a) * 0.004, 0.030, sin(a) * 0.004)),
				FIO.contorno_lancia(0.040, 0.0135, 4, 0.06), 1.9, 0.16,
				FIO.VERDE)
	var opz := {"incisione": 0.14, "arco": 0.24, "caduta": 0.18,
			"conca": 0.58, "torsione": 0.14, "ventre": 0.10,
			"apertura": 0.72, "punta": 0.75, "spessore": 0.00040}
	for i in 5:
		var a := float(i) / 5.0 * TAU + rng.randf_range(-0.10, 0.10)
		var o2 := opz.duplicate()
		o2["caduta"] = 0.18 + rng.randf_range(-0.07, 0.07)
		FIO.petalo_su(st, Transform3D(
				Basis(Vector3.UP, -a)
				* Basis(Vector3.BACK, -0.18 + rng.randf_range(-0.10, 0.10)),
				cima + Vector3(cos(a) * 0.0075, 0.0015, sin(a) * 0.0075)),
				0.0345, 0.0105, 3, 2, o2, rng.randf(), FIO.PETALO)
	FIO.cupola_su(st, Transform3D(Basis.IDENTITY, cima + Vector3(0, 0.0018, 0)),
			0.0125, 0.0068, 8, 3, 0.12, 0.24, FIO.CUORE)

	# ⚠️ La maschera d'organo di FioriGeo (r petalo · g cuore · b verde)
	# NON è quella di questo shader (`a` = prende la tinta): si traduce
	# qui, una volta, invece di dare a `wildflower` una seconda
	# convenzione da tenere allineata.
	var arr := st.commit_to_arrays()
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for k in col.size():
		var c := col[k]
		col[k] = petal if c.r > 0.5 else (heart if c.g > 0.5 else stem)
	arr[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
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
