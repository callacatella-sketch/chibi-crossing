extends RefCounted

# Test per GridManager (GDExtension C++).
# Copre la proprieta' grid_size (get/set) e il metodo snap_to_grid(Vector3) -> Vector3.
# Firme e valori verificati su src/grid_manager.cpp e src/grid_manager.h.

func _vec_eq(t, a: Vector3, b: Vector3, msg: String) -> void:
	t.almost(a.x, b.x, msg + " [x]")
	t.almost(a.y, b.y, msg + " [y]")
	t.almost(a.z, b.z, msg + " [z]")

func run(t) -> void:
	# --- grid_size: default ---
	var gm := GridManager.new()
	t.almost(gm.get_grid_size(), 2.0, "grid_size di default e' 2.0")

	# --- grid_size: roundtrip deterministico ---
	gm.set_grid_size(3.5)
	t.almost(gm.get_grid_size(), 3.5, "dopo set_grid_size(3.5) get ritorna 3.5")
	gm.set_grid_size(1.0)
	t.almost(gm.get_grid_size(), 1.0, "dopo set_grid_size(1.0) get ritorna 1.0")

	# --- grid_size: valori <= 0 memorizzati senza clamp ---
	gm.set_grid_size(0.0)
	t.almost(gm.get_grid_size(), 0.0, "set_grid_size(0.0) memorizza 0.0 senza clamp")
	gm.set_grid_size(-2.0)
	t.almost(gm.get_grid_size(), -2.0, "set_grid_size(-2.0) memorizza -2.0 senza clamp")

	# =========================================================
	# snap_to_grid con grid_size = 2.0
	# =========================================================
	gm.set_grid_size(2.0)

	# L'origine si mappa nell'origine.
	_vec_eq(t, gm.snap_to_grid(Vector3.ZERO), Vector3.ZERO, "snap(ZERO) == ZERO con grid 2.0")

	# Un punto gia' su un centro cella resta invariato.
	_vec_eq(t, gm.snap_to_grid(Vector3(4, 0, -6)), Vector3(4, 0, -6), "punto su centro cella (4,0,-6) invariato")

	# Y sempre invariata: uso una Y non banale.
	var snapped_y := gm.snap_to_grid(Vector3(2.9, 7.3, 5.1))
	t.almost(snapped_y.y, 7.3, "Y restituita invariata da snap_to_grid")

	# Arrotondamenti concreti con grid 2.0.
	_vec_eq(t, gm.snap_to_grid(Vector3(2.9, 0.0, 5.1)), Vector3(2.0, 0.0, 6.0), "(2.9,_,5.1) -> (2,_,6) con grid 2.0")
	_vec_eq(t, gm.snap_to_grid(Vector3(3.9, 0.0, 4.1)), Vector3(4.0, 0.0, 4.0), "(3.9,_,4.1) -> (4,_,4) con grid 2.0")

	# Coordinate X e Z di output sono multipli interi di grid_size.
	var s := gm.snap_to_grid(Vector3(2.9, 0.0, 5.1))
	t.almost(round(s.x / 2.0) * 2.0, s.x, "X di output e' multiplo intero di grid_size 2.0")
	t.almost(round(s.z / 2.0) * 2.0, s.z, "Z di output e' multiplo intero di grid_size 2.0")

	# Idempotenza: snap(snap(p)) == snap(p).
	var p := Vector3(2.9, 7.3, 5.1)
	var once := gm.snap_to_grid(p)
	var twice := gm.snap_to_grid(once)
	_vec_eq(t, twice, once, "snap idempotente con grid 2.0")

	# Idempotenza anche su coordinate negative.
	var pn := Vector3(-3.4, -1.2, -6.6)
	var once_n := gm.snap_to_grid(pn)
	var twice_n := gm.snap_to_grid(once_n)
	_vec_eq(t, twice_n, once_n, "snap idempotente su negativi con grid 2.0")

	# =========================================================
	# snap_to_grid usa realmente il grid_size corrente: grid = 1.0
	# =========================================================
	gm.set_grid_size(1.0)
	_vec_eq(t, gm.snap_to_grid(Vector3(2.4, 9.0, 3.6)), Vector3(2.0, 9.0, 4.0), "(2.4,9.0,3.6) -> (2,9,4) con grid 1.0")

	# =========================================================
	# Early-return quando grid_size <= 0: posizione IDENTICA, nessun arrotondamento.
	# =========================================================
	var arbitrary := Vector3(2.9, 1.0, 5.1)

	gm.set_grid_size(0.0)
	_vec_eq(t, gm.snap_to_grid(arbitrary), arbitrary, "grid_size 0.0: snap ritorna la posizione identica")

	gm.set_grid_size(-2.0)
	_vec_eq(t, gm.snap_to_grid(arbitrary), arbitrary, "grid_size negativo: snap ritorna la posizione identica")

	gm.free()
