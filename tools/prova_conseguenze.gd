extends SceneTree
## LE CONSEGUENZE, NEL MAINLEVEL VERO — quello che la suite non può dire.
##
##   Godot --headless --path . --script res://tools/prova_conseguenze.gd
##   CHIBI_CONSEG=/dove Godot --path . --script res://tools/prova_conseguenze.gd
##
## `test_cuore_vicini.gd` prova le funzioni; questo prova il VILLAGGIO: con
## il BuildSystem vero, il Garden vero, i corpi veri e il bus della
## percezione vero, si guarda **dove va il corpo** — che è l'unica cosa che
## vede chi gioca.
##
## Tre scene, e la stessa disciplina di `prova_recinto`: si fa due volte lo
## stesso gesto e si guarda la differenza.
##
##  1. **LA PANCHINA.** Due panchine, una per parte. Prima: si sceglie la
##     più vicina a casa. Poi il vicino guarda Mochi annaffiare, e sceglie
##     quella dalla parte di Mochi. Poi Mochi se ne va lontano, e si torna
##     alla panchina di casa: **nessuno insegue nessuno**.
##  2. **L'AIUOLA.** Due aiuole assetate. Prima si annaffia la più vicina a
##     casa; dopo aver visto Mochi annaffiare l'altra, si annaffia l'altra —
##     e Mochi ritrova il proprio gesto, nello stesso punto, fatto da un
##     altro.
##  3. **IL PETTEGOLEZZO CHE ARRIVA AL CORPO.** Un secondo vicino, che in
##     quel momento era dall'altra parte del villaggio, torna, incontra il
##     primo, e da quella chiacchiera si porta via una notizia. Poi va
##     all'aiuola giusta — **senza esserci mai stato**. È la sola prova che
##     il passaparola ha una conseguenza nel mondo e non solo in un
##     dizionario.
##
## DUE TRAPPOLE DI QUESTO BANCO, pagate scrivendolo:
##  · **la panchina su cui uno è già seduto è OCCUPATA** (`_free_bench`
##    salta i posti presi, e chi ci sta sopra è un residente come gli
##    altri). Senza rimettere il corpo in piedi fra una misura e l'altra,
##    le due panchine si alternano da sole e il banco «vede» un
##    cambiamento che non c'entra niente con la memoria;
##  · **il secondo vicino vedrebbe il gesto anche lui** (sta a sei metri
##    dall'aiuola). Va portato via PRIMA, o la terza scena non prova il
##    passaparola: prova che c'era.

const CASA := Vector2i(6, 6)
const CASA2 := Vector2i(9, 4)
const PANCA_A := Vector2i(1, 6)     # 5.0 m da casa, dalla parte opposta a Mochi
const PANCA_B := Vector2i(12, 6)    # 6.0 m da casa, dalla parte di Mochi
## La panchina POSATA A METÀ PROVA, sotto gli occhi del vicino. Otto metri da
## casa (dentro i nove della percezione: la vede posare) e dalla parte in cui
## non c'è nessuna delle altre due — da casa vince ancora A (cinque metri),
## dall'ancora del ricordo (a sei metri verso di lei) vince lei, a due.
const PANCA_C := Vector2i(6, 14)
const AIUOLA_V := Vector2i(5, 3)    # 3.2 m: la vicina di casa
const AIUOLA_L := Vector2i(12, 9)   # 6.7 m: quella che Mochi annaffierà
const MOCHI_QUI := Vector3(18, 0, 6)
const MOCHI_VIA := Vector3(-24, 0, -18)
const LONTANO := Vector3(-20, 0, 30)

var _guasti := 0
var _dove := ""
var _cam: Camera3D = null


func _init() -> void:
	_go()


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok      " if ok else "  GUASTO  ") + testo)


func _mondo(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)


## Dove sta andando il corpo (non la prossima tappa: la meta).
func _dove_va(corpo: Node3D) -> Vector3:
	if corpo.has_method("meta_cammino"):
		return corpo.call("meta_cammino")
	return corpo.global_position


func _scatta(centro: Vector3, occhio: Vector3, nome: String) -> void:
	if _dove == "" or _cam == null:
		return
	_cam.position = occhio
	_cam.look_at(centro, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(
			_dove.rstrip("/") + "/" + nome + ".jpg", 0.94)


## Il bus VERO della percezione, chiamato esattamente come lo chiama
## `Garden._water`: il gruppo, il verbo, il posto. Tre volte perché un gesto
## dell'orto è quasi sempre più aiuole di fila, e la memoria le fonde in un
## ricordo solo con `quante = 3`.
func _annaffia(pos: Vector3) -> void:
	for _k in 3:
		call_group("percezione", "accaduto", "annaffia", pos)


## Lo stesso bus, col verbo che emette `BuildSystem._try_place` quando il
## giocatore posa un pezzo, e col punto che gli passa (il centro della cella).
## UNA volta sola: posare una panchina è un gesto solo.
func _costruisce(pos: Vector3) -> void:
	call_group("percezione", "accaduto", "costruisce", pos)


## ASPETTA CHE IL CORPO CI SIA ARRIVATO. Una foto scattata «dopo tot
## secondi» prende il corpo a mezza strada e non dice niente: la scena è
## qualcuno SEDUTO su una panchina, non qualcuno che cammina.
func _aspetta(corpo: Node3D, stato: String, tetto := 20.0) -> float:
	var t := 0.0
	while t < tetto and str(corpo.get("_state")) != stato:
		await create_timer(0.25).timeout
		t += 0.25
	return t


## PORTA IL CORPO DOVE SERVE, E ASPETTA CHE CI SIA DAVVERO.
##
## Non è pignoleria: chi si alza da una panchina lo fa con un TWEEN sulla
## `position` (`r_bench` → «dismount», 0,4 s di discesa), e un teletrasporto
## dato mentre quel tween è vivo viene riscritto il frame dopo — il corpo
## torna sulla panchina e il banco misura un vicino che credeva a casa. È
## successo, e a intermittenza: una volta su due il gesto risultava a undici
## metri invece che a sei, e la scena non entrava in memoria.
func _porta(visitors, i: int, corpo: Node3D, pos: Vector3) -> bool:
	for _k in 14:
		visitors.call("debug_stage_resident", i, pos)
		await create_timer(0.4).timeout
		if corpo.global_position.distance_to(pos) < 0.8:
			return true
	return false


func _go() -> void:
	_dove = OS.get_environment("CHIBI_CONSEG")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)

	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	var garden := livello.get_node_or_null("Garden")
	var dn := livello.get_node_or_null("DayNight")
	var player := livello.get_node_or_null("Player")
	if build == null or visitors == null or garden == null or dn == null or player == null:
		print("GUASTO: BuildSystem=%s Visitors=%s Garden=%s DayNight=%s Player=%s"
				% [build, visitors, garden, dn, player])
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	dn.call("set_time", 0.42)
	await create_timer(1.2).timeout

	if _dove != "":
		_cam = Camera3D.new()
		_cam.fov = 58.0
		_cam.current = true
		root.add_child(_cam)

	# ----------------------------------------------------- il villaggio
	visitors.call("debug_reset")
	for c in [CASA, CASA2]:
		build.call("place_cell", c, "Letto", 0, false)
		build.call("place_cell", c, "Tetto", 0, false)
	build.call("place_cell", PANCA_A, "Panchina", 0, false)
	build.call("place_cell", PANCA_B, "Panchina", 0, false)
	build.call("place_cell", AIUOLA_V, "Aiuola", 0, false)
	build.call("place_cell", AIUOLA_L, "Aiuola", 0, false)
	build.call("aggiorna_varchi_ora")
	await create_timer(1.0).timeout
	# ASSETATE, ma senza piantarle davvero: `Garden._plant` emette un gesto
	# sul bus della percezione, e la semina finirebbe nella memoria dei
	# vicini falsando tutta la prova.
	garden.call("debug_set_stage", AIUOLA_V, 1, false)
	garden.call("debug_set_stage", AIUOLA_L, 1, false)
	var quante_aiuole := (build.call("get_placed_by_name", "Aiuola") as Array).size()
	print("aiuole posate: %d" % quante_aiuole)
	_dico(quante_aiuole == 2, "le due aiuole ci sono")
	_dico(garden.call("bed_needing_water", _mondo(AIUOLA_V), 0.9) != null,
			"la vicina ha sete")
	_dico(garden.call("bed_needing_water", _mondo(AIUOLA_L), 0.9) != null,
			"e anche quella lontana")

	visitors.call("debug_settle", 4242, CASA)
	visitors.call("debug_settle", 7171, CASA2)
	await create_timer(1.0).timeout
	var residenti: Array = visitors.get("_residents")
	if residenti.size() < 2:
		print("GUASTO: servono due residenti, ce ne sono %d" % residenti.size())
		quit(1)
		return
	var r0: Dictionary = residenti[0]
	var r1: Dictionary = residenti[1]
	var c0: Node3D = r0["node"]
	var c1: Node3D = r1["node"]
	var cuore: Object = visitors.call("cuore")
	print("\n=== %s (casa %s) e %s (casa %s) ==="
			% [r0.get("label"), CASA, r1.get("label"), CASA2])

	player.global_position = MOCHI_QUI

	# =============================================== 1) LA PANCHINA
	print("\n--- 1) la panchina, prima ---")
	await _porta(visitors, 0, c0, _mondo(CASA))
	visitors.call("debug_force_activity", 0, "riposo")
	await create_timer(0.6).timeout
	var meta_a := _dove_va(c0)
	print("       va verso %s (panchina A %s, panchina B %s)"
			% [meta_a, _mondo(PANCA_A), _mondo(PANCA_B)])
	_dico(meta_a.distance_to(_mondo(PANCA_A)) < 1.6,
			"chi non ti ha visto va alla panchina più vicina a casa (A)")
	var t_a := await _aspetta(c0, "r_bench")
	print("       si è seduto dopo %.2f s, in %s" % [t_a, c0.global_position])
	await _scatta(_mondo(CASA) + Vector3(0.5, 0.5, 0),
			_mondo(CASA) + Vector3(0.5, 5.0, -8.5), "1-panchina-prima")

	# ------------------------------------- il gesto, e chi lo vede
	print("\n--- 1b) Mochi annaffia l'aiuola lontana, e lui la vede ---")
	# il secondo vicino sta a sei metri da quell'aiuola: se resta a casa
	# vede il gesto anche lui, e la terza scena non proverebbe più niente
	await _porta(visitors, 1, c1, LONTANO)
	_dico(await _porta(visitors, 0, c0, _mondo(CASA)),
			"il vicino è tornato a casa sua prima del gesto")
	var d_gesto := c0.global_position.distance_to(_mondo(AIUOLA_L))
	var d_altro := c1.global_position.distance_to(_mondo(AIUOLA_L))
	_annaffia(_mondo(AIUOLA_L))
	await create_timer(0.4).timeout
	var grafo: Dictionary = cuore.call("debug_grafo", int(r0["ecs"]))
	print("       lui è a %.2f m dal gesto, l'altro a %.2f m" % [d_gesto, d_altro])
	print("       ricordi suoi: %d" % (grafo.get("ricordi", []) as Array).size())
	_dico((grafo.get("ricordi", []) as Array).size() == 1,
			"il gesto è entrato nella SUA memoria")
	var emo: Dictionary = cuore.call("debug_emozioni", int(r0["ecs"]))
	var amm := float(cuore.call("ammirazione", int(r0["ecs"])))
	print("       gusto %s → ammirazione %.4f (soglia %.2f)"
			% [str(emo.get("gusto")), amm, visitors.get("AMMIRA_SOGLIA")])
	_dico(amm > float(visitors.get("AMMIRA_SOGLIA")),
			"e quel che ha visto gli è importato abbastanza")

	print("\n--- 1c) la panchina, dopo ---")
	await _porta(visitors, 0, c0, _mondo(CASA))
	visitors.call("debug_force_activity", 0, "riposo")
	await create_timer(0.6).timeout
	var meta_b := _dove_va(c0)
	print("       va verso %s" % meta_b)
	_dico(meta_b.distance_to(_mondo(PANCA_B)) < 1.6,
			"chi ti ha visto sceglie quella dalla TUA parte")
	var ancora: Vector3 = visitors.call("ancora_riposo", _mondo(CASA),
			player.global_position, amm)
	print("       ancora a %.2f m da casa (tetto %.1f)"
			% [ancora.distance_to(_mondo(CASA)), float(visitors.get("SPOSTA_MAX"))])
	_dico(ancora.distance_to(_mondo(CASA)) <= float(visitors.get("SPOSTA_MAX")) + 0.01,
			"e l'ancora resta dentro il suo tetto da casa: non è un guinzaglio")
	var t_b := await _aspetta(c0, "r_bench")
	print("       si è seduto dopo %.2f s, in %s" % [t_b, c0.global_position])
	await _scatta(_mondo(CASA) + Vector3(0.5, 0.5, 0),
			_mondo(CASA) + Vector3(0.5, 5.0, -8.5), "2-panchina-dopo")

	print("\n--- 1d) Mochi se ne va: nessuno la insegue ---")
	player.global_position = MOCHI_VIA
	await _porta(visitors, 0, c0, _mondo(CASA))
	visitors.call("debug_force_activity", 0, "riposo")
	await create_timer(0.6).timeout
	var meta_c := _dove_va(c0)
	print("       va verso %s" % meta_c)
	_dico(meta_c.distance_to(_mondo(PANCA_A)) < 1.6,
			"col giocatore lontano si torna alla panchina di casa")

	# ====================== 1e) LA PANCHINA CHE TI HA VISTA POSARE
	#
	# Mochi è LONTANA (la si è appena mandata via), quindi l'ancora della
	# scena 3 è spenta: tutto quello che succede qui sotto può venire solo
	# dal ricordo di un gesto. Si posa una panchina nuova a otto metri da
	# casa sua, sotto i suoi occhi, e si guarda dove va a sedersi.
	print("\n--- 1e) la panchina appena posata, sotto i suoi occhi ---")
	build.call("place_cell", PANCA_C, "Panchina", 0, false)
	build.call("aggiorna_varchi_ora")
	await create_timer(0.6).timeout
	_dico(await _porta(visitors, 0, c0, _mondo(CASA)),
			"il vicino è a casa sua quando Mochi posa la panchina")
	var d_posa := c0.global_position.distance_to(_mondo(PANCA_C))
	_costruisce(_mondo(PANCA_C))
	await create_timer(0.4).timeout
	# la SOGLIA arriva dal chiamante, come in partita
	# (`Visitors._ancora_ricordo`): senza, `dove()` veniva chiamata con tre
	# argomenti e il banco moriva a metà, restando appeso per sempre.
	var dove_casa: Vector3 = cuore.call("dove", int(r0["ecs"]),
			cuore.get("C_CASA"), float(visitors.get("AMMIRA_SOGLIA")),
			_mondo(CASA))
	print("       lui è a %.2f m dalla posa; si ricorda del posto %s (la panchina sta in %s)"
			% [d_posa, dove_casa, _mondo(PANCA_C)])
	_dico(dove_casa.distance_to(_mondo(PANCA_C)) < 0.6,
			"il posto in cui l'hai posata è entrato nella sua memoria")
	visitors.call("debug_force_activity", 0, "riposo")
	await create_timer(0.6).timeout
	var meta_f := _dove_va(c0)
	print("       va verso %s (nuova %s, di casa %s)"
			% [meta_f, _mondo(PANCA_C), _mondo(PANCA_A)])
	_dico(meta_f.distance_to(_mondo(PANCA_C)) < 1.6,
			"e va a sedersi PROPRIO su quella che ti ha vista posare")
	var t_d := await _aspetta(c0, "r_bench")
	print("       si è seduto dopo %.2f s, in %s" % [t_d, c0.global_position])
	# TRE VISTE, non una: da casa (si vede che se n'è andato dalla panchina di
	# sempre), di tre quarti e di profilo. È la disciplina di CLAUDE.md — un
	# corpo seduto si giudica dal fianco, dove si vede se sta davvero SULLA
	# panchina o mezzo metro davanti.
	await _scatta(_mondo(PANCA_C) + Vector3(0, 0.4, 0),
			_mondo(PANCA_C) + Vector3(0.5, 3.4, -6.0), "4-panchina-posata")
	await _scatta(_mondo(PANCA_C) + Vector3(0, 0.6, 0),
			_mondo(PANCA_C) + Vector3(2.6, 2.0, 5.2), "4b-panchina-posata-tre-quarti")
	await _scatta(_mondo(PANCA_C) + Vector3(0, 0.6, 0),
			_mondo(PANCA_C) + Vector3(5.0, 1.5, 0.4), "4c-panchina-posata-profilo")

	# la panchina resta dov'è: le due scene che seguono forzano
	# «cura_giardino», che non guarda nessuna seduta. Chi si alza da lì lo fa
	# col tween di sempre, e `_porta` sa aspettarlo.
	player.global_position = MOCHI_QUI

	# =============================================== 2) L'AIUOLA
	print("\n--- 2) l'aiuola che ha visto ---")
	await _porta(visitors, 0, c0, _mondo(CASA))
	visitors.call("debug_force_activity", 0, "cura_giardino")
	await create_timer(0.6).timeout
	var meta_d := _dove_va(c0)
	print("       va verso %s (vicina %s, quella vista %s)"
			% [meta_d, _mondo(AIUOLA_V), _mondo(AIUOLA_L)])
	_dico(meta_d.distance_to(_mondo(AIUOLA_L)) < 1.6,
			"fra le assetate sceglie quella che ha visto annaffiare")
	var t_c := await _aspetta(c0, "tk_water")
	print("       ci è arrivato dopo %.2f s, in %s" % [t_c, c0.global_position])
	await _scatta(_mondo(AIUOLA_L) + Vector3(0, 0.5, 0),
			_mondo(AIUOLA_L) + Vector3(-1.5, 3.2, -5.0), "3-aiuola-scelta")

	# ================================= 3) IL PETTEGOLEZZO CHE ARRIVA AL CORPO
	print("\n--- 3) il pettegolezzo, e il vicino che non c'era ---")
	var g1: Dictionary = cuore.call("debug_grafo", int(r1["ecs"]))
	_dico((g1.get("ricordi", []) as Array).size() == 0,
			"il secondo vicino non ha visto niente (era dall'altra parte)")
	await _porta(visitors, 1, c1, c0.global_position + Vector3(1.2, 0, 0))
	visitors.call("debug_force_chat")
	await create_timer(0.6).timeout
	g1 = cuore.call("debug_grafo", int(r1["ecs"]))
	var righe: Array = g1.get("ricordi", [])
	var sentiti := 0
	for riga in righe:
		if (int((riga as Dictionary)["bandiere"]) & int(cuore.get("R_SENTITO"))) != 0:
			sentiti += 1
	print("       adesso ne ha %d, di cui sentiti %d" % [righe.size(), sentiti])
	_dico(sentiti == 1, "e dopo la chiacchiera ne ha UNO, sentito dire")
	var suo_posto: Vector3 = cuore.call("dove", int(r1["ecs"]),
			cuore.get("C_FIORE"), float(visitors.get("AMMIRA_SOGLIA")),
			_mondo(CASA2))
	print("       e sa DOVE: %s (l'aiuola sta a %s)" % [suo_posto, _mondo(AIUOLA_L)])
	_dico(suo_posto.distance_to(_mondo(AIUOLA_L)) < 0.6,
			"il luogo attraversa il passaparola intatto")

	# LE AIUOLE SI RIMETTONO ASSETATE. Nel frattempo il primo vicino l'ha
	# annaffiata davvero (è la scena 2, ed è successa), e il secondo, libero,
	# ha fatto altrettanto con quella di casa sua: senza questa riga la terza
	# scena chiederebbe a qualcuno di annaffiare un orto già bagnato, e la
	# risposta giusta sarebbe «non c'è niente da fare».
	garden.call("debug_set_stage", AIUOLA_V, 1, false)
	garden.call("debug_set_stage", AIUOLA_L, 1, false)
	await _porta(visitors, 1, c1, _mondo(CASA2))
	visitors.call("debug_force_activity", 1, "cura_giardino")
	await create_timer(0.6).timeout
	var meta_e := _dove_va(c1)
	print("       il vicino va verso %s (la sua aiuola di casa è %s)"
			% [meta_e, _mondo(AIUOLA_V)])
	_dico(meta_e.distance_to(_mondo(AIUOLA_L)) < 1.6,
			"e ci VA: chi non c'era annaffia l'aiuola di cui gli hanno parlato")

	print("\n==== CONSEGUENZE: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	if _dove != "":
		print("   foto in %s" % _dove)
	quit(1 if _guasti > 0 else 0)
