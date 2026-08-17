extends SceneTree
## LA DEVIAZIONE CONOSCE IL MONDO? — la prova viva, nel MainLevel VERO.
##
##   Godot --headless --path . --script res://tools/prova_fiume.gd
##
## `prova_recinto` guarda se il corpo attraversa una STACCIONATA. Questa
## guarda la cosa che nessuna staccionata può dire: **dove mette le zampe
## quando gira attorno**. Perché il grafo dei varchi è fatto dei soli bordi
## costruiti, e il letto del fiume — dove `place_cell` VIETA di costruire —
## è per costruzione privo di muri: cioè è il corridoio più economico che la
## ricerca possa trovare per aggirare un recinto vicino alla riva.
##
## Tre scene, e ognuna stampa una traiettoria vera campionata frame per
## frame:
##
##   1. IL FIUME. Una staccionata dal villaggio alla riva. Il vicino deve
##      girare — e il giro più corto passa nell'acqua. Si chiede a
##      `CozyWorld.is_river` (la stessa che rifiuta di piantarci un palo)
##      se ogni campione è nel letto del fiume.
##   2. LA PARETE. Uguale, ma verso la scogliera: là il terreno sale di due
##      metri e mezzo e il corpo ci camminerebbe dentro.
##   3. IL FALÒ. L'unico evento comunitario quotidiano, a cinquantacinque
##      celle da casa — cioè oltre il raggio entro cui si chiedeva una
##      strada. Con una staccionata piantata sul tragitto, si guarda se il
##      vicino la attraversa; e si misura quanto costa la sera in cui
##      ventotto vicini partono tutti insieme.
##
## L'ORACOLO NON È `Varchi`. I muri diventano i segmenti veri che occupano
## sul confine, ogni spostamento di frame è un segmento, e la domanda è se
## i due si tagliano. L'acqua la dice CozyWorld.

const VARCHI := preload("res://scenes/build/Varchi.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

## LA STACCIONATA FINO ALLA RIVA. Da x=5 a x=17 fra le righe z=8 e z=9:
## tutte celle asciutte e piazzabili (a x=17 il fiume è a 2.93 m dal
## centro, appena oltre il letto). Il capo est è a quattro celle dal
## vicino, il capo ovest a dieci: il giro più corto è quello che finisce
## nell'acqua.
const RIVA_X := [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
const RIVA_Z := 8
const RIVA_DA := Vector3(14.38, 0.0, 7.41)
const RIVA_A := Vector3(14.27, 0.0, 10.19)

## LA PARETE. Stessa forma, ma più a est: qui il giro corto scavalcherebbe
## la scogliera. La riga sta a z=-30, dove il canyon è largo e la riva est
## è terra buona: così il difetto non è «non c'era spazio», è «ha scelto di
## salire sul muro».
const PARETE_X := [24, 25, 26, 27, 28, 29]
const PARETE_Z := -30
const PARETE_DA := Vector3(28.4, 0.0, -31.4)
const PARETE_A := Vector3(28.4, 0.0, -28.6)

## IL FALÒ. La radura sta a (-1, -46) — la costante vive in Visitors, qui
## si legge da lì. La staccionata si pianta di traverso a metà strada.
const FALO_MURO_X := [-8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
const FALO_MURO_Z := -20
const CASA_FALO := Vector2i(2, 5)

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
	var cozy := livello.get_node_or_null("CozyWorld")
	if build == null or visitors == null or cozy == null:
		print("GUASTO: BuildSystem=%s Visitors=%s CozyWorld=%s"
				% [build, visitors, cozy])
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout
	visitors.call("debug_reset")

	print("\n=== DOVE STA L'ACQUA (letto del fiume secondo CozyWorld) ===")
	for z: int in [-30, 0, 8, 20]:
		var riga := ""
		for x in range(14, 24):
			riga += ("~" if bool(cozy.call("is_river", Vector3(x, 0, z))) else ".")
		print("  z=%4d  x 14..23: %s   (asse del fiume a x=%.2f, parete a x=%.2f)"
				% [z, riga, cozy.call("river_x_at", float(z)),
				cozy.call("cliff_x_at", float(z))])

	await _scena_riva(build, visitors, cozy)
	await _scena_parete(build, visitors, cozy)
	await _scena_falo(build, visitors, cozy)

	print("\n==== FIUME: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)


# ------------------------------------------------------------- le scene

func _scena_riva(build, visitors, cozy) -> void:
	print("\n--- 1) IL FIUME: la staccionata dal villaggio alla riva ---")
	for x: int in RIVA_X:
		build.call("place_edge", Vector2i(x * 2, RIVA_Z * 2 + 1), "Staccionata", false, false)
	build.call("aggiorna_varchi_ora")
	var muri: Dictionary = build.call("muri")
	print("       %d bordi murati nel villaggio" % muri.size())
	var esito := await _cammina(build, visitors, cozy, RIVA_DA, RIVA_A, muri)
	_dico(int(esito["sfondamenti"]) == 0,
			"non ha attraversato la staccionata (%d passaggi illeciti)"
			% esito["sfondamenti"])
	_dico(int(esito["in_acqua"]) == 0,
			"e NON HA MESSO LE ZAMPE NEL FIUME (%d campioni, %.2f m dentro il letto)"
			% [esito["in_acqua"], esito["metri_acqua"]])
	for x: int in RIVA_X:
		build.call("debug_remove_edge", Vector2i(x * 2, RIVA_Z * 2 + 1))
	build.call("aggiorna_varchi_ora")


func _scena_parete(build, visitors, cozy) -> void:
	print("\n--- 2) LA PARETE: la staccionata sulla riva est ---")
	for x: int in PARETE_X:
		build.call("place_edge", Vector2i(x * 2, PARETE_Z * 2 + 1), "Staccionata", false, false)
	build.call("aggiorna_varchi_ora")
	var muri: Dictionary = build.call("muri")
	var piantate := 0
	for x: int in PARETE_X:
		if muri.has(VARCHI.bordo_fra(Vector2i(x, PARETE_Z), Vector2i(x, PARETE_Z + 1))):
			piantate += 1
	print("       staccionata piantata: %d campate su %d" % [piantate, PARETE_X.size()])
	var esito := await _cammina(build, visitors, cozy, PARETE_DA, PARETE_A, muri)
	_dico(int(esito["oltre_parete"]) == 0,
			"non è salito sulla parete (%d campioni oltre il piede della scogliera)"
			% esito["oltre_parete"])
	_dico(int(esito["in_acqua"]) == 0,
			"e non è finito nel fiume (%d campioni)" % esito["in_acqua"])
	for x: int in PARETE_X:
		build.call("debug_remove_edge", Vector2i(x * 2, PARETE_Z * 2 + 1))
	build.call("aggiorna_varchi_ora")


func _scena_falo(build, visitors, cozy) -> void:
	print("\n--- 3) IL FALÒ: cinquantacinque celle, e una staccionata di traverso ---")
	var clearing: Vector3 = visitors.get("CLEARING")
	var plaza: Vector3 = visitors.get("PLAZA")
	print("       la radura è a %s, la piazza a %s: %d celle di Manhattan"
			% [clearing, plaza, absi(roundi(clearing.x - plaza.x))
			+ absi(roundi(clearing.z - plaza.z))])
	for x: int in FALO_MURO_X:
		build.call("place_edge", Vector2i(x * 2, FALO_MURO_Z * 2 + 1), "Staccionata", false, false)
	build.call("aggiorna_varchi_ora")
	var muri: Dictionary = build.call("muri")

	# un residente VERO, con la sua casa: il falò lo chiama `_routine` con
	# `do_routine("fire", posto, CLEARING)`, ed è quella la chiamata che si
	# vuole provare — non un `_walk_to` scritto a mano.
	build.call("place_cell", CASA_FALO, "Letto", 0, false)
	build.call("place_cell", CASA_FALO, "Tetto", 0, false)
	build.call("aggiorna_varchi_ora")
	visitors.call("debug_settle", 4242, CASA_FALO)
	await create_timer(0.8).timeout
	var residenti: Array = visitors.get("_residents")
	if residenti.is_empty():
		_dico(false, "nessun residente: il letto non ha fatto casa")
		return
	var corpo: Node3D = residenti[0]["node"]
	visitors.call("debug_gather_fire")     # phase=fire, lease lunga: l'agenda tace
	await process_frame
	var posto: Vector3 = visitors.call("_posto_al_falo", 0)
	var partenza := plaza + Vector3(0.37, 0, -0.28)
	corpo.position = partenza
	var orologio := Time.get_ticks_usec()
	corpo.call("do_routine", "fire", posto, clearing)
	var costo := Time.get_ticks_usec() - orologio
	var tappe: Array = corpo.get("_tappe")
	print("       la chiamata VERA (`do_routine(\"fire\", …)`, quella di")
	print("       `Visitors._routine`) gli detta %d tappe, in %d us"
			% [tappe.size(), costo])
	_dico(not tappe.is_empty(),
			"il villaggio gli detta una STRADA per il falò (non un punto)")

	# E ADESSO SI GUARDA IL CORPO. Non quello del residente: un residente
	# ha una vita — a metà strada il taccuino gli fa alzare la testa e la
	# camminata finisce — e quel che qui si vuole vedere è il TRAGITTO,
	# non l'IA. Stessa partenza, stessa meta, stesso `_walk_to`.
	var esito := await _cammina(build, visitors, cozy, partenza, posto, muri)
	_dico(int(esito["sfondamenti"]) == 0,
			"e non ha attraversato la staccionata (%d passaggi illeciti)"
			% esito["sfondamenti"])
	_dico(int(esito["in_acqua"]) == 0,
			"e non ha guadato niente (%d campioni nel fiume)" % esito["in_acqua"])
	_dico(bool(esito["arrivato"]),
			"ed è ARRIVATO al fuoco (%.2f m dal suo posto)" % esito["distanza"])

	# ------------------------------------------- e quanto costa la sera
	#
	# NON si sommano ventotto domande in fila e si chiama quello «il costo
	# della sera»: sarebbe la misura di un gioco che non esiste, perché a
	# 60 Hz quelle domande cadono su frame diversi. Si guardano due sere.
	var posti: Array = []
	for i in 28:
		posti.append([plaza + Vector3(cos(float(i)) * 6.0, 0, sin(float(i) * 1.7) * 6.0),
				clearing + Vector3(cos(float(i) * 0.9) * 2.4, 0, sin(float(i)) * 2.4)])

	# 1) LA SERA VERA. `Visitors._routine`, quando la fase diventa «fire»,
	#    dà a ciascuno un lease `randf_range(0.4, 1.8)`: a 60 Hz sono
	#    ottantaquattro frame per ventotto partenze.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260810
	var quando: Array[int] = []
	for _i in 28:
		quando.append(int(rng.randf_range(0.4, 1.8) * 60.0))
	print("\n       la sera VERA (lease 0.4–1.8 s, come in `Visitors._routine`)")
	var vera := await _sera(build, posti, quando)
	print("       %d serviti; il frame peggiore: %.2f ms su 16.7 "
			% [vera["serviti"], vera["peggiore"] / 1000.0]
			+ "(%d domande nel frame più affollato)" % vera["max_domande"])
	print("       le domande, in ordine di arrivo: %s" % vera["ordine"])

	# 2) IL CASO PEGGIORE POSSIBILE, che la realtà non produce mai: tutti e
	#    ventotto nello stesso identico frame. Serve a vedere il TETTO, e a
	#    provare che il turno non perde nessuno per strada.
	var tutti: Array[int] = []
	for _i in 28:
		tutti.append(0)
	print("\n       e il caso peggiore possibile: tutti nello stesso frame")
	var pess := await _sera(build, posti, tutti)
	print("       %d serviti in %d frame (%.0f ms di gioco); "
			% [pess["serviti"], pess["frames"], pess["frames"] * 16.7]
			+ "il frame peggiore: %.2f ms" % (pess["peggiore"] / 1000.0))
	print("       la domanda più cara: %.2f ms; la mediana: %.2f ms"
			% [pess["max_domanda"] / 1000.0, pess["mediana"] / 1000.0])
	# LE PROVE SONO SUL MECCANISMO, non su un numero di millisecondi che
	# cambia con la macchina. Quello che deve restare vero per sempre è:
	# il turno SFALSA (mai una pila di ricerche in un frame solo) e non
	# PERDE nessuno. I millisecondi si stampano perché servono a chi legge,
	# ma la soglia è larga apposta: è lì per accorgersi di un turno tolto
	# (ventotto ricerche insieme farebbero cinquanta millisecondi), non per
	# arbitrare decimi.
	_dico(int(pess["serviti"]) == 28,
			"nemmeno nel caso peggiore qualcuno resta senza strada (%d su 28)"
			% pess["serviti"])
	_dico(int(pess["max_domande"]) <= 3,
			"e il turno le sfalsa: al più %d ricerche in un frame, non 28"
			% pess["max_domande"])
	_dico(float(pess["peggiore"]) < 12000.0,
			"nessun frame ci passa dentro mezza giornata (%.2f ms su 16.7)"
			% (float(pess["peggiore"]) / 1000.0))
	for x: int in FALO_MURO_X:
		build.call("debug_remove_edge", Vector2i(x * 2, FALO_MURO_Z * 2 + 1))
	build.call("aggiorna_varchi_ora")


## UNA SERA, frame per frame. `quando[i]` è il frame in cui il vicino i si
## alza; chi trova il turno occupato ritenta al frame dopo, esattamente
## come fa `Visitor._rotta_attesa`.
func _sera(build, posti: Array, quando: Array[int]) -> Dictionary:
	var attesa: Array = []
	var serviti := 0
	var peggiore := 0.0
	var max_domande := 0
	var costi: Array[float] = []
	var ordine := ""
	var f := 0
	while f < 400 and (serviti < posti.size() or not attesa.is_empty()):
		await process_frame
		var pronti: Array = attesa.duplicate()
		attesa.clear()
		for i in posti.size():
			if quando[i] == f:
				pronti.append(i)
		var speso := 0.0
		var domande := 0
		for i: int in pronti:
			if not bool(build.call("turno_rotte_libero")):
				attesa.append(i)      # «fra un frame»: nessuno perde la strada
				continue
			var t0 := Time.get_ticks_usec()
			var r: Array = build.call("deviazione", posti[i][0], posti[i][1])
			var dt := float(Time.get_ticks_usec() - t0)
			speso += dt
			domande += 1
			costi.append(dt)
			ordine += "%.1f " % (dt / 1000.0)
			if not r.is_empty():
				serviti += 1
		peggiore = maxf(peggiore, speso)
		max_domande = maxi(max_domande, domande)
		f += 1
	costi.sort()
	return {"serviti": serviti, "peggiore": peggiore, "frames": f,
			"max_domande": max_domande, "ordine": ordine,
			"max_domanda": 0.0 if costi.is_empty() else costi[costi.size() - 1],
			"mediana": 0.0 if costi.is_empty() else costi[costi.size() / 2]}


# ------------------------------------------------------- il camminatore

## Un chibi vero, messo in scena apposta e NON iscritto fra i residenti:
## così nessuna routine gli cambia stato a metà strada e quel che si vede è
## la camminata, non l'IA.
func _cammina(build, visitors, cozy, da: Vector3, a: Vector3,
		muri: Dictionary) -> Dictionary:
	var v: Node3D = VISITOR.new()
	v.set("species", "chibi")
	v.set("dna", DNA.generate(9182))
	visitors.add_child(v)
	v.global_position = da
	await create_timer(0.3).timeout
	v.global_position = da
	var orologio := Time.get_ticks_usec()
	v.call("_walk_to", a, "r_idle")
	var costo := Time.get_ticks_usec() - orologio
	var tappe: Array = v.get("_tappe")
	var elenco := "(%.1f,%.1f)" % [(v.get("_target") as Vector3).x,
			(v.get("_target") as Vector3).z]
	for p: Vector3 in tappe:
		elenco += " → (%.1f,%.1f)" % [p.x, p.z]
	print("       la strada che gli ha dato il villaggio (%d us): %s" % [costo, elenco])
	var esito := await _segui(v, cozy, muri, 90.0)
	esito["distanza"] = v.global_position.distance_to(a)
	esito["arrivato"] = v.global_position.distance_to(a) < 0.05
	v.queue_free()
	return esito


## Segue il corpo frame per frame e giudica ogni SPOSTAMENTO: ha tagliato
## un muro? ha messo la zampa nell'acqua? è salito sulla parete?
func _segui(corpo: Node3D, cozy, muri: Dictionary, secondi: float) -> Dictionary:
	var segs := _muri_segmenti(muri)
	var scia: Array[Vector3] = []
	var prima: Vector3 = corpo.global_position
	var sfondamenti := 0
	var in_acqua := 0
	var oltre_parete := 0
	var metri_acqua := 0.0
	var dentro_max := 0.0
	var frames := 0
	var tetto := int(secondi * 60.0)
	while frames < tetto and str(corpo.get("_state")) == "walk":
		await process_frame
		frames += 1
		var ora: Vector3 = corpo.global_position
		scia.append(ora)
		var p0 := Vector2(prima.x, prima.z)
		var p1 := Vector2(ora.x, ora.z)
		if p0.distance_squared_to(p1) > 1e-14:
			for s in segs:
				if _taglia(p0, p1, s[0], s[1]):
					sfondamenti += 1
					print("         GUASTO: da (%.2f,%.2f) a (%.2f,%.2f) taglia il muro %s–%s"
							% [p0.x, p0.y, p1.x, p1.y, s[0], s[1]])
					break
		# L'ACQUA la dice CozyWorld, non io: `is_river` è la stessa domanda
		# con cui `place_cell` rifiuta di piantare un palo nel letto.
		if bool(cozy.call("is_river", ora)):
			in_acqua += 1
			metri_acqua += p0.distance_to(p1)
			dentro_max = maxf(dentro_max,
					2.9 - absf(ora.x - float(cozy.call("river_x_at", ora.z))))
		if ora.x > float(cozy.call("cliff_x_at", ora.z)) - 0.55:
			oltre_parete += 1
		prima = ora
	print("       traiettoria (un campione ogni venti frame):")
	var riga := ""
	for i in scia.size():
		if i % 20 != 0:
			continue
		riga += "(%.1f,%.1f)%s " % [scia[i].x, scia[i].z,
				("~" if bool(cozy.call("is_river", scia[i])) else "")]
		if riga.length() > 62:
			print("         " + riga)
			riga = ""
	if riga != "":
		print("         " + riga)
	print("       …fermo a (%.2f, %.2f) dopo %d frame, stato «%s»"
			% [corpo.global_position.x, corpo.global_position.z, frames,
			corpo.get("_state")])
	if in_acqua > 0:
		print("       NEL FIUME per %d frame, %.2f m di cammino, fino a %.2f m "
				% [in_acqua, metri_acqua, dentro_max]
				+ "dentro il letto (l'acqua è a y=%.2f, il corpo a y=0)"
				% float(cozy.get("RIVER_WATER_Y")))
	if oltre_parete > 0:
		print("       SULLA PARETE per %d frame (il terreno lì sta a y=%.2f)"
				% [oltre_parete, float(cozy.get("CLIFF_H"))])
	return {"sfondamenti": sfondamenti, "in_acqua": in_acqua,
			"oltre_parete": oltre_parete, "metri_acqua": metri_acqua,
			"frames": frames}


# ------------------------------------------------------------- l'oracolo

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


static func _taglia(p0: Vector2, p1: Vector2, q0: Vector2, q1: Vector2) -> bool:
	var e := 1e-9
	var d1 := _orient(q0, q1, p0)
	var d2 := _orient(q0, q1, p1)
	var d3 := _orient(p0, p1, q0)
	var d4 := _orient(p0, p1, q1)
	if absf(d1) < e or absf(d2) < e or absf(d3) < e or absf(d4) < e:
		return false
	return (d1 > 0.0) != (d2 > 0.0) and (d3 > 0.0) != (d4 > 0.0)
