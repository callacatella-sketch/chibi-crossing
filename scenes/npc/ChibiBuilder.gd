class_name ChibiBuilder
extends RefCounted

## Dal DNA al chibi: costruzione deterministica di un villager nello
## stile di Mochi ma sempre diverso. Niente catene di sfere: le code
## sono veri tubi rastremati spazzati lungo una Catmull-Rom (con punta
## chiara e uno snodo per il colpo di frusta), il vestitino è una
## superficie di rivoluzione a pera con l'orlo arrotondato, e ogni
## archetipo ha musetto, nasino, orecchie e coda suoi: gatto, coniglietta,
## orsetto, volpina, topolino. Restituisce le parti animabili.
## Convenzione: la faccia guarda verso -Z.

const TOON := preload("res://shaders/toon.gdshader")
const FACE := preload("res://scenes/characters/FaceController.gd")

## Profilo del vestitino (raggio, altezza), dall'orlo alla spalla.
## Il primo punto è il sotto-orlo interno: chiude la gonna da sotto.
const DRESS_PROFILE := [
	Vector2(0.22, 0.185),
	Vector2(0.315, 0.145),
	Vector2(0.335, 0.19),
	Vector2(0.318, 0.25),
	Vector2(0.288, 0.34),
	Vector2(0.252, 0.46),
	Vector2(0.212, 0.58),
	Vector2(0.165, 0.69),
	Vector2(0.10, 0.78),
	Vector2(0.0, 0.825),
]


static func _mat(color: Color, fur := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo_color", color)
	if fur > 0.0:
		m.set_shader_parameter("fur_noise", fur)
	return m


static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# ---------------------------------------------------------- primitive morbide

static func cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Un tubo morbido spazzato lungo la Catmull-Rom dei punti di controllo,
## col raggio che si rastrema da un controllo all'altro. Frame trasportati
## in parallelo (niente torsioni), normali che seguono la rastremazione,
## tappi alle estremità. È la spina dorsale di code, orecchie e musetti.
static func tube(parent: Node3D, pts: Array, radii: Array, mat: Material,
		samples := 20, sides := 12) -> MeshInstance3D:
	var n := pts.size()
	var centers: Array[Vector3] = []
	var rads: Array[float] = []
	for i in samples + 1:
		var u := float(i) / float(samples) * float(n - 1)
		var seg := clampi(int(u), 0, n - 2)
		var t := u - float(seg)
		centers.append(cr(pts[maxi(seg - 1, 0)], pts[seg],
				pts[seg + 1], pts[mini(seg + 2, n - 1)], t))
		rads.append(lerpf(float(radii[seg]), float(radii[seg + 1]),
				smoothstep(0.0, 1.0, t)))

	var count := centers.size()
	var tans: Array[Vector3] = []
	for i in count:
		tans.append((centers[mini(i + 1, count - 1)] \
				- centers[maxi(i - 1, 0)]).normalized())
	var nrm := Vector3.RIGHT
	if absf(tans[0].dot(nrm)) > 0.9:
		nrm = Vector3.UP
	nrm = (nrm - tans[0] * nrm.dot(tans[0])).normalized()

	var verts := []
	var norms := []
	for i in count:
		if i > 0:
			var axis := tans[i - 1].cross(tans[i])
			var l := axis.length()
			if l > 0.0001:
				nrm = nrm.rotated(axis / l, tans[i - 1].angle_to(tans[i]))
		var bin := tans[i].cross(nrm).normalized()
		var prev_i := maxi(i - 1, 0)
		var next_i := mini(i + 1, count - 1)
		var ds := centers[next_i].distance_to(centers[prev_i])
		var slope := 0.0 if ds < 0.0001 else (rads[next_i] - rads[prev_i]) / ds
		var ring_v: Array[Vector3] = []
		var ring_n: Array[Vector3] = []
		for j in sides:
			var a := float(j) / float(sides) * TAU
			var dirv := nrm * cos(a) + bin * sin(a)
			ring_v.append(centers[i] + dirv * rads[i])
			ring_n.append((dirv - tans[i] * slope).normalized())
		verts.append(ring_v)
		norms.append(ring_n)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count - 1:
		for j in sides:
			var j2 := (j + 1) % sides
			st.set_normal(norms[i][j])
			st.add_vertex(verts[i][j])
			st.set_normal(norms[i + 1][j])
			st.add_vertex(verts[i + 1][j])
			st.set_normal(norms[i + 1][j2])
			st.add_vertex(verts[i + 1][j2])
			st.set_normal(norms[i][j])
			st.add_vertex(verts[i][j])
			st.set_normal(norms[i + 1][j2])
			st.add_vertex(verts[i + 1][j2])
			st.set_normal(norms[i][j2])
			st.add_vertex(verts[i][j2])
	# tappi
	for j in sides:
		var j2 := (j + 1) % sides
		st.set_normal(-tans[0])
		st.add_vertex(centers[0])
		st.set_normal(-tans[0])
		st.add_vertex(verts[0][j])
		st.set_normal(-tans[0])
		st.add_vertex(verts[0][j2])
		st.set_normal(tans[count - 1])
		st.add_vertex(centers[count - 1])
		st.set_normal(tans[count - 1])
		st.add_vertex(verts[count - 1][j2])
		st.set_normal(tans[count - 1])
		st.add_vertex(verts[count - 1][j])

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Superficie di rivoluzione attorno all'asse Y: il profilo è una lista
## di (raggio, altezza) dal basso verso l'alto. Un solo pezzo continuo
## per il vestitino a pera, con normali morbide e il fondo chiuso.
static func lathe(parent: Node3D, profile: Array, mat: Material,
		pos := Vector3.ZERO, sides := 30, scale_r := 1.0, scale_y := 1.0) -> MeshInstance3D:
	var n := profile.size()
	var pr: Array[Vector2] = []
	for p in profile:
		pr.append(Vector2(p.x * scale_r, p.y * scale_y))

	# normali 2D dal profilo (dr, dy) -> (dy, -dr)
	var n2: Array[Vector2] = []
	for i in n:
		var d: Vector2 = (pr[mini(i + 1, n - 1)] - pr[maxi(i - 1, 0)]).normalized()
		n2.append(Vector2(d.y, -d.x).normalized())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := func(i: int, j: int) -> Vector3:
		var a := float(j) / float(sides) * TAU
		return Vector3(cos(a) * pr[i].x, pr[i].y, -sin(a) * pr[i].x)
	var ring_n := func(i: int, j: int) -> Vector3:
		var a := float(j) / float(sides) * TAU
		return Vector3(cos(a) * n2[i].x, n2[i].y, -sin(a) * n2[i].x).normalized()
	for i in n - 1:
		for j in sides:
			var j2 := (j + 1) % sides
			st.set_normal(ring_n.call(i, j))
			st.add_vertex(ring.call(i, j))
			st.set_normal(ring_n.call(i + 1, j))
			st.add_vertex(ring.call(i + 1, j))
			st.set_normal(ring_n.call(i + 1, j2))
			st.add_vertex(ring.call(i + 1, j2))
			st.set_normal(ring_n.call(i, j))
			st.add_vertex(ring.call(i, j))
			st.set_normal(ring_n.call(i + 1, j2))
			st.add_vertex(ring.call(i + 1, j2))
			st.set_normal(ring_n.call(i, j2))
			st.add_vertex(ring.call(i, j2))
	# fondo chiuso (se il profilo non parte da raggio zero); winding
	# concorde alle pareti: visto da sotto il tappo è davvero visibile
	if pr[0].x > 0.001:
		var c := Vector3(0, pr[0].y, 0)
		for j in sides:
			var j2 := (j + 1) % sides
			st.set_normal(Vector3.DOWN)
			st.add_vertex(c)
			st.set_normal(Vector3.DOWN)
			st.add_vertex(ring.call(0, j))
			st.set_normal(Vector3.DOWN)
			st.add_vertex(ring.call(0, j2))

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Un ciuffetto di pelo: ventaglio di ciocche morbide a goccia,
## appiattite e sventagliate. Le ciocche crescono lungo il +Y locale;
## dir_rot orienta il ciuffo. La taglia scala tutto insieme.
static func tuft(parent: Node3D, mat: Material, pos: Vector3, dir_rot: Vector3,
		size: float, locks := 3, spread := 0.55) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	t.rotation = dir_rot
	parent.add_child(t)
	for i in locks:
		var off := float(i) - float(locks - 1) * 0.5
		var lock := lathe(t, [Vector2(0.34, 0.0), Vector2(0.27, 0.42),
				Vector2(0.13, 0.78), Vector2(0.0, 1.0)],
				mat, Vector3(off * 0.42, 0, 0) * size, 10, size, size)
		lock.rotation.z = off * spread
		lock.scale.z = 0.5
	return t


## Colletto a petali arrotondati, appoggiato sulla spalla del vestitino
## come un colletto tondo da grembiulino.
static func collar(root: Node3D, mat: Material, y: float, r: float,
		count := 7, petal := 0.058) -> void:
	for i in count:
		var a := float(i) / float(count) * TAU
		var p := Node3D.new()
		p.position = Vector3(cos(a) * r, y, sin(a) * r)
		p.rotation.y = PI * 0.5 - a
		root.add_child(p)
		var pe := _ball(p, petal, mat, Vector3(0, 0, petal * 0.5),
				Vector3(0.9, 0.4, 1.3))
		pe.rotation.x = 0.5


static func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3,
		scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 22
	sm.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _capsule(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------- il chibi

## Costruisce il chibi. Restituisce
## {"root", "head", "ears", "arms", "tail", "tail_tip", "face"} — tail_tip è
## lo snodo della punta (null per le code a ponpon), "face" è il rig facciale
## animabile (occhi, iridi, sopracciglia, bocche…) per il FaceController.
static func build(dna: Dictionary) -> Dictionary:
	var fur := _mat(Color(dna["fur"]), 0.45)
	var fur2 := _mat(Color(dna["fur2"]), 0.45)
	var belly := _mat(Color(dna["belly"]), 0.4)
	var dress := _mat(Color(dna["dress"]))
	var dress2 := _mat(Color(dna["dress2"]))
	var inner := _mat(Color(dna["inner_ear"]))
	var fluff: float = dna.get("fluff", 0.6)

	var root := Node3D.new()
	root.scale = Vector3.ONE * float(dna["size"])

	# --- vestitino a pera, colletto a petali, gambette, braccine ---
	lathe(root, DRESS_PROFILE, dress, Vector3.ZERO, 30, 0.94, 0.96)
	collar(root, dress2, 0.575, 0.155)

	# il pelo del petto che sbuffa sopra la scollatura
	tuft(root, fur, Vector3(0, 0.63, -0.155), Vector3(-2.55, 0, 0),
			0.10 * (0.55 + 0.65 * fluff), 3, 0.5)
	# e il ciuffo alla base della coda, dove esce dal vestitino
	tuft(root, fur, Vector3(0, 0.255, 0.26), Vector3(1.25, 0, 0),
			0.055 + 0.05 * fluff, 3, 0.7)

	var legs: Array[Node3D] = []
	# gambette con lo SNODO all'anca: il ciclo di camminata le fa trottare
	# (piedino che si alza in fase aerea, spinge in appoggio)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.105, 0.16, -0.02)
		root.add_child(hip)
		_capsule(hip, 0.062, 0.17, belly, Vector3(0, -0.06, 0))
		_ball(hip, 0.068, belly, Vector3(0, -0.135, -0.045), Vector3(1, 0.62, 1.35))
		legs.append(hip)

	var arms: Array[Node3D] = []
	# braccia VERE, leggibili: manica corta a sbuffo (vestito) col polsino
	# chiaro, poi l'avambraccio in PELO — che stacca dal vestito, prima le
	# braccia sparivano perché manica e campana erano lo stesso colore —
	# e in punta la zampa-guanto paffuta col pollicino: la "mano" dei chibi
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		# spalla raccolta sul corpo, braccio corto: proporzioni da peluche
		shoulder.position = Vector3(side * 0.21, 0.56, 0)
		shoulder.rotation.z = side * 0.32
		root.add_child(shoulder)
		_capsule(shoulder, 0.076, 0.18, dress, Vector3(0, -0.045, 0))
		_ball(shoulder, 0.07, dress2, Vector3(0, -0.12, 0), Vector3(1, 0.55, 1))
		# gomito morbido, piega in avanti più accentuata: niente bastoncini
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.125, 0)
		elbow.rotation.x = 0.24
		shoulder.add_child(elbow)
		_capsule(elbow, 0.046, 0.2, fur, Vector3(0, -0.085, 0))
		_ball(elbow, 0.066, belly, Vector3(0, -0.19, 0), Vector3(0.95, 1.1, 0.85))
		_ball(elbow, 0.026, belly, Vector3(side * -0.04, -0.165, -0.022))
		arms.append(shoulder)

	# --- testa: più larga che alta, come i pupazzetti ---
	var head := Node3D.new()
	head.position = Vector3(0, 0.92, 0)
	root.add_child(head)
	var hs: float = dna["head_scale"]
	_ball(head, 0.4, fur, Vector3.ZERO, Vector3(hs * 1.04, hs * 0.92, hs * 0.97))

	# la frangetta sulla fronte, solo per i più pelosetti
	if fluff > 0.45:
		tuft(head, fur, Vector3(0, 0.27 * hs, -0.26 * hs), Vector3(-2.9, 0, 0),
				0.03 + 0.09 * fluff, 3, 0.62)

	var ears := _build_ears(head, dna, fur, fur2, inner, hs)
	var face := _build_face(head, dna, fur, fur2, belly, hs)
	var tail_parts := _build_tail(root, dna, fur, fur2, belly)
	var acc = load("res://scenes/npc/ChibiAccessories.gd")
	acc.apply(dna, root, head)

	return {"root": root, "head": head, "ears": ears, "arms": arms,
			"legs": legs, "tail": tail_parts[0], "tail_tip": tail_parts[1],
			"face": face}


# ---------------------------------------------------------- orecchie

static func _build_ears(head: Node3D, dna: Dictionary, fur: ShaderMaterial,
		fur2: ShaderMaterial, inner: ShaderMaterial, hs: float) -> Array[Node3D]:
	var ears: Array[Node3D] = []
	var arche: String = dna["archetype"]
	var elen: float = dna["ear_len"]
	var eang: float = dna["ear_ang"]
	for side: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		var top := 0.30 * hs
		ear.rotation.z = side * -eang
		ear.rotation.y = side * -0.15
		head.add_child(ear)
		match arche:
			"gatto", "volpina":
				# cono morbido a punta arrotondata, interno inserito
				ear.position = Vector3(side * 0.21 * hs, top, -0.01)
				var emat := fur2 if arche == "volpina" else fur
				var esc := 1.15 if arche == "volpina" else 1.0
				lathe(ear, [Vector2(0.105, 0.0), Vector2(0.10, 0.09),
						Vector2(0.075, 0.16), Vector2(0.04, 0.215), Vector2(0.0, 0.245)],
						emat, Vector3.ZERO, 18, esc, elen * esc)
				var inr := lathe(ear, [Vector2(0.062, 0.0), Vector2(0.055, 0.07),
						Vector2(0.032, 0.13), Vector2(0.0, 0.16)],
						inner, Vector3(0, 0.035 * elen, -0.045), 14, esc, elen * esc)
				inr.scale.z = 0.55
			"coniglio":
				# orecchione lungo e morbido, appena ricurvo all'indietro
				ear.position = Vector3(side * 0.13 * hs, top + 0.02, 0)
				tube(ear, [Vector3(0, -0.02, 0), Vector3(side * 0.01, 0.10 * elen, -0.005),
						Vector3(side * 0.02, 0.20 * elen, 0.012), Vector3(side * 0.02, 0.285 * elen, 0.035)],
						[0.052, 0.062, 0.052, 0.024], fur, 16, 10)
				_ball(ear, 0.042, inner, Vector3(side * 0.012, 0.15 * elen, -0.035),
						Vector3(0.72, 2.1 * elen, 0.42), false)
			"orsetto":
				ear.position = Vector3(side * 0.23 * hs, top - 0.035, 0)
				_ball(ear, 0.105, fur, Vector3(0, 0.035, 0), Vector3(1, 0.95, 0.55))
				_ball(ear, 0.06, inner, Vector3(0, 0.038, -0.048), Vector3(1, 0.9, 0.4))
			"topolino":
				ear.position = Vector3(side * 0.27 * hs, top - 0.025, 0)
				_ball(ear, 0.135, fur, Vector3(side * 0.03, 0.06, 0), Vector3(1, 1, 0.38))
				_ball(ear, 0.09, inner, Vector3(side * 0.03, 0.06, -0.036), Vector3(1, 1, 0.3))
		ears.append(ear)
	return ears


# ---------------------------------------------------------- viso

static func _build_face(head: Node3D, dna: Dictionary, fur: ShaderMaterial,
		_fur2: ShaderMaterial, _belly: ShaderMaterial, hs: float) -> Dictionary:
	var dark := _flat(Color("2a1d1d"))
	var front := -0.34 * hs
	var arche: String = dna["archetype"]

	# il musetto: un tono appena più chiaro del pelo, mai bianco — deve
	# dare struttura al viso senza staccare come una macchia
	var muso := _mat(Color(dna["fur"]).lightened(0.07), 0.35)
	match arche:
		"volpina":
			# musetto a goccia morbida col nasino scuro in punta
			var snout := lathe(head, [Vector2(0.0, 0.0), Vector2(0.075, 0.045),
					Vector2(0.062, 0.10), Vector2(0.03, 0.145), Vector2(0.0, 0.165)],
					muso, Vector3(0, -0.095 * hs, front + 0.02), 16)
			# -PI/2: la punta esce dal viso verso il nasino (con +PI/2
			# il cono finiva DENTRO la testa e il nasino galleggiava)
			snout.rotation.x = -PI * 0.5
			_ball(head, 0.026, dark, Vector3(0, -0.088 * hs, front - 0.135),
					Vector3(1.15, 0.85, 0.8), false)
		"topolino":
			_ball(head, 0.10, muso, Vector3(0, -0.10 * hs, front + 0.01),
					Vector3(1, 0.68, 0.5))
			_ball(head, 0.024, dark, Vector3(0, -0.062 * hs, front - 0.075),
					Vector3(1.1, 0.85, 0.8), false)
		"orsetto":
			_ball(head, 0.14, muso, Vector3(0, -0.105 * hs, front + 0.005),
					Vector3(1, 0.66, 0.42))
			_ball(head, 0.032, dark, Vector3(0, -0.045 * hs, front - 0.062),
					Vector3(1.25, 0.8, 0.7), false)
		_:
			# gatto e coniglietta: due cuscinetti affiancati e il nasino rosa
			for side: float in [-1.0, 1.0]:
				_ball(head, 0.082, muso, Vector3(side * 0.046, -0.115 * hs, front - 0.012),
						Vector3(1, 0.72, 0.5))
			_ball(head, 0.02, _flat(Color("ff8fa3")),
					Vector3(0, -0.052 * hs, front - 0.058), Vector3(1.3, 0.85, 0.7), false)

	# occhioni con doppia luce, raccolti attorno a un nodo "iride": lo sguardo
	# lo sposta e la tenerezza lo dilata (vedi FaceController). Sopra ogni
	# occhio un sopracciglio animabile, e un arco "^^" per la felicità piena.
	var eye_r: float = dna["eye_r"]
	var gap: float = dna["eye_gap"]
	var ey: float = 0.035 + float(dna["eye_h"])
	var eyes: Array[Node3D] = []
	var eyeballs: Array[MeshInstance3D] = []
	var irises: Array[Node3D] = []
	var happy: Array[Node3D] = []
	var brows: Array[Node3D] = []
	# sopracciglia vere dal DNA: lo stile viene dal mazzo dell'archetipo, le
	# micro-variazioni (folte/arcuate/lunghe) dal genoma. Toon e non unshaded:
	# il fuso ha un rilievo, piatto tornerebbe una macchia.
	var brow_mat := _mat(Color(dna["fur"]).darkened(0.62))
	var brow_stile := str(dna.get("brow", "morbide"))
	var brow_ricetta: Dictionary = FACE.BROW_STYLES.get(
			brow_stile, FACE.BROW_STYLES["morbide"])
	var brow_vari := {"arco": float(brow_ricetta["arco"]) \
			* float(dna.get("brow_arco", 1.0))}
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * gap * hs, ey, front)
		head.add_child(eye)
		var ball := _ball(eye, eye_r, dark, Vector3.ZERO, Vector3(1, 1.18, 0.55), false)
		var iris := Node3D.new()
		eye.add_child(iris)
		# luci a disco, appoggiate sulla superficie dell'occhio
		_ball(iris, eye_r * 0.36, _flat(Color.WHITE),
				Vector3(-0.028 * side, eye_r * 0.42, -eye_r * 0.5), Vector3(1, 1, 0.35), false)
		_ball(iris, eye_r * 0.16, _flat(Color("ffdce4")),
				Vector3(0.03 * side, -eye_r * 0.32, -eye_r * 0.52), Vector3(1, 1, 0.35), false)
		eyes.append(eye)
		eyeballs.append(ball)
		irises.append(iris)
		happy.append(FACE.build_happy_arc(head, dark,
				Vector3(side * gap * hs, ey + 0.006, front - 0.006), side, eye_r * 0.92))
		brows.append(FACE.build_brow(head, brow_mat, side,
				Vector3(side * gap * hs * 0.92, ey + eye_r * 1.7, front + 0.002),
				eye_r * 1.05 * float(dna.get("brow_len", 1.0)),
				0.015 * float(dna.get("brow_folto", 1.0)),
				brow_stile, brow_vari))

	# il set completo di bocche morbide (neutra, sorriso, ghigno, o/O, broncio,
	# triste, seria) + la cavità che si apre per parlare/ridere/stupirsi.
	# Labbra-fuso dal DNA (mazzo dell'archetipo + micro-variazioni), in toon
	# come le sopracciglia: il rilievo del labbro si deve leggere.
	#
	# DOVE sta la bocca lo decide il MUSETTO, non una quota unica: prima
	# stava a -0.105·hs per tutti — sui musetti sporgenti (volpina, orsetto,
	# topolino) restava SEPOLTA nella geometria e si leggeva solo il naso,
	# su gatto/coniglio finiva sopra i cuscinetti, attaccata al naso.
	# Con la bocca arriva il "filtrino": il trattino verticale naso→labbro
	# dei pupazzi, che cuce il musetto alla bocca (non per la volpina: il
	# suo naso sta in punta al muso a goccia, la bocca sotto la base).
	var mouth_mat := _mat(Color("5a3434"))
	var bocca_stile := str(dna.get("bocca", "morbida"))
	var bocca_ricetta: Dictionary = FACE.MOUTH_STYLES.get(
			bocca_stile, FACE.MOUTH_STYLES["morbida"])
	var bocca_vari := {
		"larg": float(bocca_ricetta["larg"]) * float(dna.get("bocca_larg", 1.0)),
		"spess": float(bocca_ricetta["spess"]) * float(dna.get("bocca_spess", 1.0)),
	}
	var my: float
	var mouth_z: float
	var mscale := hs
	var philtrum: MeshInstance3D = null
	match arche:
		"volpina":
			# sotto la BASE del muso a goccia, sul viso: piccola e raccolta
			my = -0.19 * hs
			mouth_z = front - 0.038
			mscale = hs * 0.88
		"orsetto":
			# sul musetto largo, subito sotto il nasone
			my = -0.142 * hs
			mouth_z = front - 0.064
			philtrum = tube(head,
					[Vector3(0, -0.078 * hs, front - 0.072),
					Vector3(0, -0.136 * hs, front - 0.066)],
					[0.005 * hs, 0.0038 * hs], mouth_mat, 6, 8)
		"topolino":
			my = -0.132 * hs
			mouth_z = front - 0.058
			philtrum = tube(head,
					[Vector3(0, -0.082 * hs, front - 0.070),
					Vector3(0, -0.126 * hs, front - 0.060)],
					[0.0045 * hs, 0.0035 * hs], mouth_mat, 6, 8)
		_:
			# gatto e coniglietta: sull'orlo basso dei cuscinetti, col
			# filtrino che percorre la loro giuntura dal nasino rosa
			my = -0.175 * hs
			mouth_z = front - 0.055
			philtrum = tube(head,
					[Vector3(0, -0.068 * hs, front - 0.062),
					Vector3(0, -0.168 * hs, front - 0.058)],
					[0.0048 * hs, 0.0036 * hs], mouth_mat, 8, 8)
	if philtrum != null:
		philtrum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mouths := FACE.build_mouth_set(head, mouth_mat, Vector3(0, my, mouth_z),
			mscale, bocca_stile, bocca_vari)
	var mouth_open := FACE.build_mouth_open(head, _flat(Color("3a1f1f")),
			Vector3(0, my, mouth_z), mscale)

	# ciuffi sulle guance: quanti e quanto folti dipende dal pelo del DNA
	var fluff: float = dna.get("fluff", 0.6)
	for side: float in [-1.0, 1.0]:
		tuft(head, fur, Vector3(side * 0.35 * hs, -0.07, -0.10),
				Vector3(0, side * -0.35, side * -2.05),
				0.075 * (0.5 + 0.8 * fluff), 2 if fluff < 0.6 else 3, 0.6)

	# guanciotte e, per qualcuno, lentiggini
	var blush_a: float = dna["blush"]
	var blush_nodes: Array[MeshInstance3D] = []
	for side: float in [-1.0, 1.0]:
		var blush := _ball(head, 0.052, _flat(Color(1.0, 0.62, 0.7, blush_a * 0.7)),
				Vector3(side * 0.245 * hs, -0.06, front + 0.045), Vector3(1, 0.6, 0.3), false)
		blush.rotation.y = side * -0.55
		blush_nodes.append(blush)
		if dna["freckles"]:
			var fr := _flat(Color(Color(dna["fur2"]), 0.85))
			for i in 3:
				_ball(head, 0.008, fr,
						Vector3(side * (0.2 + 0.035 * i) * hs, -0.02 - 0.02 * (i % 2), front + 0.03),
						Vector3.ONE, false)

	return {
		"eyes": eyes, "eyeballs": eyeballs, "irises": irises,
		"happy": happy, "brows": brows, "blush": blush_nodes,
		"mouths": mouths, "mouth_open": mouth_open, "philtrum": philtrum,
		"eye_base_scale": Vector3(1, 1.18, 0.55),
		"face_side": maxf(gap * hs, 0.12),
	}


# ---------------------------------------------------------- code

## Ritorna [pivot base, pivot punta (o null)]. La base spunta dal retro
## del vestitino; la punta è uno snodo per il colpo di frusta del
## scodinzolio, con una sferetta-nocca che nasconde la giuntura.
static func _build_tail(root: Node3D, dna: Dictionary, fur: ShaderMaterial,
		fur2: ShaderMaterial, belly: ShaderMaterial) -> Array:
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.22, 0.26)
	root.add_child(tail)
	var tip: Node3D = null
	match str(dna["tail"]):
		"ricciolo":
			# coda da gatto: sporge all'indietro a bandiera e si arriccia in su
			tube(tail, [Vector3(0, -0.02, -0.06), Vector3(0, 0.0, 0.09),
					Vector3(0, 0.04, 0.18), Vector3(0, 0.10, 0.24)],
					[0.055, 0.059, 0.054, 0.046], fur, 18, 12)
			_ball(tail, 0.044, fur, Vector3(0, 0.10, 0.24))
			tip = Node3D.new()
			tip.position = Vector3(0, 0.10, 0.24)
			tail.add_child(tip)
			tube(tip, [Vector3.ZERO, Vector3(0, 0.07, 0.035), Vector3(0, 0.13, 0.04)],
					[0.045, 0.036, 0.024], fur, 12, 10)
			tube(tip, [Vector3(0, 0.13, 0.04), Vector3(0, 0.17, 0.025), Vector3(0, 0.20, -0.01)],
					[0.024, 0.016, 0.006], belly, 10, 8)
		"ponpon":
			# batuffolo soffice, con bombature che lo spettinano
			_ball(tail, 0.095, belly, Vector3(0, 0.04, 0.05))
			_ball(tail, 0.05, belly, Vector3(0.05, 0.09, 0.06))
			_ball(tail, 0.045, belly, Vector3(-0.055, 0.05, 0.08))
			_ball(tail, 0.042, belly, Vector3(0.01, 0.0, 0.1))
		"volpe":
			# il codone folto: carota soffice quasi orizzontale, punta chiara
			tube(tail, [Vector3(0, -0.02, -0.06), Vector3(0, 0.0, 0.08),
					Vector3(0, 0.05, 0.19), Vector3(0, 0.13, 0.26)],
					[0.05, 0.082, 0.102, 0.088], fur2, 18, 12)
			_ball(tail, 0.086, fur2, Vector3(0, 0.13, 0.26))
			tip = Node3D.new()
			tip.position = Vector3(0, 0.13, 0.26)
			tail.add_child(tip)
			tube(tip, [Vector3.ZERO, Vector3(0, 0.08, 0.03), Vector3(0, 0.14, 0.025)],
					[0.086, 0.06, 0.04], fur2, 12, 10)
			tube(tip, [Vector3(0, 0.14, 0.025), Vector3(0, 0.19, 0.0), Vector3(0, 0.215, -0.04)],
					[0.04, 0.026, 0.009], belly, 10, 8)
		"filo":
			# coda da topolino: filo sottile con l'onda e il ricciolo in punta
			tube(tail, [Vector3(0, -0.01, -0.04), Vector3(0.025, 0.02, 0.08),
					Vector3(-0.02, 0.08, 0.16), Vector3(0, 0.15, 0.2)],
					[0.021, 0.018, 0.016, 0.014], fur2, 16, 8)
			_ball(tail, 0.0135, fur2, Vector3(0, 0.15, 0.2))
			tip = Node3D.new()
			tip.position = Vector3(0, 0.15, 0.2)
			tail.add_child(tip)
			tube(tip, [Vector3.ZERO, Vector3(0.01, 0.06, -0.015), Vector3(-0.005, 0.10, -0.045)],
					[0.014, 0.011, 0.006], fur2, 10, 8)
	return [tail, tip]


# Gli accessori vivono nel loro modulo: scenes/npc/ChibiAccessories.gd
# (caricato a runtime in build(), così il modulo può a sua volta usare
# le primitive del builder senza cicli di preload).
