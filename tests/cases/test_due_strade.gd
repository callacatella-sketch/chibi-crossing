extends RefCounted
## LE DUE STRADE, RECITATE — e il verbo che spegne una paura appresa.
##
## Il Limbico sapeva già fare la cosa difficile: strada veloce (il corpo
## reagisce a un indizio grezzo), strada lenta (un istante dopo la testa
## capisce), marchi sui luoghi, e l'estinzione che li spegne. Quello che
## mancava era che si VEDESSE, e un verbo per il giocatore.
##
## Questi test difendono le quattro cose che si romperebbero in silenzio:
##  1. che la strada veloce possa SBAGLIARSI (spaventarsi di un amico che
##     arriva di corsa nel buio): è l'unico modo in cui la strada lenta ha
##     qualcosa da correggere, e senza quello la meccanica non si vede;
##  2. che la frase del perché non venga formattata PRIMA di essere
##     tradotta — in inglese sparirebbe senza un errore;
##  3. che le regole di Accompagnare restino quelle: si guarisce stando
##     ACCANTO, e allontanarsi non è un fallimento ma un annullamento;
##  4. che il PERCHÉ SU RICHIESTA (salutare un vicino ancora scosso) parli
##     solo quando il corpo ha davvero qualcosa da dire, e mai al posto
##     del saluto felice quando non c'è niente da spiegare.

const ANIMO = preload("res://scenes/npc/Animo.gd")
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
	_test_il_perche_su_richiesta(t)
	_test_wiring_perche_su_richiesta(t)
	_test_fili_attaccati(t)
	_il_canale_che_non_c_era(t)
	_il_no_non_scrive_niente(t)
	_la_carezza_non_si_conta_due_volte(t)
	_il_verbo_offerto_si_puo_mantenere(t)


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


## IL PERCHÉ SU RICHIESTA: salutare (T) un vicino ancora scosso lo fa
## parlare invece di fare la festa finta. Le due metà sono PURE apposta
## (vedi il commento sopra `corpo_ha_da_dire` in Visitors.gd): `_show_toast`
## presuppone la UI costruita da `_build_ui()`, e chiamarla su un Visitors
## appena creato con `.new()` manderebbe in crash qualunque test — quindi
## la decisione e la composizione si provano senza toccare un nodo vivo,
## e l'orchestrazione (chi chiama chi) si verifica leggendo il sorgente.
func _test_il_perche_su_richiesta(t) -> void:
	# la SOGLIA: solo due stati meritano una nuvoletta, mai "tranquillo"
	t.ok(VISITORS.corpo_ha_da_dire("col cuore in gola"),
			"un cuore in gola ha qualcosa da dire")
	t.ok(VISITORS.corpo_ha_da_dire("ancora guardingo"),
			"e anche il residuo dell'allerta")
	t.ok(not VISITORS.corpo_ha_da_dire("tranquillo"),
			"«tranquillo» a fianco di ogni saluto sarebbe un bollettino medico")
	t.ok(not VISITORS.corpo_ha_da_dire("di buonumore"),
			"e nemmeno un buonumore merita una spiegazione")
	t.ok(not VISITORS.corpo_ha_da_dire(""),
			"un corpo senza dati non deve far esplodere niente")
	# la COMPOSIZIONE: un posto preciso se c'è, il corpo da solo altrimenti
	t.eq(VISITORS.spiegazione_del_corpo("ancora guardingo", ""),
			"ancora guardingo",
			"senza un posto preciso, resta la sensazione pura del corpo")
	t.eq(VISITORS.spiegazione_del_corpo("col cuore in gola",
			"gli è successo qualcosa di brutto lì (3 volte)"),
			"col cuore in gola — gli è successo qualcosa di brutto lì (3 volte)",
			"col posto preciso, le due frasi si compongono in una")


## L'orchestrazione di _spiega_come_sta: legge il corpo, cerca il perché
## SOLO fra i posti che quel residente evita davvero (non una lista fissa
## slegata), e non parla mai a vuoto.
func _test_wiring_perche_su_richiesta(t) -> void:
	var corpo := _body("res://scenes/npc/Visitors.gd", "_spiega_come_sta")
	t.ok(corpo.contains("corpo_ha_da_dire("),
			"la soglia passa dalla funzione pura, non da un if duplicato")
	t.ok(corpo.contains("luoghi_evitati(label)"),
			"il perché si cerca solo fra i posti che QUEL residente evita")
	t.ok(corpo.contains("perche_evita_dati("),
			"mai la versione preformattata: si traduce il template, non la frase")
	t.ok(corpo.contains("chat_bubble") and corpo.contains("speak"),
			"il corpo si vede prima di essere spiegato a parole")
	var saluta := _body("res://scenes/npc/Visitors.gd", "_saluta")
	t.ok(saluta.contains("_spiega_come_sta("),
			"il saluto (T) è la richiesta: senza questo filo il verbo non esiste")
	t.ok(saluta.contains("if not _spiega_come_sta"),
			"e la festa finta scatta SOLO se il corpo non aveva niente da dire")


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


## ⚠️ **IL CANALE CHE NON C'ERA: un vicino può dire di no.**
##
## Fino a ieri, sulla soglia dell'Accompagnare si entrava SEMPRE: bastava
## restargli accanto un secondo e mezzo. Cioè il giocatore non chiedeva —
## **ordinava**, e in tutto il villaggio non esisteva un solo momento in cui
## qualcuno potesse rifiutare. (La Lavagna non conta: è una meccanica del
## gioco, e una meccanica del gioco non può costare — il no doveva nascere
## dove chiedere è già facoltativo.)
func _il_canale_che_non_c_era(t) -> void:
	# --- ⚠️ IL PAVIMENTO È STRUTTURALE: sotto la paura che ferma si entra
	#     sempre, comunque stia il corpo. Per la stragrande maggioranza dei
	#     vicini il gioco è bit per bit quello di ieri.
	var sotto: float = ACCOMPAGNA.PAURA_CHE_FERMA - 0.01
	t.ok(ACCOMPAGNA.ce_la_fa(-sotto, 1.0, 0.0),
			("sotto la paura che ferma si entra SEMPRE, anche col corpo in "
			+ "pieno allarme: e' il gioco di ieri"))
	t.ok(ACCOMPAGNA.ce_la_fa(0.0, 1.0, 0.0),
			"…e a paura zero, ovviamente")

	# --- una paura profonda col corpo in allarme: non ce la fa
	var alta: float = ACCOMPAGNA.PAURA_CHE_FERMA + 0.05
	t.ok(not ACCOMPAGNA.ce_la_fa(-alta, 0.8, 0.0),
			("una paura profonda e il corpo in allarme: non ce la fa, e il "
			+ "soggetto del no e' il POSTO"))

	# --- ⚠️ E LA FIDUCIA AIUTA, ma non piu' di come stai adesso. Se potesse
	#     valere di piu' sarebbe una valuta che compra il coraggio, e il
	#     giocatore imparerebbe a coltivare i vicini invece che a volergli
	#     bene.
	# ⚠️ E NON SI GIUDICA UN FILO DI LAMA. Con `alta` a 0.60 e il corpo a 0.8
	# di allarme, la fiducia piena vale 0.60 + 0.20 − 0.25 = **0.55 esatti**,
	# cioè il pareggio: un'asserzione su quel punto misura l'aritmetica in
	# virgola mobile, non il progetto. La proprietà da sorvegliare è che la
	# fiducia SPOSTI davvero l'esito, e si prova dove l'esito si ribalta —
	# a corpo calmo, che è anche la scena vera (ci si arriva camminando).
	t.ok(not ACCOMPAGNA.ce_la_fa(-alta, 0.0, 0.0),
			"a corpo calmo, senza fiducia, una paura profonda ferma lo stesso")
	t.ok(ACCOMPAGNA.ce_la_fa(-alta, 0.0, 1.0),
			("…e con la fiducia piena entra: il canale non e' decorativo, "
			+ "ribalta un esito"))
	# e la direzione non ha buchi: piu' ci si fida, mai peggio
	var scorso := false
	for q in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var ora: bool = ACCOMPAGNA.ce_la_fa(-alta, 0.0, q)
		t.ok(not scorso or ora,
				"la fiducia non torna mai indietro (a %.2f)" % q)
		scorso = ora
	t.ok(ACCOMPAGNA.PESO_FIDUCIA <= ACCOMPAGNA.PESO_ALLARME + 1e-9,
			("la fiducia non pesa piu' dell'allarme (%.3f contro %.3f): il "
			+ "tetto e' quello che rende impossibile comprarsi il coraggio")
					% [ACCOMPAGNA.PESO_FIDUCIA, ACCOMPAGNA.PESO_ALLARME])

	# --- il segno della carica non conta: si guarda la PROFONDITÀ
	t.eq(ACCOMPAGNA.ce_la_fa(-alta, 0.8, 0.0),
			ACCOMPAGNA.ce_la_fa(alta, 0.8, 0.0),
			"la carica si legge in valore assoluto, come fa `evita`")

	# --- ⚠️ IL DEGRADO E I NUMERI MALATI: un NaN non deve poter chiudere il
	#     posto per sempre. Il degrado va verso «si entra», cioe' il gioco di
	#     ieri.
	for cattivo in [NAN, INF, -INF]:
		t.ok(ACCOMPAGNA.ce_la_fa(cattivo, 0.5, 0.0)
				or not ACCOMPAGNA.ce_la_fa(cattivo, 0.5, 0.0),
				"con %s la funzione risponde e non esplode" % str(cattivo))
	t.ok(ACCOMPAGNA.ce_la_fa(NAN, NAN, NAN),
			("con tutti e tre i numeri malati si ENTRA: il degrado va sempre "
			+ "verso il gioco di ieri, mai verso un no inventato"))

	# --- ⚠️ E LA SOGLIA E' UNA LETTURA, MAI UNA TRANSAZIONE. `trattieni()`
	#     scala la regolazione e alza il cortisolo: usarlo qui vorrebbe dire
	#     far PAGARE al vicino il fatto che gli hai chiesto una cosa.
	var sorgente := FileAccess.get_file_as_string(
			"res://scenes/npc/Accompagna.gd")
	var corpo := sorgente.substr(sorgente.find("static func ce_la_fa"))
	corpo = corpo.substr(0, corpo.find("static func scena_persa"))
	t.ok(not corpo.contains("trattieni"),
			("`ce_la_fa` non chiama `trattieni()`: chiedere non deve poter "
			+ "lasciare il vicino peggio di come stava"))


## ⚠️ **UN NO NON E' UN TORTO: non scrive niente, da nessuna parte.**
##
## Il giocatore non ha niente da riparare, perche' non ha rotto niente — e la
## chiave per la volta dopo e' quella che ha appena visto addosso al corpo:
## stare fermi un momento e richiedere, la stessa grammatica di
## `FiatoSospeso.calma()`.
func _il_no_non_scrive_niente(t) -> void:
	# ⚠️ IL SORGENTE SENZA I COMMENTI, e serve in tutti e due i versi: la cura
	# di questo difetto NOMINA la posa che ha tolto (per spiegare perché l'ha
	# tolta), e un guardiano ingenuo dichiarerebbe rotto proprio il file
	# riparato. È lo stesso ferro di `test_vento`, e sta nell'harness.
	var sorgente: String = load("res://tests/test_util.gd").codice(
			"res://scenes/npc/Accompagna.gd")
	var corpo := sorgente.substr(sorgente.find("func _non_oggi"))
	corpo = corpo.substr(0, corpo.find("func _guarisci"))
	for vietato in ["ricorda", "_marchia", "rancore", "gesto_gentile"]:
		t.ok(not corpo.contains(vietato),
				("il rifiuto non chiama `%s`: un no non e' un torto, e non "
				+ "lascia una riga nel libro mastro") % vietato)
	# ⚠️ e ROMPE IL LEASE, o quello che si vede non e' un rifiuto: e' un fermo
	# immagine di quarantacinque secondi (`manda` scrive `next_act = 45.0`).
	t.ok(corpo.contains("libera"),
			("il rifiuto restituisce la giornata al vicino: senza, il corpo "
			+ "resta piantato sulla soglia per 45 secondi"))
	t.ok(corpo.contains("evitamento"),
			("e il corpo se ne va col Largo — il gesto dell'evitamento, il "
			+ "cui soggetto e' il POSTO"))

	# --- ⚠️ **E IL CAMMINO VA DIROTTATO: il lease e' meta' del lucchetto.**
	#     MISURATO nel MainLevel vero: `manda()` aveva fatto
	#     `do_task("wonder", pos)`, e al verdetto mancano ~1,9 m di strada
	#     verso il posto. Il corpo li camminava — la distanza dalla catasta
	#     passava da 1,09 m a **0,00 m** — ed entrava in `tk_wonder`, con
	#     l'«!» sopra la testa e il cuoricino di `_spawn_heart` all'uscita.
	#     Il rifiuto reso identico a un successo. E l'agenda non poteva
	#     salvarlo: si riprende il corpo solo dagli stati di
	#     `Visitors.STATI_A_RIPOSO`, dove ne' «walk» ne' «tk_wonder» stanno.
	t.ok(corpo.contains("do_routine"),
			("il rifiuto DIROTTA il cammino, non solo il lease: senza, il "
			+ "corpo finisce di camminare dentro il posto che ha rifiutato"))
	var i_rotta := corpo.find("do_routine")
	var i_largo := corpo.find("evitamento")
	t.ok(i_rotta >= 0 and i_largo > i_rotta,
			("e il Largo si chiede DOPO: `_enter_state` chiama "
			+ "`gesto_spegni()`, quindi un gesto chiesto prima morirebbe nel "
			+ "fotogramma in cui nasce"))
	# --- e il Largo deve sapere DA CHE PARTE: senza `posto`, `via` resta il
	#     default +1 (sempre a destra), cioe' meta' delle volte VERSO la
	#     catasta. La domanda e' nel frame del corpo, e la sa solo lui.
	t.ok(corpo.contains("posto"),
			("e il Largo riceve il POSTO: senza, ci si scosta sempre a "
			+ "destra — meta' delle volte verso quello che si sta evitando"))

	# --- ⚠️ **E IL RINNOVO NON DEVE RIMANDARLO INDIETRO.** Il blocco che
	#     rinnova il lease gira PRIMA del `match`: nel fotogramma in cui la
	#     fase e' gia' «no» ma la scena non e' ancora chiusa, un rinnovo
	#     scaduto rispedirebbe il corpo alla catasta con 45 s di lease,
	#     riaprendo la cura da sola.
	var avanza := sorgente.substr(sorgente.find("func _avanza"))
	avanza = avanza.substr(0, avanza.find("func _non_oggi"))
	var i_rinnovo := avanza.find("_manda()")
	t.ok(i_rinnovo > 0, "`_avanza` rinnova il lease mentre la scena vive")
	var prima_del_rinnovo := avanza.substr(0, i_rinnovo)
	t.ok(prima_del_rinnovo.contains('"no"'),
			("e il rinnovo e' gattato sulla fase «no»: chi ha detto di no non "
			+ "viene rimandato indietro con un lease di quarantacinque "
			+ "secondi"))

	# --- ⚠️ **E «NON SCRIVE NIENTE» VALE PER IL CORPO, non solo per il libro
	#     mastro.** MISURATO nel MainLevel vero: qui c'era
	#     `set_meta("postura", "spalle_basse")`, ed era ancora addosso al
	#     corpo **sei secondi dopo e nella scena successiva**. Le pose di
	#     `Visitor.RECITA` sono STABILI: restano finche' qualcuno non toglie
	#     il meta, e qui la scena si chiude nel frame dopo — non c'e' nessuno
	#     che lo tolga. Sarebbe il vicino curvo per il resto della partita di
	#     cui `Visitor._recita_applica` racconta nel proprio commento.
	#
	#     ⚠️ E I NOMI NON SI RICOPIANO: si leggono dalle due tabelle vere. Una
	#     lista scritta a mano qui sarebbe la tabella gemella che diverge in
	#     silenzio il giorno che il vocabolario del corpo cresce.
	var stabili: Array = VISITOR.RECITA.keys().filter(
			func(k): return not VISITOR.RECITA_TRANS.has(k))
	t.ok(stabili.size() >= 3,
			"le pose stabili si leggono da `Visitor.RECITA` (%d)" % stabili.size())
	var posata := ""
	for k in stabili:
		if corpo.contains('"%s"' % str(k)):
			posata = str(k)
			break
	t.eq(posata, "",
			("il rifiuto non posa nessuna posa STABILE addosso al corpo "
			+ "(«%s»): non avrebbe nessuno che gliela tolga, e il Largo e' "
			+ "gia' la sua parola") % posata)


## ⚠️ **LA CAREZZA NON SI CONTA DUE VOLTE — la guardia che non c'era.**
##
## MISURATO: la batteria di mutazioni ha provato otto righe una per volta;
## sette sono diventate rosse e UNA no — togliere il `tranne` da
## `fiducia("giocatore", "accompagnato")` lasciava la suite **completamente
## verde**. Cioè la riga che impedisce alla stessa carezza di pesare due volte
## dentro una sola decisione non aveva **nessun lettore**: la nona volta, in
## questo progetto, che del codice giusto non ha nessuno che lo guardi.
##
## Perché conta: `_guarisci()` scrive una riga `accompagnato` nel libro
## mastro. Senza il `tranne`, la volta scorsa che quel vicino ti ha seguito
## conterebbe DUE volte — una come marchio del posto che scende (il canale
## vero, quello che il giocatore vede) e una come fiducia in te. Il verbo si
## comprerebbe da solo, e ogni accompagnamento renderebbe il successivo più
## facile senza che sia successo niente di nuovo.
##
## ⚠️ E IL TIPO NON SI RICOPIA: si LEGGE da `_guarisci`, cioè dal posto che
## quella riga la scrive. Una stringa ricopiata qui sarebbe la tabella gemella
## che diverge in silenzio il giorno che qualcuno rinomina il gesto.
func _la_carezza_non_si_conta_due_volte(t) -> void:
	var sorgente := FileAccess.get_file_as_string(
			"res://scenes/npc/Accompagna.gd")

	# --- il TIPO che `_guarisci` incide, letto da lui
	var g := sorgente.substr(sorgente.find("func _guarisci"))
	g = g.substr(0, g.find("func _nodo"))
	var m := RegEx.new()
	m.compile('gesto_gentile"\\s*,\\s*label\\s*,\\s*"([a-z_]+)"')
	var trovato := m.search(g)
	t.ok(trovato != null,
			"`_guarisci` incide una riga nel libro mastro, e si vede quale")
	var tipo := trovato.get_string(1) if trovato != null else ""

	# --- e OGNI lettura della fiducia deve escludere ESATTAMENTE quello.
	#     ⚠️ Non basta guardare `_ce_la_fa_ora`: da quando anche l'offerta
	#     interroga la fiducia (`_vale_la_pena`) i lettori sono due, e una
	#     guardia che ne conosce uno solo lascia l'altro scoperto — misurato,
	#     la mutazione sul secondo restava verde. Si contano TUTTE le
	#     chiamate: cosi' la guardia copre anche il lettore che verra'.
	var codice: String = load("res://tests/test_util.gd").codice(
			"res://scenes/npc/Accompagna.gd")
	var re := RegEx.new()
	re.compile('animo\\.fiducia\\(([^)]*)\\)')
	var letture := re.search_all(codice)
	t.ok(letture.size() >= 2,
			"la fiducia si legge in piu' di un posto (%d)" % letture.size())
	for lettura in letture:
		var argomenti := lettura.get_string(1)
		t.ok(argomenti.contains('"%s"' % tipo),
				("ogni lettura della fiducia esclude il gesto che `_guarisci` "
				+ "scrive («%s»): trovato `fiducia(%s)` — senza il `tranne` "
				+ "la stessa carezza pesa due volte") % [tipo, argomenti])

	# --- e il `tranne` FUNZIONA davvero: non è una stringa decorativa
	var a = ANIMO.new()
	a.setup({"nome": "Prova", "tratti": {}})
	for i in 5:
		a.ricorda(tipo, "giocatore", 0.8, 0.9)
	var con_tutto: float = a.fiducia("giocatore")
	var senza: float = a.fiducia("giocatore", tipo)
	t.ok(con_tutto > 0.05,
			"cinque accompagnamenti costruiscono fiducia (%.3f)" % con_tutto)
	t.almost(senza, 0.0,
			("…ma non la propria: escludendo «%s» resta zero (%.3f)"
			% [tipo, senza]), 0.0005)

	# --- la CONTROPROVA: un gesto DIVERSO conta eccome, o il `tranne` sarebbe
	#     diventato un interruttore che spegne tutto il canale
	var b = ANIMO.new()
	b.setup({"nome": "Prova2", "tratti": {}})
	for i in 5:
		b.ricorda("regalo", "giocatore", 0.8, 0.9)
	t.ok(b.fiducia("giocatore", tipo) > 0.05,
			("un gesto diverso conta per intero (%.3f): il `tranne` non "
			+ "guarda due volte una riga, non spegne il canale")
					% b.fiducia("giocatore", tipo))


## ⚠️ **UN VERBO OFFERTO DEV'ESSERE CONCEDIBILE — e questa e' l'invariante che
## la soglia nuova poteva rompere in silenzio.**
##
## `Limbico.evita` apre il prompt a `SOGLIA_EVITAMENTO` (0,45); `ce_la_fa` lo
## concede sotto il proprio tetto. Se le due fasce non si sovrapponessero, il
## gioco offrirebbe l'Accompagnare e non lo concederebbe MAI — il giocatore
## attraverserebbe il villaggio per un no certo, e imparerebbe a non usare piu'
## il verbo. Sarebbe la prima domanda della REGOLA SACRA fallita in modo
## strutturale: nessuna chiave a forma di giocatore, perche' nessun gesto
## cambia l'esito.
##
## ⚠️ E I DUE NUMERI SI LEGGONO DA DOVE VIVONO: la soglia da `Limbico`, il
## tetto da `Accompagna`. Scriverli a mano qui li giudicherebbe contro se'
## stessi — il caso resterebbe verde portando `PAURA_CHE_FERMA` a zero.
func _il_verbo_offerto_si_puo_mantenere(t) -> void:
	var apre: float = LIMBICO.SOGLIA_EVITAMENTO
	# il tetto: la paura piu' profonda che si possa ancora affrontare, a corpo
	# calmo e con la fiducia piena. Sopra, `ce_la_fa` e' una costante falsa.
	var tetto: float = ACCOMPAGNA.PAURA_CHE_FERMA + ACCOMPAGNA.PESO_FIDUCIA
	t.ok(tetto > apre,
			("la fascia in cui il verbo si offre (da %.2f) e quella in cui si "
			+ "puo' concedere (fino a %.2f) si sovrappongono: esiste una "
			+ "paura che si offre E si puo' affrontare") % [apre, tetto])
	# e la sovrapposizione non e' un filo: dev'esserci spazio vero
	t.ok(tetto - apre > 0.15,
			("…e la sovrapposizione e' larga %.2f, non un filo di lama"
			% (tetto - apre)))

	# --- il caso VERO: una paura dentro la fascia si affronta, una sopra no
	var dentro: float = (apre + tetto) * 0.5
	t.ok(ACCOMPAGNA.ce_la_fa(-dentro, 0.0, 1.0),
			("una paura in mezzo alla fascia (%.2f) si affronta, se ci si "
			+ "fida e si e' calmi") % dentro)
	t.ok(not ACCOMPAGNA.ce_la_fa(-(tetto + 0.05), 0.0, 1.0),
			"e una sopra il tetto no, comunque si stia")

	# --- ⚠️ E L'OFFERTA GUARDA IL CASO MIGLIORE, non adesso. Se `_vale_la_pena`
	#     passasse l'arousal vero, il prompt sparirebbe a chi in questo momento
	#     ha il cuore in gola — cioe' proprio a chi si sta avvicinando a Mochi —
	#     e tornerebbe un attimo dopo: un verbo che lampeggia non e' un verbo.
	var acc: String = load("res://tests/test_util.gd").codice(
			"res://scenes/npc/Accompagna.gd")
	# ⚠️ e il corpo della funzione va DELIMITATO: senza, `substr` arriva a fine
	# file e ci finisce dentro `_ce_la_fa_ora`, che l'allarme lo guarda —
	# giustamente, perche' e' lei a decidere sulla soglia. Una guardia che
	# legge il file intero accusa la funzione sbagliata.
	var vp := acc.substr(acc.find("func _vale_la_pena"))
	vp = vp.substr(0, vp.find("func _process"))
	t.ok(vp.contains("0.0"),
			("`_vale_la_pena` chiede il caso MIGLIORE (allarme zero): "
			+ "l'offerta e' onesta, l'esito resta vivo"))
	t.ok(not vp.contains("arousal"),
			("…e non guarda l'allarme di adesso: il prompt non deve "
			+ "lampeggiare col battito di chi ti vede arrivare"))
	# e il candidato la CHIAMA: senza, tutto questo e' aritmetica che nessuno
	# esegue — la nona volta, in questo progetto.
	var cand := acc.substr(acc.find("func _candidato"))
	cand = cand.substr(0, cand.find("func _vale_la_pena"))
	t.ok(cand.contains("_vale_la_pena"),
			"e `_candidato` la interroga davvero prima di offrire il verbo")
