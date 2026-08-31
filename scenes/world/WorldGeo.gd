extends RefCounted
## Fabbriche di geometria di Chibi Crossing: mesh procedurali (tronchi, chiome,
## fiori, fili d'erba), materiali dipinti a mano, texture morbide ed emettitori
## di particelle alla deriva.
##
## Tutte funzioni `static`, senza stato e senza albero della scena: si usano come
## `WorldGeo.cone_mesh(...)` previo `const GEO := preload(...)`.
## Estratte da CozyWorld.gd per alleggerirlo.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")


static func paint_mat(a: Color, b: Color, grain := 4.0, amount := 0.45, wind := 0.0,
		world_noise := false, trans := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	mat.set_shader_parameter("wind_strength", wind)
	mat.set_shader_parameter("use_world_noise", world_noise)
	if trans > 0.0:
		mat.set_shader_parameter("translucency", trans)
	return mat

# il filo d'erba vero: un nastro affusolato che si incurva in avanti,
# UV.y = altezza (lo shader ci appende gradienti, vento e spinte)
static func blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# livelli: [altezza, mezza larghezza, curva in avanti]
	var lv := [[0.0, 0.017, 0.0], [0.12, 0.013, 0.012],
			[0.22, 0.008, 0.038], [0.30, 0.0, 0.085]]
	for s in 3:
		var a: Array = lv[s]
		var b: Array = lv[s + 1]
		var auv := float(a[0]) / 0.30
		var buv := float(b[0]) / 0.30
		var al := Vector3(-a[1], a[0], a[2])
		var ar := Vector3(a[1], a[0], a[2])
		if float(b[1]) > 0.0:
			var bl := Vector3(-b[1], b[0], b[2])
			var br := Vector3(b[1], b[0], b[2])
			for v: Array in [[al, auv], [bl, buv], [ar, auv],
					[ar, auv], [bl, buv], [br, buv]]:
				st.set_uv(Vector2(0.0, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
		else:
			var tip := Vector3(0, b[0], b[2])
			for v: Array in [[al, auv], [tip, 1.0], [ar, auv]]:
				st.set_uv(Vector2(0.0, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()

# il gambo comune: stelo con una lieve curva naturale + due foglioline
# basali lanceolate. Ogni specie ci appoggia sopra la sua corolla.
static func flower_base(mesh: ArrayMesh, h: float, leaf_s := 1.0) -> void:
	var green := paint_mat(Color("7fae6a"), Color("5f9050"), 6.0, 0.5, 0.02, true)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# stelo in due segmenti, il secondo piegato appena: mai un palo dritto
	var low := cyl_mesh(0.011, 0.013, h * 0.55, 6)
	var high := cyl_mesh(0.009, 0.011, h * 0.5, 6)
	st.append_from(low, 0, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.275, 0)))
	st.append_from(high, 0, Transform3D(
			Basis(Vector3.RIGHT, 0.12), Vector3(0, h * 0.76, -h * 0.03)))
	# foglie: ellissoidi lunghi e sottili, inclinati verso l'alto
	var leaf := sphere_mesh(0.05, 8)
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3.UP, side * 1.2 + 0.4) \
				* Basis(Vector3.RIGHT, -0.55) \
				* Basis.IDENTITY.scaled(Vector3(0.42, 0.14, 1.5) * leaf_s)
		st.append_from(leaf, 0, Transform3D(b, Vector3(side * 0.03, h * 0.16, 0.015)))
	st.set_material(green)
	st.commit(mesh)

## La margherita: doppia corona di petali veri (8 sotto + 5 sopra,
## ruotati e appena rialzati) attorno al bottone dorato bombato.
static func daisy_mesh(petal_color: Color, center_color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	flower_base(mesh, 0.20)

	var pet_mat := paint_mat(petal_color, petal_color.lightened(0.22), 2.2, 0.5, 0.02, true, 0.5)
	var petal := sphere_mesh(0.034, 8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# corona bassa: 8 petali lunghi, appena conici verso l'alto
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.22) \
				* Basis.IDENTITY.scaled(Vector3(0.62, 0.22, 1.75))
		st.append_from(petal, 0, Transform3D(b,
				Vector3(cos(a) * 0.055, 0.205, sin(a) * 0.055)))
	# corona alta: 5 petali più corti, sfalsati, più alzati
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.63
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.5) \
				* Basis.IDENTITY.scaled(Vector3(0.55, 0.2, 1.3))
		st.append_from(petal, 0, Transform3D(b,
				Vector3(cos(a) * 0.038, 0.218, sin(a) * 0.038)))
	st.set_material(pet_mat)
	st.commit(mesh)

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(sphere_mesh(0.03, 10), 0, Transform3D(
			Basis.IDENTITY.scaled(Vector3(1, 0.62, 1)), Vector3(0, 0.225, 0)))
	st.set_material(paint_mat(center_color, center_color.darkened(0.25), 9.0, 0.55))
	st.commit(mesh)
	return mesh

## Il tulipano: sei petali verticali chiusi a coppa su uno stelo alto,
## con la foglia lunga avvolgente tipica.
static func tulip_mesh(cup_color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	flower_base(mesh, 0.26, 1.25)

	var pet_mat := paint_mat(cup_color, cup_color.lightened(0.18), 2.0, 0.45, 0.02, true, 0.55)
	var petal := sphere_mesh(0.045, 8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		# petali dritti che si stringono in alto: la silhouette a uovo
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.16) \
				* Basis.IDENTITY.scaled(Vector3(0.72, 1.35, 0.4))
		st.append_from(petal, 0, Transform3D(b,
				Vector3(cos(a) * 0.026, 0.315, sin(a) * 0.026)))
	st.set_material(pet_mat)
	st.commit(mesh)

	# il cuoricino scuro appena visibile dentro la coppa
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(sphere_mesh(0.02, 8), 0, Transform3D(
			Basis.IDENTITY, Vector3(0, 0.31, 0)))
	st.set_material(paint_mat(cup_color.darkened(0.4), cup_color.darkened(0.55), 6.0, 0.4))
	st.commit(mesh)
	return mesh

## La lavanda: spiga di campanellini viola sfalsati su uno stelo slanciato.
static func lavender_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	flower_base(mesh, 0.30, 0.8)

	var bud_mat := paint_mat(Color("a98fd8"), Color("8f6fc4"), 2.5, 0.5, 0.025, true, 0.45)
	var bud := sphere_mesh(0.026, 8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var t := float(i) / 6.0
		var a := t * 5.2  # i campanellini salgono a spirale
		var y := 0.24 + t * 0.11
		var r := 0.018 * (1.0 - t * 0.45)
		var b := Basis(Vector3.UP, -a) \
				* Basis.IDENTITY.scaled(Vector3(1.15, 0.85, 1.15) * (1.0 - t * 0.35))
		st.append_from(bud, 0, Transform3D(b, Vector3(cos(a) * r, y, sin(a) * r)))
	# la puntina in cima
	st.append_from(bud, 0, Transform3D(
			Basis.IDENTITY.scaled(Vector3(0.6, 0.9, 0.6)), Vector3(0, 0.365, 0)))
	st.set_material(bud_mat)
	st.commit(mesh)
	return mesh

static func soft_circle(color: Color, edge := 0.6) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, edge, 1.0])
	grad.colors = PackedColorArray([color, Color(color, color.a * 0.55), Color(color, 0.0)])
	tex.gradient = grad
	return tex

static func merge(parts: Array) -> ArrayMesh:
	# [[Mesh, Transform3D, Material], ...] -> ArrayMesh con una superficie
	# per materiale
	var groups := {}
	for p in parts:
		var mat: Material = p[2]
		if not groups.has(mat):
			groups[mat] = []
		(groups[mat] as Array).append(p)
	var mesh := ArrayMesh.new()
	for mat in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in groups[mat]:
			st.append_from(p[0], 0, p[1])
		st.set_material(mat)
		st.commit(mesh)
	return mesh

static func cone_mesh(radius: float, height: float, segments := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	return m

static func cyl_mesh(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m

static func sphere_mesh(radius: float, segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = int(segments * 0.5)
	return m

# normali morbide di una griglia di anelli chiusi: tangente lungo
# l'anello × tangente lungo la colonna (differenze centrali; ai bordi
# one-sided). Le righe degenerate (poli, punte) ricadono sulla verticale.
static func grid_normals(pos: Array, segs: int) -> Array:
	var rows := pos.size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		var below: Array = pos[maxi(i - 1, 0)]
		var above: Array = pos[mini(i + 1, rows - 1)]
		for j in segs:
			var t_lon: Vector3 = pos[i][(j + 1) % segs] - pos[i][(j - 1 + segs) % segs]
			var t_lat: Vector3 = above[j] - below[j]
			var n := t_lon.cross(t_lat)
			if n.length_squared() < 0.0000001:
				# riga degenere (polo in basso, polo/punta in alto)
				nrow.append(Vector3.DOWN if i == 0 else Vector3.UP)
				continue
			nrow.append(n.normalized())
		out.append(nrow)
	return out

# griglia + normali -> mesh (due triangoli per quad, facce esterne)
static func grid_commit(pos: Array, nrm: Array, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pos.size() - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			for idx: Array in [[i, j], [i + 1, j], [i + 1, j2],
					[i, j], [i + 1, j2], [i, j2]]:
				st.set_normal(nrm[idx[0]][idx[1]])
				st.add_vertex(pos[idx[0]][idx[1]])
	return st.commit()

# nuvola soffice: sfera schiacciata con gonfiori pseudo-noise coerenti.
# Le normali vere dei gonfiori vengono ammorbidite verso quelle
# dell'ellissoide liscio (il trucco dello stylized foliage): i lobi si
# leggono, ma l'ombra resta rotonda come un cuscino — mai accartocciata.
static func puff_mesh(r: float, seed_v: int, squash := 0.82, lump := 0.09,
		segs := 12, rings := 7, detail := 0.5) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var v1 := Vector3(rng.randf_range(1.6, 3.0), rng.randf_range(1.6, 3.0),
			rng.randf_range(1.6, 3.0))
	var v2 := Vector3(rng.randf_range(2.2, 4.2), rng.randf_range(2.2, 4.2),
			rng.randf_range(2.2, 4.2))
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU

	var pos: Array = []
	var soft: Array = []  # la normale dell'ellissoide liscio, per il blend
	for i in rings + 1:
		var lat := float(i) / float(rings) * PI - PI * 0.5  # -90° (sotto) -> +90°
		var prow: Array[Vector3] = []
		var srow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			var d := Vector3(cos(lat) * cos(lon), sin(lat), -cos(lat) * sin(lon))
			var k := 1.0 + lump * sin(d.dot(v1) * 2.2 + ph1) \
					* cos(d.dot(v2) * 1.7 + ph2)
			prow.append(Vector3(d.x, d.y * squash, d.z) * r * k)
			# normale esatta dell'ellissoide (1, squash, 1): scala inversa
			srow.append(Vector3(d.x, d.y / squash, d.z).normalized())
		pos.append(prow)
		soft.append(srow)

	var nrm := grid_normals(pos, segs)
	for i in nrm.size():
		for j in segs:
			nrm[i][j] = (soft[i][j].lerp(nrm[i][j], detail)).normalized()
	return grid_commit(pos, nrm, segs)

# tronco vero: svasato alla base, affusolato in cima, corteccia
# irregolare e una lieve inclinazione — con le normali che seguono
# davvero gobbe e svasatura (la luce radente rivela la corteccia)
static func trunk_mesh(h: float, rb: float, rt: float, seed_v: int,
		bend := 0.07, segs := 10) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	var kink := rng.randf_range(2.0, 3.4)
	var lean := Vector2(cos(ph), sin(ph)) * bend * h

	var ts := [0.0, 0.05, 0.14, 0.32, 0.58, 0.82, 1.0]
	var pos: Array = []
	for i in ts.size():
		var t: float = ts[i]
		var prow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			# affusolamento + svasatura delle radici alla base
			var r := lerpf(rb, rt, pow(t, 0.85)) * (1.0 + 1.1 * pow(1.0 - t, 7.0))
			# corteccia: gobbe radiali che ruotano piano salendo
			r *= 1.0 + 0.055 * sin(lon * 3.0 + t * kink + ph) \
					+ 0.03 * sin(lon * 7.0 - t * 2.0)
			var c := Vector3(lean.x * t * t, t * h, lean.y * t * t)
			prow.append(c + Vector3(cos(lon) * r, 0, -sin(lon) * r))
		pos.append(prow)
	return grid_commit(pos, grid_normals(pos, segs), segs)

# la gonna di un pino: cono con l'orlo smerlato che ricade. Le normali
# vere fanno prendere luce a ogni smerlo: la fronda si accende onda
# per onda invece di essere un cono uniforme.
static func skirt_mesh(r: float, h: float, seed_v: int, droop := 0.14,
		waves := 7, segs := 16) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	# profili bottom→top: [frazione raggio, quota]
	var prof := [[1.0, 0.0], [0.72, h * 0.2], [0.38, h * 0.55], [0.0, h]]
	var pos: Array = []
	for i in prof.size():
		var prow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			var rr: float = r * float(prof[i][0])
			var y: float = prof[i][1]
			if i == 0:
				# l'orlo: onde che scendono e rientrano appena
				var w := sin(lon * waves + ph)
				y -= droop * r * (0.55 + 0.45 * w)
				rr *= 1.0 + 0.05 * sin(lon * waves + ph + 1.3)
			prow.append(Vector3(cos(lon) * rr, y, -sin(lon) * rr))
		pos.append(prow)
	return grid_commit(pos, grid_normals(pos, segs), segs)

static func capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m

static func strip_normals(pos: Array) -> Array:
	var rows := pos.size()
	var cols: int = (pos[0] as Array).size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		for j in cols:
			var t_row: Vector3 = pos[mini(i + 1, rows - 1)][j] - pos[maxi(i - 1, 0)][j]
			var t_col: Vector3 = pos[i][mini(j + 1, cols - 1)] - pos[i][maxi(j - 1, 0)]
			var n := t_row.cross(t_col)
			nrow.append(n.normalized() if n.length_squared() > 0.000001 else Vector3.UP)
		out.append(nrow)
	return out

# il colore-bersaglio di una chioma, data la sua tinta di primavera e la
# stagione. Il valore (luminosità) si conserva quasi sempre: così i tre
# strati scuro/medio/chiaro della nuvola restano leggibili anche d'autunno
static func leaf_target(c: Color, klass: String, season: int) -> Color:
	match season:
		0:  # primavera: il colore di nascita
			return c
		1:  # estate: verdi più profondi e ricchi (il ciliegio rinverdisce)
			if klass == "cherry":
				return Color.from_hsv(0.28, 0.52, clampf(c.v * 0.9, 0.22, 0.95))
			if klass == "needle":
				return Color.from_hsv(c.h, minf(c.s * 1.06, 1.0), c.v * 0.96)
			return Color.from_hsv(c.h, minf(c.s * 1.12, 1.0), c.v * 0.93)
		2:  # autunno: oro, rame, cremisi — ma le conifere restano verdi
			if klass == "needle":
				return Color.from_hsv(fposmod(c.h - 0.01, 1.0), c.s * 0.95, c.v * 0.97)
			if klass == "cherry":
				# ⚠️ LA TINTA E' UN CERCHIO, E QUI SI FACEVA IL GIRO LUNGO.
				# L'intento e' scritto due righe sopra — «oro, rame,
				# cremisi» — cioe' cremisi (0.98) per gli strati scuri e
				# oro (0.07) per quelli chiari: sono NOVE CENTESIMI di
				# ruota passando per lo zero. Interpolando da 0.98 a 0.07
				# in linea retta se ne percorrono NOVANTUNO, dalla parte
				# sbagliata: si attraversa il blu (0.6), il ciano (0.5) e
				# il VERDE (0.3). MISURATO sul ciliegio vero: lo strato
				# scuro (v = 0.749) usciva a tinta 0.298, cioe' `#6ec257`
				# — un ciliegio d'autunno con la gonna d'ombra VERDE
				# addosso, sotto due strati arancioni.
				# Il file lo sapeva gia': le conifere, qui sotto, girano
				# con `fposmod`. Questa riga se l'era dimenticato.
				return Color.from_hsv(fposmod(lerpf(-0.02, 0.07,
						clampf(c.v, 0.0, 1.0)), 1.0), 0.55,
						clampf(c.v * 0.95 + 0.05, 0.0, 1.0))
			return Color.from_hsv(lerpf(0.03, 0.10, clampf(c.v, 0.0, 1.0)), 0.72,
					clampf(c.v * 1.02 + 0.05, 0.0, 1.0))
		_:  # inverno: brina e dormienza (la neve globale imbianca il resto)
			if klass == "needle":
				return Color.from_hsv(fposmod(c.h + 0.01, 1.0), c.s * 0.9, c.v * 0.82)
			return Color.from_hsv(0.09, 0.14, clampf(c.v * 0.72 + 0.14, 0.0, 1.0))

# fabbrica di emettitori "che scendono dal cielo": neve o foglie
static func drift_emitter(tex: Texture2D, count: int, sz: float, box: Vector3,
		grav: Vector3, life: float, spin_slow: bool) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(sz, sz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.55
	pm.gravity = grav
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7 if spin_slow else 0.4
	pm.turbulence_noise_speed = Vector3(0.25, 0.15, 0.25)
	pm.scale_min = 0.6
	pm.scale_max = 1.25
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -40.0 if spin_slow else -140.0
	pm.angular_velocity_max = 40.0 if spin_slow else 140.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.88, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var fx := GPUParticles3D.new()
	fx.amount = count
	fx.lifetime = life
	fx.preprocess = life * 0.7
	fx.local_coords = false
	fx.emitting = false
	fx.process_material = pm
	fx.draw_pass_1 = quad
	fx.visibility_aabb = AABB(Vector3(-16, -12, -16), Vector3(32, 18, 32))
	return fx


## IL DISCO D'ACQUA: una griglia POLARE (anelli × spicchi) invece del
## cappello a ventaglio del CylinderMesh — che ha un solo vertice al
## centro e nessuna suddivisione radiale, quindi qualunque onda sui
## vertici gli faceva fare solo il cono. Qui i vertici ci sono davvero:
## le onde capillari hanno dove vivere.
##
## Gli anelli si INFITTISCONO verso la riva (dove l'occhio guarda di
## striscio e le increspature contano di più): il raggio va come
## `t^stretta` con **stretta < 1**, quindi i passi si accorciano verso
## il bordo. Con un esponente > 1 succederebbe l'esatto contrario.
##
## UV: x = raggio normalizzato (0 centro, 1 riva), y = angolo/TAU —
## così lo shader sa sempre quanto è vicino alla sponda. L'angolo NON
## è preso modulo: l'ultimo spicchio va da 63/64 a 1.0, che è lo stesso
## punto di 0.0 per cos/sin ma non fa tornare indietro la UV (sarebbe
## una cucitura visibile in ogni funzione periodica dell'angolo).
static func disco_acqua(raggio: float, anelli := 14, spicchi := 64,
		stretta := 0.75) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var punto := func(ia: int, isp: int) -> void:
		var fr := pow(float(ia) / float(anelli), stretta)
		var giro := float(isp) / float(spicchi)
		var ang := TAU * giro
		st.set_uv(Vector2(fr, giro))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(ang) * fr * raggio, 0.0, sin(ang) * fr * raggio))
	for ia in anelli:
		for isp in spicchi:
			if ia == 0:
				# il cuore: un ventaglio di triangoli sul centro
				punto.call(0, 0)
				punto.call(1, isp)
				punto.call(1, isp + 1)
			else:
				punto.call(ia, isp)
				punto.call(ia + 1, isp)
				punto.call(ia + 1, isp + 1)
				punto.call(ia, isp)
				punto.call(ia + 1, isp + 1)
				punto.call(ia, isp + 1)
	return st.commit()
