extends RefCounted
## ESSERE GUARDATI — le tre valvole, e il pavimento.

const OSS = preload("res://scenes/npc/Osservare.gd")
const LIMBICO = preload("res://scenes/npc/Limbico.gd")
const VISITOR = preload("res://scenes/npc/Visitor.gd")
const FIATO = preload("res://scenes/world/FiatoSospeso.gd")


func run(t) -> void:
	_il_pavimento(t)
	_le_tre_valvole(t)
	_il_peso_si_accumula(t)
	_i_numeri_vengono_da_altrove(t)
	_la_chiave_esiste(t)
	_il_villaggio_guarda_davvero(t)


## ⚠️ **CHI GUARDA NORMALMENTE NON INCONTRA MAI QUESTA COSA.** È la garanzia
## che regge tutto il resto: il Fiato Sospeso su una bestiola, un'occhiata a
## un vicino, una sosta di due secondi — niente di niente.
func _il_pavimento(t) -> void:
	for secondi in [0.0, 1.0, 3.2, 10.0, OSS.PAZIENZA - 0.01]:
		t.ok(not OSS.osserva(2.0, 1.0, float(secondi), true),
				"a %.2f s di sguardo non succede niente (la pazienza è %.1f)"
						% [float(secondi), OSS.PAZIENZA])
		t.almost(OSS.peso(float(secondi)), 0.0,
				"…e il peso è zero esatto", 1e-12)
	# ⚠️ e la soglia è FUORI SCALA rispetto a uno sguardo normale, o
	# scatterebbe su un'occhiata: `Percezione.DURATA_SGUARDO` è 3,2 s.
	t.ok(OSS.PAZIENZA > 10.0,
			("la pazienza (%.1f s) è fuori scala rispetto a una testa che si "
			+ "gira: guardare resta guardare") % OSS.PAZIENZA)


func _le_tre_valvole(t) -> void:
	var lungo: float = OSS.PAZIENZA + 5.0
	t.ok(OSS.osserva(2.0, 1.0, lungo, true), "il caso pieno conta")
	# 1. il tempo — già provato dal pavimento
	# 2. la distanza
	t.ok(not OSS.osserva(OSS.RAGGIO + 0.5, 1.0, lungo, true),
			"da lontano no: si è osservati da vicino, non dal prato")
	# 3. ⚠️ e deve poterti vedere
	t.ok(not OSS.osserva(2.0, 1.0, lungo, false),
			("chi dorme o è dentro casa non se ne accorge: un segno che non si "
			+ "può collegare a un gesto insegna che il gioco marchia a caso"))
	# e la calma: se ti muovi sei uno che passa
	t.ok(not OSS.osserva(2.0, OSS.CALMA_MINIMA - 0.05, lungo, true),
			"se ti stai muovendo non stai guardando: sei uno che passa")
	# i numeri malati non inventano niente
	for c in [NAN, INF, -INF]:
		t.ok(not OSS.osserva(float(c), 1.0, lungo, true),
				"una distanza %s non produce un'osservazione" % str(c))
		t.ok(not OSS.osserva(2.0, 1.0, float(c), true),
				"…né una durata %s" % str(c))
	t.almost(OSS.peso(NAN), 0.0, "e il peso di un NaN è zero", 1e-12)


func _il_peso_si_accumula(t) -> void:
	var a: float = OSS.peso(OSS.PAZIENZA + 2.0)
	var b: float = OSS.peso(OSS.PAZIENZA + 6.0)
	t.ok(b > a and a > 0.0, "più si insiste più pesa (%.3f → %.3f)" % [a, b])
	t.ok(OSS.peso(OSS.PAZIENZA + 600.0) <= OSS.TETTO_EPISODIO + 1e-9,
			"e c'è un tetto per episodio (%.2f)" % OSS.TETTO_EPISODIO)

	# --- ⚠️ **LA SCALA È LA DURATA, NON IL NUMERO DI VOLTE**, e i tre numeri
	#     qui sotto vengono da una misura contro il `Limbico` vero, non da
	#     un'idea: `rivaluta` ABITUA a ciò che si ripete uguale, quindi
	#     ripetere lo stesso peso porta a un plateau e basta (misurato: peso
	#     0.48 ripetuto SESSANTA volte si ferma a 0.444 e non chiude mai).
	#     Chi si ferma venti secondi non lascia niente, per quante volte lo
	#     faccia; chi ci sta un minuto e mezzo sì.
	var corto: float = OSS.peso(OSS.PAZIENZA + 20.0)
	var lungo_p: float = OSS.peso(OSS.PAZIENZA + 75.0)
	t.ok(corto < 0.30,
			("venti secondi di sguardo pesano %.3f, cioè sotto il pavimento "
			+ "del Limbico (0.30): non lasciano NIENTE, mai") % corto)
	t.ok(lungo_p > LIMBICO.SOGLIA_EVITAMENTO,
			("settantacinque secondi pesano %.3f, sopra la soglia "
			+ "dell'evitamento (%.2f): fissare è un'altra cosa da guardare")
					% [lungo_p, LIMBICO.SOGLIA_EVITAMENTO])


## ⚠️ **I NUMERI SONO PRESI DA DOVE VIVONO, non scelti.** Due costanti
## ricopiate a mano diventano due tabelle gemelle che divergono in silenzio il
## giorno che qualcuno tara l'originale.
func _i_numeri_vengono_da_altrove(t) -> void:
	t.almost(OSS.RAGGIO, VISITOR.FACCIA_AL_GIOCATORE,
			("il raggio è quello con cui il gioco aveva già deciso che una "
			+ "faccia vale la pena puntarla"), 1e-9)
	t.almost(OSS.CALMA_MINIMA, FIATO.SOGLIA_FIDUCIA,
			"e la calma è quella con cui il prato decide di fidarsi", 1e-9)


## ⚠️ **LA CHIAVE A FORMA DI GIOCATORE ESISTE GIÀ, e non è nuova.** Un posto
## chiuso da uno sguardo si riapre con gli stessi gesti con cui si cura ogni
## altra paura: l'estinzione del tempo, `visita_serena`, e l'Accompagnare.
func _la_chiave_esiste(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	var posto: String = OSS.luogo_di(Vector2i(7, 3))
	t.ok(OSS.e_un_posto_guardato(posto),
			"un posto guardato si riconosce dal nome (%s)" % posto)
	t.ok(not OSS.e_un_posto_guardato("catasta"),
			"…e la catasta non è un posto guardato")
	# lo si chiude insistendo
	for i in 4:
		l.rivaluta("guardato", "giocatore", -OSS.TETTO_EPISODIO, posto)
	t.ok(l.evita(posto),
			("insistendo, il posto si chiude (carica %.3f)")
					% l.carica_di(posto))
	# e si riapre: la chiave è quella di sempre
	for i in 8:
		l.visita_serena(posto)
	t.ok(not l.evita(posto),
			("e `visita_serena` lo riapre (%.3f): nessun gesto nuovo da "
			+ "imparare") % l.carica_di(posto))
	# ⚠️ e il tempo da solo lo consuma: nessuno resta chiuso per sempre
	var m = LIMBICO.new()
	m.setup({})
	for i in 4:
		m.rivaluta("guardato", "giocatore", -OSS.TETTO_EPISODIO, posto)
	for g in 12:
		m.passa_giorno(true)
	t.ok(not m.evita(posto),
			("e dodici giornate lo consumano comunque (%.3f): l'estinzione "
			+ "vale anche qui") % m.carica_di(posto))


## ⚠️ **QUESTA MECCANICA ESISTE IN PARTITA, o è una libreria che nessuno apre.**
##
## È la guardia che mancava, e la sua assenza è costata l'intera meccanica:
## `Osservare.gd` è stato consegnato completo, provato, con i suoi numeri
## MISURATI e una sezione nel CLAUDE.md — e **zero chiamanti di qualunque
## tipo**. Tutte le altre asserzioni di questo file restavano verdi, perché
## provano la REGOLA e non il cablaggio. È la firma numero uno di questo
## progetto, e in questa tornata l'ha presa tre volte.
##
## Qui si fa girare `Visitors._tick_osservati` VERO, col corpo VERO (le tre
## valvole passano da `Percezione.puo_vedere`, che chiama `is_hidden`, `dorme`
## e `in_scena` su quel nodo) e il `Limbico` VERO.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass


func _il_villaggio_guarda_davvero(t) -> void:
	var vis = Registro.new()
	t.stage(vis)
	var mochi := Node3D.new()
	t.stage(mochi)
	mochi.global_position = Vector3(0, 0, 0)
	vis.set("_player", mochi)

	var corpo := Node3D.new()
	corpo.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo)
	corpo.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(1717))
	corpo.set("mode", "resident")
	corpo.global_position = Vector3(0, 0, 2.0)      # dentro OSS.RAGGIO
	var animo = preload("res://scenes/npc/Animo.gd").new()
	animo.setup({"name": "Guardato", "tratti": {}, "sogno": "casa"})
	(vis.get("_residents") as Array).append({
		"label": "G", "cell": Vector2i(0, 0), "species": "chibi",
		"node": corpo, "dna": corpo.get("dna")})
	(vis.get("_animi") as Dictionary)["G"] = animo

	var luogo := OSS.luogo_di(Vector2i(0, 0))
	t.almost(float(animo.limbico.carica_di(luogo)), 0.0,
			"il posto nasce senza marchio", 1e-9)

	# --- 1) il Fiato Sospeso tenuto addosso, ben oltre la pazienza
	vis.call("set_calma", 1.0, Vector3.ZERO)
	for _i in int(90.0 / 0.25):
		vis.call("_tick_osservati", 0.25)
	# finché dura non è ancora successo niente: si paga alla FINE
	t.almost(float(animo.limbico.carica_di(luogo)), 0.0,
			"mentre dura non si è ancora inciso niente", 1e-9)
	# il giocatore si alza: l'episodio si chiude
	vis.call("set_calma", 0.0, Vector3.ZERO)
	vis.call("_tick_osservati", 0.25)
	var carica: float = float(animo.limbico.carica_di(luogo))
	t.ok(carica < -0.05,
			"novanta secondi di sguardo tenuto caricano il POSTO (%.4f)" % carica)

	# ⚠️ E IL SEGNO NON È SU DI TE: `attore` è vuoto apposta
	t.almost(float(animo.limbico.carica_di("", "giocatore")), 0.0,
			"…e non c'è nessun marchio sulla PERSONA del giocatore", 1e-9)

	# --- 2) LA CONTROPROVA: un'occhiata normale non lascia niente
	var vis2 = Registro.new()
	t.stage(vis2)
	var mochi2 := Node3D.new()
	t.stage(mochi2)
	mochi2.global_position = Vector3(20, 0, 20)
	vis2.set("_player", mochi2)
	var corpo2 := Node3D.new()
	corpo2.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo2)
	corpo2.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(1818))
	corpo2.set("mode", "resident")
	corpo2.global_position = Vector3(20, 0, 22.0)
	var animo2 = preload("res://scenes/npc/Animo.gd").new()
	animo2.setup({"name": "Sereno", "tratti": {}, "sogno": "casa"})
	(vis2.get("_residents") as Array).append({
		"label": "S", "cell": Vector2i(20, 20), "species": "chibi",
		"node": corpo2, "dna": corpo2.get("dna")})
	(vis2.get("_animi") as Dictionary)["S"] = animo2
	vis2.call("set_calma", 1.0, Vector3.ZERO)
	for _i in int(10.0 / 0.25):          # dieci secondi: sotto la PAZIENZA
		vis2.call("_tick_osservati", 0.25)
	vis2.call("set_calma", 0.0, Vector3.ZERO)
	vis2.call("_tick_osservati", 0.25)
	t.almost(float(animo2.limbico.carica_di(OSS.luogo_di(Vector2i(20, 20)))), 0.0,
			"e un'occhiata di dieci secondi non lascia NIENTE", 1e-9)

	# --- 3) ⚠️ E IL TICK DEVE GIRARE DAVVERO NEL `_process` DEL VILLAGGIO.
	# I due blocchi qui sopra chiamano `_tick_osservati` a mano: provano la
	# REGOLA, e resterebbero verdi anche togliendo la riga che la fa girare —
	# cioè lascerebbero passare esattamente il difetto che questo caso esiste
	# per chiudere (MISURATO: togliendo quella riga, 38 passati e 0 falliti).
	# Il `_process` vero non si può far girare qui (vuole l'ECS, il
	# BuildSystem, il cielo), quindi si guarda il SORGENTE — e lo si guarda
	# **spogliato dei commenti**, col ferro dell'harness: questo file la
	# chiamata la nomina apposta, e un guardiano ingenuo matcherebbe se stesso.
	# ⚠️ `var src: String = …` e non `:=`: `load()` torna un valore non
	# tipizzato, e l'inferenza non compila (è la trappola scritta nella
	# convenzione dei test di questo progetto).
	var src: String = load("res://tests/test_util.gd").codice(
			"res://scenes/npc/Visitors.gd")
	var i0 := src.find("func _process(delta")
	t.ok(i0 >= 0, "il `_process` di Visitors si trova")
	if i0 >= 0:
		var i1 := src.find("\nfunc ", i0 + 8)
		var corpo_process := src.substr(i0, (i1 - i0) if i1 > i0 else -1)
		t.ok(corpo_process.contains("_tick_osservati("),
				"e chiama `_tick_osservati` a ogni fotogramma: senza, tutto "
				+ "`Osservare.gd` è una libreria che non apre nessuno")
