extends Node

## I PENSIERI — il nodo che chiude il cerchio della Fase 5, in partita.
##
## Tutto il resto della Fase 5 esisteva già e non lo chiamava nessuno: il
## Suggeritore sa scrivere il prompt, il Pensatoio sa fare la fila, il
## Giudice sa scegliere, `Deduzioni` sa incassare, `Visitors` sa pagare la
## ricevuta e dirottare l'agenda. Mancava **il padrone del ritmo**: qualcuno
## che, dentro il gioco vero, scegliesse un vicino, gli montasse il foglio,
## accodasse il pensiero e portasse l'esito fino al grafo. È questo file, e
## non fa nient'altro.
##
## Il giro, per esteso, è cinque righe:
##
##     un vicino  →  FoglioDelVicino.foglio_deduzione()  →  Pensatoio.accoda
##       →  il thread C++ scrive N bozze JSON  →  Deduzioni.incassa()
##       →  un nodo nel grafo, muto, che aspetta di farsi vedere
##
## Da lì in poi il file non c'entra più: la RICEVUTA la paga
## `Visitors._cuore_di` (la testa che si gira, solo se il giocatore è lì a
## vederla) e il dirottamento lo fa `Visitors._deduzione_dirotta`, sul fronte
## dell'agenda. Questo nodo non tocca nessun corpo, non scrive nessuno stato,
## non stampa niente a chi gioca.
##
## ────────────────────────────────────────────────────────────────────────
## LA REGOLA CHE VIENE PRIMA DI TUTTE: SENZA MODELLO NON SUCCEDE NIENTE
## ────────────────────────────────────────────────────────────────────────
##
## Non «quasi niente», non «degrada con grazia»: **niente**. Se
## `Llm.acceso()` è falso — e oggi è falso per tutti, perché nessun modello
## viaggia col gioco — questo `_ready` spegne il proprio `_process` e ritorna
## **prima di aver allocato un solo oggetto**: niente ponte, niente
## Pensatoio, niente elenco di candidati, niente riga stampata. Un nodo con
## `_process` spento non viene nemmeno chiamato dal motore: il costo per
## fotogramma non è «piccolo», è ZERO, e il villaggio è bit per bit quello di
## prima che la Fase 5 esistesse.
##
## È anche il motivo per cui la porta è `acceso()` e non `disponibile()`:
## `disponibile()` dice che il BINARIO sa scrivere, e su un binario `llm=yes`
## senza modello sarebbe vera — cioè il nodo si sveglierebbe, aprirebbe il
## ponte, comincerebbe a montare fogli e li butterebbe, **per ogni giocatore
## che ha il gioco e non ha i pesi**. Le due domande sono due, e stanno tutte
## e due in `systems/Llm.gd`.
##
## ────────────────────────────────────────────────────────────────────────
## LE SETTE SCELTE, e ognuna ha la sua ragione
## ────────────────────────────────────────────────────────────────────────
##
## 1. **IL CABLAGGIO SI RIPROVA, SEMPRE.** È la trappola già pagata due volte
##    in questo progetto (il taccuino del Gufo, la percezione): i
##    collaboratori di questo nodo nascono TARDI — l'`EcsMondo` lo crea
##    `Visitors._ensure_ecs()` al primo ciclo del sonno, e i figli di
##    CozyWorld nascono in una generazione differita su più frame. Un
##    cablaggio fatto una volta sola dentro un `call_deferred` del `_ready`
##    trova `null` **per sempre**, e il sistema resta muto senza un errore.
## 2. **IL MODELLO SI APRE QUANDO C'È QUALCUNO CHE PUÒ PENSARE**, non al
##    caricamento della scena. Due gigabyte e mezzo mappati in un villaggio
##    appena nato — nessuna casa, nessun vicino — sono due gigabyte e mezzo
##    che il giocatore paga per una funzione che non ha ancora nessun
##    soggetto. Si aspetta il primo residente con un handle ECS: il carico
##    arriva quando il villaggio c'è, sul thread, mentre il gioco disegna.
## 3. **SI PENSA SOLO SU CHI SI PUÒ VEDERE.** Il ritmo del villaggio pieno è
##    già lungo (una generazione ogni parecchi secondi, un pensiero per
##    vicino ogni parecchi minuti): spendere l'unico slot che c'è su qualcuno
##    che è **dentro casa** vuol dire buttarlo, perché la ricevuta non gli si
##    può pagare (`Percezione.puo_vedere` esclude chi è nascosto) e la
##    deduzione resterebbe muta finché non scade. Chi dorme un pisolino nel
##    prato resta candidato: si sveglia in pochi secondi, e la deduzione ha
##    minuti per trovare il suo momento.
## 4. **`gia_dedotto` SI RIEMPIE, e non è decorativo.** Il ponte rifiuta una
##    deduzione con lo stesso obiettivo di una ancora viva, e il Giudice non
##    ha modo di saperlo da solo: lasciandolo vuoto si promuovono bozze che
##    il mondo butta, **e la seconda bocciatura è muta** (misurato a monte:
##    delle 34 scelte-e-non-incassate, la maggioranza erano gemelle). La
##    fonte è una sola, `EcsMondo.debug_deduzioni(id)`.
## 5. **IL COLLAUDO È CONTRO IL RITRATTO CON CUI IL PENSIERO È PARTITO**, e
##    arriva col foglio (`Pensatoio` lo tiene da parte apposta). Ricostruirlo
##    alla consegna vorrebbe dire giudicare contro un villaggio di un minuto
##    dopo: un ricordo può essersi raffreddato sotto soglia nel frattempo, e
##    una deduzione vera verrebbe bocciata — o, peggio, il contrario.
## 6. **IL SEME È DERIVATO, MAI TIRATO.** In questo gioco i dadi si salvano
##    (`Animo._rng`), e un dado nuovo dentro un generatore di prompt sarebbe
##    una seconda storia che nessun salvataggio racconta. Qui il seme è
##    `hash(nome + numero del pensiero)`: due pensieri dello stesso vicino
##    non chiedono la stessa cosa, e la stessa partita rifatta chiede le
##    stesse cose. (Il grafo delle deduzioni **non è persistito** — vive in
##    RAM e muore col processo — quindi nemmeno il contatore deve esserlo.)
## 7. **NON SI SCRIVE MAI NEL MONDO DA QUI.** Il villaggio ha undici sistemi
##    che impongono stati a evento; un dodicesimo che arriva da un thread,
##    con un modello linguistico dentro, renderebbe il gioco non riproducibile
##    — e non ci sarebbe nessun test capace di dirlo. Quello che questo file
##    consegna al mondo è **un nodo muto nel grafo**: la prima cosa che ne
##    esce è una testa che si gira, e solo dopo, forse, un mestiere diverso.
##
## ────────────────────────────────────────────────────────────────────────
## LE USCITE
## ────────────────────────────────────────────────────────────────────────
##
## Una generazione dura decine di secondi. In quei secondi il giocatore può
## tornare al titolo, ricaricare la partita, chiudere il gioco: da lì in poi
## nessun esito ha più un destinatario, e uno che arrivasse sarebbe il
## pensiero di un altro mondo. Le uscite sono due e nessuna chiede a nessuno
## di ricordarsi niente:
##
##  · **`_exit_tree`** — questa è VERA e immediata, e ce l'ha solo un nodo:
##    il Pensatoio è un `RefCounted`, `_exit_tree` non gli arriva mai (era la
##    prima uscita che la documentazione dava per esistente e non esisteva).
##    Quando il livello se ne va, il ritmo si svuota e il thread molla.
##  · **il maniglione che muore** — quando il nodo viene distrutto cade anche
##    il riferimento al ponte, e i due terminatori del C++ (il distruttore
##    dell'ultimo maniglione, e lo scaricamento della GDExtension alla
##    chiusura del gioco) fanno il resto. Il nome della classe nativa non si
##    scrive nemmeno qui: ha una casa sola, ed è `systems/Llm.gd`.
##
## Si **annulla**, non si chiude: `chiudi()` libera il modello, e riaprire due
## gigabyte e mezzo a ogni cambio di scena sarebbe la cura peggiore della
## malattia.

const LLM := preload("res://systems/Llm.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const DEDUZIONI := preload("res://scenes/npc/Deduzioni.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## CHI È IL PROTAGONISTA, per il modello. Il gioco chiama Mochi per nome in
## ottanta posti e non ha (ancora) una costante sola: si scrive qui la stessa
## parola che `Suggeritore` usa come ripiego, così se un giorno il nome
## diventasse scegliibile ci sarà un posto solo da cambiare in tutta la
## Fase 5.
const PROTAGONISTA := "Mochi"

## LA FINESTRA DI ATTENZIONE, in gettoni. 2048 è la misura su cui sono state
## fatte TUTTE le misure della fase (prompt veri da 607–659 gettoni, cache di
## attenzione compresa nella stima di `stima_byte_totali`): cambiarla vuol
## dire rifare la tabella della RAM.
const FINESTRA := 2048

## LA PRIORITÀ DEL THREAD CHE SCRIVE — **la più bassa, e MISURATA.**
##
## Sui core normali il modello scrive quattro volte più in fretta, e non serve
## a niente: nessuno sta aspettando quel pensiero. Quello che serve è che i
## core buoni restino al fotogramma, e il conto non è piccolo. Misurato nel
## MainLevel vero con ventotto residenti, a blocchi alternati nella stessa
## corsa (`tools/prova_villaggio_pensa.gd`, macchina nello stesso stato):
##
##     priorità 1   fotogramma medio +2.98 ms (+8.6%)   p99  40.4 → 67.2 ms
##     priorità 2   fotogramma medio +1.01 ms (+3.2%)   p99  33.7 → 39.8 ms
##
## Tre volte meno sul medio, e soprattutto **la coda**: a priorità 1 il p99
## quasi raddoppia, cioè il singhiozzo si vede. Si paga in gettoni al secondo
## — un pensiero ogni cinquanta secondi invece che ogni quindici — e non è un
## prezzo: un pensiero è una cosa RARA per definizione, e la rarità è metà del
## suo effetto (è la stessa ragione per cui le scenette del menù sono rare).
const PRIORITA := 2

## OGNI QUANTO SI RIPROVA A CABLARE / AD APRIRE, in secondi. Finché il
## villaggio non ha un cuore e un abitante non c'è niente da fare, e cercarlo
## sessanta volte al secondo è sessanta volte più spesso del necessario.
const RIPROVA := 1.0

## PER QUANTO VALE L'ELENCO DEI CANDIDATI, in secondi. Il Pensatoio chiede la
## fonte a **ogni tentativo**, e i tentativi cadono a cadenza di fotogramma
## quando nessuno ha niente da dire: ricostruire ventotto righe sessanta
## volte al secondo per una domanda la cui risposta cambia quando qualcuno
## entra in casa è la definizione di spesa inutile. Un secondo è più corto di
## qualunque cosa possa cambiare qui dentro.
const ELENCO_VALE := 1.0


var _pens: RefCounted = null
var _llm: Object = null
var _vis: Node = null
var _cuore: Object = null
var _dn: Node = null

## "spento" · "attesa" (cerca il villaggio) · "carica" · "pensa" · "guasto".
## Solo "spento" è uno stato in cui questo nodo non fa assolutamente niente.
var _stato := "spento"
var _diagnosi := ""
var _chiesto := false          # `apri_modello` si chiede UNA volta per vita
var _da_riprova := 0.0

var _elenco: Array = []
var _elenco_scad := 0.0
## Quanti fogli sono stati montati da quando il gioco è aperto. È il secondo
## ingrediente del seme (vedi la regola 6), e conta i TENTATIVI e non le
## consegne: un pensiero che non torna non deve far ripetere al vicino dopo
## la stessa identica domanda.
var _semi := 0

# --- le misure, per i banchi e per la nota di consegna --------------------
var _pensieri := 0             # esiti consegnati dal motore
var _dedotte := 0              # deduzioni entrate nel grafo
var _bocciate := 0             # consegne in cui il Giudice (o il ponte) ha detto no
var _bozze_tot := 0
var _bozze_ok := 0
var _porte := {}               # perché le bozze sono state buttate
var _consegna_ms := 0.0
var _consegna_ms_peggio := 0.0
var _passo_us_peggio := 0.0
var _passo_us_somma := 0.0
var _passi := 0
var _t_carico_ms := 0


func _ready() -> void:
	# ⚠️ LA PORTA, ED È TUTTO IL FILE. Prima di questa riga non è stato
	# allocato niente; dopo il `return` non lo sarà mai. Un `_process` spento
	# non viene chiamato: nessun ramo di questo file gira per chi non ha il
	# modello, che oggi è chiunque.
	if not _si_accende():
		set_process(false)
		return
	_stato = "attesa"
	add_to_group("pensieri")


func _exit_tree() -> void:
	# L'USCITA VERA, e ce l'ha solo un nodo (vedi il blocco in cima). Il
	# Pensatoio non sta nell'albero e `_exit_tree` non gli arriva mai: questa
	# riga è l'unico posto in cui il cambio di scena diventa un `annulla()`
	# immediato invece di aspettare che un `RefCounted` venga raccolto.
	if _pens != null:
		_pens.svuota()


func _process(delta: float) -> void:
	if _pens == null:
		_da_riprova -= delta
		if _da_riprova > 0.0:
			return
		_da_riprova = RIPROVA
		_elenco_scad -= RIPROVA
		_avvia()
		return
	_elenco_scad -= delta
	var t0 := Time.get_ticks_usec()
	_pens.passo(delta)
	var us := float(Time.get_ticks_usec() - t0)
	_passo_us_peggio = maxf(_passo_us_peggio, us)
	_passo_us_somma += us
	_passi += 1


# =========================================================================
# L'ACCENSIONE — cablaggio, poi il modello, poi il ritmo
# =========================================================================

## Un tentativo. Torna quando ha finito il suo pezzo: cablare, chiedere il
## modello, aspettare che finisca di caricarsi, accendere il ritmo. Ogni
## passo è idempotente, così si può ritentare per sempre senza sporcare
## niente.
func _avvia() -> void:
	# «GUASTO» È TERMINALE, e la guardia non è ridondante: `_ferma()` spegne
	# il `_process`, ma un banco che chiama `_process` a mano (e i banchi lo
	# fanno: è l'unico modo di far passare dieci secondi di gioco dentro un
	# frame) arriverebbe qui col ponte già lasciato andare. Un errore a
	# runtime in questo punto non fa fallire niente — interrompe la funzione
	# in silenzio e lascia la suite verde.
	if _stato == "guasto":
		return
	if not _cabla():
		return
	if not _chiesto:
		# REGOLA 2: prima che ci sia qualcuno che possa pensare, non si apre
		# niente. `_candidati()` è la stessa lista che userà il ritmo.
		if _candidati().is_empty():
			return
		_llm = _apri_ponte()
		if _llm == null:
			_ferma("il ponte non si è aperto")
			return
		_chiesto = true
		_stato = "carica"
		_t_carico_ms = Time.get_ticks_msec()
		var percorso := LLM.percorso_modello()
		var opz := opzioni_modello(percorso)
		if not bool(_llm.call("apri_modello", percorso, opz)):
			_ferma(str((_llm.call("misure") as Dictionary).get("diagnosi", "rifiutato")))
			return
		# ⚠️ IL PERCORSO PER INTERO, non `get_file()`. I tre candidati di
		# `Llm.percorso_modello()` si chiamano tutti «pensieri.gguf» tranne
		# il primo: col solo nome del file, un modello dimenticato in
		# `user://` che scavalca quello spedito è **invisibile** in un log —
		# ed è il residuo dichiarato di quell'ordine. Qui si legge.
		print("pensieri: apro «%s» (finestra %d, impronta %s)"
				% [percorso, FINESTRA,
				"verificata" if opz.has("impronta") else "non richiesta"])
		return
	# CARICA (1) → si aspetta, e il gioco continua a disegnare: il carico sta
	# sul thread, ed è misurato (il fotogramma medio non se ne accorge).
	var st := int(_llm.call("stato"))
	if st == 1:
		return
	if st != 2 and st != 3:
		_ferma(str((_llm.call("misure") as Dictionary).get("diagnosi", "il modello non si è aperto")))
		return
	_pens = PENSATOIO.new()
	_pens.collega(_llm, _candidati, _foglio, _consegna)
	_stato = "pensa"
	print("pensieri: il villaggio pensa (%d ms per aprire il modello)"
			% (Time.get_ticks_msec() - _t_carico_ms))


## CON CHE COSA SI APRE IL MODELLO — e sta in una funzione sua perché è
## **l'unica parte dell'accensione che un banco può interrogare**.
##
## Il modello spedito vive dentro il pacchetto di un gioco esportato: nessun
## test può piantarcene uno (piantarlo dentro il bundle di Godot vorrebbe dire
## romperne la firma), quindi nessun test può far arrivare `_avvia()` fin qui
## con il percorso che conta. Presa a parte, invece, le si può passare quel
## percorso — `Llm.spedito_accanto_a()` lo sa dire anche quando il file non
## c'è — e guardare cosa risponde.
##
## ⚠️ **E NON BASTA CERCARE `impronta_attesa` NEL SORGENTE.** MISURATO il
## 2026-08-13: la prima stesura di questa guardia era proprio quello, e
## sostituendo la chiamata con `var imp := ""` — cioè spegnendo l'unica difesa
## contro il bit girato nei pesi — **la suite restava verde**, perché la
## parola cercata compariva nel commento qui sopra. È la trappola che questo
## progetto ha già pagato due volte (il `source-check` che matcha un commento)
## e che `test_vento.gd` salta i commenti apposta per evitare.
##
## L'IMPRONTA vale SOLO per il file dentro il pacchetto: `Llm.impronta_attesa`
## torna "" per `CHIBI_MODELLO` e per il `.gguf` che chi gioca si è messo in
## `user://`, di cui non conosciamo — e non possiamo conoscere — i byte.
##
## ⚠️ LA RISERVA È LA LEVA DEI BANCHI, e solo dei banchi. Il cancello della RAM
## (`Config::riserva_byte`, di serie 1 GB) è quello che impedisce al gioco di
## mandare in swap la macchina di chi gioca: **in partita non si tocca**, e
## infatti qui non c'è nessun valore di serie da passare. Ma un banco deve
## poter misurare anche il modello che il gioco rifiuterebbe — su questa
## macchina la riserva rifiuta perfino il modello da un miliardo di parametri
## — e senza questa riga l'unica alternativa sarebbe misurare un gioco diverso
## da quello vero. È lo stesso `CHIBI_RISERVA` degli altri banchi della fase, e
## vale solo se qualcuno lo esporta a mano.
func opzioni_modello(percorso: String) -> Dictionary:
	var opz := {"n_ctx": FINESTRA, "priorita": PRIORITA}
	var imp := LLM.impronta_attesa(percorso)
	if imp != "":
		opz["impronta"] = imp
	var riserva := OS.get_environment("CHIBI_RISERVA")
	if riserva != "":
		opz["riserva_byte"] = int(riserva)
	return opz


## SI SPEGNE E BASTA, per sempre, e con UNA riga nel registro.
##
## I quattro modi in cui un modello non si apre — non c'è, non è sano (il
## portiere), sfonda il tetto di RAM dell'autore, la macchina non ha la
## memoria libera — sono tutti e quattro **normali**, e nessuno dei quattro
## si mostra a chi gioca: da qui in poi il gioco è quello con i testi
## scritti a mano, cioè il gioco. La riga stampata serve a chi legge un log
## di un difetto segnalato; senza, un modello rifiutato sarebbe
## indistinguibile da un modello che non c'è.
func _ferma(perche: String) -> void:
	_stato = "guasto"
	_diagnosi = perche
	_llm = null
	set_process(false)
	print("pensieri: spento — %s (il gioco continua con i testi scritti a mano)" % perche)


## LE DUE GIUNTURE, e sono qui per la stessa ragione per cui il `Pensatoio`
## si fa iniettare il motore: **una guardia che nessun test può far diventare
## rossa, in questo progetto, è già stata tre volte una guardia che non
## c'era.** Il cablaggio vero, il ritmo vero e il giro chiuso non si possono
## provare con la classe nativa, che nel binario normale NON ESISTE — e un
## test che gira solo sul binario con llama.cpp proverebbe l'unica
## configurazione che nessun giocatore ha.
##
## Di serie rispondono `systems/Llm.gd` e nient'altro: la porta resta quella,
## e un caso a parte pretende che il ripiego combaci con `Llm.acceso()` — se
## qualcuno cambiasse la porta senza cambiare quel caso, il test lo direbbe.
func _si_accende() -> bool:
	return LLM.acceso()


func _apri_ponte() -> Object:
	return LLM.apri()


## SI RIPROVA FINCHÉ NON HA TROVATO TUTTO. Vedi la regola 1.
func _cabla() -> bool:
	if not is_inside_tree():
		return false
	if _vis == null or not is_instance_valid(_vis):
		_vis = get_tree().get_first_node_in_group("visitors")
		_cuore = null
	if _vis == null:
		return false
	if _cuore == null or not is_instance_valid(_cuore):
		# il cuore non c'è finché nessun residente è stato censito: è normale
		# in un villaggio appena aperto, e si ritenta al giro dopo
		_cuore = _vis.call("cuore")
	if _cuore == null or not is_instance_valid(_cuore):
		return false
	if _dn == null or not is_instance_valid(_dn):
		# il DayNight non è obbligatorio (il foglio ne fa a meno: senza, il
		# prompt non parla di stagione né di ora), quindi non si torna false
		_dn = get_tree().root.find_child("DayNight", true, false)
	return true


# =========================================================================
# LE TRE CALLABLE DEL RITMO
# =========================================================================

## CHI PUÒ RICEVERE UN PENSIERO ADESSO. Vedi la regola 3: chi è dentro casa
## non è candidato, perché la sua ricevuta non si potrebbe pagare a nessuno.
##
## L'elenco vale un secondo (vedi `ELENCO_VALE`): il Pensatoio lo chiede a
## ogni tentativo, e i tentativi cadono a cadenza di fotogramma.
func _candidati() -> Array:
	if _elenco_scad > 0.0:
		return _elenco
	# ⚠️ SI RICORDA ANCHE L'ELENCO VUOTO, e non è pignoleria: di notte i
	# ventotto residenti sono TUTTI dentro casa, quindi la risposta giusta è
	# «nessuno» — e una cache che tiene solo le risposte piene ricostruirebbe
	# quel «nessuno» sessanta volte al secondo, per tutta la notte, cioè
	# esattamente nel momento in cui non c'è niente da fare.
	#
	# ⚠️ E LA SCADENZA SCORRE COL `delta` DEL NODO, non con l'orologio da
	# polso. Un banco che chiama `_process(1.0)` dieci volte di fila fa
	# passare dieci secondi di gioco dentro lo stesso millisecondo vero: con
	# `Time.get_ticks_msec()` l'elenco resterebbe congelato a quello del primo
	# giro, e il banco proverebbe una cache invece del cablaggio. È la stessa
	# trappola dell'«orologio da polso» dichiarata in `tools/prova_identico.gd`
	# a proposito del riposo delle chiacchiere.
	_elenco_scad = ELENCO_VALE
	_elenco = []
	if _vis == null or not is_instance_valid(_vis):
		return _elenco
	for riga in (_vis.get("_residents") as Array):
		var r: Dictionary = riga
		if not r.has("ecs"):
			continue            # non ancora censito: non ha una memoria
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if bool(node.call("is_hidden")):
			continue
		_elenco.append({"chi": int(r["ecs"]), "id": str(r.get("label", "")), "r": r})
	return _elenco


## IL FOGLIO DI UNO, montato SUL THREAD PRINCIPALE nell'istante in cui la
## generazione comincia (è la regola 1 del Pensatoio: la coda porta nomi, non
## fogli già scritti). `{}` vuol dire «non ha niente di vero da dire», che è
## il caso normale e non un errore.
func _foglio(c) -> Dictionary:
	var d: Dictionary = c
	var r: Dictionary = d["r"]
	# REGOLA 6: derivato, mai tirato.
	var seme := absi(hash(str(d.get("id", "")) + "#" + str(_semi))) & 0x7FFFFFFF
	_semi += 1
	return FOGLIO.foglio_deduzione(_vis, _dn, _cuore, r, PROTAGONISTA, seme)


## L'ESITO: dalle bozze grezze al nodo nel grafo.
##
## Le bozze arrivano NON COLLAUDATE (è la regola del Pensatoio: il ritmo e il
## giudizio si cambiano separatamente), e da qui in poi il cammino è tutto in
## `Deduzioni.incassa` — che apre i JSON, chiama il Giudice e lascia
## l'ultima parola al ponte, che rilegge il grafo VERO invece del ritratto.
func _consegna(c, bozze: PackedStringArray, foglio: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	_pensieri += 1
	var d: Dictionary = c
	var id := int(d.get("chi", -1))
	var rit: Dictionary = foglio.get("ritratto", {})
	if rit.is_empty() or id < 0 or _cuore == null or not is_instance_valid(_cuore):
		return
	var aperte := DEDUZIONI.bozze_da(Array(bozze))
	_bozze_tot += bozze.size()
	var mondo := {
		"fattibili": rit.get("fattibili", []),
		# REGOLA 4: senza questa riga il Giudice promuove gemelle, e la
		# seconda bocciatura — quella del ponte — è muta.
		"gia_dedotto": _gia_dedotto(id),
	}
	var esito: Dictionary = DEDUZIONI.incassa(_cuore, id, aperte, rit, mondo,
			VISITORS.AMMIRA_SOGLIA)
	if int(esito.get("indice", -1)) >= 0:
		_dedotte += 1
		_bozze_ok += 1
	else:
		_bocciate += 1
		var p := str(esito.get("motivo", ""))
		_porte[p] = int(_porte.get(p, 0)) + 1
	_consegna_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_consegna_ms_peggio = maxf(_consegna_ms_peggio, _consegna_ms)


## GLI OBIETTIVI CHE QUESTO VICINO HA GIÀ DEDOTTO E CHE SONO ANCORA VIVI.
## La fonte è il ponte, e la traduzione maschera→nome è quella di `Deduzioni`
## (quattro confronti): nessun numero di `chibi::Provvedimento` ricopiato qui.
func _gia_dedotto(id: int) -> Array:
	var out := []
	var d: Dictionary = _cuore.call("debug_deduzioni", id)
	for riga in (d.get("deduzioni", []) as Array):
		var nome := DEDUZIONI.nome_obiettivo(_cuore,
				int((riga as Dictionary).get("obiettivo", 0)))
		if nome != "" and not out.has(nome):
			out.append(nome)
	return out


# =========================================================================
# LE MISURE — per i banchi, e per chi legge un log
# =========================================================================

func misure() -> Dictionary:
	var m := {
		"stato": _stato,
		"diagnosi": _diagnosi,
		"acceso": _pens != null,
		"pensieri": _pensieri,
		"dedotte": _dedotte,
		"bocciate": _bocciate,
		"bozze": _bozze_tot,
		"bozze_ok": _bozze_ok,
		"porte": _porte,
		"consegna_ms": _consegna_ms,
		"consegna_ms_peggio": _consegna_ms_peggio,
		"passo_us_peggio": _passo_us_peggio,
		"passo_us_medio": _passo_us_somma / maxf(float(_passi), 1.0),
		"carico_ms": _t_carico_ms,
		"candidati": _elenco.size(),
	}
	if _pens != null:
		m["ritmo"] = _pens.misure()
	return m


## SOLO PER I BANCHI: mette in pausa il ritmo senza smontare niente, così una
## misura appaiata (col motore acceso e spento, nella STESSA corsa) è
## possibile. Due corse diverse non sono confrontabili — compilazione degli
## shader, cache, e soprattutto le altre sessioni che girano sulla macchina.
func debug_pausa(quanto: bool) -> void:
	set_process(not quanto)
	if quanto and _pens != null:
		_pens.svuota()
