class_name Scarico
extends Node

## IL CORRIERE — il modello si scarica al primo uso, e il gioco non se ne accorge.
##
## **LA DECISIONE DELL'AUTORE (2026-08-13): il modello non viaggia più dentro
## il pacchetto.** Il gioco resta piccolo per tutti, e chi non accenderà mai la
## funzione non paga niente — né in byte scaricati, né in disco, né in tempo di
## installazione. La ragione tecnica che l'ha forzata: GitHub non accetta
## allegati sopra i 2 GiB, e il pacchetto col modello dentro ne pesa 2,4.
##
## Perciò questo nodo. Sta sotto `/root` (non dentro il livello) e porta a casa
## `pensieri.gguf` mentre il giocatore gioca: `Llm.percorso_modello()` lo trova
## da solo il giro dopo, senza che nessun altro file cambi di una riga.
##
## ────────────────────────────────────────────────────────────────────────
## LE REGOLE DI QUESTA FASE, e nessuna è negoziabile
## ────────────────────────────────────────────────────────────────────────
##
## 1. **NIENTE RETE SE NON QUANDO IL GIOCATORE LO CHIEDE.** La Fase 5 ha un
##    vincolo scritto: l'inferenza è tutta locale, nessuna chiamata a un
##    servizio esterno. Questo scarico è l'UNICA cosa che tocca la rete in
##    tutto il gioco, ed è un gesto unico e voluto: nessun controllo
##    all'avvio, nessun ping, nessuna telemetria, nessun «cerco se c'è una
##    versione nuova». Il thread di rete nasce dentro `avvia()` — che si
##    chiama da un bottone — e muore quando ha finito. Un test
##    (`test_scarico.gd`) scandaglia `scenes/` e `systems/` perché resti così.
## 2. **IL GIOCO CONTINUA.** Si scarica mentre si gioca, e il fotogramma non
##    deve accorgersene. Il lavoro sta tutto su un `Thread`; sul fotogramma
##    resta un `_process` che legge sei numeri sotto lucchetto — MISURATO:
##    **2,6 µs** in media, e il fotogramma medio del MainLevel non si muove.
## 3. **SI PUÒ ANNULLARE, E ANNULLARE FUNZIONA.** Non «smette di aggiornare la
##    barra»: il thread molla, il file si chiude, e quello che è arrivato
##    resta lì col nome sbagliato — cioè pronto per la ripresa e invisibile a
##    chi cerca il modello. MISURATO: il thread si ferma in **1 ms**.
## 4. **IL GIOCO FUNZIONA IDENTICO SENZA.** Chi non scarica niente ha il gioco
##    di sempre. Chi comincia e non finisce, idem. Chi scarica un file
##    rovinato, idem — e il file rovinato viene buttato invece di restare lì a
##    spegnere la funzione per sempre in silenzio.
##
## ────────────────────────────────────────────────────────────────────────
## DOVE SI PRENDE, E PERCHÉ LE COSTANTI STANNO IN DUE CASE
## ────────────────────────────────────────────────────────────────────────
##
## Qui sta **dove andarlo a prendere** (repository, file, revisione, quanto
## pesa). In [`systems/Llm.gd`](Llm.gd) sta **cos'è** (come si chiama una volta
## a casa, `NOME_MODELLO`; che impronta deve avere, `IMPRONTA_SPEDITO`; in che
## cartella vive, `CARTELLA_MODELLI`). Sono due domande diverse e questo file
## non ricopia una sola di quelle costanti: le legge.
##
## ⚠️ **LA REVISIONE È PINNATA APPOSTA.** Un `resolve/main/…` punterebbe a
## qualunque cosa ci sia a monte domani, e l'impronta del gioco non
## combacerebbe più: il modello verrebbe scaricato per intero e buttato alla
## fine, a ogni tentativo, per sempre. Con la revisione pinnata i byte sono
## quelli, e il preflight se ne accorge in un decimo di secondo.
## Cambiare modello vuol dire cambiare, INSIEME: `REPO`/`FILE_A_MONTE`/
## `REVISIONE`/`DIMENSIONE` qui, `IMPRONTA_SPEDITO` in `Llm.gd`, e la voce in
## `THIRD_PARTY_NOTICES.md` (i pesi hanno una licenza loro, che non è quella
## di llama.cpp).

const LLM := preload("res://systems/Llm.gd")

## Il repository a monte, la revisione, il file. Formato tenuto SEMPLICE
## apposta: `release.yml` legge queste righe con `sed`, come già fa con
## `NOME_MODELLO` e `IMPRONTA_SPEDITO`, invece di tenersi una copia che
## diverge in silenzio.
const REPO := "ggml-org/gemma-3-4b-it-GGUF"
const FILE_A_MONTE := "gemma-3-4b-it-Q4_K_M.gguf"
const REVISIONE := "d0976223747697cb51e056d85c532013931fe52e"

## Quanto pesa, al byte. Verificato a monte (`x-linked-size`) e sul disco: un
## file più corto o più lungo non è il nostro, e si scopre prima di leggerne
## due gigabyte e mezzo per calcolarne l'impronta.
const DIMENSIONE := 2489757856

## Il nome del nodo sotto `/root`. Fa anche da lucchetto: due scarichi insieme
## si scriverebbero addosso.
const NODO := "ScaricoModello"

## Ogni quanto si racconta a chi guarda. Quattro volte al secondo: più spesso è
## una barra che trema, meno spesso è una barra ferma.
const RESPIRO := 0.25

signal avanzato(fatti: int, totali: int, fase: int)
signal finito(esito: int, diagnosi: String)


var _thread: Thread = null
var _mutex := Mutex.new()
# l'istantanea condivisa col thread: si legge e si scrive SOLO sotto `_mutex`
var _fase := ScaricoMacchina.FASE_SPAZIO
var _fatti := 0
var _esito := ScaricoMacchina.ESITO_NIENTE
var _diagnosi := ""
var _al_secondo := 0.0
var _impronta_avanti := 0.0
var _ferma := false
var _finita := false
var _diario: Array[String] = []

var _detto := false          # il segnale `finito` è già uscito?
var _prossimo_respiro := 0.0
var _rete_finta = null       # i banchi possono mettere un altro tubo
var _url_banco := ""         # …e altri estremi (vedi `usa_questi_estremi`)
var _dest_banco := ""
var _dim_banco := 0
var _imp_banco := ""


# =========================================================================
# LE DOMANDE CHE SI FANNO DA FUORI (e la casa unica di ognuna)
# =========================================================================

## SERVE SCARICARLO? Vero se questo binario saprebbe scrivere (c'è llama
## dentro) e un modello non c'è. Se il cuore è stato compilato senza llama.cpp
## la risposta è NO e non è un ripiego: scaricare due gigabyte e mezzo che
## nessuno saprebbe aprire è il modo più costoso di non fare niente.
static func serve() -> bool:
	return LLM.disponibile() and LLM.percorso_modello() == ""


## Dove finirà il file, per esteso. `Llm` dice la cartella e il nome; qui si
## mettono insieme e basta.
static func destinazione() -> String:
	return LLM.CARTELLA_MODELLI.path_join(LLM.NOME_MODELLO)


static func url() -> String:
	return "https://huggingface.co/%s/resolve/%s/%s" % [REPO, REVISIONE, FILE_A_MONTE]


## Quanti byte di un viaggio interrotto ci sono già sul disco. Serve a chi
## disegna il bottone: «riprendi» invece di «scarica» non è una parola gentile,
## è l'informazione che dice a chi gioca che non ricomincia da capo.
static func parziale_byte() -> int:
	var p := destinazione() + ".parte"
	if not FileAccess.file_exists(p):
		return 0
	var f := FileAccess.open(p, FileAccess.READ)
	return 0 if f == null else f.get_length()


## Butta il pezzo di viaggio rimasto a metà. Non lo fa mai il gioco da solo: un
## parziale è roba di chi gioca, e cancellare due gigabyte già scaricati perché
## è passata una settimana sarebbe un dispetto.
static func butta_il_parziale() -> void:
	var p := destinazione() + ".parte"
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


## Lo scarico in corso, o `null`. Vive sotto `/root` e non dentro il livello
## apposta: chi comincia dal menù di pausa e poi torna al titolo (o carica
## un'altra partita) non deve perdere quello che ha già preso.
static func vivo(albero: SceneTree) -> Scarico:
	if albero == null or albero.root == null:
		return null
	return albero.root.get_node_or_null(NODO) as Scarico


## Comincia (o riprende). Torna il nodo — quello nuovo, o quello che stava già
## lavorando: due scarichi insieme scriverebbero sullo stesso file.
static func avvia(albero: SceneTree) -> Scarico:
	var gia := vivo(albero)
	if gia != null:
		return gia
	var s := Scarico.new()
	s.name = NODO
	albero.root.add_child(s)
	s.comincia()
	return s


# =========================================================================
# IL LAVORO
# =========================================================================

## Un corriere fermo non costa NIENTE al fotogramma: `_process` è spento
## finché non c'è un viaggio in corso. È la stessa regola di `Pensieri` — un
## `_process` spento non viene chiamato, quindi il costo non è «piccolo», è
## zero — e qui vale doppio, perché questo nodo esiste anche mentre la
## schermata sta solo chiedendo se lo si vuole.
func _ready() -> void:
	set_process(_thread != null)


## Accende il thread. Da qui in poi il fotogramma non fa più niente tranne
## leggere sei numeri.
func comincia() -> void:
	if _thread != null:
		return
	_mutex.lock()
	_ferma = false
	_finita = false
	_esito = ScaricoMacchina.ESITO_NIENTE
	_fase = ScaricoMacchina.FASE_SPAZIO
	_fatti = 0
	_diagnosi = ""
	_mutex.unlock()
	_detto = false
	set_process(true)
	_thread = Thread.new()
	_thread.start(_lavora)


## Ferma. Torna subito: a mollare ci mette il thread, e ci mette un millesimo.
func annulla() -> void:
	_mutex.lock()
	_ferma = true
	_mutex.unlock()


func fase() -> int:
	_mutex.lock()
	var v := _fase
	_mutex.unlock()
	return v


func esito() -> int:
	_mutex.lock()
	var v := _esito
	_mutex.unlock()
	return v


func fatti() -> int:
	_mutex.lock()
	var v := _fatti
	_mutex.unlock()
	return v


func totali() -> int:
	return _dim_banco if _dim_banco > 0 else DIMENSIONE


## Byte al secondo, media mobile. Per il tempo che manca, e per capire — mentre
## si guarda un banco — se la linea sta lavorando o è ferma.
func al_secondo() -> float:
	_mutex.lock()
	var v := _al_secondo
	_mutex.unlock()
	return v


func diagnosi() -> String:
	_mutex.lock()
	var v := _diagnosi
	_mutex.unlock()
	return v


func diario() -> Array[String]:
	_mutex.lock()
	var v := _diario.duplicate()
	_mutex.unlock()
	return v


## I banchi mettono qui il loro tubo (un server finto in casa, una rete che
## cade apposta). Nel gioco non lo chiama nessuno, e un test lo sorveglia.
func usa_questa_rete(rete) -> void:
	_rete_finta = rete


## E qui i loro estremi: da dove, dove, quanto, che impronta. Serve ai banchi
## e ai provini — quello che prova la ripresa con un file da trecento
## kilobyte, e quello che misura il fotogramma scaricando davvero in una
## cartella sua.
##
## ⚠️ **Nel gioco non lo chiama nessuno**, e un caso di `test_scarico.gd` fa
## la guardia: un corriere che va a prendere il modello da un posto deciso da
## qualcun altro è la porta che questa fase non deve avere. In partita gli
## estremi sono tre costanti (`url()`, `destinazione()`, `DIMENSIONE`) più
## l'impronta di `Llm`.
func usa_questi_estremi(url_: String, destinazione_: String, dimensione_: int,
		impronta_: String) -> void:
	_url_banco = url_
	_dest_banco = destinazione_
	_dim_banco = dimensione_
	_imp_banco = impronta_


func _lavora() -> void:
	var rete = _rete_finta if _rete_finta != null else ScaricoRete.new()
	var m := ScaricoMacchina.new(rete,
			_url_banco if _url_banco != "" else url(),
			_dest_banco if _dest_banco != "" else destinazione(),
			_dim_banco if _dim_banco > 0 else DIMENSIONE,
			_imp_banco if _imp_banco != "" else LLM.IMPRONTA_SPEDITO)
	var t_prima := Time.get_ticks_msec()
	var b_prima := 0
	while true:
		_mutex.lock()
		var ferma := _ferma
		_mutex.unlock()
		if ferma:
			m.annulla()
		var p := m.passo()
		# l'istantanea: pochissimo lavoro sotto lucchetto, perché di là c'è un
		# fotogramma che aspetta
		var ora := Time.get_ticks_msec()
		var v := -1.0
		if ora - t_prima >= 500:
			v = float(m.fatti() - b_prima) * 1000.0 / float(ora - t_prima)
			t_prima = ora
			b_prima = m.fatti()
		_mutex.lock()
		_fase = m.fase()
		_fatti = m.fatti()
		_impronta_avanti = m.impronta_avanti()
		if v >= 0.0:
			_al_secondo = _al_secondo * 0.5 + v * 0.5 if _al_secondo > 0.0 else v
		if p == ScaricoMacchina.PASSO_FINE:
			_esito = m.esito()
			_diagnosi = m.diagnosi()
			_diario = m.diario()
			_finita = true
		_mutex.unlock()
		if p == ScaricoMacchina.PASSO_FINE:
			return
		if p == ScaricoMacchina.PASSO_ATTESA:
			# un millesimo: è il tempo che ci mette la rete a portare il pezzo
			# dopo, ed è anche il tempo massimo che un annullamento aspetta
			OS.delay_msec(1)


func _process(_d: float) -> void:
	_mutex.lock()
	var finita := _finita
	var fatti := _fatti
	var fase := _fase
	var esito := _esito
	var diagnosi := _diagnosi
	_mutex.unlock()

	var ora := float(Time.get_ticks_msec()) / 1000.0
	if not finita and ora >= _prossimo_respiro:
		_prossimo_respiro = ora + RESPIRO
		avanzato.emit(fatti, DIMENSIONE, fase)

	if finita and not _detto:
		_detto = true
		if _thread != null:
			_thread.wait_to_finish()
			_thread = null
		set_process(false)
		avanzato.emit(fatti, DIMENSIONE, fase)
		finito.emit(esito, diagnosi)


## L'USCITA. Il nodo se ne va (fine del gioco, o qualcuno lo libera): il thread
## si ferma e si aspetta che abbia finito, o resterebbe a scrivere dentro un
## processo che sta chiudendo. È la stessa lezione di `Pensatoio` e delle tre
## uscite del cuore che scrive: un thread che nessuno ferma non muore da solo.
##
## ⚠️ `_exit_tree` e non `NOTIFICATION_PREDELETE`: dentro PREDELETE i propri
## metodi non si possono chiamare (MISURATO in questo progetto, 4.7.1: «Attempt
## to call function … in base 'null instance'», e nel runner è un SCRIPT ERROR
## che non fa fallire niente).
func _exit_tree() -> void:
	if _thread != null:
		_mutex.lock()
		_ferma = true
		_mutex.unlock()
		_thread.wait_to_finish()
		_thread = null


# =========================================================================
# LE PAROLE — la casa unica di quello che si dice a chi gioca
# =========================================================================
#
# Nessuna di queste frasi nomina una macchina: chi gioca non deve sapere
# cos'è un modello linguistico per decidere se lo vuole, e soprattutto non
# deve leggere una diagnosi. Le diagnosi (`diagnosi()`) sono per i log.

## Cosa sta succedendo, in una riga.
func frase_fase() -> String:
	_mutex.lock()
	var f := _fase
	var b := _fatti
	_mutex.unlock()
	match f:
		ScaricoMacchina.FASE_SPAZIO, ScaricoMacchina.FASE_TESTA:
			return L10n.t("Un momento…")
		ScaricoMacchina.FASE_APRE:
			return L10n.t("Mi collego…")
		ScaricoMacchina.FASE_CORPO:
			return L10n.tf("%s di %s", [misura_umana(b), misura_umana(totali())])
		ScaricoMacchina.FASE_IMPRONTA:
			return L10n.t("Controllo che sia arrivato tutto…")
		ScaricoMacchina.FASE_POSA:
			return L10n.t("Ci siamo.")
	return ""


## Come è finita, per chi gioca. Ogni riga dice due cose: cosa è successo, e
## cosa può fare adesso — perché «non ha funzionato» senza un seguito è solo
## un modo elegante di dare la colpa a chi legge.
static func frase(esito: int) -> String:
	match esito:
		ScaricoMacchina.ESITO_FATTO:
			return L10n.t("È arrivato. Dal prossimo avvio i vicini avranno idee tutte loro.")
		ScaricoMacchina.ESITO_ANNULLATO:
			return L10n.t("Lasciato a metà. Quello che è arrivato resta: si riprende da lì.")
		ScaricoMacchina.ESITO_SPAZIO:
			return L10n.t("Sul disco non c'è abbastanza spazio libero.")
		ScaricoMacchina.ESITO_RETE:
			return L10n.t("La connessione non ha retto. Riprova quando vuoi: si riprende da dov'era.")
		ScaricoMacchina.ESITO_IMPRONTA:
			return L10n.t("Quello che è arrivato non era intero, e l'ho buttato. Riprova quando vuoi.")
		ScaricoMacchina.ESITO_SORGENTE, ScaricoMacchina.ESITO_CHIUSO:
			return L10n.t("Adesso non si trova. Riprova più tardi.")
		ScaricoMacchina.ESITO_DISCO:
			return L10n.t("Non riesco a scrivere sul disco.")
	return ""


## «2,3 GB». La virgola è italiana e il punto è inglese: è l'unico numero di
## questo file che chi gioca legge, e scriverlo con la punteggiatura di
## un'altra lingua è il genere di sciatteria che si nota subito.
static func misura_umana(byte: int) -> String:
	var v := float(byte)
	var unita := "B"
	for u in ["kB", "MB", "GB"]:
		if v < 1024.0:
			break
		v /= 1024.0
		unita = u
	var n := "%.1f" % v if unita == "GB" else "%d" % roundi(v)
	if L10n.lingua_corrente() == L10n.SORGENTE:
		n = n.replace(".", ",")
	return "%s %s" % [n, unita]
