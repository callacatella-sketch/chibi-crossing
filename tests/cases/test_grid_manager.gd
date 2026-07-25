extends RefCounted
## Test per GridManager (GDExtension C++, src/grid_manager.cpp).
## Testa SOLO i metodi esposti in _bind_methods():
##   get_grid_size(), set_grid_size(p_size), snap_to_grid(position).
## GridManager e' un Node3D: si crea con .new() senza aggiungerlo all'albero,
## si usa e si libera con .free().


func run(t) -> void:
	var g := GridManager.new()

	# --- grid_size di default (campo C++: grid_size = 2.0) ---
	t.almost(g.get_grid_size(), 2.0, "grid_size di default e' 2.0")

	# --- roundtrip set/get (determinismo) ---
	g.set_grid_size(3.5)
	t.almost(g.get_grid_size(), 3.5, "set_grid_size/get_grid_size roundtrip")

	# --- snap_to_grid con griglia da 2.0 ---
	g.set_grid_size(2.0)

	# origine -> origine
	var o := g.snap_to_grid(Vector3.ZERO)
	t.almost(o.x, 0.0, "snap dell'origine: x = 0")
	t.almost(o.y, 0.0, "snap dell'origine: y = 0")
	t.almost(o.z, 0.0, "snap dell'origine: z = 0")

	# la Y viene SEMPRE mantenuta invariata (y = position.y nel codice)
	var py := g.snap_to_grid(Vector3(1.3, 5.75, 2.6))
	t.almost(py.y, 5.75, "snap mantiene la Y invariata")

	# punto gia' su un centro cella: resta invariato
	var on_grid := g.snap_to_grid(Vector3(4.0, 0.0, -6.0))
	t.almost(on_grid.x, 4.0, "punto su griglia: x invariato")
	t.almost(on_grid.z, -6.0, "punto su griglia: z invariato")

	# valori concreti di arrotondamento (grid 2.0), lontani dai casi limite .5
	var s := g.snap_to_grid(Vector3(2.9, 0.0, 5.1))
	t.almost(s.x, 2.0, "snap(2.9) -> 2.0 con grid 2 (round(1.45)*2)")
	t.almost(s.z, 6.0, "snap(5.1) -> 6.0 con grid 2 (round(2.55)*2)")

	var s2 := g.snap_to_grid(Vector3(3.9, 0.0, 4.1))
	t.almost(s2.x, 4.0, "snap(3.9) -> 4.0 con grid 2")
	t.almost(s2.z, 4.0, "snap(4.1) -> 4.0 con grid 2")

	# idempotenza: snap(snap(p)) == snap(p)
	var a := g.snap_to_grid(Vector3(7.3, 2.2, -3.7))
	var b := g.snap_to_grid(a)
	t.almost(b.x, a.x, "idempotenza snap: x")
	t.almost(b.y, a.y, "idempotenza snap: y")
	t.almost(b.z, a.z, "idempotenza snap: z")

	# le coordinate X e Z snappate sono multipli interi di grid_size
	t.almost(a.x - round(a.x / 2.0) * 2.0, 0.0, "x snappata e' multiplo di grid_size")
	t.almost(a.z - round(a.z / 2.0) * 2.0, 0.0, "z snappata e' multiplo di grid_size")

	# grid_size personalizzato realmente usato dallo snap
	g.set_grid_size(1.0)
	var c := g.snap_to_grid(Vector3(2.4, 9.0, 3.6))
	t.almost(c.x, 2.0, "grid 1.0: snap(2.4) -> 2.0")
	t.almost(c.y, 9.0, "grid 1.0: Y invariata")
	t.almost(c.z, 4.0, "grid 1.0: snap(3.6) -> 4.0")

	# grid_size <= 0 => snap_to_grid restituisce la posizione INVARIATA (early return)
	g.set_grid_size(0.0)
	var z0 := g.snap_to_grid(Vector3(1.234, 5.6, 7.89))
	t.almost(z0.x, 1.234, "grid_size 0: x invariata")
	t.almost(z0.y, 5.6, "grid_size 0: y invariata")
	t.almost(z0.z, 7.89, "grid_size 0: z invariata")

	g.set_grid_size(-1.0)
	var zn := g.snap_to_grid(Vector3(1.5, 2.5, 3.5))
	t.almost(zn.x, 1.5, "grid_size negativo: x invariata")
	t.almost(zn.z, 3.5, "grid_size negativo: z invariata")

	g.free()
