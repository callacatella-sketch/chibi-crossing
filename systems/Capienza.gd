class_name Capienza
extends RefCounted

## CI STA? — la domanda che si fa PRIMA di chiedere due gigabyte e mezzo.
##
## Dal 2026-08-13 il modello non viaggia più dentro il pacchetto: si scarica
## al primo uso, quando chi gioca accende la funzione. Il gioco resta piccolo
## per tutti, e chi non la userà mai non paga niente.
##
## Ma un download da 2,3 GB è una cosa che si CHIEDE, e chiederla a una
## macchina che poi non riuscirà ad aprire il modello è la cosa peggiore che
## questa fase possa fare: mezz'ora di rete, due gigabyte e mezzo di disco, e
## alla fine il villaggio non pensa lo stesso — senza che chi gioca possa
## collegare le due cose. **La domanda si fa prima, e se la risposta è no non
## si offre niente.**
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ QUESTO FILE È PURO (e non sta dentro la schermata)
## ────────────────────────────────────────────────────────────────────────
##
## Perché è l'unica parte del flusso che si può interrogare senza una rete,
## senza un disco e senza due gigabyte di pesi: si passano quattro numeri e
## si guarda cosa risponde. La schermata, sopra, non decide niente — sceglie
## solo quale pagina mostrare. Un verdetto scritto dentro un `if` in mezzo a
## una `_build()` sarebbe verificabile solo costruendo l'intero pannello su
## una macchina con la RAM giusta, cioè non sarebbe verificabile.
##
## ⚠️ **I NUMERI NON SONO SUOI, E NON DEVONO DIVENTARLO.** `serve` arriva da
## `Llm.RAM_MODELLO` (quanto chiede il modello che offriamo); il tetto, la
## riserva e la memoria della macchina arrivano dal binario, e chi li chiede è
## la schermata (`OffertaModello._numeri_macchina`). Ricopiarne uno qui
## vorrebbe dire un secondo tetto — l'errore che il ponte del cuore C++ esiste
## apposta per non ripetere.
##
## ────────────────────────────────────────────────────────────────────────
## LE TRE RISPOSTE, E PERCHÉ SONO TRE E NON DUE
## ────────────────────────────────────────────────────────────────────────
##
## «Non ci sta» detto a chi ha un computer grande ma in quel momento pieno di
## finestre aperte è una **bugia permanente su una cosa temporanea**: quella
## persona chiude il browser, torna, e il gioco continua a dirle di no perché
## nessuno le ha detto che poteva riprovare. Al contrario, dire «riprova più
## tardi» a chi ha una macchina che non ce la farà **mai** è una presa in
## giro gentile che costa tempo a chi non ha niente da guadagnarci.
##
##  · `"ci_sta"`    — adesso c'è la memoria. Si può offrire.
##  · `"adesso_no"` — la macchina è grande abbastanza, ma in questo momento è
##                    occupata. Si dice, e si offre di riprovare.
##  · `"mai"`       — la macchina, tutta intera, è più piccola di quel che
##                    serve: chiudere qualcosa non può bastare. Si dice, e
##                    non si offre niente.
##  · `"non_lo_so"` — la piattaforma non sa rispondere (vedi `llm_memoria.h`:
##                    zero vuol dire «non lo so»). **E «non lo so» non è mai
##                    un no**: si offre lo stesso. Spegnere una funzione per
##                    un numero che non abbiamo sarebbe il degrado dalla
##                    parte sbagliata.
##
## Le stringhe sono la risposta, come i gradini di `Animo.SCALA`: si
## confrontano per nome e non per indice, così inserirne una in mezzo non
## sposta niente.

## I quattro verdetti, per nome. Chi ne aggiunge uno deve dire anche se «si
## può offrire» (sotto): un verdetto senza quella riga passerebbe per un sì.
const VERDETTI := ["ci_sta", "adesso_no", "mai", "non_lo_so"]

## Quelli che NON permettono di offrire il download. È l'unica riga che
## trasforma un verdetto in una decisione, ed è per questo che sta qui e non
## nella schermata: la schermata sceglie le parole, non la politica.
const VERDETTI_NO := ["adesso_no", "mai"]


## IL VERDETTO SULLA MEMORIA. Tutti e quattro i numeri in byte.
##
##  · `totale`  — la RAM della macchina (`memoria()["totale_sistema"]`)
##  · `libera`  — quella libera adesso (`memoria()["libera_sistema"]`)
##  · `serve`   — quanto chiederà il modello (`Llm.RAM_MODELLO`)
##  · `riserva` — quanto deve restare al gioco (`limiti()["riserva_byte"]`)
##  · `tetto`   — il tetto di RAM dell'autore (`limiti()["tetto_byte"]`), 0 =
##                nessun tetto
##
## ⚠️ **LA REGOLA È LA STESSA DEL C++, NON UNA SUA APPROSSIMAZIONE.**
## `Traduttore::_carica` rifiuta se `serve > tetto` e poi se
## `serve + riserva > libera`: qui si fanno le stesse due domande, con gli
## stessi numeri, solo **prima** — quando la risposta può ancora risparmiare
## a qualcuno mezz'ora di rete. Se un giorno il C++ cambiasse quella regola e
## questo file no, il guasto sarebbe muto e nella direzione peggiore: si
## offrirebbe un download che il portiere poi rifiuta. La guardia è
## `test_capienza._la_stessa_regola_del_cuore`, che confronta i due verdetti
## sugli stessi numeri.
static func della_memoria(totale: int, libera: int, serve: int, riserva: int,
		tetto: int) -> String:
	# IL TETTO PRIMA DI TUTTO, come nel C++: è una proprietà del modello che
	# offriamo, non della macchina di chi gioca. Se ci finiamo dentro è un
	# nostro sbaglio di scelta del modello — ma il rimedio, per chi sta
	# davanti allo schermo, è comunque «non c'è niente da scaricare».
	if tetto > 0 and serve > tetto:
		return "mai"
	# ZERO = «NON LO SO», su tutte e due le righe (llm_memoria.h). Le due
	# domande sono separate apposta: macOS e Linux sanno rispondere a
	# entrambe, ma una piattaforma futura potrebbe saperne solo una, e una
	# risposta che c'è non deve essere buttata con quella che manca.
	if totale > 0 and totale < serve + riserva:
		return "mai"
	if libera > 0 and libera < serve + riserva:
		return "adesso_no"
	if totale <= 0 and libera <= 0:
		return "non_lo_so"
	return "ci_sta"


## SI PUÒ OFFRIRE IL DOWNLOAD? La riga che trasforma un verdetto in un sì.
static func si_puo_offrire(verdetto: String) -> bool:
	return not VERDETTI_NO.has(verdetto)


# =========================================================================
# COME SI DICONO I NUMERI A UNA PERSONA
# =========================================================================

## «2,3 GB». Un decimale e basta: la seconda cifra non aggiunge niente a
## nessuno, e mezzo gigabyte in più o in meno non cambia nessuna decisione.
##
## ⚠️ **E DEVE DIRE LA STESSA COSA DI `Scarico.misura_umana()`.** Sono due
## funzioni perché sono nate in due posti (questa la usano la schermata che
## chiede e le Note legali, quella la usa il corriere per la riga sotto la
## barra) — ma compaiono **nella stessa pagina, a tre centimetri di
## distanza**: la scheda dice quanto pesa e la barra dice a che punto siamo.
## Se una contasse in gigabyte da 1000 e l'altra in gigabyte da 1024, il
## giocatore leggerebbe «2,5 GB» sopra e «… di 2,3 GB» sotto, e avrebbe
## ragione a non fidarsi di nessuno dei due.
##
## Perciò qui si conta **in gibibyte**, come il corriere e come tutto il
## resto del gioco (il C++ divide per 1024·1024 dappertutto). Il prezzo è
## dichiarato: il browser di chi gioca gli dirà 2,49 GB dove noi diciamo 2,3
## — un file più GRANDE di quello che avevamo promesso, che è il verso
## giusto dell'errore. Un'asserzione in `test_offerta_modello` tiene le due
## funzioni legate; la strada giusta, il giorno che qualcuno rimette mano a
## questa fase, è farne sparire una.
static func in_giga(byte: int) -> String:
	return "%s GB" % numero(float(byte) / float(1024 * 1024 * 1024), 1)


## Un numero con la virgola dove va la virgola. L'italiano scrive «2,3», e
## `String.num()` scrive sempre «2.3»: è la stessa distinzione fra dato e
## presentazione che vale per le frasi, applicata alle cifre.
##
## La lingua si chiede a `L10n`, che è la sua casa. Non si passa da fuori:
## un chiamante che se la dimenticasse produrrebbe un punto dentro una frase
## italiana, e nessun test di localizzazione lo vedrebbe (i numeri non stanno
## in tabella).
static func numero(v: float, decimali: int) -> String:
	var s := String.num(v, decimali)
	return s.replace(".", ",") if L10n.lingua_corrente() == L10n.SORGENTE else s


## QUANTO MANCA, detto come lo direbbe una persona. Mai i secondi esatti:
## una stima al secondo su un download da mezz'ora è una precisione finta
## che si smentisce da sola ogni volta che la rete respira.
##
## Torna una **chiave** e i suoi argomenti (`{"k":…, "args":[…]}`), non una
## frase: è la «frase rimandata» di `L10n.rendi()`. Qui non serve perché
## non passa da nessun salvataggio — serve perché così la funzione resta
## PURA e la si può interrogare senza una tabella di traduzione caricata.
static func quanto_manca(byte_rimasti: int, byte_al_secondo: float) -> Dictionary:
	if byte_al_secondo <= 0.0 or byte_rimasti <= 0:
		return {"k": "ancora un momento", "args": []}
	var secondi := float(byte_rimasti) / byte_al_secondo
	if secondi < 90.0:
		return {"k": "meno di un minuto", "args": []}
	var minuti := int(round(secondi / 60.0))
	if minuti <= 1:
		return {"k": "un minuto circa", "args": []}
	if minuti < 60:
		return {"k": "circa %d minuti", "args": [minuti]}
	var ore := int(round(secondi / 3600.0))
	if ore <= 1:
		return {"k": "circa un'ora", "args": []}
	return {"k": "più di %d ore", "args": [ore - 1]}


## LA VELOCITÀ, in gigabyte al secondo? No: in mega**bit**, che è l'unità in
## cui una persona conosce la propria linea («ho trenta mega»). È l'unico
## posto del gioco in cui si nomina una misura tecnica, e si nomina proprio
## per farsi riconoscere.
##
static func velocita(byte_al_secondo: float) -> String:
	var mbit := byte_al_secondo * 8.0 / 1000000.0
	return "%s Mbit/s" % numero(mbit, 1 if mbit < 10.0 else 0)
