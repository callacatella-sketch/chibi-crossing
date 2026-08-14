extends Node

## LA PERCEZIONE — il canale che porta ai vicini quello che Mochi FA.
##
## Il villaggio ha già cinque memorie (i ricordi dell'Animo, il libro mastro
## degli Affetti, il Filo Rosso, i marchi del Limbico, le opinioni del
## Villaggio) e non ne apre una sesta. Quello che davvero mancava era **un
## solo tipo di arco: l'OSSERVAZIONE** — «io ho visto te fare questa cosa,
## qui». Questo nodo è la porta da cui quell'arco entra nel mondo, e non fa
## nient'altro: raccoglie un gesto del giocatore, decide chi poteva vederlo,
## e per ognuno di quelli fa DUE cose nello stesso respiro.
##
## ────────────────────────────────────────────────────────────────────────
## LA REGOLA CHE VIENE PRIMA DI TUTTE, e per cui questo file esiste
## ────────────────────────────────────────────────────────────────────────
##
## **CHI NON HA GIRATO LA TESTA NON HA VISTO — e la testa la gira la STESSA
## funzione che incide il fatto**, in due righe consecutive
## (`_testimonia`). Non esiste, e non deve poter esistere, un percorso che
## esegua l'una senza l'altra.
##
## Non è pignoleria. Una conseguenza senza premessa non attenua l'effetto:
## **lo INVERTE**. Se un vicino domani va all'aiuola che hai annaffiato ma
## nell'istante del gesto stava guardando da un'altra parte, il giocatore
## non impara «mi ha visto»: impara «i vicini fanno cose a caso» — e da
## quel momento non riconosce più NESSUNA delle conseguenze vere, comprese
## quelle che gli sono costate mesi di lavoro. È la regola del taccuino del
## Gufo («si afferma solo ciò che si è VISTO») portata dal testo al corpo:
## là la prova era una frase verificabile, qui è una testa girata.
##
## Il contrario — un vicino che gira la testa e poi non se ne ricorda — è
## innocuo: sembra distrazione, che è una cosa che le creature fanno.
## Perciò l'ordine delle due righe è quello, e non l'altro.
##
## **L'UNITÀ È IL RICORDO, NON IL GESTO** — e questa riga è la sola
## precisazione che la regola ammette. Nel grafo, gesti uguali e ravvicinati
## non fanno ricordi nuovi: fondono in uno solo che si rinfresca e conta
## `quante` (`FINESTRA_FUSIONE`, src/grafo_ricordi.h). Il ventesimo pezzo di
## un sentiero non è una cosa vista in più — è la stessa cosa, ancora. Perciò
## la testa si gira una volta per RICORDO: piena quando il ricordo nasce, e
## poi solo un'occhiata ogni tanto finché la raffica dura. Ogni conseguenza
## del sistema pesa un ricordo, e ogni ricordo ha avuto la sua testa girata:
## la premessa c'è tutta. Il conto sta in `Visitor.guarda_gesto`, che riceve
## da qui il verbo e la finestra vera — la finestra **non si ricopia**, la
## dice il C++.
##
## ────────────────────────────────────────────────────────────────────────
## COSA NON C'È, e non per dimenticanza
## ────────────────────────────────────────────────────────────────────────
##
##  · **Nessun cono visivo, nessun raycast, nessuna occlusione.** In tutto
##    il progetto non esiste un raycast, e i muri (`Varchi`) modellano il
##    passaggio di un CORPO, non la linea di vista — una staccionata ferma
##    le gambe, una Serra è di vetro. Il guasto che si eviterebbe (un
##    vicino che vede attraverso un muro) non si nota mai; quello che si
##    creerebbe (un vicino che NON si accorge di te a due metri) si nota
##    sempre. Fra i due si sceglie quello che nessuno vede.
##  · **Nessuna modulazione con `FiatoSospeso.calma()`.** Quel numero è la
##    fonte unica di «quanta paura fai al prato adesso», e ha già tre
##    consumatori taratissimi. Appiccicargli sopra una seconda semantica
##    («quanto ti notano») è esattamente il modo in cui in questo progetto
##    sono nate le divergenze silenziose. Il raggio è UNO e sta qui sotto.
##  · **Nessun verbo negativo.** Gli otto verbi che il ponte conosce
##    (`src/grafo_ricordi.h`) sono tutti gesti del ciclo di gioco. Un
##    villaggio che ti guarda storto ogni volta che tagli un albero smette
##    di essere un posto dove si va a stare bene.
##  · **Nessun testo, nessun toast, nessuna lettera.** Il villaggio non
##    commenta mai. L'unica uscita legittima è, in ordine: dove uno si
##    mette, come tiene il corpo, e quale simbolo esce in una chiacchiera
##    fra due di LORO.
##  · **Nessuna persistenza.** Questo nodo non entra nel gruppo
##    `persistable` e non scrive niente: il grafo dei ricordi vive in RAM
##    sull'entità ECS e muore col processo. Se durasse, si imparerebbe ad
##    annaffiare in cerchio davanti a un vicino per «caricarlo», e il gesto
##    gentile diventerebbe una moneta.

## IL RAGGIO, in metri: fin dove arriva uno sguardo distratto su un prato.
##
## È **l'unica costante di distanza nuova** che la Fase 4 ha il permesso di
## creare (il progetto ne ha già una ventina scritte a mano, e ogni nuova
## soglia è un posto in cui due sistemi possono cominciare a raccontare due
## villaggi diversi). Sta accanto al predicato che la usa, e chiunque debba
## chiedersi «chi c'era» passa da `puo_vedere()` — nessuno riscrive un 9.
##
## Perché nove: la conversazione ravvicinata del gioco vive dentro 1.6 m
## (`_nearby_resident`), il saluto dentro 1.4, il regalo dentro 4.0
## (`nearest_giftable_resident`), la faccia che insegue il giocatore dentro
## 4.5. Nove metri è il primo valore che sta **fuori** da tutte quelle
## soglie — cioè che non può essere scambiato per nessuna di quelle
## reazioni — e sta dentro il campo visivo utile di una camera a 4,6 m
## d'altezza: un testimone a nove metri è ancora nell'inquadratura mentre
## Mochi annaffia, e la sua testa che si gira si VEDE. Un raggio che
## comprenda testimoni fuori schermo produrrebbe conseguenze la cui
## premessa il giocatore non ha potuto vedere — cioè il guasto di sopra.
const RAGGIO := 9.0

## Chi decide se uno sguardo vale anche un CORPO. Sta di là e non qui: la
## regia è la stessa per tutte e sette le occasioni del vocabolario, e questo
## nodo ne conosce due.
const REGIA := preload("res://scenes/npc/Regia.gd")

## Per quanto tempo la testa resta girata, in secondi.
##
## Misurato sui gesti veri, non scelto a occhio: l'orto tiene Mochi occupata
## 2,1 s a seminare, 2,3 s ad annaffiare, 2,0 s a raccogliere (i tre
## `_busy = false` di `Garden.gd`). Il più lungo è 2,3 — e la scena vuole
## «per tutta la durata del gesto **e un secondo dopo**», perché è il
## secondo dopo a trasformare un'occhiata in un'attenzione. 2,3 + 1,0 ≈ 3,2.
##
## Non è per verbo, ed è una scelta: un tempo diverso per ogni gesto sarebbe
## otto numeri da tarare e da guardare, e nessuno di quegli otto sarebbe più
## leggibile di questo. Chi un giorno volesse la durata vera del gesto la
## faccia arrivare dal chiamante — la firma di `guarda_gesto` la prende già.
##
## **NON ABBASSARLO PER CURARE UNA RAFFICA.** Se qualcuno segnala vicini che
## fissano troppo a lungo mentre si costruisce, il numero da guardare non è
## questo: è il RITMO delle riprese in `Visitor.guarda_gesto`. Questo qui
## regola il gesto SINGOLO — l'annaffiata, la pesca, il dono — cioè
## esattamente quello che deve restare leggibile; accorciarlo rovinerebbe il
## caso buono per rattoppare quello cattivo.
const DURATA_SGUARDO := 3.2

## Il registro dei vicini e il cuore ECS. Si RITROVANO a ogni chiamata
## finché non ci sono entrambi: vedi `_cabla()`.
var _visitors: Node = null
var _cuore: Object = null

## LA FINESTRA DI FUSIONE DEL GRAFO, in secondi, letta dal C++ una volta
## sola (`EcsMondo.debug_grafo_costanti`). Non è una costante di questo file
## e non deve diventarlo: è il numero che decide se un gesto fa un ricordo
## NUOVO o rinfresca quello di prima, vive in `src/grafo_ricordi.h`, e la
## ricevuta deve seguirlo — se un domani qualcuno lo cambia lì, la testa
## deve cambiare ritmo con lui invece di raccontare una regola scaduta.
var _finestra := 0.0


func _ready() -> void:
	# il gruppo È l'API: gli otto siti di emissione chiamano
	# `call_group("percezione", "accaduto", …)` e non conoscono questo nodo.
	# Zero accoppiamento, come il `note()` del Regista — e se un giorno
	# questo nodo non c'è, il gioco continua a girare senza saperlo.
	add_to_group("percezione")


# ---------------------------------------------------------------- il predicato

## CHI PUÒ AVER VISTO. Statica e pura: è l'unico posto al mondo che sa
## rispondere, e ci si può far girare sopra un test senza mezzo villaggio in
## scena. `Visitors.testimoni()` la chiama, e non ne tiene una seconda copia.
##
## Le quattro valvole, e ognuna chiude un modo preciso di sbagliare:
##  · **il corpo non c'è** — `is_hidden()`: la notte i residenti rientrano
##    in casa e il nodo resta nell'albero rimpicciolito a 0.03. Senza questa,
##    tutto il villaggio «vedrebbe» attraverso i muri di casa propria, di
##    notte, e la mattina dopo si comporterebbe di conseguenza.
##  · **dorme** — il pisolino (`tk_nap`): il corpo è nel mondo, ma a occhi
##    chiusi. `Visitor._process` lo sa già (chi dorme non insegue nessuno
##    con lo sguardo); qui lo si dice anche alla memoria, perché sarebbe
##    assurdo ricordarsi di un gesto che non si è potuto guardare.
##  · **è a un appuntamento suo** — `in_scena()`: il concerto al pianoforte,
##    il coro attorno al carillon, il nascondino nel bosco, il raduno al
##    Grande Albero la sera del lutto, la prima parola di un cucciolo, e
##    l'appuntamento delle Promesse. Sono le scene rare del gioco, quelle
##    scritte a mano perché una volta ogni tanto succeda qualcosa di
##    preciso: un gesto qualunque del giocatore non deve poterle
##    interrompere né prendersene il merito.
##    **Questo elenco è una promessa verificabile**, non una didascalia: chi
##    lo allunga deve far chiamare `Visitor.apri_scena` alla scena che
##    aggiunge, o scrive una valvola che non chiude niente. È già successo —
##    per un pezzo l'unico chiamante era `Promesse`, e le cinque scene qui
##    sopra restavano scoperte con questo commento a giurare il contrario.
##  · **è lontano** — oltre `raggio` metri.
##
## Il raggio arriva come parametro e non si legge da qui dentro: così il
## test può stringere e allargare la finestra senza toccare la costante che
## sta provando.
static func puo_vedere(node: Node3D, pos: Vector3, raggio: float) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if pos.distance_to(node.global_position) > raggio:
		return false
	if bool(node.call("is_hidden")):
		return false
	if bool(node.call("dorme")):
		return false
	if bool(node.call("in_scena")):
		return false
	return true


# ------------------------------------------------------------------ il bus

## È ACCADUTO. L'unica API di questo nodo, e la sola cosa che gli otto siti
## di emissione sanno di lei è il suo nome.
##
##  · `verbo` — una parola fra le otto che il ponte conosce ("annaffia",
##    "semina", "raccoglie", "costruisce", "taglia", "pesca", "cucina",
##    "dona"). Si passa il NOME e non un indice: la traduzione vive in un
##    posto solo (`EcsMondo.indice_verbo`), come già per indoli, quirk,
##    fatti, azioni e operatori. Una parola sbagliata non diventa un gesto
##    fantasma: si ferma qui, con un avviso.
##  · `pos` — DOVE è successo, in coordinate mondo. Non è un ornamento: è la
##    quarta scena («l'aiuola che ha visto»), cioè l'unica conseguenza di
##    tutta la fase che il giocatore ritrova con gli occhi, nello stesso
##    punto in cui l'aveva lasciata.
##  · `a_chi` — la label del residente a cui il gesto era rivolto ("" se non
##    era per nessuno). Serve a UNA cosa: chi riceve un dono se lo ricorda
##    il doppio (`R_SU_DI_ME`, l'unica asimmetria fra persone che il grafo
##    conosce, e non è un giudizio).
##
## UNA EMISSIONE PER GESTO, NON UNA PER TESTIMONE: il sito chiama questa
## funzione una volta sola, e la lista di chi c'era si costruisce qui dentro
## una volta sola. Un `accaduto()` dentro un ciclo sui vicini scriverebbe N²
## ricordi e li fonderebbe in un `quante = N`, cioè racconterebbe che Mochi
## ha annaffiato ventotto volte.
func accaduto(verbo: String, pos: Vector3, a_chi := "") -> void:
	if not _cabla():
		return
	var v := int(_cuore.call("indice_verbo", verbo))
	if v < 0:
		# Rumoroso di proposito. Un verbo fuori tabella è un errore di
		# cablaggio, e il modo in cui si manifesterebbe da solo è il
		# peggiore possibile: un gesto che nessuno vede mai, per sempre,
		# con la suite verde.
		push_warning("Percezione: verbo sconosciuto «%s» (il gesto non lo vedrà nessuno)" % verbo)
		return

	var visti: Array = testimoni(pos, RAGGIO)
	if visti.is_empty():
		return

	# Il DESTINATARIO, se c'è, è uno dei testimoni: un dono lo si fa in
	# faccia a qualcuno, e qualcuno che non poteva vedere non lo ha ricevuto.
	# Cercarlo fuori da questa lista vorrebbe dire una seconda passata sul
	# registro dei vicini per un caso che non esiste.
	var soggetto := -1
	if a_chi != "":
		for i in visti.size():
			var riga: Dictionary = visti[i]
			if str(riga.get("label", "")) == a_chi:
				soggetto = int(riga.get("ecs", -1))
				break

	# CICLO CON INDICE ESPLICITO, e non è uno stilismo: le lambda di GDScript
	# catturano per VALORE, e un contatore chiuso dentro una lambda non
	# avanza. È la trappola che nella Vetreria ha lasciato UNA seduta su
	# quattro (tutti gli ancoraggi si chiamavano «Posto0», Godot rinominava i
	# doppioni in «@Node3D@78» e `find_children("Posto*")` non li trovava
	# più) — con la geometria giusta e nessun test in grado di accorgersene.
	for i in visti.size():
		_testimonia(visti[i], v, pos, soggetto)


## CHI C'ERA. Delega al registro dei vicini, che è l'unico a sapere quali
## corpi esistono e quale entità ECS ha ciascuno; il PREDICATO però è di
## qua (`puo_vedere`), accanto al raggio che usa.
func testimoni(pos: Vector3, raggio: float) -> Array:
	if not _cabla():
		return []
	return _visitors.call("testimoni", pos, raggio)


# ------------------------------------------------------------ le due righe

## LE DUE RIGHE. Non si separano, non si riordinano, non ci si mette un `if`
## in mezzo, e non si aggiunge un `continue` fra l'una e l'altra. Vedi la
## regola in cima al file: fra le due c'è tutta la credibilità del sistema.
func _testimonia(riga: Dictionary, verbo: int, pos: Vector3, soggetto: int) -> void:
	var node := riga.get("node") as Node3D
	var id := int(riga.get("ecs", -1))
	# La riga si scarta INTERA o si consuma INTERA: qui, prima delle due
	# righe, e mai in mezzo.
	if node == null or not is_instance_valid(node) or id < 0:
		return
	var nuovo := bool(node.call("guarda_gesto", pos, DURATA_SGUARDO, verbo, _finestra))
	_cuore.call("osserva", id, verbo, pos, soggetto)
	# ------------------------------------------------------------------
	# E LA TERZA RIGA, che è di un'altra specie e sta DOPO le due apposta.
	#
	# La testa che si gira è la premessa, e da sola non basta: misurata, si
	# legge solo da vicino e solo da davanti — di spalle l'imbardata non ha
	# verso (rapporto 1,04: si vedono le orecchie muoversi e non si sa da
	# che parte), e a diciassette metri la testa è venti pixel. Il PUNTO —
	# il corpo che si ferma — si legge a diciassette metri da qualunque
	# azimut, perché non è una forma: è l'assenza improvvisa di movimento in
	# un villaggio che cammina.
	#
	# ⚠️ **STA DOPO, E NON È UNA DI LORO.** Quelle due non possono fallire;
	# questa **quasi sempre fallisce** — il palco del villaggio è ancora
	# caldo, il vicino ha già gesticolato da poco, sta fermo, è a undici
	# metri. Il silenzio è il comportamento normale e la ricevuta resta
	# pagata lo stesso: il degrado va SEMPRE verso il comportamento che
	# c'era già.
	#
	# ⚠️ **E SEGUE IL RICORDO, NON IL GESTO.** `nuovo` è la cosa che
	# `guarda_gesto` ha appena deciso per la TESTA, restituita invece che
	# ricalcolata: nel grafo, gesti uguali e ravvicinati non fanno ricordi
	# nuovi — fondono in uno solo che si rinfresca e conta `quante`. Il
	# ventesimo pezzo di un sentiero non è una cosa vista in più, è la stessa
	# cosa ancora, e un corpo non si ferma due volte per la stessa cosa.
	# Senza questa riga il Punto usciva **quasi sempre in mezzo a una raffica
	# monotona** invece che sul gesto singolo, che è quello che si legge —
	# perché l'usciere serviva chi bussava per primo, e in una raffica bussa
	# sempre la raffica. Il numero non si ricalcola qui: la finestra di
	# fusione vive nel C++ e deve avere UN lettore.
	#
	# E chi era il DESTINATARIO se lo ricorda il doppio (`R_SU_DI_ME`, la
	# sola asimmetria che il grafo conosce): per lui è un'occasione diversa,
	# che aspetta molto meno. Non è un giudizio su una persona — è «quella
	# cosa lì l'hai fatta a me».
	if _visitors.has_method("chiedi_gesto"):
		var occ: String = REGIA.occasione_dello_sguardo(nuovo,
				soggetto >= 0 and soggetto == id)
		if occ != "":
			_visitors.call("chiedi_gesto", str(riga.get("label", "")), occ)


# ------------------------------------------------------------- il cablaggio

## SI RIPROVA A OGNI CHIAMATA, finché non ha trovato tutto.
##
## Non è prudenza: è una trappola già pagata due volte in questo progetto.
## I collaboratori di questo nodo nascono TARDI e a scoppio ritardato — il
## cuore ECS lo crea `Visitors._ensure_ecs()` al primo ciclo del sonno, e i
## figli di CozyWorld nascono in una generazione differita su più frame. Un
## cablaggio fatto una volta sola dentro un `call_deferred` del `_ready`
## trova `null` **per sempre**, e il sistema resta muto senza un errore: è
## esattamente com'è morto il taccuino del Gufo, che cercava il Regista una
## volta e non lo trovava mai.
func _cabla() -> bool:
	if not is_inside_tree():
		return false
	if _visitors == null or not is_instance_valid(_visitors):
		_visitors = get_tree().get_first_node_in_group("visitors")
		_cuore = null
	if _visitors == null:
		return false
	if _cuore == null or not is_instance_valid(_cuore):
		# Il cuore non c'è finché nessun residente è stato censito: è normale
		# in un villaggio appena aperto, e si ritenta al gesto dopo.
		_cuore = _visitors.call("cuore")
		_finestra = 0.0
	if _cuore == null or not is_instance_valid(_cuore):
		return false
	if _finestra <= 0.0:
		# UNA VOLTA SOLA, e appena il cuore c'è: la finestra è una costante
		# del ponte, non un dato che cambia. (Se la lettura fallisse, zero
		# vuol dire «ogni gesto è nuovo» — cioè il comportamento di prima
		# che questa grammatica esistesse: si degrada verso il rumoroso, mai
		# verso il muto.)
		var k: Dictionary = _cuore.call("debug_grafo_costanti")
		_finestra = float(k.get("finestra_fusione", 0.0))
	return true
