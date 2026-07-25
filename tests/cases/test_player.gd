extends RefCounted

# Test per PlayerController (GDExtension C++).
# Fondamenti nel codice reale:
#  - src/player_controller.h riga 14: walk_speed = 3.0 (default)
#  - src/player_controller.h riga 15: run_speed  = 6.0 (default)
#  - src/player_controller.cpp righe 82-96: getter/setter = pura assegnazione, nessun clamp
#  - src/player_controller.cpp righe 9-12: get/set_walk_speed e get/set_run_speed esposti in _bind_methods()
# PlayerController estende CharacterBody3D (Node): si crea con .new() senza aggiungerlo
# all'albero (cosi _ready/_physics_process non partono) e si libera con .free().

func run(t) -> void:
	_test_walk_speed(t)
	_test_run_speed(t)


func _test_walk_speed(t) -> void:
	var p := PlayerController.new()
	# Default fondato su header riga 14 (walk_speed = 3.0), costruttore vuoto
	t.almost(p.get_walk_speed(), 3.0, "walk_speed default = 3.0")
	# Roundtrip: il setter fa pura assegnazione (cpp righe 86-88)
	p.set_walk_speed(5.5)
	t.almost(p.get_walk_speed(), 5.5, "walk_speed roundtrip 5.5")
	p.set_walk_speed(0.0)
	t.almost(p.get_walk_speed(), 0.0, "walk_speed roundtrip 0.0")
	# Nessun clamp: valore negativo accettato tal quale
	p.set_walk_speed(-2.0)
	t.almost(p.get_walk_speed(), -2.0, "walk_speed senza clamp: negativo accettato")
	# Nessun clamp: valore grande accettato tal quale
	p.set_walk_speed(1000.0)
	t.almost(p.get_walk_speed(), 1000.0, "walk_speed senza clamp: valore grande accettato")
	# Determinismo: getter ripetuto senza set resta stabile
	t.almost(p.get_walk_speed(), p.get_walk_speed(), "walk_speed getter deterministico")
	p.free()


func _test_run_speed(t) -> void:
	var p := PlayerController.new()
	# Default fondato su header riga 15 (run_speed = 6.0)
	t.almost(p.get_run_speed(), 6.0, "run_speed default = 6.0")
	# Roundtrip: setter pura assegnazione (cpp righe 94-96)
	p.set_run_speed(9.0)
	t.almost(p.get_run_speed(), 9.0, "run_speed roundtrip 9.0")
	p.set_run_speed(0.0)
	t.almost(p.get_run_speed(), 0.0, "run_speed roundtrip 0.0")
	# Nessun clamp: valore negativo accettato tal quale
	p.set_run_speed(-1.5)
	t.almost(p.get_run_speed(), -1.5, "run_speed senza clamp: negativo accettato")
	# Determinismo: getter ripetuto senza set resta stabile
	t.almost(p.get_run_speed(), p.get_run_speed(), "run_speed getter deterministico")
	# Indipendenza tra le due proprieta (membri distinti nel .h righe 14-15)
	p.set_walk_speed(3.0)
	p.set_run_speed(7.0)
	t.almost(p.get_walk_speed(), 3.0, "set_run_speed non tocca walk_speed")
	t.almost(p.get_run_speed(), 7.0, "set_walk_speed non tocca run_speed")
	p.free()
