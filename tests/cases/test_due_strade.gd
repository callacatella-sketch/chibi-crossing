extends RefCounted
## LE DUE STRADE, RECITATE — e il verbo che spegne una paura appresa.
##
## Il Limbico sapeva già fare la cosa difficile: strada veloce (il corpo
## reagisce a un indizio grezzo), strada lenta (un istante dopo la testa
## capisce), marchi sui luoghi, e l'estinzione che li spegne. Quello che
## mancava era che si VEDESSE, e un verbo per il giocatore.
##
## Questi test difendono le tre cose che si romperebbero in silenzio:
##  1. che la strada veloce possa SBAGLIARSI (spaventarsi di un amico che
##     arriva di corsa nel buio): è l'unico modo in cui la strada lenta ha
##     qualcosa da correggere, e senza quello la meccanica non si vede;
##  2. che la frase del perché non venga formattata PRIMA di essere
##     tradotta — in inglese sparirebbe senza un errore;
##  3. che le regole di Accompagnare restino quelle: si guarisce stando
##     ACCANTO, e allontanarsi non è un fallimento ma un annullamento.

const LIMBICO = preload("res://scenes/npc/Limbico.gd")
const VISITORS = preload("res://scenes/npc/Visitors.gd")
const ACCOMPAGNA = preload("res://scenes/npc/Accompagna.gd")
const LEGAMI = preload("res://scenes/world/Legami.gd")
const MAIL = preload("res://scenes/interact/Mail.gd")
const VISITOR = preload("res://scenes/npc/Visitor.gd")


func run(t) -> void:
	_test_indizio_grezzo(t)
	_test_la_strada_veloce_puo_sbagliarsi(t)
	_test_il_sussulto_nel_rig(t)
	_test_il_perche_non_e_preformattato(t)
	_test_le_regole_di_accompagnare(t)
	_test_estinzione_vera(t)
	_test_momento_del_coraggio(t)
	_test_fili_attaccati(t)


## L'indizio grezzo: quanto è brusco il modo in cui il giocatore arriva.
## Camminare di giorno non è niente; correre addosso nel buio sì.
func _test_indizio_grezzo(t) -> void:
	t.almost(VISITORS.indizio_grezzo(0.0, 0.0, 0.0), 0.0,
			"da ferma, di giorno, non c'è nulla di brusco")
	t.almost(VISITORS.indizio_grezzo(1.4, 1.0, 1.0), 0.0,
			"anche di notte, una camminata tranquilla non spaventa nessuno")
	var corsa_giorno := VISITORS.indizio_grezzo(5.0, 0.0, 1.0)
	var corsa_notte := VISITORS.indizio_grezzo(5.0, 1.0, 1.0)
	t.ok(corsa_giorno > 0.0, "correre addosso si sente anche di giorno (%.2f)" % corsa_giorno)
	t.ok(corsa_notte > corsa_giorno * 1.8,
			"ma nel buio vale molto di più (%.2f contro %.2f)" % [corsa_notte, corsa_giorno])
	var lontano := VISITORS.indizio_grezzo(5.0, 1.0, 0.0)
	t.ok(lontano < corsa_notte,
			"e da lontano meno che addosso (%.2f < %.2f)" % [lontano, corsa_notte])
	for v in [0.0, 2.0, 5.0, 20.0]:
		for b in [0.0, 0.5, 1.0]:
			var x := VISITORS.indizio_grezzo(v, b, 1.0)
			t.ok(x >= 0.0 and x <= 1.0, "resta in 0..1 (v=%.0f b=%.1f)" % [v, b])


## LA COSA CHE CONTA: la strada veloce reagisce a COME arriva qualcosa, non
## a chi è. Deve poter far trasalire un residente che ti VUOLE BENE — è
## quello lo spavento che un istante dopo diventa «ah… sei tu».
func _test_la_strada_veloce_puo_sbagliarsi(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	# un amico vero: marchio POSITIVO su di te
	for i in 4:
		l.rivaluta("regalo", "giocatore", 0.9)
	t.ok(l.carica_di("", "giocatore") > 0.2,
			"il marchio su di te è positivo (%.2f)" % l.carica_di("", "giocatore"))
	# se arrivi piano, si illumina
	var calmo: Dictionary = l.percepisci("giocatore", "", 0.0)
	t.eq(str(calmo["reazione"]), "si_illumina",
			"chi ti vuole bene, se arrivi piano, si illumina")
	# se arrivi di colpo, TRASALISCE LO STESSO: il corpo non sa ancora chi sei
	var l2 = LIMBICO.new()
	l2.setup({})
	for i in 4:
		l2.rivaluta("regalo", "giocatore", 0.9)
	var brusco: Dictionary = l2.percepisci("giocatore", "", 0.8)
	t.eq(str(brusco["reazione"]), "trasalisce",
			"ma se gli arrivi addosso di colpo trasalisce, anche se sei tu")
	t.ok(float(brusco["grezzo"]) > 0.0, "e il sussulto si ricorda di essere stato grezzo")
	# e la STRADA LENTA lo corregge: valutando chi sei davvero, sente bene
	var esito: Dictionary = l2.rivaluta("incontro", "giocatore", 0.55)
	t.ok(float(esito["sentito"]) > -0.001,
			"un istante dopo la testa valuta e non se la prende (%.2f)"
			% float(esito["sentito"]))
	# senza indizio grezzo e senza marchi, non succede niente: nessun
	# residente deve sobbalzare a caso
	var l3 = LIMBICO.new()
	l3.setup({})
	t.eq(str(l3.percepisci("giocatore", "", 0.0)["reazione"]), "nulla",
			"a freddo, senza storia e senza bruschezza, il corpo sta zitto")


## Il sussulto dev'essere nel CORPO: orecchie indietro, coda irrigidita, e
## mezzo passo indietro vero. `vx` da solo è un'inclinazione: un chibi che
## si piega restando inchiodato non sta trasalendo, sta facendo una posa.
func _test_il_sussulto_nel_rig(t) -> void:
	var subito: Dictionary = VISITOR.recita_bersagli("sereno", "trasalisce", 0.02, 0.0)
	t.ok(float(subito["ear"]) < -0.3,
			"le orecchie vanno indietro (%.2f)" % float(subito["ear"]))
	t.ok(float(subito["vz"]) > 0.05,
			"e c'è mezzo passo indietro VERO, non un'inclinazione (%.2f)"
			% float(subito["vz"]))
	t.ok(float(subito["tail"]) < -0.3,
			"e la coda si irrigidisce (%.2f)" % float(subito["tail"]))
	# e tutto rientra: uno spavento che non passa è una postura
	var dopo: Dictionary = VISITOR.recita_bersagli("sereno", "trasalisce", 1.2, 0.0)
	t.ok(absf(float(dopo["vz"])) < absf(float(subito["vz"])) * 0.5,
			"il passo indietro rientra da solo")
	t.ok(absf(float(dopo["tail"])) < absf(float(subito["tail"])) * 0.5,
			"e la coda si riabbassa")
	# a riposo i canali nuovi non devono sporcare nessuna posa
	var fermo: Dictionary = VISITOR.recita_bersagli("sereno", "", 0.0, 0.0)
	t.almost(float(fermo["vz"]), 0.0, "senza transitorio nessuno si sposta")
	t.almost(float(fermo["tail"]), 0.0, "e nessuna coda si muove")


## La frase del perché arriva come TEMPLATE + numero, non già riempita:
## una stringa col «3» dentro non sta in nessuna tabella di traduzione.
func _test_il_perche_non_e_preformattato(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	for i in 3:
		l.rivaluta("spavento", "qualcuno", -0.95, "catasta")
	t.ok(l.evita("catasta"), "tre spaventi lì e ci gira al largo")
	var d: Dictionary = l.perche_evita_dati("catasta")
	t.ok(not d.is_empty(), "e sa dire perché")
	t.ok(str(d["testo"]).contains("%d"),
			"il perché è un TEMPLATE: il numero si mette dopo aver tradotto")
	t.ok(int(d["n"]) >= 2, "e il numero delle volte viaggia a parte (%d)" % int(d["n"]))
	# la versione comoda resta, e dice la stessa cosa
	t.ok(l.perche_evita("catasta").contains(str(int(d["n"]))),
			"la versione già in italiano combacia col template riempito")
	# da un posto che non teme non dice niente (e non esplode)
	t.ok(l.perche_evita_dati("stagno").is_empty(),
			"da un posto qualunque non c'è niente da spiegare")


## Le regole di Accompagnare: si guarisce stando ACCANTO, e allontanarsi
## non è un fallimento — è che accompagnare vuol dire restare.
func _test_le_regole_di_accompagnare(t) -> void:
	t.ok(ACCOMPAGNA.visita_compiuta(1.0, 2.0, ACCOMPAGNA.SECONDI_INSIEME + 0.1),
			"arrivati, accanto, e passato il tempo: la visita conta")
	t.ok(not ACCOMPAGNA.visita_compiuta(1.0, 2.0, 1.0),
			"un attimo non basta: l'estinzione è tempo passato lì")
	t.ok(not ACCOMPAGNA.visita_compiuta(9.0, 2.0, 99.0),
			"e se lui non c'è arrivato non conta, per quanto si aspetti")
	t.ok(not ACCOMPAGNA.visita_compiuta(1.0, 99.0, 99.0),
			"e nemmeno se tu sei da un'altra parte: il punto è essergli accanto")
	t.ok(ACCOMPAGNA.scena_persa(ACCOMPAGNA.DISTANZA_MASSIMA * 2.0),
			"se ti allontani davvero, la scena si scioglie")
	t.ok(not ACCOMPAGNA.scena_persa(ACCOMPAGNA.DISTANZA_MASSIMA),
			"ma c'è un margine: non si annulla per mezzo passo")
	# il posto da affrontare: il primo temuto che il mondo sappia mostrare
	t.eq(ACCOMPAGNA.luogo_da_affrontare(["confine", "catasta"],
			["catasta", "orto"]), "catasta",
			"si salta il posto che non ha una posizione vera")
	t.eq(ACCOMPAGNA.luogo_da_affrontare(["confine"], ["catasta"]), "",
			"e se nessuno dei temuti si sa dov'è, il verbo non si offre")
	t.eq(ACCOMPAGNA.luogo_da_affrontare([], ["catasta"]), "",
			"chi non teme niente non va accompagnato da nessuna parte")


## L'estinzione VERA: tornarci senza che accada niente spegne la paura, e
## bastano poche volte. Se non convergesse, il verbo sarebbe una promessa
## che il sistema non mantiene.
func _test_estinzione_vera(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	for i in 4:
		l.rivaluta("spavento", "qualcuno", -0.95, "catasta")
	t.ok(l.evita("catasta"), "la paura c'è")
	var prima: float = absf(l.carica_di("catasta"))
	var visite := 0
	while l.evita("catasta") and visite < 20:
		l.visita_serena("catasta")
		visite += 1
	t.ok(visite > 0 and visite <= 6,
			"poche visite serene e non lo evita più (%d)" % visite)
	t.ok(absf(l.carica_di("catasta")) < prima,
			"e la carica è scesa (da %.2f a %.2f)" % [prima, absf(l.carica_di("catasta"))])
	# ogni visita DIMEZZA circa: non azzera di colpo, o non sarebbe una cura
	var l2 = LIMBICO.new()
	l2.setup({})
	for i in 4:
		l2.rivaluta("spavento", "qualcuno", -0.95, "orto")
	var c0: float = absf(l2.carica_di("orto"))
	l2.visita_serena("orto")
	var c1: float = absf(l2.carica_di("orto"))
	t.ok(c1 < c0 and c1 > c0 * 0.4,
			"una visita sola non guarisce tutto (%.2f -> %.2f)" % [c0, c1])


## Il giorno in cui una paura si spegne resta sul filo per sempre — e le
## tabelle del Filo Rosso devono restare allineate (è la classe di bug che
## il progetto ha già pagato due volte).
func _test_momento_del_coraggio(t) -> void:
	t.ok(LEGAMI.TIPI.has("coraggio"), "«coraggio» è un momento del Filo")
	t.ok(MAIL.MOMENTI_TESTO.has("coraggio"), "e ha la sua lettera")
	t.ok(str(MAIL.MOMENTI_TESTO.get("coraggio", "")).contains("%d"),
			"che cita il giorno")
	t.eq(str(ACCOMPAGNA.LEGAMI_TIPO), "coraggio",
			"e Accompagna annoda proprio quel tipo")


## I fili nei sorgenti: la strada lenta deve restare cablata, o si torna al
## sussulto senza risoluzione.
func _test_fili_attaccati(t) -> void:
	var src := _sorgente("res://scenes/npc/Visitors.gd")
	t.ok(src.contains("_tick_riconoscimenti"),
			"la strada lenta gira: il sussulto ha una risoluzione")
	t.ok(_body("res://scenes/npc/Visitors.gd", "_tick_sussulti")
			.contains("_riconoscimenti[label] = ATTESA_RICONOSCIMENTO"),
			"e la mette in coda proprio quando il corpo trasalisce")
	t.ok(_body("res://scenes/npc/Visitors.gd", "_tick_riconoscimenti")
			.contains("rivaluta("),
			"la risoluzione passa dalla strada LENTA, non da una battuta scritta")
	t.ok(_body("res://scenes/npc/Visitors.gd", "_tick_sussulti")
			.contains("indizio_grezzo("),
			"e la strada veloce riceve l'indizio grezzo")
	var acc := _sorgente("res://scenes/npc/Accompagna.gd")
	t.ok(acc.contains("visita_serena("),
			"Accompagnare spegne il marchio con l'estinzione del Limbico")
	t.ok(acc.contains("perche_evita_dati("),
			"e dice il perché senza formattare prima di tradurre")
	t.ok(_sorgente("res://scenes/world/CozyWorld.gd").contains("Accompagna.gd"),
			"il verbo è appeso al mondo, o non esiste per il giocatore")
	t.ok(0.3 < VISITORS.ATTESA_RICONOSCIMENTO and VISITORS.ATTESA_RICONOSCIMENTO < 0.7,
			"e fra corpo e testa passa circa mezzo secondo (%.2f s)"
			% VISITORS.ATTESA_RICONOSCIMENTO)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
