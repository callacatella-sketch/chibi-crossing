extends SceneTree
## LA PELLICOLA DEI GESTI — perché un movimento non si giudica in una posa.
##
##   CHIBI_GESTI=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_gesti.gd
##
##   CHIBI_GESTO=punto        # uno solo, per iterare in fretta
##   CHIBI_VISTA=profilo      # una vista sola
##   CHIBI_TENUTE=1           # le cinque tenute del Punto, affiancate
##
## La suite non dice niente sulla resa, e nemmeno il cancello del verso: quello
## conta pixel, e i pixel non sanno se un corpo sembra VIVO. Qui si guarda.
##
## Tre regole di ripresa, tutte già pagate da questo progetto:
##
##  1. **Il MONDO VERO** (`MainLevel`), non un fondale: la luce, l'erba e la
##     scala del villaggio sono metà di quello che si giudica.
##  2. **DI PROFILO e DI TRE QUARTI**, non solo di fronte: è lì che si
##     smascherano i trucchi (la bocca «in volo» davanti al muso viveva così).
##  3. **Una PELLICOLA, non una posa.** La differenza fra vivo e spento è il
##     micro-movimento — il respiro, l'assestamento, l'overshoot della molla,
##     l'asimmetria — e nessuna di queste cose esiste in un fotogramma solo.
##
## E la camera è quella VERA del gioco (incollata a Mochi, 2,7 m sopra e 3,7
## dietro): una macchina piazzata a un metro dal muso mostrerebbe un gesto che
## il giocatore non vedrà mai.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const SEME := 7331
const VISTE := {"fronte": 180.0, "trequarti": 135.0, "profilo": 90.0,
		"spalle": 0.0}
## A che distanza si guarda. Sei metri è l'altezza da cui un giocatore vede un
## vicino mentre gli passa accanto.
const DIST := 6.0

## Gli istanti di ogni pellicola, in secondi dall'inizio del gesto. Sono
## scelti sulla busta: l'attacco, il colmo, l'assestamento, il rilascio.
const ISTANTI := {
	"punto": [0.0, 0.10, 0.22, 0.45, 1.00, 1.60, 2.05, 2.35, 2.80],
	"raccolto": [0.0, 0.25, 0.55, 0.90, 1.60, 2.60, 3.10, 3.60, 4.40],
	"rialzo": [0.0, 0.06, 0.12, 0.22, 0.40, 0.65, 0.95, 1.25, 1.55],
	"largo": [0.0, 0.15, 0.35, 0.70, 1.20, 1.80, 2.20, 2.60, 2.95],
}

var _dove := ""
var _player: Node3D = null
var _v: Node3D = null
var _scatti := 0
var _dist := DIST


func _init() -> void:
	_go()


## ⚠️ **IL RITAGLIO LO CALCOLA LA CAMERA, non chi guarda dopo.** Un riquadro
## fisso deciso a mano sbaglia appena il corpo si sposta — e in una pellicola
## il corpo SI SPOSTA, è il punto — e si finisce per fotografare l'erba
## dicendo «il gesto non si vede». Qui il riquadro insegue la proiezione del
## corpo, quindi tutti i fotogrammi sono confrontabili fra loro.
func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var cam := get_root().get_camera_3d()
	if cam != null and _v != null:
		var c := cam.unproject_position(_v.global_position + Vector3(0, 0.62, 0))
		# il riquadro scala con la distanza: il corpo occupa sempre la stessa
		# frazione, e due pellicole a distanze diverse si confrontano
		var alto := cam.unproject_position(_v.global_position + Vector3(0, 1.4, 0))
		var basso := cam.unproject_position(_v.global_position)
		var h := maxf(120.0, absf(basso.y - alto.y) * 1.35)
		var r := Rect2i(Vector2i(int(c.x - h * 0.5), int(c.y - h * 0.5)),
				Vector2i(int(h), int(h)))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 16 and r.size.y > 16:
			img = img.get_region(r)
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_scatti += 1


## ⚠️ **LA CAMERA HA UNA MOLLA, e va lasciata arrivare.** Spostare Mochi e
## scattare subito dopo fa scivolare l'inquadratura per tutta la pellicola: la
## prima stesura di questo provino ha prodotto un Raccolto in cui il corpo
## traslava di un metro senza muovere una zampa, e per un attimo è sembrato un
## difetto del gesto. Un secondo e mezzo, e la camera è dove sta.
func _posa(vista: String) -> void:
	var yaw: float = deg_to_rad(float(VISTE[vista]))
	_v.global_position = Vector3.ZERO
	_v.set("_yaw", yaw)
	_v.rotation.y = yaw
	# ⚠️ e Mochi si mette DI LATO: la camera è incollata a lei, quindi a
	# distanza ravvicinata la sua testona copre esattamente il vicino che si
	# sta guardando (la prima stesura ha prodotto una pellicola intera del
	# Rialzo in cui il gesto era dietro la protagonista).
	_player.global_position = Vector3(1.7, _player.global_position.y, _dist)
	await create_timer(1.5).timeout


func _go() -> void:
	_dove = OS.get_environment("CHIBI_GESTI")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	var visitors := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	if _player == null or visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	if OS.get_environment("CHIBI_DIST") != "":
		_dist = float(OS.get_environment("CHIBI_DIST"))
	await create_timer(1.5).timeout

	_v = VS.new()
	_v.set("species", "chibi")
	_v.set("dna", DNAG.generate(SEME))
	visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 999999.0)
	await create_timer(0.6).timeout

	var quali: Array = ISTANTI.keys()
	if OS.get_environment("CHIBI_GESTO") != "":
		quali = [OS.get_environment("CHIBI_GESTO")]
	var viste: Array = VISTE.keys()
	if OS.get_environment("CHIBI_VISTA") != "":
		viste = [OS.get_environment("CHIBI_VISTA")]

	for g: String in quali:
		for vista: String in viste:
			await _pellicola(g, vista)
	if OS.get_environment("CHIBI_TENUTE") != "":
		await _le_tenute()
	print("\n  scatti: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	quit(0)


# =========================================================================
# LA PELLICOLA
# =========================================================================

## ⚠️ **IL TEMPO SI GOVERNA CON `Engine.time_scale`, NON CON UN TIMER.**
## Fermare il mondo e far avanzare il gesto a mano vorrebbe dire scrivere una
## seconda volta il motore del gesto dentro il provino — cioè fotografare il
## provino invece del gioco. Qui il gesto gira DAVVERO, e fra un fotogramma e
## l'altro si aspetta il tempo vero.
func _pellicola(nome: String, vista: String) -> void:
	print("\n── %s · %s ──" % [nome.to_upper(), vista])
	var dati := {}
	if nome == "largo":
		dati = {"via": 1.0, "posto": Vector3(-7.0, 0.0, -4.0)}
	# il Punto e il Largo vogliono un corpo CHE CAMMINA (il Punto è un
	# contrasto di moto: su un corpo fermo non produce niente). Gli altri due
	# si recitano da fermi.
	var in_cammino := nome == "punto" or nome == "largo"
	await _posa(vista)
	if in_cammino:
		var yaw: float = deg_to_rad(float(VISTE[vista]))
		var muso := Vector3(-sin(yaw), 0.0, -cos(yaw))
		# si parte indietro e si mira lontano: il corpo attraversa l'origine
		# alla velocità di crociera, col ciclo del passo a regime
		_v.global_position = -muso * 1.1
		_v.call("_walk_to", muso * 60.0, "r_idle")
		await create_timer(0.75).timeout
	else:
		_v.call("_enter_state", "r_idle")
		_v.set("_timer", 999999.0)
		await create_timer(0.4).timeout

	var ok: bool = _v.call("gesto", nome, dati)
	print("   partito: %s   (durata %.2f s)" % [str(ok), GESTI.durata(nome, dati)])
	var t0 := Time.get_ticks_msec()
	var i := 0
	for istante: float in ISTANTI[nome]:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < istante:
			await process_frame
		var r: float = _v.get("_gs_r")
		print("   t=%.2f  ritmo %.2f  blend %.2f"
				% [istante, r, float(_v.get("_andatura").blend)
						if _v.get("_andatura") != null else -1.0])
		await _scatta("%s_%s_%d_t%03d" % [nome, vista, i, int(istante * 100)])
		i += 1
	_v.call("gesto_spegni")
	await create_timer(0.6).timeout


# =========================================================================
# LE CINQUE TENUTE — l'unico numero in forbice di tutto il vocabolario
# =========================================================================

## Quanto resta fermo il Punto. Sotto una certa soglia il fermo si confonde
## con un'esitazione del passo; sopra, il vicino sembra rotto. Non è una cosa
## che si deduce: si guarda.
##
## Si stampa anche la CURVA DEL RITMO campionata dal gioco vero, perché un
## fermo si giudica anche a orecchio — quanto dura il silenzio fra due passi.
func _le_tenute() -> void:
	print("\n" + "█".repeat(72))
	print("LE CINQUE TENUTE DEL PUNTO")
	print("█".repeat(72))
	for tenuta: float in [0.8, 1.2, 1.8, 2.4, 3.5]:
		var yaw: float = deg_to_rad(135.0)
		var muso := Vector3(-sin(yaw), 0.0, -cos(yaw))
		await _posa("trequarti")
		_v.global_position = -muso * 1.1
		_v.call("_walk_to", muso * 60.0, "r_idle")
		await create_timer(0.75).timeout
		var partenza: Vector3 = _v.global_position
		_v.call("gesto", "punto", {"tenuta": tenuta})
		var t0 := Time.get_ticks_msec()
		var dur := GESTI.punto_durata(tenuta, false)
		var i := 0
		var fermo_da := -1.0
		var fermo_a := -1.0
		while float(Time.get_ticks_msec() - t0) / 1000.0 < dur:
			var t := float(Time.get_ticks_msec() - t0) / 1000.0
			var b: float = float(_v.get("_andatura").blend)
			if b < 0.10 and fermo_da < 0.0:
				fermo_da = t
			if fermo_da >= 0.0 and b > 0.10:
				fermo_a = t
			if t >= float(i) * dur / 5.0:
				await _scatta("tenuta_%.1f_%d" % [tenuta, i])
				i += 1
			await process_frame
		var arrivo: Vector3 = _v.global_position
		print("  tenuta %.1f s → il passo è SPENTO da %.2f a %.2f (%.2f s),"
				% [tenuta, fermo_da, fermo_a, fermo_a - fermo_da]
				+ " strada persa %.2f m"
				% (dur * 1.45 - partenza.distance_to(arrivo)))
		_v.call("gesto_spegni", true)
		await create_timer(0.5).timeout
