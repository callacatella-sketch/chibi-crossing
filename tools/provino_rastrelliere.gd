extends SceneTree
## IL PROVINO DELLE RASTRELLIERE IN FILA: una sola, due, e la fila mista
## delle tre varianti. Serve a GUARDARE se la fila si legge come UN mobile
## — il montante condiviso uno solo, le tavole che si toccano, le testate
## finite solo ai due capi.
##
##   CHIBI_RAST=/dove/salvare Godot --path . \
##       --script res://tools/provino_rastrelliere.gd

const PAL = preload("res://scenes/build/BuildPalestra.gd")

## Le file da provare: elenco di varianti, una per campata.
const FILE := {
	"1-sola": ["manubri"],
	"2-in-fila": ["manubri", "dischi"],
	"3-mista": ["manubri", "dischi", "pietre"],
	"4-lunga": ["dischi", "manubri", "pietre", "manubri"],
}

const VISTE := [
	{"file": "1-fronte.jpg", "az": 0.0, "ele": 0.30},
	{"file": "2-tre-quarti.jpg", "az": 0.70, "ele": 0.38},
	{"file": "3-profilo.jpg", "az": 1.570796, "ele": 0.30},
	{"file": "4-occhio.jpg", "az": 0.25, "ele": 0.10},
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


## La fila: una campata per cella, ognuna che sa se di fianco continua —
## esattamente come le ricostruisce BuildSystem.
func _fila(varianti: Array) -> Node3D:
	var radice := Node3D.new()
	for i in varianti.size():
		var campata: Node3D = PAL.rastrelliera_cella(
				{"sx": i > 0, "dx": i < varianti.size() - 1},
				str(varianti[i]), 7 + i * 13)
		campata.position = Vector3(float(i), 0.0, 0.0)
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
	var dove := OS.get_environment("CHIBI_RAST")
	if dove == "":
		dove = "docs/catalogo/provini-rastrelliere"
	for nome: String in FILE:
		var cartella: String = dove + "/" + nome
		DirAccess.make_dir_recursive_absolute(cartella)
		var varianti: Array = FILE[nome]
		var fila: Node3D = _fila(varianti)
		_sv.add_child(fila)
		await process_frame
		var tutti := _mesh_aabb(fila, fila)
		var box := AABB()
		if not tutti.is_empty():
			box = tutti[0]
			for k in range(1, tutti.size()):
				box = box.merge(tutti[k])
		print("FILA %-12s %d campate · %d mesh · %.2f x %.2f x %.2f"
				% [nome, varianti.size(), _conta_mesh(fila),
						box.size.x, box.size.y, box.size.z])
		for v in VISTE:
			await _scatta(box, float(v["az"]), float(v["ele"]),
					cartella + "/" + str(v["file"]))
		_sv.remove_child(fila)
		fila.free()
	print("FATTO -> ", dove)
	quit()
