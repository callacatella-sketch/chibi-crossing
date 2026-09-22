extends RefCounted
## IL CARICO — quello che una brutta stagione lascia addosso.

const LIMBICO = preload("res://scenes/npc/Limbico.gd")
const ANIMO = preload("res://scenes/npc/Animo.gd")
const CIELO := {"luce": 0.8, "pioggia": 0.0, "temperatura": 20.0}
const TEMPESTA := {"luce": 0.3, "pioggia": 1.0, "temperatura": 2.0}


func run(t) -> void:
	_il_pavimento(t)
	_una_stagione_lascia_qualcosa(t)
	_la_notte_non_lo_cancella(t)
	_l_autocontrollo_non_e_compromesso(t)
	_si_scarica_facendo(t)
	_il_degrado(t)
	_il_villaggio_fa_avanzare_il_carico(t)


func _vivi(l, sec: float, amb := CIELO, atti := 0.0) -> void:
	var dt := 0.25
	for k in int(sec / dt):
		l.passo_neuro(dt, amb, false, 0.0)
		l.passo_carico(dt, atti * dt)


## …e la stessa vita, ma dalla PORTA VERA: `Animo.passo_carico`, che fa
## avanzare il carico e poi rifà il punto di riposo dai bisogni. È quella che
## `Visitors` chiama a ogni fotogramma.
func _vivi_animo(a, sec: float, amb := CIELO, atti := 0.0) -> void:
	var dt := 0.25
	for k in int(sec / dt):
		a.limbico.passo_neuro(dt, amb, false, 0.0)
		a.passo_carico(dt, atti * dt)


## ⚠️ **NESSUNO SI CARICA VIVENDO, e questo è il numero che decide se il
## lavoro si può consegnare.** Se la vita normale caricasse, il villaggio
## diventerebbe un ospedale — ed è esattamente il guasto per cui la PRIMA
## stesura di questo meccanismo è stata buttata: era un termine sul livello
## del cortisolo, il cui certificato era calcolato sulla baseline invece che
## sul bersaglio vero, e sotto tempesta un codardo sedeva a otto centesimi dal
## ribaltamento.
func _il_pavimento(t) -> void:
	for caso in [["sereno", CIELO], ["tempesta", TEMPESTA]]:
		var l = LIMBICO.new()
		l.setup({})
		_vivi(l, 3000.0, caso[1])
		t.almost(l.quanto_carico(), 0.0,
				("dodici giornate col cielo «%s» non caricano NIENTE: non ci "
				+ "si carica vivendo") % str(caso[0]), 1e-9)
	# e nemmeno un codardo, che è il caso peggiore
	var c = LIMBICO.new()
	c.setup({"codardia": 1.0})
	_vivi(c, 3000.0, TEMPESTA)
	t.almost(c.quanto_carico(), 0.0,
			"e nemmeno un codardo sotto tempesta, che è il caso peggiore", 1e-9)


## ⚠️ **E QUI SI PASSA DALL'ANIMO, non dal `Limbico` nudo.** Il punto di
## riposo lo scrivono i BISOGNI (`Animo.sincronizza_neuro`), e il carico ci si
## somma sopra dentro `applica_tinta`: è `Animo.passo_carico` a mettere le due
## cose in fila, ed è la porta che il villaggio chiama davvero.
##
## La prima stesura guidava il limbico da sola, e quel file allora rifaceva
## `neuro_base` dalla baseline a ogni passo — cioè **cancellava i drive**. Il
## caso era verde perché non aveva drive da cancellare: un banco che non
## attraversa la porta vera non può vedere cosa c'è dietro.
func _una_stagione_lascia_qualcosa(t) -> void:
	var a = ANIMO.new()
	a.setup({"name": "Carico", "tratti": {}, "sogno": "casa"})
	var l = a.limbico
	var riposo_prima: float = float(l.neuro_base["cortisolo"])
	for g in 10:
		l.umore = -0.9        # una stagione brutta, tenuta
		_vivi_animo(a, 240.0)
	t.ok(l.quanto_carico() > 0.25,
			("dieci giornate di malumore vero lasciano un carico (%.4f)")
					% l.quanto_carico())
	t.ok(float(l.neuro_base["cortisolo"]) > riposo_prima + 0.10,
			("e il carico sposta il PUNTO DI RIPOSO (%.4f → %.4f), non il "
			+ "livello: è la riga da cui discende tutto il resto")
					% [riposo_prima, float(l.neuro_base["cortisolo"])])


## ⚠️ **UNA NOTTE NON LO CANCELLA — ed è il difetto che ha ucciso la prima
## stesura.** `consolida_sonno` fa `move_toward(cortisolo, base_cort, 0.85)`:
## un carico messo sul LIVELLO spariva in una notte sola (da 0.91 alla
## baseline ci sono 0.83, meno del drenaggio), quindi era irraggiungibile
## oltre una giornata di gioco — completo, provato, verde e inerte in partita.
## Messo sul RIPOSO, la notte riporta il livello **al riposo spostato**, e non
## si tocca una riga di `consolida_sonno`.
func _la_notte_non_lo_cancella(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	for g in 10:
		l.umore = -0.9
		_vivi(l, 240.0)
	var prima: float = l.quanto_carico()
	var riposo: float = float(l.neuro_base["cortisolo"])
	l.consolida_sonno(1.0)
	t.almost(l.quanto_carico(), prima,
			"la notte non tocca il carico (%.4f)" % prima, 1e-9)
	t.almost(float(l.neuro["cortisolo"]), riposo,
			("…e riporta il livello al RIPOSO — che è quello spostato "
			+ "(%.4f)") % riposo, 0.02)


## ⚠️ **IL TEOREMA: chi è carico non diventa inaffidabile.** `trattieni()` —
## la forza di mordersi la lingua — scala su `max(0, livello − riposo)`. Il
## carico sposta TUTTI E DUE, quindi all'equilibrio la deviazione è **zero
## per tutti**. «Una condizione non rende nessuno inaffidabile» smette di
## essere una mitigazione e diventa una conseguenza della forma.
func _l_autocontrollo_non_e_compromesso(t) -> void:
	var sano = LIMBICO.new()
	sano.setup({})
	_vivi(sano, 600.0)
	var carico = LIMBICO.new()
	carico.setup({})
	for g in 10:
		carico.umore = -0.9
		_vivi(carico, 240.0)
	_vivi(carico, 600.0)
	var d_sano: float = maxf(0.0, float(sano.neuro["cortisolo"])
			- float(sano.neuro_base["cortisolo"]))
	var d_car: float = maxf(0.0, float(carico.neuro["cortisolo"])
			- float(carico.neuro_base["cortisolo"]))
	t.ok(carico.quanto_carico() > 0.2, "il secondo è davvero carico (%.3f)"
			% carico.quanto_carico())
	t.almost(d_car, d_sano,
			("la deviazione sopra il proprio riposo è la STESSA (%.5f contro "
			+ "%.5f): l'autocontrollo costa uguale") % [d_car, d_sano], 0.02)


## ⚠️ **SI SCARICA FACENDO, NON ASPETTANDO.** È la *behavioural activation*,
## il trattamento con più evidenza per la depressione, e funziona attraverso
## il FARE — non attraverso l'umore che migliora prima. Per questo l'uscita è
## un conteggio di gesti portati a termine e non una somma di conforto.
func _si_scarica_facendo(t) -> void:
	var fermo = LIMBICO.new()
	fermo.setup({})
	fermo.carico = 0.80
	fermo.umore = 0.0
	_vivi(fermo, 2400.0, CIELO, 0.0)
	var attivo = LIMBICO.new()
	attivo.setup({})
	attivo.carico = 0.80
	attivo.umore = 0.0
	_vivi(attivo, 2400.0, CIELO, 0.05)
	t.ok(fermo.quanto_carico() > 0.4,
			("dieci giornate senza fare niente lo smaltiscono appena (%.4f "
			+ "da 0.80)") % fermo.quanto_carico())
	t.ok(attivo.quanto_carico() < 0.05,
			("…e dieci giornate in cui si PORTA A TERMINE qualcosa lo tolgono "
			+ "(%.4f): l'uscita è il fare") % attivo.quanto_carico())


func _il_degrado(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	l.carico = 0.4
	var prima: float = l.quanto_carico()
	l.passo_carico(-1.0)
	l.passo_carico(NAN)
	t.almost(l.quanto_carico(), prima, "un passo negativo o NaN non tocca nulla", 1e-12)
	l.carico = NAN
	l.passo_carico(0.25)
	t.ok(is_finite(l.quanto_carico()), "e un carico malato si ripara invece di propagarsi")
	# ⚠️ e un salvataggio di ieri non ha la chiave: risponde zero, e il gioco
	# è quello di prima. Nessuna migrazione.
	var v = LIMBICO.new()
	v.setup({})
	v.load({"umore": 0.2})
	t.almost(v.quanto_carico(), 0.0,
			"un salvataggio senza la chiave dà carico zero: nessuna migrazione", 1e-12)
	# e il giro completo
	l.carico = 0.37
	var w = LIMBICO.new()
	w.setup({})
	w.load(l.save())
	t.almost(w.quanto_carico(), 0.37, "e il carico sopravvive al salvataggio", 1e-6)


## ⚠️ **IL CARICO HA UN LETTORE IN PARTITA, o è aritmetica che nessuno esegue.**
##
## È la guardia che mancava, e la sua assenza è costata tutto il meccanismo:
## `passo_carico` è stato consegnato con quindici asserzioni, una sezione nel
## CLAUDE.md e **nessun chiamante fuori dai test**. `neuro_base` non si
## spostava mai, il corpo non indossava niente, e le altre guardie di questo
## file restavano verdi — perché provano la REGOLA, non il cablaggio. È la
## firma numero uno di questo progetto, e questa volta era mia.
##
## Si chiama il ciclo VERO (`Visitors._ciclo_sonno`) con un residente che sta
## male: se la riga che fa avanzare il carico sparisce, qui diventa rosso.
class VicinoDiProva extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass

	## il cielo è un DATO e si dà: senza un `DayNight` nell'albero
	## `_leggi_ambiente` torna vuoto, che è il degrado dichiarato del Limbico
	func _leggi_ambiente() -> Dictionary:
		return CIELO


func _il_villaggio_fa_avanzare_il_carico(t) -> void:
	var vis = VicinoDiProva.new()
	t.stage(vis)
	var corpo := Node3D.new()
	corpo.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo)
	corpo.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(3131))
	(vis.get("_residents") as Array).append({
		"label": "K", "cell": Vector2i(0, 0), "species": "chibi",
		"node": corpo, "dna": corpo.get("dna")})

	# un primo giro a vuoto, perché l'animo nasca
	vis.call("_ciclo_sonno", 0.25, 0.5)
	var a = (vis.get("_animi") as Dictionary).get("K")
	t.ok(a != null, "il ciclo ha fatto nascere l'animo")
	if a == null:
		return
	t.almost(a.limbico.quanto_carico(), 0.0,
			"e nasce senza carico", 1e-9)

	# dieci giornate di malumore vero, passate dalla porta del villaggio
	for g in 10:
		for _i in 960:                 # 240 s a dt 0.25
			a.limbico.umore = -0.9
			vis.call("_ciclo_sonno", 0.25, 0.5)
	t.ok(a.limbico.quanto_carico() > 0.25,
			("il villaggio fa avanzare il carico: dieci giornate di malumore "
			+ "lasciano %.4f") % a.limbico.quanto_carico())
	t.ok(float(a.limbico.neuro_base["cortisolo"])
					> float(a.limbico.NEURO_BASELINE["cortisolo"]) + 0.10,
			("…e il punto di riposo si è spostato (%.4f), che è l'unico modo "
			+ "in cui il carico tocca il mondo")
					% float(a.limbico.neuro_base["cortisolo"]))

	# ⚠️ LA CONTROPROVA: chi NON sta male non si carica passando dalla stessa
	# porta. Senza, «il villaggio fa avanzare il carico» sarebbe verde anche
	# con un passo che carica chiunque.
	var vis2 = VicinoDiProva.new()
	t.stage(vis2)
	var corpo2 := Node3D.new()
	corpo2.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo2)
	corpo2.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(9090))
	(vis2.get("_residents") as Array).append({
		"label": "S", "cell": Vector2i(0, 0), "species": "chibi",
		"node": corpo2, "dna": corpo2.get("dna")})
	for g in 10:
		for _i in 960:
			vis2.call("_ciclo_sonno", 0.25, 0.5)
	var b = (vis2.get("_animi") as Dictionary).get("S")
	t.almost(b.limbico.quanto_carico(), 0.0,
			"e chi vive la sua vita non si carica di niente", 1e-9)
