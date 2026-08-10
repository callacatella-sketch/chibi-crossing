extends SceneTree
## LA SCENA DELLA FASE 3, nel MainLevel VERO.
##
##   Godot --headless --path . --script res://tools/prova_recinto.gd
##
## La suite prova il risolutore su stati inventati, e il ponte su liste
## costruite a mano. Questo prova la cosa vera, che nessuna delle due può
## provare: che in partita, con il BuildSystem vero e un vicino vero, la
## staccionata cambi la storia.
##
## Si fa due volte lo stesso gesto e si guarda la differenza:
##
##   1. c'è un cespuglio, il vicino ha fame → va al cespuglio;
##   2. il giocatore chiude il cespuglio in un recinto → lo stesso vicino,
##      con la stessa fame e lo stesso cespuglio, va alla Lavagna e
##      appende un biglietto per Mochi.
##
## Non si guarda una variabile interna del pianificatore: si guarda cosa
## FA il corpo, e se sulla lavagna compare un biglietto. È l'unica prova
## che conta, perché è quella che vede chi gioca.

const CASA := Vector2i(6, 6)
const CESPUGLIO := Vector2i(3, 6)
const LAVAGNA := Vector2i(10, 6)

var _guasti := 0


func _init() -> void:
	_go()


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok   " if ok else "  GUASTO ") + testo)


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	var commissioni := livello.get_node_or_null("Commissioni")
	if build == null or visitors == null or commissioni == null:
		print("GUASTO: BuildSystem=%s Visitors=%s Commissioni=%s"
				% [build, visitors, commissioni])
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout

	# ------------------------------------------------------- il villaggio
	visitors.call("debug_reset")
	build.call("place_cell", CASA, "Letto", 0, false)
	build.call("place_cell", CASA, "Tetto", 0, false)
	build.call("place_cell", LAVAGNA, "Lavagna", 0, false)
	build.call("place_cell", CESPUGLIO, "Cespuglio", 0, false)
	build.call("aggiorna_varchi_ora")
	visitors.call("debug_settle", 4242, CASA)
	await create_timer(0.8).timeout

	var residenti: Array = visitors.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente (il letto non ha fatto casa)")
		quit(1)
		return
	var r: Dictionary = residenti[0]
	var chi := str(r.get("label", "?"))
	var corpo: Node3D = r["node"]
	print("\n=== IL VICINO: %s, casa in %s ===" % [chi, CASA])

	# ------------------------------------------- 1) prato aperto: si mangia
	print("\n--- 1) il cespuglio è lì, e ci si arriva ---")
	_dico(bool(build.call("raggiungibile", CASA, CESPUGLIO)),
			"il BuildSystem dice che al cespuglio ci si arriva")
	var partita: bool = visitors.call("debug_force_activity", 0, "spuntino")
	_dico(partita, "la scena è partita")
	await create_timer(0.6).timeout
	var meta1 := _dove_va(corpo)
	print("       va verso %s (stato «%s»)" % [meta1, corpo.get("_state")])
	_dico(meta1.distance_to(Vector3(CESPUGLIO.x, 0, CESPUGLIO.y)) < 2.0,
			"e cammina verso il CESPUGLIO")
	# il salvataggio può già avere biglietti di altri: si guarda SOLO i suoi
	_dico(not bool(commissioni.call("ha_richiesta_di", chi)),
			"e non ha chiesto niente a nessuno")

	# --------------------------------- 2) il giocatore chiude il recinto
	print("\n--- 2) il giocatore chiude il cespuglio in un recinto ---")
	visitors.call("debug_force_activity", 0, "gironzola")
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		build.call("place_edge", CESPUGLIO * 2 + d, "Staccionata", false, false)
	build.call("aggiorna_varchi_ora")
	_dico(not bool(build.call("raggiungibile", CASA, CESPUGLIO)),
			"adesso al cespuglio NON ci si arriva più")
	_dico(bool(build.call("raggiungibile", CASA, LAVAGNA)),
			"ma alla Lavagna sì")

	await create_timer(0.5).timeout
	partita = visitors.call("debug_force_activity", 0, "spuntino")
	_dico(partita, "la stessa fame, lo stesso gesto: la scena riparte")
	await create_timer(0.6).timeout
	var meta2 := _dove_va(corpo)
	print("       va verso %s (stato «%s»)" % [meta2, corpo.get("_state")])
	_dico(meta2.distance_to(Vector3(LAVAGNA.x, 0, LAVAGNA.y)) < 2.5,
			"e adesso cammina verso la LAVAGNA")

	# il biglietto compare quando il gessetto si ferma, non prima
	_dico(not bool(commissioni.call("ha_richiesta_di", chi)),
			"mentre cammina non c'è ancora nessun biglietto suo")
	var prima := int(commissioni.call("quante"))
	var atteso := 0.0
	while atteso < 20.0 and not bool(commissioni.call("ha_richiesta_di", chi)):
		await create_timer(0.5).timeout
		atteso += 0.5
	_dico(bool(commissioni.call("ha_richiesta_di", chi)),
			"e dopo %.1f s ha appeso il SUO biglietto" % atteso)
	_dico(int(commissioni.call("quante")) == prima + 1,
			"uno solo, e senza toccare quelli degli altri")
	for riga in commissioni.call("debug_stato"):
		print("       📌 %s" % riga)

	# ------------------------------------ 3) e non ne scrive un secondo
	print("\n--- 3) e non passa la giornata a chiedere ---")
	var quanti := int(commissioni.call("quante"))
	visitors.call("debug_force_activity", 0, "spuntino")
	await create_timer(1.5).timeout
	_dico(int(commissioni.call("quante")) == quanti,
			"con un biglietto già appeso non ne scrive un altro")
	print("       stato: «%s»" % corpo.get("_state"))

	# ------------------------------------------ 4) tolta una staccionata
	print("\n--- 4) il giocatore riapre il recinto ---")
	build.call("debug_remove_edge", CESPUGLIO * 2 + Vector2i(-1, 0))
	build.call("aggiorna_varchi_ora")
	_dico(bool(build.call("raggiungibile", CASA, CESPUGLIO)),
			"tolta una staccionata, al cespuglio ci si torna")

	print("\n==== RECINTO: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)


## Dove sta andando il corpo: la meta del cammino se ne ha una, altrimenti
## dov'è adesso.
func _dove_va(corpo: Node3D) -> Vector3:
	var t = corpo.get("_target")
	if t is Vector3 and (t as Vector3) != Vector3.ZERO:
		return Vector3((t as Vector3).x, 0, (t as Vector3).z)
	return Vector3(corpo.global_position.x, 0, corpo.global_position.z)
