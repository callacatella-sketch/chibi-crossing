extends SceneTree
## Il cuoricino esiste ancora? Villaggio VERO, gesto gentile VERO, e poi
## Mochi che arriva piano. Nessuna scorciatoia: si passa da `gesto_gentile`,
## che è la porta dei piatti, delle feste e dell'accompagnare.
func _init() -> void:
	_go()

func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	var build := liv.get_node_or_null("BuildSystem")
	var vis := liv.get_node_or_null("Visitors")
	var player := liv.get_node_or_null("Player") as Node3D
	var dn := liv.get_node_or_null("DayNight")
	build.call("set_persist_for_debug", false)
	dn.set("cycle_seconds", 1000000.0)
	dn.set("time", 0.42)
	await create_timer(1.2).timeout
	vis.call("debug_reset")
	var cella := Vector2i(2, 2)
	build.call("place_cell", cella, "Letto", 0, false)
	build.call("place_cell", cella, "Tetto", 0, false)
	build.call("aggiorna_varchi_ora")
	vis.call("debug_settle", 5150, cella)
	await create_timer(1.5).timeout
	var residenti: Array = vis.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente"); quit(1); return
	var r: Dictionary = residenti[0]
	var label := str(r["label"])
	var corpo := r.get("node") as Node3D
	vis.call("debug_stage_resident", 0, Vector3(cella.x, 0, cella.y))
	await create_timer(0.8).timeout
	var animi: Dictionary = vis.get("_animi")
	var lim: RefCounted = (animi[label] as RefCounted).limbico
	print("PRIMA del regalo: marchio su di te = %.3f" % lim.carica_di("", "giocatore"))
	# LA PORTA VERA: un piatto, come quello che il giocatore cucina e regala
	vis.call("gesto_gentile", label, "piatto", 0.85)
	print("DOPO il regalo:   marchio su di te = %.3f" % lim.carica_di("", "giocatore"))
	# …e adesso Mochi gli si avvicina, PIANO (niente di brusco)
	player.global_position = corpo.global_position + Vector3(0, 0, 2.5)
	vis.set("_pp_prec", player.global_position)
	vis.set("_sussulto_cd", {})
	vis.call("_tick_sussulti", 1.0 / 60.0)
	var s: Dictionary = lim.ultimo_sussulto
	print("il corpo dice: %s (forza d'allarme %.3f · calore %.3f)"
			% [str(s["reazione"]), float(s["forza"]), float(s["calore"])])
	print("il corpo sta:  «%s»" % lim.stato_corpo())
	print("postura sul nodo: %s · coda somatica: %.3f"
			% [str(corpo.get_meta("postura", "-")), float(corpo.get("_gs_soma"))])
	quit(0)
