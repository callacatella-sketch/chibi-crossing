extends RefCounted

## LA RILETTURA — il secondo modo di regolare un'emozione, e l'unico che
## non costa niente a chi lo usa.
##
## Il villaggio ne aveva UNO solo, ed è la SOPPRESSIONE (`Limbico.trattieni`):
## l'impulso arriva intero, e ci si morde la lingua. Costa `regolazione`, che
## è finita, alza il cortisolo, e prima o poi qualcosa esce di sbieco — «è
## così che si scoppia per una sciocchezza», dice la testata di
## `Visitors._tick_confronti`.
##
## Ma prima di doversi trattenere c'è un momento in cui l'emozione non è
## ancora tutta lì, e in quel momento si può fare l'altra cosa: **rileggere**.
## «Non ce l'aveva con me», «era di fretta», «una volta mi ha portato da
## mangiare». Non è forza di volontà — è che il fatto, riletto, pesa meno.
##
## Qui vive la parte PURA e statica: cosa rende una rilettura possibile, e
## quanto vale. **Ad applicarla non è nessuno** — rileggere è NON pagare, e
## il modulo non scrive un bit; il materiale delle `attese` lo legge
## nessuno, e a decidere è `Animo.regola`. Chi la chiede è
## `Visitors._tick_confronti`, nello stesso identico punto in cui oggi si
## chiede di trattenersi. Questo file non conosce Godot, non tiene stato, e
## non tira un solo dado.
##
## ────────────────────────────────────────────────────────────────────────
## LE QUATTRO REGOLE, e nessuna è una taratura
## ────────────────────────────────────────────────────────────────────────
##
## **1 · LA DISPONIBILITÀ NON SI TIRA A DADI: È UNA PROVA NEL GRAFO.**
## Non c'è nessun `randf()` in questo file e non ce ne può essere uno: la
## stessa storia dà sempre la stessa risposta. Una rilettura è possibile
## quando esiste, fra i ricordi vivi di quel vicino, abbastanza materiale
## che REGGE una lettura più benevola — e quel materiale ce l'ha messo il
## giocatore.
##
## **2 · SI GUARDA SOLO LA PROVA CHE ASSOLVE, MAI QUELLA CHE ACCUSA.**
## `peso_prova()` torna `maxf(0.0, valenza) · …`: una riga ostile contribuisce
## **zero**, e non «poco» — zero. E l'uscita di tutto il modulo è una `quota`
## in 0..1 che può solo TOGLIERE dal torto, mai aggiungerci. Due clamp, tutti
## e due a senso unico, e il modulo è **monotòno nella direzione giusta e
## cieco all'altra**.
##
## ⚠️ **E QUI L'ATTORE SI GUARDA, mentre in `Schema.gd` è vietato per
## iscritto.** Non è un'incoerenza, è la stessa regola applicata: là si
## decideva **quali ricordi sopravvivono**, e proteggerli per attore avrebbe
## costruito un archivio di rancori. Qui si decide **quanto un torto pesa**, e
## siccome il segno è fissato nel codice (solo `valenza > 0`), un indice per
## attore può soltanto SCIOGLIERE un rancore: è strutturalmente incapace di
## costruirne uno. La differenza non la tiene un commento — la tiene il
## `maxf(0.0, …)`, e un caso di test le passa un mucchio di righe ostili
## pretendendo la stessa identica risposta di zero righe.
##
## **3 · NON È UN TRATTO.** In tutto il file non compare nessun nome di
## carattere, e le firme non hanno un posto in cui infilarcelo. Due vicini
## con lo stesso identico carattere rileggono in modo diverso perché il
## giocatore li ha trattati in modo diverso — e lo stesso vicino rilegge oggi
## e si morde la lingua domani, se nel frattempo le prove sono invecchiate.
## «È uno che rivaluta» è una frase che questo gioco non può dire di nessuno.
##
## **4 · UNA RILETTURA NON CANCELLA IL FATTO — e non lo cancella perché non
## lo TOCCA.** Questo modulo non scrive niente e non ha un effetto durevole:
## il torto resta intero nel libro mastro, il ricordo resta come è, le attese
## non si spostano di un bit. Quello che cambia è soltanto che quel vicino
## **non ha dovuto pagare** per tenerselo dentro.
##
## ⚠️ **La prima stesura invece rialzava le `attese` verso quella persona**,
## col ragionamento che «chi rilegge si rimette a sperare, e in questo motore
## un'attesa più alta è una lama più affilata». Suonava bene ed era una
## trappola per chi era stato gentile: le chiavi dei DONI stanno già sopra la
## media (è l'abitudine di `rivaluta`) e non si muovevano, quindi a salire
## erano solo quelle dei COMPITI — cioè lo stesso identico incarico si
## incideva peggio a chi ti aveva portato da mangiare per una settimana.
## L'ha trovata una revisione avversariale, e la cura non è tararla: è che il
## guadagno di una rilettura non deve avere un costo da nessuna parte.
##
## Il torto dev'essere almeno questo, o non c'è niente da rileggere — e serve
## soprattutto a non dividere per un denominatore che tende a zero, che è il
## modo classico di fabbricare un infinito e leggerlo come «rilettura sempre
## disponibile».
##
## ⚠️ **E NON È LA `SOGLIA_SORPRESA` DEL LIMBICO, anche se il numero è lo
## stesso.** Ci ho provato, ed era una fonte unica FINTA: quella misura una
## *sorpresa* in −1..1, questa misura un *torto accumulato* sulla scala di
## `Animo.conto_verso`, dove un ricordo brutto a piena forza vale ~1.0 e
## `SATURAZIONE` è 55. Due grandezze diverse che indossano lo stesso numero
## sono peggio di due numeri: il giorno che qualcuno tara l'una, l'altra si
## sposta senza che nessuno l'abbia chiesto. Qui 0,08 vuol dire «meno di un
## decimo di un solo ricordo brutto», e lo vuol dire da sé.
const TORTO_MIN := 0.08

## Quante prove servono PER UNITÀ DI TORTO. Sotto, la rilettura non c'è.
## Non è una soglia sulla quantità di gentilezza in assoluto: è un RAPPORTO,
## ed è questo a rendere impossibile la lavanderia — un torto grosso vuole
## proporzionalmente più passato per essere riletto. Una gentilezza sola
## (valenza 0,5 · intensità 0,6 → 0,30) contro un torto da 0,7 fa 0,43: non
## basta, ed è giusto che non basti.
const RAPPORTO_MIN := 0.50


## IL PESO DI UNA PROVA CHE ASSOLVE. È la regola 2 scritta in aritmetica: il
## `maxf` in testa è il motivo per cui questo modulo non può accusare
## nessuno, e va letto come una guardia, non come una formattazione.
static func peso_prova(valenza: float, intensita: float, recenza: float) -> float:
	if not is_finite(valenza) or not is_finite(intensita) or not is_finite(recenza):
		return 0.0
	return maxf(0.0, valenza) * clampf(intensita, 0.0, 1.0) * maxf(0.0, recenza)


## Quante prove ci sono per unità di torto. Torna 0 se non c'è torto: un
## rapporto su un denominatore che tende a zero è il modo classico di
## fabbricare un infinito che poi si legge come «rilettura sempre
## disponibile».
static func rapporto(torto: float, prove: float, torto_min := TORTO_MIN) -> float:
	if not is_finite(torto) or not is_finite(prove):
		return 0.0
	if torto < torto_min:
		return 0.0
	return maxf(0.0, prove) / torto


## C'È DI CHE RILEGGERE? Nessun dado, nessun tratto: il rapporto, e basta.
##
## ⚠️⚠️ **E LE `attese` NON CI SONO, anche se il brief le dava come materiale
## insieme ai ricordi. Ci ho provato, e non ne esce una condizione.**
##
## L'idea era: chi si aspetta già esattamente quello che ha ricevuto non ha
## una lettura alternativa da trovare — ha un fatto, e i fatti si tengono.
## Si era scritta come `Limbico.divario`, il massimo di `media_prove − attesa`
## sulle chiavi `tipo|attore` di quella persona. Una revisione avversariale ha
## mostrato che è **aperta per costruzione**: chi arriva qui ha per forza un
## torto ripetuto (il ramo di `_tick_confronti` vuole gradino ≥ «svogliato»),
## e quel torto ha già scritto un'attesa NEGATIVA — quattro «ignorato» a −0,8
## con `ABITUDINE` 0,30 lasciano ≈ −0,60, quindi il divario valeva ≈ 0,60
## anche per chi non ha una sola prova buona.
##
## E la lettura opposta — il divario sulle sole chiavi delle PROVE — si chiude
## **sempre**, perché l'abitudine di `rivaluta` porta proprio quelle al
## livello delle prove. Un cancello che non può chiudersi e uno che non può
## aprirsi non sono due tarature diverse della stessa idea: sono la stessa
## idea che non dice niente. Si toglie, come si fa qui con ogni guardia che
## nessun test può far fallire — e si scrive che metà del materiale del brief
## non ha prodotto una condizione, invece di lasciare in piedi una firma che
## sembra severa e non lo è.
static func disponibile(torto: float, prove: float,
		torto_min := TORTO_MIN) -> bool:
	return rapporto(torto, prove, torto_min) >= RAPPORTO_MIN


## LA SCHEDA COMPLETA, per chi la deve applicare e per chi la deve misurare.
## `{"riletto", "rapporto"}` — e `riletto` è l'unica cosa che il chiamante
## deve guardare per decidere se saltare il morso della lingua.
static func scheda(torto: float, prove: float,
		torto_min := TORTO_MIN) -> Dictionary:
	return {"riletto": disponibile(torto, prove, torto_min),
			"rapporto": rapporto(torto, prove, torto_min)}
