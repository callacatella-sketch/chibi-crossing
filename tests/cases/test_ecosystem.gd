extends RefCounted

# Test dell'area "EcosystemManager (C++)".
# EcosystemManager e' una classe C++ registrata dalla GDExtension (Node3D):
# la si crea con EcosystemManager.new() SENZA aggiungerla all'albero, cosi'
# _ready/_physics_process non partono, si usano solo i metodi esposti in
# _bind_methods() e alla fine si chiama .free().
# Ogni asserzione e' fondata su src/ecosystem_manager.cpp / .h.

func run(t) -> void:
	_test_counts_iniziale(t)
	_test_drop_seeds(t)
	_test_save_state_struttura(t)
	_test_roundtrip(t)
	_test_load_state(t)
	_test_setter_puri(t)
	_test_sparrow_letture(t)
	_test_on_new_day(t)
	_test_debug_burst(t)


# counts() stato iniziale (istanza vuota) --- righe 508-517
func _test_counts_iniziale(t) -> void:
	var e := EcosystemManager.new()
	var c := e.counts()
	t.ok(c.has("farfalle") and c.has("lucciole") and c.has("fiori") \
			and c.has("semi") and c.has("uova") and c.has("passerotti"),
			"counts() ha le sei chiavi attese")
	t.eq(c["farfalle"], 0, "farfalle iniziali = 0")
	t.eq(c["lucciole"], 0, "lucciole iniziali = 0")
	t.eq(c["fiori"], 0, "fiori iniziali = 0")
	t.eq(c["semi"], 0, "semi iniziali = 0")
	t.eq(c["uova"], 0, "uova iniziali = 0")
	t.eq(c["passerotti"], 0, "passerotti iniziali = 0")
	e.free()


# drop_seeds: accumulo monotono, tetto SEED_MAX=40, n<=0 no-op --- righe 114-121
func _test_drop_seeds(t) -> void:
	var e := EcosystemManager.new()
	e.drop_seeds(Vector3(0, 0, 0), 5)
	t.eq(e.counts()["semi"], 5, "drop_seeds(5) da 0 -> 5 semi")
	e.drop_seeds(Vector3(0, 0, 0), 3)
	t.eq(e.counts()["semi"], 8, "drop_seeds(3) si accumula -> 8 semi")
	# i semi toccano solo i semi
	var c := e.counts()
	t.eq(c["farfalle"], 0, "drop_seeds non tocca le farfalle")
	t.eq(c["lucciole"], 0, "drop_seeds non tocca le lucciole")
	t.eq(c["fiori"], 0, "drop_seeds non tocca i fiori")
	t.eq(c["uova"], 0, "drop_seeds non tocca le uova")
	t.eq(c["passerotti"], 0, "drop_seeds non tocca i passerotti")
	# saturazione al tetto SEED_MAX=40 e non oltre
	e.drop_seeds(Vector3(0, 0, 0), 1000)
	t.eq(e.counts()["semi"], 40, "drop_seeds satura a SEED_MAX=40")
	e.drop_seeds(Vector3(0, 0, 0), 1000)
	t.eq(e.counts()["semi"], 40, "oltre il tetto resta 40")
	e.free()

	# n<=0 non aggiunge nulla (istanza pulita)
	var e2 := EcosystemManager.new()
	e2.drop_seeds(Vector3.ZERO, 0)
	t.eq(e2.counts()["semi"], 0, "drop_seeds(0) non aggiunge semi")
	e2.drop_seeds(Vector3.ZERO, -5)
	t.eq(e2.counts()["semi"], 0, "drop_seeds(-5) non aggiunge semi")
	e2.free()


# save_state(): struttura del Dictionary e riflesso dei conteggi --- righe 521-553
func _test_save_state_struttura(t) -> void:
	var e := EcosystemManager.new()
	var s := e.save_state()
	t.ok(s.has("bf") and s.has("ff") and s.has("wf") and s.has("eggs") and s.has("seeds"),
			"save_state() ha le chiavi bf/ff/wf/eggs/seeds")
	t.eq(s["bf"], 0, "save_state vuoto: bf = 0")
	t.eq(s["ff"], 0, "save_state vuoto: ff = 0")
	t.eq((s["wf"] as Array).size(), 0, "save_state vuoto: wf array vuoto")
	t.eq((s["eggs"] as Array).size(), 0, "save_state vuoto: eggs array vuoto")
	t.eq((s["seeds"] as Array).size(), 0, "save_state vuoto: seeds array vuoto")
	# dopo aver seminato: righe seeds da 2 elementi (x,z)
	e.drop_seeds(Vector3.ZERO, 3)
	s = e.save_state()
	t.eq((s["seeds"] as Array).size(), 3, "save_state: seeds ha 3 righe")
	t.eq((s["seeds"][0] as Array).size(), 2, "save_state: ogni seme ha (x,z)")
	t.eq(s["bf"], 0, "save_state dopo semina: bf resta 0")
	t.eq(s["ff"], 0, "save_state dopo semina: ff resta 0")
	e.free()


# roundtrip save_state()/load_state() --- righe 555-605
func _test_roundtrip(t) -> void:
	var e := EcosystemManager.new()
	e.drop_seeds(Vector3(1, 0, 2), 3)
	var s1 := e.save_state()
	e.load_state(s1)
	t.eq(e.counts()["semi"], 3, "roundtrip: semi preservati = 3")
	t.eq(e.counts()["farfalle"], 0, "roundtrip: farfalle restano 0")
	t.eq(e.counts()["lucciole"], 0, "roundtrip: lucciole restano 0")
	# doppio salvataggio: stessa dimensione e stesse coordinate x,z
	var s2 := e.save_state()
	var a1 := s1["seeds"] as Array
	var a2 := s2["seeds"] as Array
	t.eq(a2.size(), a1.size(), "roundtrip: numero di semi invariato")
	for i in range(a1.size()):
		var r1 := a1[i] as Array
		var r2 := a2[i] as Array
		t.almost(r2[0], r1[0], "roundtrip: x del seme %d coincide" % i)
		t.almost(r2[1], r1[1], "roundtrip: z del seme %d coincide" % i)
	e.free()


# load_state(dizionario): ricostruzione, default, clamp, malformate, tetto, reset
# --- righe 555-605
func _test_load_state(t) -> void:
	# ricostruzione completa
	var e := EcosystemManager.new()
	var st := {
		"seeds": [[1, 2], [3, 4]],
		"wf": [[0, 0, 0.5, 1]],
		"eggs": [[5, 6, 1]],
		"bf": 3,
		"ff": 2,
	}
	e.load_state(st)
	var c := e.counts()
	t.eq(c["semi"], 2, "load_state: 2 semi")
	t.eq(c["fiori"], 1, "load_state: 1 fiore")
	t.eq(c["uova"], 1, "load_state: 1 uovo")
	t.eq(c["farfalle"], 3, "load_state: bf=3 -> 3 farfalle")
	t.eq(c["lucciole"], 2, "load_state: ff=2 -> 2 lucciole")
	t.eq(c["passerotti"], 0, "load_state: passerotti azzerati")

	# dict vuoto: default bf=6, ff=8; resto azzerato
	e.load_state({})
	c = e.counts()
	t.eq(c["farfalle"], 6, "load_state({}): default bf=6")
	t.eq(c["lucciole"], 8, "load_state({}): default ff=8")
	t.eq(c["semi"], 0, "load_state({}): semi azzerati")
	t.eq(c["fiori"], 0, "load_state({}): fiori azzerati")
	t.eq(c["uova"], 0, "load_state({}): uova azzerate")
	t.eq(c["passerotti"], 0, "load_state({}): passerotti azzerati")

	# clamp ai limiti
	e.load_state({"bf": 100000, "ff": 100000})
	c = e.counts()
	t.eq(c["farfalle"], 90, "clamp: bf enorme -> BF_MAX=90")
	t.eq(c["lucciole"], 60, "clamp: ff enorme -> FF_MAX=60")
	e.load_state({"bf": -5, "ff": 0})
	c = e.counts()
	t.eq(c["farfalle"], 0, "clamp: bf negativo -> 0")
	t.eq(c["lucciole"], 0, "ff=0 -> 0 lucciole")

	# righe malformate saltate: la riga con size<2 e' ignorata
	e.load_state({"seeds": [[1], [2, 3]]})
	t.eq(e.counts()["semi"], 1, "load_state: riga seeds malformata saltata")

	# tetto in caricamento: 50 righe -> SEED_MAX=40
	var rows := []
	for i in range(50):
		rows.append([float(i), float(i) + 1.0])
	e.load_state({"seeds": rows})
	t.eq(e.counts()["semi"], 40, "load_state: 50 righe -> tetto 40")

	# reset dello stato: drop poi load_state({})
	e.drop_seeds(Vector3.ZERO, 5)
	e.load_state({})
	t.eq(e.counts()["semi"], 0, "load_state({}) resetta i semi a 0")
	e.free()


# setter puri: nessun effetto sui conteggi --- righe 90-110
func _test_setter_puri(t) -> void:
	var e := EcosystemManager.new()
	e.set_meadow(Vector3(-5, 0, -5), Vector3(5, 0, 5))
	e.set_pond(Vector3(0, 0, 0), 2.0)
	e.set_night(true)
	e.set_flower_sources(PackedVector3Array([Vector3(1, 0, 1)]))
	var c := e.counts()
	t.eq(c["farfalle"], 0, "setter puri: farfalle restano 0")
	t.eq(c["lucciole"], 0, "setter puri: lucciole restano 0")
	t.eq(c["fiori"], 0, "setter puri: fiori restano 0")
	t.eq(c["semi"], 0, "setter puri: semi restano 0")
	t.eq(c["uova"], 0, "setter puri: uova restano 0")
	t.eq(c["passerotti"], 0, "setter puri: passerotti restano 0")
	e.free()


# lettori passerotti fuori range (istanza senza passerotti) --- righe 472-494
func _test_sparrow_letture(t) -> void:
	var e := EcosystemManager.new()
	t.eq(e.sparrow_count(), 0, "sparrow_count() = 0 su istanza vuota")
	t.ok(e.sparrow_pos(0) == Vector3.ZERO and e.sparrow_pos(-1) == Vector3.ZERO \
			and e.sparrow_pos(100) == Vector3.ZERO,
			"sparrow_pos fuori range -> Vector3(0,0,0)")
	t.ok(e.sparrow_dir(0) == Vector3(0, 0, -1) and e.sparrow_dir(-1) == Vector3(0, 0, -1) \
			and e.sparrow_dir(100) == Vector3(0, 0, -1),
			"sparrow_dir fuori range -> Vector3(0,0,-1)")
	t.eq(e.sparrow_state(0), 0, "sparrow_state fuori range -> 0")
	t.eq(e.sparrow_state(-1), 0, "sparrow_state(-1) -> 0")
	t.eq(e.sparrow_id(5), -1, "sparrow_id fuori range -> -1")
	t.eq(e.sparrow_id(-1), -1, "sparrow_id(-1) -> -1")
	e.free()


# on_new_day(): no-op su vuoto e soglia di schiusa uova (>=2 giorni) --- righe 123-155
func _test_on_new_day(t) -> void:
	# no-op su stato vuoto: nessun crash, conteggi a 0
	var e := EcosystemManager.new()
	e.on_new_day()
	var c := e.counts()
	t.eq(c["uova"], 0, "on_new_day vuoto: uova = 0")
	t.eq(c["lucciole"], 0, "on_new_day vuoto: lucciole = 0")
	t.eq(c["farfalle"], 0, "on_new_day vuoto: farfalle = 0")
	t.eq(c["semi"], 0, "on_new_day vuoto: semi = 0")
	e.free()

	# uovo con days=0: dopo un giorno resta uovo (soglia >= 2)
	var e0 := EcosystemManager.new()
	e0.load_state({"eggs": [[0.0, 0.0, 0]], "ff": 0, "bf": 0})
	e0.on_new_day()
	t.eq(e0.counts()["uova"], 1, "uovo days=0 dopo 1 giorno: resta uovo")
	t.eq(e0.counts()["lucciole"], 0, "uovo days=0: nessuna schiusa")
	e0.free()

	# uovo con days=1: dopo un giorno si schiude
	var e1 := EcosystemManager.new()
	e1.load_state({"eggs": [[0.0, 0.0, 1]], "ff": 0, "bf": 0})
	e1.on_new_day()
	t.eq(e1.counts()["uova"], 0, "uovo days=1 dopo 1 giorno: schiuso")
	t.eq(e1.counts()["lucciole"], 1, "uovo days=1: nasce 1 lucciola")
	e1.free()


# debug_burst(): popolamento deterministico delle farfalle --- righe 609-639
func _test_debug_burst(t) -> void:
	var e := EcosystemManager.new()
	e.debug_burst()
	t.eq(e.counts()["farfalle"], 22, "debug_burst: farfalle esattamente 22")
	t.eq(e.counts()["passerotti"], 0, "debug_burst senza semi: passerotti 0")
	var f: int = e.counts()["fiori"]
	t.ok(f >= 0 and f <= 60, "debug_burst: fiori nel range [0,60]")
	e.free()
