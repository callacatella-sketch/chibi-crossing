extends SceneTree
## IL PROVINO DEI FIORI E DELLE FARFALLE. Mancava, ed è la ragione per cui
## nessuno si era accorto che da vicino sono cartoncini: il catalogo
## fotografa i PEZZI COSTRUIBILI, non quello che cresce nel prato.
##
##   CHIBI_FIORI=/dove/salvare Godot --path . \
##       --script res://tools/provino_fiori.gd
##
## LE DUE DISTANZE CHE CONTANO, e vanno guardate tutte e due:
##  · 0.8 m — Mochi che cammina nel prato: qui si smaschera il poligono;
##  · 6 m — l'inquadratura normale del gioco: qui si smaschera il
##    coriandolo (una cosa bellissima da vicino che a sei metri sparisce
##    o diventa una macchia di colore).
## Di PROFILO, sempre: un fiore piatto si vede solo di lato.

const GEO = preload("res://scenes/world/WorldGeo.gd")

const VISTE := [
	{"file": "1-vicino.jpg", "d": 0.80, "ele": 0.30},
	{"file": "2-profilo.jpg", "d": 0.80, "ele": 0.06},
	{"file": "3-lontano.jpg", "d": 6.00, "ele": 0.35},
]
const FOV := 40.0

var _sv: SubViewport
var _cam: Camera3D


func _init() -> void:
	_go()


func _studio() -> void:
	var lato := int(OS.get_environment("CHIBI_LATO")) if OS.get_environment("CHIBI_LATO") != "" else 1100
	_sv = SubViewport.new()
	_sv.size = Vector2i(lato, int(float(lato) * 0.62))
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.80, 0.86, 0.83)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.90, 0.95)
	e.ambient_light_energy = 0.9
	env.environment = e
	_sv.add_child(env)
	# il sole BASSO e da dietro: è il controluce che dice se un petalo ha
	# spessore o è un cartoncino
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-26, 152, 0)
	sole.light_energy = 1.15
	sole.shadow_enabled = true
	_sv.add_child(sole)
	var riempi := DirectionalLight3D.new()
	riempi.rotation_degrees = Vector3(-48, -30, 0)
	riempi.light_energy = 0.45
	_sv.add_child(riempi)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	suolo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.44, 0.60, 0.36)
	sm.roughness = 1.0
	suolo.material_override = sm
	_sv.add_child(suolo)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.current = true
	_sv.add_child(_cam)


## Le mesh dei fiori che il prato usa davvero. Se una manca, il provino lo
## DICE invece di saltarla in silenzio: un banco che tace su quello che non
## ha trovato è un banco che mente.
func _fiori() -> Array:
	var out: Array = []
	for voce in [
			["margherita", "daisy_mesh", [Color("fffaf4"), Color("ffcf5e")]],
			["margherita rosa", "daisy_mesh", [Color("ffc4d6"), Color("ffd76e")]],
			["tulipano", "tulip_mesh", [Color("ffb35c")]],
			["lavanda", "lavender_mesh", []]]:
		var nome: String = voce[0]
		var fn: String = voce[1]
		# WorldGeo e' una libreria di funzioni STATIC: has_method/callv
		# vogliono un'istanza, quindi si chiede allo script
		var libreria = GEO.new()
		if not libreria.has_method(fn):
			print("!! WorldGeo non ha %s: il prato e' cambiato sotto il banco" % fn)
			continue
		var m: Mesh = libreria.callv(fn, voce[2])
		out.append([nome, m])
	return out


## LA MACCHIA: tante istanze come le semina il prato. È la vista in cui
## «si smaschera il coriandolo» — una cosa bellissima da vicino che a sei
## metri diventa una spruzzata di confetti — e l'unica che dice se il
## prato è diventato un prato o solo un prato più caro.
func _macchia(fiori: Array, quanti: int, raggio: float) -> Node3D:
	var radice := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260830
	for i in quanti:
		var f: Array = fiori[rng.randi() % fiori.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = f[1]
		var a := rng.randf() * TAU
		var r := raggio * sqrt(rng.randf())
		# la stessa posa del prato: scala tirata verso il piccolo e
		# inclinazione correlata alla taglia (i grandi pendono di più)
		var sc := 0.72 + 0.53 * pow(rng.randf(), 1.6)
		var pend := rng.randf_range(-0.28, 0.28) * sc
		mi.transform = Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU)
				* Basis(Vector3(cos(a), 0, sin(a)), pend)
				* Basis.IDENTITY.scaled(Vector3.ONE * sc),
				Vector3(cos(a) * r, -0.012, sin(a) * r))
		radice.add_child(mi)
	return radice


func _scatta(dove: String, mira: Vector3, d: float, ele: float,
		az := 0.0) -> void:
	_cam.position = mira + Vector3(sin(az), ele, cos(az)).normalized() * d
	_cam.look_at(mira, Vector3.UP)
	for _k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_sv.get_texture().get_image().save_jpg(dove, 0.93)


func _go() -> void:
	await process_frame
	_studio()
	var dove := OS.get_environment("CHIBI_FIORI")
	if dove == "":
		dove = "docs/catalogo/provini-fiori"
	DirAccess.make_dir_recursive_absolute(dove)
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "FDM"
	var fiori := _fiori()
	for i in fiori.size():
		var m := fiori[i][1] as Mesh
		var tri := 0
		var sup := m.get_surface_count()
		for si in sup:
			var arr := m.surface_get_arrays(si)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tri += (idx.size() / 3) if idx.size() > 0 else (vtx.size() / 3)
		var aabb := m.get_aabb()
		print("FIORE %-18s %4d tris · %d superfici · alto %.3f · largo %.3f"
				% [fiori[i][0], tri, sup, aabb.size.y, aabb.size.x])

	# --- LA FILA: tutti insieme, per confrontarne le taglie
	if "F" in parti:
		var fila := Node3D.new()
		_sv.add_child(fila)
		var passo := 0.30
		for i in fiori.size():
			var mi := MeshInstance3D.new()
			mi.mesh = fiori[i][1]
			mi.position = Vector3(-passo * float(fiori.size() - 1) * 0.5
					+ passo * float(i), 0, 0)
			fila.add_child(mi)
		await process_frame
		for v in VISTE:
			await _scatta(dove + "/" + str(v["file"]), Vector3(0, 0.10, 0),
					float(v["d"]), float(v["ele"]))
		_sv.remove_child(fila)
		fila.free()

	# --- IL DETTAGLIO: uno per volta, da QUATTRO azimut. È qui che si
	# smascherano i trucchi — «verifica anche di profilo e di tre quarti,
	# non solo frontale»
	if "D" in parti:
		for f in fiori:
			var nome := str(f[0]).replace(" ", "-")
			var cart := dove + "/" + nome
			DirAccess.make_dir_recursive_absolute(cart)
			var mi := MeshInstance3D.new()
			mi.mesh = f[1]
			_sv.add_child(mi)
			await process_frame
			var a := (f[1] as Mesh).get_aabb()
			var mira := Vector3(0, a.position.y + a.size.y * 0.72, 0)
			var d: float = maxf(a.size.y, 0.12) * 1.35
			for vv in [["1-fronte.jpg", 0.0, 0.18], ["2-trequarti.jpg", 0.9, 0.22],
					["3-profilo.jpg", 1.5708, 0.10], ["4-alto.jpg", 0.5, 0.95]]:
				await _scatta(cart + "/" + str(vv[0]), mira, d,
						float(vv[2]), float(vv[1]))
			_sv.remove_child(mi)
			mi.free()

	# --- LA MACCHIA: 120 istanze, a sei metri e a dodici
	if "M" in parti:
		var macchia := _macchia(fiori, 120, 1.9)
		_sv.add_child(macchia)
		await process_frame
		await _scatta(dove + "/5-macchia-6m.jpg", Vector3(0, 0.12, 0), 6.0, 0.34)
		await _scatta(dove + "/6-macchia-12m.jpg", Vector3(0, 0.12, 0), 12.0, 0.30)
		await _scatta(dove + "/7-macchia-occhio.jpg", Vector3(0, 0.12, 0), 2.4, 0.10)
		_sv.remove_child(macchia)
		macchia.free()

	print("FATTO -> ", dove)
	quit()
