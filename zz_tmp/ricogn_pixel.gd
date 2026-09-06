extends SceneTree
## LA VERITÀ IN PIXEL — quanti pixel dipinge DAVVERO ogni parte, e quanti
## pixel cambia DAVVERO un gesto. Con l'occlusione dentro, che è metà della
## risposta: da dietro gli occhi hanno una geometria e ZERO pixel.
##
##   CHIBI_PX=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --script res://zz_tmp/ricogn_pixel.gd      # SENZA --headless
##
## Il metodo è la LASTRA DI FONDO: si rende lo sfondo senza il chibi, poi il
## chibi. La differenza è la sua MASCHERA — l'insieme dei pixel che occupa
## davvero, ombra compresa. Da lì:
##   · l'area di ogni parte = i pixel che spariscono nascondendo quella parte;
##   · la lettura di un gesto = i pixel di MASCHERA che cambiano (il
##     contorno), separati da quelli che cambiano solo di colore (il dettaglio
##     interno, che a distanza si impasta).
##
## ⚠️ Il mondo si CONGELA (`Engine.time_scale = 0`): senza, l'erba al vento e
## le farfalle cambiano più pixel del gesto, e si misurerebbe il prato.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

const DISTANZE := [2.0, 4.0, 6.0, 9.0, 15.0]
const VISTE := [["fronte", 180.0], ["trequarti", 135.0], ["profilo", 90.0], ["spalle", 0.0]]
const SEME := 7331

var _dove := ""
var _player: Node3D = null
var _v: Node3D = null
var _manifest := []
var _n := 0


func _init() -> void:
	_go()


func _cam() -> Camera3D:
	return get_root().get_camera_3d()


func _mesh(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mesh(c))
	return out


func _proj(p: Vector3) -> Vector2:
	return _cam().unproject_position(p)


func _bbox_tutto() -> Rect2:
	var radice := _v.get("_corpo") as Node3D
	var r := Rect2()
	var primo := true
	for m in _mesh(radice):
		var mi: MeshInstance3D = m
		var ab := mi.get_aabb()
		var xf := mi.global_transform
		for i in 8:
			var q: Vector3 = xf * (ab.position + Vector3(
					ab.size.x * float(i & 1), ab.size.y * float((i >> 1) & 1),
					ab.size.z * float((i >> 2) & 1)))
			if _cam().is_position_behind(q):
				continue
			var s := _proj(q)
			if primo:
				r = Rect2(s, Vector2.ZERO)
				primo = false
			else:
				r = r.expand(s)
	return r


func _scatto(nome: String, r: Rect2i) -> void:
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var big := Rect2i(Vector2i.ZERO, img.get_size())
	var rr := r.intersection(big)
	img.get_region(rr).save_png(_dove.rstrip("/") + "/" + nome + ".png")
	_n += 1


func _metti_yaw(y: float) -> void:
	_v.set("_yaw", y)
	_v.rotation.y = y


func _posa(d: float, gradi: float) -> void:
	_v.global_position = Vector3.ZERO
	_player.global_position = Vector3(0.0, _player.global_position.y, d)
	_metti_yaw(deg_to_rad(gradi))


# ── i gruppi, come nella ricognizione geometrica ─────────────────────────

func _gruppi() -> Dictionary:
	var testa := _v.get("_head") as Node3D
	var orecchie: Array = _v.get("_c_ears")
	var braccia: Array = _v.get("_c_arms")
	var gambe: Array = _v.get("_c_legs")
	var coda = _v.get("_tail_p")
	var coda_p = _v.get("_tail_tip")
	var faccia = _v.get("_face")
	var occhi_n := []
	var brow_n := []
	var bocca_n := []
	if faccia != null:
		for e in (faccia.get("_eyes") as Array):
			occhi_n.append(e)
		for b in (faccia.get("_brows") as Array):
			brow_n.append(b)
		var mm = faccia.get("_mouths")
		if mm is Dictionary:
			for k in (mm as Dictionary):
				bocca_n.append((mm as Dictionary)[k])
	var g := {"testona": [], "orecchie": [], "occhi": [], "sopracciglia": [],
			"bocca e naso": [], "braccia": [], "mani": [], "gambe": [], "coda": [],
			"corpo (vestito)": []}
	var radice := _v.get("_corpo") as Node3D
	for m in _mesh(radice):
		var mi: MeshInstance3D = m
		var chi := "corpo (vestito)"
		var n: Node = mi
		var dentro_testa := false
		while n != null and n != radice.get_parent():
			if n in occhi_n:
				chi = "occhi"; break
			if n in brow_n:
				chi = "sopracciglia"; break
			if n in bocca_n:
				chi = "bocca e naso"; break
			if n in orecchie:
				chi = "orecchie"; break
			if n in braccia:
				chi = "braccia"; break
			if n in gambe:
				chi = "gambe"; break
			if n == coda or (coda_p != null and n == coda_p):
				chi = "coda"; break
			if n == testa:
				dentro_testa = true; break
			n = n.get_parent()
		if chi == "corpo (vestito)" and dentro_testa:
			chi = "bocca e naso"      # naso, filtrino, guanciotte, ciuffi
		g[chi].append(mi)
	var testa_ms: Array = g["bocca e naso"]
	var big: MeshInstance3D = null
	var bigv := -1.0
	for m in testa_ms:
		var ab: AABB = (m as MeshInstance3D).get_aabb()
		var vol := ab.size.x * ab.size.y * ab.size.z
		if vol > bigv:
			bigv = vol; big = m
	if big != null:
		testa_ms.erase(big)
		g["testona"] = [big]
	for br in braccia:
		var giu: MeshInstance3D = null
		var giuy := 9999.0
		for m in _mesh(br as Node):
			var c: Vector3 = (m as MeshInstance3D).global_transform \
					* (m as MeshInstance3D).get_aabb().get_center()
			if c.y < giuy:
				giuy = c.y; giu = m
		if giu != null:
			(g["braccia"] as Array).erase(giu)
			(g["mani"] as Array).append(giu)
	return g


# ── le pose da provare (rig congelato) ───────────────────────────────────

func _pose() -> Array:
	var testa := _v.get("_head") as Node3D
	var vis := _v.get("_vis") as Node3D
	var corpo := _v.get("_corpo") as Node3D
	var orecchie: Array = _v.get("_c_ears")
	var braccia: Array = _v.get("_c_arms")
	var coda = _v.get("_tail_p")
	return [
	["testa_imb10", func(): testa.rotation.y += 0.175],
	["testa_imb20", func(): testa.rotation.y += 0.349],
	["testa_imb44", func(): testa.rotation.y += 0.775],
	["testa_imb44neg", func(): testa.rotation.y -= 0.775],
	["testa_imb90", func(): testa.rotation.y += 1.571],
	["testa_becc20", func(): testa.rotation.x += 0.349],
	["testa_becc44", func(): testa.rotation.x += 0.775],
	["testa_roll20", func(): testa.rotation.z += 0.349],
	["testa_roll44", func(): testa.rotation.z += 0.775],
	["orecchie_giu25", func():
		for o in orecchie:
			(o as Node3D).rotation.x += 0.436],
	["orecchie_giu50", func():
		for o in orecchie:
			(o as Node3D).rotation.x += 0.873],
	["braccio_su60", func(): (braccia[0] as Node3D).rotation.x -= 1.047],
	["braccia_lato70", func():
		(braccia[0] as Node3D).rotation.z += 1.222
		(braccia[1] as Node3D).rotation.z -= 1.222],
	["braccia_su140", func():
		(braccia[0] as Node3D).rotation.z += 2.44
		(braccia[1] as Node3D).rotation.z -= 2.44],
	["busto_avanti15", func(): corpo.rotation.x += 0.262],
	["busto_avanti30", func(): corpo.rotation.x += 0.524],
	["busto_torsione25", func(): corpo.rotation.y += 0.436],
	["corpo_gira44", func(): vis.rotation.y += 0.775],
	["corpo_gira90", func(): vis.rotation.y += 1.571],
	["corpo_passo40", func(): _v.global_position += _cam().global_transform.basis.x * 0.40],
	["corpo_saltello15", func(): _v.global_position += Vector3(0, 0.15, 0)],
	["corpo_accovaccia", func(): corpo.scale.y *= 0.85],
	["coda_frusta40", func():
		if coda != null:
			(coda as Node3D).rotation.y += 0.698],
	]


var _snap := {}

func _congela() -> void:
	_snap.clear()
	var nodi := [_v, _v.get("_vis"), _v.get("_corpo"), _v.get("_head"),
			_v.get("_tail_p"), _v.get("_tail_tip")]
	for a in (_v.get("_c_ears") as Array):
		nodi.append(a)
	for a in (_v.get("_c_arms") as Array):
		nodi.append(a)
	for a in (_v.get("_c_legs") as Array):
		nodi.append(a)
	for n in nodi:
		if n != null and is_instance_valid(n):
			_snap[n] = (n as Node3D).transform


func _rimetti() -> void:
	for n in _snap:
		if is_instance_valid(n):
			(n as Node3D).transform = _snap[n]


func _go() -> void:
	_dove = OS.get_environment("CHIBI_PX")
	if _dove == "":
		print("serve CHIBI_PX=/dove")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	var visitors := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout
	_v = VS.new()
	_v.species = "chibi"
	_v.dna = DNAG.generate(SEME)
	visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 99999.0)
	_v.global_position = Vector3.ZERO
	await create_timer(0.8).timeout

	# IL MONDO SI FERMA. Da qui in poi niente `create_timer`: con time_scale
	# a zero non scatterebbe mai.
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame

	var radice := _v.get("_corpo") as Node3D
	for vista in VISTE:
		var nome: String = vista[0]
		for dv in DISTANZE:
			var d := float(dv)
			_posa(d, float(vista[1]))
			for _i in 3:
				await process_frame
			_congela()
			var r := _bbox_tutto().grow(40.0)
			var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
					Vector2i(ceili(r.size.x), ceili(r.size.y)))
			var base := "%s_%02.0fm" % [nome, d]
			# 1) la LASTRA DI FONDO: il chibi sparisce del tutto
			radice.visible = false
			await _scatto(base + "__bg", rr)
			radice.visible = true
			# 2) il rumore di fondo: due scatti identici
			await _scatto(base + "__base", rr)
			await _scatto(base + "__base2", rr)
			# 3) ogni parte, nascosta una per volta
			var g := _gruppi()
			for k in g:
				var ms: Array = g[k]
				if ms.is_empty():
					continue
				for m in ms:
					(m as MeshInstance3D).visible = false
				await _scatto(base + "__hide_" + str(k).replace(" ", "-").replace("(", "").replace(")", ""), rr)
				for m in ms:
					(m as MeshInstance3D).visible = true
			# 4) le pose (solo alle tre distanze che contano)
			if d == 2.0 or d == 6.0 or d == 15.0:
				for p in _pose():
					(p[1] as Callable).call()
					_v.force_update_transform()
					await _scatto(base + "__pose_" + str(p[0]), rr)
					_rimetti()
					_v.force_update_transform()
			_manifest.append({"vista": nome, "d": d, "rect": [rr.position.x,
					rr.position.y, rr.size.x, rr.size.y]})
			print("  %s: %d scatti" % [base, _n])
	var f := FileAccess.open(_dove.rstrip("/") + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_manifest))
	f.close()
	Engine.time_scale = 1.0
	print("fatto: %d scatti in %s" % [_n, _dove])
	quit(0)
