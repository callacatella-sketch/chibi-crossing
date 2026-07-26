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
	_test_salvataggio(t)


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
