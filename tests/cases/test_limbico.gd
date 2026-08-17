## Test per IL LIMBICO (scenes/npc/Limbico.gd).
##
## Qui non si verificano funzioni: si verificano FENOMENI UMANI. Ognuno di
## questi test ha un nome che un giocatore riconoscerebbe — l'abitudine, il
## contrasto, il tradimento, lo spavento che resta addosso, la goccia che fa
## traboccare il vaso. Se uno di questi si rompe, gli NPC smettono di
## sembrare persone molto prima che qualcosa smetta di funzionare.

extends RefCounted

const LIMBICO := preload("res://scenes/npc/Limbico.gd")


func run(t) -> void:
	_test_abitudine(t)
	_test_contrasto(t)
	_test_tradimento(t)
	_test_due_strade(t)
	_test_marchio_e_estinzione(t)
	_test_spavento_resta_addosso(t)
	_test_umore_lente(t)
	_test_goccia_che_trabocca(t)
	_test_carattere_cambia_il_corpo(t)
	_test_neurochimica(t)
	_test_consolida_sonno(t)
	_test_salvataggio(t)


	_il_passo_e_invariante(t)
	_l_umore_non_si_muove_da_solo(t)
	_il_NaN_non_avvelena(t)
	_la_notte_ha_una_RESA_non_un_interruttore(t)
func _nuovo(tratti := {}):
	var l = LIMBICO.new()
	l.setup(tratti)
	return l


# ---- L'ABITUDINE: il decimo regalo non commuove più nessuno ----
func _test_abitudine(t) -> void:
	var l = _nuovo()
	var primo: float = float(l.rivaluta("regalo", "giocatore", 0.8)["sentito"])
	var ultimo := 0.0
	for i in 9:
		ultimo = float(l.rivaluta("regalo", "giocatore", 0.8)["sentito"])
	t.ok(primo > 0.3, "il primo regalo si sente eccome (%.2f)" % primo)
	t.ok(ultimo < primo * 0.5,
			"il decimo vale molto meno del primo (%.2f vs %.2f)" % [ultimo, primo])
	var d: Dictionary = l.rivaluta("regalo", "giocatore", 0.8)
	t.ok(str(d["perche"]).contains("abitudine") or str(d["perche"]).contains("aspetta"),
			"e il sistema sa dire che ci ha fatto l'abitudine")


# ---- IL CONTRASTO: una gentilezza dopo il gelo vale dieci regali ----
func _test_contrasto(t) -> void:
	var freddo = _nuovo()
	for i in 8:
		freddo.rivaluta("ordine", "giocatore", -0.6)     # settimane di torti
	var dopo_il_gelo: float = float(freddo.rivaluta("regalo", "giocatore", 0.8)["sentito"])

	var coccolato = _nuovo()
	for i in 8:
		coccolato.rivaluta("regalo", "giocatore", 0.8)   # sempre trattato bene
	var uno_dei_tanti: float = float(coccolato.rivaluta("regalo", "giocatore", 0.8)["sentito"])

	t.ok(dopo_il_gelo > uno_dei_tanti * 1.8,
			"la stessa gentilezza vale molto di più dopo il gelo (%.2f vs %.2f)"
			% [dopo_il_gelo, uno_dei_tanti])


# ---- IL TRADIMENTO: il male da chi ti aspettavi il bene ----
func _test_tradimento(t) -> void:
	var amico = _nuovo()
	for i in 8:
		amico.rivaluta("gesto", "Pepe", 0.8)             # Pepe è sempre stato buono
	var tradito: float = float(amico.rivaluta("gesto", "Pepe", -0.7)["sentito"])

	var estraneo = _nuovo()
	var da_estraneo: float = float(estraneo.rivaluta("gesto", "Ignoto", -0.7)["sentito"])

	t.ok(tradito < da_estraneo,
			"lo stesso torto da un amico fa più male (%.2f vs %.2f)" % [tradito, da_estraneo])
	var d: Dictionary = amico.rivaluta("gesto", "Pepe", -0.7)
	t.ok(str(d["perche"]).contains("proprio da"),
			"e il sistema sa dire che è il tradimento a bruciare")


# ---- LE DUE STRADE: il corpo reagisce prima della testa ----
func _test_due_strade(t) -> void:
	var l = _nuovo({"codardia": 0.8})
	# all'inizio nessun marchio: nessun sussulto
	t.eq(str(l.percepisci("Ignoto", "catasta")["reazione"]), "nulla",
			"davanti a un posto neutro il corpo non fa nulla")
	# ora succede qualcosa di brutto lì
	l.rivaluta("spavento", "orso", -0.9, "catasta")
	var s: Dictionary = l.percepisci("", "catasta")
	t.eq(str(s["reazione"]), "trasalisce", "tornando lì, il corpo trasalisce")
	t.ok(float(s["forza"]) > 0.0, "e con una forza misurabile")
	t.ok(str(s["fonte"]).contains("catasta"), "e si sa da dove viene il sussulto")
	# la strada veloce può sbagliarsi: la lenta rivaluta e può smentirla
	var lenta: Dictionary = l.rivaluta("visita", "amico", 0.5, "catasta")
	t.ok(float(lenta["sentito"]) > 0.0,
			"ma la valutazione lenta può smentire il sussulto: era un amico")


# ---- IL MARCHIO e la sua ESTINZIONE ----
func _test_marchio_e_estinzione(t) -> void:
	var l = _nuovo()
	for i in 3:
		l.rivaluta("spavento", "orso", -0.9, "pozzo")
	t.ok(l.evita("pozzo"), "dopo tre spaventi gira al largo dal pozzo")
	t.ok(l.perche_evita("pozzo").length() > 0, "e sa dire perché")
	t.ok(l.perche_evita("pozzo").contains("3") or l.perche_evita("pozzo").contains("volte"),
			"citando quante volte è successo")
	# tornarci senza che accada nulla spegne la paura: si può rimediare
	for i in 6:
		l.visita_serena("pozzo")
	t.ok(not l.evita("pozzo"),
			"tornarci in pace disinnesca la paura: nessun trauma è per sempre")


# ---- LO SPAVENTO RESTA ADDOSSO: il corpo è più lento della testa ----
func _test_spavento_resta_addosso(t) -> void:
	var l = _nuovo()
	l.rivaluta("spavento", "orso", -0.95, "bosco")
	var subito: float = l.arousal
	t.ok(subito > 0.2, "lo spavento alza l'attivazione del corpo")
	t.ok(l.stato_corpo() != "tranquillo", "e si vede addosso")
	l.passa_giorno()
	t.ok(l.arousal < subito, "una notte calma il corpo")
	t.ok(l.arousal > 0.0, "ma non lo azzera: si resta guardinghi per un po'")


# ---- L'UMORE È UNA LENTE: di malumore si prende tutto storto ----
func _test_umore_lente(t) -> void:
	var sereno = _nuovo()
	var neutro_sereno: float = float(sereno.rivaluta("incontro", "tizio", 0.0)["sentito"])
	var cupo = _nuovo()
	cupo.umore = -0.8
	var neutro_cupo: float = float(cupo.rivaluta("incontro", "tizio", 0.0)["sentito"])
	t.ok(neutro_cupo < neutro_sereno,
			"lo stesso incontro neutro, di malumore, si legge peggio (%.2f vs %.2f)"
			% [neutro_cupo, neutro_sereno])
	t.eq(cupo.stato_corpo(), "di malumore", "e lo stato del corpo lo dice")


# ---- LA GOCCIA CHE FA TRABOCCARE IL VASO: trattenersi costa ----
func _test_goccia_che_trabocca(t) -> void:
	var l = _nuovo()
	var riusciti := 0
	for i in 20:
		if l.trattieni():
			riusciti += 1
		else:
			break
	t.ok(riusciti >= 3, "ci si riesce a trattenere qualche volta (%d)" % riusciti)
	t.ok(riusciti < 20, "ma non all'infinito: la pazienza è finita")
	t.ok(l.esausto(), "e a un certo punto finisce davvero")
	t.ok(l.perche_scoppio().contains("trattenut") or l.perche_scoppio().contains("pazienza"),
			"e si sa spiegare: non è la sciocchezza, è la decima volta")
	# dormirci sopra restituisce la pazienza
	l.passa_giorno()
	t.ok(not l.esausto(), "dormirci sopra restituisce la pazienza")
	t.eq(l.morsi_oggi, 0, "e il conto riparte da zero")


# ---- il carattere non cambia i fatti, cambia il CORPO che li riceve ----
func _test_carattere_cambia_il_corpo(t) -> void:
	var codardo = _nuovo({"codardia": 0.95, "grinta": 0.1})
	var tosto = _nuovo({"codardia": 0.05, "grinta": 0.95})
	t.ok(codardo.reattivita > tosto.reattivita,
			"il codardo ha il grilletto più sensibile")
	codardo.rivaluta("spavento", "orso", -0.9, "bosco")
	tosto.rivaluta("spavento", "orso", -0.9, "bosco")
	t.ok(codardo.arousal > tosto.arousal,
			"lo stesso spavento lo scuote molto di più (%.2f vs %.2f)"
			% [codardo.arousal, tosto.arousal])
	# l'ambizioso si abitua prima al bene: gli basta sempre meno
	var ambizioso = _nuovo({"ambizione": 0.95})
	var pago = _nuovo({"ambizione": 0.05})
	t.ok(ambizioso.abitudine > pago.abitudine,
			"chi ha ambizione si abitua prima a quello che riceve")


func _test_neurochimica(t) -> void:
	var l = _nuovo()
	t.ok(l.livello_neuro("dopamina") > 0.0, "ha baseline di dopamina")
	t.ok(l.livello_neuro("serotonina") > 0.0, "ha baseline di serotonina")
	t.almost(l.livello_neuro("cortisolo"), 0.08, "cortisolo a baseline fisiologica", 0.04)

	# Stimolo neurochimico
	var pre_dop: float = l.livello_neuro("dopamina")
	l.stimola_neuro("dopamina", 0.25)
	t.almost(l.livello_neuro("dopamina"), minf(1.0, pre_dop + 0.25), "stimola_neuro incrementa la dopamina")

	# Cortisolo aumenta il costo di trattenersi
	var l_calmo = _nuovo()
	var l_stress = _nuovo()
	l_stress.stimola_neuro("cortisolo", 0.70)
	l_calmo.regolazione = 0.30
	l_stress.regolazione = 0.30
	var ok_calmo: bool = l_calmo.trattieni(0.25)
	var ok_stress: bool = l_stress.trattieni(0.25)
	t.ok(ok_calmo, "il calmo riesce a trattenersi con poca regolazione")
	t.ok(not ok_stress, "sotto cortisolo elevato il morso costa di più e fallisce")


func _test_consolida_sonno(t) -> void:
	var l = _nuovo()
	l.stimola_neuro("adenosina", 0.85)
	l.stimola_neuro("cortisolo", 0.60)
	l.arousal = 0.80
	l.regolazione = 0.10

	l.consolida_sonno(true) # notte protetta
	t.almost(l.livello_neuro("adenosina"), 0.0, "NREM azzera l'adenosina", 0.001)
	t.ok(l.livello_neuro("cortisolo") < 0.20, "NREM drena il cortisolo verso baseline")
	t.ok(l.regolazione > 0.80, "NREM ricarica la capacità di regolazione")
	t.ok(l.arousal < 0.50, "REM calma l'arousal somatico")


func _test_salvataggio(t) -> void:
	var l = _nuovo({"codardia": 0.7})
	for i in 3:
		l.rivaluta("spavento", "orso", -0.9, "pozzo")
	l.rivaluta("regalo", "giocatore", 0.8)
	l.trattieni()
	var d: Dictionary = l.save()

	var l2 = LIMBICO.new()
	l2.load(d)
	t.almost(l2.arousal, l.arousal, "l'attivazione sopravvive al salvataggio")
	t.almost(l2.umore, l.umore, "e l'umore")
	t.almost(l2.regolazione, l.regolazione, "e la pazienza rimasta")
	t.eq(l2.evita("pozzo"), l.evita("pozzo"), "e le paure apprese")
	t.almost(float(l2.attese["regalo|giocatore"]), float(l.attese["regalo|giocatore"]),
			"e le attese: ricaricando, non si ricomincia a stupirsi di tutto")
	t.almost(l2.livello_neuro("dopamina"), l.livello_neuro("dopamina"),
			"e i livelli neurochimici sopravvivono al salvataggio")



## ⚠️ **L'INTEGRAZIONE E' INVARIANTE AL PASSO — e prima non lo era.**
##
## Il modello di prima scriveva `B + (N−B)·e^(−λΔt) + Π·Δt`: il decadimento
## esatto e la produzione in Eulero esplicito, fuori dall'esponenziale. Il
## punto fisso diventava `B + Π·Δt/(1−e^(−λΔt))`, cioe' una funzione del
## PASSO — e siccome il passo e' il fotogramma, **lo stato era funzione del
## frame rate**. MISURATO sul binario di allora: un minuto simulato a 1 fps
## contro 60 fps dava melatonina 0.697490 contro 0.669030.
##
## Qui si percorre lo STESSO tempo di gioco a due cadenze diverse e si
## pretende lo stesso risultato. La tolleranza e' quella dei double, non una
## soglia comoda: con `Π/λ` dentro la parentesi le due curve sono la stessa
## curva campionata piu' o meno fitto.
func _il_passo_e_invariante(t) -> void:
	var amb := {"luce": 1.0, "pioggia": 0.0, "temperatura": 20.0}
	var fitto = LIMBICO.new()
	var rado = LIMBICO.new()
	fitto.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
	rado.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
	for _i in 400:
		fitto.passo_neuro(0.5, amb, false)
	for _i in 100:
		rado.passo_neuro(2.0, amb, false)
	for tipo in LIMBICO.NEURO_TRASMETTITORI:
		t.almost(float(fitto.neuro[tipo]), float(rado.neuro[tipo]),
				"«%s»: duecento secondi sono duecento secondi, a qualunque cadenza" % tipo,
				1e-6)
	# …e la serotonina non sfonda il tetto: il suo punto fisso e' 0.85, non 2.50
	t.ok(float(fitto.neuro["serotonina"]) < 0.99,
			"e la serotonina non resta incollata al tetto (%.4f): con luce piena "
			% float(fitto.neuro["serotonina"])
			+ "il suo equilibrio e' 0.85, non 2.50")


## ⚠️ **L'UMORE NON SI MUOVE DA SOLO** — e per un pezzo l'ha fatto.
##
## `_modula_stati_da_neuro` faceva `umore += spinta * 0.05` **per CHIAMATA**,
## e `Visitors._ciclo_sonno` la chiamava due volte per fotogramma per ogni
## residente. MISURATO nel MainLevel vero, dieci residenti che nessuno tocca:
## **umore +1.0000 su dieci su dieci**, saturo in 17,5 s a 60 fps e in 42,1 s
## a 25 — esattamente il rapporto 60/25. Un LUTTO si cancellava in tre
## secondi, e `stato_corpo()` non avrebbe mai piu' detto «di malumore».
##
## La soglia non e' un numero comodo: e' quanto rimette a posto una NOTTE DI
## SONNO (`RIENTRO_UMORE`). Un secondo di villaggio non puo' spostare l'umore
## piu' di una notte.
func _l_umore_non_si_muove_da_solo(t) -> void:
	var l = LIMBICO.new()
	l.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
	l.umore = 0.0
	# un secondo di villaggio: sessanta fotogrammi, e a ognuno il gioco
	# stimola i canali del ritmo circadiano come fa `_ciclo_sonno`
	for _f in 60:
		l.stimola_neuro("melatonina", 0.0)
		l.stimola_neuro("adenosina", 0.0)
		l.passo_neuro(1.0 / 60.0)
	t.ok(absf(l.umore) <= LIMBICO.RIENTRO_UMORE,
			("un secondo di villaggio sposta l'umore di %.4f, meno di quanto lo "
			+ "rimetta a posto una notte (%.4f)") % [absf(l.umore), LIMBICO.RIENTRO_UMORE])
	# …e un LUTTO non si cancella in tre secondi
	l.umore = -0.9
	for _f2 in 180:
		l.passo_neuro(1.0 / 60.0)
	t.ok(l.umore < -0.5,
			"e tre secondi dopo un colpo l'umore e' ancora sotto (%.4f)" % l.umore)


## ⚠️ **UN NaN NON AVVELENA IL CANALE PER SEMPRE.**
##
## Lo stato e' ricorsivo e `clamp(NaN)` restituisce NaN: un solo fotogramma
## sporco basta. MISURATO sul modello di prima, con un NaN passato una volta
## sola dall'ambiente: **quattro canali su sette morti per sempre**, ancora
## NaN dieci secondi dopo. Il cancello sta all'ingresso, e ce n'e' uno solo.
func _il_NaN_non_avvelena(t) -> void:
	var l = LIMBICO.new()
	l.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
	var prima := float(l.neuro["cortisolo"])
	l.stimola_neuro("cortisolo", NAN)
	t.almost(float(l.neuro["cortisolo"]), prima, "un impulso NaN si scarta", 1e-9)
	l.passo_neuro(NAN)
	l.passo_neuro(INF)
	l.passo_neuro(1.0, {"luce": NAN, "pioggia": 0.0, "temperatura": 20.0})
	l.passo_neuro(1.0, {"luce": 0.5, "pioggia": 0.0, "temperatura": NAN})
	var vivi := 0
	for tipo in LIMBICO.NEURO_TRASMETTITORI:
		if is_finite(float(l.neuro[tipo])):
			vivi += 1
	t.eq(vivi, LIMBICO.NEURO_TRASMETTITORI.size(),
			"e dopo un ambiente sporco tutti e sette i canali sono ancora vivi")
	# e il modello riprende a funzionare
	l.passo_neuro(1.0, {"luce": 1.0, "pioggia": 0.0, "temperatura": 20.0})
	t.ok(is_finite(l.umore), "…e l'umore non e' avvelenato")


## ⚠️ **LA NOTTE HA UNA RESA, NON UN INTERRUTTORE — e gli estremi devono
## essere BYTE PER BYTE i due rami di prima.**
##
## `consolida_sonno` aveva un `bool`: `true` la notte di tutti, `false` una
## notte che ripara meno — **e quel ramo non lo chiamava nessuno**, in tutto
## il gioco. Adesso e' un grado fra i due, e questo caso e' la prova che il
## cambiamento non ha spostato niente: a `resa = 1.0` i sette canali, la
## regolazione, l'arousal e l'umore devono uscire **identici** a com'erano,
## e a `resa = 0.0` identici all'altro ramo. In mezzo, monotono.
##
## E' il primo passo di un lavoro piu' grande, e la regola che lo governa e'
## questa: **ogni forma e' un moltiplicatore su un canale che esiste, e col
## substrato a zero il gioco e' bit-identico**. Se questo caso arrossisce,
## quel lavoro non parte.
func _la_notte_ha_una_RESA_non_un_interruttore(t) -> void:
	var CANALI := ["dopamina", "ossitocina", "serotonina", "cortisolo",
			"melatonina", "adenosina", "endorfine"]

	# --- gli estremi, contro i due rami scritti a mano qui dentro
	for atteso in [[1.0, 0.85, 0.85, 1.0, 0.20], [0.0, 0.40, 0.35, 0.8, 0.10]]:
		var r: float = float(atteso[0])
		var l = LIMBICO.new()
		l.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
		l.regolazione = 0.10
		l.arousal = 0.90
		l.umore = 0.90
		for c in CANALI:
			l.neuro[c] = 0.90
		var atteso_cort: float = move_toward(0.90,
				float(l.neuro_base["cortisolo"]), float(atteso[1]))
		var atteso_reg: float = clampf(0.10 + float(atteso[2]), 0.0, 1.0)
		var atteso_umo: float = move_toward(0.90, 0.0,
				LIMBICO.RIENTRO_UMORE * float(atteso[3]))
		l.consolida_sonno(r)
		t.almost(float(l.neuro["cortisolo"]), atteso_cort,
				"resa %.1f: il cortisolo drena come il ramo di prima" % r, 1e-9)
		t.almost(l.regolazione, atteso_reg,
				"resa %.1f: la regolazione si ricarica come prima" % r, 1e-9)
		t.almost(l.umore, atteso_umo,
				"resa %.1f: l'umore rientra come prima" % r, 1e-9)
		for c2 in ["dopamina", "ossitocina", "serotonina", "endorfine"]:
			t.almost(float(l.neuro[c2]), move_toward(0.90,
					float(l.neuro_base[c2]), float(atteso[4])),
					"resa %.1f: «%s» rientra come prima" % [r, c2], 1e-9)
		t.almost(float(l.neuro["adenosina"]), 0.0,
				"resa %.1f: l'adenosina si azzera comunque" % r, 1e-12)
		t.almost(float(l.neuro["melatonina"]), 0.0,
				"resa %.1f: e la melatonina anche" % r, 1e-12)

	# --- IN MEZZO E' MONOTONO: piu' resa, piu' pazienza al risveglio. Senza
	#     questo, un `lerp` scritto al contrario passerebbe gli estremi.
	var prec := -1.0
	for passo in 6:
		var r2: float = float(passo) / 5.0
		var m = LIMBICO.new()
		m.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
		m.regolazione = 0.0
		m.consolida_sonno(r2)
		t.ok(m.regolazione > prec,
				"resa %.2f rende piu' di %.2f (regolazione %.4f)" % [r2, r2 - 0.2, m.regolazione])
		prec = m.regolazione

	# --- e una resa storta non fa danni: il degrado va verso la notte NORMALE
	for storta in [NAN, INF, -3.0, 7.0]:
		var g = LIMBICO.new()
		g.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
		g.regolazione = 0.0
		g.consolida_sonno(storta)
		t.ok(is_finite(g.regolazione) and g.regolazione > 0.3,
				"una resa storta (%s) non avvelena la notte (%.3f)" % [storta, g.regolazione])
