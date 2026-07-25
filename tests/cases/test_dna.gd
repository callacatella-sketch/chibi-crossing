extends RefCounted

## Test per ChibiDNA.generate() (GDScript, statico).
## Carichiamo lo script con alias diversi dal class_name globale per evitare
## collisioni e per leggere le costanti dei moduli collegati.
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const ACC := preload("res://scenes/npc/ChibiAccessories.gd")


func run(t) -> void:
	_test_determinismo(t)
	_test_struttura_chiavi(t)
	_test_categorici(t)
	_test_range_float(t)
	_test_orecchie_coniglio(t)
	_test_weights(t)
	_test_indole(t)
	_test_quirk(t)
	_test_traits(t)


## generate() con lo STESSO seed >= 0 deve ritornare risultati identici.
func _test_determinismo(t) -> void:
	var sv := 12345
	var a: Dictionary = DNA.generate(sv)
	var b: Dictionary = DNA.generate(sv)

	# campi String + il bool freckles: confronto esatto
	for k in ["name", "label", "archetype", "fur", "fur2", "belly",
			"inner_ear", "dress", "dress2", "mouth", "tail", "acc", "quirk"]:
		t.eq(a[k], b[k], "determinismo campo '%s'" % k)
	t.eq(a["freckles"], b["freckles"], "determinismo freckles")

	# Array: in Godot 4 == confronta per valore
	t.ok(a["indole"] == b["indole"], "determinismo indole")
	t.ok(a["traits"] == b["traits"], "determinismo traits")
	t.ok(a["weights"] == b["weights"], "determinismo weights")

	# float dallo stesso RNG: bit-identici
	for k in ["size", "head_scale", "ear_len", "ear_ang", "eye_r",
			"eye_gap", "eye_h", "blush", "fluff"]:
		t.almost(a[k], b[k], "determinismo float '%s'" % k)


## Il Dictionary contiene tutte le chiavi attese.
func _test_struttura_chiavi(t) -> void:
	var d: Dictionary = DNA.generate(7)
	t.ok(typeof(d) == TYPE_DICTIONARY, "generate ritorna un Dictionary")
	var keys := ["name", "label", "archetype", "fur", "fur2", "belly",
			"inner_ear", "dress", "dress2", "size", "head_scale", "ear_len",
			"ear_ang", "eye_r", "eye_gap", "eye_h", "mouth", "blush",
			"freckles", "fluff", "tail", "acc", "weights", "traits",
			"indole", "quirk"]
	for k in keys:
		t.ok(d.has(k), "chiave presente: '%s'" % k)


## Dominio dei campi categorici (invariante su piu seed).
func _test_categorici(t) -> void:
	var tail_map := {"gatto": "ricciolo", "coniglio": "ponpon",
			"orsetto": "ponpon", "volpina": "volpe", "topolino": "filo"}
	for s in range(0, 40):
		var d: Dictionary = DNA.generate(s)
		t.ok(d["archetype"] in DNA.ARCHETYPES,
				"archetype in ARCHETYPES (seed %d)" % s)
		t.ok(d["mouth"] in ["w", "smile", "o"],
				"mouth valida (seed %d)" % s)
		t.ok(d["acc"] in ACC.POOL, "acc in POOL (seed %d)" % s)
		t.ok(d["name"] in DNA.NAMES, "name in NAMES (seed %d)" % s)
		t.eq(d["tail"], tail_map[d["archetype"]],
				"tail coerente con archetipo (seed %d)" % s)
		t.eq(d["label"], "%s %s" % [DNA.DESCR[d["archetype"]], d["name"]],
				"label formattata (seed %d)" % s)


## Range dei float. randf_range e semi-aperto: piccola tolleranza ai bordi.
func _test_range_float(t) -> void:
	for s in range(0, 40):
		var d: Dictionary = DNA.generate(s)
		_in_range(t, d["size"], 0.6, 0.78, "size", s)
		_in_range(t, d["head_scale"], 0.9, 1.12, "head_scale", s)
		_in_range(t, d["ear_ang"], 0.2, 0.5, "ear_ang", s)
		_in_range(t, d["eye_r"], 0.07, 0.098, "eye_r", s)
		_in_range(t, d["eye_gap"], 0.13, 0.175, "eye_gap", s)
		_in_range(t, d["eye_h"], -0.01, 0.06, "eye_h", s)
		_in_range(t, d["blush"], 0.3, 0.85, "blush", s)
		_in_range(t, d["fluff"], 0.25, 1.0, "fluff", s)
		_in_range(t, d["ear_len"], 0.8, 2.08, "ear_len", s)


func _in_range(t, v: float, lo: float, hi: float, nome: String, s: int) -> void:
	t.ok(v >= lo - 1e-5 and v <= hi + 1e-5,
			"%s in [%.4f, %.4f] = %.4f (seed %d)" % [nome, lo, hi, v, s])


## Regola del coniglio: ear_len ha il fattore 1.6 -> in [1.28, 2.08].
func _test_orecchie_coniglio(t) -> void:
	var trovato := false
	for s in range(0, 200):
		var d: Dictionary = DNA.generate(s)
		if d["archetype"] == "coniglio":
			trovato = true
			var e: float = d["ear_len"]
			t.ok(e >= 1.28 - 1e-5 and e <= 2.08 + 1e-5,
					"coniglio ear_len fattore 1.6 = %.4f (seed %d)" % [e, s])
	t.ok(trovato, "trovato almeno un coniglio nei seed 0..199")


## weights: Dictionary con bias esattamente -6.0 e tutte le chiavi.
func _test_weights(t) -> void:
	var d: Dictionary = DNA.generate(3)
	var w: Dictionary = d["weights"]
	t.ok(typeof(w) == TYPE_DICTIONARY, "weights e un Dictionary")
	t.almost(w["bias"], -6.0, "weights.bias == -6.0")
	for k in ["bias", "roof", "walls", "door", "window", "comfort",
			"garden", "warmth", "welcome", "sunny"]:
		t.ok(w.has(k), "weights ha chiave '%s'" % k)


## indole: 2 elementi distinti, entrambi presenti tra BRAIN.INDOLI.keys().
func _test_indole(t) -> void:
	var indole_keys: Array = BRAIN.INDOLI.keys()
	for s in range(0, 40):
		var d: Dictionary = DNA.generate(s)
		var ind: Array = d["indole"]
		t.eq(ind.size(), 2, "indole ha 2 elementi (seed %d)" % s)
		t.ok(ind[0] != ind[1], "indole distinte (seed %d)" % s)
		t.ok(ind[0] in indole_keys, "indole[0] valida (seed %d)" % s)
		t.ok(ind[1] in indole_keys, "indole[1] valida (seed %d)" % s)


## quirk: stringa vuota oppure un valore contenuto in BRAIN.QUIRKS.
func _test_quirk(t) -> void:
	for s in range(0, 40):
		var d: Dictionary = DNA.generate(s)
		var q: String = d["quirk"]
		t.ok(q == "" or q in BRAIN.QUIRKS,
				"quirk valido: '%s' (seed %d)" % [q, s])


## traits: Array di String, 3 senza quirk / 4 con quirk (quindi 3..4).
func _test_traits(t) -> void:
	for s in range(0, 40):
		var d: Dictionary = DNA.generate(s)
		var tr: Array = d["traits"]
		t.ok(tr.size() >= 3 and tr.size() <= 4,
				"traits size 3..4 = %d (seed %d)" % [tr.size(), s])
		for x in tr:
			t.ok(x is String, "trait e String (seed %d)" % s)
		# la 4a riga esiste se e solo se c'e una stravaganza
		if d["quirk"] != "":
			t.eq(tr.size(), 4, "traits size 4 con quirk (seed %d)" % s)
		else:
			t.eq(tr.size(), 3, "traits size 3 senza quirk (seed %d)" % s)
