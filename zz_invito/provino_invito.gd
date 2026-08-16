extends SceneTree
## IL PROVINO DELL'INVITO — si guarda, perche' la suite non dice niente
## sulla resa.
##
##   CHIBI_INVITO=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://zz_invito/provino_invito.gd
##   (SENZA --headless: senza rendering non c'e' niente da guardare)
##
## Tre domande che nessun numero risponde:
##  1. tre chibi seduti sugli sgabelli del gazebo (92 cm l'uno dall'altro):
##     si legge «insieme», o si legge «compenetrati»? E di PROFILO?
##  2. il posto che si riempie e si svuota: una PELLICOLA, non una posa.
##  3. IL RIFIUTO — chi c'era si alza due secondi dopo che l'altro si e'
##     seduto. Si legge come uno sgarbo? Accanto, la stessa scena con
##     quindici secondi in mezzo.
##
## ⚠️ LA CAMERA DI QUESTO GIOCO NON SI GIRA (nessuna imbardata: guarda
## sempre lungo −Z del mondo, 2,7 m sopra Mochi e 3,7 m dietro). Per vedere
## la scena da un altro lato si ruota IL PEZZO, mai la macchina.

## Si PROVANO, e si tengono le prime tre che il villaggio accetta.
const CANDIDATE := [Vector2i(-2, 18), Vector2i(2, 18), Vector2i(-6, 18),
	Vector2i(6, 18), Vector2i(-2, 20), Vector2i(2, 20), Vector2i(-6, 20),
	Vector2i(6, 20), Vector2i(-9, 18), Vector2i(9, 18)]
const GAZ := Vector2i(0, 16)

var _dove := ""
var _vis: Node
var _build: Node
var _player: Node3D
var _dn: Node
var _scatti := 0


func _init() -> void:
	_go()


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_scatti += 1


func _mochi_a(p: Vector3) -> void:
	_player.global_position = p


func _posti_del_gazebo() -> Array:
	var out: Array = []
	for g in (_build.call("get_placed_by_name", "Gazebo") as Array):
		for p in (g as Node3D).find_children("Posto*", "Node3D", true, false):
			out.append(p as Node3D)
	out.sort_custom(func(a, b): return str(a.name) < str(b.name))
	return out


func _siedi(nodo: Node3D, posto: Node3D) -> void:
	var arrivo: Vector3 = posto.global_position
	var sguardo := Vector3.ZERO
	if posto.has_meta("tavolo"):
		sguardo = (posto.get_parent() as Node3D).global_transform \
				* (posto.get_meta("tavolo") as Vector3)
	nodo.call("do_routine", "bench", Vector3(arrivo.x, 0, arrivo.z), sguardo, posto)


func _go() -> void:
	_dove = OS.get_environment("CHIBI_INVITO")
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
	_dn = liv.get_node_or_null("DayNight")
	if _build == null or _vis == null or _player == null:
		print("GUASTO: manca qualcosa"); quit(1); return
	_build.call("set_persist_for_debug", false)
	if _dn != null:
		_dn.set("cycle_seconds", 1000000.0)
		_dn.set("time", 0.42)
	await create_timer(1.2).timeout
	_vis.call("debug_reset")
	# LE CELLE SI PROVANO UNA PER UNA: `place_cell` rifiuta IN SILENZIO se la
	# cella e' gia' presa (il villaggio caricato ha 28 panchine) o se e' nel
	# letto del fiume. Un banco che non lo verifica insedia meno corpi di
	# quanti crede e poi dichiara un guasto che non c'e'.
	var libere: Array = []
	for c in CANDIDATE:
		var prima: int = (_build.call("get_placed_by_name", "Letto") as Array).size()
		_build.call("place_cell", c, "Letto", 0, false)
		await process_frame
		var dopo: int = (_build.call("get_placed_by_name", "Letto") as Array).size()
		if dopo > prima:
			_build.call("place_cell", c, "Tetto", 0, false)
			libere.append(c)
		if libere.size() >= 3:
			break
	print("celle usate: %s" % str(libere))
	if libere.size() < 3:
		print("GUASTO: solo %d celle libere" % libere.size()); quit(1); return
	# le due PANCHINE ACCOSTATE, per la scena 4
	_build.call("place_cell", Vector2i(11, 19), "Panchina", 0, false)
	_build.call("place_cell", Vector2i(12, 19), "Panchina", 0, false)
	_build.call("place_cell", GAZ, "Gazebo", 0, false)
	_build.call("aggiorna_varchi_ora")
	for k in 3:
		_vis.call("debug_settle", 4242 + k * 91, libere[k])
		await create_timer(0.6).timeout
	await create_timer(1.0).timeout
	var res: Array = _vis.get("_residents")
	if res.size() < 3:
		print("GUASTO: %d residenti" % res.size()); quit(1); return
	var corpi: Array = []
	for r in res:
		corpi.append((r as Dictionary)["node"] as Node3D)
	for i in res.size():
		_vis.call("debug_force_activity", i, "gironzola")
		(res[i] as Dictionary)["next_act"] = 9999.0
	var posti := _posti_del_gazebo()
	print("posti del gazebo: %d" % posti.size())
	if posti.size() >= 2:
		print("  distanza fra gli sgabelli: %.2f m / %.2f m"
				% [(posti[0] as Node3D).global_position.distance_to((posti[1] as Node3D).global_position),
				(posti[0] as Node3D).global_position.distance_to((posti[2] as Node3D).global_position)])
	var centro: Vector3 = (posti[0] as Node3D).global_position

	# ---------------------------------------------------------------
	print("\n█ SCENA 1 — LA PELLICOLA: il posto che si riempie")
	_mochi_a(centro + Vector3(0.4, 0, 5.2))
	await create_timer(0.6).timeout
	await _scatta("1_00_vuoto")
	_siedi(corpi[0] as Node3D, posti[0])
	await create_timer(6.0).timeout
	await _scatta("1_01_uno")
	_siedi(corpi[1] as Node3D, posti[1])
	await create_timer(2.6).timeout
	await _scatta("1_02_arriva_il_secondo")
	await create_timer(3.4).timeout
	await _scatta("1_03_due")
	_siedi(corpi[2] as Node3D, posti[2])
	await create_timer(3.0).timeout
	await _scatta("1_04_arriva_il_terzo")
	await create_timer(3.5).timeout
	await _scatta("1_05_tre")
	# e piu' vicino, che e' come ci si passa accanto
	_mochi_a(centro + Vector3(0.4, 0, 3.4))
	await create_timer(0.6).timeout
	await _scatta("1_06_tre_da_vicino")

	# ---------------------------------------------------------------
	print("█ SCENA 2 — DI PROFILO E DI TRE QUARTI (si ruota il PEZZO)")
	for rot in [1, 2, 3]:
		_build.call("_remove_at", 2, GAZ, 0)
		await create_timer(0.4).timeout
		_build.call("place_cell", GAZ, "Gazebo", rot, false)
		_build.call("aggiorna_varchi_ora")
		await create_timer(0.5).timeout
		var pp := _posti_del_gazebo()
		if pp.size() < 3:
			print("  (rot %d: il gazebo non ha i posti)" % rot)
			continue
		for k2 in 3:
			(corpi[k2] as Node3D).call("_enter_state", "r_idle")
			_siedi(corpi[k2] as Node3D, pp[k2])
		await create_timer(6.0).timeout
		await _scatta("2_rot%d" % rot)

	# ---------------------------------------------------------------
	print("█ SCENA 3 — IL RIFIUTO: due secondi contro quindici")
	_build.call("_remove_at", 2, GAZ, 0)
	await create_timer(0.4).timeout
	var pan: Array = []
	for p2 in (_build.call("get_placed_by_name", "Panchina") as Array):
		pan.append(p2 as Node3D)
	if pan.size() >= 2:
		var c0 := (pan[0] as Node3D).global_position
		print("  due panchine accostate: %.2f m"
				% c0.distance_to((pan[1] as Node3D).global_position))
		_mochi_a(c0 + Vector3(0.5, 0, 4.6))
		for caso in [["3a_rifiuto", 2.0], ["3b_insieme", 12.0]]:
			for k3 in 2:
				(corpi[k3] as Node3D).call("_enter_state", "r_idle")
			var arr0: Vector3 = (pan[0] as Node3D).global_transform * Vector3(0, 0, 0.8)
			var arr1: Vector3 = (pan[1] as Node3D).global_transform * Vector3(0, 0, 0.8)
			(corpi[0] as Node3D).call("do_routine", "bench",
					Vector3(arr0.x, 0, arr0.z), Vector3.ZERO, pan[0], 40.0)
			await create_timer(6.0).timeout
			(corpi[1] as Node3D).call("do_routine", "bench",
					Vector3(arr1.x, 0, arr1.z), Vector3.ZERO, pan[1], 40.0)
			await create_timer(6.0).timeout
			await _scatta(str(caso[0]) + "_1_seduti")
			await create_timer(float(caso[1])).timeout
			# il primo si alza: gli si azzera il timer
			(corpi[0] as Node3D).set("_timer", 0.01)
			await create_timer(1.4).timeout
			await _scatta(str(caso[0]) + "_2_si_alza")
			await create_timer(1.6).timeout
			await _scatta(str(caso[0]) + "_3_resta_uno")

	print("\n  foto scattate: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	quit(0)
