extends Node
## Harness di verifica/screenshot da riga di comando (estratto da MainLevel.gd).
##
## NON fa parte del gameplay: MainLevel lo istanzia come nodo figlio solo quando
## rileva le env var CHIBI_SHOT (salva screenshot) o CHIBI_MAKESAVE (crea un
## salvataggio), poi chiama run(). Tutti gli @onready/$ del vecchio codice sono
## rimappati sul MainLevel passato in run() come `_level`.

const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")
const CHIBI_BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")

var _level: Node3D
var player
var build_system
var interactions


func run(level: Node3D, mode: String, arg: String = "") -> void:
	_level = level
	player = level.player
	build_system = level.build_system
	interactions = level.interactions
	match mode:
		"shot":
			await _debug_screenshots(arg)
		"makesave":
			await _make_save()

func _frames(n: int):
	for i in n:
		await get_tree().process_frame

func _shot(dir: String, file: String):
	await _frames(2)
	get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))

func _debug_screenshots(dir: String):
	var mochi = player.get_node_or_null("Mochi")
	var player_cam: Camera3D = player.get_node("CameraPivot/Camera3D")

	# stato audio: l'autoload c'è? i suoni sono stati sintetizzati?
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx == null:
		printerr("AUDIO: autoload /root/Sfx MANCANTE")
	else:
		print("AUDIO: ok, %d effetti sintetizzati" % sfx.sound_count())
		sfx.place_ok()

	await get_tree().create_timer(1.4).timeout

	# 1. vista del mondo
	var vista_cam := Camera3D.new()
	add_child(vista_cam)
	vista_cam.position = Vector3(-7.0, 4.6, 10.0)
	vista_cam.fov = 50.0
	vista_cam.current = true
	vista_cam.look_at(Vector3(0.0, 1.0, -1.0))
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "cozy_vista")

	# 2. camminata (camera di gioco)
	player_cam.make_current()
	Input.action_press("ui_right")
	await get_tree().create_timer(0.85).timeout
	await _shot(dir, "mochi_walk")

	# 2b. la coda che scodinzola: tre quarti da dietro, in cammino
	var codacam := Camera3D.new()
	add_child(codacam)
	codacam.position = player.global_position + Vector3(-1.5, 0.85, 1.6)
	codacam.fov = 42.0
	codacam.current = true
	codacam.look_at(player.global_position + Vector3(0.65, 0.45, -0.25))
	await get_tree().create_timer(0.35).timeout
	await _shot(dir, "mochi_coda")
	player_cam.make_current()

	# 3. corsa: gli occhi diventano ">.<" — camera davanti a lei
	Input.action_press("ui_accept")
	await get_tree().create_timer(0.7).timeout
	var rcam := Camera3D.new()
	add_child(rcam)
	rcam.position = player.global_position + Vector3(2.1, 0.85, 1.3)
	rcam.fov = 40.0
	rcam.current = true
	rcam.look_at(player.global_position + Vector3(0.6, 0.65, 0))
	await _shot(dir, "mochi_run")
	Input.action_release("ui_accept")
	Input.action_release("ui_right")
	player_cam.make_current()

	# 4. primo piano di Mochi (prima che la demo del builder occupi la scena)
	if mochi:
		await get_tree().create_timer(1.2).timeout
		mochi.set("_next_blink", 10.0)   # niente palpebre a metà nello scatto
		var fwd: Vector3 = -mochi.global_transform.basis.z
		var focus: Vector3 = player.global_position + Vector3(0, 0.78, 0)
		var ccam := Camera3D.new()
		add_child(ccam)
		ccam.position = focus + fwd * 2.4 + Vector3(0, 0.35, 0)
		ccam.fov = 40.0
		ccam.current = true
		ccam.look_at(focus)
		await get_tree().create_timer(0.25).timeout
		await _shot(dir, "mochi_closeup")

	# 5. il builder: una casetta demo costruita col sistema vero (col tetto)
	_demo_build()
	build_system.set_active_for_debug(true, Vector3(1, 0, 4), "Pianta")
	var bcam := Camera3D.new()
	add_child(bcam)
	bcam.position = Vector3(0.2, 8.2, 8.6)
	bcam.fov = 42.0
	bcam.current = true
	bcam.look_at(Vector3(4.2, 0.0, 1.2))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "mochi_builder")

	# 5b. la verticalità: la scala esterna e il secondo piano
	build_system.set_active_for_debug(false, Vector3(1, 0, 4))
	player.global_position = Vector3(6.5, 0, 1.0)
	var upcam := Camera3D.new()
	add_child(upcam)
	upcam.position = Vector3(9.0, 3.2, 5.4)
	upcam.fov = 46.0
	upcam.current = true
	upcam.look_at(Vector3(4.6, 1.6, 0.8))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "piano_scala")

	# 5b2. l'arrampicata: mano-sopra-mano sui pioli, corpo alla scala
	var scale_nodes: Array = build_system.get_placed_by_name("Scala")
	if not scale_nodes.is_empty():
		var sc_pos: Vector3 = (scale_nodes[0] as Node3D).global_position
		player.global_position = sc_pos + Vector3(0, 1.05, 0.15)
		mochi.call("debug_climb", true)
		var clcam := Camera3D.new()
		add_child(clcam)
		clcam.position = sc_pos + Vector3(1.9, 1.6, 2.1)
		clcam.fov = 44.0
		clcam.current = true
		clcam.look_at(sc_pos + Vector3(0, 1.2, 0))
		await get_tree().create_timer(0.55).timeout
		await _shot(dir, "scala_arrampicata")
		mochi.call("debug_climb", false)

	# 5c. Mochi sul balconcino del piano di sopra
	player.global_position = Vector3(5.0, 2.4, 1.0)
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "piano_su")

	# 5d. sul ponticello di corda, verso il belvedere
	player.global_position = Vector3(6.0, 2.4, 2.0)
	var bridgecam := Camera3D.new()
	add_child(bridgecam)
	bridgecam.position = Vector3(6.1, 3.7, 5.4)
	bridgecam.fov = 45.0
	bridgecam.current = true
	bridgecam.look_at(Vector3(6.5, 2.1, 1.7))
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "ponticello")

	# 5e. il Grande Albero, cresciuto come al giorno 26, coi segni incisi
	var gtree: Node3D = get_tree().get_first_node_in_group("grande_albero")
	gtree.debug_showcase(26)
	player.global_position = Vector3(-2.7, 0, -0.7)
	var gcam3 := Camera3D.new()
	add_child(gcam3)
	gcam3.position = Vector3(2.4, 4.4, 4.4)
	gcam3.fov = 52.0
	gcam3.current = true
	gcam3.look_at(Vector3(-4.0, 3.4, -2.0))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "grande_albero")

	# 5f. gli anelli: la cronaca del villaggio su carta crema
	gtree.debug_open()
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "grande_albero_anelli")
	gtree.debug_close()

	# 5g. co-op sul divano: l'amico IJKL annaffia il giardino con Mochi
	var coop: Node = get_tree().get_first_node_in_group("coop")
	player.global_position = Vector3(0.4, 0, 5.2)
	player.get_node("Mochi").set("_yaw", 0.5)
	coop.debug_join(4242, Vector3(1.7, 0, 5.0))
	var garden2: Node = _level.get_node(^"Garden")
	garden2.debug_plant()
	await get_tree().create_timer(0.8).timeout
	coop.debug_help()
	var ccam := Camera3D.new()
	add_child(ccam)
	ccam.position = Vector3(1.2, 1.7, 7.4)
	ccam.fov = 46.0
	ccam.current = true
	ccam.look_at(Vector3(1.0, 0.45, 4.4))
	await get_tree().create_timer(0.9).timeout
	await _shot(dir, "coop_giardino")
	coop.call("_leave")
	await get_tree().create_timer(0.6).timeout

	# 5h. il timelapse dei ricordi: tre mattine e il proiettore
	var memories: Node = get_tree().get_first_node_in_group("ricordi")
	await memories.debug_capture(1)
	await memories.debug_capture(2)
	await memories.debug_capture(3)
	memories.debug_film()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "ricordi_film")
	memories.call("_stop_film")

	# 5i. il guardaroba di Mochi: i ricordi indossabili
	var wardrobe: Node3D = get_tree().get_first_node_in_group("guardaroba")
	wardrobe.debug_unlock_all()
	wardrobe.debug_open_panel()
	player.global_position = Vector3(0.5, 0, 5.0)
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "guardaroba")
	wardrobe.debug_close_panel()

	# 5j. Mochi vestita: cappello di petali, sciarpina e lanterna
	wardrobe.debug_wear("cappello_petali")
	wardrobe.debug_wear("sciarpina_lana")
	wardrobe.debug_wear("lanterna_lucciola")
	player.global_position = Vector3(-1.8, 0, 7.6)
	player.get_node("Mochi").set("_yaw", 2.7)
	player.get_node("Mochi").set("_next_blink", 10.0)
	var wcam2 := Camera3D.new()
	add_child(wcam2)
	wcam2.position = Vector3(-2.7, 1.2, 9.6)
	wcam2.fov = 40.0
	wcam2.current = true
	wcam2.look_at(Vector3(-1.75, 0.72, 7.75))
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "mochi_vestita")
	wardrobe.debug_strip()
	build_system.set_active_for_debug(true, Vector3(1, 0, 4), "Pianta")

	# 6. seduta sulla panchina, col prompt a schermo
	interactions.debug_sit("Panchina")
	var scam := Camera3D.new()
	add_child(scam)
	scam.position = Vector3(-1.3, 1.3, 4.3)
	scam.fov = 42.0
	scam.current = true
	scam.look_at(Vector3(1.0, 0.55, 3.0))
	await get_tree().create_timer(0.7).timeout
	await _shot(dir, "mochi_sit")

	# 7. a nanna nel letto: il tetto svanisce per farci sbirciare, arrivano gli zzz
	interactions.debug_sit("Letto")
	var ncam := Camera3D.new()
	add_child(ncam)
	ncam.position = Vector3(3.0, 3.6, 3.2)
	ncam.fov = 45.0
	ncam.current = true
	ncam.look_at(Vector3(3.0, 0.4, 0.0))
	await get_tree().create_timer(2.1).timeout
	await _shot(dir, "mochi_sleep")

	# 8. il tramonto dorato sul prato
	interactions.call("_stand_up")
	await get_tree().create_timer(0.5).timeout
	var dn: Node3D = _level.get_node(^"DayNight")
	dn.set_time(0.72)
	var tcam := Camera3D.new()
	add_child(tcam)
	tcam.position = Vector3(-7.0, 3.4, 9.5)
	tcam.fov = 48.0
	tcam.current = true
	tcam.look_at(Vector3(1.5, 1.2, -1.0))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "cozy_tramonto")

	# 9. la notte: stelle, lucciole, la lampada e le finestre accese
	dn.set_time(0.97)
	await get_tree().create_timer(2.8).timeout
	var mcam := Camera3D.new()
	add_child(mcam)
	mcam.position = Vector3(8.2, 2.4, 6.8)
	mcam.fov = 50.0
	mcam.current = true
	mcam.look_at(Vector3(4.0, 1.2, 1.5))
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "cozy_notte")

	# 9b. le lucciole dell'ecosistema danzano sullo stagno
	build_system.set_active_for_debug(false, Vector3(1, 0, 4))
	var lucciolecam := Camera3D.new()
	add_child(lucciolecam)
	lucciolecam.position = Vector3(5.4, 1.6, -6.6)
	lucciolecam.fov = 48.0
	lucciolecam.current = true
	lucciolecam.look_at(Vector3(9.5, 0.6, -10.5))
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "ecosistema_lucciole")

	# 9c. le costellazioni di Mochi: sdraiata a pancia in su…
	var stargazing: Node3D = get_tree().get_first_node_in_group("stelle")
	player.global_position = Vector3(-2.0, 0, 7.0)
	player.get_node("Mochi").set("_yaw", PI * 0.5)
	player.get_node("Mochi").call("set_pose", "stargaze")
	var sdcam := Camera3D.new()
	add_child(sdcam)
	sdcam.position = Vector3(-2.1, 1.35, 8.9)
	sdcam.fov = 44.0
	sdcam.current = true
	sdcam.look_at(Vector3(-2.0, 0.45, 6.9))
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "stelle_disteso")
	player.get_node("Mochi").call("set_pose", "stand")

	# 9d. …e la costellazione battezzata, per sempre nel cielo
	stargazing.debug_add("La Zuppetta")
	var dn9: Node3D = _level.get_node(^"DayNight")
	var star_dir: Vector3 = (dn9.get("star_dirs")[40] as Vector3)
	var skycam := Camera3D.new()
	add_child(skycam)
	skycam.position = Vector3(0, 1.4, 6.0)
	skycam.fov = 50.0
	skycam.current = true
	skycam.look_at(Vector3(0, 1.4, 6.0) + star_dir * 52.0)
	await get_tree().create_timer(1.6).timeout
	await _shot(dir, "costellazione")
	build_system.set_active_for_debug(true, Vector3(1, 0, 4), "Pianta")

	# 10. la foresta di giorno: sentiero, felci, fasci di luce tra le chiome
	dn.set_time(0.42)
	player.global_position = Vector3(0.5, 0, -20)
	var fcam := Camera3D.new()
	add_child(fcam)
	fcam.position = Vector3(4.5, 3.0, -13.0)
	fcam.fov = 48.0
	fcam.current = true
	fcam.look_at(Vector3(-2.5, 1.3, -30.0))
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "foresta_giorno")

	# 11. la radura col falò, al crepuscolo, coi funghi luminosi
	dn.set_time(0.79)
	player.global_position = Vector3(1.0, 0, -43.5)
	var gcam := Camera3D.new()
	add_child(gcam)
	gcam.position = Vector3(4.2, 2.4, -40.0)
	gcam.fov = 46.0
	gcam.current = true
	gcam.look_at(Vector3(-1.5, 0.7, -46.5))
	await get_tree().create_timer(0.9).timeout
	await _shot(dir, "foresta_falo")

	# 12. a letto di notte si dorme fino al mattino: dissolvenza al buio,
	# "Buongiorno!", e al risveglio l'ora deve essere quella dell'alba
	interactions.debug_sit("Letto")
	await get_tree().create_timer(4.4).timeout
	await _shot(dir, "mochi_wake")
	await get_tree().create_timer(4.2).timeout
	if dn.time >= 0.28 and dn.time <= 0.36:
		print("SLEEP: ok, sveglia alle %.2f" % dn.time)
	else:
		printerr("SLEEP: ora sbagliata dopo il risveglio: %.2f" % dn.time)

	# 12b. la posta del mattino: bandierina alzata, sportello che si apre,
	# la busta che fa capolino
	var mail: Node = _level.get_node(^"Mail")
	mail.debug_deliver()
	mail.debug_force_gift()
	player.global_position = Vector3(5.4, 0, 3.6)
	var pcam := Camera3D.new()
	add_child(pcam)
	pcam.position = Vector3(4.8, 1.7, 2.4)
	pcam.fov = 45.0
	pcam.current = true
	pcam.look_at(Vector3(6.1, 0.95, 4.3))
	await get_tree().create_timer(1.1).timeout
	await _shot(dir, "posta_aperta")

	# 12c. la lettera aperta: la card, e Mochi che la legge DAVVERO —
	# il foglio tra le zampine, la testolina che segue le righe.
	# Set nel prato aperto (niente staccionate né palette): Mochi a
	# sinistra del quadro, la card della lettera respira al centro-destra
	build_system.set_active_for_debug(false, Vector3(1, 0, 4))
	player.global_position = Vector3(-4.0, 0, 8.0)
	mochi.set("_next_blink", 10.0)
	mochi.set("_yaw", PI)
	mail.debug_read()
	var lcam := Camera3D.new()
	add_child(lcam)
	lcam.position = player.global_position + Vector3(1.15, 0.98, 1.85)
	lcam.fov = 40.0
	lcam.current = true
	lcam.look_at(player.global_position + Vector3(0.72, 0.6, 0.0))
	# lo scatto all'INIZIO della riga 2 (~2.7s): testolina ben china e
	# girata a inizio riga — il fotogramma dove la lettura si legge di più
	await get_tree().create_timer(2.7).timeout
	await _shot(dir, "posta_lettera")
	# ...e alla firma, il sorrisino a testa inclinata: lo scatto coglie
	# il saltello di contentezza a mezz'aria (apice a ~6.45s)
	await get_tree().create_timer(3.75).timeout
	await _shot(dir, "posta_firma")
	mail.call("_close_letter")
	await get_tree().create_timer(0.5).timeout

	# basta modalità build: via il fantasma e la griglia dagli scatti
	build_system.set_active_for_debug(false, Vector3(1, 0, 4))

	# 12d. giardinaggio: semina, poi annaffiatoio con la pioggerella
	var garden: Node = _level.get_node(^"Garden")
	player.global_position = Vector3(0.6, 0, 5.15)
	var wcam := Camera3D.new()
	add_child(wcam)
	wcam.position = Vector3(2.8, 1.6, 5.4)
	wcam.fov = 42.0
	wcam.current = true
	wcam.look_at(Vector3(0.85, 0.3, 3.95))
	# UNA semina con tutta la coreografia (accovacciata, archi, semini)…
	garden.debug_plant()
	await get_tree().create_timer(1.15).timeout
	await _shot(dir, "giardino_semina")
	await get_tree().create_timer(1.1).timeout
	# …poi il resto dei letti in massa, e l'annaffiatura
	garden.debug_plant_all()
	await get_tree().create_timer(0.25).timeout
	garden.debug_water()
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "giardino_annaffia")

	# 12e. tre notti dopo: la fioritura (e l'orto matura con lei)
	garden.debug_grow()
	await get_tree().create_timer(0.3).timeout
	garden.debug_grow()
	await get_tree().create_timer(0.3).timeout
	garden.debug_grow()
	await get_tree().create_timer(0.9).timeout
	await _shot(dir, "giardino_fiorito")

	# 12e2. l'orto maturo: le carote da un lato, le zucche dall'altro
	player.global_position = Vector3(2.2, 0, 5.1)
	player.get_node("Mochi").set("_yaw", 0.22)
	var ocam := Camera3D.new()
	add_child(ocam)
	ocam.position = Vector3(1.5, 1.75, 6.5)
	ocam.fov = 46.0
	ocam.current = true
	ocam.look_at(Vector3(1.35, 0.1, 3.8))
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "orto_maturo")

	# 12e1b. la raccolta: giù ad afferrare, su a sollevare il trofeo
	garden.debug_harvest()
	await get_tree().create_timer(0.85).timeout
	await _shot(dir, "orto_raccolta")
	await get_tree().create_timer(1.4).timeout

	# 12e2b. l'ecosistema vero: fiori selvatici nati dall'impollinazione,
	# farfalle a popolazione reale e passerotti sui semi dimenticati
	var ecosys: Node3D = get_tree().get_first_node_in_group("ecosystem")
	ecosys.eco.set_flower_sources(garden.bloomed_positions())
	ecosys.drop_seeds(Vector3(-0.5, 0, 6.2), 5)
	ecosys.drop_seeds(Vector3(-2.0, 0, 5.2), 4)
	ecosys.eco.debug_burst()
	var ecocam := Camera3D.new()
	add_child(ecocam)
	ecocam.position = Vector3(-4.0, 2.7, 9.4)
	ecocam.fov = 50.0
	ecocam.current = true
	ecocam.look_at(Vector3(1.2, 0.35, 3.2))
	await get_tree().create_timer(1.2).timeout
	await _shot(dir, "ecosistema_prato")
	print("ECO: ", ecosys.eco.counts())

	# 12e3. la passeggiata nel bosco ha uno scopo: i funghi da raccogliere
	var world: Node3D = _level.get_node(^"CozyWorld")
	var shroom: Node3D = (world.get("_pickups") as Array)[0]
	player.global_position = shroom.global_position + Vector3(0.9, 0, 0.4)
	player.get_node("Mochi").set("_yaw", atan2(0.9, 0.4))
	var fungocam := Camera3D.new()
	add_child(fungocam)
	fungocam.position = shroom.global_position + Vector3(-1.2, 1.1, 1.6)
	fungocam.fov = 44.0
	fungocam.current = true
	fungocam.look_at(shroom.global_position + Vector3(0.35, 0.35, 0))
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "bosco_fungo")
	garden.debug_pick()
	await get_tree().create_timer(0.28).timeout
	await _shot(dir, "bosco_raccolta")
	# la scena completa (afferra, solleva, esulta) dura ~1.9 s
	await get_tree().create_timer(1.9).timeout

	# 12f. il ricettario del camino: la dispensa piena, i piatti accesi
	var cooking: Node = _level.get_node(^"Cooking")
	player.global_position = Vector3(4.4, 0, 0.2)
	var kcam := Camera3D.new()
	add_child(kcam)
	kcam.position = Vector3(4.7, 1.1, 1.15)
	kcam.fov = 45.0
	kcam.current = true
	kcam.look_at(Vector3(3.55, 0.55, 2.1))
	cooking.debug_fill_pantry()
	cooking.debug_open_menu()
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "ricettario")
	cooking.debug_close_menu()

	# 12f2. il rituale: il pentolino che sobbolle sul fuoco...
	cooking.debug_cook()
	# girata di tre quarti: il visetto in camera, il fuoco di lato
	await get_tree().create_timer(0.3).timeout
	player.get_node("Mochi").set("_yaw", 0.1)
	await get_tree().create_timer(0.9).timeout
	await _shot(dir, "camino_pentolino")
	# ...la ciotola tra le zampine, col soffio per raffreddarla...
	await get_tree().create_timer(2.1).timeout
	await _shot(dir, "camino_te")
	# ...e finalmente il morso, con le briciole
	await get_tree().create_timer(1.05).timeout
	await _shot(dir, "camino_morso")
	await get_tree().create_timer(2.2).timeout

	# 12g. la pioggerella: gocce sottili, tonfi sull'erba, cielo morbido —
	# e Mochi con l'impermeabilino giallo, felice sotto la pioggia
	var weather: Node3D = _level.get_node(^"Weather")
	dn.set_time(0.45)
	weather.debug_rain(true)
	var wr12: Node3D = get_tree().get_first_node_in_group("guardaroba")
	wr12.debug_wear("impermeabilino")
	player.global_position = Vector3(-2.0, 0, 6.0)
	var raincam := Camera3D.new()
	add_child(raincam)
	raincam.position = Vector3(-6.0, 2.8, 9.5)
	raincam.fov = 50.0
	raincam.current = true
	raincam.look_at(Vector3(1.5, 1.2, 0.5))
	await get_tree().create_timer(3.2).timeout
	await _shot(dir, "meteo_pioggia")

	# 12h. smette di piovere: l'arcobaleno si distende sul villaggio
	weather.debug_rain(false)
	await get_tree().create_timer(2.0).timeout
	var rbcam := Camera3D.new()
	add_child(rbcam)
	rbcam.position = Vector3(1.0, 2.5, 16.0)
	rbcam.fov = 62.0
	rbcam.current = true
	rbcam.look_at(Vector3(2.0, 9.0, -30.0))
	await get_tree().create_timer(2.4).timeout
	await _shot(dir, "meteo_arcobaleno")
	wr12.debug_strip()

	# 12i. un visitatore: il riccio si riposa sulla panchina
	var visitors: Node = _level.get_node(^"Visitors")
	visitors.debug_visit("riccio")
	var vis: Node3D = visitors.get("_active")
	vis.call("debug_goto_sit")
	player.global_position = Vector3(2.6, 0, 4.6)
	var vcam := Camera3D.new()
	add_child(vcam)
	vcam.position = Vector3(-1.5, 1.15, 4.2)
	vcam.fov = 40.0
	vcam.current = true
	vcam.look_at(Vector3(1.05, 0.6, 2.95))
	await get_tree().create_timer(1.7).timeout
	await _shot(dir, "visita_riccio")

	# 12j. il regalino lasciato davanti alla panchina
	vis.call("debug_goto_gift")
	await get_tree().create_timer(4.0).timeout
	player.global_position = Vector3(0.15, 0, 2.2)
	var gcam2 := Camera3D.new()
	add_child(gcam2)
	gcam2.position = Vector3(1.9, 1.25, 1.5)
	gcam2.fov = 42.0
	gcam2.current = true
	gcam2.look_at(Vector3(0.1, 0.35, 3.1))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "visita_regalo")

	# 12k-pre. il character creator: tre villager generati dal DNA, in fila
	var cast_roots: Array[Node3D] = []
	var cast_accs := ["cappellino", "occhialini", "papillon"]
	for i in 3:
		var cdna: Dictionary = DNA_GEN.generate(101 + i * 7)
		cdna["acc"] = cast_accs[i]
		var croot: Node3D = CHIBI_BUILDER.build(cdna)["root"]
		croot.position = Vector3(-1.5 + i * 1.5, 0, 7.2)
		croot.rotation.y = PI
		add_child(croot)
		cast_roots.append(croot)
	var castcam := Camera3D.new()
	add_child(castcam)
	castcam.position = Vector3(0, 1.05, 9.6)
	castcam.fov = 42.0
	castcam.current = true
	castcam.look_at(Vector3(0, 0.55, 7.0))
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "npc_cast")
	for c in cast_roots:
		c.queue_free()

	# 12k. il trasloco: un villager generato arriva con la valigia e
	# aspetta il benvenuto sull'uscio della casa
	visitors.debug_candidate(2026)
	visitors.debug_goto_wait()
	player.global_position = Vector3(3.1, 0, 4.5)
	visitors.welcome_candidate()
	var tcam2 := Camera3D.new()
	add_child(tcam2)
	tcam2.position = Vector3(5.8, 1.4, 5.9)
	tcam2.fov = 44.0
	tcam2.current = true
	tcam2.look_at(Vector3(4.1, 0.45, 3.3))
	await get_tree().create_timer(1.2).timeout
	await _shot(dir, "trasloco_visita")

	# 12l. la mente dice sì: si trasferisce, valigia accanto al letto
	visitors.debug_force_decide()
	player.global_position = Vector3(4.7, 0, 1.1)
	await get_tree().create_timer(4.4).timeout
	var tcam3 := Camera3D.new()
	add_child(tcam3)
	tcam3.position = Vector3(2.0, 3.0, 3.9)
	tcam3.fov = 45.0
	tcam3.current = true
	tcam3.look_at(Vector3(3.5, 0.35, 0.3))
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "trasloco_casa")

	# 12l2. la vita dei residenti: la sera tutti al falò, con le chiacchiere
	visitors.debug_add_resident(555, Vector3(2, 0, 6))
	dn.set_time(0.72)
	visitors.debug_gather_fire()
	await get_tree().create_timer(1.2).timeout
	visitors.debug_force_chat()
	var campcam := Camera3D.new()
	add_child(campcam)
	campcam.position = Vector3(2.6, 1.7, -43.0)
	campcam.fov = 46.0
	campcam.current = true
	campcam.look_at(Vector3(-1.3, 0.5, -46.4))
	await get_tree().create_timer(1.1).timeout
	await _shot(dir, "vita_falo")
	await get_tree().create_timer(1.2).timeout

	# 12l3. il regalo della zuppetta: i gusti vengono dal DNA
	dn.set_time(0.45)
	visitors.debug_stage_resident(0, Vector3(1.6, 0, 5.4))
	player.global_position = Vector3(1.6, 0, 6.6)
	cooking.set("held_dish", {"name": "zuppa di carote", "art": "la", "warm": true})
	var dishcam := Camera3D.new()
	add_child(dishcam)
	dishcam.position = Vector3(3.4, 1.5, 7.3)
	dishcam.fov = 42.0
	dishcam.current = true
	dishcam.look_at(Vector3(1.5, 0.6, 5.6))
	await get_tree().create_timer(0.5).timeout
	visitors.debug_give_dish()
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "vita_regalo")
	await get_tree().create_timer(0.8).timeout

	# 12l3b. la lavagna col calendario: compleanni scritti col gessetto
	var calendario: Node3D = get_tree().get_first_node_in_group("calendario")
	calendario.debug_seed_board()
	player.global_position = Vector3(6.6, 0, 3.6)
	var lavcam := Camera3D.new()
	add_child(lavcam)
	lavcam.position = Vector3(5.2, 1.5, 2.6)
	lavcam.fov = 44.0
	lavcam.current = true
	lavcam.look_at(Vector3(7.05, 1.0, 4.05))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "lavagna")
	calendario.debug_open_panel()
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "lavagna_calendario")
	calendario.debug_close_panel()

	# 12l3c. la festa a sorpresa: coriandoli e tutto il villaggio che balla
	calendario.debug_party(0)
	var festacam := Camera3D.new()
	add_child(festacam)
	festacam.position = Vector3(3.4, 1.6, 7.2)
	festacam.fov = 46.0
	festacam.current = true
	festacam.look_at(Vector3(1.5, 0.7, 5.3))
	await get_tree().create_timer(0.55).timeout
	await _shot(dir, "festa_compleanno")
	await get_tree().create_timer(1.2).timeout

	# 12l3c2. l'autunno della vita: musetto brizzolato, sopracciglia
	# d'argento, schiena china e il bastoncino di ciliegio
	visitors.debug_eta(1.0)
	var anziano: Node3D = null
	for rr in visitors.get("_residents"):
		var n3 := rr.get("node") as Node3D
		if n3 and is_instance_valid(n3) and not n3.call("is_hidden"):
			anziano = n3
			break
	if anziano:
		var etacam := Camera3D.new()
		add_child(etacam)
		etacam.position = anziano.global_position + Vector3(1.1, 0.85, 1.4)
		etacam.fov = 38.0
		etacam.current = true
		etacam.look_at(anziano.global_position + Vector3(0, 0.5, 0))
		await get_tree().create_timer(0.7).timeout
		await _shot(dir, "vicino_anziano")
	visitors.debug_eta(0.0)

	# 12l3d. il mercante col carretto a strisce
	calendario.debug_merchant()
	var merccam := Camera3D.new()
	add_child(merccam)
	merccam.position = Vector3(3.3, 1.8, 7.2)
	merccam.fov = 46.0
	merccam.current = true
	merccam.look_at(Vector3(5.6, 0.9, 4.3))
	player.global_position = Vector3(6.5, 0, 5.9)
	player.get_node("Mochi").set("_yaw", 2.6)
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "mercante")
	calendario.call("_despawn_merchant")
	await get_tree().create_timer(0.5).timeout

	# 12l4. il premio finale: la casa sull'albero al crepuscolo, la
	# lanterna che dondola e un residente che si arrampica a trovarti
	build_system.place_cell(Vector2i(-8, 1), "Casa albero")
	dn.set_time(0.73)
	player.global_position = Vector3(-7.5, 2.75, 1.7)
	player.get_node("Mochi").set("_yaw", -2.2)
	var thcam := Camera3D.new()
	add_child(thcam)
	thcam.position = Vector3(-4.2, 3.9, 4.6)
	thcam.fov = 48.0
	thcam.current = true
	thcam.look_at(Vector3(-7.8, 2.6, 1.2))
	visitors.debug_stage_resident(0, Vector3(-8.0, 0, 3.6))
	await get_tree().create_timer(0.4).timeout
	var th: Node3D = build_system.get_placed_by_name("Casa albero")[0]
	var thtf: Transform3D = th.global_transform
	(visitors.get("_residents")[0]["node"] as Node3D).call("treehouse_visit",
			thtf * build_system.TH_BASE, thtf * build_system.TH_TOP, thtf * build_system.TH_PERCH)
	await get_tree().create_timer(3.4).timeout
	await _shot(dir, "casa_albero")
	await get_tree().create_timer(0.6).timeout

	# 12l5. l'onsen del bosco: vapore, lanterna di pietra e il bagno
	# condiviso col residente in accappatoio
	var onsen: Node3D = get_tree().get_first_node_in_group("onsen")
	var oncam := Camera3D.new()
	add_child(oncam)
	oncam.position = onsen.global_position + Vector3(-3.6, 2.2, 3.2)
	oncam.fov = 46.0
	oncam.current = true
	oncam.look_at(onsen.global_position + Vector3(0.3, 0.4, -0.3))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "onsen")
	var bagnante: Node3D = visitors.get("_residents")[1]["node"]
	bagnante.call("resident_wake")
	visitors.debug_stage_resident(1, onsen.global_position + Vector3(-2.6, 0, -1.4))
	onsen.debug_soak()
	player.get_node("Mochi").set("_yaw", 2.3)
	onsen.debug_guest(bagnante)
	var oncam2 := Camera3D.new()
	add_child(oncam2)
	oncam2.position = onsen.global_position + Vector3(-2.3, 1.5, 2.5)
	oncam2.fov = 42.0
	oncam2.current = true
	oncam2.look_at(onsen.global_position + Vector3(0.1, 0.35, -0.2))
	await get_tree().create_timer(4.2).timeout
	await _shot(dir, "onsen_bagno")
	onsen.debug_exit()
	await get_tree().create_timer(0.4).timeout

	# 12m. il retino: Mochi a mezza sventagliata su una farfalla
	var collection: Node = _level.get_node(^"Collection")
	dn.set_time(0.45)
	player.global_position = Vector3(-3.0, 0, 6.5)
	player.get_node("Mochi").set("_yaw", PI)
	var rncam := Camera3D.new()
	add_child(rncam)
	rncam.position = Vector3(-3.0, 1.05, 8.7)
	rncam.fov = 45.0
	rncam.current = true
	rncam.look_at(Vector3(-3.0, 0.75, 6.3))
	collection.debug_demo_catch()
	await get_tree().create_timer(0.16).timeout
	await _shot(dir, "retino")
	await get_tree().create_timer(1.2).timeout

	# 12n. la collezione in mostra: libreria temporanea in prato aperto
	collection.debug_fill()
	build_system.place_cell(Vector2i(0, 9), "Libreria", 0)
	player.global_position = Vector3(2.5, 0, 9.0)
	await get_tree().create_timer(0.4).timeout
	var jcam := Camera3D.new()
	add_child(jcam)
	jcam.position = Vector3(0.55, 1.85, 6.7)
	jcam.fov = 45.0
	jcam.current = true
	jcam.look_at(Vector3(0.0, 1.05, 9.05))
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "collezione")
	build_system._remove_at(2, Vector2i(0, 9))

	# 12n2. lo stagno: ninfee, canne, una rana sulla sponda
	var scam2 := Camera3D.new()
	add_child(scam2)
	scam2.position = Vector3(4.6, 2.3, -6.2)
	scam2.fov = 46.0
	scam2.current = true
	scam2.look_at(Vector3(9.6, 0.1, -10.8))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "stagno")

	# 12n2b. il fiume: il ponte ad arco, la corrente, le tife, la scogliera
	var rivcam := Camera3D.new()
	add_child(rivcam)
	rivcam.position = Vector3(11.5, 3.2, 9.5)
	rivcam.fov = 50.0
	rivcam.current = true
	rivcam.look_at(Vector3(19.5, -0.2, 1.0))
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "fiume")

	# 12n2c. la cascata che precipita dalla scogliera nel fiume
	var wfcam := Camera3D.new()
	add_child(wfcam)
	wfcam.position = Vector3(12.8, 1.8, 0.5)
	wfcam.fov = 46.0
	wfcam.current = true
	wfcam.look_at(Vector3(20.4, 1.0, -4.0))
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "cascata")

	# 12n3. la pesca: galleggiante affondato, cerchi nell'acqua, "E — tira!"
	var fishing: Node = _level.get_node(^"Fishing")
	player.global_position = Vector3(5.6, 0, -9.6)
	fishing.debug_start()
	await get_tree().create_timer(1.0).timeout
	fishing.debug_force_bite()
	var fcam2 := Camera3D.new()
	add_child(fcam2)
	fcam2.position = Vector3(3.9, 1.6, -7.6)
	fcam2.fov = 44.0
	fcam2.current = true
	fcam2.look_at(Vector3(7.6, 0.1, -10.3))
	await get_tree().create_timer(0.45).timeout
	await _shot(dir, "pesca")
	# e il pesce si prende davvero: esercita l'arco del _catch
	fishing.call("_catch")
	await get_tree().create_timer(1.0).timeout

	# 12o. modalità foto: inquadratura libera, zero UI
	var photo: Node = _level.get_node(^"PhotoMode")
	player.global_position = Vector3(0.5, 0, 5.0)
	photo.debug_enter(Vector3(-1.6, 0.65, 7.0), Vector3(1.2, 0.9, 3.5))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "modalita_foto")
	photo.debug_exit()
	await get_tree().create_timer(0.3).timeout

	# 12z. il Regista: profilo finto da botanico, routine Lua composte nel
	# recinto, piano recitato da un residente davanti alla camera
	dn.set_time(0.45)
	var regista: Node = get_tree().get_first_node_in_group("regista")
	regista.debug_note_many("giardino", 8)
	regista.debug_note_many("retino", 2)
	regista.debug_compose()
	var lua_stats: Dictionary = regista.debug_stats()
	var piano: Array = regista.debug_first_plan()
	var recinto_ok: bool = regista.debug_recinto()
	if bool(lua_stats["attivo"]) and int(lua_stats["compilate"]) >= 2 \
			and not piano.is_empty() and recinto_ok:
		print("REGISTA: ok, %d routine Lua (profilo %s), piano di %d passi, recinto ok" \
				% [int(lua_stats["compilate"]), lua_stats["profilo"], piano.size()])
	else:
		printerr("REGISTA: stats=%s piano=%d recinto=%s" % [lua_stats, piano.size(), recinto_ok])
	await _frames(2)   # i residenti nascosti si risvegliano col giorno
	visitors.debug_stage_resident(0, Vector3(2.2, 0, 6.0))
	var attore: Node3D = (visitors.get("_residents") as Array)[0]["node"]
	attore.call("run_plan", piano)
	var luacam := Camera3D.new()
	add_child(luacam)
	luacam.position = Vector3(2.0, 1.7, 8.6)
	luacam.fov = 45.0
	luacam.current = true
	luacam.look_at(Vector3(1.6, 0.5, 4.6))
	await get_tree().create_timer(2.4).timeout
	await _shot(dir, "regista_lua")

	# 12z2. il saluto: T — la zampina di Mochi ondeggia (prato aperto,
	# tre quarti frontale-destro: il braccio si apre contro l'erba)
	player.global_position = Vector3(-4.0, 0, 8.0)
	player.get_node("Mochi").set("_yaw", 0.0)
	player.get_node("Mochi").call("wave")
	var wavecam := Camera3D.new()
	add_child(wavecam)
	wavecam.position = Vector3(-2.4, 1.35, 6.4)
	wavecam.fov = 44.0
	wavecam.current = true
	wavecam.look_at(Vector3(-4.0, 0.72, 8.1))
	await get_tree().create_timer(0.55).timeout
	await _shot(dir, "saluto")
	await get_tree().create_timer(0.8).timeout

	# 12z3. l'offerta: zampine protese, inchino, il piatto che fluttua
	# (al residente 1: lo 0 potrebbe avere il COMPLEANNO, e la festa a
	# sorpresa avrebbe la precedenza sull'offerta)
	visitors.debug_stage_resident(1, Vector3(-2.6, 0, 8.3))
	(_level.get_node(^"Cooking") as Node).held_dish = {"name": "vellutata di zucca", "art": "la", "warm": true}
	player.global_position = Vector3(-4.2, 0, 8.0)
	visitors.debug_give_dish(1)
	var offcam := Camera3D.new()
	add_child(offcam)
	offcam.position = Vector3(-3.3, 1.25, 10.2)
	offcam.fov = 44.0
	offcam.current = true
	offcam.look_at(Vector3(-3.4, 0.62, 8.1))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "offerta")
	await get_tree().create_timer(1.2).timeout

	# 12zz. i cervelli: indole procedurale, agenda a utilità e
	# autosufficienza vera — un residente annaffia l'aiuola DA SOLO
	build_system.place_cell(Vector2i(0, 7), "Aiuola")
	await _frames(3)
	garden.debug_plant_cell(Vector2i(0, 7))
	visitors.debug_stage_resident(0, Vector3(0.2, 0, 8.6))
	var cervello: RefCounted = visitors.debug_brain(0)
	var att_ok: bool = visitors.debug_force_activity(0, "cura_giardino")
	var bcam2 := Camera3D.new()
	add_child(bcam2)
	bcam2.position = Vector3(2.4, 1.7, 9.6)
	bcam2.fov = 45.0
	bcam2.current = true
	bcam2.look_at(Vector3(0.2, 0.4, 7.0))
	await get_tree().create_timer(4.6).timeout
	var annaffiato: bool = garden.debug_is_watered(Vector2i(0, 7))
	if att_ok and annaffiato and not (cervello.get("indole") as Array).is_empty():
		print("CERVELLI: ok — %s; annaffiatura autonoma riuscita" \
				% str(cervello.call("descrizione")))
	else:
		printerr("CERVELLI: attivita=%s annaffiato=%s indole=%s" \
				% [att_ok, annaffiato, cervello.get("indole")])
	await _shot(dir, "vita_annaffia")

	# 12zz2. la stravaganza in scena: la serenata alla luna (il cervello
	# diventa nottambulo, così non rientra a dormire col tramonto)
	cervello.set("quirk", "canta_alla_luna")
	dn.set_time(0.85)
	visitors.debug_stage_resident(0, Vector3(1.2, 0, 5.6))
	await _frames(2)
	visitors.debug_quirk(0, "canta_alla_luna")
	var qcam := Camera3D.new()
	add_child(qcam)
	qcam.position = Vector3(1.2, 1.5, 8.0)
	qcam.fov = 44.0
	qcam.current = true
	qcam.look_at(Vector3(1.2, 0.6, 5.2))
	await get_tree().create_timer(1.6).timeout
	await _shot(dir, "npc_stravagante")
	dn.set_time(0.45)

	# 13. salvataggio: salva -> svuota -> ricarica, i pezzi devono tornare tutti
	var before: int = build_system.piece_count()
	build_system.save_path = dir.path_join("village_test.json")
	build_system._persist = true
	build_system._save_village()
	build_system._persist = false
	build_system.debug_clear()
	build_system._load_village()
	var after: int = build_system.piece_count()
	if before > 0 and after == before:
		print("SAVE: ok, %d pezzi salvati e ricaricati" % after)
	else:
		printerr("SAVE: pezzi %d -> %d" % [before, after])

	get_tree().quit()

# ------------------------------------------------- il villaggio regalo
# CHIBI_MAKESAVE=1: costruisce un villaggio già vissuto (casa arredata,
# giardino avviato, due residenti insediati) e lo salva come salvataggio
# vero in user://village.json, con anteprima PNG. Poi esce.

func _make_save() -> void:
	await _frames(10)
	build_system.debug_clear()
	(_level.get_node(^"Visitors") as Node).debug_reset()
	await _frames(2)
	_dream_build()
	await _frames(3)   # la cache delle aiuole si aggiorna col segnale

	# il giardino è già vissuto: una fioritura, boccioli, l'orto avviato
	var giardino: Node = _level.get_node(^"Garden")
	giardino.debug_set_stage(Vector2i(-1, 4), 3, false)
	giardino.debug_set_stage(Vector2i(0, 4), 2, true)
	giardino.debug_set_stage(Vector2i(5, 4), 2, true)

	# dispensa con qualcosa in fondo, e il calendario al giorno 3
	(_level.get_node(^"Cooking") as Node).pantry = {"carota": 3, "fungo": 2, "bacca": 2}
	(_level.get_node(^"DayNight") as Node3D).day = 3

	# casa del giocatore: il letto grande è già "casa"
	(_level.get_node(^"Home") as Node).home_cell = Vector2i(1, -1)

	# due vicini già insediati nelle casette
	var vis: Node = _level.get_node(^"Visitors")
	vis.debug_settle(4242, Vector2i(8, 0))
	vis.debug_settle(707, Vector2i(-5, 0))
	await _frames(3)

	build_system._save_village()
	print("MAKESAVE: villaggio regalo salvato — %d pezzi, %d residenti" \
			% [build_system.piece_count(), (vis.get("_residents") as Array).size()])

	# l'anteprima, per gli occhi
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-9.0, 6.5, 12.5)
	cam.fov = 50.0
	cam.current = true
	cam.look_at(Vector3(2.0, 0.5, 0.5))
	await get_tree().create_timer(1.2).timeout
	await _shot("user://", "anteprima_villaggio")
	get_tree().quit()


func _dream_build() -> void:
	var b: Node3D = build_system
	# --- la casa grande: 4x3, finestre a nord, porta a sud ---
	for x in range(1, 5):
		for z in range(-1, 2):
			b.place_cell(Vector2i(x, z), "Pavimento")
	for entry in [[Vector2i(2, -3), "Finestra"], [Vector2i(4, -3), "Muro"],
			[Vector2i(6, -3), "Finestra"], [Vector2i(8, -3), "Muro"],
			[Vector2i(2, 3), "Muro"], [Vector2i(6, 3), "Muro"], [Vector2i(8, 3), "Finestra"],
			[Vector2i(1, -2), "Muro"], [Vector2i(1, 0), "Muro"], [Vector2i(1, 2), "Muro"],
			[Vector2i(9, -2), "Muro"], [Vector2i(9, 0), "Finestra"], [Vector2i(9, 2), "Muro"]]:
		b.place_edge(entry[0], entry[1])
	b.place_edge(Vector2i(4, 3), "Porta", true)
	# arredo: l'angolo notte, il salottino, il camino acceso
	b.place_cell(Vector2i(1, -1), "Letto")
	b.place_cell(Vector2i(2, -1), "Comodino")
	b.place_cell(Vector2i(4, -1), "Libreria")
	b.place_cell(Vector2i(2, 0), "Tappeto")
	b.place_cell(Vector2i(3, 0), "Tappeto")
	b.place_cell(Vector2i(3, 0), "Tavolino")
	b.place_cell(Vector2i(2, 0), "Sedia", 1)
	b.place_cell(Vector2i(4, 1), "Camino", 3)
	b.place_cell(Vector2i(1, 1), "Sgabello")
	for x in range(1, 5):
		for z in range(-1, 2):
			b.place_cell(Vector2i(x, z), "Tetto")

	# --- il giardino: sentiero, aiuole, orto, angolo della posta ---
	for z in range(2, 6):
		b.place_cell(Vector2i(2, z), "Sentiero")
	b.place_cell(Vector2i(-1, 4), "Aiuola")
	b.place_cell(Vector2i(0, 4), "Aiuola")
	b.place_cell(Vector2i(5, 4), "Orto")
	b.place_cell(Vector2i(0, 2), "Lampada")
	b.place_cell(Vector2i(4, 2), "Lampada")
	b.place_cell(Vector2i(5, 2), "Cassetta posta")
	b.place_cell(Vector2i(-1, 2), "Panchina", 1)
	b.place_cell(Vector2i(6, 2), "Lavagna")
	b.place_cell(Vector2i(-2, 3), "Cespuglio")
	b.place_cell(Vector2i(6, 3), "Cespuglio")
	b.place_cell(Vector2i(-2, 5), "Fungo")
	b.place_cell(Vector2i(7, 4), "Fungo")
	b.place_cell(Vector2i(-2, 2), "Alberello")
	b.place_cell(Vector2i(7, 2), "Alberello")
	# staccionata a sud, col varco sul sentiero
	for x in range(-2, 8):
		if x != 2:
			b.place_edge(Vector2i(x * 2, 11), "Staccionata")

	# --- le due casette dei vicini: 1x1 col tetto, porta a sud ---
	for hut_x in [8, -5]:
		b.place_cell(Vector2i(hut_x, 0), "Pavimento")
		b.place_cell(Vector2i(hut_x, 0), "Letto")
		b.place_edge(Vector2i(hut_x * 2, -1), "Muro")
		b.place_edge(Vector2i(hut_x * 2, 1), "Porta", true)
		b.place_edge(Vector2i(hut_x * 2 - 1, 0), "Muro")
		b.place_edge(Vector2i(hut_x * 2 + 1, 0), "Finestra")
		b.place_cell(Vector2i(hut_x, 0), "Tetto")


func _demo_build():
	var b: Node3D = build_system
	# pavimento 3x3 sulle celle x 3..5, z 0..2
	for x in range(3, 6):
		for z in range(0, 3):
			b.place_cell(Vector2i(x, z), "Pavimento")
	# perimetro sui BORDI delle celle (chiavi raddoppiate):
	# lato nord (z = -0.5): finestra, muro, finestra
	b.place_edge(Vector2i(6, -1), "Finestra")
	b.place_edge(Vector2i(8, -1), "Muro")
	b.place_edge(Vector2i(10, -1), "Finestra")
	# lati ovest (x = 2.5) ed est (x = 5.5)
	for z in [0, 2, 4]:
		b.place_edge(Vector2i(5, z), "Muro")
		b.place_edge(Vector2i(11, z), "Muro")
	# fronte sud (z = 2.5): muro, porta, muro
	b.place_edge(Vector2i(6, 5), "Muro")
	b.place_edge(Vector2i(8, 5), "Porta", true)
	b.place_edge(Vector2i(10, 5), "Muro")
	# arredo interno
	b.place_cell(Vector2i(3, 0), "Letto")
	b.place_cell(Vector2i(3, 1), "Comodino")
	b.place_cell(Vector2i(5, 0), "Libreria", 2)
	b.place_cell(Vector2i(4, 1), "Tappeto")
	b.place_cell(Vector2i(4, 1), "Tavolino")
	b.place_cell(Vector2i(5, 1), "Sedia", 3)
	b.place_cell(Vector2i(3, 2), "Camino", 3)
	# giardino
	b.place_cell(Vector2i(7, 3), "Lampada")
	b.place_cell(Vector2i(6, 4), "Cassetta posta")
	b.place_cell(Vector2i(1, 3), "Panchina", 1)
	b.place_cell(Vector2i(7, 4), "Lavagna", 3)
	b.place_cell(Vector2i(2, 3), "Fungo")
	b.place_cell(Vector2i(1, 4), "Aiuola")
	b.place_cell(Vector2i(0, 3), "Orto")
	b.place_cell(Vector2i(2, 4), "Orto")
	b.place_cell(Vector2i(7, 1), "Cespuglio")
	b.place_cell(Vector2i(0, 5), "Alberello")
	# staccionata lungo il bordo sud del giardino (z = 4.5), varco sul sentiero
	for x in range(2, 7):
		if x != 4:
			b.place_edge(Vector2i(x * 2, 9), "Staccionata")
	# sentiero fino alla porta
	for z in range(3, 6):
		b.place_cell(Vector2i(4, z), "Sentiero")

	# --- il piano di sopra: solai al posto del vecchio tetto ---
	for x in range(3, 6):
		for z in range(0, 3):
			b.place_cell(Vector2i(x, z), "Solaio")
	# la scala esterna, addossata alla parete est: sale verso ovest
	b.place_cell(Vector2i(6, 1), "Scala", 3)
	# muri e finestre del piano di sopra (varco a est dove arriva la scala)
	b.place_edge(Vector2i(6, -1), "Finestra", false, true, 1)
	b.place_edge(Vector2i(8, -1), "Muro", false, true, 1)
	b.place_edge(Vector2i(10, -1), "Finestra", false, true, 1)
	for z in [0, 4]:
		b.place_edge(Vector2i(5, z), "Muro", false, true, 1)
		b.place_edge(Vector2i(11, z), "Muro", false, true, 1)
	b.place_edge(Vector2i(5, 2), "Muro", false, true, 1)
	b.place_edge(Vector2i(6, 5), "Muro", false, true, 1)
	b.place_edge(Vector2i(8, 5), "Finestra", false, true, 1)
	b.place_edge(Vector2i(10, 5), "Muro", false, true, 1)
	# arredo in quota e il tetto, ora in cima al secondo piano
	b.place_cell(Vector2i(3, 0), "Comodino", 0, true, 1)
	b.place_cell(Vector2i(3, 2), "Lampada", 0, true, 1)
	for x in range(3, 6):
		for z in range(0, 3):
			b.place_cell(Vector2i(x, z), "Tetto", 0, true, 1)

	# il belvedere: ponticello di corda dal balcone e piattaforma
	b.place_cell(Vector2i(6, 2), "Ponticello", 1)
	b.place_cell(Vector2i(7, 2), "Solaio")
	b.place_edge(Vector2i(15, 4), "Staccionata", false, true, 1)
	b.place_edge(Vector2i(14, 5), "Staccionata", false, true, 1)
	b.place_edge(Vector2i(14, 3), "Staccionata", false, true, 1)
