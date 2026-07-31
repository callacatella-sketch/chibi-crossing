extends RefCounted
## LE SPONDE DEL FIUME — il muro che si attraversava a piedi asciutti.
##
## Difetto trovato dalla caccia e verificato spazzando la capsula del
## giocatore in scena: le barriere campionavano ogni 2,4 m e saltavano il
## CAMPIONE INTERO quando cadeva entro 1,8 m da un guado. Con scatole
## profonde 2,55 questo toglieva fino a 4,65 m di muro per lasciar passare
## un ponte largo 1,62 — quattro corridoi completi da sponda a sponda, e il
## fiume si attraversava ovunque, sospesi sopra l'acqua.
##
## Ora l'apertura si ricava dalla larghezza VERA del camminatoio, e la
## matematica e' pura: si prova qui, senza costruire il mondo.

const MATH := preload("res://scenes/world/WorldMath.gd")
const COZY := preload("res://scenes/world/CozyWorld.gd")


func run(t) -> void:
	_test_le_aperture_sono_quelle_dei_guadi(t)
	_test_nessun_altro_varco(t)
	_test_casi_limite(t)


func _aperture() -> Array:
	return [[COZY.BRIDGE_Z - COZY.PASSAGGIO_PONTE, COZY.BRIDGE_Z + COZY.PASSAGGIO_PONTE],
			[COZY.LOG_Z - COZY.PASSAGGIO_TRONCO, COZY.LOG_Z + COZY.PASSAGGIO_TRONCO]]


func _test_le_aperture_sono_quelle_dei_guadi(t) -> void:
	var tratti: Array = MATH.tratti_sponda(COZY.RIVER_Z_MIN, COZY.RIVER_Z_MAX, _aperture())
	t.eq(tratti.size(), 3, "due guadi tagliano la sponda in tre tratti pieni")
	# i buchi fra un tratto e l'altro sono ESATTAMENTE i due passaggi
	var buchi: Array = []
	for i in range(tratti.size() - 1):
		buchi.append(float(tratti[i + 1][0]) - float(tratti[i][1]))
	buchi.sort()
	t.almost(buchi[0], COZY.PASSAGGIO_TRONCO * 2.0,
			"il varco del tronco e' largo quanto il tronco", 0.001)
	t.almost(buchi[1], COZY.PASSAGGIO_PONTE * 2.0,
			"…e quello del ponte quanto il ponte", 0.001)
	# e il ponte e' largo 1,62: il varco non deve essere molto piu' largo,
	# o si passa a fianco del camminatoio
	t.ok(COZY.PASSAGGIO_PONTE * 2.0 < 1.62 + 0.5,
			"il varco del ponte non straborda dal camminatoio (%.2f m)"
			% (COZY.PASSAGGIO_PONTE * 2.0))
	t.ok(COZY.PASSAGGIO_TRONCO * 2.0 < 0.80 + 0.5,
			"…né quello del tronco (%.2f m)" % (COZY.PASSAGGIO_TRONCO * 2.0))
	# ma abbastanza da passarci: un varco piu' stretto del corpo e' un muro
	t.ok(COZY.PASSAGGIO_TRONCO * 2.0 > 0.8,
			"…e ci si passa davvero, il corpo di un chibi e' largo mezzo metro")


## NESSUN ALTRO VARCO. È la prova che discrimina: col vecchio codice,
## saltare un campione da 2,4 m apriva un buco anche dove non c'era nessun
## guado da attraversare.
func _test_nessun_altro_varco(t) -> void:
	var tratti: Array = MATH.tratti_sponda(COZY.RIVER_Z_MIN, COZY.RIVER_Z_MAX, _aperture())
	var coperto := 0.0
	for tr in tratti:
		coperto += float(tr[1]) - float(tr[0])
	var totale: float = COZY.RIVER_Z_MAX - COZY.RIVER_Z_MIN
	var aperto := totale - coperto
	t.almost(aperto, (COZY.PASSAGGIO_PONTE + COZY.PASSAGGIO_TRONCO) * 2.0,
			"su tutta la sponda è aperto SOLO quanto i due guadi", 0.001)
	t.ok(aperto < 3.2,
			"in tutto meno di tre metri di varco su %.0f di sponda (%.2f)"
			% [totale, aperto])


func _test_casi_limite(t) -> void:
	# un'apertura fuori dalla sponda non taglia niente
	t.eq(MATH.tratti_sponda(0.0, 10.0, [[20.0, 21.0]]).size(), 1,
			"un guado fuori dal fiume non apre niente")
	# un'apertura che copre tutto non lascia muro
	t.eq(MATH.tratti_sponda(0.0, 10.0, [[-1.0, 11.0]]).size(), 0,
			"un'apertura più larga della sponda la cancella")
	# due aperture sovrapposte non producono un tratto vuoto
	var due: Array = MATH.tratti_sponda(0.0, 10.0, [[4.0, 6.0], [5.0, 7.0]])
	for tr in due:
		t.ok(float(tr[1]) > float(tr[0]), "nessun tratto di lunghezza zero")
	# senza aperture, il muro è intero
	t.eq(MATH.tratti_sponda(0.0, 10.0, []).size(), 1, "senza guadi il muro è intero")
