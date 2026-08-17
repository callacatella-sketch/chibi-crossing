extends SceneTree
## IL PROVINO DELLA RICEVUTA — le due misure si scelgono GUARDANDO.
##
##   CHIBI_RICEVUTA=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --script res://tools/provino_ricevuta.gd     # senza --headless
##
## La ricevuta della deduzione ha due numeri, e nessuno dei due si può
## dedurre da un ragionamento:
##
##  · **`Deduzioni.RAGGIO`** — fin dove il giocatore LEGGE una testa che si
##    gira. Non è `Percezione.RAGGIO` (nove metri, che è fin dove un vicino
##    si accorge di Mochi): è la domanda rovesciata, e la risposta la dà
##    l'occhio davanti allo schermo.
##  · **`Deduzioni.APERTURA`** — quanto possono divergere «dove guarda» e
##    «dove va» prima che si vedano due cose invece di una.
##
## ⚠️ **SI GUARDA DALLA CAMERA VERA DEL GIOCO**, non da una macchina messa
## lì per l'occasione. La camera di questo gioco è incollata a Mochi
## (`Player.tscn`: `CameraPivot` + `Camera3D` a 2,7 m d'altezza e 3,7 m
## dietro, senza imbardata) e non si può girare: quello che il giocatore
## vede di un vicino a sei metri **è** quello, con quella prospettiva e
## quella dimensione sullo schermo. Una camera piazzata a un metro dal muso
## risponderebbe a una domanda che nessuno si fa.
##
## E si guarda una COPPIA, mai una posa sola: una testa girata di
## quarantacinque gradi, da sola, non si distingue da una testa messa così.
## Quello che il giocatore vede è il MOVIMENTO — prima/dopo — ed è la sola
## cosa che questo provino stampa.

const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DED := preload("res://scenes/npc/Deduzioni.gd")

const CASA := Vector2i(8, 8)

## LE CINQUE DISTANZE, in metri fra Mochi e il vicino. `Deduzioni.RAGGIO` sta
## in mezzo apposta: si deve poter vedere anche il gradino prima e quello
## dopo, o si sta guardando una sola variante e chiamandola provino.
const DISTANZE := [2.5, 4.5, 6.5, 9.0, 12.0]

## I CINQUE ANGOLI fra l'ancora e la meta, in gradi.
const ANGOLI := [0.0, 15.0, 30.0, 45.0, 60.0]

## Quanto è lontana l'ancora dal vicino, nel provino dell'apertura: la
## mediana misurata nel villaggio vero (`tools/misura_attribuzione.gd`).
const ANCORA_DISTANZA := 11.0
## E la meta: la distanza tipica di un cespuglio o di una panchina.
const META_DISTANZA := 7.0

var _dove := ""
var _vis: Node = null
var _build: Node = null
var _player: Node3D = null
var _cuore: Object = null
var _corpo: Node3D = null
var _scatti := 0


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


## UNO SCATTO DALLA CAMERA VERA. Due `frame_post_draw`: il primo `save`
## prenderebbe il frame PRECEDENTE (l'idioma già pagato dagli altri provini).
func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_scatti += 1


## L'IMBARDATA SI SCRIVE SU `_yaw`, non su `rotation.y`: `Visitor._process`
## finisce con `rotation.y = _yaw` per ogni stato, ogni frame, e una
## rotazione scritta da fuori vive esattamente un frame. È la trappola già
## pagata da `tools/prova_pensieri.gd`.
func _metti_yaw(corpo: Node3D, y: float) -> void:
	corpo.set("_yaw", y)
	corpo.rotation.y = y


## Di quanto il MUSO manca il bersaglio, in radianti (il rig guarda −Z).
func _scarto(corpo: Node3D, bersaglio: Vector3) -> float:
	var avanti: Vector3 = -corpo.global_transform.basis.z
	avanti.y = 0.0
	var verso: Vector3 = bersaglio - corpo.global_position
	verso.y = 0.0
	if avanti.length() < 0.01 or verso.length() < 0.01:
		return 0.0
	return absf(avanti.normalized().angle_to(verso.normalized()))


func _go() -> void:
	_dove = OS.get_environment("CHIBI_RICEVUTA")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	_build = livello.get_node_or_null("BuildSystem")
	_vis = livello.get_node_or_null("Visitors")
	_player = livello.get_node_or_null("Player") as Node3D
	var dn := livello.get_node_or_null("DayNight")
	if _build == null or _vis == null or _player == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# L'OROLOGIO SI FERMA a metà pomeriggio: la luce di una foto non deve
	# cambiare fra una variante e l'altra, o si sta confrontando l'ora.
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.2).timeout

	_vis.call("debug_reset")
	_build.call("place_cell", CASA, "Letto", 0, false)
	_build.call("place_cell", CASA, "Tetto", 0, false)
	_build.call("aggiorna_varchi_ora")
	_vis.call("debug_settle", 4242, CASA)
	await create_timer(1.0).timeout
	var residenti: Array = _vis.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	_corpo = (residenti[0] as Dictionary)["node"]
	_cuore = _vis.call("cuore")
	# SI ZITTISCE L'AGENDA: un corpo che riparte a metà pellicola fotografa
	# un'altra scena.
	_vis.call("debug_force_activity", 0, "gironzola")
	await create_timer(0.5).timeout

	print("\n" + "█".repeat(72))
	print("PROVINO 1 — FIN DOVE SI LEGGE UNA TESTA CHE SI GIRA")
	print("█".repeat(72))
	print("  la camera è quella vera: 2,7 m sopra Mochi e 3,7 m dietro, fov 50")
	print("  (Deduzioni.RAGGIO adesso è %.1f m)" % DED.RAGGIO)
	for d in DISTANZE:
		await _scena_distanza(float(d))

	print("\n" + "█".repeat(72))
	print("PROVINO 2 — QUANTO POSSONO DIVERGERE «GUARDA» E «VA»")
	print("█".repeat(72))
	print("  (Deduzioni.APERTURA adesso è %.0f°)" % rad_to_deg(DED.APERTURA))
	for g in ANGOLI:
		await _scena_angolo(float(g))

	await _perche_resta_muta()

	print("\n  foto scattate: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	quit(0)


# =========================================================================
# 3) PERCHÉ UNA RICEVUTA RESTA MUTA
# =========================================================================

## ⚠️ **IL SOSPETTATO ERA IL RIG; È IL CORPO CHE SI GIRA.**
##
## La prova viva col modello vero (`tools/prova_pensieri.gd`) ha misurato
## nove ricevute pagate: sette portano la testa sul posto (picco 0–6°) e
## **due no** (28,2° e 23,3° di residuo, col bit acceso). I due candidati
## dichiarati erano `Visitor._sguardo_applica` — quanto la posa dello stato
## si mangia lo scostamento — e la stanchezza.
##
## Qui si misura, invece di sospettare. `collo_ci_arriva` si chiede UNA
## VOLTA, nell'istante in cui la ricevuta si paga; dopo, il corpo continua a
## vivere — gironzola, riparte, cambia mestiere — e `_sguardo_testimone`
## **ripinza il bersaglio a `tetto_ricevuta()` a ogni frame**. Se il corpo si
## gira di trenta gradi dalla parte sbagliata, la testa resta incollata al
## tetto e il residuo È quei trenta gradi. Nessun canale orfano, nessuna
## stanchezza: una premessa che scade perché il corpo si è voltato.
##
## Si stampa la curva: quanto è girato il corpo, quanto vale il collo, e
## quanto manca la testa al bersaglio.
func _perche_resta_muta() -> void:
	print("\n" + "█".repeat(72))
	print("PROVINO 3 — perché una ricevuta resta MUTA (il corpo si gira dopo)")
	print("█".repeat(72))
	var lui := Vector3(CASA.x, 0.0, float(CASA.y) + 4.0)
	var ancora := lui + Vector3(-6.0, 0.0, -6.0)
	_player.global_position = Vector3(lui.x, _player.global_position.y, lui.z + 3.4)
	_vis.call("debug_stage_resident", 0, lui)
	# il muso quasi sul bersaglio: la ricevuta si pagherebbe di sicuro
	var verso: Vector3 = ancora - lui
	_metti_yaw(_corpo, atan2(-verso.x, -verso.z))
	await create_timer(0.8).timeout
	_corpo.call("guarda_gesto", ancora, 30.0)
	await create_timer(1.5).timeout

	var testa := _corpo.get("_head") as Node3D
	print("  tetto del collo: %.1f°  (Visitor.tetto_ricevuta)"
			% rad_to_deg(VISITOR.tetto_ricevuta()))
	print("   corpo girato di    il bersaglio è a   la TESTA lo manca di   collo")
	for g in [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0, 120.0]:
		_metti_yaw(_corpo, atan2(-verso.x, -verso.z) + deg_to_rad(float(g)))
		await create_timer(0.7).timeout
		var manca := 0.0
		if testa != null and is_instance_valid(testa):
			var avanti: Vector3 = -testa.global_transform.basis.z
			avanti.y = 0.0
			var v2: Vector3 = ancora - testa.global_position
			v2.y = 0.0
			if avanti.length() > 0.01 and v2.length() > 0.01:
				manca = absf(avanti.normalized().angle_to(v2.normalized()))
		print("      %5.0f°             %6.1f°              %6.1f°          %+6.1f°"
				% [float(g), rad_to_deg(_scarto(_corpo, ancora)), rad_to_deg(manca),
				rad_to_deg(float(_corpo.get("_tst_off")))])


# =========================================================================
# 1) LA DISTANZA
# =========================================================================

## Il vicino è davanti a Mochi (la camera guarda −Z), l'ancora di lato: la
## testa si gira di traverso, che è il caso in cui il movimento si vede.
func _scena_distanza(d: float) -> void:
	var mochi := Vector3(CASA.x, 0.0, float(CASA.y) + d + 4.0)
	var lui := Vector3(CASA.x, 0.0, float(CASA.y) + 4.0)
	var ancora := lui + Vector3(-9.0, 0.0, -6.0)

	_player.global_position = Vector3(mochi.x, _player.global_position.y, mochi.z)
	_vis.call("debug_stage_resident", 0, lui)
	# il muso verso Mochi: è la posa in cui la testa girata si vede di più,
	# ed è anche quella in cui un vicino sta quando ti guarda passare
	_metti_yaw(_corpo, PI)
	await create_timer(0.8).timeout
	await _scatta("1_distanza_%.1fm_a_prima" % d)

	_corpo.call("guarda_gesto", ancora, 6.0)
	await create_timer(1.2).timeout
	print("  %5.1f m — il muso manca l'ancora di %.0f°, la testa è girata di %.0f°"
			% [d, rad_to_deg(_scarto(_corpo, ancora)),
			rad_to_deg(absf(float(_corpo.get("_tst_off"))))])
	await _scatta("1_distanza_%.1fm_b_dopo" % d)
	# si lascia spegnere, o la variante dopo parte con la testa già girata
	await create_timer(6.0).timeout


# =========================================================================
# 2) L'APERTURA
# =========================================================================

## La stessa ricevuta, la stessa testa, e la meta ruotata attorno al vicino.
## Tre momenti: la testa girata sull'ancora · il corpo che parte · il corpo
## arrivato. La domanda è una sola, e si fa guardando la terza foto con la
## prima in mente: **è andato dove aveva guardato?**
func _scena_angolo(gradi: float) -> void:
	var lui := Vector3(CASA.x, 0.0, float(CASA.y) + 4.0)
	var mochi := lui + Vector3(0.0, 0.0, 3.4)
	var verso := Vector3(-0.55, 0.0, -0.83).normalized()
	var ancora := lui + verso * ANCORA_DISTANZA
	var meta := lui + verso.rotated(Vector3.UP, deg_to_rad(gradi)) * META_DISTANZA

	_player.global_position = Vector3(mochi.x, _player.global_position.y, mochi.z)
	_vis.call("debug_stage_resident", 0, lui)
	_metti_yaw(_corpo, PI)
	await create_timer(0.8).timeout

	_corpo.call("guarda_gesto", ancora, 8.0)
	await create_timer(1.4).timeout
	await _scatta("2_angolo_%02.0f_a_guarda" % gradi)

	# e poi parte. `do_task` è il gesto vero del villaggio: il corpo cammina
	# come cammina sempre, con la sua andatura e la sua rotta.
	_corpo.call("do_task", "nibble", meta, func(): pass)
	await create_timer(1.6).timeout
	await _scatta("2_angolo_%02.0f_b_parte" % gradi)
	await create_timer(4.0).timeout
	await _scatta("2_angolo_%02.0f_c_arrivato" % gradi)
	print("  %4.0f° — ancora a %.1f m, meta a %.1f m, fra loro %.1f m"
			% [gradi, lui.distance_to(ancora), lui.distance_to(meta),
			ancora.distance_to(meta)])
	_vis.call("debug_force_activity", 0, "gironzola")
	await create_timer(1.0).timeout
