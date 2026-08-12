extends RefCounted

## IL GIUDICE — venti bozze entrano, una esce. O nessuna.
##
## Fase 5, il passo della scelta. Da qualche parte, fuori da questo file, un
## modello piccolo scrive: non una volta, MOLTE. Questo file non lo chiama e
## non sa che esista — riceve N stringhe già scritte e dice **quale**, e
## soprattutto **perché**. Tutto quello che c'è qui dentro è puro,
## deterministico e provabile senza un modello: gli si danno cinque stringhe
## scritte a mano e risponde con un numero e una ragione.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE: il dilemma misurato del provino
## ────────────────────────────────────────────────────────────────────────
##
## Il provino dell'11 agosto ha fatto girare quattro modelli piccoli sullo
## stesso foglio, 184 generazioni, e ha trovato una cosa che nessuno dei
## quattro può risolvere da solo:
##
##   · i modelli ONESTI sono MONOTONI. gemma3 non inventa mai (0 su 15) e
##     scrive quindici lettere che cominciano in **due** modi: «il vento…»
##     dieci volte, «il sole…» cinque. gemma4: tre incipit su quindici.
##   · i modelli VARI INVENTANO. llama3.2 dà undici incipit diversi su
##     quindici, e in quattro lettere su quindici dice cose che nel villaggio
##     non sono successe. qwen3.5: nove incipit, quattro invenzioni.
##
## Su UNA generazione non se ne esce: si sceglie fra un gioco che si ripete e
## un gioco che mente. Su venti sì, e non serve un modello migliore — serve
## **buttare**. La monotonia si uccide tenendo lo scarto raro; l'allucinazione
## si uccide buttando le bozze che citano cose mai successe. È anche la
## richiesta esplicita dell'autore: «deve generare e scrivere molte copie, di
## cui il codebase ne sceglie una e scarta le altre».
##
## ────────────────────────────────────────────────────────────────────────
## L'ORDINE NON È UN DETTAGLIO: LA PORTA PRIMA DEL PUNTEGGIO
## ────────────────────────────────────────────────────────────────────────
##
## ⚠️ Misurato, e ribalta l'istinto: **le bozze più rare sono anche quelle
## che inventano di più.** Sul mazzo vero, la bozza più lontana dalle sorelle
## è, per llama3.2, «la mia pelle è ancora fresca dopo il tuo annaffiato / la
## mia vista non ha visto le tue mani che hanno costruito»; per qwen3.5, «ho
## visto come hai fissato quel pezzo di legno». Tutt'e due inventano. È
## ovvio col senno di poi: il modello si allontana dal solco proprio quando
## smette di attenersi a quello che gli è stato dato.
##
## Perciò l'ancoraggio **non è un punteggio con un peso alto**: è una PORTA.
## Un giudice che sommasse «quanto è vera» e «quanto è rara» sarebbe una
## macchina per scegliere la bugia più bella — e con dei pesi taratissimi,
## qualche volta, la sceglierebbe. Prima si butta, poi si sceglie fra i
## rimasti; il punteggio non può mai riaprire una porta chiusa.
##
## ────────────────────────────────────────────────────────────────────────
## IL SILENZIO È UN ESITO, E DEVE ESSERE FREQUENTE
## ────────────────────────────────────────────────────────────────────────
##
## `scelta = -1` non è un guasto: è la regola 2 del taccuino del Gufo —
## «meglio nessuna lettera che una a vuoto» — applicata a una macchina che,
## a differenza di chi scrive a mano, non si stanca mai di provarci. Quando
## il giudice tace, il gioco fa quello che farebbe se il modello non ci
## fosse: manda la lettera scritta a mano. Che è anche il caso NORMALE, per
## la stragrande maggioranza dei giocatori (il modello è spento di default).
##
## ────────────────────────────────────────────────────────────────────────
## QUELLO CHE QUESTO GIUDICE NON SA FARE, dichiarato
## ────────────────────────────────────────────────────────────────────────
##
## Non sa se una frase è BELLA. Sa se è VERA (l'ancoraggio, che è una porta),
## se è NUOVA (la memoria) e se è RARA (le sorelle). Una riga sgraziata ma
## onesta e mai detta passa, e passerà sempre: giudicare la prosa italiana
## non è cosa che si faccia con una funzione pura, e fingere di saperlo fare
## sarebbe il modo più veloce di scrivere un giudice che si crede più bravo
## di quanto sia. L'unico difetto di FATTURA che sa vedere è la parola
## incollata al tetto della grammatica, e la vede perché quella lascia una
## cicatrice misurabile (vedi `Suggeritore.LETTERE_MAX`).
##
## E non sa **in che lingua si sta giocando**: giudica testo italiano perché
## il foglio è italiano. Chi mostra la lettera deve chiederselo lui — in
## inglese la strada giusta è non mostrarla affatto e lasciare le lettere
## scritte a mano, che sono tradotte (è la conseguenza dichiarata in cima a
## `Suggeritore.gd`). Un villaggio inglese con una lettera italiana in mezzo
## è peggio di un villaggio senza sorprese, e questo file non può accorgersene.

const SUG := preload("res://scenes/npc/Suggeritore.gd")


# =========================================================================
# LE SCALE — tutte tarate sul mazzo vero, nessuna a occhio
# =========================================================================

## QUANTO DEVONO SOMIGLIARSI DUE LETTERE PERCHÉ LA SECONDA SIA GIÀ DETTA.
##
## La misura è il coefficiente di Dice fra i sacchi di **parole lunghe e
## coppie di parole** delle sole righe libere (vedi `somiglianza`). Il numero
## non è scelto: è il **99° percentile** delle 1770 coppie del mazzo vero —
## 18 coppie su 1770 lo superano, e sono esattamente quelle che a leggerle di
## fila sono la stessa lettera («il vento sussurra, spargendo polvere» contro
## «il vento sussurra, la terra è bruna»). La mediana del mazzo è 0.026.
##
## Chi lo alza fa passare le ripetizioni; chi lo abbassa fa tacere il Gufo.
## Si ritara guardando le coppie, non i numeri: `tools/prova_giudice.gd`.
const SOGLIA_GIA_DETTO := 0.30

## LE PRIME PAROLE, e perché contano da sole. L'incipit è la cosa che un
## lettore riconosce prima di aver letto la riga: due lettere che cominciano
## con «il vento» sono due lettere uguali anche se il resto diverge. Ed è
## anche la misura con cui il provino ha smascherato la monotonia («2 incipit
## diversi su 15»), quindi è la misura giusta per curarla.
const INCIPIT_PAROLE := 2

## Quante lettere indietro guarda la memoria degli incipit. Sei è quanto un
## giocatore ne legge in una settimana di gioco: più indietro di così, «il
## vento» torna a essere una parola e non un tic.
const MEMORIA_INCIPIT := 6

## I DUE PESI DELLA SCELTA. La rarità pesa il doppio della lontananza dalla
## memoria, e c'è una ragione: la memoria ha già BOCCIATO chi si ripeteva
## (è una porta), quindi la lontananza qui serve solo a rompere i pari fra
## bozze tutte lecite — mentre la rarità è l'unica leva che questo file ha
## contro la monotonia di un modello onesto.
##
## E per chi verrà a tararli, la misura onesta: portare `PESO_LONTANANZA` da
## 0.5 a ZERO sposta l'esito in **circa il 2% delle sere** sul mazzo vero
## (gemma4 manda tre lettere in più su centocinquanta, qwen due in meno).
## Questa manopola è piccola: se un giorno le lettere non vanno bene, non è
## qui che si aggiusta.
const PESO_RARITA := 1.0
const PESO_LONTANANZA := 0.5


# =========================================================================
# LA SCELTA
# =========================================================================

## SCEGLIE UNA BOZZA, O NESSUNA. Torna:
##   {"scelta": int, "testo": String, "lettera": String, "motivo": String,
##    "schede": Array}
## `scelta` è l'indice in `bozze`, oppure **-1** (silenzio). `testo` è la
## bozza com'era (è quella che va messa in memoria); `lettera` è la stessa
## passata da `Suggeritore.rifinisci`, cioè come si legge sullo schermo.
##
## `memoria` è {"sue": [testi], "villaggio": [testi]}, e vuole i testi
## **GREZZI** — quelli con le righe libere ancora in minuscolo. È da lì che
## si riconosce la citazione di un altro vicino (comincia per maiuscola) e la
## si tiene fuori dal confronto: due lettere che citano lo stesso fatto non
## sono la stessa lettera, e confondere le due cose farebbe tacere il
## villaggio proprio quando succede qualcosa di grosso.
##
## 💡 E in `villaggio` ci va anche una cosa che non è una lettera: **le righe
## di esempio del prompt**, se un domani il foglio ne avrà. Misurato sul
## mazzo: quando il prompt del provino conteneva due lettere già scritte «per
## far sentire la voce», llama3.2 ne ha ricopiato una riga in tre delle
## quattro lettere che il giudice gli ha preso — e una frase ricopiata
## dall'esempio è la monotonia nella sua forma peggiore, perché è identica
## anche fra vicini diversi. Per il giudice è già «detto da qualcun altro»,
## e basta passargliela.
static func scegli(bozze: Array, rit: Dictionary, memoria := {}) -> Dictionary:
	# IL BANCO SI COSTRUISCE UNA VOLTA per tutte le bozze. Senza, `accetta()`
	# rifà i fatti, le frasi, i nomi e le radici quattro volte per bozza —
	# misurato, e il conto cresce col numero di bozze: vedi `Suggeritore.banco`.
	var banc := SUG.banco(rit)
	var cit: Array = banc["citazioni"]
	var sue: Array = memoria.get("sue", [])
	var altrui: Array = memoria.get("villaggio", [])
	var ricordate := []
	for m in sue:
		ricordate.append(str(m))
	for m in altrui:
		ricordate.append(str(m))

	# gli incipit già usati di recente, dai più recenti a ritroso
	var incipit_usati := []
	for k in range(ricordate.size() - 1, max(-1, ricordate.size() - 1 - MEMORIA_INCIPIT), -1):
		incipit_usati.append(incipit(str(ricordate[k]), cit))

	# I SACCHI DI TUTTE LE BOZZE, bocciate comprese: la rarità si misura
	# contro quello che il modello HA SCRITTO stasera, che è la sua indole di
	# stasera — non contro i soli sopravvissuti, che sono già una selezione.
	var sacchi := []
	for b in bozze:
		sacchi.append(sacco(str(b), cit))
	var sacchi_memoria := []
	for m in ricordate:
		sacchi_memoria.append(sacco(str(m), cit))

	var schede := []
	for i in bozze.size():
		schede.append(_scheda(str(bozze[i]), i, sacchi, sacchi_memoria,
				incipit_usati, rit, cit, banc))

	var vince := -1
	for i in schede.size():
		var s: Dictionary = schede[i]
		if not bool(s["ok"]):
			continue
		# A PARI MERITO VINCE L'INDICE PIÙ BASSO: nessun dado, mai. È la
		# regola di `fatti()` e di `da_raccontare`, e serve a che due
		# esecuzioni identiche diano la stessa lettera.
		if vince < 0 or float(s["punti"]) > float(schede[vince]["punti"]):
			vince = i

	if vince < 0:
		return {"scelta": -1, "testo": "", "lettera": "",
				"motivo": _perche_silenzio(schede), "schede": schede}
	var vinta: Dictionary = schede[vince]
	return {
		"scelta": vince,
		"testo": str(bozze[vince]),
		"lettera": SUG.rifinisci(str(bozze[vince])),
		"motivo": "la più rara fra le %d ammesse (rarità %.2f su %d bozze)"
				% [_quante_ammesse(schede), float(vinta["rarita"]), schede.size()],
		"schede": schede,
	}


static func _quante_ammesse(schede: Array) -> int:
	var n := 0
	for s in schede:
		if bool((s as Dictionary)["ok"]):
			n += 1
	return n


static func _scheda(testo: String, i: int, sacchi: Array, sacchi_memoria: Array,
		incipit_usati: Array, rit: Dictionary, cit: Array, banc: Dictionary) -> Dictionary:
	var s := {"ok": false, "perche": "", "porta": "", "rarita": 0.0,
			"lontananza": 0.0, "punti": 0.0}

	# ---- LA PORTA 1: è vero quello che dice? --------------------------
	var esito: Dictionary = SUG.accetta(testo, rit, banc)
	if not bool(esito["ok"]):
		s["perche"] = str(esito["motivo"])
		s["porta"] = str(esito.get("porta", "forma"))
		return s

	# ---- LA PORTA 2: l'ha già detto? ----------------------------------
	var mio := incipit(testo, cit)
	if mio != "" and incipit_usati.has(mio):
		s["perche"] = "comincia come una lettera di poco fa: «%s»" % mio
		s["porta"] = "memoria"
		return s

	var vicino := 0.0
	for k in sacchi_memoria.size():
		vicino = max(vicino, dice(sacchi[i], sacchi_memoria[k]))
	if vicino >= SOGLIA_GIA_DETTO:
		s["perche"] = "l'ha già detto (somiglianza %.2f)" % vicino
		s["porta"] = "memoria"
		return s

	# ---- IL PUNTEGGIO: quanto è rara, e quanto è lontana --------------
	var somma := 0.0
	var quante := 0
	for k in sacchi.size():
		if k == i:
			continue
		somma += dice(sacchi[i], sacchi[k])
		quante += 1
	s["rarita"] = 1.0 - (somma / float(quante) if quante > 0 else 0.0)
	s["lontananza"] = 1.0 - vicino
	s["punti"] = PESO_RARITA * float(s["rarita"]) + PESO_LONTANANZA * float(s["lontananza"])
	s["ok"] = true
	# «ammessa», non «scelta»: chi vince lo si sa solo dopo aver visto tutte le
	# sorelle, e una scheda che si dichiarasse vincitrice da sola racconterebbe
	# una gara che non è ancora finita.
	s["perche"] = "ammessa (rarità %.2f, lontananza %.2f)" \
			% [float(s["rarita"]), float(s["lontananza"])]
	return s


## PERCHÉ NON È USCITO NIENTE. Si contano le porte invece di riportare il
## primo motivo: «tre inventavano, due l'avevano già detto» è una diagnosi;
## «una riga libera troppo corta» è un aneddoto.
static func _perche_silenzio(schede: Array) -> String:
	if schede.is_empty():
		return "nessuna bozza"
	var conta := {}
	for s in schede:
		var p := str((s as Dictionary)["porta"])
		conta[p] = int(conta.get(p, 0)) + 1
	var pezzi := []
	for p in ["ancoraggio", "memoria", "forma", "parola"]:
		if conta.has(p):
			pezzi.append("%d %s" % [int(conta[p]), p])
	return "nessuna bozza è passata (%s)" % ", ".join(pezzi)


# =========================================================================
# LA MISURA DELLA NOVITÀ
# =========================================================================

## LE RIGHE CHE CONTANO: solo quelle libere. La citazione viene da una lista
## chiusa e la scrive il gioco — due lettere che citano lo stesso ricordo non
## sono la stessa lettera, e contare quelle righe farebbe somigliare fra loro
## tutte le lettere di una sera in cui è successa una cosa sola.
##
## Si riconosce in due modi, e servono tutti e due: la riga sta fra le
## citazioni di QUESTO vicino (`cit`), oppure comincia per maiuscola — che
## nella metà libera non può succedere, perché la grammatica non ha le
## maiuscole. Il secondo modo è l'unico che funzioni sulle lettere degli
## ALTRI vicini, che citano fatti che qui non sono in lista.
static func righe_libere(testo: String, cit: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for r in testo.split("\n"):
		var s := str(r).strip_edges()
		if s == "" or cit.has(s):
			continue
		var c := s.substr(0, 1)
		if c != c.to_lower():
			continue
		out.append(s)
	return out


## IL SACCO DI UNA LETTERA: le parole lunghe più tutte le coppie di parole
## consecutive.
##
## ⚠️ NIENTE LISTA DI PAROLE VUOTE, ed è una scelta misurata. Un elenco di
## articoli e preposizioni scritto a mano sarebbe l'unica tabella di questo
## file a non avere una fonte, e non serve: le coppie fanno da sole il
## mestiere che farebbe l'elenco (una preposizione conta solo insieme a quello
## che regge), e la soglia di lunghezza tiene fuori il resto. Misurato sulle
## 1770 coppie del mazzo: con l'elenco a mano la separazione fra «stessa
## lettera» e «lettere diverse» è 2.8×, con parole+coppie è 3.2×.
const PAROLA_PIENA := 4

static func sacco(testo: String, cit: Array) -> Dictionary:
	var out := {}
	var prec := ""
	for riga in righe_libere(testo, cit):
		prec = ""
		for w in SUG.parole(str(riga)):
			if w.length() >= PAROLA_PIENA:
				out[w] = true
			if prec != "":
				out[prec + " " + w] = true
			prec = w
	return out


## Il coefficiente di Dice fra due sacchi: 0 = niente in comune, 1 = uguali.
static func dice(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var comuni := 0
	for k in a:
		if b.has(k):
			comuni += 1
	return 2.0 * float(comuni) / float(a.size() + b.size())


## Quanto si somigliano due lettere. Pubblica perché è la misura con cui si
## tara `SOGLIA_GIA_DETTO`, e una soglia che non si può misurare da fuori è
## una soglia che nessuno ritara mai.
static func somiglianza(a: String, b: String, cit := []) -> float:
	return dice(sacco(a, cit), sacco(b, cit))


## LE PRIME PAROLE della prima riga libera, in minuscolo. "" se non ce ne
## sono (una lettera fatta della sola citazione non ha un incipit da
## ricordare, e non deve bloccarne un'altra).
static func incipit(testo: String, cit := []) -> String:
	var righe := righe_libere(testo, cit)
	if righe.is_empty():
		return ""
	var ws := SUG.parole(str(righe[0]))
	if ws.size() < INCIPIT_PAROLE:
		return ""
	var pezzi := []
	for i in INCIPIT_PAROLE:
		pezzi.append(str(ws[i]))
	return " ".join(pezzi)


# =========================================================================
# L'ALTRA MATERIA: le deduzioni, cioè i JSON
# =========================================================================

## L'altra metà della Fase 5: il modello non scrive solo lettere, restituisce
## anche un JSON che diventa un nodo nuovo nel grafo o un obiettivo per il
## GOAP. Le bozze arrivano tante anche lì, e la scelta è lo stesso mestiere —
## con un criterio in più che le lettere non hanno: **si può fare davvero?**
##
## ────────────────────────────────────────────────────────────────────────
## LA REGOLA DELLA RICEVUTA, che qui vale doppio
## ────────────────────────────────────────────────────────────────────────
##
## Una deduzione entra nel mondo come un FATTO OSSERVABILE prima che come un
## obiettivo: il vicino deve fare qualcosa che il giocatore VEDE prima di
## fare qualcosa che deve INTERPRETARE. Da qui le due regole che sembrano
## severe e non lo sono:
##
##  · **una deduzione non ha campi liberi.** Solo `obiettivo` e `perche`.
##    Un campo di testo dentro un JSON è una frase che nessuno ha collaudato,
##    e prima o poi qualcuno la mostra: sarebbe l'ancoraggio riaperto dalla
##    finestra dopo averlo chiuso dalla porta.
##  · **una deduzione che propone quello che il vicino sta già facendo non è
##    una deduzione.** Non produce nessuna ricevuta: il giocatore vedrebbe
##    esattamente quello che stava già vedendo, e la macchina avrebbe
##    lavorato per niente.
##
## `mondo` è quello che il chiamante sa e questo file non può sapere:
##   · `fattibili`   — i nomi degli obiettivi per cui il risolutore trova
##                     una strada ADESSO (`Piani`/`sistema_piani`). Un
##                     obiettivo irraggiungibile è una promessa che il mondo
##                     non mantiene, e si butta;
##   · `gia_dedotto` — gli obiettivi già dedotti di recente per questo
##                     vicino: la novità, per un JSON.
## Sta fuori apposta: così questo file resta puro e provabile senza binario,
## esattamente come `ritratto()` è l'unico posto del Suggeritore che tocca la
## GDExtension.
const CAMPI_DEDUZIONE := ["obiettivo", "perche"]


## È AZIONABILE? Torna {"ok": bool, "motivo": String}.
static func utile(ded: Dictionary, rit: Dictionary, mondo := {}) -> Dictionary:
	for k in ded:
		if not CAMPI_DEDUZIONE.has(str(k)):
			return {"ok": false, "motivo": "una deduzione non ha campi liberi: «%s»" % str(k)}

	var ob := str(ded.get("obiettivo", ""))
	if not SUG.OBIETTIVI_DETTI.has(ob):
		return {"ok": false, "motivo": "«%s» non è un obiettivo che il mondo conosce" % ob}

	# LA RICEVUTA: i ricordi che la reggono devono esistere ANCORA. `fatti()`
	# ha già potato i ricordi spenti e quelli senza bandiere: chiedere a lei
	# vuol dire che la deduzione e la lettera si appoggiano alla stessa
	# memoria, e non a due letture diverse dello stesso grafo.
	var vivi := {}
	for f in SUG.fatti(rit):
		vivi[int((f as Dictionary)["riga"])] = true
	var perche = ded.get("perche", [])
	if not (perche is Array) or (perche as Array).is_empty():
		return {"ok": false, "motivo": "una deduzione senza un ricordo che la regga"}
	# IL TETTO È QUELLO DEL PONTE. `chibi::MAX_PERCHE` è il numero di copie che
	# una deduzione si porta dietro: una catena più lunga il ponte la rifiuta,
	# e una bozza promossa qui e rifiutata di là è una bozza buttata due volte
	# — con la seconda bocciatura muta.
	if (perche as Array).size() > SUG.PERCHE_MAX:
		return {"ok": false, "motivo": "una deduzione non si appoggia a più di %d ricordi"
				% SUG.PERCHE_MAX}
	var visti := {}
	for r in (perche as Array):
		if not vivi.has(int(r)):
			return {"ok": false, "motivo": "si appoggia a un ricordo che non c'è (riga %d)" % int(r)}
		# NIENTE DOPPIONI. La catena si misura dall'anello più debole (vedi
		# `scegli_deduzione`): citare due volte lo stesso ricordo la fa
		# sembrare più lunga senza renderla più solida, ed è il modo in cui un
		# modello, senza volerlo, gonfia quello che gli si è chiesto.
		if visti.has(int(r)):
			return {"ok": false, "motivo": "cita due volte lo stesso ricordo (riga %d)" % int(r)}
		visti[int(r)] = true

	if ob == str(rit.get("obiettivo", "")):
		return {"ok": false, "motivo": "propone quello che sta già facendo"}

	var fattibili: Array = mondo.get("fattibili", [])
	if not fattibili.is_empty() and not fattibili.has(ob):
		return {"ok": false, "motivo": "il mondo non ha una strada per «%s» adesso" % ob}

	var gia: Array = mondo.get("gia_dedotto", [])
	if gia.has(ob):
		return {"ok": false, "motivo": "l'aveva già dedotto"}
	return {"ok": true, "motivo": ""}


## SCEGLIE UNA DEDUZIONE, O NESSUNA. Stessa forma di `scegli`.
##
## Fra le azionabili vince quella che sta in piedi meglio, e «meglio» è il suo
## ricordo **più debole**: una catena vale quanto il suo anello più fragile, e
## misurare così toglie il vantaggio a chi cita tutto quello che può — che è
## il modo in cui un modello, senza volerlo, gonfia una deduzione.
static func scegli_deduzione(bozze: Array, rit: Dictionary, mondo := {}) -> Dictionary:
	var pesi = rit.get("pesi", null)
	var schede := []
	var vince := -1
	for i in bozze.size():
		var ded: Dictionary = bozze[i] if bozze[i] is Dictionary else {}
		var esito := utile(ded, rit, mondo)
		var s := {"ok": bool(esito["ok"]), "perche": str(esito["motivo"]), "punti": 0.0}
		if bool(esito["ok"]):
			var minimo := INF
			for r in (ded["perche"] as Array):
				var p := 1.0
				if pesi != null and int(r) < pesi.size():
					p = float(pesi[int(r)])
				minimo = min(minimo, p)
			s["punti"] = float(minimo)
			s["perche"] = "il ricordo più debole che la regge pesa %.2f" % float(minimo)
			if vince < 0 or float(s["punti"]) > float(schede[vince]["punti"]):
				vince = i
		schede.append(s)

	if vince < 0:
		return {"scelta": -1, "deduzione": {}, "motivo": "nessuna deduzione azionabile",
				"schede": schede}
	return {"scelta": vince, "deduzione": bozze[vince],
			"motivo": str(schede[vince]["perche"]), "schede": schede}
