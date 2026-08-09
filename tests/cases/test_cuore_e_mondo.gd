extends RefCounted
## IL CUORE E IL MONDO — la guardia di cinque difetti trovati il 2026-08-09.
##
## Tutti e cinque erano invisibili a una lettura del sorgente e vivevano in
## posti che nessun test toccava: due nel C++, uno fra C++ e shader, uno in
## un metodo che il chiamante credeva esistesse, uno in un `match` senza il
## suo caso. Perciò qui NON si cerca una stringa nei file: si entra nello
## stato vero, si fa girare il codice vero e si misura.
##
##  A. A stamina ZERO Mochi correva a 3.0 (walk_speed) mentre da sfinita
##     correva a 1.7: la scala 6.0 → 1.7 → 3.0 non era monotona.
##  B. `.normalized()` sull'input rendeva PIENA qualunque inclinazione del
##     levetta, e con la velocità sempre al massimo la calma del Fiato
##     Sospeso restava incollata a zero mentre ti muovi.
##  C. Al MultiMesh andava l'OROLOGIO interno invece dello sfasamento: lo
##     shader lo moltiplica per 6.283, quindi la derivata dell'orologio si
##     sommava alla frequenza e le lucciole pulsavano 2,6 volte più veloci.
##  D. `CozyWorld.distanza_dall_acqua()` non esisteva: il taccuino del Gufo
##     ripiegava sul solo fiume e chiamava «prato» la riva dello stagno.
##  E. La damigella di velo cadeva nel `default` del match e nasceva col
##     corpo (immobile) della cicala.
##
## NOTA DI TECNICA: `_physics_process` di una GDExtension non è chiamabile
## per nome da GDScript (non è in ClassDB). Lo si fa partire col suo
## NOTIFICATION_PHYSICS_PROCESS, che è la stessa strada che usa il motore —
## e per quello il nodo deve stare nell'albero, altrimenti il delta è zero.

const NOT_FISICA := Node.NOTIFICATION_PHYSICS_PROCESS


func run(t) -> void:
	_test_scala_dello_sfinimento(t)
	_test_andatura_analogica(t)
	_test_sfasamento_costante_orologio_vivo(t)
	_test_distanza_dall_acqua(t)
	_test_damigella_ha_un_corpo(t)


# ======================================================== A · lo sfinimento

## La scala della corsa deve essere MONOTONA: più sei a terra, più vai
## piano. Chi è completamente esaurito non può superare chi è quasi
## esaurito — ed è esattamente quello che succedeva, perché a stamina 0 il
## C++ non toccava `current_speed` e restava a walk_speed.
func _test_scala_dello_sfinimento(t) -> void:
	if not ClassDB.class_exists("PlayerController"):
		t.ok(false, "PlayerController assente: la GDExtension non è caricata")
		return
	var pc = _banco()
	var sc = pc.get_node("SurvivalComponent")
	t.stage(pc)
	pc.walk_speed = 3.0
	Input.action_press("ui_down") # avanti, a fondo corsa

	# i tre gradini VERI, con i numeri che MainLevel scrive su run_speed
	var fresca := _velocita(pc, sc, 6.0, 100.0, true)
	var sfinita := _velocita(pc, sc, 1.7, 0.4, true)
	var a_terra := _velocita(pc, sc, 1.7, 0.0, true)
	var stamina_dopo = sc.get_stamina()
	var passo := _velocita(pc, sc, 1.7, 0.0, false)

	Input.action_release("ui_down")
	Input.action_release("ui_accept")

	t.almost(fresca, 6.0, "riposata e in corsa: va a run_speed pieno", 0.01)
	t.almost(sfinita, 1.7, "sfinita: va all'andatura che le lascia il GDScript", 0.01)
	t.almost(a_terra, 1.7,
			"a stamina ZERO resta a 1.7 (prima saltava a walk_speed = 3.0)", 0.01)
	t.almost(passo, 3.0, "senza il tasto di corsa cammina, sempre", 0.01)
	t.ok(a_terra <= sfinita + 0.001,
			"la scala è monotona: a terra (%.2f) non supera lo sfinimento (%.2f)"
			% [a_terra, sfinita])
	t.ok(a_terra < passo,
			"a terra (%.2f) si va più piano che a passeggio (%.2f), non più forte"
			% [a_terra, passo])
	t.almost(stamina_dopo, 0.0,
			"col tasto premuto a zero la stamina NON si ricarica (niente sfarfallio)",
			0.001)


# ======================================================== B · l'andatura

## L'inclinazione del levetta È l'andatura. Con `.normalized()` qualunque
## tocco oltre la deadzone dava velocità piena, e FiatoSospeso.calma() —
## che è 1 - velocita/3.0 — restava a zero per tutto il tempo in cui ti
## muovi: il prato aveva sempre la paura al massimo.
func _test_andatura_analogica(t) -> void:
	if not ClassDB.class_exists("PlayerController"):
		return
	var pc = _banco()
	var sc = pc.get_node("SurvivalComponent")
	t.stage(pc)
	pc.walk_speed = 3.0

	Input.action_press("ui_down") # levetta a fondo
	var pieno := _velocita(pc, sc, 6.0, 100.0, false)
	Input.action_release("ui_down")

	Input.action_press("ui_down", 0.45) # levetta accompagnata
	# quanto vale DAVVERO questa inclinazione dopo la deadzone: il banco di
	# prova non deve indovinarlo, deve chiederlo allo stesso Input che legge
	# il C++ (se un domani cambia la deadzone, il test resta vero)
	var inclinazione := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").length()
	var accompagnato := _velocita(pc, sc, 6.0, 100.0, false)
	Input.action_release("ui_down")

	t.ok(inclinazione > 0.05 and inclinazione < 0.9,
			"il banco di prova ha davvero un'inclinazione parziale (%.3f)" % inclinazione)
	t.almost(pieno, 3.0, "a fondo corsa si cammina a walk_speed pieno", 0.01)
	t.almost(accompagnato, 3.0 * inclinazione,
			"accompagnando il levetta la velocità è PROPORZIONALE all'inclinazione",
			0.02)
	t.ok(accompagnato < pieno * 0.9,
			"mezza inclinazione non dà velocità piena (%.2f contro %.2f)"
			% [accompagnato, pieno])
	# e la conseguenza che conta: a quell'andatura la calma esiste ancora
	var calma := clampf(1.0 - accompagnato / 3.0, 0.0, 1.0)
	t.ok(calma > 0.05,
			"muovendosi piano il prato ha ancora un po' di calma (%.2f), non zero" % calma)


## Il banco: il SurvivalComponent va appeso PRIMA di entrare nell'albero —
## il _ready del C++ lo cerca per nome una volta sola, e appenderlo dopo
## lascia il controller senza stamina (con tanto di printerr nel log).
func _banco():
	var pc = ClassDB.instantiate("PlayerController")
	var sc = ClassDB.instantiate("SurvivalComponent")
	sc.name = "SurvivalComponent"
	pc.add_child(sc)
	return pc


## Un tick di fisica vero, e la velocità piana che ne esce.
func _velocita(pc, sc, run_speed: float, stamina: float, corsa: bool) -> float:
	pc.run_speed = run_speed
	sc.set_stamina(stamina)
	if corsa:
		Input.action_press("ui_accept")
	else:
		Input.action_release("ui_accept")
	pc.velocity = Vector3.ZERO
	pc.notification(NOT_FISICA)
	var v = pc.velocity
	return Vector2(v.x, v.z).length()


# ============================================ C · sfasamento vs orologio

## Il campo che arriva allo shader (INSTANCE_CUSTOM.x) è uno SFASAMENTO
## costante: lì viene moltiplicato per 6.283, e un valore che cresce nel
## tempo somma la propria derivata alla frequenza del lampeggio. Ma lo
## stesso oggetto ha ANCHE un orologio interno che deve girare: il test
## pretende le due cose insieme, così non si può passarlo congelando tutto.
func _test_sfasamento_costante_orologio_vivo(t) -> void:
	if not ClassDB.class_exists("EcosystemManager"):
		t.ok(false, "EcosystemManager assente: la GDExtension non è caricata")
		return
	# ATTENZIONE: in headless il RenderingServer è finto e
	# MultiMesh.get_instance_custom_data() torna SEMPRE (0,0,0,1) — verificato.
	# Perciò si legge da debug_farfalla/debug_lucciola, che riportano il
	# valore registrato sul posto dallo stesso Color spedito al MultiMesh.
	var eco = t.stage(ClassDB.instantiate("EcosystemManager"))
	var quad := QuadMesh.new()
	eco.configure(quad, quad, quad)
	eco.set_night(true) # senza notte le lucciole non vengono nemmeno disegnate
	eco.notification(NOT_FISICA)

	var ff0 = eco.debug_lucciola(0)
	var bf0 = eco.debug_farfalla(0)
	t.ok(not ff0.is_empty(), "di notte qualche lucciola c'è")
	t.ok(not bf0.is_empty(), "e qualche farfalla vola")
	if ff0.is_empty() or bf0.is_empty():
		return

	# 45 tick ≈ 0.75 s: sotto il passo di sim_step (1.5 s), così nessuna
	# farfalla cambia stato e l'istanza 0 è ancora la stessa bestia
	for i in 45:
		eco.notification(NOT_FISICA)
	var ff1 = eco.debug_lucciola(0)
	var bf1 = eco.debug_farfalla(0)

	t.almost(float(ff1["shader_x"]), float(ff0["shader_x"]),
			"lo sfasamento della lucciola è COSTANTE (prima cresceva di 0.6 al secondo)",
			0.0005)
	t.almost(float(bf1["shader_x"]), float(bf0["shader_x"]),
			"lo sfasamento della farfalla è COSTANTE (prima cresceva di 1.0 al secondo)",
			0.0005)
	# ...ma l'orologio interno DEVE aver girato, altrimenti la costanza qui
	# sopra la otterrebbe anche un ecosistema morto
	var giro_ff: float = (ff1["pos"] as Vector3).distance_to(ff0["pos"] as Vector3)
	var giro_bf: float = (bf1["pos"] as Vector3).distance_to(bf0["pos"] as Vector3)
	t.ok(giro_ff > 0.02,
			"nel frattempo la lucciola ha continuato il suo giro (%.3f m)" % giro_ff)
	t.ok(giro_bf > 0.02,
			"nel frattempo la farfalla si è mossa (%.3f m)" % giro_bf)
	# e gli sfasamenti servono a SPARPAGLIARE: devono stare in 0..1 e
	# differire fra loro, o le lucciole lampeggerebbero all'unisono
	var basso := 2.0
	var alto := -1.0
	for i in 8:
		var riga = eco.debug_lucciola(i)
		if riga.is_empty():
			continue
		var v := float(riga["shader_x"])
		basso = minf(basso, v)
		alto = maxf(alto, v)
	t.ok(basso >= 0.0 and alto <= 1.0,
			"gli sfasamenti stanno in 0..1 (%.3f … %.3f)" % [basso, alto])
	t.ok(alto - basso > 0.15,
			"e sono sparpagliati: le lucciole non lampeggiano all'unisono")


# ========================================================= D · l'acqua

## Il taccuino del Gufo chiede a CozyWorld quanto dista l'acqua per poter
## citare il posto giusto in una lettera. Il metodo non c'era, e il
## ripiego (la sola curva del fiume) chiamava «prato» la riva dello stagno:
## per quel sistema una citazione che non combacia è l'unico guasto grave.
func _test_distanza_dall_acqua(t) -> void:
	var CW := load("res://scenes/world/CozyWorld.gd")
	var MATH := load("res://scenes/world/WorldMath.gd")
	var cw = CW.new() # fuori dall'albero: il metodo è pura geometria
	t.ok(cw.has_method("distanza_dall_acqua"),
			"CozyWorld espone distanza_dall_acqua (il taccuino la cerca per nome)")
	if not cw.has_method("distanza_dall_acqua"):
		cw.free()
		return
	var centro = cw.POND_CENTER
	var raggio = cw.POND_R

	# 1) la riva dello stagno — ed è ESATTAMENTE il punto in cui Collection
	#    fa nascere rana e damigella: centro + direzione * (POND_R + 0.5)
	var riva := Vector3(centro.x + raggio + 0.5, 0.0, centro.z)
	var d_riva = cw.distanza_dall_acqua(riva)
	var solo_fiume := absf(riva.x - float(MATH.river_x(riva.z)))
	t.ok(d_riva < 4.0,
			"sulla riva dello stagno l'acqua è vicina (%.2f m)" % d_riva)
	t.ok(solo_fiume > 4.0,
			"…e col solo fiume quel punto risultava lontano %.2f m: era il difetto"
			% solo_fiume)

	# 2) lo stagno è un'ELLISSE (il disco d'acqua ha scale.x = 1.15): alla
	#    stessa distanza dal centro, a est si è ancora sull'acqua, a nord no
	var est := Vector3(centro.x + raggio + 0.3, 0.0, centro.z)
	var nord := Vector3(centro.x, 0.0, centro.z + raggio + 0.3)
	t.almost(cw.distanza_dall_acqua(est), 0.0,
			"a est, dove l'acqua si allunga, si è ancora dentro lo stagno", 0.001)
	t.ok(cw.distanza_dall_acqua(nord) > 0.2,
			"a nord, alla stessa distanza dal centro, si è già a riva")
	t.almost(cw.distanza_dall_acqua(centro), 0.0,
			"in mezzo allo stagno la distanza dall'acqua è zero", 0.001)

	# 3) il fiume, che continua a essere riconosciuto
	var sul_fiume := Vector3(float(MATH.river_x(0.0)), 0.0, 0.0)
	t.almost(cw.distanza_dall_acqua(sul_fiume), 0.0,
			"in mezzo al fiume la distanza è zero", 0.001)
	var sponda := Vector3(float(MATH.river_x(12.0)) + 3.0, 0.0, 12.0)
	t.ok(cw.distanza_dall_acqua(sponda) < 1.5,
			"sulla sponda del fiume l'acqua è a un passo")

	# 4) e il prato è prato: senza questa, un metodo che torna sempre 0
	#    passerebbe tutto il resto
	var prato := Vector3(-6.0, 0.0, 4.0)
	t.ok(cw.distanza_dall_acqua(prato) > 8.0,
			"in mezzo al prato l'acqua è lontana (%.1f m)"
			% cw.distanza_dall_acqua(prato))
	# 5) oltre la fine del fiume l'acqua NON c'è: misurare la distanza dalla
	#    sua curva là in fondo sarebbe una bugia
	var fuori := Vector3(float(MATH.river_x(99.0)), 0.0, 99.0)
	t.ok(cw.distanza_dall_acqua(fuori) > 50.0,
			"fuori dal tratto navigabile la curva del fiume non conta più")
	cw.free()


# ====================================================== E · la damigella

## La damigella di velo era l'unica specie RARA senza un corpo suo: cadeva
## nel default dei due `match` e nasceva vestita da cicala — immobile,
## appoggiata a un tronco che sulla riva dello stagno non c'è.
func _test_damigella_ha_un_corpo(t) -> void:
	var CL := load("res://scenes/interact/Collection.gd")
	var col = CL.new() # fuori dall'albero: si chiedono solo le due fabbriche
	var dam: Node3D = col._make_bestiola("damigella")
	var cic: Node3D = col._make_bestiola("cicala")

	t.ok(dam.get_child_count() != cic.get_child_count()
			or _firma(dam) != _firma(cic),
			"il corpo della damigella è DIVERSO da quello della cicala")
	t.ok(dam.get_node_or_null("ala0") != null and dam.get_node_or_null("ala3") != null,
			"ha le sue quattro ali (quattro perni, non due)")
	t.eq(cic.get_node_or_null("ala0"), null,
			"e la cicala non se le è prese per sbaglio")

	# il volo: 30 passi di animazione vera, col tempo che scorre
	var b := {"node": dam, "kind": "damigella", "seed": 3.0,
			"base": Vector3(2, 0, 1), "trunk": Vector3.ZERO, "hop": 2.0,
			"heading": 0.0}
	var ali: Array[float] = []
	var punti: Array[Vector3] = []
	for i in 30:
		col._t = float(i) * 0.05
		col._anima_bestiola(b, 0.05)
		ali.append((dam.get_node("ala0") as Node3D).rotation.z)
		punti.append(dam.position)
	var ala_min := 9.0
	var ala_max := -9.0
	for a in ali:
		ala_min = minf(ala_min, a)
		ala_max = maxf(ala_max, a)
	t.ok(ala_max - ala_min > 0.2,
			"le ali battono davvero (escursione %.2f rad)" % (ala_max - ala_min))
	t.ok(dam.position.y > 0.2,
			"sta sospesa in aria, non appoggiata per terra (y = %.2f)" % dam.position.y)
	t.ok(punti[10].distance_to(punti[29]) > 0.005,
			"e il volo fermo non è FERMO: si sposta di continuo")

	# la controprova: la cicala, che sta appoggiata, non si muove — così
	# «si muove» non è una proprietà che avrebbe qualunque bestiola
	var b2 := {"node": cic, "kind": "cicala", "seed": 3.0,
			"base": Vector3(2, 0, 1), "trunk": Vector3.ZERO, "hop": 2.0,
			"heading": 0.0}
	for i in 30:
		col._t = float(i) * 0.05
		col._anima_bestiola(b2, 0.05)
	t.almost(cic.position.distance_to(Vector3(2, 0, 1)), 0.0,
			"la cicala invece resta dov'è (il default non è cambiato)", 0.001)

	dam.free()
	cic.free()
	col.free()


func _firma(n: Node) -> String:
	var s := ""
	for c in n.get_children():
		s += c.get_class() + ","
	return s
