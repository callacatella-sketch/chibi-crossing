extends RefCounted

## LE PERSONE CAMBIANO — la deriva dei tratti, e la sua metà pura.
##
## Un tratto (codardia, lealtà, ambizione) può spostarsi lentissimamente nella
## direzione in cui la vita di quella persona ha spinto. Non in un giorno: in
## una **stagione**. È il cambiamento più grande che questo gioco possa fare,
## perché tutto il resto legge i tratti — l'andatura, la voce, le reazioni,
## chi si affeziona a chi, chi si stanca a che ora.
##
## Questo file è **puro**: nessuno stato, nessun nodo, nessun orologio. Entra
## quello che è successo a una persona, esce un numero. È la casa di
## `Cricche.gd` e `Gesti.gd`.
##
## ============================================================
## LA DERIVA NON SI SALVA — e questa è la decisione che tiene su tutto
## ============================================================
## È una **lettura**, come `Affetti.coppia()` e come `Animo.assenza()`: si
## ricava ogni volta dalle prove che erano già nel salvataggio (i ricordi, il
## sommario, i marchi). Quindi zero chiavi nuove, zero migrazioni, e niente
## che possa restare appeso a metà.
##
## ⚠️ **E non è un'eleganza: è l'unica forma che regge il vincolo dell'autore
## «il ritorno dev'essere sempre possibile».** I tratti in questo gioco sono
## salvati DUE volte (`dna.tratti` e `animo.tratti`) e la copia da cui il
## gioco legge è la seconda — `_ensure_brain` fa `setup(dna)` e **poi**
## `load(salvato)`, che riscrive `tratti`. Un delta scritto lì dentro
## diventerebbe permanente al primo `save()` e si ricomporrebbe a ogni
## caricamento: chi era sarebbe perduto, e non ci sarebbe più nessun posto da
## cui tornare. Il genoma resta il genoma; la deriva è quello che gli si legge
## sopra, adesso.
##
## ============================================================
## LE TRE REGOLE DELLE SPINTE
## ============================================================
## 1. **Solo prove POSITIVE e datate di cose ACCADUTE.** Mai il conteggio di
##    ciò che non è successo. Un tratto che deriva perché a qualcuno *non* è
##    stato fatto niente sarebbe una punizione per chi gioca in un altro modo,
##    e il collaudo è meccanico: **senza righe, la deriva è 0.000**.
## 2. **Solo carburante UNO-A-UNO.** Una cosa che il villaggio fa a tutti non
##    distingue nessuno, quindi non può muovere nessuno. Il cancello è la
##    chiave `attore == "giocatore"`, e non una lista di esclusioni: la riga
##    `vegliato` che la Veglia scrive a ogni residente ogni mattina è
##    intestata alla guardia, quindi non entra **per costruzione**.
##    ⚠️ È per questo che «protetto per venti notti» — l'esempio dell'autore —
##    non è nella prima consegna: quella riga oggi vale 1.000 per residente
##    per giornata, identica per tutti (misurato). La versione che sta sui
##    binari vuole prima che la Veglia sappia dire CHI ha avuto la propria
##    porta al buio, e quello è un commit suo.
## 3. **La quantità la porta la RIGA, non una tabella nuova.** Ogni ricordo ha
##    già `valenza` (passata dal `Limbico` di quella persona: la sorpresa e
##    l'abitudine sono già dentro) e `intensita`; il sommario ha `peso` e
##    `ultimo`; la recenza c'è. Qui si dichiara **solo la direzione**. Questo
##    cancella una classe intera di taratura — e fa sì che lo stesso piatto
##    valga numeri diversi per due vicini diversi.


## QUALI TRATTI DERIVANO. Chi non è in questa lista non si muove mai, e per
## due di loro è una decisione, non una dimenticanza:
##
## ⚠️ **la GRINTA no.** Il suo unico carburante candidato è il lavoro, e il
## lavoro fa fuoco 1.000 volte per residente per giornata per tutti (misurato,
## 14 su 14): è la spinta broadcast che la regola 2 vieta. E il suo canale sul
## corpo è l'adenosina, cioè **la stanchezza** — la sola direzione che non si
## riesce a dichiarare «diversa e non peggiore».
##
## ⚠️ **l'ORGOGLIO no, e va detto.** Non tinge **nessun** canale del corpo
## (`Limbico.setup` tinge cortisolo, ossitocina, dopamina, endorfine,
## serotonina: l'orgoglio non compare), e i suoi tre lettori sono una porta,
## una crisi e una **frase**. Un tratto che non può colorare nulla non deriva.
const DERIVANO := ["codardia", "lealta"]

## LA DIREZIONE, mai la quantità. `-1` = quel gesto porta il tratto giù.
const SPINTE := {
	"codardia": {"piatto": -1, "regalo": -1, "festa": -1},
}

## I MARCHI VIVI TIRANO DALL'ALTRA PARTE. Una paura appresa e ancora accesa
## rende più guardinghi — ed è la sola direzione che ha un gesto del giocatore
## per tornare indietro (`visita_serena`, l'Accompagnare), non solo il tempo.
## ⚠️ Oggi è **dormiente**: zero marchi su tredici residenti in 55 giornate.
const MARCHI := {
	"codardia": 1,
}

## LA COMPAGNIA — quante volte quella persona ha passato del tempo con
## qualcuno, e in che direzione la muove.
##
## ⚠️ **NON e' carburante del giocatore, e va detto perche' non viola la
## regola del uno-a-uno.** Quella regola esiste perche' *cio' che il villaggio
## fa a tutti non distingue nessuno*, e il cancello sull'attore ne era
## l'attuazione per i ricordi. La co-presenza distingue eccome — misurata nel
## salvataggio vero, va da **2 a 24 righe per persona**: e' quello che il
## meccanismo chiede.
##
## E la chiave del giocatore c'e', ed e' quella costruita con la nozione di
## INSIEME: **i posti dove ci si trova li posa lui**, e sedendosi puo' fare da
## ponte fra due che non si erano mai incontrati. Chi non riceve niente resta
## a chi era — nessun malus, nessuna partizione, e **non esiste e non deve
## esistere una funzione «chi e' solo»**.
const COMPAGNIA := {
	"lealta": 1,
}

## QUANTO AL MASSIMO, come frazione della PROPRIA distanza dal bordo.
##
## Non è un numero scelto: è l'unico con un significato dentro l'intervallo
## che le misure lasciano libero. Sotto 0.20 di spostamento **non si vede
## niente su nessun canale** (pavimento di leggibilità); 0.35 è 1,63 σ, cioè
## il 94° percentile (soffitto dell'irriconoscibilità). In mezzo c'è **una
## deviazione standard, 0.2146**, misurata sul generatore vero — e al valore
## mediano della codardia (0.534) questa frazione dà esattamente quello.
##
## Chi la vuole muovere resti fra 0.30 e 0.45, **e porti la misura**.
const FRAZIONE := 0.40

## QUANTE PROVE SATURANO. Viene dall'unità dell'autore, non dall'occhio:
## perché **venti notti di cura** valgano una spinta di `1 − 1/e` ≈ 0,63, con
## questa saturazione e una riga protettiva da ~0,18 di peso, serve una somma
## di ~2,56 — e quindi questo numero.
const SAZIETA := 8.0


## LA PRESSIONE che la vita ha fatto su un tratto, −1 .. +1. Pura, e **zero se
## non ci sono prove**.
##
## [param recenza] è la curva del tempo di chi sta chiedendo, passata come
## `Callable`: la mezza vita dei ricordi vive in `Animo` e non si ricopia di
## qua. È la stessa disciplina con cui `Cricche` riceve il giorno invece di
## leggere l'orologio.
## [param compagnia] sono le GIORNATE in cui quella persona ha passato del
## tempo con qualcuno — una per riga di co-presenza. Arrivano da fuori
## (`Cricche` vive in un altro file e in un altro nodo): questa resta pura, ed
## e' la stessa disciplina con cui riceve `recenza` invece di leggere
## l'orologio.
static func spinta(tratto: String, ricordi: Array, sommario: Dictionary,
		marchi: Dictionary, recenza: Callable, compagnia: Array = []) -> float:
	if not SPINTE.has(tratto) and not MARCHI.has(tratto) \
			and not COMPAGNIA.has(tratto):
		return 0.0
	var somma := 0.0
	var tipi: Dictionary = SPINTE.get(tratto, {})

	# --- le righe VIVE
	for r in ricordi:
		var d := r as Dictionary
		# ⚠️ IL CANCELLO DEL «UNO-A-UNO», e sta qui e in nessun altro posto.
		if str(d.get("attore", "")) != "giocatore":
			continue
		var t := str(d.get("tipo", ""))
		if not tipi.has(t):
			continue
		# ⚠️ SOLO PROVE POSITIVE: una valenza negativa e' un torto, e un
		# torto non deve poter spostare chi sei. (Il rancore ha la sua casa.)
		var v := float(d.get("valenza", 0.0))
		if not (v > 0.0):
			continue
		somma += float(int(tipi[t])) * v * float(d.get("intensita", 1.0)) \
				* float(recenza.call(int(d.get("quando", 0))))

	# --- e quelle FONDUTE nel sommario, che non viene mai potato: e' la
	#     memoria lunga del gioco, e senza di lei la deriva sparirebbe
	#     proprio nei villaggi vivaci — dove nessun collaudo arriva.
	for k in sommario:
		var parti := str(k).split("|")
		if parti.size() < 2 or str(parti[1]) != "giocatore":
			continue
		if not tipi.has(str(parti[0])):
			continue
		var s := sommario[k] as Dictionary
		var p := float(s.get("peso", 0.0))
		if not (p > 0.0):
			continue
		somma += float(int(tipi[str(parti[0])])) * p \
				* float(recenza.call(int(s.get("ultimo", 0))))

	# --- i marchi ancora accesi, dall'altra parte. Senza recenza: si
	#     spengono già da soli, e ricontarne il decadimento sarebbe contarlo
	#     due volte.
	if MARCHI.has(tratto):
		var forza := 0.0
		for mk in marchi:
			var m := marchi[mk] as Dictionary
			forza += maxf(0.0, -float(m.get("carica", 0.0)))
		somma += float(int(MARCHI[tratto])) * forza

	# --- e il tempo passato con qualcuno. Ogni riga vale uno, pesata dalla
	#     stessa recenza di tutto il resto: chi si e' visto molto e poi piu'
	#     torna indietro da solo, come tutto in questo file.
	if COMPAGNIA.has(tratto):
		var insieme := 0.0
		for g in compagnia:
			insieme += float(recenza.call(int(g)))
		somma += float(int(COMPAGNIA[tratto])) * insieme

	if not is_finite(somma) or is_zero_approx(somma):
		return 0.0
	# la saturazione ha la STESSA forma di `Animo.rancore()`: molte prove
	# contano meno delle prime, e non si arriva mai a uno.
	return signf(somma) * (1.0 - exp(-absf(somma) / SAZIETA * 3.0))


## δ — DI QUANTO SI SPOSTA, e sempre come frazione della **propria** distanza
## dal bordo in quella direzione.
##
## ⚠️ **È la lettura letterale del vincolo «mai oltre una frazione del tratto
## originale», e in cambio regala tre teoremi invece di tre tarature:**
##
## 1. **nessuno arriva al muro, a qualunque ampiezza.** Un tetto additivo
##    ±0.15 porta al muro il 7% dei valori misurati e ±0.35 il 47%: tre
##    codardi a 0.85 / 0.92 / 0.98 diventerebbero **tre volte la stessa
##    persona**. Qui è zero per costruzione.
## 2. **a parità di prove l'ordine si conserva**: la derivata rispetto alla
##    base vale `1 − FRAZIONE·|s| > 0`. Due codardi diversi restano diversi,
##    e nell'ordine in cui erano.
## 3. **un tratto che nasce a 0 o a 1 non deriva** — e va bene: non ha
##    distanza da percorrere.
static func delta(base: float, pressione: float) -> float:
	if not is_finite(base) or not is_finite(pressione):
		return 0.0
	var b := clampf(base, 0.0, 1.0)
	var s := clampf(pressione, -1.0, 1.0)
	return FRAZIONE * s * (1.0 - b) if s >= 0.0 else FRAZIONE * s * b


## IL TRATTO DI ADESSO, dato chi era e cosa gli è successo. La composizione in
## un posto solo, così nessuno la somma a mano da qualche parte.
static func derivato(base: float, pressione: float) -> float:
	if not is_finite(base):
		return 0.0
	return clampf(clampf(base, 0.0, 1.0) + delta(base, pressione), 0.0, 1.0)
