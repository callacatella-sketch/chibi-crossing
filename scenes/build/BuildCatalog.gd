class_name BuildCatalog
extends RefCounted

## Il catalogo del builder: pezzi d'arredo procedurali "dipinti a mano".
## Ogni builder restituisce un Node3D con pivot al centro, appoggiato a
## terra (1 cella = 1 metro).
##
## Campi di ogni voce:
##   name     nome mostrato in UI
##   cat      0 Struttura · 1 Arredo · 2 Giardino
##   type     "cell" (occupa una cella) | "edge" (sta sul bordo tra due celle)
##   layer    per le celle: 0 pavimenti · 1 tappeti/decori · 2 oggetti
##   builder  Callable che costruisce il visual
##   cols     collisioni: array di [dimensioni Box, posizione centro] con
##            un terzo elemento opzionale: rotazione X (per le rampe)
##   up       true = il pezzo vive al piano di sopra (Solaio, Ponticello)

const HANDPAINT := preload("res://shaders/handpaint.gdshader")

const WOOD := Color("c89a6b")
const WOOD_DARK := Color("a87c50")
const WOOD_PALE := Color("e8cfa8")
const PLASTER := Color("f2e8d5")
const PLASTER_SHADE := Color("e2d4b8")
const TERRACOTTA := Color("d98d6a")
const LEAF := Color("7fbc62")
const LEAF_DARK := Color("5f9c48")
const PINK := Color("f4b8c8")
const PINK_DEEP := Color("eba4b8")
const CREAM := Color("fff3e0")
const STONE := Color("c9c2b4")
const STONE_DARK := Color("a89f92")
const METAL := Color("8a7f72")


static func items() -> Array[Dictionary]:
	return [
		# --- Struttura ---
		{"name": "Pavimento", "cat": 0, "type": "cell", "layer": 0, "builder": _floor_tile, "cols": []},
		{"name": "Sentiero", "cat": 0, "type": "cell", "layer": 0, "builder": _path_tile, "cols": []},
		{"name": "Tappeto", "cat": 0, "type": "cell", "layer": 1, "builder": _rug, "cols": []},
		{"name": "Muro", "cat": 0, "type": "edge", "layer": 2, "builder": _wall,
			"cols": [[Vector3(1.0, 2.1, 0.14), Vector3(0, 1.05, 0)]]},
		{"name": "Finestra", "cat": 0, "type": "edge", "layer": 2, "builder": _window_wall,
			"cols": [[Vector3(1.0, 2.1, 0.14), Vector3(0, 1.05, 0)]]},
		{"name": "Porta", "cat": 0, "type": "edge", "layer": 2, "builder": _door_wall,
			"cols": [[Vector3(0.16, 2.1, 0.14), Vector3(-0.42, 1.05, 0)],
					[Vector3(0.16, 2.1, 0.14), Vector3(0.42, 1.05, 0)]]},
		{"name": "Staccionata", "cat": 0, "type": "edge", "layer": 2, "builder": _fence,
			"cols": [[Vector3(0.95, 0.95, 0.1), Vector3(0, 0.47, 0)]]},
		{"name": "Tetto", "cat": 0, "type": "cell", "layer": 3, "builder": _roof_tile, "cols": []},
		{"name": "Scala", "cat": 0, "type": "cell", "layer": 2, "builder": _stairs,
			"cols": [[Vector3(0.9, 0.12, 2.44), Vector3(0, 1.07, 0), 1.135]]},
		{"name": "Solaio", "cat": 0, "type": "cell", "layer": 0, "up": true, "builder": _floor_slab,
			"cols": [[Vector3(1.0, 0.14, 1.0), Vector3(0, -0.07, 0)]]},
		{"name": "Ponticello", "cat": 0, "type": "cell", "layer": 0, "up": true, "builder": _rope_bridge,
			"cols": [[Vector3(1.0, 0.12, 1.0), Vector3(0, -0.1, 0)]]},
		{"name": "Casa albero", "cat": 0, "type": "cell", "layer": 2, "builder": _treehouse,
			"cols": [[Vector3(0.62, 2.4, 0.62), Vector3(0, 1.2, 0)],
					[Vector3(2.3, 0.12, 2.3), Vector3(0, 2.5, 0)],
					[Vector3(0.7, 0.1, 2.79), Vector3(0, 1.28, 1.6), 1.165]]},

		# --- Arredo ---
		{"name": "Tavolino", "cat": 1, "type": "cell", "layer": 2, "builder": _table,
			"cols": [[Vector3(0.75, 0.72, 0.75), Vector3(0, 0.36, 0)]]},
		{"name": "Sedia", "cat": 1, "type": "cell", "layer": 2, "builder": _chair,
			"cols": [[Vector3(0.46, 0.95, 0.46), Vector3(0, 0.47, 0)]]},
		{"name": "Sgabello", "cat": 1, "type": "cell", "layer": 2, "builder": _stool,
			"cols": [[Vector3(0.4, 0.5, 0.4), Vector3(0, 0.25, 0)]]},
		{"name": "Letto", "cat": 1, "type": "cell", "layer": 2, "builder": _bed,
			"cols": [[Vector3(0.92, 0.55, 0.98), Vector3(0, 0.27, 0)]]},
		{"name": "Libreria", "cat": 1, "type": "cell", "layer": 2, "builder": _bookshelf,
			"cols": [[Vector3(0.9, 1.55, 0.32), Vector3(0, 0.77, 0)]]},
		{"name": "Comodino", "cat": 1, "type": "cell", "layer": 2, "builder": _nightstand,
			"cols": [[Vector3(0.46, 0.55, 0.42), Vector3(0, 0.27, 0)]]},
		{"name": "Camino", "cat": 1, "type": "cell", "layer": 2, "builder": _fireplace,
			"cols": [[Vector3(0.92, 1.1, 0.42), Vector3(0, 0.55, 0)]]},
		{"name": "Lampada", "cat": 1, "type": "cell", "layer": 2, "builder": _lamp,
			"cols": [[Vector3(0.2, 1.75, 0.2), Vector3(0, 0.87, 0)]]},

		# --- Giardino ---
		{"name": "Pianta", "cat": 2, "type": "cell", "layer": 2, "builder": _plant,
			"cols": [[Vector3(0.32, 0.55, 0.32), Vector3(0, 0.27, 0)]]},
		{"name": "Aiuola", "cat": 2, "type": "cell", "layer": 1, "builder": _flowerbed, "cols": []},
		{"name": "Orto", "cat": 2, "type": "cell", "layer": 1, "builder": _vegetable_patch, "cols": []},
		{"name": "Alberello", "cat": 2, "type": "cell", "layer": 2, "builder": _sapling,
			"cols": [[Vector3(0.26, 1.3, 0.26), Vector3(0, 0.65, 0)]]},
		{"name": "Cespuglio", "cat": 2, "type": "cell", "layer": 2, "builder": _bush,
			"cols": [[Vector3(0.7, 0.65, 0.7), Vector3(0, 0.32, 0)]]},
		{"name": "Fungo", "cat": 2, "type": "cell", "layer": 2, "builder": _mushroom, "cols": []},
		{"name": "Cassetta posta", "cat": 2, "type": "cell", "layer": 2, "builder": _mailbox,
			"cols": [[Vector3(0.18, 1.1, 0.3), Vector3(0, 0.55, 0)]]},
		{"name": "Panchina", "cat": 2, "type": "cell", "layer": 2, "builder": _bench,
			"cols": [[Vector3(0.95, 0.85, 0.42), Vector3(0, 0.42, 0)]]},
		{"name": "Lavagna", "cat": 2, "type": "cell", "layer": 2, "builder": _blackboard,
			"cols": [[Vector3(1.05, 1.6, 0.16), Vector3(0, 0.8, 0.05)]]},

		# --- pezzi del NEGOZIO (si comprano dal mercante · vedi Economy.gd) ---
		{"name": "Casetta uccellini", "cat": 2, "type": "cell", "layer": 2, "builder": _birdhouse,
			"cols": [[Vector3(0.28, 1.5, 0.28), Vector3(0, 0.75, 0)]]},
		{"name": "Lampione", "cat": 2, "type": "cell", "layer": 2, "builder": _streetlamp,
			"cols": [[Vector3(0.22, 2.3, 0.22), Vector3(0, 1.15, 0)]]},
		{"name": "Amaca", "cat": 1, "type": "cell", "layer": 2, "builder": _hammock,
			"cols": [[Vector3(0.95, 0.95, 0.4), Vector3(0, 0.45, 0)]]},
		{"name": "Altalena", "cat": 2, "type": "cell", "layer": 2, "builder": _swing,
			"cols": [[Vector3(1.1, 1.65, 0.14), Vector3(0, 0.82, 0)]]},
		{"name": "Fontana", "cat": 2, "type": "cell", "layer": 2, "builder": _fountain,
			"cols": [[Vector3(0.98, 0.6, 0.98), Vector3(0, 0.3, 0)]]},
		{"name": "Gazebo", "cat": 0, "type": "cell", "layer": 2, "builder": _gazebo,
			"cols": [[Vector3(0.16, 2.2, 0.16), Vector3(0.5, 1.1, 0.5)],
					[Vector3(0.16, 2.2, 0.16), Vector3(-0.5, 1.1, 0.5)],
					[Vector3(0.16, 2.2, 0.16), Vector3(0.5, 1.1, -0.5)],
					[Vector3(0.16, 2.2, 0.16), Vector3(-0.5, 1.1, -0.5)]]},
		{"name": "Giostrina", "cat": 2, "type": "cell", "layer": 2, "builder": _carousel,
			"cols": [[Vector3(0.5, 1.6, 0.5), Vector3(0, 0.8, 0)]]},
		{"name": "Braciere stellato", "cat": 1, "type": "cell", "layer": 2, "builder": _brazier,
			"cols": [[Vector3(0.5, 0.8, 0.5), Vector3(0, 0.4, 0)]]},
		{"name": "Bancarella", "cat": 2, "type": "cell", "layer": 2, "builder": _player_stall,
			"cols": [[Vector3(1.3, 1.0, 0.7), Vector3(0, 0.5, 0)]]},
		{"name": "Stendino", "cat": 2, "type": "cell", "layer": 2, "builder": _clothesline,
			"cols": [[Vector3(0.12, 1.15, 0.12), Vector3(-0.55, 0.57, 0)],
					[Vector3(0.12, 1.15, 0.12), Vector3(0.55, 0.57, 0)]]},
		{"name": "Carillon", "cat": 1, "type": "cell", "layer": 2, "builder": _musicbox,
			"cols": [[Vector3(0.45, 0.75, 0.4), Vector3(0, 0.37, 0)]]},
		{"name": "Serra", "cat": 2, "type": "cell", "layer": 2, "builder": _greenhouse,
			"cols": [[Vector3(0.98, 1.35, 0.98), Vector3(0, 0.67, 0)]]},
		{"name": "Mongolfiera", "cat": 2, "type": "cell", "layer": 2, "builder": _balloon,
			"cols": [[Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0)],
					[Vector3(1.05, 1.3, 1.05), Vector3(0, 2.05, 0)]]},
	]


# ---------------------------------------------------------------- helper

static func _mat(a: Color, b: Color, scale := 6.0, amount := 0.5, trans := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", scale)
	mat.set_shader_parameter("noise_amount", amount)
	if trans > 0.0:
		mat.set_shader_parameter("translucency", trans)
	return mat


static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, top: float, bottom: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, radius: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- struttura

static func _floor_tile() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(1.0, 0.05, 1.0), _mat(WOOD_PALE, WOOD, 3.0, 0.55), Vector3(0, 0.025, 0))
	var groove := _mat(WOOD_DARK, WOOD_DARK, 1.0, 0.0)
	for i in 2:
		_box(n, Vector3(1.0, 0.012, 0.015), groove, Vector3(0, 0.052, -0.17 + 0.34 * i))
	return n


static func _path_tile() -> Node3D:
	var n := Node3D.new()
	var mat := _mat(STONE, STONE_DARK, 4.0, 0.55)
	_cyl(n, 0.4, 0.44, 0.05, mat, Vector3(0.05, 0.025, 0.03))
	_cyl(n, 0.16, 0.18, 0.045, mat, Vector3(-0.32, 0.022, -0.3))
	_cyl(n, 0.12, 0.14, 0.04, mat, Vector3(0.35, 0.02, -0.33))
	return n


static func _rug() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.46, 0.46, 0.025, _mat(CREAM, Color("f3dfc8"), 5.0, 0.5), Vector3(0, 0.065, 0))
	_cyl(n, 0.32, 0.32, 0.02, _mat(PINK, PINK_DEEP, 5.0, 0.45), Vector3(0, 0.085, 0))
	return n


static func _wall() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(1.0, 2.0, 0.14), _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5), Vector3(0, 1.0, 0))
	_box(n, Vector3(1.0, 0.14, 0.2), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.07, 0))
	_box(n, Vector3(1.0, 0.08, 0.18), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 2.04, 0))
	return n


static func _window_wall() -> Node3D:
	var n := _wall()
	_box(n, Vector3(0.58, 0.72, 0.18), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 1.25, 0))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("cfe8f5")
	glass.emission_enabled = true
	glass.emission = Color("bfe0f2")
	glass.emission_energy_multiplier = 0.35
	glass.roughness = 0.2
	_box(n, Vector3(0.46, 0.6, 0.2), glass, Vector3(0, 1.25, 0))
	var bar := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	_box(n, Vector3(0.46, 0.035, 0.21), bar, Vector3(0, 1.25, 0))
	_box(n, Vector3(0.035, 0.6, 0.21), bar, Vector3(0, 1.25, 0))
	return n


static func _door_wall() -> Node3D:
	# muro con porta socchiusa: il varco centrale è attraversabile
	var n := Node3D.new()
	var plaster := _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for side: float in [-1.0, 1.0]:
		_box(n, Vector3(0.16, 2.0, 0.14), plaster, Vector3(side * 0.42, 1.0, 0))
	_box(n, Vector3(1.0, 0.44, 0.14), plaster, Vector3(0, 1.78, 0))
	_box(n, Vector3(1.0, 0.08, 0.18), wood, Vector3(0, 2.04, 0))
	_box(n, Vector3(0.76, 0.1, 0.16), wood, Vector3(0, 1.61, 0))
	for side: float in [-1.0, 1.0]:
		_box(n, Vector3(0.08, 1.56, 0.16), wood, Vector3(side * 0.38, 0.78, 0))
	# l'anta: riempie tutto il varco (0.68 × 1.56, a filo di stipiti e
	# architrave). Chiusa di default, il BuildSystem la apre all'avvicinarsi.
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-0.34, 0, 0)
	n.add_child(hinge)
	var door_mat := _mat(Color("b3805a"), Color("96683f"), 3.0, 0.55)
	_box(hinge, Vector3(0.68, 1.56, 0.05), door_mat, Vector3(0.34, 0.78, 0))
	# doghe decorative
	var slat := _mat(Color("a2734e"), Color("8a5f3e"), 2.0, 0.4)
	_box(hinge, Vector3(0.56, 0.03, 0.055), slat, Vector3(0.34, 0.5, 0))
	_box(hinge, Vector3(0.56, 0.03, 0.055), slat, Vector3(0.34, 1.06, 0))
	_ball(hinge, 0.032, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0.6, 0.82, 0.05))
	return n


static func _fence() -> Node3D:
	var n := Node3D.new()
	var mat := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	for x in [-0.38, 0.38]:
		_box(n, Vector3(0.09, 0.85, 0.09), mat, Vector3(x, 0.425, 0))
		_ball(n, 0.06, mat, Vector3(x, 0.88, 0), Vector3(1, 0.7, 1))
	_box(n, Vector3(0.95, 0.08, 0.05), mat, Vector3(0, 0.62, 0))
	_box(n, Vector3(0.95, 0.08, 0.05), mat, Vector3(0, 0.32, 0))
	return n


static func _roof_tile() -> Node3D:
	# lastra di coppi: si affianca cella per cella sopra i muri (h 2.0)
	var n := Node3D.new()
	_box(n, Vector3(1.02, 0.1, 1.02), _mat(Color("d97e5f"), Color("c26847"), 3.0, 0.55), Vector3(0, 2.06, 0))
	var ridge := _mat(Color("b55c3e"), Color("a34f34"), 2.0, 0.4)
	for i in 3:
		_box(n, Vector3(1.02, 0.035, 0.07), ridge, Vector3(0, 2.115, -0.3 + 0.3 * i))
	# la pioggia si ferma sulle tegole: dentro casa non piove
	var pcol := GPUParticlesCollisionBox3D.new()
	pcol.size = Vector3(1.04, 0.14, 1.04)
	pcol.position = Vector3(0, 2.06, 0)
	n.add_child(pcol)
	return n


# ---------------------------------------------------------------- arredo

static func _table() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_cyl(n, 0.42, 0.42, 0.06, _mat(WOOD_PALE, WOOD, 3.0, 0.5), Vector3(0, 0.63, 0))
	_cyl(n, 0.055, 0.07, 0.6, wood, Vector3(0, 0.3, 0))
	_cyl(n, 0.2, 0.24, 0.05, wood, Vector3(0, 0.025, 0))
	return n


static func _chair() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_box(n, Vector3(0.42, 0.06, 0.42), wood, Vector3(0, 0.45, 0))
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			_box(n, Vector3(0.055, 0.45, 0.055), wood, Vector3(x, 0.225, z))
	var back := _box(n, Vector3(0.42, 0.55, 0.05), wood, Vector3(0, 0.75, -0.19))
	back.rotation.x = 0.08
	_cyl(n, 0.17, 0.17, 0.05, _mat(PINK, PINK_DEEP, 5.0, 0.4), Vector3(0, 0.505, 0.01))
	return n


static func _stool() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_cyl(n, 0.19, 0.21, 0.06, wood, Vector3(0, 0.4, 0))
	for i in 4:
		var a := (float(i) + 0.5) / 4.0 * TAU
		var leg := _box(n, Vector3(0.05, 0.4, 0.05), wood, Vector3(cos(a) * 0.13, 0.2, sin(a) * 0.13))
		leg.rotation.z = cos(a) * 0.12
		leg.rotation.x = -sin(a) * 0.12
	_cyl(n, 0.16, 0.16, 0.05, _mat(Color("bfe0c8"), Color("a8ccb2"), 5.0, 0.4), Vector3(0, 0.45, 0))
	return n


static func _bed() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_box(n, Vector3(0.92, 0.22, 0.98), wood, Vector3(0, 0.11, 0))
	_box(n, Vector3(0.92, 0.5, 0.07), wood, Vector3(0, 0.35, -0.46))
	_box(n, Vector3(0.86, 0.12, 0.9), _mat(CREAM, Color("f3e6d0"), 4.0, 0.4), Vector3(0, 0.28, 0))
	_box(n, Vector3(0.5, 0.1, 0.26), _mat(Color.WHITE, Color("f0ecdf"), 5.0, 0.35), Vector3(0, 0.37, -0.3))
	_box(n, Vector3(0.88, 0.07, 0.55), _mat(PINK, PINK_DEEP, 3.0, 0.5), Vector3(0, 0.35, 0.18))
	return n


static func _bookshelf() -> Node3D:
	# guscio aperto sul fronte (-Z): schiena, fianchi, cima e base, coi
	# ripiani e i libri BEN visibili — e la cima libera per la collezione
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	_box(n, Vector3(0.9, 1.55, 0.06), pale, Vector3(0, 0.775, 0.12))
	for side in [-0.435, 0.435]:
		_box(n, Vector3(0.06, 1.55, 0.3), wood, Vector3(side, 0.775, 0))
	_box(n, Vector3(0.9, 0.06, 0.3), wood, Vector3(0, 1.52, 0))
	_box(n, Vector3(0.9, 0.06, 0.3), wood, Vector3(0, 0.03, 0))
	for row in 3:
		var base_y := 0.06 + row * 0.48
		if row > 0:
			_box(n, Vector3(0.78, 0.04, 0.26), wood, Vector3(0, base_y - 0.02, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = row * 17 + 3
		var x := -0.36
		while x < 0.3:
			var w := rng.randf_range(0.055, 0.09)
			var h := rng.randf_range(0.24, 0.36)
			var col: Color = [Color("d97f7f"), Color("7fa8d9"), Color("d9c27f"), Color("8fbc8a"), Color("b78ac2")][rng.randi() % 5]
			_box(n, Vector3(w, h, 0.2), _mat(col, col.darkened(0.2), 6.0, 0.4),
					Vector3(x + w * 0.5, base_y + h * 0.5, -0.02))
			x += w + rng.randf_range(0.005, 0.03)
	return n


static func _nightstand() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_box(n, Vector3(0.45, 0.45, 0.4), wood, Vector3(0, 0.28, 0))
	_box(n, Vector3(0.36, 0.16, 0.03), _mat(WOOD_PALE, WOOD, 3.0, 0.45), Vector3(0, 0.34, 0.2))
	_ball(n, 0.025, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0, 0.34, 0.225))
	# candelina
	_cyl(n, 0.035, 0.035, 0.09, _mat(CREAM, Color("f3e6d0"), 5.0, 0.35), Vector3(0.1, 0.55, 0))
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color("ffd382")
	flame.emission_enabled = true
	flame.emission = Color("ffb84d")
	flame.emission_energy_multiplier = 2.5
	_ball(n, 0.02, flame, Vector3(0.1, 0.62, 0), Vector3(1, 1.5, 1))
	return n


static func _fireplace() -> Node3D:
	var n := Node3D.new()
	var stone := _mat(STONE, STONE_DARK, 3.0, 0.55)
	_box(n, Vector3(0.9, 0.9, 0.4), stone, Vector3(0, 0.45, 0))
	_box(n, Vector3(1.0, 0.1, 0.48), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.95, 0))
	_box(n, Vector3(0.54, 0.5, 0.42), _mat(Color("3a3230"), Color("2a2422"), 3.0, 0.4), Vector3(0, 0.32, 0.01))
	# braci
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color("ff9440")
	coal.emission_enabled = true
	coal.emission = Color("ff7a26")
	coal.emission_energy_multiplier = 1.8
	_ball(n, 0.06, coal, Vector3(-0.08, 0.12, 0.08), Vector3(1, 0.6, 1))
	_ball(n, 0.05, coal, Vector3(0.09, 0.11, 0.05), Vector3(1, 0.6, 1))

	# fuoco
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.55, 0.2, 0.5), Color(1.0, 0.4, 0.1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.albedo_texture = tex
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.vertex_color_use_as_albedo = true
	quad.material = fmat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.16, 0.02, 0.1)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var fire := GPUParticles3D.new()
	fire.amount = 16
	fire.lifetime = 0.7
	fire.process_material = pm
	fire.draw_pass_1 = quad
	fire.position = Vector3(0, 0.16, 0.05)
	n.add_child(fire)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.1
	light.omni_range = 3.2
	light.position = Vector3(0, 0.4, 0.3)
	n.add_child(light)

	# il COMIGNOLO: la canna che sale sopra la mensola e il vaso in
	# terracotta col cappello. È da qui che la sera esce il filo di fumo
	# (l'emettitore lo aggancia VitaSecondaria, in cima alla canna)
	_box(n, Vector3(0.34, 0.52, 0.3), stone, Vector3(0, 1.26, 0))
	_box(n, Vector3(0.42, 0.06, 0.38), _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5),
			Vector3(0, 1.55, 0))
	_cyl(n, 0.085, 0.105, 0.18, _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5),
			Vector3(0, 1.65, 0))
	_box(n, Vector3(0.26, 0.035, 0.26), stone, Vector3(0, 1.78, 0))
	return n


static func _lamp() -> Node3D:
	var n := Node3D.new()
	var metal := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.11, 0.15, 0.06, metal, Vector3(0, 0.03, 0))
	_cyl(n, 0.028, 0.035, 1.45, metal, Vector3(0, 0.78, 0))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffe6b0")
	glow.emission_enabled = true
	glow.emission = Color("ffd382")
	glow.emission_energy_multiplier = 2.2
	_ball(n, 0.16, glow, Vector3(0, 1.6, 0))
	_cyl(n, 0.05, 0.19, 0.1, metal, Vector3(0, 1.74, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 1.6
	light.omni_range = 4.5
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 1.58, 0)
	n.add_child(light)
	return n


# ---------------------------------------------------------------- giardino

static func _plant() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.17, 0.12, 0.22, _mat(TERRACOTTA, Color("bd7455"), 4.0, 0.5), Vector3(0, 0.11, 0))
	_cyl(n, 0.13, 0.13, 0.03, _mat(Color("6a4a38"), Color("53382a"), 6.0, 0.4), Vector3(0, 0.225, 0))
	var leaf := _mat(LEAF, LEAF_DARK, 3.0, 0.6)
	_ball(n, 0.17, leaf, Vector3(0, 0.42, 0))
	_ball(n, 0.12, leaf, Vector3(0.1, 0.52, 0.05))
	_ball(n, 0.11, leaf, Vector3(-0.1, 0.5, -0.04))
	_ball(n, 0.035, _mat(PINK, Color("ffd7e2"), 6.0, 0.4), Vector3(0.05, 0.62, 0.02))
	return n


static func _flowerbed() -> Node3D:
	# aiuola da giardinaggio: terra smossa pronta per i semi. I germogli e
	# i fiori li fa crescere il sistema Garden, notte dopo notte.
	var n := Node3D.new()
	_cyl(n, 0.44, 0.46, 0.07, _mat(Color("7a5a42"), Color("64483a"), 4.0, 0.5), Vector3(0, 0.035, 0))
	# solchi di semina
	var furrow := _mat(Color("5e4534"), Color("50392c"), 3.0, 0.4)
	for i in 3:
		_box(n, Vector3(0.58, 0.012, 0.055), furrow, Vector3(0, 0.071, -0.2 + 0.2 * i))
	# sassolini sul bordo
	var pebble := _mat(Color("c9c2b4"), Color("a89f92"), 5.0, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 7:
		var a := float(i) / 7.0 * TAU + 0.2
		_ball(n, rng.randf_range(0.03, 0.045), pebble,
				Vector3(cos(a) * 0.44, 0.035, sin(a) * 0.44), Vector3(1, 0.7, 1))
	return n


static func _vegetable_patch() -> Node3D:
	# l'orto: terra squadrata coi solchi e i picchetti agli angoli.
	# Semina, annaffia e il Garden fa crescere carote, zucche o bacche.
	var n := Node3D.new()
	_box(n, Vector3(0.92, 0.07, 0.92), _mat(Color("6f5240"), Color("5a4234"), 4.0, 0.5), Vector3(0, 0.035, 0))
	var furrow := _mat(Color("543d2e"), Color("463327"), 3.0, 0.4)
	for i in 3:
		_box(n, Vector3(0.8, 0.014, 0.07), furrow, Vector3(0, 0.072, -0.24 + 0.24 * i))
	var stake := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx in [-0.42, 0.42]:
		for sz in [-0.42, 0.42]:
			_box(n, Vector3(0.05, 0.24, 0.05), stake, Vector3(sx, 0.12, sz))
	return n


static func _blackboard() -> Node3D:
	# la lavagna del villaggio: i nuovi abitanti ci scrivono il loro
	# compleanno, il Calendario ci appende gli eventi. Fronte verso -Z.
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.48, 0.48]:
		_box(n, Vector3(0.09, 1.6, 0.09), wood, Vector3(sx, 0.8, 0.06))
	_box(n, Vector3(1.06, 0.1, 0.1), wood, Vector3(0, 1.52, 0.05))
	_box(n, Vector3(1.06, 0.08, 0.1), wood, Vector3(0, 0.42, 0.05))
	# il quadro nero-verde, appena inclinato all'indietro
	var slate := _box(n, Vector3(0.94, 1.02, 0.05),
			_mat(Color("3d4a40"), Color("32403a"), 5.0, 0.35), Vector3(0, 0.97, 0.06))
	slate.rotation.x = 0.05
	# la vaschetta dei gessetti, coi gessetti
	_box(n, Vector3(0.9, 0.05, 0.12), wood, Vector3(0, 0.47, -0.02))
	_box(n, Vector3(0.12, 0.025, 0.025), _mat(Color("fff8ee"), Color("efe6da"), 6.0, 0.3),
			Vector3(-0.2, 0.51, -0.02))
	_box(n, Vector3(0.1, 0.025, 0.025), _mat(Color("f4c2cf"), Color("e8aebe"), 6.0, 0.3),
			Vector3(0.14, 0.51, -0.02))
	return n


# ------------------------------------------------- verticalità

static func _stairs() -> Node3D:
	# scala di legno ripida ma percorribile: sale verso -Z (R per girarla)
	var n := Node3D.new()
	var step_mat := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var dark := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	for i in 8:
		var y := (float(i) + 0.5) * 0.269
		var z := 0.4375 - float(i) * 0.125
		_box(n, Vector3(0.86, 0.269, 0.125), step_mat, Vector3(0, y, z))
	# fiancate e corrimano inclinati
	for sx: float in [-0.45, 0.45]:
		var stringer := _box(n, Vector3(0.06, 0.16, 2.44), dark, Vector3(sx, 1.07, 0))
		stringer.rotation.x = 1.135
		var rail := _box(n, Vector3(0.05, 0.07, 2.5), step_mat, Vector3(sx, 1.85, 0))
		rail.rotation.x = 1.135
		for t: float in [0.12, 0.88]:
			_box(n, Vector3(0.06, 0.8, 0.06), dark,
					Vector3(sx, 0.269 * 8.0 * t - 1.05 * t + 0.55, 0.4 - t * 0.8))
	return n


static func _floor_slab() -> Node3D:
	# il solaio: assito di legno col piano di calpestio a y 0 (vive già
	# alzato a quota piano: le travi sotto si vedono da giù)
	var n := Node3D.new()
	_box(n, Vector3(1.0, 0.08, 1.0), _mat(WOOD_PALE, WOOD, 5.0, 0.4), Vector3(0, -0.04, 0))
	var dark := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	for gz: float in [-0.17, 0.17]:
		_box(n, Vector3(1.0, 0.006, 0.018), dark, Vector3(0, 0.002, gz))
	for bx: float in [-0.42, 0.42]:
		_box(n, Vector3(0.09, 0.1, 1.0), dark, Vector3(bx, -0.12, 0))
	return n


static func _rope_bridge() -> Node3D:
	# ponticello di corda: assi che incurvano appena, corde e paletti.
	# Corre lungo Z (R per orientarlo); il piano resta camminabile.
	var n := Node3D.new()
	var plank := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var rope := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	for i in 6:
		var t := float(i) / 5.0
		var z := -0.415 + t * 0.83
		var dip := -0.05 - 0.045 * sin(PI * t)
		var p := _box(n, Vector3(0.86, 0.045, 0.145), plank, Vector3(0, dip, z))
		p.rotation.z = 0.03 if i % 2 == 0 else -0.03
	for sx: float in [-0.46, 0.46]:
		# paletti agli angoli e corrimano in due tratti che si abbassano al centro
		for sz: float in [-0.48, 0.48]:
			_cyl(n, 0.032, 0.04, 0.52, rope, Vector3(sx, 0.16, sz))
		for half: float in [-1.0, 1.0]:
			var seg := _cyl(n, 0.02, 0.02, 0.54, rope, Vector3(sx, 0.33, half * 0.25))
			seg.rotation.x = PI * 0.5 + half * 0.17
		# cordine verticali tra corrimano e assi
		for i in 3:
			var z := -0.25 + float(i) * 0.25
			_cyl(n, 0.011, 0.011, 0.36, rope, Vector3(sx, 0.12, z))
	return n


static func _treehouse() -> Node3D:
	# il premio finale: la casetta sull'albero. Tronco, chioma, piattaforma
	# con ringhiera, casetta con la finestrella accesa, scala a pioli e la
	# lanterna che dondola (l'oscillazione la anima il BuildSystem).
	var n := Node3D.new()
	var bark := _mat(Color("9a6b4f"), Color("7e563f"), 3.0, 0.55)
	var leaf := _mat(LEAF, LEAF_DARK, 2.0, 0.6, 0.4)
	var plank := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var dark := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	var plaster := _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5)
	var tile := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)

	# tronco, radici, rami
	_cyl(n, 0.24, 0.36, 2.7, bark, Vector3(0, 1.35, 0))
	_cyl(n, 0.15, 0.2, 1.4, bark, Vector3(0, 3.3, 0))
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.4
		var root := _cyl(n, 0.08, 0.14, 0.5, bark, Vector3(cos(a) * 0.34, 0.16, sin(a) * 0.34))
		root.rotation.x = cos(a) * 0.5
		root.rotation.z = sin(a) * 0.5
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var branch := _cyl(n, 0.06, 0.1, 0.9, bark, Vector3(s * 0.45, 3.55, -0.1 * s))
		branch.rotation.z = s * 1.0

	# la chioma abbraccia la casetta
	_ball(n, 1.25, leaf, Vector3(0, 4.45, 0))
	_ball(n, 0.9, leaf, Vector3(0.95, 4.05, 0.3))
	_ball(n, 0.95, leaf, Vector3(-0.85, 4.1, -0.35))
	_ball(n, 0.85, leaf, Vector3(0.1, 4.15, -0.95))

	# piattaforma con fascia, travetti e puntoni di sostegno
	_box(n, Vector3(2.3, 0.1, 2.3), _mat(WOOD_PALE, WOOD, 5.0, 0.4), Vector3(0, 2.51, 0))
	for gz: float in [-0.75, -0.25, 0.25, 0.75]:
		_box(n, Vector3(2.3, 0.006, 0.02), dark, Vector3(0, 2.562, gz))
	for e: float in [-1.16, 1.16]:
		_box(n, Vector3(2.36, 0.09, 0.07), dark, Vector3(0, 2.5, e))
		_box(n, Vector3(0.07, 0.09, 2.36), dark, Vector3(e, 2.5, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var strut := _cyl(n, 0.05, 0.05, 1.45, bark, Vector3(sx * 0.5, 1.95, sz * 0.5))
			strut.rotation.x = -sz * 0.55
			strut.rotation.z = sx * 0.55

	# ringhiera (varco a sud per la scala)
	var posts: Array[Vector3] = []
	for x: float in [-1.1, -0.55, 0.0, 0.55, 1.1]:
		posts.append(Vector3(x, 0, -1.1))
	for x: float in [-1.1, -0.55, 0.55, 1.1]:
		posts.append(Vector3(x, 0, 1.1))
	for z: float in [-0.55, 0.0, 0.55]:
		posts.append(Vector3(-1.1, 0, z))
		posts.append(Vector3(1.1, 0, z))
	for p in posts:
		_box(n, Vector3(0.07, 0.52, 0.07), plank, Vector3(p.x, 2.82, p.z))
	_box(n, Vector3(2.27, 0.06, 0.05), plank, Vector3(0, 3.08, -1.1))
	_box(n, Vector3(0.05, 0.06, 2.27), plank, Vector3(-1.1, 3.08, 0))
	_box(n, Vector3(0.05, 0.06, 2.27), plank, Vector3(1.1, 3.08, 0))
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.72, 0.06, 0.05), plank, Vector3(sx * 0.74, 3.08, 1.1))

	# la casetta: pareti intonacate, montanti, porta a sud, finestrella accesa
	var hy := 3.13
	for sxw: float in [-1.0, 1.0]:
		_box(n, Vector3(0.42, 1.1, 0.1), plaster, Vector3(sxw * 0.54, hy, 0.32))
		_box(n, Vector3(0.1, 1.1, 1.42), plaster, Vector3(sxw * 0.7, hy, -0.37))
	_box(n, Vector3(1.5, 1.1, 0.1), plaster, Vector3(0, hy, -1.06))
	_box(n, Vector3(1.5, 0.28, 0.1), plaster, Vector3(0, 3.54, 0.32))
	for cx: float in [-0.7, 0.7]:
		for cz: float in [-1.06, 0.32]:
			_box(n, Vector3(0.11, 1.16, 0.11), dark, Vector3(cx, hy, cz))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd9a0")
	glow.emission_enabled = true
	glow.emission = Color("ffc978")
	glow.emission_energy_multiplier = 1.1
	var win := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.14
	wm.bottom_radius = 0.14
	wm.height = 0.03
	win.mesh = wm
	win.material_override = glow
	win.position = Vector3(0.76, 3.24, -0.37)
	win.rotation.z = PI * 0.5
	n.add_child(win)

	# tetto a falde col colmo
	for half: float in [-1.0, 1.0]:
		var slope := _box(n, Vector3(1.78, 0.07, 0.98), tile, Vector3(0, 3.94, -0.37 + half * 0.38))
		slope.rotation.x = -half * 0.62
	_box(n, Vector3(1.82, 0.09, 0.12), dark, Vector3(0, 4.22, -0.37))

	# scala a pioli (sale da sud): montanti inclinati e pioli tondi
	for sx: float in [-0.3, 0.3]:
		var stringer := _box(n, Vector3(0.06, 0.11, 2.85), dark, Vector3(sx, 1.28, 1.6))
		stringer.rotation.x = 1.165
	for i in 7:
		var t := (float(i) + 0.7) / 8.0
		var rung := _cyl(n, 0.032, 0.032, 0.62, plank,
				Vector3(0, 0.25 + t * 2.25, 2.18 - t * 1.15))
		rung.rotation.z = PI * 0.5

	# la lanterna sul braccio della gronda: il pivot dondola nel vento
	_box(n, Vector3(0.42, 0.055, 0.055), dark, Vector3(0.78, 3.68, 0.5))
	var pivot := Node3D.new()
	pivot.name = "LanternaPivot"
	pivot.position = Vector3(0.97, 3.66, 0.5)
	n.add_child(pivot)
	var chain := _cyl(pivot, 0.012, 0.012, 0.26, dark, Vector3(0, -0.13, 0))
	chain.rotation.z = 0.0
	_cyl(pivot, 0.085, 0.075, 0.19, _mat(METAL, Color("6f665b"), 4.0, 0.4), Vector3(0, -0.36, 0))
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.058
	cm.height = 0.116
	core.mesh = cm
	core.material_override = glow
	core.position = Vector3(0, -0.36, 0)
	pivot.add_child(core)
	_cyl(pivot, 0.02, 0.05, 0.06, dark, Vector3(0, -0.245, 0))
	var light := OmniLight3D.new()
	light.light_color = Color("ffc98a")
	light.light_energy = 1.3
	light.omni_range = 4.5
	light.shadow_enabled = false
	light.position = Vector3(0, -0.42, 0)
	pivot.add_child(light)
	return n


static func _sapling() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.05, 0.08, 0.55, _mat(Color("9a6b4f"), Color("7e563f"), 4.0, 0.5), Vector3(0, 0.27, 0))
	var leaf := _mat(Color("97cc74"), Color("74b05c"), 2.0, 0.6, 0.45)
	_ball(n, 0.32, leaf, Vector3(0, 0.75, 0))
	_ball(n, 0.22, leaf, Vector3(0.16, 0.95, 0.05))
	_ball(n, 0.2, leaf, Vector3(-0.15, 0.92, -0.05))
	return n


static func _bush() -> Node3D:
	var n := Node3D.new()
	var leaf := _mat(Color("8cc873"), Color("6cae5b"), 2.0, 0.6, 0.4)
	_ball(n, 0.32, leaf, Vector3(0, 0.28, 0))
	_ball(n, 0.24, leaf, Vector3(0.2, 0.24, 0.08), Vector3(1, 0.9, 1))
	_ball(n, 0.22, leaf, Vector3(-0.2, 0.22, -0.06), Vector3(1, 0.9, 1))
	_ball(n, 0.035, _mat(PINK_DEEP, PINK, 6.0, 0.4), Vector3(0.12, 0.5, 0.12))
	_ball(n, 0.03, _mat(Color("fff6f9"), CREAM, 6.0, 0.4), Vector3(-0.16, 0.42, 0.1))
	return n


static func _mushroom() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.05, 0.07, 0.14, _mat(CREAM, Color("f0e2cc"), 5.0, 0.4), Vector3(0, 0.07, 0))
	_ball(n, 0.14, _mat(Color("d96a6a"), Color("c25454"), 4.0, 0.5), Vector3(0, 0.16, 0), Vector3(1, 0.62, 1))
	var dot := _mat(Color.WHITE, CREAM, 4.0, 0.2)
	_ball(n, 0.025, dot, Vector3(0.06, 0.21, 0.05))
	_ball(n, 0.02, dot, Vector3(-0.05, 0.22, -0.03))
	_ball(n, 0.018, dot, Vector3(0.0, 0.19, -0.09))
	return n


static func _mailbox() -> Node3D:
	# cassetta animabile dal sistema posta: "Lid" (sportello incernierato in
	# basso), "Flag" (bandierina, alzata = c'è posta), "Letter" (la busta
	# che fa capolino). Il fronte guarda verso -Z.
	var n := Node3D.new()
	_cyl(n, 0.03, 0.04, 0.85, _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.42, 0))
	var body := _mat(Color("d97f7f"), Color("c26a6a"), 4.0, 0.45)
	_box(n, Vector3(0.24, 0.2, 0.34), body, Vector3(0, 0.94, 0.01))
	_cyl(n, 0.12, 0.12, 0.36, body, Vector3(0, 1.04, 0)).rotation.x = PI * 0.5
	# fondo scuro dell'imboccatura, svelato dallo sportello aperto
	_box(n, Vector3(0.2, 0.16, 0.012), _mat(Color("4a3230"), Color("3a2624"), 3.0, 0.4), Vector3(0, 0.94, -0.155))

	# la busta, nascosta finché non arriva posta
	var letter := _box(n, Vector3(0.15, 0.105, 0.012), _mat(CREAM, Color("f3e6d0"), 5.0, 0.35), Vector3(0, 0.95, -0.125))
	letter.name = "Letter"
	letter.rotation.x = -0.3
	letter.visible = false
	# sigillo a cuoricino
	_ball(letter, 0.016, _mat(PINK_DEEP, PINK, 4.0, 0.3), Vector3(0, 0.0, -0.01))

	# sportello incernierato sul bordo basso del fronte
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.845, -0.175)
	n.add_child(lid)
	_box(lid, Vector3(0.22, 0.19, 0.016), _mat(Color("e89090"), Color("d47a7a"), 4.0, 0.45), Vector3(0, 0.095, 0))
	_ball(lid, 0.018, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0, 0.155, -0.014))

	# bandierina: abbassata di default, si alza quando arriva una lettera
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0.135, 0.99, 0.08)
	flag.rotation.x = -1.35
	n.add_child(flag)
	var yellow := _mat(Color("ffd76e"), Color("eec254"), 4.0, 0.4)
	_box(flag, Vector3(0.016, 0.15, 0.03), yellow, Vector3(0, 0.075, 0))
	_box(flag, Vector3(0.016, 0.05, 0.09), yellow, Vector3(0, 0.13, -0.05))
	return n


static func _bench() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var dark := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	for x in [-0.36, 0.36]:
		_box(n, Vector3(0.08, 0.42, 0.34), dark, Vector3(x, 0.21, 0))
	_box(n, Vector3(0.95, 0.05, 0.17), wood, Vector3(0, 0.44, 0.09))
	_box(n, Vector3(0.95, 0.05, 0.17), wood, Vector3(0, 0.44, -0.1))
	var back_a := _box(n, Vector3(0.95, 0.14, 0.04), wood, Vector3(0, 0.62, -0.19))
	var back_b := _box(n, Vector3(0.95, 0.14, 0.04), wood, Vector3(0, 0.8, -0.22))
	back_a.rotation.x = 0.15
	back_b.rotation.x = 0.15
	return n


# ================================================================ NEGOZIO
# I pezzi che si comprano dal mercante (con le noccioline o le stelline).
# Stessa mano pastello del resto del catalogo.

# la bancarella di Mochi: il banco di legno chiaro col tendone menta e
# crema (MAI rosa: quello è il carretto del mercante), tre piedistalli
# per la merce esposta e il cartellino di legno sul fianco. La merce vera
# e i prezzi li mette il sistema Bancarella.gd: qui solo il banco.
static func _player_stall() -> Node3D:
	var n := Node3D.new()
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	# il banco: cassa piena, piano sporgente, zoccolo
	_box(n, Vector3(1.16, 0.08, 0.62), wood, Vector3(0, 0.04, 0))
	_box(n, Vector3(1.08, 0.72, 0.5), pale, Vector3(0, 0.44, 0))
	_box(n, Vector3(1.26, 0.07, 0.62), wood, Vector3(0, 0.83, 0))
	# la fascia frontale coi listelli
	for i in 5:
		_box(n, Vector3(0.16, 0.5, 0.03), wood, Vector3(-0.44 + float(i) * 0.22, 0.5, 0.26))
	# i montanti e il tendone a strisce menta e crema
	for sx: float in [-0.56, 0.56]:
		_box(n, Vector3(0.06, 1.5, 0.06), wood, Vector3(sx, 0.78, -0.18))
	for i in 6:
		var stripe := _box(n, Vector3(0.22, 0.045, 0.78),
				_mat(Color("9fd8cf"), Color("86c2b8"), 4.0, 0.4) if i % 2 == 0 \
				else _mat(CREAM, Color("f0e2cc"), 4.0, 0.4),
				Vector3(-0.55 + float(i) * 0.22, 1.56, -0.02))
		stripe.rotation.z = 0.07
		stripe.rotation.x = -0.12
	# i tre piedistalli della merce (gli stessi offset che usa Bancarella.gd)
	for sx: float in [-0.38, 0.0, 0.38]:
		_cyl(n, 0.1, 0.11, 0.05, wood, Vector3(sx, 0.89, 0.02))
	# il cartellino di legno appeso sul fianco, con lo spago
	var targa := _box(n, Vector3(0.26, 0.18, 0.03), pale, Vector3(0.66, 0.62, 0.12))
	targa.rotation.z = -0.08
	_cyl(n, 0.008, 0.008, 0.14, _mat(Color("d9c08a"), Color("c0a878"), 10.0, 0.4),
			Vector3(0.64, 0.76, 0.12))
	return n


# lo stendino: due pali a T, la corda che fa la pancia in mezzo e il
# cestello di vimini alla base. Nasce VUOTO: i teli ce li mettono Mochi
# (E — stendi il bucato) o i residenti, ed è VitaSecondaria a gestirli.
static func _clothesline() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.55, 0.55]:
		_box(n, Vector3(0.07, 1.15, 0.07), wood, Vector3(sx, 0.57, 0))
		_box(n, Vector3(0.24, 0.05, 0.06), wood, Vector3(sx, 1.12, 0))
		# il picchetto di sbieco che tiene il palo
		var picchetto := _box(n, Vector3(0.05, 0.4, 0.05), wood, Vector3(sx * 0.82, 0.2, 0.12))
		picchetto.rotation.x = -0.5
		picchetto.rotation.z = -sx * 0.35
	# la corda, in tre segmenti con la pancia al centro
	var corda := _mat(Color("d9c08a"), Color("c0a878"), 10.0, 0.4)
	var seg1 := _cyl(n, 0.012, 0.012, 0.4, corda, Vector3(-0.35, 1.09, 0))
	seg1.rotation.z = PI * 0.5 - 0.1
	var seg2 := _cyl(n, 0.012, 0.012, 0.34, corda, Vector3(0, 1.055, 0))
	seg2.rotation.z = PI * 0.5
	var seg3 := _cyl(n, 0.012, 0.012, 0.4, corda, Vector3(0.35, 1.09, 0))
	seg3.rotation.z = PI * 0.5 + 0.1
	# il cestello del bucato, di vimini, appoggiato a un palo
	var vimini := _mat(Color("c9a86a"), Color("a8874c"), 5.0, 0.5)
	_box(n, Vector3(0.24, 0.15, 0.17), vimini, Vector3(0.36, 0.08, 0.16))
	_box(n, Vector3(0.26, 0.03, 0.19), _mat(Color("b8935a"), Color("97783f"), 5.0, 0.5),
			Vector3(0.36, 0.16, 0.16))
	return n


# il carillon: cassa di ciliegio, rullo d'ottone e la manovella sul fianco.
# La musica vera la mette Interactions (E per caricarlo): qui solo il corpo.
static func _musicbox() -> Node3D:
	var n := Node3D.new()
	var ciliegio := _mat(Color("b06a4a"), Color("8f5238"), 4.0, 0.5)
	var ottone := _mat(Color("e8c46a"), Color("c49c48"), 5.0, 0.35)
	_box(n, Vector3(0.42, 0.1, 0.36), _mat(WOOD_DARK, Color("7a5636"), 4.0, 0.5), Vector3(0, 0.05, 0))
	_box(n, Vector3(0.38, 0.3, 0.32), ciliegio, Vector3(0, 0.25, 0))
	_box(n, Vector3(0.4, 0.04, 0.34), ottone, Vector3(0, 0.42, 0))
	# il rullo a pettine, coi dentini che pizzicano le note
	var rullo := _cyl(n, 0.07, 0.07, 0.26, ottone, Vector3(0, 0.52, 0))
	rullo.rotation.z = PI * 0.5
	for i in 5:
		_box(n, Vector3(0.015, 0.02, 0.09), ciliegio, Vector3(-0.1 + i * 0.05, 0.44, 0.1))
	# la manovella sul fianco
	var perno := _cyl(n, 0.018, 0.018, 0.1, ottone, Vector3(0.23, 0.3, 0))
	perno.rotation.z = PI * 0.5
	_box(n, Vector3(0.03, 0.11, 0.03), ottone, Vector3(0.28, 0.25, 0))
	_ball(n, 0.028, ciliegio, Vector3(0.28, 0.19, 0))
	return n


# la serra: un giardino di vetro col telaio chiaro e il tetto a capanna.
# Dentro, due vasi che sognano l'estate anche a gennaio.
static func _greenhouse() -> Node3D:
	var n := Node3D.new()
	var telaio := _mat(Color("e8e2d2"), Color("cfc8b4"), 4.0, 0.4)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.81, 0.91, 0.96, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color("bfe0f2")
	glass.emission_energy_multiplier = 0.25
	glass.roughness = 0.15
	_box(n, Vector3(1.0, 0.06, 1.0), _mat(STONE, STONE_DARK, 4.0, 0.45), Vector3(0, 0.03, 0))
	# i quattro montanti e le pareti di vetro
	for sx: float in [-0.46, 0.46]:
		for sz: float in [-0.46, 0.46]:
			_box(n, Vector3(0.07, 0.95, 0.07), telaio, Vector3(sx, 0.51, sz))
	_box(n, Vector3(0.92, 0.85, 0.03), glass, Vector3(0, 0.51, -0.46))
	_box(n, Vector3(0.92, 0.85, 0.03), glass, Vector3(0, 0.51, 0.46))
	_box(n, Vector3(0.03, 0.85, 0.92), glass, Vector3(-0.46, 0.51, 0))
	_box(n, Vector3(0.03, 0.85, 0.92), glass, Vector3(0.46, 0.51, 0))
	_box(n, Vector3(1.0, 0.05, 1.0), telaio, Vector3(0, 0.96, 0))
	# il tetto a capanna, due falde di vetro sul colmo
	for lato: float in [-1.0, 1.0]:
		var falda := _box(n, Vector3(1.02, 0.03, 0.62), glass, Vector3(0, 1.17, lato * 0.26))
		falda.rotation.x = lato * 0.56
		var trave := _box(n, Vector3(1.04, 0.05, 0.06), telaio, Vector3(0, 1.17, lato * 0.5))
		trave.rotation.x = lato * 0.56
	_box(n, Vector3(1.06, 0.06, 0.06), telaio, Vector3(0, 1.32, 0))
	# dentro: due vasi col verde che non teme l'inverno
	for sx: float in [-0.22, 0.24]:
		_cyl(n, 0.09, 0.11, 0.14, _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5), Vector3(sx, 0.13, 0.05 * sx * 10.0))
		_ball(n, 0.11, _mat(LEAF, LEAF_DARK, 4.0, 0.5), Vector3(sx, 0.27, 0.05 * sx * 10.0), Vector3(1.0, 0.85, 1.0))
	return n


# la mongolfiera decorativa: pallone a spicchi rosa e crema, cesto di vimini
# e quattro corde. Resta ormeggiata e DONDOLA piano: il respiro glielo dà un
# AnimationPlayer in loop, niente script (i pezzi piazzati sono nodi nudi).
static func _balloon() -> Node3D:
	var n := Node3D.new()
	var vimini := _mat(Color("c9a86a"), Color("a8874c"), 4.0, 0.5)
	# il cesto, con l'orlo e due sacchetti di zavorra
	_box(n, Vector3(0.5, 0.42, 0.5), vimini, Vector3(0, 0.31, 0))
	_box(n, Vector3(0.56, 0.07, 0.56), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.54, 0))
	_ball(n, 0.09, _mat(Color("d9c4a8"), Color("c4ae90"), 3.0, 0.5), Vector3(0.3, 0.2, 0.22), Vector3(1.0, 1.25, 1.0))
	_ball(n, 0.09, _mat(Color("d9c4a8"), Color("c4ae90"), 3.0, 0.5), Vector3(-0.28, 0.2, -0.2), Vector3(1.0, 1.25, 1.0))
	# tutto ciò che dondola sta sotto questo nodo: il pallone e le corde
	var su := Node3D.new()
	su.name = "Pallone"
	n.add_child(su)
	for i in 8:
		var a := float(i) * TAU / 8.0
		var mat := _mat(PINK, PINK_DEEP, 4.0, 0.4) if i % 2 == 0 else _mat(CREAM, Color("f3dfc8"), 4.0, 0.4)
		var spicchio := _ball(su, 0.5, mat, Vector3(0, 2.05, 0), Vector3(0.42, 1.0, 0.95))
		spicchio.rotation.y = a
	_ball(su, 0.5, _mat(Color("f2cf7e"), Color("d9a84a"), 3.0, 0.4), Vector3(0, 1.38, 0), Vector3(0.36, 0.36, 0.36))
	for sx: float in [-0.2, 0.2]:
		for sz: float in [-0.2, 0.2]:
			var corda := _cyl(su, 0.012, 0.012, 0.75, vimini, Vector3(sx, 0.95, sz))
			corda.rotation.z = -sx * 0.35
			corda.rotation.x = sz * 0.35
	# il respiro: su e giù di sei dita, con una punta di rollio
	var anim := Animation.new()
	anim.length = 6.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var tr_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr_pos, NodePath("Pallone:position:y"))
	anim.track_insert_key(tr_pos, 0.0, 0.0)
	anim.track_insert_key(tr_pos, 3.0, 0.12)
	anim.track_insert_key(tr_pos, 6.0, 0.0)
	var tr_rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr_rot, NodePath("Pallone:rotation:z"))
	anim.track_insert_key(tr_rot, 0.0, -0.02)
	anim.track_insert_key(tr_rot, 3.0, 0.02)
	anim.track_insert_key(tr_rot, 6.0, -0.02)
	anim.track_set_interpolation_type(tr_pos, Animation.INTERPOLATION_CUBIC)
	anim.track_set_interpolation_type(tr_rot, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("dondola", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "dondola"
	return n


static func _glow(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


# uno zampillo / scintillio di particelle morbide (fontana, braciere)
static func _emit_fx(parent: Node3D, pos: Vector3, color: Color, up_vel: float, grav: float, amount: int, life: float, size: float) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([color, Color(color, 0.5), Color(color, 0.0)])
	tex.gradient = g
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = up_vel * 0.6
	pm.initial_velocity_max = up_vel
	pm.gravity = Vector3(0, grav, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = pos
	parent.add_child(p)


static func _birdhouse() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	_cyl(n, 0.035, 0.05, 1.05, wood, Vector3(0, 0.52, 0))
	_box(n, Vector3(0.28, 0.3, 0.26), _mat(PLASTER, PLASTER_SHADE, 3.0, 0.45), Vector3(0, 1.18, 0))
	var tile := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	for s: float in [-1.0, 1.0]:
		var r := _box(n, Vector3(0.24, 0.03, 0.32), tile, Vector3(s * 0.08, 1.36, 0))
		r.rotation.z = -s * 0.6
	var hole := _cyl(n, 0.05, 0.05, 0.04, _mat(Color("4a3226"), Color("31201a"), 3.0, 0.4), Vector3(0, 1.18, 0.14))
	hole.rotation.x = PI * 0.5
	var perch := _cyl(n, 0.012, 0.012, 0.12, wood, Vector3(0, 1.1, 0.17))
	perch.rotation.x = PI * 0.5
	return n


static func _streetlamp() -> Node3D:
	var n := Node3D.new()
	var metal := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.14, 0.18, 0.1, metal, Vector3(0, 0.05, 0))
	_cyl(n, 0.035, 0.05, 2.0, metal, Vector3(0, 1.0, 0))
	_box(n, Vector3(0.24, 0.06, 0.24), metal, Vector3(0, 2.02, 0))
	_box(n, Vector3(0.17, 0.2, 0.17), _glow(Color("ffe6b0"), Color("ffd382"), 2.0), Vector3(0, 2.14, 0))
	var cap := _cyl(n, 0.02, 0.14, 0.12, metal, Vector3(0, 2.3, 0))
	cap.name = "cap"
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 1.6
	light.omni_range = 5.5
	light.position = Vector3(0, 2.14, 0)
	n.add_child(light)
	return n


static func _hammock() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for x: float in [-0.42, 0.42]:
		var post := _cyl(n, 0.04, 0.06, 0.9, wood, Vector3(x, 0.45, 0))
		post.rotation.z = -signf(x) * 0.12
	var a := _mat(PINK, PINK_DEEP, 5.0, 0.4)
	var b := _mat(CREAM, Color("f3dfc8"), 5.0, 0.4)
	for i in 9:
		var t := float(i) / 8.0
		var x := -0.36 + t * 0.72
		var dip := 0.44 - 0.16 * sin(PI * t)
		_box(n, Vector3(0.08, 0.02, 0.34), a if i % 2 == 0 else b, Vector3(x, dip, 0))
	return n


static func _swing() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for x: float in [-0.48, 0.48]:
		_cyl(n, 0.035, 0.05, 1.55, wood, Vector3(x, 0.77, 0))
	var bar := _cyl(n, 0.04, 0.04, 1.05, wood, Vector3(0, 1.53, 0))
	bar.rotation.z = PI * 0.5
	var rope := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	for x: float in [-0.16, 0.16]:
		_cyl(n, 0.01, 0.01, 0.95, rope, Vector3(x, 1.05, 0.05))
	_box(n, Vector3(0.44, 0.05, 0.22), _mat(WOOD_PALE, WOOD, 3.0, 0.5), Vector3(0, 0.6, 0.05))
	return n


static func _fountain() -> Node3D:
	var n := Node3D.new()
	var stone := _mat(STONE, STONE_DARK, 3.0, 0.5)
	_cyl(n, 0.46, 0.5, 0.16, stone, Vector3(0, 0.08, 0))
	_cyl(n, 0.42, 0.42, 0.02, stone, Vector3(0, 0.02, 0))
	var water := _glow(Color(0.55, 0.82, 0.95, 0.75), Color(0.4, 0.7, 0.9), 0.15)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(n, 0.42, 0.42, 0.02, water, Vector3(0, 0.14, 0))
	_cyl(n, 0.09, 0.13, 0.36, stone, Vector3(0, 0.32, 0))
	_cyl(n, 0.17, 0.2, 0.05, stone, Vector3(0, 0.5, 0))
	var wtop := _glow(Color(0.6, 0.84, 0.95, 0.8), Color(0.45, 0.72, 0.92), 0.2)
	wtop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(n, 0.15, 0.15, 0.02, wtop, Vector3(0, 0.53, 0))
	_emit_fx(n, Vector3(0, 0.62, 0), Color(0.72, 0.9, 1.0), 1.4, -3.2, 20, 1.0, 0.08)
	return n


static func _gazebo() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	_box(n, Vector3(1.12, 0.08, 1.12), pale, Vector3(0, 0.04, 0))
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			_box(n, Vector3(0.09, 2.1, 0.09), wood, Vector3(sx, 1.05, sz))
	_box(n, Vector3(1.18, 0.08, 1.18), wood, Vector3(0, 2.12, 0))
	var tile := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	for i in 4:
		var a := float(i) * PI * 0.5
		var slope := _box(n, Vector3(1.35, 0.06, 0.72), tile, Vector3(cos(a) * 0.32, 2.4, sin(a) * 0.32))
		slope.rotation.y = a
		slope.rotation.x = -0.72
	_ball(n, 0.1, _mat(Color("f2cf7e"), Color("d9a84a"), 3.0, 0.4), Vector3(0, 2.78, 0))
	return n


static func _carousel() -> Node3D:
	var n := Node3D.new()
	var pole := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.42, 0.44, 0.04, _mat(WOOD_PALE, WOOD, 3.0, 0.4), Vector3(0, 0.03, 0))
	_cyl(n, 0.03, 0.05, 1.5, pole, Vector3(0, 0.77, 0))
	for i in 8:
		var a := float(i) * TAU / 8.0
		var mat := _mat(PINK, PINK_DEEP, 4.0, 0.4) if i % 2 == 0 else _mat(CREAM, Color("f3dfc8"), 4.0, 0.4)
		var stripe := _box(n, Vector3(0.34, 0.04, 0.16), mat, Vector3(cos(a) * 0.22, 1.48, sin(a) * 0.22))
		stripe.rotation.y = a
		stripe.rotation.x = -0.5
	_ball(n, 0.06, _mat(Color("f2cf7e"), Color("d9a84a"), 3.0, 0.4), Vector3(0, 1.6, 0))
	for i in 3:
		var a := float(i) * TAU / 3.0
		var hx := cos(a) * 0.3
		var hz := sin(a) * 0.3
		_cyl(n, 0.008, 0.008, 0.62, pole, Vector3(hx, 0.6, hz))
		_ball(n, 0.075, _mat(CREAM, PINK, 4.0, 0.4), Vector3(hx, 0.42, hz), Vector3(1.5, 0.95, 0.7))
	return n


static func _brazier() -> Node3D:
	var n := Node3D.new()
	var metal := _mat(METAL, Color("5f564c"), 5.0, 0.4)
	_cyl(n, 0.22, 0.13, 0.16, metal, Vector3(0, 0.55, 0))
	_cyl(n, 0.2, 0.2, 0.02, _glow(Color("ff9440"), Color("ff7a26"), 1.8), Vector3(0, 0.6, 0))
	for i in 3:
		var a := (float(i) + 0.5) * TAU / 3.0
		var leg := _cyl(n, 0.015, 0.022, 0.5, metal, Vector3(cos(a) * 0.14, 0.25, sin(a) * 0.14))
		leg.rotation.z = cos(a) * 0.24
		leg.rotation.x = -sin(a) * 0.24
	_emit_fx(n, Vector3(0, 0.66, 0), Color("ffd257"), 0.9, 0.5, 22, 1.1, 0.09)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = 1.7
	light.omni_range = 4.2
	light.position = Vector3(0, 0.72, 0)
	n.add_child(light)
	return n
