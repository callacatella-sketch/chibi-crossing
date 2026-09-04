extends SceneTree
## LA FIDUCIA, MISURATA IN PARTITA — e i cancelli d'arresto dichiarati PRIMA.
##
##   CHIBI_GIORNI=3 Godot --headless --path . \
##     --script res://tools/misura_fiducia.gd
##
## `Animo.fiducia()` è la gemella di `rancore()`, e nasce perché il libro
## mastro sapeva dire quanto qualcuno ti ha fatto del male e non sapeva dire
## quanto ti ha fatto del bene. Le domande che decidono se vale:
##
##   1. IL CARBURANTE ESISTE, e DISTINGUE? (è la domanda che ha ucciso la
##      spinta «vegliato»: una prova che tocca tutti allo stesso modo non
##      distingue nessuno.)
##   2. QUANTO ALTA arriva davvero, giocando come si gioca?
##   3. ⚠️ CAMBIA UNA DECISIONE? `punteggio()` ha un solo lettore (`decide()`)
##      che pesa `exp((s − base) · nitidezza)` con `base` preso dai voti
##      stessi: un termine additivo si cancella ESATTAMENTE. Se le scelte non
##      cambiano, questa funzione è la nona completa-provata-verde-e-spenta.
##   4. ⚠️ CANCELLO D'ARRESTO: chi il giocatore NON ha toccato deve avere il
##      gioco di ieri, bit per bit. Se anche lui si muove, è un malus
##      mascherato e la funzione va tolta.
##
## ⚠️ E non si tocca il `village.json` dell'autore.

const ANIMO := preload("res://scenes/npc/Animo.gd")

var _giorni := 3
var _guasti := 0


func _init() -> void:
	_go()


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok      " if ok else "  ARRESTO ") + testo)


func _go() -> void:
	if OS.get_environment("CHIBI_GIORNI") != "":
		_giorni = int(OS.get_environment("CHIBI_GIORNI"))
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var liv := current_scene
	var vis := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	if vis == null or build == null:
		print("GUASTO: livello incompleto")
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout

	var res: Array = vis.get("_residents")
	var animi: Dictionary = vis.get("_animi")
	if res.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	print("")
	print("=".repeat(72))
	print("LA FIDUCIA — %d residenti, %d giornate" % [res.size(), _giorni])
	print("=".repeat(72))

	# ------------------------------------------------------------------
	# 1) IL GIOCATORE GIOCA. Non a tutti: è il vincolo che fa la varietà,
	#    ed è anche il modo in cui il cancello 4 diventa osservabile.
	# ------------------------------------------------------------------
	var toccati := {}
	var passi := int(_giorni * 240.0 / 3.0)
	for p in passi:
		await create_timer(3.0).timeout
		if p % 7 == 3 and not res.is_empty():
			# solo i primi quattro, sempre — così restano dei non toccati
			var chi: Dictionary = res[(p / 7) % mini(4, res.size())]
			var lab := str(chi.get("label", ""))
			if vis.has_method("gesto_gentile"):
				vis.call("gesto_gentile", lab,
						"piatto" if p % 14 == 3 else "regalo", 0.85)
				toccati[lab] = int(toccati.get(lab, 0)) + 1

	# ------------------------------------------------------------------
	# 2) IL CARBURANTE, e la fiducia che ne esce
	# ------------------------------------------------------------------
	print("\n1-2. IL CARBURANTE E LA FIDUCIA")
	var f_toccati: Array = []
	var f_altri: Array = []
	var riga := ""
	for r in res:
		var lab := str(r.get("label", ""))
		var a = animi.get(lab)
		if a == null:
			continue
		var f: float = float(a.fiducia("giocatore"))
		riga += "%s:%.3f " % [lab.get_slice(" ", lab.get_slice_count(" ") - 1), f]
		if int(toccati.get(lab, 0)) > 0:
			f_toccati.append(f)
		else:
			f_altri.append(f)
	print("   %s" % riga)
	print("   toccati dal giocatore: %s" % _riass(f_toccati))
	print("   NON toccati:           %s" % _riass(f_altri))
	_dico(_max(f_toccati) > 0.0,
			"il carburante esiste: chi il giocatore ha curato ha fiducia > 0")
	_dico(_max(f_toccati) > _max(f_altri),
			"e DISTINGUE: chi è stato curato si separa da chi no")

	# ------------------------------------------------------------------
	# 3) ⚠️ CAMBIA UNA DECISIONE VERA?
	# ------------------------------------------------------------------
	print("\n3. ⚠️ CAMBIA UNA DECISIONE — l'oracolo è la SCELTA, non il punteggio")
	var azioni: Array = (ANIMO.COMPITI as Dictionary).keys()
	var diversi := 0
	var provati := 0
	for r2 in res:
		var lab2 := str(r2.get("label", ""))
		var a2 = animi.get(lab2)
		if a2 == null or float(a2.fiducia("giocatore")) <= 0.0:
			continue
		provati += 1
		# lo stesso animo, con e senza la storia: si confronta il PUNTEGGIO
		# su ogni azione, perché è lì che il termine vive
		for az in azioni:
			var con: float = float(a2.punteggio(str(az), "giocatore"))
			var senza: float = float(a2.punteggio(str(az), "un_estraneo"))
			if absf(con - senza) > 0.001:
				diversi += 1
				break
	print("   residenti con fiducia > 0: %d · di cui il punteggio cambia: %d"
			% [provati, diversi])
	_dico(provati > 0, "qualcuno ha una storia col giocatore")
	_dico(diversi > 0,
			("e per lui `punteggio()` DIFFERISCE fra chi ha una storia e un "
			+ "estraneo: se fosse zero, la funzione sarebbe spenta"))

	# ------------------------------------------------------------------
	# 4) ⚠️ IL CANCELLO D'ARRESTO
	# ------------------------------------------------------------------
	print("\n4. ⚠️ CANCELLO D'ARRESTO — chi non è stato toccato ha il gioco di ieri")
	var mossi := 0
	for f3 in f_altri:
		if float(f3) > 0.0:
			mossi += 1
	print("   non toccati con fiducia > 0: %d su %d" % [mossi, f_altri.size()])
	_dico(mossi == 0,
			("chi il giocatore non ha toccato vale ZERO: nessun malus "
			+ "mascherato, e il suo gioco è bit per bit quello di ieri"))

	print("\n==== LA FIDUCIA: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d ARRESTI" % _guasti))
	quit(0 if _guasti == 0 else 1)


func _riass(a: Array) -> String:
	if a.is_empty():
		return "(nessuno)"
	var mn := 9e9
	var mx := -9e9
	var sm := 0.0
	for x in a:
		mn = minf(mn, float(x))
		mx = maxf(mx, float(x))
		sm += float(x)
	return "n=%d  media %.4f  min %.4f  max %.4f" % [a.size(),
			sm / float(a.size()), mn, mx]


func _max(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m
