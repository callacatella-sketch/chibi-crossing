extends RefCounted
## Test del FaceController: costruisce un rig facciale sintetico con gli helper
## statici, monta il controller e lo fa girare esercitando ogni espressione, lo
## sguardo, gli umori del Chibiese, il parlato, l'impulso e l'ammicco.
## Contiene la regressione della BOCCA CAPOVOLTA: uno smile deve curvare a ∪
## (angoli più in alto del centro) e un frown a ∩ — un segno invertito qui
## trasforma il sorriso in broncio su tutti i personaggi del gioco.
## (Era tests/face_smoke.gd, script sciolto fuori dalla suite.)

const FACE := "res://scenes/characters/FaceController.gd"


func run(t) -> void:
	var fc: GDScript = load(FACE)
	if fc == null or not fc.can_instantiate():
		t.ok(false, "FaceController.gd non compilabile")
		return
	var rig := _build_rig(t, fc)
	if rig.is_empty():
		return
	_test_curvatura_bocca(t, rig)
	_test_giro_espressioni(t, fc, rig)
	_test_recita_sopracciglia(t, fc)
	_test_bocche_intere(t, fc, rig)


# un rig sintetico: testa, due occhi con bulbo e iride, archi felici,
# sopracciglia, guanciotte, e il set di bocche costruito dagli helper statici
func _build_rig(t, fc: GDScript) -> Dictionary:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a1d1d")
	var head := t.stage(Node3D.new()) as Node3D

	var eyes: Array[Node3D] = []
	var eyeballs: Array[MeshInstance3D] = []
	var irises: Array[Node3D] = []
	var happy: Array[Node3D] = []
	var brows: Array[Node3D] = []
	var blush: Array[MeshInstance3D] = []
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.155, 0.03, -0.355)
		head.add_child(eye)
		var ball := MeshInstance3D.new()
		ball.mesh = SphereMesh.new()
		ball.material_override = mat
		ball.scale = Vector3(1, 1.18, 0.55)
		eye.add_child(ball)
		eyeballs.append(ball)
		var iris := Node3D.new()
		var shine := MeshInstance3D.new()
		shine.mesh = SphereMesh.new()
		iris.add_child(shine)
		eye.add_child(iris)
		irises.append(iris)
		eyes.append(eye)
		happy.append(fc.build_happy_arc(head, mat, Vector3(side * 0.155, 0.03, -0.36), side))
		brows.append(fc.build_brow(head, mat, side, Vector3(side * 0.15, 0.16, -0.36)))
		var bl := MeshInstance3D.new()
		bl.mesh = SphereMesh.new()
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(1, 0.6, 0.7, 0.6)
		bl.material_override = bm
		head.add_child(bl)
		blush.append(bl)

	var mouths: Dictionary = fc.build_mouth_set(head, mat, Vector3(0, -0.1, -0.408))
	var mouth_open: Node3D = fc.build_mouth_open(head, mat, Vector3(0, -0.1, -0.408))
	t.ok(mouths.size() >= 6, "il set di bocche ha almeno 6 forme (%d)" % mouths.size())
	t.ok(mouth_open != null, "la bocca aperta è stata costruita")
	if mouths.size() < 6 or mouth_open == null:
		return {}

	return {
		"head": head, "eyes": eyes, "eyeballs": eyeballs, "irises": irises,
		"happy": happy, "brows": brows, "blush": blush,
		"mouths": mouths, "mouth_open": mouth_open,
		"eye_base_scale": Vector3(1, 1.18, 0.55), "face_side": 0.36,
	}


# la curvatura di una bocca: quanto gli angoli stanno PIÙ IN ALTO del centro.
# >0 = ∪ (sorriso) · <0 = ∩ (broncio). Si misura dai VERTICI del labbro-fuso:
# la bocca non è più una catena di palline con una posizione per pallina.
func _curvatura(mouths: Dictionary, shape: String) -> float:
	var node: Node3D = mouths[shape]
	var mi := node.get_child(0) as MeshInstance3D
	if mi == null or not (mi.mesh is ArrayMesh):
		return 0.0
	var vs: PackedVector3Array = \
			(mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var hw := 0.0
	for v in vs:
		hw = maxf(hw, absf(v.x))
	var corner := -INF
	var center := -INF
	for v in vs:
		if absf(v.x) > hw * 0.8:
			corner = maxf(corner, v.y)
		elif absf(v.x) < hw * 0.2:
			center = maxf(center, v.y)
	return corner - center


func _test_curvatura_bocca(t, rig: Dictionary) -> void:
	var mouths: Dictionary = rig["mouths"]
	if not mouths.has("smile") or not mouths.has("frown"):
		t.ok(false, "il set di bocche non ha smile/frown")
		return
	t.ok(_curvatura(mouths, "smile") > 0.0,
			"il sorriso curva a ∪ (angoli in alto), non capovolto")
	t.ok(_curvatura(mouths, "frown") < 0.0,
			"il broncio curva a ∩ (angoli in basso), non capovolto")


# monta il controller e lo fa girare su ogni espressione, umore e transitorio
func _test_giro_espressioni(t, fc: GDScript, rig: Dictionary) -> void:
	var face = fc.new()
	face.setup(rig)

	var target := t.stage(Node3D.new()) as Node3D
	target.position = Vector3(1, 1, -2)
	face.look_at_node(target)

	var frames := 0
	for e in fc.EXPRESSIONS.keys():
		face.set_expression(e, 1.0)
		face.set_talking(frames % 2 == 0)
		for f in 30:
			face.update(0.016)
			frames += 1
	t.ok(frames == fc.EXPRESSIONS.size() * 30,
			"ogni espressione ha girato 30 frame senza errori (%d)" % frames)

	for mood in ["neutro", "felice", "domanda", "triste"]:
		face.set_mood(mood)
		for f in 10:
			face.update(0.016)
	t.ok(true, "gli umori del Chibiese girano senza errori")

	face.pulse("sorpresa", 0.3)
	face.freeze_blink(10.0)
	for f in 40:
		face.update(0.016)
	t.ok(true, "impulso transitorio e freeze dell'ammicco girano")


# La RECITA delle sopracciglia: la molla sottosmorzata deve SUPERARE il
# bersaglio (overshoot: è ciò che l'occhio legge come muscolo, non
# interruttore) e poi assestarsi; il flick del curioso deve rompere la
# simmetria (un sopracciglio su, l'altro giù). Un rig fresco per ciascuna
# prova: le molle partono da riposo.
func _test_recita_sopracciglia(t, fc: GDScript) -> void:
	# la tabella: ogni voce punta a un'espressione vera e a uno stile noto
	var stili_noti := ["scatto", "tremito", "flick", "rimbalzo", "fremito",
			"morsa", "sciolto", "pesante", "quiete"]
	for nome in fc.BROW_PLAY:
		t.ok(fc.EXPRESSIONS.has(nome),
				"BROW_PLAY['%s'] è un'espressione vera" % nome)
		t.ok(str(fc.BROW_PLAY[nome].get("stile", "")) in stili_noti,
				"BROW_PLAY['%s']: stile conosciuto" % nome)

	# overshoot e assestamento sulla sorpresa
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.freeze_blink(60.0)
	var base_y: float = (rig["brows"][0] as Node3D).position.y
	face.set_expression("sorpresa", 1.0)
	var massimo := -INF
	for f in 60:
		face.update(1.0 / 60.0)
		massimo = maxf(massimo, (rig["brows"][0] as Node3D).position.y - base_y)
	var bersaglio: float = fc.EXPRESSIONS["sorpresa"]["brow_h"]
	t.ok(massimo > bersaglio * 1.08,
			"sorpresa: il sopracciglio SUPERA il bersaglio (%.3f > %.3f)"
			% [massimo, bersaglio])
	for f in 150:
		face.update(1.0 / 60.0)
	var fermo: float = (rig["brows"][0] as Node3D).position.y - base_y
	t.ok(absf(fermo - bersaglio) < 0.02,
			"sorpresa: e poi si assesta sul bersaglio (%.3f ~ %.3f)"
			% [fermo, bersaglio])

	# l'asimmetria del flick: sul curioso i due lati devono divergere
	var rig2 := _build_rig(t, fc)
	var face2 = fc.new()
	face2.setup(rig2)
	face2.freeze_blink(60.0)
	face2.set_expression("curioso", 1.0)
	var scarto := 0.0
	for f in 150:
		face2.update(1.0 / 60.0)
		scarto = maxf(scarto, absf(
				(rig2["brows"][0] as Node3D).position.y \
				- (rig2["brows"][1] as Node3D).position.y))
	t.ok(scarto > 0.008,
			"curioso: il flick rompe la simmetria dei sopraccigli (%.4f)" % scarto)


# Le bocche INTERE: niente più cavità esterna sovrapposta — su grin/o/O la
# palla scura di mouth_open resta spenta e respira la loro "apertura"
func _test_bocche_intere(t, fc: GDScript, rig: Dictionary) -> void:
	for shape in ["grin", "o", "O"]:
		var node: Node3D = rig["mouths"][shape]
		t.ok(node.get_node_or_null("apertura") != null,
				"%s: la bocca porta con sé cavo e linguetta" % shape)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("gioia", 1.0)   # grin + mouth_open 0.45
	for f in 40:
		face.update(0.016)
	t.ok(not (rig["mouth_open"] as Node3D).visible,
			"gioia: la cavità esterna resta SPENTA (era la seconda bocca)")
	face.set_expression("sorpresa", 1.0)   # "O" + mouth_open 0.6
	for f in 40:
		face.update(0.016)
	t.ok(not (rig["mouth_open"] as Node3D).visible,
			"sorpresa: idem sull'anellone 'O'")
	face.set_expression("neutro", 1.0)
	face.set_talking(true)
	for f in 40:
		face.update(0.016)
	t.ok((rig["mouth_open"] as Node3D).visible,
			"parlato su bocca neutra: la cavità esterna serve ancora")
	face.set_talking(false)
