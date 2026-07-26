## Test per il cercatore di posto degli alberi (scenes/world/TreeSpots.gd).
##
## È la parte del taglio della legna che, se sbaglia, pianta un pino dentro
## lo stagno o in mezzo al salotto: qui si verifica che dica di NO all'acqua,
## alla roccia, alle costruzioni, agli abitanti e ai pendii, e di SÌ al prato
## libero — tutto headless, senza aprire il gioco.

extends RefCounted

const SPOTS := preload("res://scenes/world/TreeSpots.gd")


func run(t) -> void:
	_test_prato_libero(t)
	_test_confini(t)
	_test_fiume(t)
	_test_scogliera(t)
	_test_cerchi(t)
	_test_sentiero(t)
	_test_altri_alberi(t)
	_test_terreno_serpeggiante(t)
	_test_ricerca(t)
	_test_mondo_pieno(t)


# un cercatore su prato vuoto: fiume e scogliera lontanissimi
func _vuoto():
	var s = SPOTS.new()
	s.flat_terrain(999.0, 999.0)
	return s


func _test_prato_libero(t) -> void:
	var s = _vuoto()
	t.ok(s.is_free(0.0, 0.0), "il prato vuoto accoglie un albero")
	t.eq(s.rejection(0.0, 0.0), "", "e non ha nulla da ridire")


func _test_confini(t) -> void:
	var s = _vuoto()
	t.ok(not s.is_free(500.0, 0.0), "fuori dal mondo non si pianta")
	t.eq(s.rejection(0.0, 999.0), "fuori dal mondo", "e lo dice chiaramente")
	t.ok(s.is_free(s.bounds_max.x - 1.0, s.bounds_max.y - 1.0),
			"appena dentro il confine invece sì")


func _test_fiume(t) -> void:
	var s = _vuoto()
	s.flat_terrain(10.0, 999.0)      # fiume dritto a x=10
	t.eq(s.rejection(10.0, 0.0), "fiume", "in mezzo all'acqua no")
	t.eq(s.rejection(10.0 + s.river_half - 0.5, 0.0), "fiume", "nemmeno sulla riva bagnata")
	t.ok(s.is_free(10.0 + s.river_half + 1.0, 0.0), "oltre la riva sì")


func _test_scogliera(t) -> void:
	var s = _vuoto()
	s.flat_terrain(999.0, 20.0)      # parete a x=20
	t.eq(s.rejection(25.0, 0.0), "scogliera o rilievo", "sulla parete non si cresce")
	t.eq(s.rejection(20.0 - s.cliff_margin + 0.5, 0.0), "scogliera o rilievo",
			"nemmeno appiccicati al suo piede")
	t.ok(s.is_free(20.0 - s.cliff_margin - 2.0, 0.0), "un po' più in là sì")


func _test_cerchi(t) -> void:
	var s = _vuoto()
	s.block(5.0, 5.0, 3.0)           # un masso / una casa / uno stagno
	t.eq(s.rejection(5.0, 5.0), "terreno occupato", "sopra l'ostacolo no")
	t.eq(s.rejection(6.0, 6.0), "terreno occupato", "nemmeno appena dentro")
	t.ok(s.is_free(5.0, 9.5), "appena fuori dal cerchio sì")
	# più ostacoli convivono
	s.block(-8.0, 2.0, 2.0)
	t.ok(not s.is_free(-8.0, 2.0), "anche il secondo ostacolo blocca")
	t.ok(s.is_free(-8.0, 6.0), "e non blocca tutto il resto")


func _test_sentiero(t) -> void:
	var s = _vuoto()
	s.path = PackedVector3Array([Vector3(0, 0, -20), Vector3(0, 0, -18)])
	t.eq(s.rejection(0.0, -20.0), "sentiero", "in mezzo al sentiero no")
	t.eq(s.rejection(0.0, -18.0), "sentiero", "il sentiero è tutto vietato, non solo un punto")
	# lo spazio si misura da OGNI punto del tracciato: -18 è l'ultimo
	t.ok(s.is_free(0.0, -18.0 + s.path_clear + 1.0), "di fianco al sentiero sì")
	t.ok(s.is_free(s.path_clear + 1.0, -19.0), "e di lato pure")


func _test_altri_alberi(t) -> void:
	var s = _vuoto()
	s.trees = [Vector2(0.0, 0.0)]
	t.eq(s.rejection(1.0, 0.0), "troppo vicino a un altro albero",
			"gli alberi non si accavallano")
	t.ok(s.is_free(s.tree_clear + 1.0, 0.0), "alla distanza giusta sì")


# fiume e scogliera SERPEGGIANO: il campionamento deve seguirli, non
# ridurli a una riga dritta
func _test_terreno_serpeggiante(t) -> void:
	var s = SPOTS.new()
	s.sample_terrain(
			func(z): return sin(z * 0.05) * 12.0,     # fiume che ondeggia
			func(z): return 40.0 + cos(z * 0.05) * 5.0,
			-56.0, 56.0, 2.0)
	for z in [-40.0, -10.0, 0.0, 10.0]:
		var rx: float = sin(z * 0.05) * 12.0
		t.almost(s.river_at(z), rx, "il fiume è seguito alla quota %.0f" % z, 0.3)
		t.eq(s.rejection(rx, z), "fiume", "e l'acqua è vietata anche dove curva")


func _test_ricerca(t) -> void:
	var s = _vuoto()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var p = s.find_spot(rng, Vector2(0, 0))
	t.ok(p != Vector2.INF, "su prato libero un posto si trova")
	t.ok(s.is_free(p.x, p.y), "e il posto trovato è davvero libero")
	# il posto sta vicino a dove si è tagliato: il bosco si rimargina lì
	t.ok(Vector2(p).length() < 31.0, "il posto nuovo non è dall'altra parte del mondo")


# se il mondo è pieno, find_spot deve ARRENDERSI, non piantare a caso
func _test_mondo_pieno(t) -> void:
	var s = _vuoto()
	s.bounds_min = Vector2(-10, -10)
	s.bounds_max = Vector2(10, 10)
	s.block(0.0, 0.0, 100.0)          # un ostacolo che copre tutto
	t.eq(s.free_count(2.0), 0, "il cercatore sa che non c'è più posto")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	t.eq(s.find_spot(rng, Vector2(0, 0)), Vector2.INF,
			"e si arrende invece di piantare a caso")
