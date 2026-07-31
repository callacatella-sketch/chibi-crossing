extends RefCounted
## Il salto della trota: l'indizio del bestiario («salta dove la cascata
## spumeggia») finalmente mantenuto. Verifica headless:
##  • la PARABOLA è giusta: parte dal pelo, tocca l'apice richiesto a metà
##    volo, rientra al pelo alla durata calcolata — mai un pesce che
##    resta a mezz'aria o sprofonda;
##  • il salto punta CONTROCORRENTE (verso il velo: +x della pozza);
##  • la cadenza promessa: 20–40 secondi tra un salto e l'altro;
##  • la pozza sta DOVE spumeggia la cascata: x da WorldMath.river_x(FALL_Z)
##    e z = FALL_Z (fonte unica, mai coordinate ricopiate);
##  • la livrea è QUELLA del bestiario (Critters.SPECIE["trota"].colore):
##    la trota che vedi saltare è quella che peschi;
##  • il pesce è un modellino vero (corpo+fascia+coda su pivot+dorsale)
##    col ventre metallico che prende la luce, e nasce nascosto;
##  • il bestiario comanda: il salto passa da Critters.disponibile;
##  • CozyWorld monta l'emitter dopo il fiume.

const SALTO := "res://scenes/world/SaltoTrota.gd"
const MATHS := "res://scenes/world/WorldMath.gd"
const CRITTERS := "res://scenes/world/Critters.gd"


func run(t) -> void:
	var s: GDScript = load(SALTO)
	t.ok(s != null and s.can_instantiate(), "SaltoTrota.gd compila")
	if s == null or not s.can_instantiate():
		return

	_test_parabola(t, s)
	_test_cadenza(t, s)
	_test_posa_e_livrea(t, s)
	_test_salto_vivo(t, s)
	_test_cablaggio(t)


func _test_parabola(t, s: GDScript) -> void:
	var g := 6.5
	var apice := 0.9
	var dur: float = s.durata_salto(apice, g)
	var vy := sqrt(2.0 * g * apice)
	var start := Vector3(1, 0, 2)
	var vel := Vector3(0.4, vy, 0.1)
	var inizio: Vector3 = s.punto_salto(start, vel, g, 0.0)
	t.eq(inizio, start, "a t=0 il pesce è al pelo dell'acqua")
	var colmo: Vector3 = s.punto_salto(start, vel, g, dur * 0.5)
	t.almost(colmo.y - start.y, apice, "a metà volo tocca l'apice richiesto", 0.01)
	var fine: Vector3 = s.punto_salto(start, vel, g, dur)
	t.almost(fine.y, start.y, "alla durata calcolata rientra al pelo", 0.01)
	t.ok(fine.x > start.x, "…e ha viaggiato in avanti (l'arco, non la fontana)")


func _test_cadenza(t, s: GDScript) -> void:
	t.almost(float(s.ATTESA_MIN), 20.0, "cadenza minima: 20 s")
	t.almost(float(s.ATTESA_MAX), 40.0, "cadenza massima: 40 s")
	t.ok(float(s.PROB_DOPPIO) > 0.0 and float(s.PROB_DOPPIO) < 0.5,
			"il doppio salto dell'ostinata è raro ma esiste")


func _test_posa_e_livrea(t, s: GDScript) -> void:
	var math: GDScript = load(MATHS)
	var trota = t.stage(s.new())
	t.almost(trota.position.z, float(math.FALL_Z),
			"la pozza sta alla Z della cascata (fonte unica)", 0.001)
	# LA FONTE E' `cliff_x`, NON `river_x`. Questo test certificava il
	# valore sbagliato: la cascata la posa CozyWorld con `cliff_x - 0.55`, e
	# per definizione `cliff_x(FALL_Z) = river_x(FALL_Z) + 2.9` — la trota
	# saltava quasi tre metri lontano dalla schiuma che l'indizio del
	# bestiario le attribuisce.
	t.almost(trota.position.x,
			float(math.cliff_x(math.FALL_Z)) - 0.55 - float(s.RIENTRO_POZZA),
			"…e alla X della CASCATA, rientrata dentro la pozza", 0.001)
	t.ok(absf(trota.position.x - (float(math.cliff_x(math.FALL_Z)) - 0.55)) < 2.0,
			"il guizzo sta dentro la pozza, non a mezzo fiume di distanza")
	t.ok(not trota._pesce.visible, "tra un salto e l'altro il pesce non c'è")

	var critters: GDScript = load(CRITTERS)
	var livrea: Color = critters.SPECIE["trota"]["colore"]
	var pezzi := 0
	var pivot_coda := false
	for c in trota._pesce.get_children():
		if c is MeshInstance3D:
			pezzi += 1
		elif c is Node3D and c.get_child_count() == 2:
			pivot_coda = true
	t.ok(pezzi >= 3, "il modellino è vero: corpo, fascia, dorsale (%d)" % pezzi)
	t.ok(pivot_coda, "la coda a due lobi vive su un pivot (il colpo di coda)")
	t.ok(trota._corpo_mat.metallic > 0.5, "il ventre è argento vivo (metallico)")
	var fascia_ok := false
	for c in trota._pesce.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D \
				and (mi.material_override as StandardMaterial3D).albedo_color \
				.is_equal_approx(livrea):
			fascia_ok = true
	t.ok(fascia_ok, "la livrea è QUELLA del bestiario (stessa trota che peschi)")


func _test_salto_vivo(t, s: GDScript) -> void:
	var trota = t.stage(s.new())
	trota._salta(false)
	t.ok(trota._pesce.visible, "al via il pesce esce dall'acqua")
	var vel: Vector3 = trota._salto["vel"]
	t.ok(vel.x > 0.0, "il salto punta CONTROCORRENTE, verso il velo")
	t.ok(vel.y > 1.5, "…e verso l'alto")
	# il volo intero, frame a frame: niente errori, poi l'ammaraggio
	var passi := int(float(trota._salto["dur"]) / 0.016) + 2
	for f in passi:
		trota._process(0.016)
	t.ok(trota._salto.is_empty(), "il volo si conclude da solo")
	t.ok(not trota._pesce.visible, "e il pesce è rientrato nell'acqua")
	# il percorso VERO del timer: allo scatto la cadenza si riarma 20-40
	trota._cd = 0.01
	trota._process(0.02)
	t.ok(not trota._salto.is_empty(), "allo scadere del timer si salta")
	t.ok(trota._cd >= float(s.ATTESA_MIN) and trota._cd <= float(s.ATTESA_MAX),
			"e la cadenza si riarma fra 20 e 40 s (%.1f)" % trota._cd)


func _test_cablaggio(t) -> void:
	var cozy := FileAccess.get_file_as_string("res://scenes/world/CozyWorld.gd")
	t.ok(cozy.contains("SaltoTrota.gd"), "CozyWorld monta il salto della trota")
	var sorgente := FileAccess.get_file_as_string(SALTO)
	t.ok(sorgente.contains("disponibile"),
			"il salto obbedisce al bestiario (Critters.disponibile)")
	t.ok(sorgente.contains("water_ripple"),
			"lo splash usa le increspature VERE del fiume")
	t.ok(sorgente.contains("plop"), "e il plop di Sfx")