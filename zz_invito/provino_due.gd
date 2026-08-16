extends SceneTree
## Due panchine ACCOSTATE (celle adiacenti = 1 m) con due chibi sopra.
## Si legge «vicini» o «compenetrati»? Tre inquadrature ruotando IL PEZZO.
##   CHIBI_DUE=/dove/le/foto Godot --path . --resolution 1280x720 \
##     --script res://zz_invito/provino_due.gd

const A := Vector2i(-2, 20)
const B := Vector2i(-1, 20)
const CASE := [Vector2i(-6, 20), Vector2i(3, 20)]

var _dove := ""
var _vis: Node
var _build: Node
var _player: Node3D
var _n := 0


func _init() -> void:
	_go()


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_n += 1


func _go() -> void:
	_dove = OS.get_environment("CHIBI_DUE")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_build = liv.get_node_or_null("BuildSystem")
	_vis = liv.get_node_or_null("Visitors")
	_player = liv.get_node_or_null("Player") as Node3D
	var dn := liv.get_node_or_null("DayNight")
	_build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.2).timeout
	_vis.call("debug_reset")
	for c in CASE:
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
	await process_frame
	for k in 2:
		_vis.call("debug_settle", 7000 + k * 313, CASE[k])
		await create_timer(0.6).timeout
	var res: Array = _vis.get("_residents")
	if res.size() < 2:
		print("GUASTO: %d residenti" % res.size()); quit(1); return
	var corpi: Array = []
	for r in res:
		corpi.append((r as Dictionary)["node"] as Node3D)
	for i in res.size():
		_vis.call("debug_force_activity", i, "gironzola")
		(res[i] as Dictionary)["next_act"] = 9999.0
	for rot in [0, 1, 2]:
		# le due panchine, ruotate insieme
		for cc in [A, B]:
			_build.call("_remove_at", 2, cc, 0)
		await create_timer(0.4).timeout
		_build.call("place_cell", A, "Panchina", rot, false)
		_build.call("place_cell", B, "Panchina", rot, false)
		_build.call("aggiorna_varchi_ora")
		await create_timer(0.5).timeout
		var mie: Array = []
		for p in (_build.call("get_placed_by_name", "Panchina") as Array):
			var q := p as Node3D
			var c2 := Vector2i(roundi(q.global_position.x), roundi(q.global_position.z))
			if c2 == A or c2 == B:
				mie.append(q)
		if mie.size() < 2:
			print("  rot %d: le panchine non ci sono (%d)" % [rot, mie.size()])
			continue
		var d := (mie[0] as Node3D).global_position.distance_to((mie[1] as Node3D).global_position)
		for k2 in 2:
			(corpi[k2] as Node3D).call("_enter_state", "r_idle")
			var arr: Vector3 = (mie[k2] as Node3D).global_transform * Vector3(0, 0, 0.8)
			(corpi[k2] as Node3D).call("do_routine", "bench",
					Vector3(arr.x, 0, arr.z), Vector3.ZERO, mie[k2], 60.0)
		_player.global_position = ((mie[0] as Node3D).global_position
				+ (mie[1] as Node3D).global_position) * 0.5 + Vector3(0, 0, 3.6)
		await create_timer(7.0).timeout
		var seduti := 0
		for k3 in 2:
			if str((corpi[k3] as Node3D).get("_state")) == "r_bench":
				seduti += 1
		var dc := (corpi[0] as Node3D).global_position.distance_to((corpi[1] as Node3D).global_position)
		print("  rot %d — panchine a %.2f m, corpi a %.2f m, seduti %d/2" % [rot, d, dc, seduti])
		await _scatta("due_rot%d" % rot)
	print("\n  foto: %d in %s" % [_n, _dove])
	quit(0)
