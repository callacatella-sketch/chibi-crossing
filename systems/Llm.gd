class_name Llm
extends RefCounted

## IL CUORE CHE SCRIVE — e la domanda si fa QUI, una volta sola.
##
## Il gioco può avere dentro un modello linguistico piccolo, in locale, che
## scrive di suo pugno le lettere del Gufo, i pensieri e i discorsi. Può.
## **Il gioco deve funzionare IDENTICO senza**: chi non ce l'ha ha un gioco
## meno sorprendente, non un gioco a cui manca un pezzo. Nessuna schermata di
## errore, nessun caricamento che si pianta, nessun testo che non arriva —
## le lettere scritte a mano ci sono e restano.
##
## Come fa il gioco a saperlo: la GDExtension registra la classe nativa
## `LlmLocale` SOLO se il cuore è stato compilato con `scons llm=yes`.
## L'esistenza della classe **è** il segnale — non c'è un file di
## configurazione da tenere allineato, non c'è un flag salvato che possa
## mentire, e un binario compilato senza llama.cpp non ha nemmeno il codice
## per rispondere di sì.
##
##     if Llm.disponibile():
##         var cuore = Llm.apri()
##         ...
##
## LE DUE REGOLE DI CHI CI COSTRUISCE SOPRA:
##
## 1. **Il ramo senza è quello NORMALE, e si scrive per primo.** Non
##    «altrimenti mostra un errore»: altrimenti succede la cosa bella di
##    prima. Se una funzione non ha una risposta sensata senza il modello,
##    quella funzione non va scritta.
## 2. **Non si chiede mai `ClassDB.class_exists` altrove.** È la stessa
##    regola delle fonti uniche: la domanda ha una casa sola, così il giorno
##    in cui la risposta dipenderà anche da altro (un modello scaricato, una
##    impostazione del giocatore, poca memoria) cambia un posto e non venti.
##
## ⚠️ **E `disponibile()` NON vuol dire «il modello si aprirà».** Dice una
## cosa sola: che questo binario ha llama.cpp dentro. Il modello può poi non
## aprirsi per ragioni che nessuno può sapere prima — il file non c'è, non è
## sano (il portiere, `llm_gguf.h`), sfonda il tetto di RAM dell'autore,
## oppure **questa macchina non ha la memoria libera** per tenerlo senza
## mandare in swap il gioco (`Config::riserva_byte`). Tutti e quattro i casi
## finiscono nello stesso posto — `LlmLocale.stato()` che diventa `GUASTO` e
## una `diagnosi` leggibile nei log — e tutti e quattro sono **normali**: chi
## li incontra ha il gioco di sempre, quello con le lettere scritte a mano.
## Nessuno deve mostrarli a chi gioca.

## Il nome della classe nativa registrata da `src/llm_ponte.cpp`.
const CLASSE := "LlmLocale"


## C'è un cuore che scrive?
static func disponibile() -> bool:
	return ClassDB.class_exists(CLASSE)


## Il ponte, oppure `null` — e `null` non è un guasto, è la normalità.
## Non stampa niente: un avviso a ogni chiamata insegnerebbe a chi gioca
## (e a chi sviluppa) che manca qualcosa, e non manca niente.
static func apri() -> Object:
	if not disponibile():
		return null
	return ClassDB.instantiate(CLASSE)


## Una riga leggibile per i log e per i provini: cosa c'è dentro questo
## binario. Senza il modulo dice che non c'è, e va benissimo così.
static func riga_di_stato() -> String:
	var cuore := apri()
	if cuore == null:
		return "llm: assente (il gioco gira con i testi scritti a mano)"
	return "llm: %s — backend %s" % [str(cuore.versione()), ", ".join(cuore.backend())]


# =========================================================================
# IL MODELLO — dove sta, e se si accende
# =========================================================================
#
# `disponibile()` dice che questo BINARIO sa scrivere. Non dice che ci sia
# qualcosa da far scrivere: i pesi non entrano nel repository e non entrano
# nel `.pck` (sono gigabyte, e Git li conserverebbe per sempre). Perciò le
# due domande sono due, e stanno tutte e due qui — la casa unica della
# domanda «c'è un cuore che scrive?» è anche la casa di «e ha di che».

## Come si chiama il modello quando ce l'ha il giocatore. Un nome fisso e non
## una scansione della cartella: un `.gguf` qualunque trovato per caso è il
## modo in cui il gioco finisce a caricare due gigabyte che non sono suoi.
const NOME_MODELLO := "pensieri.gguf"

## E dove lo si mette. `user://` è l'unico posto scrivibile che esiste su
## tutte e tre le piattaforme, e `globalize_path` lo trasforma nel percorso
## VERO su disco — llama.cpp apre un file, non una risorsa di Godot.
const CARTELLA_MODELLI := "user://modelli"


## IL PERCORSO DEL MODELLO, o "" — e "" è la normalità, oggi per TUTTI.
##
## Due posti, in ordine, e nessuno dei due è una sorpresa:
##  1. `CHIBI_MODELLO` — la leva dei banchi di prova e dei provini, che è
##     anche il modo in cui l'autore prova il gioco vero col modello vero.
##     Sta per prima apposta: chi la esporta sta dicendo esplicitamente quale
##     modello vuole, e nessun file trovato in giro deve poterlo scavalcare.
##  2. `user://modelli/pensieri.gguf` — dove lo mette chi gioca.
##
## ⚠️ **IL TERZO POSTO NON C'È ANCORA, ED È UNA SCELTA.** Il giorno in cui il
## gioco spedirà il suo modello, quello arriverà ACCANTO all'eseguibile (mai
## dentro il `.pck`: llama vuole un percorso su disco, e una risorsa
## impacchettata non ne ha uno) e sarà un terzo candidato QUI DENTRO. Non
## cambia nient'altro in tutto il gioco — è precisamente la ragione per cui
## questa domanda ha una casa sola.
static func percorso_modello() -> String:
	var da_fuori := OS.get_environment("CHIBI_MODELLO")
	if da_fuori != "" and FileAccess.file_exists(da_fuori):
		return da_fuori
	var suo := CARTELLA_MODELLI.path_join(NOME_MODELLO)
	if FileAccess.file_exists(suo):
		return ProjectSettings.globalize_path(suo)
	return ""


## LA LEVA DI CHI GIOCA. Vera quando il villaggio ha il permesso di pensare:
## il binario sa scrivere, un modello c'è, e nessuno ha detto di no.
##
## ⚠️ **SERVE UNA LEVA? SÌ — E NON VA NEL PANNELLO DELLE IMPOSTAZIONI.** Le
## due metà di questa risposta vengono dallo stesso vincolo dell'autore.
##
## Serve, perché il giorno in cui il modello viaggia dentro il pacchetto la
## sola via d'uscita sarebbe cancellare un file dentro la cartella
## d'installazione: non è una via d'uscita, è un sabotaggio. E la funzione
## costa RAM e core VERI sulla macchina di chi gioca — misurato: 2,7 GB di
## impronta col 4B, e su un Mac da 8 GB il resto della macchina se ne accorge.
##
## Ma **non va nel pannello**, e non oggi: una casella «il villaggio pensa»
## mostrata a chi non ha nessun modello è esattamente «un gioco a cui manca
## un pezzo» — la cosa che la Fase 5 non ha il permesso di essere. Una
## casella spenta e ingrigita insegna a chi gioca che gli manca qualcosa, e
## non gli manca niente: ha un gioco meno sorprendente, che è un'altra cosa.
## La casella comparirà il giorno in cui il modello c'è, sotto
## `if Llm.disponibile() and Llm.percorso_modello() != ""`, e sarà una riga:
## il bit che governa **esiste già** (`Settings.llm_spento`, persistito), e
## la porta è già questa. Non c'è niente da rifare, c'è solo da mostrarla.
##
## `CHIBI_LLM=0` spegne tutto anche dai banchi: serve alle misure appaiate
## (lo stesso villaggio, con e senza), che sono l'unico modo di dimostrare
## «identico» invece di dichiararlo.
static func acceso() -> bool:
	if not disponibile():
		return false
	if OS.get_environment("CHIBI_LLM") == "0":
		return false
	if spento_da_chi_gioca():
		return false
	return percorso_modello() != ""


## Il bit del giocatore, letto da dove vivono le sue preferenze. Difensivo
## apposta: un salvataggio delle impostazioni scritto da una versione più
## vecchia non ha quella chiave, e «non lo so» non deve diventare «spento».
static func spento_da_chi_gioca() -> bool:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return false
	var s: Node = (loop as SceneTree).root.get_node_or_null("/root/Settings")
	if s == null:
		return false
	return bool(s.get("llm_spento"))
