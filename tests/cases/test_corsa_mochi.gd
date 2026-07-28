extends RefCounted
## LA CORSA DI MOCHI: banking in curva, frenata con la nuvoletta, ">.<" intero.
##
## Tre difetti trovati il 2026-07-27 guardando la corsa da vicino:
##  1. gli occhi ">.<" erano DUE pennellate per occhio che si davano
##     appuntamento al vertice — dove build_stroke rastrema entrambe a zero:
##     il chevron restava spezzato, due petali con un buco in mezzo;
##  2. niente banking: in curva il corpo restava dritto come un palo;
##  3. niente polvere alla frenata: da sprint a fermo senza un segno.
## Questi test tengono le tre cure al loro posto.

const MOCHI = preload("res://scenes/characters/Mochi.gd")


func run(t) -> void:
	_test_banking_puro(t)
	_test_frenata_pura(t)
	_test_bezier_passa_per_il_vertice(t)
	_test_fili_attaccati(t)


## inclinazione_in_curva: rollio proporzionale alla virata, col tetto,
## pesato dalla velocità. Da ferma o a passeggio non si banka.
func _test_banking_puro(t) -> void:
	t.almost(MOCHI.inclinazione_in_curva(2.0, 0.0), 0.0,
			"da ferma niente banking, qualunque sia la virata")
	t.ok(MOCHI.inclinazione_in_curva(2.0, 5.0) > 0.1,
			"in corsa piena la virata a sinistra inclina davvero")
	t.almost(MOCHI.inclinazione_in_curva(2.0, 5.0),
			-MOCHI.inclinazione_in_curva(-2.0, 5.0),
			"il banking è simmetrico: destra e sinistra si specchiano")
	t.ok(absf(MOCHI.inclinazione_in_curva(50.0, 9.0)) <= 0.32001,
			"anche un dietrofront di scatto resta sotto il tetto (0.32)")
	var passeggio = absf(MOCHI.inclinazione_in_curva(2.0, 1.2))
	var corsa = absf(MOCHI.inclinazione_in_curva(2.0, 5.0))
	t.ok(passeggio < corsa * 0.45,
			"a passeggio (%.3f) ci si inclina molto meno che in corsa (%.3f)"
			% [passeggio, corsa])
	t.ok(MOCHI.inclinazione_in_curva(1.0, 5.0)
			< MOCHI.inclinazione_in_curva(2.0, 5.0),
			"sotto il tetto, più virata = più inclinazione (monotona)")


## frenata_secca: scatta SOLO quando la velocità vera è crollata mentre la
## media lenta ricorda ancora lo slancio della corsa.
func _test_frenata_pura(t) -> void:
	t.ok(MOCHI.frenata_secca(0.4, 4.0),
			"da sprint a quasi fermo con lo slancio in memoria: sgommatina")
	t.ok(not MOCHI.frenata_secca(4.5, 4.8),
			"mentre corre ancora, nessuna frenata")
	t.ok(not MOCHI.frenata_secca(0.4, 1.0),
			"fermarsi dal passeggio non solleva polvere")
	t.ok(not MOCHI.frenata_secca(2.0, 4.0),
			"rallentare senza piantarsi non basta")


## La pennellata unica del ">.<": il campionamento bezier usato in
## _build_head (de Casteljau con controllo OLTRE il vertice) deve passare
## ESATTAMENTE per il vertice a metà corsa — è tutta la cura del buco.
func _test_bezier_passa_per_il_vertice(t) -> void:
	var centro := Vector3(0.155, 0.03, -0.36)
	var vertice := centro + Vector3(-0.0266, 0.0, 0.0)
	var alto := centro + Vector3(0.0446, 0.0643, 0.0)
	var basso := centro + Vector3(0.0446, -0.0643, 0.0)
	var ctrl := vertice * 2.0 - (alto + basso) * 0.5
	var q := alto.lerp(ctrl, 0.5).lerp(ctrl.lerp(basso, 0.5), 0.5)
	t.almost(q.x, vertice.x, "l'apice della bezier atterra sul vertice (x)")
	t.almost(q.y, vertice.y, "l'apice della bezier atterra sul vertice (y)")


## I fili nei sorgenti: la pennellata è UNA per occhio, il banking entra nel
## rollio, la frenata fa partire lo sbuffo one-shot.
func _test_fili_attaccati(t) -> void:
	var head := _body("res://scenes/characters/Mochi.gd", "_build_head")
	var da := head.find("_squints.append")
	t.ok(da >= 0, "il blocco degli squint esiste in _build_head")
	if da >= 0:
		var blocco := head.substr(maxi(0, da - 2600), 2600)
		t.eq(blocco.count("FACE.build_stroke"), 1,
				"UNA pennellata per occhio nel blocco squint (niente due petali)")
		t.ok(not blocco.contains("for verso"),
				"il vecchio doppio tratto (for verso) non è tornato")
		t.ok(blocco.contains("vertice * 2.0"),
				"il controllo bezier sta oltre il vertice (ci passa sopra)")
	var proc := _body("res://scenes/characters/Mochi.gd", "_process")
	t.ok(proc.contains("+ _bank"),
			"il banking entra nel rollio del corpo (rotation.z)")
	t.ok(proc.contains("inclinazione_in_curva("),
			"il bersaglio del banking viene dalla funzione pura")
	t.ok(proc.contains("frenata_secca(") and proc.contains("_brake_dust.restart()"),
			"la frenata secca fa partire lo sbuffo di polvere")


func _body(path: String, fn: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
