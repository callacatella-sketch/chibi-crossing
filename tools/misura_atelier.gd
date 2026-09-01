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
	# ⚠️ IL VSYNC SI SPEGNE, o si misura il monitor invece del gioco: con
	# il vsync acceso i delta si allineano ai refresh (16,67 · 33,3 · 50 ms)
	# e una differenza vera piu piccola di un refresh sparisce dentro la
	# quantizzazione. E il tappo dei fps farebbe lo stesso. E' la regola
	# della sezione «Le PRESTAZIONI non si misurano headless» del CLAUDE.md,
	# ed e la stessa riga che ha `tools/misura_fps.gd`.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	# ⚠️ E SI CONTA DOPO AVER LASCIATO RESPIRARE LA CODA. La rialimentazione
	# passa da un `call_deferred`, quindi esiste un fotogramma in cui la
	# coda è vuota e le carte in attesa ci sono ancora: contando lì, un
	# codice sano sembra rotto. Si aspetta che si fermi DAVVERO — e se
	# dopo trenta fotogrammi tranquilli restano carte appese, allora è vero.
	for i in 30:
		await process_frame
	# ⚠️ «CODA VUOTA» NON VUOL DIRE «GRIGLIA PIENA», e senza questo conto il
	# banco PREMIA chi toglie la cura: togliendo la rialimentazione di
	# `_su_miniatura` la coda si prosciuga prima, quindi «svuotata dopo»
	# scende — e il banco direbbe che il codice rotto è più veloce. Le
	# carte ancora appese sono la vera domanda.
	var bianche := 0
	var attesa: Variant = bs.get("_carte_attesa")
	if attesa is Dictionary:
		for nome in (attesa as Dictionary):
			bianche += ((attesa as Dictionary)[nome] as Array).size()
	print("STUDI=", mini.get("STUDI") if mini else "?")
	print("  coda svuotata dopo  : ", svuota, " ms")
	print("  CARTE ANCORA BIANCHE: ", bianche, "  (deve essere 0)")
	print("  misure              : ", mini.call("misure") if mini else "?")
	var r_med := _media(riposo) * 1000.0
	var d_med := _media(dip) * 1000.0
	var r_max := _max(riposo) * 1000.0
	var d_max := _max(dip) * 1000.0
	print("  riposo  n=", riposo.size(), " medio=", "%.2f" % r_med,
			" max=", "%.2f" % r_max, " ms")
	print("  dipinge n=", dip.size(), " medio=", "%.2f" % d_med,
			" max=", "%.2f" % d_max, " ms")
	# ⚠️ QUESTI sono i numeri da confrontare fra due corse, e gli altri no:
	# lo SCARTO dal proprio riposo. Dire «il fotogramma peggiore e 86,3 qui
	# e 87,9 la» significa confrontare due macchine, non due codici.
	print("  SCARTO  medio=+", "%.2f" % (d_med - r_med),
			" ms   peggiore=+", "%.2f" % (d_max - r_max), " ms")
	# ⚠️ E LA GEOMETRIA DEI DUE STATI. Il pannello piegato e la barra dei
	# colori sono passati attraverso una revisione intera senza che nessuno
	# li misurasse: il primo stava in 104 px dove ne servono 153 (Godot alza
	# il rect al minimo combinato e lo fa crescere verso il BASSO, cioè
	# fuori dallo schermo), la seconda cadeva dentro la griglia e copriva
	# tre carte. Due difetti di rettangoli, che nessuna asserzione della
	# suite può toccare e che un provino vede solo se qualcuno pensa a
	# scattare QUELLA scena.
	var guai: Array[String] = []
	var pan: Control = bs.get("_panel")
	var barra: Control = bs.get("_variant_bar")
	var alto := float(get_root().size.y)
	for stato in [true, false]:
		bs.call("_piega", stato)
		await create_timer(0.6).timeout
		var nome := "aperto" if stato else "piegato"
		var r := pan.get_global_rect()
		print("  %-8s pannello %s  (schermo alto %d)" % [nome, str(r), int(alto)])
		if r.end.y > alto + 0.5:
			guai.append("da %s il pannello sfora di %.0f px sotto lo schermo"
					% [nome, r.end.y - alto])
		if barra != null and barra.visible \
				and r.intersects(barra.get_global_rect()):
			guai.append("da %s la barra dei colori cade DENTRO il pannello" % nome)
	if barra != null and not barra.visible:
		print("  (la barra dei colori non è in scena: nessuna tinta sbloccata)")

	if bianche > 0:
		guai.append("%d carte non hanno mai avuto il loro ritratto" % bianche)
	if not guai.is_empty():
		print("")
		for g in guai:
			print("⚠️  ", g)
		quit(1)
		return
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
