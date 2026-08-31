extends SceneTree
## IL METRO DELL'ATELIER — quanto costa riempire il catalogo.
##
## Due numeri che nessuna asserzione sa dare: **quando la griglia è piena**
## (il transitorio di carte bianche, l'unica delle due cose che il
## giocatore vede) e **quanto pesa il fotogramma mentre si dipinge**.
##
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##         --resolution 1920x1080 --script res://tools/misura_atelier.gd
##
## ⚠️ SI MISURA A/B NELLA STESSA CORSA, e qui non si può: `Miniature.STUDI`
## è una costante. Perciò ogni corsa porta **il proprio fotogramma a
## riposo** come termine di paragone, e si confrontano gli SCARTI — mai i
## millisecondi nudi. Due corse dello stesso codice, in questa serie, sono
## uscite col riposo a 38,6 e a 40,65 ms: chi confronta i numeri assoluti
## sta misurando le altre sessioni che girano sulla macchina.
##
## ⚠️ E NON in `--headless`: senza schermo non si disegna, quindi non c'è
## niente da contare e lo studio nasce spento.
var _dt: Array[float] = []
var _campiona := false
func _init() -> void: _go()
func _process(_d: float) -> bool:
	if _campiona: _dt.append(get_root().get_process_delta_time())
	return false
func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 8: await process_frame
	await create_timer(2.0).timeout
	var bs: Node = current_scene.get_node_or_null("BuildSystem")
	bs.call("set_persist_for_debug", false)
	bs.set("_locks_active", false)
	# il fotogramma a riposo, PRIMA di aprire: il termine di paragone
	_campiona = true
	await create_timer(2.0).timeout
	var riposo := _dt.duplicate(); _dt.clear()
	bs.call("set_active_for_debug", true, Vector3(2, 0, 4), "Tavolino")
	var t0 := Time.get_ticks_msec()
	var svuota := -1
	var mini: Node = null
	for i in 900:
		await process_frame
		if mini == null: mini = bs.get("_mini")
		if mini and svuota < 0:
			var m: Dictionary = mini.call("misure")
			if int(m.get("n", 0)) > 0 and int(m.get("in_coda", 0)) == 0:
				svuota = Time.get_ticks_msec() - t0
				break
	var dip := _dt.duplicate()
	print("STUDI=", mini.get("STUDI") if mini else "?")
	print("  coda svuotata dopo  : ", svuota, " ms")
	print("  misure              : ", mini.call("misure") if mini else "?")
	print("  riposo  n=", riposo.size(), " medio=", "%.2f" % (_media(riposo) * 1000.0),
			" max=", "%.2f" % (_max(riposo) * 1000.0), " ms")
	print("  dipinge n=", dip.size(), " medio=", "%.2f" % (_media(dip) * 1000.0),
			" max=", "%.2f" % (_max(dip) * 1000.0), " ms")
	quit()
func _media(a: Array[float]) -> float:
	if a.is_empty(): return 0.0
	var s := 0.0
	for x in a: s += x
	return s / a.size()
func _max(a: Array[float]) -> float:
	var m := 0.0
	for x in a: m = maxf(m, x)
	return m
