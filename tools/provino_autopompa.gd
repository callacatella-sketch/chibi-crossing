extends SceneTree
## IL PROVINO DELL'AUTOPOMPA: renderizza il pezzo da sei angoli nello
## stesso studio del catalogo (stessa luce, stesso calcolo d'inquadratura
## sugli otto spigoli). Serve a GUARDARE mentre si modella: la suite
## verde non dice niente sulla resa.
##
##   CHIBI_PROVINO=/dove/salvare Godot --path . \
##       --script res://tools/provino_autopompa.gd
##
## Facoltativo: CHIBI_LATO (lato immagine, default 900).

const CAT = preload("res://scenes/build/BuildCatalog.gd")

## Angoli RELATIVI AL CAMION: il muso guarda -X, quindi il muso pieno
## sta ad azimut -90° (camera a -X), non a 0 come i pezzi che guardano -Z.
const VISTE := [
	{"file": "1-muso.jpg", "az": -1.570796, "ele": 0.42},
	{"file": "2-tre-quarti.jpg", "az": -0.785398, "ele": 0.42},
	{"file": "3-profilo.jpg", "az": 0.0, "ele": 0.42},
	{"file": "4-tre-quarti-retro.jpg", "az": 0.785398, "ele": 0.42},
	{"file": "5-retro.jpg", "az": 1.570796, "ele": 0.42},
	{"file": "6-alto.jpg", "az": -0.785398, "ele": 1.1},
]
const FOV := 34.0

var _sv: SubViewport
var _cam: Camera3D


func _init() -> void:
	_go()


func _studio() -> void:
	var lato := int(OS.get_environment("CHIBI_LATO")) if OS.get_environment("CHIBI_LATO") != "" else 900
	_sv = SubViewport.new()
	_sv.size = Vector2i(lato, lato)
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.885, 0.895, 0.90)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.88, 0.93)
	e.ambient_light_energy = 0.85
	env.environment = e
	_sv.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-42, -38, 0)
	sole.light_energy = 0.85
	sole.shadow_enabled = true
	_sv.add_child(sole)
	var contro := DirectionalLight3D.new()
	contro.rotation_degrees = Vector3(-16, 148, 0)
	contro.light_energy = 0.22
	_sv.add_child(contro)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	suolo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.74, 0.755, 0.735)
	sm.roughness = 0.96
	suolo.material_override = sm
	_sv.add_child(suolo)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.current = true
	_sv.add_child(_cam)


func _mesh_aabb(n: Node, radice: Node3D) -> Array:
	var out: Array = []
	if n is Node3D and not (n as Node3D).visible:
		return out
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var tr := Transform3D.IDENTITY
		var cur := n as Node3D
		while cur != null and cur != radice:
			tr = cur.transform * tr
			cur = cur.get_parent() as Node3D
		out.append(tr * (n as MeshInstance3D).mesh.get_aabb())
	for f in n.get_children():
		out.append_array(_mesh_aabb(f, radice))
	return out


func _scatta(a: AABB, az: float, ele: float, dove: String) -> void:
	var centro := a.position + a.size * 0.5
	var dir := Vector3(sin(az), ele, -cos(az)).normalized()
	var t := tan(deg_to_rad(FOV * 0.5))
	var dist := maxf(a.size.length(), 0.2)
	var pos := centro + dir * dist
	var fwd := (centro - pos).normalized()
	var destra := fwd.cross(Vector3.UP).normalized()
	var su := destra.cross(fwd).normalized()
	var arretra := 0.0
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var ang := a.position + Vector3(a.size.x * float(ix),
						a.size.y * float(iy), a.size.z * float(iz))
				var v := ang - pos
				var scarto: float = maxf(absf(v.dot(destra)), absf(v.dot(su)))
				arretra = maxf(arretra, scarto / t - v.dot(fwd))
	dist = (dist + arretra) * 1.06
	_cam.position = centro + dir * dist
	_cam.look_at(centro, Vector3.UP)
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_sv.get_texture().get_image().save_jpg(dove, 0.92)


func _go() -> void:
	await process_frame
	_studio()
	var dove := OS.get_environment("CHIBI_PROVINO")
	if dove == "":
		dove = "docs/catalogo/provini"
	DirAccess.make_dir_recursive_absolute(dove)
	var nodo: Node3D = CAT._autopompa()
	_sv.add_child(nodo)
	await process_frame
	var tutti := _mesh_aabb(nodo, nodo)
	var ing: AABB = tutti[0]
	for i in range(1, tutti.size()):
		ing = ing.merge(tutti[i])
	for v in VISTE:
		await _scatta(ing, float(v["az"]), float(v["ele"]),
				dove.rstrip("/") + "/" + str(v["file"]))
	print("PROVINO autopompa -> ", dove, " (", VISTE.size(), " viste)")
	quit()
