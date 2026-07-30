extends SceneTree
## USA E GETTA — la verifica VIVA del salvataggio di prova.
##
## Carica il MainLevel vero col villaggio generato, spegne subito la scrittura
## sul salvataggio (cosi la prova non riscrive il file), e poi chiede al gioco
## le tre cose che contano: quanti pezzi ha caricato, quante case libere vede, e
## se un candidato che arriva davanti alla porta accetta o riparte col trolley.
##
##   Godot --headless --path . --script res://tools/prova_arrivi.gd
##
## Il conto delle feature lo fa il gioco, non io: e questo che distingue una
## verifica da un augurio.

var _fase := 0
var _fatto := false


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	# il MainLevel costruisce il mondo in differita: gli si da tempo
	for i in 6:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si e caricato")
		quit(1)
		return

	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	if build == null or visitors == null:
		print("GUASTO: BuildSystem=%s Visitors=%s" % [build, visitors])
		quit(1)
		return

	# PRIMA di ogni altra cosa: niente scritture sul salvataggio
	build.call("set_persist_for_debug", false)
	print("persistenza: spenta")

	await create_timer(1.5).timeout

	var pezzi: int = build.call("piece_count") if build.has_method("piece_count") else -1
	var letti: Array = build.call("get_placed_by_name", "Letto")
	var coperti := 0
	for letto in letti:
		var cella := Vector2i(roundi(letto.position.x), roundi(letto.position.z))
		if build.call("has_cover", cella):
			coperti += 1
	print("PEZZI: ", pezzi)
	print("LETTI: ", letti.size(), "  di cui con copertura: ", coperti)
	print("CASA LIBERA: ", visitors.call("has_free_house"))
	print("RESIDENTI INIZIALI: ", int(visitors.get("_residents").size()))

	# e adesso la domanda vera: uno che arriva, si trasferisce?
	var prima := int(visitors.get("_residents").size())
	var arrivati := 0
	for i in 4:
		if not bool(visitors.call("has_free_house")):
			break
		visitors.call("debug_candidate", 1000 + i * 37)
		await process_frame
		visitors.call("debug_goto_wait")
		await process_frame
		visitors.call("debug_force_decide")
		await create_timer(0.35).timeout
		var ora := int(visitors.get("_residents").size())
		if ora > prima:
			arrivati += 1
		prima = ora
	print("ARRIVI RIUSCITI: ", arrivati, " su 4 tentativi")
	print("RESIDENTI DOPO: ", int(visitors.get("_residents").size()))
	print("CASA LIBERA DOPO: ", visitors.call("has_free_house"))

	var esito := 0
	if pezzi <= 0 or letti.size() == 0 or coperti != letti.size() or arrivati < 4:
		esito = 1
		print("ESITO: QUALCOSA NON TORNA")
	else:
		print("ESITO: TUTTO A POSTO")
	quit(esito)
