extends RefCounted
## LO SCHEMA DEL SÉ: quale ricordo si sacrifica quando la memoria è piena.
##
## Tutte funzioni `static`, pure, senza stato e senza albero della scena.
##
## ⚠️ PERCHÉ ESISTE. `Animo._potatura` era un FIFO: oltre quaranta ricordi
## vivi si faceva `pop_front()`, e la memoria autobiografica di un vicino
## era ordinata solo dal tempo. La memoria umana non fa così — le memorie
## AUTO-DEFINENTI resistono in modo sproporzionato, ed è quell'asimmetria
## a rendere il ricordo una prova dell'identità invece che un registro.
##
## E qui non è cosmetico, perché `Animo.cause()` ha DUE passate che
## leggono cose diverse: i compiti ripetuti li conta dai ricordi vivi **e
## dal sommario** (quindi «taglia_legna × 47» sopravvive alla potatura),
## ma i **colpi singoli che hanno lasciato il segno** li cerca solo fra i
## ricordi VIVI. Il FIFO cancellava perciò esattamente gli episodi UNICI
## e conservava quelli frequenti: col tempo ogni vicino finiva per saper
## dire soltanto la cosa che il giocatore fa più spesso. È convergenza, e
## non è un'ipotesi — è l'aritmetica di come `cause()` è scritta.
##
## La forma da imitare era già in casa, e in DUE posti: `Legami.costo`
## (costo-di-perdita, intoccabili, e `-1` = si sfora invece di buttare) e
## `src/grafo_ricordi.h`, che pota già per PESO e non per età. Il FIFO di
## `Animo` era l'anomalia.
##
## ═══ IL CANCELLO, e non è una regola: è la FIRMA
##
## **La congruenza si misura sul SOGNO e sul TIPO DI GESTO, mai
## sull'ATTORE.** Si può proteggere «cosa mi è successo», non «chi me
## l'ha fatto — altrimenti un vicino diventa un archivio di rancori, cioè
## un villaggio che tiene il conto. E la chiave del sommario è
## letteralmente `"tipo|attore"`: una congruenza che pesasse l'attore
## proteggerebbe *per costruzione* le righe di quella persona, e
## `rancore()`, `cause()` e `quante_volte()` leggono tutti e tre per
## attore. Sarebbe la gogna dalla porta di servizio.
##
## Perciò il cancello **non è rispettato, è impossibile da violare**:
## `scheda()` costruisce una vista del ricordo SENZA il campo `attore`, e
## `costo()` riceve solo quelle. La funzione non può pesare l'attore
## nemmeno per sbaglio, perché non ce l'ha.
##
## ═══ E LA CONGRUENZA NON È LA VALENZA
##
## Auto-definente non vuol dire «bello». `COMPITI[tipo]` dice già `serve`
## (il sogno che quel compito realizza) e `tradisce` (i sogni che
## contraddice), e **tutti e due gli estremi dicono chi sei**: il giorno
## in cui ho fatto la cosa che sognavo, e il giorno in cui mi è stato
## chiesto il contrario. Pesare solo i primi darebbe un diario rosa;
## pesare solo i secondi, un archivio di torti. Si pesa il VALORE
## ASSOLUTO dell'allineamento — ed è per questo che questa potatura non
## può diventare né l'uno né l'altro.
##
## ═══ ⚠️ E L'IMMUNITÀ DELLA FERITA HA UNA CHIAVE, A FORMA DI GIOCATORE
##
## `intoccabile()` protegge il PRIMO episodio della sua specie che parla
## di me. Preso alla lettera vuol dire che **la prima volta che a un
## vicino è stato chiesto il contrario di quello che sogna diventava
## PERMANENTE**: nessuna potatura la toccava più per il resto della
## partita, `cause()` e `sfogo()` potevano citarla al confronto fra sei
## mesi, e non esisteva nessun gesto che la cancellasse — mentre il lutto
## di un amico, la nascita di un cucciolo o il primo regalo di un altro
## vicino (congruenza 0) restavano tutti potabili.
##
## È lo «stato permanente la cui unica chiave non è in mano al giocatore»
## che la **regola 1 degli Affetti** vieta per iscritto — *«nessuno stato
## permanente la cui unica chiave sia in mano a un altro»* — e per giunta
## intestato a un gesto suo: è lui che assegna i compiti dalla Lavagna.
##
## Perciò l'immunità di una ferita **DECADE quando il giocatore ha
## prodotto la controprova**: una riga che TRADISCE il sogno smette di
## essere intoccabile appena esiste, fra le schede vive, almeno una riga
## che quel sogno lo SERVE. Il gesto che la apre esiste già ed è leggere
## il sogno di qualcuno e dargli quel lavoro — lo stesso su cui
## `Animo.esegue` scrive l'unica valenza POSITIVA dei compiti (`+0.12`) e
## su cui `Deriva.SOGNO` fa muovere l'ambizione.
##
## ⚠️ E la chiave esiste per OGNI vicino, non per i fortunati: i sette
## `Animo.SOGNI` hanno tutti e sette un compito che li serve (boscaiolo →
## `taglia_legna`, artista → `suona`, estetista → `abbellisce`…). Se un
## giorno si aggiungesse un sogno senza il suo compito, quel vicino
## tornerebbe ad avere una ferita senza chiave — e nessun test se ne
## accorgerebbe da qui.
##
## Tre cose che questa forma regala, e che una taratura non darebbe:
##  · **non è un'amnistia.** La riga potata finisce nel sommario come
##    tutte le altre, quindi `cause()` continua a dire «taglia_legna ×
##    40»: decade la CITABILITÀ come episodio, non il conto. È la stessa
##    distinzione che `Animo._potatura` dichiara già;
##  · **la controprova non evapora.** La prima riga che serve il sogno è
##    intoccabile a sua volta (è la prima della sua specie), quindi
##    finché quella memoria è viva la porta resta aperta;
##  · **la ferita non viene cancellata: viene resa MORTALE.** Torna a
##    costare come tutte le altre, e se è ancora l'episodio più definente
##    che quel vicino ha, sopravvive lo stesso — per merito e non per
##    privilegio.
##
## ⚠️ **E IL VERSO NON ARRIVA DALL'ATTORE.** Distinguere `serve` da
## `tradisce` — che `congruenza()` fonde apposta nel valore assoluto —
## chiedeva un campo nuovo, e la tentazione era guardare CHI ha ordinato
## il compito. Il campo è `verso` (+1 / −1 / 0) e si ricava dal SOGNO e
## dal TIPO come la congruenza: il cancello qui sopra resta impossibile
## da violare, perché nella scheda l'attore continua a non esserci.

## Quanto pesa la SOMIGLIANZA COL SÉ. È il termine più grande, ed è il
## punto di tutta la meccanica: le memorie auto-definenti resistono in
## modo SPROPORZIONATO. Con un peso pari agli altri non resisterebbero
## affatto, e la potatura sarebbe un FIFO con del rumore sopra.
const PESO_SCHEMA := 1.6
## Quanto pesa essere l'unico della sua specie. È la `rarità` di
## `Legami.costo` (4/n) riportata su questa scala: l'unico litigio vale
## più della quarantesima legna spaccata, ed è questo termine a produrre
## la DIVERGENZA fra vicini. ⚠️ E la congruenza gli si MOLTIPLICA (vedi
## `costo`): un ricordo che dice chi sei è un episodio singolo, non una
## routine ripetuta quaranta volte.
const PESO_DISTINTIVO := 1.0
## Quanto pesa la botta: |valenza| × intensità. Un fatto tiepido si
## dimentica anche se è unico.
const PESO_FORZA := 0.8
## Quanto pesa essere recente. ⚠️ È il termine che il FIFO aveva, e resta:
## a parità di tutto il resto se ne va il più vecchio, che è la cosa
## giusta. Quello che cambia è che adesso può essere SCAVALCATO.
const PESO_ANZIANITA := 1.0


## LA SCHEDA di un ricordo: quello che la potatura ha il diritto di
## sapere. Nessun `attore`, e non per disciplina — perché la funzione che
## sceglie riceve queste e nient'altro.
##
## `compiti` è la tabella `Animo.COMPITI`, passata come DATO: la legge di
## quali sogni un compito serve o tradisce vive lì, e ricopiarla qui
## sarebbe la tabella gemella che questo progetto vieta.
##
## ⚠️ `verso` sta ACCANTO a `congruenza`, non al suo posto: la potatura
## continua a pesare il valore assoluto (nessun diario rosa, nessun
## libro dei torti), e il segno lo guarda **soltanto** `intoccabile()`,
## per sapere quale delle due prove ha bisogno di una chiave.
static func scheda(r: Dictionary, sogno: String, compiti: Dictionary) -> Dictionary:
	var tipo := str(r.get("tipo", ""))
	var v := verso(tipo, sogno, compiti)
	return {
		"tipo": tipo,
		"quando": int(r.get("quando", 0)),
		"valenza": float(r.get("valenza", 0.0)),
		"intensita": float(r.get("intensita", 0.5)),
		# ⚠️ **UNA RICERCA SOLA, non due.** `congruenza()` è il MODULO di
		# `verso()`, quindi chiamarle tutte e due qui vorrebbe dire due
		# ricerche in `COMPITI` per ogni ricordo — e questa funzione gira
		# per ogni ricordo vivo a ogni potatura. Si chiede il verso una
		# volta e si deriva il modulo.
		"congruenza": absf(float(v)),
		"verso": v,
	}


## DA CHE PARTE STA questo fatto rispetto a chi voglio essere:
## **+1** l'ho fatto (il compito SERVE il sogno) · **−1** mi è stato
## chiesto il contrario (lo TRADISCE) · **0** col mio sogno non c'entra.
##
## ⚠️ SUL SOGNO E SUL TIPO, MAI SULL'ATTORE — esattamente come la
## congruenza, di cui questo è il segno. Ricavarlo da chi ha ordinato il
## compito sarebbe la gogna dalla porta di servizio (vedi il cancello in
## testa al file), ed è per questo che la firma è identica a quella di
## `congruenza()`: non riceve il ricordo, riceve solo il tipo.
static func verso(tipo: String, sogno: String, compiti: Dictionary) -> int:
	if sogno == "" or tipo == "":
		return 0
	var c: Dictionary = compiti.get(tipo, {})
	if c.is_empty():
		return 0
	if str(c.get("serve", "")) == sogno:
		return 1
	if sogno in (c.get("tradisce", []) as Array):
		return -1
	return 0


## QUANTO QUESTO FATTO PARLA DI ME, 0..1. Sul tipo di gesto e sul sogno,
## mai su chi l'ha fatto.
##
## ⚠️ VALORE ASSOLUTO dell'allineamento: `serve` e `tradisce` valgono
## uguale. Un ricordo che realizza il sogno e uno che lo contraddice sono
## tutti e due prove dell'identità — e pesarne uno solo trasformerebbe la
## memoria in un diario rosa o in un libro dei torti.
##
## ⚠️ E la frase qui sopra è scritta in aritmetica invece che in un
## commento: la congruenza **è** il modulo di `verso()`. Con due tabelle
## di ricerca gemelle, il giorno che qualcuno aggiunge una terza
## relazione a `COMPITI` le due funzioni divergerebbero in silenzio — e a
## divergere sarebbe proprio il cancello dell'immunità.
static func congruenza(tipo: String, sogno: String, compiti: Dictionary) -> float:
	return absf(float(verso(tipo, sogno, compiti)))


## QUANTO COSTA PERDERE la scheda `i`. Più basso = più sacrificabile.
## Quattro voci, e ognuna risponde a «cosa succederebbe senza»:
##  · SCHEMA — senza, resta un FIFO col rumore, e i vicini convergono;
##  · DISTINTIVO — senza, la quarantesima legna vale quanto l'unico
##    litigio, e sopravvive la routine invece della biografia;
##  · FORZA — senza, un fatto tiepido ma unico scaccia una botta vera;
##  · ANZIANITÀ — senza, la memoria si fossilizza sul primo mese e non
##    entra più niente di nuovo.
static func costo(schede: Array, i: int, oggi: int, mezza_vita: float) -> float:
	if i < 0 or i >= schede.size():
		return INF
	var s: Dictionary = schede[i]
	var tipo := str(s.get("tipo", ""))
	var quanti := 0
	for k in schede:
		if str((k as Dictionary).get("tipo", "")) == tipo:
			quanti += 1
	var recente := pow(0.5, float(oggi - int(s.get("quando", 0)))
			/ maxf(mezza_vita, 0.001))
	var forza: float = absf(float(s.get("valenza", 0.0))) \
			* clampf(float(s.get("intensita", 0.5)), 0.0, 1.0)
	# ⚠️ LA CONGRUENZA MOLTIPLICA LA RARITÀ, non ci si somma. La
	# quarantesima volta che mi è stato chiesto il contrario di quello che
	# sogno NON è quaranta volte più definente della prima: quel conto lo
	# tiene già il sommario, e `cause()` lo dice col numero in chiaro
	# («taglia_legna × 40, e lui sognava di fare il guerriero»). Un
	# ricordo auto-definente è un EPISODIO SINGOLO E VIVIDO, e la
	# divisione per `quanti` è quella frase scritta in aritmetica.
	#
	# Senza, quaranta righe identiche portavano 1.6 ciascuna e
	# scacciavano il lutto di un amico: lo scenario del brief — «si è
	# ribellato perché l'ho mandato a tagliare legna quaranta giorni e ho
	# ignorato la morte del suo amico» — perdeva per strada la seconda
	# metà. L'ha trovato `test_animo`, non una rilettura.
	return PESO_ANZIANITA * recente \
			+ PESO_FORZA * forza \
			+ (PESO_DISTINTIVO
					+ PESO_SCHEMA * float(s.get("congruenza", 0.0))) \
					/ float(maxi(quanti, 1))


## C'È, FRA QUESTE SCHEDE, UNA VOLTA IN CUI IL MIO SOGNO È STATO SERVITO?
## È la controprova del giocatore, e apre l'unica porta di questo file
## (vedi `intoccabile`).
##
## ⚠️ SI GUARDANO LE SCHEDE VIVE, non il sommario, ed è voluto: la porta
## la tiene aperta un EPISODIO che quel vicino sa ancora raccontare, non
## un contatore. Ed è più solido di come sembra — la prima riga che serve
## il sogno è intoccabile a sua volta (è la prima della sua specie),
## quindi una volta prodotta la controprova non se ne va da sola.
static func controprova(schede: Array) -> bool:
	for k in schede:
		if int((k as Dictionary).get("verso", 0)) > 0:
			return true
	return false


## CHI NON SI TOCCA. Il PRIMO della sua specie che parla di me: la prima
## volta che mi è stato chiesto il contrario di quello che sogno, o la
## prima volta che ho fatto la cosa che sognavo.
##
## ⚠️ È un insieme piccolo per costruzione — al più uno per tipo di
## compito, cioè una dozzina contro quaranta ricordi vivi: non può
## bloccare la potatura. Ma la valvola di `Legami` resta, e per la stessa
## ragione: meglio sforare di uno che buttare un ricordo insostituibile.
##
## ⚠️ **E L'IMMUNITÀ DELLA FERITA DECADE ALLA CONTROPROVA** (la testata,
## sezione «l'immunità della ferita ha una chiave»): senza questa riga la
## prima volta che a un vicino è stato chiesto il contrario del suo sogno
## era permanente per tutta la partita, ed era uno stato permanente senza
## una chiave a forma di giocatore — la regola 1 degli Affetti.
## Il verso positivo NON decade, e non è una svista: quella non è una
## ferita, è il giorno in cui qualcuno mi ha dato la cosa che sognavo, e
## togliergliela vorrebbe dire che un gesto buono del giocatore si
## consuma da sé.
##
## ⚠️ Una scheda SENZA `verso` (i banchi che se le fabbricano a mano) si
## comporta come prima: se il verso non lo sappiamo non si toglie
## un'immunità, e il degrado va dove va sempre — verso il comportamento
## che c'era già.
static func intoccabile(schede: Array, i: int) -> bool:
	if i < 0 or i >= schede.size():
		return true
	var s: Dictionary = schede[i]
	if float(s.get("congruenza", 0.0)) <= 0.0:
		return false
	if int(s.get("verso", 0)) < 0 and controprova(schede):
		return false
	var tipo := str(s.get("tipo", ""))
	for j in i:
		if str((schede[j] as Dictionary).get("tipo", "")) == tipo \
				and float((schede[j] as Dictionary).get("congruenza", 0.0)) > 0.0:
			return false
	return true


## L'indice del ricordo che costa meno perdere, o -1 se è tutto
## intoccabile (e allora si sfora, come fa il filo dei Legami).
static func indice_da_sacrificare(schede: Array, oggi: int,
		mezza_vita: float) -> int:
	var scelto := -1
	var minimo := INF
	for i in schede.size():
		if intoccabile(schede, i):
			continue
		var c := costo(schede, i, oggi, mezza_vita)
		if c < minimo:
			minimo = c
			scelto = i
	return scelto
