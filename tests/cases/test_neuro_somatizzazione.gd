extends RefCounted
## Test della somatizzazione procedurale dei neurotrasmettitori per:
## 1. FaceController.gd (corrugatore, dilatazione pupillare, blush, inclinazione sopracciglia, saccadi/focus)
## 2. Andatura.gd (altezza rimbalzo hop, inclinazione busto, scodinzolio e ritardo punta coda)

const FACE := "res://scenes/characters/FaceController.gd"
const ANDATURA := "res://scenes/npc/Andatura.gd"


func run(t) -> void:
	var fc_script: GDScript = load(FACE)
	t.ok(fc_script != null and fc_script.can_instantiate(), "FaceController.gd compila")
	var and_script: GDScript = load(ANDATURA)
	t.ok(and_script != null and and_script.can_instantiate(), "Andatura.gd compila")
	if fc_script == null or and_script == null:
		return

	_test_face_neuro_corrugatore_e_pupilla(t, fc_script)
	_test_face_neuro_ossitocina_blush(t, fc_script)
	_test_face_neuro_serotonina_sopracciglia(t, fc_script)
	_test_face_neuro_dopamina_sguardo(t, fc_script)
	_test_face_api_limbico(t, fc_script)

	_test_andatura_hop_dopamina_adenosina(t, and_script)
	_test_andatura_postura_busto(t, and_script)
	_test_andatura_scodinzolio_serotonina(t, and_script)
	_test_andatura_api_limbico(t, and_script)


# --- Helper rig sintetico per FaceController ---
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

	return {
		"head": head, "eyes": eyes, "eyeballs": eyeballs, "irises": irises,
		"happy": happy, "brows": brows, "blush": blush,
		"mouths": mouths, "mouth_open": mouth_open,
		"eye_base_scale": Vector3(1, 1.18, 0.55), "face_side": 0.36,
	}


func _test_face_neuro_corrugatore_e_pupilla(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("neutro", 1.0)

	# Baseline: cortisolo = 0.0
	for f in 30:
		face.update(0.016)
	var base_sq: float = face._c_brow_sq
	var base_pupil: float = face._c_pupil
	t.almost(base_sq, 0.0, "a riposo il corrugatore è rilassato", 0.01)
	t.almost(base_pupil, 1.0, "a riposo la pupilla è neutra", 0.02)

	# Alto cortisolo: allarme/stress acuto
	face.cortisolo = 1.0
	for f in 40:
		face.update(0.016)
	t.ok(face._c_brow_sq > base_sq + 0.03,
			"alto cortisolo: il corrugatore si contrae verso il centro (%.4f > %.4f)"
			% [face._c_brow_sq, base_sq])
	t.ok(face._c_pupil < base_pupil - 0.15,
			"alto cortisolo: la pupilla si restringe per allarme/stress (%.3f < %.3f)"
			% [face._c_pupil, base_pupil])

	# Reset
	face.reset_neuro()
	for f in 40:
		face.update(0.016)
	t.almost(face._c_brow_sq, 0.0, "il reset ripristina il corrugatore", 0.01)


func _test_face_neuro_ossitocina_blush(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("neutro", 1.0)

	for f in 30:
		face.update(0.016)
	var base_blush: float = face._c_blush
	var base_pupil: float = face._c_pupil

	# Alta ossitocina (calore sociale / affetto / bonding)
	face.ossitocina = 1.0
	for f in 40:
		face.update(0.016)

	t.ok(face._c_blush > base_blush + 0.25,
			"alta ossitocina: blush passivo caldo sulle guance (%.3f > %.3f)"
			% [face._c_blush, base_blush])
	t.ok(face._c_pupil > base_pupil + 0.12,
			"alta ossitocina: dilatazione pupillare da empatia/affetto (%.3f > %.3f)"
			% [face._c_pupil, base_pupil])


func _test_face_neuro_serotonina_sopracciglia(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("neutro", 1.0)

	# Bassa serotonina = depressione / malinconia / tono basso
	face.serotonina = 0.0
	for f in 50:
		face.update(0.016)
	var ang_bassa: float = face._c_brow_ang
	t.ok(ang_bassa < -0.025,
			"bassa serotonina: inclinazione malinconica a V rovesciata (%.4f < -0.025)"
			% ang_bassa)

	# Alta serotonina = serenità e fiducia
	face.serotonina = 1.0
	for f in 50:
		face.update(0.016)
	var ang_alta: float = face._c_brow_ang
	t.ok(ang_alta > ang_bassa + 0.05,
			"alta serotonina: sguardo sereno e aperto (%.4f > %.4f)"
			% [ang_alta, ang_bassa])


func _test_face_neuro_dopamina_sguardo(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	var target := t.stage(Node3D.new()) as Node3D
	target.position = Vector3(0.5, 0.2, -1.5)
	face.look_at_node(target)

	# Alta dopamina: focus tenace, dilatazione pupillare
	face.dopamina = 1.0
	for f in 40:
		face.update(0.016)
	t.ok(face._c_pupil > 1.05,
			"alta dopamina: dilatazione pupillare da attenzione/ricompensa (%.3f > 1.05)"
			% face._c_pupil)

	# Verifica che lo sguardo insegua senza salti infiniti o NaN
	t.ok(not face._gaze_cur.is_zero_approx(), "lo sguardo è agganciato al bersaglio")
	t.ok(absf(face._gaze_cur.x) <= 1.0 and absf(face._gaze_cur.y) <= 1.0,
			"lo sguardo resta nei limiti anatomici normalizzati")


func _test_face_api_limbico(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)

	# Dizionario con chiavi italiane e inglesi
	face.set_neuro({"dopamine": 0.8, "serotonin": 0.2, "oxytocin": 0.7, "cortisol": 0.9})
	t.almost(face.dopamina, 0.8, "set_neuro imposta dopamine", 0.001)
	t.almost(face.serotonina, 0.2, "set_neuro imposta serotonin", 0.001)
	t.almost(face.ossitocina, 0.7, "set_neuro imposta oxytocin", 0.001)
	t.almost(face.cortisolo, 0.9, "set_neuro imposta cortisol", 0.001)

	# Integrazione con oggetto finto simile a Limbico
	var finto_limbico := {"arousal": 0.65, "umore": -0.5}
	face.set_neuro(finto_limbico)
	t.almost(face.cortisolo, 0.65, "arousal mappa su cortisolo", 0.001)
	t.almost(face.serotonina, 0.25, "umore -0.5 mappa su serotonina 0.25", 0.001)


# --- Test Andatura ---
func _build_andatura(t, and_script: GDScript):
	var a = and_script.new()
	var vis := t.stage(Node3D.new()) as Node3D
	var testa := Node3D.new()
	var braccia: Array[Node3D] = [Node3D.new(), Node3D.new()]
	var gambe: Array[Node3D] = [Node3D.new(), Node3D.new()]
	var orecchie: Array[Node3D] = [Node3D.new(), Node3D.new()]
	var coda := Node3D.new()
	var coda_punta := Node3D.new()
	vis.add_child(testa)
	for b in braccia: vis.add_child(b)
	for g in gambe: vis.add_child(g)
	for o in orecchie: vis.add_child(o)
	vis.add_child(coda)
	coda.add_child(coda_punta)

	a.parti({
		"head": testa, "arms": braccia, "legs": gambe,
		"ears": orecchie, "tail": coda, "tail_tip": coda_punta
	}, vis)
	return a


func _test_andatura_hop_dopamina_adenosina(t, and_script: GDScript) -> void:
	# Andatura A: alta dopamina, riposato (adenosina = 0)
	var a_dopa = _build_andatura(t, and_script)
	a_dopa.dopamina = 1.0
	a_dopa.adenosina = 0.0

	# Andatura B: bassa dopamina, esausto (adenosina = 1.0)
	var a_fatica = _build_andatura(t, and_script)
	a_fatica.dopamina = 0.0
	a_fatica.adenosina = 1.0

	var max_hop_dopa := -INF
	var max_hop_fatica := -INF

	for f in 60:
		var pos := Vector3(float(f) * 0.025, 0, 0)
		a_dopa.misura(0.016, pos, 0.0)
		a_dopa.applica()
		max_hop_dopa = maxf(max_hop_dopa, a_dopa.vis.position.y)

		a_fatica.misura(0.016, pos, 0.0)
		a_fatica.applica()
		max_hop_fatica = maxf(max_hop_fatica, a_fatica.vis.position.y)

	t.ok(max_hop_dopa > max_hop_fatica * 1.8,
			"la dopamina aumenta il rimbalzo rispetto alla fatica/adenosina (%.4f > %.4f)"
			% [max_hop_dopa, max_hop_fatica])


func _test_andatura_postura_busto(t, and_script: GDScript) -> void:
	# Andatura con alto stress/depressione (alto cortisolo, bassa serotonina)
	var a_curva = _build_andatura(t, and_script)
	a_curva.cortisolo = 1.0
	a_curva.serotonina = 0.0

	# Andatura fiera/serena (basso cortisolo, alta serotonina)
	var a_fiera = _build_andatura(t, and_script)
	a_fiera.cortisolo = 0.0
	a_fiera.serotonina = 1.0

	for f in 40:
		var pos := Vector3(float(f) * 0.02, 0, 0)
		a_curva.misura(0.016, pos, 0.0)
		a_curva.applica()
		a_fiera.misura(0.016, pos, 0.0)
		a_fiera.applica()

	t.ok(a_curva.vis.rotation.x < a_fiera.vis.rotation.x - 0.25,
			"alto cortisolo e bassa serotonina curvano il busto in avanti (%.3f vs %.3f rad)"
			% [a_curva.vis.rotation.x, a_fiera.vis.rotation.x])


func _test_andatura_scodinzolio_serotonina(t, and_script: GDScript) -> void:
	# Alta serotonina: scodinzolio vivace e ampio, coda sollevata
	var a_alta = _build_andatura(t, and_script)
	a_alta.serotonina = 1.0

	# Bassa serotonina: scodinzolio spento e coda abbassata
	var a_bassa = _build_andatura(t, and_script)
	a_bassa.serotonina = 0.0

	var max_wag_alta := -INF
	var max_wag_bassa := -INF

	for f in 80:
		var pos := Vector3(float(f) * 0.02, 0, 0)
		a_alta.misura(0.016, pos, 0.0)
		a_alta.applica()
		max_wag_alta = maxf(max_wag_alta, absf(a_alta.coda.rotation.y))

		a_bassa.misura(0.016, pos, 0.0)
		a_bassa.applica()
		max_wag_bassa = maxf(max_wag_bassa, absf(a_bassa.coda.rotation.y))

	t.ok(max_wag_alta > max_wag_bassa * 1.5,
			"alta serotonina: scodinzolio più ampio (%.3f > %.3f)"
			% [max_wag_alta, max_wag_bassa])
	t.ok(a_alta.coda.rotation.x > a_bassa.coda.rotation.x + 0.15,
			"alta serotonina: coda più alta e fiera (%.3f > %.3f)"
			% [a_alta.coda.rotation.x, a_bassa.coda.rotation.x])


func _test_andatura_api_limbico(t, and_script: GDScript) -> void:
	var a = _build_andatura(t, and_script)
	a.set_neuro({"dopamine": 0.9, "serotonin": 0.8, "fatica": 0.4, "cortisol": 0.3})
	t.almost(a.dopamina, 0.9, "set_neuro imposta dopamina", 0.001)
	t.almost(a.serotonina, 0.8, "set_neuro imposta serotonina", 0.001)
	t.almost(a.adenosina, 0.4, "set_neuro imposta fatica/adenosina", 0.001)
	t.almost(a.cortisolo, 0.3, "set_neuro imposta cortisolo", 0.001)

	a.reset_neuro()
	t.almost(a.dopamina, 0.5, "reset ripristina dopamina a 0.5", 0.001)
	t.almost(a.serotonina, 0.5, "reset ripristina serotonina a 0.5", 0.001)
	t.almost(a.adenosina, 0.0, "reset ripristina adenosina a 0.0", 0.001)
	t.almost(a.cortisolo, 0.0, "reset ripristina cortisolo a 0.0", 0.001)
