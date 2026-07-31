extends RefCounted

## LA FORMA DEL GRANDE ALBERO — quanto è grande, e com'è fatto.
##
## L'albero cresce coi giorni come un bonsai condiviso, e non è un
## dettaglio decorativo: è il monumento al centro del prato, il posto dove
## si incidono gli eventi, e la prima cosa che si vede aprendo il gioco.
##
## Sta qui e non dentro `GrandTree` perché lo costruiscono in DUE: il
## villaggio, e il diorama del menù principale — che deve mostrare
## l'albero VERO del salvataggio, alla taglia che ha raggiunto quella
## partita. Con la geometria in un posto solo, un albero che cresce in
## modo diverso nel menù e nel gioco non è possibile; con due copie
## sarebbe stato il primo bug e nessuno se ne sarebbe accorto (chi
## confronta un menù con la partita?).
##
## Tutto `static`: entra un palco e una taglia, esce l'albero.

const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const HANDPAINT := preload("res://shaders/handpaint.gdshader")


## LA CRESCITA. Da alberello (0.12) a gigante (1.0) in un mese di
## calendario, con la curva che rallenta: i primi giorni si vede crescere
## a occhio, poi si assesta. È la formula del villaggio — il menù la
## chiama, non la ricopia.
static func stage_per_giorno(giorno: int) -> float:
	return clampf(pow(float(giorno) / 30.0, 0.62), 0.12, 1.0)


## Le misure che discendono dalla taglia: altezza del tronco, raggio alla
## base, raggio della chioma. Le vuole anche chi deve mettere qualcosa
## SOTTO l'albero (una gatta seduta, un'altalena, dei vicini che giocano).
static func misure(stage: float) -> Dictionary:
	return {
		"h": 1.7 + 5.0 * stage,
		"r": 0.30 + 0.55 * stage,
		"cr": 1.0 + 3.0 * stage,
	}


## La tinta della chioma secondo la stagione (0 primavera … 3 inverno).
static func colore_foglia(c: Color, stagione: int, e_fiore: bool) -> Color:
	match stagione:
		0:  # primavera: verde tenero e sbuffi in fiore
			return c
		1:  # estate: verde pieno; i fiori diventano fronda
			if e_fiore:
				return Color.from_hsv(0.29, 0.5, clampf(c.v * 0.82, 0.25, 0.9))
			return Color.from_hsv(c.h, minf(c.s * 1.1, 1.0), c.v * 0.92)
		2:  # autunno: oro e rame, i fiori cremisi
			if e_fiore:
				return Color.from_hsv(0.02, 0.52, clampf(c.v * 0.9, 0.0, 1.0))
			return Color.from_hsv(lerpf(0.04, 0.10, clampf(c.v, 0.0, 1.0)), 0.72,
					clampf(c.v + 0.03, 0.0, 1.0))
		_:  # inverno: chioma brinata, fiori di ghiaccio (la neve fa il resto)
			if e_fiore:
				return Color.from_hsv(0.95, 0.08, clampf(c.v * 0.85 + 0.12, 0.0, 1.0))
			return Color.from_hsv(0.10, 0.14, clampf(c.v * 0.72 + 0.14, 0.0, 1.0))


static func materiale(a: Color, b: Color, grain := 3.0, amount := 0.5,
		wind := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	mat.set_shader_parameter("wind_strength", wind)
	return mat


## I quattro materiali della chioma per una stagione, in un colpo solo.
static func materiali(stagione: int) -> Dictionary:
	return {
		"bark": materiale(Color("8a5f43"), Color("6f4a33"), 2.5, 0.55),
		"leaf": materiale(colore_foglia(Color("7fbc62"), stagione, false),
				colore_foglia(Color("5f9c48"), stagione, false), 2.0, 0.6, 0.02),
		"leaf2": materiale(colore_foglia(Color("97cc74"), stagione, false),
				colore_foglia(Color("74b05c"), stagione, false), 2.0, 0.6, 0.02),
		"blossom": materiale(colore_foglia(Color("ffc2d4"), stagione, true),
				colore_foglia(Color("f5a8c0"), stagione, true), 2.5, 0.5, 0.02),
	}


## COSTRUISCE L'ALBERO dentro [param parent], alla taglia [param stage].
## Torna {h, r, cr, swing} — l'altalena è `null` finché l'albero non è
## abbastanza grande da reggerla.
##
## [param semina] rende ripetibile la chioma: con lo stesso seme lo stesso
## albero. Serve al menù, che ricostruisce il diorama a ogni apertura e
## non deve mostrare un albero diverso ogni volta.
static func costruisci(parent: Node3D, stage: float, mats: Dictionary,
		semina := 20260730) -> Dictionary:
	var m := misure(stage)
	var h: float = m["h"]
	var r: float = m["r"]
	var cr: float = m["cr"]
	var bark: Material = mats["bark"]
	var leaf: Material = mats["leaf"]
	var leaf2: Material = mats["leaf2"]
	var blossom: Material = mats["blossom"]
	var rng := RandomNumberGenerator.new()
	rng.seed = semina

	# il tronco possente, coi fianchi che si allargano alla base
	BUILDER.lathe(parent, [Vector2(r * 1.65, 0.0), Vector2(r * 1.12, 0.4),
			Vector2(r * 0.95, h * 0.38), Vector2(r * 0.78, h * 0.72),
			Vector2(r * 0.6, h), Vector2(r * 0.3, h * 1.04)], bark, Vector3.ZERO, 20)
	# radici che artigliano il prato
	for i in 6:
		var a := float(i) / 6.0 * TAU + 0.35
		var dir := Vector3(cos(a), 0, sin(a))
		BUILDER.tube(parent, [dir * r * 0.7 + Vector3(0, 0.34, 0),
				dir * r * 1.5 + Vector3(0, 0.1, 0), dir * r * 2.3],
				[r * 0.3, r * 0.2, r * 0.07], bark, 10, 8)
	# rami che reggono la chioma
	if stage > 0.3:
		for i in 4:
			var a := float(i) / 4.0 * TAU + 0.8
			var dir := Vector3(cos(a), 0, sin(a))
			BUILDER.tube(parent, [Vector3(0, h * 0.82, 0) + dir * r * 0.4,
					Vector3(0, h * 0.98, 0) + dir * cr * 0.42,
					Vector3(0, h * 1.12, 0) + dir * cr * 0.62],
					[r * 0.34, r * 0.22, r * 0.1], bark, 10, 8)

	# la chioma: un cumulo di nuvole verdi con due sbuffi in fiore
	var cc := Vector3(0, h + cr * 0.42, 0)
	_ball(parent, cr, leaf, cc)
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.5
		_ball(parent, cr * 0.62, leaf2 if i % 2 == 0 else leaf,
				cc + Vector3(cos(a) * cr * 0.72,
						rng.randf_range(-0.15, 0.3) * cr, sin(a) * cr * 0.72))
	_ball(parent, cr * 0.55, leaf2, cc + Vector3(0, cr * 0.7, 0))
	_ball(parent, cr * 0.3, blossom, cc + Vector3(cr * 0.55, cr * 0.5, cr * 0.35))
	_ball(parent, cr * 0.26, blossom, cc + Vector3(-cr * 0.6, cr * 0.35, -cr * 0.3))

	# dal ramo basso, l'altalena di corda che aspetta qualcuno
	var swing: Node3D = null
	if stage > 0.5:
		var branch_a := 0.8
		var bdir := Vector3(cos(branch_a), 0, sin(branch_a))
		swing = Node3D.new()
		swing.position = Vector3(0, h * 0.98, 0) + bdir * cr * 0.42
		parent.add_child(swing)
		var rope := materiale(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
		var drop := h * 0.98 - 0.55
		for side: float in [-0.14, 0.14]:
			_cyl(swing, 0.016, drop, rope, Vector3(side, -drop * 0.5, 0))
		var plank := MeshInstance3D.new()
		var pmsh := BoxMesh.new()
		pmsh.size = Vector3(0.44, 0.04, 0.18)
		plank.mesh = pmsh
		plank.material_override = materiale(Color("c89a6b"), Color("a87c50"), 4.0, 0.5)
		plank.position = Vector3(0, -drop, 0)
		swing.add_child(plank)

	return {"h": h, "r": r, "cr": cr, "swing": swing}


static func _ball(parent: Node3D, radius: float, mat: Material, pos: Vector3) -> void:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


static func _cyl(parent: Node3D, radius: float, height: float, mat: Material,
		pos: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
