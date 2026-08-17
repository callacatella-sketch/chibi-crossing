extends RefCounted

## IL PENSATOIO — la coda dei pensieri: uno alla volta, sfalsato per vicino.
##
## Fase 5, il passo del RITMO. Da qualche parte, sotto, c'è un thread C++ che
## sa scrivere (il ponte nativo, che si apre con `Llm.apri()` e da nessun'
## altra parte). Questo file decide **di chi si scrive, e ogni
## quanto** — che è una domanda di gioco, non di motore, e per questo sta di
## qua: il C++ non sa chi è sveglio, chi è appena arrivato, chi ha visto
## qualcosa che vale la pena raccontare.
##
## ────────────────────────────────────────────────────────────────────────
## LE CINQUE REGOLE, e ognuna chiude un guasto che si vede
## ────────────────────────────────────────────────────────────────────────
##
## 1. **LA CODA PORTA NOMI, NON FOGLI GIÀ SCRITTI.** L'autore aveva scritto
##    «ogni dieci secondi per abitante»: con ventotto abitanti sono 2.8
##    inferenze al secondo, e la macchina ne regge una ogni pochi secondi.
##    Quindi si fa la fila. Ma se si mettessero in fila i PROMPT, l'ultimo
##    della fila riceverebbe un pensiero costruito **due minuti prima**: il
##    vicino ricorderebbe una cosa che nel frattempo ha dimenticato, sarebbe
##    in un altro posto, starebbe facendo un'altra cosa. Il foglio si scrive
##    quando la generazione COMINCIA — e siccome se ne scrive uno per
##    generazione, il costo sul frame è una volta ogni parecchi secondi
##    invece che ventotto volte per giro.
## 2. **UNO ALLA VOLTA, IN TUTTO IL VILLAGGIO.** Non è una limitazione
##    tecnica: due generazioni insieme su quattro core non vanno il doppio,
##    vanno la metà ciascuna, e nel frattempo il gioco resta senza core. Il
##    motore ha la coda profonda uno e questo file non prova nemmeno a
##    riempirla.
## 3. **IL GIRO È UN GIRO, non una classifica.** Il cursore avanza di UNO per
##    tentativo e non ordina nessuno: chi ha il grafo più pieno non passa
##    davanti. Ordinare i vicini per «quanto sono interessanti» è la
##    classifica visibile che questo gioco si è già vietato una volta
##    (`Affetti`, regola 2), e qui uscirebbe come «i soliti tre parlano
##    sempre».
## 4. **IL BIGLIETTO SI CONTROLLA, SEMPRE.** Un pensiero torna dopo secondi:
##    in mezzo il giocatore può aver cambiato scena, quel vicino può essere
##    partito, il salvataggio può essere stato ricaricato. Si consegna solo
##    se il biglietto è quello che stiamo aspettando **e** chi l'ha chiesto
##    esiste ancora. È la stessa disciplina dell'handle dentro un ricordo:
##    «il guasto peggiore possibile è un'etichetta assente, mai un
##    comportamento sbagliato».
## 5. **QUESTO FILE NON SCRIVE NIENTE NEL MONDO.** Consegna a `_consegna` e
##    finisce lì. Il villaggio ha undici sistemi che impongono stati a
##    evento: un dodicesimo che arriva da un thread, con un dado dentro,
##    renderebbe il gioco non riproducibile — e non ci sarebbe nessun test
##    capace di dirlo.
##
## ⚠️ **LA REGOLA DELLA RICEVUTA vale anche qui, e vale doppio.** Chi consuma
## quello che esce da questo file deve farne un FATTO OSSERVABILE prima che
## una conseguenza da interpretare. Un pensiero che cambia in silenzio quel
## che un vicino fa non attenua l'effetto: lo inverte, perché il giocatore
## vede un villaggio che si muove a caso.
##
## ────────────────────────────────────────────────────────────────────────
## COME SI COLLEGA (e perché è tutto iniettato)
## ────────────────────────────────────────────────────────────────────────
##
## `Visitors.gd` non si istanzia in headless (il suo `_ready` vuole `%Player`
## e `../BuildSystem`). Un ritmo scritto dentro Visitors non sarebbe
## guastabile da un test una valvola per volta — e in questo progetto una
## guardia che nessun test può far diventare rossa è già stata, tre volte,
## una guardia che non c'era. Perciò qui entrano quattro cose e nessuna di
## loro è il villaggio:
##
##   collega(motore, fonte, foglio, consegna)
##
##  · `motore`   — quello che torna `Llm.apri()`, o QUALUNQUE oggetto con
##                 `libero/accoda/raccogli/annulla`. Nei test è un finto che
##                 risponde a comando. Questo file non nomina MAI la classe
##                 nativa: la domanda «c'è un cuore che scrive?» ha una casa
##                 sola (`systems/Llm.gd`), e un test fa la guardia.
##  · `fonte`    — Callable() -> Array: chi è candidato adesso. L'ordine non
##                 conta (vedi regola 3), il contenuto sì: Dictionary con
##                 almeno `chi` (l'handle ECS) e `id` (una chiave stabile per
##                 il riposo — la label del residente).
##  · `foglio`   — Callable(candidato) -> Dictionary con `sistema`, `utente`,
##                 `grammatica`, `seme`; **`{}` vuol dire «non ha niente di
##                 vero da dire»**, che è il caso normale e non un errore.
##  · `consegna` — Callable(candidato, bozze: PackedStringArray, foglio:
##                 Dictionary). Il foglio è quello con cui il pensiero è
##                 partito: dentro c'è il `ritratto`, e senza quello chi
##                 riceve non può passare le bozze da `Suggeritore.accetta()`
##                 — che è l'ultima porta prima dello schermo.
##
## ⚠️ **CHI RICEVE DEVE COLLAUDARE.** Questo file consegna le bozze GREZZE, e
## non è una dimenticanza: la scelta fra N bozze e il collaudo di quella
## scelta sono un mestiere loro, e metterli qui vorrebbe dire che il ritmo e
## il giudizio si cambiano insieme. Ma consegnare grezzo vuol dire che
## nessuna bozza è ancora passata da `accetta()`: **una bozza non collaudata
## non arriva allo schermo, mai.**

## OGNI QUANTO, AL MASSIMO, PARTE UN PENSIERO. Non è il ritmo vero (quello lo
## detta la macchina: finché il motore non è `libero()` qui non parte niente),
## è il PAVIMENTO — la garanzia che due generazioni non si tocchino nemmeno
## sulla macchina più veloce del mondo. Mezzo secondo è lo spazio in cui il
## sistema operativo si riprende i core che ggml ha appena mollato.
const RIPRESA := 0.5

## QUANTO ASPETTA LO STESSO VICINO prima di poter ricevere un altro pensiero.
## Con ventotto residenti il giro naturale è già lungo (vedi `attesa_stimata`),
## ma un villaggio di TRE vicini senza questo numero li farebbe pensare a
## raffica, e la macchina non farebbe altro. Cinque minuti di gioco vero: un
## pensiero è una cosa rara per definizione, e la rarità è metà del suo
## effetto (è la stessa ragione per cui le scenette del menù sono rare).
const RIPOSO := 300.0

## Quante bozze si chiedono in una volta. **È QUI CHE SI UCCIDE LA
## MONOTONIA**, ed è la richiesta esplicita dell'autore: si genera molto e si
## tiene poco.
##
## ⚠️ **QUESTO NUMERO NON È ANCORA TARATO, ed è la cosa più importante che
## resta da fare qui.** Le due parti tirano in direzioni opposte, e tutte e
## due hanno ragione:
##  · il GIUDICE ne vuole tante — «venti bozze entrano, una esce» — perché
##    la rarità si misura contro le sorelle: con poche bozze la più rara del
##    mazzo non è rara, è solo l'unica rimasta;
##  · il COSTO le conta una per una. Il prompt si paga UNA volta (il trucco
##    delle copie in `llm_pensieri.cpp`), ma ogni bozza in più costa la sua
##    coda: ~60 gettoni, cioè `60 / gettoni_al_secondo`.
##
## Il conto è tutto qui, e si rifà con `tools/misura_pensieri.gd`:
##
##     secondi_per_pensiero = prompt/g_s_prompt + COPIE * 60/g_s_uscita
##
## Cinque è un default prudente, non una scelta misurata: la macchina su cui
## ho misurato aveva un carico medio fra 6 e 47 (altri lavori in parallelo) e
## dava fra 2.0 e 3.5 gettoni/s in uscita — numeri con cui QUALUNQUE scelta
## sarebbe stata sbagliata. Chi lo tara su una macchina ferma deve guardare
## due cose insieme, e il provino le stampa tutte e due: quanto dura un
## pensiero, e **quante bozze su N il Giudice ne ammette** — perché è quello,
## non il totale, il numero che decide se la scelta ha davvero di che
## scegliere.
const COPIE := 5

## Il tetto di gettoni per una bozza. Tre righe brevi ne vogliono ~60; 128
## lascia margine alle accentate (in italiano un gettone non è una lettera) e
## resta il tetto DURO oltre il quale si smette comunque.
const MAX_TOKEN := 128

var _motore: Object = null
var _fonte: Callable
var _foglio: Callable
var _consegna: Callable

var _giro := 0
var _da_ultimo := 0.0
var _riposo := {}          # id → secondi che mancano
var _biglietto := 0        # quello che stiamo aspettando (0 = nessuno)
var _in_volo_chi = null    # il candidato di quel biglietto
var _in_volo_foglio := {}  # e il foglio con cui è partito (dentro c'è il ritratto)

# --- le misure, per il provino e per la nota di consegna -----------------
var _consegnati := 0
var _buttati := 0
var _muti := 0             # tentativi finiti in «non ha niente da dire»
var _perso := 0            # pensieri che il motore non ha mai restituito
var _ultimo_errore := ""   # perché l'ultimo pensiero non è arrivato
var _ultimo_ms := 0.0      # quanto è costato l'ultimo foglio, in ms
var _peggio_ms := 0.0
var _ultimo_esito := {}    # i tempi dell'ultima generazione, così come li dà il motore


func collega(motore: Object, fonte: Callable, foglio: Callable, consegna: Callable) -> void:
	_motore = motore
	_fonte = fonte
	_foglio = foglio
	_consegna = consegna


## UN PASSO, da chiamare nel `_process` di chi lo ospita. Nel caso normale —
## e il caso normale è «il motore sta pensando», oppure «non c'è nessun
## motore» — costa un confronto e un'addizione.
func passo(delta: float) -> void:
	if _motore == null or not is_instance_valid(_motore):
		return
	_scala_riposi(delta)
	_ritira()
	if _biglietto != 0:
		# LA RETE: un pensiero che non torna non deve zittire il villaggio.
		#
		# Aspettare un biglietto è giusto (regola 2), ma è anche l'unico modo
		# in cui questo file può fermarsi PER SEMPRE: se l'esito non arriva
		# mai — un errore del motore, un annullamento arrivato da fuori, una
		# generazione che è finita mentre nessuno guardava — `_biglietto`
		# resta acceso e nessuno chiede più niente. Nessun errore, nessun
		# avviso: il villaggio smette di pensare e basta.
		#
		# Il motore che dice `libero()` mentre noi stiamo ancora aspettando
		# vuol dire esattamente questo: lui ha finito, noi non abbiamo visto
		# niente. Si conta come buttato e si riparte. Il degrado va SEMPRE
		# verso «si continua a pensare».
		if bool(_motore.call("libero")):
			_perso += 1
			_buttati += 1
			_biglietto = 0
			_in_volo_chi = null
			_in_volo_foglio = {}
		return  # c'è un pensiero in volo: non se ne chiede un altro
	_da_ultimo += delta
	if _da_ultimo < RIPRESA:
		return
	if not bool(_motore.call("libero")):
		return
	_prova_a_chiedere()


## ⚠️ E QUANDO IL PENSATOIO MUORE, SE LO PORTA DIETRO.
##
## Questa è un'USCITA VERA, e prima non ce n'erano: la documentazione ne
## dichiarava una (`Pensatoio._exit_tree`, citata in `register_types.cpp`) che
## non poteva esistere — questo è un `RefCounted`, non sta nell'albero e
## `_exit_tree` non gli arriva mai. Misurato con `tools/prova_uscita.gd`:
## lasciando cadere il Pensatoio mentre un pensiero era in volo, il thread
## continuava a scrivere per quaranta secondi, cioè fino in fondo, mentre il
## gioco caricava un'altra scena.
##
## `NOTIFICATION_PREDELETE` arriva a QUALUNQUE Object un istante prima che
## venga distrutto, `RefCounted` compreso. Chi ospita il ritmo non deve
## ricordarsi di niente: gli basta lasciarlo andare.
##
## ⚠️⚠️ E QUI C'È UNA TRAPPOLA DI GODOT, misurata (4.7.1): dentro
## `NOTIFICATION_PREDELETE` **i propri metodi non si possono chiamare**. I
## campi si leggono ancora (`_motore` è valido) e i metodi degli ALTRI oggetti
## si chiamano; ma `svuota()` — cioè un metodo di sé stessi — dà
## «Attempt to call function 'svuota' in base 'null instance'», che nel runner
## di questo progetto è un `SCRIPT ERROR` che NON fa fallire niente: il
## Pensatoio si sarebbe portato dietro un errore rosso e nessun annullamento.
## Per questo il gesto vive in una funzione **statica** (le statiche stanno
## sullo script, non sull'istanza, e da lì si chiamano ancora): una sola
## implementazione, chiamata da tutte e due le strade.
func _notification(cosa: int) -> void:
	if cosa == NOTIFICATION_PREDELETE:
		butta_il_volo(_motore)


## Dire al motore di lasciar perdere quello che sta scrivendo. Statica apposta
## (vedi la trappola qui sopra), e con la sua guardia: il motore può essere
## già sparito, o non esserci mai stato — che è la configurazione normale di
## chi gioca senza modello.
static func butta_il_volo(motore: Object) -> void:
	if motore != null and is_instance_valid(motore):
		motore.call("annulla")


## Butta quello che è in volo. Si chiama quando si cambia scena, si torna al
## titolo, si ricarica una partita: da lì in poi nessun esito ha più un
## destinatario, e uno che arrivasse sarebbe un pensiero di un altro mondo.
## NON BLOCCA (il motore se ne accorge dentro llama e molla).
func svuota() -> void:
	_biglietto = 0
	_in_volo_chi = null
	_in_volo_foglio = {}
	_riposo.clear()
	butta_il_volo(_motore)


## Ogni quanto, in secondi, un dato vicino riceve un pensiero — dato quanto
## dura una generazione su QUESTA macchina. Non è una costante: è il conto
## che lega la cadenza al numero di abitanti, ed è quello che si stampa nel
## provino invece di dichiarare un numero a memoria.
static func attesa_stimata(quanti_vicini: int, secondi_per_pensiero: float) -> float:
	if quanti_vicini <= 0:
		return 0.0
	var per_giro: float = maxf(secondi_per_pensiero, RIPRESA)
	return maxf(per_giro * float(quanti_vicini), RIPOSO)


func misure() -> Dictionary:
	return {
		"consegnati": _consegnati,
		"buttati": _buttati,
		"muti": _muti,
		"persi": _perso,
		"errore": _ultimo_errore,
		"in_volo": _biglietto != 0,
		"foglio_ms": _ultimo_ms,
		"foglio_ms_peggio": _peggio_ms,
		"ultimo": _ultimo_esito,
	}


# =========================================================================

func _scala_riposi(delta: float) -> void:
	if _riposo.is_empty():
		return
	var finiti := []
	for k in _riposo:
		var t: float = float(_riposo[k]) - delta
		if t <= 0.0:
			finiti.append(k)
		else:
			_riposo[k] = t
	for k in finiti:
		_riposo.erase(k)


## RITIRA, e butta senza pietà tutto quello che non è più suo. Il ritiro sta
## PRIMA della richiesta e non dopo: così un esito che arriva nello stesso
## frame in cui il motore torna libero viene consegnato subito, invece di
## aspettare il giro dopo.
func _ritira() -> void:
	while true:
		var e: Dictionary = _motore.call("raccogli")
		if e.is_empty():
			return
		var b := int(e.get("biglietto", 0))
		var bozze: PackedStringArray = e.get("bozze", PackedStringArray())
		if b != _biglietto or _in_volo_chi == null or bozze.is_empty():
			# NON È PIÙ NOSTRO. Un biglietto vecchio vuol dire che in mezzo
			# c'è stato uno `svuota()` — cambio di scena, partita ricaricata,
			# vicino partito. Consegnarlo lo stesso sarebbe un pensiero di un
			# altro mondo addosso a qualcuno che non l'ha pensato.
			_buttati += 1
			if b == _biglietto:
				# ERA IL NOSTRO, ma è tornato vuoto: il motore ha avuto un
				# guaio (prompt più lungo della finestra, grammatica che non
				# si apre, decode rifiutato). Si smette di aspettarlo — se no
				# il villaggio ammutolisce per sempre — e si TIENE il motivo:
				# un errore che nessuno può leggere è un errore che nessuno
				# aggiusterà.
				_ultimo_errore = str(e.get("errore", "il motore non ha scritto niente"))
				_biglietto = 0
				_in_volo_chi = null
				_in_volo_foglio = {}
			continue
		var chi = _in_volo_chi
		var foglio := _in_volo_foglio
		_biglietto = 0
		_in_volo_chi = null
		_in_volo_foglio = {}
		_consegnati += 1
		_ultimo_esito = {
			"secondi_prompt": float(e.get("secondi_prompt", 0.0)),
			"secondi_generazione": float(e.get("secondi_generazione", 0.0)),
			"token_prompt": int(e.get("token_prompt", 0)),
			"token_generati": int(e.get("token_generati", 0)),
			"bozze": bozze.size(),
		}
		if _consegna.is_valid():
			_consegna.call(chi, bozze, foglio)


func _prova_a_chiedere() -> void:
	var candidati: Array = _fonte.call() if _fonte.is_valid() else []
	if candidati.is_empty():
		return
	# UN SOLO CANDIDATO PER TENTATIVO. Scandire l'elenco finché non se ne
	# trova uno che ha qualcosa da dire vorrebbe dire, in un villaggio che non
	# ha ancora visto niente (cioè all'inizio di ogni partita), costruire
	# ventotto ritratti dentro un frame — e il gioco punirebbe chi comincia.
	var i: int = _giro % candidati.size()
	_giro = (_giro + 1) % maxi(candidati.size(), 1)
	var c = candidati[i]
	var id := str(c.get("id", i)) if c is Dictionary else str(i)
	if _riposo.has(id):
		return

	var t0 := Time.get_ticks_usec()
	var f: Dictionary = _foglio.call(c) if _foglio.is_valid() else {}
	_ultimo_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_peggio_ms = maxf(_peggio_ms, _ultimo_ms)
	if f.is_empty():
		# NON HA NIENTE DI VERO DA DIRE, ed è il caso normale — il silenzio è
		# il comportamento normale di tutto ciò che in questo gioco parla. Si
		# mette a riposo lo stesso: senza, il cursore tornerebbe da lui al
		# giro dopo e il villaggio spenderebbe la giornata a costruire ritratti
		# vuoti.
		_muti += 1
		_riposo[id] = RIPOSO
		return

	var b := int(_motore.call("accoda", int(c.get("chi", -1)),
			str(f.get("sistema", "")), str(f.get("utente", "")),
			str(f.get("grammatica", "")),
			{"copie": COPIE, "max_token": MAX_TOKEN, "seme": int(f.get("seme", 0))}))
	if b == 0:
		return  # rifiutato (motore occupato, o grammatica vuota): si riprova
	_biglietto = b
	_in_volo_chi = c
	# IL FOGLIO SI TIENE DA PARTE FINCHÉ IL PENSIERO NON TORNA, e non è per
	# comodità: dentro c'è il RITRATTO con cui è stata generata la grammatica,
	# e senza quello chi riceve le bozze **non può collaudarle**.
	# `Suggeritore.accetta()` è l'ultima porta prima dello schermo e vuole lo
	# stesso ritratto: ricostruirlo alla consegna vorrebbe dire collaudare
	# contro un villaggio di un minuto dopo — un ricordo può essersi
	# raffreddato sotto soglia nel frattempo, e allora una frase vera
	# verrebbe bocciata (o, peggio, il contrario).
	_in_volo_foglio = f
	_da_ultimo = 0.0
	_riposo[id] = RIPOSO
