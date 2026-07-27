extends RefCounted
## LA BARCHETTA DI MOCHI — il verbo "navigare". Guardie:
##  1. la fisica è PURA e da barca a remi: la corrente da sola porta a
##     valle (+z) alla sua velocità terminale, remando controcorrente si
##     RISALE (il gioco promesso), l'attrito tiene tutto a misura;
##  2. le sponde sono binari: dentro_l_alveo non lascia mai uscire;
##  3. le due ACQUE non si mescolano: dallo stagno niente trota/anguilla,
##     dal fiume solo le sue — e l'anguilla esce solo di notte;
##  4. il molo e la barca si costruiscono; la canna sa pescare dal fiume
##     (fili nei sorgenti: _wl, disponibili_in, deriva senza riavvolgere).

const BAR := preload("res://scenes/world/Barchetta.gd")
const CRIT := preload("res://scenes/world/Critters.gd")
const MATH := preload("res://scenes/world/WorldMath.gd")


func run(t) -> void:
	_test_fisica_pura(t)
	_test_sponde(t)
	_test_le_due_acque(t)
	_test_asset(t)
	_test_fili_attaccati(t)


func _test_fisica_pura(t) -> void:
	# la corrente, da sola: cento passi da ferma → deriva a valle (+z)
	var vel := Vector3.ZERO
	for i in 600:
		vel = BAR.passo_navigazione(vel, Vector3(0, 0, -1), 0.0, 0.05)
	t.ok(vel.z > 0.5, "smettendo di remare la corrente porta a valle (%.2f)" % vel.z)
	t.ok(vel.z < 1.2, "ma con la calma di un fiume gentile, mai una rapida")
	# remando controcorrente (prua a monte, -z) si RISALE
	var su := Vector3.ZERO
	for i in 600:
		su = BAR.passo_navigazione(su, Vector3(0, 0, -1), BAR.REMATA, 0.05)
	t.ok(su.z < -0.8, "remando controcorrente si risale davvero (%.2f)" % su.z)
	# a favore di corrente si vola (ma da barca a remi, non da motoscafo)
	var giu := Vector3.ZERO
	for i in 600:
		giu = BAR.passo_navigazione(giu, Vector3(0, 0, 1), BAR.REMATA, 0.05)
	t.ok(giu.z > absf(su.z), "a favore di corrente si va più svelti")
	t.ok(giu.z < 4.0, "ma mai a motore")


func _test_sponde(t) -> void:
	var rx: float = MATH.river_x(10.0)
	t.eq(BAR.dentro_l_alveo(rx, rx), rx, "al centro dell'alveo si naviga liberi")
	t.eq(BAR.dentro_l_alveo(rx + 99.0, rx), rx + BAR.SPONDA,
			"la sponda est rimanda indietro")
	t.eq(BAR.dentro_l_alveo(rx - 99.0, rx), rx - BAR.SPONDA,
			"e quella ovest pure")
	t.ok(BAR.SPONDA < 2.35, "l'alveo navigabile sta DENTRO l'acqua disegnata")
	t.ok(BAR.Z_MIN > -56.0 and BAR.Z_MAX < 56.0,
			"i capolinea stanno dentro il corso del fiume")


func _test_le_due_acque(t) -> void:
	# le specie nuove esistono, con la loro casa
	t.eq(CRIT.classe("trota"), "pesce", "la trota del salto è un pesce")
	t.eq(CRIT.classe("anguilla"), "pesce", "e l'anguilla pure")
	t.ok(CRIT.rara("anguilla"), "l'anguilla della notte è la rara del fiume")
	t.ok(not CRIT.rara("trota"), "la trota è la compagna di ogni remata")
	# la dogana delle acque: giorno di primavera
	var giorno := CRIT.contesto(0, 0.5, false, "sereno")
	var stagno: Array = CRIT.disponibili_in("pesce", giorno, false)
	var fiume: Array = CRIT.disponibili_in("pesce", giorno, true)
	t.ok(not ("trota" in stagno) and not ("anguilla" in stagno),
			"dallo stagno non abboccano i pesci del fiume")
	t.ok("trota" in fiume, "dal fiume la trota c'è, di giorno")
	t.ok(not ("anguilla" in fiume), "ma l'anguilla di giorno dorme")
	t.ok(not stagno.is_empty(), "e lo stagno non resta MAI senza pesci")
	# la notte del fiume
	var notte := CRIT.contesto(1, 0.95, true, "sereno")
	var fiume_notte: Array = CRIT.disponibili_in("pesce", notte, true)
	t.ok("anguilla" in fiume_notte, "col buio l'anguilla esce")
	# in ogni ora e stagione il fiume ha SEMPRE qualcosa all'amo
	for stagione in 4:
		for buio in [false, true]:
			var ctx := CRIT.contesto(stagione, 0.9 if buio else 0.5, buio, "sereno")
			t.ok(not (CRIT.disponibili_in("pesce", ctx, true) as Array).is_empty(),
					"il fiume non resta mai senza pesci (s%d %s)"
					% [stagione, "notte" if buio else "giorno"])


func _test_asset(t) -> void:
	var bar = BAR.new()
	var molo: Node3D = bar._make_molo()
	t.ok(molo.get_child_count() >= 10,
			"il molo ha assi, pali e bitta (%d pezzi)" % molo.get_child_count())
	molo.free()
	var barca: Node3D = bar._make_barca()
	t.ok(barca.get_child_count() >= 8,
			"la barchetta ha scafo, panchetta e remi (%d)" % barca.get_child_count())
	barca.free()
	bar.free()


func _test_fili_attaccati(t) -> void:
	var src := _sorgente("res://scenes/interact/Fishing.gd")
	t.ok(src.contains("disponibili_in"),
			"la canna fa la dogana delle acque (disponibili_in)")
	t.ok(src.contains("_wl"), "il rito della pesca è espresso dalla superficie (_wl)")
	t.ok(_body(src, "_check_walked_away").contains("_in_barca"),
			"alla deriva si pesca: la corrente non riavvolge la lenza")
	t.ok(_body(src, "_cast").contains("punto_di_pesca"),
			"dal fiume si lancia verso il corso vero")
	t.ok(_sorgente("res://scenes/levels/MainLevel.tscn").contains("Barchetta"),
			"la barchetta è un nodo della scena principale")
	var fis := _sorgente("res://scenes/world/Barchetta.gd")
	t.ok(_body(fis, "_physics_process").contains("passo_navigazione"),
			"la barca naviga col passo puro")
	t.ok(_body(fis, "_imbarca").contains("set_physics_process"),
			"a bordo il PlayerController riposa (la camera viene da sola)")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func _body(src: String, fn: String) -> String:
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
