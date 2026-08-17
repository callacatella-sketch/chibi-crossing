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
##
## E poi c'è la quinta scena, che è l'ultimo pezzo della Fase 3: **il
## corpo segue la rotta, non la retta**. Si pianta una staccionata lunga
## fra un vicino e un punto, si dice al vicino di andarci, e si stampa la
## TRAIETTORIA campionata: deve girare attorno al muro, non attraversarlo.

const VARCHI := preload("res://scenes/build/Varchi.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const CASA := Vector2i(6, 6)
const CESPUGLIO := Vector2i(3, 6)
const LAVAGNA := Vector2i(10, 6)

# --- la quinta scena: la staccionata lunga, e il giro ---------------------
## Il muro corre fra la riga z=8 e la riga z=9, e non è un muretto: è la
## staccionata da undici metri che un giocatore pianta davvero. Chi parte
## da sotto e vuole andare sopra deve uscire da un capo o dall'altro — ed
## è il caso che costa di più al risolutore, perché la BFS deve arrivare
## fino in fondo alla staccionata prima di trovare l'uscita.
const MURO_X := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const MURO_Z := 8
## PARTENZA E ARRIVO SFASATI, e non è un vezzo. Un vicino non sta mai
## esattamente sul centro della sua cella: quello è l'unico caso in cui la
## spezzata che il villaggio giudica e quella che il corpo cammina
## coincidono, cioè l'unico in cui la garanzia valeva. Con gli estremi ai
## centri, questa prova (e la sua guardia headless) erano cieche allo
## stesso modo — e sotto passavano 25 sfondamenti su mille.
const DA := Vector3(6.38, 0, 6.41)
const A := Vector3(5.72, 0, 11.27)

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

	# ------------------------------- 5) IL CORPO SEGUE LA ROTTA, NON LA RETTA
	await _il_giro(build, visitors)

	print("\n==== RECINTO: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)


## LA QUINTA SCENA. Una staccionata da undici metri fra un vicino e un
## punto, e si GUARDA dove passa il corpo — campionato frame per frame,
## stampato, e ricontrollato con un oracolo che non è `Varchi`.
##
## È qui che si è visto il difetto che la suite non poteva vedere: il
## corpo usciva dal capo della staccionata tagliando ESATTAMENTE per il
## palo, perché `Varchi.filo_libero` decideva gli spigoli campionando. Una
## traiettoria stampata vale più di venti asserzioni su un piano.
##
## Poi questa prova è stata smontata a sua volta, per due motivi:
##
##  1. **partiva da un centro di cella** — l'unico posto in cui la
##     spezzata giudicata e quella camminata coincidono. Adesso `DA` e `A`
##     sono sfasati, come lo è sempre un vicino vero.
##  2. **giudicava con `Varchi`**: chiedeva alla stessa funzione che ha
##     deciso la strada se era d'accordo con sé stessa, e per giunta sulla
##     traiettoria RIDOTTA A CELLE (un corpo che entra ed esce da un muro
##     fra due campioni non lasciava traccia). Adesso i muri diventano i
##     segmenti veri che occupano sul confine, ogni spostamento di un
##     frame è un segmento, e la domanda è se i due si tagliano.
##
## Il camminatore è un chibi VERO messo in scena apposta e non iscritto fra
## i residenti: così nessuna routine gli cambia stato a metà strada e quel
## che si vede è la camminata, non l'IA.
func _il_giro(build, visitors) -> void:
	print("\n--- 5) il corpo SEGUE LA ROTTA, non la retta ---")
	for x: int in MURO_X:
		build.call("place_edge", Vector2i(x * 2, MURO_Z * 2 + 1), "Staccionata", false, false)
	build.call("aggiorna_varchi_ora")
	var muri: Dictionary = build.call("muri")
	var piantate := 0
	for x: int in MURO_X:
		if muri.has(VARCHI.bordo_fra(Vector2i(x, MURO_Z), Vector2i(x, MURO_Z + 1))):
			piantate += 1
	_dico(piantate == MURO_X.size(),
			"la staccionata è piantata tutta (%d campate su %d)"
			% [piantate, MURO_X.size()])
	_dico(not VARCHI.filo_libero(muri, Vector2(DA.x, DA.z), Vector2(A.x, A.z)),
			"e la RETTA fra i due punti ci sbatte contro")

	var camminatore: Node3D = VISITOR.new()
	camminatore.set("species", "chibi")
	camminatore.set("dna", DNA.generate(9182))
	visitors.add_child(camminatore)
	camminatore.global_position = DA
	await create_timer(0.3).timeout
	camminatore.global_position = DA
	camminatore.call("_walk_to", A, "r_idle")
	var tappe: Array = camminatore.get("_tappe")
	var elenco := "(%.1f,%.1f)" % [(camminatore.get("_target") as Vector3).x,
			(camminatore.get("_target") as Vector3).z]
	for p: Vector3 in tappe:
		elenco += " → (%.1f,%.1f)" % [p.x, p.z]
	print("       la strada che gli ha dato il villaggio: %s" % elenco)
	_dico(not tappe.is_empty(), "il villaggio gli detta una strada, non un punto")

	# ------------------------------------------------ e adesso si GUARDA
	# UN CAMPIONE PER FRAME, non uno ogni decimo: fra due campioni lontani
	# un corpo entra ed esce da un muro senza lasciare traccia, ed è
	# esattamente il passaggio che si vuole cogliere.
	var segs := _muri_segmenti(muri)
	var scia: Array[Vector3] = []
	var prima: Vector3 = camminatore.global_position
	var sfondamenti := 0
	var palo_piu_vicino := 99.0
	var frames := 0
	while frames < 6000 and str(camminatore.get("_state")) == "walk":
		await process_frame
		frames += 1
		var ora: Vector3 = camminatore.global_position
		scia.append(ora)
		var p0 := Vector2(prima.x, prima.z)
		var p1 := Vector2(ora.x, ora.z)
		if p0.distance_squared_to(p1) > 1e-14:
			for s in segs:
				if _taglia(p0, p1, s[0], s[1]):
					sfondamenti += 1
					print("         GUASTO: da (%.3f,%.3f) a (%.3f,%.3f) si taglia il muro %s–%s"
							% [p0.x, p0.y, p1.x, p1.y, s[0], s[1]])
					break
			for s2 in segs:
				for capo: Vector2 in [s2[0], s2[1]]:
					palo_piu_vicino = minf(palo_piu_vicino,
							Geometry2D.get_closest_point_to_segment(capo, p0, p1)
							.distance_to(capo))
		prima = ora
	print("       traiettoria (un campione ogni venti frame):")
	var riga := ""
	for i in scia.size():
		if i % 20 != 0:
			continue
		riga += "(%.1f,%.1f) " % [scia[i].x, scia[i].z]
		if riga.length() > 66:
			print("         " + riga)
			riga = ""
	if riga != "":
		print("         " + riga)
	print("       …e si ferma a (%.2f, %.2f) dopo %d frame, stato «%s»"
			% [camminatore.global_position.x, camminatore.global_position.z,
			frames, camminatore.get("_state")])

	_dico(camminatore.global_position.distance_to(A) < 0.05,
			"è ARRIVATO dall'altra parte del muro, sul punto chiesto (%.3f m)"
			% camminatore.global_position.distance_to(A))
	_dico(sfondamenti == 0,
			"e NESSUNO spostamento ha tagliato la staccionata (%d frame guardati)"
			% scia.size())
	# e non l'ha nemmeno sfiorata: la testata della staccionata chiude i
	# correnti con una pallina di 3 cm centrata sullo spigolo, in mezzo alla
	# fascia in cui cammina un chibi
	_dico(palo_piu_vicino > 0.04,
			"e non ha strusciato la testata (al più vicino: %.3f m)" % palo_piu_vicino)
	# il giro si vede: è uscito dal fascio delle campate
	var largo := 0.0
	for p in scia:
		largo = maxf(largo, absf(p.x - DA.x))
	_dico(largo > 1.5, "ha girato attorno per davvero (%.1f m di scarto dalla retta)" % largo)
	camminatore.queue_free()


# ------------------------------------------------------------- l'oracolo
#
# Non passa da `Varchi`: se il giudice fosse la stessa funzione che ha
# deciso la strada, misurerebbe la propria coerenza invece della verità.

## I muri come SEGMENTI di mondo: il confine fra due celle è un metro di
## retta, e sta sui mezzi interi.
func _muri_segmenti(muri: Dictionary) -> Array:
	var fuori := []
	for k: Vector2i in muri:
		if posmod(k.y, 2) == 1:
			@warning_ignore("integer_division")
			var cy := (k.y - 1) / 2
			@warning_ignore("integer_division")
			var cx := k.x / 2
			fuori.append([Vector2(cx - 0.5, cy + 0.5), Vector2(cx + 0.5, cy + 0.5)])
		else:
			@warning_ignore("integer_division")
			var cx2 := (k.x - 1) / 2
			@warning_ignore("integer_division")
			var cy2 := k.y / 2
			fuori.append([Vector2(cx2 + 0.5, cy2 - 0.5), Vector2(cx2 + 0.5, cy2 + 0.5)])
	return fuori


static func _orient(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


## I due segmenti si TAGLIANO davvero? Sfiorarsi a un capo non conta.
static func _taglia(p0: Vector2, p1: Vector2, q0: Vector2, q1: Vector2) -> bool:
	var e := 1e-9
	var d1 := _orient(q0, q1, p0)
	var d2 := _orient(q0, q1, p1)
	var d3 := _orient(p0, p1, q0)
	var d4 := _orient(p0, p1, q1)
	if absf(d1) < e or absf(d2) < e or absf(d3) < e or absf(d4) < e:
		return false
	return (d1 > 0.0) != (d2 > 0.0) and (d3 > 0.0) != (d4 > 0.0)


## Dove sta andando il corpo: la META del viaggio se ne ha una, altrimenti
## dov'è adesso. NON `_target`: da quando il corpo segue la rotta, quello è
## la prossima tappa — un angolo da girare, non il posto dove sta andando.
func _dove_va(corpo: Node3D) -> Vector3:
	var t = corpo.call("meta_cammino")
	if t is Vector3 and (t as Vector3) != Vector3.ZERO:
		return Vector3((t as Vector3).x, 0, (t as Vector3).z)
	return Vector3(corpo.global_position.x, 0, corpo.global_position.z)
