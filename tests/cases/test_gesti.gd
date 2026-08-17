extends RefCounted
## IL VOCABOLARIO DEL CORPO — comportamentale, mai di facciata.
##
## Il banco è un `Visitor` VERO col rig di `ChibiBuilder`, il suo `_process`
## fatto girare a 60 Hz, e si guarda **il rig**. Niente `source-check`: un
## test che cerca una stringa nel sorgente resta verde anche cancellando il
## codice che sorveglia.
##
## ⚠️ E NIENTE DOPPIO CHE RI-IMPLEMENTA IL GESTO. In `test_deduzioni` il
## `Corpo` del banco ri-scriveva `collo_ci_arriva` con un `angle_to`: il
## conto tornava, e proprio per questo la valvola vera non aveva **nessun
## lettore** — poteva diventare `return true` *e* `return false` senza che
## una sola asserzione su 63942 se ne accorgesse. Qui le funzioni chiamate
## sono quelle di produzione, e i canali si leggono dai nodi che il rig ha
## davvero.
##
## LE QUINDICI MUTAZIONI, una riga di produzione per volta, ricompilate e
## rifatte girare — col numero di asserzioni diventate rosse:
##
##   `_move_gait` senza `* _gs_r` (il ritmo non arriva al corpo) ...  3
##   `_gesto_passo` mai chiamato .................................. 21
##   `_enter_state` senza `gesto_spegni()` .........................  4
##   `_gs_viaggio` mai acceso (due Punti nello stesso viaggio) .....  2
##   `_gesto_scala` che non restituisce la scala di riposo .........  2
##   il tetto del debito tolto .....................................  1
##   `set_cucciolo` che non spegne il gesto ........................  2
##   `Andatura.misura` senza il segno (il moonwalk) ................  2
##   la coda somatica con τ = 7,0 invece di 2,8 ....................  1
##   il Punto che frena anche un anziano ........................... 60
##   la ripartenza decisa senza il Rialzo innestato ................  2
##   la rampa di spegnimento tolta (il gesto troncato salta) .......  1
##   il Largo che si scosta VERSO il posto invece che via ..........  2
##   il capo che non si trasferisce mai ............................  1
##   l'assestamento della tenuta azzerato ..........................  2
##
## E LE QUINDICI DELLE **DUE METÀ** e dei **LIVELLI**, aggiunte dopo che una
## revisione avversariale ha trovato quattro difetti che questo file, con
## 66804 asserzioni verdi, non sapeva vedere. Stessa disciplina: una riga di
## produzione per volta, con la mutazione PLAUSIBILE.
##
##   il Raccolto · le due braccia identiche ........................  8
##   il Raccolto · orecchie `dx = k·sx` (due quote, un orologio) ...  8
##   il Raccolto · braccia `dx = k·sx` .............................  2
##   il Raccolto · il tremolio azzerato (la tenuta è una posa) ..... 24
##   il Largo · le due orecchie identiche ..........................  5
##   il Largo · orecchie `dx = k·sx` ...............................  4
##   il Largo · le due braccia identiche / `dx = k·sx` ......... 3 / 2
##   la Coda · le due braccia identiche / `dx = k·sx` .......... 8 / 8
##   la Coda · orecchie `dx = k·sx` ................................  8
##   `pigrizia()` a zero (nessun corpo ha un lato pigro) ........... 50
##   il CAPO tagliato invece che spento (niente rampa) .............  2
##   la CODA tagliata invece che spenta (niente rampa) .............  2
##   la rampa dei livelli troppo LUNGA (5 s) .......................  2
##   la rampa dei livelli troppo CORTA (0,15 s) ....................  2
##   la coda che SPARISCE sotto soglia invece di spegnersi .........  1
##
## ⚠️ **DUE DI QUESTE MUTAZIONI NON MORDEVANO ALLA PRIMA STESURA**, e sono
## le due lezioni del giro:
##  · sostituire la sola BUSTA della metà che segue lascia il
##    micro-movimento su una metà sola — che non è un filo solo. La
##    mutazione plausibile è `dx = k · sx`, cioè esattamente com'era il
##    codice prima della cura, e quella dà residuo ZERO;
##  · e la rampa dei livelli va pinzata **da tutte e due le parti**: col
##    solo tetto sullo scatto, una rampa di dieci secondi sarebbe passata a
##    pieni voti lasciando l'allerta addosso al corpo per tutta la scena.
##
## ⚠️ **QUATTRO DI QUESTE RIGHE ALL'INIZIO NON ERANO FALSIFICABILI**, e
## trovarlo è stato metà del lavoro di questo file:
##  · togliere il `* _gs_r` da `_move_gait` lasciava DUE asserzioni rosse e
##    nessuna diceva la cosa che conta — il banco guardava `_gs_r`, che è il
##    numero *prima* di essere usato. Adesso si misurano i METRI, contro un
##    gemello che non si è fermato;
##  · la restituzione della scala e la rampa di spegnimento erano **zero
##    rosse**: due guardie che nessun test poteva far fallire, cioè due
##    guardie che non c'erano;
##  · e l'assestamento della tenuta pure — si poteva azzerare il
##    micro-movimento, cioè la regola che questo progetto mette per prima,
##    con 582 asserzioni tutte verdi.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const ANDATURA := preload("res://scenes/npc/Andatura.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0


func run(t) -> void:
	_la_tabella_e_pura(t)
	_il_costo_in_metri(t)
	_il_ritmo_torna_a_uno(t)
	_il_punto_spezza_il_passo(t)
	_una_sola_per_viaggio(t)
	_i_canali_tornano_a_riposo(t)
	_la_rete_gira_per_ogni_stato(t)
	_la_scala_e_di_chi_cresce(t)
	_il_debito_ha_un_tetto(t)
	_l_anziano_non_frena(t)
	_la_coda_decade_prima_del_riarmo(t)
	_il_capo_e_una_sequenza_non_un_seno(t)
	_il_verso_del_passo(t)
	_venti_e_centoquarantaquattro(t)
	_il_rialzo_non_si_recita_da_solo(t)
	_il_largo_si_scosta_dalla_parte_giusta(t)
	_il_largo_esita_prima_di_scostarsi(t)
	_il_gesto_troncato_non_salta(t)
	_niente_posa_piu_adesivo(t)
	_le_due_meta_non_sono_un_filo_solo(t)
	_la_tenuta_non_e_una_posa(t)
	_i_livelli_non_si_staccano(t)
	_la_coda_si_spegne_invece_di_sparire(t)
	_le_manopole_non_le_scrive_il_gioco(t)


# --------------------------------------------------------------- il banco

func _corpo(t, seme := 4242):
	var v = VISITOR.new()
	v.species = "chibi"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)     # il `_process` lo facciamo girare NOI, a passi noti
	return v


## Un tot di secondi di vita vera, un fotogramma per volta.
func _gira(v, secondi: float, passo := DT) -> void:
	var n := int(secondi / passo)
	for _i in n:
		v._process(passo)


## Il corpo in cammino, col ciclo del passo a regime: è la precondizione del
## Punto, e senza di essa il gesto si rifiuta (giustamente).
func _in_cammino(v, meta := Vector3(0, 0, -30)) -> void:
	v._enter_state("r_idle")
	v._walk_to(meta, "r_idle")
	_gira(v, 0.7)


# =========================================================================
# LA TABELLA — pura, senza Godot
# =========================================================================

func _la_tabella_e_pura(t) -> void:
	# il riposo è riposo ESATTO: `r` e `sy` a uno, tutto il resto a zero.
	# Un `sy` dimenticato a zero schiaccerebbe il corpo a un foglio di carta.
	var rip := GESTI.riposo()
	t.almost(float(rip["r"]), 1.0, "il ritmo a riposo è UNO")
	t.almost(float(rip["sy"]), 1.0, "la scala a riposo è UNO")
	for c in ["vx", "vy", "vz", "vrz", "px", "hx", "hy", "hz", "hpy",
			"ear", "ear_dx", "ax0", "ax1", "tail"]:
		t.almost(float(rip[c]), 0.0, "il canale «%s» a riposo è zero" % c)

	# FUORI DALLA DURATA IL RIPOSO È ESATTO, per ogni gesto e per ogni
	# variante: un residuo «quasi zero» è un residuo che qualcuno somma di
	# nuovo il frame dopo, e il rig deriva senza che nessuno lo veda.
	for nome: String in GESTI.EVENTI:
		for d: Dictionary in [{}, {"decisa": true}, {"rialzo": 0.6},
				{"via": -1.0}, {"tenuta": 3.0}]:
			var dur: float = GESTI.durata(nome, d)
			var fuori: Dictionary = GESTI.bersagli(nome, dur + 0.01, d, 1.3)
			for c in fuori:
				var atteso: float = 1.0 if (c == "r" or c == "sy") else 0.0
				t.almost(float(fuori[c]), atteso,
						"«%s» oltre la durata: «%s» a riposo" % [nome, c])
			# e PRIMA di cominciare, idem
			var prima: Dictionary = GESTI.bersagli(nome, -0.5, d, 1.3)
			t.almost(float(prima["r"]), 1.0, "«%s» prima di partire: ritmo a uno" % nome)

	# il ritmo del Punto è 1 → 0 → 1, e torna a UNO ESATTO alla fine
	var tenuta := 1.8
	t.almost(GESTI.punto_ritmo(0.0, tenuta, false), 1.0, "il Punto parte a ritmo pieno")
	t.almost(GESTI.punto_ritmo(GESTI.PUNTO_FRENO, tenuta, false), 0.0,
			"a fine frenata il ritmo è zero", 0.001)
	t.almost(GESTI.punto_ritmo(GESTI.PUNTO_FRENO + tenuta * 0.5, tenuta, false), 0.0,
			"dentro la tenuta il ritmo resta zero")
	var dur := GESTI.punto_durata(tenuta, false)
	t.ok(GESTI.punto_ritmo(dur, tenuta, false) > 0.99,
			"a fine gesto il ritmo è tornato a uno (%.4f)"
					% GESTI.punto_ritmo(dur, tenuta, false))
	# la RIPARTENZA DECISA supera l'uno, e poi rientra: «ha deciso» si vede
	# perché per un attimo cammina più svelto del normale
	var sopra := false
	var s := GESTI.PUNTO_FRENO + tenuta
	for i in 100:
		if GESTI.punto_ritmo(s + float(i) * 0.01, tenuta, true) > 1.05:
			sopra = true
	t.ok(sopra, "la ripartenza DECISA passa sopra il ritmo normale")
	t.ok(GESTI.punto_ritmo(GESTI.punto_durata(tenuta, true), tenuta, true) < 1.02,
			"…e poi rientra")
	# e L'ANZIANO NON FRENA: il suo fermo ce l'ha già
	for i in 60:
		t.almost(GESTI.punto_ritmo(float(i) * 0.06, tenuta, false, false), 1.0,
				"su un anziano il Punto non tocca il ritmo")


func _il_costo_in_metri(t) -> void:
	# quanto costa un gesto, integrando il ritmo perso. Nessuno deve poter
	# sfondare il tetto della rete: se lo facesse, la rete lo spegnerebbe a
	# metà — e un gesto troncato dalla sua stessa tabella si vede.
	# LE TENUTE SONO QUELLE CHE IL GIOCO PRODUCE, non un numero a caso: il
	# tetto del debito è una rete contro un ritmo INCASTRATO, non una tara
	# sulla tabella. Provarlo con una tenuta che nessuno chiede vorrebbe dire
	# alzare il tetto per far passare un caso che non esiste — e un tetto
	# alzato per il test è un tetto che in partita non ferma più niente.
	var tmax := GESTI.PUNTO_TENUTA * (1.0 + GESTI.PUNTO_TENUTA_SCARTO)
	for nome: String in GESTI.EVENTI:
		for d: Dictionary in [{}, {"decisa": true}, {"tenuta": tmax},
				{"tenuta": tmax, "decisa": true}, {"rialzo": 0.6}]:
			var m: float = GESTI.costo_metri(nome, d)
			t.ok(m <= GESTI.DEBITO_MAX,
					"«%s» %s costa %.2f m, sotto il tetto %.1f"
							% [nome, str(d), m, GESTI.DEBITO_MAX])
	# …e il tetto non è nemmeno troppo largo: il gesto più caro deve starci
	# DENTRO con margine, ma non di un ordine di grandezza (una rete che
	# scatta solo a dieci metri non è una rete).
	var peggio: float = GESTI.costo_metri("punto", {"tenuta": tmax})
	t.ok(peggio > GESTI.DEBITO_MAX * 0.5,
			"il tetto è tarato sul gesto vero (il peggiore costa %.2f m su %.1f)"
					% [peggio, GESTI.DEBITO_MAX])
	# il Largo non costa: ANDANDO più svelto ne guadagna
	t.ok(GESTI.costo_metri("largo", {}) < 0.0,
			"il Largo non ruba strada, ne guadagna (%.2f m)"
					% GESTI.costo_metri("largo", {}))


# =========================================================================
# IL CORPO
# =========================================================================

func _il_ritmo_torna_a_uno(t) -> void:
	var v = _corpo(t)
	_in_cammino(v)
	t.ok(v.gesto("punto"), "il Punto parte su un corpo che cammina")
	_gira(v, GESTI.punto_durata(GESTI.PUNTO_TENUTA * 1.13, false) + 0.6)
	t.almost(float(v.get("_gs_r")), 1.0, "a gesto finito il ritmo è tornato a UNO", 0.005)
	t.eq(str(v.gesto_in_corso()), "", "…e non c'è più nessun gesto in corso")


func _il_punto_spezza_il_passo(t) -> void:
	var v = _corpo(t)
	_in_cammino(v)
	var and_ = v.get("_andatura")
	t.ok(float(and_.blend) > 0.9,
			"prima del Punto il ciclo del passo è pieno (%.2f)" % float(and_.blend))
	t.ok(v.gesto("punto"), "il Punto parte")
	# IL PASSO SI SPEGNE, e in fretta: sotto `VELOCITA_FERMO` dopo 0,155 s,
	# poi il blend estingue il ciclo da sé. Nessuna animazione d'arresto.
	_gira(v, 0.45)
	t.ok(float(and_.blend) < 0.10,
			"a 0,45 s dal Punto il ciclo del passo è spento (%.3f)" % float(and_.blend))
	# IL CORPO È FERMO DAVVERO: non è una posa sopra un corpo che scorre
	var dove: Vector3 = v.global_position
	_gira(v, 0.8)
	t.ok(v.global_position.distance_to(dove) < 0.01,
			"dentro la tenuta il corpo non si sposta (%.4f m)"
					% v.global_position.distance_to(dove))
	# ⚠️ E IL RITMO DEVE ARRIVARE AL CORPO, non solo alla variabile. La prima
	# stesura di questo file guardava `_gs_r`, che è il numero PRIMA di
	# essere usato: togliendo il `* _gs_r` da `_move_gait` — cioè scollegando
	# il gesto dal passo — restavano due sole asserzioni rosse, e nessuna
	# diceva la cosa che conta. Il Punto è un CONTRASTO DI MOTO: si misura in
	# metri, contro un gemello che non si è fermato.
	var gm = _corpo(t, 4242)
	_in_cammino(gm)
	var da_v: Vector3 = v.global_position
	var da_g: Vector3 = gm.global_position
	_gira(v, 1.2)
	_gira(gm, 1.2)
	var fatti_v := da_v.distance_to(v.global_position)
	var fatti_g := da_g.distance_to(gm.global_position)
	t.ok(fatti_v < fatti_g * 0.15,
			"in un secondo e due il gemello fa %.2f m e chi si è fermato %.2f"
					% [fatti_g, fatti_v])
	# …e poi RIPARTE
	_gira(v, GESTI.punto_durata(GESTI.PUNTO_TENUTA * 1.13, false))
	t.ok(float(and_.blend) > 0.9,
			"dopo il Punto il ciclo del passo è tornato pieno (%.2f)"
					% float(and_.blend))
	var dopo: Vector3 = v.global_position
	_gira(v, 0.5)
	t.ok(v.global_position.distance_to(dopo) > 0.3,
			"…e il corpo cammina di nuovo (%.2f m in mezzo secondo)"
					% v.global_position.distance_to(dopo))


func _una_sola_per_viaggio(t) -> void:
	var v = _corpo(t)
	_in_cammino(v)
	t.ok(v.gesto("punto"), "il primo Punto del viaggio parte")
	_gira(v, GESTI.punto_durata(GESTI.PUNTO_TENUTA * 1.13, false) + 0.8)
	t.ok(not v.gesto("punto"),
			"il SECONDO Punto dello stesso viaggio si rifiuta")
	# ma un viaggio nuovo riapre il diritto
	v._walk_to(Vector3(0, 0, -60), "r_idle")
	_gira(v, 0.7)
	t.ok(v.gesto("punto"), "…e al viaggio dopo riparte")


## ⚠️ **L'ORACOLO È UN GEMELLO, e la prima stesura di questo file non ce
## l'aveva.** Confrontare il rig PRIMA e DOPO un gesto non prova niente: fra
## i due istanti il ciclo del passo è avanzato, e canali come
## `_vis.rotation.z` o `_c_ears[i].rotation.x` sono scritti in ASSOLUTO da
## `Andatura.applica` a ogni fotogramma — la differenza misurata era la fase
## del passo, non il residuo del gesto. Undici asserzioni rosse su un codice
## sano: un test che sbaglia oracolo non è severo, è **rumoroso**, e un test
## rumoroso lo si finisce per allentare finché non dice più niente.
##
## Il gemello è lo STESSO corpo (stesso genoma, stesso copione, stesso numero
## di `_process`) che non gesticola. Alla fine si porta tutti e due in
## `r_idle` finché il passo non si spegne: da lì in poi i canali del passo
## non dipendono più dalla fase (`blend` a zero), e **qualunque differenza
## residua è il gesto che non se n'è andato**.
func _i_canali_tornano_a_riposo(t) -> void:
	for nome: String in ["punto", "raccolto", "rialzo", "largo"]:
		var dati := {}
		if nome == "largo":
			dati = {"posto": Vector3(4, 0, 0)}
		var v = _corpo(t, 909)
		var g = _corpo(t, 909)      # il gemello: non gesticola mai
		for corpo in [v, g]:
			if nome == "punto" or nome == "largo":
				_in_cammino(corpo)
			else:
				corpo._enter_state("r_idle")
				corpo.set("_timer", 1.0e9)
				_gira(corpo, 0.4)
		t.ok(v.gesto(nome, dati), "«%s» parte" % nome)
		_gira(v, GESTI.durata(nome, dati) + 1.0)
		_gira(g, GESTI.durata(nome, dati) + 1.0)
		# e poi tutti e due allo stesso passo, dallo stesso punto
		for corpo in [v, g]:
			_normalizza(corpo)
		var dopo := _rig(v)
		var atteso := _rig(g)
		for c in atteso:
			t.almost(float(dopo[c]), float(atteso[c]),
					"«%s»: il canale «%s» del RIG è quello del GEMELLO" % [nome, c],
					0.002)


## ⚠️ **E PRIMA DI CONFRONTARE SI NORMALIZZA IL PASSO.** `Andatura.applica`
## scrive le orecchie e l'inclinazione del busto in ASSOLUTO, ma **solo negli
## stati di movimento**: da fermo quei canali restano CONGELATI all'ultimo
## fotogramma camminato. Due corpi che si fermano con la fase del passo
## diversa — e il Punto, che ferma il suo, ce l'ha per forza diversa —
## mostrano orecchie diverse per una ragione che col gesto non c'entra
## niente (misurato: 0,116 rad di scarto sulle orecchie, su un codice sano).
##
## Si riportano tutti e due allo STESSO punto, con la STESSA fase, e li si fa
## camminare un secondo: da lì in poi ogni canale è riscritto ogni fotogramma
## dallo stesso conto, e **quel che resta diverso è il gesto**.
func _normalizza(v) -> void:
	var a = v.get("_andatura")
	if a != null:
		a.fase = 0.0
		a.blend = 0.0
		a.banco = 0.0
		a.wag = 0.0
		a._prev_pos = Vector3.INF
	v.global_position = Vector3.ZERO
	v.set("_yaw", 0.0)
	v._walk_to(Vector3(0, 0, -40), "r_idle")
	_gira(v, 1.2)


## I canali veri, letti dai nodi del rig — non dal dizionario del gesto.
func _rig(v) -> Dictionary:
	var out := {}
	var vis: Node3D = v.get("_vis")
	var testa: Node3D = v.get("_head")
	var corpo: Node3D = v.get("_corpo")
	out["vis.x"] = vis.position.x
	out["vis.rz"] = vis.rotation.z
	out["testa.rz"] = testa.rotation.z
	out["testa.y"] = testa.position.y
	out["corpo.sy"] = corpo.scale.y
	out["corpo.sx"] = corpo.scale.x
	var orecchie: Array = v.get("_c_ears")
	if orecchie.size() == 2:
		out["ear0"] = (orecchie[0] as Node3D).rotation.x
		out["ear1"] = (orecchie[1] as Node3D).rotation.x
	return out


func _la_rete_gira_per_ogni_stato(t) -> void:
	# L'ORFANO: si spara un gesto e a metà si SNAPPA lo stato. Tutti i canali
	# devono tornare a riposo comunque — non solo per lo stato che li ha
	# accesi. È la regola più costosa di questo progetto (un `r` incastrato a
	# 0,35 è un vicino che cammina a un terzo per il resto della partita, e
	# nessun test guarda la velocità).
	for stato: String in ["r_idle", "tk_nap", "r_pasto", "hidden"]:
		var v = _corpo(t, 313)
		var g = _corpo(t, 313)
		_in_cammino(v)
		_in_cammino(g)
		v.gesto("punto")
		_gira(v, 0.9)          # in piena tenuta
		_gira(g, 0.9)
		t.ok(absf(float(v.get("_gs_r")) - 1.0) > 0.5,
				"«%s»: a metà gesto il ritmo è davvero fuori posa" % stato)
		for corpo in [v, g]:
			if stato == "hidden":
				corpo.resident_sleep()
			else:
				corpo._enter_state(stato)
			_gira(corpo, GESTI.SPEGNI + 0.5)
		t.almost(float(v.get("_gs_r")), 1.0,
				"«%s»: il RITMO è tornato a uno dopo l'interruzione" % stato, 0.004)
		if stato == "hidden":
			# il corpo è rimpicciolito da un TWEEN: il rig non si legge, e
			# combattere un tween è proprio la cosa che non si fa
			continue
		for corpo in [v, g]:
			_normalizza(corpo)
		var dopo := _rig(v)
		var atteso := _rig(g)
		for c in ["vis.x", "vis.rz", "testa.rz", "testa.y", "corpo.sy", "corpo.sx"]:
			t.almost(float(dopo[c]), float(atteso[c]),
					"«%s»: «%s» è quello del GEMELLO dopo l'interruzione" % [stato, c],
					0.004)


func _la_scala_e_di_chi_cresce(t) -> void:
	# LA SCALA HA UN PADRONE, e non è il gesto: `set_cucciolo` scrive
	# `_corpo.scale` in assoluto. Un gesto in corso deve SPEGNERSI, non
	# combattere — e la scala che ne esce dev'essere esattamente quella
	# della crescita, non quella di riposo di due frame fa.
	var v = _corpo(t, 77)
	v._enter_state("r_idle")
	_gira(v, 0.4)
	var corpo: Node3D = v.get("_corpo")
	var base: Vector3 = corpo.scale
	t.ok(v.gesto("raccolto"), "il Raccolto parte")
	_gira(v, 1.6)
	t.ok(corpo.scale.y < base.y * 0.97,
			"a metà Raccolto il corpo è compresso (%.3f contro %.3f)"
					% [corpo.scale.y, base.y])
	# IL VOLUME SI CONSERVA: chi si comprime si ALLARGA
	t.ok(corpo.scale.x > base.x * 1.01,
			"…e allargato (%.3f contro %.3f)" % [corpo.scale.x, base.x])
	# ⚠️ **IL TAGLIO SECCO È L'UNICO POSTO IN CUI LA RESTITUZIONE SI VEDE**, e
	# senza questo caso quella riga era una guardia che nessun test poteva far
	# fallire (misurato: togliendola, zero asserzioni rosse su 578). La rampa
	# riporta la scala a uno da sé, dolcemente; `gesto_spegni(true)` no — è
	# per chi sta smontando il corpo, e deve restituire la scala **nello
	# stesso istante**, o il corpo resta schiacciato per sempre.
	var v2 = _corpo(t, 77)
	v2._enter_state("r_idle")
	v2.set("_timer", 1.0e9)
	_gira(v2, 0.4)
	var corpo2: Node3D = v2.get("_corpo")
	var base2: Vector3 = corpo2.scale
	v2.gesto("raccolto")
	_gira(v2, 1.6)
	t.ok(corpo2.scale.y < base2.y * 0.97, "il secondo corpo è compresso")
	v2.gesto_spegni(true)
	t.almost(corpo2.scale.y, base2.y,
			"il taglio secco restituisce la scala NELLO STESSO ISTANTE", 0.0001)
	t.almost(corpo2.scale.x, base2.x, "…su tutti e tre gli assi", 0.0001)

	v.set_cucciolo(0.3)
	_gira(v, 0.5)
	t.eq(str(v.gesto_in_corso()), "", "la crescita ha spento il gesto")
	var cb: Vector3 = v.get("_corpo_base")
	var e := 0.3 * 0.3 * (3.0 - 2.0 * 0.3)
	t.almost(corpo.scale.y, cb.y * lerpf(VISITOR.TAGLIA_CUCCIOLO, 1.0, e),
			"…e la scala è ESATTAMENTE quella della crescita", 0.0005)
	t.almost(corpo.scale.x, corpo.scale.z, "…isotropa, come la crescita")


func _il_debito_ha_un_tetto(t) -> void:
	# la rete del ritmo: un gesto che rubasse più di `DEBITO_MAX` metri si
	# spegne, e il corpo torna a camminare. Si costruisce apposta un Punto
	# fuori scala — nel gioco non lo chiede nessuno, ma la rete deve esserci.
	var v = _corpo(t, 51)
	_in_cammino(v)
	t.ok(v.gesto("punto", {"tenuta": 30.0}),
			"un Punto smisurato parte (la rete non è una precondizione)")
	_gira(v, GESTI.DEBITO_MAX / GESTI.VELOCITA_METRO + 0.6)
	t.almost(float(v.get("_gs_r")), 1.0,
			"…e il tetto del debito lo ha spento: il corpo cammina di nuovo", 0.01)


func _l_anziano_non_frena(t) -> void:
	# `_move_gait` ferma già chi ha vissuto per 1,3 s ogni 7,5. Due sistemi
	# che rallentano lo stesso corpo sono un corpo che si impunta: il Punto
	# aspetta il FIATO e ci si accomoda sopra.
	var v = _corpo(t, 1234)
	v.set_eta(0.8)
	_in_cammino(v)
	# lo si chiede FUORI dal fiato: deve mettersi in attesa, non frenare
	v.set("_t", 4.0)     # 4.0 s dentro un periodo di 7,5 → fuori dal fiato
	t.ok(v.gesto("punto"), "su un anziano il Punto viene accettato")
	t.eq(str(v.gesto_in_corso()), "punto", "…e resta in attesa del suo fiato")
	var frenato := false
	for _i in 30:
		v._process(DT)
		if float(v.get("_gs_r")) < 0.98:
			frenato = true
	t.ok(not frenato, "…senza mai toccare il ritmo mentre aspetta")
	# arrivato il fiato, il gesto parte — e ANCORA non tocca il ritmo
	_gira(v, 4.0)
	t.almost(float(v.get("_gs_r")), 1.0,
			"anche partito, il Punto di un anziano non frena", 0.001)


func _la_coda_decade_prima_del_riarmo(t) -> void:
	# ⚠️ IL NUMERO CHE FA LA DIFFERENZA FRA UN LIVELLO E UN GUASTO. Il
	# raffreddamento del sussulto è 9 s per residente: se la coda somatica
	# vivesse più a lungo, si riaccenderebbe prima di essersi spenta e
	# resterebbe accesa il 100% del tempo su chiunque il giocatore sfiori
	# camminando — cioè il livello monotono che la regola dei livelli vieta.
	t.ok(GESTI.coda_ampiezza(1.0, 9.0) <= 0.0,
			"a forza PIENA la coda è già spenta al riarmo (9 s)")
	t.ok(GESTI.coda_ampiezza(1.0, 6.0) > 0.0,
			"…ma a sei secondi c'è ancora")
	var v = _corpo(t, 88)
	var g = _corpo(t, 88)
	for corpo in [v, g]:
		corpo._enter_state("r_idle")
		corpo.set("_timer", 1.0e9)   # o `r_idle` scade e il corpo riparte
		_gira(corpo, 0.3)
	var prima := _rig(g)
	v.somatico(1.0)
	_gira(v, 1.0)
	_gira(g, 1.0)
	t.ok(absf(float(_rig(v)["ear0"]) - float(prima["ear0"])) > 0.05,
			"la coda somatica si vede addosso (le orecchie)")
	t.ok(float(v.get("_gs_r")) < 0.9,
			"…e il passo cala (%.3f)" % float(v.get("_gs_r")))
	# DUE STRATI, DUE VITE, e questo è il punto della meccanica: la CODA
	# (veloce) muore prima del riarmo del sussulto, il RALLENTANDO (lento)
	# vive molto più a lungo — ed è l'unica cosa del vocabolario che arriva
	# ai venti vicini lontani, dove nessuna posa è più di sei pixel.
	_gira(v, 9.0)
	_gira(g, 9.0)
	t.ok(float(v.get("_gs_r")) < 0.99,
			"a nove secondi il RALLENTANDO vive ancora (%.3f)" % float(v.get("_gs_r")))
	t.ok(float(v.get("_gs_r")) >= GESTI.SOMA_PAVIMENTO,
			"…e non scende mai sotto il pavimento (%.3f)" % float(v.get("_gs_r")))
	_gira(v, 70.0)
	_gira(g, 70.0)
	t.almost(float(v.get("_gs_r")), 1.0,
			"e alla fine rientra anche lui: nessun livello resta acceso", 0.01)
	_normalizza(v)
	_normalizza(g)
	var dopo := _rig(v)
	var atteso := _rig(g)
	for c in atteso:
		t.almost(float(dopo[c]), float(atteso[c]),
				"spenti i due strati, «%s» è quello del gemello" % c, 0.003)


func _il_capo_e_una_sequenza_non_un_seno(t) -> void:
	# IL CAPO CHE PENDE non è un `sin`: è una sequenza di TRASFERIMENTI con
	# una molla sottosmorzata, e fra l'uno e l'altro NON SUCCEDE NIENTE. È
	# l'immobilità a rendere leggibile il trasferimento — un'oscillazione
	# continua è un metronomo, e un metronomo si smette di vedere.
	var v = _corpo(t, 4242)
	v._enter_state("r_idle")
	_gira(v, 0.4)
	v.capo_pende(true)
	var campioni: Array[float] = []
	for _i in int(30.0 / DT):
		v._process(DT)
		campioni.append(float(v.get("_gs_capo_x")))
	var maxi_ := 0.0
	for c in campioni:
		maxi_ = maxf(maxi_, absf(c))
	t.ok(maxi_ >= GESTI.CAPO_AMP_MIN * 0.95 and maxi_ <= GESTI.CAPO_AMP_MAX * 1.45,
			"il rollio sta nella forbice misurata (%.3f)" % maxi_)
	# QUANTO STA FERMO: la frazione di tempo in cui il capo non si muove
	# quasi. Sotto la metà sarebbe un'oscillazione, non una sequenza.
	var fermi := 0
	for i in range(1, campioni.size()):
		if absf(campioni[i] - campioni[i - 1]) < 0.0006:
			fermi += 1
	t.ok(float(fermi) / float(campioni.size()) > 0.5,
			"il capo sta FERMO più della metà del tempo (%.0f%%)"
					% (100.0 * float(fermi) / float(campioni.size())))
	# E NON PASSA MAI DUE VOLTE PER LO STESSO PUNTO NELLO STESSO MODO: due
	# orologi incommensurabili, quindi gli intervalli non si ripetono.
	var v2 = _corpo(t, 999)
	v2._enter_state("r_idle")
	_gira(v2, 0.4)
	v2.capo_pende(true)
	var diverso := false
	for i in int(30.0 / DT):
		v2._process(DT)
		if absf(float(v2.get("_gs_capo_x")) - campioni[i]) > 0.01:
			diverso = true
	t.ok(diverso, "due genomi diversi non pendono all'unisono")
	# e SPEGNENDOLO la molla rientra da sé: è la sua rete
	v.capo_pende(false)
	_gira(v, 2.0)
	t.almost(float(v.get("_gs_capo_x")), 0.0, "spento, il capo torna dritto", 0.002)


func _il_verso_del_passo(t) -> void:
	# LA RIGA GRATIS. `Andatura.misura` usava il MODULO dello spostamento:
	# la fase avanzava anche per un corpo che va INDIETRO — le zampe facevano
	# il passo in avanti mentre il corpo indietreggiava. È in partita adesso
	# (`tk_startle` tweena il corpo verso `position + basis.z * 0.7`).
	var a = ANDATURA.new()
	a.misura(DT, Vector3.ZERO, 0.0)
	# il muso guarda −Z: si cammina in avanti andando verso −Z
	a.misura(DT, Vector3(0, 0, -0.03), 0.0)
	var avanti: float = a.fase
	t.ok(avanti > 0.0, "camminando avanti la fase AVANZA (%.4f)" % avanti)
	var b = ANDATURA.new()
	b.misura(DT, Vector3.ZERO, 0.0)
	b.misura(DT, Vector3(0, 0, 0.03), 0.0)     # all'indietro
	t.ok(b.fase < 0.0, "camminando all'INDIETRO la fase torna indietro (%.4f)" % b.fase)
	t.almost(b.fase, -avanti, "…e di tanto quanto", 0.0001)


func _venti_e_centoquarantaquattro(t) -> void:
	# LA DERIVA DEL `+=` SU UNA BASE NON RISCRITTA è già costata a questo
	# progetto un canale che passava «da 9,6° a 30 fps a 46° a 144». I canali
	# del vocabolario si misurano a due frequenze molto diverse, e la posa
	# alla stessa età dev'essere la stessa.
	for passo: float in [1.0 / 20.0, 1.0 / 144.0]:
		var v = _corpo(t, 606)
		v._enter_state("r_idle")
		_gira(v, 0.4, passo)
		v.gesto("raccolto")
		_gira(v, 2.6, passo)
		var r := _rig(v)
		# il riferimento è la corsa a 60 Hz
		if passo > 0.04:
			_rif_20 = r
		else:
			for c in r:
				t.almost(float(r[c]), float(_rif_20[c]),
						"«%s» uguale a 20 e a 144 fotogrammi al secondo" % c, 0.02)
		# e la RETE regge a qualunque frequenza
		v._enter_state("r_pasto")
		_gira(v, 1.2, passo)
		t.almost(float(v.get("_gs_r")), 1.0,
				"il ritmo rientra anche a %.0f fps" % (1.0 / passo), 0.004)


var _rif_20 := {}


func _il_rialzo_non_si_recita_da_solo(t) -> void:
	# LA GRAMMATICA. Il Rialzo non si recita da solo: «mi è tornato in mente»
	# detto da solo è una lampadina accesa a mezzogiorno. Vive INNESTATO —
	# nella ripartenza decisa del Punto e nel rilascio del Raccolto — e
	# questo si prova sui CANALI, non su una tabella.
	#
	# ⚠️ **LA REGOLA È «SOLO COL BUIO», NON «MAI»**, e la differenza è tutta
	# in queste tre righe. La prima stesura chiedeva che nessuna frase fosse
	# un Rialzo nudo, cioè giudicava la TABELLA — ma il buio non deve per
	# forza venire di lì: quello del sollievo è il SUSSULTO, passato quattro
	# decimi di secondo prima, che ha irrigidito il corpo davvero
	# (`Visitors._tick_riconoscimenti`, la strada veloce che precede la
	# lenta). Quel che va provato è che il buio ci sia **sul corpo**: una
	# frase che porta un Rialzo nudo deve DICHIARARLO, e `Visitor.gesto()`
	# deve rifiutarla quando quel buio non c'è. La prova che morde sta in
	# `test_regia._il_sollievo_vuole_il_buio`.
	for f in GESTI.FRASI:
		var fr: Dictionary = GESTI.FRASI[f]
		if str(fr["g"]) != "rialzo":
			continue
		t.ok(bool((fr["d"] as Dictionary).get("buio", false)),
				"la frase «%s» è un Rialzo nudo e dichiara il buio" % f)
	# il Punto DECISO porta il Rialzo addosso: dopo la tenuta il corpo SALE
	var fine: float = GESTI.PUNTO_FRENO + GESTI.PUNTO_TENUTA
	var molle: Dictionary = GESTI.bersagli("punto",
			fine + 0.12, {"tenuta": GESTI.PUNTO_TENUTA}, 1.0)
	var deciso: Dictionary = GESTI.bersagli("punto",
			fine + 0.12, {"tenuta": GESTI.PUNTO_TENUTA, "decisa": true}, 1.0)
	t.ok(float(deciso["vy"]) - float(molle["vy"]) > 0.03,
			"la ripartenza decisa SOLLEVA il corpo (%.3f contro %.3f)"
					% [float(deciso["vy"]), float(molle["vy"])])
	t.ok(float(deciso["sy"]) > float(molle["sy"]) + 0.01,
			"…e lo allunga")
	# il Raccolto con `rialzo` esce salendo, e più piano del Rialzo pieno
	var senza: Dictionary = GESTI.bersagli("raccolto",
			0.9 + GESTI.RACCOLTO_TENUTA + 0.12, {}, 1.0)
	var con: Dictionary = GESTI.bersagli("raccolto",
			0.9 + GESTI.RACCOLTO_TENUTA + 0.12, {"rialzo": 0.6}, 1.0)
	t.ok(float(con["vy"]) > float(senza["vy"]) + 0.01,
			"dalla rinuncia si esce con un mezzo respiro")
	t.ok(float(con["vy"]) < GESTI.RIALZO_VY * 0.8,
			"…ma più piccolo del Rialzo pieno: da una rinuncia non si esce trionfanti")


func _il_largo_si_scosta_dalla_parte_giusta(t) -> void:
	# IL VERSO DELLO SCOSTAMENTO è una domanda nel frame DEL CORPO, e il rig
	# guarda −Z: un `atan2` col segno storto ha tenuto il fantasma del
	# congedo di spalle a Mochi per mesi, sotto un commento che giurava il
	# contrario. Qui si guarda dove finisce il corpo, non che segno ha una
	# variabile.
	for lato: float in [1.0, -1.0]:
		var v = _corpo(t, 2024)
		v._enter_state("r_idle")
		v.set("_yaw", 0.0)          # il muso verso −Z
		v._walk_to(Vector3(0, 0, -40), "r_idle")
		_gira(v, 0.7)
		# il posto insopportabile alla sua DESTRA (lato=+1) o sinistra
		var posto: Vector3 = v.global_position + Vector3(3.0 * lato, 0.0, 0.5)
		t.ok(v.gesto("largo", {"posto": posto}), "il Largo parte")
		_gira(v, 1.4)
		var vis: Node3D = v.get("_vis")
		# ci si scosta VIA dal posto: se il posto è a destra (+X locale), il
		# corpo va a sinistra (−X)
		t.ok(signf(vis.position.x) == -lato,
				"col posto a %s il corpo si scosta dall'altra parte (px %.3f)"
						% ["destra" if lato > 0.0 else "sinistra", vis.position.x])
		t.ok(absf(vis.position.x) > GESTI.LARGO_PX * 0.5,
				"…e di quanto basta (%.3f m)" % absf(vis.position.x))
		# e la TESTA resta indietro, verso il posto
		var testa: Node3D = v.get("_head")
		t.ok(absf(testa.rotation.y) > 0.05,
				"…con la testa che si stacca a fatica (%.3f rad)" % testa.rotation.y)


# =========================================================================
# LE DUE REGOLE DI QUALITÀ, che nessun'altra asserzione sapeva far fallire
# =========================================================================

## ⚠️ **UN GESTO TRONCATO NON DEVE SALTARE**, e senza questo caso la rampa
## (`Gesti.SPEGNI`) era una guardia che nessun test poteva far fallire:
## togliendola, 582 asserzioni restavano verdi. Eppure è la differenza fra un
## corpo che rientra e un adesivo staccato male — e i gesti vengono troncati
## di continuo, perché il mondo interrompe.
##
## La soglia non è a occhio: è il MASSIMO MISURATO col codice sano — 0,0197
## rad per fotogramma sull'orecchio destro, che è il colmo della derivata
## della rampa — con mezzo margine sopra. Senza rampa lo stesso canale
## rientra tutto in UN fotogramma: 0,28 rad, quattordici volte tanto.
const SALTO_MAX := 0.030

func _il_gesto_troncato_non_salta(t) -> void:
	var v = _corpo(t, 4711)
	v._enter_state("r_idle")
	v.set("_timer", 1.0e9)
	_gira(v, 0.4)
	v.gesto("raccolto")
	_gira(v, 1.6)               # piena compressione
	var prima := _rig(v)
	# si tronca come lo tronca il mondo: uno stato nuovo, non una funzione di
	# comodo. `_enter_state` è il posto da cui passano tutte e undici le
	# interruzioni vere.
	#
	# ⚠️ …e lo stato nuovo è uno che NON muove il corpo. Con `r_wander` — che
	# manda il corpo a camminare — il salto misurato era 0,0400 sul rollio
	# del busto, e non era il gesto: era il ciclo del passo che si accendeva.
	# Un banco che misura la cosa sbagliata è severo su niente.
	v._enter_state("r_idle")
	v.set("_timer", 1.0e9)
	var salto := 0.0
	var quale := ""
	for _i in int((GESTI.SPEGNI + 0.4) / DT):
		v._process(DT)
		var ora := _rig(v)
		for c in ora:
			var d: float = absf(float(ora[c]) - float(prima[c]))
			if d > salto:
				salto = d
				quale = c
		prima = ora
	t.ok(salto <= SALTO_MAX,
			"il gesto troncato rientra senza saltare (max %.4f su «%s», tetto %.3f)"
					% [salto, quale, SALTO_MAX])


## ⚠️ **MAI «POSA + ADESIVO».** Un corpo fermo che è *davvero* fermo è un
## fermo immagine, e si smaschera in un secondo; un `sin()` puro si smaschera
## in due cicli. Questo caso guarda le due cose insieme sull'assestamento del
## Punto — l'unico micro-movimento che vive dentro la tenuta — e senza di lui
## si poteva azzerare quel canale lasciando la suite tutta verde.
func _niente_posa_piu_adesivo(t) -> void:
	# UNA TENUTA LUNGA, apposta: nel gioco non si chiede (il Punto sta fra
	# 1,6 e 2,4 s) ma la proprietà da provare è della FUNZIONE, e su due
	# secondi un periodo di sette non si vedrebbe nemmeno se ci fosse.
	var d := {"tenuta": 30.0}
	var campioni: Array[float] = []
	var t0 := GESTI.PUNTO_FRENO + 0.6
	for i in 1400:
		var x := t0 + float(i) * 0.02
		campioni.append(float(GESTI.bersagli("punto", x, d, 1.7)["px"]))
	var lo := 1.0e9
	var hi := -1.0e9
	for c in campioni:
		lo = minf(lo, c)
		hi = maxf(hi, c)
	t.ok(hi - lo > 0.004,
			"dentro la tenuta il corpo si ASSESTA: non è un fermo immagine (%.4f m)"
					% (hi - lo))
	t.ok(hi - lo < 0.03, "…ma di quel tanto: è un peso che si sposta, non un passo")
	# E NON SI RICHIUDE MAI. Si cerca un periodo — uno qualunque, fra mezzo
	# secondo e dodici — che rimetta la curva su sé stessa. Con due orologi
	# incommensurabili non esiste; con un `sin()` puro si trova subito.
	var soglia := (hi - lo) * 0.12
	var periodo := -1.0
	var p := 0.5
	while p <= 12.0:
		var lag := int(p / 0.02)
		var peggio := 0.0
		for i in range(0, campioni.size() - lag):
			peggio = maxf(peggio, absf(campioni[i] - campioni[i + lag]))
		if peggio < soglia:
			periodo = p
			break
		p += 0.02
	t.ok(periodo < 0.0,
			"l'assestamento non si richiude MAI su sé stesso"
					+ ("" if periodo < 0.0 else " (si ripete ogni %.2f s)" % periodo))
	# la controprova: un `sin()` puro lo stesso banco lo trova in un colpo
	var puro: Array[float] = []
	for i in 1400:
		puro.append(0.008 * sin(float(i) * 0.02 * 0.83))
	var trovato := -1.0
	p = 0.5
	while p <= 12.0:
		var lag := int(p / 0.02)
		var peggio := 0.0
		for i in range(0, puro.size() - lag):
			peggio = maxf(peggio, absf(puro[i] - puro[i + lag]))
		if peggio < 0.016 * 0.12:
			trovato = p
			break
		p += 0.02
	t.ok(trovato > 0.0,
			"…e la controprova: su un sin() puro questo stesso banco trova il periodo (%.2f s)"
					% trovato)

## L'ESITAZIONE DEL LARGO — l'unico canale di questo gesto che si veda.
##
## ⚠️ **GUARDATA, non dedotta** (`tools/provino_vocabolario.gd`, parte X:
## cinque varianti affiancate ed etichettate, a sei metri, di tre quarti e di
## spalle, col riquadro fermo sulla riga che il corpo avrebbe fatto). Senza
## esitazione le otto tessere della striscia sono la stessa immagine: nove
## centimetri di scostamento non si vedono, perché **non c'è niente con cui
## confrontarli** — il Punto si legge contro il corpo di prima, un corpo che
## cammina nove centimetri più in là no. Con l'esitazione il corpo resta
## indietro fra 0,3 e 0,6 s, e quello si vede.
##
## Qui si sorveglia la FORMA, cioè le tre cose che rendono l'esitazione
## un'esitazione e non una fermata: c'è, dura poco, e finisce sopra uno.
func _il_largo_esita_prima_di_scostarsi(t) -> void:
	var trough := 2.0
	var t_trough := -1.0
	var s := 0.0
	while s < 0.9:
		var r: float = float(GESTI.bersagli("largo", s, {})["r"])
		if r < trough:
			trough = r
			t_trough = s
		s += 1.0 / 240.0
	t.ok(trough < 0.85,
			"il Largo ESITA: il ritmo scende a %.2f (com'era, non scendeva mai)" % trough)
	# …ma non è una fermata: quella è la parola del Punto, e due parole che
	# si dicono con lo stesso corpo sono una parola sola detta male
	# ⚠️ la soglia è 0,40 e non 0,30 APPOSTA: a 0,30 la variante «esitazione
	# forte» (dip 0,70), che il provino ha scartato perché diventa una
	# fermata, sarebbe passata per un centesimo — cioè la guardia non
	# avrebbe sorvegliato la mutazione contro cui esiste. MISURATO: dip 0,45
	# → 0,57 · dip 0,70 → 0,31.
	t.ok(trough > 0.40,
			"…e non è una fermata (%.2f, il Punto va a zero)" % trough)
	t.ok(t_trough < 0.35,
			"l'esitazione è PRIMA dello scostamento (colmo a %.2f s)" % t_trough)
	# e si è già ripresa quando il corpo si scosta davvero
	t.ok(float(GESTI.bersagli("largo", 0.9, {})["r"]) > 1.0,
			"a nove decimi il passo è di nuovo pieno: si attraversa la vita, non la si interrompe")
	# e costa pochi centimetri: la rete del debito non c'entra
	t.ok(GESTI.costo_metri("largo", {}) < 0.6,
			"l'esitazione costa meno di mezzo metro (%.2f m)"
			% GESTI.costo_metri("largo", {}))


# =========================================================================
# LE DUE METÀ — la regola che la suite non sapeva far fallire
# =========================================================================
#
# ⚠️ **NIENTE DI QUESTO FILE VEDEVA IL DIFETTO.** Quattro gesti su sette
# muovevano i due arti sullo stesso identico filo, e 66804 asserzioni erano
# verdi: si poteva scrivere `out["ax1"] = out["ax0"]` in tre punti e nessuna
# si accorgeva di niente. La ragione è che un'asimmetria di TEMPO **non
# esiste in un istante**: è la differenza fra due istanti, e ogni asserzione
# di questo file guardava un istante.
#
# IL METRO È IL **RESIDUO DI FORMA**, e l'oracolo è qui dentro, scritto per
# esteso: si cerca la costante `k` che meglio sovrappone la destra alla
# sinistra (minimi quadrati) e si guarda quanto resta. Zero vuol dire che la
# destra È la sinistra moltiplicata per un numero — cioè un filo solo — e
# **nessuna differenza di ampiezza può salvarlo**: 0,28 contro 0,22 dà
# residuo zero esattamente come 0,22 contro 0,22.
#
# ⚠️ E si guarda **il corpo PEGGIORE, non il corpo medio**. Quanto è pigra la
# metà che segue viene dal genoma (`Gesti.pigrizia`), quindi provarne uno
# solo vuol dire provare un vicino solo — e la prima stesura del banco aveva
# pescato proprio la fase del minimo, leggendo metà della cura e credendo di
# leggerla tutta.

## Le soglie sono MISURATE (`tools/misura_asimmetrie.gd`, il peggiore su
## sedici fasi), con circa un terzo di margine sotto:
##
##   il Raccolto · braccia   16,3 %   ·   orecchie   17,4 %
##   il Largo    · braccia   33,0 %   ·   orecchie   32,9 %
##   il Punto    · orecchie  48,5 %   ·   il Rialzo  79,7 %
##   la Coda     · braccia    4,1 %   ·   orecchie    6,5 %
##
## I LIVELLI hanno una soglia più bassa, e non è indulgenza: **un livello non
## ha un attacco**. Il residuo di un gesto viene dalla busta (una metà arriva
## dopo); un livello ha solo un'ampiezza che decade, e ritardare un
## esponenziale non cambia la sua forma di un capello. Là l'unica asimmetria
## possibile è il micro-movimento, e il micro-movimento è piccolo per
## definizione — se non lo fosse sarebbe un tremore, che è un'altra parola.
const FILO_EVENTO := 0.10
const FILO_LIVELLO := 0.030


func _le_due_meta_non_sono_un_filo_solo(t) -> void:
	# gli EVENTI, con le loro buste
	for p: Array in [
			["il Raccolto", "raccolto", {}, 5.1],
			["il Raccolto→Rialzo", "raccolto", {"rialzo": 0.6}, 5.1],
			["il Largo", "largo", {}, 3.0],
			["il Largo (dall'altra parte)", "largo", {"via": -1.0}, 3.0],
			["il Punto", "punto", {}, 3.4],
			["il Rialzo", "rialzo", {}, 1.6]]:
		var peggio_or := 1.0e9
		var peggio_br := 1.0e9
		var lag_or := 0
		for f in 8:
			var fase := 0.05 + TAU * float(f) / 8.0
			var orecchie := _due_meta(str(p[1]), p[2], float(p[3]), fase, true)
			var braccia := _due_meta(str(p[1]), p[2], float(p[3]), fase, false)
			peggio_or = minf(peggio_or, float(orecchie[0]))
			if absf(float(orecchie[1])) > absf(float(lag_or)):
				lag_or = int(orecchie[1])
			# il Punto e il Rialzo non muovono le braccia, e non devono:
			# un canale che non si scrive non è un filo solo, è un canale
			# che non c'è
			if float(braccia[2]) > 0.001:
				peggio_br = minf(peggio_br, float(braccia[0]))
		t.ok(peggio_or >= FILO_EVENTO,
				"%s: le due ORECCHIE non sono un filo solo (residuo %.1f%%, soglia %.0f%%)"
						% [str(p[0]), 100.0 * peggio_or, 100.0 * FILO_EVENTO])
		t.ok(lag_or != 0,
				"%s: …e non sono nemmeno sullo stesso orologio (sfasamento %d fotogrammi)"
						% [str(p[0]), lag_or])
		if peggio_br < 1.0e8:
			t.ok(peggio_br >= FILO_EVENTO,
					"%s: le due BRACCIA non sono un filo solo (residuo %.1f%%)"
							% [str(p[0]), 100.0 * peggio_br])

	# i LIVELLI: nessuna busta, quindi l'asimmetria è tutta nel micro
	for f in 8:
		var fase := 0.05 + TAU * float(f) / 8.0
		var sx_or: Array[float] = []
		var dx_or: Array[float] = []
		var sx_br: Array[float] = []
		var dx_br: Array[float] = []
		var n := int(GESTI.CODA_VITA * 60.0)
		for i in n:
			var tt := float(i) * DT
			var a: float = GESTI.coda_ampiezza(1.0, tt)
			var c: Dictionary = GESTI.coda_canali(a, tt, fase)
			sx_or.append(float(c["ear"]))
			dx_or.append(float(c["ear"]) + float(c["ear_dx"]))
			sx_br.append(float(c["ax0"]))
			dx_br.append(float(c["ax1"]))
		t.ok(_residuo_forma(sx_or, dx_or, 0) >= FILO_LIVELLO,
				"la Coda: le due orecchie non sono un filo solo (residuo %.1f%%)"
						% (100.0 * _residuo_forma(sx_or, dx_or, 0)))
		t.ok(_residuo_forma(sx_br, dx_br, 0) >= FILO_LIVELLO,
				"la Coda: le due braccia non sono un filo solo (residuo %.1f%%)"
						% (100.0 * _residuo_forma(sx_br, dx_br, 0)))


## Il residuo di forma di un canale doppio, più lo sfasamento che lo
## minimizza. Torna [residuo, lag, ampiezza].
func _due_meta(g: String, d: Dictionary, dur: float, fase: float,
		orecchie: bool) -> Array:
	var sx: Array[float] = []
	var dx: Array[float] = []
	var n := int(dur * 60.0)
	for i in n:
		var c: Dictionary = GESTI.bersagli(g, float(i) * DT, d, fase)
		if orecchie:
			sx.append(float(c["ear"]))
			dx.append(float(c["ear"]) + float(c["ear_dx"]))
		else:
			sx.append(float(c["ax0"]))
			dx.append(float(c["ax1"]))
	var amp := 0.0
	for v in sx:
		amp = maxf(amp, absf(v))
	for v in dx:
		amp = maxf(amp, absf(v))
	var res := _residuo_forma(sx, dx, 0)
	var lag := 0
	var meglio := res
	for l in range(-20, 21):
		var r := _residuo_forma(sx, dx, l)
		if r < meglio:
			meglio = r
			lag = l
	return [res, lag, amp]


## L'ORACOLO, scritto per esteso e senza chiedere niente a `Gesti`: `k` ai
## minimi quadrati, e il peggior scarto che resta, in frazione dell'ampiezza.
func _residuo_forma(sx: Array[float], dx: Array[float], lag: int) -> float:
	var num := 0.0
	var den := 0.0
	var amp := 0.0
	for i in sx.size():
		var j := i + lag
		if j < 0 or j >= sx.size():
			continue
		num += sx[i] * dx[j]
		den += sx[i] * sx[i]
		amp = maxf(amp, absf(sx[i]))
	if den <= 1.0e-12 or amp <= 1.0e-9:
		return 0.0
	var k := num / den
	var peggio := 0.0
	for i in sx.size():
		var j := i + lag
		if j < 0 or j >= sx.size():
			continue
		peggio = maxf(peggio, absf(dx[j] - k * sx[i]))
	return peggio / amp


## ⚠️ **E LA TENUTA È IL POSTO DOVE UN'ASIMMETRIA DI TEMPO SPARISCE.** Dopo
## l'attacco le due metà sono arrivate tutte e due, e restano ferme nello
## stesso rapporto per due secondi: la posa più l'adesivo, cioè quello che
## la regola vieta per prima.
##
## ⚠️ **E L'ORACOLO NON È «IL RAPPORTO CAMBIA», ED È UNA LEZIONE.** La prima
## stesura chiedeva che il rapporto fra le due metà avesse un'escursione:
## restava verde con il tremolio azzerato, perché le due buste **convergono**
## per tutta la tenuta e il rapporto sale comunque. Una deriva monotòna non
## è vita — è la stessa posa che arriva piano. Quel che distingue un corpo da
## un adesivo è che il movimento **cambia verso**: qui si contano le
## inversioni, per ogni metà e per il rapporto, e la metà che segue non deve
## invertire negli stessi istanti dell'altra.
func _la_tenuta_non_e_una_posa(t) -> void:
	# ⚠️ UNA TENUTA LUNGA, apposta — è la stessa ragione per cui
	# `_niente_posa_piu_adesivo` ne chiede trenta: la proprietà da provare è
	# della FUNZIONE. Con la tenuta di serie (2 s) la busta della metà che
	# segue sta ANCORA salendo per tutta la finestra (sale di 0,001 rad per
	# fotogramma contro gli 0,0003 del tremolio), quindi il tremolio è
	# sommerso e il banco misurerebbe l'attacco credendo di misurare la
	# tenuta.
	var d := {"tenuta": 6.0}
	for f in 6:
		var fase := 0.2 + TAU * float(f) / 6.0
		var sx: Array[float] = []
		var dx: Array[float] = []
		var b0: Array[float] = []
		var b1: Array[float] = []
		# a buste arrivate, e prima del rilascio
		var x := 3.5
		while x < 6.5:
			var c: Dictionary = GESTI.bersagli("raccolto", x, d, fase)
			sx.append(float(c["ear"]))
			dx.append(float(c["ear"]) + float(c["ear_dx"]))
			b0.append(float(c["ax0"]))
			b1.append(float(c["ax1"]))
			x += DT
		var i_sx := _inversioni(sx)
		var i_dx := _inversioni(dx)
		t.ok(i_sx.size() >= 2,
				"dentro la tenuta l'orecchio SINISTRO cambia verso (%d volte)"
						% i_sx.size())
		t.ok(i_dx.size() >= 2,
				"…e il DESTRO anche (%d volte)" % i_dx.size())
		t.ok(_inversioni(b0).size() >= 2 and _inversioni(b1).size() >= 2,
				"…e le due braccia pure (%d e %d)"
						% [_inversioni(b0).size(), _inversioni(b1).size()])
		# e non nello stesso istante: due metà che invertono insieme sono un
		# filo solo che ondeggia
		var insieme := 0
		for a: int in i_sx:
			for b: int in i_dx:
				if absi(a - b) <= 2:
					insieme += 1
					break
		t.ok(insieme < i_sx.size(),
				"…e non cambiano verso negli stessi istanti (%d su %d coincidono)"
						% [insieme, i_sx.size()])


## Gli indici in cui una curva cambia verso. La soglia sul dislivello toglie
## il rumore di virgola mobile senza toccare un micro-movimento vero: un
## tremolio da 0,007 rad su un fotogramma vale mille volte tanto.
func _inversioni(v: Array[float]) -> Array[int]:
	var out: Array[int] = []
	var verso := 0
	for i in range(1, v.size()):
		var dd: float = v[i] - v[i - 1]
		if absf(dd) < 1.0e-7:
			continue
		var s: int = 1 if dd > 0.0 else -1
		if verso != 0 and s != verso:
			out.append(i)
		verso = s
	return out


# =========================================================================
# I LIVELLI NON SI STACCANO — la seconda regola che nessuno sorvegliava
# =========================================================================

## Il tetto dello scatto per fotogramma quando il mondo toglie il corpo di
## mano. MISURATO col codice sano: 0,0176 rad entrando in una scena, 0,0087
## uscendone (`tools/misura_asimmetrie.gd`). Il tetto è quello di un GESTO
## troncato (`SALTO_MAX`, 0,030), perché un livello non ha nessun diritto di
## saltare più di un gesto — anzi: i suoi canali sono i più grossi che il
## vocabolario abbia. Senza rampa lo stesso banco misurava **0,4158**.
const SALTO_LIVELLO := 0.025
## …e il livello deve essere DAVVERO passato di mano quando la rampa è
## finita. Senza questa metà, una rampa di dieci secondi passerebbe la
## prima: lo scatto per fotogramma sarebbe minuscolo e l'allerta di uno
## spavento resterebbe addosso al corpo per tutta la scena scritta a mano —
## che è il guasto che la sospensione esiste per impedire.
const LIVELLO_SPENTO := 0.006


func _i_livelli_non_si_staccano(t) -> void:
	var v = _corpo(t, 4242)
	v._enter_state("r_idle")
	v.set("_timer", 1.0e9)
	_gira(v, 0.2)
	# i due livelli addosso, DALLE PORTE VERE
	v.capo_pende(true)
	v.somatico(1.0)
	# si aspetta che il rollio sia lontano da zero: uno scatto da zero non è
	# uno scatto, e la guardia non sorveglierebbe niente
	var colmo := 0.0
	for _i in 400:
		v._process(DT)
		colmo = maxf(colmo, absf(float(v.get("_gs_capo_x"))))
		if absf(float(v.get("_gs_capo_x"))) > 0.06:
			break
	t.ok(colmo > 0.05,
			"il rollio del capo è a regime prima della scena (%.4f rad)" % colmo)
	var prima := _rig(v)
	var ear_prima: float = absf(float(prima["ear1"]))
	t.ok(ear_prima > 0.15,
			"…e la coda somatica si vede addosso (%.3f rad)" % ear_prima)

	# LA SOSPENSIONE, dalla porta vera: una scena scritta a mano
	v.apri_scena(6.0)
	var salto := 0.0
	var quale := ""
	for _i in 45:
		v._process(DT)
		var ora := _rig(v)
		for c in ora:
			var dd: float = absf(float(ora[c]) - float(prima[c]))
			if dd > salto:
				salto = dd
				quale = c
		prima = ora
	t.ok(salto <= SALTO_LIVELLO,
			"i livelli passano di mano SENZA saltare (max %.4f su «%s», tetto %.3f)"
					% [salto, quale, SALTO_LIVELLO])
	# …e a rampa finita il corpo non è più loro
	_gira(v, 0.6)
	var dentro := _rig(v)
	t.ok(absf(float(dentro["ear1"])) <= LIVELLO_SPENTO,
			"dentro la scena il livello è passato di mano davvero (%.4f rad)"
					% absf(float(dentro["ear1"])))
	t.almost(float(v.get("_gs_r")), 1.0,
			"…e il ritmo è tornato a chi ha scritto la scena", 0.004)
	t.ok(float(v.get("_gs_soma")) > 0.0,
			"ma il livello NON è spento: è sospeso, e il suo orologio gira")

	# E ALL'USCITA, che è l'altra metà: rientra con la stessa rampa
	v.chiudi_scena()
	prima = _rig(v)
	var salto2 := 0.0
	var quale2 := ""
	for _i in 45:
		v._process(DT)
		var ora := _rig(v)
		for c in ora:
			var dd: float = absf(float(ora[c]) - float(prima[c]))
			if dd > salto2:
				salto2 = dd
				quale2 = c
		prima = ora
	t.ok(salto2 <= SALTO_LIVELLO,
			"…e rientrano senza saltare (max %.4f su «%s»)" % [salto2, quale2])
	t.ok(absf(float(_rig(v)["ear1"])) > 0.02,
			"…e rientrano davvero (%.4f rad)" % absf(float(_rig(v)["ear1"])))


## ⚠️ **E UN LIVELLO NON SPARISCE NEMMENO QUANDO MUORE DA SOLO.** La soglia
## di `coda_ampiezza` serve a farlo morire (senza, `_gs_soma` non si azzera
## mai); ma una soglia secca è un gradino, e al momento di sparire le
## orecchie valevano ancora 0,027 rad. È la stessa regola della rampa,
## applicata all'unico modo che questo livello ha di finire per conto suo.
func _la_coda_si_spegne_invece_di_sparire(t) -> void:
	var passo := 0.0
	var prima: float = GESTI.coda_ampiezza(1.0, 0.0)
	var x := DT
	while x < GESTI.CODA_VITA + 1.0:
		var a: float = GESTI.coda_ampiezza(1.0, x)
		passo = maxf(passo, absf(a - prima))
		prima = a
		x += DT
	# il tetto sta FRA i due numeri veri, e nessuno dei due è a occhio: il
	# decadimento naturale a forza piena vale `1/τ/60` = **0,0060** per
	# fotogramma (è il primo fotogramma della coda, e non è un gradino: è la
	# curva), mentre la soglia secca ne faceva **0,0600** — dieci volte
	# tanto — nell'istante in cui il livello spariva.
	t.ok(passo < 0.015,
			"la coda si SPEGNE: nessun gradino nell'ampiezza (max %.5f per fotogramma, naturale 0,0060, gradino 0,0600)"
					% passo)
	t.almost(prima, 0.0, "…e finisce a zero esatto")
	# e la vita non è cambiata: la coda deve morire prima del proprio riarmo
	t.ok(GESTI.coda_ampiezza(1.0, 9.0) <= 0.0,
			"…senza vivere un attimo di più (a nove secondi è spenta)")


## LE MANOPOLE DEL PROVINO NON LE SCRIVE IL GIOCO. `debug_gesti` esiste
## perché i due LIVELLI non passano da `frase(nome, extra)` e un banco deve
## poter spegnere la cura per mostrare cosa cura — ma se un giorno qualcuno
## la scrivesse dal gioco, metà del villaggio si ritroverebbe un'asimmetria
## che nessuno ha chiesto. È la stessa guardia del banco della concorrenza.
func _le_manopole_non_le_scrive_il_gioco(t) -> void:
	var trovati: Array[String] = []
	for dir_nome: String in ["res://scenes", "res://systems"]:
		_scandaglia(dir_nome, trovati)
	t.eq(trovati.size(), 0,
			"nel gioco nessuno scrive `debug_gesti`%s"
					% ("" if trovati.is_empty() else ": " + ", ".join(trovati)))


func _scandaglia(percorso: String, trovati: Array[String]) -> void:
	var dir := DirAccess.open(percorso)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var pieno := percorso + "/" + f
		if dir.current_is_dir():
			_scandaglia(pieno, trovati)
		elif f.ends_with(".gd"):
			var fa := FileAccess.open(pieno, FileAccess.READ)
			if fa != null:
				var righe := fa.get_as_text().split("\n")
				for i in righe.size():
					var r: String = righe[i].strip_edges()
					if r.begins_with("#"):
						continue
					# la DICHIARAZIONE è lecita; l'assegnazione no
					if r.begins_with("var debug_gesti"):
						continue
					if r.contains("debug_gesti =") or r.contains("debug_gesti["):
						trovati.append("%s:%d" % [f, i + 1])
		f = dir.get_next()
	dir.list_dir_end()
