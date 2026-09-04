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
static func scheda(r: Dictionary, sogno: String, compiti: Dictionary) -> Dictionary:
	var tipo := str(r.get("tipo", ""))
	return {
		"tipo": tipo,
		"quando": int(r.get("quando", 0)),
		"valenza": float(r.get("valenza", 0.0)),
		"intensita": float(r.get("intensita", 0.5)),
		"congruenza": congruenza(tipo, sogno, compiti),
	}


## QUANTO QUESTO FATTO PARLA DI ME, 0..1. Sul tipo di gesto e sul sogno,
## mai su chi l'ha fatto.
##
## ⚠️ VALORE ASSOLUTO dell'allineamento: `serve` e `tradisce` valgono
## uguale. Un ricordo che realizza il sogno e uno che lo contraddice sono
## tutti e due prove dell'identità — e pesarne uno solo trasformerebbe la
## memoria in un diario rosa o in un libro dei torti.
static func congruenza(tipo: String, sogno: String, compiti: Dictionary) -> float:
	if sogno == "" or tipo == "":
		return 0.0
	var c: Dictionary = compiti.get(tipo, {})
	if c.is_empty():
		return 0.0
	if str(c.get("serve", "")) == sogno:
		return 1.0
	if sogno in (c.get("tradisce", []) as Array):
		return 1.0
	return 0.0


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


## CHI NON SI TOCCA. Il PRIMO della sua specie che parla di me: la prima
## volta che mi è stato chiesto il contrario di quello che sogno, o la
## prima volta che ho fatto la cosa che sognavo.
##
## ⚠️ È un insieme piccolo per costruzione — al più uno per tipo di
## compito, cioè una dozzina contro quaranta ricordi vivi: non può
## bloccare la potatura. Ma la valvola di `Legami` resta, e per la stessa
## ragione: meglio sforare di uno che buttare un ricordo insostituibile.
static func intoccabile(schede: Array, i: int) -> bool:
	if i < 0 or i >= schede.size():
		return true
	var s: Dictionary = schede[i]
	if float(s.get("congruenza", 0.0)) <= 0.0:
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
