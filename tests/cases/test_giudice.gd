extends RefCounted
## IL GIUDICE — venti bozze entrano, una esce. O nessuna.
## (Fase 5, il passo della scelta.)
##
## La cosa da provare non è che il giudice «scelga»: sceglie sempre. È che
## **non scelga una bugia**, e che il giorno in cui gliene arrivano venti
## tutte vere non ne scelga sempre la stessa. Sono le due metà del dilemma
## misurato dal provino — i modelli onesti sono monotoni, i modelli vari
## inventano — e un giudice che ne cura una sola non serve a niente.
##
## Perciò i casi qui sotto sono di due specie, e nessuna guarda il sorgente:
##  · quelli che gli danno da scegliere fra una bozza VERA e una FALSA e
##    pretendono la vera — anche quando la falsa è più bella, più rara e più
##    nuova, che è il caso peggiore e anche quello misurato sul mazzo vero;
##  · quelli che gli danno quindici bozze legittime e quasi identiche e
##    pretendono che tiri fuori quella diversa.
##
## E uno che non riguarda il giudice ma il Gufo: **le righe scritte a mano
## nelle lettere di `Director` devono passare l'ancoraggio**. È l'unico
## oracolo indipendente che questo file abbia — se un domani qualcuno stringe
## le regole fino a bocciare la voce del Gufo, quella non è più una guardia:
## è una museruola, e la suite lo dice qui.

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")
const DIRECTOR := preload("res://scenes/npc/Director.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")

const B_SENTITO := 1
const B_SU_DI_ME := 2
const B_NESSUNO := 4294967295


func run(t) -> void:
	_il_gufo_scritto_a_mano_passa(t)
	_il_buco_del_collaudo_e_chiuso(t)
	_una_riga_libera_puo_ancora_respirare(t)
	_la_parola_incollata_non_e_una_parola(t)
	_il_pezzo_di_citazione_non_e_una_riga_tua(t)
	_il_foglio_non_e_testo(t)
	_le_virgolette_non_ci_sono(t)
	_una_parola_senza_vocali_non_e_una_parola(t)

	_l_ancoraggio_e_una_porta_non_un_punteggio(t)
	_lo_scarto_raro_vince(t)
	_a_pari_merito_vince_il_primo(t)
	_due_giri_uguali_danno_la_stessa_lettera(t)

	_non_si_ripete(t)
	_l_incipit_conta_da_solo(t)
	_citare_lo_stesso_fatto_non_e_ripetersi(t)

	_il_silenzio_e_un_esito(t)
	_senza_bozze_non_si_inventa_niente(t)

	_gli_obiettivi_della_deduzione_sono_quelli_del_mondo(t)
	_una_deduzione_senza_ricevuta_non_passa(t)
	_la_catena_vale_il_suo_anello_piu_debole(t)


# =========================================================================
# IL BANCO — lo stesso vicino del provino, così i numeri si confrontano
# =========================================================================

## Il ritratto di prova: quattro ricordi, uno per forma di frase.
## Le citazioni che ne escono sono quelle su cui il provino ha misurato tutto.
func _banco() -> Dictionary:
	return {
		"nome": "la volpina Papavero", "eta": "giovane",
		"indole": ["goloso"], "quirk": "canta_alla_luna",
		"casa": Vector3(4, 0, 6), "azione": "quattro_chiacchiere",
		"obiettivo": "", "stagione": "autunno", "momento": "pomeriggio",
		"ciclo": 240.0, "protagonista": "Mochi", "compito": "lettera",
		"nomi": {3: "la volpina Prugna"},
		"verbi": ["annaffia", "semina", "raccoglie", "costruisce",
				"taglia", "pesca", "cucina", "dona"],
		"cose": ["fiore", "cibo", "casa", "fuoco", "pesce", "amico"],
		"gusto": PackedFloat64Array([1.0, 1.0, 2.2, 0.0, 1.0, 1.0]),
		"tinte": {"ammirazione": 2.9, "gratitudine": 1.4,
				"interesse": PackedFloat64Array([0, 0, 2.2, 0, 0, 0])},
		"ora": 900.0, "mezza_vita": 120.0,
		"pesi": PackedFloat64Array([2.4, 1.2, 0.6, 0.4]),
		"bandiere": {"sentito": B_SENTITO, "su_di_me": B_SU_DI_ME,
				"detto": 4, "nessuno": B_NESSUNO},
		"ricordi": [
			_ric(0, 0, 6, 5.0, 7.0, 880.0),                 # annaffia, vicino
			_ric(7, B_SU_DI_ME, 1, 4.0, 6.0, 700.0, 3),     # ha ricevuto un dono
			_ric(5, B_SENTITO, 2, 40.0, 30.0, 860.0),       # pesca, sentito dire
			_ric(3, 0, 1, 30.0, 30.0, 300.0),               # costruisce, lontano
		],
	}


func _ric(verbo: int, bandiere: int, quante: int, px: float, pz: float,
		quando: float, sogg := B_NESSUNO) -> Dictionary:
	return {"verbo": verbo, "bandiere": bandiere, "quante": quante,
			"px": px, "pz": pz, "quando": quando, "soggetto": sogg}


## Una lettera fatta bene: la citazione numero `k` più le righe date.
func _lettera(rit: Dictionary, k: int, prima: String, dopo: String) -> String:
	var cit: Array = SUG.citazioni(rit)
	return "%s\n%s\n%s" % [prima, str(cit[k]), dopo]


# =========================================================================
# L'ANCORAGGIO — la porta che prima non c'era
# =========================================================================

## L'ORACOLO INDIPENDENTE. L'ultima riga di una lettera del Gufo è sempre
## SUA — è la forma di tutte e sei: prima cos'è successo (che qui viene dalla
## lista chiusa), poi cos'ha pensato lui. Quelle righe sono la definizione
## vivente di «una riga libera fatta bene», e non le ha scritte questo file.
func _il_gufo_scritto_a_mano_passa(t) -> void:
	var rit := _banco()
	var quante := 0
	for k in DIRECTOR.TACCUINO_LETTERE:
		var testo := str((DIRECTOR.TACCUINO_LETTERE[k] as Dictionary)["text_key"])
		var righe := testo.split("\n")
		var ultima := str(righe[righe.size() - 1])
		var m := str(SUG.afferma(ultima, rit))
		t.eq(m, "", "il Gufo scritto a mano passa l'ancoraggio (%s: «%s»)" % [k, ultima])
		quante += 1
	# se un domani le lettere cambiassero forma, questo numero lo dice
	t.ok(quante >= 6, "le lettere scritte a mano sono ancora almeno sei (%d)" % quante)


## LE RIGHE VERE DEL PROVINO CHE PASSAVANO CON LA LUCE VERDE. Sono state
## generate dai quattro modelli l'11 agosto: tutte minuscole, senza cifre,
## dentro il conto delle parole — cioè irreprensibili per il collaudo di
## prima, che guardava i caratteri. Ognuna dice una cosa che non è successa.
##
## Si pretende anche la PORTA: `ancoraggio` vuol dire «il collaudo di prima
## l'avrebbe promossa», ed è la misura del buco.
func _il_buco_del_collaudo_e_chiuso(t) -> void:
	var rit := _banco()
	var casi := [
		["ti hanno sentito parlare a lungo con la volpina perua, e l'ho vista allontanarsi.",
				"un fatto inventato di sana pianta"],
		["l'ho vista costruire dal palo del filo per il vetro, dalla parte della casa.",
				"una seconda citazione scritta a mano"],
		["ho visto come hai fissato quel pezzo di legno, con tanto amore.",
				"il passato della seconda persona"],
		["sono rimasta lì a guardare fino a quando non sei andata via.",
				"un altro passato della seconda persona"],
		["la volpina papavero si sente sola nella sua casa di foglie secche.",
				"il nome di una vicina, in minuscolo"],
		["papavero non sa dove sei, ma sente il tuo peso leggero.",
				"il nome nudo, senza la specie"],
		["il villaggio è pieno di aiuole, ma la sua è l'unica che non è annaffiata.",
				"un verbo del villaggio coniugato"],
		["le case sono state regolate con cura, come sempre.",
				"una cosa del villaggio messa al passato"],
		["mi hanno raccontato di averti vista pescare, dall'altra parte.",
				"il sentito dire riscritto a mano"],
		# ⚠️ QUESTA RIGA HA UNA STORIA. La falsificazione ha trovato che
		# «chi ti ha vista» non era sorvegliato da nessun caso: le altre
		# righe che lo contengono cadevano prima, sulla percezione seguita da
		# un'azione. Qui il telaio è NUDO — «vista» non è seguita da niente —
		# e allora l'unica regola che può prenderla è quella della terza
		# persona su di te. Toglierla lasciava la suite verde.
		["ti hanno vista, e adesso lo sanno tutti.",
				"chi altri ti ha vista, che è il mestiere del sentito dire"],
		# ⚠️ LE DUE RIGHE CHE PASSAVANO ANCORA, e sono uscite davvero: la
		# regola del telaio pretendeva PERCEZIONE + un infinito o un
		# participio, quindi con un oggetto NOMINALE non scattava; e la regola
		# del passato di seconda persona guarda «hai/sei», non «ho». Misurate
		# su un banco puro, senza modello, prima che la regola 3b esistesse.
		["ho visto i tuoi passi e ho visto le tue zampe.",
				"cos'ho visto DI TE, detto con un nome invece che con un verbo"],
		["ho visto la tua casa e ho visto il tuo focolare.",
				"lo stesso, con la seconda persona in un possessivo"],
		["l'ho guardata, la tua aiuola, per tutto il pomeriggio.",
				"il telaio nudo, e il «tuo» due parole più in là"],
	]
	for c in casi:
		var riga := str(c[0])
		t.ok(str(SUG.afferma(riga, rit)) != "", "l'ancoraggio boccia: %s" % str(c[1]))
		var testo := _lettera(rit, 0, "il vento muove le foglie di pietra.", riga)
		var esito: Dictionary = SUG.accetta(testo, rit)
		t.ok(not bool(esito["ok"]), "e la lettera intera non passa: %s" % str(c[1]))
		t.eq(str(esito.get("porta", "")), "ancoraggio",
				"...e passa dalla porta nuova, cioè prima sarebbe uscita (%s)" % str(c[1]))


## LA CONTROPROVA, e senza di lei le regole di sopra non provano niente: un
## controllo che boccia tutto è verde su ogni caso negativo. Queste righe sono
## uscite dagli stessi quattro modelli e non affermano niente — devono
## passare, comprese quelle che il primo giro di taratura bocciava.
func _una_riga_libera_puo_ancora_respirare(t) -> void:
	var rit := _banco()
	for riga in [
		"il vento accarezza il muschio, e il silenzio si allunga sul legno.",
		"il sole è sceso lento, e le ombre sono lunghe.",
		"le case sono ancora tristi dopo la sera di ieri.",
		"non ho visto nulla di nuovo, solo i rami che si muovono al vento.",
		"l'ho guardato dall'alto, stamattina, e non ho detto niente.",
		"anche quando tagliare sarebbe più corto, io giro attorno.",
		"ci ho pensato tutto il pomeriggio, e non ho concluso niente.",
		"il silenzio riempie le case, e a me va bene così.",
	]:
		t.eq(str(SUG.afferma(riga, rit)), "",
				"una riga che non afferma niente passa: «%s»" % riga)


## IL FOGLIO LETTO AD ALTA VOCE. Il prompt scrive tre cose che il modello deve
## LEGGERE e mai ripetere — il dossier del vicino, l'etichetta del peso fra
## quadre, i pezzi facoltativi fra parentesi — e nessuna delle tre è falsa:
## sono appunti di regia, e una lettera che li recita suona come un referto.
##
## Ogni riga qui sotto è USCITA DAVVERO, sul mazzo di 180 bozze registrate in
## partita: fra le 77 che il collaudo promuoveva, una su cinque era questa
## cosa qui. La coda conta quanto la frase intera — l'etichetta è «se lo
## ricorda bene» e la riga diceva «che lo ricorda bene».
func _il_foglio_non_e_testo(t) -> void:
	var rit := _banco()
	var casi := [
		["che lo ricorda bene, come una pietra al sole.", "l'etichetta del peso, senza il «se»"],
		["il suo peso resta addosso appena, e non so dire altro.", "l'etichetta del peso, intera"],
		["qualche ora fa, e da allora non è cambiato niente.",
				"il «quando», che sta fra parentesi"],
		["che a due passi da casa sua, e nient'altro.", "il «dove», che sta fra parentesi"],
		["ha sempre un certo languorino, e non lo dice.", "l'indole, cioè il dossier"],
		["poi, un certo languorino che non passa mai.", "l'indole, presa dalla coda"],
		["capita che canticchia alla luna, quando è tardi.", "la stravaganza"],
		["adesso cerca qualcuno con cui parlare, e non lo trova.", "il mestiere di adesso"],
		["quello che sta più a cuore è lontano, stasera.", "l'apertura dell'elenco del gusto"],
	]
	for c in casi:
		var riga := str(c[0])
		var testo := _lettera(rit, 0, "il vento muove le foglie di pietra.", riga)
		var esito: Dictionary = SUG.accetta(testo, rit)
		t.ok(not bool(esito["ok"]), "il foglio riletto non passa: %s" % str(c[1]))
		t.eq(str(esito.get("porta", "")), "forma",
				"...e passa dalla porta della forma (%s)" % str(c[1]))

	# LA CONTROPROVA, e senza di lei tutto questo sarebbe un controllo che
	# boccia tutto. Sotto le tre parole un frammento smette di essere la frase
	# del gioco e torna a essere italiano di chiunque — e il dossier di UN
	# ALTRO vicino non è il foglio di questo.
	for riga in [
		"il vento sussurra poco fa, e nessuno lo sente.",
		"si riposa anche la pietra, in questo villaggio.",
		"a lungo, e poi il silenzio si è richiuso sopra tutto.",
		"poltrisce fino a tardi anche il sole, in autunno.",
		"si perde a guardare il cielo perfino il fiume, oggi.",
		# e nemmeno un «quando» che questo foglio non contiene: le frasi
		# vietate sono quelle scritte STASERA, non le sei possibili
		"un pezzo fa il villaggio era più piccolo, e si sentiva.",
	]:
		var testo := _lettera(rit, 0, "il vento muove le foglie di pietra.", riga)
		t.ok(bool((SUG.accetta(testo, rit) as Dictionary)["ok"]),
				"e una riga che non è di questo foglio passa: «%s»" % riga)


## LE VIRGOLETTE NON CI SONO, e un apostrofo che non elide è una virgoletta.
##
## È la regola che pesa di più sul mazzo vero: **44 bozze su 180**, cioè più
## della metà di quelle che il collaudo promuoveva. Un modello piccolo prende
## l'apostrofo per una virgoletta, e da lì la riga libera smette di essere sua
## e diventa una citazione di qualcosa — del foglio, della SAGOMA del prompt
## («'una riga tua' irds un fiore»), o di una frase che nessuno ha detto
## («'mi hai vista annaffiare le aiuole'»).
func _le_virgolette_non_ci_sono(t) -> void:
	var rit := _banco()
	for riga in [
		"'una riga tua' e poi il vento si è fermato.",
		"il sole scende, ' e la pietra resta fredda.",
		"' ' e poi più niente, per tutta la sera.",
		"non so dirlo, 'forse è solo il vento che passa.",
	]:
		var testo := _lettera(rit, 0, "il vento muove le foglie di pietra.", riga)
		var esito: Dictionary = SUG.accetta(testo, rit)
		t.ok(not bool(esito["ok"]), "una virgoletta non passa: «%s»" % riga)
		t.eq(str(esito.get("porta", "")), "forma", "...e passa dalla forma: «%s»" % riga)

	# LA CONTROPROVA: l'apostrofo italiano resta, tutto quanto. L'elisione
	# («l'ho», «un'ombra») e il troncamento in fondo («un po'») sono la
	# ragione per cui l'apostrofo è nell'alfabeto, e vietarli vorrebbe dire
	# togliere al Gufo il modo in cui questa lingua respira.
	for riga in [
		"l'ho pensato tutto il pomeriggio, e non ho concluso niente.",
		"un'ombra lunga si è posata sul legno, e ci è rimasta.",
		"un po' di silenzio, e il villaggio sembra più grande.",
		"c'è un po' d'aria stasera, e l'erba se n'è accorta.",
	]:
		var testo := _lettera(rit, 0, "il vento muove le foglie di pietra.", riga)
		t.ok(bool((SUG.accetta(testo, rit) as Dictionary)["ok"]),
				"e l'apostrofo che elide passa: «%s»" % riga)


## UNA PAROLA SENZA VOCALI NON È UNA PAROLA. Regola di lingua, non di gusto:
## in italiano ogni parola ne ha almeno una, e le sigle qui non esistono
## (non ci sono maiuscole).
##
## ⚠️ IL CASO CHE LA TIENE ONESTA è il secondo: `parole()` spezza
## sull'apostrofo apposta, quindi «l'ho» dà «l» e «ho» — e «l» non ha vocali.
## Una prima stesura guardava proprio lì e bocciava **19 bozze su 180**, quasi
## tutte per un'elisione perfettamente italiana.
func _una_parola_senza_vocali_non_e_una_parola(t) -> void:
	var rit := _banco()
	var testo := _lettera(rit, 0, "il vento muove le foglie.",
			"il silenzio si posa sul legno, ryst.")
	var esito: Dictionary = SUG.accetta(testo, rit)
	t.ok(not bool(esito["ok"]), "un pezzo di gettone non è una parola")
	t.eq(str(esito.get("porta", "")), "parola", "...e passa dalla porta della parola")

	for riga in [
		"l'ho pensato a lungo, e non ne ho parlato con nessuno.",
		"c'è chi dorme e c'è chi guarda, e va bene così.",
		"quell'ombra si è mossa appena, poi più niente.",
	]:
		var buona := _lettera(rit, 0, "il vento muove le foglie.", riga)
		t.ok(bool((SUG.accetta(buona, rit) as Dictionary)["ok"]),
				"e l'elisione non è una parola senza vocali: «%s»" % riga)


## Il modello che sbatte contro il tetto della grammatica non si ferma:
## incolla. Sei parole su 392 righe del provino, tutte incollate, e la più
## lunga parola italiana vera del mazzo ne ha tredici.
func _la_parola_incollata_non_e_una_parola(t) -> void:
	var rit := _banco()
	var testo := _lettera(rit, 0, "il vento muove le foglie.",
			"la sua aiuola è l'unica che non è stataannaffiata oggi.")
	var esito: Dictionary = SUG.accetta(testo, rit)
	t.ok(not bool(esito["ok"]), "una parola incollata non passa")
	# e la riga «sana» della stessa forma passa, o starei misurando altro
	var buono := _lettera(rit, 0, "il vento muove le foglie.",
			"e io sono rimasto sul ramo a non fare niente.")
	t.ok(bool(SUG.accetta(buono, rit)["ok"]), "la stessa lettera senza la parola incollata passa")


## La citazione andata a capo lascia in giro un pezzo di sé che sembra una
## riga libera: minuscolo, corto, senza affermazioni. Non è una bugia, è una
## lettera rotta — e va buttata lo stesso.
func _il_pezzo_di_citazione_non_e_una_riga_tua(t) -> void:
	var rit := _banco()
	var testo := _lettera(rit, 4, "il sole cade piano sul tetto.",
			"dall'altra parte del villaggio.")
	t.ok(not bool(SUG.accetta(testo, rit)["ok"]), "un pezzo di citazione non è una riga tua")

	# L'ETICHETTA DEL PESO. Nel foglio sta fra quadre, per dire al modello di
	# cosa valga la pena parlare; questa riga viene da una lettera vera del
	# provino, ed è arrivata fino allo schermo.
	var leak := _lettera(rit, 0, "il sole cade piano sul tetto.",
			"il peso di quel gesto resta addosso appena, come una pietra.")
	t.ok(not bool(SUG.accetta(leak, rit)["ok"]), "l'etichetta del peso non è una riga tua")
	# ...ma l'italiano normale che ci somiglia resta lecito: si confronta
	# l'etichetta INTERA, o il Gufo perde una frase che è sua.
	var lecito := _lettera(rit, 0, "il sole cade piano sul tetto.",
			"il rumore del tuo passo mi resta addosso, non so perché.")
	t.ok(bool(SUG.accetta(lecito, rit)["ok"]),
			"«mi resta addosso» è italiano, e passa")


# =========================================================================
# LA SCELTA
# =========================================================================

## IL CASO CHE DEFINISCE IL PROGETTO, ed è misurato sul mazzo vero: la bozza
## più RARA è anche quella che inventa. Qui gliene diamo quattro identiche e
## vere, e una unica e falsa: se l'ancoraggio fosse un punteggio da sommare
## alla rarità, vincerebbe la falsa. È una porta, quindi non può vincere —
## mai, con nessun peso.
func _l_ancoraggio_e_una_porta_non_un_punteggio(t) -> void:
	var rit := _banco()
	var uguale := "il vento muove le foglie di pietra."
	var bozze := [
		_lettera(rit, 0, uguale, "il silenzio si allunga sul legno."),
		_lettera(rit, 0, uguale, "il silenzio si allunga sul legno, ancora."),
		_lettera(rit, 0, uguale, "il silenzio si allunga sul legno, adesso."),
		_lettera(rit, 0, uguale, "il silenzio si allunga sul legno, sempre."),
		# la più rara di tutte, e l'unica che mente
		_lettera(rit, 0, "una lucciola sola scrive una riga d'oro sull'acqua nera.",
				"ho visto come hai fissato quel pezzo di legno, con tanto amore."),
	]
	var esito: Dictionary = GIU.scegli(bozze, rit)
	t.ok(int(esito["scelta"]) >= 0, "una lettera esce")
	t.ok(int(esito["scelta"]) != 4, "la bozza più rara NON vince se inventa")
	var schede: Array = esito["schede"]
	t.eq(str((schede[4] as Dictionary)["porta"]), "ancoraggio",
			"e la si boccia per il motivo giusto")
	# la controprova: la stessa bozza, senza la bugia, VINCE — cioè la rarità
	# funziona davvero e il caso di sopra non passa perché il giudice è cieco
	bozze[4] = _lettera(rit, 0, "una lucciola sola scrive una riga d'oro sull'acqua nera.",
			"non ho mosso una piuma, per non disturbarti.")
	t.eq(int(GIU.scegli(bozze, rit)["scelta"]), 4,
			"la stessa bozza rara, se non mente, vince")


## LA CURA DELLA MONOTONIA. Quattordici bozze che si somigliano e una che
## no: esce quella. È il caso di gemma3, che scrive quindici lettere con due
## incipit.
func _lo_scarto_raro_vince(t) -> void:
	var rit := _banco()
	var bozze := []
	for i in 14:
		bozze.append(_lettera(rit, 0, "il vento sussurra fra i rami alti.",
				"il silenzio si allunga sul legno."))
	bozze.append(_lettera(rit, 0, "una lucciola sola scrive una riga d'oro sull'acqua nera.",
			"e io non ho mosso una piuma."))
	var esito: Dictionary = GIU.scegli(bozze, rit)
	t.eq(int(esito["scelta"]), 14, "fra quindici bozze esce lo scarto raro")
	var schede: Array = esito["schede"]
	t.ok(float((schede[14] as Dictionary)["rarita"]) > float((schede[0] as Dictionary)["rarita"]),
			"e la rarità misurata gli dà ragione")


func _a_pari_merito_vince_il_primo(t) -> void:
	var rit := _banco()
	var una := _lettera(rit, 0, "il vento sussurra fra i rami.", "il silenzio si allunga.")
	t.eq(int(GIU.scegli([una, una, una], rit)["scelta"]), 0,
			"a pari merito vince l'indice più basso: nessun dado, mai")


## Il giudice è puro: due giri identici danno la stessa lettera. Se un domani
## qualcuno ci mettesse dentro un dado (per «variare»), il villaggio
## smetterebbe di poter riprodurre una sera.
func _due_giri_uguali_danno_la_stessa_lettera(t) -> void:
	var rit := _banco()
	var bozze := [
		_lettera(rit, 0, "il vento sussurra fra i rami.", "il silenzio si allunga."),
		_lettera(rit, 1, "una lucciola scrive sull'acqua nera.", "non ho mosso una piuma."),
		_lettera(rit, 2, "la nebbia sale dal fondo del prato.", "e io resto qui a guardare."),
	]
	var a: Dictionary = GIU.scegli(bozze, rit)
	var b: Dictionary = GIU.scegli(bozze, rit)
	t.eq(int(a["scelta"]), int(b["scelta"]), "due giri identici, la stessa scelta")
	t.eq(str(a["lettera"]), str(b["lettera"]), "e la stessa lettera rifinita")


# =========================================================================
# LA MEMORIA
# =========================================================================

func _non_si_ripete(t) -> void:
	var rit := _banco()
	var vecchia := _lettera(rit, 0, "il vento sussurra fra i rami alti.",
			"il silenzio si allunga sul legno.")
	var quasi := _lettera(rit, 1, "il vento sussurra fra i rami alti, oggi.",
			"il silenzio si allunga sul legno, ancora.")
	var nuova := _lettera(rit, 1, "una lucciola scrive una riga d'oro sull'acqua nera.",
			"e io non ho mosso una piuma.")
	var esito: Dictionary = GIU.scegli([quasi, nuova], rit, {"sue": [vecchia]})
	t.eq(int(esito["scelta"]), 1, "non si rimanda una lettera già mandata")
	var schede: Array = esito["schede"]
	t.eq(str((schede[0] as Dictionary)["porta"]), "memoria", "e si dice che è la memoria")
	# la controprova: senza memoria, quella bozza è legittima
	t.ok(int(GIU.scegli([quasi], rit)["scelta"]) == 0,
			"la stessa bozza, senza memoria, va benissimo")

	# ⚠️ E LA STESSA LETTERA CHE COMINCIA DIVERSA. Anche questo caso viene
	# dalla falsificazione: senza di lui, la SOGLIA di somiglianza non era
	# sorvegliata da nessuno — la bozza di sopra cadeva già sull'incipit, e
	# cancellare il confronto sul corpo lasciava la suite verde. Qui l'inizio
	# è diverso apposta, così l'unica porta che può chiudersi è quella.
	var travestita := _lettera(rit, 1, "oggi il vento sussurra fra i rami alti.",
			"il silenzio si allunga sul legno.")
	t.ok(GIU.incipit(travestita, SUG.citazioni(rit))
			!= GIU.incipit(vecchia, SUG.citazioni(rit)),
			"comincia in un altro modo, quindi l'incipit non c'entra")
	var esito2: Dictionary = GIU.scegli([travestita, nuova], rit, {"sue": [vecchia]})
	t.eq(int(esito2["scelta"]), 1, "cambiare le prime parole non basta a rifare la stessa lettera")
	t.eq(str((esito2["schede"][0] as Dictionary)["porta"]), "memoria",
			"e la porta è ancora la memoria")


## L'incipit vale da solo: due lettere che cominciano con le stesse due
## parole sono due lettere uguali per chi legge, anche se il resto diverge.
func _l_incipit_conta_da_solo(t) -> void:
	var rit := _banco()
	var vecchia := _lettera(rit, 0, "il vento sussurra fra i rami alti.",
			"il silenzio si allunga sul legno.")
	var stesso_inizio := _lettera(rit, 1, "il vento porta odore di terra bagnata e di fumo.",
			"domani chissà dove sarò.")
	var altra := _lettera(rit, 1, "una lucciola scrive una riga d'oro sull'acqua nera.",
			"domani chissà dove sarò.")
	var esito: Dictionary = GIU.scegli([stesso_inizio, altra], rit, {"sue": [vecchia]})
	t.eq(int(esito["scelta"]), 1, "non si comincia due volte con le stesse parole")
	t.ok(str((esito["schede"][0] as Dictionary)["perche"]).contains("il vento"),
			"e il motivo dice quali erano")
	# e la somiglianza da sola non l'avrebbe presa: è proprio l'incipit
	t.ok(GIU.somiglianza(vecchia, stesso_inizio, SUG.citazioni(rit)) < GIU.SOGLIA_GIA_DETTO,
			"la somiglianza, da sola, l'avrebbe lasciata passare")


## DUE LETTERE CHE CITANO LO STESSO FATTO NON SONO LA STESSA LETTERA. La
## citazione viene da una lista chiusa: se contasse nella somiglianza, la sera
## in cui succede una cosa sola il villaggio ammutolirebbe.
func _citare_lo_stesso_fatto_non_e_ripetersi(t) -> void:
	var rit := _banco()
	var cit: Array = SUG.citazioni(rit)
	var a := "%s\n%s\n%s" % ["il vento sussurra fra i rami alti.", str(cit[0]),
			"il silenzio si allunga sul legno."]
	var b := "%s\n%s\n%s" % ["una lucciola scrive d'oro sull'acqua nera.", str(cit[0]),
			"domani chissà dove sarò."]
	t.ok(GIU.somiglianza(a, b, cit) < GIU.SOGLIA_GIA_DETTO,
			"la citazione condivisa non fa somiglianza")
	t.eq(int(GIU.scegli([b], rit, {"sue": [a]})["scelta"]), 0,
			"e la seconda lettera esce lo stesso")


# =========================================================================
# IL SILENZIO
# =========================================================================

func _il_silenzio_e_un_esito(t) -> void:
	var rit := _banco()
	var bozze := [
		_lettera(rit, 0, "il vento muove le foglie.", "papavero mi ha detto una cosa."),
		_lettera(rit, 0, "il vento muove le foglie.", "ho visto come hai fissato il legno."),
		"non c'è nessuna citazione qui dentro.\ne nemmeno qui.",
	]
	var esito: Dictionary = GIU.scegli(bozze, rit)
	t.eq(int(esito["scelta"]), -1, "se sono tutte da buttare, non esce niente")
	t.eq(str(esito["testo"]), "", "e non esce nemmeno mezza lettera")
	t.ok(str(esito["motivo"]).contains("ancoraggio"),
			"e il motivo conta le porte, non racconta un aneddoto (%s)" % str(esito["motivo"]))


func _senza_bozze_non_si_inventa_niente(t) -> void:
	var rit := _banco()
	t.eq(int(GIU.scegli([], rit)["scelta"]), -1, "zero bozze, zero lettere")


# =========================================================================
# LE DEDUZIONI — l'altra materia
# =========================================================================

## Gli obiettivi che una deduzione può proporre sono quelli che il mondo sa
## fare: le quattro chiavi di `Piani.OBIETTIVO`, non una quinta scritta qui.
func _gli_obiettivi_della_deduzione_sono_quelli_del_mondo(t) -> void:
	var veri := {}
	for a in PIANI.OBIETTIVO:
		veri[str(PIANI.OBIETTIVO[a])] = true
	for ob in SUG.OBIETTIVI_DETTI:
		t.ok(veri.has(str(ob)), "«%s» è un obiettivo che il pianificatore conosce" % str(ob))
	t.eq(SUG.OBIETTIVI_DETTI.size(), veri.size(),
			"e sono tutti e soli quelli: né uno in più, né uno in meno")


func _una_deduzione_senza_ricevuta_non_passa(t) -> void:
	var rit := _banco()
	var mondo := {"fattibili": ["provvedi_cura", "provvedi_energia"], "gia_dedotto": []}
	var buona := {"obiettivo": "provvedi_cura", "perche": [0]}
	t.ok(bool(GIU.utile(buona, rit, mondo)["ok"]), "una deduzione con la sua ricevuta passa")

	var casi := [
		[{"obiettivo": "provvedi_cura", "perche": [0], "nota": "papavero ce l'ha con te"},
				"un campo libero dentro il JSON"],
		[{"obiettivo": "diventa_re", "perche": [0]}, "un obiettivo che non esiste"],
		[{"obiettivo": "provvedi_cura", "perche": []}, "nessun ricordo che la regga"],
		[{"obiettivo": "provvedi_cura"}, "nemmeno il campo dei ricordi"],
		[{"obiettivo": "provvedi_cura", "perche": [99]}, "un ricordo che non c'è"],
		[{"obiettivo": "provvedi_pancino", "perche": [0]}, "un obiettivo che il mondo non può darle"],
	]
	for c in casi:
		var esito: Dictionary = GIU.utile(c[0], rit, mondo)
		t.ok(not bool(esito["ok"]), "si boccia una deduzione con: %s" % str(c[1]))

	# quello che sta già facendo non è una deduzione: nessuna ricevuta
	var suo := _banco()
	suo["obiettivo"] = "provvedi_cura"
	t.ok(not bool(GIU.utile(buona, suo, mondo)["ok"]),
			"propone quello che sta già facendo: non cambia niente di visibile")
	# e nemmeno quello che aveva già dedotto ieri
	t.ok(not bool(GIU.utile(buona, rit,
			{"fattibili": ["provvedi_cura"], "gia_dedotto": ["provvedi_cura"]})["ok"]),
			"l'aveva già dedotto")


## Fra due deduzioni azionabili vince quella che sta in piedi meglio, e
## «meglio» è il suo ricordo più DEBOLE: così citare tutto non conviene.
func _la_catena_vale_il_suo_anello_piu_debole(t) -> void:
	var rit := _banco()
	var mondo := {"fattibili": ["provvedi_cura", "provvedi_energia"]}
	var gonfia := {"obiettivo": "provvedi_cura", "perche": [0, 1, 3]}   # pesi 2.4, 1.2, 0.4
	var solida := {"obiettivo": "provvedi_energia", "perche": [0, 1]}   # pesi 2.4, 1.2
	var esito: Dictionary = GIU.scegli_deduzione([gonfia, solida], rit, mondo)
	t.eq(int(esito["scelta"]), 1, "vince la catena senza l'anello debole")
	t.almost(float((esito["schede"][1] as Dictionary)["punti"]), 1.2,
			"e il punteggio è il peso del ricordo più debole", 0.001)
	t.eq(int(GIU.scegli_deduzione([], rit, mondo)["scelta"]), -1,
			"zero deduzioni, nessuna deduzione")
