extends SceneTree
## Provino: il cesto dei saldi com'è ora e con le maniche PIEGATE.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const BOU = preload("res://scenes/build/BuildBoutique.gd")
const BUILDER = preload("res://scenes/npc/ChibiBuilder.gd")

const FOV := 34.0
const ELEV := 0.42
const VISTE := [["1-fronte", 0.0], ["2-tre-quarti", 0.785398], ["3-profilo", 1.570796]]

var _sv: SubViewport
var _cam: Camera3D


func _init() -> void:
	_go()


# ------------------------------------------------------- il cesto RIPARATO
static func cesto_fix() -> Node3D:
	var n: Node3D = BOU.cesto_saldi()
	# via i tre bastoni dritti (cilindri alti 0.30 figli diretti del cesto)
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var cm := mi.mesh as CylinderMesh
		if cm != null and is_equal_approx(cm.height, 0.30):
			n.remove_child(mi)
			mi.queue_free()
	var r_orlo := 0.362 + 0.025
	for i in 3:
		var a2 := 0.7 + float(i) * 2.1
		var m := Node3D.new()
		m.rotation.y = -a2
		n.add_child(m)
		BUILDER.tube(m, [
				Vector3(0.19, 0.40 + 0.02 * float(i), 0.0),
				Vector3(0.315, 0.372, 0.0),
				Vector3(r_orlo + 0.010, 0.320, 0.0),
				Vector3(r_orlo + 0.018, 0.205 - 0.03 * float(i), 0.0)],
				[0.030, 0.032, 0.029, 0.022], BOU._stoffa(1 + i * 3), 22, 12)
	return n


# ------------------------------------------------------------------ studio
func _mesh_aabb(nd: Node, radice: Node3D) -> Array:
	var out: Array = []
	if nd is Node3D and not (nd as Node3D).visible:
		return out
	if nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null:
		var tr := Transform3D.IDENTITY
		var cur := nd as Node3D
		while cur != null and cur != radice:
			tr = cur.transform * tr
			cur = cur.get_parent() as Node3D
		out.append(tr * (nd as MeshInstance3D).mesh.get_aabb())
	for f in nd.get_children():
		out.append_array(_mesh_aabb(f, radice))
	return out


func _ingombro(nd: Node3D) -> AABB:
	var tutti: Array = _mesh_aabb(nd, nd)
	var out: AABB = tutti[0]
	for i in range(1, tutti.size()):
		out = out.merge(tutti[i])
	return out


func _studio() -> void:
	_sv = SubViewport.new()
	_sv.size = Vector2i(900, 900)
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


func _scatta(a: AABB, az: float, dove: String) -> void:
	var centro := a.position + a.size * 0.5
	var dir := Vector3(sin(az), ELEV, -cos(az)).normalized()
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
	_sv.get_texture().get_image().save_png(dove)


func _go() -> void:
	await process_frame
	_studio()
	var fuori := OS.get_environment("CHIBI_FUORI")
	for coppia in [["ora", BOU.cesto_saldi()], ["fix", cesto_fix()]]:
		var nodo: Node3D = coppia[1]
		_sv.add_child(nodo)
		await process_frame
		var ing := _ingombro(nodo)
		print(coppia[0], "  ingombro x=%.3f z=%.3f y=%.3f" % [ing.size.x, ing.size.z, ing.size.y])
		for v in VISTE:
			await _scatta(ing, float(v[1]), fuori + "/cesto_" + str(coppia[0]) + "_" + str(v[0]) + ".png")
		_sv.remove_child(nodo)
		nodo.queue_free()
	quit()
