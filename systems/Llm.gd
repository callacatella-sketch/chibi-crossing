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
