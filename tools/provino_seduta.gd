extends SceneTree
## IL PROVINO DELLA SEDUTA — perché una suite verde non dice niente sulla resa.
##
## Il movimento non si giudica in una posa: si giudica in una PELLICOLA.
## Questo apre il MainLevel vero, ci posa una Panchina col BuildSystem
## vero, ci manda un vicino vero a sedersi, e fotografa il montaggio (e poi
## la discesa) a intervalli fissi — una striscia di fotogrammi che si
## guarda tutta insieme.
##
##   CHIBI_SEDUTA=/dove/salvare Godot --path . --fixed-fps 60 \
##       --script res://tools/provino_seduta.gd
##
## Le due strisce da confrontare sono "salita" e "discesa". Ciò che si
## cerca: il corpo deve COPRIRE la distanza, non sparire da un fotogramma
## e ricomparire in quello dopo. Se fra due scatti consecutivi il vicino
## fa mezzo metro, è la fucilata di prima.

## Ogni quanti frame si scatta (a 60 fps: uno scatto ogni 3 centesimi —
## abbastanza fitto da vedere il vecchio salto, che durava UN frame).
const OGNI := 2
## Quanti scatti per striscia.
const SCATTI := 16
## La cella dove si posa la panchina della prova.
const CELLA := Vector2i(6, 6)

var _cam: Camera3D = null
var _dir := ""


func _init() -> void:
	_go()


func _scatta(nome: String) -> void:
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, nome])


func _go() -> void:
	_dir = OS.get_environment("CHIBI_SEDUTA")
	if _dir == "":
		print("serve CHIBI_SEDUTA=<cartella>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)

	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 20:
		await process_frame
	var lv := current_scene
	var build := lv.get_node_or_null("BuildSystem")
	var visitors := lv.get_node_or_null("Visitors")
	if build == null or visitors == null:
		print("GUASTO: MainLevel senza BuildSystem/Visitors")
		quit(1)
		return
	build.call("set_persist_for_debug", false)

	# mezzogiorno pieno: la luce non deve essere una variabile del provino
	var dn = lv.get_node_or_null("DayNight")
	if dn:
		dn.call("set_time", 0.42)

	# la panchina, e una casa per il vicino che ci si siederà
	visitors.call("debug_reset")
	build.call("place_cell", CELLA, "Letto", 0, false, 0, "")
	build.call("place_cell", CELLA, "Tetto", 0, false, 0, "")
	build.call("place_cell", CELLA + Vector2i(0, 2), "Panchina", 0, false, 0, "")
	await process_frame
	visitors.call("debug_settle", 909, CELLA)
	for _i in 4:
		await process_frame
	var res: Array = visitors.get("_residents")
	if res.is_empty():
		print("GUASTO: nessun residente insediato")
		quit(1)
		return
	var v := (res[0] as Dictionary).get("node") as Node3D
	var panca := (build.call("get_placed_by_name", "Panchina") as Array)[0] as Node3D

	# LA CAMERA STA DI PROFILO, perpendicolare al movimento. Il vicino si
	# avvicina lungo +Z e sale di 52 cm: da qui quegli 80 cm sono tutti
	# leggibili, mentre di tre quarti (o peggio, in asse) un corpo che
	# trasla senza camminare si nasconde nella prospettiva.
	_cam = Camera3D.new()
	lv.add_child(_cam)
	_cam.current = true
	_cam.fov = 32.0
	var c: Vector3 = panca.global_position
	# alta abbastanza da vedere i PIEDI: a filo d'erba il filo d'erba
	# nasconde proprio la cosa che si sta misurando
	_cam.position = c + Vector3(4.2, 1.75, 0.55)
	_cam.look_at(c + Vector3(0, 0.30, 0.45))

	# via l'interfaccia: si guarda il corpo, non le barrette
	for layer in get_root().find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false

	# il vicino parte dal punto in cui la routine lo lascia: 80 cm davanti
	var arrivo: Vector3 = panca.global_transform * Vector3(0, 0, 0.8)
	v.position = Vector3(arrivo.x, 0, arrivo.z)
	# niente agenda che gli rubi il corpo a metà provino
	visitors.call("debug_stage_resident", 0, v.position)
	(res[0] as Dictionary)["next_act"] = 9999.0
	await process_frame

	print("--- LA SALITA ---")
	v.call("do_routine", "bench", Vector3(arrivo.x, 0, arrivo.z),
			Vector3.ZERO, panca, 3.0)
	# lo si lascia arrivare col cammino, poi si scatta il montaggio
	var giri := 0
	while str(v.get("_state")) != "r_bench" and giri < 600:
		await process_frame
		giri += 1
	for i in SCATTI:
		await _scatta("salita_%02d" % i)
		for _j in OGNI:
			await process_frame

	print("--- LA DISCESA ---")
	v.set("_timer", 0.0)
	for i in SCATTI:
		await _scatta("discesa_%02d" % i)
		for _j in OGNI:
			await process_frame

	print("provino in %s" % _dir)
	quit(0)
