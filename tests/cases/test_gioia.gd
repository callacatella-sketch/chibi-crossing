extends RefCounted
## LA GIOIA NON PORTA LA FACCIA DELLA PAURA.
##
## La strada veloce del `Limbico` ha due risposte — chi ti teme trasalisce,
## chi ti vuole bene si illumina — e **una sola moneta le pagava tutte e
## due**. La coda somatica («sono ancora guardingo»: orecchie GIÙ, braccia
## chiuse, coda irrigidita, passo al 72%) veniva accesa PRIMA del `match`
## sulla reazione, quindi si posava anche sopra il cuoricino; e la forza che
## la accendeva era costruita col valore ASSOLUTO del marchio, cioè un amico
## reagiva più forte di uno spaventato.
##
## MISURATO nel villaggio vero prima della cura (`tools/misura_sussulti.gd`,
## 28 residenti, 8 minuti): **48 «si illumina» contro 4 «trasalisce»** — la
## gioia è dodici volte più frequente della paura — e la coda si è armata su
## **45 di quelle 48**, più 91 volte su 129 percetti che non avevano prodotto
## NESSUNA reazione. Nell'istante del cuoricino le orecchie andavano **giù 17
## volte su 21**. E 45 cuoricini su 48 capitavano a chi non aveva **nessun**
## marchio addosso: un cuore che il giocatore non può ricondurre a niente.
##
## Questo file tiene chiuse cinque porte, e nessuna è un `source-check`: si
## fa girare il `_tick_sussulti` VERO su corpi VERI e si guarda il rig.
##
## LE NOVE MUTAZIONI, una riga di produzione per volta, rifatte girare — col
## numero di asserzioni diventate rosse (MISURATE, non stimate):
##
##   `somatico()` rimesso PRIMA del `match` (com'era) ................   2
##   `forza` che riprende `absf(carica)` (la moneta unica) ...........   2
##   `si_illumina` come ramo DI SERIE (il cuore senza storia) ........   4
##   l'arousal pompato anche dalla gioia .............................   3
##   `rivaluta` che torna a `absf(sorpresa)` (il regalo allarma) .....   4
##   il rilascio della coda tolto dal Rialzo .........................   2
##   il rilascio che TAGLIA invece di rientrare ......................   1
##   `somatico` che non riarma un rilascio in corso ..................   1
##   la `reattivita` tolta dall'allarme (la prova di equivalenza) .... 270
##
## ⚠️ **E LE PRIME DUE SONO GUARDIE INDIPENDENTI SULLA STESSA REGOLA**: la
## mutazione 1 (il cablaggio) e la 2 (l'aritmetica) fanno arrossire asserzioni
## DIVERSE. È voluto — rimettere la chiamata dov'era non riaccende la coda
## sopra una gioia, perché a monte una gioia non ha più forza d'allarme da
## passare; e rimettere la moneta unica non la riaccende, perché a valle la
## chiamata sta dentro il ramo di chi ha trasalito. Serve romperle tutte e
## due insieme per riavere il difetto, ed è il motivo per cui ce ne sono due.
##
## ⚠️ **DUE TRAPPOLE DI BANCO, pagate scrivendo questo file** — e sono la
## stessa: un mutatore che non si controlla misura sé stesso.
##  1. il mutatore cercava ancore che nel file compaiono PIÙ VOLTE (`return
##     0.0`, `pass`): il verso «togli la mutazione» rimetteva il codice in un
##     punto a caso — dentro `punto_ritmo` e dentro `c_decide` — e le tre
##     mutazioni dopo misuravano un file corrotto (254 errori di parse
##     scambiati per asserzioni rosse). Ogni ancora dev'essere UNICA, e dopo
##     ogni ripristino si confronta l'IMPRONTA del file;
##  2. e la catena `muta on && prova && grep FAIL && muta off` **non ripristina
##     niente** quando il `grep` non trova nulla: si ferma prima, e la
##     mutazione resta in casa. Il ripristino non va messo dopo una `&&`.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0


## Il registro dei vicini VERO, col solo `_ready` scavalcato (quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero).
## È la stessa forma di `test_regia.Registro`, e per la stessa ragione.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


func run(t) -> void:
	_la_coda_segue_solo_l_allarme(t)
	_il_cuoricino_vuole_una_storia(t)
	_la_forza_e_l_allarme(t)
	_la_gioia_non_alza_l_allarme(t)
	_la_paura_non_e_cambiata(t)
	_il_sollievo_scioglie_la_coda(t)
	_il_rilascio_non_taglia(t)
	_una_paura_nuova_riarma_la_coda(t)


# --------------------------------------------------------------- il banco

func _corpo(t, seme := 5150):
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)     # il `_process` lo facciamo girare NOI
	v._enter_state("r_idle")
	v.set("_timer", 1.0e9)   # o `r_idle` scade e il corpo riparte
	return v


func _gira(v, secondi: float, passo := DT) -> void:
	for _i in int(secondi / passo):
		v._process(passo)


## Un animo VERO (col suo Limbico dentro), come lo costruisce
## `Visitors._ensure_brain`.
func _animo(dna: Dictionary):
	var a = ANIMO.new()
	a.setup(dna)
	return a


## Un villaggio minimo col registro VERO: N corpi, il loro animo, e Mochi
## addosso (il sussulto non guarda nessuno oltre 3,2 m).
func _villaggio(t, quanti := 3) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var vis = t.stage(Registro.new())
	var player := Node3D.new()
	t.stage(player)
	player.global_position = Vector3(0, 0, 4)
	vis.set("_player", player)
	var corpi: Array = []
	var animi: Array = []
	for i in quanti:
		var c = _corpo(t, 5150 + i * 211)
		c.global_position = Vector3(float(i) * 0.4, 0, 3.0)
		var lab := "V%d" % i
		var a = _animo(c.dna)
		a.nome = lab
		(vis.get("_animi") as Dictionary)[lab] = a
		vis._residents.append({"node": c, "label": lab, "dna": c.dna,
				"cell": Vector2i(i, 0), "species": "chibi", "friend": 4})
		corpi.append(c)
		animi.append(a)
	return {"vis": vis, "player": player, "corpi": corpi, "animi": animi}


## MOCHI ARRIVA, e il modo in cui arriva è tutto: `_tick_sussulti` ricava la
## velocità dallo SPOSTAMENTO fra due suoi tick. Si passa dalla porta vera —
## si sposta il giocatore — invece di scrivere un `grezzo` a mano: la
## bruschezza è quella che il gioco calcola, non quella che vorrei io.
func _arriva(v: Dictionary, velocita: float) -> void:
	var p: Node3D = v["player"]
	var pos := p.global_position
	v["vis"].set("_pp_prec", pos - Vector3(0, 0, velocita * DT))
	p.global_position = pos
	v["vis"]._tick_sussulti(DT)


# =========================================================================
# 1 · LA CODA SEGUE SOLO L'ALLARME
# =========================================================================
#
# Il cablaggio, non la formula: `Visitors._tick_sussulti` chiamava
# `somatico(forza)` PRIMA di guardare che reazione fosse.

func _la_coda_segue_solo_l_allarme(t) -> void:
	var v := _villaggio(t, 3)
	var animi: Array = v["animi"]
	var corpi: Array = v["corpi"]
	# A · CHI TI VUOLE BENE: il marchio positivo se lo scrive il Limbico da
	# solo, incontro dopo incontro — è la porta di `_tick_riconoscimenti`.
	for _i in 6:
		animi[0].limbico.rivaluta("incontro", "giocatore", 0.55)
	# B · CHI TI TEME: la stessa porta, dall'altra parte.
	for _i in 5:
		animi[1].limbico.rivaluta("spavento", "giocatore", -0.95)
	# C · UNO SCONOSCIUTO, che non ha nessuna storia con te.

	# Mochi arriva A PASSO DI CAMMINATA (`PlayerController.walk_speed`): non
	# è un dettaglio: a velocità zero la bruschezza è zero, la forza è zero,
	# e `somatico(0)` non farebbe niente nemmeno col difetto in casa — il
	# caso sarebbe verde su tutte e due le versioni del codice.
	_arriva(v, 3.0)

	var sa: Dictionary = animi[0].limbico.ultimo_sussulto
	var sb: Dictionary = animi[1].limbico.ultimo_sussulto
	var sc: Dictionary = animi[2].limbico.ultimo_sussulto
	t.eq(str(sa["reazione"]), "si_illumina", "chi ti vuole bene si illumina")
	t.eq(str(sb["reazione"]), "trasalisce", "chi ti teme trasalisce")
	t.eq(str(sc["reazione"]), "nulla", "e chi non ti conosce non fa niente")
	# …e la bruschezza c'è davvero, o il caso non proverebbe nulla
	t.ok(float(sa["grezzo"]) > 0.1,
			"(la camminata è arrivata come bruschezza: %.3f)" % float(sa["grezzo"]))

	t.almost(float(corpi[0].get("_gs_soma")), 0.0,
			"la GIOIA non accende la coda guardinga")
	t.ok(float(corpi[1].get("_gs_soma")) > 0.0,
			"…lo SPAVENTO sì (%.3f): è la controprova, senza la quale questo"
			% float(corpi[1].get("_gs_soma")) + " caso sarebbe verde anche senza coda")
	t.almost(float(corpi[2].get("_gs_soma")), 0.0,
			"e un percetto che non ha prodotto NESSUNA reazione non accende niente")
	# la forza del percetto muto non era zero: è proprio quello che il
	# cablaggio di prima passava al corpo
	t.ok(float(sc["forza"]) > 0.0,
			"(il percetto muto aveva comunque una forza: %.3f)" % float(sc["forza"]))

	# E LO SI VEDE ADDOSSO. Il numero da solo non basta: le orecchie della
	# gioia devono andare SU (negativo), non giù.
	_gira(corpi[0], 0.17)
	_gira(corpi[1], 0.17)
	var ear_gioia := float((corpi[0].get("_rc_appl") as Dictionary).get("ear", 0.0))
	var ear_paura := float((corpi[1].get("_rc_appl") as Dictionary).get("ear", 0.0))
	t.ok(ear_gioia < 0.0,
			"nell'istante del cuoricino le orecchie vanno SU (%+.4f rad)" % ear_gioia)
	t.ok(ear_paura < ear_gioia or ear_paura > 0.0,
			"(e quelle dello spavento fanno la loro strada: %+.4f)" % ear_paura)


# =========================================================================
# 2 · IL CUORICINO VUOLE UNA STORIA
# =========================================================================
#
# `si_illumina` era il ramo DI SERIE: bastava che la forza superasse la
# soglia e che non ci fosse niente di brusco. Con la bruschezza di una
# camminata (0,185) e un carattere timido (reattività 1,24) la forza arriva
# a 0,229 — e un vicino che non ti ha mai visto ti mostrava un cuoricino.

func _il_cuoricino_vuole_una_storia(t) -> void:
	var estraneo = LIMBICO.new()
	estraneo.setup({"codardia": 0.9, "grinta": 0.5})
	t.ok(estraneo.reattivita > 1.2,
			"(un timido ha il grilletto sensibile: %.2f)" % estraneo.reattivita)
	var g := VISITORS.indizio_grezzo(3.0, 0.0, 1.0)
	t.ok(g > 0.0 and g <= LIMBICO.RIFLESSO_GREZZO,
			"(una camminata addosso è bruschezza, ma non un riflesso: %.3f)" % g)
	var s: Dictionary = estraneo.percepisci("giocatore", "", g)
	t.eq(str(s["reazione"]), "nulla",
			"senza nessuna storia non c'è nessun cuoricino")
	# …e con la storia sì: il cuore dice una cosa VERA o non dice niente
	var amico = LIMBICO.new()
	amico.setup({"codardia": 0.9, "grinta": 0.5})
	for _i in 6:
		amico.rivaluta("incontro", "giocatore", 0.55)
	t.ok(amico.carica_di("", "giocatore") > LIMBICO.SOGLIA_SUSSULTO,
			"(sei incontri felici lasciano un marchio vero: %.3f)"
			% amico.carica_di("", "giocatore"))
	t.eq(str(amico.percepisci("giocatore", "", g)["reazione"]), "si_illumina",
			"chi ti vuole bene, sì")
	# e la soglia è la STESSA per le due monete: sotto, silenzio
	var appena = LIMBICO.new()
	appena.setup({})
	appena.marchi["chi|giocatore"] = {"carica": LIMBICO.SOGLIA_SUSSULTO - 0.02,
			"conferme": 1}
	t.eq(str(appena.percepisci("giocatore", "", 0.0)["reazione"]), "nulla",
			"un affetto appena accennato non si vede ancora")

	# ⚠️ **E SI GUADAGNA CON UN GESTO SOLO — la prima delle tre domande del
	# collaudo del genere: «il giocatore può rimediare?».** Il cuoricino non
	# è diventato più raro per essere raro: è diventato una cosa che il
	# giocatore FA succedere, e la porta esiste già ed è quella dei regali
	# (`Visitors.gesto_gentile` → `Animo.ricorda` → `rivaluta`). Un piatto,
	# una festa, un accompagnamento: da lì in poi quel vicino ti si illumina
	# quando arrivi.
	var regalato = LIMBICO.new()
	regalato.setup({})
	regalato.rivaluta("regalo", "giocatore", 0.8)
	t.eq(str(regalato.percepisci("giocatore", "", 0.0)["reazione"]), "si_illumina",
			"un solo gesto gentile, e da lì in poi quel vicino si illumina")


# =========================================================================
# 3 · LA FORZA È L'ALLARME — un amico non reagisce più forte di uno spaventato
# =========================================================================

func _la_forza_e_l_allarme(t) -> void:
	# L'AMICO, arrivo tranquillo: il corpo non ha NIENTE da allarmarsi.
	var amico = LIMBICO.new()
	amico.setup({})
	for _i in 6:
		amico.rivaluta("incontro", "giocatore", 0.55)
	var gioia: Dictionary = amico.percepisci("giocatore", "", 0.0)
	# LO SCONOSCIUTO, caricato di corsa (`PlayerController.run_speed`).
	var estraneo = LIMBICO.new()
	estraneo.setup({})
	var paura: Dictionary = estraneo.percepisci("giocatore", "",
			VISITORS.indizio_grezzo(6.0, 0.0, 1.0))
	t.eq(str(paura["reazione"]), "trasalisce", "(chi ti vede correre addosso trasalisce)")
	t.ok(float(gioia["forza"]) < float(paura["forza"]),
			"un amico non reagisce più forte di uno spaventato (%.3f < %.3f)"
			% [float(gioia["forza"]), float(paura["forza"])])
	t.almost(float(gioia["forza"]), 0.0,
			"anzi: chi ti vuole bene e ti vede arrivare piano non si allarma affatto")
	# …e il CALORE c'è, sotto il suo nome: la gioia ha una sua intensità, e
	# non è quella dell'allarme
	t.ok(float(gioia["calore"]) > 0.0,
			"la gioia ha la sua misura, e ha un nome suo (%.3f)" % float(gioia["calore"]))
	t.almost(float(paura["calore"]), 0.0, "e uno spavento non ne ha")


# =========================================================================
# 4 · LA GIOIA NON ALZA L'ALLARME
# =========================================================================
#
# `arousal` in questo gioco ha un vocabolario solo — «ancora guardingo»,
# «col cuore in gola» — e un consumatore che CAMBIA il gioco: salutando (T)
# chi ha il corpo scosso, `Visitors._spiega_come_sta` toglie il saluto
# felice e mette una nuvoletta di puntini. Se la gioia lo alzasse, il
# giocatore che fa un regalo verrebbe accolto da un «…».

func _la_gioia_non_alza_l_allarme(t) -> void:
	var caro = LIMBICO.new()
	caro.setup({})
	for _i in 6:
		caro.rivaluta("incontro", "giocatore", 0.55)
	# …e il giocatore gli passa accanto DUE volte, come capita davvero: il
	# sussulto si riarma ogni nove secondi, e un'attivazione che si accumula
	# a ogni incontro felice arriva in fretta al «cuore in gola».
	caro.percepisci("giocatore", "", 0.0)
	caro.percepisci("giocatore", "", 0.0)
	t.almost(caro.arousal, 0.0,
			"sei incontri felici non lasciano il cuore in gola (%.3f)" % caro.arousal)
	t.ok(caro.stato_corpo() != "col cuore in gola"
			and caro.stato_corpo() != "ancora guardingo",
			"il corpo di chi ti vuole bene non porta le parole della paura («%s»)"
			% caro.stato_corpo())
	t.ok(not VISITORS.corpo_ha_da_dire(caro.stato_corpo()),
			"…e salutandolo si prende il saluto felice, non una nuvoletta di puntini")
	# IL REGALO, che è l'altra metà della stessa strada
	var donato = LIMBICO.new()
	donato.setup({})
	donato.rivaluta("regalo", "giocatore", 0.9)
	t.ok(not VISITORS.corpo_ha_da_dire(donato.stato_corpo()),
			"e nemmeno chi ha appena ricevuto un regalo («%s»)" % donato.stato_corpo())
	# LA CONTROPROVA: l'allarme lo alza ciò che allarma, e si vede addosso.
	var scosso = LIMBICO.new()
	scosso.setup({})
	scosso.rivaluta("spavento", "orso", -0.95, "bosco")
	t.ok(scosso.arousal > 0.2,
			"uno spavento sì (%.3f): senza questa riga il caso sopra sarebbe"
			% scosso.arousal + " verde anche con l'attivazione morta")
	t.ok(VISITORS.corpo_ha_da_dire(scosso.stato_corpo()),
			"…e a lui il gioco risponde col corpo che ha («%s»)" % scosso.stato_corpo())
	# e una DELUSIONE è un allarme come un altro: la sorpresa negativa
	var deluso = LIMBICO.new()
	deluso.setup({})
	for _i in 6:
		deluso.rivaluta("gesto", "Pepe", 0.8)
	var prima: float = deluso.arousal
	deluso.rivaluta("gesto", "Pepe", -0.7)
	t.ok(deluso.arousal > prima,
			"il male da chi ti aspettavi il bene scuote il corpo (%.3f → %.3f)"
			% [prima, deluso.arousal])


# =========================================================================
# 5 · LA PAURA NON È CAMBIATA — la prova di equivalenza
# =========================================================================
#
# La cura tocca UNA metà della strada veloce. L'altra — tutto ciò che
# allarmava — deve restare identica al bit: se cambiasse anche lei, non
# sarebbe una correzione, sarebbe una taratura nuova con dentro una
# correzione. L'oracolo è la formula di ieri, scritta qui.

func _la_paura_non_e_cambiata(t) -> void:
	var uguali := 0
	for carica: float in [-1.0, -0.8, -0.55, -0.3, -0.12, 0.0]:
		for grezzo: float in [0.0, 0.1, 0.25, 0.45, 0.8, 1.0]:
			for cod: float in [0.05, 0.5, 0.95]:
				for ar: float in [0.0, 0.35, 0.9]:
					var l = LIMBICO.new()
					l.setup({"codardia": cod, "grinta": 1.0 - cod})
					l.arousal = ar
					if carica < 0.0:
						l.marchi["chi|giocatore"] = {"carica": carica, "conferme": 1}
					var s: Dictionary = l.percepisci("giocatore", "", grezzo)
					# la formula di IERI, per intero
					var vecchia: float = clampf((absf(carica) + grezzo)
							* l.reattivita * (1.0 + ar * 0.6), 0.0, 1.0)
					var vecchia_r := "nulla"
					if vecchia > 0.22:
						vecchia_r = "trasalisce" if (carica < 0.0 or grezzo > 0.25) \
								else "si_illumina"
					if vecchia_r != "trasalisce":
						continue    # il ramo della gioia è quello che è cambiato
					t.eq(str(s["reazione"]), "trasalisce",
							"chi trasaliva ieri trasalisce oggi (c=%.2f g=%.2f)"
							% [carica, grezzo])
					t.almost(float(s["forza"]), vecchia,
							"…con la STESSA forza (c=%.2f g=%.2f cod=%.2f ar=%.2f)"
							% [carica, grezzo, cod, ar], 0.0)
					t.almost(l.arousal, clampf(ar + vecchia * 0.55, 0.0, 1.0),
							"…e la stessa scia nel corpo", 0.0)
					uguali += 1
	t.ok(uguali > 100, "(la griglia ha provato %d spaventi veri)" % uguali)


# =========================================================================
# 6 · «AH… SEI TU» SCIOGLIE LA CODA
# =========================================================================
#
# `Gesti.gd` lo prometteva per iscritto — «il corpo si è irrigidito davvero
# e il Rialzo la scioglie» — e non lo faceva nessuno: dopo il
# riconoscimento il corpo restava guardingo per otto secondi di posa e
# settantaquattro di passo rallentato. Un sollievo che non scioglie niente
# non è un sollievo: è una seconda posa sopra la prima.

func _il_sollievo_scioglie_la_coda(t) -> void:
	var v = _corpo(t, 6101)
	var gemello = _corpo(t, 6101)
	for c in [v, gemello]:
		c.somatico(0.8)
		_gira(c, 0.4)         # `Visitors.ATTESA_RICONOSCIMENTO`: la strada lenta
	t.ok(v.frase("sollievo"), "(il sollievo parte: il buio c'era)")
	_gira(v, GESTI.SPEGNI + 0.15)
	_gira(gemello, GESTI.SPEGNI + 0.15)
	t.almost(float(v.get("_gs_soma")), 0.0,
			"dopo «ah… sei tu» il corpo ha mollato: la coda non c'è più")
	t.ok(float(gemello.get("_gs_soma")) > 0.0,
			"…e al gemello che non è stato riconosciuto resta addosso (%.3f):"
			% float(gemello.get("_gs_soma"))
			+ " senza questa riga il caso sarebbe verde su una coda che decade da sé")
	t.almost(float(v.get("_gs_r")), 1.0,
			"e il passo è tornato pieno", 0.001)
	t.ok(float(gemello.get("_gs_r")) < 0.99,
			"mentre il gemello cammina ancora piano (%.3f)" % float(gemello.get("_gs_r")))


func _il_rilascio_non_taglia(t) -> void:
	# UN TAGLIO SECCO È UN SALTO DEL RIG, e un salto del rig è la firma
	# dell'adesivo staccato male. Il metro non è un numero a occhio: è la
	# posa che c'è da mollare — se sparisse in un fotogramma, quel fotogramma
	# si sposterebbe di TUTTA la posa. Si guarda l'orecchio VERO, letto dal
	# nodo del rig, fotogramma per fotogramma.
	var v = _corpo(t, 6102)
	v.somatico(0.9)
	_gira(v, 0.3)
	var da_mollare: float = absf(float(GESTI.coda_canali(
			GESTI.coda_ampiezza(float(v.get("_gs_soma")), float(v.get("_gs_soma_t"))),
			0.0, 0.0)["ear"]))
	t.ok(da_mollare > 0.1, "(c'è una posa vera da mollare: %.3f rad)" % da_mollare)
	v.soma_sciogli()
	var salto := 0.0
	var ear_prec := _ear(v)
	for _i in int((GESTI.SPEGNI + 0.2) / DT):
		v._process(DT)
		salto = maxf(salto, absf(_ear(v) - ear_prec))
		ear_prec = _ear(v)
	t.almost(float(v.get("_gs_soma")), 0.0, "il rilascio finisce, e finisce a zero")
	t.ok(salto < da_mollare * 0.2,
			"…rientrando, non tagliando: il fotogramma peggiore sposta l'orecchio"
			+ " di %.4f rad su %.3f da mollare" % [salto, da_mollare])


func _una_paura_nuova_riarma_la_coda(t) -> void:
	# UN SECONDO SPAVENTO DENTRO IL RILASCIO non lo aspetta: il corpo
	# riparte da capo. Senza questa riga il vicino resterebbe insensibile
	# per tutto lo scioglimento — cioè proprio mentre il giocatore è lì.
	var v = _corpo(t, 6103)
	v.somatico(0.8)
	_gira(v, 0.4)
	v.soma_sciogli()
	_gira(v, 0.12)
	v.somatico(1.0)
	_gira(v, 0.1)
	t.ok(float(v.get("_gs_soma")) > 0.9,
			"una paura nuova riarma la coda anche a rilascio cominciato (%.3f)"
			% float(v.get("_gs_soma")))
	_gira(v, 1.0)
	t.ok(GESTI.coda_ampiezza(float(v.get("_gs_soma")), float(v.get("_gs_soma_t"))) > 0.0,
			"…e la coda nuova vive la sua vita intera")


## L'orecchio VERO, letto dal nodo del rig.
func _ear(v) -> float:
	var orecchie: Array = v.get("_c_ears")
	if orecchie.size() < 1:
		return 0.0
	return (orecchie[0] as Node3D).rotation.x
