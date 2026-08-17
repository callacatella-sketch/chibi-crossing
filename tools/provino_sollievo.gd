extends SceneTree
## «AH… SEI TU» — la pellicola del sollievo, nel MONDO VERO.
##
##   CHIBI_SOLLIEVO=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 900x600 --script res://tools/provino_sollievo.gd
##
## La suite non dice NIENTE sulla resa, e questo gesto è l'unico del
## vocabolario che si recita da fermo, in faccia al giocatore, a meno di tre
## metri: se non si legge lì, non si legge da nessuna parte.
##
## ⚠️ **NON SI SPARA IL GESTO A MANO.** Il giocatore vero si avvicina, il
## corpo sussulta (`Limbico.percepisci`, la strada veloce), e quattro decimi
## di secondo dopo la testa capisce (`rivaluta`, la strada lenta) e il corpo
## si scioglie. Qui si muove SOLO il giocatore, e tutto il resto è il gioco:
## se il cablaggio non ci fosse, questa pellicola sarebbe un chibi fermo.
##
## Tre strisce, perché un movimento non si giudica in una posa:
##   1. di TRE QUARTI, che è come lo si vede passando;
##   2. di PROFILO, dove si smascherano i trucchi (la salita è verticale: di
##      profilo o si vede o non c'è);
##   3. di SPALLE, l'inquadratura che oggi non dice niente — qui il corpo
##      sale, e la salita non ha l'ambiguità dell'imbardata.

const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

var _dove := ""
var _cam: Camera3D = null


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_SOLLIEVO")
	if _dove == "":
		_dove = "/tmp/sollievo"
	DirAccess.make_dir_recursive_absolute(_dove)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	var build := liv.get_node_or_null("BuildSystem")
	var vis := liv.get_node_or_null("Visitors")
	var player := liv.get_node_or_null("Player") as Node3D
	var dn := liv.get_node_or_null("DayNight")
	if build == null or vis == null or player == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	# l'orologio si ferma a metà pomeriggio: un giorno dura quattro minuti, e
	# un vicino che va a dormire si rimpicciolisce a scala 0.03
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.0).timeout

	vis.call("debug_reset")
	var cella := Vector2i(2, 2)
	build.call("place_cell", cella, "Letto", 0, false)
	build.call("place_cell", cella, "Tetto", 0, false)
	build.call("aggiorna_varchi_ora")
	vis.call("debug_settle", 5150, cella)
	await create_timer(1.5).timeout
	var residenti: Array = vis.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	var r: Dictionary = residenti[0]
	var label := str(r.get("label", ""))
	var corpo := r.get("node") as Node3D
	vis.call("debug_stage_resident", 0, Vector3(cella.x, 0, cella.y))
	# CHI TI VUOLE BENE: la strada lenta torna un sentito positivo solo se
	# l'amicizia è vera (`_tick_riconoscimenti`)
	r["friend"] = 4
	await create_timer(0.8).timeout

	_cam = Camera3D.new()
	liv.add_child(_cam)
	_cam.current = true
	_cam.fov = 50.0

	# IL GIOCATORE ARRIVA. Svelto e addosso: è `indizio_grezzo` — qualcosa di
	# grosso che si muove veloce, vicino — e non c'è nessun altro modo di far
	# sussultare qualcuno in questo gioco.
	print("il vicino: %s a %s" % [label, str(corpo.global_position)])
	player.global_position = corpo.global_position + Vector3(0, 0, 6.0)
	await create_timer(0.4).timeout

	var t := 0.0
	var scattati := 0
	var soglie: Array = [0.0, 0.20, 0.40, 0.52, 0.64, 0.80, 1.10, 1.60, 2.20]
	var sussultato := false
	var t_sussulto := -1.0
	var righe: Array = []
	var indietro := false
	# ⚠️ **ALLA VELOCITÀ DI CORSA, e a giri.** La strada veloce del Limbico
	# guarda COME arrivi (`indizio_grezzo`: niente di brusco sotto 1,6 m/s) e
	# quanto sei reattivo (`Limbico.reattivita`, dal carattere: 0,2–1,8). Un
	# avvicinamento a 3,4 m/s dà forza 0,17 contro una soglia di 0,22 —
	# misurato, **nessun sussulto in sei secondi**, e il provino dichiarava
	# un silenzio che era suo. Si corre (6,0 m/s, `PlayerController.run_speed`)
	# e si fanno più giri finché il corpo non salta davvero.
	var corsa: float = float(player.get("run_speed"))
	if corsa <= 0.0:
		corsa = 6.0
	# ⚠️ **IL PASSO È L'OROLOGIO DA POLSO, non 1/60.** `Visitors._tick_sussulti`
	# ricava la velocità del giocatore dallo SPOSTAMENTO fra due suoi tick,
	# divisa per il delta VERO del fotogramma. Muovendo Mochi di `6.0/60` m
	# per fotogramma mentre la scena ne disegna venticinque al secondo, il
	# gioco misura 2,5 m/s invece di 6 — sotto la soglia del brusco, e
	# nessuno sussulta mai. È la stessa trappola di `prova_villaggio_gesti`:
	# una misura che non sa che ora è non misura niente.
	var ms := Time.get_ticks_msec()
	while t < 40.0:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		# giri: addosso, via, addosso — finché non salta
		var d := player.global_position.distance_to(corpo.global_position)
		if not sussultato:
			if d < 1.2:
				indietro = true
			elif d > 7.0:
				indietro = false
			var v := (corpo.global_position - player.global_position)
			v.y = 0.0
			if v.length() > 0.01:
				player.global_position += v.normalized() * corsa * dt \
						* (-1.0 if indietro else 1.0)
		elif d > 2.0:
			var v2 := (corpo.global_position - player.global_position)
			v2.y = 0.0
			player.global_position += v2.normalized() * 2.0 * dt
		if not sussultato and fposmod(t, 2.0) < dt:
			var an: Dictionary = (vis.get("_animi") as Dictionary)
			if an.has(label):
				print("  t=%.1f d=%.1f  ultimo sussulto: %s"
						% [t, d, str((an[label] as RefCounted).limbico.ultimo_sussulto)])
		# ⚠️ il SUSSULTO non si legge dal meta `postura`: `_recita_applica` lo
		# CONSUMA nel fotogramma in cui lo trova, e una sonda che guarda il
		# meta lo vede solo se cade esattamente in mezzo. Lo stato vero è
		# `_rc_trans`, che dura quanto il transitorio (1,3 s).
		if not sussultato and str(corpo.get("_rc_trans")) == "trasalisce":
			sussultato = true
			t_sussulto = t
			print("SUSSULTO a %.2f s" % t)
		if t_sussulto < 0.0:
			continue
		var dts := t - t_sussulto
		righe.append("%6.2f  gesto=%-8s vy=%+.4f sy=%.4f soma=%.2f/%.2f trans=%-12s spegni=%.2f fresco=%s stato=%-10s libero=%-5s scena=%s"
				% [dts, str(corpo.call("gesto_in_corso")),
				(corpo.get("_gs_cur") as Dictionary).get("vy", 0.0),
				(corpo.get("_gs_cur") as Dictionary).get("sy", 1.0),
				float(corpo.get("_gs_soma")), float(corpo.get("_gs_soma_t")),
				str(corpo.get("_rc_trans")), float(corpo.get("_gs_spegni")),
				str(corpo.call("_sussulto_fresco")), str(corpo.get("_state")), str(corpo.call("gesto_libero", true)), str(corpo.call("in_scena"))])
		if scattati < soglie.size() and dts >= float(soglie[scattati]):
			await _striscia(corpo, "%02d_t%03d" % [scattati, int(dts * 100.0)])
			scattati += 1

	print("")
	print("LA PELLICOLA, fotogramma per fotogramma (t = dal sussulto):")
	for i in mini(righe.size(), 150):
		print("  " + str(righe[i]))
	print("")
	print("I NO DELL'USCIERE: %s" % str(vis.call("debug_gesti_contatori")))
	print("scatti in %s" % _dove)
	quit(0)


## Tre inquadrature dello stesso istante. Le distanze sono quelle vere: la
## camera del gioco sta a 2,70 m sopra Mochi e 3,70 dietro, e questo gesto
## si guarda da lì — non da un metro dal muso.
func _striscia(corpo: Node3D, nome: String) -> void:
	var p: Vector3 = corpo.global_position
	var yaw: float = float(corpo.get("_yaw"))
	var viste := {
		"trequarti": yaw + PI * 0.75,
		"profilo": yaw + PI * 0.5,
		"spalle": yaw,
	}
	for v in viste:
		var a: float = viste[v]
		_cam.global_position = p + Vector3(sin(a) * 3.7, 2.7, cos(a) * 3.7)
		_cam.look_at(p + Vector3(0, 0.55, 0), Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_jpg("%s/%s_%s.jpg" % [_dove.rstrip("/"), nome, v], 0.93)
