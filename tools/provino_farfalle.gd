extends SceneTree
## IL PROVINO DELLE FARFALLE. Mancava, e le farfalle sono la cosa che nel
## villaggio ti passa più vicino: si posano sul naso di Mochi.
##
##   CHIBI_FARF=/dove/salvare Godot --path . --resolution 1100x680 \
##       --script res://tools/provino_farfalle.gd
##
## Tre parti (CHIBI_PARTI=SBM):
##  S — la SAGOMA: il rig nominato da quattro azimut, e da SOTTO (è da
##      lì che la vede Mochi quando gliela si posa sul muso);
##  B — la PELLICOLA DEL BATTITO: otto istanti in fila, e nella riga
##      accanto lo stesso battito fatto col `sin()` puro di prima. La
##      pausa in cima o si vede in questa lastra, o non c'è;
##  M — le NOVANTA del MultiMesh, con lo shader VERO, a due metri e a
##      sei. È l'unica parte in cui si guarda quello che il vertex
##      shader fa davvero — la mesh da sola non lo dice.

const FARF = preload("res://scenes/world/FarfalleGeo.gd")
const GEO = preload("res://scenes/world/WorldGeo.gd")
const CRIT = preload("res://scenes/world/Critters.gd")
const SHADER = preload("res://shaders/butterfly.gdshader")

const FOV := 34.0

var _sv: SubViewport
var _cam: Camera3D


func _init() -> void:
	_go()


func _studio() -> void:
	var lato := 1100
	if OS.get_environment("CHIBI_LATO") != "":
		lato = int(OS.get_environment("CHIBI_LATO"))
	_sv = SubViewport.new()
	_sv.size = Vector2i(lato, int(float(lato) * 0.60))
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.84, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.84, 0.88, 0.94)
	e.ambient_light_energy = 0.85
	env.environment = e
	_sv.add_child(env)
	# il sole basso e da dietro: su un'ala è il controluce a dire se è
	# una membrana o un cartoncino
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-24, 158, 0)
	sole.light_energy = 1.25
	sole.shadow_enabled = true
	_sv.add_child(sole)
	var riempi := DirectionalLight3D.new()
	riempi.rotation_degrees = Vector3(-50, -34, 0)
	riempi.light_energy = 0.42
	_sv.add_child(riempi)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	suolo.mesh = pm
	suolo.position.y = -0.45
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.46, 0.60, 0.38)
	sm.roughness = 1.0
	suolo.material_override = sm
	_sv.add_child(suolo)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.current = true
	_sv.add_child(_cam)


## IL RIG NOMINATO, montato come lo monta `CozyWorld._make_butterfly`:
## corpo + due perni che ruotano su Z. Torna {nodo, sx, dx}.
func _rig(kind: String, apertura: float, corda: float) -> Dictionary:
	var b := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = FARF.corpo(corda * 0.72)
	body.material_override = GEO.paint_mat(Color("6a5a4a"), Color("4a3e33"), 8.0, 0.4)
	b.add_child(body)
	var col: Color = CRIT.colore(kind)
	var mat := GEO.paint_mat(col, col.darkened(0.42), 26.0, 0.58, 0.0, false, 0.50)
	var perni: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var p := Node3D.new()
		b.add_child(p)
		var mi := MeshInstance3D.new()
		mi.mesh = FARF.ali_lato(side, apertura, corda)
		mi.material_override = mat
		p.add_child(mi)
		perni.append(p)
	return {"nodo": b, "sx": perni[0], "dx": perni[1]}


func _batti(r: Dictionary, ampiezza: float) -> void:
	(r["sx"] as Node3D).rotation.z = ampiezza
	(r["dx"] as Node3D).rotation.z = -ampiezza


func _scatta(dove: String, mira: Vector3, d: float, ele: float,
		az := 0.0) -> void:
	_cam.position = mira + Vector3(sin(az), ele, cos(az)).normalized() * d
	_cam.look_at(mira, Vector3.UP)
	for _k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_sv.get_texture().get_image().save_jpg(dove, 0.93)


func _conta(m: Mesh) -> int:
	var tri := 0
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		tri += (idx.size() / 3) if idx.size() > 0 else (vtx.size() / 3)
	return tri


func _go() -> void:
	await process_frame
	_studio()
	var dove := OS.get_environment("CHIBI_FARF")
	if dove == "":
		dove = "docs/catalogo/provini-farfalle"
	DirAccess.make_dir_recursive_absolute(dove)
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "SBM"

	var piatta: Mesh = FARF.piatta(0.105, 0.076)
	var ala: Mesh = FARF.ali_lato(1.0, 0.129, 0.084)
	var corpo: Mesh = FARF.corpo(0.0605)
	print("FARFALLA piatta (le 90)   %4d tris · %d superfici"
			% [_conta(piatta), piatta.get_surface_count()])
	print("FARFALLA rig  (le 5)      %4d tris (%d ala x2 + %d corpo)"
			% [_conta(ala) * 2 + _conta(corpo), _conta(ala), _conta(corpo)])
	var ab := piatta.get_aabb()
	print("   apertura %.3f m · corda %.3f m" % [ab.size.x, ab.size.z])

	# --- S: LA SAGOMA
	if "S" in parti:
		var r := _rig("rosa", 0.129, 0.084)
		_sv.add_child(r["nodo"])
		_batti(r, 0.18)
		await process_frame
		for v in [["1-alto.jpg", 0.0, 1.05], ["2-trequarti.jpg", 0.8, 0.30],
				["3-profilo.jpg", 1.5708, 0.08], ["4-davanti.jpg", 0.0, 0.10],
				["5-da-sotto.jpg", 0.2, -0.55]]:
			await _scatta(dove + "/" + str(v[0]), Vector3.ZERO, 0.19,
					float(v[2]), float(v[1]))
		_sv.remove_child(r["nodo"])
		(r["nodo"] as Node3D).free()

	# --- B: LA PELLICOLA DEL BATTITO, e la controprova col sin() puro
	if "B" in parti:
		var fila := Node3D.new()
		_sv.add_child(fila)
		var passo := 0.165
		var istanti := 8
		for i in istanti:
			var theta := TAU * float(i) / float(istanti)
			for riga in 2:
				var r := _rig("rosa" if riga == 0 else "azzurra", 0.129, 0.084)
				var n := r["nodo"] as Node3D
				n.position = Vector3(
						(float(i) - float(istanti - 1) * 0.5) * passo,
						0.11 if riga == 0 else -0.11, 0.0)
				fila.add_child(n)
				# riga 0: la legge VERA (fronti ripidi, colmo piatto)
				# riga 1: il `sin()` puro di prima, per confronto
				var s := absf(FARF.battito(theta)) if riga == 0 \
						else absf(sin(theta))
				_batti(r, s * 0.95)
		await process_frame
		await _scatta(dove + "/6-battito.jpg", Vector3(0, 0, 0), 0.80, 0.16)
		await _scatta(dove + "/7-battito-profilo.jpg", Vector3(0, 0, 0), 0.80,
				0.16, 1.35)
		_sv.remove_child(fila)
		fila.free()

	# --- M: LE NOVANTA, con lo shader VERO
	if "M" in parti:
		var mm := MultiMeshInstance3D.new()
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_custom_data = true
		var mesh2: ArrayMesh = FARF.piatta(0.105, 0.076)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("raggio_torace", FARF.raggio_torace(0.105))
		mesh2.surface_set_material(0, mat)
		m.mesh = mesh2
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		m.instance_count = 14
		for i in 14:
			var a := rng.randf() * TAU
			var rr := 0.55 * sqrt(rng.randf())
			m.set_instance_transform(i, Transform3D(
					Basis(Vector3.UP, rng.randf() * TAU),
					Vector3(cos(a) * rr, rng.randf_range(-0.12, 0.15),
							sin(a) * rr)))
			# sfasamento COSTANTE, specie, velocità: il contratto dello shader
			m.set_instance_custom_data(i, Color(rng.randf(),
					float(rng.randi() % 3), 1.0, 0.0))
		mm.multimesh = m
		_sv.add_child(mm)
		await process_frame
		await _scatta(dove + "/8-novanta-1m.jpg", Vector3.ZERO, 1.0, 0.22)
		await _scatta(dove + "/9-novanta-3m.jpg", Vector3.ZERO, 3.0, 0.26)
		_sv.remove_child(mm)
		mm.free()

	print("FATTO -> ", dove)
	quit()
