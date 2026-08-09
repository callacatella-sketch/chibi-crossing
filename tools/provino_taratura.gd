extends SceneTree
## IL PROVINO DELLE TARATURE: la stessa luce, N regolazioni affiancate.
##
## È il ferro con cui è stata scelta la luce della «Lanterna blu» (cinque
## prove al buio, e si guarda). Qui è generalizzato: si dice un pezzo del
## catalogo e un elenco di tarature, e ne esce UNA striscia con i
## fotogrammi affiancati e ETICHETTATI — perché due immagini in due file
## diversi non si confrontano, si ricordano male.
##
##   CHIBI_PEZZO_CAT="Lampione" \
##   CHIBI_TARATURE="1.6/5.5/1.0 | 2.6/5.0/1.1 | 3.4/4.6/1.2" \
##   CHIBI_PROVINO=/dove \
##       Godot --path . --script res://tools/provino_taratura.gd
##
## Una taratura è `energia/portata/attenuazione` più due campi
## facoltativi: `/dy` (alza o abbassa la sorgente) e `/colore` in esadecimale.
## `-` da solo lascia la taratura com'è nel catalogo (la prova di controllo:
## la prima colonna deve SEMPRE essere quella, o non si sta confrontando).
##
## Facoltativi:
##   CHIBI_VISTA   `alto` (default, la pozza per terra) oppure `occhio`
##   CHIBI_LATO    lato di un fotogramma (default 620)
##   CHIBI_VARIANTE  uno script con `static func costruisci() -> Node3D`,
##                   in alternativa al pezzo di catalogo

const CAT = preload("res://scenes/build/BuildCatalog.gd")

const FOV := 34.0

var _sv: SubViewport
var _cam: Camera3D
var _eti: Label
var _lato := 620


func _init() -> void:
	_go()


func _studio() -> void:
	_sv = SubViewport.new()
	_sv.size = Vector2i(_lato, _lato)
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)

	# LA STESSA NOTTE di provino_variante.gd e provino_luci.gd: tre studi
	# diversi renderebbero incomparabili tre giudizi
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

	# l'etichetta: senza, alla terza immagine non si sa più quale sia quale
	_eti = Label.new()
	_eti.position = Vector2(14, 10)
	_eti.add_theme_font_size_override("font_size", maxi(16, _lato / 26))
	_eti.add_theme_color_override("font_color", Color(1, 1, 1))
	_eti.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_eti.add_theme_constant_override("outline_size", 6)
	_sv.add_child(_eti)


func _luci(n: Node, out: Array) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		out.append(n)
	for f in n.get_children():
		_luci(f, out)


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


func _inquadra(a: AABB, alto: bool) -> void:
	var centro := a.position + a.size * 0.5
	# l'azimut si può girare: i pezzi che hanno un DAVANTI (il Fondale ha
	# la ribalta a +Z) dal tre quarti di sempre si guardano di schiena, e
	# di una conchiglia acustica vista da dietro non si giudica niente
	var az := 0.785398
	if OS.get_environment("CHIBI_AZ") != "":
		az = deg_to_rad(float(OS.get_environment("CHIBI_AZ")))
	var ele := 0.50 if alto else 0.09
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


func _costruisci() -> Node3D:
	var quale := OS.get_environment("CHIBI_VARIANTE")
	if quale != "":
		var sv = load(quale)
		return sv.costruisci() if sv != null else null
	var nome := OS.get_environment("CHIBI_PEZZO_CAT")
	for v in CAT.items():
		if str(v["name"]) == nome:
			return (v["builder"] as Callable).call()
	return null


func _go() -> void:
	await process_frame
	if OS.get_environment("CHIBI_LATO") != "":
		_lato = int(OS.get_environment("CHIBI_LATO"))
	_studio()
	var dove := OS.get_environment("CHIBI_PROVINO")
	if dove == "":
		dove = "docs/catalogo/provini-taratura"
	DirAccess.make_dir_recursive_absolute(dove)
	var alto := OS.get_environment("CHIBI_VISTA") != "occhio"

	var tarature: Array = []
	for s in OS.get_environment("CHIBI_TARATURE").split("|"):
		var v := s.strip_edges()
		if v != "":
			tarature.append(v)
	if tarature.is_empty():
		tarature = ["-"]

	var foglio := Image.create(_lato * tarature.size(), _lato, false, Image.FORMAT_RGB8)
	for i in tarature.size():
		var nodo := _costruisci()
		if nodo == null:
			push_error("Niente da renderizzare")
			quit(1)
			return
		var luci: Array = []
		_luci(nodo, luci)
		var t := str(tarature[i])
		if t != "-":
			var p := t.split("/")
			for l in luci:
				if l is OmniLight3D:
					l.light_energy = float(p[0])
					l.omni_range = float(p[1])
					l.omni_attenuation = float(p[2])
				else:
					l.light_energy = float(p[0])
					l.spot_range = float(p[1])
					l.spot_attenuation = float(p[2])
				if p.size() > 3:
					l.position.y += float(p[3])
				if p.size() > 4:
					l.light_color = Color(str(p[4]))
		_eti.text = ("catalogo: %.2f/%.1f/%.2f" % [
				(luci[0].light_energy if not luci.is_empty() else 0.0),
				(luci[0].omni_range if (not luci.is_empty() and luci[0] is OmniLight3D)
						else (luci[0].spot_range if not luci.is_empty() else 0.0)),
				(luci[0].omni_attenuation if (not luci.is_empty() and luci[0] is OmniLight3D)
						else (luci[0].spot_attenuation if not luci.is_empty() else 0.0))
			]) if t == "-" else t
		_sv.add_child(nodo)
		await process_frame
		var tutti := _mesh_aabb(nodo, nodo)
		var ing: AABB = tutti[0]
		for k in range(1, tutti.size()):
			ing = ing.merge(tutti[k])
		ing = ing.grow(0.55)
		ing.position.y = maxf(ing.position.y, -0.02)
		_inquadra(ing, alto)
		for _j in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		foglio.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
				Vector2i(_lato * i, 0))
		_sv.remove_child(nodo)
		nodo.queue_free()

	var chi := OS.get_environment("CHIBI_PEZZO_CAT")
	if chi == "":
		chi = "variante"
	var slug := chi.to_lower().replace(" ", "-")
	var esce := dove.rstrip("/") + "/" + slug + ("-alto" if alto else "-occhio") + ".jpg"
	foglio.save_jpg(esce, 0.92)
	print("TARATURE -> ", esce)
	quit()
