extends SceneTree
## IL PROVINO DEL DUETTO — «si sono trovati», o è un singhiozzo del motore?
##
##   CHIBI_DUETTO=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_duetto.gd
##
## Il duetto non ha un canale suo: è il Punto deciso, due volte, sfalsato. Il
## significato sta tutto **nell'intervallo** — e un intervallo non si giudica
## contando, si giudica guardando. Fino a che nessuno l'ha guardato, quattro
## decimi di secondo sono un'opinione.
##
## ============================================================
## LA TESSERA DI CONTROLLO, ed è la ragione per cui questo provino SA FALLIRE
## ============================================================
## Un provino che mostra solo la cosa bella non prova niente: qualunque
## numero, guardato da solo, sembra giusto. Qui accanto alle sei battute c'è
## un **singhiozzo VERO** — i due corpi congelati per tre fotogrammi e poi
## ripartiti, che è l'aspetto che ha un motore che perde un frame. Se il
## duetto e il singhiozzo si assomigliano, il numero è sbagliato, e questo
## provino lo deve dire.
##
## ============================================================
## LE QUATTRO SCENE
## ============================================================
##   I    LA BATTUTA: 0,00 / 0,20 / 0,40 / 0,70 / 1,20 s + il SINGHIOZZO,
##        ognuna in pellicola, da quattro azimut (fronte · tre quarti ·
##        profilo · spalle)
##   II   LA DISTANZA: 2,2 / 3,4 / 4,6 / 6,0 / 8,0 m — «si prendono in uno
##        sguardo solo?» (la taratura di `DUETTO_MAX`)
##   III  ANZIANO + GIOVANE: il caso in cui il tempo lo detta un orologio che
##        non controlliamo (il fiato), e la battuta slitta da sé
##   IV   CI SEI ANCHE TU: il Punto singolo ancorato a Mochi, a 2/4/6/9 m —
##        si vede DI CHE COSA si è accorto? Se no, si toglie: è il primo
##        pezzo da tagliare.
##
## ⚠️ **DALLA CAMERA VERA DEL GIOCO.** Incollata a Mochi, 2,70 m sopra e 3,70
## dietro, fov 50, niente imbardata. Una macchina piazzata a un metro dai due
## musi risponderebbe a una domanda che nessuno si fa.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Due genomi diversi: due copie dello stesso chibi si fermerebbero identiche
## anche nel micro-movimento, e mostrerebbero un difetto che il gioco non ha.
const SEMI := [7331, 5119]
## Le battute da provinare. `DUETTO_RITARDO` è quella scritta; le altre
## servono a capire dove comincia a leggersi come reazione e dove smette.
const BATTUTE := [0.0, 0.20, 0.40, 0.70, 1.20]
## Le distanze fra i due corpi.
const DISTANZE := [2.2, 3.4, 4.6, 6.0, 8.0]
## …e quelle a cui si guarda il Punto singolo di «ci sei anche tu».
const DIST_MOCHI := [2.0, 4.0, 6.0, 9.0]
## ⚠️ **LA CAMERA DI QUESTO GIOCO NON SI GIRA**, e non la si può girare: sta
## 3,70 m dietro Mochi e guarda sempre −Z. Quindi «da che parte si guarda» non
## è una scelta di chi riprende — è **da che parte arrivano i due**, e il
## giocatore sta sempre nello stesso posto rispetto all'obiettivo.
##
## La prima stesura spostava MOCHI attorno alla scena: a 90°, 135° e 180° i
## due finivano **dietro l'obiettivo**, il ritaglio non li trovava, e il
## provino salvava tre quarti delle sue tessere con dentro il prato vuoto e la
## nuca di Mochi. Le foto c'erano, il soggetto no.
##
## Qui invece si ruota la DIREZIONE DI ARRIVO attorno al punto di ritrovo:
## 180° li fa venire incontro alla macchina (si vedono le facce), 0° li manda
## via (si vedono le schiene), 90° li fa attraversare di profilo.
const AZIMUT := [
	["fronte", 180.0], ["tre_quarti", 135.0], ["profilo", 90.0], ["spalle", 0.0]]
## Dove sta Mochi rispetto al punto di ritrovo: sempre di qua, perché di là
## la macchina non guarda.
const MOCHI_DA := 7.0

var _dove := ""
var _player: Node3D = null
var _vis: Node = null
var _liv: Node = null
var _a: Node3D = null
var _b: Node3D = null
var _scatti := 0


func _init() -> void:
	_go()


# ------------------------------------------------------------------ la ripresa

## Lo scatto racchiude TUTTI E DUE i corpi: qui non si giudica una posa, si
## giudica un quadro d'insieme — se i due si prendono in uno sguardo solo.
func _scatta(nome: String, chi: Array) -> void:
	if _dove == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var cam := get_root().get_camera_3d()
	if cam != null and not chi.is_empty():
		var minv := Vector2(1e9, 1e9)
		var maxv := Vector2(-1e9, -1e9)
		for c in chi:
			if c == null or not is_instance_valid(c):
				continue
			for q in [Vector3(0, 0, 0), Vector3(0, 1.30, 0)]:
				var p := cam.unproject_position((c as Node3D).global_position + q)
				minv = Vector2(minf(minv.x, p.x), minf(minv.y, p.y))
				maxv = Vector2(maxf(maxv.x, p.x), maxf(maxv.y, p.y))
		var m := 70.0
		var r := Rect2i(Vector2i(int(minv.x - m), int(minv.y - m)),
				Vector2i(int(maxv.x - minv.x + m * 2),
						int(maxv.y - minv.y + m * 2)))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		# ⚠️ **UNA TESSERA SENZA SOGGETTO SI DICHIARA, non si salva.** Il
		# ripiego «se il ritaglio non torna, salva il quadro intero» ha
		# prodotto tre quarti di provino con dentro il prato e la nuca di
		# Mochi, e sembravano foto vere. Un provino che non sa dire «qui non
		# c'era nessuno» non sa fallire.
		if r.size.x <= 32 or r.size.y <= 32:
			print("     ⚠️  %s: i corpi non sono in quadro — tessera saltata"
					% nome)
			return
		img = img.get_region(r)
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_scatti += 1


## Mochi (e con lei la camera) si mette SEMPRE di qua dal punto di ritrovo,
## alla distanza da cui è stato tarato tutto il vocabolario.
func _guarda_da(centro: Vector3, raggio := MOCHI_DA) -> void:
	_player.global_position = centro + Vector3(0.0, 0.0, raggio)
	await create_timer(0.5).timeout


func _posa(v: Node3D, p: Vector3, verso: Vector3) -> void:
	v.global_position = p
	var d := (verso - p)
	d.y = 0.0
	if d.length() > 0.01:
		var y := atan2(-d.x, -d.z)     # il rig guarda −Z
		v.set("_yaw", y)
		v.rotation.y = y
	v.call("_enter_state", "r_idle")


## I DUE IN CONVERGENZA, con le tre condizioni del momento soddisfatte
## insieme: più di tre metri di strada davanti a ciascuno (o il Punto si
## rifiuta), la meta dentro quattro metri dal posto, e i due corpi fra loro
## dentro la finestra del duetto. Ci si arriva dallo stesso quadrante — due
## punti su un arco di sessanta gradi attorno al posto, che è la corda uguale
## al raggio.
func _converge(centro: Vector3, distanza: float, orient := 0.0) -> void:
	for i in 2:
		var v: Node3D = _a if i == 0 else _b
		v.call("gesto_spegni", true)
		v.call("_enter_state", "r_idle")
	_riposiziona(centro, distanza, orient)
	for j in 2:
		var v2: Node3D = _a if j == 0 else _b
		v2.call("_walk_to", centro, "r_idle")
		v2.set("_gs_viaggio", false)
	# …e si cammina davvero, perché il ciclo del passo arrivi a regime: sotto
	# `GESTO_BLEND_MIN` non c'è un passo da spezzare, e il Punto si rifiuta
	await create_timer(0.35).timeout
	_riposiziona(centro, distanza, orient)


## ⚠️ **E SI RIMETTONO DOVE LI VOGLIAMO SUBITO PRIMA DI CHIEDERE, senza un
## `await` in mezzo.** Fra il `_walk_to` e la domanda i corpi CAMMINANO
## davvero — mezzo secondo sono sessantacinque centimetri — e arrivano a meno
## di `GESTO_STRADA_MIN` dalla loro meta: il Punto si rifiuta, giustamente, e
## il provino stampa venti righe di `apre=false` che sembrano un difetto del
## gesto. MISURATO alla prima stesura: chiesti 3,4 m, veri 2,65.
##
## ⚠️ **E QUI NON SI TOCCA LO STATO.** La seconda stesura chiamava `_posa`,
## che fa `_enter_state("r_idle")`: rimetteva i corpi al posto giusto e
## intanto li fermava, quindi il Punto rispondeva «non cammina» — le venti
## righe di `apre=false` restavano, con la geometria adesso perfetta. Due
## cause diverse, lo stesso sintomo: **è per questo che un banco stampa il
## MOTIVO e non solo l'esito.**
func _riposiziona(centro: Vector3, distanza: float, orient := 0.0) -> void:
	var raggio := maxf(distanza, 3.6)
	var arco := 2.0 * asin(clampf(distanza * 0.5 / raggio, 0.0, 1.0))
	var base := deg_to_rad(orient)
	for i in 2:
		var v: Node3D = _a if i == 0 else _b
		var ang := base - arco * 0.5 + arco * float(i)
		v.global_position = centro + Vector3(sin(ang), 0.0, cos(ang)) * raggio
		var d := centro - v.global_position
		d.y = 0.0
		if d.length() > 0.01:
			var y := atan2(-d.x, -d.z)     # il rig guarda −Z
			v.set("_yaw", y)
			v.rotation.y = y


## LA PELLICOLA IN CIFRE, accanto alle tessere.
##
## ⚠️ **Perché serve, e non è una comodità.** Un fotogramma FERMO non può
## mostrare una battuta: due corpi immobili a sette metri si somigliano
## qualunque sia il ritardo con cui si sono fermati, e infatti `battuta_040`
## e `battuta_singhiozzo` in un JPEG sono quasi identici. Quello che
## distingue le due cose è la FORMA NEL TEMPO — il ciclo del passo che si
## estingue su una rampa, sfalsato fra i due — e queste due cifre per
## fotogramma la mettono sotto gli occhi di chi guarda le tessere.
##
## Il duetto legge `99 · 45 · 12 · 03` per il primo e `99 · 99 · 80 · 21` per
## il secondo: **due rampe uguali, spostate.** Il singhiozzo legge la stessa
## cifra ripetuta e poi il ritorno di colpo: **nessuna rampa, e insieme.**
func _fotogramma() -> String:
	var an_a = _a.get("_andatura")
	var an_b = _b.get("_andatura")
	return "%02d/%02d " % [
		int(round((1.0 if an_a == null else float(an_a.blend)) * 99.0)),
		int(round((1.0 if an_b == null else float(an_b.blend)) * 99.0))]


func _sgombra() -> void:
	_vis.set("_gesto_acc", 0.0)
	_vis.set("_gesto_chi", "")
	_vis.set("_gesto_riposo", {})


# ------------------------------------------------------------------ le scene

func _go() -> void:
	_dove = OS.get_environment("CHIBI_DUETTO")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	_liv = current_scene
	_player = _liv.get_node_or_null("Player") as Node3D
	_vis = _liv.get_node_or_null("Visitors")
	var build := _liv.get_node_or_null("BuildSystem")
	var dn := _liv.get_node_or_null("DayNight")
	if _player == null or _vis == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	# ⚠️ L'OROLOGIO SI FERMA. Una giornata dura quattro minuti e questo
	# provino ne dura parecchi: senza, a metà prova i vicini vanno a dormire,
	# `resident_sleep` li rimpicciolisce a scala 0.03, e le foto inquadrano
	# due granelli al buio. (È la trappola di banco della Fase 5.)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	var centro := Vector3(0, 0, 0)
	for i in SEMI.size():
		var v = VS.new()
		v.set("species", "chibi")
		v.set("dna", DNAG.generate(int(SEMI[i])))
		_vis.add_child(v)
		v.set("greet_enabled", false)
		if i == 0:
			_a = v
		else:
			_b = v
	await create_timer(1.2).timeout
	# nessuno dei due ha l'età del fiato: nella scena I la battuta dev'essere
	# quella chiesta, non quella che detta un respiro
	_a.set("_eta", 0.0)
	_b.set("_eta", 0.0)

	await _scena_battuta(centro)
	await _scena_distanza(centro)
	await _scena_anziano(centro)
	await _scena_ci_sei_anche_tu(centro)

	print("\n  scatti: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	print("  GUARDALI: la domanda è UNA — il secondo corpo si legge come una")
	print("  RISPOSTA al primo, o come un secondo fatto? E la tessera")
	print("  `battuta_singhiozzo_*` deve sembrare un'altra cosa: se somiglia")
	print("  a `battuta_040_*`, il numero è sbagliato.")
	quit(0)


## SCENA I — LA BATTUTA, e la tessera di controllo.
func _scena_battuta(centro: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA I — LA BATTUTA (%s + il singhiozzo di controllo)"
			% ", ".join(PackedStringArray(BATTUTE.map(func(x): return "%.2f" % x))))
	print("█".repeat(72))
	for b in BATTUTE:
		for az in AZIMUT:
			await _una_battuta(centro, float(b), str(az[0]), float(az[1]))
	for az2 in AZIMUT:
		await _il_singhiozzo(centro, str(az2[0]), float(az2[1]))


## Un duetto con la battuta chiesta, ripreso in pellicola: il momento non è
## una posa, e in un fotogramma solo si vede il fermo di uno solo dei due.
func _una_battuta(centro: Vector3, battuta: float, nome_az: String,
		gradi: float) -> void:
	await _converge(centro, 4.4, gradi)
	await _guarda_da(centro)
	_riposiziona(centro, 4.4, gradi)   # …e niente `await` da qui alla domanda
	_sgombra()
	# si accende PRIMA la risposta (che non si vede), poi l'apertura: è
	# l'ordine vero di `chiedi_duetto`, e l'indivisibilità è costruita così
	var ok_b := true
	if battuta > 0.0:
		ok_b = bool(_b.call("frase", "incontro", {"fra": battuta}))
	var ok_a := bool(_a.call("frase", "incontro", {}))
	if battuta <= 0.0:
		ok_b = bool(_b.call("frase", "incontro", {}))
	print("  battuta %.2f · %-11s  apre=%s risponde=%s  (%s / %s)"
			% [battuta, nome_az, str(ok_a), str(ok_b),
				str(_a.call("punto_impedimento")),
				str(_b.call("punto_impedimento"))])
	var t0 := Time.get_ticks_msec()
	var riga := ""
	for k in 9:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) * 0.22:
			await process_frame
		riga += _fotogramma()
		await _scatta("battuta_%03d_%s_%02d"
				% [int(round(battuta * 100.0)), nome_az, k], [_a, _b])
	print("      %s" % riga)
	for v in [_a, _b]:
		(v as Node3D).call("gesto_spegni", true)


## LA TESSERA DI CONTROLLO: un singhiozzo VERO.
##
## I due corpi si fermano insieme e ripartono — **nessuna busta, nessun
## attacco, nessuna tenuta, nessun micro-movimento**: è l'aspetto che ha un
## motore che perde qualche fotogramma, ed è la cosa da cui il duetto si deve
## distinguere. Si ottiene spegnendo il `_process` dei due corpi, che è
## letteralmente quello che succede quando un fotogramma non arriva: il rig
## resta com'era, a metà passo.
##
## ⚠️ La prima stesura scriveva un `_move_speed_mult` che **su `Visitor` non
## esiste** (la velocità è `_speed`): `Object.set()` di una proprietà che non
## c'è non fa niente e non fallisce, quindi la tessera di controllo mostrava
## due corpi che camminavano normalmente. Una tessera di controllo che non
## controlla niente è peggio di nessuna tessera: fa sembrare distintivo
## qualunque numero.
func _il_singhiozzo(centro: Vector3, nome_az: String, gradi: float) -> void:
	await _converge(centro, 4.4, gradi)
	await _guarda_da(centro)
	_riposiziona(centro, 4.4, gradi)
	print("  SINGHIOZZO   · %-11s  (il rig si gela: nessuna busta)" % nome_az)
	var t0 := Time.get_ticks_msec()
	var riga := ""
	for k in 9:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) * 0.22:
			await process_frame
		# il gelo cade dove nel duetto cadono i due fermi
		var gelo: bool = k >= 2 and k <= 4
		for v in [_a, _b]:
			(v as Node3D).set_process(not gelo)
			(v as Node3D).set_physics_process(not gelo)
		riga += _fotogramma()
		await _scatta("battuta_singhiozzo_%s_%02d" % [nome_az, k], [_a, _b])
	print("      %s" % riga)
	for v3 in [_a, _b]:
		(v3 as Node3D).set_process(true)
		(v3 as Node3D).set_physics_process(true)


## SCENA II — LA DISTANZA: fin dove i due si prendono in uno sguardo solo.
func _scena_distanza(centro: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA II — LA DISTANZA (DUETTO_MIN=%.1f, DUETTO_MAX=%.1f)"
			% [VISITORS.DUETTO_MIN, VISITORS.DUETTO_MAX])
	print("█".repeat(72))
	for d in DISTANZE:
		await _converge(centro, float(d), 135.0)
		await _guarda_da(centro, 8.0)
		_riposiziona(centro, float(d), 135.0)
		_sgombra()
		var dentro: bool = float(d) >= VISITORS.DUETTO_MIN \
				and float(d) <= VISITORS.DUETTO_MAX
		_b.call("frase", "incontro", {"fra": VISITORS.DUETTO_RITARDO})
		_a.call("frase", "incontro", {})
		var vera := _a.global_position.distance_to(_b.global_position)
		print("  chiesta %.1f m · vera %.2f m · la regola direbbe %s"
				% [d, vera, "SÌ" if dentro else "no"])
		var t0 := Time.get_ticks_msec()
		for k in 5:
			while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) * 0.30:
				await process_frame
			await _scatta("distanza_%02d_%02d" % [int(round(float(d) * 10.0)), k],
					[_a, _b])
		for v in [_a, _b]:
			(v as Node3D).call("gesto_spegni", true)


## SCENA III — ANZIANO + GIOVANE. Il fermo dell'anziano è già in calendario
## (il fiato, 1,3 s ogni 7,5): apre lui, e la battuta di chi risponde è
## quella scritta. Poi il caso rovesciato, dove a slittare è la risposta.
func _scena_anziano(centro: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA III — ANZIANO + GIOVANE (il tempo lo detta il fiato)")
	print("█".repeat(72))
	for caso in ["apre_l_anziano", "risponde_l_anziano"]:
		_a.set("_eta", 0.9 if caso == "apre_l_anziano" else 0.0)
		_b.set("_eta", 0.0 if caso == "apre_l_anziano" else 0.9)
		# l'anziano si mette DENTRO il suo fiato: la scena serve a mostrare
		# come si legge, non a rifare il tiro di dadi del respiro (che ha già
		# il suo caso, in `test_cricche_corpo`)
		if caso == "apre_l_anziano":
			_a.set("_t", 0.1)
		await _converge(centro, 4.4, 135.0)
		await _guarda_da(centro)
		_riposiziona(centro, 4.4, 135.0)
		_sgombra()
		var battuta := float(_b.call("fiato_fra", VISITORS.DUETTO_RITARDO,
				VISITORS.DUETTO_RITARDO_MAX))
		var apre_ora := float(_a.call("fiato_fra", 0.0, 0.0)) >= 0.0
		print("  %s · chi apre può adesso: %s · battuta di chi risponde: %s"
				% [caso, str(apre_ora),
					("silenzio" if battuta < 0.0 else "%.2f s" % battuta)])
		if not apre_ora or battuta < 0.0:
			print("     → SILENZIO, ed è il comportamento giusto: il fermo di")
			print("       un anziano fuori dal suo fiato sarebbe una posa")
			print("       sopra un corpo che cammina, cioè l'adesivo.")
			continue
		_b.call("frase", "incontro", {"fra": battuta})
		_a.call("frase", "incontro", {})
		var t0 := Time.get_ticks_msec()
		for k in 9:
			while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) * 0.22:
				await process_frame
			await _scatta("anziano_%s_%02d" % [caso, k], [_a, _b])
		for v in [_a, _b]:
			(v as Node3D).call("gesto_spegni", true)
	_a.set("_eta", 0.0)
	_b.set("_eta", 0.0)


## SCENA IV — CI SEI ANCHE TU. Il Punto singolo ancorato a Mochi, alle
## quattro distanze. **La domanda è una sola: si vede DI CHE COSA si è
## accorto?** Se a quattro metri non si vede, questo canale si toglie — è il
## primo pezzo da tagliare, e va tagliato guardando, non discutendo.
func _scena_ci_sei_anche_tu(centro: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA IV — CI SEI ANCHE TU (il Punto singolo, ancorato a te)")
	print("█".repeat(72))
	_b.global_position = centro + Vector3(60, 0, 60)   # fuori dai piedi
	for d in DIST_MOCHI:
		# ⚠️ **DAVANTI ALL'OBIETTIVO, non dietro.** La camera sta 3,70 m
		# dietro Mochi e guarda −Z: un vicino piazzato dalla parte del
		# giocatore spunta **alle spalle della macchina**, e le sue sette
		# tessere escono vuote (misurato: 21 su 28). Arriva quindi da −Z,
		# cammina verso Mochi, e le passa accanto.
		var da := centro - Vector3(0, 0, float(d))
		var meta := centro + Vector3(0, 0, 4.0)
		_posa(_a, da, meta)
		_a.call("_walk_to", meta, "r_idle")
		_a.set("_gs_viaggio", false)
		_a.call("gesto_spegni", true)
		await create_timer(0.35).timeout
		_a.global_position = da
		_player.global_position = centro
		await create_timer(0.4).timeout
		_sgombra()
		var ok: bool = bool(_a.call("frase", "premessa", {}))
		print("  Mochi a %.1f m · il Punto è partito: %s" % [d, str(ok)])
		var t0 := Time.get_ticks_msec()
		for k in 7:
			while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) * 0.28:
				await process_frame
			await _scatta("ci_sei_%02d_%02d" % [int(round(float(d))), k], [_a])
		_a.call("gesto_spegni", true)
