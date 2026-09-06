extends SceneTree
## L'AMPIEZZA — quanto deve essere GRANDE un movimento per arrivare allo
## schermo a sei metri. Si spazza l'ampiezza di ogni canale e si guarda
## quanti pixel di CONTORNO entrano o escono.
##
##   CHIBI_AMP=/dove Godot --path . --script res://zz_tmp/ricogn_ampiezza.gd

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const VISTE := [["fronte", 180.0], ["trequarti", 135.0], ["profilo", 90.0], ["spalle", 0.0]]
const SEME := 7331

var _dove := ""
var _player: Node3D = null
var _v: Node3D = null
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
			var s := _cam().unproject_position(q)
			if primo:
				r = Rect2(s, Vector2.ZERO); primo = false
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
	var rr := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rr).save_png(_dove.rstrip("/") + "/" + nome + ".png")
	_n += 1


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


## LO SPAZZAMENTO. Ogni voce è [famiglia, valore, Callable].
func _sweep() -> Array:
	var testa := _v.get("_head") as Node3D
	var vis := _v.get("_vis") as Node3D
	var corpo := _v.get("_corpo") as Node3D
	var orecchie: Array = _v.get("_c_ears")
	var braccia: Array = _v.get("_c_arms")
	var out := []
	for g in [10.0, 20.0, 30.0, 44.0, 60.0, 90.0]:
		out.append(["testaImb", g, func(): testa.rotation.y += deg_to_rad(g)])
	for g in [10.0, 20.0, 30.0, 44.0]:
		out.append(["testaCenno", g, func(): testa.rotation.x += deg_to_rad(g)])
		out.append(["testaRollio", g, func(): testa.rotation.z += deg_to_rad(g)])
	for g in [15.0, 25.0, 40.0, 60.0, 80.0]:
		out.append(["orecchie", g, func():
			for o in orecchie:
				(o as Node3D).rotation.x += deg_to_rad(g)])
	# LE BRACCIA, tutti e due i versi e tutti e due gli assi: la domanda è se
	# un braccio POSSA uscire dalla sagoma, non se esca con la posa che ho
	# scelto io. La prima stesura ne aveva provata UNA e concludeva di no.
	for g in [30.0, 60.0, 90.0, 120.0]:
		out.append(["braccioAvanti", g, func():
			(braccia[0] as Node3D).rotation.x -= deg_to_rad(g)
			(braccia[1] as Node3D).rotation.x -= deg_to_rad(g)])
		out.append(["braccioIndietro", g, func():
			(braccia[0] as Node3D).rotation.x += deg_to_rad(g)
			(braccia[1] as Node3D).rotation.x += deg_to_rad(g)])
		out.append(["braccioFuori", g, func():
			(braccia[0] as Node3D).rotation.z -= deg_to_rad(g)
			(braccia[1] as Node3D).rotation.z += deg_to_rad(g)])
		out.append(["braccioDentro", g, func():
			(braccia[0] as Node3D).rotation.z += deg_to_rad(g)
			(braccia[1] as Node3D).rotation.z -= deg_to_rad(g)])
	for g in [10.0, 20.0, 30.0, 45.0]:
		out.append(["bustoAvanti", g, func(): corpo.rotation.x += deg_to_rad(g)])
	for g in [20.0, 44.0, 90.0, 180.0]:
		out.append(["corpoGira", g, func(): vis.rotation.y += deg_to_rad(g)])
	for m in [0.05, 0.10, 0.15, 0.25, 0.40]:
		out.append(["saltello", m * 100.0, func(): _v.global_position += Vector3(0, m, 0)])
	for k in [0.05, 0.10, 0.15, 0.25]:
		out.append(["accovaccia", k * 100.0, func(): corpo.scale.y *= (1.0 - k)])
		out.append(["allunga", k * 100.0, func(): corpo.scale.y *= (1.0 + k)])
	for m in [0.10, 0.20, 0.40, 0.80]:
		out.append(["passoLato", m * 100.0, func():
			_v.global_position += _cam().global_transform.basis.x * m])
	return out


func _go() -> void:
	_dove = OS.get_environment("CHIBI_AMP")
	if _dove == "":
		print("serve CHIBI_AMP=/dove"); quit(1); return
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
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame

	var radice := _v.get("_corpo") as Node3D
	for vista in VISTE:
		var nome: String = vista[0]
		_v.global_position = Vector3.ZERO
		_player.global_position = Vector3(0.0, _player.global_position.y, 6.0)
		_v.set("_yaw", deg_to_rad(float(vista[1])))
		_v.rotation.y = deg_to_rad(float(vista[1]))
		for _i in 3:
			await process_frame
		_congela()
		var r := _bbox_tutto().grow(90.0)
		var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
				Vector2i(ceili(r.size.x), ceili(r.size.y)))
		radice.visible = false
		await _scatto("%s__bg" % nome, rr)
		radice.visible = true
		await _scatto("%s__base" % nome, rr)
		for s in _sweep():
			(s[2] as Callable).call()
			_v.force_update_transform()
			await _scatto("%s__%s_%03.0f" % [nome, str(s[0]), float(s[1])], rr)
			_rimetti()
			_v.force_update_transform()
		print("  %s: %d" % [nome, _n])
	Engine.time_scale = 1.0
	print("fatto: %d scatti" % _n)
	quit(0)
