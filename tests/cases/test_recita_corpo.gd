extends RefCounted
## La recita del corpo: le posture della ribellione finalmente ADDOSSO ai
## chibi. Verifica:
##  • FONTE UNICA: ogni postura del TELEGRAFO di Animo esiste in
##    Visitor.RECITA (una scala che telegrafa una posa mai renderizzata
##    era il buco più prezioso del gioco);
##  • i transitori dei sussulti (esita/trasalisce/si_illumina) esistono
##    in RECITA_TRANS e si spengono da soli (inviluppo che muore);
##  • la semantica delle pose: spalle_basse = orecchie giù e mento giù,
##    testa_alta = mento su e orecchie su, petto_in_fuori = schiena
##    indietro, braccia_conserte = incrocio SPECCHIATO sui due lati,
##    fagotto = braccio destro alzato a reggere il bastone;
##  • il fagotto è un oggetto vero (bastone+sacchetto+nodo+fiocco);
##  • END-TO-END: un Visitor vero, costruito dal DNA, legge il meta
##    "postura" scritto da Visitors e il suo corpo CAMBIA — orecchie giù
##    per spalle_basse, mento su per testa_alta — e il transitorio si
##    consuma (il meta torna alla postura stabile);
##  • il pattern togli/riapplica non accumula: cento frame di idle non
##    fanno derivare i canali.

const VISITOR := "res://scenes/npc/Visitor.gd"
const ANIMO := "res://scenes/npc/Animo.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"


func run(t) -> void:
	var vs: GDScript = load(VISITOR)
	var an: GDScript = load(ANIMO)
	t.ok(vs != null and vs.can_instantiate(), "Visitor.gd compila")
	if vs == null or not vs.can_instantiate():
		return

	_test_fonte_unica(t, vs, an)
	_test_semantica(t, vs)
	_test_transitori(t, vs)
	_test_fagotto(t, vs)
	_test_end_to_end(t, vs)


func _test_fonte_unica(t, vs: GDScript, an: GDScript) -> void:
	for gradino in an.TELEGRAFO:
		var postura := str((an.TELEGRAFO[gradino] as Array)[0])
		t.ok((vs.RECITA as Dictionary).has(postura),
				"la postura del telegrafo '%s' ha la sua RECITA" % postura)
	for tr in ["esita", "trasalisce", "si_illumina"]:
		t.ok((vs.RECITA_TRANS as Dictionary).has(tr),
				"il transitorio '%s' ha la sua recita" % tr)


func _test_semantica(t, vs: GDScript) -> void:
	var b: Dictionary = vs.recita_bersagli("spalle_basse", "", 0.0, 0.0)
	t.ok(float(b["ear"]) > 0.0 and float(b["hx"]) > 0.0 and float(b["vx"]) > 0.0,
			"spalle_basse: orecchie giù, mento giù, schiena curva")
	b = vs.recita_bersagli("testa_alta", "", 0.0, 0.0)
	t.ok(float(b["ear"]) < 0.0 and float(b["hx"]) < 0.0,
			"testa_alta: mento su e orecchie su")
	b = vs.recita_bersagli("petto_in_fuori", "", 0.0, 0.0)
	t.ok(float(b["vx"]) < 0.0 and float(b["ear"]) < 0.0,
			"petto_in_fuori: schiena indietro, orecchie all'erta")
	b = vs.recita_bersagli("braccia_conserte", "", 0.0, 0.0)
	t.ok(float(b["az0"]) > 0.0 and float(b["az1"]) < 0.0,
			"braccia_conserte: l'incrocio è SPECCHIATO sui due lati")
	t.almost(float(b["az0"]), -float(b["az1"]), "…e perfettamente simmetrico")
	b = vs.recita_bersagli("fagotto_in_spalla", "", 0.0, 0.0)
	t.ok(float(b["ax1"]) < -1.5,
			"fagotto: il braccio destro si alza a reggere il bastone")
	t.ok(float(b["ax0"]) > -0.5, "…ma il sinistro resta giù")
	b = vs.recita_bersagli("distratto", "", 0.0, 2.0)
	t.ok(absf(float(b["hy"])) > 0.05, "distratto: lo sguardo vaga (hy vivo)")
	b = vs.recita_bersagli("sereno", "", 0.0, 0.0)
	var quiete := true
	for c in b:
		if absf(float(b[c])) > 0.0001:
			quiete = false
	t.ok(quiete, "sereno: il corpo è in quiete, nessun offset")


func _test_transitori(t, vs: GDScript) -> void:
	# trasalisce: attacco istantaneo (orecchie SU forte)…
	var b: Dictionary = vs.recita_bersagli("sereno", "trasalisce", 0.02, 0.0)
	t.ok(float(b["ear"]) < -0.5, "trasalisce: le orecchie schizzano su (%.2f)" % b["ear"])
	t.ok(float(b["vy"]) > 0.0, "…col sobbalzo del corpo")
	# …e si spegne prima della fine
	var fine: Dictionary = vs.recita_bersagli("sereno", "trasalisce", 1.25, 0.0)
	t.ok(absf(float(fine["ear"])) < 0.05,
			"trasalisce: a fine corsa non resta quasi nulla (%.3f)" % fine["ear"])
	# si_illumina rimbalza a metà e muore in fondo
	var meta: Dictionary = vs.recita_bersagli("sereno", "si_illumina", 0.9, 0.0)
	t.ok(float(meta["ear"]) < -0.3, "si_illumina: orecchie su a metà corsa")
	var chiusa: Dictionary = vs.recita_bersagli("sereno", "si_illumina", 1.79, 0.0)
	t.ok(absf(float(chiusa["ear"])) < 0.06, "si_illumina: e si spegne dolce")
	# il transitorio si somma alla postura stabile, non la sostituisce
	var somma: Dictionary = vs.recita_bersagli("spalle_basse", "trasalisce", 0.02, 0.0)
	t.ok(float(somma["vx"]) > 0.0,
			"il sussulto NON cancella la schiena curva di spalle_basse")


func _test_fagotto(t, vs: GDScript) -> void:
	var fagotto: Node3D = vs.fai_fagotto()
	t.stage(fagotto)
	var pezzi := 0
	for c in fagotto.get_children():
		if c is MeshInstance3D:
			pezzi += 1
	t.ok(pezzi >= 5, "il fagotto è un oggetto vero: bastone, sacco, nodo, fiocco (%d)" % pezzi)
	t.ok(bool((vs.RECITA["fagotto_in_spalla"] as Dictionary).get("fagotto", false)),
			"la postura fagotto_in_spalla lo indossa")


func _test_end_to_end(t, vs: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	var v = vs.new()
	v.dna = dna_s.generate(4242)
	t.stage(v)
	# il rig è nato dal DNA
	t.eq((v._c_ears as Array).size(), 2, "il villager ha le sue orecchie")
	var ear_base: float = (v._c_ears[0] as Node3D).rotation.x

	# Visitors scrive il meta (come fa il telegrafo): il corpo DEVE cambiare
	v.set_meta("postura", "spalle_basse")
	for f in 90:
		v._process(1.0 / 60.0)
	var ear_giu: float = (v._c_ears[0] as Node3D).rotation.x
	t.ok(ear_giu > ear_base + 0.3,
			"spalle_basse: le orecchie sono DAVVERO giù (%.2f → %.2f)"
			% [ear_base, ear_giu])

	v.set_meta("postura", "testa_alta")
	for f in 120:
		v._process(1.0 / 60.0)
	t.ok((v._head as Node3D).rotation.x < -0.1,
			"testa_alta: il mento è DAVVERO su (%.2f)" % (v._head as Node3D).rotation.x)

	# il transitorio si consuma: il meta torna alla postura stabile
	v.set_meta("postura", "trasalisce")
	v._process(1.0 / 60.0)
	t.eq(str(v.get_meta("postura")), "testa_alta",
			"il sussulto si consuma e il meta torna alla postura stabile")

	# il fagotto compare con la diserzione
	v.set_meta("postura", "fagotto_in_spalla")
	for f in 30:
		v._process(1.0 / 60.0)
	t.ok(v._fagotto != null and is_instance_valid(v._fagotto),
			"la diserzione mette il fagotto sulla spalla")
	v.set_meta("postura", "sereno")
	for f in 30:
		v._process(1.0 / 60.0)
	t.ok(v._fagotto == null, "tornato sereno, il fagotto se ne va")

	# niente accumuli: cento frame di sereno riportano il rig quasi a zero
	for f in 200:
		v._process(1.0 / 60.0)
	t.almost((v._c_ears[0] as Node3D).rotation.x, ear_base,
			"il pattern togli/riapplica non deriva (orecchie a riposo)", 0.03)