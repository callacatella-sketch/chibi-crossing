extends SceneTree
## Smoke test headless di Mochi col nuovo volto vivo: la costruisce, la mette
## in scena e la fa girare esercitando pose, soffio, stanchezza, saluto, gioia
## e la lettura della letterina — così un errore a runtime nella pipeline
## facciale esce subito, senza aprire l'editor.
##   Godot --headless --path . --script res://tests/mochi_smoke.gd


func _initialize() -> void:
	var M := load("res://scenes/characters/Mochi.gd")
	if M == null or not (M is GDScript) or not M.can_instantiate():
		push_error("Mochi: errore di parse")
		quit(1)
		return

	var mochi = M.new()
	get_root().add_child(mochi)
	# in un runner SceneTree "--script" il _ready differito non scatta prima
	# della prima iterazione: lo forziamo qui (nel gioco vero scatta normale)
	if mochi._head == null:
		mochi._ready()

	# il volto è stato montato?
	var ok := true
	if mochi._face == null: push_error("_face nullo"); ok = false
	if mochi._eyes.size() != 2: push_error("occhi: %d" % mochi._eyes.size()); ok = false
	if mochi._eyeballs.size() != 2: push_error("eyeballs: %d" % mochi._eyeballs.size()); ok = false
	if mochi._brows.size() != 2: push_error("sopracciglia: %d" % mochi._brows.size()); ok = false
	if mochi._happy.size() != 2: push_error("archi felici: %d" % mochi._happy.size()); ok = false
	if mochi._mouths.size() < 6: push_error("bocche: %d" % mochi._mouths.size()); ok = false
	if not ok:
		quit(1)
		return
	print("FACE_WIRED eyes=", mochi._eyes.size(), " brows=", mochi._brows.size(),
			" mouths=", mochi._mouths.size())

	var step := func(n: int) -> void:
		for i in n:
			mochi._process(0.016)

	step.call(20)

	# l'espressione "dorme" chiude davvero gli occhi (apertura piccola)?
	mochi.set_pose("sleep")
	step.call(40)
	var ap: float = mochi._eyeballs[0].scale.y
	print("apertura occhio dormendo (scala.y) = ", ap)
	if ap > 0.35:
		push_error("gli occhi non si chiudono nel sonno (%.2f)" % ap)
		quit(1)
		return
	mochi.set_pose("stand")
	step.call(40)
	var ap2: float = mochi._eyeballs[0].scale.y
	print("apertura occhio da sveglia (scala.y) = ", ap2)

	# pose
	for pose in ["sit", "sleep", "stargaze", "soak", "stand"]:
		mochi.set_pose(pose)
		step.call(30)

	# soffio sulla tazza
	mochi.hold_cup(true)
	mochi.start_blowing()
	step.call(20)
	mochi.stop_blowing()
	mochi.hold_cup(false)
	step.call(10)

	# stanchezza + guanciotte al massimo
	mochi.set_tired(true)
	mochi.set_blush_max(true)
	step.call(30)
	mochi.set_tired(false)
	mochi.set_blush_max(false)
	step.call(10)

	# saluto + gioia
	mochi.wave()
	step.call(30)
	mochi.joy = 1.0
	step.call(20)
	mochi.joy = 0.0

	# la letterina: lettura riga per riga fino alla firma
	mochi.hold_letter(true)
	for k in 20:
		mochi.pour = float(k) / 19.0
		step.call(3)
	mochi.hold_letter(false)
	step.call(10)

	# freeze del volto (usato dal DebugHarness)
	mochi.freeze_face(10.0)
	step.call(10)

	# nota: l'anomalia (lato horror) usa get_viewport().get_camera_3d(), che
	# in un runner headless "--script" non esiste — la si prova nel gioco vero.

	print("MOCHI_SMOKE_OK")
	quit(0)
