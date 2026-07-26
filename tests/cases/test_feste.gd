extends RefCounted
## Le feste stagionali del Calendar (scenes/world/Calendar.gd): il cuore
## PURO — festa_del_giorno / prossima_festa — e le invarianti del tavolo
## FESTE (una festa per stagione, campi pieni, giorni dentro la settimana).
## Nessun SceneTree: si legge tutto da const e static.

const CAL := preload("res://scenes/world/Calendar.gd")
const DN := preload("res://scenes/world/DayNight.gd")


func run(t) -> void:
	_test_tavolo_feste(t)
	_test_festa_del_giorno(t)
	_test_prossima_festa(t)


## Il tavolo: 4 feste, una per stagione, coi testi pieni.
func _test_tavolo_feste(t) -> void:
	t.eq(CAL.FESTE.size(), 4, "quattro feste, una per stagione")
	var stagioni := {}
	for f in CAL.FESTE:
		var s := int(f["season"])
		t.ok(not stagioni.has(s), "stagione %d: una festa sola" % s)
		stagioni[s] = true
		t.ok(s >= 0 and s <= 3, "stagione nel range")
		var g := int(f["day"])
		t.ok(g >= 1 and g <= DN.SEASON_DAYS,
				"%s: il giorno %d sta nella settimana" % [f["id"], g])
		for campo in ["id", "nome", "evento", "icona", "annuncio", "toast", "cronaca"]:
			t.ok(str(f[campo]) != "", "%s: %s non vuoto" % [f["id"], campo])
	t.eq(stagioni.size(), 4, "tutte e quattro le stagioni sono coperte")
	# solo la notte delle lucciole aspetta il buio
	for f in CAL.FESTE:
		t.eq(bool(f["notte"]), str(f["id"]) == "lucciole",
				"%s: scatta col buio solo se e' la notte delle lucciole" % f["id"])


## Un anno intero, giorno per giorno: i giorni di festa sono esattamente 4,
## ognuno nella SUA stagione, e l'anno dopo il giro ricomincia identico.
func _test_festa_del_giorno(t) -> void:
	var trovate := []
	for day in range(1, DN.YEAR_DAYS + 1):
		var f := CAL.festa_del_giorno(day)
		if not f.is_empty():
			trovate.append([day, str(f["id"])])
			@warning_ignore("integer_division")
			var stagione := (day - 1) / DN.SEASON_DAYS
			t.eq(int(f["season"]), stagione,
					"giorno %d: la festa %s cade nella sua stagione" % [day, f["id"]])
	t.eq(trovate.size(), 4, "quattro giorni di festa nell'anno")
	# l'ordine dell'anno: hanami, lucciole, sagra, pupazzo
	var ordine := []
	for riga in trovate:
		ordine.append(riga[1])
	t.eq(",".join(ordine), "hanami,lucciole,sagra,pupazzo",
			"le feste seguono il giro delle stagioni")
	# l'anno dopo, lo stesso giro
	for riga in trovate:
		var f2 := CAL.festa_del_giorno(int(riga[0]) + DN.YEAR_DAYS)
		t.eq(str(f2.get("id", "")), str(riga[1]),
				"giorno %d+%d: stessa festa l'anno dopo" % [riga[0], DN.YEAR_DAYS])


## La prossima festa: da oggi incluso, sempre nel futuro prossimo, e il
## giorno indicato e' davvero un giorno di quella festa.
func _test_prossima_festa(t) -> void:
	for day in range(1, DN.YEAR_DAYS * 2 + 1):
		var pf := CAL.prossima_festa(day)
		var quando := int(pf[0])
		var f: Dictionary = pf[1]
		t.ok(not f.is_empty(), "giorno %d: una prossima festa esiste sempre" % day)
		t.ok(quando >= day and quando < day + DN.YEAR_DAYS,
				"giorno %d: la prossima festa e' entro un anno" % day)
		t.eq(str(CAL.festa_del_giorno(quando).get("id", "")), str(f["id"]),
				"giorno %d: nel giorno indicato c'e' proprio quella festa" % day)
	# il giorno stesso della festa conta come "prossima" (e' oggi!)
	var pf4 := CAL.prossima_festa(4)
	t.eq(int(pf4[0]), 4, "il giorno dell'hanami la prossima festa e' OGGI")
	t.eq(str((pf4[1] as Dictionary)["id"]), "hanami", "ed e' l'hanami")
	# la vigilia di capodanno guarda all'hanami dell'anno nuovo
	var pf28 := CAL.prossima_festa(DN.YEAR_DAYS)
	t.eq(str((pf28[1] as Dictionary)["id"]), "hanami",
			"dall'ultimo giorno dell'anno si vede l'hanami nuovo")
