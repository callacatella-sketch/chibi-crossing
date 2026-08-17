extends SceneTree
## LA SEDUTA CHE SCIVOLA — la MISURA, nel villaggio vero.
##
## Un vicino che si siede su una panchina parte con un tween di 0,4 s
## (TRANS_BACK/EASE_OUT) che scrive `position`. Deve coprire gli 0,8 m
## dell'avvicinamento PIU' i 52 cm del sedile: quasi un metro in quattro
## decimi di secondo, con un'attenuazione che parte alla massima velocita'.
## Il corpo non si siede: viene SPARATO sul sedile — e ci arriva col ciclo
## del passo ancora acceso (il blend scende in ~0,15 s), cioe' zampettando
## in aria mentre trasla.
##
## E c'e' un secondo guasto, piu' subdolo: il tween e' legato al NODO, non
## allo stato. Se qualcuno cambia stato in quei 0,4 s — e succede — il
## tween continua a scrivere `position` mentre il corpo e' gia' in cammino
## da un'altra parte.
##
## Questo non e' un test: e' il metro. Costruisce un accampamento vero col
## BuildSystem vero (letti, tetti, panchine), ci insedia residenti veri, e
## campiona OGNI FRAME posizione, velocita' e blend dell'andatura.
##
##   Godot --headless --path . --fixed-fps 60 \
##       --script res://tools/prova_seduta_troncata.gd
##
## `--fixed-fps 60` non e' un vezzo: senza, in headless il delta ballonzola
## e la velocita' misurata e' rumore.

## Quanto dura la parte A (secondi di villaggio).
const DURATA := 45.0
## Sopra questa velocita' orizzontale un corpo non sta camminando: sta
## scivolando. Il passo piu' veloce del gioco e' quello del passerotto in
## fase aerea (1,7 x 1,7 = 2,89 m/s); i residenti chibi stanno sotto 1,45.
const SOGLIA_SCIVOLO := 2.9
## Quanto durano le sedute della prova: corte, per vedere anche le DISCESE
## (in partita durano 14-22 s e in 45 s non se ne vedrebbe nessuna).
const SEDUTA_CORTA := 3.0


func _init() -> void:
	_go()


## DOVE SI CAMPIONA, e perche' non e' un dettaglio. L'ordine del frame in
## Godot e': segnale `process_frame` -> `_process` dei nodi -> TWEEN. Un
## campionamento dentro `_process` cade quindi IN MEZZO, fra il tween del
## frame scorso e il cammino di questo: la differenza fra due campioni
## somma due spostamenti che il giocatore non ha mai visto insieme, e
## inventa picchi che non esistono (misurato: 3,2 m/s di puro artefatto).
## Ci si aggancia percio' a `process_frame`, che vede la posizione come
## l'ha lasciata il frame precedente — cioe' come e' stata disegnata.
class Sonda extends Node:
	var campioni: Array = []      # [t, chi, stato, v, blend, stato_prec, y]
	var _prec: Dictionary = {}
	var _stato_prec: Dictionary = {}
	var t := 0.0
	var attiva := false
	var dettaglio := false

	func _ready() -> void:
		get_tree().process_frame.connect(_campiona)

	func azzera() -> void:
		campioni.clear()
		_prec.clear()
		_stato_prec.clear()
		t = 0.0

	func _campiona() -> void:
		if not attiva:
			return
		var delta := get_process_delta_time()
		t += delta
		for n in get_tree().get_nodes_in_group("passanti"):
			var p := (n as Node3D).global_position
			var chi := str(n.get_instance_id())
			var stato := str(n.get("_state"))
			var vel := 0.0
			var prima: Vector3 = _prec.get(chi, p)
			if _prec.has(chi):
				var d: Vector3 = p - prima
				vel = Vector2(d.x, d.z).length() / maxf(delta, 0.0001)
			_prec[chi] = p
			var blend := 0.0
			var and_ = n.get("_andatura")
			if and_ != null:
				blend = float(and_.get("blend"))
			campioni.append([t, chi, stato, vel, blend,
					str(_stato_prec.get(chi, "")), p.y])
			if dettaglio and vel > 2.9:
				print("    [dettaglio] t=%.3f  %s -> %s   %s  =>  %s"
						% [t, str(_stato_prec.get(chi, "")), stato,
						str(prima), str(p)])
			_stato_prec[chi] = stato


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	var lv := current_scene
	if lv == null:
		print("GUASTO: MainLevel non caricato")
		quit(1)
		return
	var build := lv.get_node_or_null("BuildSystem")
	var visitors := lv.get_node_or_null("Visitors")
	if build == null or visitors == null:
		print("GUASTO: BuildSystem=%s Visitors=%s" % [build, visitors])
		quit(1)
		return
	# PRIMA di tutto: niente scritture sul salvataggio vero
	build.call("set_persist_for_debug", false)

	# --- l'accampamento: sei case (letto + tetto) e sei panchine ---------
	visitors.call("debug_reset")
	var celle: Array[Vector2i] = []
	for i in 6:
		var c := Vector2i(4 + i * 3, 6)
		celle.append(c)
		build.call("place_cell", c, "Letto", 0, false, 0, "")
		build.call("place_cell", c, "Tetto", 0, false, 0, "")
		build.call("place_cell", c + Vector2i(0, 2), "Panchina", 0, false, 0, "")
	await process_frame
	for i in celle.size():
		visitors.call("debug_settle", 4000 + i * 13, celle[i])
	await process_frame
	await process_frame
	var res: Array = visitors.get("_residents")
	var panche: Array = build.call("get_placed_by_name", "Panchina")
	print("residenti insediati: %d   panchine: %d" % [res.size(), panche.size()])
	if res.size() < 4:
		print("GUASTO: non si sono insediati abbastanza residenti")
		quit(1)
		return

	var sonda := Sonda.new()
	sonda.dettaglio = OS.get_environment("CHIBI_DETTAGLIO") != ""
	lv.add_child(sonda)

	# ================= PARTE A: 45 s di villaggio =======================
	sonda.attiva = true
	var t := 0.0
	var prossimo := 0.0
	while t < DURATA:
		await process_frame
		t = float(sonda.t)
		# ogni 5 s si rimanda tutti a sedersi, con una seduta CORTA: cosi'
		# in 45 s si vedono sia le salite sia le discese
		if t >= prossimo:
			prossimo = t + 5.0
			for i in res.size():
				var nodo := (res[i] as Dictionary).get("node") as Node3D
				if nodo == null or not is_instance_valid(nodo):
					continue
				var panca := panche[i % panche.size()] as Node3D
				var arrivo: Vector3 = panca.global_transform * Vector3(0, 0, 0.8)
				nodo.call("do_routine", "bench", Vector3(arrivo.x, 0, arrivo.z),
						Vector3.ZERO, panca, SEDUTA_CORTA)
	sonda.attiva = false
	print("\n########## PARTE A — 45 s DI VILLAGGIO ##########")
	_rapporto(sonda.campioni)

	# ============ PARTE B: l'interruzione, di proposito =================
	# Si entra in r_bench e a tween ANCORA VIVO si cambia stato. Se il
	# tween sopravvive allo stato che l'ha creato, il corpo scivola verso
	# la panchina mentre cammina dall'altra parte — e ci resta appeso a
	# mezz'aria, perche' nessuno gli rimette i piedi a terra.
	print("\n########## PARTE B — L'INTERRUZIONE A TWEEN VIVO ##########")
	var cavia := (res[0] as Dictionary).get("node") as Node3D
	var panca0 := panche[0] as Node3D
	# l'agenda naturale va messa in pausa, o ruba la cavia a meta' prova
	for i in res.size():
		visitors.call("debug_stage_resident", i, (res[i] as Dictionary
				).get("node").global_position)
	for ritardo in [2, 6, 12, 21]:
		for i in res.size():
			(res[i] as Dictionary)["next_act"] = 9999.0
		var arrivo: Vector3 = panca0.global_transform * Vector3(0, 0, 0.8)
		cavia.call("do_routine", "bench", Vector3(arrivo.x, 0, arrivo.z),
				Vector3.ZERO, panca0, 30.0)
		var giri := 0
		while str(cavia.get("_state")) != "r_bench" and giri < 900:
			await process_frame
			giri += 1
		if str(cavia.get("_state")) != "r_bench":
			print("GUASTO: la cavia non si e' mai seduta")
			quit(1)
			return
		for _i in ritardo:
			await process_frame
		sonda.azzera()
		sonda.attiva = true
		cavia.call("do_routine", "sniff", cavia.global_position + Vector3(9, 0, 0))
		for _i in 50:
			await process_frame
		sonda.attiva = false
		_rapporto_cavia(sonda.campioni, str(cavia.get_instance_id()),
				float(ritardo) / 60.0)
	quit(0)


func _rapporto(campioni: Array) -> void:
	print("campioni: %d" % campioni.size())
	var v_max := 0.0
	var per_stato: Dictionary = {}
	var scivoli: Array = []
	var in_corso: Dictionary = {}
	for c in campioni:
		var t: float = c[0]
		var chi: String = c[1]
		var stato: String = c[2]
		var vel: float = c[3]
		var blend: float = c[4]
		v_max = maxf(v_max, vel)
		per_stato[stato] = maxf(float(per_stato.get(stato, 0.0)), vel)
		if vel > SOGLIA_SCIVOLO:
			if not in_corso.has(chi):
				in_corso[chi] = [t, vel, String(c[5]) + "->" + stato, blend, 1]
			else:
				var s: Array = in_corso[chi]
				s[1] = maxf(s[1], vel)
				s[3] = maxf(s[3], blend)
				s[4] = int(s[4]) + 1
				if not (stato in String(s[2])):
					s[2] = String(s[2]) + "+" + stato
		elif in_corso.has(chi):
			scivoli.append(in_corso[chi])
			in_corso.erase(chi)
	for chi in in_corso:
		scivoli.append(in_corso[chi])

	# quante salite e quante discese, e quante interrotte entro i 0,4 s
	var sedute := 0
	var discese := 0
	var troncate := 0
	var entrata: Dictionary = {}
	for c in campioni:
		var t: float = c[0]
		var chi: String = c[1]
		var stato: String = c[2]
		var prima: String = c[5]
		if stato == prima:
			continue
		if stato == "r_bench" or stato == "sit":
			sedute += 1
			entrata[chi] = t
		elif stato == "dismount":
			discese += 1
		if prima == "r_bench" or prima == "sit":
			if entrata.has(chi) and t - float(entrata[chi]) < 0.45 \
					and stato != "dismount":
				troncate += 1
			entrata.erase(chi)

	# LA LEVITAZIONE: un corpo che cammina col sedile ancora sotto. Se il
	# tween di montaggio finisce dopo che lo stato e' cambiato, l'ultimo a
	# scrivere `position.y` e' lui: 52 cm sopra l'erba, per sempre.
	var frame_a_mezzaria := 0
	var y_camminando := 0.0
	for c in campioni:
		if String(c[2]) != "walk":
			continue
		y_camminando = maxf(y_camminando, float(c[6]))
		if float(c[6]) > 0.1:
			frame_a_mezzaria += 1

	print("SALITE sulla panchina: %d      DISCESE: %d" % [sedute, discese])
	print("SALITE interrotte entro i 0,45 s del tween: %d" % troncate)
	print("LEVITAZIONE: %d frame in cammino con y > 0,10 (y max %.2f m)"
			% [frame_a_mezzaria, y_camminando])
	print("VELOCITA' MASSIMA: %.2f m/s" % v_max)
	print("SCIVOLI sopra %.1f m/s: %d" % [SOGLIA_SCIVOLO, scivoli.size()])
	var chiavi: Array = per_stato.keys()
	chiavi.sort_custom(func(a, b): return float(per_stato[a]) > float(per_stato[b]))
	print("--- velocita' massima per stato ---")
	for k in chiavi:
		if float(per_stato[k]) > 0.05:
			print("  %-12s %.2f m/s" % [k, float(per_stato[k])])
	if not scivoli.is_empty():
		print("--- i primi scivoli (durata in frame a 60 fps) ---")
		for i in mini(8, scivoli.size()):
			var s: Array = scivoli[i]
			print("  t=%6.2f  stato=%-18s v_max=%5.2f m/s  blend=%.2f  %d frame"
					% [s[0], s[2], s[1], s[3], s[4]])


func _rapporto_cavia(campioni: Array, chi: String, dopo: float) -> void:
	var v_max := 0.0
	var v_max_stato := ""
	var blend_al_max := 0.0
	var y_fine := 0.0
	var y_max := 0.0
	for c in campioni:
		if String(c[1]) != chi:
			continue
		if float(c[3]) > v_max:
			v_max = float(c[3])
			v_max_stato = String(c[2])
			blend_al_max = float(c[4])
		y_max = maxf(y_max, float(c[6]))
		y_fine = float(c[6])
	var esito := "SCIVOLA" if v_max > SOGLIA_SCIVOLO else "a passo d'uomo"
	print("  interrotta a %.2f s dal via | v_max %5.2f m/s (%s, blend %.2f)"
			% [dopo, v_max, v_max_stato, blend_al_max]
			+ " | y max %.2f, y finale %.2f | %s" % [y_max, y_fine, esito])
