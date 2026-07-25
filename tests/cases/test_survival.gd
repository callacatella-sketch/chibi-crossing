extends RefCounted
## Test per SurvivalComponent (GDExtension C++, src/survival_component.cpp).
## Testa SOLO i metodi esposti in _bind_methods():
##   get/set_stamina, get/set_max_stamina, drain_stamina,
##   get/set_hunger, get/set_max_hunger, get/set_water, get/set_max_water,
##   e i segnali stamina_changed / hunger_changed / water_changed.
##
## SurvivalComponent e' un Node: lo si crea con .new() SENZA aggiungerlo al
## SceneTree, cosi _ready/_process non partono e non c'e drain di fame/acqua nel
## tempo. Alla fine di ogni test si chiama .free().


func run(t) -> void:
	_test_valori_iniziali(t)
	_test_stamina_clamp(t)
	_test_drain_stamina(t)
	_test_max_stamina(t)
	_test_hunger_clamp(t)
	_test_max_hunger(t)
	_test_water_clamp(t)
	_test_max_water(t)
	_test_segnali(t)


func _test_valori_iniziali(t) -> void:
	var c := SurvivalComponent.new()

	# Inizializzatori di campo nel .h: tutti i valori partono da 100.
	t.almost(c.get_stamina(), 100.0, "stamina iniziale == 100")
	t.almost(c.get_max_stamina(), 100.0, "max_stamina iniziale == 100")
	t.almost(c.get_hunger(), 100.0, "hunger iniziale == 100")
	t.almost(c.get_max_hunger(), 100.0, "max_hunger iniziale == 100")
	t.almost(c.get_water(), 100.0, "water iniziale == 100")
	t.almost(c.get_max_water(), 100.0, "max_water iniziale == 100")

	# Fuori dall'albero (_process non gira) i valori non cambiano da soli
	# tra due letture consecutive: nessun drain di fame/acqua.
	var s1 := c.get_stamina()
	var h1 := c.get_hunger()
	var w1 := c.get_water()
	var s2 := c.get_stamina()
	var h2 := c.get_hunger()
	var w2 := c.get_water()
	t.almost(s1, s2, "stamina invariata fuori dall'albero (no _process)")
	t.almost(h1, h2, "hunger invariata fuori dall'albero (no _process)")
	t.almost(w1, w2, "water invariata fuori dall'albero (no _process)")

	c.free()


func _test_stamina_clamp(t) -> void:
	var c := SurvivalComponent.new()

	# max_stamina di default = 100.
	c.set_stamina(150.0)
	t.almost(c.get_stamina(), 100.0, "set_stamina(150) clampa a max=100")
	t.ok(c.get_stamina() >= 0.0 and c.get_stamina() <= c.get_max_stamina(), "invariante clamp dopo set_stamina(150)")

	c.set_stamina(-50.0)
	t.almost(c.get_stamina(), 0.0, "set_stamina(-50) clampa a 0")
	t.ok(c.get_stamina() >= 0.0 and c.get_stamina() <= c.get_max_stamina(), "invariante clamp dopo set_stamina(-50)")

	c.set_stamina(60.0)
	t.almost(c.get_stamina(), 60.0, "set_stamina(60) roundtrip esatto in range")
	t.ok(c.get_stamina() >= 0.0 and c.get_stamina() <= c.get_max_stamina(), "invariante clamp dopo set_stamina(60)")

	c.free()


func _test_drain_stamina(t) -> void:
	var c := SurvivalComponent.new()

	# drain_stamina(amount) == set_stamina(stamina - amount).
	c.set_stamina(100.0)
	c.drain_stamina(30.0)
	t.almost(c.get_stamina(), 70.0, "drain_stamina(30) da 100 -> 70")

	# Non scende sotto 0.
	c.set_stamina(100.0)
	c.drain_stamina(200.0)
	t.almost(c.get_stamina(), 0.0, "drain_stamina(200) clampa a 0")

	# amount 0 lascia invariato.
	c.set_stamina(80.0)
	c.drain_stamina(0.0)
	t.almost(c.get_stamina(), 80.0, "drain_stamina(0) lascia il valore invariato")

	# amount negativo aggiunge stamina ma resta clampata a max.
	c.set_stamina(100.0)
	c.drain_stamina(-1000.0)
	t.almost(c.get_stamina(), 100.0, "drain_stamina(-1000) resta clampata a max=100")

	c.free()


func _test_max_stamina(t) -> void:
	# Abbassare il max riclampa il corrente verso il basso.
	var c := SurvivalComponent.new()
	c.set_stamina(100.0)
	c.set_max_stamina(50.0)
	t.almost(c.get_max_stamina(), 50.0, "set_max_stamina(50) -> max == 50")
	t.almost(c.get_stamina(), 50.0, "corrente riclampato a 50 quando si abbassa il max")

	# Max negativo diventa 0 via MAX(p,0) e riclampa il corrente a 0.
	c.set_max_stamina(-10.0)
	t.almost(c.get_max_stamina(), 0.0, "set_max_stamina(-10) -> max == 0 (MAX(p,0))")
	t.almost(c.get_stamina(), 0.0, "corrente riclampato a 0 con max 0")
	c.free()

	# Alzare il max NON aumenta il corrente.
	var c2 := SurvivalComponent.new()
	c2.set_stamina(100.0)
	c2.set_max_stamina(200.0)
	t.almost(c2.get_max_stamina(), 200.0, "set_max_stamina(200) -> max == 200")
	t.almost(c2.get_stamina(), 100.0, "alzare il max non aumenta il corrente (resta 100)")
	c2.free()


func _test_hunger_clamp(t) -> void:
	var c := SurvivalComponent.new()

	c.set_hunger(150.0)
	t.almost(c.get_hunger(), 100.0, "set_hunger(150) clampa a max=100")
	t.ok(c.get_hunger() >= 0.0 and c.get_hunger() <= c.get_max_hunger(), "invariante clamp dopo set_hunger(150)")

	c.set_hunger(-1.0)
	t.almost(c.get_hunger(), 0.0, "set_hunger(-1) clampa a 0")
	t.ok(c.get_hunger() >= 0.0 and c.get_hunger() <= c.get_max_hunger(), "invariante clamp dopo set_hunger(-1)")

	c.set_hunger(42.0)
	t.almost(c.get_hunger(), 42.0, "set_hunger(42) roundtrip esatto in range")
	t.ok(c.get_hunger() >= 0.0 and c.get_hunger() <= c.get_max_hunger(), "invariante clamp dopo set_hunger(42)")

	c.free()


func _test_max_hunger(t) -> void:
	var c := SurvivalComponent.new()
	c.set_hunger(100.0)
	c.set_max_hunger(30.0)
	t.almost(c.get_max_hunger(), 30.0, "set_max_hunger(30) -> max == 30")
	t.almost(c.get_hunger(), 30.0, "corrente hunger riclampato a 30")

	c.set_max_hunger(-5.0)
	t.almost(c.get_max_hunger(), 0.0, "set_max_hunger(-5) -> max == 0 (MAX(p,0))")
	t.almost(c.get_hunger(), 0.0, "corrente hunger riclampato a 0")
	c.free()

	var c2 := SurvivalComponent.new()
	c2.set_hunger(100.0)
	c2.set_max_hunger(300.0)
	t.almost(c2.get_max_hunger(), 300.0, "set_max_hunger(300) -> max == 300")
	t.almost(c2.get_hunger(), 100.0, "alzare il max hunger non aumenta il corrente (resta 100)")
	c2.free()


func _test_water_clamp(t) -> void:
	var c := SurvivalComponent.new()

	c.set_water(150.0)
	t.almost(c.get_water(), 100.0, "set_water(150) clampa a max=100")
	t.ok(c.get_water() >= 0.0 and c.get_water() <= c.get_max_water(), "invariante clamp dopo set_water(150)")

	c.set_water(-20.0)
	t.almost(c.get_water(), 0.0, "set_water(-20) clampa a 0")
	t.ok(c.get_water() >= 0.0 and c.get_water() <= c.get_max_water(), "invariante clamp dopo set_water(-20)")

	c.set_water(75.0)
	t.almost(c.get_water(), 75.0, "set_water(75) roundtrip esatto in range")
	t.ok(c.get_water() >= 0.0 and c.get_water() <= c.get_max_water(), "invariante clamp dopo set_water(75)")

	c.free()


func _test_max_water(t) -> void:
	var c := SurvivalComponent.new()
	c.set_water(100.0)
	c.set_max_water(40.0)
	t.almost(c.get_max_water(), 40.0, "set_max_water(40) -> max == 40")
	t.almost(c.get_water(), 40.0, "corrente water riclampato a 40")

	c.set_max_water(-100.0)
	t.almost(c.get_max_water(), 0.0, "set_max_water(-100) -> max == 0 (MAX(p,0))")
	t.almost(c.get_water(), 0.0, "corrente water riclampato a 0")
	c.free()

	var c2 := SurvivalComponent.new()
	c2.set_water(100.0)
	c2.set_max_water(250.0)
	t.almost(c2.get_max_water(), 250.0, "set_max_water(250) -> max == 250")
	t.almost(c2.get_water(), 100.0, "alzare il max water non aumenta il corrente (resta 100)")
	c2.free()


func _test_segnali(t) -> void:
	# I segnali funzionano anche su un nodo non nell'albero.
	# Ogni hit registra [new_value, max_value] cosi hits.size() e' il conteggio.

	# --- stamina_changed ---
	var c := SurvivalComponent.new()
	var stam_hits := []
	c.stamina_changed.connect(func(nv, mv): stam_hits.append([nv, mv]))
	# Valore invariato (default 100 -> clamp resta 100): NON emette.
	c.set_stamina(100.0)
	t.eq(stam_hits.size(), 0, "set_stamina(100) su 100 NON emette stamina_changed")
	# Cambio effettivo: emette esattamente una volta.
	c.set_stamina(50.0)
	t.eq(stam_hits.size(), 1, "set_stamina(50) emette stamina_changed una sola volta")
	t.almost(stam_hits[0][0], 50.0, "stamina_changed: new_value == 50")
	t.almost(stam_hits[0][1], c.get_max_stamina(), "stamina_changed: max_value == get_max_stamina()")
	c.free()

	# --- hunger_changed ---
	var h := SurvivalComponent.new()
	var hun_hits := []
	h.hunger_changed.connect(func(nv, mv): hun_hits.append([nv, mv]))
	# hunger=100 gia clampato a max: set_hunger(200) NON cambia il valore -> nessun segnale.
	h.set_hunger(200.0)
	t.eq(hun_hits.size(), 0, "set_hunger(200) su 100 (gia a max) NON emette hunger_changed")
	h.set_hunger(30.0)
	t.eq(hun_hits.size(), 1, "set_hunger(30) emette hunger_changed una sola volta")
	t.almost(hun_hits[0][0], 30.0, "hunger_changed: new_value == 30")
	t.almost(hun_hits[0][1], h.get_max_hunger(), "hunger_changed: max_value == get_max_hunger()")
	h.free()

	# --- water_changed ---
	var w := SurvivalComponent.new()
	var wat_hits := []
	w.water_changed.connect(func(nv, mv): wat_hits.append([nv, mv]))
	w.set_water(200.0)
	t.eq(wat_hits.size(), 0, "set_water(200) su 100 (gia a max) NON emette water_changed")
	w.set_water(25.0)
	t.eq(wat_hits.size(), 1, "set_water(25) emette water_changed una sola volta")
	t.almost(wat_hits[0][0], 25.0, "water_changed: new_value == 25")
	t.almost(wat_hits[0][1], w.get_max_water(), "water_changed: max_value == get_max_water()")
	w.free()
