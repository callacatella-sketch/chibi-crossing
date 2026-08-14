extends SceneTree
## IL PROVINO DEL VOCABOLARIO — l'unica fase che decide se questo lavoro esiste.
##
##   CHIBI_VOC=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_vocabolario.gd
##
##   CHIBI_PARTI=D        # solo le distanze (D) · le pellicole (F) · il
##                        # villaggio vivo (V) · i confronti (C). Di serie: DFCV
##   CHIBI_SOLO=premessa  # un gesto solo, per iterare in fretta
##   CHIBI_MINUTI=6       # quanto dura la parte viva
##
## ────────────────────────────────────────────────────────────────────────
## LE REGOLE DI RIPRESA, e ognuna chiude un modo di mentire a se stessi
## ────────────────────────────────────────────────────────────────────────
##
## 1. **LA CAMERA È QUELLA VERA.** `Player.tscn`: la camera sta a 2,70 m sopra
##    Mochi e 3,70 dietro, inclinata di 28°, fov 50, e **non ha imbardata**.
##    Una macchina piazzata a un metro dal muso risponde a una domanda che
##    nessun giocatore si fa.
##
## 2. **LE DISTANZE SONO VERE, E IL RITAGLIO NON BARA.** Nella lastra delle
##    distanze il riquadro è di **pixel fissi** (195), non «tanti quanti ne
##    occupa il corpo»: a 2 m il chibi riempie il riquadro, a 9 m è cinquanta
##    pixel — che è esattamente quello che vede chi gioca. Un ritaglio che
##    scala col corpo mostrerebbe un gesto leggibile a nove metri che nella
##    partita non esiste.
##
## 3. **L'AZIMUT SI CALCOLA, non si scrive.** Il vicino sta di lato rispetto a
##    Mochi (o la sua testona lo coprirebbe): «di profilo» rispetto alla
##    camera NON è `yaw = 90°`, ed è un errore di dieci-diciassette gradi che
##    si porta via proprio la colonna che si sta misurando. Qui l'angolo si
##    prende fra la direzione **camera → corpo** e il muso del corpo.
##
## 4. **UNA PELLICOLA, E CON I FOTOGRAMMI PRIMA.** Metà del vocabolario è un
##    contrasto di MOTO (il Punto ferma un corpo che camminava): una striscia
##    che comincia quando il gesto comincia fotografa solo la metà muta. Qui
##    gli istanti negativi ci sono, e il riquadro è **ancorato al mondo**, non
##    al corpo — se inseguisse il corpo cancellerebbe proprio il segnale.
##
## 5. **IL TEMPO SI RALLENTA, non si campiona a caso.** `Engine.time_scale`
##    a 0,35: il gioco gira identico e il provino può chiedere il fotogramma
##    a 0,12 s dall'inizio — che a venticinque fotogrammi al secondo, a
##    velocità piena, non esiste. Il colmo del Rialzo dura un decimo di
##    secondo: senza questa riga si fotografa sempre un attimo dopo.
##
## 6. **IL GESTO VECCHIO STA NELLA STESSA MATRICE**, con le stesse regole e
##    **nel suo caso migliore** (il bersaglio a 90°, cioè la testa al tetto).
##    Un confronto in cui il termine di paragone è messo male non è un
##    confronto.
##
## 7. **E ALMENO UNA VOLTA IN MEZZO AL VILLAGGIO VIVO**, a fotogramma pieno e
##    senza nessuna freccia: la domanda vera non è «si vede» ma «si nota fra
##    venti cose che si muovono», e una freccia disegnata sopra la risposta
##    la regala.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

const SEME := 7331
const VISTE := ["fronte", "trequarti", "profilo", "spalle"]
## 0° = il muso guarda VIA dalla camera (le spalle), 180° = in faccia.
const AZIMUT := {"fronte": 180.0, "trequarti": 135.0, "profilo": 90.0,
		"spalle": 0.0}
const DISTANZE := [2.0, 4.0, 6.0, 9.0]
const DIST_FILM := 6.0
## Di quanto sta di lato il vicino, in FRAZIONE della distanza dalla camera:
## così la sua posizione sullo schermo è la stessa a due metri e a nove, e le
## colonne della lastra sono confrontabili. (E la testona di Mochi non lo
## copre: la prima stesura di `provino_gesti` ci aveva perso una pellicola.)
## ⚠️ **E NON PIÙ STRETTO DI COSÌ.** A 0,245 (dodici gradi) la testona di
## Mochi entra nel riquadro da sotto e a due metri lo riempie per un quarto:
## la lastra del dettaglio diventa un ritratto della protagonista con un
## vicino dietro. A 0,42 (ventitré gradi) il vicino sta a due terzi di
## schermo, dentro l'inquadratura vera e fuori dalla testona — che è poi
## quello che fa un giocatore quando guarda qualcuno.
const OFF_ANG := 0.42
const TILE_D := 195      # il riquadro delle distanze, in pixel VERI del gioco
const TILE_F := 220      # il riquadro della pellicola
## Quanto mondo entra in un fotogramma di pellicola. **Non è una costante
## sola**: chi cammina attraversa il riquadro (e il Punto È quella traversata,
## quindi gliene serve), chi si recita da fermo pagherebbe quella larghezza in
## corpo piccolo — cioè nel dettaglio che si sta cercando di giudicare.
const FILM_CAMMINA := 3.4
const FILM_FERMO := 1.9
## La lastra del DETTAGLIO: a due metri, riquadro stretto, tessere grandi. Non
## serve a dire «si legge» (a quello risponde la lastra delle distanze): serve
## all'altra domanda, quella che nessun contatore di pixel sa fare — **sembra
## una persona o sembra un mimo?**
const DIST_DETT := 2.0
const TILE_G := 300
const DETT_CAMMINA := 3.0
const DETT_FERMO := 1.35
const RALL := 0.35       # il rallentatore
## La velocità di crociera di un chibi giovane (`Visitor._speed` a età zero).
## Serve solo a sapere DA DOVE far partire il corpo perché arrivi in mezzo
## all'inquadratura nell'istante in cui il gesto si accende.
const VEL_STIMA := 1.45

## Cosa si prova, e come. `colmo` è l'istante che finisce nella lastra delle
## distanze: quello in cui il gesto ha più da dire.
const PROVA := {
	"ricevuta": {"tipo": "testa", "cammina": false,
		"istanti": [-0.4, 0.0, 0.25, 0.6, 1.2, 2.2, 3.1], "colmo": 4,
		"che": "IL GESTO DI IERI — la testa che si gira (3,2 s)"},
	"premessa": {"tipo": "frase", "frase": "premessa", "cammina": true,
		"istanti": [-0.55, -0.25, 0.05, 0.6, 1.5, 2.15, 2.6], "colmo": 4,
		"che": "LA PREMESSA — il Punto molle: «mi sono accorto»"},
	"pensiero": {"tipo": "frase", "frase": "pensiero", "cammina": true,
		"istanti": [-0.55, -0.25, 0.05, 1.0, 2.0, 2.12, 2.6], "colmo": 5,
		"che": "IL PENSIERO — il Punto deciso + il Capo: «ho deciso»"},
	"rinuncia": {"tipo": "frase", "frase": "rinuncia", "cammina": false,
		"istanti": [-0.4, 0.0, 0.3, 0.85, 2.0, 3.05, 3.6], "colmo": 4,
		"che": "LA RINUNCIA — il Raccolto → Rialzo: «vorrei, e non lo faccio»"},
	"evitamento": {"tipo": "frase", "frase": "evitamento", "cammina": true,
		"istanti": [-0.4, 0.0, 0.25, 0.6, 1.2, 2.1, 2.7], "colmo": 4,
		"segui": true,
		"che": "L'EVITAMENTO — il Largo, camminando: «quel posto lì, no»"},
	"sollievo": {"tipo": "frase", "frase": "sollievo", "cammina": false,
		"istanti": [-0.3, 0.0, 0.06, 0.12, 0.3, 0.7, 1.25], "colmo": 3,
		"che": "IL SOLLIEVO — il Rialzo dopo il sussulto: «ah… sei tu»"},
	"capo": {"tipo": "livello", "livello": "capo", "cammina": false,
		"istanti": [-0.3, 0.3, 0.42, 0.52, 0.7, 1.1, 5.5], "colmo": 3,
		"che": "IL CAPO CHE PENDE (livello) — «ci sto pensando»"},
	"coda": {"tipo": "livello", "livello": "soma", "cammina": true,
		"istanti": [-0.3, 0.0, 0.4, 1.2, 2.5, 4.5, 6.5], "colmo": 2,
		"segui": true,
		"che": "LA CODA SOMATICA (livello) — «sono ancora guardingo»"},
}

var _dove := ""
var _liv: Node = null
var _player: Node3D = null
var _visitors: Node = null
var _build: Node = null
var _v: Node3D = null
var _cam: Camera3D = null
var _vp: SubViewport = null
var _lab: Label = null
var _cache := {}
var _fogli := 0
var _righe_log: Array = []
var _py := 0.0
## I parametri che questa presa vuole passare alla frase (le varianti).
var _extra_presa := {}


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_VOC")
	if _dove == "":
		_dove = "/tmp/vocabolario"
	DirAccess.make_dir_recursive_absolute(_dove)
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "DFGV"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	_liv = current_scene
	_player = _liv.get_node_or_null("Player") as Node3D
	_visitors = _liv.get_node_or_null("Visitors")
	_build = _liv.get_node_or_null("BuildSystem")
	var dn := _liv.get_node_or_null("DayNight")
	if _player == null or _visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if _build != null:
		_build.call("set_persist_for_debug", false)
	# l'orologio si ferma a metà pomeriggio: un giorno dura quattro minuti, e
	# un vicino che va a dormire si rimpicciolisce a scala 0,03
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	_py = _player.global_position.y
	_cam = get_root().get_camera_3d()
	if _cam == null:
		print("GUASTO: nessuna camera — la GDExtension non si e' caricata?")
		quit(1)
		return
	if parti.contains("X"):
		await _varianti()
		print("\n  fogli: %d in %s" % [_fogli, _dove])
		quit(0)
		return
	if parti.contains("D") or parti.contains("F") or parti.contains("G") \
			or parti.contains("M"):
		await _matrice(parti)
	if parti.contains("V"):
		var hud2 := _liv.get_node_or_null("HUD")
		if hud2 != null:
			hud2.set("visible", true)
		await _villaggio()
	print("\n  fogli: %d in %s" % [_fogli, _dove])
	quit(0)


# =========================================================================
# LA MATRICE — un corpo solo, il mondo vero, ogni gesto a ogni distanza
# =========================================================================

func _matrice(parti: String) -> void:
	var hud := _liv.get_node_or_null("HUD")
	if hud != null:
		hud.set("visible", false)
	_v = VS.new()
	_v.set("species", "chibi")
	_v.set("dna", DNAG.generate(SEME))
	_visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 999999.0)
	await create_timer(0.5).timeout
	print("il corpo: eta %.2f" % float(_v.get("_eta")))

	var quali: Array = PROVA.keys()
	if OS.get_environment("CHIBI_SOLO") != "":
		quali = OS.get_environment("CHIBI_SOLO").split(",")
	for g: String in quali:
		if not PROVA.has(g):
			continue
		if parti.contains("D") or parti.contains("F") or parti.contains("G"):
			await _un_gesto(g, parti)
		if parti.contains("M") and bool((PROVA[g] as Dictionary)["cammina"]):
			await _il_moto(g)


func _un_gesto(gid: String, parti: String) -> void:
	var d: Dictionary = PROVA[gid]
	print("\n" + "█".repeat(70))
	print("  %s" % str(d["che"]))
	print("█".repeat(70))
	var istanti: Array = d["istanti"]
	var colmo := int(d["colmo"])
	# celle[[riga, colonna]] → Image
	var celle_d := {}
	var celle_f := {}
	var celle_g := {}
	var viste: Array = VISTE
	if OS.get_environment("CHIBI_VISTE") != "":
		viste = OS.get_environment("CHIBI_VISTE").split(",")
	for vi in viste.size():
		var vista: String = viste[vi]
		for di in DISTANZE.size():
			var dist: float = DISTANZE[di]
			var film: bool = absf(dist - DIST_FILM) < 0.01 and parti.contains("F")
			var dett: bool = absf(dist - DIST_DETT) < 0.01 and parti.contains("G")
			if not film and not dett and not parti.contains("D"):
				continue
			# a 6 m si gira la pellicola intera; alle altre distanze bastano
			# il riposo e il colmo — e la lastra delle distanze si serve dalla
			# stessa presa, che è anche l'unico modo perché le due lastre
			# raccontino lo stesso gesto
			var pieno: bool = film or dett
			var quali_i: Array = istanti if pieno else [istanti[colmo]]
			var r: Dictionary = await _presa(gid, vista, dist, quali_i, pieno,
					_finestra(gid, dett))
			if r.is_empty():
				continue
			celle_d[[vi, di * 2]] = r["riposo"]
			var t: Array = r["tiles_d"]
			celle_d[[vi, di * 2 + 1]] = t[colmo if pieno else 0]
			if pieno:
				var tf: Array = r["tiles_f"]
				for c in tf.size():
					if dett:
						celle_g[[vi, c]] = tf[c]
					else:
						celle_f[[vi, c]] = tf[c]

	if parti.contains("D") and not celle_d.is_empty():
		var col: Array = []
		for dist: float in DISTANZE:
			col.append("%.0f m\nriposo" % dist)
			col.append("%.0f m\nGESTO" % dist)
		await _foglio("%s   ·   LE DISTANZE VERE (riquadro di %d pixel del gioco)"
				% [str(d["che"]), TILE_D], viste, col, celle_d, TILE_D, TILE_D,
				"%s/%s_distanze.jpg" % [_dove, gid])
	if parti.contains("G") and not celle_g.is_empty():
		var col3: Array = []
		for t3: float in istanti:
			col3.append("t %+.2f" % t3)
		await _foglio("%s   ·   IL DETTAGLIO a %.0f m — «una persona o un mimo?»"
				% [str(d["che"]), DIST_DETT], viste, col3, celle_g,
				TILE_G, TILE_G, "%s/%s_dettaglio.jpg" % [_dove, gid])
	if parti.contains("F") and not celle_f.is_empty():
		var col2: Array = []
		for t: float in istanti:
			col2.append("t %+.2f" % t)
		await _foglio("%s   ·   LA PELLICOLA a %.0f m (t = secondi dall'inizio)"
				% [str(d["che"]), DIST_FILM], viste, col2, celle_f,
				TILE_F, TILE_F, "%s/%s_pellicola.jpg" % [_dove, gid])


# =========================================================================
# IL CONTRASTO DI MOTO — la lastra che serve SOLO a chi cammina
# =========================================================================
#
# ⚠️ **UNA LASTRA DI POSE NON PUÒ GIUDICARE UN GESTO DI MOTO, e la lastra
# delle distanze è una lastra di pose.** Il Punto non è una forma: è un corpo
# che camminava e adesso non cammina più, e in un fotogramma solo — riposo
# contro colmo, tutti e due centrati sul corpo — quella notizia non c'è
# proprio. Serve un riquadro **fermo sul mondo** e istanti **regolari**: due
# tessere consecutive in cui il corpo sta nello stesso punto SONO il gesto.
#
# Il riquadro è di pixel fissi (come le distanze: a nove metri il chibi è
# cinquanta pixel e deve restare cinquanta pixel), e gli istanti sono scelti
# perché a QUALUNQUE distanza il corpo entri da un bordo, si fermi in mezzo e
# riparta: a 1,45 m/s, 0,35 s sono 58 pixel a due metri e 30 a nove.
## ⚠️ **E PER CHI NON SI FERMA IL RIQUADRO NON PUÒ STARE FERMO.** Il Largo e
## il rallentando si recitano CAMMINANDO: dentro un riquadro fisso sul mondo
## il corpo lo attraversa e sparisce in mezzo secondo — le ultime quattro
## tessere sono erba. E soprattutto la domanda è un'altra: non «si è fermato»
## ma «si è scostato dalla riga che stava seguendo» e «è rimasto indietro
## rispetto al passo che teneva».
##
## Perciò il riquadro insegue **la strada che il corpo avrebbe fatto senza il
## gesto** (`anc + muso · 1,45 · t`): il riferimento che al giocatore arriva
## dal moto degli altri e dalla propria memoria di quel corpo, e che in una
## pellicola di fotogrammi fermi non c'è. Quello che si vede nella tessera è
## esattamente lo SCARTO — di lato per il Largo, indietro per il rallentando.
const MOTO_T := [-0.80, -0.45, -0.10, 0.25, 0.90, 1.60, 2.10, 2.50]
const MOTO_VISTE := ["trequarti", "spalle"]
const TILE_M := 190


func _il_moto(gid: String) -> void:
	var d: Dictionary = PROVA[gid]
	print("\n  ── il contrasto di MOTO · %s ──" % gid)
	var celle := {}
	var righe: Array = []
	var r := 0
	for vista: String in MOTO_VISTE:
		for dist: float in DISTANZE:
			righe.append("%s\n%.0f m" % [vista, dist])
			var res: Dictionary = await _presa(gid, vista, dist, MOTO_T, true,
					0.0, TILE_M, bool(d.get("segui", false)))
			if not res.is_empty():
				var tf: Array = res["tiles_f"]
				for c in tf.size():
					celle[[r, c]] = tf[c]
			r += 1
	var col: Array = []
	for t: float in MOTO_T:
		col.append("t %+.2f" % t)
	var titolo := "riquadro fermo sul MONDO"
	if bool(d.get("segui", false)):
		titolo = "riquadro sulla STRADA CHE AVREBBE FATTO senza il gesto"
	await _foglio("%s   ·   IL CONTRASTO DI MOTO (%s, "
			% [str(d["che"]), titolo] + "pixel veri del gioco)", righe, col, celle,
			TILE_M, TILE_M, "%s/%s_moto.jpg" % [_dove, gid])


## UNA PRESA: si posa il corpo, lo si fa camminare se il gesto lo vuole, si
## fotografa il riposo, si accende il gesto e si scattano gli istanti.
func _finestra(gid: String, dett: bool) -> float:
	var cam := bool((PROVA[gid] as Dictionary)["cammina"])
	if dett:
		return DETT_CAMMINA if cam else DETT_FERMO
	return FILM_CAMMINA if cam else FILM_FERMO


func _presa(gid: String, vista: String, dist: float, istanti: Array,
		film: bool, metri := FILM_CAMMINA, px := 0, segui := false,
		extra := {}) -> Dictionary:
	var d: Dictionary = PROVA[gid]
	var cammina := bool(d["cammina"])
	Engine.time_scale = 1.0
	_extra_presa = extra
	_ripulisci()

	# 1) DOVE STA IL CORPO E DOVE STA MOCHI. Il vicino all'origine, Mochi
	#    dietro e di lato di un ANGOLO fisso: così sta sempre nello stesso
	#    punto dello schermo, a due metri come a nove.
	var ancora := Vector3.ZERO
	var lato := OFF_ANG * (dist + 3.7)
	_player.global_position = Vector3(lato, _py, dist)
	var cam_pos := _player.global_position + Vector3(0.0, 2.7, 3.7)
	# 2) L'AZIMUT VERO: l'angolo si prende fra «camera → corpo» e il muso.
	var dir := (ancora - cam_pos)
	var phi := atan2(dir.x, dir.z)
	var yaw := wrapf(phi + PI + deg_to_rad(float(AZIMUT[vista])), -PI, PI)
	var muso := Vector3(-sin(yaw), 0.0, -cos(yaw))

	_v.call("gesto_spegni", true)
	if cammina:
		# ⚠️ **DA QUANTO INDIETRO SI PARTE È UN CONTO, NON UN NUMERO A CASO.**
		# Fra il `_walk_to` e l'istante in cui il gesto si accende passano il
		# tempo di assestamento (0,9 s) e tutto il pre-rullo della pellicola
		# (gli istanti negativi, più il lancio): a 1,45 m/s sono TRE METRI, e
		# la prima stesura ne concedeva 1,6. Il corpo arrivava un metro e
		# mezzo oltre il punto inquadrato e continuava ad allontanarsi per
		# tutta la pellicola — a sei metri, di profilo, **usciva dal
		# fotogramma**, e la tessera veniva fuori mezza nera. Un provino che
		# perde il corpo non dice «il gesto non si vede»: non dice niente.
		var pre := 0.9 + 0.35 + absf(float(istanti[0]))
		_v.global_position = ancora - muso * (VEL_STIMA * pre)
		_v.set("_yaw", yaw)
		_v.rotation.y = yaw
		_v.call("_walk_to", ancora + muso * 60.0, "r_idle")
	else:
		_v.global_position = ancora
		_v.set("_yaw", yaw)
		_v.rotation.y = yaw
		_v.call("_enter_state", "r_idle")
		_v.set("_timer", 999999.0)
	await create_timer(0.9).timeout

	# 3) IL RALLENTATORE. Da qui in poi il gioco gira identico e il provino
	#    può chiedere il fotogramma a 0,06 s dall'inizio.
	Engine.time_scale = RALL
	var out := {"riposo": null, "tiles_d": [], "tiles_f": []}
	var anc := ancora
	var tg := float(istanti[0]) - 0.35
	var acceso := false
	var ms := Time.get_ticks_msec()
	var i := 0
	var riposo_fatto := false
	var fine := float(istanti[istanti.size() - 1]) + 0.05
	var guardia := 0
	while tg < fine and guardia < 6000:
		guardia += 1
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		_player.global_position = Vector3(lato, _py, dist)
		tg += dt * Engine.time_scale
		if not riposo_fatto:
			riposo_fatto = true
			# l'ancora del ritaglio è DOVE IL CORPO SARÀ quando il gesto si
			# accende, non dov'è adesso: la pellicola deve stare ferma sul
			# punto in cui succede la cosa
			if cammina:
				anc = _v.global_position + muso * VEL_STIMA \
						* (0.35 + absf(float(istanti[0])))
			var im := await _scatta()
			out["riposo"] = _rit_d(im)
			continue
		if not acceso and tg >= 0.0:
			acceso = true
			if not _accendi(gid, ancora, muso, yaw):
				print("   ⚠ %s · %s · %.0f m — IL CORPO HA DETTO DI NO"
						% [gid, vista, dist])
				Engine.time_scale = 1.0
				return {}
			# da qui l'orologio è quello del gesto, che è l'unico esatto
			tg = 0.0
		if acceso and str(_v.get("_gs_nome")) != "":
			tg = float(_v.get("_gs_t"))
		while i < istanti.size() and tg >= float(istanti[i]):
			var im2 := await _scatta()
			(out["tiles_d"] as Array).append(_rit_d(im2))
			if film:
				if px > 0:
					var centro := anc + Vector3(0, 0.45, 0)
					if segui:
						centro += muso * VEL_STIMA * tg
					(out["tiles_f"] as Array).append(_ritaglia(im2,
							_cam.unproject_position(centro), px, px))
				else:
					(out["tiles_f"] as Array).append(_rit_f(im2, anc, metri,
							TILE_G if dist < 3.0 else TILE_F))
			i += 1
	Engine.time_scale = 1.0
	while (out["tiles_d"] as Array).size() < istanti.size():
		(out["tiles_d"] as Array).append(_vuota(TILE_D))
		if film:
			(out["tiles_f"] as Array).append(_vuota(px if px > 0
					else (TILE_G if dist < 3.0 else TILE_F)))
	print("   %-10s %-10s %.0f m   ok" % [gid, vista, dist])
	_ripulisci()
	return out


## Accende quello che va acceso. **Sempre dalle porte vere** (`frase`,
## `guarda_gesto`, `somatico`, `capo_pende`): se il gesto si rifiuta, la presa
## si butta e lo dice — un provino che scrive il rig a mano fotografa se
## stesso.
func _accendi(gid: String, ancora: Vector3, muso: Vector3, yaw: float) -> bool:
	var d: Dictionary = PROVA[gid]
	match str(d["tipo"]):
		"testa":
			# IL CASO MIGLIORE per la ricevuta: il bersaglio a 90° dal muso,
			# cioè la testa che si gira fino al suo tetto (44°). Metterlo
			# davanti al vicino sarebbe misurare una testa ferma.
			var destra := Vector3(cos(yaw), 0.0, -sin(yaw))
			var pos := _v.global_position + destra * 4.0
			return bool(_v.call("guarda_gesto", pos, 3.2))
		"frase":
			var f := str(d["frase"])
			var extra := {}
			if f == "evitamento":
				# il posto da schivare: davanti e di lato, come una cella
				extra["posto"] = _v.global_position + muso * 5.0 \
						+ Vector3(cos(yaw), 0.0, -sin(yaw)) * 2.2
			for k in _extra_presa:
				extra[k] = _extra_presa[k]
			if f == "sollievo":
				# IL BUIO PRIMA, dalla porta vera: `somatico` è quello che
				# chiama `Visitors._tick_sussulti`. Senza, `frase` si rifiuta
				# — ed è giusto che si rifiuti.
				_v.call("somatico", 0.85)
			return bool(_v.call("frase", f, extra))
		"livello":
			if str(d["livello"]) == "capo":
				_v.call("capo_pende", true)
			else:
				_v.call("somatico", 1.0)
			return true
	return false


func _ripulisci() -> void:
	if _v == null:
		return
	_v.call("gesto_spegni", true)
	_v.call("capo_pende", false)
	_v.set("_gs_soma", 0.0)
	_v.set("_gs_soma_t", 0.0)
	_v.set("_gs_capo_x", 0.0)
	_v.set("_gs_capo_v", 0.0)
	_v.set("_tst_t", 0.0)
	_v.set("_gs_viaggio", false)


# =========================================================================
# GLI SCATTI E I RITAGLI
# =========================================================================

func _scatta() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()


## IL RITAGLIO DELLE DISTANZE: **pixel fissi**, centrato sul corpo. Il chibi
## è grande quanto è grande — a nove metri sono cinquanta pixel, ed è tutto
## il punto della lastra.
func _rit_d(img: Image) -> Image:
	var c := _cam.unproject_position(_v.global_position + Vector3(0, 0.45, 0))
	return _ritaglia(img, c, TILE_D, TILE_D)


## IL RITAGLIO DELLA PELLICOLA: **ancorato al mondo**, non al corpo. Se
## inseguisse il corpo, il Punto — che è un contrasto di moto — diventerebbe
## una successione di fotogrammi identici, cioè il segnale cancellato dal
## suo stesso provino.
func _rit_f(img: Image, ancora: Vector3, metri: float, tile: int) -> Image:
	var c := _cam.unproject_position(ancora + Vector3(0, 0.45, 0))
	var alto := _cam.unproject_position(ancora + Vector3(0, 1.45, 0))
	var pxm := maxf(8.0, absf(c.y - alto.y))
	var lato := int(metri * pxm)
	var t := _ritaglia(img, c, lato, lato)
	if t.get_width() != tile:
		t.resize(tile, tile, Image.INTERPOLATE_LANCZOS)
	return t


func _ritaglia(img: Image, centro: Vector2, w: int, h: int) -> Image:
	var r := Rect2i(Vector2i(int(centro.x) - w / 2, int(centro.y) - h / 2),
			Vector2i(w, h))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.06, 0.06, 0.07))
	var dentro := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if dentro.size.x > 4 and dentro.size.y > 4:
		var pezzo := img.get_region(dentro)
		pezzo.convert(Image.FORMAT_RGBA8)
		out.blit_rect(pezzo, Rect2i(Vector2i.ZERO, pezzo.get_size()),
				dentro.position - r.position)
	return out


func _vuota(lato: int) -> Image:
	var im := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.35, 0.05, 0.05))
	return im


# =========================================================================
# LE LASTRE — affiancate ED ETICHETTATE
# =========================================================================
#
# Le etichette si rendono con un `SubViewport` e una `Label`: senza, una
# lastra di varianti è una griglia di immagini che si somigliano, e chi la
# guarda sceglie la variante sbagliata credendo di aver scelto quella giusta.

func _testo(s: String, w: int, h: int, dim := 17) -> Image:
	var k := "%s|%d|%d|%d" % [s, w, h, dim]
	if _cache.has(k):
		return _cache[k]
	if _vp == null:
		_vp = SubViewport.new()
		_vp.transparent_bg = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_lab = Label.new()
		_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vp.add_child(_lab)
		get_root().add_child(_vp)
	_vp.size = Vector2i(w, h)
	_lab.size = Vector2(w, h)
	_lab.position = Vector2.ZERO
	_lab.text = s
	_lab.add_theme_font_size_override("font_size", dim)
	_lab.add_theme_color_override("font_color", Color(1, 1, 1))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	_cache[k] = img
	return img


func _foglio(titolo: String, righe: Array, colonne: Array, celle: Dictionary,
		tw: int, th: int, percorso: String) -> void:
	var LM := 120
	var TT := 44
	var TM := 46
	var W := LM + colonne.size() * tw
	var H := TT + TM + righe.size() * th
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.12, 1.0))
	var t := await _testo(titolo, W - 10, TT - 8, 21)
	img.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(5, 4))
	for c in colonne.size():
		var tc := await _testo(str(colonne[c]), tw - 6, TM - 8, 16)
		img.blend_rect(tc, Rect2i(Vector2i.ZERO, tc.get_size()),
				Vector2i(LM + c * tw + 3, TT + 4))
	for r in righe.size():
		var tr := await _testo(str(righe[r]), LM - 8, th, 18)
		img.blend_rect(tr, Rect2i(Vector2i.ZERO, tr.get_size()),
				Vector2i(4, TT + TM + r * th))
		for c in colonne.size():
			if not celle.has([r, c]):
				continue
			var cel: Image = celle[[r, c]]
			cel.convert(Image.FORMAT_RGBA8)
			img.blit_rect(cel, Rect2i(Vector2i.ZERO, cel.get_size()),
					Vector2i(LM + c * tw, TT + TM + r * th))
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(percorso, 0.95)
	_fogli += 1
	print("   → %s   (%dx%d)" % [percorso, W, H])


# =========================================================================
# LE VARIANTI — affiancate ED ETICHETTATE, che è l'unico modo di scegliere
# =========================================================================
#
# «Se non sei sicuro di un valore, fai un PROVINO»: cinque varianti sullo
# stesso corpo, sotto la stessa luce, nella stessa inquadratura, con
# l'etichetta addosso. Indovinare un numero e sperare è il contrario di
# questo mestiere — e scegliere fra due immagini che si somigliano SENZA
# l'etichetta è peggio, perché si sceglie e si crede di aver scelto.

const VAR_LARGO := [
	["A · com'è oggi", {}],
	["B · + esitazione 0,45", {"dip": 0.45}],
	["C · + inclinazione 0,15", {"vrz": 0.15, "px": 0.16}],
	["D · esitazione + inclinazione", {"dip": 0.45, "vrz": 0.15, "px": 0.16}],
	["E · esitazione forte 0,70", {"dip": 0.70}],
]
const VAR_T := [-0.45, -0.10, 0.10, 0.30, 0.60, 1.10, 1.80, 2.50]


func _varianti() -> void:
	_v = VS.new()
	_v.set("species", "chibi")
	_v.set("dna", DNAG.generate(SEME))
	_visitors.add_child(_v)
	_v.set("greet_enabled", false)
	var hud := _liv.get_node_or_null("HUD")
	if hud != null:
		hud.set("visible", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 999999.0)
	await create_timer(0.5).timeout
	for vista: String in ["trequarti", "spalle"]:
		var celle := {}
		var righe: Array = []
		for i in VAR_LARGO.size():
			righe.append(str((VAR_LARGO[i] as Array)[0]))
			var extra: Dictionary = ((VAR_LARGO[i] as Array)[1] as Dictionary).duplicate()
			var res: Dictionary = await _presa("evitamento", vista, DIST_FILM,
					VAR_T, true, 0.0, TILE_M, true, extra)
			if res.is_empty():
				continue
			var tf: Array = res["tiles_f"]
			for c in tf.size():
				celle[[i, c]] = tf[c]
		var col: Array = []
		for t: float in VAR_T:
			col.append("t %+.2f" % t)
		await _foglio("L'EVITAMENTO — CINQUE VARIANTI a %.0f m, vista %s "
				% [DIST_FILM, vista]
				+ "(riquadro sulla strada che avrebbe fatto senza il gesto)",
				righe, col, celle, TILE_M, TILE_M,
				"%s/VARIANTI_largo_%s.jpg" % [_dove, vista])


# =========================================================================
# IL VILLAGGIO VIVO — «si nota fra venti cose che si muovono?»
# =========================================================================
#
# Fotogrammi PIENI, senza ritaglio e senza nessun segno sopra: la domanda è
# se un gesto si stacca dal fondo di un villaggio che vive, e una freccia
# disegnata sopra regalerebbe la risposta. Chi ha gesticolato si legge nel
# registro stampato DOPO, che è il modo onesto di guardare una prova così.

func _villaggio() -> void:
	if _v != null and is_instance_valid(_v):
		_v.queue_free()
		_v = null
	await create_timer(0.5).timeout
	var minuti := 5.0
	if OS.get_environment("CHIBI_MINUTI") != "":
		minuti = float(OS.get_environment("CHIBI_MINUTI"))
	var quanti := 14
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))

	_visitors.call("debug_reset")
	# ⚠️ **IL VILLAGGIO SI COSTRUISCE STRETTO.** La domanda di questa parte è
	# «si nota fra venti cose che si muovono», e con le case ogni due metri
	# su ventotto metri di prato nell'inquadratura ci sta UN vicino: si
	# finirebbe per rispondere alla domanda facile. Un metro di passo mette
	# venti residenti in dieci metri, che è come costruisce chi gioca.
	var celle: Array[Vector2i] = []
	for gx in range(-6, 7):
		for gz in range(-6, 7):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	var letti := 0
	var i := 0
	var celle_letto: Array[Vector2i] = []
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		letti += 1
		celle_letto.append(c)
	var extra := 0
	while extra < 12 and i < celle.size():
		var c2: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c2, ["Cespuglio", "Panchina", "Aiuola"][extra % 3],
				0, false)
		extra += 1
	_build.call("aggiorna_varchi_ora")
	for k in celle_letto.size():
		_visitors.call("debug_settle", 5000 + k * 37, celle_letto[k])
	await create_timer(1.5).timeout
	var residenti: Array = _visitors.get("_residents")
	for k in residenti.size():
		var cc: Vector2i = (residenti[k] as Dictionary)["cell"]
		_visitors.call("debug_stage_resident", k, Vector3(cc.x, 0, cc.y))
	await create_timer(1.0).timeout
	_prepara(residenti)
	print("\n" + "█".repeat(70))
	print("  IL VILLAGGIO VIVO — %d residenti, %.0f minuti" % [residenti.size(), minuti])
	print("█".repeat(70))
	await _gira(minuti * 60.0, residenti)


func _prepara(residenti: Array) -> void:
	var animi: Dictionary = _visitors.get("_animi")
	var k := 0
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var animo: RefCounted = animi[lab]
		if k % 3 == 0:
			for _i in 4:
				animo.limbico.rivaluta("spavento", "", -0.9, "cucina", true)
		if k % 3 == 1:
			for _i in 2:
				animo.limbico.trattieni()
			r["gradino"] = maxi(int(r.get("gradino", 0)), 2)
			animo.set("gradino", maxi(int(animo.get("gradino")), 2))
		if k % 3 == 2:
			r["friend"] = maxi(int(r.get("friend", 0)), 3)
		k += 1


const VERBI := ["annaffia", "semina", "raccoglie", "costruisce", "pesca"]


func _gira(secondi: float, residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var meta := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var lavoro := 3.0
	var verbo := 0
	var sosta := 0.0
	var eventi := 0
	var fondo := 0
	var quadro := 0
	var fuori := 0
	var in_corso := {}
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= dt
		elif Vector2(p.x - meta.x, p.z - meta.z).length() < 1.0:
			sosta = 2.5
			if rng.randf() < 0.34 and not residenti.is_empty():
				var q: Dictionary = residenti[rng.randi() % residenti.size()]
				var qn := q.get("node") as Node3D
				meta = qn.global_position if qn != null and is_instance_valid(qn) \
						else Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			else:
				meta = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		var verso := (meta - p)
		verso.y = 0.0
		if sosta <= 0.0 and verso.length() > 0.01:
			var lontano: bool = verso.length() > 8.0
			var vel: float = float(_player.get("run_speed") if lontano
					else _player.get("walk_speed"))
			if vel <= 0.0:
				vel = 6.0 if lontano else 3.0
			_player.global_position = p + verso.normalized() * vel * dt
		lavoro -= dt
		if lavoro <= 0.0:
			lavoro = 5.5
			var perc := _liv.get_node_or_null("Percezione")
			if perc != null:
				for _k in 2 + (verbo % 3):
					perc.call("accaduto", VERBI[verbo % VERBI.size()],
							_player.global_position)
				verbo += 1
				if verbo % 3 == 0:
					var vicino := ""
					var dmin := 9.0
					for r in residenti:
						var n := (r as Dictionary).get("node") as Node3D
						if n == null or not is_instance_valid(n):
							continue
						var dd: float = _player.global_position.distance_to(n.global_position)
						if dd < dmin:
							dmin = dd
							vicino = str((r as Dictionary).get("label", ""))
					if vicino != "":
						perc.call("accaduto", "dona", _player.global_position, vicino)
		# IL FONDO: ogni tanto un fotogramma pieno in cui NON sta succedendo
		# niente, che è il termine di paragone senza il quale «si nota» non
		# vuol dire niente.
		if fondo < 3 and t > 20.0 * float(fondo + 1):
			var qualcuno := false
			for r in residenti:
				var n2 := (r as Dictionary).get("node") as Node3D
				if n2 != null and is_instance_valid(n2) \
						and str(n2.call("gesto_in_corso")) != "":
					qualcuno = true
			if not qualcuno:
				fondo += 1
				var im := await _scatta()
				im.save_jpg("%s/vivo_fondo_%d.jpg" % [_dove, fondo], 0.94)
		# e la pellicola di chi gesticola
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n == null or not is_instance_valid(n) or not n.has_method("gesto_in_corso"):
				continue
			var lab := str((r as Dictionary).get("label", ""))
			# ⚠️ **LA CHIAVE È IL CORPO, NON IL NOME.** Con diciannove
			# residenti pescati da un elenco di nomi due etichette si
			# ripetono, e la riga che spegne il segno di «sta gesticolando»
			# lo spegneva a un OMONIMO: il gesto veniva ricontato a ogni
			# fotogramma per tutta la sua durata. Misurato: 150 «gesti» dove
			# l'usciere ne aveva concessi 17. Un banco che conta male non
			# dice una cosa un po' sbagliata — dice una cosa che non esiste.
			var chiave := n.get_instance_id()
			var g := str(n.call("gesto_in_corso"))
			if g == "" :
				in_corso.erase(chiave)
				continue
			if not in_corso.has(chiave):
				# il conto vale per TUTTI i gesti, non solo per quelli
				# fotografati: otto pellicole bastano a guardare, otto
				# campioni non bastano a contare
				if _cam != null and _cam.is_position_in_frustum(
						n.global_position + Vector3(0, 0.55, 0)):
					quadro += 1
				else:
					fuori += 1
				in_corso[chiave] = 1
				if eventi >= 6:
					continue
				eventi += 1
				var dd2: float = _player.global_position.distance_to(n.global_position)
				var dentro := _cam != null and _cam.is_position_in_frustum(
						n.global_position + Vector3(0, 0.55, 0))
				_righe_log.append("evento %d · t=%.0f s · %s · gesto «%s» · a %.1f m da Mochi · %s"
						% [eventi, t, lab, g, dd2,
						"NELL'INQUADRATURA" if dentro else "⚠ FUORI DALL'INQUADRATURA"])
				await _pellicola_viva(eventi, n, lab, g)
	print("")
	print("  ⇒ GESTI PARTITI: %d — nell'inquadratura %d, FUORI %d (%.0f%%)"
			% [quadro + fuori, quadro, fuori,
			100.0 * float(fuori) / maxf(1.0, float(quadro + fuori))])
	print("  ── CHI HA GESTICOLATO, e dove ──")
	for r in _righe_log:
		print("   " + str(r))
	print("")
	print("  I NO DELL'USCIERE: %s" % str(_visitors.call("debug_gesti_contatori")))


## Sei fotogrammi PIENI durante un gesto vero, in mezzo al villaggio che vive.
## Niente rallentatore: qui si guarda quello che vede chi gioca.
func _pellicola_viva(n_ev: int, nodo: Node3D, lab: String, g: String) -> void:
	var passi := [0.0, 0.35, 0.9, 1.6, 2.3, 3.0]
	var t0 := Time.get_ticks_msec()
	var i := 0
	while i < passi.size():
		await process_frame
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		if t < float(passi[i]):
			continue
		var im := await _scatta()
		var scher := Vector2(-1, -1)
		if _cam != null and is_instance_valid(nodo):
			scher = _cam.unproject_position(nodo.global_position + Vector3(0, 0.6, 0))
		im.save_jpg("%s/vivo_%d_%s_%d.jpg" % [_dove, n_ev, g, i], 0.94)
		_righe_log.append("    fotogramma %d (t=%.2f): %s è a schermo in (%d, %d)"
				% [i, t, lab, int(scher.x), int(scher.y)])
		i += 1
