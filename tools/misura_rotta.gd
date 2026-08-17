extends SceneTree
## IL METRO DELLA RICERCA — quanto costa chiedere una strada, e a chi.
##
##   Godot --headless --path . --script res://tools/misura_rotta.gd
##
## `misura_cammino` misura il CORPO (quanto sbanda, quanti muri attraversa).
## Questo misura la RICERCA, che è l'altra metà del conto e l'unica che può
## far singhiozzare un frame:
##
##   1. quante celle si espandono, e quanto costano — in ampiezza (BFS)
##      contro guidata dalla distanza (A\*), sul tragitto vero piazza→falò;
##   2. la sera del falò: ventotto vicini che partono, uno dopo l'altro;
##   3. la memoria del suolo: quante volte si disturba il mondo, con e
##      senza;
##   4. e la controprova che conta: **la strada trovata è la più corta?**
##      Confronto contro una BFS scritta QUI, che non è quella del gioco.
##
## ## Come si contano le celle espanse SENZA strumentare il gioco
##
## `rotta` torna vuota quando il tetto è speso: allora il numero di celle
## che le servono è il più piccolo tetto con cui trova ancora la strada, e
## lo si cerca per bisezione. Nessun contatore da aggiungere al codice di
## produzione, nessuno stato globale — e il numero è quello vero.

const VARCHI := preload("res://scenes/build/Varchi.gd")

## La staccionata di traverso sul tragitto del falò (quindici campate).
const FALO_MURO_X := [-8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
const FALO_MURO_Z := -20


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	var cozy := livello.get_node_or_null("CozyWorld")
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout
	visitors.call("debug_reset")

	var plaza: Vector3 = visitors.get("PLAZA")
	var clearing: Vector3 = visitors.get("CLEARING")
	for x: int in FALO_MURO_X:
		build.call("place_edge", Vector2i(x * 2, FALO_MURO_Z * 2 + 1), "Staccionata", false, false)
	build.call("aggiorna_varchi_ora")
	var muri: Dictionary = build.call("muri")
	var suolo = build.call("suolo")

	print("\n=== IL METRO DELLA RICERCA ===")
	print("villaggio: %d bordi murati; piazza %s → falò %s (%d celle)"
			% [muri.size(), plaza, clearing,
			VARCHI.manhattan(Vector2i(roundi(plaza.x), roundi(plaza.z)),
			Vector2i(roundi(clearing.x), roundi(clearing.z)))])

	var da := Vector2i(roundi(plaza.x), roundi(plaza.z))
	var a := Vector2i(roundi(clearing.x), roundi(clearing.z))

	# --------------------------------------------- 1) in ampiezza vs guidata
	print("\n--- 1) il tragitto del falò, con la staccionata di traverso ---")
	var t0 := Time.get_ticks_usec()
	var via := VARCHI.rotta(muri, da, a, VARCHI.MAX_CELLE, suolo)
	var us_a := Time.get_ticks_usec() - t0
	print("  A*  : %d celle di strada, %d us" % [via.size(), us_a])
	print("        celle espanse: %d" % _quante_espande(muri, da, a, suolo))
	t0 = Time.get_ticks_usec()
	var via_bfs := _bfs(muri, da, a, 200000, suolo)
	var us_b := Time.get_ticks_usec() - t0
	print("  BFS : %d celle di strada, %d us, %d celle toccate"
			% [via_bfs.size(), us_b, _quante_bfs(muri, da, a, suolo)])
	print("  → la strada è LUNGA UGUALE (%d contro %d): la guida non fa "
			% [via.size(), via_bfs.size()] + "sconti sulla lunghezza")
	print("  → e con il tetto di gioco (%d) la BFS non ci sarebbe arrivata: %d celle"
			% [VARCHI.ROTTA_TETTO, _bfs(muri, da, a, VARCHI.ROTTA_TETTO, suolo).size()])

	# ------------------------------------------------------ 2) la sera vera
	print("\n--- 2) la sera del falò: 28 vicini, una domanda a testa ---")
	for giro in 2:
		var totale := 0.0
		var peggiore := 0.0
		var tappe_tot := 0
		var prima_domande: int = suolo.domande
		for i in 28:
			var p := plaza + Vector3(cos(float(i)) * 6.0, 0, sin(float(i) * 1.7) * 6.0)
			var q := clearing + Vector3(cos(float(i) * 0.9) * 2.4, 0, sin(float(i)) * 2.4)
			var t := Time.get_ticks_usec()
			var r: Array = build.call("deviazione", p, q)
			var dt := float(Time.get_ticks_usec() - t)
			totale += dt
			peggiore = maxf(peggiore, dt)
			tappe_tot += r.size()
		print("  %s: %.2f ms in tutto, la peggiore %.2f ms, %d tappe, "
				% ["a freddo" if giro == 0 else "a caldo", totale / 1000.0,
				peggiore / 1000.0, tappe_tot]
				+ "%d domande al mondo" % (suolo.domande - prima_domande))

	# ------------------------------------------- 2b) e dove se ne va il tempo
	print("\n--- 2b) il conto in dettaglio, su una domanda sola (a caldo) ---")
	var p2 := plaza + Vector3(0.37, 0, -0.28)
	var q2 := clearing + Vector3(1.1, 0, 0.4)
	var giri := 20
	var t_gate := 0.0
	var t_rotta := 0.0
	var t_filo := 0.0
	for _g in giri:
		var t := Time.get_ticks_usec()
		VARCHI.filo_libero(muri, Vector2(p2.x, p2.z), Vector2(q2.x, q2.z))
		t_gate += float(Time.get_ticks_usec() - t)
		t = Time.get_ticks_usec()
		var celle := VARCHI.rotta(muri, VARCHI.cella(Vector2(p2.x, p2.z)),
				VARCHI.cella(Vector2(q2.x, q2.z)), VARCHI.ROTTA_TETTO, suolo)
		t_rotta += float(Time.get_ticks_usec() - t)
		var spina: Array[Vector2] = [Vector2(p2.x, p2.z)]
		for c: Vector2i in celle:
			spina.append(Vector2(c))
		spina.append(Vector2(q2.x, q2.z))
		t = Time.get_ticks_usec()
		VARCHI.tira_filo_mondo(muri, spina, suolo)
		t_filo += float(Time.get_ticks_usec() - t)
	print("  cancello (la retta ha muri?) : %6.0f us" % (t_gate / giri))
	print("  la RICERCA                   : %6.0f us" % (t_rotta / giri))
	print("  il FILO TESO                 : %6.0f us" % (t_filo / giri))

	# ------------------------- 2bis) quanto esplora OGNI vicino, e perché
	#
	# La media non dice niente: quello che conta è il PEGGIORE, ed è il
	# vicino per cui i due giri — a destra e a sinistra della staccionata —
	# costano quasi uguale. Lì la ricerca non può scegliere: deve aprirli
	# tutti e due fino in fondo.
	print("\n--- 2bis) celle espanse, vicino per vicino ---")
	var espansioni: Array[int] = []
	for i in 28:
		var p := plaza + Vector3(cos(float(i)) * 6.0, 0, sin(float(i) * 1.7) * 6.0)
		var q := clearing + Vector3(cos(float(i) * 0.9) * 2.4, 0, sin(float(i)) * 2.4)
		espansioni.append(_quante_espande(muri, VARCHI.cella(Vector2(p.x, p.z)),
				VARCHI.cella(Vector2(q.x, q.z)), suolo))
	espansioni.sort()
	print("  minimo %d · mediana %d · massimo %d   (tetto di gioco: %d)"
			% [espansioni[0], espansioni[14], espansioni[27], VARCHI.ROTTA_TETTO])

	# -------------------------------- 2c) quanto costa CHIEDERE AL MONDO
	print("\n--- 2c) il prezzo di una domanda al mondo (terreno_vietato) ---")
	var quante_c := 20000
	var t3 := Time.get_ticks_usec()
	for i in quante_c:
		cozy.call("terreno_vietato", Vector2i(i % 60 - 10, (i / 60) % 60 - 30))
	var us_cella := float(Time.get_ticks_usec() - t3) / float(quante_c)
	print("  %.2f us per cella  →  una rotta nuova da 800 celle: %.1f ms"
			% [us_cella, us_cella * 800.0 / 1000.0])

	# ------------------------------------------------- 3) la memoria del suolo
	print("\n--- 3) la memoria del suolo ---")
	print("  celle ricordate: %d   domande fatte al mondo: %d"
			% [suolo.ricordate(), suolo.domande])
	var senza = VARCHI.Suolo.new(Callable(cozy, "terreno_vietato"))
	var quante := 0
	for i in 28:
		var p := plaza + Vector3(cos(float(i)) * 6.0, 0, sin(float(i) * 1.7) * 6.0)
		var q := clearing + Vector3(cos(float(i) * 0.9) * 2.4, 0, sin(float(i)) * 2.4)
		VARCHI.rotta(muri, VARCHI.cella(Vector2(p.x, p.z)),
				VARCHI.cella(Vector2(q.x, q.z)), VARCHI.ROTTA_TETTO, senza)
		quante += 1
	print("  la stessa sera SENZA memoria costerebbe %d domande al mondo "
			% (senza.domande * 0 + _senza_memoria(muri, plaza, clearing, cozy))
			+ "invece di %d" % senza.domande)

	# ------------------------------------- 4) è davvero la strada più corta?
	print("\n--- 4) la strada è la più corta? (300 villaggi a caso) ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260810
	var uguali := 0
	var provati := 0
	var piu_lunghe := 0
	for _v in 300:
		var m := _villaggio_a_caso(rng)
		var p0 := Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var p1 := Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var r1 := VARCHI.rotta(m, p0, p1)
		var r2 := _bfs(m, p0, p1, 200000, null)
		provati += 1
		if r1.size() == r2.size():
			uguali += 1
		elif r1.size() > r2.size():
			piu_lunghe += 1
	print("  %d/%d lunghezze identiche alla BFS (%d più lunghe)"
			% [uguali, provati, piu_lunghe])
	quit(0)


# ----------------------------------------------------------- gli strumenti

## Quante celle espande `rotta` per questa domanda: il più piccolo tetto
## con cui trova ancora la strada, cercato per bisezione. Il tetto è per
## definizione il numero di espansioni concesse, quindi il risultato è
## esatto — e non è servito strumentare niente.
func _quante_espande(muri: Dictionary, da: Vector2i, a: Vector2i, suolo) -> int:
	var lo := 1
	var hi := 200000
	while lo < hi:
		@warning_ignore("integer_division")
		var mid := (lo + hi) / 2
		if VARCHI.rotta(muri, da, a, mid, suolo).is_empty():
			lo = mid + 1
		else:
			hi = mid
	return lo


func _quante_bfs(muri: Dictionary, da: Vector2i, a: Vector2i, suolo) -> int:
	var lo := 1
	var hi := 200000
	while lo < hi:
		@warning_ignore("integer_division")
		var mid := (lo + hi) / 2
		if _bfs(muri, da, a, mid, suolo).is_empty():
			lo = mid + 1
		else:
			hi = mid
	return lo


## LA BFS DI RIFERIMENTO — scritta qui, non presa dal gioco: se il giudice
## fosse la stessa funzione che cerca, misurerebbe la propria coerenza.
## In ampiezza pura, senza stima: la strada che trova è per definizione la
## più corta.
func _bfs(muri: Dictionary, da: Vector2i, a: Vector2i, tetto: int,
		suolo) -> Array:
	if da == a:
		return [da]
	var padre := {da: da}
	var coda: Array = [da]
	var i := 0
	while i < coda.size() and i < tetto:
		var c: Vector2i = coda[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if padre.has(n):
				continue
			if muri.has(c * 2 + d):
				continue
			if suolo != null and bool(suolo.vietata(n)):
				continue
			padre[n] = c
			if n == a:
				var giu: Array = [a]
				var cur := a
				while cur != da:
					cur = padre[cur]
					giu.append(cur)
				giu.reverse()
				return giu
			coda.append(n)
	return []


## Quante domande costerebbe la stessa sera se ogni cella si chiedesse al
## mondo ogni volta invece di ricordarsela: un suolo nuovo per ogni vicino.
func _senza_memoria(muri: Dictionary, plaza: Vector3, clearing: Vector3, cozy) -> int:
	var tot := 0
	for i in 28:
		var fresco = VARCHI.Suolo.new(Callable(cozy, "terreno_vietato"))
		var p := plaza + Vector3(cos(float(i)) * 6.0, 0, sin(float(i) * 1.7) * 6.0)
		var q := clearing + Vector3(cos(float(i) * 0.9) * 2.4, 0, sin(float(i)) * 2.4)
		VARCHI.rotta(muri, VARCHI.cella(Vector2(p.x, p.z)),
				VARCHI.cella(Vector2(q.x, q.z)), VARCHI.ROTTA_TETTO, fresco)
		tot += fresco.domande
	return tot


func _villaggio_a_caso(rng: RandomNumberGenerator) -> Dictionary:
	var m := {}
	for _k in rng.randi_range(4, 40):
		var c := Vector2i(rng.randi_range(-7, 7), rng.randi_range(-7, 7))
		var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
		m[c * 2 + d] = true
	return m
