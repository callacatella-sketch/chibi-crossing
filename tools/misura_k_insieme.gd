extends SceneTree
## LA TARATURA DI `K_INSIEME`, misurata invece che scelta a occhio.
##
## La domanda non e' «di quanto sale il riposo» (quella la sa l'aritmetica:
## del venti per cento). E' **quante decisioni il termine SCAVALCA, e di
## quanto** — cioe' se e' una considerazione o un veto. Un moltiplicatore che
## ribalta una decisione su due non e' un'inclinazione: e' un ordine, e il
## villaggio smetterebbe di avere caratteri diversi.
##
## ⚠️ **LE DUE REGOLE APPAIATE SULLO STESSO CONTESTO**, mai due corse: si
## chiedono al binario i punteggi col bit spento, e l'unica cosa che cambia
## e' il fattore. Due villaggi diversi risponderebbero a una domanda diversa.
##
## ⚠️ **E LA SIMULAZIONE DI K E' ESATTA, non approssimata.** A modulatore
## neutro il fattore e' un moltiplicatore puro sul punteggio del riposo
## (`punteggi()`: i fattori si moltiplicano in ordine stretto, poi l'innesto
## dell'emozione vale zero perche' `d = v*1.0 - v = 0`, e il riposo non ha
## ne' pavimento ne' il ramo del nottambulo). Quindi `riposo_con_K ==
## riposo_senza * K`, BIT PER BIT — e la prima cosa che questo banco fa e'
## verificarlo contro il binario, col K che il gioco ha compilato. Se quella
## verifica fallisse, tutto il resto sarebbe aritmetica su un modello
## sbagliato.
##
##   Godot --headless --path . --script res://tools/misura_k_insieme.gd

const CARATTERI := [
	[], ["goloso"], ["dormiglione"], ["chiacchierone"], ["timido"],
	["sognatore"], ["ordinato"], ["chiacchierone", "timido"],
	["goloso", "ordinato"], ["sognatore", "dormiglione"],
]

## Le quattro forme di mondo in cui un vicino si trova davvero: il prato
## nudo, il villaggio normale, il villaggio col posto bello, e il mattino
## col giardino che ha sete (dove il PAVIMENTO dell'aiuola chiama chiunque —
## ed e' il caso in cui un termine sul riposo NON deve poter vincere).
const MONDI := [
	[],
	["spuntino_vicino", "amico_in_giro"],
	["spuntino_vicino", "amico_in_giro", "meraviglia_posto"],
	["mattina", "aiuola_da_annaffiare", "spuntino_vicino", "amico_in_giro",
			"meraviglia_posto"],
]

const LIVELLI := [0.08, 0.36, 0.64, 0.92]
const KAPPA := [1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.60]


func _initialize() -> void:
	if not ClassDB.class_exists("EcsMondo"):
		push_error("EcsMondo non registrata: manca --import?")
		quit(1)
		return
	var m = ClassDB.instantiate("EcsMondo")
	var cost: Dictionary = m.debug_costanti_agenda()
	var k_vero := float(cost["k_insieme"])
	var margine := float(cost["margine"])
	var bit: int = m.maschera_fatti(PackedStringArray(["insieme_accanto"]))
	print("K compilato nel gioco: %.4f · margine d'urgenza: %.4f · bit %d"
			% [k_vero, margine, bit])

	# ---- 0) LA CONTROPROVA: il modello e' esatto? ----
	var storto := 0
	var confronti := 0
	for c in CARATTERI:
		var ind: int = m.maschera_indole(PackedStringArray(c))
		for liv in LIVELLI:
			var b := PackedFloat64Array([liv, liv, liv, liv, liv])
			for mondo in MONDI:
				var f: int = m.maschera_fatti(PackedStringArray(mondo))
				var senza: PackedFloat64Array = m.debug_punteggi(b, f, ind, -1)
				var con: PackedFloat64Array = m.debug_punteggi(b, f | bit, ind, -1)
				confronti += 1
				if con[1] != senza[1] * k_vero:
					storto += 1
				for i in 8:
					if i != 1 and con[i] != senza[i]:
						storto += 1
	print("il modello «riposo × K, e nient'altro» regge su %d contesti: %s"
			% [confronti, "SI, bit per bit" if storto == 0 else "NO (%d scarti)" % storto])
	if storto > 0:
		m.free()
		quit(1)
		return

	# ---- 1) LA SPAZZATA ----
	# I bisogni sono INDIPENDENTI: un vicino stanco e sazio non e' lo stesso
	# di uno stanco e affamato, ed e' proprio nel secondo che un termine sul
	# riposo puo' fare danno.
	var righe := {}
	for k in KAPPA:
		righe[k] = {"n": 0, "flip": 0, "scarti": [], "urgenze": 0, "rubati": {},
				"riposo_argmax": 0}
	var contesti := 0
	var senza_argmax := 0
	for c2 in CARATTERI:
		var ind2: int = m.maschera_indole(PackedStringArray(c2))
		for mondo2 in MONDI:
			var f2: int = m.maschera_fatti(PackedStringArray(mondo2))
			for a in LIVELLI:
				for b2 in LIVELLI:
					for c3 in LIVELLI:
						for d2 in LIVELLI:
							for e2 in LIVELLI:
								var bis := PackedFloat64Array([a, b2, c3, d2, e2])
								var p: PackedFloat64Array = m.debug_punteggi(bis, f2, ind2, -1)
								contesti += 1
								var am := 0
								for iq in 8:
									if p[iq] > p[am]:
										am = iq
								if am == 1:
									senza_argmax += 1
								_valuta(p, righe, margine)
	print("\ncontesti spazzati: %d" % contesti)
	var base := senza_argmax
	print("\n  K      decisioni SCAVALCATE      scarto (mediano/max)   «riposo» e' l'argmax   urgenze")
	for k2 in KAPPA:
		var r: Dictionary = righe[k2]
		var sc: Array = r["scarti"]
		sc.sort()
		var med := 0.0 if sc.is_empty() else float(sc[sc.size() / 2])
		var mx := 0.0 if sc.is_empty() else float(sc[sc.size() - 1])
		print("  %.2f   %5d su %5d  (%5.2f%%)     %.4f / %.4f        %6.2f%%                %d%s"
				% [k2, int(r["flip"]), int(r["n"]),
				100.0 * float(r["flip"]) / maxf(1.0, float(r["n"])),
				med, mx,
				100.0 * float(r["riposo_argmax"]) / maxf(1.0, float(r["n"])),
				int(r["urgenze"]),
				"   ← quello compilato" if absf(k2 - k_vero) < 1e-9 else ""])
	print("  1.00   (il termine spento)                                   %6.2f%%"
			% [100.0 * float(base) / maxf(1.0, float(contesti))])

	print("\n  CHI VIENE SCAVALCATO, al K compilato:")
	var AZIONI := ["spuntino", "riposo", "chiacchiere", "giardino",
			"meraviglia", "stella", "regia", "gironzola"]
	var rubati: Dictionary = (righe[k_vero] as Dictionary)["rubati"]
	var chiavi := rubati.keys()
	chiavi.sort()
	for ch in chiavi:
		print("    a «%s»: %d volte" % [AZIONI[int(ch)], int(rubati[ch])])

	# ---- 2) IL TETTO, letto dal binario e non riscritto ----
	# `max(riposo)` si MISURA: energia a zero, dormiglione. Un numero
	# ricopiato qui sarebbe la stessa relazione affidata di nuovo alla
	# memoria di chi tara.
	var i_dorm: int = m.maschera_indole(PackedStringArray(["dormiglione"]))
	var pmax: PackedFloat64Array = m.debug_punteggi(
			PackedFloat64Array([1.0, 0.0, 1.0, 1.0, 1.0]), 0, i_dorm, -1)
	print("\n  IL TETTO: max(riposo) = %.4f · scarto massimo del termine = %.4f · margine = %.4f  → %s"
			% [pmax[1], pmax[1] * (k_vero - 1.0), margine,
			"INCLINA" if pmax[1] * (k_vero - 1.0) < margine else "⚠️ APRE L'URGENZA ⚠️"])
	m.free()
	quit()


## Per ogni K: l'argmax cambia? e lo scarto apre la corsia d'urgenza?
##
## L'URGENZA si misura come la misura il motore: il primo batte il corrente
## di piu' di `margine`. Qui il «corrente» piu' sfavorevole possibile e'
## l'argmax di prima — cioe' si chiede se il termine, DA UN PAREGGIO col
## vincitore precedente, puo' da solo aprire la corsia. E' il caso peggiore.
func _valuta(p: PackedFloat64Array, righe: Dictionary, margine: float) -> void:
	var a_senza := 0
	for i in 8:
		if p[i] > p[a_senza]:
			a_senza = i
	for k in KAPPA:
		var r: Dictionary = righe[k]
		var riposo: float = p[1] * k
		var a_con := 0
		for i2 in 8:
			var v: float = riposo if i2 == 1 else p[i2]
			var vb: float = riposo if a_con == 1 else p[a_con]
			if v > vb:
				a_con = i2
		r["n"] = int(r["n"]) + 1
		if a_con == 1:
			r["riposo_argmax"] = int(r["riposo_argmax"]) + 1
		(r["scarti"] as Array).append(riposo - p[1])
		if riposo - p[1] > margine:
			r["urgenze"] = int(r["urgenze"]) + 1
		if a_con != a_senza:
			r["flip"] = int(r["flip"]) + 1
			var ru: Dictionary = r["rubati"]
			ru[a_senza] = int(ru.get(a_senza, 0)) + 1
