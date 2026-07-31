extends RefCounted
## La camminata dei Visitor, portata alla specie di Mochi. Su un villager
## VERO (costruito dal DNA) si verifica:
##  • NIENTE MOONWALK: la fase del passo avanza coi metri percorsi — a
##    velocità doppia, passi (circa) doppi; da fermo, fase ferma;
##  • il blend SI SPEGNE DA SOLO: fermarsi non congela le gambe a
##    mezz'aria né scatta — in un secondo il ciclo sfuma nel respiro;
##  • le braccia hanno la TORSIONE di Mochi (ruotano mentre oscillano);
##  • l'INCLINAZIONE IN CURVA: chi svolta camminando si piega dentro la
##    curva, chi va dritto no;
##  • un TELETRASPORTO non è un passo: il blend non si accende;
##  • i contratti nel sorgente: il ramo chibi usa il ciclo condiviso
##    (niente più fase a tempo fisso né passi a timer), e l'idle chibi
##    passa dallo stesso ciclo.

const VISITOR := "res://scenes/npc/Visitor.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"


func run(t) -> void:
	var vs: GDScript = load(VISITOR)
	t.ok(vs != null and vs.can_instantiate(), "Visitor.gd compila")
	if vs == null or not vs.can_instantiate():
		return

	_test_cammino_e_spegnimento(t, vs)
	_test_cadenza_dai_metri(t, vs)
	_test_curva(t, vs)
	_test_teletrasporto(t, vs)
	_test_contratti(t)


## Lo stato del passo (blend, fase, banco) vive nell'ANDATURA, che i
## vicini condividono col diorama del menù (scenes/npc/Andatura.gd). Il
## Visitor la tiene in `_andatura` e la costruisce al primo frame.
func _and(v) -> RefCounted:
	return v._andatura


func _nuovo(t, vs: GDScript):
	var dna_s: GDScript = load(DNA)
	var v = vs.new()
	v.dna = dna_s.generate(4242)
	t.stage(v)
	return v


## Muove il villager di [param passo] a frame e fa girare misura+corpo.
func _cammina(v, frames: int, passo: Vector3, giro := 0.0) -> void:
	for f in frames:
		v.global_position += passo
		v._yaw += giro / 60.0
		v._process(1.0 / 60.0)
		v._gait_chibi()


func _test_cammino_e_spegnimento(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	var lo := 99.0
	var hi := -99.0
	var torsione := 0.0
	for f in 100:
		v.global_position += Vector3(0.022, 0, 0)
		v._process(1.0 / 60.0)
		v._gait_chibi()
		lo = minf(lo, (v._c_legs[0] as Node3D).rotation.x)
		hi = maxf(hi, (v._c_legs[0] as Node3D).rotation.x)
		torsione = maxf(torsione, absf((v._c_arms[0] as Node3D).rotation.y))
	t.ok(_and(v).blend > 0.85, "in cammino il blend è acceso (%.2f)" % _and(v).blend)
	t.ok(hi - lo > 0.5, "le gambe fanno il ciclo VERO (escursione %.2f)" % (hi - lo))
	t.ok(torsione > 0.04, "le braccia hanno la torsione di Mochi (%.3f)" % torsione)

	# ci si ferma: il ciclo si SPEGNE da solo, senza scatti
	_cammina(v, 90, Vector3.ZERO)
	t.ok(_and(v).blend < 0.06, "da fermo il blend si spegne da solo (%.3f)" % _and(v).blend)
	t.ok(absf((v._c_legs[0] as Node3D).rotation.x) < 0.05,
			"…e le gambe si posano, mai congelate a mezz'aria")
	t.almost((v._c_legs[0] as Node3D).position.y, 0.16,
			"i piedini tornano a terra", 0.01)


func _test_cadenza_dai_metri(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	_cammina(v, 30, Vector3(0.022, 0, 0))     # a regime
	var da: float = _and(v).fase
	_cammina(v, 60, Vector3(0.022, 0, 0))
	var avanza_pieno: float = _and(v).fase - da

	var v2 = _nuovo(t, vs)
	_cammina(v2, 30, Vector3(0.011, 0, 0))
	var da2: float = _and(v2).fase
	_cammina(v2, 60, Vector3(0.011, 0, 0))
	var avanza_mezzo: float = _and(v2).fase - da2
	t.ok(avanza_pieno > avanza_mezzo * 1.6,
			"la fase avanza COI METRI: velocità doppia ≈ passi doppi (%.2f vs %.2f)"
			% [avanza_pieno, avanza_mezzo])

	var fermo: float = _and(v).fase
	_cammina(v, 30, Vector3.ZERO)
	t.almost(_and(v).fase, fermo, "da fermo la fase NON avanza (niente moonwalk)", 0.001)


func _test_curva(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	_cammina(v, 80, Vector3(0.02, 0, 0), 1.4)    # svolta decisa
	t.ok(_and(v).banco < -0.02,
			"in curva il corpo si PIEGA dentro (banco %.3f)" % _and(v).banco)
	_cammina(v, 80, Vector3(0.02, 0, 0), 0.0)    # rettilineo
	t.ok(absf(_and(v).banco) < 0.012,
			"in rettilineo il banco si raddrizza (%.3f)" % _and(v).banco)


func _test_teletrasporto(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	v.global_position += Vector3(5, 0, 0)     # uno snap di routine
	v._process(1.0 / 60.0)
	for f in 5:
		v._process(1.0 / 60.0)
	t.ok(_and(v).blend < 0.1, "un teletrasporto non è un passo: il blend resta spento")


func _test_contratti(t) -> void:
	var src := FileAccess.get_file_as_string(VISITOR)
	var move := src.substr(src.find("func _anim_move"))
	move = move.substr(0, move.find("func _relax_legs"))
	t.ok(move.contains("_gait_chibi()"),
			"il ramo chibi di _anim_move usa il ciclo condiviso")
	t.ok(not move.contains("_gait_ph += delta * 8.0"),
			"REGRESSIONE MOONWALK: mai più fase a tempo fisso")
	var idle := src.substr(src.find("func _anim_idle"))
	idle = idle.substr(0, idle.find("func run_plan"))
	t.ok(idle.contains("_gait_chibi()"),
			"anche l'idle chibi passa dal ciclo (lo spegnimento è SUO)")
	_test_passo_all_appoggio(t)


## IL PASSO SUONA ALL'APPOGGIO, non a timer. Era un `contains` sul
## sorgente — un controllo che resta verde anche cancellando la riga che
## conta. Adesso si fa camminare un'andatura vera con un finto Sfx in
## ascolto e si guarda QUANDO suona: i colpi devono cadere a distanza
## regolare in FASE (uno ogni mezzo ciclo), non a distanza regolare nel
## tempo — che è ciò che li rende passi invece che un metronomo.
func _test_passo_all_appoggio(t) -> void:
	var and_s: GDScript = load("res://scenes/npc/Andatura.gd")
	var a = and_s.new()
	var corpo := Node3D.new()
	a.parti({"arms": [], "legs": [], "ears": []}, corpo)
	var orecchio := _OrecchioSfx.new()
	a.sfx = orecchio
	# si cammina a velocità che CAMBIA: se il passo fosse a timer, i colpi
	# resterebbero equidistanti nel tempo mentre la falcata si allunga
	for f in 600:
		var v := 0.75 + 0.45 * sin(float(f) * 0.02)
		corpo.position.x += v / 60.0
		a.misura(1.0 / 60.0, corpo.position, 0.0)
		a.applica()
		orecchio.fasi_viste.append([a.fase, orecchio.colpi])
	t.ok(orecchio.colpi >= 8, "camminando, il passo suona (%d colpi)" % orecchio.colpi)
	# fra un colpo e l'altro deve passare mezzo ciclo di fase, sempre
	var fasi_colpo: Array = []
	var ultimo := -1
	for riga in orecchio.fasi_viste:
		if int(riga[1]) != ultimo:
			ultimo = int(riga[1])
			fasi_colpo.append(float(riga[0]))
	var peggior_scarto := 0.0
	for i in range(2, fasi_colpo.size()):
		peggior_scarto = maxf(peggior_scarto,
				absf((float(fasi_colpo[i]) - float(fasi_colpo[i - 1])) - PI))
	t.ok(peggior_scarto < 0.35,
			"i colpi cadono ogni mezzo ciclo di FASE, non a tempo (scarto %.3f)"
			% peggior_scarto)
	corpo.free()


## Un orecchio finto al posto di Sfx: conta i passi invece di suonarli.
class _OrecchioSfx:
	extends RefCounted
	var colpi := 0
	var fasi_viste: Array = []
	func play(_suono: String, _db := 0.0, _pitch := 1.0) -> void:
		colpi += 1