extends RefCounted
## LA PIOGGIA ADDOSSO: i corpi reagiscono all'acqua — zampina a visiera
## (sopra la testona non si arriva: stessa lezione del saluto), orecchie
## appiattite, testolina nelle spalle, passetto svelto. Il cablaggio:
## Mochi si legge il meteo da sola, ai residenti il flag lo alza Visitors
## per chi è fuori senza un tetto (has_cover) — e sotto una copertura il
## corpo si rilassa da solo. Il livello si SOMMA a qualunque postura
## della recita, con la spalla che resta una spalla (clamp sul braccio).

func run(t) -> void:
	var mochi := _sorgente("res://scenes/characters/Mochi.gd")
	var visitor := _sorgente("res://scenes/npc/Visitor.gd")
	var visitors := _sorgente("res://scenes/npc/Visitors.gd")

	# --- Mochi: si accorge della pioggia e si ripara ---
	t.ok(mochi.contains("is_raining()") and mochi.contains("has_cover(cella)"),
			"Mochi legge pioggia E copertura: sotto un tetto niente visiera")
	t.ok(mochi.contains("maxf(_droop, 0.92 * _riparo)"),
			"le orecchie si appiattiscono (vince il piu' forte tra pioggia e sonno)")
	t.ok(mochi.contains("1.0 + 0.42 * _riparo"),
			"il passetto svelto: passi piu' fitti sotto l'acqua")
	t.ok(mochi.contains("_hold > 0.05 or _hold_target > 0.0 or _climb > 0.05"),
			"la visiera cede il passo a oggetti in zampa e arrampicata")
	t.ok(mochi.contains("* _riparo * (1.0 - _walk)"),
			"il brivido «brrr» solo da ferma, a folate")

	# --- Visitor: il livello pioggia si somma alla recita del corpo ---
	t.ok(visitor.contains("var riparo_pioggia := false"),
			"il Visitor espone il flag che Visitors alza")
	t.ok(visitor.contains("bersagli[\"ax1\"] += -2.75 * _riparo"),
			"la zampina destra sale quasi verticale (negativo = su, come il fagotto)")
	t.ok(visitor.contains("bersagli[\"az1\"] += 0.45 * _riparo"),
			"e VERSO FUORI: davanti alla testona sparirebbe (lezione del saluto)")
	t.ok(visitor.contains("maxf(bersagli[\"ax1\"], -2.9)"),
			"col fagotto gia' in spalla il braccio NON gira oltre (clamp)")
	t.ok(visitor.contains("bersagli[\"ear\"] += 0.85 * _riparo"),
			"orecchie basse anche per i residenti")
	t.ok(visitor.contains("_gait_ph += v * delta * 5.5 * (1.0 + 0.42 * _riparo)"),
			"la fase del passo e' un accumulatore: si infittisce senza saltare (e ora avanza coi METRI, non col tempo)")

	# --- Visitors: il flag per chi e' fuori senza tetto, ospite compreso ---
	t.ok(visitors.contains("riparo_pioggia\", raining and not _build.has_cover"),
			"Visitors alza il riparo solo per chi e' sotto l'acqua vera")
	var blocco := visitors.substr(visitors.find("la pioggia ADDOSSO"))
	t.ok(blocco.contains("_active"),
			"anche l'ospite di passaggio si ripara (non solo i residenti)")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
