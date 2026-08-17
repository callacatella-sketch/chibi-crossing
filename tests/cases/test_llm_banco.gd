extends RefCounted
## LA FINESTRA DI `annulla()` — la corsa che ha ammutolito il villaggio PER
## SEMPRE, provata SENZA modello.
##
## ────────────────────────────────────────────────────────────────────────
## IL DIFETTO, e perché nessun test poteva vederlo
## ────────────────────────────────────────────────────────────────────────
##
## `Traduttore::accoda()` accende `_in_volo` mettendo in coda; a spegnerlo,
## prima, c'era UN SOLO posto — la fine di un lavoro ESEGUITO. Ma fra il
## momento in cui la richiesta entra in coda e quello in cui chi scrive la
## prende passa un tempo VERO (misurato su un M1: mediana 27 µs a macchina
## scarica, punte di 117 ms a macchina carica — cioè proprio quando il
## modello genera, che è quando la macchina è carica). Un `annulla()` che
## cade lì dentro buttava il lavoro e lasciava `_in_volo` acceso **per
## sempre**: `libero()` falso per sempre → `accoda()` che rifiuta tutto per
## il resto del processo → il villaggio smette di pensare, in silenzio, e la
## diagnosi continua a dire «pronto».
##
## La cura sta in due righe (`_in_volo` spento nel ramo «era ancora in coda»,
## e `_preso` acceso da chi prende il lavoro). MISURATO il 2026-08-12,
## togliendole una per volta dal sorgente e rifacendo la suite intera:
## **63942 passati, 0 falliti** tutte e due le volte. Cioè le due righe che
## riparano il guasto peggiore di questa fase non erano provate da niente.
##
## L'unico giudice era `tools/prova_concorrenza.cpp`: vuole un `.gguf` da due
## gigabyte e un eseguibile compilato a mano, quindi non gira in nessuna
## suite e non gira in CI.
##
## ────────────────────────────────────────────────────────────────────────
## COME SI PROVA UNA CORSA SENZA CORRERE
## ────────────────────────────────────────────────────────────────────────
##
## Il difetto **non è di tempistica**: è una transizione di stato che nessuno
## gestiva. Il tempo decideva solo quanto spesso ci si cascava. Perciò qui
## non si cerca di infilarsi in una finestra di ventisette microsecondi da
## GDScript (sarebbe un test che passa quasi sempre, cioè un test che non
## dice niente): si toglie di mezzo **il lavoro**, e si muove la richiesta a
## mano attraverso le funzioni VERE.
##
## `LlmLocale.banco_*` accende un `chibi::Traduttore` vero SENZA modello e
## SENZA thread; `accoda()`, `annulla()`, il prologo di chi scrive
## (`_prendi_lavoro`) e il suo epilogo (`_epilogo`) sono quelli di
## produzione, chiamati dagli stessi posti e sotto lo stesso lucchetto.
## Finto è solo il lavoro — e non si inventa nemmeno una parola: il testo
## dell'esito lo passa questo file.
##
## ⚠️ **È L'OPPOSTO DI UN DOPPIO.** Un doppio reimplementa la cosa da provare
## (ed è così che `MotoreFinto.annulla()` ha coperto questo stesso difetto
## per mesi: «annulla e sono libero», sempre — cioè il finto faceva la cosa
## giusta che il vero non faceva). Qui non si reimplementa niente: si toglie
## la cosa che non c'entra.
##
## ⚠️ QUESTO FILE GIRA SOLO NEL BINARIO COMPILATO CON `llm=yes` (il job
## `test-llm` di tests.yml). Senza, `chibi::Traduttore` non è nemmeno
## compilato: non c'è niente da proteggere — ed è la configurazione NORMALE,
## non un guasto. L'unico caso che gira SEMPRE è l'ultimo, che tiene chiusa
## la porta del banco verso il gioco.

const LLM := preload("res://systems/Llm.gd")

## Una grammatica qualunque, purché ci sia: `accoda()` rifiuta senza, e non è
## una raccomandazione (misurato: senza grammatica il 27% delle citazioni è
## inventato). Il banco non salta nessuna delle tre porte vere.
const GRAMM := "root ::= \"va bene\""

## `LlmLocale::Stato`, gli stessi numeri dell'enum del ponte.
const SPENTO := 0
const PRONTO := 2
const PENSA := 3


func run(t) -> void:
	# QUESTO GIRA SEMPRE, anche nel binario senza llama: è la guardia che
	# tiene il banco fuori dal gioco, e senza di lei un domani qualcuno
	# potrebbe accendere un motore che non scrive niente dentro una partita.
	_il_banco_resta_fuori_dal_gioco(t)

	if not LLM.disponibile():
		return
	var cuore := LLM.apri()
	if cuore == null:
		return

	_il_banco_si_accende_senza_modello(t)
	_annullare_un_lavoro_ancora_in_coda_libera_il_motore(t)
	_annullare_un_lavoro_gia_in_mano_lo_ferma(t)
	_annullare_due_volte_non_lascia_la_rete_aperta(t)
	_un_banco_che_muore_richiude_la_rete(t)
	_un_esito_vuoto_si_consegna_lo_stesso(t)
	_il_banco_e_suo_e_non_tocca_il_villaggio(t, cuore)


# =========================================================================
# IL BANCO
# =========================================================================

## Un traduttore vero, acceso senza modello. Ogni caso ha il SUO: il banco
## non si riaccende (`banco_accendi` rifiuta un motore già acceso), e due
## casi che si passassero lo stesso motore si racconterebbero a vicenda uno
## stato che non hanno costruito loro.
func _acceso(t) -> Object:
	var c := LLM.apri()
	if c == null:
		t.ok(false, "il ponte non si apre")
		return null
	t.ok(c.banco_accendi(), "il banco si accende (nessun modello, nessun thread)")
	return c


func _st(c) -> Dictionary:
	return c.banco_stato() as Dictionary


# =========================================================================
# 1. IL PUNTO DI PARTENZA
# =========================================================================

## Un motore PRONTO che non ha aperto niente: è tutto quello che serve per
## far girare la contabilità della coda. E le tre porte di `accoda()` restano
## quelle vere — un banco che le saltasse proverebbe una funzione che il
## gioco non ha.
func _il_banco_si_accende_senza_modello(t) -> void:
	var c = _acceso(t)
	if c == null:
		return
	var s := _st(c)
	t.eq(int(s["stato"]), PRONTO, "il traduttore del banco è PRONTO")
	t.ok(bool(s["libero"]), "e libero: gli si può chiedere un pensiero")
	t.ok(not bool(s["in_mano"]), "nessuno ha un lavoro in mano")
	t.ok(not bool(s["deve_smettere"]), "e nessuno ha ricevuto l'ordine di smettere")

	t.eq(int(c.banco_accoda(1, "le frasi", "")), 0,
			"senza grammatica non si scrive, e `accoda` rifiuta")
	t.eq(int(c.banco_accoda(1, "", GRAMM)), 0, "e senza foglio nemmeno")
	t.ok(bool(_st(c)["libero"]), "due rifiuti non lasciano il motore occupato")

	t.ok(not c.banco_accendi(), "e un banco già acceso non si riaccende")


# =========================================================================
# 2. IL DIFETTO — «annulla» dentro la finestra
# =========================================================================

## ⚠️ **IL CASO CHE VALE TUTTO IL FILE.** Il lavoro è in coda e chi scrive
## non l'ha ancora preso: è ESATTAMENTE la finestra da 27 µs. `annulla()`
## butta la richiesta — quel lavoro non esiste più, nessuno lo finirà mai — e
## quindi `_in_volo` **deve spegnersi lì**, perché non c'è nessun altro che
## possa farlo.
##
## FALSIFICATO togliendo `_in_volo.store(false, …)` dal ramo «era ancora in
## coda» di `Traduttore::annulla()` (`src/llm_pensieri.cpp`): il motore non
## torna più libero, `accoda()` rifiuta tutto per il resto del processo, e
## qui diventano rosse quattro asserzioni. Prima di questo file la stessa
## mutazione lasciava la suite a 63942/0.
func _annullare_un_lavoro_ancora_in_coda_libera_il_motore(t) -> void:
	var c = _acceso(t)
	if c == null:
		return
	var b := int(c.banco_accoda(7, "le frasi del Gufo", GRAMM))
	t.ok(b > 0, "il pensiero entra in coda (biglietto %d)" % b)
	var dentro := _st(c)
	t.ok(not bool(dentro["libero"]), "da lì il motore non è libero: c'è un lavoro in volo")
	t.ok(not bool(dentro["in_mano"]),
			"ma chi scrive non ce l'ha ancora in mano — È LA FINESTRA")

	# il cambio di scena cade proprio qui
	c.banco_annulla()

	var dopo := _st(c)
	t.ok(bool(dopo["libero"]),
			"annullato un lavoro che nessuno aveva preso, il motore torna LIBERO")
	t.ok(not bool(dopo["deve_smettere"]),
			"e non resta nessun ordine di smettere addosso al pensiero dopo")
	t.eq(int(dopo["buttati"]), 1, "il lavoro buttato si conta")

	# LA PROVA CHE IL VILLAGGIO NON È MUTO: si torna a pensare, e il pensiero
	# arriva fino in fondo. Senza la riga, `accoda` qui risponde 0 per sempre.
	var b2 := int(c.banco_accoda(7, "le frasi del Gufo", GRAMM))
	t.ok(b2 > b, "e il villaggio torna a pensare (biglietto %d)" % b2)
	t.ok(c.banco_prendi(), "chi scrive prende il pensiero nuovo")
	c.banco_finisci("una riga.\nuna citazione.\naltra riga.")
	var e: Dictionary = c.banco_raccogli()
	t.eq(int(e.get("biglietto", 0)), b2, "e quel pensiero si consegna davvero")
	t.eq(int(_st(c)["pensieri"]), 1, "contato fra i pensieri fatti")


## ⚠️ **E L'ALTRA METÀ: quando il lavoro è GIÀ IN MANO a chi scrive.**
##
## Qui `annulla()` non deve spegnere niente: deve alzare la bandiera e
## andarsene, perché a spegnere `_in_volo` sarà chi molla — e a mollare ci
## vuole il suo tempo (misurato sul vero: 1–35 ms, perché `abort_callback`
## ferma `llama_decode` a metà di un gettone). Chi decide fra i due rami è
## `_preso`, e `_preso` lo accende il prologo di chi scrive.
##
## FALSIFICATO togliendo `_preso = true` da `Traduttore::_prendi_lavoro()`:
## `annulla()` prende il ramo sbagliato, la generazione in corso **non
## riceve l'ordine di smettere** (cioè il thread continua a scrivere per
## tutta la scena nuova: misurato quaranta secondi), la finestra del silenzio
## non si apre, e l'esito di una scena finita viene CONSEGNATO addosso a un
## vicino che nel frattempo se n'è andato. Cinque asserzioni rosse. Prima di
## questo file: 63942/0.
func _annullare_un_lavoro_gia_in_mano_lo_ferma(t) -> void:
	var c = _acceso(t)
	if c == null:
		return
	var b := int(c.banco_accoda(9, "le frasi del Gufo", GRAMM))
	t.ok(b > 0, "il pensiero entra in coda")
	t.ok(c.banco_prendi(), "e chi scrive lo prende")
	var preso := _st(c)
	t.ok(bool(preso["in_mano"]), "da qui il lavoro è suo")
	t.eq(int(preso["stato"]), PENSA, "e il motore sta scrivendo")

	c.banco_annulla()

	var dopo := _st(c)
	t.ok(bool(dopo["deve_smettere"]),
			"l'annullamento arriva DENTRO la generazione: chi scrive riceve l'ordine di smettere")
	t.ok(bool(dopo["abbandono"]),
			"e si apre la finestra del silenzio: le righe che llama stampa mollando "
					+ "non sono errori, sono il rumore di un gesto voluto")
	t.ok(not bool(dopo["libero"]),
			"il motore NON torna libero all'istante: sta ancora mollando")
	t.ok(bool(dopo["in_mano"]), "il lavoro è ancora in mano a chi scrive")

	# e adesso molla
	c.banco_finisci("questa non la leggerà nessuno")

	var fine := _st(c)
	t.ok(bool(fine["libero"]), "mollato, il motore è di nuovo libero")
	t.ok(not bool(fine["in_mano"]), "e non ha più niente in mano")
	t.ok(not bool(fine["abbandono"]),
			"la rete del silenzio si richiude: da adesso un errore di llama è un errore")
	t.ok((c.banco_raccogli() as Dictionary).is_empty(),
			"UN ESITO ANNULLATO NON SI CONSEGNA: quel pensiero era di un'altra scena")
	t.eq(int(fine["pensieri"]), 0, "e non si conta fra i pensieri fatti")


## LA RETE DEL SILENZIO SI APRE UNA VOLTA SOLA. `g_abbandoni` è un contatore
## globale al PROCESSO, e chi lo alza è chi annulla mentre chi lo abbassa è
## chi molla: due `annulla()` ravvicinati (un cambio di scena mentre un
## vicino se ne va) alzerebbero due volte e abbasserebbero una — e da lì in
## poi **ogni** errore di llama resterebbe declassato ad avviso, per tutta la
## partita. Non si rompe il gioco: si rompe la rete che si accorge quando il
## gioco è rotto davvero.
##
## FALSIFICATO togliendo la guardia `if (!_annullato.exchange(true, …))` da
## `Traduttore::annulla()` (cioè alzando la finestra a ogni chiamata): dopo
## l'epilogo l'abbandono resta acceso, e l'ultima asserzione diventa rossa.
func _annullare_due_volte_non_lascia_la_rete_aperta(t) -> void:
	var c = _acceso(t)
	if c == null:
		return
	c.banco_accoda(4, "le frasi del Gufo", GRAMM)
	t.ok(c.banco_prendi(), "chi scrive ha il lavoro in mano")
	c.banco_annulla()
	c.banco_annulla()
	t.ok(bool(_st(c)["abbandono"]), "due annullamenti, e la finestra è aperta")
	c.banco_finisci("")
	t.ok(not bool(_st(c)["abbandono"]),
			"un solo epilogo la richiude TUTTA: il contatore non resta appeso")


## ⚠️ **E SE CHI STAVA MOLLANDO NON MOLLA MAI?** È il cambio di scena vero:
## si annulla, e un istante dopo il maniglione se ne va con l'albero. Il
## contatore del silenzio l'ha alzato `annulla()` e ad abbassarlo doveva
## essere l'epilogo — che adesso non arriverà. Se restasse su, da lì alla
## fine della partita **ogni** errore di llama uscirebbe declassato ad
## avviso: non si rompe il gioco, si rompe la rete che si accorge quando il
## gioco è rotto davvero.
##
## Nel gioco vero questo ramo non si raggiunge (la finestra si apre solo se
## c'è un thread che scrive, e `chiudi()` lo aspetta), ma il banco ci arriva
## — e una riga che vale «mai, tranne quando qualcuno prova» è il posto
## esatto in cui un residuo si accumula senza che nessuno lo veda.
##
## Il testimone è un SECONDO banco: `abbandono` è un contatore del processo,
## e per leggerlo dopo che il primo è morto serve qualcuno ancora vivo.
##
## FALSIFICATO in due modi, tutti e due rossi: togliendo il blocco
## `if (_zittisci)` dal ramo senza thread di `Traduttore::chiudi()`, e
## togliendo `_banco->chiudi()` dal distruttore di `LlmLocale`.
func _un_banco_che_muore_richiude_la_rete(t) -> void:
	var testimone = _acceso(t)
	var c = _acceso(t)
	if c == null or testimone == null:
		return
	c.banco_accoda(5, "le frasi del Gufo", GRAMM)
	t.ok(c.banco_prendi(), "chi scrive ha il lavoro in mano")
	c.banco_annulla()
	t.ok(bool(_st(testimone)["abbandono"]), "la finestra del silenzio è aperta")
	c = null   # il cambio di scena: se ne va chi stava mollando
	t.ok(not bool(_st(testimone)["abbandono"]),
			"e morendo la richiude: nessun errore di llama resta declassato per sempre")


# =========================================================================
# 3. L'ALTRO MODO DI DIVENTARE MUTI
# =========================================================================

## ⚠️ **UN ESITO VUOTO SI CONSEGNA LO STESSO**, ed è l'altra metà del
## villaggio muto. Chi aspetta un biglietto — `Pensatoio` — se non lo riceve
## MAI non smette mai di aspettarlo, quindi non chiede più nessun pensiero:
## il villaggio si spegne dopo un errore solo, senza una riga di log. Un
## prompt più lungo della finestra, una grammatica che non si apre, un
## `llama_decode` che rifiuta: sono tutti casi veri, e l'unico modo perché
## quel testo arrivi a chi può stamparlo è consegnare l'esito vuoto.
##
## FALSIFICATO rimettendo `|| p_esito.bozze.empty()` nella condizione di
## scarto dell'epilogo (che è com'era scritto prima): la cassetta resta
## vuota, e diventano rosse quattro asserzioni.
func _un_esito_vuoto_si_consegna_lo_stesso(t) -> void:
	var c = _acceso(t)
	if c == null:
		return
	var b := int(c.banco_accoda(3, "le frasi del Gufo", GRAMM))
	t.ok(c.banco_prendi(), "chi scrive prende il lavoro")
	c.banco_finisci("")   # la generazione non ha prodotto niente

	var e: Dictionary = c.banco_raccogli()
	t.ok(not e.is_empty(),
			"un esito VUOTO si consegna lo stesso: chi lo aspetta deve poter smettere")
	t.eq(int(e.get("biglietto", 0)), b, "col suo biglietto, o chi riceve lo butta")
	t.eq((e.get("bozze", PackedStringArray()) as PackedStringArray).size(), 0,
			"senza bozze, perché non ce n'erano")
	t.ok(str(e.get("errore", "")) != "",
			"ma con un errore da leggere (invece: «%s»)" % str(e.get("errore", "")))
	var s := _st(c)
	t.eq(int(s["pensieri"]), 0, "e non si conta fra i pensieri fatti")
	t.ok(bool(s["libero"]), "il motore torna comunque libero")


# =========================================================================
# 4. IL BANCO NON DEVE ESISTERE, PER IL GIOCO
# =========================================================================

## IL BANCO È DEL MANIGLIONE, NON DEL PROCESSO. Se accendesse il traduttore
## vero, tutti i casi successivi della suite si troverebbero un motore acceso
## che non hanno chiesto — e `test_pensatoio` pretende, giustamente, di
## trovarlo SPENTO.
func _il_banco_e_suo_e_non_tocca_il_villaggio(t, cuore) -> void:
	t.eq(int(cuore.stato()), SPENTO,
			"dopo tutti questi banchi, il traduttore del PROCESSO è ancora spento")
	t.ok(not cuore.libero(), "e spento non è libero")
	t.eq(int(cuore.accoda(1, "s", "u", GRAMM, {})), 0,
			"e continua a rifiutare lavoro, come deve")
	# e un maniglione che non ha mai acceso il banco non ha nessun banco
	var vergine := LLM.apri()
	t.ok((vergine.banco_stato() as Dictionary).is_empty(),
			"un maniglione che non l'ha acceso non ha nessun banco")
	t.eq(int(vergine.banco_accoda(1, "u", GRAMM)), 0, "e non gli si può accodare niente")


## ⚠️ **E NEL GIOCO NON LO CHIAMA NESSUNO.** Il banco mette un traduttore in
## PRONTO senza modello: se una riga di partita lo accendesse, il villaggio
## avrebbe un motore che accetta pensieri e non ne scrive nessuno — e la
## Fase 5 diventerebbe «un gioco a cui manca un pezzo», che è precisamente la
## cosa che non ha il permesso di essere.
##
## Si cerca il NOME dei metodi, e si saltano i commenti: la lezione di questo
## file è scritta apposta nella prosa che lo descrive, e un guardiano che non
## distingue il codice dai commenti costringe chi verrà a togliere le
## spiegazioni per far passare la suite (è già successo in `test_pensatoio`).
func _il_banco_resta_fuori_dal_gioco(t) -> void:
	var vietati := ["banco_accendi", "banco_accoda", "banco_prendi",
			"banco_finisci", "banco_annulla", "banco_raccogli", "banco_stato",
			"banco_in_mano", "banco_deve_smettere"]
	# UNA ASSERZIONE PER FILE, non una per nome: nove asserzioni verdi per
	# ognuno dei centoventi sorgenti sarebbero mille righe di rumore in una
	# suite che si legge contando i numeri. Il nome trovato entra nel
	# messaggio, così quando diventa rossa si sa già cosa cercare.
	var trovati := []
	var quanti := 0
	for f in _script_sotto("res://scenes") + _script_sotto("res://systems"):
		quanti += 1
		var codice := _codice(f)
		for v in vietati:
			if codice.contains(v):
				trovati.append("%s → %s" % [f, v])
	t.eq(trovati.size(), 0,
			"il gioco non accende mai il banco (invece: %s)" % ", ".join(trovati))
	t.ok(quanti > 100, "e i sorgenti del gioco si sono letti davvero (%d file)" % quanti)


## Tutti gli `.gd` sotto una cartella, ricorsivamente.
func _script_sotto(radice: String) -> Array:
	var out := []
	var dir := DirAccess.open(radice)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var p := radice.path_join(f)
		if dir.current_is_dir():
			out.append_array(_script_sotto(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = dir.get_next()
	dir.list_dir_end()
	return out


## Il sorgente SENZA le righe di commento.
func _codice(percorso: String) -> String:
	var righe := PackedStringArray()
	for r in FileAccess.get_file_as_string(percorso).split("\n"):
		if (r as String).strip_edges().begins_with("#"):
			continue
		righe.append(r)
	return "\n".join(righe)
