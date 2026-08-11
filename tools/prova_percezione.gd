extends SceneTree
## LA RICEVUTA, GUARDATA CON GLI OCCHI — quello che la suite non può dire.
##
## `test_percezione.gd` prova che la testa si gira dalla parte giusta e che
## il canale torna a posto. Nessuna di quelle asserzioni sa dire la sola
## cosa che conta: **se la testa girata SI VEDE**. Se non si legge a occhio,
## tutta la Fase 4 è invisibile — le conseguenze arrivano senza premessa, e
## una conseguenza senza premessa non attenua l'effetto, lo inverte.
##
## Fa due cose:
##  1. IL PROVINO DELLA TARATURA — cinque chibi affiancati con la testa a
##     0.30 · 0.60 · 0.90 · 1.20 · 1.50 rad, di tre quarti E di profilo. È
##     così che si sceglie `Visitor.TESTA_MAX`, non indovinando un numero.
##  2. LA SCENA VERA — si apre il MainLevel, si insediano tre vicini (a 6 m,
##     a 20 m, dall'altra parte del prato) e si fa accadere un gesto
##     davvero, dal bus vero. Si fotografa DURANTE (la testa del vicino è
##     girata, quella del lontano no) e DOPO (tutti tornati ai fatti loro).
##
##   CHIBI_PERC=/dove Godot --path . --script res://tools/prova_percezione.gd

const TARATURE := [0.30, 0.60, 0.90, 1.20, 1.50]

var _cam: Camera3D = null
var _dove := ""


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _scatta(centro: Vector3, occhio: Vector3, nome: String) -> void:
	_cam.position = occhio
	_cam.look_at(centro, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(
			_dove.rstrip("/") + "/" + nome + ".jpg", 0.94)


func _cartello(padre: Node3D, testo: String, y: float) -> void:
	var l := Label3D.new()
	l.text = testo
	l.font_size = 64
	l.pixel_size = 0.0016
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 14
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.1, 0.08, 0.12)
	l.position = Vector3(0, y, 0)
	padre.add_child(l)


func _go() -> void:
	_dove = OS.get_environment("CHIBI_PERC")
	if _dove == "":
		_dove = "docs/catalogo/provini-percezione"
	DirAccess.make_dir_recursive_absolute(_dove)

	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 30:
		await process_frame

	var vis := _trova("visitors")
	var dn := _trova("daynight")
	var perc := _trova("percezione")
	print("Percezione in scena: ", perc != null)
	if vis == null or dn == null or perc == null:
		push_error("manca Visitors, DayNight o Percezione")
		quit(1)
		return
	dn.call("set_time", 0.42)     # mattina piena: luce che non nasconde niente
	for _i in 6:
		await process_frame

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.current = true
	root.add_child(_cam)

	var VS := load("res://scenes/npc/Visitor.gd")
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")

	# ------------------------------------------------ 1. IL PROVINO DELLA TARATURA
	var banco := Node3D.new()
	banco.position = Vector3(0, 0, 40)      # lontano dal villaggio, prato pulito
	root.add_child(banco)
	var pose: Array = []
	for k in TARATURE.size():
		var v = VS.new()
		v.dna = DNAG.generate(9100 + k * 13)
		banco.add_child(v)
		# IN DIAGONALE, non in fila: una fila si copre da sola appena si
		# gira intorno, e la prima stesura di questa prova ha dato un
		# «profilo» in cui i cinque erano uno dietro l'altro — cioè nessun
		# profilo. Di sbieco si vedono tutti da tutte e tre le parti.
		v.position = Vector3(float(k) * 1.45 - 2.9, 0, float(k) * 1.25 - 2.5)
		v.mode = "resident"
		v._enter_state("r_idle")
		v.set("_timer", 9999.0)
		v.set("_yaw", 0.0)                  # muso verso −Z: verso la camera
		pose.append(v)
		_cartello(v, "%.2f" % float(TARATURE[k]), 1.35)
	for _i in 40:
		await process_frame
	# posa CONGELATA: si spegne il `_process` e si scrive il canale a mano,
	# così i cinque si guardano fianco a fianco senza respirare a fasi diverse
	for k in pose.size():
		var v: Node3D = pose[k]
		v.set_process(false)
		var testa := v.get("_head") as Node3D
		if testa != null:
			testa.rotation.y = -float(TARATURE[k])   # verso la sua destra
	for _i in 4:
		await process_frame

	var c := banco.position + Vector3(0, 0.75, 0)
	await _scatta(c, c + Vector3(0, 1.9, -8.6), "0-taratura-fronte")
	await _scatta(c, c + Vector3(5.0, 1.9, -6.4), "0-taratura-trequarti")
	await _scatta(c, c + Vector3(8.6, 1.6, 0.6), "0-taratura-profilo")
	for v in pose:
		(v as Node).queue_free()
	banco.queue_free()
	for _i in 6:
		await process_frame

	# ------------------------------------------------ 2. LA SCENA VERA
	# il gesto succede qui; i tre vicini stanno a 6, a 20 e in capo al prato
	var gesto := Vector3(0, 0, 3.0)
	var posti := [
		{"nome": "vicino", "p": gesto + Vector3(4.2, 0, 4.3)},     # ~6 m
		{"nome": "lontano", "p": gesto + Vector3(14.0, 0, 14.0)},  # ~20 m
		{"nome": "altrove", "p": gesto + Vector3(-26.0, 0, 8.0)},
	]
	var residenti: Array = vis.get("_residents")
	var miei: Array = []
	for k in posti.size():
		var v = VS.new()
		v.dna = DNAG.generate(9200 + k * 29)
		vis.add_child(v)
		v.mode = "resident"
		v.position = (posti[k] as Dictionary)["p"]
		v._enter_state("r_idle")
		v.set("_timer", 9999.0)
		# IL CORPO GIRATO DI TRAVERSO, apposta e con un conto: il gesto deve
		# cadere a novanta gradi dal muso. Se guardassero già da quella parte
		# la testa girata non proverebbe niente; se ce l'avessero alle spalle
		# il collo si fermerebbe al suo tetto e non si capirebbe verso cosa.
		var verso_gesto := gesto - (posti[k] as Dictionary)["p"] as Vector3
		v.set("_yaw", atan2(-verso_gesto.x, -verso_gesto.z) + PI * 0.5)
		var r := {"node": v, "label": "Perc%d" % k, "dna": v.dna,
				"cell": Vector2i(60 + k, 0), "species": "chibi"}
		residenti.append(r)
		var b: RefCounted = vis.call("_ensure_brain", r)
		b.indole = []
		b.quirk = ""
		miei.append(r)
		for _i in 2:
			await process_frame
	# il censimento ECS: in partita lo fa `_ciclo_sonno`, qui lo si chiede
	vis.call("_ensure_ecs")
	for r in miei:
		vis.call("_ecs_id", r)
	var cuore = vis.get("_ecs")
	print("residenti di prova: ", miei.size(), "  cuore: ", cuore != null)

	# I CORPI VANNO TENUTI FERMI: la routine del villaggio li manda a
	# zonzo, e una prova che dipende da dove li coglie non è una prova.
	for r in miei:
		var n := (r as Dictionary)["node"] as Node3D
		n.set("_timer", 9999.0)

	# IL GESTO, dal bus vero
	perc.call("accaduto", "annaffia", gesto)
	for _i in 18:
		await process_frame
		for r in miei:
			var n := (r as Dictionary)["node"] as Node3D
			n.set("_timer", 9999.0)

	for r in miei:
		var rr := r as Dictionary
		var n := rr["node"] as Node3D
		var testa := n.get("_head") as Node3D
		var g: Dictionary = cuore.call("debug_grafo", int(rr["ecs"]))
		print("%-8s  d=%.1f m  testa.y=%+.3f  ricordi=%d" % [
				str(rr["label"]), gesto.distance_to(n.global_position),
				(testa.rotation.y if testa else 0.0),
				(g.get("ricordi", []) as Array).size()])

	var perno: Node3D = (miei[0] as Dictionary)["node"]
	# la camera DAVANTI AL CORPO: si vede il petto di fronte e la testa
	# girata di lato, che è la lettura più chiara che questa posa abbia
	var avanti := Vector3(-sin(perno.rotation.y), 0, -cos(perno.rotation.y))
	var cc := perno.global_position + Vector3(0, 0.62, 0)
	await _scatta(cc, cc + avanti * 3.6 + Vector3(0, 0.75, 0), "1-ricevuta-fronte")
	await _scatta(cc, cc + (avanti * 3.0).rotated(Vector3.UP, 0.9) + Vector3(0, 0.8, 0),
			"1-ricevuta-trequarti")
	await _scatta(cc, cc + (avanti * 3.0).rotated(Vector3.UP, PI * 0.5) + Vector3(0, 0.55, 0),
			"1-ricevuta-profilo")
	# il quadro largo: il vicino guarda, il lontano no
	var largo := gesto + Vector3(0, 0.8, 0)
	await _scatta(largo, largo + Vector3(9.0, 7.0, 14.0), "1-ricevuta-quadro")

	# …e DOPO: lo sguardo è scaduto, tutti ai fatti loro
	for _i in 260:
		await process_frame
		for r in miei:
			var n := (r as Dictionary)["node"] as Node3D
			n.set("_timer", 9999.0)
	for r in miei:
		var rr := r as Dictionary
		var n := rr["node"] as Node3D
		var testa := n.get("_head") as Node3D
		print("dopo   %-8s  testa.y=%+.3f  scostamento=%+.4f" % [
				str(rr["label"]), (testa.rotation.y if testa else 0.0),
				float(n.get("_tst_off"))])
	cc = perno.global_position + Vector3(0, 0.62, 0)
	await _scatta(cc, cc + avanti * 3.6 + Vector3(0, 0.75, 0), "2-dopo-fronte")

	print("PERCEZIONE -> ", _dove)
	quit()
