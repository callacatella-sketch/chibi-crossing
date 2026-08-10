extends SceneTree
## IL CREPUSCOLO, NEL VILLAGGIO VERO — la prova che la suite non può dare.
##
## `test_ecs_mondo.gd` prova la regola, `test_sonno_residenti.gd` prova il
## cablaggio su nodi montati a mano. Questo apre il MainLevel VERO, ci
## insedia dei vicini, porta l'orologio al tramonto e GUARDA: chi rientra
## sparisce dentro casa, e chi non poteva entrare resta fuori.
##
## Serve anche a una cosa che nessun test headless vede: che `EcsMondo`
## nasca davvero dentro la scena vera (il nodo «CuoreSonno» sotto Visitors),
## che il ponte regga a 60 frame al secondo con la partita intera addosso, e
## che non compaia un solo errore nel registro.
##
##   CHIBI_SONNO=/dove Godot --path . --script res://tools/prova_sonno_ecs.gd

## le tre ore che raccontano la storia: giorno pieno, notte, mattino
const MOMENTI := [
	{"nome": "1-pomeriggio", "ora": 0.55},
	{"nome": "2-sera", "ora": 0.86},
	{"nome": "3-mattino", "ora": 0.40},
]

var _cam: Camera3D = null


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _scatta(centro: Vector3, dist: float, dove: String) -> void:
	_cam.position = centro + Vector3(0.7, 0.55, 0.7).normalized() * dist
	_cam.look_at(centro, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(dove, 0.92)


func _go() -> void:
	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 24:
		await process_frame

	var vis := _trova("visitors")
	var dn := _trova("daynight")
	if vis == null or dn == null:
		push_error("manca Visitors o DayNight")
		quit(1)
		return

	# IL NODO C'È? È la prima cosa da vedere: se la GDExtension non fosse
	# caricata, `_ensure_ecs` avrebbe solo stampato un errore e i vicini non
	# dormirebbero mai — un guasto che di notte si nota e di giorno no.
	dn.call("set_time", 0.55)
	for _i in 4:
		await process_frame
	var cuore := vis.get_node_or_null("CuoreSonno")
	print("CuoreSonno in scena: ", cuore != null,
			"  (classe ", (cuore.get_class() if cuore else "-"), ")")
	if cuore == null:
		push_error("EcsMondo non è nato nella scena vera")

	var dove := OS.get_environment("CHIBI_SONNO")
	if dove == "":
		dove = "docs/catalogo/provini-sonno"
	DirAccess.make_dir_recursive_absolute(dove)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam.current = true
	root.add_child(_cam)

	# SI INSEDIANO I VICINI A MANO, e non con `debug_candidate`: un arrivo
	# vero pretende una casa libera (un Letto con la sua copertura) e la
	# accetta solo se supera 0.72 di gradimento — in un villaggio appena
	# nato non ce n'è nessuna, e infatti si insediavano in zero. Il
	# salvataggio di prova ne avrebbe dieci, ma è il file dell'AUTORE: una
	# prova non ci mette le mani.
	# Qui si costruiscono corpi VERI (gli stessi Visitor del gioco) e si
	# infilano nel registro dei residenti: da lì in poi è il `_process` vero
	# di Visitors a farli vivere, ed è quello che si vuole guardare.
	var VS := load("res://scenes/npc/Visitor.gd")
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")
	var residenti: Array = vis.get("_residents")
	for k in 3:
		var v = VS.new()
		v.dna = DNAG.generate(7000 + k * 31)
		vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(k) * 1.6 - 1.6, 0, 2.0)
		v._enter_state("r_idle")
		residenti.append({"node": v, "label": "Prova%d" % k, "dna": v.dna,
				"cell": Vector2i(k, 0), "species": "chibi"})
		var b: RefCounted = vis.call("_ensure_brain", residenti[k])
		# niente indole e niente quirk: la finestra è quella base (0.80),
		# se no un «sognatore» va a letto alle 0.92 e la foto delle 0.86 lo
		# mostra ancora in piedi — giustissimo, ma illeggibile in una prova
		b.indole = []
		b.quirk = ""
		for _i in 2:
			await process_frame
	print("residenti insediati: ", residenti.size())

	var centro := Vector3(0, 1.0, 0)
	if residenti.size() > 0:
		var n0 := (residenti[0] as Dictionary).get("node") as Node3D
		if n0 != null and is_instance_valid(n0):
			centro = n0.global_position + Vector3(0, 0.8, 0)

	for m in MOMENTI:
		dn.call("set_time", float(m["ora"]))
		# LA SERA DEVE PASSARE DAVVERO. Novanta frame sono un secondo e mezzo:
		# in un villaggio VIVO la routine manda i vicini a fare qualcosa
		# (`walk`, `lp_sniff`) e il registro — giustamente — non strappa a
		# letto chi ha il corpo occupato. Con un secondo e mezzo la prova
		# dipendeva da dove li coglieva, e infatti ha dato 3/3 una volta e
		# 0/3 la volta dopo. Dieci secondi bastano perché finiscano quel che
		# stavano facendo e tornino interrompibili.
		for _i in 600:
			await process_frame
		var dormono := 0
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n != null and is_instance_valid(n) and bool(n.call("is_hidden")):
				dormono += 1
		print("%-12s ora %.2f · dormono %d/%d" % [str(m["nome"]),
				float(m["ora"]), dormono, residenti.size()])
		for r in residenti:
			var rr := r as Dictionary
			var nn := rr.get("node") as Node3D
			var ecs = vis.get("_ecs")
			print("   sonda: state=", (nn.get("_state") if nn else "-"),
					" ecs=", (ecs.stato(int(rr["ecs"])) if (ecs and rr.has("ecs")) else "?"),
					" finestra=", (ecs.in_finestra(int(rr["ecs"])) if (ecs and rr.has("ecs")) else "?"),
					" dbg=", (ecs.debug_entita(int(rr["ecs"])) if (ecs and rr.has("ecs")) else "?"))
		await _scatta(centro, 7.0, dove.rstrip("/") + "/" + str(m["nome"]) + ".jpg")

	print("SONNO ECS -> ", dove)
	quit()
