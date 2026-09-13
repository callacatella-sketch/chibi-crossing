extends RefCounted
## IL CARICO — quello che una brutta stagione lascia addosso.

const LIMBICO = preload("res://scenes/npc/Limbico.gd")
const CIELO := {"luce": 0.8, "pioggia": 0.0, "temperatura": 20.0}
const TEMPESTA := {"luce": 0.3, "pioggia": 1.0, "temperatura": 2.0}


func run(t) -> void:
	_il_pavimento(t)
	_una_stagione_lascia_qualcosa(t)
	_la_notte_non_lo_cancella(t)
	_l_autocontrollo_non_e_compromesso(t)
	_si_scarica_facendo(t)
	_il_degrado(t)


func _vivi(l, sec: float, amb := CIELO, atti := 0.0) -> void:
	var dt := 0.25
	for k in int(sec / dt):
		l.passo_neuro(dt, amb, false, 0.0)
		l.passo_carico(dt, atti * dt)


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


func _una_stagione_lascia_qualcosa(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	var riposo_prima: float = float(l.neuro_base["cortisolo"])
	for g in 10:
		l.umore = -0.9        # una stagione brutta, tenuta
		_vivi(l, 240.0)
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
