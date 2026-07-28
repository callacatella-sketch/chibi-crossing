extends RefCounted
## IL SONNO DEGLI NPC — il respiro è la differenza fra dormire ed essere
## spenti. Il pisolino era `_anim_sit()` (la posa da SEDUTO) più una "z"
## a timer; ora è un sonno vero. Verifica:
##  • IL RESPIRO ESISTE: il torace si alza e si abbassa nel tempo, con
##    ampiezza da respiro (piccola) e periodo di 5 s;
##  • È ASIMMETRICO come un torace vero: l'inspiro è più CORTO
##    dell'espiro (un sin() puro suona meccanico, ed è il difetto che
##    separa un corpo vivo da un manichino che pulsa);
##  • le tre fasi: si parte in piedi (nessun gradino), ci si ACCOVACCIA
##    entro il settle (anche giù, zampe piegate), si dorme (testa china,
##    orecchie mosce, coda arrotolata), ci si STIRACCHIA al risveglio
##    (zampine al cielo) e si torna a zero;
##  • il PLOP dell'accovacciarsi (il peso che trova terra e rimbalza);
##  • la ZETA esce sull'ESPIRO, una per respiro — mai a timer, mai due
##    sovrapposte;
##  • su un Visitor VERO il corpo si muove davvero, e al risveglio il
##    rig torna a riposo (nessun accumulo col sistema togli/riapplica);
##  • i conflitti chiusi: niente posa da seduto, niente sguardo che
##    insegue a occhi chiusi, niente voce, niente zampina-visiera della
##    pioggia sopra un dormiente, e il volto è "dorme".

const VISITOR := "res://scenes/npc/Visitor.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"


func run(t) -> void:
	var vs: GDScript = load(VISITOR)
	t.ok(vs != null and vs.can_instantiate(), "Visitor.gd compila")
	if vs == null or not vs.can_instantiate():
		return

	_test_respiro(t, vs)
	_test_asimmetria(t, vs)
	_test_tre_fasi(t, vs)
	_test_zeta_sull_espiro(t, vs)
	_test_corpo_vero(t, vs)
	_test_conflitti(t, vs)


# ------------------------------------------------------------ il respiro

func _test_respiro(t, vs: GDScript) -> void:
	var dur := 20.0
	var lo := 99.0
	var hi := -99.0
	for i in 400:
		var s := 3.0 + float(i) * 0.02      # in pieno sonno
		var vy: float = vs.assesto_sonno(s, s, 60.0)["vy"]
		lo = minf(lo, vy)
		hi = maxf(hi, vy)
	t.ok(hi - lo > 0.02,
			"IL PETTO SI ALZA: il respiro esiste (escursione %.4f)" % (hi - lo))
	t.ok(hi - lo < 0.09,
			"…ed è un respiro, non un sussulto (%.4f)" % (hi - lo))
	t.almost(float(vs.SONNO_T), 5.0, "il periodo del respiro è 5 s (12 al minuto)")

	# il periodo MISURATO fra due colmi consecutivi del petto
	var colmi: Array = []
	var prev := 0.0
	var prev2 := 0.0
	var passo := dur / 4000.0
	for i in 4000:
		var tt := float(i) * passo
		var r: float = vs.respiro_fase(tt)
		if prev > prev2 and prev > r:
			colmi.append(tt - passo)
		prev2 = prev
		prev = r
	t.ok(colmi.size() >= 3, "il petto si alza più volte in 20 s (%d)" % colmi.size())
	if colmi.size() >= 3:
		var periodo: float = (float(colmi[-1]) - float(colmi[0])) \
				/ float(colmi.size() - 1)
		t.almost(periodo, 5.0,
				"fra un colmo e l'altro passano 5 s: 12 respiri al minuto", 0.02)


func _test_asimmetria(t, vs: GDScript) -> void:
	# la firma di un torace vero: l'inspiro sale in fretta, l'espiro
	# scende piano. Si misurano i due tratti su un periodo intero.
	var passo := 0.002
	var salita := 0.0
	var discesa := 0.0
	var prev: float = vs.respiro_fase(0.0)
	for i in range(1, int(5.0 / passo)):
		var r: float = vs.respiro_fase(float(i) * passo)
		if r > prev:
			salita += passo
		elif r < prev:
			discesa += passo
		prev = r
	t.ok(salita < discesa * 0.75,
			"ASIMMETRIA: l'inspiro (%.2f s) è più corto dell'espiro (%.2f s)"
			% [salita, discesa])
	t.almost(salita / (salita + discesa), float(vs.SONNO_INSPIRO),
			"…nella proporzione fisiologica dichiarata", 0.03)
	# e la fase resta sempre nel suo intervallo
	var fuori := 0
	for i in 500:
		var r: float = vs.respiro_fase(float(i) * 0.031)
		if r < -0.001 or r > 1.001:
			fuori += 1
	t.eq(fuori, 0, "la fase del respiro resta fra 0 e 1")


# -------------------------------------------------------------- le fasi

func _test_tre_fasi(t, vs: GDScript) -> void:
	var dur: float = vs.NAP_DUR
	var a0: Dictionary = vs.assesto_sonno(0.0, 0.0, dur)
	for c in ["vx", "hx", "lx", "ear", "tx"]:
		t.ok(absf(float(a0[c])) < 0.06,
				"a t=0 si è ancora in piedi: nessun gradino (%s=%.3f)" % [c, a0[c]])

	# accovacciato: dopo il settle le anche sono giù e le zampe piegate
	var dorme: Dictionary = vs.assesto_sonno(float(vs.SONNO_SETTLE) + 0.1, 3.0, dur)
	t.ok(float(dorme["lx"]) > 1.0,
			"accovacciato: le zampe sono piegate sotto (%.2f)" % dorme["lx"])
	t.ok(float(dorme["ly"]) < -0.05,
			"…e le anche sono scese a terra (%.3f)" % dorme["ly"])
	t.ok(float(dorme["hx"]) > 0.28, "il musetto è china sul petto (%.2f)" % dorme["hx"])
	t.ok(float(dorme["ear"]) > 0.5, "le orecchie sono mosce (%.2f)" % dorme["ear"])
	t.ok(float(dorme["tx"]) > 0.3, "la coda è arrotolata (%.2f)" % dorme["tx"])
	t.ok(absf(float(dorme["hz"])) > 0.05,
			"la guancia cede di lato: l'asimmetria dell'abbandono")

	# il PLOP dell'accovacciarsi: il corpo sprofonda, quindi il rimbalzo
	# non si legge nei cambi di segno del valore (vy resta negativo per
	# tutto il sonno) ma nei cambi di DIREZIONE: giu', su, giu' di nuovo.
	var inversioni := 0
	var prev: float = vs.assesto_sonno(0.0, 0.0, dur)["vy"]
	var dir_prev := 0.0
	var fondo := 0.0
	for i in range(1, 90):
		var vy: float = vs.assesto_sonno(float(i) * 0.01, 0.0, dur)["vy"]
		fondo = minf(fondo, vy)
		var dir := signf(vy - prev)
		if dir != 0.0 and dir_prev != 0.0 and dir != dir_prev:
			inversioni += 1
		if dir != 0.0:
			dir_prev = dir
		prev = vy
	t.ok(inversioni >= 2,
			"il peso trova terra con un PLOP che RIMBALZA (%d inversioni)"
			% inversioni)
	t.ok(fondo < -0.03,
			"…affondando davvero sotto il pelo del prato (%.3f)" % fondo)
	# e non c'e' il gradino: il primo fotogramma parte da zero
	t.ok(absf(float(vs.assesto_sonno(0.0, 0.0, dur)["vy"])) < 0.002,
			"REGRESSIONE: il corpo non SALTA giu' al primo fotogramma")

	# lo stiracchio: le zampine vanno SU (segno negativo = in fuori/alto)
	var stira_min := 99.0
	for i in 160:
		var s := dur - float(vs.SONNO_WAKE) + float(i) * 0.01
		stira_min = minf(stira_min, float(vs.assesto_sonno(s, 2.0, dur)["ax"]))
	t.ok(stira_min < -1.5,
			"al risveglio ci si STIRACCHIA: zampine al cielo (%.2f)" % stira_min)

	# a fine corsa tutto è rientrato e si è svegli
	var fine: Dictionary = vs.assesto_sonno(dur, 2.0, dur)
	t.almost(float(fine["sveglio"]), 1.0, "a fine pisolino si è svegli", 0.02)
	for c in ["vx", "hx", "lx", "ear", "tx", "ax"]:
		t.ok(absf(float(fine[c])) < 0.06,
				"…e il corpo è tornato a riposo (%s=%.3f)" % [c, fine[c]])


func _test_zeta_sull_espiro(t, vs: GDScript) -> void:
	# NON si deduce dalla curva (ri-scrivere qui la soglia del codice
	# renderebbe il test verde anche cancellando la riga che emette la
	# zeta): si CONTANO le zeta che escono davvero, in un pisolino intero
	# pilotato dal _process, con tre orologi di partenza diversi.
	var dna_s: GDScript = load(DNA)
	var visti: Array = []
	for fase in [0.0, 1.7, 3.4]:
		var v = vs.new()
		v.dna = dna_s.generate(4242)
		t.stage(v)
		v._t = fase
		v._enter_state("tk_nap")
		var zeta := 0
		var prima_a := -99.0
		var stacco_min := 99.0
		var tempo := 0.0
		for f in int(vs.NAP_DUR * 60.0):
			v._process(1.0 / 60.0)
			tempo += 1.0 / 60.0
			var n := 0
			for c in v.get_children():
				if c is Label3D and str((c as Label3D).text) == "z":
					n += 1
			if n > zeta:
				if prima_a > -50.0:
					stacco_min = minf(stacco_min, tempo - prima_a)
				prima_a = tempo
				zeta = n
		visti.append(zeta)
		t.ok(zeta >= 1,
				"un pisolino esala almeno una zeta (fase %.1f: %d)" % [fase, zeta])
		t.ok(zeta <= 3, "…e mai una raffica (%d)" % zeta)
		if stacco_min < 50.0:
			t.ok(stacco_min > 1.6,
					"…mai due zeta sovrapposte: passano %.1f s" % stacco_min)
	t.ok(visti.size() == 3, "la zeta esce con ogni fase di partenza del respiro")


# ---------------------------------------------------------- il corpo vero

func _test_corpo_vero(t, vs: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	var v = vs.new()
	v.species = "chibi"
	v.dna = dna_s.generate(4242)
	t.stage(v)
	# un ANZIANO: cosi' la base delle orecchie non e' zero e "torna a
	# riposo" verifica davvero il ritorno (con un rig a zero passerebbe
	# anche un'animazione che dimentica l'eta')
	v.set_eta(0.9)
	var ear_base: float = (v._c_ears[0] as Node3D).rotation.x
	var arm_base: float = (v._c_arms[0] as Node3D).rotation.x
	t.ok(ear_base > 0.2,
			"l'anziano parte con le orecchie stanche (%.2f): la base non e' zero"
			% ear_base)

	# in pieno sonno il corpo è coricato e il petto si muove
	v._sit_t = 0.0
	var lo := 99.0
	var hi := -99.0
	for f in 240:                      # 4 secondi: dentro il sonno pieno
		v._t += 1.0 / 60.0
		v._anim_dorme(vs.NAP_DUR, 1.0 / 60.0)
		if v._sit_t > 2.0:
			lo = minf(lo, v._vis.position.y)
			hi = maxf(hi, v._vis.position.y)
	t.ok(hi - lo > 0.015,
			"sul corpo VERO il torace si alza e si abbassa (%.4f)" % (hi - lo))
	t.ok((v._c_legs[0] as Node3D).rotation.x > 1.0,
			"…il villager è accovacciato davvero (%.2f)"
			% (v._c_legs[0] as Node3D).rotation.x)
	t.ok((v._head as Node3D).rotation.x > 0.28, "…col musetto china")
	t.ok(absf((v._tail_p as Node3D).rotation.y) < 0.15,
			"…e la coda NON scodinzola: smentirebbe il sonno")

	# lo stiracchio e il ritorno: il rig torna a riposo, senza accumuli
	v._sit_t = vs.NAP_DUR - 0.02
	v._anim_dorme(vs.NAP_DUR, 1.0 / 60.0)
	t.almost((v._c_ears[0] as Node3D).rotation.x, ear_base,
			"a sonno finito le orecchie tornano ESATTAMENTE alla loro base "
			+ "(l'eta' compresa)", 0.01)
	t.almost((v._c_arms[0] as Node3D).rotation.x, arm_base,
			"…e le braccine pure (nessun accumulo)", 0.01)
	t.almost(v._vis.position.y, 0.0, "…e il corpo è di nuovo in piedi", 0.01)


func _test_conflitti(t, vs: GDScript) -> void:
	var src := FileAccess.get_file_as_string(VISITOR)
	var dna_s: GDScript = load(DNA)

	# COMPORTAMENTALE, non testuale: si entra nello stato vero e si guarda
	# il corpo. Cancellare la chiamata a _anim_dorme (o rimettere
	# _anim_sit, o accorciare _timer) fa fallire QUESTE asserzioni —
	# un source-check sui commenti no.
	var v = vs.new()
	v.dna = dna_s.generate(77)
	t.stage(v)
	v._enter_state("tk_nap")
	t.almost(v._timer, float(vs.NAP_DUR),
			"lo stato dura quanto le sue tre fasi (NAP_DUR)", 0.01)
	for f in 150:                       # 2.5 s: dopo il settle
		v._process(1.0 / 60.0)
	t.ok((v._c_legs[0] as Node3D).rotation.x > 1.0,
			"entrando in tk_nap il corpo si CORICA davvero (%.2f)"
			% (v._c_legs[0] as Node3D).rotation.x)
	t.ok(v._vis.position.y < -0.1,
			"…e sprofonda nel sonno (%.3f)" % v._vis.position.y)

	# la postura si SOSPENDE, non si cancella: un disertore che schiaccia
	# un pisolino deve ritrovare il suo fagotto al risveglio
	var d = vs.new()
	d.dna = dna_s.generate(99)
	t.stage(d)
	d.set_meta("postura", "fagotto_in_spalla")
	d._process(1.0 / 60.0)
	t.eq(d._rc_stabile, "fagotto_in_spalla", "il disertore ha la sua postura")
	d._enter_state("tk_nap")
	for f in 90:
		d._process(1.0 / 60.0)
	t.eq(d._rc_stabile, "fagotto_in_spalla",
			"REGRESSIONE: il pisolino SOSPENDE la postura, non la cancella")
	t.ok(d._fagotto == null or not is_instance_valid(d._fagotto),
			"…e mentre dorme il fagotto non gli sta in spalla")

	# il volto, lo sguardo e la voce
	t.eq(v._expr_for_state("tk_nap"), "dorme", "il volto recita 'dorme'")
	t.ok(src.contains("if _state == \"tk_nap\":\n\t\t\t# a occhi chiusi"),
			"a occhi chiusi lo sguardo non insegue il giocatore "
			+ "(il ramo suo, non il clear_gaze generico)")
	var prima = v._speak_cd
	v.speak(["ciao"], "felice")
	t.eq(v._speak_cd, prima, "chi dorme non parla")
	t.ok(src.contains("riparo_pioggia and _state != \"tk_nap\""),
			"niente zampina-visiera della pioggia sopra un dormiente")

	# --- le regressioni che una revisione avversariale ha scovato ---

	# 1) un pisolino TRONCATO non lascia il corpo fuori posa per sempre.
	# Coda arrotolata e spalle chiuse le scrive SOLO il sonno, e troncare
	# un pisolino e' la norma (resident_sleep parte anche da tk_nap).
	var w = vs.new()
	w.dna = dna_s.generate(7)
	t.stage(w)
	var coda0: float = (w._tail_p as Node3D).rotation.x
	var spalla0: float = (w._c_arms[0] as Node3D).rotation.z
	w._enter_state("tk_nap")
	for f in 180:                       # 3 s: in pieno sonno
		w._process(1.0 / 60.0)
	t.ok(absf((w._tail_p as Node3D).rotation.x - coda0) > 0.2,
			"dormendo la coda si arrotola davvero")
	w._state = "r_idle"                 # come fanno _walk_to / mangia / resident_sleep
	for f in 60:
		w._process(1.0 / 60.0)
	t.almost((w._tail_p as Node3D).rotation.x, coda0,
			"REGRESSIONE: pisolino troncato → la coda torna a posto", 0.02)
	t.almost((w._c_arms[0] as Node3D).rotation.z, spalla0,
			"…e le spalle riaprono (mai fuori posa per sempre)", 0.02)

	# 2) chi dorme non recita i TRANSITORI: niente trasalimento addosso
	# al dormiente solo perche' il giocatore gli passa vicino
	var s2 = vs.new()
	s2.dna = dna_s.generate(31)
	t.stage(s2)
	s2._enter_state("tk_nap")
	for f in 120:
		s2._process(1.0 / 60.0)
	s2.set_meta("postura", "trasalisce")
	for f in 30:
		s2._process(1.0 / 60.0)
	t.ok(absf(float(s2._rc_cur.get("ax0", 0.0))) < 0.05,
			"il dormiente non trasalisce se ti avvicini (%.3f)"
			% s2._rc_cur.get("ax0", 0.0))

	# 3) chi si corica SUL POSTO lo fa a terra, non sopra la panchina
	var b = vs.new()
	b.dna = dna_s.generate(55)
	b.mode = "resident"
	t.stage(b)
	b.position.y = 0.52                 # seduto in panchina
	b.do_task("nap", Vector3.ZERO)
	t.almost(b.position.y, 0.0,
			"il pisolino preso dalla panchina si prende A TERRA", 0.01)

	# 4) il respiro deve avere il TEMPO di leggersi: un ritmo, non un sospiro
	var pieno := (float(vs.NAP_DUR) - float(vs.SONNO_WAKE)
			- float(vs.SONNO_SETTLE)) / float(vs.SONNO_T)
	t.ok(pieno >= 2.0,
			"il sonno pieno dura almeno DUE respiri (%.2f periodi)" % pieno)
