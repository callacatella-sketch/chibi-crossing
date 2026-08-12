extends RefCounted

## LE DEDUZIONI — l'ufficio dell'injection, cioè la porta fra «un modello ha
## scritto» e «il villaggio lo sa».
##
## Fase 5, il terzo passo. Il Suggeritore prepara il foglio, il motore scrive
## molte copie, il Giudice ne sceglie una; da qui in poi quella scelta
## diventa **una cosa che il mondo contiene**. Questo file è l'unico posto
## che sa fare quel passaggio, ed è piccolo apposta: quasi tutto il lavoro è
## già stato fatto da chi sta prima, e quello che resta sono tre gesti in un
## ordine che NON si può invertire.
##
## ────────────────────────────────────────────────────────────────────────
## L'ORDINE, ED È TUTTO IL FILE: incassa → si vede → si fa
## ────────────────────────────────────────────────────────────────────────
##
## 1. **INCASSA.** Il JSON si apre qui (`JSON.parse_string`), il Giudice lo
##    collauda, e quello che attraversa il ponte sono due interi e una lista
##    di indici. Da lì in poi la deduzione è un nodo del grafo — muta.
## 2. **SI VEDE.** La testa del vicino si gira verso il posto in cui ha visto
##    Mochi fare la cosa che l'ha fatto pensare. È la RICEVUTA, e finché non
##    è pagata la deduzione non produce niente: non è una buona pratica, è un
##    bit (`chibi::D_RICEVUTA`).
## 3. **SI FA.** Alla prima decisione vera dell'agenda, e solo se il mondo ha
##    una strada, l'obiettivo del pianificatore è il suo. Una volta.
##
## ⚠️ **PERCHÉ QUESTO ORDINE, e non un altro.** «Una conseguenza che il
## giocatore non sa attribuire non attenua l'effetto: LO INVERTE.» È la regola
## che la Fase 4 ha già pagato con la testa che si gira, e qui vale doppio,
## perché quello che sta dietro alla conseguenza non è più una tabella
## scritta a mano: è un modello linguistico. Un vicino che cambia mestiere
## senza che si sia visto niente insegna al giocatore che il villaggio si
## muove a caso — e da quel momento non riconosce più NESSUNA delle
## conseguenze vere, comprese quelle che sono costate mesi.
##
## **NON SI INVENTA UN CANALE NUOVO.** La ricevuta è la stessa
## `Visitor.guarda_gesto()` della Fase 4, chiamata con la stessa durata
## (`Percezione.DURATA_SGUARDO`). La differenza fra le due scene non la fa il
## codice, la fa il mondo: là la testa si gira verso una cosa che sta
## succedendo ADESSO, qui verso un posto in cui non succede niente. Un
## vicino che guarda l'aiuola vuota e poi ci va è leggibile senza una parola
## — ed è l'unica forma in cui questo gioco ha il permesso di raccontare
## qualcosa (`Percezione`: «nessun testo, nessun toast, nessuna lettera»).
##
## ────────────────────────────────────────────────────────────────────────
## IL VETO — cosa una deduzione non può fare, e perché non è una promessa
## ────────────────────────────────────────────────────────────────────────
##
##  · **nessun testo verso il giocatore.** Una deduzione ha due campi e
##    nessuno dei due è una stringa libera (`Giudice.CAMPI_DEDUZIONE`), e la
##    grammatica non ha un posto in cui infilarne una
##    (`Suggeritore.grammatica_deduzione`). Le due guardie sono indipendenti:
##    una governa il campionamento, l'altra cosa entra nel mondo.
##  · **nessun giudizio su una persona, nessuna classifica.** La deduzione
##    non porta un soggetto: `EcsMondo::deduci()` lo azzera copiando i
##    ricordi. Non c'è un campo in cui scriverlo, quindi non c'è una regola
##    da rispettare.
##  · **nessun corteo dietro Mochi.** L'obiettivo è uno dei quattro
##    provvedimenti (fame, aiuola, riposo, meraviglia): nessuno dei quattro
##    dice «vai da qualcuno». E il posto verso cui si guarda è quello di un
##    RICORDO — un'aiuola, una panchina, un cespuglio: cose che non
##    camminano, che è lo stesso argomento per cui `_ancora_ricordo` non ha
##    bisogno delle valvole di `ancora_riposo`.
##  · **e non ci si mette in fila.** Il Pensatoio consegna un pensiero per
##    volta in tutto il villaggio e mette a riposo chi l'ha ricevuto per
##    cinque minuti: ventotto vicini che deducono la stessa cosa nello stesso
##    momento non è una taratura fortunata, è un ritmo che non lo permette.
##
## ────────────────────────────────────────────────────────────────────────
## E SENZA IL MODELLO
## ────────────────────────────────────────────────────────────────────────
##
## Nessuno chiama `incassa()`, il componente delle deduzioni resta vuoto,
## `pronta()` risponde -1 per sempre e `dirotta()` restituisce l'azione che
## le è arrivata, **la stessa Stringa**. Non è un ramo che degrada bene: è un
## ramo che non si accende. Questo è il caso normale, per la stragrande
## maggioranza dei giocatori.

const PIANI := preload("res://scenes/npc/Piani.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIUDICE := preload("res://scenes/npc/Giudice.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")


# =========================================================================
# I DUE TEMPI DELLA RICEVUTA — nessuno dei due è scelto qui
# =========================================================================

## QUANTO DEVE PASSARE FRA LA TESTA CHE SI GIRA E IL CORPO CHE PARTE.
##
## È `Percezione.DURATA_SGUARDO`, cioè **quanto dura uno sguardo in questo
## gioco**, e si legge di là invece di riscriverlo: la premessa e la sua
## durata sono la stessa cosa, e due numeri per la stessa cosa divergono. Chi
## un domani accorciasse lo sguardo accorcerebbe con lui anche l'attesa, che
## è esattamente il comportamento giusto — se lo sguardo si vede per meno
## tempo, aspettare di più non lo rende più leggibile, lo rende soltanto
## slegato.
const ATTESA := PERCEZIONE.DURATA_SGUARDO

## E QUANTO VALE, quella ricevuta, prima di scadere.
##
## Non è una costante: è il **tetto d'impegno dell'agenda**, letto dal
## binario (`debug_costanti_agenda()["tetto_impegno"]`). Il conto è tutto
## qui: la deduzione può diventare un obiettivo solo quando l'agenda apre una
## decisione, e quel tetto è il tempo massimo che l'agenda può metterci. Una
## finestra più corta farebbe scadere deduzioni che non hanno ancora avuto la
## loro occasione (silenzio senza motivo); una più lunga farebbe arrivare una
## conseguenza quando il giocatore non ricorda più la premessa — che è il
## guasto che inverte l'effetto.
##
## Il ripiego (senza cuore, senza GDExtension) è ZERO, che di là vuol dire
## «nessuna scadenza»: il degrado va verso il comportamento che c'era prima
## che questa valvola esistesse, mai verso «non succede mai niente».
static func finestra(cuore: Object) -> float:
	if cuore == null or not is_instance_valid(cuore):
		return 0.0
	var k: Dictionary = cuore.call("debug_costanti_agenda")
	return float(k.get("tetto_impegno", 0.0))


# =========================================================================
# LE DUE TRADUZIONI, tutte e due DERIVATE
# =========================================================================

## DALL'OBIETTIVO DEL PIANIFICATORE ALL'AZIONE DELL'AGENDA.
##
## È l'inversa di `Piani.OBIETTIVO`, **calcolata da lei** e non ricopiata: la
## corrispondenza fra le quattro azioni e i quattro provvedimenti vive in un
## posto solo, e una seconda tabella scritta a mano è il modo esatto in cui
## in questo progetto sono divergite le specie, la scala della ribellione e
## il salvataggio. "" se quell'obiettivo non ha un'azione — e allora non si
## dirotta niente.
static func azione_di(obiettivo: String) -> String:
	for act in PIANI.OBIETTIVO:
		if str(PIANI.OBIETTIVO[act]) == obiettivo:
			return str(act)
	return ""


## DALLA MASCHERA AL NOME. Il ponte parla per NOME in un verso solo
## (`maschera_obiettivo`), e questo è l'altro: si prova nome per nome, sui
## quattro che `Piani` conosce. Quattro confronti, una volta per
## dirottamento — e in cambio nessun numero di `chibi::Provvedimento`
## ricopiato in GDScript.
static func nome_obiettivo(cuore: Object, maschera: int) -> String:
	if cuore == null or not is_instance_valid(cuore) or maschera == 0:
		return ""
	for act in PIANI.OBIETTIVO:
		var nome := str(PIANI.OBIETTIVO[act])
		if int(cuore.call("maschera_obiettivo", nome)) == maschera:
			return nome
	return ""


# =========================================================================
# 1. INCASSA — il JSON diventa un nodo del grafo
# =========================================================================

## UNA BOZZA APERTA, oppure `{}`.
##
## Il JSON si apre QUI e non nel C++, ed è uno scostamento dichiarato dal
## piano dell'autore (la ragione per esteso sta in `ecs_mondo.h`): il
## collaudo di una deduzione è già tutto in GDScript, e il testo di un
## modello è l'ingresso più ostile del gioco — di qua un JSON malformato
## torna `null`, di là sarebbe una superficie nuova dentro il processo del
## giocatore.
##
## Si normalizza SOLO la forma, mai il contenuto: `perche` diventa un array
## di interi. Un campo in più, un obiettivo inventato, una lista vuota non si
## aggiustano qui — li boccia il Giudice, che è il posto che sa dire anche
## perché.
static func da_json(testo: String) -> Dictionary:
	var v = JSON.parse_string(testo)
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	var out := {}
	for k in d:
		if str(k) != "perche":
			out[str(k)] = d[k]
			continue
		if not (d[k] is Array):
			# una lista che non è una lista si lascia com'è: il Giudice la
			# boccia con la sua frase, invece di sparire qui in silenzio
			out["perche"] = d[k]
			continue
		var righe := []
		for r in (d[k] as Array):
			righe.append(int(r))
		out["perche"] = righe
	return out


## TUTTE LE BOZZE, aperte. Quelle che non si aprono spariscono: una stringa
## che non è un JSON non è una deduzione da bocciare, è rumore — e contarla
## fra le bocciate gonfierebbe la diagnosi del Giudice con una porta che non
## esiste.
static func bozze_da(testi) -> Array:
	var out := []
	for t in testi:
		var d := da_json(str(t))
		if not d.is_empty():
			out.append(d)
	return out


## INCASSA: dalle bozze grezze al nodo nel grafo.
##
## Torna `{"indice": int, "obiettivo": String, "motivo": String}` —
## `indice = -1` vuol dire che non è entrato niente, ed è il caso normale.
##
##  · `rit`   — il ritratto con cui il pensiero è PARTITO (arriva col foglio
##              del Pensatoio). Collaudare contro un ritratto ricostruito
##              adesso vorrebbe dire giudicare contro un villaggio di
##              qualche secondo dopo;
##  · `mondo` — quello che il Giudice non può sapere: `fattibili`,
##              `gia_dedotto`;
##  · `soglia`— quanto deve pesare il ricordo più debole perché la deduzione
##              valga la pena. È `Visitors.AMMIRA_SOGLIA`, la stessa con cui
##              un'ancora torna a casa: sotto quel peso il villaggio ha già
##              deciso, in tre posti, che un ricordo non conta più.
##
## L'ULTIMA PAROLA È DEL PONTE, non del Giudice: `deduci()` rilegge il grafo
## VERO (il ritratto è una fotografia), rifiuta i doppioni, rifiuta la
## gemella di una deduzione ancora viva. Chi chiama deve guardare l'indice.
static func incassa(cuore: Object, id: int, bozze: Array, rit: Dictionary,
		mondo := {}, soglia := 0.0) -> Dictionary:
	var muto := {"indice": -1, "obiettivo": "", "motivo": "nessuna bozza"}
	if cuore == null or not is_instance_valid(cuore) or bozze.is_empty():
		return muto
	var scelta: Dictionary = GIUDICE.scegli_deduzione(bozze, rit, mondo)
	if int(scelta["scelta"]) < 0:
		muto["motivo"] = str(scelta["motivo"])
		return muto
	var ded: Dictionary = scelta["deduzione"]
	var nome := str(ded.get("obiettivo", ""))
	var maschera := int(cuore.call("maschera_obiettivo", nome))
	if maschera == 0:
		# non può succedere (il Giudice controlla `OBIETTIVI_DETTI`, e un test
		# lega quelle quattro chiavi alle maschere vere), e se succedesse
		# vorrebbe dire che le due tabelle hanno divorziato: si tace.
		return {"indice": -1, "obiettivo": nome,
				"motivo": "«%s» non ha una maschera nel ponte" % nome}
	var righe := PackedInt32Array()
	for r in (ded.get("perche", []) as Array):
		righe.append(int(r))
	var i := int(cuore.call("deduci", id, maschera, righe, soglia))
	return {"indice": i, "obiettivo": nome,
			"motivo": str(scelta["motivo"]) if i >= 0 else "il ponte l'ha rifiutata"}


# =========================================================================
# 2. LA RICEVUTA — le due righe
# =========================================================================

## LE DUE RIGHE. Non si separano, non si riordinano, non ci si mette un `if`
## in mezzo. È l'idioma di `Percezione._testimonia`, e per la stessa ragione:
## fra le due c'è tutta la credibilità del sistema.
##
## Qui però l'ordine è ROVESCIATO rispetto a là, e non per distrazione. Nella
## percezione si gira la testa e POI si incide il ricordo, perché il guasto
## innocuo è «ha guardato e non se n'è ricordato». Qui il fatto esiste già
## (la deduzione è nel grafo da prima) e quello che si paga è il permesso di
## AGIRE: si gira la testa, e solo dopo si dice al motore che il giocatore ha
## visto. Il guasto innocuo resta lo stesso — una testa che si gira e non
## produce niente è distrazione, che è una cosa che le creature fanno.
##
## Torna `true` se la ricevuta è stata pagata.
##
## ⚠️ **SI PAGA SOLO A CHI PUÒ GUARDARE**, e la domanda si fa a
## `Percezione.puo_vedere` passandogli la SUA posizione: la distanza diventa
## zero e quello che resta sono esattamente le tre valvole che contano qui —
## il corpo sparito dentro casa, il pisolino, l'appuntamento a una scena
## rara. Chiedere non è un vezzo: pagare la ricevuta a un vicino addormentato
## vorrebbe dire una conseguenza la cui premessa non si è vista, cioè il
## guasto che tutto questo file esiste per rendere impossibile. E si chiede
## di là, non con tre `if` scritti qui, perché il giorno che qualcuno
## aggiunge una quarta valvola la ricevuta la eredita invece di ignorarla.
static func consegna(cuore: Object, id: int, node: Node3D, i: int) -> bool:
	if cuore == null or not is_instance_valid(cuore) or i < 0:
		return false
	if node == null or not is_instance_valid(node):
		return false
	if not PERCEZIONE.puo_vedere(node, node.global_position, 1.0):
		return false
	var dove: Vector3 = cuore.call("deduzione_dove", id, i, node.global_position)
	# SI ASPETTA IL MOMENTO IN CUI IL COLLO CI ARRIVA. Vedi
	# `Visitor.collo_ci_arriva`: misurato nel MainLevel vero, col posto alle
	# spalle la testa si ferma al tetto del rig e restano **102° di scarto** —
	# e una testa che punta altrove non è una premessa, è rumore. La deduzione
	# ha minuti per trovare il suo momento (un vicino si gira di continuo), e
	# se non lo trova muore in silenzio, che è l'esito buono.
	#
	# ⚠️ E COPRE ANCHE «non c'è niente da mostrare»: quando i ricordi non
	# indicano più nessun posto, `deduzione_dove` restituisce il ripiego —
	# cioè la posizione del vicino stesso — e un collo non guarda i propri
	# piedi. Qui c'era un controllo apposta per quel caso: era un
	# sottoinsieme stretto di questo (il pavimento di distanza del rig è
	# cinque centimetri, `is_equal_approx` un centesimo di millimetro), e
	# nessuna mutazione poteva più farlo diventare rosso. Una guardia che
	# nessun test può far fallire è una guardia che non c'è.
	#
	# `has_method` e non un `if` sul tipo: chi non sa rispondere non riceve
	# ricevute, e il degrado va verso il silenzio — mai verso una premessa
	# che nessuno ha visto.
	if not node.has_method("collo_ci_arriva") or not bool(node.call("collo_ci_arriva", dove)):
		return false
	# LE DUE RIGHE.
	node.call("guarda_gesto", dove, PERCEZIONE.DURATA_SGUARDO)
	cuore.call("deduzione_ricevuta", id, i)
	return true


# =========================================================================
# 3. IL DIROTTAMENTO — l'obiettivo prioritario, una volta sola
# =========================================================================

## CHE COSA VUOL DIRE «PRIORITARIO», DETTO PRECISO.
##
## Vuol dire che **quando l'agenda apre una decisione, la deduzione è la
## prima a cui si chiede** — e se il mondo le dà una strada intera, il piano
## è il suo. Non vuol dire niente di più, e le tre cose che NON vuol dire
## sono le tre leve che la Fase 2 ha pagato a caro prezzo:
##
##  1. **non scavalca il lucchetto del corpo.** Si dirotta solo dentro
##     `_gesti_agenda`, sul FRONTE (`azione_cambiata`), e il fronte esiste
##     solo quando il registro ha già deciso che si può cambiare — cioè col
##     corpo a riposo. Un vicino che sta camminando o compiendo un gesto non
##     si interrompe;
##  2. **non tocca `T_MIN`.** Non c'è nessuna corsia d'urgenza qui: la
##     deduzione non alza un punteggio, non muove un modulatore, non entra
##     nell'argmax. Arriva DOPO che l'argmax ha parlato;
##  3. **non tocca il dado congelato.** Non c'è un dado in questo file: la
##     scelta fra le bozze è del Giudice, che è puro e senza dadi, e il seme
##     del modello arriva da fuori.
##
## E la quarta, che è della Fase 3: **MAI UN PIANO A METÀ.** Si chiede al
## risolutore, e se torna a mani vuote — nessuna catena, budget esaurito,
## obiettivo già vero — non si dirotta niente. Portare un corpo a metà strada
## e piantarcelo è il guasto che quel sistema esiste per rendere impossibile.
##
## Torna l'azione da recitare: quella della deduzione, oppure **la stessa
## che è arrivata**. In un villaggio senza modello è sempre la seconda.
##
## ⚠️ **LA DEDUZIONE SI SPENDE ANCHE QUANDO NON DIROTTA**, ed è voluto. Le
## tre uscite «il mondo non ha una strada», «l'agenda voleva già quello» e
## «l'ho fatto» sono tutte la fine della sua vita: la ricevuta è stata pagata
## e ha avuto la sua occasione. Tenerla in caldo vorrebbe dire che alla
## prossima decisione — che può essere fra quaranta secondi — parte una
## conseguenza la cui premessa il giocatore non ha più in mente. Una
## deduzione vale UN'occasione, quella subito dopo la sua ricevuta.
static func dirotta(cuore: Object, id: int, act: String, luoghi: Array,
		fatti: int, soglia: float) -> String:
	if cuore == null or not is_instance_valid(cuore):
		return act
	# LA DOMANDA A BUON MERCATO PER PRIMA. `finestra()` chiede al binario un
	# ORACOLO (`debug_costanti_agenda` alloca un Dictionary per rispondere), e
	# questa funzione gira a ogni fronte dell'agenda di ogni vicino: nel caso
	# normale — che è «non c'è nessun modello», per la stragrande maggioranza
	# dei giocatori — non deve costare più di un confronto fra interi.
	#
	# Chiedere «senza scadenza» è un SOVRAINSIEME di chiedere «entro la
	# finestra»: se non c'è niente di pronto nemmeno senza scadenza, non ci
	# sarà niente nemmeno con. Non è un'euristica, è un'implicazione — ed è
	# per questo che si può mettere davanti senza cambiare il comportamento.
	if int(cuore.call("deduzione_pronta", id, soglia, ATTESA, 0.0)) < 0:
		return act
	var i := int(cuore.call("deduzione_pronta", id, soglia, ATTESA, finestra(cuore)))
	if i < 0:
		return act
	# da qui in poi la deduzione ha avuto la sua occasione, comunque vada
	cuore.call("deduzione_spendi", id, i)
	var nome := nome_obiettivo(cuore, int(cuore.call("deduzione_obiettivo", id, i)))
	var nuova := azione_di(nome)
	if nuova == "" or nuova == act:
		return act
	if luoghi.size() < PIANI.LUOGHI.size():
		return act
	var passi: PackedInt32Array = cuore.call("pianifica",
			fatti, int(cuore.call("maschera_obiettivo", nome)), PIANI.cammino(luoghi))
	if passi.is_empty():
		return act
	return nuova
