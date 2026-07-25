extends SceneTree
## Smoke test headless del FaceController: costruisce un rig sintetico con gli
## helper statici, monta il controller e lo fa girare per un po' di frame
## esercitando ogni espressione, lo sguardo, il parlato e l'ammicco.
##   Godot --headless --path . --script res://tests/face_smoke.gd


func _initialize() -> void:
	var FC := load("res://scenes/characters/FaceController.gd")
	if FC == null or not (FC is GDScript) or not FC.can_instantiate():
		push_error("FaceController: errore di parse")
		quit(1)
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a1d1d")

	var head := Node3D.new()
	get_root().add_child(head)

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
		var sm := SphereMesh.new()
		ball.mesh = sm
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
		happy.append(FC.build_happy_arc(head, mat, Vector3(side * 0.155, 0.03, -0.36), side))
		brows.append(FC.build_brow(head, mat, side, Vector3(side * 0.15, 0.16, -0.36)))
		var bl := MeshInstance3D.new()
		bl.mesh = SphereMesh.new()
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(1, 0.6, 0.7, 0.6)
		bl.material_override = bm
		head.add_child(bl)
		blush.append(bl)

	var mouths: Dictionary = FC.build_mouth_set(head, mat, Vector3(0, -0.1, -0.408))
	var mouth_open: Node3D = FC.build_mouth_open(head, mat, Vector3(0, -0.1, -0.408))

	# la curvatura: uno smile deve essere ∪ (angoli PIÙ IN ALTO del centro),
	# un frown ∩ (angoli più in basso). Regressione del bug "bocca capovolta".
	var curve := func(shape: String) -> float:
		var node: Node3D = mouths[shape]
		var kids := node.get_children()
		var corner: float = maxf((kids[0] as Node3D).position.y,
				(kids[kids.size() - 1] as Node3D).position.y)
		var center: float = (kids[kids.size() / 2] as Node3D).position.y
		return corner - center   # >0 = ∪ (sorriso), <0 = ∩ (broncio)
	if curve.call("smile") <= 0.0:
		push_error("smile NON è ∪ (bocca capovolta): %.3f" % curve.call("smile"))
		quit(1); return
	if curve.call("frown") >= 0.0:
		push_error("frown NON è ∩: %.3f" % curve.call("frown"))
		quit(1); return
	print("MOUTH_CURVE ok smile=%.3f frown=%.3f" % [curve.call("smile"), curve.call("frown")])

	var face = FC.new()
	face.setup({
		"head": head, "eyes": eyes, "eyeballs": eyeballs, "irises": irises,
		"happy": happy, "brows": brows, "blush": blush,
		"mouths": mouths, "mouth_open": mouth_open,
		"eye_base_scale": Vector3(1, 1.18, 0.55), "face_side": 0.36,
	})

	var target := Node3D.new()
	target.position = Vector3(1, 1, -2)
	get_root().add_child(target)
	face.look_at_node(target)

	var exprs: Array = FC.EXPRESSIONS.keys()
	var frames := 0
	for e in exprs:
		face.set_expression(e, 1.0)
		face.set_talking(frames % 2 == 0)
		for f in 30:
			face.update(0.016)
			frames += 1
	# umori del Chibiese
	for mood in ["neutro", "felice", "domanda", "triste"]:
		face.set_mood(mood)
		for f in 10:
			face.update(0.016)
	# impulso transitorio + freeze
	face.pulse("sorpresa", 0.3)
	face.freeze_blink(10.0)
	for f in 40:
		face.update(0.016)

	print("FACE_SMOKE_OK frames=", frames)
	quit(0)
