extends RefCounted

## Test delle funzioni PURE di CozyWorld (scenes/world/CozyWorld.gd).
## L'istanza viene creata con CW.new() e NON aggiunta all'albero, cosi'
## _ready() (che costruisce tutto il mondo) non parte mai: chiamiamo solo
## funzioni pure e alla fine facciamo w.free().

const CW = preload("res://scenes/world/CozyWorld.gd")


func run(t) -> void:
	var w = CW.new()

	_test_river_x(t, w)
	_test_is_river(t, w)
	_test_cliff_x(t, w)
	_test_catmull(t, w)
	_test_tuft_hash(t, w)
	_test_tuft_vnoise(t, w)
	_test_tuft_field(t, w)
	_test_cone_mesh(t, w)
	_test_cyl_mesh(t, w)
	_test_sphere_mesh(t, w)
	_test_capsule_mesh(t, w)
	_test_paint_mat(t, w)
	_test_soft_circle(t, w)
	_test_merge_empty(t, w)
	_test_procedural_meshes(t, w)

	w.free()


# ------------------------------------------------------------ _river_x

func _test_river_x(t, w) -> void:
	# Determinismo: due chiamate con lo stesso z danno lo stesso valore.
	t.eq(w._river_x(5.0), w._river_x(5.0), "_river_x deterministico per z=5.0")

	# Riproduce esattamente la formula per piu' z (negativi, zero, positivi).
	for z: float in [-30.0, 0.0, 12.0, 40.0]:
		var atteso = 18.6 + sin(z * 0.061) * 1.35 + sin(z * 0.023 + 2.0) * 0.85
		t.almost(w._river_x(z), atteso, "_river_x segue la formula per z=%s" % z)

	# Resta nel range dell'ampiezza: 18.6 +/- (1.35 + 0.85) = [16.4, 20.8].
	for z: float in [-120.0, -56.0, -13.7, 0.0, 7.3, 56.0, 200.0]:
		var v = w._river_x(z)
		t.ok(v >= 16.4 - 0.001 and v <= 20.8 + 0.001,
				"_river_x nel range [16.4, 20.8] per z=%s (v=%s)" % [z, v])


# ------------------------------------------------------------ is_river

func _test_is_river(t, w) -> void:
	# Vero al centro dell'alveo, entro i limiti z.
	t.ok(w.is_river(Vector3(w._river_x(0.0), 0.0, 0.0)),
			"is_river vero al centro del letto (z=0)")

	# Falso se lontano in x (|dx| = 5 >= 2.9).
	t.ok(not w.is_river(Vector3(w._river_x(0.0) + 5.0, 0.0, 0.0)),
			"is_river falso lontano dal centro in x")

	# Falso oltre il limite z superiore (z = 60 non < 56).
	t.ok(not w.is_river(Vector3(w._river_x(60.0), 0.0, 60.0)),
			"is_river falso oltre RIVER_Z_MAX")

	# Falso oltre il limite z inferiore (z = -60 non > -56).
	t.ok(not w.is_river(Vector3(w._river_x(-60.0), 0.0, -60.0)),
			"is_river falso oltre RIVER_Z_MIN")


# ------------------------------------------------------------ _cliff_x

func _test_cliff_x(t, w) -> void:
	# Alla cascata (z = FALL_Z = -4.0) lo smoothstep vale 0.
	t.almost(w._cliff_x(-4.0), w._river_x(-4.0) + 2.9,
			"_cliff_x alla cascata: solo river_x + 2.9")

	# Lontano dalla cascata (|z - (-4)| = 14 >= 9) lo smoothstep satura a 1.
	t.almost(w._cliff_x(10.0), w._river_x(10.0) + 2.9 + 9.0,
			"_cliff_x lontano dalla cascata: river_x + 2.9 + 9.0")

	# Limiti per ogni z: river_x+2.9 <= cliff_x <= river_x+2.9+9.0.
	# E la parete e' sempre a est del centro fiume: cliff_x > river_x.
	for z: float in [-56.0, -20.0, -4.0, 0.0, 3.0, 22.0, 56.0]:
		var base = w._river_x(z) + 2.9
		var c = w._cliff_x(z)
		t.ok(c >= base - 0.0001 and c <= base + 9.0 + 0.0001,
				"_cliff_x nei limiti dello smoothstep per z=%s (c=%s)" % [z, c])
		t.ok(c > w._river_x(z), "_cliff_x a est del centro fiume per z=%s" % z)

	# Determinismo.
	t.eq(w._cliff_x(3.0), w._cliff_x(3.0), "_cliff_x deterministico per z=3.0")


# ------------------------------------------------------------ _catmull

func _test_catmull(t, w) -> void:
	var a = Vector3(0.0, 0.0, 0.0)
	var b = Vector3(1.0, 2.0, -1.0)
	var c = Vector3(3.0, -1.0, 2.0)
	var d = Vector3(4.0, 4.0, 4.0)

	# A t=0 restituisce esattamente p1.
	t.ok(w._catmull(a, b, c, d, 0.0).is_equal_approx(b),
			"_catmull(t=0) == p1")

	# A t=1 restituisce esattamente p2.
	t.ok(w._catmull(a, b, c, d, 1.0).is_equal_approx(c),
			"_catmull(t=1) == p2")

	# Determinismo: stessi input danno lo stesso Vector3.
	t.ok(w._catmull(a, b, c, d, 0.37).is_equal_approx(w._catmull(a, b, c, d, 0.37)),
			"_catmull deterministico per t=0.37")


# ------------------------------------------------------------ _tuft_hash

func _test_tuft_hash(t, w) -> void:
	# Sempre nel range [0,1] (0xfffff / 1048575.0 = 1.0 e' il massimo).
	for coppia in [[0, 0], [3, 7], [-5, 2], [123, -456], [-999, -999]]:
		var v = w._tuft_hash(coppia[0], coppia[1])
		t.ok(v >= 0.0 and v <= 1.0,
				"_tuft_hash in [0,1] per (%s,%s) -> %s" % [coppia[0], coppia[1], v])

	# Determinismo.
	t.eq(w._tuft_hash(3, 7), w._tuft_hash(3, 7), "_tuft_hash deterministico (3,7)")
	t.eq(w._tuft_hash(-5, 2), w._tuft_hash(-5, 2), "_tuft_hash deterministico (-5,2)")


# ----------------------------------------------------------- _tuft_vnoise

func _test_tuft_vnoise(t, w) -> void:
	# Sempre nel range [0,1]: interpolazione bilineare (pesi in [0,1]) di
	# valori _tuft_hash gia' in [0,1].
	for p in [[0.0, 0.0], [2.3, -4.1], [-7.6, 5.5], [12.25, 12.25], [-0.5, -0.5]]:
		var v = w._tuft_vnoise(p[0], p[1])
		t.ok(v >= -0.0001 and v <= 1.0001,
				"_tuft_vnoise in [0,1] per (%s,%s) -> %s" % [p[0], p[1], v])

	# Determinismo.
	t.almost(w._tuft_vnoise(2.3, -4.1), w._tuft_vnoise(2.3, -4.1),
			"_tuft_vnoise deterministico")


# ----------------------------------------------------------- _tuft_field

func _test_tuft_field(t, w) -> void:
	# Sempre nel range [0,1]: 0.65 + 0.35 = 1 su due vnoise ciascuno in [0,1].
	for p in [[0.0, 0.0], [1.0, 1.0], [-8.3, 6.4], [15.0, -18.0], [-3.3, -3.3]]:
		var v = w._tuft_field(p[0], p[1])
		t.ok(v >= -0.0001 and v <= 1.0001,
				"_tuft_field in [0,1] per (%s,%s) -> %s" % [p[0], p[1], v])

	# Determinismo.
	t.almost(w._tuft_field(1.0, 1.0), w._tuft_field(1.0, 1.0),
			"_tuft_field deterministico")


# ------------------------------------------------------------ _cone_mesh

func _test_cone_mesh(t, w) -> void:
	var m: CylinderMesh = w._cone_mesh(0.5, 1.2, 8)
	t.almost(m.top_radius, 0.0, "_cone_mesh top_radius = 0 (cono)")
	t.almost(m.bottom_radius, 0.5, "_cone_mesh bottom_radius = radius passato")
	t.almost(m.height, 1.2, "_cone_mesh height = height passato")
	t.eq(m.radial_segments, 8, "_cone_mesh radial_segments = segments passato")


# ------------------------------------------------------------- _cyl_mesh

func _test_cyl_mesh(t, w) -> void:
	var m: CylinderMesh = w._cyl_mesh(0.1, 0.2, 0.5, 6)
	t.almost(m.top_radius, 0.1, "_cyl_mesh top_radius = top passato")
	t.almost(m.bottom_radius, 0.2, "_cyl_mesh bottom_radius = bottom passato")
	t.almost(m.height, 0.5, "_cyl_mesh height = height passato")
	t.eq(m.radial_segments, 6, "_cyl_mesh radial_segments = segments passato")


# ----------------------------------------------------------- _sphere_mesh

func _test_sphere_mesh(t, w) -> void:
	var m: SphereMesh = w._sphere_mesh(0.3, 12)
	t.almost(m.radius, 0.3, "_sphere_mesh radius = radius passato")
	t.almost(m.height, 0.6, "_sphere_mesh height = radius * 2")
	t.eq(m.radial_segments, 12, "_sphere_mesh radial_segments = segments passato")
	t.eq(m.rings, 6, "_sphere_mesh rings = int(12 * 0.5) = 6")

	# rings = int(segments * 0.5): 4 per segments = 8.
	var m2: SphereMesh = w._sphere_mesh(1.0, 8)
	t.eq(m2.rings, 4, "_sphere_mesh rings = int(8 * 0.5) = 4")


# ---------------------------------------------------------- _capsule_mesh

func _test_capsule_mesh(t, w) -> void:
	# h >= 2*r evita il clamp interno di Godot (0.1 * 2 = 0.2 <= 1.0).
	var m: CapsuleMesh = w._capsule_mesh(0.1, 1.0)
	t.almost(m.radius, 0.1, "_capsule_mesh radius = r passato")
	t.almost(m.height, 1.0, "_capsule_mesh height = h passato (nessun clamp)")


# ------------------------------------------------------------ _paint_mat

func _test_paint_mat(t, w) -> void:
	# Assegna lo shader e mappa color_a/color_b agli argomenti.
	var mat: ShaderMaterial = w._paint_mat(Color(1, 0, 0), Color(0, 1, 0))
	t.ok(mat.shader != null, "_paint_mat assegna lo shader HANDPAINT")
	t.ok(mat.get_shader_parameter("color_a") == Color(1, 0, 0),
			"_paint_mat color_a = argomento a")
	t.ok(mat.get_shader_parameter("color_b") == Color(0, 1, 0),
			"_paint_mat color_b = argomento b")

	# I parametri float di default: grain=4.0, amount=0.45, wind=0.0.
	t.almost(mat.get_shader_parameter("noise_scale"), 4.0,
			"_paint_mat noise_scale = grain")
	t.almost(mat.get_shader_parameter("noise_amount"), 0.45,
			"_paint_mat noise_amount = amount")
	t.almost(mat.get_shader_parameter("wind_strength"), 0.0,
			"_paint_mat wind_strength = wind")

	# use_world_noise mappato dal booleano passato.
	var mat2: ShaderMaterial = w._paint_mat(Color(1, 1, 1), Color(1, 1, 1),
			4.0, 0.45, 0.0, true)
	t.eq(mat2.get_shader_parameter("use_world_noise"), true,
			"_paint_mat use_world_noise = world_noise")

	# translucency impostato solo se trans > 0.
	var mat3: ShaderMaterial = w._paint_mat(Color(1, 1, 1), Color(1, 1, 1),
			4.0, 0.45, 0.0, false, 0.5)
	t.almost(mat3.get_shader_parameter("translucency"), 0.5,
			"_paint_mat translucency = trans (quando > 0)")


# ---------------------------------------------------------- _soft_circle

func _test_soft_circle(t, w) -> void:
	var tex: GradientTexture2D = w._soft_circle(Color(1, 1, 1), 0.5)
	t.eq(tex.width, 64, "_soft_circle width = 64")
	t.eq(tex.height, 64, "_soft_circle height = 64")
	t.eq(tex.fill, GradientTexture2D.FILL_RADIAL, "_soft_circle fill radiale")
	t.almost(tex.gradient.offsets[1], 0.5,
			"_soft_circle offset centrale del gradiente = edge")
	t.ok(tex.gradient.colors[0] == Color(1, 1, 1),
			"_soft_circle primo colore del gradiente = color")


# -------------------------------------------------------------- _merge

func _test_merge_empty(t, w) -> void:
	# Con lista vuota: ArrayMesh senza superfici.
	var m: ArrayMesh = w._merge([])
	t.eq(m.get_surface_count(), 0, "_merge([]) senza superfici")


# ------------------------------------------ costruttori di mesh procedurali

func _test_procedural_meshes(t, w) -> void:
	# _blade_mesh(): esattamente 1 superficie.
	t.eq(w._blade_mesh().get_surface_count(), 1,
			"_blade_mesh -> 1 superficie")

	# _puff_mesh(0.9, 42): 1 superficie e deterministico per seme fisso.
	t.eq(w._puff_mesh(0.9, 42).get_surface_count(), 1,
			"_puff_mesh -> 1 superficie")
	t.ok(w._puff_mesh(0.9, 42).get_faces() == w._puff_mesh(0.9, 42).get_faces(),
			"_puff_mesh deterministico per seme fisso")

	# _trunk_mesh(1.5, 0.2, 0.1, 7): 1 superficie e deterministico.
	t.eq(w._trunk_mesh(1.5, 0.2, 0.1, 7).get_surface_count(), 1,
			"_trunk_mesh -> 1 superficie")
	t.ok(w._trunk_mesh(1.5, 0.2, 0.1, 7).get_faces()
			== w._trunk_mesh(1.5, 0.2, 0.1, 7).get_faces(),
			"_trunk_mesh deterministico per seme fisso")

	# _skirt_mesh(1.2, 1.0, 3): 1 superficie e deterministico.
	t.eq(w._skirt_mesh(1.2, 1.0, 3).get_surface_count(), 1,
			"_skirt_mesh -> 1 superficie")
	t.ok(w._skirt_mesh(1.2, 1.0, 3).get_faces()
			== w._skirt_mesh(1.2, 1.0, 3).get_faces(),
			"_skirt_mesh deterministico per seme fisso")
