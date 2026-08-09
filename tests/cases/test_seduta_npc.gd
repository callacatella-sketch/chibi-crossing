extends RefCounted
## La seduta degli NPC: non più secca — l'ASSESTAMENTO. Verifica:
##  • il PLOP: al sedersi si affonda, e c'è il rimbalzo (il tonfo non è
##    un gradino ma una molla che muore);
##  • il SOSPIRO: il petto si alza attorno a ~1.3s (mai subito), le
##    spalle salgono e poi si lasciano andare;
##  • la CODA si sistema con colpi decisi nei primi istanti, poi passa
##    all'ondeggio placido;
##  • a ~3 secondi è TUTTO assestato: resta solo il respiro;
##  • ci si guarda intorno solo DOPO essersi accomodati;
##  • gli anziani si assestano con più calma (il tempo scorre più lento);
##  • ogni nuova seduta RIPARTE dall'assestamento (_enter_state azzera).

const VISITOR := "res://scenes/npc/Visitor.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"


func run(t) -> void:
	var vs: GDScript = load(VISITOR)
	t.ok(vs != null and vs.can_instantiate(), "Visitor.gd compila")
	if vs == null or not vs.can_instantiate():
		return

	_test_assesto_puro(t, vs)
	_test_seduta_viva(t, vs)
	_test_reset(t, vs)


func _test_assesto_puro(t, vs: GDScript) -> void:
	var inizio: Dictionary = vs.assesto_seduta(0.0)
	t.ok(float(inizio["plop"]) < -0.02, "al sedersi si AFFONDA (%.3f)" % inizio["plop"])
	t.ok(float(inizio["sospiro"]) < 0.05, "il sospiro non parte mai subito")

	var rimbalza := false
	for i in 40:
		if float(vs.assesto_seduta(float(i) * 0.025)["plop"]) > 0.004:
			rimbalza = true
	t.ok(rimbalza, "…e c'è il RIMBALZO: una molla che muore, non un gradino")

	t.ok(float(vs.assesto_seduta(1.3)["sospiro"]) > 0.8,
			"il sospiro culmina attorno a 1.3 s")
	var coda_max := 0.0
	for i in 20:
		coda_max = maxf(coda_max, absf(float(vs.assesto_seduta(float(i) * 0.025)["coda"])))
	t.ok(coda_max > 0.2, "la coda si sistema con colpi decisi (%.2f)" % coda_max)

	var fine: Dictionary = vs.assesto_seduta(3.0)
	t.ok(absf(float(fine["plop"])) < 0.002 and absf(float(fine["fianchi"])) < 0.01 \
			and float(fine["sospiro"]) < 0.01 and absf(float(fine["coda"])) < 0.01,
			"a tre secondi è tutto assestato: resta solo il respiro")

	# l'anziano è più lento: allo stesso istante REALE è meno avanti
	t.ok(float(vs.assesto_seduta(0.5)["calo"]) < float(vs.assesto_seduta(0.5 / 1.6)["calo"]),
			"il tempo dell'assesto scorre più piano per gli anziani")


func _test_seduta_viva(t, vs: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	var v = vs.new()
	v.dna = dna_s.generate(4242)
	t.stage(v)

	# L'ISTANTE va compensato del delta del frame. `_anim_sit()` fa
	# `_sit_t += get_process_delta_time()` PRIMA di leggere l'assesto:
	# partendo da 0.0 non si misurava l'attimo del plop ma l'assesto un
	# delta più tardi — e nel runner il delta di un caso è la DURATA del
	# caso precedente (un caso per frame), cioè un numero che cambia da
	# una macchina all'altra e da un giro all'altro. A 0.13 s il plop ha
	# già quasi finito di rimbalzare (-0.005 invece di -0.035) e
	# l'asserzione diventava rossa senza che nessuno avesse toccato il
	# corpo: un falso allarme che costa un'indagine. Partendo da -delta,
	# l'istante misurato è esattamente quello scritto qui sotto.
	var dt: float = v.get_process_delta_time()

	# l'attimo del plop
	v._sit_t = 0.0 - dt
	v._t = 0.0
	v._anim_sit()
	t.ok(v._vis.position.y < -0.02,
			"appena seduto il corpo AFFONDA (%.3f)" % v._vis.position.y)
	t.ok(absf((v._head as Node3D).rotation.y) < 0.03,
			"…e non si guarda ancora intorno: si sta accomodando")

	# il sospiro a metà assestamento: le spalle si alzano
	v._sit_t = 1.3 - dt
	v._anim_sit()
	t.ok((v._c_arms[0] as Node3D).rotation.x < 0.05,
			"il sospiro alza le spalle (%.2f)" % (v._c_arms[0] as Node3D).rotation.x)

	# assestato: solo respiro, e la testolina libera di girarsi
	v._sit_t = 5.0 - dt
	v._t = 3.0
	v._anim_sit()
	t.ok(absf(v._vis.position.y) < 0.02, "assestato: resta il respiro")
	t.ok(absf((v._head as Node3D).rotation.y) > 0.05,
			"…e ora sì che ci si guarda intorno")
	t.almost((v._c_arms[0] as Node3D).rotation.x, 0.2,
			"le zampe riposano in grembo", 0.03)


func _test_reset(t, vs: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	var v = vs.new()
	v.dna = dna_s.generate(7)
	t.stage(v)
	v._sit_t = 4.0
	v._enter_state("idle")
	t.almost(v._sit_t, 0.0, "ogni nuova seduta riparte dall'assestamento", 0.001)
	var src := FileAccess.get_file_as_string(VISITOR)
	t.ok(src.contains("_sit_t = 0.0"), "il reset vive in _enter_state")