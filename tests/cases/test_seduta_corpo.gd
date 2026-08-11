extends RefCounted
## IL CORPO CHE SI SIEDE — e il tween che non gli sopravvive.
##
## Un tween è legato al NODO, non allo stato che l'ha acceso: continua a
## scrivere `position` anche dopo che quello stato è finito. Il montaggio
## sulla panchina durava 0,4 s, e in quei 0,4 s chiunque poteva cambiare
## stato (la routine, una chiacchierata, il Salone, un piano del Regista).
## Misurato nel MainLevel vero, 45 s di villaggio (`tools/prova_seduta_
## troncata.gd`): il corpo scivolava fino a **8,9 m/s** col ciclo del passo
## a blend 1,00, e restava appeso a **52 cm** dall'erba — 928 frame di
## levitazione su 2704, cioè un sesto del tempo.
##
## E anche senza interruzioni il montaggio era una fucilata: quasi un metro
## in quattro decimi di secondo, con un'attenuazione che parte al massimo.
## Sopra i 2,8 m/s (`Andatura.VELOCITA_ASSURDA`) l'andatura legge un
## teletrasporto e SMETTE di far girare la fase del passo: le zampe si
## congelavano a mezz'aria mentre il corpo traslava.
##
## Qui si verifica il COMPORTAMENTO, non i commenti:
##  • si entra in `r_bench`, si cambia stato a tween vivo, e si pretende che
##    il corpo non superi il passo d'uomo e che i piedi tornino a terra;
##  • il montaggio e la discesa, INTERI, restano sotto la velocità oltre la
##    quale l'andatura si arrende;
##  • la rete dell'altezza gira per OGNI stato (canali orfani), ma non
##    scippa il sedile a chi ci sta legittimamente sopra;
##  • il plop dell'assestamento aspetta l'ATTERRAGGIO.
##
## Per falsificarlo: togliere `_corpo_ferma()` da `_walk_to`, oppure la
## chiamata a `_corpo_rete()` in `_process`, oppure rimettere il vecchio
## `tween_property(self, "position", seat, 0.4)` con TRANS_BACK.

const VISITOR := "res://scenes/npc/Visitor.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"
const ANDATURA := "res://scenes/npc/Andatura.gd"

## Il passo di un frame simulato (60 fps).
const DT := 1.0 / 60.0
## Il passo più veloce di un residente chibi è 1,45 m/s. Con un dito di
## margine per l'attenuazione dell'ultimo avvicinamento (SINE/OUT parte a
## π/2 volte la media) il corpo non deve MAI superare questa velocità.
const PASSO_MAX := 2.0


func run(t) -> void:
	var vs: GDScript = load(VISITOR)
	t.ok(vs != null and vs.can_instantiate(), "Visitor.gd compila")
	if vs == null or not vs.can_instantiate():
		return

	_test_interruzione(t, vs)
	_test_montaggio_intero(t, vs)
	_test_discesa(t, vs)
	_test_rete_altezza(t, vs)
	_test_sedile_conservato(t, vs)
	_test_plop_sull_atterraggio(t, vs)
	_test_nessun_tween_crudo(t)


# --------------------------------------------------------------- il banco

## Un vicino vero, in scena, col corpo montato — e la panchina davanti.
## Torna [vicino, panchina, punto_di_arrivo].
func _banco(t, vs: GDScript, dove := Vector3(3, 0, 0)) -> Array:
	var dna_s: GDScript = load(DNA)
	var panca := Node3D.new()
	t.stage(panca)
	panca.position = dove
	var v = vs.new()
	v.species = "chibi"
	v.dna = dna_s.generate(7331)
	t.stage(v)
	v.mode = "resident"
	# il punto in cui la routine lascia chi cammina: 80 cm davanti al pezzo
	# (`Visitors._recita`, ramo "riposo")
	var arrivo: Vector3 = panca.global_transform * Vector3(0, 0, 0.8)
	v.position = Vector3(arrivo.x, 0, arrivo.z)
	v._routine_aux = panca
	return [v, panca, arrivo]


## Un frame vero, nell'ORDINE VERO del motore: `_process` dei nodi, POI i
## tween. Chi campiona in mezzo somma due spostamenti che il giocatore non
## ha mai visto insieme e si inventa picchi che non esistono (è successo:
## 3,2 m/s di puro artefatto di misura).
func _frame(v) -> void:
	v._process(DT)
	if v._corpo_tw != null and v._corpo_tw.is_valid():
		v._corpo_tw.custom_step(DT)


## Fa girare [param n] frame e torna la velocità orizzontale MASSIMA vista
## fra un frame disegnato e il successivo, insieme al blend a quell'istante.
func _corri(v, n: int) -> Dictionary:
	# la posizione come l'ha lasciata il frame precedente
	var prec: Vector3 = v.position
	var v_max := 0.0
	var blend_al_max := 0.0
	var y_max := 0.0
	for _i in n:
		_frame(v)
		var d: Vector3 = v.position - prec
		var vel := Vector2(d.x, d.z).length() / DT
		if vel > v_max:
			v_max = vel
			blend_al_max = float(v._andatura.blend) if v._andatura != null else 0.0
		y_max = maxf(y_max, absf(v.position.y))
		prec = v.position
	return {"v": v_max, "blend": blend_al_max, "y": y_max}


# ------------------------------------------- 1. l'interruzione a tween vivo

func _test_interruzione(t, vs: GDScript) -> void:
	var and_s: GDScript = load(ANDATURA)
	# si interrompe in QUATTRO momenti diversi del montaggio, perché il
	# guasto peggiore stava all'inizio (dove la vecchia attenuazione era
	# più ripida) ma la levitazione restava a qualunque istante
	for quando in [1, 4, 10, 20]:
		var b := _banco(t, vs)
		var v = b[0]
		v._enter_state("r_bench")
		t.ok(v._corpo_tw != null and v._corpo_tw.is_valid(),
				"il montaggio accende un tween del corpo")
		t.eq(v._corpo_tw_padrone, "r_bench",
				"…e il tween porta il nome dello stato che l'ha acceso")
		for _i in quando:
			_frame(v)

		# ADESSO qualcun altro lo manda da un'altra parte, a tween vivo
		v.do_routine("sniff", v.position + Vector3(9, 0, 0))
		t.eq(v._state, "walk", "l'ordine arriva: si mette in cammino")
		t.ok(v._corpo_tw == null,
				"IL TWEEN MUORE CON LO STATO CHE L'AVEVA ACCESO"
				+ " (interrotto al frame %d)" % quando)

		var m := _corri(v, 45)
		t.ok(m["v"] <= PASSO_MAX,
				"…e il corpo se ne va A PASSO D'UOMO, non sparato:"
				+ " %.2f m/s al massimo (frame %d)" % [m["v"], quando])
		t.ok(m["v"] < float(and_s.VELOCITA_ASSURDA),
				"…sotto la velocità oltre la quale l'andatura si arrende"
				+ " (%.2f < %.2f)" % [m["v"], float(and_s.VELOCITA_ASSURDA)])
		t.ok(absf(v.position.y) < 0.01,
				"E I PIEDI TORNANO A TERRA: niente corpo che cammina a 52 cm"
				+ " dall'erba (y = %.3f, frame %d)" % [v.position.y, quando])


# ---------------------------------------------- 2. il montaggio, per intero

func _test_montaggio_intero(t, vs: GDScript) -> void:
	var and_s: GDScript = load(ANDATURA)
	var b := _banco(t, vs)
	var v = b[0]
	var panca: Node3D = b[1]
	var seat: Vector3 = panca.global_transform * vs.SEDUTA_PREDEFINITA
	v._enter_state("r_bench")
	# 90 frame = 1,5 s: il montaggio intero ci sta comodo
	var m := _corri(v, 90)

	t.ok(m["v"] <= PASSO_MAX,
			"IL MONTAGGIO NON È UNA FUCILATA: %.2f m/s (prima: 8,9)" % m["v"])
	t.ok(m["v"] < float(and_s.VELOCITA_ASSURDA),
			"…e l'andatura non deve mai ingoiare un teletrasporto:"
			+ " %.2f < %.2f m/s" % [m["v"], float(and_s.VELOCITA_ASSURDA)])
	t.ok(m["blend"] < 1.01,
			"…col ciclo del passo che resta un ciclo del passo (blend %.2f)"
			% m["blend"])
	t.almost(v.position.x, seat.x, "e si arriva sul sedile, in x", 0.01)
	t.almost(v.position.z, seat.z, "e si arriva sul sedile, in z", 0.01)
	t.almost(v.position.y, seat.y, "e alla quota del sedile", 0.01)
	t.eq(v._state, "r_bench", "e ci si resta seduti")
	t.ok(v._su_un_sedile, "il corpo sa di essere su un sedile")


# ------------------------------------------------------------ 3. la discesa

func _test_discesa(t, vs: GDScript) -> void:
	var and_s: GDScript = load(ANDATURA)
	var b := _banco(t, vs)
	var v = b[0]
	v._enter_state("r_bench")
	_corri(v, 90)                      # si siede
	v._timer = 0.0                     # ed è ora di alzarsi
	var m := _corri(v, 120)

	t.ok(m["v"] <= PASSO_MAX,
			"ANCHE SCENDERE si fa a passo d'uomo: %.2f m/s (prima: 3,1)" % m["v"])
	t.ok(m["v"] < float(and_s.VELOCITA_ASSURDA),
			"…senza mai chiedere all'andatura di ingoiare un salto")
	t.ok(absf(v.position.y) < 0.01,
			"…e si finisce con i piedi sull'erba (y = %.3f)" % v.position.y)
	t.eq(v._state, "r_idle", "e la discesa consegna allo stato che l'attendeva")
	t.ok(not v._su_un_sedile, "il sedile è stato lasciato davvero")


# ------------------------------- 4. la rete dell'altezza, per OGNI stato

func _test_rete_altezza(t, vs: GDScript) -> void:
	# UN CANALE ORFANO. Se solo certi stati scrivono `position.y`, basta
	# un'interruzione per lasciare un corpo appeso per il resto della
	# partita. La rete gira per ogni stato — ma non deve scippare il posto
	# a chi ci sta sopra per mestiere.
	var b := _banco(t, vs)
	var v = b[0]

	v._enter_state("r_idle")
	v.position.y = 0.52                # come lo lasciava il tween morto
	v._process(DT)
	t.almost(v.position.y, 0.0,
			"chi sta in `r_idle` non può stare a mezz'aria: la rete lo posa",
			0.001)

	for stato in ["th_perch", "r_bench", "dismount", "sit"]:
		v._state = stato
		v._su_un_sedile = false
		v.position.y = 0.42
		v._process(DT)
		t.almost(v.position.y, 0.42,
				"…ma «%s» il corpo lo tiene su di diritto: la rete non tocca"
				% stato, 0.001)

	# l'onsen la quota se la scrive da sé, ogni frame: la rete non deve
	# tirarlo fuori dall'acqua
	v._state = "on_soak"
	v._su_un_sedile = false
	v.position.y = 0.0
	v._process(DT)
	t.ok(v.position.y < -0.3,
			"…e chi è a mollo resta a mollo (y = %.2f)" % v.position.y)


func _test_sedile_conservato(t, vs: GDScript) -> void:
	# CHI MANGIA IN PANCHINA NON DEVE CADERE. `mangia()` porta lo stato a
	# `r_pasto`, che non è uno stato «sollevato»: senza la memoria del
	# sedile, un vicino a cui porti un piatto mentre è seduto scivolerebbe
	# a terra a metà pranzo, attraverso il legno.
	var b := _banco(t, vs)
	var v = b[0]
	v._enter_state("r_bench")
	_corri(v, 90)
	var quota: float = v.position.y
	t.ok(quota > 0.4, "è seduto sul legno (y = %.2f)" % quota)
	v._state = "r_pasto"               # come fa `mangia()`
	for _i in 10:
		v._process(DT)
	t.almost(v.position.y, quota,
			"…e mangia SEDUTO: il pranzo non lo fa cadere dalla panchina", 0.001)


# --------------------------------------------- 5. il plop, sull'atterraggio

func _test_plop_sull_atterraggio(t, vs: GDScript) -> void:
	var b := _banco(t, vs)
	var v = b[0]
	var panca: Node3D = b[1]
	var seat: Vector3 = panca.global_transform * vs.SEDUTA_PREDEFINITA
	v._enter_state("r_bench")

	# quanto dovrebbe durare il montaggio, dalle costanti (non a occhio)
	var piano := Vector2(seat.x - v.position.x, seat.z - v.position.z)
	var t_avv: float = maxf(float(vs.SEDUTA_AVV_MIN),
			piano.length() / float(vs.SEDUTA_VEL))
	var salita: float = maxf(seat.y - 0.0, 0.02)
	var t_su: float = float(vs.SEDUTA_SALITA) * sqrt(salita / 0.52)
	var atteso: float = maxf(t_avv, t_avv * float(vs.SEDUTA_ANTICIPO) + t_su)

	t.almost(v._sit_attesa, atteso,
			"L'ASSESTAMENTO ASPETTA L'ATTERRAGGIO: il plop è armato per"
			+ " quando il corpo tocca il legno", 0.001)
	t.ok(atteso > 0.4,
			"…e l'atterraggio arriva DOPO i 0,4 s del vecchio tween (%.2f s)"
			% atteso)
	t.almost(v._sit_t, 0.0, "…e fino ad allora l'assestamento non è partito",
			0.0001)


# ------------------------------------ 6. nessun tween crudo sul corpo, mai

func _test_nessun_tween_crudo(t) -> void:
	# LA REGOLA, non solo il caso. Chi domani aggiungerà uno stato che
	# muove il corpo deve passare da `_corpo_muovi`/`_siediti`/`_alzati`,
	# o si riapre esattamente questo guasto — e senza rumore, perché un
	# corpo che scivola non solleva errori.
	var f := FileAccess.open(VISITOR, FileAccess.READ)
	t.ok(f != null, "Visitor.gd si legge")
	if f == null:
		return
	var righe := f.get_as_text().split("\n")
	f.close()
	var crudi: Array = []
	for i in righe.size():
		var r := String(righe[i])
		if not r.contains("tween_property(self,"):
			continue
		# l'unico modo lecito di muovere il corpo è un tween che ha un
		# padrone: si crea con `_corpo_muovi()`, che lo registra
		var da_muovi := false
		for j in range(maxi(0, i - 10), i):
			if String(righe[j]).contains("_corpo_muovi("):
				da_muovi = true
		if not da_muovi:
			crudi.append("riga %d: %s" % [i + 1, r.strip_edges()])
	t.ok(crudi.is_empty(),
			"OGNI tween che muove il corpo ha un padrone che lo spegne"
			+ (" — orfani: %s" % str(crudi) if not crudi.is_empty() else ""))
