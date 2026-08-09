extends SceneTree
## LA RASSEGNA DELLE LUCI, tutte insieme, di NOTTE.
##
## `provino_variante.gd` rende UN pezzo per volta e va benissimo per
## tarare; ma per giudicare una dozzina di luci serve vederle tutte
## nello stesso studio e nella stessa sera — altrimenti si finisce per
## confrontare due immagini fatte con due occhi diversi.
##
## Ogni pezzo esce in UNA immagine sola con due riprese affiancate:
## a sinistra il tre quarti dall'alto (dove si legge la POZZA per
## terra, che è metà del giudizio di una luce), a destra l'occhio
## basso (dove si legge se il vetro è bruciato e quanto sale l'alone).
##
##   CHIBI_PROVINO=/dove Godot --path . --script res://tools/provino_luci.gd
##
## Facoltativi:
##   CHIBI_LUCI   elenco di nomi separati da virgola (default: tutti i
##                pezzi del catalogo che accendono una luce)
##   CHIBI_LATO   lato di UNA ripresa (default 760)
##   CHIBI_LARGO  metri di inquadratura in più (per i fasci inclinati,
##                che atterrano lontano dal pezzo)

const CAT = preload("res://scenes/build/BuildCatalog.gd")

## I pezzi del catalogo che, di notte, accendono qualcosa.
## Gli ultimi tre prendono la luce da `BuildCatalog._luce_blu()`, che è
## la loro fonte unica (tarata al buio su cinque prove): si guardano per
## controllare la SCALA del lume, non per ritoccare quei numeri.
const ACCESI := [
	"Camino", "Lampada", "Lampada semplice", "Casa albero", "Serra",
	"Lampione", "Fontana", "Gazebo", "Giostrina", "Braciere stellato",
	"Torretta", "Autopompa", "Fondale", "Lucine",
	"Vetrina moda", "Camerino", "Faretti", "Candeliere",
	"Lanterna blu", "Guardiola", "Insegna guardia",
]

const FOV := 34.0
## le due riprese: la pozza per terra e l'occhio di chi ci passa accanto
const VISTE := [
	{"az": 0.785398, "ele": 0.50},
	{"az": 0.785398, "ele": 0.09},
]

var _sv: SubViewport
var _cam: Camera3D
var _lato := 760


func _init() -> void:
	_go()


func _studio() -> void:
	_sv = SubViewport.new()
	_sv.size = Vector2i(_lato, _lato)
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)

	# LA STESSA NOTTE di provino_variante.gd: se i due studi divergono,
	# una taratura scelta qui non vale più là
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.055, 0.07, 0.115)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.38, 0.55)
	e.ambient_light_energy = 0.16
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.25
	e.glow_hdr_threshold = 0.85
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = e
	_sv.add_child(env)

	var luna := DirectionalLight3D.new()
	luna.rotation_degrees = Vector3(-28, 152, 0)
	luna.light_color = Color(0.55, 0.66, 0.95)
	luna.light_energy = 0.14
	_sv.add_child(luna)

	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	suolo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.17, 0.2, 0.26)
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


func _inquadra(a: AABB, az: float, ele: float) -> void:
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


func _scatta() -> Image:
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _sv.get_texture().get_image()


func _go() -> void:
	await process_frame
	if OS.get_environment("CHIBI_LATO") != "":
		_lato = int(OS.get_environment("CHIBI_LATO"))
	_studio()
	var dove := OS.get_environment("CHIBI_PROVINO")
	if dove == "":
		dove = "docs/catalogo/provini-luci"
	DirAccess.make_dir_recursive_absolute(dove)

	var elenco: Array = ACCESI.duplicate()
	if OS.get_environment("CHIBI_LUCI") != "":
		elenco = []
		for s in OS.get_environment("CHIBI_LUCI").split(","):
			elenco.append(s.strip_edges())

	var largo := 0.0
	if OS.get_environment("CHIBI_LARGO") != "":
		largo = float(OS.get_environment("CHIBI_LARGO"))

	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v

	var i := 0
	for nome in elenco:
		i += 1
		if not per_nome.has(nome):
			push_error("Pezzo sconosciuto: " + str(nome))
			continue
		var nodo: Node3D = (per_nome[nome]["builder"] as Callable).call()
		_sv.add_child(nodo)
		await process_frame
		var tutti := _mesh_aabb(nodo, nodo)
		if tutti.is_empty():
			nodo.queue_free()
			continue
		var ing: AABB = tutti[0]
		for k in range(1, tutti.size()):
			ing = ing.merge(tutti[k])
		# 0.55 basta per una pozza che cade attorno al pezzo; un fascio
		# INCLINATO (il girofaro) atterra a metri di distanza e uscirebbe
		# dall'inquadratura — allora si allarga a mano
		ing = ing.grow(0.55 + largo)
		ing.position.y = maxf(ing.position.y, -0.02)

		var foglio := Image.create(_lato * 2, _lato, false, Image.FORMAT_RGB8)
		for j in VISTE.size():
			_inquadra(ing, float(VISTE[j]["az"]), float(VISTE[j]["ele"]))
			var img: Image = await _scatta()
			img.convert(Image.FORMAT_RGB8)
			foglio.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
					Vector2i(_lato * j, 0))
		var slug := str(nome).to_lower().replace(" ", "-").replace("à", "a") \
				.replace("è", "e").replace("é", "e").replace("ì", "i") \
				.replace("ò", "o").replace("ù", "u")
		foglio.save_jpg(dove.rstrip("/") + "/%02d-%s.jpg" % [i, slug], 0.9)
		print("  ", nome)
		_sv.remove_child(nodo)
		nodo.queue_free()
	print("RASSEGNA LUCI -> ", dove)
	quit()
