extends RefCounted

## LE GUARDIE DELLA RIPRODUCIBILITÀ — i dadi nominati, le leve, e l'orologio
## che non deve tornare in posizione di seme.
##
## Il difetto che questo file sorveglia è costato la validità di TUTTE le
## misure psicologiche del progetto: due corse della stessa misura con gli
## stessi parametri davano 0,31 e 1,77 righe di co-presenza per residente,
## perché il dado di ogni vicino partiva dall'orologio
## (`VillagerBrain.setup`). Senza ripetizione non c'è ablazione, e senza
## ablazione un numero non è un risultato.
##
## ⚠️ Tre lezioni di banco sono cablate qui dentro, e vengono da guardie che
## in questo progetto erano già state pagate:
##
## 1. **si spogliano i commenti PRIMA di accusare** — e qui più che altrove,
##    perché la cura all'epicentro NOMINA la chiamata vietata per spiegare
##    cosa c'era prima. Una guardia che legge i commenti accusa chi ha già
##    curato il difetto. Lo spogliatore è quello di `test_fiato`, che è
##    l'unico che toglie anche i commenti in coda e rispetta le virgolette,
##    e si AUTOCOLLAUDA prima di essere creduto;
## 2. **si conta quanti file si sono davvero letti** — una guardia che per
##    un percorso sbagliato ne legge zero è verde (solo `test_cablaggio`
##    aveva questa riga);
## 3. **la proprietà che conta si prova COMPORTAMENTALMENTE**, non cercando
##    stringhe: un `contains()` resta verde anche svuotando la funzione.
##
## ────────────────────────────────────────────────────────────────────────
## ⚠️ LA SECONDA METÀ DEL FILE È NATA DA UNA REVISIONE AVVERSARIALE
## ────────────────────────────────────────────────────────────────────────
##
## Tre cure sono state consegnate SENZA una guardia — e in questo progetto
## vuol dire che non c'erano. Misurato: mutando `_radice_dal_salvataggio()`
## in `return null` — cioè spegnendo il ramo 2 di «DA DOVE VIENE LA RADICE» e
## riportando ogni villaggio a coniarsi una radice nuova a ogni avvio — la
## suite restava **completamente verde**. Le tre cure sono:
##
##  · la radice si legge dal villaggio (e dalla sua copia `.bak`);
##  · «Nuovo villaggio» la DIMENTICA, o il villaggio nuovo eredita gli
##    abitanti del vecchio (la PRIMA domanda della REGOLA SACRA: ricominciare
##    è il rimedio del giocatore, e un rimedio che gli ridà le stesse
##    identiche persone non rimedia);
##  · `CHIBI_ROTTE_CONTO` si valida, e un refuso non spegne le rotte.
##
## Queste guardie possono chiedere all'AMBIENTE, e non è un lusso: `Dadi`
## legge `CHIBI_SEME` e `CHIBI_VILLAGGIO` da `OS.get_environment`, e finché
## nessuno gliele muove il ramo del salvataggio non si attraversa mai. Godot
## 4.7 ha `OS.set_environment`/`unset_environment` (verificato dal vivo), e
## l'unica disciplina è **rendere l'ambiente com'era** — la suite gira in un
## processo solo, e un `CHIBI_VILLAGGIO` lasciato addosso farebbe lavorare i
## casi successivi su un villaggio che non è il loro.

const RADICI := ["res://scenes", "res://systems"]

## Il banco lavora QUI dentro, e da nessun'altra parte: vedi `_butta()`.
const CARTELLA := "user://prova_dadi"
const FINTO := CARTELLA + "/villaggio.json"


func run(t) -> void:
	_lo_spogliatore_sa_leggere(t)
	_una_chiave_da_lo_stesso_dado(t)
	_chiavi_diverse_dadi_diversi(t)
	_la_radice_cambia_tutto(t)
	_un_consumatore_in_piu_non_sposta_gli_altri(t)
	_la_radice_si_posa_e_si_dimentica(t)
	_il_canale_libero_e_dichiarato(t)
	_lorologio_non_semina_piu(t)
	_ogni_leva_ha_un_lettore(t)
	_ogni_lettore_usa_un_nome_dichiarato(t)
	_le_leve_partono_accese(t)
	_una_leva_sconosciuta_non_spegne_niente(t)
	_il_gioco_non_tocca_le_leve(t)
	_la_condizione_si_sa_dire(t)
	# la radice viene dal villaggio, e il villaggio ha una casa sola
	_la_strada_del_villaggio(t)
	_la_strada_del_villaggio_ha_una_casa_sola(t)
	_leggere_un_salvataggio_non_esplode(t)
	_la_radice_viene_dal_salvataggio(t)
	_due_villaggi_nuovi_non_si_somigliano(t)
	_la_regola_del_gesto_sa_fallire(t)
	_il_gesto_del_villaggio_nuovo_arriva_dopo_larchiviazione(t)
	# il flusso globale, e le due leve d'ambiente che restano
	_il_flusso_globale_ha_una_posizione_sola(t)
	_il_tetto_delle_rotte_si_valida(t)
	_loracolo_dellablazione_si_puo_chiedere(t)


# ────────────────────────────────────────────────────────── i dadi

func _una_chiave_da_lo_stesso_dado(t) -> void:
	Dadi.posa_radice(4242)
	var a := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	var b := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	t.eq(a, b, "lo stesso (flusso, chiave, radice) dà la stessa vita")


func _chiavi_diverse_dadi_diversi(t) -> void:
	Dadi.posa_radice(4242)
	var a := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	var b := _tira(Dadi.rng(Dadi.VILLAGGIO, "Nocciola"), 8)
	t.ok(a != b, "due vicini non tirano gli stessi numeri")
	var c := _tira(Dadi.rng(Dadi.AMBIENTE, "Ciliegia"), 8)
	t.ok(a != c, "…e nemmeno lo stesso nome in due flussi diversi")


func _la_radice_cambia_tutto(t) -> void:
	Dadi.posa_radice(1)
	var a := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	Dadi.posa_radice(2)
	var b := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	t.ok(a != b, "cambiare radice cambia la partita")
	Dadi.posa_radice(1)
	var c := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	t.eq(a, c, "…e tornare alla radice di prima la ridà identica")


## ⭐ LA PROPRIETÀ CHE TIENE IN PIEDI TUTTO IL LAVORO, e l'unica che si
## perderebbe «ottimizzando» i dadi in un flusso condiviso.
##
## Con un generatore per flusso, aggiungere un chiamante sposta tutti i
## numeri a valle: spegnere un meccanismo per misurarlo cambierebbe anche
## tutti gli altri, e il banco delle repliche direbbe numeri che non vogliono
## dire niente. Qui si dimostra il contrario: B non si accorge di A.
func _un_consumatore_in_piu_non_sposta_gli_altri(t) -> void:
	Dadi.posa_radice(4242)
	var prima := _tira(Dadi.rng(Dadi.VILLAGGIO, "B"), 6)
	# adesso arriva un consumatore nuovo, e ne tira cento
	var nuovo := Dadi.rng(Dadi.VILLAGGIO, "A")
	for i in 100:
		nuovo.randf()
	var dopo := _tira(Dadi.rng(Dadi.VILLAGGIO, "B"), 6)
	t.eq(prima, dopo,
			"un consumatore in più non sposta di un bit la vita degli altri")


func _la_radice_si_posa_e_si_dimentica(t) -> void:
	Dadi.posa_radice(7)
	t.eq(Dadi.radice(), 7, "la radice posata è quella che si legge")
	t.ok(Dadi.radice_posata(), "e il modulo sa che qualcuno l'ha posata")
	Dadi.posa_radice(0)
	t.eq(Dadi.radice(), 0, "zero è una radice legittima, non «nessuna»")
	t.ok(Dadi.radice_posata(), "…e non va scambiata per «non ancora deciso»")
	Dadi.dimentica()
	t.ok(not Dadi.radice_posata(), "dimentica() rimette il modulo com'era")
	# e senza nessuno che l'abbia posata se ne conia una: il degrado va verso
	# «il gioco funziona», mai verso «tutti i villaggi nascono identici».
	var coniata := Dadi.radice()
	t.ok(Dadi.radice_posata(), "chiederla la conia")
	t.eq(Dadi.radice(), coniata, "…e da lì in poi è ferma")
	Dadi.posa_radice(4242)


func _il_canale_libero_e_dichiarato(t) -> void:
	t.ok(Dadi.FLUSSI.has(Dadi.LIBERO),
			"il canale cosmetico è DICHIARATO, non sottinteso")
	t.eq(Dadi.FLUSSI.size(), 4, "i flussi sono quattro e si contano")
	# il libero non è seminato, ed è tutta la sua definizione
	Dadi.posa_radice(4242)
	var a := _tira(Dadi.libero(), 6)
	var b := _tira(Dadi.libero(), 6)
	t.ok(a != b, "il canale libero NON è riproducibile, ed è la sua natura")


# ─────────────────────────────────────────── l'orologio in posizione di seme

## Le sorgenti che non devono mai finire dentro un seme. Non è un divieto
## generico: `Time.get_ticks_usec()` cronometra (ed è giusto), e
## `get_instance_id()` fa da chiave a dei dizionari (ed è giusto). Quello che
## non si può fare è **seminarci un dado**, e la guardia guarda la RIGA:
## deve contenere insieme una di queste e un'assegnazione di seme.
const VIETATE := ["get_ticks_msec", "get_ticks_usec", "get_unix_time_from_system",
		"get_instance_id", "randomize()"]


func _lorologio_non_semina_piu(t) -> void:
	var colpevoli: Array = []
	var visti := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			visti += 1
			# ⚠️ L'UNICA ESENZIONE, ed è la definizione stessa del modulo:
			# `Dadi.conia()` e `Dadi.libero()` SONO l'entropia autorizzata di
			# questo progetto. Esentare il file è il modo di dire che è UNO,
			# e che si vede: chiunque altro chieda entropia vera compare in
			# questo elenco.
			if path.ends_with("/Dadi.gd"):
				continue
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			var n := 0
			for riga in src.split("\n"):
				n += 1
				if not _e_una_seminatura(riga):
					continue
				for cattiva in VIETATE:
					if riga.contains(cattiva):
						colpevoli.append("%s:%d (%s)"
								% [path.get_file(), n, cattiva])
	# la soglia è sotto il numero vero (140 file al 2026-09-04): serve a
	# beccare uno scandaglio che per un percorso sbagliato legge zero file e
	# passa in silenzio — è la riga di sanità che solo `test_cablaggio` aveva.
	t.ok(visti >= 120,
			"lo scandaglio ha davvero letto i sorgenti (%d file)" % visti)
	t.eq(colpevoli.size(), 0,
			"nessun dado seminato dall'orologio o da un indirizzo: %s"
			% ", ".join(colpevoli))


## Una riga è una seminatura se ci si scrive dentro un seme. `randomize()` è
## una seminatura per definizione — è la sua unica funzione.
static func _e_una_seminatura(riga: String) -> bool:
	if riga.contains("randomize()"):
		return true
	return riga.contains(".seed") or riga.contains("seed(") \
			or riga.contains(".state")


func _lo_spogliatore_sa_leggere(t) -> void:
	t.ok(_senza_commenti("var x = 1  # randomize() qui è solo una parola")
			.find("randomize") < 0,
			"la guardia non accusa un commento in CODA")
	t.ok(_senza_commenti("# _rng.seed = Time.get_ticks_msec()")
			.find("get_ticks") < 0,
			"…né una riga interamente di commento")
	t.ok(_senza_commenti("\t_rng.seed = Time.get_ticks_msec()")
			.find("get_ticks") >= 0,
			"…ma vede il codice vero")
	t.ok(_senza_commenti("var s := \"# non è un commento\"")
			.find("non è un commento") >= 0,
			"…e non si fa ingannare da un cancelletto fra virgolette")
	t.ok(_e_una_seminatura("\t_rng.seed = 3"), "riconosce una seminatura")
	t.ok(not _e_una_seminatura("\tvar t := Time.get_ticks_usec()"),
			"…e lascia in pace un cronometro")


# ────────────────────────────────────────────────────────────── le leve

func _le_leve_partono_accese(t) -> void:
	Leve.dimentica()
	for nome in Leve.MECCANISMI:
		t.ok(Leve.acceso(str(nome)),
				"di serie «%s» è acceso: una leva è uno strumento di misura,"
				% nome + " non una configurazione")
	t.ok(Leve.spente().is_empty(), "e non ce n'è nessuna spenta")


func _una_leva_sconosciuta_non_spegne_niente(t) -> void:
	Leve.dimentica()
	t.ok(Leve.acceso("non_esiste_questa"),
			"un nome sconosciuto resta ACCESO: spegnere per un errore di"
			+ " battitura è il guasto che si legge come un risultato")
	Leve.spegni("non_esiste_questa")
	t.ok(Leve.spente().is_empty(), "…e non si può nemmeno spegnere")


func _la_condizione_si_sa_dire(t) -> void:
	Leve.dimentica()
	t.eq(Leve.condizione(), "tutto", "la condizione di controllo ha un nome")
	Leve.spegni(Leve.INSIEME)
	t.ok(not Leve.acceso(Leve.INSIEME), "spegnere spegne")
	t.eq(Leve.condizione(), "senza:insieme", "…e si sa dire in una parola")
	Leve.spegni(Leve.DERIVA)
	t.eq(Leve.condizione(), "senza:deriva+insieme",
			"due leve spente si dicono in ordine, o due referti della stessa"
			+ " condizione non si riconoscerebbero")
	Leve.accendi(Leve.INSIEME)
	t.ok(Leve.acceso(Leve.INSIEME), "e si riaccende")
	Leve.dimentica()


## ⚠️ UNA LEVA SENZA LETTORE È UNA PROMESSA VUOTA: il banco la spegne, non
## succede niente, e il referto si legge come «quel meccanismo non conta».
func _ogni_leva_ha_un_lettore(t) -> void:
	var sorgenti := _tutta_la_roba()
	for nome in Leve.MECCANISMI:
		# la costante è il nome in maiuscolo: è un'invariante, non una
		# comodità — è ciò che rende possibile risalire dal sorgente al
		# registro senza chiedere al modulo di riflettere su sé stesso.
		var costante := str(nome).to_upper()
		var letta := sorgenti.contains("Leve.acceso(Leve.%s)" % costante)
		t.ok(letta, "la leva «%s» ha almeno un lettore nel gioco" % nome)


## …e il verso opposto: un nome non dichiarato non fallisce da nessuna parte,
## smette solo di spegnere qualcosa.
func _ogni_lettore_usa_un_nome_dichiarato(t) -> void:
	var fuori: Array = []
	var letture := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			var da := 0
			while true:
				var i := src.find("Leve.acceso(", da)
				if i < 0:
					break
				letture += 1
				da = i + 12
				var j := src.find(")", i)
				var arg := src.substr(i + 12, maxi(0, j - i - 12)).strip_edges()
				if not arg.begins_with("Leve."):
					fuori.append("%s: %s" % [path.get_file(), arg])
					continue
				var costante := arg.substr(5)
				if not Leve.MECCANISMI.has(costante.to_lower()):
					fuori.append("%s: %s" % [path.get_file(), arg])
	t.ok(letture >= 4, "lo scandaglio ha trovato le letture (%d)" % letture)
	t.eq(fuori.size(), 0,
			"ogni lettura di una leva usa una costante dichiarata: %s"
			% ", ".join(fuori))


## Le SCRITTURE che nel gioco non fa nessuno: le leve si muovono da
## `CHIBI_LEVE` o da un banco, e la radice ha dei proprietari dichiarati.
## È la stessa guardia che `test_regia` fa su `debug_occlusione`, e cerca la
## SCRITTURA, mai la parola nuda.
const SCRITTURE := ["Leve.spegni(", "Leve.accendi(", "Leve.dimentica(",
		"Dadi.posa_radice(", "Dadi.dimentica("]

## ⚠️ L'ELENCO DEI PROPRIETARI, e ce n'è UNO SOLO. C'era anche
## «BuildSystem.gd → Dadi.posa_radice(», ed era un'ECCEZIONE MORTA: quella
## chiamata è stata tolta quando `Dadi.radice()` ha imparato a leggersi il
## seme da sé (il caricamento è `call_deferred`, e posare la radice lì
## arrivava sempre dopo il primo dado). Un'eccezione che non protegge più
## niente non è innocua: è un lasciapassare — chi un domani «rimettesse il
## seme del salvataggio dove stava» riaprirebbe in silenzio il difetto
## dell'ordine differito, con la suite verde. Per questo `_ne_troppi_ne_morti`
## guarda anche il verso opposto.
const AMMESSI_SCRITTURE := ["TitleScreen.gd → Dadi.dimentica("]


func _il_gioco_non_tocca_le_leve(t) -> void:
	var trovati: Array = []
	var visti := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			visti += 1
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			for scrittura in SCRITTURE:
				if src.contains(scrittura):
					trovati.append("%s → %s" % [path.get_file(), scrittura])
	t.ok(visti >= 120,
			"lo scandaglio delle scritture ha letto i sorgenti (%d file)" % visti)
	_ne_troppi_ne_morti(t, "nel gioco nessuno spegne una leva né tocca la radice",
			trovati, AMMESSI_SCRITTURE)
	# MUTAZIONE: rimettere `Dadi.posa_radice(` in BuildSystem._load_village
	#   → 1 rossa (la prima metà: c'è un colpevole non ammesso).
	# MUTAZIONE: togliere `Dadi.dimentica()` da TitleScreen._start_new
	#   → 1 rossa (la seconda metà: l'eccezione è rimasta senza la sua
	#     chiamata), più quella di `_il_gesto_del_villaggio_nuovo…`.


# ────────────────────────────────── la strada del villaggio, e la sua radice

## ⚠️ CHI DECIDE DOVE VIVE IL VILLAGGIO È UNO SOLO, ed è `Dadi`. Non è
## simmetria: `Dadi.radice()` deve poter leggere il seme PRIMA che
## BuildSystem esista, quindi la strada sta di là e `BuildSystem.save_path` la
## prende di lì. Una seconda copia scritta a mano (`TitleScreen` ne aveva una,
## `const SAVE_PATH`) diverge appena qualcuno passa `CHIBI_VILLAGGIO`: il menù
## archiviava un villaggio e `Dadi` ne rileggeva un altro — cioè la
## dimenticanza del villaggio nuovo non funzionava proprio nel banco che la
## stava provando.
##
## L'unica altra apparizione ammessa è il valore di SERIE di
## `RiassuntoSalvataggio.dal_disco()`, che oggi nessun chiamante usa (l'unico,
## `TitleScreen`, passa `Dadi.percorso_villaggio()`): è un'eccezione che non
## costa niente, e se un domani quel valore di serie sparisce l'elenco deve
## accorciarsi — ci pensa `_ne_troppi_ne_morti`.
const AMMESSI_STRADA := ["Dadi.gd", "RiassuntoSalvataggio.gd"]


func _la_strada_del_villaggio(t) -> void:
	var era_c := OS.has_environment("CHIBI_VILLAGGIO")
	var era := OS.get_environment("CHIBI_VILLAGGIO")
	OS.set_environment("CHIBI_VILLAGGIO", "")
	t.eq(Dadi.percorso_villaggio(), "user://village.json",
			"senza ambiente il villaggio sta dove è sempre stato")
	OS.set_environment("CHIBI_VILLAGGIO", FINTO)
	t.eq(Dadi.percorso_villaggio(), FINTO,
			"…e CHIBI_VILLAGGIO lo sposta: è la sola ragione per cui un banco"
			+ " può lavorare senza toccare il villaggio dell'autore")
	if era_c:
		OS.set_environment("CHIBI_VILLAGGIO", era)
	else:
		OS.unset_environment("CHIBI_VILLAGGIO")
	# MUTAZIONE: `percorso_villaggio()` che torna la costante ignorando
	#   l'ambiente → 1 rossa. E in partita non si vedrebbe nulla: si vedrebbe
	#   che ogni banco lavora sul `village.json` vero.


func _la_strada_del_villaggio_ha_una_casa_sola(t) -> void:
	var trovati: Array = []
	var visti := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			visti += 1
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			if src.contains("\"user://village.json\""):
				trovati.append(path.get_file())
	t.ok(visti >= 120,
			"lo scandaglio della strada ha letto i sorgenti (%d file)" % visti)
	_ne_troppi_ne_morti(t, "la strada del villaggio è scritta in un posto solo",
			trovati, AMMESSI_STRADA)
	# MUTAZIONE: rimettere `const SAVE_PATH := "user://village.json"` in
	#   TitleScreen → 1 rossa.


## Il salvataggio letto da `Dadi`: quello che conta è che **non esploda**, e
## che un file che non è un salvataggio valga quanto un file che non c'è. Il
## ramo del `.bak` esiste apposta per il file TRONCATO — cioè per il giorno in
## cui il disco ha fatto i capricci — e un parser che ci si strozza sopra
## porterebbe via la radice proprio lì.
func _leggere_un_salvataggio_non_esplode(t) -> void:
	var prima := _presta_il_mondo()
	t.eq(Dadi.leggi_salvataggio(CARTELLA + "/non_esiste_proprio.json"), null,
			"un file che non c'è vale null")
	_scrivi(FINTO, "{ questo non è json")
	t.eq(Dadi.leggi_salvataggio(FINTO), null,
			"un file troncato vale null, e non porta via niente con sé")
	_scrivi(FINTO, "[1, 2, 3]")
	t.eq(Dadi.leggi_salvataggio(FINTO), null,
			"un JSON valido che non è un salvataggio vale null: un Array non"
			+ " ha chiavi, e chiedergliene una è l'errore a runtime che"
			+ " interrompe la funzione e lascia la suite verde")
	_scrivi(FINTO, "{\"seme\": \"9\", \"pieces\": []}")
	var d = Dadi.leggi_salvataggio(FINTO)
	t.ok(d is Dictionary and (d as Dictionary).has("seme"),
			"…e un salvataggio vero si legge")
	_rendi_il_mondo(prima)
	# MUTAZIONE: `leggi_salvataggio` che torna `d` invece di
	#   `d if d is Dictionary else null` → 1 rossa (l'Array passa).


## ⭐ IL RAMO 2 DI «DA DOVE VIENE LA RADICE», e prima di questo caso non lo
## provava nessuno: mutando `_radice_dal_salvataggio()` in `return null` la
## suite restava completamente verde, mentre nel gioco ogni villaggio si
## coniava una radice nuova a ogni avvio — cioè la partita di chi gioca non
## era più ripetibile con sé stessa, che è la sola ragione per cui quel ramo
## esiste (diagnosticare un difetto segnalato da chi gioca).
##
## I sei casi sono le sei risposte possibili, e le tre asimmetrie fra loro
## sono la parte che si sbaglia:
##  · il file che MANCA è un villaggio NUOVO → si conia, e il `.bak` non si
##    guarda nemmeno (guardarlo RESUSCITEREBBE la radice del villaggio
##    archiviato: di là erano case e residenti, di qua un numero solo, e
##    quindi ancora più muto);
##  · il file che c'è ma è ILLEGGIBILE è il disco che ha fatto i capricci →
##    la copia vale, con la stessa disciplina di `BuildSystem._load_village`;
##  · il file che si legge e TACE è un salvataggio anteriore a questa
##    versione → si conia, e non si va a cercare nel `.bak` una chiave che
##    quel villaggio non ha.
##
## ⚠️ Questo caso STAMPA degli errori, e non sono un guasto: i file sono rotti
## apposta, quindi `JSON.parse_string` si lamenta (quattro «Parse JSON
## failed») e `Dadi` dice «la radice viene dalla copia .bak». Quella riga è
## anzi la conferma che il ramo del `.bak` è stato attraversato davvero. Chi
## conta il rumore della suite conti i `SCRIPT ERROR`, che qui sono zero.
func _la_radice_viene_dal_salvataggio(t) -> void:
	var prima := _presta_il_mondo()

	# 1. il file c'è e porta la sua radice (la forma che scrive BuildSystem:
	#    il seme viaggia come STRINGA, perché dal JSON ogni numero torna float)
	_scrivi(FINTO, "{\"seme\": \"424242\"}")
	Dadi.dimentica()
	t.eq(Dadi.radice(), 424242, "la radice viene dal villaggio salvato")

	# 2. il file manca: è un villaggio nuovo, e se ne conia una
	_butta(FINTO)
	Dadi.dimentica()
	var coniata := Dadi.radice()
	t.ok(coniata != 424242,
			"un villaggio nuovo non eredita la radice di quello archiviato")

	# 3. il file c'è ed è illeggibile, la copia è buona: vale la copia
	_scrivi(FINTO, "{ tronc")
	_scrivi(FINTO + ".bak", "{\"seme\": \"777\"}")
	Dadi.dimentica()
	t.eq(Dadi.radice(), 777,
			"un village.json troncato non porta via il seme: lo tiene il .bak")

	# 4. tutte e due rotte: si conia, e il gioco continua
	_scrivi(FINTO + ".bak", "nemmeno questo è json")
	Dadi.dimentica()
	t.ok(Dadi.radice() != 777,
			"e se è rotta anche la copia si conia: il degrado va verso «il"
			+ " gioco funziona»")

	# 5. il file si legge ma TACE: la sua parola è definitiva anche così
	_scrivi(FINTO, "{\"pieces\": []}")
	_scrivi(FINTO + ".bak", "{\"seme\": \"555\"}")
	Dadi.dimentica()
	t.ok(Dadi.radice() != 555,
			"un salvataggio senza «seme» è anteriore a questa versione: si"
			+ " conia, e non si ripesca dal .bak una chiave che non ha")

	# 6. il file manca e la copia c'è: nessuna RESURREZIONE
	_butta(FINTO)
	Dadi.dimentica()
	t.ok(Dadi.radice() != 555,
			"un .bak rimasto indietro non resuscita la radice del villaggio"
			+ " archiviato")

	_rendi_il_mondo(prima)
	# MUTAZIONE: `_radice_dal_salvataggio()` → `return null`  → 2 rosse (1, 3).
	# MUTAZIONE: togliere il ripiego sul `.bak`                → 1 rossa (3).
	# MUTAZIONE: guardare il `.bak` anche quando il file MANCA → 1 rossa (6).
	# MUTAZIONE: guardare il `.bak` quando il file TACE        → 1 rossa (5).


## ⭐ LA PRIMA DOMANDA DELLA REGOLA SACRA: **il giocatore può rimediare?**
## «Nuovo villaggio» è il rimedio, e un rimedio che gli ridà le stesse
## identiche persone — stessi nomi nello stesso ordine, stesso manto, stessi
## tratti, perché `ChibiDNA` e `FaceController` derivano dalla radice — non
## rimedia niente.
##
## Qui si cammina il gesto vero a pezzi, e le due metà sbagliate si asseriscono
## anche loro: sono la ragione per cui `Dadi.dimentica()` sta DOVE sta.
func _due_villaggi_nuovi_non_si_somigliano(t) -> void:
	var prima := _presta_il_mondo()

	# la partita in corso: il villaggio sul disco, e la sua radice già in mano
	# al modulo — è quello che succede nel menù, dove il diorama costruisce
	# Mochi e il `setup` del volto chiede un dado prima di ogni altra cosa.
	_scrivi(FINTO, "{\"seme\": \"31337\"}")
	Dadi.dimentica()
	t.eq(Dadi.radice(), 31337, "la partita in corso ha la sua radice")

	# il gesto giusto: si archivia (il .json E il .bak), poi si dimentica
	_butta(FINTO)
	_butta(FINTO + ".bak")
	Dadi.dimentica()
	t.ok(Dadi.radice() != 31337,
			"dopo «Nuovo villaggio» la radice è un'altra: due villaggi non si"
			+ " somigliano, ed è la promessa scritta in Dadi")

	# ⚠️ la prima metà sbagliata: ARCHIVIARE NON BASTA. Una `static var`
	# sopravvive al cambio di scena, e la radice era già in mano al modulo
	# prima che il file se ne andasse — `_save_village` la riscriveva pari
	# pari dentro il villaggio nuovo.
	_scrivi(FINTO, "{\"seme\": \"31337\"}")
	Dadi.dimentica()
	Dadi.radice()
	_butta(FINTO)
	t.eq(Dadi.radice(), 31337,
			"archiviare senza dimenticare non cambia niente: la radice è già"
			+ " posata, e un cambio di scena non azzera una static var")

	# ⚠️ la seconda metà sbagliata: DIMENTICARE PRIMA non basta, perché il
	# seme è ancora sul disco e la prossima domanda se lo riprende. È il
	# motivo per cui l'ordine dentro `_start_new` è sorvegliato a parte.
	Dadi.dimentica()
	_scrivi(FINTO, "{\"seme\": \"31337\"}")
	t.eq(Dadi.radice(), 31337,
			"e dimenticarla PRIMA di archiviare non serve: il seme è ancora"
			+ " sul disco, e Dadi se lo rilegge")

	_rendi_il_mondo(prima)
	# MUTAZIONE: `dimentica()` che non azzera `_posata` → 1 rossa (la seconda
	#   asserzione: la radice del vecchio villaggio sopravvive).


## Il cablaggio del gesto, e il suo POSTO. La parte comportamentale sta nel
## caso qui sopra; questa è la sola riga che lega quel comportamento a
## `_start_new`, ed è un source-check per una ragione dichiarata: la funzione
## vera non si può far girare da un test — archivia `foto_ricordi.json` e
## `sentieri_consumati.png`, SVUOTA `user://ricordi/` e cambia scena, e niente
## di tutto questo passa da `CHIBI_VILLAGGIO`. Farla girare qui vorrebbe dire
## portare via l'album del timelapse dell'autore, che è la lezione già pagata
## da un altro banco (`test_offerta_modello` si è portato via due gigabyte).
##
## ⚠️ E non basta che la chiamata CI SIA: deve stare **dopo** l'archiviazione
## del `.bak`. Messa prima, `Dadi.radice()` ritroverebbe il seme sul disco —
## il caso qui sopra lo asserisce — e il gesto sarebbe verde e inutile.
func _il_gesto_del_villaggio_nuovo_arriva_dopo_larchiviazione(t) -> void:
	var corpo := _senza_commenti(
			_corpo("res://scenes/ui/TitleScreen.gd", "_start_new"))
	t.ok(corpo.length() > 200,
			"il corpo di _start_new si legge (%d caratteri)" % corpo.length())
	t.eq(_ordine_del_gesto(corpo), "ok",
			"«Nuovo villaggio» dimentica la radice, e DOPO aver archiviato")
	# MUTAZIONE: togliere `Dadi.dimentica()` da _start_new → 1 rossa (qui) più
	#   quella dell'eccezione morta.
	# MUTAZIONE: spostarla in cima alla funzione → 1 rossa.


## ⚠️ E LA REGOLA SI COLLAUDA SU CORPI FABBRICATI, prima di essere creduta.
## Una guardia di POSIZIONE che non si sa far fallire è un'affermazione, non
## una guardia — ed è l'unico modo di falsificarla senza andare a guastare
## `TitleScreen.gd`, che è di un altro. È l'idioma di
## `_lo_spogliatore_sa_leggere`, applicato a un ordine invece che a un taglio.
func _la_regola_del_gesto_sa_fallire(t) -> void:
	t.eq(_ordine_del_gesto("rename(v + \".bak\")\nDadi.dimentica()"), "ok",
			"riconosce il gesto giusto")
	t.eq(_ordine_del_gesto("Dadi.dimentica()\nrename(v + \".bak\")"),
			"dimentica PRIMA di archiviare",
			"…e la metà sbagliata che lascia il seme sul disco")
	t.eq(_ordine_del_gesto("rename(v + \".bak\")"),
			"non dimentica la radice",
			"…e il gesto che manca del tutto")
	t.eq(_ordine_del_gesto("Dadi.dimentica()"),
			"non archivia la copia .bak",
			"…e la copia lasciata indietro, che resuscita il villaggio vecchio")


## Il giudizio sul corpo di `_start_new`, isolato in una funzione PURA perché
## si possa collaudare (vedi il caso qui sopra). Torna «ok» o il nome del
## guasto: un messaggio che dice COSA è storto vale i venti minuti che
## risparmia a chi lo legge.
static func _ordine_del_gesto(corpo: String) -> String:
	var quando := corpo.find("Dadi.dimentica(")
	var bak := corpo.find(".bak")
	if quando < 0:
		return "non dimentica la radice"
	if bak < 0:
		return "non archivia la copia .bak"
	return "ok" if quando > bak else "dimentica PRIMA di archiviare"


# ─────────────────────────────────────────────────────── il flusso globale

## ⚠️ IL FLUSSO GLOBALE NON È UN FLUSSO NOMINATO: è il generatore condiviso
## del motore, quello che risponde a `randf()` senza istanza, e lo consuma
## anche il C++ (`update_butterflies` ne prende due per farfalla per passo di
## fisica). Non gli si dà una casa: gli si dà UNA posizione, e una sola.
##
## Ce n'erano tre, e tutte e tre «per sicurezza»: `CozyWorld._ready`,
## `BuildSystem._ready` e `BuildSystem._load_village`. Le due di BuildSystem
## cadevano **in mezzo** alla generazione del mondo — la coroutine di
## `CozyWorld._ready` cede il controllo per sette fotogrammi, e il
## caricamento del villaggio sta tutto dentro il frame 0 — quindi
## riposizionavano il flusso fra l'erba e gli alberi: la promessa «così quel
## che viene dopo non dipende da quanti tiri ha fatto la generazione» valeva
## esattamente al contrario.
func _il_flusso_globale_ha_una_posizione_sola(t) -> void:
	var siti: Array = []
	var visti := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			visti += 1
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			var da := 0
			while true:
				var i := src.find("Dadi.semina_globale(", da)
				if i < 0:
					break
				da = i + 1
				siti.append(path.get_file())
	t.ok(visti >= 120,
			"lo scandaglio del flusso globale ha letto i sorgenti (%d file)"
			% visti)
	t.eq(", ".join(siti), "CozyWorld.gd",
			"il flusso globale riceve una posizione UNA volta sola, e la dà il"
			+ " suo primo consumatore")

	# e la posizione dipende davvero dalla radice: senza questa metà, la riga
	# qui sopra resterebbe verde anche con un `semina_globale()` svuotato.
	Dadi.posa_radice(101)
	Dadi.semina_globale()
	var a := _tira_globale(6)
	Dadi.posa_radice(202)
	Dadi.semina_globale()
	var b := _tira_globale(6)
	Dadi.posa_radice(101)
	Dadi.semina_globale()
	var c := _tira_globale(6)
	t.ok(a != b, "due radici diverse mettono il flusso globale in due punti")
	t.eq(a, c, "…e la stessa radice lo rimette dov'era")
	# ⚠️ E SI RENDE COM'ERA. Il flusso globale è del processo, non di questo
	# caso: lasciarlo fermo su 101 renderebbe deterministico ogni `randf()`
	# dei casi che vengono dopo — non più fragile, ma diverso da come gira in
	# partita, e un banco non deve cambiare il mondo che misura. (Questo
	# `randomize()` è in `tests/`, che lo scandaglio dell'orologio non guarda:
	# lì è vietato SEMINARE un dado, non rendere il caso al processo.)
	randomize()
	Dadi.posa_radice(4242)
	# MUTAZIONE: rimettere `Dadi.semina_globale()` in BuildSystem._ready
	#   → 1 rossa (due siti).
	# MUTAZIONE: `semina_globale()` che non chiama `seed()` → 1 rossa (a == b).


# ──────────────────────────────────────────── le altre leve d'ambiente

## ⚠️ IL VERSO DEL GUASTO ERA QUELLO PERICOLOSO. `int("sei")` in GDScript è
## **zero**, e uno zero lì non voleva dire «nessun tetto»: voleva dire
## `_turno_domande < 0`, cioè turno chiuso per sempre. Nessuna `deviazione`
## veniva più calcolata, ogni corpo ripiegava sulla retta e camminava dritto
## attraverso staccionate e recinti — e un banco misurava chi incontra chi in
## un villaggio che non esiste, **senza un messaggio**.
##
## Il degrado va dove va sempre: qualunque cosa storta ripiega sul CRONOMETRO,
## cioè su quello che il gioco fa quando la variabile non c'è. Gli errori che
## questo caso stampa non sono rumore: sono la metà del rimedio — un
## validatore che tace è indistinguibile da uno che non c'è.
func _il_tetto_delle_rotte_si_valida(t) -> void:
	var era_c := OS.has_environment("CHIBI_ROTTE_CONTO")
	var era := OS.get_environment("CHIBI_ROTTE_CONTO")
	for storto in ["sei", "0", "-3", "0x1F", "1.5"]:
		OS.set_environment("CHIBI_ROTTE_CONTO", storto)
		t.eq(BuildSystem._leggi_conto_rotte(), -1,
				"«%s» non è un tetto: resta il cronometro" % storto)
	OS.set_environment("CHIBI_ROTTE_CONTO", "")
	t.eq(BuildSystem._leggi_conto_rotte(), -1,
			"e senza la variabile il gioco fa quello che ha sempre fatto")
	OS.set_environment("CHIBI_ROTTE_CONTO", "1")
	t.eq(BuildSystem._leggi_conto_rotte(), 1,
			"uno è il tetto vero del banco: una domanda cara per fotogramma")
	OS.set_environment("CHIBI_ROTTE_CONTO", "  2  ")
	t.eq(BuildSystem._leggi_conto_rotte(), 2,
			"…e uno spazio in coda non è una richiesta diversa: questa"
			+ " variabile la scrivono degli script di shell")
	if era_c:
		OS.set_environment("CHIBI_ROTTE_CONTO", era)
	else:
		OS.unset_environment("CHIBI_ROTTE_CONTO")
	# MUTAZIONE: tornare a `int(e) if e != "" else -1` → 3 rosse («sei» dà 0,
	#   «0» dà 0, «0x1F» dà 1 — e lo zero è il turno chiuso per sempre).
	# MUTAZIONE: togliere `strip_edges()` → 1 rossa («  2  »).
	# MUTAZIONE: accettare lo zero (`< 1` → `< 0`) → 1 rossa.


## ⚠️ L'ORACOLO DELL'ABLAZIONE, e qui si sorveglia solo che si POSSA chiedere.
##
## `misura_insieme` pubblica «il fatto si SAREBBE acceso», e per un pezzo
## quel numero era il valore ABLATO invece del controfattuale: a leva spenta
## `_seduta_da` esce alla prima riga senza guardare chi c'è già seduto, quindi
## la panca che si osservava non era «quella che avrei scelto a leva accesa»
## ma «quella che avrei scelto comunque». Il referto ne stampava la
## conclusione OPPOSTA a quella vera — chi leggeva «non si sarebbe acceso
## quasi mai» concludeva «non ne avrebbe avuto occasione», mentre l'occasione
## c'era. Un oracolo che mente è peggio di nessun oracolo: nessun oracolo ti
## fa misurare, uno che mente ti fa credere di aver già misurato.
##
## La cura è il parametro `come_se_accesa`, che scavalca la leva NEL POSTO in
## cui il lavoro si salta. Due cose lo tengono:
##  · il parametro ESISTE su tutti e due i gradini (si legge dalla firma
##    compilata, non dal testo: se qualcuno lo toglie, questo caso arrossisce
##    prima ancora che `misura_insieme` menta di nuovo);
##  · e i quattro anelli lo passano TUTTI. Decorativo su tre anelli su quattro
##    darebbe un oracolo giusto solo per chi si siede vicino a Mochi.
func _loracolo_dellablazione_si_puo_chiedere(t) -> void:
	var vis := load("res://scenes/npc/Visitors.gd") as GDScript
	t.ok(vis != null, "Visitors si carica")
	t.eq(_argomenti(vis, "_seduta_da"), ["ancora", "chiede", "come_se_accesa"],
			"la leva si scavalca dove il lavoro si salta")
	t.eq(_argomenti(vis, "_panchina_per"), ["r", "home", "come_se_accesa"],
			"…e il gradino sopra sa passarglielo")
	var corpo := _senza_commenti(
			_corpo("res://scenes/npc/Visitors.gd", "_panchina_per"))
	var anelli := corpo.count("_seduta_da(")
	t.ok(anelli >= 4,
			"i quattro anelli di _panchina_per ci sono ancora (%d)" % anelli)
	t.eq(corpo.count("come_se_accesa)"), anelli,
			"…e il controfattuale arriva a tutti: un anello che se lo dimentica"
			+ " dà un oracolo vero solo per chi passa di lì")
	# MUTAZIONE: togliere `come_se_accesa` da `_seduta_da` → 2 rosse.
	# MUTAZIONE: non passarlo a uno dei quattro anelli     → 1 rossa.
	# ⚠️ QUESTO CASO NON PROVA CHE `insieme_osservato` SIA IL CONTROFATTUALE:
	#   quello vuole il fixture di `test_insieme` (un villaggio con due sedute
	#   nello stesso anello, la più vicina libera e sola, la più lontana con
	#   qualcuno accanto) e sta scritto lì. Qui si tiene aperta la STRADA, non
	#   si giudica il numero.


# ─────────────────────────────────────────────────────────────── ferri

static func _tira(g: RandomNumberGenerator, n: int) -> Array:
	var v: Array = []
	for i in n:
		v.append(g.randf())
	return v


static func _tira_globale(n: int) -> Array:
	var v: Array = []
	for i in n:
		v.append(randf())
	return v


## Le DUE direzioni di un elenco di eccezioni, in un ferro solo perché le
## sbaglia sempre la stessa persona: si guarda che non ci sia nessun colpevole
## fuori elenco, **e** che nessuna voce dell'elenco sia rimasta senza la sua
## chiamata. Un'eccezione morta non è innocua: è un lasciapassare intestato a
## un gesto che oggi è vietato, e la suite resta verde mentre qualcuno lo
## rifà.
func _ne_troppi_ne_morti(t, che_cosa: String, trovati: Array,
		ammessi: Array) -> void:
	var veri: Array = []
	for c in trovati:
		if not (c in ammessi):
			veri.append(str(c))
	t.eq(veri.size(), 0, "%s: %s" % [che_cosa, ", ".join(veri)])
	var morte: Array = []
	for a in ammessi:
		if not (a in trovati):
			morte.append(str(a))
	t.eq(morte.size(), 0,
			"…e nessuna eccezione MORTA nell'elenco (%s): un permesso"
			% ", ".join(morte)
			+ " concesso a un chiamante che non esiste più è un lasciapassare")


func _tutta_la_roba() -> String:
	var s := ""
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			s += _senza_commenti(FileAccess.get_file_as_string(path))
	return s


static func _tutti_i_gd(radice: String) -> Array:
	var fuori: Array = []
	var d := DirAccess.open(radice)
	if d == null:
		return fuori
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := radice + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				fuori.append_array(_tutti_i_gd(p))
		elif n.ends_with(".gd"):
			fuori.append(p)
		n = d.get_next()
	d.list_dir_end()
	return fuori


## Il corpo di una funzione, com'è scritto. È l'idioma di `test_salvataggio`:
## si taglia al prossimo `func` di primo livello, così il doc-commento della
## funzione dopo non finisce dentro.
static func _corpo(path: String, fn: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	f.close()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)


## I nomi degli argomenti di un metodo, letti dalla FIRMA COMPILATA e non dal
## testo: un parametro che sparisce fa arrossire il caso anche se qualcuno ha
## lasciato in giro un commento che giura il contrario.
static func _argomenti(script: GDScript, metodo: String) -> Array:
	for m in script.get_script_method_list():
		if m["name"] == metodo:
			var nomi: Array = []
			for a in m["args"]:
				nomi.append(str(a["name"]))
			return nomi
	return []


## Lo spogliatore di `test_fiato`: toglie anche i commenti in coda e rispetta
## le virgolette. Qui è obbligatorio, non consigliato — la cura all'epicentro
## nomina apposta la chiamata vietata per spiegare cosa c'era prima.
static func _senza_commenti(src: String) -> String:
	var out := ""
	for riga in src.split("\n"):
		var pulita := ""
		var in_str := false
		var i := 0
		while i < riga.length():
			var c := riga[i]
			if c == "\"":
				in_str = not in_str
			elif c == "#" and not in_str:
				break
			pulita += c
			i += 1
		out += pulita + "\n"
	return out


# ───────────────────────────────────────────── il mondo preso in prestito

## L'ambiente e lo stato del modulo, presi in prestito e resi com'erano.
##
## ⚠️ `CHIBI_SEME` SI AZZERA, ed è la riga senza la quale questi casi non
## proverebbero niente: è il PRIMO ramo di `radice()`, quindi finché c'è il
## salvataggio non viene nemmeno guardato — e chi fa girare la suite con un
## seme fisso (i banchi lo fanno sempre) misurerebbe un ramo che non è quello.
func _presta_il_mondo() -> Dictionary:
	var p := {
		"seme_c": OS.has_environment("CHIBI_SEME"),
		"seme": OS.get_environment("CHIBI_SEME"),
		"vill_c": OS.has_environment("CHIBI_VILLAGGIO"),
		"vill": OS.get_environment("CHIBI_VILLAGGIO"),
		"posata": Dadi.radice_posata(),
		"radice": 0,
	}
	if p["posata"]:
		p["radice"] = Dadi.radice()
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	OS.set_environment("CHIBI_SEME", "")
	OS.set_environment("CHIBI_VILLAGGIO", FINTO)
	Dadi.dimentica()
	return p


func _rendi_il_mondo(p: Dictionary) -> void:
	_butta(FINTO)
	_butta(FINTO + ".bak")
	DirAccess.remove_absolute(CARTELLA)
	if p["seme_c"]:
		OS.set_environment("CHIBI_SEME", str(p["seme"]))
	else:
		OS.unset_environment("CHIBI_SEME")
	if p["vill_c"]:
		OS.set_environment("CHIBI_VILLAGGIO", str(p["vill"]))
	else:
		OS.unset_environment("CHIBI_VILLAGGIO")
	if p["posata"]:
		Dadi.posa_radice(int(p["radice"]))
	else:
		Dadi.dimentica()


static func _scrivi(percorso: String, testo: String) -> void:
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f != null:
		f.store_string(testo)
		f.close()


## ⚠️ NON CANCELLA NIENTE FUORI DALLA SUA CARTELLA, e non è pignoleria: il
## `village.json` dell'autore è a un `percorso_villaggio()` di distanza, e in
## questo progetto un banco che puliva «la sua» destinazione si è già portato
## via due gigabyte di modello e uno scarico a metà. Un banco che non PUÒ
## sbagliare bersaglio vale più di uno che sta attento.
static func _butta(percorso: String) -> void:
	if not percorso.begins_with(CARTELLA + "/"):
		push_error("test_dadi: rifiuto di cancellare «%s», è fuori da %s"
				% [percorso, CARTELLA])
		return
	if FileAccess.file_exists(percorso):
		DirAccess.remove_absolute(percorso)
