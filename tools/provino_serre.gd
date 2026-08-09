extends SceneTree
## IL PROVINO DELLE SERRE FUSE: la Vetreria in tutte le sue forme, nello
## studio del catalogo. Serve a GUARDARE — la suite verde non dice niente
## sulla resa, e qui la resa È la feature.
##
##   CHIBI_SERRE=/dove/salvare Godot --path . \
##       --script res://tools/provino_serre.gd
##
## Facoltativi: CHIBI_LATO (lato immagine, default 1000), CHIBI_FORME
## (elenco separato da virgole, per rifare una forma sola).

const CAT = preload("res://scenes/build/BuildCatalog.gd")

## Le forme che un giocatore costruisce davvero, più le due che rompono
## le regole ingenue: la L (angolo concavo) e la diagonale (il pizzico).
const FORME := {
	"1-sola": [Vector2i(0, 0)],
	"2-in-fila": [Vector2i(0, 0), Vector2i(1, 0)],
	"2-di-traverso": [Vector2i(0, 0), Vector2i(0, 1)],
	"3-in-fila": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"3-a-elle": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	"4-quadrato": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"5-croce": [Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0),
			Vector2i(1, 2)],
	"9-palmeria": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	"2-in-diagonale": [Vector2i(0, 0), Vector2i(1, 1)],
}

## Le viste. Di profilo si smascherano i trucchi; dall'alto si vede se il
## tetto è un edificio solo o N tetti appoggiati.
const VISTE := [
	{"file": "1-fronte.jpg", "az": 0.0, "ele": 0.42},
	{"file": "2-tre-quarti.jpg", "az": 0.785398, "ele": 0.42},
	{"file": "3-profilo.jpg", "az": 1.570796, "ele": 0.42},
	{"file": "4-alto.jpg", "az": 0.785398, "ele": 1.15},
	{"file": "5-occhio.jpg", "az": 0.35, "ele": 0.10},
]
const FOV := 34.0

var _sv: SubViewport
var _cam: Camera3D


func _init() -> void:
	_go()


func _studio() -> void:
	var lato := int(OS.get_environment("CHIBI_LATO")) if OS.get_environment("CHIBI_LATO") != "" else 1000
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


## L'edificio: una campata per cella, ognuna al posto della sua cella —
## esattamente come le posa BuildSystem.
func _edificio(celle: Array) -> Node3D:
	var radice := Node3D.new()
	var pianta := CAT.serra_pianta(celle)
	for c: Vector2i in celle:
		var campata: Node3D = CAT.serra_cella(pianta, c)
		campata.position = Vector3(float(c.x), 0.0, float(c.y))
		radice.add_child(campata)
	return radice


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


func _conta_mesh(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		c += 1
	for f in n.get_children():
		c += _conta_mesh(f)
	return c


func _go() -> void:
	await process_frame
	_studio()
	var dove := OS.get_environment("CHIBI_SERRE")
	if dove == "":
		dove = "docs/catalogo/provini-serre"
	var scelte := OS.get_environment("CHIBI_FORME")
	for nome: String in FORME:
		if scelte != "" and not (nome in scelte.split(",")):
			continue
		var cartella: String = dove + "/" + nome
		DirAccess.make_dir_recursive_absolute(cartella)
		var edificio: Node3D = _edificio(FORME[nome])
		_sv.add_child(edificio)
		await process_frame
		var tutti := _mesh_aabb(edificio, edificio)
		var box := AABB()
		if not tutti.is_empty():
			box = tutti[0]
			for k in range(1, tutti.size()):
				box = box.merge(tutti[k])
		var mesh: int = _conta_mesh(edificio)
		var celle: int = (FORME[nome] as Array).size()
		print("FORMA %-16s %d celle · %d mesh (%.1f per campata) · %.2f x %.2f x %.2f"
				% [nome, celle, mesh, float(mesh) / float(celle),
						box.size.x, box.size.y, box.size.z])
		for v in VISTE:
			await _scatta(box, float(v["az"]), float(v["ele"]),
					cartella + "/" + str(v["file"]))
		_sv.remove_child(edificio)
		edificio.free()
	print("FATTO -> ", dove)
	quit()
