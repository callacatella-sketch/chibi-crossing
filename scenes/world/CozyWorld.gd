class_name CozyWorld
extends Node3D

## Il prato di Mochi: tutto procedurale, tutto "dipinto a mano".
## Erba che ondeggia al vento, fiori, alberi (uno in fiore che perde
## petali), sassi del sentiero, nuvole soffici alla deriva, farfalle
## e pulviscolo dorato nell'aria.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const RIVER_SHADER := preload("res://shaders/river.gdshader")
const WATERFALL_SHADER := preload("res://shaders/waterfall.gdshader")
const GRASS_BLADE := preload("res://shaders/grass_blade.gdshader")

# il manto d'erba: fili instanziati a ciuffi, appiattibili cella per
# cella (sotto pavimenti e tappeti non spunta niente)
var _grass_mm: MultiMesh
var _grass_base: Array[Transform3D] = []
var _grass_cells := {}     # Vector2i -> PackedInt32Array degli indici
var _grass_flat := {}      # celle attualmente appiattite
var _player_ref: Node3D

var _clouds: Array[Node3D] = []
var _cloud_speeds: Array[float] = []
var _butterflies: Array[Dictionary] = []
var _pollen: GPUParticles3D
var _bf_respawn := 0.0
var _t := 0.0

# foresta
var _path_samples: PackedVector3Array = []
var _shaft_mat: StandardMaterial3D
var _campfire_light: OmniLight3D
var _mists: Array[MeshInstance3D] = []
var _mist_speeds: Array[float] = []

const CLEARING_CENTER := Vector3(-1.0, 0.0, -46.0)
const CLEARING_R := 6.0

# lo stagno, tra il prato e la foresta
const POND_CENTER := Vector3(9.5, 0.0, -10.5)
const POND_R := 3.6
const WATER_SHADER := preload("res://shaders/water.gdshader")

var _frogs: Array[Dictionary] = []
var _lilies: Array[Node3D] = []

# funghi raccoglibili nel bosco: si rigenerano altrove dopo la raccolta
var _pickups: Array[Node3D] = []
var _pickup_respawn := 0.0


## Di notte pollini e farfalle riposano e i fasci di luce del bosco si
## spengono (le lucciole sono del DayNight).
var _night := false
var _shaft_tw: Tween

# ---- STAGIONI ----
# Il mondo intero cambia veste col calendario (il regista è il DayNight,
# che chiama set_season). I materiali del fogliame sono locali e cotti
# nelle mesh da _merge, ma _merge ne TIENE il riferimento: mutarne color_a/
# color_b ridipinge la chioma dal vivo. Qui raccogliamo quelle maniglie.
var _season := -1
var _season_snow := 0.0
# ogni voce: {"mat": ShaderMaterial, "a": Color, "b": Color, "klass": String}
# klass: "green" latifoglia · "cherry" ciliegio · "needle" conifera · "bush" cespuglio
var _leaf_mats: Array = []
var _ground_mat: ShaderMaterial          # il manto del prato (../Floor)
var _grass_mat: ShaderMaterial           # i fili d'erba veri
var _petal_fx: Array[GPUParticles3D] = []   # i petali dei ciliegi (solo primavera)
var _forest_leaf_fx: GPUParticles3D      # le foglie che cadono nel bosco (autunno)
var _forest_leaf_mat: StandardMaterial3D  # il loro colore, ridipinto per stagione
var _flower_fields: Array[MultiMeshInstance3D] = []  # i campi di fiori (spariscono d'inverno)
var _snow_fx: GPUParticles3D             # la nevicata sul villaggio (inverno)
var _meadow_leaf_fx: GPUParticles3D      # le foglie che volano sul prato (autunno)
var _season_tw: Tween


func set_night(night: bool) -> void:
	_night = night
	_refresh_critters()
	if _shaft_mat:
		# se piove, i fasci restano spenti anche all'alba (li riaccende
		# il Weather quando smette); un solo tween alla volta
		var w := get_tree().get_first_node_in_group("weather")
		var target := 0.0 if (night or (w and w.call("is_raining"))) else 0.32
		if _shaft_tw and _shaft_tw.is_valid():
			_shaft_tw.kill()
		_shaft_tw = create_tween()
		_shaft_tw.tween_property(_shaft_mat, "albedo_color:a", target, 1.5)


# pollini e farfalle riposano di notte E d'inverno (il prato gelato non ha
# né polline né farfalle): il crocevia dei due stati vive qui
func _refresh_critters() -> void:
	var awake := not _night and _season != 3
	if _pollen:
		_pollen.emitting = awake
	for b in _butterflies:
		(b["node"] as Node3D).visible = awake


## Emesso quando tutta la geometria differita è stata costruita.
signal world_built


func _ready() -> void:
	add_to_group("cozy_world")
	add_to_group("season_listener")
	# Generazione DIFFERITA su più frame: toglie l'hitch d'avvio (prima tutta la
	# geometria — erba, fiori, alberi, bosco, stagno, fiume — nasceva in un solo
	# frame). L'ordine è identico a prima e il mondo "compare" in una frazione di
	# secondo. I fratelli prendono comunque subito il riferimento a CozyWorld (il
	# nodo esiste da subito) e interrogano la geometria solo a runtime.
	_build_grass()
	await get_tree().process_frame
	_build_flowers()
	await get_tree().process_frame
	_build_trees()
	await get_tree().process_frame
	# il Grande Albero: il monumento che cresce coi giorni del villaggio
	add_child(preload("res://scenes/world/GrandTree.gd").new())
	# il timelapse dei ricordi e l'amico co-op del divano
	add_child(preload("res://scenes/world/Memories.gd").new())
	add_child(preload("res://scenes/characters/Coop.gd").new())
	# le costellazioni di Mochi e il calendario del villaggio
	add_child(preload("res://scenes/world/Stargazing.gd").new())
	add_child(preload("res://scenes/world/Calendar.gd").new())
	# il guardaroba di Mochi: ricordi indossabili
	add_child(preload("res://scenes/characters/Wardrobe.gd").new())
	# l'onsen del bosco, oltre la radura del falò
	add_child(preload("res://scenes/world/Onsen.gd").new())
	# il Regista: osserva come giochi e compone in Lua le routine dei residenti
	add_child(preload("res://scenes/npc/Director.gd").new())
	# il Filo Rosso: la memoria dei momenti condivisi coi vicini
	add_child(preload("res://scenes/world/Legami.gd").new())
	await get_tree().process_frame
	_build_stones()
	_build_clouds()
	await get_tree().process_frame
	_build_butterflies()
	_build_pollen()
	await get_tree().process_frame
	_build_forest()
	await get_tree().process_frame
	_build_pond()
	await get_tree().process_frame
	# il fiume a est, con la scogliera a gradoni, la cascata e i ponti
	_build_river()
	_build_boundary()
	# le particelle stagionali (neve e foglie al vento) e la prima veste:
	# ora tutta la geometria esiste, i materiali sono raccolti, si può dipingere
	_build_season_fx()
	world_built.emit()
	_init_season()


func _paint_mat(a: Color, b: Color, grain := 4.0, amount := 0.45, wind := 0.0,
		world_noise := false, trans := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	mat.set_shader_parameter("wind_strength", wind)
	mat.set_shader_parameter("use_world_noise", world_noise)
	if trans > 0.0:
		mat.set_shader_parameter("translucency", trans)
	return mat


# ---------------------------------------------------------------- erba

# il filo d'erba vero: un nastro affusolato che si incurva in avanti,
# UV.y = altezza (lo shader ci appende gradienti, vento e spinte)
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# livelli: [altezza, mezza larghezza, curva in avanti]
	var lv := [[0.0, 0.017, 0.0], [0.12, 0.013, 0.012],
			[0.22, 0.008, 0.038], [0.30, 0.0, 0.085]]
	for s in 3:
		var a: Array = lv[s]
		var b: Array = lv[s + 1]
		var auv := float(a[0]) / 0.30
		var buv := float(b[0]) / 0.30
		var al := Vector3(-a[1], a[0], a[2])
		var ar := Vector3(a[1], a[0], a[2])
		if float(b[1]) > 0.0:
			var bl := Vector3(-b[1], b[0], b[2])
			var br := Vector3(b[1], b[0], b[2])
			for v: Array in [[al, auv], [bl, buv], [ar, auv],
					[ar, auv], [bl, buv], [br, buv]]:
				st.set_uv(Vector2(0.0, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
		else:
			var tip := Vector3(0, b[0], b[2])
			for v: Array in [[al, auv], [tip, 1.0], [ar, auv]]:
				st.set_uv(Vector2(0.0, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()


# ------------------------------------------------ il campo dei ciuffi
# Un unico campo di densità decide DOVE l'erba si addensa: i ciuffi
# nascono dove il campo è ricco, e lo stesso campo — cotto in una
# texture — scurisce il manto sotto di loro. Erba e terreno leggono
# la stessa mappa: il tappeto è uno solo.

const TUFT_RECT := Rect2(-16.0, -19.0, 32.0, 33.0)


# hash intero deterministico -> [0,1): identico su CPU sempre, niente
# trigonometria che diverge in precisione
func _tuft_hash(ix: int, iz: int) -> float:
	var n := ix * 374761393 + iz * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xfffff) / 1048575.0


func _tuft_vnoise(x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - float(ix)
	var fz := z - float(iz)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	return lerpf(
			lerpf(_tuft_hash(ix, iz), _tuft_hash(ix + 1, iz), ux),
			lerpf(_tuft_hash(ix, iz + 1), _tuft_hash(ix + 1, iz + 1), ux), uz)


func _tuft_field(x: float, z: float) -> float:
	return _tuft_vnoise(x * 0.30, z * 0.30) * 0.65 \
			+ _tuft_vnoise(x * 0.85 + 37.0, z * 0.85 + 11.0) * 0.35


# cuoce il campo in una texture R8 e la consegna al manto: il terreno
# si scurisce esattamente dove i ciuffi affondano le radici
func _bake_tuft_map() -> void:
	var w := 192
	var h := 192
	var img := Image.create_empty(w, h, false, Image.FORMAT_R8)
	for py in h:
		var wz := TUFT_RECT.position.y + (float(py) + 0.5) / float(h) * TUFT_RECT.size.y
		for px in w:
			var wx := TUFT_RECT.position.x + (float(px) + 0.5) / float(w) * TUFT_RECT.size.x
			var v := smoothstep(0.50, 0.80, _tuft_field(wx, wz))
			if px == 0 or py == 0 or px == w - 1 or py == h - 1:
				v = 0.0  # cornice a zero: il clamp non trascina il bordo fuori
			img.set_pixel(px, py, Color(v, v, v))
	var floor_mi := get_node_or_null("../Floor/MeshInstance3D") as MeshInstance3D
	if floor_mi:
		var gmat := floor_mi.get_surface_override_material(0) as ShaderMaterial
		if gmat:
			gmat.set_shader_parameter("tuft_map", ImageTexture.create_from_image(img))
			gmat.set_shader_parameter("tuft_origin", TUFT_RECT.position)
			gmat.set_shader_parameter("tuft_size", TUFT_RECT.size)
			# la maniglia del manto: la stagione ne ridipinge i verdi
			_ground_mat = gmat


func _build_grass() -> void:
	_bake_tuft_map()
	var mesh := _blade_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_BLADE
	mesh.surface_set_material(0, mat)
	# la maniglia dei fili: vanno tinti come il manto, o prato e terreno
	# divergerebbero (stessi tre verdi in ground.gdshader e grass_blade)
	_grass_mat = mat

	_grass_mm = MultiMesh.new()
	_grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	_grass_mm.use_custom_data = true
	_grass_mm.mesh = mesh

	# l'erba vera cresce a CIUFFI dove il campo è ricco (lì sotto il
	# manto è scuro: le radici hanno una casa), più tanti fili sciolti
	# corti a riempire i vuoti. Fili più bassi e fitti di prima: un
	# manto, non pinne appoggiate.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var punti: Array[Vector3] = []
	var dati: Array[Color] = []
	for c in 3000:
		var centro := Vector3(rng.randf_range(-15.0, 15.0), 0, rng.randf_range(-18.0, 13.0))
		if centro.distance_to(POND_CENTER) < POND_R + 1.4:
			continue
		# i ciuffi seguono il campo (con qualche ribelle qua e là)
		if _tuft_field(centro.x, centro.z) < 0.52 and rng.randf() > 0.15:
			continue
		for i in rng.randi_range(10, 17):
			var ang := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * 0.55
			var p := centro + Vector3(cos(ang) * rr, 0, sin(ang) * rr)
			if p.distance_to(POND_CENTER) < POND_R + 0.8:
				continue
			punti.append(p)
			dati.append(Color(rng.randf(), rng.randf(), 0.0,
					clampf(inverse_lerp(-13.0, -17.5, p.z), 0.0, 1.0)))
	for i in 6500:
		var p := Vector3(rng.randf_range(-15.0, 15.0), 0, rng.randf_range(-18.0, 13.0))
		if p.distance_to(POND_CENTER) < POND_R + 0.8:
			continue
		punti.append(p)
		dati.append(Color(rng.randf(), rng.randf(), 0.0,
				clampf(inverse_lerp(-13.0, -17.5, p.z), 0.0, 1.0)))

	_grass_mm.instance_count = punti.size()
	for i in punti.size():
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.25),
				rng.randf_range(0.55, 1.05), rng.randf_range(0.8, 1.25)))
		var tf := Transform3D(basis, punti[i])
		_grass_mm.set_instance_transform(i, tf)
		_grass_mm.set_instance_custom_data(i, dati[i])
		_grass_base.append(tf)
		# secchielli per cella: servono all'appiattimento sotto i pavimenti
		var cell := Vector2i(roundi(punti[i].x), roundi(punti[i].z))
		var arr: PackedInt32Array = _grass_cells.get(cell, PackedInt32Array())
		arr.append(i)
		_grass_cells[cell] = arr

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _grass_mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Sotto un pavimento o un tappeto l'erba si accuccia (il BuildSystem
## chiama qui a ogni piazzamento): nessun filo spunta dal parquet.
func flatten_cell(cell: Vector2i) -> void:
	if _grass_flat.has(cell) or not _grass_cells.has(cell):
		return
	_grass_flat[cell] = true
	for i in (_grass_cells[cell] as PackedInt32Array):
		var tf: Transform3D = _grass_base[i]
		_grass_mm.set_instance_transform(i,
				Transform3D(tf.basis.scaled(Vector3(1, 0.02, 1)), tf.origin))


## E quando il pezzo viene rimosso, l'erba rinasce.
func unflatten_cell(cell: Vector2i) -> void:
	if not _grass_flat.has(cell):
		return
	_grass_flat.erase(cell)
	if not _grass_cells.has(cell):
		return
	for i in (_grass_cells[cell] as PackedInt32Array):
		_grass_mm.set_instance_transform(i, _grass_base[i])


# ---------------------------------------------------------------- fiori

# il gambo comune: stelo con una lieve curva naturale + due foglioline
# basali lanceolate. Ogni specie ci appoggia sopra la sua corolla.
func _flower_base(mesh: ArrayMesh, h: float, leaf_s := 1.0) -> void:
	var green := _paint_mat(Color("7fae6a"), Color("5f9050"), 6.0, 0.5, 0.02, true)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# stelo in due segmenti, il secondo piegato appena: mai un palo dritto
	var low := _cyl_mesh(0.011, 0.013, h * 0.55, 6)
	var high := _cyl_mesh(0.009, 0.011, h * 0.5, 6)
	st.append_from(low, 0, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.275, 0)))
	st.append_from(high, 0, Transform3D(
			Basis(Vector3.RIGHT, 0.12), Vector3(0, h * 0.76, -h * 0.03)))
	# foglie: ellissoidi lunghi e sottili, inclinati verso l'alto
	var leaf := _sphere_mesh(0.05, 8)
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3.UP, side * 1.2 + 0.4) \
				* Basis(Vector3.RIGHT, -0.55) \
				* Basis.IDENTITY.scaled(Vector3(0.42, 0.14, 1.5) * leaf_s)
		st.append_from(leaf, 0, Transform3D(b, Vector3(side * 0.03, h * 0.16, 0.015)))
	st.set_material(green)
	st.commit(mesh)


## La margherita: doppia corona di petali veri (8 sotto + 5 sopra,
## ruotati e appena rialzati) attorno al bottone dorato bombato.
func _daisy_mesh(petal_color: Color, center_color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_flower_base(mesh, 0.20)

	var pet_mat := _paint_mat(petal_color, petal_color.lightened(0.22), 2.2, 0.5, 0.02, true, 0.5)
	var petal := _sphere_mesh(0.034, 8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# corona bassa: 8 petali lunghi, appena conici verso l'alto
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.22) \
				* Basis.IDENTITY.scaled(Vector3(0.62, 0.22, 1.75))
		st.append_from(petal, 0, Transform3D(b,
				Vector3(cos(a) * 0.055, 0.205, sin(a) * 0.055)))
	# corona alta: 5 petali più corti, sfalsati, più alzati
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.63
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.5) \
				* Basis.IDENTITY.scaled(Vector3(0.55, 0.2, 1.3))
		st.append_from(petal, 0, Transform3D(b,
				Vector3(cos(a) * 0.038, 0.218, sin(a) * 0.038)))
	st.set_material(pet_mat)
	st.commit(mesh)

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(_sphere_mesh(0.03, 10), 0, Transform3D(
			Basis.IDENTITY.scaled(Vector3(1, 0.62, 1)), Vector3(0, 0.225, 0)))
	st.set_material(_paint_mat(center_color, center_color.darkened(0.25), 9.0, 0.55))
	st.commit(mesh)
	return mesh


## Il tulipano: sei petali verticali chiusi a coppa su uno stelo alto,
## con la foglia lunga avvolgente tipica.
func _tulip_mesh(cup_color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_flower_base(mesh, 0.26, 1.25)

	var pet_mat := _paint_mat(cup_color, cup_color.lightened(0.18), 2.0, 0.45, 0.02, true, 0.55)
	var petal := _sphere_mesh(0.045, 8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		# petali dritti che si stringono in alto: la silhouette a uovo
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.16) \
				* Basis.IDENTITY.scaled(Vector3(0.72, 1.35, 0.4))
		st.append_from(petal, 0, Transform3D(b,
				Vector3(cos(a) * 0.026, 0.315, sin(a) * 0.026)))
	st.set_material(pet_mat)
	st.commit(mesh)

	# il cuoricino scuro appena visibile dentro la coppa
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(_sphere_mesh(0.02, 8), 0, Transform3D(
			Basis.IDENTITY, Vector3(0, 0.31, 0)))
	st.set_material(_paint_mat(cup_color.darkened(0.4), cup_color.darkened(0.55), 6.0, 0.4))
	st.commit(mesh)
	return mesh


## La lavanda: spiga di campanellini viola sfalsati su uno stelo slanciato.
func _lavender_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_flower_base(mesh, 0.30, 0.8)

	var bud_mat := _paint_mat(Color("a98fd8"), Color("8f6fc4"), 2.5, 0.5, 0.025, true, 0.45)
	var bud := _sphere_mesh(0.026, 8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var t := float(i) / 6.0
		var a := t * 5.2  # i campanellini salgono a spirale
		var y := 0.24 + t * 0.11
		var r := 0.018 * (1.0 - t * 0.45)
		var b := Basis(Vector3.UP, -a) \
				* Basis.IDENTITY.scaled(Vector3(1.15, 0.85, 1.15) * (1.0 - t * 0.35))
		st.append_from(bud, 0, Transform3D(b, Vector3(cos(a) * r, y, sin(a) * r)))
	# la puntina in cima
	st.append_from(bud, 0, Transform3D(
			Basis.IDENTITY.scaled(Vector3(0.6, 0.9, 0.6)), Vector3(0, 0.365, 0)))
	st.set_material(bud_mat)
	st.commit(mesh)
	return mesh


# semina un campo a macchie: i fiori veri crescono in famigliole, non
# equidistanti — centri di macchia + 2-5 fiori stretti intorno + sparsi
func _flower_field(mesh: Mesh, clusters: int, per_min: int, per_max: int,
		singles: int, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var spot := func() -> Vector3:
		for attempt in 10:
			var r := rng.randf_range(2.5, 21.0)
			var a := rng.randf() * TAU
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if p.distance_to(POND_CENTER) > POND_R + 1.6 and p.z > -14.5:
				return p
		return Vector3(6, 0, 6)
	for c in clusters:
		var centro: Vector3 = spot.call()
		for i in rng.randi_range(per_min, per_max):
			var ang := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * 0.55
			var p := centro + Vector3(cos(ang) * rr, 0, sin(ang) * rr)
			var b := Basis(Vector3.UP, rng.randf() * TAU) \
					.scaled(Vector3.ONE * rng.randf_range(0.8, 1.2))
			# ogni fiore pende dalla sua parte: niente plotone sull'attenti
			b = Basis(Vector3(cos(ang), 0, sin(ang)).cross(Vector3.UP).normalized(),
					rng.randf_range(-0.09, 0.09)) * b
			transforms.append(Transform3D(b, p))
	for i in singles:
		var b := Basis(Vector3.UP, rng.randf() * TAU) \
				.scaled(Vector3.ONE * rng.randf_range(0.75, 1.15))
		transforms.append(Transform3D(b, spot.call()))
	return _scatter_exact(mesh, transforms, false)


func _build_flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# margherite bianche e rosa, tulipani caldi, spighe di lavanda.
	# I campi si raccolgono: d'inverno il prato gelato li nasconde sotto la neve
	for field in [
			_flower_field(_daisy_mesh(Color("fffaf4"), Color("ffcf5e")), 9, 3, 5, 8, rng),
			_flower_field(_daisy_mesh(Color("ffc4d6"), Color("ffd76e")), 7, 3, 5, 6, rng),
			_flower_field(_tulip_mesh(Color("ffb35c")), 5, 2, 4, 4, rng),
			_flower_field(_tulip_mesh(Color("f2879e")), 5, 2, 4, 4, rng),
			_flower_field(_lavender_mesh(), 6, 3, 6, 4, rng)]:
		if field:
			_flower_fields.append(field)


# ---------------------------------------------------------------- alberi

# L'albero cozy vero: tronco svasato con radici, tre rami che salgono
# nella chioma, e la chioma come NUVOLA — lobo scuro sotto (l'ombra
# interna), massa centrale a due toni, ciuffi chiari in cima dove batte
# il sole. Tutto fuso in una sola mesh: un draw call per materiale.
func _make_tree(pos: Vector3, size: float, leaf_a: Color, leaf_b: Color,
		seed_v := 0, leaf_klass := "green") -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_v * 37 + int(pos.x * 7.0 + pos.z * 13.0)

	var bark := _paint_mat(Color("9a6b4f"), Color("7e563f"), 2.5, 0.55)
	# le chiome lasciano PASSARE il controluce: la frangia si accende
	# di verde-oro quando il sole è alle loro spalle
	var leaf_dark := _paint_mat(leaf_b.darkened(0.22), leaf_b.darkened(0.34), 1.1, 0.6, 0.012, false, 0.35)
	var leaf_mid := _paint_mat(leaf_a, leaf_b, 1.1, 0.65, 0.012, false, 0.45)
	var leaf_light := _paint_mat(leaf_a.lightened(0.16), leaf_a, 1.1, 0.55, 0.014, false, 0.55)
	# le tre maniglie del fogliame: la stagione le tira verso l'oro, il
	# rame o il gelo (la primavera è già il loro colore di nascita)
	_register_leaf(leaf_dark, leaf_b.darkened(0.22), leaf_b.darkened(0.34), leaf_klass)
	_register_leaf(leaf_mid, leaf_a, leaf_b, leaf_klass)
	_register_leaf(leaf_light, leaf_a.lightened(0.16), leaf_a, leaf_klass)

	var parts := []
	# tronco + radici a vista
	parts.append([_trunk_mesh(1.35, 0.19, 0.115, rng.randi()), Transform3D.IDENTITY, bark])
	for i in 4:
		var a := float(i) / 4.0 * TAU + rng.randf_range(-0.3, 0.3)
		var root := Basis(Vector3.UP, -a) \
				* Basis.IDENTITY.scaled(Vector3(0.5, 0.35, 1.25))
		parts.append([_sphere_mesh(0.16, 8), Transform3D(root,
				Vector3(cos(a) * 0.2, 0.02, sin(a) * 0.2)), bark])
	# tre rami che si aprono verso i lobi della chioma
	for i in 3:
		var a := float(i) / 3.0 * TAU + rng.randf_range(-0.4, 0.4)
		var tilt := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.9)
		parts.append([_cyl_mesh(0.035, 0.06, 0.62, 7), Transform3D(tilt,
				Vector3(cos(a) * 0.28, 1.32, sin(a) * 0.28)
				+ tilt * Vector3(0, 0.28, 0)), bark])

	# la chioma-nuvola (16×9: sono gli alberi-protagonisti del prato,
	# li si guarda da vicino — il bosco resta alla risoluzione economica)
	parts.append([_puff_mesh(0.92, rng.randi(), 0.6, 0.07, 16, 9), # gonna d'ombra
			Transform3D(Basis.IDENTITY, Vector3(0, 1.52, 0)), leaf_dark])
	parts.append([_puff_mesh(0.88, rng.randi(), 0.85, 0.1, 16, 9), # cuore
			Transform3D(Basis.IDENTITY, Vector3(0, 1.9, 0)), leaf_mid])
	for i in 5: # lobi di mezzo intorno
		var a := float(i) / 5.0 * TAU + rng.randf_range(-0.25, 0.25)
		var r := rng.randf_range(0.5, 0.64)
		parts.append([_puff_mesh(r, rng.randi(), 0.82, 0.11, 16, 9),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
				Vector3(cos(a) * 0.62, rng.randf_range(1.62, 1.82), sin(a) * 0.62)),
				leaf_mid if i % 2 == 0 else leaf_dark])
	for i in 3: # ciuffi di luce in cima
		var a := float(i) / 3.0 * TAU + rng.randf_range(-0.4, 0.4)
		parts.append([_puff_mesh(rng.randf_range(0.3, 0.42), rng.randi(), 0.8, 0.13, 16, 9),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
				Vector3(cos(a) * 0.38, rng.randf_range(2.35, 2.55), sin(a) * 0.38)),
				leaf_light])

	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * size
	tree.rotation.y = randf() * TAU
	var mi := MeshInstance3D.new()
	mi.mesh = _merge(parts)
	tree.add_child(mi)
	add_child(tree)
	return tree


func _build_trees() -> void:
	# un ciliegio in fiore che perde petali (klass "cherry": fiorisce a
	# primavera, rinverdisce d'estate, si accende d'oro-rosa in autunno)
	var cherry := _make_tree(Vector3(-6.0, 0, -5.0), 1.25, Color("ffd4e2"), Color("f5a8c0"), 1, "cherry")
	_add_petals(cherry)

	_make_tree(Vector3(7.5, 0, -6.0), 1.1, Color("86c46c"), Color("64a854"), 2)
	_make_tree(Vector3(-9.0, 0, 4.5), 0.9, Color("97cc74"), Color("74b05c"), 3)
	_make_tree(Vector3(9.5, 0, 5.5), 1.0, Color("7dbd68"), Color("5da050"), 4)

	# cespuglietti: cuscini di verde con l'ombra sotto e le bacche rosse
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var bush_dark := _paint_mat(Color("5e9a50"), Color("4b8040"), 1.6, 0.6, 0.015, false, 0.35)
	var bush_light := _paint_mat(Color("8cc873"), Color("6cae5b"), 1.6, 0.6, 0.015, false, 0.45)
	var berry := _paint_mat(Color("e6607a"), Color("c94a62"), 5.0, 0.35)
	# i cespugli seguono le stagioni; le bacche restano rosse (rosse sulla neve)
	_register_leaf(bush_dark, Color("5e9a50"), Color("4b8040"), "bush")
	_register_leaf(bush_light, Color("8cc873"), Color("6cae5b"), "bush")
	for p in [Vector3(-3.5, 0, -7.0), Vector3(4.0, 0, 7.5), Vector3(-8.0, 0, -1.5)]:
		var parts := []
		parts.append([_puff_mesh(0.52, rng.randi(), 0.62, 0.12),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), bush_dark])
		parts.append([_puff_mesh(0.42, rng.randi(), 0.78, 0.13),
				Transform3D(Basis.IDENTITY, Vector3(0.24, 0.4, 0.08)), bush_light])
		parts.append([_puff_mesh(0.36, rng.randi(), 0.78, 0.13),
				Transform3D(Basis.IDENTITY, Vector3(-0.24, 0.38, -0.08)), bush_light])
		for i in 6:
			var a := rng.randf() * TAU
			var rr := rng.randf_range(0.26, 0.42)
			parts.append([_sphere_mesh(0.032, 7), Transform3D(Basis.IDENTITY,
					Vector3(cos(a) * rr, 0.38 + rng.randf_range(-0.08, 0.16),
					sin(a) * rr)), berry])
		var bush := Node3D.new()
		bush.position = p
		bush.rotation.y = rng.randf() * TAU
		var mi := MeshInstance3D.new()
		mi.mesh = _merge(parts)
		bush.add_child(mi)
		add_child(bush)


func _soft_circle(color: Color, edge := 0.6) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, edge, 1.0])
	grad.colors = PackedColorArray([color, Color(color, color.a * 0.55), Color(color, 0.0)])
	tex.gradient = grad
	return tex


func _add_petals(tree: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_circle(Color("ffc9d9", 0.95), 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.1, 0.4, 1.1)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.25, -0.35, 0.05)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var petals := GPUParticles3D.new()
	petals.amount = 26
	petals.lifetime = 7.0
	petals.preprocess = 5.0
	petals.local_coords = false
	petals.process_material = pm
	petals.draw_pass_1 = quad
	petals.position = Vector3(0, 1.5, 0)
	petals.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 6, 12))
	tree.add_child(petals)
	# i petali nevicano solo a PRIMAVERA: la stagione li accende e li spegne
	_petal_fx.append(petals)


# ---------------------------------------------------------------- sassi

func _build_stones() -> void:
	var mat := _paint_mat(Color("c9c2b4"), Color("a89f92"), 5.0, 0.5)
	var pts := [
		Vector3(0.9, 0, 1.6), Vector3(1.7, 0, 2.1), Vector3(2.6, 0, 2.4),
		Vector3(3.5, 0, 2.6), Vector3(4.4, 0, 2.9), Vector3(5.2, 0, 3.3),
	]
	for p in pts:
		var stone := CylinderMesh.new()
		stone.top_radius = randf_range(0.24, 0.32)
		stone.bottom_radius = stone.top_radius + 0.04
		stone.height = 0.07
		var mi := MeshInstance3D.new()
		mi.mesh = stone
		mi.material_override = mat
		mi.position = p + Vector3(randf_range(-0.15, 0.15), 0.035, randf_range(-0.15, 0.15))
		mi.rotation.y = randf() * TAU
		mi.scale = Vector3(1, 1, randf_range(0.8, 1.0))
		add_child(mi)


# ---------------------------------------------------------------- nuvole

func _build_clouds() -> void:
	var mat := _paint_mat(Color(1, 1, 1), Color("e8ecf5"), 0.8, 0.5)
	mat.set_shader_parameter("rim_strength", 0.3)
	mat.set_shader_parameter("rim_color", Color(1, 0.98, 0.95))
	for i in 5:
		var cloud := Node3D.new()
		cloud.position = Vector3(randf_range(-40.0, 40.0), randf_range(14.0, 20.0), randf_range(-34.0, -8.0))
		var blob_count := randi_range(4, 6)
		for j in blob_count:
			var s := SphereMesh.new()
			var r := randf_range(1.2, 2.4)
			s.radius = r
			s.height = r * 2.0
			s.radial_segments = 20
			s.rings = 10
			var mi := MeshInstance3D.new()
			mi.mesh = s
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(float(j) * 1.5 - blob_count * 0.75, randf_range(-0.3, 0.4), randf_range(-0.6, 0.6))
			mi.scale = Vector3(1, 0.55, 0.8)
			cloud.add_child(mi)
		add_child(cloud)
		_clouds.append(cloud)
		_cloud_speeds.append(randf_range(0.25, 0.55))


# ---------------------------------------------------------------- farfalle

const BUTTERFLY_KINDS := [
	["rosa", Color("ffd1e0")], ["azzurra", Color("cfe6ff")], ["gialla", Color("fff3c9")],
]

func _build_butterflies() -> void:
	for i in 5:
		_make_butterfly(i % 3)


func _make_butterfly(kind_i: int) -> void:
	var b := Node3D.new()
	add_child(b)

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.012
	cap.height = 0.07
	body.mesh = cap
	body.rotation.x = PI * 0.5
	body.material_override = _paint_mat(Color("6a5a4a"), Color("4a3e33"), 8.0, 0.4)
	b.add_child(body)

	var wing_col: Color = BUTTERFLY_KINDS[kind_i][1]
	var wings: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		b.add_child(pivot)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.15, 0.12)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.albedo_texture = _soft_circle(wing_col, 0.75)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.rotation.x = -PI * 0.5
		mi.position = Vector3(side * 0.085, 0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		wings.append(pivot)

	_butterflies.append({
		"node": b,
		"wing_l": wings[0],
		"wing_r": wings[1],
		"seed": randf() * 100.0,
		"prev": Vector3.ZERO,
		"kind": str(BUTTERFLY_KINDS[kind_i][0]),
	})


## La farfalla più vicina entro max_d (indice, o -1).
func nearest_butterfly(pos: Vector3, max_d: float) -> int:
	var best := -1
	var best_d := max_d
	for i in _butterflies.size():
		var node := _butterflies[i]["node"] as Node3D
		if not node.visible:
			continue
		var d: float = pos.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = i
	return best


## Toglie la farfalla dal cielo e la consegna al retino: {kind, node}.
## Il prato si ripopola da solo poco dopo.
func catch_butterfly(i: int) -> Dictionary:
	var b: Dictionary = _butterflies[i]
	_butterflies.remove_at(i)
	_bf_respawn = randf_range(45.0, 90.0)
	return {"kind": b["kind"], "node": b["node"]}


# ---------------------------------------------------------------- pollini

func _build_pollen() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _soft_circle(Color(1.0, 0.95, 0.8, 0.7))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18.0, 1.5, 18.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.04
	pm.initial_velocity_max = 0.18
	pm.gravity = Vector3(0.12, 0.05, 0.04)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_speed = Vector3(0.2, 0.15, 0.2)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	_pollen = GPUParticles3D.new()
	_pollen.amount = 70
	_pollen.lifetime = 9.0
	_pollen.preprocess = 7.0
	_pollen.local_coords = false
	_pollen.process_material = pm
	_pollen.draw_pass_1 = quad
	_pollen.position = Vector3(0, 1.2, 0)
	_pollen.visibility_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 10, 48))
	add_child(_pollen)


# ================================================================ foresta
# Tutto il bosco è costruito per le performance: ogni specie è UNA mesh
# fusa (una superficie per materiale) istanziata via MultiMesh — centinaia
# di alberi in una manciata di draw call — divisa in due blocchi est/ovest
# per il frustum culling. Le collisioni dei tronchi stanno in un unico
# StaticBody3D. Le particelle sono GPU con AABB delimitati.

func _merge(parts: Array) -> ArrayMesh:
	# [[Mesh, Transform3D, Material], ...] -> ArrayMesh con una superficie
	# per materiale
	var groups := {}
	for p in parts:
		var mat: Material = p[2]
		if not groups.has(mat):
			groups[mat] = []
		(groups[mat] as Array).append(p)
	var mesh := ArrayMesh.new()
	for mat in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in groups[mat]:
			st.append_from(p[0], 0, p[1])
		st.set_material(mat)
		st.commit(mesh)
	return mesh


func _scatter_exact(mesh: Mesh, transforms: Array, shadows := true) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _cone_mesh(radius: float, height: float, segments := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	return m


func _cyl_mesh(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


func _sphere_mesh(radius: float, segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = int(segments * 0.5)
	return m


# ---------------------------------------------------- il kit botanico
# Le forme organiche del verde: niente primitive nude. Ogni superficie
# è una griglia anelli×righe (bottom→top, winding del lathe dei chibi)
# e le NORMALI sono quelle vere della superficie deformata — differenze
# centrali sui vicini della griglia — così il cel-shading accarezza i
# gonfiori invece di tagliarli con le bande della forma ideale.

# normali morbide di una griglia di anelli chiusi: tangente lungo
# l'anello × tangente lungo la colonna (differenze centrali; ai bordi
# one-sided). Le righe degenerate (poli, punte) ricadono sulla verticale.
func _grid_normals(pos: Array, segs: int) -> Array:
	var rows := pos.size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		var below: Array = pos[maxi(i - 1, 0)]
		var above: Array = pos[mini(i + 1, rows - 1)]
		for j in segs:
			var t_lon: Vector3 = pos[i][(j + 1) % segs] - pos[i][(j - 1 + segs) % segs]
			var t_lat: Vector3 = above[j] - below[j]
			var n := t_lon.cross(t_lat)
			if n.length_squared() < 0.0000001:
				# riga degenere (polo in basso, polo/punta in alto)
				nrow.append(Vector3.DOWN if i == 0 else Vector3.UP)
				continue
			nrow.append(n.normalized())
		out.append(nrow)
	return out


# griglia + normali -> mesh (due triangoli per quad, facce esterne)
func _grid_commit(pos: Array, nrm: Array, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pos.size() - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			for idx: Array in [[i, j], [i + 1, j], [i + 1, j2],
					[i, j], [i + 1, j2], [i, j2]]:
				st.set_normal(nrm[idx[0]][idx[1]])
				st.add_vertex(pos[idx[0]][idx[1]])
	return st.commit()


# nuvola soffice: sfera schiacciata con gonfiori pseudo-noise coerenti.
# Le normali vere dei gonfiori vengono ammorbidite verso quelle
# dell'ellissoide liscio (il trucco dello stylized foliage): i lobi si
# leggono, ma l'ombra resta rotonda come un cuscino — mai accartocciata.
func _puff_mesh(r: float, seed_v: int, squash := 0.82, lump := 0.09,
		segs := 12, rings := 7, detail := 0.5) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var v1 := Vector3(rng.randf_range(1.6, 3.0), rng.randf_range(1.6, 3.0),
			rng.randf_range(1.6, 3.0))
	var v2 := Vector3(rng.randf_range(2.2, 4.2), rng.randf_range(2.2, 4.2),
			rng.randf_range(2.2, 4.2))
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU

	var pos: Array = []
	var soft: Array = []  # la normale dell'ellissoide liscio, per il blend
	for i in rings + 1:
		var lat := float(i) / float(rings) * PI - PI * 0.5  # -90° (sotto) -> +90°
		var prow: Array[Vector3] = []
		var srow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			var d := Vector3(cos(lat) * cos(lon), sin(lat), -cos(lat) * sin(lon))
			var k := 1.0 + lump * sin(d.dot(v1) * 2.2 + ph1) \
					* cos(d.dot(v2) * 1.7 + ph2)
			prow.append(Vector3(d.x, d.y * squash, d.z) * r * k)
			# normale esatta dell'ellissoide (1, squash, 1): scala inversa
			srow.append(Vector3(d.x, d.y / squash, d.z).normalized())
		pos.append(prow)
		soft.append(srow)

	var nrm := _grid_normals(pos, segs)
	for i in nrm.size():
		for j in segs:
			nrm[i][j] = (soft[i][j].lerp(nrm[i][j], detail)).normalized()
	return _grid_commit(pos, nrm, segs)


# tronco vero: svasato alla base, affusolato in cima, corteccia
# irregolare e una lieve inclinazione — con le normali che seguono
# davvero gobbe e svasatura (la luce radente rivela la corteccia)
func _trunk_mesh(h: float, rb: float, rt: float, seed_v: int,
		bend := 0.07, segs := 10) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	var kink := rng.randf_range(2.0, 3.4)
	var lean := Vector2(cos(ph), sin(ph)) * bend * h

	var ts := [0.0, 0.05, 0.14, 0.32, 0.58, 0.82, 1.0]
	var pos: Array = []
	for i in ts.size():
		var t: float = ts[i]
		var prow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			# affusolamento + svasatura delle radici alla base
			var r := lerpf(rb, rt, pow(t, 0.85)) * (1.0 + 1.1 * pow(1.0 - t, 7.0))
			# corteccia: gobbe radiali che ruotano piano salendo
			r *= 1.0 + 0.055 * sin(lon * 3.0 + t * kink + ph) \
					+ 0.03 * sin(lon * 7.0 - t * 2.0)
			var c := Vector3(lean.x * t * t, t * h, lean.y * t * t)
			prow.append(c + Vector3(cos(lon) * r, 0, -sin(lon) * r))
		pos.append(prow)
	return _grid_commit(pos, _grid_normals(pos, segs), segs)


# la gonna di un pino: cono con l'orlo smerlato che ricade. Le normali
# vere fanno prendere luce a ogni smerlo: la fronda si accende onda
# per onda invece di essere un cono uniforme.
func _skirt_mesh(r: float, h: float, seed_v: int, droop := 0.14,
		waves := 7, segs := 16) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	# profili bottom→top: [frazione raggio, quota]
	var prof := [[1.0, 0.0], [0.72, h * 0.2], [0.38, h * 0.55], [0.0, h]]
	var pos: Array = []
	for i in prof.size():
		var prow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			var rr: float = r * float(prof[i][0])
			var y: float = prof[i][1]
			if i == 0:
				# l'orlo: onde che scendono e rientrano appena
				var w := sin(lon * waves + ph)
				y -= droop * r * (0.55 + 0.45 * w)
				rr *= 1.0 + 0.05 * sin(lon * waves + ph + 1.3)
			prow.append(Vector3(cos(lon) * rr, y, -sin(lon) * rr))
		pos.append(prow)
	return _grid_commit(pos, _grid_normals(pos, segs), segs)


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _path_dist(p: Vector3) -> float:
	var best := 9999.0
	for s in _path_samples:
		var dx := p.x - s.x
		var dz := p.z - s.z
		best = minf(best, dx * dx + dz * dz)
	return sqrt(best)


func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_build_forest_path(rng)
	_build_forest_trees(rng)
	_build_forest_undergrowth(rng)
	_build_forest_shafts(rng)
	_build_forest_mist(rng)
	_build_forest_leaves()
	_build_campfire()
	for i in 5:
		_spawn_pickup_mushroom()
	# il micro-ecosistema del prato (simulazione C++, arte in Ecosystem.gd)
	add_child(preload("res://scenes/world/Ecosystem.gd").new())


# sentiero sterrato serpeggiante: dischi di terra battuta lungo una Catmull-Rom
func _build_forest_path(rng: RandomNumberGenerator) -> void:
	var pts := [
		Vector3(0, 0, -6), Vector3(3, 0, -16), Vector3(-3.5, 0, -26),
		Vector3(2.5, 0, -36), CLEARING_CENTER,
	]
	_path_samples = PackedVector3Array()
	for seg in pts.size() - 1:
		var p0: Vector3 = pts[maxi(seg - 1, 0)]
		var p1: Vector3 = pts[seg]
		var p2: Vector3 = pts[seg + 1]
		var p3: Vector3 = pts[mini(seg + 2, pts.size() - 1)]
		for i in 20:
			_path_samples.append(_catmull(p0, p1, p2, p3, float(i) / 20.0))

	var disc := _cyl_mesh(0.55, 0.6, 0.05, 10)
	disc.material = _paint_mat(Color("9a7a55"), Color("83674a"), 0.9, 0.55, 0.0, true)
	var transforms: Array[Transform3D] = []
	for i in _path_samples.size():
		var s := _path_samples[i]
		var w := rng.randf_range(0.8, 1.15)
		var rot := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, 1, w))
		# quote leggermente sfalsate: dischi sovrapposti senza z-fighting
		var pos := s + Vector3(rng.randf_range(-0.2, 0.2), 0.012 + float(i % 5) * 0.004, rng.randf_range(-0.2, 0.2))
		transforms.append(Transform3D(rot, pos))
	_scatter_exact(disc, transforms, false)


func _build_forest_trees(rng: RandomNumberGenerator) -> void:
	var bark := _paint_mat(Color("6a4e3a"), Color("57402f"), 2.5, 0.55)
	# aghi e fronde in controluce: il bosco si accende quando lo
	# attraversi camminando verso il sole
	var needle_a := _paint_mat(Color("3f7050"), Color("2f5840"), 1.0, 0.6, 0.008, false, 0.3)
	var needle_b := _paint_mat(Color("4a7d58"), Color("365f46"), 1.0, 0.6, 0.008, false, 0.3)
	var needle_lite := _paint_mat(Color("5c8f65"), Color("477455"), 1.0, 0.55, 0.01, false, 0.4)
	var leaf_dark := _paint_mat(Color("3a6b3e"), Color("2d5733"), 1.0, 0.6, 0.008, false, 0.35)
	var leaf := _paint_mat(Color("4e8a52"), Color("3d7344"), 1.0, 0.65, 0.008, false, 0.4)
	var leaf_lite := _paint_mat(Color("619c5e"), Color("4e8a52"), 1.0, 0.55, 0.01, false, 0.5)
	# sette materiali per TUTTO il bosco (MultiMesh): mutarli ridipinge
	# centinaia d'alberi in un colpo. Le conifere (needle_*) restano verdi
	# tutto l'anno, le latifoglie (leaf_*) si accendono e si spogliano.
	_register_leaf(needle_a, Color("3f7050"), Color("2f5840"), "needle")
	_register_leaf(needle_b, Color("4a7d58"), Color("365f46"), "needle")
	_register_leaf(needle_lite, Color("5c8f65"), Color("477455"), "needle")
	_register_leaf(leaf_dark, Color("3a6b3e"), Color("2d5733"), "green")
	_register_leaf(leaf, Color("4e8a52"), Color("3d7344"), "green")
	_register_leaf(leaf_lite, Color("619c5e"), Color("4e8a52"), "green")

	# il pino: gonne smerlate che ricadono, tono che si schiarisce
	# salendo verso il germoglio in punta
	var pine_kit := func(seed_v: int) -> ArrayMesh:
		return _merge([
			[_trunk_mesh(1.9, 0.24, 0.13, seed_v), Transform3D.IDENTITY, bark],
			[_skirt_mesh(1.4, 1.15, seed_v + 1, 0.16, 7),
					Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), needle_a],
			[_skirt_mesh(1.08, 1.0, seed_v + 2, 0.15, 6),
					Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 2.3, 0)), needle_b],
			[_skirt_mesh(0.78, 0.9, seed_v + 3, 0.14, 6),
					Transform3D(Basis(Vector3.UP, 0.9), Vector3(0, 3.05, 0)), needle_a],
			[_skirt_mesh(0.5, 0.8, seed_v + 4, 0.13, 5),
					Transform3D(Basis(Vector3.UP, 1.3), Vector3(0, 3.75, 0)), needle_lite],
			[_sphere_mesh(0.09, 7), Transform3D(
					Basis.IDENTITY.scaled(Vector3(0.7, 1.5, 0.7)),
					Vector3(0, 4.55, 0)), needle_lite],
		])
	# la latifoglia: tronco alto, chioma-nuvola con ombra sotto e luce
	# sopra (14×8: il cel-shading sulle chiome chiare rivela ogni faccia,
	# e la mesh è UNA per variante — la risoluzione costa quasi nulla)
	var broad_kit := func(seed_v: int) -> ArrayMesh:
		var parts := [
			[_trunk_mesh(2.9, 0.22, 0.12, seed_v), Transform3D.IDENTITY, bark],
			[_puff_mesh(1.2, seed_v + 1, 0.6, 0.08, 14, 8),
					Transform3D(Basis.IDENTITY, Vector3(0, 2.85, 0)), leaf_dark],
			[_puff_mesh(1.12, seed_v + 2, 0.85, 0.1, 14, 8),
					Transform3D(Basis.IDENTITY, Vector3(0, 3.35, 0)), leaf],
		]
		var prng := RandomNumberGenerator.new()
		prng.seed = seed_v
		for i in 4:
			var a := float(i) / 4.0 * TAU + prng.randf_range(-0.3, 0.3)
			parts.append([_puff_mesh(prng.randf_range(0.6, 0.75), seed_v + 3 + i,
					0.8, 0.12, 14, 8),
					Transform3D(Basis(Vector3.UP, prng.randf() * TAU),
					Vector3(cos(a) * 0.8, prng.randf_range(3.0, 3.3), sin(a) * 0.8)),
					leaf if i % 2 == 0 else leaf_dark])
		for i in 2:
			var a := prng.randf() * TAU
			parts.append([_puff_mesh(prng.randf_range(0.38, 0.5), seed_v + 8 + i,
					0.8, 0.13, 14, 8),
					Transform3D(Basis.IDENTITY,
					Vector3(cos(a) * 0.42, prng.randf_range(4.0, 4.2), sin(a) * 0.42)),
					leaf_lite])
		return _merge(parts)

	# due varianti per specie: il bosco non è mai fatto di cloni
	var pine: ArrayMesh = pine_kit.call(31)
	var pine2: ArrayMesh = pine_kit.call(77)
	var broad: ArrayMesh = broad_kit.call(53)
	var broad2: ArrayMesh = broad_kit.call(97)

	# griglia con jitter: copertura uniforme senza radure accidentali
	var chunks := {"p1w": [], "p1e": [], "p2w": [], "p2e": [],
			"b1w": [], "b1e": [], "b2w": [], "b2e": []}
	var colliders := StaticBody3D.new()
	for gx in range(-50, 51, 4):
		for gz in range(-50, -13, 4):
			var pos := Vector3(gx + rng.randf_range(-1.8, 1.8), 0, gz + rng.randf_range(-1.8, 1.8))
			if pos.z > -15.0:
				continue
			if _path_dist(pos) < 2.0:
				continue
			if pos.distance_to(CLEARING_CENTER) < CLEARING_R:
				continue
			if pos.distance_to(POND_CENTER) < 5.6:
				continue
			# il fiume attraversa il bosco: niente alberi nel letto.
			# Sulla riva est il bosco continua a terra; oltre la parete
			# vive SULLA scogliera
			var rx := _river_x(pos.z)
			if absf(pos.x - rx) < 5.2:
				continue
			if pos.x > _cliff_x(pos.z) - 2.5:
				pos.y = CLIFF_H
			var s := rng.randf_range(0.75, 1.35)
			var tf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos)
			var key := ("p" if rng.randf() < 0.55 else "b") \
					+ ("1" if rng.randf() < 0.5 else "2") \
					+ ("w" if pos.x < 0.0 else "e")
			(chunks[key] as Array).append(tf)

			# i tronchi si toccano solo di qua dal fiume: collisioni
			# solo per gli alberi a quota prato
			if pos.y == 0.0:
				var shape := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.28 * s
				cyl.height = 3.0
				shape.shape = cyl
				shape.position = pos + Vector3(0, 1.5, 0)
				colliders.add_child(shape)
	add_child(colliders)

	_scatter_exact(pine, chunks["p1w"])
	_scatter_exact(pine, chunks["p1e"])
	_scatter_exact(pine2, chunks["p2w"])
	_scatter_exact(pine2, chunks["p2e"])
	_scatter_exact(broad, chunks["b1w"])
	_scatter_exact(broad, chunks["b1e"])
	_scatter_exact(broad2, chunks["b2w"])
	_scatter_exact(broad2, chunks["b2e"])


func _forest_spot(rng: RandomNumberGenerator, min_path := 1.5) -> Vector3:
	# un punto libero nel bosco (non sul sentiero, non nella radura,
	# di qua dal fiume: il sottobosco non cresce sott'acqua)
	for attempt in 12:
		var p := Vector3(rng.randf_range(-48.0, 48.0), 0, rng.randf_range(-50.0, -16.0))
		if _path_dist(p) > min_path and p.distance_to(CLEARING_CENTER) > CLEARING_R - 1.0 \
				and (p.x < _river_x(p.z) - 5.0
				or (p.x > _river_x(p.z) + 5.0 and p.x < _cliff_x(p.z) - 2.0)):
			return p
	return Vector3(-20, 0, -40)


func _build_forest_undergrowth(rng: RandomNumberGenerator) -> void:
	# felci: rosetta di fronde inclinate, ondeggiano al vento dello shader
	var fern_mat := _paint_mat(Color("5da060"), Color("487f4a"), 1.4, 0.6, 0.02)
	var fern_parts := []
	for i in 6:
		var yaw := float(i) / 6.0 * TAU
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -1.05)
		var off := Basis(Vector3.UP, yaw) * Vector3(0, 0.1, -0.12)
		fern_parts.append([_cone_mesh(0.11, 0.95, 6), Transform3D(b, off), fern_mat])
	var fern := _merge(fern_parts)

	var fern_tf: Array[Transform3D] = []
	# molte felci costeggiano il sentiero, le altre sparse nel bosco
	for i in range(2, _path_samples.size() - 2, 3):
		var dir := (_path_samples[i + 1] - _path_samples[i]).normalized()
		var perp := dir.cross(Vector3.UP)
		@warning_ignore("integer_division")
		var side := 1.0 if (i / 3) % 2 == 0 else -1.0
		var pos := _path_samples[i] + perp * side * rng.randf_range(1.5, 2.4)
		var s := rng.randf_range(0.6, 1.1)
		fern_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos))
	for i in 50:
		var s := rng.randf_range(0.55, 1.05)
		fern_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), _forest_spot(rng)))
	_scatter_exact(fern, fern_tf, false)

	# rocce muschiose
	var rock_gray := _paint_mat(Color("8f9088"), Color("74786f"), 2.0, 0.5)
	var moss := _paint_mat(Color("6a9a5a"), Color("55804a"), 3.0, 0.5)
	var rock := _merge([
		[_sphere_mesh(0.5, 10), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.62, 0.85)), Vector3(0, 0.2, 0)), rock_gray],
		[_sphere_mesh(0.32, 8), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.55, 0.9)), Vector3(0.42, 0.12, 0.18)), rock_gray],
		[_sphere_mesh(0.3, 8), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.4, 1)), Vector3(0, 0.4, -0.04)), moss],
	])
	var rock_tf: Array[Transform3D] = []
	for i in 36:
		var s := rng.randf_range(0.5, 1.3)
		rock_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), _forest_spot(rng, 1.1)))
	_scatter_exact(rock, rock_tf)

	# ciuffi di funghi rossi
	var stem_mat := _paint_mat(Color("f3e6d5"), Color("e2d2ba"), 5.0, 0.4)
	var cap_red := _paint_mat(Color("d96a6a"), Color("c25454"), 4.0, 0.5)
	var shroom_parts := []
	for off in [Vector3.ZERO, Vector3(0.16, -0.03, 0.06), Vector3(-0.1, -0.05, 0.12)]:
		shroom_parts.append([_cyl_mesh(0.045, 0.06, 0.13, 6), Transform3D(Basis.IDENTITY, off + Vector3(0, 0.065, 0)), stem_mat])
		shroom_parts.append([_sphere_mesh(0.12, 10), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.6, 1)), off + Vector3(0, 0.14, 0)), cap_red])
	var shrooms := _merge(shroom_parts)
	var shroom_tf: Array[Transform3D] = []
	for i in 40:
		var s := rng.randf_range(0.6, 1.2)
		shroom_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), _forest_spot(rng, 1.0)))
	_scatter_exact(shrooms, shroom_tf, false)

	# funghi luminosi: brillano teal lungo il sentiero, magici di notte
	var glow_cap := StandardMaterial3D.new()
	glow_cap.albedo_color = Color(0.42, 0.88, 0.8)
	glow_cap.emission_enabled = true
	glow_cap.emission = Color(0.3, 0.95, 0.85)
	glow_cap.emission_energy_multiplier = 1.1
	var glow := _merge([
		[_cyl_mesh(0.04, 0.055, 0.14, 6), Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0)), stem_mat],
		[_sphere_mesh(0.11, 10), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.62, 1)), Vector3(0, 0.15, 0)), glow_cap],
		[_sphere_mesh(0.07, 8), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.62, 1)), Vector3(0.14, 0.09, 0.05)), glow_cap],
	])
	var glow_tf: Array[Transform3D] = []
	for i in range(4, _path_samples.size() - 2, 8):
		var dir := (_path_samples[i + 1] - _path_samples[i]).normalized()
		var perp := dir.cross(Vector3.UP)
		@warning_ignore("integer_division")
		var side := -1.0 if (i / 8) % 2 == 0 else 1.0
		var pos := _path_samples[i] + perp * side * rng.randf_range(1.1, 1.7)
		glow_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), pos))
	for i in 6:
		var a := float(i) / 6.0 * TAU
		var pos := CLEARING_CENTER + Vector3(cos(a), 0, sin(a)) * (CLEARING_R - 1.2)
		glow_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos))
	_scatter_exact(glow, glow_tf, false)

	# tronchi caduti e ceppi
	var log_mesh := _merge([
		[_cyl_mesh(0.2, 0.2, 1.7, 9), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.2, 0)), bark_mat()],
		[_sphere_mesh(0.24, 8), Transform3D(Basis.IDENTITY.scaled(Vector3(1.6, 0.35, 0.9)), Vector3(0.2, 0.36, 0)), moss],
	])
	var log_tf: Array[Transform3D] = []
	for i in 12:
		log_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _forest_spot(rng, 1.6)))
	_scatter_exact(log_mesh, log_tf)

	var stump := _merge([
		[_cyl_mesh(0.26, 0.3, 0.42, 9), Transform3D(Basis.IDENTITY, Vector3(0, 0.21, 0)), bark_mat()],
		[_cyl_mesh(0.24, 0.24, 0.03, 9), Transform3D(Basis.IDENTITY, Vector3(0, 0.43, 0)), stem_mat],
	])
	var stump_tf: Array[Transform3D] = []
	for i in 8:
		stump_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _forest_spot(rng, 1.4)))
	# tre ceppi attorno al falò, per sedersi col pensiero
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.5
		stump_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), CLEARING_CENTER + Vector3(cos(a), 0, sin(a)) * 1.7))
	_scatter_exact(stump, stump_tf)


var _bark_cached: ShaderMaterial
func bark_mat() -> ShaderMaterial:
	if _bark_cached == null:
		_bark_cached = _paint_mat(Color("6a4e3a"), Color("57402f"), 2.5, 0.55)
	return _bark_cached


# fasci di luce dorata tra le chiome, lungo il sentiero
func _build_forest_shafts(rng: RandomNumberGenerator) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 16
	tex.height = 64
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.96, 0.8, 0.5), Color(1.0, 0.96, 0.8, 0.16), Color(1.0, 0.96, 0.8, 0.0)])
	tex.gradient = grad

	_shaft_mat = StandardMaterial3D.new()
	_shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shaft_mat.albedo_texture = tex
	_shaft_mat.albedo_color = Color(1, 1, 1, 0.32)
	_shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 5.4)
	quad.material = _shaft_mat

	var transforms: Array[Transform3D] = []
	for i in 10:
		var s := _path_samples[mini(4 + i * 7, _path_samples.size() - 1)]
		var pos := s + Vector3(rng.randf_range(-1.5, 1.5), 2.7, rng.randf_range(-1.0, 1.0))
		var rot := Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)) \
				* Basis(Vector3.RIGHT, -0.18) * Basis(Vector3.BACK, -0.3)
		rot = rot.scaled(Vector3(rng.randf_range(0.7, 1.4), 1, 1))
		transforms.append(Transform3D(rot, pos))
	_scatter_exact(quad, transforms, false)


# nebbiolina bassa che scivola tra i tronchi
func _build_forest_mist(rng: RandomNumberGenerator) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_circle(Color(0.88, 0.93, 1.0, 0.5), 0.7)
	mat.albedo_color = Color(1, 1, 1, 0.1)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y

	for i in 6:
		var quad := QuadMesh.new()
		quad.size = Vector2(7.0, 2.4)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.position = Vector3(rng.randf_range(-20.0, 20.0), 1.0, rng.randf_range(-46.0, -18.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mists.append(mi)
		_mist_speeds.append(rng.randf_range(0.08, 0.2))


# foglie d'oro che cadono planando tra gli alberi
func _build_forest_leaves() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.085, 0.085)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_circle(Color("c2cc74", 0.95), 0.55)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.0, 0.5, 15.0)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.15, -0.3, 0.05)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -80.0
	pm.angular_velocity_max = 80.0
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.88, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var leaves := GPUParticles3D.new()
	leaves.amount = 30
	leaves.lifetime = 8.0
	leaves.preprocess = 6.0
	leaves.local_coords = false
	leaves.process_material = pm
	leaves.draw_pass_1 = quad
	leaves.position = Vector3(0, 4.2, -30)
	leaves.visibility_aabb = AABB(Vector3(-10, -6, -18), Vector3(20, 9, 36))
	add_child(leaves)
	# la stagione decide quando cadono (e di che colore): piene d'autunno
	_forest_leaf_fx = leaves
	_forest_leaf_mat = mat


# la radura: cerchio di pietre, falò scoppiettante, luce che respira
func _build_campfire() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var c := CLEARING_CENTER

	var stone := _sphere_mesh(0.16, 8)
	stone.material = _paint_mat(Color("8f9088"), Color("74786f"), 3.0, 0.5)
	var ring: Array[Transform3D] = []
	for i in 8:
		var a := float(i) / 8.0 * TAU
		ring.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, 0.7, 1) * rng.randf_range(0.8, 1.2)),
				c + Vector3(cos(a) * 0.62, 0.08, sin(a) * 0.62)))
	_scatter_exact(stone, ring)

	var root := Node3D.new()
	root.position = c
	add_child(root)
	for i in 3:
		var a := float(i) / 3.0 * TAU
		var log_i := MeshInstance3D.new()
		log_i.mesh = _cyl_mesh(0.06, 0.075, 0.7, 7)
		log_i.material_override = bark_mat()
		log_i.position = Vector3(cos(a) * 0.16, 0.22, sin(a) * 0.16)
		log_i.rotation = Vector3(cos(a) * 1.1, 0, sin(a) * 1.1)
		root.add_child(log_i)

	# fiamme + scintille
	var fire_tex := _soft_circle(Color(1.0, 0.8, 0.35, 0.9), 0.5)
	var fquad := QuadMesh.new()
	fquad.size = Vector2(0.26, 0.26)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.albedo_texture = fire_tex
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.vertex_color_use_as_albedo = true
	fquad.material = fmat
	var fpm := ParticleProcessMaterial.new()
	fpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fpm.emission_box_extents = Vector3(0.22, 0.04, 0.22)
	fpm.direction = Vector3(0, 1, 0)
	fpm.spread = 10.0
	fpm.initial_velocity_min = 0.35
	fpm.initial_velocity_max = 0.7
	fpm.gravity = Vector3(0, 0.8, 0)
	fpm.scale_min = 0.5
	fpm.scale_max = 1.3
	var framp := Gradient.new()
	framp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	framp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var framp_tex := GradientTexture1D.new()
	framp_tex.gradient = framp
	fpm.color_ramp = framp_tex
	var fire := GPUParticles3D.new()
	fire.amount = 22
	fire.lifetime = 0.8
	fire.process_material = fpm
	fire.draw_pass_1 = fquad
	fire.position = Vector3(0, 0.28, 0)
	root.add_child(fire)

	_campfire_light = OmniLight3D.new()
	_campfire_light.light_color = Color(1.0, 0.72, 0.42)
	_campfire_light.light_energy = 1.25
	_campfire_light.omni_range = 6.0
	_campfire_light.position = Vector3(0, 0.9, 0)
	root.add_child(_campfire_light)


# funghi da raccolta: più grandi dei decorativi, il bottino della passeggiata
func _spawn_pickup_mushroom() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var node := Node3D.new()
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.06
	sm.bottom_radius = 0.08
	sm.height = 0.17
	stem.mesh = sm
	stem.material_override = _paint_mat(Color("f3e6d5"), Color("e2d2ba"), 5.0, 0.4)
	stem.position = Vector3(0, 0.085, 0)
	node.add_child(stem)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.17
	cm.height = 0.34
	cap.mesh = cm
	cap.material_override = _paint_mat(Color("d96a6a"), Color("c25454"), 4.0, 0.5)
	cap.position = Vector3(0, 0.19, 0)
	cap.scale = Vector3(1, 0.6, 1)
	node.add_child(cap)
	var dot_mat := _paint_mat(Color.WHITE, Color("f0e2cc"), 4.0, 0.2)
	for i in 3:
		var a := rng.randf() * TAU
		var dot := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.032
		dm.height = 0.064
		dot.mesh = dm
		dot.material_override = dot_mat
		dot.position = Vector3(cos(a) * 0.09, 0.25, sin(a) * 0.09)
		node.add_child(dot)
	node.position = _forest_spot(rng, 1.2)
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * 0.05
	add_child(node)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pickups.append(node)


## Il fungo raccoglibile più vicino entro max_d (indice, o -1).
func nearest_pickup(pos: Vector3, max_d: float) -> int:
	var best := -1
	var best_d := max_d
	for i in _pickups.size():
		var d: float = pos.distance_to(_pickups[i].global_position)
		if d < best_d:
			best_d = d
			best = i
	return best


## Consegna il fungo al cestino: il bosco ne farà crescere un altro altrove.
func collect_pickup(i: int) -> Node3D:
	var node := _pickups[i]
	_pickups.remove_at(i)
	_pickup_respawn = randf_range(50.0, 100.0)
	return node


# ================================================================ stagno

func _build_pond() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33

	# la sponda sabbiosa e il fondo scuro, appena incassati nel prato
	var rim := CylinderMesh.new()
	rim.top_radius = 4.0
	rim.bottom_radius = 4.1
	rim.height = 0.045
	rim.radial_segments = 36
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = _paint_mat(Color("c8b493"), Color("aa9478"), 2.0, 0.5, 0.0, true)
	rim_mi.position = POND_CENTER + Vector3(0, 0.02, 0)
	rim_mi.scale = Vector3(1.15, 1, 1)
	add_child(rim_mi)

	# l'acqua
	var water := CylinderMesh.new()
	water.top_radius = POND_R
	water.bottom_radius = POND_R
	water.height = 0.02
	water.radial_segments = 48
	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	var wmi := MeshInstance3D.new()
	wmi.mesh = water
	wmi.material_override = wmat
	wmi.position = POND_CENTER + Vector3(0, 0.055, 0)
	wmi.scale = Vector3(1.15, 1, 1)
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)

	# ninfee: foglie tonde col taglio, un paio in fiore
	var pad_mat := _paint_mat(Color("6aa858"), Color("548c46"), 3.0, 0.55)
	for i in 6:
		var lily := Node3D.new()
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.8, 2.6)
		lily.position = POND_CENTER + Vector3(cos(a) * r * 1.15, 0.075, sin(a) * r)
		var pad := CylinderMesh.new()
		pad.top_radius = rng.randf_range(0.16, 0.26)
		pad.bottom_radius = pad.top_radius
		pad.height = 0.02
		var mi := MeshInstance3D.new()
		mi.mesh = pad
		mi.material_override = pad_mat
		lily.add_child(mi)
		# il taglio della foglia
		var notch := MeshInstance3D.new()
		var nb := BoxMesh.new()
		nb.size = Vector3(pad.top_radius * 0.5, 0.03, 0.05)
		notch.mesh = nb
		var nmat := ShaderMaterial.new()
		nmat.shader = WATER_SHADER
		notch.material_override = nmat
		notch.position = Vector3(pad.top_radius * 0.75, 0, 0)
		notch.rotation.y = rng.randf() * TAU
		lily.add_child(notch)
		if i < 2:
			var fmat := _paint_mat(Color("ffd1e0"), Color("f4b8c8"), 8.0, 0.4)
			for k in 5:
				var pa := float(k) / 5.0 * TAU
				var petal := MeshInstance3D.new()
				var ps := SphereMesh.new()
				ps.radius = 0.05
				ps.height = 0.1
				petal.mesh = ps
				petal.material_override = fmat
				petal.position = Vector3(cos(pa) * 0.06, 0.04, sin(pa) * 0.06)
				petal.scale = Vector3(1, 0.5, 1)
				lily.add_child(petal)
			var core := MeshInstance3D.new()
			var cs := SphereMesh.new()
			cs.radius = 0.035
			cs.height = 0.07
			core.mesh = cs
			core.material_override = _paint_mat(Color("ffd76e"), Color("eec254"), 8.0, 0.4)
			core.position = Vector3(0, 0.05, 0)
			lily.add_child(core)
		add_child(lily)
		_lilies.append(lily)

	# canne con la pannocchia, a ciuffi sulla sponda
	var reed := _merge([
		[_cyl_mesh(0.012, 0.016, 0.9, 6), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)),
				_paint_mat(Color("8fae6a"), Color("74945a"), 3.0, 0.5, 0.025)],
		[_cyl_mesh(0.014, 0.018, 0.75, 6), Transform3D(Basis(Vector3.BACK, 0.12), Vector3(0.08, 0.37, 0.03)),
				_paint_mat(Color("9aba74"), Color("7ea062"), 3.0, 0.5, 0.025)],
		[_capsule_mesh(0.035, 0.18), Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)),
				_paint_mat(Color("8a6242"), Color("6f4e34"), 4.0, 0.45)],
	])
	var reed_tf: Array[Transform3D] = []
	for i in 16:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(POND_R + 0.25, POND_R + 0.7)
		var pos := POND_CENTER + Vector3(cos(a) * rr * 1.15, 0, sin(a) * rr)
		reed_tf.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.15)), pos))
	_scatter_exact(reed, reed_tf, false)

	# le rane, sedute sulla sponda: si tuffano se ti avvicini
	for i in 3:
		_spawn_frog(rng.randf() * TAU)


func _capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


func _spawn_frog(angle: float) -> void:
	var frog := Node3D.new()
	var green := _paint_mat(Color("7dbd68"), Color("5da050"), 5.0, 0.5)
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.075
	bm.height = 0.15
	body.mesh = bm
	body.material_override = green
	body.position = Vector3(0, 0.06, 0)
	body.scale = Vector3(1, 0.8, 1.1)
	frog.add_child(body)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("2a1d1d")
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.028
		em.height = 0.056
		eye.mesh = em
		eye.material_override = green
		eye.position = Vector3(side * 0.045, 0.13, -0.045)
		frog.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.012
		pm.height = 0.024
		pupil.mesh = pm
		pupil.material_override = dark
		pupil.position = Vector3(side * 0.045, 0.135, -0.068)
		frog.add_child(pupil)

	var pos := POND_CENTER + Vector3(cos(angle) * (POND_R + 0.35) * 1.15, 0.03, sin(angle) * (POND_R + 0.35))
	frog.position = pos
	frog.rotation.y = angle + PI * 0.5
	add_child(frog)
	_frogs.append({"node": frog, "angle": angle, "state": "sit", "timer": 0.0, "seed": randf() * 10.0})


## Un anello che si allarga sull'acqua e svanisce (tuffi, galleggiante…).
func water_ripple(pos: Vector3, size := 1.0, surface_y := 0.075) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.9, 0.98, 1.0, 0.8)
	quad.material = mat
	var ring := MeshInstance3D.new()
	ring.mesh = quad
	ring.rotation.x = -PI * 0.5
	ring.position = Vector3(pos.x, surface_y, pos.z)
	ring.scale = Vector3.ONE * 0.2 * size
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 2.4 * size, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


func _update_frogs(delta: float) -> void:
	var player := get_node_or_null("%Player") as Node3D
	for f in _frogs:
		match str(f["state"]):
			"sit":
				var node := f["node"] as Node3D
				node.position.y = 0.03 + absf(sin(_t * 2.0 + f["seed"])) * 0.012
				if player and player.global_position.distance_to(node.global_position) < 2.3:
					f["state"] = "jump"
					var splash: Vector3 = POND_CENTER + (node.global_position - POND_CENTER) * Vector3(0.55, 0, 0.55)
					var tw := create_tween()
					tw.set_parallel(true)
					# x e z in orizzontale, la y la governa solo l'arco del
					# salto: due tween sulla stessa "position" litigherebbero
					tw.tween_property(node, "position:x", splash.x, 0.5) \
							.set_trans(Tween.TRANS_LINEAR)
					tw.tween_property(node, "position:z", splash.z, 0.5) \
							.set_trans(Tween.TRANS_LINEAR)
					tw.tween_property(node, "position:y", 0.55, 0.25) \
							.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tw.chain().tween_property(node, "position:y", 0.0, 0.22) \
							.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
					tw.chain().tween_callback(func():
						water_ripple(splash, 1.1)
						var sfx = get_node_or_null(^"/root/Sfx")
						if sfx:
							sfx.play("step_wet2", -14.0, 1.2)
						node.visible = false
						f["state"] = "hidden"
						f["timer"] = randf_range(22.0, 40.0))
			"hidden":
				f["timer"] = float(f["timer"]) - delta
				if float(f["timer"]) <= 0.0 and player \
						and player.global_position.distance_to(POND_CENTER) > 7.0:
					var node := f["node"] as Node3D
					var a: float = f["angle"]
					node.position = POND_CENTER + Vector3(cos(a) * (POND_R + 0.35) * 1.15, 0.03, sin(a) * (POND_R + 0.35))
					node.visible = true
					f["state"] = "sit"


# muri invisibili ai bordi del mondo: un solo corpo, quattro forme
func _build_boundary() -> void:
	var body := StaticBody3D.new()
	for w in [[Vector3(0, 2, -57), Vector3(118, 4, 2)], [Vector3(0, 2, 57), Vector3(118, 4, 2)],
			[Vector3(-57, 2, 0), Vector3(2, 4, 118)], [Vector3(57, 2, 0), Vector3(2, 4, 118)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = w[1]
		shape.shape = box
		shape.position = w[0]
		body.add_child(shape)
	add_child(body)


# ================================================================ fiume
# La verticalità di Animal Crossing: il fiume serpeggia lungo il lato
# est del mondo, oltre c'è la SCOGLIERA a gradoni col bosco in cima e
# la cascata che precipita nel fiume. Si attraversa sul ponte ad arco
# (o sul tronco muschioso nella foresta) fino alla passeggiata sotto la
# parete di roccia. Il letto lo scava ground.gdshader con la stessa
# identica curva di _river_x: terreno e acqua leggono lo stesso disegno.

const RIVER_Z_MIN := -56.0
const RIVER_Z_MAX := 56.0
const RIVER_WATER_Y := -0.45
const CLIFF_H := 2.5
const BRIDGE_Z := 3.2
const LOG_Z := -26.0
const FALL_Z := -4.0

var _river_fish: Array[Dictionary] = []
var _river_pads: Array[Dictionary] = []
var _fall_base := Vector3.ZERO
var _fall_ripple_cd := 0.0


## Il corso del fiume: x del centro alla quota z data. La stessa curva
## vive nel vertex di ground.gdshader (seni piccoli: niente divergenze).
func _river_x(z: float) -> float:
	return 18.6 + sin(z * 0.061) * 1.35 + sin(z * 0.023 + 2.0) * 0.85


## Vero dentro il letto del fiume (il BuildSystem non ci piazza pezzi).
func is_river(pos: Vector3) -> bool:
	return absf(pos.x - _river_x(pos.z)) < 2.9 \
			and pos.z > RIVER_Z_MIN and pos.z < RIVER_Z_MAX


# La x della parete di scogliera alla quota z. La scogliera NON
# costeggia il fiume: si tiene indietro e lascia una riva est larga e
# percorribile (il ponte porta LÌ, mica contro un muro) — e si stringe
# fino a baciare l'acqua solo alla cascata, dove il canyon si pinza.
func _cliff_x(z: float) -> float:
	return _river_x(z) + 2.9 + 9.0 * smoothstep(1.6, 9.0, absf(z - FALL_Z))


# normali morbide di una griglia APERTA (righe × colonne, senza wrap)
func _strip_normals(pos: Array) -> Array:
	var rows := pos.size()
	var cols: int = (pos[0] as Array).size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		for j in cols:
			var t_row: Vector3 = pos[mini(i + 1, rows - 1)][j] - pos[maxi(i - 1, 0)][j]
			var t_col: Vector3 = pos[i][mini(j + 1, cols - 1)] - pos[i][maxi(j - 1, 0)]
			var n := t_row.cross(t_col)
			nrow.append(n.normalized() if n.length_squared() > 0.000001 else Vector3.UP)
		out.append(nrow)
	return out


func _build_river() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	_build_river_water()
	_build_cliff()
	_build_waterfall()
	_build_bridges()
	_build_river_barriers()
	_build_river_dressing(rng)
	_build_east_bank(rng)
	_build_river_life(rng)


# ------------------------------------------------------------- l'acqua

func _build_river_water() -> void:
	# il nastro d'acqua segue la curva; UV.y scorre a valle (+z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[Array] = []
	var z := RIVER_Z_MIN
	while z <= RIVER_Z_MAX + 0.01:
		var cx := _river_x(z)
		rows.append([Vector3(cx - 2.35, RIVER_WATER_Y, z),
				Vector3(cx + 2.35, RIVER_WATER_Y, z), z])
		z += 2.0
	for i in rows.size() - 1:
		var v0 := (float(rows[i][2]) - RIVER_Z_MIN) * 0.24
		var v1 := (float(rows[i + 1][2]) - RIVER_Z_MIN) * 0.24
		var a: Vector3 = rows[i][0]
		var b: Vector3 = rows[i][1]
		var c: Vector3 = rows[i + 1][1]
		var d: Vector3 = rows[i + 1][0]
		for v: Array in [[a, Vector2(0, v0)], [d, Vector2(0, v1)], [c, Vector2(1, v1)],
				[a, Vector2(0, v0)], [c, Vector2(1, v1)], [b, Vector2(1, v0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mat := ShaderMaterial.new()
	mat.shader = RIVER_SHADER
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ----------------------------------------------------------- scogliera

func _build_cliff() -> void:
	var rock := _paint_mat(Color("a89e8c"), Color("857b6a"), 2.2, 0.5, 0.0, true)
	var grass_cap := _paint_mat(Color("85b768"), Color("619a4e"), 0.9, 0.55, 0.0, true)
	var fringe_mat := _paint_mat(Color("6fa757"), Color("548c46"), 1.6, 0.55, 0.015)

	# la parete: profilo [sporgenza verso il fiume, quota], svasata alla
	# base, col ciglio che aggetta — e gobbe di roccia lungo il corso
	var prof := [[0.55, 0.0], [0.30, 0.75], [0.12, 1.55], [0.02, 2.15], [0.30, CLIFF_H - 0.02]]
	var pos: Array = []
	var z := RIVER_Z_MIN
	while z <= RIVER_Z_MAX + 0.01:
		var wx := _cliff_x(z)
		var row: Array[Vector3] = []
		for p: Array in prof:
			var bump := (_tuft_vnoise(z * 0.6, float(p[1]) * 1.3) - 0.5) * 0.3
			row.append(Vector3(wx - float(p[0]) - bump, float(p[1]), z))
		pos.append(row)
		z += 1.2
	var nrm := _strip_normals(pos)
	for i in nrm.size():
		for j in (nrm[i] as Array).size():
			if (nrm[i][j] as Vector3).x > 0.0:
				nrm[i][j] = -(nrm[i][j] as Vector3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pos.size() - 1:
		for j in prof.size() - 1:
			for idx: Array in [[i, j], [i, j + 1], [i + 1, j + 1],
					[i, j], [i + 1, j + 1], [i + 1, j]]:
				st.set_normal(nrm[idx[0]][idx[1]])
				st.add_vertex(pos[idx[0]][idx[1]])
	var wall := MeshInstance3D.new()
	wall.mesh = st.commit()
	wall.material_override = rock
	add_child(wall)

	# la frangia d'erba che sborda dal ciglio (pinzata via alla cascata)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fr: Array = []
	z = RIVER_Z_MIN
	while z <= RIVER_Z_MAX + 0.01:
		var wx := _cliff_x(z)
		var droop := 0.28 + _tuft_vnoise(z * 1.7, 3.0) * 0.22
		var reach := 0.55 + _tuft_vnoise(z * 1.1, 9.0) * 0.25
		if absf(z - FALL_Z) < 1.3:
			reach = 0.05
			droop = 0.05
		fr.append([Vector3(wx + 0.10, CLIFF_H + 0.015, z),
				Vector3(wx - reach, CLIFF_H - droop, z)])
		z += 2.0
	for i in fr.size() - 1:
		var a: Vector3 = fr[i][0]
		var b: Vector3 = fr[i][1]
		var c: Vector3 = fr[i + 1][1]
		var d: Vector3 = fr[i + 1][0]
		var n := Vector3(-0.55, 0.83, 0).normalized()
		for v: Vector3 in [a, d, c, a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	var fringe := MeshInstance3D.new()
	fringe.mesh = st.commit()
	fringe.material_override = fringe_mat
	add_child(fringe)

	# il pianoro erboso in cima, fino alle colline lontane
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xoff := [0.05, 6.0, 16.0, 30.0, 46.0]
	var cap: Array = []
	z = RIVER_Z_MIN
	while z <= RIVER_Z_MAX + 0.01:
		var wx := _cliff_x(z)
		var row: Array[Vector3] = []
		for xo: float in xoff:
			row.append(Vector3(wx + xo, CLIFF_H, z))
		cap.append(row)
		z += 4.0
	for i in cap.size() - 1:
		for j in xoff.size() - 1:
			var a: Vector3 = cap[i][j]
			var b: Vector3 = cap[i][j + 1]
			var c: Vector3 = cap[i + 1][j + 1]
			var d: Vector3 = cap[i + 1][j]
			for v: Vector3 in [a, d, c, a, c, b]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var capmi := MeshInstance3D.new()
	capmi.mesh = st.commit()
	capmi.material_override = grass_cap
	add_child(capmi)

	# gli alberi sul ciglio: il profilo del mondo di sopra (e un secondo
	# ciliegio lassù che perde petali giù dalla scogliera)
	var cherry_up := _make_tree(Vector3(_cliff_x(9.0) + 2.6, CLIFF_H, 9.0), 1.15,
			Color("ffd4e2"), Color("f5a8c0"), 11, "cherry")
	_add_petals(cherry_up)
	_make_tree(Vector3(_cliff_x(-14.0) + 3.4, CLIFF_H, -14.0), 1.05,
			Color("86c46c"), Color("64a854"), 12)
	_make_tree(Vector3(_cliff_x(18.0) + 5.0, CLIFF_H, 18.0), 0.95,
			Color("97cc74"), Color("74b05c"), 13)
	_make_tree(Vector3(_cliff_x(30.0) + 2.8, CLIFF_H, 30.0), 1.1,
			Color("7dbd68"), Color("5da050"), 14)
	_make_tree(Vector3(_cliff_x(42.0) + 4.2, CLIFF_H, 42.0), 0.9,
			Color("8cc873"), Color("6cae5b"), 15)

	# margheritine sparse sul ciglio, affacciate sul vuoto
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var daisy := _daisy_mesh(Color("fffaf4"), Color("ffcf5e"))
	var dts: Array[Transform3D] = []
	for i in 10:
		var dz := rng.randf_range(RIVER_Z_MIN + 8.0, RIVER_Z_MAX - 8.0)
		if absf(dz - FALL_Z) < 3.0:
			continue
		dts.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2)),
				Vector3(_cliff_x(dz) + rng.randf_range(0.7, 2.6), CLIFF_H, dz)))
	_scatter_exact(daisy, dts, false)

	# la parete è roccia vera: non ci si arrampica. I box seguono il
	# TANGENTE della parete (vicino alla cascata corre in diagonale)
	var body := StaticBody3D.new()
	z = RIVER_Z_MIN
	while z <= RIVER_Z_MAX:
		var zc := z + 0.6
		var slope := (_cliff_x(zc + 0.6) - _cliff_x(zc - 0.6)) / 1.2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, CLIFF_H + 1.0, 1.8)
		shape.shape = box
		shape.position = Vector3(_cliff_x(zc) + 0.15, (CLIFF_H + 1.0) * 0.5, zc)
		shape.rotation.y = atan(slope)
		body.add_child(shape)
		z += 1.2
	add_child(body)


# ------------------------------------------------------------ cascata

func _build_waterfall() -> void:
	var wx := _cliff_x(FALL_Z)
	_fall_base = Vector3(wx - 0.55, RIVER_WATER_Y, FALL_Z)

	# il velo: bombato verso il fiume, dal ciglio all'acqua
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 7
	var half_w := 0.85
	var sheet: Array = []
	for i in rows:
		var t := float(i) / float(rows - 1)
		var y := lerpf(CLIFF_H - 0.05, RIVER_WATER_Y - 0.06, t)
		var bow := wx - 0.12 - sin(t * PI) * 0.38 - t * 0.35
		sheet.append([Vector3(bow, y, FALL_Z - half_w), Vector3(bow, y, FALL_Z + half_w), t])
	for i in rows - 1:
		var a: Vector3 = sheet[i][0]
		var b: Vector3 = sheet[i][1]
		var c: Vector3 = sheet[i + 1][1]
		var d: Vector3 = sheet[i + 1][0]
		var t0: float = sheet[i][2]
		var t1: float = sheet[i + 1][2]
		for v: Array in [[a, Vector2(0, t0)], [d, Vector2(0, t1)], [c, Vector2(1, t1)],
				[a, Vector2(0, t0)], [c, Vector2(1, t1)], [b, Vector2(1, t0)]]:
			st.set_normal(Vector3.LEFT)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var wmat := ShaderMaterial.new()
	wmat.shader = WATERFALL_SHADER
	var veil := MeshInstance3D.new()
	veil.mesh = st.commit()
	veil.material_override = wmat
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(veil)

	# il ruscelletto sul pianoro che alimenta il salto
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y_top := CLIFF_H + 0.02
	var seg := [[wx + 4.2, 0.0], [wx + 2.0, 0.45], [wx - 0.10, 1.0]]
	for i in seg.size() - 1:
		var x0: float = seg[i][0]
		var x1: float = seg[i + 1][0]
		var v0: float = seg[i][1]
		var v1: float = seg[i + 1][1]
		var a := Vector3(x0, y_top, FALL_Z - 0.72)
		var b := Vector3(x0, y_top, FALL_Z + 0.72)
		var c := Vector3(x1, y_top, FALL_Z + 0.72)
		var d := Vector3(x1, y_top, FALL_Z - 0.72)
		for v: Array in [[a, Vector2(0, v0)], [d, Vector2(0, v1)], [c, Vector2(1, v1)],
				[a, Vector2(0, v0)], [c, Vector2(1, v1)], [b, Vector2(1, v0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var smat := ShaderMaterial.new()
	smat.shader = RIVER_SHADER
	var stream := MeshInstance3D.new()
	stream.mesh = st.commit()
	stream.material_override = smat
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)

	# le rocce che incorniciano il salto, su e giù
	var rock := _paint_mat(Color("968d7c"), Color("6f6759"), 1.8, 0.55, 0.0, true)
	var parts := []
	for side: float in [-1.0, 1.0]:
		parts.append([_puff_mesh(0.55, 900 + int(side * 3.0), 0.7, 0.16),
				Transform3D(Basis(Vector3.UP, side * 0.7),
				Vector3(wx - 0.25, CLIFF_H - 0.15, FALL_Z + side * 1.15)), rock])
		parts.append([_puff_mesh(0.38, 910 + int(side * 5.0), 0.6, 0.18),
				Transform3D(Basis(Vector3.UP, side * 1.9),
				Vector3(wx - 0.7, RIVER_WATER_Y + 0.1, FALL_Z + side * 1.05)), rock])
	var rocks := MeshInstance3D.new()
	rocks.mesh = _merge(parts)
	add_child(rocks)

	# la nebbiolina che sale dal tonfo
	var mist_mat := StandardMaterial3D.new()
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.albedo_texture = _soft_circle(Color(0.94, 0.98, 1.0, 0.55), 0.6)
	mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mist_mat.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = mist_mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.45, 0.08, 0.9)
	pm.direction = Vector3(-0.4, 1, 0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.22
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.12, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.65),
			Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var mist := GPUParticles3D.new()
	mist.amount = 10
	mist.lifetime = 1.8
	mist.preprocess = 1.5
	mist.process_material = pm
	mist.draw_pass_1 = quad
	mist.position = _fall_base + Vector3(0, 0.15, 0)
	mist.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
	add_child(mist)


# -------------------------------------------------------------- ponti

func _build_bridges() -> void:
	var plank_mat := _paint_mat(Color("c89a6b"), Color("a87c50"), 4.0, 0.5)
	var dark_mat := _paint_mat(Color("a87c50"), Color("8a6440"), 4.0, 0.5)
	var pale_mat := _paint_mat(Color("e8cfa8"), Color("c89a6b"), 3.5, 0.45)

	# il ponte ad arco: assi che salgono e ridiscendono, corrimano curvi,
	# pomelli tondi sui montanti — e le rampette dolci alle due estremità
	var bx := _river_x(BRIDGE_Z)
	var bridge := Node3D.new()
	bridge.position = Vector3(bx, 0, BRIDGE_Z)
	var body := StaticBody3D.new()
	bridge.add_child(body)
	var n_planks := 10
	for i in n_planks:
		var t := (float(i) + 0.5) / float(n_planks)
		var lx := -3.6 + 7.2 * t
		var y := 0.10 + sin(t * PI) * 0.55
		var tilt := atan(0.24 * cos(t * PI))
		var p := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.78, 0.055, 1.62)
		p.mesh = pb
		p.material_override = plank_mat if i % 2 == 0 else dark_mat
		p.position = Vector3(lx, y, 0)
		p.rotation.z = tilt
		bridge.add_child(p)
		var shape := CollisionShape3D.new()
		var sb := BoxShape3D.new()
		sb.size = Vector3(0.80, 0.12, 1.62)
		shape.shape = sb
		shape.position = Vector3(lx, y - 0.03, 0)
		shape.rotation.z = tilt
		body.add_child(shape)
	# rampette d'ingresso (niente scalino: Mochi sale che è un piacere)
	for side: float in [-1.0, 1.0]:
		var ramp := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(1.3, 0.1, 1.62)
		ramp.shape = rb
		ramp.position = Vector3(side * 4.1, 0.03, 0)
		ramp.rotation.z = -side * 0.12
		body.add_child(ramp)
	# montanti coi pomelli + corrimano che segue l'arco
	for side: float in [-1.0, 1.0]:
		for tt: float in [0.04, 0.36, 0.64, 0.96]:
			var lx := -3.6 + 7.2 * tt
			var y := 0.10 + sin(tt * PI) * 0.55
			var post := MeshInstance3D.new()
			var postb := BoxMesh.new()
			postb.size = Vector3(0.08, 0.62, 0.08)
			post.mesh = postb
			post.material_override = dark_mat
			post.position = Vector3(lx, y + 0.31, side * 0.82)
			bridge.add_child(post)
			var knob := MeshInstance3D.new()
			knob.mesh = _sphere_mesh(0.065, 8)
			knob.material_override = pale_mat
			knob.position = Vector3(lx, y + 0.66, side * 0.82)
			bridge.add_child(knob)
		for i in 6:
			var t0 := 0.04 + (0.92 / 6.0) * float(i)
			var t1 := 0.04 + (0.92 / 6.0) * float(i + 1)
			var x0 := -3.6 + 7.2 * t0
			var x1 := -3.6 + 7.2 * t1
			var y0 := 0.72 + sin(t0 * PI) * 0.55
			var y1 := 0.72 + sin(t1 * PI) * 0.55
			var rail := MeshInstance3D.new()
			var railb := BoxMesh.new()
			railb.size = Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.06, 0.07, 0.06)
			rail.mesh = railb
			rail.material_override = pale_mat
			rail.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, side * 0.82)
			rail.rotation.z = atan2(y1 - y0, x1 - x0)
			bridge.add_child(rail)
	add_child(bridge)

	# il tronco muschioso nella foresta: il guado segreto del bosco
	var lx2 := _river_x(LOG_Z)
	var log_bridge := Node3D.new()
	log_bridge.position = Vector3(lx2, 0, LOG_Z)
	var bark := _paint_mat(Color("7a5a40"), Color("60462f"), 2.5, 0.55)
	var moss := _paint_mat(Color("6a9a5a"), Color("55804a"), 3.0, 0.5)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.34
	tm.bottom_radius = 0.34
	tm.height = 7.6
	tm.radial_segments = 12
	trunk.mesh = tm
	trunk.material_override = bark
	trunk.rotation.z = PI * 0.5
	trunk.position = Vector3(0, 0.32, 0)
	log_bridge.add_child(trunk)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(7.0, 0.05, 0.52)
	top.mesh = tb
	top.material_override = moss
	top.position = Vector3(0, 0.63, 0)
	log_bridge.add_child(top)
	for side: float in [-1.0, 1.0]:
		var stump := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.40
		sm.bottom_radius = 0.46
		sm.height = 0.5
		stump.mesh = sm
		stump.material_override = bark
		stump.position = Vector3(side * 3.85, 0.22, 0)
		log_bridge.add_child(stump)
	var lbody := StaticBody3D.new()
	var deck := CollisionShape3D.new()
	var db := BoxShape3D.new()
	db.size = Vector3(7.6, 0.5, 0.8)
	deck.shape = db
	deck.position = Vector3(0, 0.40, 0)
	lbody.add_child(deck)
	for side: float in [-1.0, 1.0]:
		var ramp := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(1.5, 0.1, 0.9)
		ramp.shape = rb
		ramp.position = Vector3(side * 4.35, 0.28, 0)
		ramp.rotation.z = -side * 0.42
		lbody.add_child(ramp)
	log_bridge.add_child(lbody)
	add_child(log_bridge)


# ------------------------------------------------- sponde invalicabili

func _build_river_barriers() -> void:
	# come in AC: sul bordo dell'acqua ci si ferma, si passa sui ponti
	var body := StaticBody3D.new()
	var z := RIVER_Z_MIN
	while z <= RIVER_Z_MAX:
		if absf(z - BRIDGE_Z) > 1.8 and absf(z - LOG_Z) > 1.8:
			for side: float in [-1.0, 1.0]:
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.35, 1.7, 2.55)
				shape.shape = box
				shape.position = Vector3(_river_x(z) + side * 2.8, 0.55, z)
				body.add_child(shape)
		z += 2.4
	add_child(body)


# --------------------------------------------- tife, sassi, passi ovest

func _build_river_dressing(rng: RandomNumberGenerator) -> void:
	# le tife: stelo slanciato, salsicciotto bruno, foglie a nastro
	var green := _paint_mat(Color("5f9050"), Color("4a7a40"), 3.0, 0.5, 0.035)
	var brown := _paint_mat(Color("7a5238"), Color("64422c"), 4.0, 0.45, 0.03)
	var parts := []
	for k in 3:
		var off := Vector3(rng.randf_range(-0.16, 0.16), 0, rng.randf_range(-0.16, 0.16))
		var h := rng.randf_range(0.72, 1.02)
		parts.append([_cyl_mesh(0.014, 0.02, h, 5),
				Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)),
				off + Vector3(0, h * 0.5, 0)), green])
		if k < 2:
			var cap := CapsuleMesh.new()
			cap.radius = 0.05
			cap.height = 0.24
			parts.append([cap, Transform3D(Basis.IDENTITY, off + Vector3(0, h + 0.06, 0)), brown])
		parts.append([_cone_mesh(0.038, rng.randf_range(0.45, 0.62), 5),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU)
				* Basis(Vector3.RIGHT, -0.5), off + Vector3(0.05, 0.26, 0.03)), green])
	var reed := _merge(parts)
	var reed_tf: Array[Transform3D] = []
	for i in 22:
		var z := rng.randf_range(RIVER_Z_MIN + 4.0, RIVER_Z_MAX - 4.0)
		if absf(z - BRIDGE_Z) < 2.6 or absf(z - LOG_Z) < 2.6 or absf(z - FALL_Z) < 2.4:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		reed_tf.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)),
				Vector3(_river_x(z) + side * rng.randf_range(2.6, 3.05), -0.06, z)))
	_scatter_exact(reed, reed_tf, false)

	# ciottoli levigati che spuntano dalle sponde
	var stone := _paint_mat(Color("b0aa9c"), Color("8d8779"), 3.0, 0.5)
	var peb_parts := []
	for i in 24:
		var z := rng.randf_range(RIVER_Z_MIN + 3.0, RIVER_Z_MAX - 3.0)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		peb_parts.append([_sphere_mesh(rng.randf_range(0.09, 0.2), 8),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU)
				.scaled(Vector3(1.2, 0.55, 1.0)),
				Vector3(_river_x(z) + side * rng.randf_range(2.3, 2.7), -0.12, z)), stone])
	var pebs := MeshInstance3D.new()
	pebs.mesh = _merge(peb_parts)
	add_child(pebs)

	# il sentiero di pietre si allunga fino al ponte
	var path_mat := _paint_mat(Color("c9c2b4"), Color("a89f92"), 5.0, 0.5)
	for i in 5:
		var t := float(i) / 4.0
		var p := Vector3(lerpf(6.4, 14.8, t), 0.035, lerpf(3.0, 3.2, t))
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(0.26, 0.33)
		cm.bottom_radius = cm.top_radius + 0.04
		cm.height = 0.07
		mi.mesh = cm
		mi.material_override = path_mat
		mi.position = p + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.25, 0.25))
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3(1, 1, rng.randf_range(0.8, 1.0))
		add_child(mi)


# ------------------------------------------------------- la riva est
# La destinazione del ponte: un prato vero oltre il fiume, col
# sentierino di pietre che porta al belvedere sotto la cascata, la
# lanterna che si accende la sera, fiori e un paio di alberi.

func _build_east_bank(rng: RandomNumberGenerator) -> void:
	# il sentierino: dallo sbarco del ponte su verso la cascata
	var path_mat := _paint_mat(Color("c9c2b4"), Color("a89f92"), 5.0, 0.5)
	var start := Vector3(_river_x(BRIDGE_Z) + 4.3, 0, BRIDGE_Z)
	var goal := Vector3(_river_x(FALL_Z + 3.4) + 3.5, 0, FALL_Z + 3.4)
	for i in 6:
		var t := float(i) / 5.0
		var p := start.lerp(goal, t)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(0.26, 0.33)
		cm.bottom_radius = cm.top_radius + 0.04
		cm.height = 0.07
		mi.mesh = cm
		mi.material_override = path_mat
		mi.position = p + Vector3(rng.randf_range(-0.2, 0.2), 0.035, rng.randf_range(-0.2, 0.2))
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3(1, 1, rng.randf_range(0.8, 1.0))
		add_child(mi)

	# la lanterna di pietra allo sbarco: saluta chi attraversa, la sera
	var lant := Node3D.new()
	lant.position = Vector3(_river_x(BRIDGE_Z) + 4.6, 0, BRIDGE_Z + 1.6)
	var stone := _paint_mat(Color("b0aa9c"), Color("8d8779"), 3.0, 0.5)
	var base := MeshInstance3D.new()
	base.mesh = _cyl_mesh(0.17, 0.22, 0.18, 8)
	base.material_override = stone
	base.position = Vector3(0, 0.09, 0)
	lant.add_child(base)
	var pillar := MeshInstance3D.new()
	pillar.mesh = _cyl_mesh(0.09, 0.12, 0.55, 7)
	pillar.material_override = stone
	pillar.position = Vector3(0, 0.45, 0)
	lant.add_child(pillar)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("ffd9a0")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("ffc978")
	glow_mat.emission_energy_multiplier = 1.0
	var cell := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.2, 0.18, 0.2)
	cell.mesh = cb
	cell.material_override = glow_mat
	cell.position = Vector3(0, 0.82, 0)
	lant.add_child(cell)
	var roof := MeshInstance3D.new()
	roof.mesh = _cone_mesh(0.24, 0.18, 8)
	roof.material_override = stone
	roof.position = Vector3(0, 1.0, 0)
	lant.add_child(roof)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 0.9
	light.omni_range = 3.4
	light.shadow_enabled = false
	light.position = Vector3(0, 0.84, 0)
	lant.add_child(light)
	add_child(lant)

	# fiori della riva est: margherite bianche e spighe di lavanda
	var daisy := _daisy_mesh(Color("fffaf4"), Color("ffcf5e"))
	var lav := _lavender_mesh()
	var dts: Array[Transform3D] = []
	var lts: Array[Transform3D] = []
	for i in 14:
		var z := rng.randf_range(-14.0, 16.0)
		if _cliff_x(z) - 1.6 < _river_x(z) + 3.8:
			continue  # troppo vicino alla pinza del canyon
		var x := rng.randf_range(_river_x(z) + 3.6, _cliff_x(z) - 1.6)
		var tf := Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)),
				Vector3(x, 0, z))
		if i % 3 == 0:
			lts.append(tf)
		else:
			dts.append(tf)
	_scatter_exact(daisy, dts, false)
	_scatter_exact(lav, lts, false)

	# due alberi di riva, coi piedi nel prato
	_make_tree(Vector3(_river_x(9.5) + 6.4, 0, 9.5), 0.95,
			Color("8cc873"), Color("6cae5b"), 21)
	_make_tree(Vector3(_river_x(-11.5) + 7.2, 0, -11.5), 1.05,
			Color("86c46c"), Color("64a854"), 22)


# ------------------------------------------ la vita del fiume (animata)

func _build_river_life(rng: RandomNumberGenerator) -> void:
	# ombre di pesci che risalgono la corrente scodinzolando
	var fish_mat := StandardMaterial3D.new()
	fish_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fish_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fish_mat.albedo_texture = _soft_circle(Color(0.10, 0.16, 0.20, 0.34), 0.5)
	for i in 5:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.52, 0.2)
		quad.material = fish_mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.rotation.x = -PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_river_fish.append({
			"node": mi,
			"z": rng.randf_range(-40.0, 40.0),
			"speed": rng.randf_range(0.35, 0.7),
			"phase": rng.randf() * TAU,
			"amp": rng.randf_range(0.4, 0.85),
		})

	# ninfee vagabonde che scendono a valle piano piano
	var pad_mat := _paint_mat(Color("6aa858"), Color("548c46"), 3.0, 0.55)
	for i in 3:
		var lily := Node3D.new()
		var pad := CylinderMesh.new()
		pad.top_radius = rng.randf_range(0.14, 0.2)
		pad.bottom_radius = pad.top_radius
		pad.height = 0.02
		var mi := MeshInstance3D.new()
		mi.mesh = pad
		mi.material_override = pad_mat
		lily.add_child(mi)
		add_child(lily)
		_river_pads.append({
			"node": lily,
			"z": rng.randf_range(-45.0, 45.0),
			"speed": rng.randf_range(0.42, 0.6),
			"phase": rng.randf() * TAU,
		})


func _update_river(delta: float) -> void:
	# i pesci nuotano CONTROCORRENTE (verso nord), scodinzolando
	for f in _river_fish:
		f["z"] = float(f["z"]) - float(f["speed"]) * delta
		if float(f["z"]) < -46.0:
			f["z"] = 46.0
		var z: float = f["z"]
		var node := f["node"] as MeshInstance3D
		var wob: float = sin(_t * 2.1 + float(f["phase"])) * float(f["amp"])
		node.position = Vector3(_river_x(z) + wob, RIVER_WATER_Y - 0.08, z)
		node.rotation.y = PI + cos(_t * 2.1 + float(f["phase"])) * 0.5
		node.scale.x = 1.0 + sin(_t * 6.0 + float(f["phase"])) * 0.08

	# le ninfee scivolano a valle, ruotando pigre
	for p in _river_pads:
		p["z"] = float(p["z"]) + float(p["speed"]) * delta
		if float(p["z"]) > 50.0:
			p["z"] = -50.0
		var z: float = p["z"]
		var node := p["node"] as Node3D
		node.position = Vector3(_river_x(z) + sin(z * 0.4 + float(p["phase"])) * 1.0,
				RIVER_WATER_Y + 0.02 + sin(_t * 1.3 + float(p["phase"])) * 0.012, z)
		node.rotation.y += delta * 0.12

	# il tonfo della cascata: anelli di schiuma che sbocciano di continuo
	_fall_ripple_cd -= delta
	if _fall_ripple_cd <= 0.0:
		_fall_ripple_cd = randf_range(0.35, 0.7)
		water_ripple(_fall_base + Vector3(randf_range(-0.3, 0.1), 0, randf_range(-0.7, 0.7)),
				randf_range(0.7, 1.2), RIVER_WATER_Y + 0.03)


# ---------------------------------------------------------------- stagioni
# Il mondo cambia veste col calendario. Il regista è il DayNight (chiama
# set_season a ogni cambio di stagione); qui si ridipingono manto, erba e
# chiome, e si accendono le particelle giuste — petali a primavera, foglie
# d'autunno, neve d'inverno. La primavera è il colore di nascita del mondo;
# le altre stagioni lo tirano verso l'oro, il rame e il gelo.

# le palette del prato e del bosco, una per stagione (source_color dei due
# shader gemelli ground/grass_blade — vanno tinti INSIEME o divergono)
const GRASS_PAL := [
	{  # 0 primavera — il verde tenero di sempre (la tarda primavera attuale)
		"ga": Color(0.55, 0.74, 0.43), "gb": Color(0.36, 0.57, 0.33), "gc": Color(0.70, 0.84, 0.47),
		"clover": Color(0.33, 0.56, 0.33), "daisy": Color(0.97, 0.95, 0.89),
		"fa": Color(0.30, 0.43, 0.27), "fb": Color(0.22, 0.33, 0.20), "fl": Color(0.45, 0.37, 0.24),
		"tw": Color(0.74, 0.86, 0.42), "tc": Color(0.44, 0.72, 0.52),
	},
	{  # 1 estate — verde profondo e rigoglioso
		"ga": Color(0.45, 0.68, 0.34), "gb": Color(0.29, 0.50, 0.26), "gc": Color(0.60, 0.79, 0.38),
		"clover": Color(0.28, 0.50, 0.29), "daisy": Color(0.98, 0.96, 0.90),
		"fa": Color(0.26, 0.40, 0.24), "fb": Color(0.18, 0.30, 0.18), "fl": Color(0.42, 0.35, 0.22),
		"tw": Color(0.70, 0.84, 0.38), "tc": Color(0.40, 0.70, 0.50),
	},
	{  # 2 autunno — oro, paglia e rame; il prato che ingiallisce
		"ga": Color(0.72, 0.62, 0.33), "gb": Color(0.52, 0.45, 0.25), "gc": Color(0.83, 0.72, 0.40),
		"clover": Color(0.55, 0.48, 0.26), "daisy": Color(0.92, 0.86, 0.72),
		"fa": Color(0.52, 0.44, 0.24), "fb": Color(0.38, 0.30, 0.18), "fl": Color(0.60, 0.42, 0.22),
		"tw": Color(0.86, 0.68, 0.34), "tc": Color(0.66, 0.56, 0.34),
	},
	{  # 3 inverno — erba dormiente grigio-salvia (per lo più sotto la neve)
		"ga": Color(0.55, 0.58, 0.47), "gb": Color(0.42, 0.46, 0.38), "gc": Color(0.63, 0.65, 0.53),
		"clover": Color(0.46, 0.50, 0.42), "daisy": Color(0.88, 0.90, 0.92),
		"fa": Color(0.44, 0.47, 0.40), "fb": Color(0.33, 0.36, 0.31), "fl": Color(0.50, 0.45, 0.38),
		"tw": Color(0.66, 0.68, 0.58), "tc": Color(0.54, 0.60, 0.56),
	},
]


func _register_leaf(mat: ShaderMaterial, a: Color, b: Color, klass: String) -> void:
	_leaf_mats.append({"mat": mat, "a": a, "b": b, "klass": klass})


# il colore-bersaglio di una chioma, data la sua tinta di primavera e la
# stagione. Il valore (luminosità) si conserva quasi sempre: così i tre
# strati scuro/medio/chiaro della nuvola restano leggibili anche d'autunno
func _leaf_target(c: Color, klass: String, season: int) -> Color:
	match season:
		0:  # primavera: il colore di nascita
			return c
		1:  # estate: verdi più profondi e ricchi (il ciliegio rinverdisce)
			if klass == "cherry":
				return Color.from_hsv(0.28, 0.52, clampf(c.v * 0.9, 0.22, 0.95))
			if klass == "needle":
				return Color.from_hsv(c.h, minf(c.s * 1.06, 1.0), c.v * 0.96)
			return Color.from_hsv(c.h, minf(c.s * 1.12, 1.0), c.v * 0.93)
		2:  # autunno: oro, rame, cremisi — ma le conifere restano verdi
			if klass == "needle":
				return Color.from_hsv(fposmod(c.h - 0.01, 1.0), c.s * 0.95, c.v * 0.97)
			if klass == "cherry":
				return Color.from_hsv(lerpf(0.98, 0.07, clampf(c.v, 0.0, 1.0)), 0.55,
						clampf(c.v * 0.95 + 0.05, 0.0, 1.0))
			return Color.from_hsv(lerpf(0.03, 0.10, clampf(c.v, 0.0, 1.0)), 0.72,
					clampf(c.v * 1.02 + 0.05, 0.0, 1.0))
		_:  # inverno: brina e dormienza (la neve globale imbianca il resto)
			if klass == "needle":
				return Color.from_hsv(fposmod(c.h + 0.01, 1.0), c.s * 0.9, c.v * 0.82)
			return Color.from_hsv(0.09, 0.14, clampf(c.v * 0.72 + 0.14, 0.0, 1.0))


## Il regista chiama qui a ogni cambio di stagione (0..3). `snow` è la neve
## di oggi, `transition` sfuma il cambio con un tween invece dello scatto.
func set_season(season: int, snow: float, transition: bool) -> void:
	_season = season
	_season_snow = snow
	_apply_season(transition)
	# le particelle della stagione
	for p in _petal_fx:
		p.emitting = season == 0                      # petali: solo primavera
	if _forest_leaf_fx:
		_forest_leaf_fx.emitting = season == 2        # foglie nel bosco: autunno
		if season == 2 and _forest_leaf_mat:
			_forest_leaf_mat.albedo_texture = _soft_circle(Color("d98a3a", 0.95), 0.55)
	if _meadow_leaf_fx:
		_meadow_leaf_fx.emitting = season == 2        # foglie sul prato: autunno
	if _snow_fx:
		_snow_fx.emitting = snow > 0.03               # neve: dall'accumulo in poi
	for f in _flower_fields:
		if is_instance_valid(f):
			f.visible = season != 3                   # i fiori spariscono sotto la neve
	_refresh_critters()


# ridipinge manto, erba e tutte le chiome verso la palette della stagione.
# Al primo giro (senza transizione) imposta secco; ai cambi runtime sfuma.
func _apply_season(transition: bool) -> void:
	var pal: Dictionary = GRASS_PAL[clampi(_season, 0, 3)]
	# [materiale, nome_uniform, colore_bersaglio]
	var targets: Array = []
	if _ground_mat:
		targets.append([_ground_mat, "grass_a", pal["ga"]])
		targets.append([_ground_mat, "grass_b", pal["gb"]])
		targets.append([_ground_mat, "grass_c", pal["gc"]])
		targets.append([_ground_mat, "clover_color", pal["clover"]])
		targets.append([_ground_mat, "daisy_color", pal["daisy"]])
		targets.append([_ground_mat, "forest_a", pal["fa"]])
		targets.append([_ground_mat, "forest_b", pal["fb"]])
		targets.append([_ground_mat, "forest_litter", pal["fl"]])
	if _grass_mat:
		targets.append([_grass_mat, "grass_a", pal["ga"]])
		targets.append([_grass_mat, "grass_b", pal["gb"]])
		targets.append([_grass_mat, "grass_c", pal["gc"]])
		targets.append([_grass_mat, "tint_warm", pal["tw"]])
		targets.append([_grass_mat, "tint_cool", pal["tc"]])
	for e in _leaf_mats:
		var mat: ShaderMaterial = e["mat"]
		targets.append([mat, "color_a", _leaf_target(e["a"], e["klass"], _season)])
		targets.append([mat, "color_b", _leaf_target(e["b"], e["klass"], _season)])

	if not transition:
		for t in targets:
			(t[0] as ShaderMaterial).set_shader_parameter(t[1], t[2])
		return

	# transizione: si cattura il colore attuale e si sfuma al bersaglio in
	# un solo tween (un mattino d'autunno il mondo si accende un po' alla volta)
	var froms: Array = []
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


func _init_season() -> void:
	var dn := get_node_or_null("../DayNight")
	if dn and dn.has_method("get_season"):
		set_season(int(dn.get_season()), float(dn.snow_amount()), false)
	else:
		set_season(0, 0.0, false)


# le due nevicate/fogliate che seguono il giocatore (come la pioggia del
# Weather): sempre attorno alla camera, accese dalla stagione giusta
func _build_season_fx() -> void:
	_snow_fx = _drift_emitter(_soft_circle(Color(0.98, 0.99, 1.0, 0.95), 0.5),
			280, 0.06, Vector3(13.0, 0.4, 13.0), Vector3(0.12, -0.7, 0.06), 6.5, true)
	_snow_fx.position = Vector3(0, 8.0, 0)
	add_child(_snow_fx)
	_meadow_leaf_fx = _drift_emitter(_soft_circle(Color("d98a3a", 0.95), 0.55),
			44, 0.09, Vector3(13.0, 0.4, 12.0), Vector3(0.25, -0.5, 0.1), 8.0, false)
	_meadow_leaf_fx.position = Vector3(0, 4.5, 0)
	add_child(_meadow_leaf_fx)


# fabbrica di emettitori "che scendono dal cielo": neve o foglie
func _drift_emitter(tex: Texture2D, count: int, sz: float, box: Vector3,
		grav: Vector3, life: float, spin_slow: bool) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(sz, sz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.55
	pm.gravity = grav
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7 if spin_slow else 0.4
	pm.turbulence_noise_speed = Vector3(0.25, 0.15, 0.25)
	pm.scale_min = 0.6
	pm.scale_max = 1.25
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -40.0 if spin_slow else -140.0
	pm.angular_velocity_max = 40.0 if spin_slow else 140.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.88, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var fx := GPUParticles3D.new()
	fx.amount = count
	fx.lifetime = life
	fx.preprocess = life * 0.7
	fx.local_coords = false
	fx.emitting = false
	fx.process_material = pm
	fx.draw_pass_1 = quad
	fx.visibility_aabb = AABB(Vector3(-16, -12, -16), Vector3(32, 18, 32))
	return fx


# ---------------------------------------------------------------- vita

func _process(delta: float) -> void:
	_t += delta

	# l'erba sa dove cammina Mochi: i fili si scostano al suo passaggio
	if _player_ref == null:
		_player_ref = get_node_or_null("%Player") as Node3D
	if _player_ref:
		RenderingServer.global_shader_parameter_set("mochi_pos", _player_ref.global_position)
		# neve e foglie seguono la camera, come la pioggia: sempre attorno a te
		if _snow_fx and _snow_fx.emitting:
			_snow_fx.position = _player_ref.global_position + Vector3(0, 8.0, 0)
		if _meadow_leaf_fx and _meadow_leaf_fx.emitting:
			_meadow_leaf_fx.position = _player_ref.global_position + Vector3(0, 4.5, 0)

	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += _cloud_speeds[i] * delta
		if c.position.x > 60.0:
			c.position.x = -60.0

	# il falò respira
	if _campfire_light:
		_campfire_light.light_energy = 1.25 + sin(_t * 11.0) * 0.15 + sin(_t * 27.3) * 0.08

	# la nebbiolina scivola tra i tronchi
	for i in _mists.size():
		var m := _mists[i]
		m.position.x += _mist_speeds[i] * delta
		if m.position.x > 24.0:
			m.position.x = -24.0

	# le ninfee respirano sull'acqua
	for i in _lilies.size():
		_lilies[i].position.y = 0.075 + sin(_t * 1.1 + float(i) * 1.7) * 0.008
		_lilies[i].rotation.y += delta * 0.03

	_update_frogs(delta)
	_update_river(delta)

	# il prato si ripopola di farfalle dopo una cattura (mai di notte né
	# d'inverno: le nuove nascerebbero visibili violando set_night/stagione)
	if _butterflies.size() < 5 and not _night and _season != 3:
		_bf_respawn -= delta
		if _bf_respawn <= 0.0:
			_bf_respawn = randf_range(45.0, 90.0)
			_make_butterfly(randi() % 3)

	# e il bosco di funghi da raccogliere
	if _pickups.size() < 5:
		_pickup_respawn -= delta
		if _pickup_respawn <= 0.0:
			_pickup_respawn = randf_range(50.0, 100.0)
			_spawn_pickup_mushroom()

	for b in _butterflies:
		var s: float = b["seed"]
		var t := _t * 0.55 + s
		var pos := Vector3(
			sin(t * 0.8 + s) * 8.0 + cos(t * 0.29) * 4.0,
			0.9 + sin(t * 1.6) * 0.35 + sin(t * 5.0) * 0.06,
			cos(t * 0.62 + s * 2.0) * 8.0
		)
		var node: Node3D = b["node"]
		var vel: Vector3 = pos - b["prev"]
		b["prev"] = pos
		node.position = pos
		if vel.length() > 0.0001:
			var target := atan2(-vel.x, -vel.z)
			node.rotation.y = lerp_angle(node.rotation.y, target, 1.0 - exp(-6.0 * delta))
		var flap := sin(_t * 17.0 + s) * 0.85
		(b["wing_l"] as Node3D).rotation.z = flap
		(b["wing_r"] as Node3D).rotation.z = -flap
