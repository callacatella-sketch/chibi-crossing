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
	t.ok(v._walk_f > 0.85, "in cammino il blend è acceso (%.2f)" % v._walk_f)
	t.ok(hi - lo > 0.5, "le gambe fanno il ciclo VERO (escursione %.2f)" % (hi - lo))
	t.ok(torsione > 0.04, "le braccia hanno la torsione di Mochi (%.3f)" % torsione)

	# ci si ferma: il ciclo si SPEGNE da solo, senza scatti
	_cammina(v, 90, Vector3.ZERO)
	t.ok(v._walk_f < 0.06, "da fermo il blend si spegne da solo (%.3f)" % v._walk_f)
	t.ok(absf((v._c_legs[0] as Node3D).rotation.x) < 0.05,
			"…e le gambe si posano, mai congelate a mezz'aria")
	t.almost((v._c_legs[0] as Node3D).position.y, 0.16,
			"i piedini tornano a terra", 0.01)


func _test_cadenza_dai_metri(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	_cammina(v, 30, Vector3(0.022, 0, 0))     # a regime
	var da: float = v._gait_ph
	_cammina(v, 60, Vector3(0.022, 0, 0))
	var avanza_pieno: float = v._gait_ph - da

	var v2 = _nuovo(t, vs)
	_cammina(v2, 30, Vector3(0.011, 0, 0))
	var da2: float = v2._gait_ph
	_cammina(v2, 60, Vector3(0.011, 0, 0))
	var avanza_mezzo: float = v2._gait_ph - da2
	t.ok(avanza_pieno > avanza_mezzo * 1.6,
			"la fase avanza COI METRI: velocità doppia ≈ passi doppi (%.2f vs %.2f)"
			% [avanza_pieno, avanza_mezzo])

	var fermo: float = v._gait_ph
	_cammina(v, 30, Vector3.ZERO)
	t.almost(v._gait_ph, fermo, "da fermo la fase NON avanza (niente moonwalk)", 0.001)


func _test_curva(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	_cammina(v, 80, Vector3(0.02, 0, 0), 1.4)    # svolta decisa
	t.ok(v._banco < -0.02,
			"in curva il corpo si PIEGA dentro (banco %.3f)" % v._banco)
	_cammina(v, 80, Vector3(0.02, 0, 0), 0.0)    # rettilineo
	t.ok(absf(v._banco) < 0.012,
			"in rettilineo il banco si raddrizza (%.3f)" % v._banco)


func _test_teletrasporto(t, vs: GDScript) -> void:
	var v = _nuovo(t, vs)
	v.global_position += Vector3(5, 0, 0)     # uno snap di routine
	v._process(1.0 / 60.0)
	for f in 5:
		v._process(1.0 / 60.0)
	t.ok(v._walk_f < 0.1, "un teletrasporto non è un passo: il blend resta spento")


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
	t.ok(src.contains("_passo_prev_cos"),
			"il passo suona all'appoggio, non a timer")