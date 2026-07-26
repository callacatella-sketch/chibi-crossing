extends RefCounted
## Test di Mochi col volto vivo: la costruisce, la mette in scena e la fa
## girare esercitando pose, soffio sulla tazza, stanchezza, saluto, gioia e la
## lettura della letterina — così un errore a runtime nella pipeline facciale
## esce qui, in CI, invece che aprendo l'editor.
## Controlla anche che dormendo gli occhi si CHIUDANO davvero.
## (Era tests/mochi_smoke.gd, script sciolto fuori dalla suite.)

const MOCHI := "res://scenes/characters/Mochi.gd"


func run(t) -> void:
	var ms: GDScript = load(MOCHI)
	if ms == null or not ms.can_instantiate():
		t.ok(false, "Mochi.gd non compilabile")
		return
	var mochi = t.stage(ms.new())
	# in un runner senza frame il _ready differito può non essere scattato:
	# lo forziamo (nel gioco vero scatta normalmente)
	if mochi._head == null:
		mochi._ready()
	if not _test_volto_montato(t, mochi):
		return
	_test_occhi_nel_sonno(t, mochi)
	_test_pose_e_gesti(t, mochi)


# fa girare n frame di _process a mano (nel runner non gira il main loop)
func _step(mochi, n: int) -> void:
	for i in n:
		mochi._process(0.016)


# il volto è stato montato con tutti i suoi pezzi?
func _test_volto_montato(t, mochi) -> bool:
	t.ok(mochi._face != null, "il FaceController di Mochi è montato")
	t.eq(mochi._eyes.size(), 2, "Mochi ha due occhi")
	t.eq(mochi._eyeballs.size(), 2, "Mochi ha due bulbi oculari")
	t.eq(mochi._brows.size(), 2, "Mochi ha due sopracciglia")
	t.eq(mochi._happy.size(), 2, "Mochi ha i due archi felici")
	t.ok(mochi._mouths.size() >= 6, "Mochi ha almeno 6 bocche (%d)" % mochi._mouths.size())
	return mochi._face != null and mochi._eyes.size() == 2 and mochi._eyeballs.size() == 2


# dormendo le palpebre si chiudono: la scala verticale del bulbo crolla
func _test_occhi_nel_sonno(t, mochi) -> void:
	_step(mochi, 20)
	mochi.set_pose("sleep")
	_step(mochi, 40)
	var chiuso: float = mochi._eyeballs[0].scale.y
	t.ok(chiuso <= 0.35, "dormendo gli occhi si chiudono (scala.y %.2f <= 0.35)" % chiuso)
	mochi.set_pose("stand")
	_step(mochi, 40)
	var aperto: float = mochi._eyeballs[0].scale.y
	t.ok(aperto > chiuso, "da sveglia gli occhi si riaprono (%.2f > %.2f)" % [aperto, chiuso])


# il repertorio completo: pose, tazza, stanchezza, saluto, gioia, letterina
func _test_pose_e_gesti(t, mochi) -> void:
	for pose in ["sit", "sleep", "stargaze", "soak", "stand"]:
		mochi.set_pose(pose)
		_step(mochi, 30)
	t.ok(true, "tutte le pose girano senza errori")

	mochi.hold_cup(true)
	mochi.start_blowing()
	_step(mochi, 20)
	mochi.stop_blowing()
	mochi.hold_cup(false)
	_step(mochi, 10)
	t.ok(true, "tazza e soffio girano senza errori")

	mochi.set_tired(true)
	mochi.set_blush_max(true)
	_step(mochi, 30)
	mochi.set_tired(false)
	mochi.set_blush_max(false)
	_step(mochi, 10)
	t.ok(true, "stanchezza e guanciotte girano senza errori")

	mochi.wave()
	_step(mochi, 30)
	mochi.joy = 1.0
	_step(mochi, 20)
	mochi.joy = 0.0
	t.ok(true, "saluto e gioia girano senza errori")

	# la letterina: la lettura scorre riga per riga fino alla firma
	mochi.hold_letter(true)
	for k in 20:
		mochi.pour = float(k) / 19.0
		_step(mochi, 3)
	mochi.hold_letter(false)
	_step(mochi, 10)
	t.ok(true, "la lettura della letterina gira senza errori")

	# il freeze del volto usato dal DebugHarness per gli scatti
	mochi.freeze_face(10.0)
	_step(mochi, 10)
	t.ok(true, "il freeze del volto gira senza errori")
	# nota: l'anomalia (lato horror) usa get_viewport().get_camera_3d(), che in
	# un runner headless non esiste — quella si prova nel gioco vero.
