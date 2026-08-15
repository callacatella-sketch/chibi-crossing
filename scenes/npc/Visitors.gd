extends Node

## Il via vai del villaggio. Ogni tanto — di giorno, col sereno — un
## animaletto del bosco viene a trovarti: curiosa tra i mobili, si
## riposa sulla panchina e lascia un regalino che puoi raccogliere con E.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const MIND := preload("res://scenes/npc/VillagerMind.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const GUSTO := preload("res://scenes/npc/Gusto.gd")
const DEDUZIONI := preload("res://scenes/npc/Deduzioni.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const VILLAGGIO := preload("res://scenes/npc/Villaggio.gd")
const REGIA := preload("res://scenes/npc/Regia.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const POSTO := preload("res://scenes/world/PostoDiSempre.gd")
const UI_BROWN := Color("6a4a3a")
# Fino a ventotto vicini: il passaparola del Villaggio, le chiacchiere, le
# indoli e le stravaganze rendono per densità — la scala dell'Animo produce
# storie corali (era 4, poi 8: mezzo coro). Il tetto NON è un rubinetto: un
# candidato arriva solo se il giocatore ha costruito un letto libero sotto
# un tetto (_free_house) — 28 abitanti = 28 case volute, una per una.
const MAX_RESIDENTS := 28

const SPECIES := ["riccio", "passerotto"]
const SPECIES_LABEL := {"riccio": "Il Riccio", "passerotto": "Il Passerotto"}
const GIFTS := {
	"riccio": ["una bacca lucida", "un funghetto profumato", "una foglia a forma di cuore"],
	"passerotto": ["una piuma morbidissima", "un semino raro", "un fiocco di lana"],
}

const ENTRIES := [Vector3(14, 0, 8), Vector3(-14, 0, 7), Vector3(11, 0, -6)]
const PLAZA := Vector3(2.5, 0, 5.5)
const CLEARING := Vector3(-1.0, 0.0, -46.0)

const WISH_POOL := [["Aiuola", "garden"], ["Fungo", "garden"], ["Cespuglio", "garden"],
		["Lampada", "comfort"], ["Panchina", "comfort"]]
const WISH_ART := {"Aiuola": "un'aiuola", "Fungo": "un fungo", "Cespuglio": "un cespuglio",
		"Lampada": "una lampada", "Panchina": "una panchina"}

var _player: Node3D
var _build: Node3D
var _daynight: Node3D
var _weather: Node3D
var _sfx

var _active: Node3D
var _timer := 45.0
var _gift: Node3D
var _gift_bob: Tween
var _gift_species := ""

# il gestionale del trasloco: candidato corrente, mente, memoria, residenti
var _mind: RefCounted
var _decided := false
var _welcomes := 0
var _cand_label := ""
var _cand_visits := {}                  # nome -> visite passate (persistito)
var _residents: Array[Dictionary] = [] # {species, cell, node, dna, label, friend, wish, phase, next_act}
## FASE 5, le due misure (vedi `debug_deduzioni_contatori`). In RAM come il
## grafo delle deduzioni che contano: non entrano in nessun salvataggio.
var _ded_ricevute := 0
var _ded_dirotti := 0
var _cooking: Node
var _mail: Node
var _garden: Node
var _cozy: Node3D
var _inventory: Node
var _pockets: Node
var _chat_acc := 0.0
var _wish_acc := 0.0
var _pair_cd := {}
## Il registro delle cricche, se c'è: la co-presenza che `_chats` costruisce
## e oggi butta via. Si ricerca finché non si trova — il nodo nasce nel
## livello, e in un banco non nasce affatto.
var _cricche: Node
## Il dado delle chiacchiere: chi si parla adesso e chi apre bocca. NON si
## salva, ed è una decisione — una chiacchierata è ambiente, dura tre
## secondi e non lascia niente dietro di sé (`_run_chat` tira già `randf()`
## per il tema allo stesso titolo). I dadi che si salvano sono quelli che
## decidono una vita, e stanno in `Animo`.
var _chat_rng := RandomNumberGenerator.new()
## Chi ha addosso la posa della PORTA CHIUSA (label -> true), messa qui
## sotto. Serve a sapere che è NOSTRA: il meta "postura" lo usano anche gli
## Affetti e il telegrafo della ribellione, e con gli stessi nomi —
## toglierlo alla cieca spegnerebbe la posa di un altro sistema, che non se
## ne accorgerebbe. Non si salva: i corpi rinascono nudi.
var _posa_fuori := {}

# la vita interiore: label -> VillagerBrain (bisogni, indole, memoria)
var _brains := {}
## L'ANIMA di ogni residente (scenes/npc/Animo.gd) e il villaggio che li
## tiene insieme: pressioni, ricordi, carattere e passaparola. Il cervello
## decide cosa fare adesso; l'animo decide come STA, e se ti perdona.
var _animi := {}
var _villaggio: RefCounted
# la memoria dei partiti dal salvataggio, in attesa che il grafo nasca
# (lazy): reiniettata in _iscrivi_al_villaggio, salvata in save_extra
var _partiti_salvati := {}
## Il raffreddamento del sussulto: uno per residente, così la reazione
## istintiva scatta all'AVVICINARSI e non a ogni fotogramma.
var _sussulto_cd := {}
# LA STRADA LENTA in attesa: label -> secondi che restano prima che la
# testa capisca chi è arrivato. Senza questa coda il sussulto restava una
# reazione senza risoluzione — il vicino trasaliva e poi, semplicemente,
# non succedeva più niente.
var _riconoscimenti := {}
# la posizione del giocatore al tick precedente, per sapere quanto corre
var _pp_prec := Vector3.ZERO
var _spiegato_le_strade := false
## Chi ti sta venendo a cercare, e da quanto: {label -> secondi di attesa}.
var _in_confronto := {}
## L'orologio del canale della vita quotidiana: secondi da quando gira il
## villaggio. Non si salva — il canale è un ritmo, non uno stato.
var _vita_orologio := 0.0
var _vita_ultimo_qualunque := -1.0e18   # quando abbiamo detto QUALUNQUE cosa
var _vita_ultimo := {}                  # genere -> quando abbiamo detto QUELLA

var _prompt: PanelContainer
var _prompt_label: Label
var _toast: PanelContainer
var _toast_label: Label


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("visitors")   # il cursore delle Voci ci chiede un assaggio
	# in partita le chiacchiere non si ripetono uguali da una sessione
	# all'altra; nei banchi il seme resta quello di fabbrica (che `_ready`
	# non viene chiamato) e le misure sono ripetibili
	_chat_rng.randomize()
	_player = get_node("%Player")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_weather = get_node_or_null("../Weather")
	_sfx = get_node_or_null(^"/root/Sfx")
	(func():
		_cooking = get_node_or_null("../Cooking")
		_mail = get_node_or_null("../Mail")
		_garden = get_node_or_null("../Garden")
		_cozy = get_node_or_null("../CozyWorld")
		_inventory = get_node_or_null("../Inventory")
		_pockets = get_node_or_null("../Pockets")).call_deferred()
	if _daynight:
		_daynight.day_changed.connect(_on_new_day)
	_build_ui()


# a ogni nuovo mattino i desideri esauditi lasciano posto a sogni nuovi
var _was_raining := false
var _th_cd := 5.0


# l'età di ogni residente (dal Filo Rosso) attraversa corpo e voce
func _apply_eta() -> void:
	var legami: Node = get_tree().get_first_node_in_group("legami")
	if legami == null:
		return
	for r in _residents:
		if str(r.get("species", "")) != "chibi":
			continue
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node):
			var nome := str(r.get("dna", {}).get("name", ""))
			# i due capi della vita, nello stesso posto: quanto deve
			# ancora crescere (1 per chi è arrivato già grande) e quanti
			# anni ha. Il corpo li fonde da sé.
			node.call("set_cucciolo", float(legami.call("crescita", nome)))
			node.call("set_eta", float(legami.call("eta_f", nome)))


func debug_eta(f: float) -> void:
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node):
			node.call("set_eta", f)


func _random_resident_node() -> Node3D:
	var pool: Array[Node3D] = []
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden"):
			pool.append(node)
	return pool[randi() % pool.size()] if not pool.is_empty() else null


## Un «ya-ho» di prova per il cursore delle Voci: chi muove la manopola
## deve sentire subito COSA sta regolando — e una voce vera del villaggio
## dice molto più di un campanello d'interfaccia. Se il villaggio è vuoto
## (o siamo al titolo) non succede nulla: nessun suono finto.
func assaggio_di_voce() -> void:
	var chi := _random_resident_node()
	if chi and chi.has_method("speak"):
		chi.call("speak", ["ciao"], "felice")


func _on_new_day(_day: int) -> void:
	_giorno_di_animo()
	# «sa-la! ya-ho!» — il buongiorno al sole di un mattiniero
	var speaker := _random_resident_node()
	if speaker:
		speaker.call("speak", ["sole", "ciao"], "felice")
	# le stagioni della vita avanzano: il Filo Rosso detta l'età
	_apply_eta()
	for r in _residents:
		var wish: Dictionary = r.get("wish", {})
		if not wish.is_empty() and bool(wish.get("done", false)):
			r["wish"] = {}
		# (Fase 4) UNA PROMOZIONE AL GIORNO, e il contatore si azzera QUI —
		# col giorno, non con un timer suo. Un secondo orologio sul giorno
		# sarebbe una seconda idea di quando finisce una giornata, e questo
		# progetto ne ha già una (`day_changed`, che detta anche l'età, i
		# desideri e il giro dell'Animo).
		r["promosso_oggi"] = false


# =========================================================================
# IL VOCABOLARIO DEL CORPO — l'usciere del villaggio
# =========================================================================
#
# I gesti stanno in `Gesti.gd` e il corpo in `Visitor.gd`. Qui c'è l'unica
# cosa che né l'uno né l'altro possono sapere: **quanti se ne possono vedere
# insieme**. Ed è la domanda più pericolosa di tutto il lavoro.
#
# ⚠️ **UN GETTONE SENZA PERIODO È UN MIMO PERMANENTE.** «Uno per volta in
# tutto il villaggio» sembra la regola giusta e da sola significa *sempre
# esattamente un mimo in scena, per sempre*: appena uno finisce, il primo che
# passa prende il posto. Serve anche il PERIODO — quanto raramente il gettone
# torna disponibile — ed è il numero che decide se il villaggio sembra vivo o
# sembra un carillon di pupazzi.
#
# Si tara contro quello che il villaggio fa GIÀ, non contro zero: una
# chiacchierata ogni 3,5 s (`_chat_acc`), un sussulto ogni 9 s per residente,
# un cambio di mestiere ogni 0,4–1,6 s, il fiato dell'anziano il 17% del
# tempo. Venti secondi è il primo valore che sta **un ordine di grandezza
# sopra** la cosa più rara che il villaggio produce già.
#
# ⚠️ **DODICI, E IL NUMERO SI SCEGLIE SU QUANTO IL GETTONE MORDE, non su
# quanti gesti escono.** Misurato con `tools/prova_villaggio_gesti.gd`
# (quattordici residenti, cinque minuti, un giocatore che lavora):
#
#   | gettone | richieste | rifiutate DAL GETTONE | gesti | frazione mimo |
#   |---|---|---|---|---|
#   | 20 s | 383 | **193 (50%)** | 6 | 1,13% |
#   | 12 s | 175 | **26 (15%)** | 4 | 1,41% |
#
# ⚠️ **E LE DUE CORSE NON SONO APPAIATE**: il numero di RICHIESTE è più che
# raddoppiato fra l'una e l'altra (383 contro 175), perché dipende da quante
# volte il lavoro di Mochi trova dei testimoni — cioè dal giro che fa il
# giocatore, non dal gettone. «Sei gesti contro quattro» perciò **non dice
# niente**, ed è la stessa trappola per cui in questo progetto le misure si
# fanno A/B nella STESSA corsa. Quello che si può confrontare è la
# SELETTIVITÀ del gettone rispetto alla domanda della sua corsa, e lì la
# differenza è netta: a venti secondi il gettone era il collo di bottiglia
# (metà dei no erano suoi), a dodici lo sono le condizioni del mondo — il
# vicino deve camminare, deve avere strada davanti, non deve aver appena
# gesticolato. **È l'ordine giusto: il mondo decide QUANDO un gesto ha senso,
# il gettone impedisce soltanto che se ne vedano due insieme.**
#
# La frazione di secondi-vicino passata dentro un gesto resta 1,1–1,4%, dieci
# volte sotto il tetto del mimo (15%), e i simultanei restano **1** in tutte
# e due le corse.
const GESTO_PASSO := 12.0
## E ogni vicino ha il suo riposo lungo: cinque minuti, per genoma ±30%. Non è
## la stessa cosa del gettone — il gettone dice «uno per volta», questo dice
## «non sempre lo stesso», che è quello che distingue un villaggio da un
## teatrino con un attore.
const GESTO_RIPOSO := 300.0
## E MAI OLTRE I NOVE METRI. A quindici metri un gesto da dieci centimetri
## sono 6,7 pixel: rumore. Un rumore illeggibile insegna al giocatore che i
## vicini si muovono a caso, che è il danno peggiore che questo lavoro possa
## fare. È lo stesso raggio di `Percezione.RAGGIO`, e per la stessa ragione:
## fuori di lì la premessa non si vede.
const GESTO_RAGGIO := 9.0
## L'altezza a cui si guarda un chibi: mezzo metro, il petto. Serve alla
## domanda dell'inquadratura, e non è un numero nuovo — è la stessa quota a
## cui `Deduzioni` misura se il giocatore vede una testa girarsi.
const GESTO_QUOTA := 0.55
## LE TRE QUOTE DEL CORPO a cui si chiede «di qui si vede?». Un chibi è alto
## poco più di un metro (la testona è centrata a 0,92): sono la testa, il
## petto — che è `GESTO_QUOTA`, cioè il punto che l'inquadratura guarda già —
## e le gambe.
##
## ⚠️ **TRE E NON UNA, e non è prudenza: è che una sola sarebbe una moneta.**
## Un palo di staccionata largo quattordici centimetri copre un punto e non
## copre un corpo; un tetto copre tutto. Con un raggio solo il primo caso è
## un no — un gesto buono buttato — e nessuno può accorgersene.
const GESTO_QUOTE := [0.90, 0.55, 0.22]
## …e quante devono essere coperte perché si taccia: **TUTTE E TRE.**
##
## ⚠️ **E LA MISURA NON DECIDE FRA DUE E TRE — lo dice la misura stessa.**
## MISURATO nel villaggio vero contro l'oracolo dei PIXEL (124 campioni,
## `tools/misura_occlusione.gd`: si spegne il corpo per un fotogramma e si
## conta di quanto cambia il quadro), la maschera è quasi sempre TUTTA O
## NIENTE — 74 campioni a zero quote, 47 a tre, e **tre soli in mezzo**. Fra
## «due» e «tre» ballano tre campioni su centoventiquattro: chi scegliesse
## col numero starebbe leggendo il rumore.
##
## Si sceglie TRE per la ragione di sempre: **nel dubbio il gesto esce.** È
## la stessa direzione di «senza camera si passa» — il degrado va verso
## quello che c'era, non verso il silenzio. Un palo, uno stipite, uno
## schienale coprono un pezzo di corpo e non coprono una persona.
##
## E quello che il numero compra si vede sull'esito, non sulla soglia:
## **sui gesti VERI, a cancello acceso, gli invisibili sono zero.**
const GESTO_COPERTO_MIN := 3

var _gesto_acc := 0.0        # il gettone del villaggio
var _gesto_chi := ""         # chi lo tiene adesso
var _gesto_riposo := {}      # label -> secondi che gli restano di riposo
## Quante teste inclinate si vedono INSIEME in tutto il villaggio. Il Capo
## non prende il gettone (non ferma nessuno e non trasla nessuno), ma ha la
## sua scarsità, e la ragione è estetica: **tre teste inclinate insieme sono
## una posa di gruppo, non tre pensieri.**
##
## PROVINATO guardando (`tools/provino_capi.gd`, la camera vera del gioco,
## tre chibi a sette metri): a tre, i musetti si inclinano dalla stessa parte
## e il quadro si legge come una coreografia — quello che il vocabolario del
## corpo esiste per non essere. A due, sono due persone che stanno pensando a
## due cose diverse.
const CAPO_MAX := 2
## LA SALA D'ATTESA: label -> {occasione, extra, scade, vicino_a}.
##
## Certe occasioni capitano quando il corpo non è nelle condizioni di dirle:
## il Limbico fa cambiare idea a uno che è ancora fermo, la promozione di un
## ricordo cade su uno seduto in panchina. Il Punto e il Largo vogliono
## tutti e due un corpo in cammino — è la loro natura, sono contrasti di
## MOTO — quindi la scelta è fra buttare l'occasione e aspettare un attimo.
##
## ⚠️ **E UN GESTO RIMANDATO VIVE QUANTO LA SUA PREMESSA, mai un secondo di
## più.** Non è una scadenza tarata a occhio: è il tempo per cui il
## giocatore ha ancora sotto gli occhi la ragione. Per la promozione è la
## TESTA GIRATA (`Percezione.DURATA_SGUARDO`), che è letteralmente la
## premessa che sta guardando; per l'evitamento sono i pochi secondi in cui
## quel posto è ancora «quello lì». Scaduto il tempo si tace, e nessuno lo
## sa: una conseguenza che arriva quando la premessa non c'è più non attenua
## l'effetto, **lo inverte**.
##
## UNA VOCE PER PERSONA: chi ha già qualcosa in attesa e riceve una seconda
## occasione tiene la NUOVA (quella vecchia ha perso il suo momento). Due
## code sullo stesso corpo sarebbero due gesti in fila, cioè pantomima.
var _gesto_evita := {}
## Fin dove il posto marchiato resta «quello lì»: oltre, il gesto indicherebbe
## un punto che il giocatore non collega più a niente.
const GESTO_EVITA_RAGGIO := 7.0


## L'USCIERE. Torna false — e non fa niente — se il villaggio non ha spazio
## per questa OCCASIONE adesso: **chi perde muore in silenzio**, non si
## accoda. Una coda su ventotto corpi trasforma un picco (il falò, quaranta
## pietre di sentiero) in un minuto di pantomima.
##
## ⚠️ **SI CHIEDE PER OCCASIONE, NON PER FRASE, e la differenza è la regia.**
## Prima l'usciere riceveva «premessa» e serviva chi bussava per primo — e
## chi bussa per primo è sempre la stessa: `ha_visto` capita a ogni gesto del
## giocatore che qualcuno veda (misurato: 383 richieste in cinque minuti,
## contro le zero-o-una di una deduzione). Con un gettone solo, l'occasione
## più frequente si prendeva il palco sempre, e le cinque che valgono di più
## non si vedevano mai. La tabella che dice quanto vale ciascuna sta in
## `Regia.OCCASIONI` — una sola casa, pura, falsificabile — e qui si
## esegue.
##
## ⚠️ **E CONTA I NO, uno per uno.** Il silenzio ha otto ragioni diverse e da
## fuori si vedono tutte uguali: un banco che dice solo «zero gesti» lascia
## indovinare, e si finisce per accusare il cablaggio quando il gettone era
## semplicemente occupato. Il conto sta in RAM, costa un incremento, e lo
## legge `debug_gesti_contatori()`.
var _gesto_no := {}
## …e i SÌ, per occasione: senza, il referto dice quanti gesti sono usciti e
## non QUALI momenti della vita interiore il giocatore ha potuto vedere —
## che è l'unica cosa che questa fase deve misurare.
var _gesto_si := {}

## `conta` distingue il PRIMO tentativo dalle riprove della sala d'attesa:
## senza, un'occasione che aspetta il passo per tre secondi si conterebbe
## duecento volte e il referto direbbe che è la più insistente del villaggio
## invece che la più rara. Le riprove hanno la loro riga (`↻`).
## Un no col suo nome. Le RIPROVE della sala d'attesa non entrano
## nell'istogramma: un'occasione che aspetta il passo per tre secondi si
## conterebbe ottanta volte e il referto direbbe che è la più insistente del
## villaggio — misurato, 963 «un altro sta parlando» su 1133 richieste vere.
## Il loro conto è la riga `↻`, che dice un'altra cosa e la dice a parte.
func _no(conta: bool, perche: String) -> void:
	if conta:
		_gesto_no[perche] = int(_gesto_no.get(perche, 0)) + 1


func chiedi_gesto(label: String, occasione: String, extra := {},
		conta := true) -> bool:
	if conta:
		_gesto_no["chiesti"] = int(_gesto_no.get("chiesti", 0)) + 1
		_gesto_no["? " + occasione] = int(_gesto_no.get("? " + occasione, 0)) + 1
	else:
		_gesto_no["↻ " + occasione] = int(_gesto_no.get("↻ " + occasione, 0)) + 1
	var nome := REGIA.frase_di(occasione)
	if nome == "":
		# rumoroso di proposito: un'occasione scritta storta non fallisce —
		# **smette di parlare, in silenzio, per sempre** (è il guasto della
		# tabella delle parole del cielo, e quello del verbo fuori tabella
		# in `Percezione.accaduto`).
		push_warning("Visitors: occasione sconosciuta «%s» (quel momento non si vedrà mai)" % occasione)
		return false
	var perche_cancello := _cancelli_gesto(label, occasione)
	if perche_cancello != "":
		_no(conta, perche_cancello)
		return false
	var nodo := node_di(label)
	if not bool(nodo.call("frase", nome, extra)):
		_no(conta, _perche_no(nodo, nome))
		return false
	_gesto_chi = label
	_gesto_acc = GESTO_PASSO
	_paga_gesto(label)
	_gesto_si[occasione] = int(_gesto_si.get(occasione, 0)) + 1
	return true


## I SETTE CANCELLI DEL VILLAGGIO, e nessuno di loro tocca un corpo: "" se si
## passa, altrimenti il nome del no.
##
## ⚠️ **SONO A PARTE PERCHÉ HANNO DUE LETTORI, e il secondo deve poter
## chiedere SENZA IMPEGNARE.** Un duetto si recita in due o non si recita
## affatto: prima di accendere qualcuno bisogna sapere che tutti e due
## potrebbero, e per saperlo bisogna fare queste sette domande **su due
## persone**, a mani vuote. Ricopiarle sarebbe la tabella gemella per la
## quarta volta in questo solo file.
func _cancelli_gesto(label: String, occasione: String) -> String:
	# IL CORPO DI PRIMA NON HA ANCORA FINITO. È l'unica regola che non ha
	# eccezioni: due gesti insieme non sono due persone che pensano, sono un
	# carillon. (Un duetto non fa eccezione: prende UN gettone in due.)
	if _gesto_chi != "":
		return "un altro sta parlando"
	# …E IL PALCO È ANCORA CALDO. Quanto debba essersi raffreddato lo dice
	# l'occasione: il periodo intero per quella che capita di continuo, un
	# decimo per quella che il giocatore si è tirato addosso da solo.
	if not REGIA.palco_libero(occasione, _gesto_acc, GESTO_PASSO):
		return "palco caldo"
	# …E IL RIPOSO DI QUELLA PERSONA, con la STESSA aritmetica e lo stesso
	# numero. Non è simmetria: è la stessa fame di prima, un piano più in
	# basso — MISURATO nel villaggio vero con ventotto residenti, dieci
	# minuti, un giocatore che lavora. Il palco era ordinato e il riposo no,
	# e il risultato è che i **439 no più numerosi erano suoi**: `ha_visto`
	# bussa 1105 volte e brucia il riposo di chi passa, cosicché la
	# promozione di un ricordo (26 richieste) e il dono (36) trovavano
	# sempre gente che «ha appena parlato». Tredici gesti su tredici erano
	# `ha_visto`, cioè l'unica occasione che il vocabolario non era stato
	# fatto per mostrare.
	if not REGIA.palco_libero(occasione, float(_gesto_riposo.get(label, 0.0)),
			GESTO_RIPOSO):
		return "riposo"
	var nodo := node_di(label)
	if nodo == null or not is_instance_valid(nodo) \
			or not nodo.has_method("frase"):
		return "nessun corpo"
	# FUORI RAGGIO NON SI RECITA. Il degrado va verso il silenzio: un gesto
	# che il giocatore non può vedere non è mezzo gesto, è zero.
	if _player == null \
			or _player.global_position.distance_to(nodo.global_position) > GESTO_RAGGIO:
		return "fuori raggio"
	# …E NEMMENO FUORI DALL'INQUADRATURA.
	if not _nell_inquadratura(nodo.global_position):
		return "fuori dall'inquadratura"
	# …E NEMMENO DIETRO QUALCOSA. «Dentro l'inquadratura» non vuol dire
	# «visibile»: il villaggio è pieno di tetti, di muri, di alberi e di
	# schienali, e il gesto di un corpo coperto costa esattamente quanto
	# quello di un corpo che si vede — dodici secondi di gettone e cinque
	# minuti di riposo, tolti a uno che si sarebbe visto. È il gate più caro
	# dei sette (tre raggi contro la fisica) ed è per questo che sta per
	# ultimo: ci arriva una richiesta ogni parecchi secondi, non mille al
	# minuto.
	if debug_occlusione and _gesto_coperto(nodo.global_position):
		return "coperto"
	return ""


## IL CONTO DI CHI HA PARLATO: il riposo lungo di quella persona, per genoma
## ±30%. Il GETTONE del villaggio non sta qui — lo paga il chiamante, perché
## un duetto ne paga **uno solo in due** ma il riposo lo devono a testa: stare
## in una cricca non compra palco.
func _paga_gesto(label: String) -> void:
	var s := hash(label) % 601
	_gesto_riposo[label] = GESTO_RIPOSO * (0.85 + 0.30 * float(s) / 600.0)


# =========================================================================
# IL DUETTO — l'unica frase che questo vocabolario dice in due
# =========================================================================
#
# A si ferma. Un battito dopo, si ferma B. Restano fermi insieme più di un
# secondo, poi ripartono tutti e due decisi, e vanno dalla stessa parte.
#
# ⚠️ **NON È UN GESTO NUOVO.** È il Punto deciso, due volte, sfalsato. Il
# significato non sta in nessuno dei due corpi: sta **nell'intervallo**, che
# è l'unico canale di questo gioco che non appartiene a nessun rig.
#
# ⚠️ **E IL RITARDO NON È UNA RIFINITURA: È LA FRASE.** A zero sono due corpi
# che si bloccano nello stesso fotogramma, cioè un singhiozzo del motore —
# il giocatore lo legge come un difetto, non come un momento. A quattro
# decimi il secondo corpo è una REAZIONE al primo. Il numero ha un
# precedente misurato in questo stesso gioco: la nuvoletta di chi risponde a
# una chiacchierata esce a +1,1 s (`_run_chat`), e si legge da sempre come
# una risposta.

## QUANTO ASPETTA CHI RISPONDE. Provinato affiancato
## (`tools/provino_duetto.gd`), con una tessera di controllo che contiene un
## singhiozzo VERO di tre fotogrammi: se duetto e singhiozzo si assomigliano,
## il numero è sbagliato.
const DUETTO_RITARDO := 0.40
## …e fin dove la battuta può slittare per aspettare il fiato di un anziano.
## Oltre, il secondo fermo non è più una risposta: è un altro fatto.
const DUETTO_RITARDO_MAX := 0.90

## ⚠️ **IL DUETTO SI RECITA SOLO OLTRE IL RAGGIO DELLA CHIACCHIERA, e non è
## una taratura: è la cura di una COLLISIONE DI SAGOME.**
##
## «In questo gioco non succede mai niente insieme» è falso. `_run_chat` gira
## tutti e due i musi nello stesso fotogramma, la nuvoletta di B esce a
## +1,1 s e il cuoricino a +2,2: **la chiacchierata È GIÀ un duetto
## sfalsato**. Due corpi che si fermano l'uno per l'altro a un metro e mezzo
## di distanza, quindi, non si leggono come «si sono trovati» — si leggono
## come «una chiacchierata a cui non sono uscite le bolle», che è peggio di
## niente perché insegna al giocatore che le bolle a volte mancano.
##
## La cura è geometrica: `_chats` guarda entro 1,9 m, e sopra i 2,2 m una
## chiacchierata **è impossibile per costruzione**. Quello che si vede lì non
## somiglia a nient'altro che il gioco faccia.
const DUETTO_MIN := 2.2
## …e non oltre: due corpi agli estremi dell'inquadratura sono due fatti, non
## uno. (Il Punto pretende `GESTO_STRADA_MIN` = 3 m di strada davanti a
## ciascuno, quindi la finestra esiste davvero: due che convergono su uno
## stesso punto da tre metri ciascuno stanno fra i 2,2 e i 6.)
const DUETTO_MAX := 6.0


## CHIEDE UN DUETTO. Torna `false` — e **non muove nessuno dei due** — se il
## villaggio o uno dei due corpi non è nelle condizioni.
##
## ⚠️ **O TUTTI E DUE, O NESSUNO, e non è una preferenza estetica.** Un Punto
## solitario in mezzo al prato il giocatore lo attribuisce a tutt'altro — a
## quello che stava facendo lui, che è la cosa che il vocabolario gli ha
## insegnato a fare. Un duetto troncato non attenua l'effetto: **lo inverte**,
## e per giunta ha già speso il gettone di tutti.
##
## L'indivisibilità è costruita, non sperata: si accende **prima chi
## risponde** — che per quattro decimi di secondo non si vede, sta in sala
## d'attesa — e solo dopo chi apre. Se chi apre non ce la fa, la battuta si
## annulla e **non è mai esistita**. L'ordine inverso lascerebbe in scena un
## corpo fermo senza risposta.
##
## E il conto: **UN gettone di villaggio in due** (un duetto è un momento
## solo), ma **il riposo lo pagano a testa** — stare in una cricca non compra
## palco, e senza questa riga i due che si ritrovano diventerebbero i due che
## si vedono di più, cioè la classifica dall'altra porta.
##
## ⚠️ **IL RESIDUO, DICHIARATO.** L'indivisibilità la garantisce questa
## funzione nell'istante in cui concede; nei quattro decimi successivi il
## MONDO può ancora togliere di mezzo chi deve rispondere — si apre una scena
## scritta, arriva un pisolino, il corpo si nasconde — e la rete di
## `Visitor._process` gli svuota la sala d'attesa. Allora chi ha aperto
## recita da solo. La finestra è di ventiquattro fotogrammi e comincia subito
## dopo che i sette cancelli hanno dichiarato libero quel corpo, quindi il
## caso è vicino allo zero; e quello che resta a schermo è **un Punto
## singolo**, cioè una cosa che il gioco fa comunque tutti i giorni. Si
## dichiara invece di curarla, perché la cura vorrebbe che chi risponde
## sapesse di chi apre — cioè un legame fra due corpi che oggi non esiste, e
## che costerebbe più di quel che vale.
func chiedi_duetto(label_a: String, label_b: String, occasione: String,
		conta := true) -> bool:
	if conta:
		_gesto_no["chiesti"] = int(_gesto_no.get("chiesti", 0)) + 1
		_gesto_no["? " + occasione] = int(_gesto_no.get("? " + occasione, 0)) + 1
	var nome := REGIA.frase_di(occasione)
	if nome == "":
		push_warning("Visitors: occasione sconosciuta «%s» (quel momento non si vedrà mai)" % occasione)
		return false
	if label_a == label_b:
		_no(conta, "duetto: uno solo")
		return false
	# i sette cancelli del villaggio, su TUTTI E DUE, a mani vuote
	for l in [label_a, label_b]:
		var p := _cancelli_gesto(str(l), occasione)
		if p != "":
			_no(conta, p)
			return false
	var na := node_di(label_a)
	var nb := node_di(label_b)
	# LA DISTANZA FRA I DUE è la valvola che separa questa frase dalla
	# chiacchierata, e quella che tiene i due corpi in uno sguardo solo
	var d := na.global_position.distance_to(nb.global_position)
	if d < DUETTO_MIN:
		_no(conta, "duetto: troppo vicini (sembra una chiacchierata)")
		return false
	if d > DUETTO_MAX:
		_no(conta, "duetto: troppo lontani")
		return false
	# ⚠️ **CHI APRE NON SI INDOVINA: SI ENUMERA.** Le letture possibili della
	# stessa scena sono due, e si prende la prima che sta in piedi per intero
	# — così non esiste il caso «ho scelto A, e adesso scopro che A non può».
	#
	# **Fra le due si preferisce quella in cui apre l'ANZIANO**, e non è
	# gentilezza: il corpo di un anziano non frena — si accomoda sopra il
	# fermo che fa già da sé, 1,3 s ogni 7,5 — quindi **il suo fermo è già in
	# calendario** e l'altro ci reagisce. Il contrario vorrebbe dire aspettare
	# il respiro di un vecchio per chiudere una frase che è già cominciata:
	# un battito che balla di secondi invece che di decimi.
	var ordini: Array = [[label_a, label_b], [label_b, label_a]]
	if bool(nb.call("del_fiato")) and not bool(na.call("del_fiato")):
		ordini.reverse()
	var motivo := "duetto: nessuno dei due può aprire adesso"
	for o in ordini:
		var n_apre := node_di(str(o[0]))
		var n_risp := node_di(str(o[1]))
		# si CHIEDE, non si impegna: `punto_impedimento` è la stessa funzione
		# che `gesto()` userà fra tre righe, quindi qui non si indovina niente
		var imp := str(n_apre.call("punto_impedimento"))
		if imp == "":
			imp = str(n_risp.call("punto_impedimento"))
		if imp != "":
			motivo = imp
			continue
		# chi apre dev'essere nel suo fiato ADESSO (per chi non ha l'età del
		# fiato è sempre vero)
		if float(n_apre.call("fiato_fra", 0.0, 0.0)) < 0.0:
			motivo = "duetto: chi apre non ha il fiato adesso"
			continue
		# …e chi risponde dev'essere nel suo, dentro la finestra della
		# battuta. Se non ci sarà, **si tace, e nessuno lo sa.**
		var battuta := float(n_risp.call("fiato_fra", DUETTO_RITARDO,
				DUETTO_RITARDO_MAX))
		if battuta < 0.0:
			motivo = "duetto: il fiato di chi risponde non cade nella battuta"
			continue
		# PRIMA LA RISPOSTA (che per quattro decimi non si vede), POI
		# L'APERTURA — e se l'apertura non riesce, la battuta non è mai
		# esistita.
		if not bool(n_risp.call("frase", nome, {"fra": battuta})):
			motivo = _perche_no(n_risp, nome)
			continue
		if not bool(n_apre.call("frase", nome, {})):
			n_risp.call("attesa_annulla")
			motivo = _perche_no(n_apre, nome)
			continue
		# IL GETTONE LO TIENE CHI RISPONDE, perché finisce per ultimo: il suo
		# `gesto_in_corso()` è già pieno (la sala d'attesa conta), quindi il
		# villaggio resta zitto da adesso fino all'ultimo fotogramma del
		# duetto invece che fino a quattro decimi prima.
		_gesto_chi = str(o[1])
		_gesto_acc = GESTO_PASSO
		_paga_gesto(str(o[0]))
		_paga_gesto(str(o[1]))
		_gesto_si[occasione] = int(_gesto_si.get(occasione, 0)) + 1
		_duetto_ultimo = {"apre": str(o[0]), "risponde": str(o[1]),
				"battuta": battuta}
		return true
	_no(conta, motivo)
	return false


## L'ultimo duetto concesso: chi ha aperto, chi ha risposto, di quanto è
## slittata la battuta. In RAM, non si salva, e **nel gioco non lo legge
## nessuno** — serve ai banchi, che il ritardo devono misurarlo e non
## crederci sulla parola.
var _duetto_ultimo := {}


func debug_duetto_ultimo() -> Dictionary:
	return _duetto_ultimo.duplicate()


## PERCHÉ IL CORPO HA DETTO DI NO, con la sua parola.
##
## ⚠️ **LA RISPOSTA È DEL CORPO, non di questa funzione.** Le precondizioni
## del Punto stavano riscritte qui a mano, e le due copie **si erano già
## staccate**: `blend <= 0.6` invece di `< 0.6`, e `_gs_viaggio` guardato
## prima della strada invece che dopo. Un referto che racconta un no diverso
## da quello vero è peggio di un referto che tace — durante una messa a punto
## costa venti minuti nel posto sbagliato, e lo dice la nota qui sotto.
func _perche_no(nodo: Node3D, nome: String) -> String:
	if _e_un_punto(nome):
		var p := str(nodo.call("punto_impedimento"))
		return p if p != "" else "corpo occupato"
	if nome == "sollievo":
		# ⚠️ E LO SI CHIEDE AL CORPO, non lo si indovina. Un'etichetta messa a
		# naso è la stessa cosa di «zero gesti»: durante una messa a punto ho
		# letto «nessun buio prima» su un rifiuto che di buio ne aveva da
		# vendere, e ho cercato per venti minuti nel posto sbagliato. Il
		# referto che tira a indovinare è peggio del referto che tace.
		return ("nessun buio prima"
				if not bool(nodo.call("_sussulto_fresco"))
				else "corpo occupato")
	return "corpo occupato"


## Questa frase è un PUNTO? Cioè: `punto_impedimento()` sa rispondere per lei?
##
## Si LEGGE dalla tabella vera (`Gesti.FRASI`), non da un elenco ricopiato:
## un elenco a mano resterebbe indietro di una riga il giorno che qualcuno
## aggiunge una frase, e il referto tornerebbe a tirare a indovinare **proprio
## sulla frase nuova**, che è quella su cui si sta lavorando.
func _e_un_punto(frase: String) -> bool:
	var v: Dictionary = GESTI.FRASI.get(frase, {})
	return str(v.get("g", "")) == "punto"


## IL GIOCATORE CE L'HA DAVANTI? Non «vicino»: **dentro l'inquadratura**.
##
## ⚠️ **IL RAGGIO ERA UN'APPROSSIMAZIONE DELLA VISIBILITÀ, E IN QUESTO GIOCO
## APPROSSIMA MALE.** La camera non ha imbardata (`Player.tscn`: guarda −Z,
## 2,70 m sopra e 3,70 dietro Mochi, fov 50) e il giocatore non la può
## girare: **buona parte del cerchio dei nove metri sta dietro la macchina da
## presa**, e un gesto che parte lì consuma il gettone del villaggio (12 s) e
## il riposo di quella persona (5 minuti) per mostrare una cosa che nessuno
## può vedere in nessun modo. È la regola 4 della `Regia` presa sul serio —
## «un gesto che nessuno vede non è mezzo gesto: è zero» — e finora era
## scritta nel commento e non nel codice.
##
## MISURATO nel villaggio vero (`tools/provino_vocabolario.gd`, parte V:
## venti residenti, otto minuti, un giocatore che cammina e lavora):
## **12 gesti concessi, 8 fuori dall'inquadratura — il 67%**. Non è una
## rifinitura: due terzi del vocabolario si spendevano dove non arriva
## l'occhio, e il gettone che li aveva pagati restava caldo dodici secondi.
##
## Il degrado va SEMPRE verso quello che c'era: **senza camera si passa** —
## le suite headless, i banchi, il diorama del titolo e chiunque non abbia un
## `Camera3D` corrente continuano a comportarsi come prima. Spegnere una
## funzione per una domanda a cui non sappiamo rispondere sarebbe il degrado
## dalla parte sbagliata — è la stessa regola con cui il portiere del cuore
## che scrive legge la RAM della macchina: **zero vuol dire «non lo so», e
## «non lo so» non è mai un no**.
func _nell_inquadratura(pos: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var vp := get_viewport()
	if vp == null:
		return true
	var cam := vp.get_camera_3d()
	if cam == null:
		return true
	return cam.is_position_in_frustum(pos + Vector3(0, GESTO_QUOTA, 0))


## …E DAVANTI NON C'È NIENTE? Il frustum dice DOVE sta un corpo, non se lo
## si vede: un tetto, un muro, il tronco del Grande Albero e lo schienale di
## una panchina stanno dentro l'inquadratura esattamente come lui.
##
## ⚠️ **UN GESTO CONCESSO E NON VISTO NON È NEUTRO.** Costa il gettone del
## villaggio (dodici secondi in cui nessun altro può parlare) e il riposo di
## quella persona (cinque minuti), e li toglie a un vicino che si sarebbe
## visto. È il gemello esatto del guasto che l'inquadratura ha chiuso, un
## passo più in là.
##
## **L'ORACOLO NON È QUESTA FUNZIONE, SONO I PIXEL.** La fisica non sa cosa
## finisce sullo schermo: sa dove stanno i solidi. Il metro di questa regola
## è `tools/misura_occlusione.gd`, che a ogni gesto vero spegne il corpo per
## un fotogramma e conta di quanto cambia il quadro — che è la stessa cosa
## che vede chi gioca. La regola si tara **contro quella**, mai contro sé
## stessa.
##
## Il degrado va SEMPRE verso quello che c'era: senza albero, senza camera e
## senza mondo fisico si passa. Zero vuol dire «non lo so», e «non lo so»
## non è mai un no.
##
## ────────────────────────────────────────────────────────────────────────
## I DUE RESIDUI, MISURATI E FOTOGRAFATI (non temuti: visti)
## ────────────────────────────────────────────────────────────────────────
##
## La fisica sa dove stanno i SOLIDI, e il quadro non è fatto di solidi.
## Restano perciò due famiglie, e vanno nei due versi opposti:
##
## 1. **IL VETRO.** I muri di casa si disegnano semitrasparenti quando ci si
##    guarda dentro: il raggio li trova, l'occhio ci vede attraverso. Sono i
##    quindici «falsi allarmi» su quarantasette della misura — e sono tutti
##    vicini DENTRO una casa, cioè, in partita, gente che `is_hidden()`
##    esclude molto prima di qui. Costa silenzio, che è il comportamento
##    normale.
## 2. **LE FRONDE E I TETTI.** Le chiome degli alberi non hanno collisioni, e
##    nemmeno il pezzo «Tetto» (`cols: []` a catalogo — e non gliele si
##    aggiunge per questo cancello: una collisione sul tetto cambierebbe dove
##    si cammina, che è un'altra cosa). Se la camera finisce in mezzo a una
##    chioma, lo schermo è verde e il gesto si spende lo stesso. Fotografato.
##
## Il residuo GEMELLO — la camera dentro il tronco del Grande Albero — è
## chiuso, e da una riga sola: vedi `hit_from_inside` più sotto.
func _gesto_coperto(pos: Vector3) -> bool:
	var m := _quote_coperte(pos)
	var n := 0
	for i in GESTO_QUOTE.size():
		if m & (1 << i):
			n += 1
	return n >= GESTO_COPERTO_MIN


## Quali delle `GESTO_QUOTE` hanno qualcosa davanti, come maschera di bit
## (bit *i* = la quota *i*). Una sola funzione: la regola qui sopra e il
## banco leggono **la stessa risposta**, o si finirebbe per tarare un metro
## contro un altro metro.
##
## **QUANTO COSTA, cronometrato sulla riga** (il MainLevel vero, un villaggio
## di centosessantanove case coi muri, 4000 domande a punti a caso): **12,3 µs
## a domanda**, tre raggi compresi. E di domande ne arrivano qui **0,3 al
## secondo** (misurate in partita: 1983 richieste in quattordici minuti, di
## cui 1728 respinte dai sei cancelli che stanno prima). Non si cronometrano
## i fotogrammi per una cosa che costa quattro microsecondi al secondo: si
## cronometra la riga, che è la regola di questo progetto quando la
## differenza cercata è sotto il rumore della macchina.
##
## ⚠️ **IL GIOCATORE SI ESCLUDE.** La capsula di Mochi è alta 90 cm e la
## camera guarda da 2,70: il conto dice che non copre nessuno (a nove metri
## il raggio le passa un metro e mezzo sopra la testa) —
## ma è l'unico corpo che sta SEMPRE fra l'occhio e il villaggio, e un
## giorno che qualcuno le allarga la capsula il vocabolario ammutolirebbe in
## silenzio, che è la forma di guasto che questo file esiste per non avere.
func _quote_coperte(pos: Vector3) -> int:
	if not is_inside_tree():
		return 0
	var vp := get_viewport()
	if vp == null:
		return 0
	var cam := vp.get_camera_3d()
	if cam == null:
		return 0
	var mondo := vp.find_world_3d()
	if mondo == null:
		return 0
	var spazio := mondo.direct_space_state
	if spazio == null:
		return 0
	var esclusi: Array[RID] = []
	if _player != null and is_instance_valid(_player) \
			and _player is CollisionObject3D:
		esclusi.append((_player as CollisionObject3D).get_rid())
	var occhio := cam.global_position
	var m := 0
	for i in GESTO_QUOTE.size():
		var q := PhysicsRayQueryParameters3D.create(occhio,
				pos + Vector3(0, float(GESTO_QUOTE[i]), 0))
		q.exclude = esclusi
		q.collide_with_areas = false
		# ⚠️ **E SE L'OCCHIO È DENTRO QUALCOSA, È COPERTO.** Di serie un
		# raggio che PARTE dentro una forma non la vede affatto, e questo
		# gioco ha una camera a scorrimento fisso che non schiva niente: le
		# capita di finire dentro il tronco del Grande Albero. MISURATO — la
		# foto è nel banco: lo schermo è tutto corteccia, del vicino non
		# arriva un pixel, e i tre raggi dicevano «scoperto». È il guasto
		# peggiore di questo cancello, perché è **proprio quando il giocatore
		# non vede niente** che il vocabolario si spendeva.
		q.hit_from_inside = true
		if not spazio.intersect_ray(q).is_empty():
			m |= 1 << i
	return m


## LA LEVA DEI BANCHI, e di nessun altro. Spenta, i raggi si tirano lo
## stesso — chi misura vuole sapere cosa AVREBBE detto la regola — ma il
## gesto parte comunque: è l'unico modo di avere il «prima» e il «dopo»
## sulla stessa corsa, sugli stessi corpi, negli stessi istanti.
##
## Nel gioco non la tocca nessuno, e un caso di `test_regia` scandaglia
## `scenes/` e `systems/` perché resti così.
var debug_occlusione := true


## La maschera delle quote coperte, per i banchi. Non reimplementa niente:
## è la stessa funzione che usa la regola.
func debug_quote_coperte(pos: Vector3) -> int:
	return _quote_coperte(pos)


## Il referto dei NO, per i banchi (`prova_villaggio_gesti`). In RAM, non si
## salva, e nel gioco non lo chiama nessuno.
func debug_gesti_contatori() -> Dictionary:
	var d: Dictionary = _gesto_no.duplicate()
	for o in _gesto_si:
		d["✓ " + str(o)] = _gesto_si[o]
	return d


func _tick_gesti(delta: float) -> void:
	_gesto_acc = maxf(0.0, _gesto_acc - delta)
	for k in _gesto_riposo.keys():
		var t: float = float(_gesto_riposo[k]) - delta
		if t <= 0.0:
			_gesto_riposo.erase(k)
		else:
			_gesto_riposo[k] = t
	# il gettone torna libero quando il corpo ha finito, non quando scade
	# l'accumulatore: sono due cose diverse, e confonderle vorrebbe dire
	# lasciar partire il secondo gesto sopra il primo
	if _gesto_chi != "":
		var n := node_di(_gesto_chi)
		if n == null or not is_instance_valid(n) \
				or not n.has_method("gesto_in_corso") \
				or str(n.call("gesto_in_corso")) == "":
			_gesto_chi = ""
	_tick_evita(delta)
	_tick_capi(delta)


## Mette un'occasione in sala d'attesa. `vicino_a` diverso da ZERO aggiunge
## la condizione «e il corpo dev'essere ancora nei paraggi di quel posto».
func _rimanda_gesto(label: String, occasione: String, dur: float,
		extra := {}, vicino_a := Vector3.ZERO) -> void:
	_gesto_evita[label] = {"occ": occasione, "extra": extra, "scade": dur,
			"vicino_a": vicino_a}


## LA SALA D'ATTESA. Si riprova a ogni fotogramma finché il corpo non è
## nelle condizioni, e si rinuncia quando la premessa è scaduta.
func _tick_evita(delta: float) -> void:
	if _gesto_evita.is_empty():
		return
	for label in _gesto_evita.keys():
		var v: Dictionary = _gesto_evita[label]
		v["scade"] = float(v["scade"]) - delta
		if float(v["scade"]) <= 0.0:
			_gesto_evita.erase(label)
			continue
		var n := node_di(label)
		if n == null or not is_instance_valid(n):
			_gesto_evita.erase(label)
			continue
		var vicino_a: Vector3 = v.get("vicino_a", Vector3.ZERO)
		if vicino_a != Vector3.ZERO \
				and n.global_position.distance_to(vicino_a) > GESTO_EVITA_RAGGIO:
			continue
		if chiedi_gesto(label, str(v["occ"]), v.get("extra", {}), false):
			_gesto_evita.erase(label)


## Ogni quanto si torna a chiedere chi ha il capo storto. È un LIVELLO su
## stati che durano minuti: chiederlo sessanta volte al secondo per ventotto
## vicini vorrebbe dire 3.360 chiamate al secondo per un dato che cambia due
## volte in un pomeriggio.
##
## ⚠️ E STA QUI E NON DENTRO IL CICLO DEI SUSSULTI, dov'era. Là il
## raffreddamento del sussulto (9 s per residente) faceva da cancello *anche*
## a questa domanda: chi era stato appena spaventato dal giocatore non poteva
## smettere di pensare per nove secondi. Due meccaniche diverse dietro lo
## stesso `continue`.
const CAPO_OGNI := 0.75
var _capo_acc := 0.0


func _tick_capi(delta: float) -> void:
	_capo_acc -= delta
	if _capo_acc > 0.0:
		return
	_capo_acc = CAPO_OGNI
	for r in _residents:
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		_tick_capo(r, label, _animi[label], r.get("node") as Node3D)


## QUANTE TESTE SONO INCLINATE ADESSO — contate nel MONDO, una per una.
##
## ⚠️ **E NON IN UN REGISTRO.** Qui c'era `_gesto_capi`, un dizionario di
## label che il villaggio teneva a mano, e aveva la modalità di guasto di
## tutti i registri paralleli: **divergeva**. Divergeva verso il basso quando
## una frase accendeva il rollio dal corpo (il registro non lo sapeva, e il
## tetto lasciava passare una terza testa); divergeva verso l'alto quando la
## frase finiva su qualcuno a cui il registro aveva appena concesso il
## livello (il posto restava occupato da una testa dritta). MISURATO nel
## MainLevel vero con dodici residenti: **282 fotogrammi divergenti in tre
## minuti**, e tre teste storte insieme per il 5,4% del tempo.
##
## Il conto DERIVATO non ha niente da tenere sincronizzato e niente da
## potare: chi se n'è andato col fagotto non è più in `_residents`, e il suo
## posto si libera da sé nello stesso istante. È la stessa forma di
## `Affetti.coppia()` e della fusione delle serre.
##
## Residuo dichiarato: il corpo di chi parte resta in scena per gli 0,8 s in
## cui rimpicciolisce fino a sparire, e in quella coda non è più contato. Una
## testa storta che si smaterializza non è una posa di gruppo, e il rimedio —
## spegnere il capo dentro `_congeda` — sarebbe il terzo posto scritto a mano
## che questo lavoro esiste per togliere.
func capi_storti() -> int:
	var n := 0
	for r in _residents:
		var nodo := r.get("node") as Node3D
		if nodo != null and is_instance_valid(nodo) \
				and nodo.has_method("capo_storto") and bool(nodo.call("capo_storto")):
			n += 1
	return n


## C'È POSTO per un'altra testa inclinata? La chiede il CORPO, prima di
## accendere il Capo dentro una frase (`Visitor.frase`): il tetto è del
## villaggio, e una frase che se lo accendesse da sola sarebbe un secondo
## villaggio che non conosce il primo.
func capo_permesso() -> bool:
	return capi_storti() < CAPO_MAX


## IL LIVELLO del Capo che pende, e su non più di due vicini per volta: tre
## teste inclinate insieme sono una posa di gruppo, non tre pensieri.
##
## È un LIVELLO e non un evento — non consuma il gettone — ma ha la sua
## scarsità, perché la regola che conta non è «quanto costa» ma «quanti se ne
## vedono insieme».
##
## ⚠️ **LE CAUSE SONO TRE, E LE DECIDE `Regia`.** Una sola causa
## (`regolazione < 0.45`, che è quello che c'era) è un gesto che mappa
## uno-a-uno su una variabile interna, cioè un cruscotto: un giocatore
## attento dopo tre ore ha in testa la legenda e legge il villaggio invece di
## viverci. Con «non ho più forza di trattenermi» · «sono di malumore da
## giorni» · «ho una cosa in testa che non ho ancora detto» il capo storto
## dice *a lui sta succedendo qualcosa*, mai quale leva.
##
## La terza causa è il RIMUGINARE: una deduzione della Fase 5 che è entrata
## nel grafo e non ha ancora avuto la sua ricevuta. Senza modello quel numero
## è sempre -1 e restano le prime due — cioè il gioco è identico, che è la
## regola della Fase 5.
func _tick_capo(r: Dictionary, label: String, animo: RefCounted, nodo: Node3D) -> void:
	if nodo == null or not is_instance_valid(nodo) \
			or not nodo.has_method("capo_pende"):
		return
	var rimugina := false
	if _ecs != null and is_instance_valid(_ecs) and r.has("ecs"):
		rimugina = int(_ecs.deduzione_muta(int(r["ecs"]), AMMIRA_SOGLIA)) >= 0
	# LE STESSE TRE VALVOLE DELLA RICEVUTA, e `in_scena` non è di troppo:
	# durante il coro del carillon un capo storto è un attore che non guarda
	# il direttore.
	var vuole: bool = REGIA.capo_pensa(float(animo.limbico.regolazione),
			float(animo.limbico.umore), rimugina) \
			and not bool(nodo.call("dorme")) and not bool(nodo.call("is_hidden")) \
			and not bool(nodo.call("in_scena"))
	# ⚠️ **SI CHIEDE AL CORPO SE IL LIVELLO È SUO, non se la testa è storta.**
	# Sono due domande diverse: il rollio ha due padroni (questo registro e
	# una frase del vocabolario), e un registro che leggesse «la testa è
	# inclinata» spegnerebbe il pensiero di chi sta gesticolando — cioè
	# troncherebbe una frase che dura tre secondi con un tick che passa ogni
	# 0,75.
	var ce_l_ha := bool(nodo.call("capo_livello"))
	if vuole == ce_l_ha:
		return
	# IL TETTO CONTA LE TESTE, e concedere il livello a chi ce l'ha già storto
	# per una frase non ne aggiunge nessuna: quel posto è già occupato da lui.
	# (Ed è il caso bello: il pensiero che la frase mostrava CONTINUA, invece
	# di spegnersi appena il gesto finisce.)
	if vuole and not bool(nodo.call("capo_storto")) and capi_storti() >= CAPO_MAX:
		return
	nodo.call("capo_pende", vuole)


func is_bed_claimed(cell: Vector2i) -> bool:
	for r in _residents:
		if r["cell"] == cell:
			return true
	return false


func _process(delta: float) -> void:
	_tick_gesti(delta)
	_tick_sussulti(delta)
	_tick_confronti(delta)
	_tick_partenze(delta)
	# il prossimo ospite arriva col sereno, di giorno, quando non c'è nessuno
	if _active == null:
		var day: bool = _daynight == null or not _daynight.is_night()
		var dry: bool = _weather == null or not _weather.is_raining()
		if day and dry:
			_timer -= delta
			if _timer <= 0.0:
				# se c'è una casa libera, il prossimo arriva con la valigia:
				# un villager NUOVO, generato dal DNA
				var house := _free_house()
				if not house.is_empty() and _residents.size() < MAX_RESIDENTS:
					_spawn_candidate(DNA.generate(), house)
				else:
					_spawn(SPECIES[randi() % SPECIES.size()])

	# il candidato in attesa sull'uscio: verdetto quando la pazienza finisce
	if _active and _active.get("mode") == "candidate" and not _decided \
			and _active.get("_state") == "c_decide":
		_decide()

	# ciclo giorno/notte dei residenti: ognuno con la SUA finestra di
	# sonno (il mattiniero all'alba, il dormiglione poltrisce, il
	# sognatore resta sotto le stelle) — si va a nanna solo dagli stati
	# di routine, chi è impegnato (onsen, casa sull'albero) finisce.
	# E intanto i bisogni scorrono: dormendo si ricarica l'energia.
	var t_ora: float = float(_daynight.get("time")) if _daynight else 0.5
	_vita_orologio += delta
	_ciclo_sonno(delta, t_ora)
	_gesti_agenda()

	# la prima goccia fa alzare il musetto: qualcuno commenta la pioggia
	var raining: bool = _weather != null and _weather.is_raining()
	if raining and not _was_raining:
		var speaker := _random_resident_node()
		if speaker:
			speaker.call("speak", ["pioggia", "casa"], "domanda")
	_was_raining = raining

	# la pioggia ADDOSSO: chi è fuori senza un tetto si ripara (zampina a
	# visiera, orecchie basse, passetto svelto — il livello _riparo del
	# Visitor). Sotto una copertura il corpo si rilassa da solo.
	for r in _residents:
		var rn := r.get("node") as Node3D
		if rn != null and is_instance_valid(rn):
			var cella := Vector2i(roundi(rn.global_position.x),
					roundi(rn.global_position.z))
			rn.set("riparo_pioggia", raining and not _build.has_cover(cella))
	if _active != null and is_instance_valid(_active):
		var ca := Vector2i(roundi(_active.global_position.x),
				roundi(_active.global_position.z))
		_active.set("riparo_pioggia", raining and not _build.has_cover(ca))

	# (Fase 6) i vicini leggono Mochi: l'empatia bidirezionale
	_tick_empatia(delta, raining)

	# se Mochi è salita sulla casa sull'albero, ogni tanto un residente
	# si arrampica a trovarla: la verticalità è anche compagnia
	_th_cd -= delta
	if _th_cd <= 0.0 and _player.global_position.y > 1.8:
		_th_cd = 8.0
		for th in _build.get_placed_by_name("Casa albero"):
			var plat: Vector3 = (th as Node3D).global_position + Vector3(0, 2.5, 0)
			if _player.global_position.distance_to(plat) < 2.8:
				var guest := _random_resident_node()
				if guest:
					var tf: Transform3D = (th as Node3D).global_transform
					guest.call("treehouse_visit", tf * _build.TH_BASE,
							tf * _build.TH_TOP, tf * _build.TH_PERCH)
					_th_cd = 55.0
				break

	_routine(delta)
	_chats(delta)
	_wishes(delta)

	_update_prompts()


# ---------------------------------------------------------------- visite

func _spawn(species: String) -> void:
	_timer = randf_range(80.0, 160.0)
	var v: Node3D = VISITOR.new()
	v.species = species

	# tappe della visita: 2 mobili all'aperto scelti a caso (mai in casa)
	var pois: Array[Vector3] = []
	var candidates: Array[Node3D] = []
	for node in _build.call("get_placed_by_name", "Lampada") + \
			_build.call("get_placed_by_name", "Cassetta posta") + \
			_build.call("get_placed_by_name", "Aiuola") + \
			_build.call("get_placed_by_name", "Fungo") + \
			_build.call("get_placed_by_name", "Cespuglio"):
		var cell := Vector2i(roundi(node.position.x), roundi(node.position.z))
		if not (_build.get("_placed")[3] as Dictionary).has(cell):
			candidates.append(node)
	candidates.shuffle()
	for i in mini(2, candidates.size()):
		var p: Vector3 = candidates[i].global_position
		pois.append(p + (PLAZA - p).normalized() * 0.65)

	var bench: Node3D = null
	var benches: Array[Node3D] = _build.call("get_placed_by_name", "Panchina")
	if not benches.is_empty():
		bench = benches[0]

	add_child(v)
	v.setup(species, ENTRIES[randi() % ENTRIES.size()], PLAZA, pois, bench,
			Vector3(0, 0, -9), Vector3(-2, 0, -15))
	v.wants_gift.connect(_on_gift_dropped)
	v.finished.connect(func(): if _active == v: _active = null)
	_active = v


func _on_gift_dropped(pos: Vector3, species: String) -> void:
	if _gift_bob:
		_gift_bob.kill()
	if _gift:
		_gift.queue_free()
	_gift_species = species
	_gift = _make_present()
	_gift.position = Vector3(pos.x, 0.09, pos.z)
	add_child(_gift)
	_gift.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_gift, "scale", Vector3.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# fluttua piano finché non lo raccogli
	_gift_bob = create_tween().set_loops()
	_gift_bob.tween_property(_gift, "position:y", 0.16, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gift_bob.tween_property(_gift, "position:y", 0.09, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _sfx:
		_sfx.place_ok()


func _make_present() -> Node3D:
	var g := Node3D.new()
	var carta := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.14, 0.16)
	carta.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("f4b8c8")
	carta.material_override = wm
	g.add_child(carta)
	for rot in [0.0, PI * 0.5]:
		var ribbon := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.035, 0.15, 0.165)
		ribbon.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color("fff3e0")
		ribbon.material_override = rmat
		ribbon.rotation.y = rot
		g.add_child(ribbon)
	var knot := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.035
	km.height = 0.07
	knot.mesh = km
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color("fff3e0")
	knot.material_override = kmat
	knot.position.y = 0.085
	g.add_child(knot)
	return g


# ------------------------------------------------------- vita dei residenti

# la fase della giornata: mattina alle aiuole, giorno in giro, sera al falò
func _phase() -> String:
	if _daynight == null:
		return "day"
	var t: float = _daynight.time
	if t >= 0.28 and t < 0.42:
		return "morning"
	if t >= 0.66 and t < 0.82:
		return "fire"
	return "day"


func _routine(delta: float) -> void:
	var ph := _phase()
	for i in _residents.size():
		var r := _residents[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		if str(r.get("phase", "")) != ph:
			r["phase"] = ph
			r["next_act"] = randf_range(0.4, 1.8)
		var prima_lease := float(r.get("next_act", 1.0))
		r["next_act"] = prima_lease - delta
		if float(r["next_act"]) > 0.0:
			continue
		# la finestra delle chiacchiere è scaduta: se l'incontro vero non è
		# successo, un po' di compagnia la si è presa lo stesso stando
		# accanto a qualcuno — se no il bisogno non si sazierebbe MAI e
		# l'azione tornerebbe a vincere all'infinito
		if bool(r.get("chiacchiere_in_corso", false)):
			r["chiacchiere_in_corso"] = false
			var b_ch: RefCounted = _ensure_brain(r)
			b_ch.needs["compagnia"] = minf(1.0, float(b_ch.needs["compagnia"]) + 0.2)
		match ph:
			"fire":
				# la sera ci si ritrova tutti attorno al fuoco
				r["next_act"] = 9999.0
				node.call("do_routine", "fire", _posto_al_falo(i), CLEARING)
				# (la compagnia del falò si paga all'arrivo: vedi
				# STATO_CHE_SAZIA in _gesti_agenda)
			"morning", "day":
				# QUI NON SI DECIDE PIÙ. La scelta dell'attività è passata al
				# motore di utilità in C++, che la rivaluta a ogni frame
				# (_gesti_agenda): questo ramo esisteva per ridecidere ogni
				# 9-15 secondi, e quella cadenza era il tempo che serviva a un
				# bisogno per superare il proprio dado.
				# Resta il LEASE: `next_act` è come gli undici sistemi a
				# evento zittiscono l'agenda, e il C++ lo riceve come fatto.
				r["next_act"] = 0.0


# ------------------------------------------------- NON CI SI ALZA PER PRIMI
#
# Il canale SOTTRATTIVO delle cricche, e l'unico che chiede all'agenda invece
# che al corpo: quando uno è nel posto in cui si ritrova con qualcuno, alla
# sua ora, e quel qualcuno — **o Mochi** — è lì accanto, l'agenda tace sei
# secondi in più. Non fa fare niente a nessuno: **toglie** il momento in cui
# uno si sarebbe alzato.
#
# Sei secondi sono `PostoDiSempre.INSIEME_MINIMO`, cioè la risposta che
# questo gioco ha già dato alla domanda «quanto dura uno stare insieme perché
# si veda». Non è un numero nuovo.

## …e non si alza chi si è appena alzato: **una volta per persona per
## giornata**. Il tetto è duro perché il rischio non è estetico — un vicino
## trattenuto di continuo è un vicino che non mangia, e la prima cosa che il
## giocatore vedrebbe è qualcuno che sta peggio.
var _insieme_oggi := {}       # label -> giorno in cui gli è già toccato


## L'AGENDA ASPETTA. Torna `true` se ha davvero allungato il guinzaglio.
##
## ⚠️ **SI ALZA IL LEASE, NON SI INGOIA UNA DECISIONE.** La strada corta —
## intercettare il fronte in `_gesti_agenda` e non recitare — è un LIVELLOCK:
## `azione_cambiata` è vero in un fotogramma solo, e se in quel fotogramma non
## si recita, quella decisione **non verrà recitata mai** (alla rivalutazione
## dopo, se vince la stessa azione, il fronte non c'è più). Il vicino
## resterebbe fermo con la fame che sale e nessuno stampa un errore. Qui
## invece si tace PRIMA che il motore decida: il lease è esattamente il modo
## in cui gli undici sistemi a evento fanno aspettare l'agenda, e il C++ lo
## riceve come fatto (`riferisci_agenda`).
##
## E si può solo ALZARE: `maxf`. Abbassare un lease vorrebbe dire scavalcare
## un sistema a evento — il concerto, il congedo — con una regola di gruppo.
func trattieni_insieme(label: String) -> bool:
	if _phase() == "fire":
		return false      # al falò si sta insieme comunque: non è una notizia
	var giorno: int = int(_daynight.get("day")) if _daynight else 0
	if int(_insieme_oggi.get(label, -1)) == giorno:
		return false
	for r in _residents:
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			return false
		# chi è in mezzo a una scena scritta non è di nessuno di noi, e chi
		# non è a riposo sta già andando da qualche parte: trattenere un
		# corpo in cammino non è «resta ancora un po'», è un inciampo
		if bool(node.call("in_scena")) or bool(node.call("is_hidden")):
			return false
		if not (str(node.get("_state")) in STATI_A_RIPOSO):
			return false
		# …E MAI CONTRO UN BISOGNO CHE URLA. Sei secondi non affamano
		# nessuno, ma la regola dev'essere scritta: la compagnia non passa
		# sopra al pancino, e un sistema che facesse stare peggio qualcuno
		# per «renderlo leggibile» avrebbe già perso.
		var brain: RefCounted = _ensure_brain(r)
		for k in brain.needs:
			if float(brain.needs[k]) < INSIEME_BISOGNO_MIN:
				return false
		_insieme_oggi[label] = giorno
		r["next_act"] = maxf(float(r.get("next_act", 0.0)),
				POSTO.INSIEME_MINIMO)
		return true
	return false


## Sotto questo livello un bisogno è un'urgenza, e chi ha un'urgenza si alza
## quando vuole lui.
##
## ⚠️ **NON È UN NUMERO MISURATO, ed è onesto dirlo**: nel gioco non esiste
## una soglia di «bisogno basso» da ereditare — l'urgenza dell'agenda è un
## margine fra PUNTEGGI (`sistema_agenda.h`, 0.60), non un livello. Questo è
## un pavimento di PRINCIPIO, e il principio è che la compagnia non passa
## sopra al pancino. Sei secondi su una giornata da 240 non affamano nessuno;
## la riga sta qui perché il giorno che qualcuno alzasse `INSIEME_MINIMO`
## trovi già scritto dove si ferma.
const INSIEME_BISOGNO_MIN := 0.25


# ------------------------------------------------------- l'agenda recitata

# il contesto che il cervello legge prima di decidere
func _brain_ctx(r: Dictionary, ph: String) -> Dictionary:
	var home := Vector3(r["cell"].x, 0, r["cell"].y)
	var t_ora: float = float(_daynight.get("time")) if _daynight else 0.5
	var amico := false
	for other in _residents:
		if other == r:
			continue
		var on := other.get("node") as Node3D
		if on and is_instance_valid(on) and not on.call("is_hidden"):
			amico = true
			break
	return {
		"mattina": ph == "morning",
		"sera_stellata": t_ora >= 0.80 and t_ora < 0.92,
		# la stessa domanda che si fa la recita, e per forza: se la
		# fattibilità guardasse un'aiuola e il corpo ne raggiungesse
		# un'altra, «cura_giardino» sarebbe fattibile per un'aiuola che
		# nessuno va ad annaffiare
		"aiuola_da_annaffiare": _aiuola_da_curare(r, home) != null,
		"spuntino_vicino": _nearest_named(["Cespuglio", "Fungo", "Orto"], home, 12.0) != null,
		"amico_in_giro": amico,
		"regia": get_tree().get_first_node_in_group("regista") != null,
	}


# dall'attività scelta ai passi concreti — con la vita che si vede:
# ogni tanto un toast racconta cosa stanno combinando
func _recita(r: Dictionary, node: Node3D, brain: RefCounted, act: String, ph: String) -> void:
	var home := Vector3(r["cell"].x, 0, r["cell"].y)
	# FASE 3: prima di recitare, si chiede al PIANO. Nel caso comune il
	# piano conferma la strada che il gesto scritto a mano prenderebbe
	# comunque, e non succede niente — è quando la strada non c'è più che
	# il piano dice una cosa che nessun `match` saprebbe dire.
	if PIANI.ha_obiettivo(act) and _piano_dirotta(r, node, act, home):
		return
	match act:
		"spuntino":
			var cibo := _nearest_named(PEZZI_CIBO, home, 12.0)
			if cibo:
				var pos: Vector3 = cibo.global_position
				pos += (home - pos).normalized() * 0.6
				node.call("do_task", "nibble", pos, func():
					brain.satisfy("spuntino")
					brain.remember("cibo", "uno spuntino ai cespugli"))
				_vita_toast("spuntino", L10n.tf("%s sgranocchia qualcosa tra i cespugli…", [r["label"]]))
				return
		"cura_giardino":
			if _garden:
				# LA SCENA 4: fra le assetate, quella che ha visto annaffiare.
				# La regola «quali aiuole hanno sete» resta tutta del Garden —
				# qui cambia solo il punto da cui si guarda.
				var bed: Node3D = _aiuola_da_curare(r, home)
				if bed:
					var lato: Vector3 = bed.global_position + Vector3(0.75, 0, 0.1)
					node.call("do_task", "water", lato, func():
						if _garden:
							_garden.villager_water(bed)
						brain.satisfy("cura_giardino")
						brain.remember("fiore", "un'aiuola annaffiata"))
					_vita_toast("annaffia", L10n.tf("♥ %s sta annaffiando le tue aiuole!", [r["label"]]))
					return
		"riposo":
			if brain.get("quirk") == "pisolini_ovunque" and randf() < 0.5:
				node.call("do_task", "nap", Vector3.ZERO, func(): brain.satisfy("pisolino"))
				_vita_toast("pisolino", L10n.tf("%s si è addormentato lì, così.", [r["label"]]))
				return
			# LA SCENA 3: la panchina si sceglie da un'ancora che, per chi ti
			# ammira e ce l'ha vicino, è spostata di qualche metro verso di te.
			# L'ancora, non il corpo: vedi il blocco «IL CUORE» più sopra.
			var bench := _panchina_per(r, home)
			if bench:
				# per gli sgabelli del gazebo si arriva SUL posto (il +0.8
				# della Panchina attraverserebbe il tavolino) e si guarda
				# il tè: il meta `tavolo` dice dove, in coordinate del
				# pezzo, e `r_bench` orienta chi si siede
				var arrivo: Vector3 = bench.global_transform * Vector3(0, 0, 0.8)
				var sguardo := Vector3.ZERO
				if bench.has_meta("seduta"):
					arrivo = bench.global_position
				if bench.has_meta("tavolo"):
					sguardo = (bench.get_parent() as Node3D).global_transform \
							* (bench.get_meta("tavolo") as Vector3)
				node.call("do_routine", "bench",
						Vector3(arrivo.x, 0, arrivo.z), sguardo, bench)
				# LA SAZIETÀ SI PAGA QUANDO IL GESTO ACCADE, non qui. Con la
				# valutazione continua, saziare nel frame della DECISIONE
				# significa che l'azione si azzera il punteggio da sola
				# mentre il vicino sta ancora camminando verso la panchina:
				# una macchina per oscillare cablata nel codice, e per giunta
				# uno che «si riposa» senza essersi seduto. La paga
				# `_gesti_agenda` leggendo STATO_CHE_SAZIA.
				return
			node.call("do_task", "nap", Vector3.ZERO, func(): brain.satisfy("pisolino"))
			return
		"quattro_chiacchiere":
			# cerca compagnia: il migliore amico se c'è, chiunque altrimenti
			var meta: Node3D = null
			var best_label: String = brain.migliore_amico()
			for other in _residents:
				if other == r:
					continue
				var on := other.get("node") as Node3D
				if on == null or not is_instance_valid(on) or on.call("is_hidden"):
					continue
				if meta == null or str(other["label"]) == best_label:
					meta = on
			if meta:
				var fianco: Vector3 = meta.global_position + Vector3(randf_range(-0.9, 0.9), 0, 0.9)
				node.call("do_routine", "sniff", fianco)
				return
		"meraviglia":
			var posti: Array[Vector3] = []
			if _cozy:
				posti.append(_cozy.POND_CENTER + Vector3(0, 0, _cozy.POND_R + 0.9))
			var albero := get_tree().get_first_node_in_group("grande_albero")
			if albero:
				posti.append((albero as Node3D).global_position + Vector3(1.6, 0, 1.2))
			if not posti.is_empty():
				node.call("do_task", "wonder", posti[randi() % posti.size()], func():
					brain.satisfy("meraviglia")
					brain.remember("sole", "un posto bellissimo"))
				return
		"stella":
			node.call("do_task", "stella", Vector3.ZERO, func():
				brain.satisfy("stella")
				brain.remember("dormire", "una notte di stelle"))
			_vita_toast("stelle", L10n.tf("%s è rimasto fuori a guardare le stelle…", [r["label"]]))
			return
		"regia":
			var piano := _regia_plan(r, ph)
			if not piano.is_empty():
				node.call("run_plan", piano)
				return
	# nessuna scena disponibile: due passi intorno a casa
	node.call("do_routine", "wander", Vector3.ZERO)


## LA POSA DI CHI RESTA FUORI, messa e tolta. Sta in una funzione sua per
## due motivi, tutti e due lezioni pagate:
##
##  · si CHIEDE LA POSTURA, non il meta. Qui c'era `has_meta("postura") ==
##    false`: ma il meta non si toglie quasi mai — quando un transitorio si
##    consuma viene RISCRITTO con la stabile sottostante — quindi bastava
##    che il giocatore fosse passato UNA volta a 1,4 metri (il saluto)
##    perché questo ramo fosse morto per sempre, e chi resta fuori la sera
##    non lo dicesse più col corpo. La domanda vera è «il corpo è libero?»;
##  · si toglie SOLO LA NOSTRA. Gli Affetti e il telegrafo della ribellione
##    usano lo stesso meta e gli stessi nomi: cancellarlo alla cieca
##    spegnerebbe la posa di un altro sistema, che non se ne accorgerebbe.
##
## Ed è una funzione a sé anche perché così si può PROVARE: far girare
## `_process` vorrebbe il villaggio intero (mondo, meteo, costruzioni).
func _aggiorna_posa_fuori(label: String, node: Node, resta_fuori: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if resta_fuori:
		if _posa_fuori.has(label):
			return
		if node.has_method("postura_libera") and node.call("postura_libera"):
			node.set_meta("postura", "spalle_basse")
			_posa_fuori[label] = true
		return
	if not _posa_fuori.has(label):
		return
	_posa_fuori.erase(label)
	if str(node.get_meta("postura", "")) == "spalle_basse":
		node.remove_meta("postura")


# la finestra di sonno personale: [inizio sera, fine all'alba]
## Può entrare in casa sua stanotte? Falso solo se chi divide quella soglia
## con lui gliel'ha chiusa. Una ferita non rende scontrosi con tutti: la
## porta è chiusa a UNA persona, e a nessun altro.
func _puo_entrare(r: Dictionary) -> bool:
	# fuori dall'albero non c'è nessun Affetti a cui chiedere, e non
	# esistendo il rancore la porta è aperta. Serve anche a poter PROVARE
	# il ciclo del sonno senza montare mezzo villaggio.
	# `is_inside_tree()` e non `get_tree() == null`: il secondo stampa
	# comunque un ERROR del motore prima di tornare null, e un test pulito
	# non deve lasciare rumore nel registro.
	if not is_inside_tree():
		return true
	var aff := get_tree().get_first_node_in_group("affetti")
	if aff == null:
		return true
	var mio := str((r.get("dna", {}) as Dictionary).get("name", ""))
	if mio == "":
		return true
	var cella: Vector2i = r.get("cell", Vector2i.ZERO)
	for altro in _residents:
		if altro == r:
			continue
		if (altro.get("cell", Vector2i.ZERO) as Vector2i) != cella:
			continue
		var suo := str((altro.get("dna", {}) as Dictionary).get("name", ""))
		if suo != "" and not bool(aff.call("apre_a", suo, mio)):
			return false
	return true


# ======================= IL CICLO DEL SONNO, DECISO IN C++ ==============
#
# Questo è il primo canale del villaggio in cui la DECISIONE non sta più in
# GDScript. Qui restano i FATTI (chi è nascosto, chi ha il corpo libero, a
# chi si apre la porta) e i GESTI (dormi, svegliati, spalle basse); in mezzo
# c'è `EcsMondo`, che con quei tre fatti decide se uno sta sveglio, dorme o
# resta fuori — e la finestra del sonno esiste solo là dentro.
#
# Perché la marionetta è QUESTO file e non `Visitor.gd`: il Visitor non
# decide già oggi, RECITA (lo dice VillagerBrain in cima al suo file). Chi
# decideva era questo ciclo. Ed è per lo stesso motivo che l'autorità è su
# UN canale solo: undici sistemi (il concerto, il salone, il nascondino, le
# promesse…) impongono stati a evento, e un C++ che scrivesse «lo stato»
# ogni frame vincerebbe su di loro senza un errore. Vedi CLAUDE.md.

## Gli stati da cui il corpo si può interrompere per andare a dormire. Era
## un letterale in mezzo al `_process`. Il C++ non li conosce: gli arriva
## solo il booleano `corpo_libero`, perché i 43 stati-stringa del Visitor
## non sono affar suo (e alcuni nascono composti a runtime).
## Gli stati in cui il CORPO è fermo e disponibile a cambiare mestiere. La
## differenza con quelli interrompibili qui sotto ha un perché: dal SONNO ci
## si alza anche da sotto le stelle, dall'AGENDA no — quei tre pagano la
## loro sazietà quando il gesto finisce, e strapparli a metà vorrebbe dire
## che il bisogno non si sazia mai.
const STATI_A_RIPOSO := ["r_idle", "r_wander", "r_fire", "r_bench", "r_sniff"]

const STATI_INTERROMPIBILI := ["r_idle", "r_wander", "r_fire", "r_bench",
		"r_sniff", "tk_stella", "tk_sing", "tk_nap"]

## Ogni quanti frame si rinfrescano i FATTI del mondo per un residente. Il
## contesto costa (interroga il Garden, cerca i cespugli, guarda gli altri
## residenti): calcolarlo a 60 Hz per ventotto vicini vorrebbe dire metà
## frame, e il costo CRESCEREBBE con quanto il giocatore costruisce — cioè
## il gioco punirebbe chi costruisce. Sfalsato per residente (la FASE viene
## da `hash(label)`, vedi `_fatti_di`), così a ogni frame se ne rinfresca
## circa uno: la spesa è quella di oggi, e i fatti sono freschi ogni mezzo
## secondo invece che ogni 9-15 secondi.
const FATTI_OGNI := 30

## QUALE STATO DEL CORPO SAZIA QUALE BISOGNO, e si paga quando il gesto
## ACCADE — cioè quando il corpo è arrivato e sta facendo la cosa, non
## quando l'ha decisa. Prima «riposo» e il falò pagavano alla decisione:
## con la valutazione continua l'azione si azzerava il punteggio da sola
## mentre il vicino era ancora per strada, e per giunta uno si «riposava»
## senza essersi mai seduto.
## Le altre attività pagavano già alla callback d'arrivo: qui si mettono in
## riga quelle che non ce l'avevano.
const STATO_CHE_SAZIA := {"r_bench": "riposo", "r_fire": "falo"}

var _ecs: Object = null
var _ecs_manca_detto := false
var _ST_DORME := 1
var _ST_FUORI := 2


## MAI `EcsMondo.new()`: nominare la classe fa fallire il PARSE dell'intero
## file quando la GDExtension non è caricata, e il villaggio resterebbe
## senza abitanti oltre che senza cuore. Con ClassDB il file compila sempre.
func _ensure_ecs() -> void:
	if _ecs != null and is_instance_valid(_ecs):
		return
	if not ClassDB.class_exists("EcsMondo"):
		if not _ecs_manca_detto:
			_ecs_manca_detto = true
			push_error("EcsMondo assente: la GDExtension non è caricata, i residenti non dormiranno.")
		return
	_ecs = ClassDB.instantiate("EcsMondo")
	_ecs.name = "CuoreSonno"
	add_child(_ecs)
	# le costanti si leggono dall'oggetto: qui dentro non si scrive 0/1/2
	_ST_DORME = _ecs.STATO_DORME
	_ST_FUORI = _ecs.STATO_FUORI
	# IL RITMO DELLA MEMORIA SI DERIVA DAL CICLO DEL GIORNO, e si dice UNA
	# volta sola: un villaggio con le giornate lunghe ha ricordi lunghi. Il
	# C++ ha un suo valore di partenza che vale lo stesso conto (mezza
	# giornata), ma un default che combacia per caso è il modo esatto in cui
	# due numeri divorziano — il giorno che qualcuno sposta `cycle_seconds`,
	# i ricordi lo devono seguire senza che nessuno vada a cercare un 120
	# nascosto in un header. Se non c'è nessun DayNight (i banchi di prova,
	# il prologo) non si inventa un ciclo: resta quello di là.
	if _daynight != null and is_instance_valid(_daynight):
		_ecs.imposta_ritmo(float(_daynight.cycle_seconds))


## L'handle dell'entità. Vive SOLO qui, in RAM, dentro la riga del residente:
## non finisce in nessun salvataggio e non attraversa nessun altro sistema —
## il villaggio ha già due anagrafi (nome e label) e questa non deve
## diventare la terza.
func _ecs_id(r: Dictionary) -> int:
	var brain: RefCounted = _ensure_brain(r)
	if not r.has("ecs"):
		r["ecs"] = _ecs.registra(PackedStringArray(brain.indole), str(brain.quirk))
		r["ecs_ind"] = (brain.indole as Array).duplicate()
		r["ecs_q"] = str(brain.quirk)
		return int(r["ecs"])
	# LA FOTOGRAFIA DEL DNA SCADE. Indole e quirk non sono geni estetici (il
	# salone non li tocca), ma `debug_quirk` li scrive su un cervello vivo —
	# è così che DebugHarness fabbrica un nottambulo. Senza questo confronto
	# il registro manderebbe a letto alle 0.80 uno che è appena diventato
	# nottambulo, e non se ne accorgerebbe nessuno.
	# Si confronta invece di riproiettare sempre: sono due letture e un
	# paragone di array corti, mentre `riproietta` alloca una
	# PackedStringArray a ogni residente a ogni frame.
	if r.get("ecs_ind") != brain.indole or str(r.get("ecs_q", "")) != str(brain.quirk):
		r["ecs_ind"] = (brain.indole as Array).duplicate()
		r["ecs_q"] = str(brain.quirk)
		_ecs.riproietta(int(r["ecs"]), PackedStringArray(brain.indole), str(brain.quirk))
	return int(r["ecs"])


## Dove muore il cervello, muore l'entità. È la regola, ed è greppabile:
## accanto a ogni `_brains.erase` c'è una di queste.
func _dimentica_ecs(r: Dictionary) -> void:
	if _ecs != null and is_instance_valid(_ecs) and r.has("ecs"):
		_ecs.dimentica(int(r["ecs"]))
	r.erase("ecs")
	r.erase("ecs_ind")
	r.erase("ecs_q")


## IL CUORE, per chi deve incidere un ricordo. È l'unico modo di arrivarci
## da fuori: il registro ECS nasce TARDI (`_ensure_ecs` al primo ciclo del
## sonno), quindi qui si torna `null` finché non c'è, e chi chiede deve
## riprovare — non fidarsi di una fotografia scattata nel proprio `_ready`.
func cuore() -> Object:
	return _ecs if (_ecs != null and is_instance_valid(_ecs)) else null


## CHI C'ERA. La fonte unica del «l'ha visto»: una riga per testimone,
## `{node, ecs, label}` — il corpo da far girare e l'entità su cui incidere.
##
## Solo questa funzione sa mettere insieme le due cose, perché l'handle ECS
## vive dentro la riga del residente e da nessun'altra parte. Il PREDICATO
## invece NON è qui: sta in `Percezione.puo_vedere`, accanto al raggio che
## usa. Due ragioni, e la seconda è quella che decide:
##  1. la percezione è il mestiere di quel file, non di questo (che ne ha
##    già quaranta);
##  2. **Visitors non si istanzia in headless** — il suo `_ready` vuole
##    `%Player` e `../BuildSystem` — quindi un predicato scritto qui dentro
##    non sarebbe guastabile da un test una valvola per volta, e in questo
##    progetto una guardia che nessun test può far diventare rossa è già
##    stata, tre volte, una guardia che non c'era.
func testimoni(pos: Vector3, raggio: float) -> Array:
	var out: Array = []
	for r in _residents:
		if not r.has("ecs"):
			continue      # non ancora censito: non ha una memoria in cui incidere
		var node := r.get("node") as Node3D
		if not PERCEZIONE.puo_vedere(node, pos, raggio):
			continue
		out.append({"node": node, "ecs": int(r["ecs"]), "label": str(r.get("label", ""))})
	return out


# ==================== IL CUORE: DOVE UNA MEMORIA DIVENTA UN GESTO ==========
#
# Quattro fili, e tutti e quattro finiscono in una cosa che si VEDE. La
# Fase 4 non ha una riga di testo, non un toast, non una lettera: quello che
# un vicino ha visto fare a Mochi esce da qui in tre modi soli — DOVE si
# mette, QUALE simbolo gli scappa in una chiacchiera con un altro, e (una
# volta al giorno, al massimo) un ricordo che gli resta addosso anche dopo un
# riavvio.
#
# LA REGOLA CHE VIENE PRIMA DI TUTTE, e che ha deciso la forma di ogni riga
# qui sotto: **l'ammirazione non produce un guinzaglio.** Non esiste una nona
# azione «stai vicino a Mochi», non esiste un corpo che si sposta perché il
# giocatore si è spostato. Quello che si sposta è un'ANCORA — il punto da cui
# si cerca una panchina, il punto da cui si cerca un'aiuola — di al massimo
# SPOSTA_MAX metri da casa propria. Il guasto opposto non è un bug che si
# nota: sono ventotto vicini che ti orbitano intorno, con la suite verde e
# tutti i test comportamentali soddisfatti, e ci si arriva TARANDO BENE un
# sistema progettato male. Un gioco cozy in cui non si può stare da soli è
# rovinato.

## Di quanto può spostarsi un'ancora da casa propria, in metri.
##
## Non è un raggio d'azione: è la lunghezza del guinzaglio che questo sistema
## NON deve avere. Sei metri stanno dentro il cortile di casa (le case del
## villaggio distano fra loro molto di più) e sono la metà scarsa del raggio
## con cui si cerca una panchina (16 m).
##
## ⚠️ MA IL CORPO PUÒ ARRIVARE PIÙ LONTANO DI SEI METRI, e per un po' qui
## c'è stato scritto il contrario («l'ancora spostata cambia QUALE panchina,
## non fa comparire un villaggio nuovo di panchine»). Non è vero, e la
## differenza si misura: `_free_bench` cerca entro 16 m **dall'ancora**, e
## se l'ancora è già a sei metri da casa il posto scelto può stare a
## ventidue — misurato, un vicino si è seduto a dieci metri da casa sua
## proprio per questo. Il raggio di ricerca cresce davvero, da 16 a 22 m.
##
## **Ed è voluto**, perché è esattamente la scena 2: posi una panchina in
## un angolo del villaggio mentre qualcuno ti guarda, e quel qualcuno ci va.
## Se si filtrasse il risultato a 16 m da casa, la panchina appena posata un
## po' più in là non chiamerebbe più nessuno — cioè l'emozione TOGLIEREBBE,
## che è la cosa che qui non deve mai succedere. Quello che questa costante
## garantisce non è un raggio: è che **nessuno cammini verso una PERSONA**.
## Si cammina verso una panchina, che sta ferma, e non più lontano di
## SPOSTA_MAX + il raggio di sempre.
const SPOSTA_MAX := 6.0

## Fin dove si cerca un'aiuola che ha sete, in metri.
##
## **NON è una soglia nuova**, ed è l'opposto: questo 14 era scritto a mano in
## TRE punti di questo file (il contesto del cervello, i luoghi del piano, la
## recita), la Fase 4 li ha ridotti a una funzione sola, e lì dentro ne
## restavano due copie — quella per l'ancora spostata e quella per il ripiego
## su casa. Due copie in una funzione sola sono il caso peggiore: chi ne
## cambia una allarga la ricerca da casa e non quella da spostati, e il
## villaggio comincia a scegliere l'aiuola con due metri diversi a seconda di
## chi ha visto cosa — senza un errore, e con la suite verde.
const RAGGIO_AIUOLA := 14.0

## SOTTO QUESTO PESO, QUELLO CHE HAI VISTO NON SPOSTA PIÙ NIENTE.
##
## UN NUMERO SOLO PER TUTTE E DUE LE ANCORE, ed è la cosa importante di
## questa riga. Lo leggono:
##  · `ancora_riposo`, contro `Tinte.ammirazione` (la somma di tutto quello
##    che ti ha visto fare) — «mi fa piacere che tu sia qui»;
##  · `_ancora_ricordo`, contro il peso del SINGOLO ricordo che nomina il
##    posto (`EcsMondo.dove`) — «l'aiuola che ti ho vista annaffiare».
## Sono due domande diverse fatte nella STESSA unità: l'occhiata. Un ricordo
## fresco, visto una volta, non fatto a me, a gusto neutro pesa esattamente
## **1.0** (`chibi::peso`), e dimezza ogni mezza giornata di gioco. 0.35 è
## quindi «poco più di un'occhiata e mezza fa» — misurato: una sola
## osservazione tiene un'ancora spostata per 1,51 mezze vite, cioè circa tre
## minuti di gioco, poi si riassesta da sola.
##
## ⚠️ IL SECONDO LETTORE È NUOVO, E PRIMA NON C'ERA: `dove()` accettava
## qualunque peso maggiore di zero, e `2^(-dt/mezza_vita)` non arriva a zero
## prima di ~1074 mezze vite. Misurato: posato UN palo di staccionata sotto
## gli occhi di un vicino, la sua ancora restava spostata dopo trenta
## giornate di gioco, con l'ammirazione a 0.000000. Cioè quel vicino
## ignorava per sempre la panchina a tre metri da casa sua per una cosa che
## non ricordava più. Il valore non è cambiato: è cambiato il numero di
## posti che lo guardano — e se un domani si tara, si tara **una volta**.
##
## Perché bassa e non alta: questa non è una scena rara da conservare, è una
## tendenza. Deve capitare abbastanza spesso da diventare una cosa che il
## giocatore sente («qui c'è sempre qualcuno») e mai abbastanza da diventare
## un corteo — e a impedire il corteo non è questa soglia, sono `SPOSTA_MAX`
## e le due valvole qui sotto.
const AMMIRA_SOGLIA := 0.35

## Quanto dev'essere vicina Mochi a casa di uno perché la sua ancora si
## sposti verso di lei. Oltre venti metri, «più vicino a Mochi» vorrebbe dire
## dall'altra parte del villaggio — cioè un vicino che abbandona il proprio
## angolo perché il giocatore è passato di là. Questa è la valvola che
## trasforma «mi fa piacere che tu sia qui» in «ti sto seguendo».
const MOCHI_VICINA := 20.0

## Quanto dev'essere pesante il ricordo più forte perché diventi un ricordo
## PERMANENTE (`VillagerBrain.remember`, l'unica cosa della Fase 4 che
## attraversa un riavvio). Stessa unità di sopra: **un'occhiata sola vale
## 1.0**, quindi questa soglia dice, letteralmente, «più di un'occhiata».
##
## Le due strade per superarla sono le due che vale la pena ricordare, e non
## è una coincidenza — sono i due moltiplicatori che `chibi::peso` conosce:
##  · **l'hai fatto a me** (R_SU_DI_ME raddoppia): un regalo, un piatto;
##  · **ti ho vista farlo a lungo** (`quante`): due volte dentro la finestra
##    di fusione bastano (1.375), sei valgono 2.25.
## Una passata di sfuggita, invece, non diventa il ricordo di una vita.
##
## ⚠️ QUI C'ERA SCRITTO che questa soglia è «il motivo per cui annaffiare in
## cerchio davanti a un vicino non serve a niente», e le due righe di sopra
## dicevano già il contrario: farlo a lungo È una delle due strade per
## superarla. Insistere serve, e deve servire — «ti ho vista lavorare tutto
## il pomeriggio» è una cosa vera che vale la pena ricordarsi. Quello che
## non deve succedere è che insistere PAGHI SENZA FINE, e a tenerlo chiuso
## non è questa soglia: è il tetto delle ripetizioni in `chibi::peso`
## (`RIP_TETTO`), che ferma un pomeriggio intero a quattro occhiate. Con
## quello, il tempo che una conseguenza dura passa da 185 s (un gesto) a un
## massimo di 422 s — per qualunque insistenza, misurato. E la promozione
## resta comunque **una al giorno**: annaffiare in cerchio non riempie la
## memoria di nessuno.
const RICORDO_SOGLIA := 1.0

## L'ANCORA DEL RIPOSO — pura, e per questo falsificabile una valvola per
## volta (`Visitors` non si istanzia in headless: il suo `_ready` vuole
## `%Player` e `../BuildSystem`).
##
## Torna il punto DA CUI cercare una panchina. È casa propria, sempre, tranne
## quando tutte e due queste cose sono vere insieme:
##  1. quel vicino ti ammira davvero (ha visto, e gli è importato);
##  2. tu sei già dalle sue parti.
## E anche allora si sposta al massimo di `SPOSTA_MAX`. Nessuno ti raggiunge,
## nessuno ti insegue: cambia solo QUALE panchina, fra quelle che c'erano già.
static func ancora_riposo(home: Vector3, pos_mochi: Vector3, ammira: float) -> Vector3:
	if not (ammira > AMMIRA_SOGLIA):
		return home
	if home.distance_to(pos_mochi) >= MOCHI_VICINA:
		return home
	return home.move_toward(pos_mochi, SPOSTA_MAX)


## Quanto ti ammira, adesso. Zero per chi non ha ancora un cuore (il villaggio
## appena aperto, i banchi senza GDExtension): il degrado va sempre verso il
## comportamento di sempre, mai verso un ramo nuovo che nessuno ha provato.
func _ammirazione_di(r: Dictionary) -> float:
	if _ecs == null or not is_instance_valid(_ecs) or not r.has("ecs"):
		return 0.0
	return float(_ecs.ammirazione(int(r["ecs"])))


## L'ANCORA DI UN RICORDO: il punto da cui cercare, spostato verso il posto
## in cui ho visto Mochi fare QUELLA cosa — e mai più di `SPOSTA_MAX` metri
## da casa mia.
##
## UNA SOLA FUNZIONE PER DUE SCENE, e non per risparmiare righe: «l'aiuola
## che ha visto» e «la panchina che ti ha vista costruire» sono la stessa
## regola detta su due cose diverse, e una regola scritta due volte è una
## regola che prima o poi si dice diversa (le specie, la scala della
## ribellione, il salvataggio: questo progetto l'ha già pagata tre volte).
## Chi ne aggiungerà una terza CHIAMI questa, e non ricopi il `move_toward`.
##
## LA COSA SI CHIEDE PER NOME, non per indice. È la stessa disciplina del bus
## della percezione (`Percezione.accaduto` manda «annaffia», non un 0): la
## traduzione vive in un posto solo, di là, e un nome sbagliato si ferma qui
## con un avviso invece di diventare in silenzio il ricordo di un'altra cosa.
##
## TRE COSE CHE SEMBRANO DETTAGLI E NON LO SONO:
##  · il ripiego di `dove()` è `home`, quindi «non ricordo niente» produce
##    `home.move_toward(home, …)` = `home` ESATTO: chi non ha visto niente si
##    comporta come si è sempre comportato, bit per bit, senza un `if`;
##  · si sposta verso un POSTO, mai verso una persona. È tutta la differenza
##    con `ancora_riposo`, ed è il motivo per cui questa non ha bisogno delle
##    sue due valvole: un'aiuola e una panchina non camminano, quindi qui non
##    c'è nessuno che si possa seguire (regola 5, il guinzaglio che non deve
##    esistere);
##  · **la soglia**, ed è la sola cosa che fa TORNARE INDIETRO l'ancora. Un
##    ricordo scende sotto `AMMIRA_SOGLIA` in tre minuti di gioco e da lì in
##    poi `dove()` risponde `home`, cioè l'ancora si riassesta da sé. Senza
##    quel numero l'ancora poteva solo essere SOSTITUITA, mai tornare: il
##    peso di un ricordo non arriva a zero prima di trentasei ore di gioco,
##    e un palo di staccionata posato sotto gli occhi di un vicino gli
##    cambiava la panchina per tutta la sessione. La soglia sta di qua e non
##    dentro il C++ per la stessa ragione dello smorzamento del
##    pettegolezzo: è una decisione di gioco, e si legge dove si prende.
func _ancora_ricordo(r: Dictionary, home: Vector3, cosa: String) -> Vector3:
	if _ecs == null or not is_instance_valid(_ecs) or not r.has("ecs"):
		return home
	var c: int = int(_ecs.indice_cosa(cosa))
	if c < 0:
		# rumoroso di proposito: da solo si manifesterebbe come un'ancora che
		# non si sposta mai, cioè come niente, per sempre e con la suite verde
		push_warning("Visitors: cosa sconosciuta «%s» (l'ancora non si sposterà mai)" % cosa)
		return home
	return home.move_toward(
			_ecs.dove(int(r["ecs"]), c, AMMIRA_SOGLIA, home), SPOSTA_MAX)


## UN POSTO DOVE SEDERSI, e DA DOVE si cerca. Quattro ancore in ordine, e si
## ferma alla prima che dà una panchina vera.
##
## 1. **SE SEI QUI E TI AMMIRA** — la scena 3: sceglie la panchina libera più
##    vicina a un punto un po' spostato verso di te. Non ti raggiunge, non ti
##    parla, non si avvicina: fa le sue cose, un po' più in là.
##
## 2. **ALTRIMENTI, DOVE TI HA VISTA COSTRUIRE.** Posa una panchina in un
##    angolo del villaggio mentre qualcuno ti guarda, e quando a quel
##    qualcuno verrà voglia di sedersi ci andrà — proprio lui, proprio lì.
##    È la stessa regola della quarta scena detta sull'altra cosa che il
##    giocatore lascia nel mondo: là il gesto era annaffiare, qui è
##    costruire, e la funzione che sposta l'ancora è LA STESSA
##    (`_ancora_ricordo`). Non è una macchina nuova: è la lettura `dove()`,
##    che c'era già e aveva un consumatore solo, agganciata a `_free_bench`,
##    che c'era già da sempre.
##    Perché è sicura: si sposta verso un POSTO, non verso una persona — e
##    una panchina non cammina, quindi non c'è nessuno da seguire. Il salto è
##    lo stesso `SPOSTA_MAX`, e il caso peggiore possibile è che si sieda su
##    un'altra delle panchine che c'erano già.
##    E viene DOPO la prima: se sei qui adesso, quello che sta succedendo
##    adesso conta più di quello che è successo ieri.
##
## 3. **E POI, DOVE SI TROVA CON QUALCUNO.** Chi da giorni finisce nello
##    stesso angolo con le stesse persone si siede *da quella parte*, e con
##    abbastanza giornate certi posti diventano di qualcuno — senza che
##    esista da nessuna parte un flag di proprietà, e senza che il gioco lo
##    dica. L'ancora è il **punto medio delle case** di quelli con cui si
##    ritrova: un POSTO, non una persona, quindi non c'è nessuno da seguire
##    (è la stessa ragione per cui è sicura la 2).
##
##    ⚠️ **STA DOPO MOCHI, E MAI PRIMA, ed è tutta la terza domanda della
##    regola del cozy.** Finché sei nei paraggi l'ancora la vince il
##    GIOCATORE: **il villaggio non si raggruppa mai altrove nel momento in
##    cui arrivi**. Un giocatore che vedesse i vicini radunarsi lontano da lui
##    proprio quando entra in scena avrebbe imparato, senza una parola, di
##    essere quello di troppo — e sarebbe colpa di quattro righe messe
##    nell'ordine sbagliato.
##
## 4. **E SE NO, CASA.** Senza questo ripiego l'unica panchina del villaggio,
##    se sta dalla parte opposta, uscirebbe dal raggio dell'ancora spostata e
##    il vicino si addormenterebbe per terra — cioè starebbe PEGGIO per
##    averti visto, che è il modo più veloce per rendere illeggibile un
##    sistema che non parla. L'emozione AGGIUNGE, mai toglie.
func _panchina_per(r: Dictionary, home: Vector3) -> Node3D:
	var verso_te := ancora_riposo(home, _dove_sta_mochi(home), _ammirazione_di(r))
	if verso_te != home:
		var vicina: Node3D = _free_bench(verso_te)
		if vicina != null:
			return vicina
	var verso_opera := _ancora_ricordo(r, home, "casa")
	if verso_opera != home:
		var nuova: Node3D = _free_bench(verso_opera)
		if nuova != null:
			return nuova
	var verso_loro := _ancora_ritrovo(r, home)
	if verso_loro != home:
		var insieme: Node3D = _free_bench(verso_loro)
		if insieme != null:
			return insieme
	return _free_bench(home)


## L'ANCORA DEL RITROVO: casa propria spostata verso il punto medio delle
## CASE di quelli con cui ci si ritrova, e mai più di `SPOSTA_MAX`.
##
## Le case e non i corpi: un corpo cammina, e un'ancora che insegue un corpo
## è un corteo. È la stessa distinzione che rende sicura l'ancora dell'opera.
##
## Senza registro delle cricche — un banco, il diorama, una partita nuova —
## torna `home` ESATTO, e da lì in giù non cambia una virgola di quello che
## il villaggio faceva prima.
func _ancora_ritrovo(r: Dictionary, home: Vector3) -> Vector3:
	var cr := get_tree().get_first_node_in_group("cricche")
	if cr == null or not is_instance_valid(cr) or not cr.has_method("compagni"):
		return home
	var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
	if nome == "":
		return home
	var somma := Vector3.ZERO
	var n := 0
	for altro in (cr.call("compagni", nome) as PackedStringArray):
		var lab := label_di_nome(str(altro))
		if lab == "":
			continue
		var c := cella_di(lab)
		if c.x == 999:
			continue
		somma += Vector3(float(c.x), 0.0, float(c.y))
		n += 1
	# ⚠️ **UNA GUARDIA SOLA, e prima ce n'erano due.** C'era anche un
	# `if loro.is_empty(): return home` davanti al ciclo, e **non poteva
	# mordere**: con l'elenco vuoto il ciclo non aggiunge niente, `n` resta
	# zero, e si finisce esattamente qui. L'ha trovata una mutazione — toglierla
	# lasciava la suite verde — e una guardia che nessun test può far fallire è
	# una guardia che non c'è. (È la stessa lezione di `GIORNATE_RESTA_LUNGA`,
	# tolta dal predicato per la stessa ragione.)
	#
	# Questa invece morde: chi si ritrova con nessuno, o con gente che ha
	# traslocato, deve avere **casa sua ESATTA** — non il baricentro di un
	# insieme vuoto, che sarebbe l'origine del mondo.
	if n == 0:
		return home
	return home.move_toward(somma / float(n), SPOSTA_MAX)


## Dove sta Mochi. Senza giocatore (i banchi di prova, il diorama del titolo)
## si risponde «a casa tua», che è il valore per cui `ancora_riposo` non
## sposta niente: il degrado va verso il comportamento di sempre.
func _dove_sta_mochi(home: Vector3) -> Vector3:
	var p: Variant = posizione_mochi()
	return home if p == null else (p as Vector3)


## DOVE STA MOCHI, o `null` se in questa scena non c'è un giocatore (i banchi,
## il diorama del titolo, il Prologo).
##
## ⚠️ **`null` e non `Vector3.ZERO`**: l'origine è un punto VERO del
## villaggio — ci passa il fiume, e non è lontana dalla piazza. Confonderla
## con «non lo so» vorrebbe dire che tutto ciò che si misura «vicino a Mochi»
## si accende attorno a un fantasma piantato là, per sempre, e a nessuno
## verrebbe in mente di guardare lì.
func posizione_mochi() -> Variant:
	if _player == null or not is_instance_valid(_player):
		return null
	return _player.global_position


## L'AIUOLA CHE HA SETE, e DA DOVE si guarda. Fonte unica: prima di questa
## funzione la stessa domanda si faceva in tre punti diversi (il contesto del
## cervello, i luoghi del piano, la recita) — tre copie della stessa riga,
## che è precisamente come due sistemi cominciano a raccontare due villaggi.
##
## La regola «quali aiuole hanno sete» resta tutta e sola del Garden: qui
## cambia il PUNTO DA CUI si cerca, e cambia di al massimo `SPOSTA_MAX` metri
## da casa. È la scena 4 — chi ti ha vista annaffiare *quella* aiuola, fra le
## assetate sceglie quella, e Mochi torna all'orto e ritrova il proprio gesto
## nello stesso punto, fatto da un altro.
##
## Lo spostamento dell'ancora e il suo ripiego stanno in `_ancora_ricordo`,
## che è la stessa funzione che sposta l'ancora della panchina: se l'emozione
## non ricorda niente, torna `home` ESATTO e da qui in giù non cambia una
## virgola di quel che il villaggio faceva prima.
##
## E SE DALL'ANCORA SPOSTATA NON SI VEDE NESSUNA AIUOLA, SI RIPIEGA SU CASA.
## Senza questa riga l'emozione potrebbe far fare MENO (un vicino che, per
## aver visto, smette di annaffiare) — e una conseguenza che toglie è il modo
## più veloce per rendere il sistema illeggibile.
func _aiuola_da_curare(r: Dictionary, home: Vector3) -> Node3D:
	if _garden == null:
		return null
	var da := _ancora_ricordo(r, home, "fiore")
	if da != home:
		var vista: Node3D = _garden.bed_needing_water(da, RAGGIO_AIUOLA)
		if vista != null:
			return vista
	return _garden.bed_needing_water(home, RAGGIO_AIUOLA)


## IL CUORE DI UN RESIDENTE, alla cadenza dei FATTI e non a ogni frame.
##
## Fa due cose, e nessuna delle due è una decisione: spinge di là il GUSTO
## (chi tiene a cosa) e, al massimo una volta al giorno, promuove il ricordo
## più forte a ricordo permanente.
##
## PERCHÉ NON ACCANTO A `riferisci_bisogni`, che gira a sessanta hertz: i
## bisogni sono cinque double già pronti, il gusto è un giro sul genoma e
## sulle indoli più un array nuovo. Ventotto vicini per sessanta frame
## sarebbero 1.680 ricostruzioni al secondo di un dato che cambia quando
## qualcuno esce dal salone di bellezza.
##
## PERCHÉ CONFRONTA-E-RIPROIETTA e non «si scrive una volta e basta»: è la
## lezione della Fase 1, pagata col `DnaComponent`. Il salone di bellezza
## riscrive i geni DENTRO lo stesso Dictionary che sta nella riga del
## salvataggio, e `debug_quirk` scrive su un cervello vivo: una copia in C++
## fotografata alla registrazione diventerebbe stale al primo cambiamento,
## **con la suite verde**. Si ricalcola, si confronta, e si spinge solo se è
## cambiato davvero.
##
## COSA FA DAVVERO QUESTO CONFRONTO, e cosa NON fa. Non è lui a impedire che
## il gradino del modulatore venga annullato di continuo: quello lo fa già
## `EcsMondo::riferisci_gusto`, che confronta le sei voci di là e invalida la
## vista SOLO se una è cambiata (src/ecs_mondo.cpp) — MISURATO da una
## revisione avversariale, che ha visto la mutazione «riproietta sempre»
## restare verde proprio per quello. Qui il confronto risparmia un
## marshalling di Variant per residente ogni `FATTI_OGNI` frame: piccolo, ma
## la ragione è quella, e vale la pena scriverla giusta.
func _cuore_di(r: Dictionary, node: Node3D) -> void:
	if _ecs == null or not is_instance_valid(_ecs) or not r.has("ecs"):
		return
	# SFALSATO PER RESIDENTE, con l'etichetta come seme. Senza questa riga
	# ventotto vicini caricati nello stesso frame si riproietterebbero tutti
	# insieme ogni mezzo secondo: la spesa sarebbe la stessa in media e un
	# picco venti volte più alto, cioè uno scatto ogni mezzo secondo nel
	# villaggio più pieno — che è l'unico posto in cui si nota.
	if not r.has("cuore_scad"):
		r["cuore_scad"] = float(absi(hash(str(r.get("label", "")))) % FATTI_OGNI)
	var scad := float(r["cuore_scad"])
	r["cuore_scad"] = scad - 1.0
	if scad > 0.0:
		return
	r["cuore_scad"] = float(FATTI_OGNI)

	var id: int = int(r["ecs"])
	# L'INDOLE ARRIVA DAL CERVELLO, non dal genoma: è lì che vive quella VERA
	# (il genoma può non averla affatto — i villaggi salvati prima che le
	# indoli ci entrassero — e `debug_quirk` scrive su un cervello vivo). È la
	# stessa fonte da cui `_ecs_id` proietta la finestra del sonno: una
	# persona, un'indole.
	var g: PackedFloat64Array = GUSTO.da_dna(
			r.get("dna", {}), _ensure_brain(r).indole)
	if r.get("gusto_ecs") != g:
		r["gusto_ecs"] = g
		_ecs.riferisci_gusto(id, g)

	# FASE 5: LA RICEVUTA DELLA DEDUZIONE. Sta qui, sulla cadenza dei fatti,
	# e non nel `_process` di nessuno: una deduzione arriva al massimo una
	# volta ogni cinque minuti per vicino (`Pensatoio.RIPOSO`), quindi
	# chiedere «ce n'è una da mostrare?» mezzo secondo dopo l'altro è già
	# ottanta volte più spesso del necessario. Nel caso normale — e il caso
	# normale è «non c'è nessun modello» — costa un confronto fra interi.
	#
	# PRIMA della promozione e del suo `return`: una deduzione che aspetta la
	# sua ricevuta non deve rimanere muta perché quel giorno il vicino aveva
	# già promosso un ricordo.
	#
	# ⚠️ **DOVE STA MOCHI È UN ARGOMENTO, e senza di lei non si paga niente.**
	# La ricevuta è una testa che si gira: se non c'è nessun giocatore — i
	# banchi di prova, il diorama del titolo — non c'è nemmeno nessuno che
	# possa vederla, e una conseguenza la cui premessa non ha visto nessuno è
	# il guasto che tutta la Fase 5 esiste per rendere impossibile. Qui il
	# degrado va verso il SILENZIO e non verso «come si è sempre fatto», ed è
	# l'unico posto della classe in cui è così: `_dove_sta_mochi` ripiega su
	# `home` perché di là un'ancora che non si sposta è il comportamento di
	# sempre; qui ripiegare vorrebbe dire pagare una ricevuta a nessuno.
	var muta: int = int(_ecs.deduzione_muta(id, AMMIRA_SOGLIA))
	if muta >= 0 and _player != null and is_instance_valid(_player):
		if DEDUZIONI.consegna(_ecs, id, node, muta, _player.global_position,
				r.get("luoghi", []), int(r.get("fatti", 0))):
			_ded_ricevute += 1
			# IL PENSIERO. La ricevuta di una deduzione era, letteralmente,
			# una testa che si gira: il giocatore vedeva quello e poi, sette
			# secondi dopo, un vicino che cambiava mestiere. Adesso il corpo
			# **si ferma**, il capo pende una volta o due, e si riparte
			# decisi — e la ripartenza decisa porta il Rialzo addosso, che è
			# la faccia visibile di «ho deciso».
			#
			# Se il gettone è occupato non succede niente e la ricevuta resta
			# pagata: la testa si gira comunque. La regola è quella della
			# Fase 5 — **la ricevuta non è MAI condizionata dal gettone**.
			chiedi_gesto(str(r.get("label", "")), "ha_dedotto")

	# LA PROMOZIONE: una al giorno, e solo per quello che ha visto coi propri
	# occhi. È l'unico residuo di tutta la Fase 4 che attraversa un riavvio, e
	# passa da un canale che esiste già, è già persistito, è già limitato a
	# sei e ha già un consumatore che lo mette in scena senza parole. Il grafo
	# dei ricordi, lui, non si salva: l'emozione dura minuti e non lascia
	# traccia, o si imparerebbe a farsi guardare per «caricare» qualcuno.
	#
	# «DURA MINUTI» NON È GRATIS: non basta non salvare il grafo, perché una
	# CONSEGUENZA può sopravvivere al ricordo che l'ha prodotta. È già
	# successo due volte, e le due riparazioni sono `AMMIRA_SOGLIA` passata a
	# `dove()` (l'ancora che torna a casa) e il freddo che `racconta` incide
	# nell'eco (la voce che non risorge). Chi aggiunge un terzo lettore del
	# grafo deve chiedersi non «cosa legge», ma **quando smette di leggere**.
	if bool(r.get("promosso_oggi", false)):
		return
	var c: int = int(_ecs.cosa_da_ricordare(id, RICORDO_SOGLIA))
	if c < 0:
		return
	r["promosso_oggi"] = true
	# Il secondo campo è una CHIAVE, mai una frase: non lo mostra nessuno, e
	# il giorno che lo mostrasse servirebbe `L10n.rendi()`. Il primo è il
	# concetto che uscirà dalla nuvoletta — cioè una parola che un chibi sa
	# davvero dire (`Visitor.LP_SIMBOLI`).
	var nome := str(_ecs.nome_cosa(c))
	if nome != "":
		_ensure_brain(r).remember(nome, nome)
	_se_lo_tiene(r, node, id, c)


## «SE LO TIENE» — il corpo della PROMOZIONE, e il gemello senza modello del
## pensiero.
##
## Fin qui la promozione era **completamente invisibile**: un ricordo passava
## dal grafo che vive in RAM a `VillagerBrain.remember`, che attraversa un
## riavvio, e sullo schermo non succedeva niente. Il giocatore avrebbe visto
## la conseguenza — quella parola che scappa in una nuvoletta, giorni dopo —
## senza mai aver visto il momento in cui quel vicino ha deciso di tenersela.
## Una conseguenza senza premessa non attenua l'effetto: **lo inverte**.
##
## ⚠️ **E QUESTA È L'OCCASIONE CHE FUNZIONA PER TUTTI.** L'altra metà del
## «pensiero» — la deduzione della Fase 5 — vuole un modello linguistico da
## due gigabyte e mezzo, cioè non succede a chi non l'ha scaricato: senza
## questa, il gesto più bello del vocabolario sarebbe stato una funzione
## facoltativa. La promozione invece è vecchia quanto la Fase 4, gira in ogni
## partita, ed è già limitata a **una al giorno per vicino**.
##
## LE DUE RIGHE, nell'ordine, e l'ordine è quello di `Percezione`:
##  1. la TESTA va sul posto di quel ricordo — è la ricevuta, e non passa
##     dal gettone: si paga sempre, come quella della Fase 5;
##  2. il CORPO, se il villaggio ha spazio — e quasi sempre non ce l'ha.
##
## L'ANCORA SI VERIFICA, e se non c'è si tace. `EcsMondo.dove()` ripiega su
## casa propria quando di quel ricordo non resta abbastanza: guardarsi la
## porta di casa e poi fermarsi non racconta niente a nessuno, ed è
## esattamente il gesto che il giocatore non saprebbe ricondurre a sé.
func _se_lo_tiene(r: Dictionary, node: Node3D, id: int, cosa: int) -> void:
	if node == null or not is_instance_valid(node) \
			or not node.has_method("guarda_gesto"):
		return
	var home := Vector3(r["cell"].x, 0, r["cell"].y)
	var dove: Vector3 = _ecs.dove(id, cosa, AMMIRA_SOGLIA, home)
	if not REGIA.ancora_valida(dove, home):
		return
	node.call("guarda_gesto", dove, PERCEZIONE.DURATA_SGUARDO)
	var label := str(r.get("label", ""))
	if chiedi_gesto(label, "se_lo_tiene"):
		return
	# ⚠️ **E SE IL CORPO NON È IN CAMMINO, SI ASPETTA — quanto dura la testa
	# girata, e non un secondo di più.** Una promozione capita al massimo una
	# volta al giorno per vicino e cade dove capita: seduto in panchina, fermo
	# a un cespuglio, appena arrivato. Il Punto invece è un contrasto di MOTO
	# e vuole un passo da spezzare. MISURATO nel villaggio vero: dei no,
	# **284 erano «non cammina»** — cioè l'occasione più rara e più bella del
	# vocabolario cadeva quasi sempre sul corpo sbagliato.
	# La premessa è la testa girata verso quel posto: finché è girata, il
	# corpo che si ferma si legge come la seconda metà dello stesso gesto.
	_rimanda_gesto(label, "se_lo_tiene", PERCEZIONE.DURATA_SGUARDO)


## I FATTI DEL MONDO per un residente, come maschera di bit.
##
## Si rinfrescano ogni FATTI_OGNI frame, SFALSATI per residente: il
## contesto costa (il Garden, i cespugli, gli altri vicini) e calcolarlo a
## sessanta hertz per ventotto persone vorrebbe dire metà frame. Sfalsato,
## a ogni frame se ne rinfresca circa uno — la stessa spesa di prima, con i
## fatti freschi ogni mezzo secondo invece che ogni 9-15 secondi. Lo
## sfalsamento è la riga di `hash(label)` qui sotto, e non è decorativa:
## senza, «circa uno per frame» diventa «tutti e ventotto insieme, due
## volte al secondo».
##
## Fra un rinfresco e l'altro il motore continua a valutare: sono i BISOGNI
## a scorrere di continuo, e sono loro a muovere le decisioni.
func _fatti_di(r: Dictionary, node: Node3D) -> int:
	var scad := float(r.get("fatti_scad", -1.0))
	r["fatti_scad"] = scad - 1.0
	if scad > 0.0 and r.has("fatti"):
		return int(r["fatti"])
	# SFALSATO PER RESIDENTE, con l'etichetta come seme — come in `_cuore_di`.
	# Senza, `load_extra` crea tutti i residenti nello stesso frame, tutti
	# scadono nello stesso frame, e ventotto `_brain_ctx` +
	# `_luoghi_del_piano` cadono INSIEME due volte al secondo, per sempre.
	# La MEDIA resta quella promessa qui sopra — ed è per questo che una
	# media non basta a vedere il guasto — mentre il picco è ventotto volte
	# tanto. Misurato nel MainLevel vero, 28 vicini su 600 frame
	# (`tools/misura_picco_fatti.gd`): prima 19 frame caldi e picco 28, con
	# l'istogramma tutto-o-niente (0 oppure 28, mai una via di mezzo); dopo,
	# 292 frame caldi e picco 6, a media invariata.
	#
	# IL SEME VA QUI, NON SUL DEFAULT DI `r.get`, e la differenza col gemello
	# è la clausola `and r.has("fatti")` della guardia qui sopra: `_cuore_di`
	# si ferma al solo `scad > 0.0` e lì basta seminare il contatore prima.
	# Qui la clausola c'è per forza — senza, il ritorno in cache leggerebbe
	# una chiave che non esiste ancora — e rende il primo giro un rinfresco
	# QUALUNQUE cosa dica il contatore: seminare il default è un no-op
	# esatto, misurato (stessi 19 frame caldi, stesso picco 28).
	# Si sfalsa perciò la FASE, non il primo giro, ed è anche giusto così:
	# chi non ha ancora i fatti resterebbe senza `luoghi`, che `_recita` e
	# `_piano_dirotta` si aspettano pronti nello stesso ciclo. E nessuno
	# aspetta più di prima: il seme sta sotto FATTI_OGNI, quindi il ciclo si
	# accorcia soltanto — verificato su tutti e trenta i semi, ogni rinfresco
	# cade dove cadeva o prima, mai dopo.
	#
	# Il modulo è FATTI_OGNI per stare identico al gemello, non perché sia il
	# numero esatto: fra un rinfresco e il successivo passano 31 chiamate, e
	# una fase su 31 non viene mai usata. Sui 28 nomi veri (`ChibiDNA.NAMES`)
	# vale un rinfresco: picco 5 col 30, picco 4 col 31. Se la si vuole, si
	# cambia QUI E NEL GEMELLO insieme.
	r["fatti_scad"] = float(FATTI_OGNI) if r.has("fatti") \
			else float(absi(hash(str(r.get("label", "")))) % FATTI_OGNI)
	# FUORI DAL VILLAGGIO NON CI SONO FATTI. `_brain_ctx` interroga il
	# BuildSystem, il Garden e i gruppi dell'albero: senza mondo esploderebbe
	# a ogni rinfresco, e un errore a runtime interrompe la funzione in
	# silenzio lasciando la suite verde. Con l'agenda che gira dentro
	# `_ciclo_sonno` questo percorso lo attraversano anche i test dei
	# residenti, che il villaggio non ce l'hanno.
	if _ecs == null or _build == null or not is_inside_tree():
		return int(r.get("fatti", 0))
	var ph := _phase()
	var ctx := _brain_ctx(r, ph)
	var nomi: Array = []
	if bool(ctx.get("mattina", false)):
		nomi.append("mattina")
	if bool(ctx.get("sera_stellata", false)):
		nomi.append("sera_stellata")
	if bool(ctx.get("aiuola_da_annaffiare", false)):
		nomi.append("aiuola_da_annaffiare")
	if bool(ctx.get("spuntino_vicino", false)):
		nomi.append("spuntino_vicino")
	if bool(ctx.get("amico_in_giro", false)):
		nomi.append("amico_in_giro")
	if bool(ctx.get("regia", false)):
		nomi.append("regia")
		# DIVERGENZA VOLUTA: «regia» valeva 0.75 anche quando il Regista non
		# aveva ancora un piano per quel residente, e la scena cadeva su
		# «wander» senza dirlo. Adesso l'azione non è nemmeno fattibile.
		# si chiede se un piano C'È, non lo si esegue: `plan_for` entrerebbe
		# in Lua e produrrebbe il piano vero, sessanta volte al minuto e per
		# niente. `ha_piano` risponde con le stesse due condizioni.
		var reg := get_tree().get_first_node_in_group("regista")
		if reg != null and reg.has_method("ha_piano") and bool(reg.call("ha_piano", r)):
			nomi.append("regia_pronta")
	# DIVERGENZA VOLUTA: senza un posto da guardare, «meraviglia» non è
	# fattibile. Prima vinceva lo stesso e poi il corpo gironzolava.
	var home := Vector3(r["cell"].x, 0, r["cell"].y)
	if _nearest_named(["Stagno", "Grande Albero", "Panchina"], home, 18.0) != null:
		nomi.append("meraviglia_posto")
	# FASE 3: i cinque luoghi, e quali si raggiungono davvero. Si calcolano
	# qui perché `_recita` li ritrovi pronti nello stesso ciclo — chiedere
	# due volte al mondo dove sono le cose, a mezzo secondo di distanza,
	# vuol dire pianificare su un mondo e camminare in un altro.
	var luoghi := _luoghi_del_piano(r, home)
	r["luoghi"] = luoghi
	nomi.append_array(PIANI.fatti(luoghi))
	var m := int(_ecs.maschera_fatti(PackedStringArray(nomi)))
	r["fatti"] = m
	return m


## I CINQUE LUOGHI del piano, nell'ordine di `chibi::Luogo`.
##
## La distanza è in linea d'aria, non sulla rotta, ed è una scelta: la
## rotta vera costa una BFS per luogo per vicino (centoquaranta al secondo
## in un villaggio pieno), e servirebbe solo a scegliere fra due posti
## quasi equivalenti. Quello che NON si approssima è la raggiungibilità,
## che è un confronto fra due interi ed è esatta: si può sbagliare di
## qualche metro quale cespuglio conviene, mai credere di arrivare a un
## cespuglio chiuso in un recinto.
## IL PIANO CAMBIA LA SCENA? Torna `true` solo quando il risolutore
## sceglie una catena che comincia con «vai alla lavagna» — cioè quando ha
## scoperto che al posto giusto non ci si arriva più, e che l'unica strada
## rimasta passa da Mochi.
##
## Nel caso comune il piano dice esattamente quello che `_recita` farebbe
## da sola, e allora si lascia recitare lei: NON si ricostruisce qui la
## messa in scena di quattro gesti che esistono già, tarati, con i loro
## toast e le loro callback. Il pianificatore non è arrivato per rifare
## quello che funzionava — è arrivato per il giorno in cui non funziona.
func _piano_dirotta(r: Dictionary, node: Node3D, act: String, home: Vector3) -> bool:
	if _ecs == null or _build == null:
		return false
	var luoghi: Array = r.get("luoghi", [])
	if luoghi.size() < PIANI.LUOGHI.size():
		return false
	var ob: int = int(_ecs.maschera_obiettivo(str(PIANI.OBIETTIVO[act])))
	if ob == 0:
		return false
	var passi: PackedInt32Array = _ecs.pianifica(
			int(r.get("fatti", 0)), ob, PIANI.cammino(luoghi))
	if passi.is_empty() or int(passi[0]) != int(_ecs.indice_operatore("vai_alla_lavagna")):
		return false
	var lavagna: Dictionary = luoghi[PIANI.LUOGHI.find("lavagna")]
	var pos: Vector3 = lavagna["pos"]
	var label := str(r.get("label", ""))
	var com := get_tree().get_first_node_in_group("commissioni")
	if com == null or not com.has_method("appendi_per"):
		return false
	# la merce la decide il GESTO che non si può più fare: chi non arriva
	# più al cespuglio chiede da mangiare, chi non arriva più all'aiuola
	# chiede di che curarla
	var merce := "mela" if act == "spuntino" else "bacca"
	node.call("go_write", pos + (home - pos).normalized() * 0.9, pos,
			func(): com.call("appendi_per", label, merce))
	# la finestra: mentre scrive, l'agenda non gli cambia idea sotto
	r["next_act"] = 9.0
	return true


## FASE 5: L'OBIETTIVO PRIORITARIO. Il raccordo fra il registro e l'ufficio
## delle deduzioni, e non fa nient'altro: la regola sta tutta in
## `Deduzioni.dirotta()`, che è pura e si può guastare una valvola per volta
## senza un villaggio in scena.
##
## Torna l'azione da recitare. Senza cuore, senza deduzioni pronte, o con un
## mondo che non ha una strada, torna **la stessa Stringa** che le è
## arrivata: `_recita` non si accorge che questa riga esiste.
func _deduzione_dirotta(r: Dictionary, act: String) -> String:
	if _ecs == null or not is_instance_valid(_ecs) or not r.has("ecs"):
		return act
	var nuova: String = DEDUZIONI.dirotta(_ecs, int(r["ecs"]), act,
			r.get("luoghi", []), int(r.get("fatti", 0)), AMMIRA_SOGLIA)
	if nuova != act:
		_ded_dirotti += 1
	return nuova


## I DUE NUMERI DELLA FASE 5 CHE SOLO IL REGISTRO PUÒ CONTARE: quante
## ricevute sono state PAGATE (teste girate che il giocatore ha potuto
## vedere) e quanti mestieri sono cambiati per una deduzione.
##
## Non sono strumentazione da banco appiccicata sopra: sono i due eventi che
## la nota di consegna dell'injection promette al giocatore, e senza un
## contatore l'unico modo di misurarli sarebbe RIFARE la regola dentro un
## banco — cioè chiedere al giudice se è d'accordo con sé stesso, che è
## esattamente l'errore che `tools/misura_cammino.gd` esiste per non
## commettere. Costano due interi e nessun ramo: senza modello nessuno dei
## due `if` viene mai raggiunto, perché le due funzioni sopra tornano prima.
func debug_deduzioni_contatori() -> Dictionary:
	return {"ricevute": _ded_ricevute, "dirotti": _ded_dirotti}


## GLI OBIETTIVI PER CUI IL MONDO HA UNA STRADA, adesso, per questo vicino.
##
## Serve alla GRAMMATICA delle deduzioni (`Suggeritore.grammatica_deduzione`
## la legge da `rit["fattibili"]`), e serve al Giudice. Non è una guardia in
## più: è la stessa guardia, spostata **prima del campionamento** invece che
## dopo. Un obiettivo che il mondo non sa servire, se il modello riesce a
## proporlo, costa una bozza buttata; se non riesce a proporlo, costa niente.
##
## Vuoto quando non c'è il cuore o non ci sono ancora i luoghi: di là «vuoto»
## vuol dire «non filtrare», cioè il comportamento che c'era prima.
func obiettivi_fattibili(r: Dictionary) -> Array:
	var out := []
	if _ecs == null or not is_instance_valid(_ecs):
		return out
	var luoghi: Array = r.get("luoghi", [])
	if luoghi.size() < PIANI.LUOGHI.size():
		return out
	var cammino := PIANI.cammino(luoghi)
	var fatti := int(r.get("fatti", 0))
	for act in PIANI.OBIETTIVO:
		var nome := str(PIANI.OBIETTIVO[act])
		var ob := int(_ecs.maschera_obiettivo(nome))
		if ob == 0:
			continue
		if not (_ecs.pianifica(fatti, ob, cammino) as PackedInt32Array).is_empty():
			out.append(nome)
	return out


func _luoghi_del_piano(r: Dictionary, home: Vector3) -> Array:
	var fuori := []
	var cerca := func(nodo: Node3D) -> Dictionary:
		if nodo == null:
			return {"ok": false, "metri": 0.0, "pos": Vector3.ZERO}
		var p: Vector3 = nodo.global_position
		return {"ok": true, "metri": p.distance_to(home), "pos": p}
	fuori.append(cerca.call(_nearest_named(["Cespuglio", "Fungo", "Orto"], home, 12.0)))
	var aiuola: Node3D = _aiuola_da_curare(r, home)
	if aiuola != null:
		if not _build.raggiungibile(
				Vector2i(roundi(home.x), roundi(home.z)),
				Vector2i(roundi(aiuola.global_position.x), roundi(aiuola.global_position.z))):
			aiuola = null  # il Garden non sa dei recinti: glielo si dice qui
	fuori.append(cerca.call(aiuola))
	fuori.append(cerca.call(_panchina_per(r, home)))
	fuori.append(cerca.call(_nearest_named(["Stagno", "Grande Albero", "Panchina"], home, 18.0)))
	# LA LAVAGNA È PRONTA solo se non c'è già un biglietto di questo vicino:
	# uno che ha già chiesto non va a chiedere di nuovo, va a fare altro.
	# Senza questa condizione il piano «vai a chiedere» resterebbe il più
	# economico per sempre, e il vicino passerebbe la giornata alla lavagna.
	var lavagna: Node3D = null
	var com := get_tree().get_first_node_in_group("commissioni")
	if com != null and com.has_method("ha_richiesta_di") \
			and not bool(com.call("ha_richiesta_di", str(r.get("label", "")))):
		lavagna = _nearest_named(["Lavagna"], home, 60.0)
	fuori.append(cerca.call(lavagna))
	return fuori


## LA MARIONETTA DELL'AGENDA, e la regola è una: si recita SOLO SUL FRONTE.
##
## `_recita` chiama `do_task`/`do_routine`, che riscrivono lo stato e
## rimettono il corpo in cammino. Chiamarla a ogni frame vorrebbe dire
## rilanciare il cammino sessanta volte al secondo, cioè NON ARRIVARE MAI —
## e senza arrivare il gesto non si compie, il bisogno non si sazia, e il
## bisogno insoddisfatto rilancia la scelta. Un livelock che non stampa
## nessun errore. Per questo il permesso di recitare è `azione_cambiata`,
## che è vero in un frame solo.
func _gesti_agenda() -> void:
	if _ecs == null:
		return
	var ph := _phase()
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if not r.has("ecs"):
			continue
		var id: int = int(r["ecs"])
		# IL PAGAMENTO ALL'ARRIVO. Il latch serve perché un gesto che dura
		# dieci secondi non sazi dieci volte al secondo: si paga una volta
		# per azione, e il latch si azzera quando l'azione cambia.
		var st_corpo := str(node.get("_state"))
		if STATO_CHE_SAZIA.has(st_corpo):
			if not bool(r.get("saziato", false)):
				r["saziato"] = true
				_ensure_brain(r).satisfy(str(STATO_CHE_SAZIA[st_corpo]))
		if not _ecs.azione_cambiata(id):
			continue
		r["saziato"] = false
		var idx: int = _ecs.azione(id)
		if idx < 0 or idx >= BRAIN.AZIONI.size():
			continue
		var brain: RefCounted = _ensure_brain(r)
		var act := str(BRAIN.AZIONI[idx])
		# il Limbico può ancora far cambiare idea su un LUOGO diventato
		# insopportabile: è una ferita del personaggio, non una preferenza,
		# e resta dov'era
		act = _filtra_luogo(str(r.get("label", "")), act)
		# FASE 5: E POI LA DEDUZIONE, se ce n'è una che ha già mostrato la
		# sua ricevuta. DOPO il Limbico apposta — una ferita del personaggio
		# non si discute con una macchina — e dentro il fronte, che è l'unico
		# posto in cui cambiare idea non rompe nessuna delle tre leve della
		# Fase 2. Senza modello questa riga restituisce la stessa Stringa.
		act = _deduzione_dirotta(r, act)
		_recita(r, node, brain, act, ph)
		# IL POZZO DELLE CHIACCHIERE, e va chiuso qui o il motore ci cade
		# dentro. Chi sceglie «quattro_chiacchiere» non sazia NIENTE: la
		# compagnia la ricarica solo l'incontro vero (_run_chat), che scatta
		# per prossimità, una coppia ogni 3,5 s in tutto il villaggio.
		# Prima non si vedeva perché si ridecideva ogni 9-15 secondi col
		# dado; adesso il dado è congelato dentro la decisione, quindi
		# l'azione continuerebbe a vincere e il vicino trascurerebbe la fame
		# restando in piedi ad avvicinarsi a qualcuno.
		# Si dà una FINESTRA (il lease che zittisce l'agenda, lo stesso che
		# usano gli undici sistemi a evento): dentro quella finestra
		# `_run_chat` può succedere davvero, e se non succede si esce
		# comunque con una consolazione.
		if act == "quattro_chiacchiere":
			r["next_act"] = 12.0
			r["chiacchiere_in_corso"] = true


## Fatti → passo → gesti, dentro UN frame e in quest'ordine. È una funzione
## a sé anche perché così si può PROVARE: far girare `_process` vorrebbe il
## villaggio intero (mondo, meteo, costruzioni).
func _ciclo_sonno(delta: float, t_ora: float) -> void:
	_ensure_ecs()
	# 1) I FATTI. `brain.tick` sta qui, prima di ogni transizione, esattamente
	#    dov'era.
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var brain: RefCounted = _ensure_brain(r)
		var nascosto: bool = node.call("is_hidden")
		brain.tick(delta, nascosto)
		if _ecs != null:
			var id_e: int = _ecs_id(r)
			_ecs.riferisci(id_e, nascosto,
					str(node.get("_state")) in STATI_INTERROMPIBILI,
					_puo_entrare(r))
			# --- FASE 2: i fatti dell'agenda ---
			_ecs.riferisci_bisogni(id_e, brain.bisogni_packed())
			_ecs.riferisci_agenda(id_e, _fatti_di(r, node),
					str(node.get("_state")) in STATI_A_RIPOSO,
					float(r.get("next_act", 0.0)) > 0.0)
			# --- FASE 4: il cuore. Alla cadenza dei FATTI, sfalsata: il
			#     gusto si riproietta solo se è cambiato, e una volta al
			#     giorno il ricordo più forte diventa un ricordo per sempre.
			_cuore_di(r, node)
			# il dado si tira una volta per DECISIONE, non a ogni frame
			if _ecs.vuole_dado(id_e):
				_ecs.semina_agenda(id_e, brain.jitter())
	if _ecs == null:
		return
	# 2) IL PASSO: l'unica decisione che il C++ possiede in tutto il gioco
	_ecs.avanza(delta, t_ora)
	# 3) I GESTI. Applicazione IDEMPOTENTE: si guarda com'è il corpo ADESSO e
	#    lo si porta dov'è giusto. Nessun fronte da perdere, nessun ordine da
	#    ricordare — e se un altro sistema ha mosso il corpo nel frattempo, al
	#    giro dopo il registro lo accetta invece di combatterlo.
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var id: int = _ecs_id(r)
		var st: int = _ecs.stato(id)
		var nascosto: bool = node.call("is_hidden")
		var lab := str(r.get("label", ""))
		# la posa della porta chiusa la mette e la toglie SEMPRE lo stesso
		# posto, e solo se è ancora la nostra
		_aggiorna_posa_fuori(lab, node, st == _ST_FUORI)
		if st == _ST_DORME:
			if not nascosto:
				node.call("resident_sleep")
		else:
			if nascosto:
				node.call("resident_wake")
			elif not (_ecs.in_finestra(id) \
					and str(node.get("_state")) in STATI_INTERROMPIBILI):
				# le stravaganze continuano a girare quando non sta per
				# andare a letto: la loro whitelist è un sottoinsieme di
				# STATI_INTERROMPIBILI, quindi la condizione è la stessa di
				# prima detta al contrario
				_quirk_tick(r, node, _ensure_brain(r), delta, t_ora)


# LA FINESTRA DI SONNO NON ABITA PIÙ QUI. Era `_sleep_window(brain, t)`, ed
# è stata spostata in C++ (src/sistema_sonno.cpp) insieme alla decisione che
# la usava — non ne resta una copia, perché una seconda formula è esattamente
# il modo in cui due verità cominciano a divergere in silenzio.
# Una copia CONGELATA vive in tests/oracolo_sonno.gd e serve solo alla prova
# di equivalenza (tests/cases/test_ecs_mondo.gd).


func _ensure_brain(r: Dictionary) -> RefCounted:
	var key := str(r.get("label", "?"))
	if not _brains.has(key):
		var brain: RefCounted = BRAIN.new()
		brain.setup(r.get("dna", {}))
		var salvato: Dictionary = r.get("brain", {})
		if not salvato.is_empty():
			brain.from_dict(salvato)
		_brains[key] = brain
		# insieme al cervello nasce l'ANIMO: dal genoma prende sogno e tratti
		var animo: RefCounted = ANIMO.new()
		animo.setup(r.get("dna", {}))
		animo.nome = key
		var salvato_a: Dictionary = r.get("animo", {})
		if not salvato_a.is_empty():
			animo.load(salvato_a)
		_animi[key] = animo
		_iscrivi_al_villaggio(key, animo)
		# il timido saluta solo gli amici veri
		var node := r.get("node") as Node3D
		if node:
			node.set("greet_enabled",
					not brain.has_indole("timido") or int(r.get("friend", 0)) >= 3)
	# il saluto della sua indole arriva al corpo (una volta sola per nodo:
	# i nodi rinascono a ogni alba, il cervello no)
	var nodo_s := r.get("node") as Node3D
	if nodo_s and is_instance_valid(nodo_s) \
			and str(nodo_s.get("saluto_stile")) == "":
		nodo_s.set("saluto_stile", VISITOR.saluto_di(_brains[key]))
	return _brains[key]


# I POSTI CHE NON SI SOPPORTANO PIÙ.
#
# L'ultimo pezzo del limbico: un marchio non è solo un numero nel salvataggio,
# è una deviazione nel cammino. Il residente arriva in vista dell'orto, si
# ferma, e va da un'altra parte — e siccome il giocatore vede la scena senza
# spiegazione, il registro gliela dà: «gira al largo dalla catasta».
#
# Ritorna l'attività da fare DAVVERO: quella scelta, o un ripiego se il posto
# è diventato insopportabile.
func _filtra_luogo(label: String, act: String) -> String:
	if not _animi.has(label):
		return act
	var luogo := str(LUOGO_ATTIVITA.get(act, ""))
	if luogo == "":
		return act
	var animo: RefCounted = _animi[label]
	if not animo.limbico.evita(luogo):
		return act
	var nodo: Node3D = null
	for r in _residents:
		if str(r.get("label", "")) == label:
			nodo = r.get("node") as Node3D
			break

	# SE MOCHI È LÌ, CI VA LO STESSO.
	#
	# La trappola della paura appresa è che si autoalimenta: chi evita un
	# posto non ci torna mai, e non tornandoci non scopre mai che adesso
	# non succede nulla. Da solo, quel marchio non si sarebbe spento più —
	# e `Limbico.visita_serena`, la porta per rimediare a un trauma, non
	# la apriva nessuno.
	# La chiave è la cosa più semplice e più vera del mondo: con un amico
	# accanto ci si va. Se il giocatore è a due passi nel momento in cui
	# il vicino si blocca, il vicino tira su il musetto e ci va — e la
	# visita, siccome non succede niente, DIMEZZA la paura. Bastano poche
	# volte perché il posto torni un posto qualunque.
	if nodo != null and is_instance_valid(nodo) and _player != null \
			and _player.global_position.distance_to(nodo.global_position) < 3.5:
		animo.limbico.visita_serena(luogo)
		if nodo.has_method("celebrate"):
			nodo.call("celebrate")
		if nodo.has_method("speak"):
			nodo.call("speak", ["coraggio", "amico"], "felice")
		nodo.set_meta("postura", "si_illumina")
		if not animo.limbico.evita(luogo):
			_show_toast(L10n.tf("Con te accanto, %s ci torna — e non succede niente.",
					[label]))
		return act

	# altrimenti ci arriva vicino e si blocca: è la scena che il giocatore vede
	if nodo != null and is_instance_valid(nodo) and nodo.has_method("chat_bubble"):
		nodo.call("chat_bubble", "…")
		nodo.set_meta("postura", "esita")
		# IL LARGO. Fin qui il vicino cambiava idea e se ne andava **senza
		# nessun segno residuo**: il momento c'era nella simulazione e il
		# corpo non lo diceva. Non si chiede adesso — adesso è ancora fermo,
		# e il Largo è l'unico gesto che si recita CAMMINANDO: si segna il
		# posto e si aspetta che il ripiego lo metta in movimento.
		var dove := _luogo_posizione(luogo, label, nodo.global_position)
		if dove != Vector3.ZERO:
			_rimanda_gesto(label, "quel_posto_no", 4.0, {"posto": dove}, dove)
	return RIPIEGO           # cambia idea e va a cercare compagnia


## Dove sta, nel mondo, un luogo del Limbico. La metà FISICA della stessa
## corrispondenza di `LUOGO_ATTIVITA` — e i nomi dei pezzi si leggono da dove
## già vivono (`PEZZI_CIBO`, la stessa lista che usa `_recita` per lo
## spuntino) invece di ricopiarli qui.
##
## Il BOSCO non ha un posto: non è un pezzo costruito, è una direzione. Chi
## evita il bosco non ha niente da guardare, e il Largo non parte — che è il
## degrado giusto (silenzio, mai un gesto verso il niente).
func _luogo_posizione(luogo: String, label: String, da: Vector3) -> Vector3:
	match luogo:
		"cucina":
			var cibo := _nearest_named(PEZZI_CIBO, da, 14.0)
			if cibo != null:
				return cibo.global_position
		"orto":
			for r in _residents:
				if str(r.get("label", "")) == label:
					var bed: Node3D = _aiuola_da_curare(r, da)
					if bed != null:
						return bed.global_position
					break
	return Vector3.ZERO


## Da quali posti questo residente gira al largo, e perché. Il registro lo
## mostra: una deviazione senza spiegazione sembra un difetto di percorso.
func luoghi_evitati(label: String) -> Array:
	if not _animi.has(label):
		return []
	var out := []
	var lim = (_animi[label] as RefCounted).limbico
	for posto in ["catasta", "orto", "cucina", "confine", "bosco"]:
		if lim.evita(posto):
			out.append(posto)
	return out


# ============================================ la partenza

## Dopo quanti secondi dallo sfogo chi ha detto «me ne vado» se ne va davvero.
## Non subito: il giocatore deve avere il tempo di corrergli dietro con un
## regalo. È l'ultima finestra per rimediare, e dev'essere una finestra vera.
const ATTESA_PARTENZA := 90.0

# CHI DICE «ME NE VADO» SE NE VA.
#
# Era il buco più grande del sistema: la scala arrivava in fondo e non
# succedeva niente, e una minaccia che non si avvera insegna al giocatore che
# può ignorare tutto. Ora il residente prepara le sue cose, lascia una
# LETTERA (non sparisce e basta: sparire è un bug, una lettera è una storia)
# e il suo letto torna libero.
func _tick_partenze(delta: float) -> void:
	for i in range(_residents.size() - 1, -1, -1):
		var r: Dictionary = _residents[i]
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		# UN CUCCIOLO NON SE NE VA DA SOLO. Questo ramo non controllava
		# l'eta', e `e_cucciolo` lo chiamavano soltanto Lavori e
		# Commissioni: un piccolo il cui animo arrivava a «diserzione»
		# faceva il fagotto e usciva dal villaggio. Un bambino puo' essere
		# infelice — e deve poterlo essere — ma non traslocare.
		if e_cucciolo(label):
			r["parte_fra"] = 0.0
			continue
		var animo: RefCounted = _animi[label]
		if not ANIMO.almeno(int(animo.gradino), "diserzione"):
			r["parte_fra"] = 0.0        # ha cambiato idea: si rimette a posto
			continue
		var resta: float = float(r.get("parte_fra", 0.0))
		if resta <= 0.0:
			r["parte_fra"] = ATTESA_PARTENZA
			continue
		var prima := resta
		resta -= delta
		r["parte_fra"] = resta
		if resta > 0.0:
			# I NOVANTA SECONDI DEVONO VEDERSI. Se l'unico segnale fosse il
			# toast finale, la partenza sembrerebbe arbitraria: il giocatore
			# non ha avuto modo di accorgersene. Invece lo si vede raccogliere
			# le sue cose, fermarsi sulla soglia, guardarsi intorno — e ha
			# tutto il tempo di andargli incontro con qualcosa in mano.
			var node_p := r.get("node") as Node3D
			for soglia in [ATTESA_PARTENZA * 0.75, ATTESA_PARTENZA * 0.45,
					ATTESA_PARTENZA * 0.15]:
				if prima > soglia and resta <= soglia:
					if node_p != null and is_instance_valid(node_p):
						node_p.set_meta("postura", "fagotto_in_spalla")
						if node_p.has_method("chat_bubble"):
							node_p.call("chat_bubble", "…")
					_show_toast(L10n.tf("%s sta raccogliendo le sue cose.", [label]))
					break
			continue
		_congeda(i, r, animo)


# Il congedo: la lettera, il ricordo sul Filo Rosso, il letto che si libera.
func _congeda(i: int, r: Dictionary, animo: RefCounted) -> void:
	var label := str(r.get("label", ""))
	var node := r.get("node") as Node3D
	# la lettera d'addio, coi SUOI motivi: è ciò che trasforma una partenza
	# in una storia che il giocatore si ricorda invece che in un bug
	var mail := get_node_or_null("../Mail")
	if mail and mail.has_method("queue_letter"):
		mail.call("queue_letter", {
			"from_key": label,
			"text_key": "%s\n\nHo lasciato le mie cose in ordine.\nNon serbo rancore: serbo memoria.",
			# lo sfogo si mette in coda a PEZZI, non già detto: l'animo che
			# l'ha prodotto sparisce con lui, ma le sue chiavi restano e la
			# lettera parlerà la lingua di chi la apre domattina
			"args": [animo.sfogo_rimandato()],
			"gift": false,
		})
	# il toast della partenza va PRIMA: il toast è uno solo, e quello del
	# filo che si colora («il giorno in cui ha fatto il fagotto») arriva
	# dopo — se si scrivesse dopo, lo cancellerebbe nello stesso frame e
	# quella frase non si vedrebbe mai
	_show_toast(L10n.tf("%s se n'è andato.", [label]))
	# il Filo Rosso se lo ricorda: chi se n'è andato non si cancella
	for legami in get_tree().get_nodes_in_group("legami"):
		if legami.has_method("momento"):
			# il NOME, non la label: le chiavi dei fili sono il nome del
			# DNA (come negli altri otto punti). Passando la label,
			# l'addio — il momento piu' importante della diserzione —
			# finiva in un filo separato che nessuno leggeva mai.
			legami.call("momento",
					str((r.get("dna", {}) as Dictionary).get("name", "")),
					"addio", animo.racconta())
			# e il suo filo smette di invecchiare: senza, quaranta giorni
			# dopo il villaggio annuncerebbe i peli d'argento di chi non
			# c'è più (col nome storpiato) e il Gufo scriverebbe di
			# stargli vicino. La label si salva col filo: le sue lettere
			# la vogliono, e il DNA non esisterà più.
			legami.call("segna_andato_via",
					str((r.get("dna", {}) as Dictionary).get("name", "")), label)
			break
	# e via anche dalla lavagna dei compleanni: una festa a sorpresa per
	# chi non c'è più sarebbe la cosa più triste del villaggio
	get_tree().call_group("calendario", "dimentica",
			str((r.get("dna", {}) as Dictionary).get("name", "")))
	if node != null and is_instance_valid(node):
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	_residents.remove_at(i)          # il letto torna libero
	_animi.erase(label)
	_brains.erase(label)
	_dimentica_ecs(r)
	# e si congeda anche dal GRAFO del villaggio: senza questa riga il
	# disertore restava lì come un fantasma — continuava a spettegolare
	# contro di te a ogni simula_giorno e a tenere alta la tensione di un
	# posto che aveva già lasciato
	if _villaggio != null:
		_villaggio.rimuovi(label)
	_in_confronto.erase(label)
	_sussulto_cd.erase(label)
	_sussulto_cd.erase("morso_" + label)
	# e l'incarico si azzera: una label riciclata in futuro non deve
	# ereditare dal giorno uno un lavoro mai assegnato (rancore invisibile)
	get_tree().call_group("lavori", "assegna", label, "")


func _label_in_use(label: String) -> bool:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return true
	return false


# ================================================= API per il Filo Rosso
# (Congedo.gd orchestra il congedo, il lutto e l'empatia: queste sono le
#  mani che gli servono per muovere i residenti senza frugare nell'agenda)

func node_di(label: String) -> Node3D:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return r.get("node") as Node3D
	return null


func dna_di(label: String) -> Dictionary:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return r.get("dna", {})
	return {}


func cella_di(label: String) -> Vector2i:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return r["cell"]
	return Vector2i(999, 999)


## La label a partire dal NOME. I sistemi che ragionano di persone (il
## Filo Rosso, le nascite, il calendario) sono chiavati per nome; quelli
## che ragionano di corpi lo sono per label. Questa è la porta fra i due
## mondi, e prima ognuno se la riapriva per conto suo con un ciclo.
func label_di_nome(nome: String) -> String:
	for r in _residents:
		if str(r.get("dna", {}).get("name", "")) == nome:
			return str(r.get("label", ""))
	return ""


## Manda un residente in un punto (il giro delle ultime cose): l'agenda
## si mette da parte e lui va, si guarda intorno, resta un po'.
func manda(label: String, pos: Vector3) -> void:
	for r in _residents:
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			return
		if node.call("is_hidden"):
			node.call("resident_wake")
		r["next_act"] = 45.0
		node.call("do_task", "wonder", pos)
		return


## Il posto di ognuno attorno al fuoco: cerchi concentrici — undici per
## anello, poi si allarga — così anche in ventotto nessuno finisce seduto
## in braccio a un altro.
func _posto_al_falo(i: int) -> Vector3:
	@warning_ignore("integer_division")
	var anello := i / 11
	var ang := 0.9 + float(i) * 0.55 + float(anello) * 0.27
	return CLEARING + Vector3(cos(ang), 0, sin(ang)) * (1.7 + 0.85 * float(anello))


## Il raduno al falò: tutti attorno al fuoco (l'ultima sera del congedo
## la chiama il Congedo; la CLI la usa da sempre via debug_gather_fire).
func gather_fire() -> void:
	for i in _residents.size():
		var r := _residents[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		r["next_act"] = 9999.0
		node.call("do_routine", "fire", _posto_al_falo(i), CLEARING)


## La partenza per il Grande Prato: GENTILE. Niente lettera di rancore
## (quella è della diserzione): la storia l'ha già raccontata il congedo.
## La pulizia è la stessa di _congeda: letto libero, grafo, incarichi.
func parte_per_il_grande_prato(label: String) -> void:
	for i in _residents.size():
		var r := _residents[i]
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node != null and is_instance_valid(node):
			var tw := create_tween()
			tw.tween_property(node, "scale", Vector3.ONE * 0.01, 1.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(node.queue_free)
		# via dalla lavagna dei compleanni PRIMA di perdere il dna: chi
		# e' partito per il Grande Prato non festeggia piu' qui
		get_tree().call_group("calendario", "dimentica",
				str((r.get("dna", {}) as Dictionary).get("name", "")))
		_dimentica_ecs(r)
		_residents.remove_at(i)
		_animi.erase(label)
		_brains.erase(label)
		if _villaggio != null:
			_villaggio.rimuovi(label)
		_in_confronto.erase(label)
		_sussulto_cd.erase(label)
		_sussulto_cd.erase("morso_" + label)
		get_tree().call_group("lavori", "assegna", label, "")
		_build.request_save()
		return


# ------------------------------------------- l'empatia bidirezionale
# (Fase 6) Il colpo di scena del Filo Rosso: quando Mochi ha bisogno,
# sono i VICINI ad accorgersene. Ogni gentilezza al più una volta al
# giorno, mai due insieme: l'empatia vera è discreta.
# NB: la FAME è affare della Premura (scenes/npc/Premura.gd): il languore,
# il passo piccolo e il boccone diviso vivono là — qui restano il ritorno,
# la pioggia e il lutto, così nessun bisogno riceve due premure doppie.

var _pioggia_acc := 0.0
var _pioggia_fatta := false     # una premura per acquazzone, non una al secondo
var _ritorno_visto := false
var _empatia_giorno := {}       # motivo -> giorno in cui è già successa


func _tick_empatia(delta: float, raining: bool) -> void:
	if _residents.is_empty() or _player == null:
		return
	var oggi: int = int(_daynight.get("day")) if _daynight else 1

	# il ritorno dopo un'assenza REALE: ti sono mancati, e te lo dicono
	# venendoti incontro tutti insieme (una volta sola, poco dopo il load)
	if not _ritorno_visto:
		_ritorno_visto = true
		var legami: Node = get_tree().get_first_node_in_group("legami")
		if legami and float(legami.call("assenza_reale_giorni")) >= 2.0 \
				and _residents.size() >= 2:
			var pp: Vector3 = _player.global_position
			var quanti := 0
			for r in _residents:
				var node := r.get("node") as Node3D
				if node == null or not is_instance_valid(node) or node.call("is_hidden"):
					continue
				r["next_act"] = 30.0
				var ang := TAU * float(quanti) / 4.0
				node.call("do_routine", "sniff",
						pp + Vector3(cos(ang), 0, sin(ang)) * 1.3, pp)
				node.call("speak", ["ciao", "felice"], "felice")
				node.call("_spawn_heart")
				quanti += 1
				if quanti >= 4:
					break
			if quanti > 0:
				_show_toast(L10n.t("Bentornata! Ti hanno aspettata, giorno dopo giorno."))

	# la pioggia con Mochi fuori: qualcuno la raggiunge sotto l'acqua
	if raining:
		var cell := Vector2i(roundi(_player.global_position.x),
				roundi(_player.global_position.z))
		var al_coperto: bool = _build != null and bool(_build.call("has_cover", cell))
		if not al_coperto and not _pioggia_fatta \
				and int(_empatia_giorno.get("pioggia", -1)) != oggi:
			_pioggia_acc += delta
			if _pioggia_acc >= 25.0:
				_pioggia_fatta = conforta_mochi("pioggia")
				if _pioggia_fatta:
					_empatia_giorno["pioggia"] = oggi
		elif al_coperto:
			_pioggia_acc = 0.0
	else:
		_pioggia_acc = 0.0
		_pioggia_fatta = false


## Un amico si accorge di Mochi e viene a starle vicino (Fasi 4 e 6:
## lutto, fame, pioggia, ritorno). Ritorna false se nessuno può.
func conforta_mochi(motivo: String) -> bool:
	var vicino: Node3D = null
	var vicino_r := {}
	var best_d := INF   # 999 non basta: un amico viene anche da lontano
	var dorme: Node3D = null      # un amico vero si alza anche dal letto
	var dorme_r := {}
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if node.call("is_hidden"):
			dorme = node
			dorme_r = r
			continue
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			vicino = node
			vicino_r = r
	if vicino == null and dorme != null:
		dorme.call("resident_wake")
		vicino = dorme
		vicino_r = dorme_r
	if vicino == null:
		return false
	var label := str(vicino_r.get("label", ""))
	vicino_r["next_act"] = 30.0
	var fianco: Vector3 = _player.global_position + Vector3(randf_range(-0.8, 0.8), 0, 0.9)
	vicino.call("do_routine", "sniff", fianco, _player.global_position)
	# le parole giuste per ogni premura (nel lutto: quasi niente — si siede
	# accanto e basta, è il capolavoro dell'empatia)
	var parole: Array = ["felice", "amico"]
	var umore := "felice"
	var cuore := true
	match motivo:
		"lutto":
			parole = ["amico", "~"]
			umore = "triste"
			cuore = false
			_show_toast(L10n.tf("%s viene a sederti accanto. Non dice niente.", [label]))
		"pioggia":
			parole = ["pioggia", "amico"]
			umore = "neutro"
			_show_toast(L10n.tf("%s ti ha raggiunta sotto la pioggia, per non lasciarti sola.", [label]))
	# e le dice sottovoce, quando è arrivato accanto a lei
	var conforto := vicino
	get_tree().create_timer(2.6).timeout.connect(func():
		if not is_instance_valid(conforto):
			return
		conforto.call("face_towards", _player.global_position)
		conforto.call("speak", parole, umore)
		if cuore:
			conforto.call("_spawn_heart")
		else:
			conforto.call("chat_bubble", "…"))
	return true


# ============================================ il confronto e il morso
# Le soglie si interrogano PER NOME (ANIMO.almeno): prima erano due indici
# scritti a mano, 5 e 6, e bastava inserire un gradino in mezzo alla scala
# perché puntassero al gradino sbagliato senza un errore.

# CHI HA QUALCOSA DA DIRTI TE LO VIENE A DIRE.
#
# È il momento che il giocatore ricorderà: non un contatore che sale in un
# menù, ma qualcuno che attraversa il prato, ti si pianta davanti e ti
# rinfaccia FATTI PRECISI — quante volte, e cosa aveva sognato di fare.
# Chi sta più in basso sulla scala invece si morde la lingua: e siccome
# mordersi la lingua COSTA (Limbico.trattieni), prima o poi qualcosa esce
# lo stesso, di sbieco. È così che si scoppia «per una sciocchezza».
func _tick_confronti(delta: float) -> void:
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	for r in _residents:
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var animo: RefCounted = _animi[label]
		var d: float = pp.distance_to(node.global_position)

		if ANIMO.almeno(int(animo.gradino), "confronto"):
			# ti viene incontro: si ferma poco distante, non addosso
			var attesa: float = float(_in_confronto.get(label, 0.0)) - delta
			if d > 2.2:
				if attesa <= 0.0 and node.has_method("do_routine"):
					var verso: Vector3 = pp + (node.global_position - pp).normalized() * 1.6
					node.call("do_routine", "confronto", verso, pp)
					_in_confronto[label] = 4.0
				else:
					_in_confronto[label] = attesa
				continue
			# è arrivato: lo sfogo, una volta sola finché non cambia qualcosa
			if bool(r.get("sfogato", false)):
				continue
			r["sfogato"] = true
			if node.has_method("face_towards"):
				node.call("face_towards", pp)   # ti guarda in faccia
			_show_toast("%s: %s" % [label, animo.sfogo()])
			if node.has_method("chat_bubble"):
				node.call("chat_bubble", "!")
			node.set_meta("postura", "petto_in_fuori")
			continue

		# sotto il confronto: si trattiene. Ma la forza per farlo è finita.
		if d < 2.6 and ANIMO.almeno(int(animo.gradino), "svogliato"):
			var cd: float = float(_sussulto_cd.get("morso_" + label, 0.0)) - delta
			if cd > 0.0:
				_sussulto_cd["morso_" + label] = cd
				continue
			_sussulto_cd["morso_" + label] = 12.0
			if not animo.limbico.trattieni():
				# non ce l'ha fatta: qualcosa esce, di sbieco
				_show_toast(L10n.tf("%s: «…niente. Lascia stare.»", [label]))
				if node.has_method("chat_bubble"):
					node.call("chat_bubble", "…")
				node.set_meta("postura", "spalle_basse")
			else:
				# ⚠️ **E CE L'HA FATTA — cioè il caso COMUNE, che finora non
				# aveva nessun corpo.** Questo ramo non esisteva: il gioco
				# reagiva solo al morso FALLITO, quindi «mordersi la lingua»
				# si vedeva soltanto quando smetteva di funzionare. La
				# rinuncia riuscita è il gesto più silenzioso che una persona
				# faccia, e adesso si vede: il corpo si raccoglie, si tira
				# indietro di tre centimetri, e ne esce piano.
				#
				# L'ANCORA È MOCHI, e sta a meno di 2,6 metri per costruzione
				# (la condizione di questo ramo): non c'è niente da
				# verificare, e non c'è modo di non ricondurlo a sé.
				chiedi_gesto(label, "si_e_trattenuto")


# LA STRADA VELOCE, ADDOSSO AL RESIDENTE. Quando Mochi arriva, il corpo del
# residente reagisce PRIMA che la testa abbia valutato qualcosa: chi ti teme
# trasalisce, chi ti vuole bene si illumina. È il segnale più onesto che il
# giocatore riceve — e arriva senza che nessuno debba parlargli.
## Quanto \u00e8 GREZZO il modo in cui il giocatore sta arrivando, 0..1.
##
## La strada veloce non guarda chi arriva: guarda COME. Una cosa che si
## muove svelta, nel buio, addosso \u2014 e il corpo parte prima della testa.
## PURA e statica: si prova headless invece che correndo nel buio a
## sperare (tests/cases/test_due_strade.gd).
##  velocita: m/s del giocatore \u00b7 buio: 0 giorno pieno, 1 notte piena
##  vicino: 0..1, quanto \u00e8 gi\u00e0 addosso (1 = a un passo)
static func indizio_grezzo(velocita: float, buio: float, vicino: float) -> float:
	# sotto la camminata tranquilla non c'\u00e8 nulla di brusco, di giorno
	var svelto := clampf((velocita - 1.6) / 3.4, 0.0, 1.0)
	# il buio non spaventa da solo: RADDOPPIA quello che non si vede bene
	return clampf(svelto * (0.45 + 0.75 * buio) * (0.55 + 0.45 * vicino), 0.0, 1.0)


func _tick_sussulti(delta: float) -> void:
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	# la velocit\u00e0 vera del giocatore, dal suo spostamento fra due tick
	var vel := 0.0
	if _pp_prec != Vector3.ZERO and delta > 0.0001:
		vel = (pp - _pp_prec).length() / delta
	_pp_prec = pp
	# il buio lo dice DayNight, che ha gi\u00e0 la sua nozione di notte: una
	# soglia sull'ora scritta qui sarebbe una seconda verit\u00e0 da mantenere
	var buio := 0.0
	if _daynight != null and _daynight.is_night():
		buio = 1.0
	_tick_riconoscimenti(delta)
	for r in _residents:
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		var cd: float = float(_sussulto_cd.get(label, 0.0)) - delta
		if cd > 0.0:
			_sussulto_cd[label] = cd
			continue
		var node := r.get("node") as Node3D
		if node == null:
			continue
		var d: float = pp.distance_to(node.global_position)
		if d > 3.2:
			continue
		var animo: RefCounted = _animi[label]
		var grezzo := indizio_grezzo(vel, buio, clampf(1.0 - d / 3.2, 0.0, 1.0))
		var s: Dictionary = animo.limbico.percepisci("giocatore", "", grezzo)
		_sussulto_cd[label] = 9.0
		match str(s.get("reazione", "nulla")):
			"trasalisce":
				node.set_meta("postura", "trasalisce")
				if node.has_method("chat_bubble"):
					node.call("chat_bubble", "!")
				# LA CODA E IL RALLENTANDO. `Limbico` promette da sempre che
				# l'attivazione somatica «è lentezza fisica, non
				# testardaggine», e non l'aveva mai mantenuta: `arousal`
				# aveva due lettori, ed erano una stringa e la voce. Adesso
				# resta nel CORPO — le spalle un filo più chiuse, lo sguardo
				# che scansiona, il passo che cala — per qualche secondo dopo
				# che la testa ha già capito.
				#
				# ⚠️ **E STA DENTRO QUESTO RAMO, non prima del `match`.**
				# La coda è la faccia della PAURA: orecchie giù, braccia
				# chiuse, coda irrigidita, corpo rimpicciolito, passo al 72%.
				# Accesa un gradino più su si posava su tutte e tre le
				# risposte — e siccome la gioia è dodici volte più frequente
				# della paura (MISURATO nel villaggio vero, otto minuti con
				# ventotto residenti: 48 «si illumina» contro 4
				# «trasalisce»), il livello «guardingo» stava addosso a chi
				# ti vuole bene molto più che a chi ti teme. Nell'istante del
				# cuoricino le orecchie andavano GIÙ 17 volte su 21; il
				# rallentando restava acceso il 41,6% dei secondi in cui
				# Mochi era vicina a qualcuno; e si accendeva perfino sui
				# percetti che non producevano NESSUNA reazione (91 volte su
				# 129) — cioè il livello monotono, che è il guasto che la
				# regola dei livelli vieta.
				#
				# La seconda guardia è nel `Limbico` e sta a monte: `forza` è
				# l'ALLARME, e una gioia ne ha zero. Sono indipendenti
				# apposta.
				#
				# ⚠️ E NON PRENDE IL GETTONE: è un livello, non un evento.
				# Passa da qui e non da `chiedi_frase` apposta — un sussulto
				# è una reazione, e una reazione non aspetta il suo turno.
				if node.has_method("somatico"):
					node.call("somatico", float(s.get("forza", 0.0)))
				# \u2026e QUI comincia la strada lenta: fra poco la testa capir\u00e0
				_riconoscimenti[label] = ATTESA_RICONOSCIMENTO
			"si_illumina":
				node.set_meta("postura", "si_illumina")
				if node.has_method("chat_bubble"):
					node.call("chat_bubble", "\u2665")


## Quanto passa fra il sussulto del corpo e il capire della testa. Non \u00e8 un
## numero arbitrario: \u00e8 l'ordine di grandezza vero fra la via sottocorticale
## e quella corticale, e sullo schermo \u00e8 il tempo minimo perch\u00e9 l'occhio
## legga DUE cose invece di una.
const ATTESA_RICONOSCIMENTO := 0.4


## LA STRADA LENTA. Un istante dopo il sussulto la testa valuta davvero chi
## \u00e8 arrivato \u2014 e se \u00e8 qualcuno di caro, il corpo si scioglie: \u00abah\u2026 sei tu\u00bb.
## \u00c8 la seconda met\u00e0 della meccanica pi\u00f9 bella del progetto, e prima non
## c'era: il vicino trasaliva e restava cos\u00ec.
func _tick_riconoscimenti(delta: float) -> void:
	if _riconoscimenti.is_empty():
		return
	for label in _riconoscimenti.keys():
		var t: float = float(_riconoscimenti[label]) - delta
		if t > 0.0:
			_riconoscimenti[label] = t
			continue
		_riconoscimenti.erase(label)
		if not _animi.has(label):
			continue
		var node := node_di(label)
		if node == null or not is_instance_valid(node):
			continue
		var animo: RefCounted = _animi[label]
		# quanto vale, per lui, che sia proprio TU: l'amicizia vera
		var amicizia := 0
		for r in _residents:
			if str(r.get("label", "")) == label:
				amicizia = int(r.get("friend", 0))
				break
		var valenza := 0.55 if amicizia >= 3 else (0.3 if amicizia > 0 else 0.05)
		var esito: Dictionary = animo.limbico.rivaluta("incontro", "giocatore", valenza)
		if float(esito.get("sentito", 0.0)) > 0.0:
			# il sollievo: il corpo si scioglie e lo dice
			node.set_meta("postura", "si_illumina")
			if node.has_method("speak"):
				node.call("speak", ["ciao", "amico"], "felice")
			if node.has_method("chat_bubble"):
				node.call("chat_bubble", "\u2665")
			_spiega_le_strade(label)
			# \u2026E IL CORPO SI SCIOGLIE DAVVERO. `si_illumina` \u00e8 una posa: le
			# orecchie su, le braccia su, il mento su, e per un secondo e
			# otto decimi resta l\u00ec. Quello che mancava \u00e8 il MOVIMENTO \u2014
			# quattro centimetri di corpo che sale a mezzo metro al secondo,
			# che \u00e8 il canale pi\u00f9 direzionale del rig e l'unico che dice
			# \u00absollievo\u00bb invece di \u00abattenzione\u00bb.
			#
			# \u26a0\ufe0f **\u00c8 IL RIALZO, CHE NON SI RECITA DA SOLO \u2014 e qui non lo fa.**
			# Il buio prima c'\u00e8, e non lo mette la tabella delle frasi: \u00e8 il
			# SUSSULTO di quattro decimi di secondo fa, che ha irrigidito
			# questo stesso corpo. `Visitor.frase("sollievo")` lo verifica
			# sul corpo (`_sussulto_fresco`) e si rifiuta se non \u00e8 vero:
			# nessun altro chiamante pu\u00f2 prendersi quel gesto barando.
			#
			# \u00c8 l'occasione pi\u00f9 attribuibile che questo gioco abbia \u2014 il
			# giocatore \u00e8 a meno di 3,2 metri, ha appena fatto saltare
			# qualcuno, e un istante dopo quello lo riconosce \u2014 e in
			# `Regia.OCCASIONI` \u00e8 infatti quella che aspetta meno di tutte.
			chiedi_gesto(label, "ah_sei_tu")
		else:
			# non si scioglie: di te, per ora, non \u00e8 ancora convinto
			node.set_meta("postura", "esita")
			if node.has_method("chat_bubble"):
				node.call("chat_bubble", "\u2026")


## La prima volta che succede \u2014 e SOLO la prima \u2014 il gioco dice al giocatore
## cosa ha appena visto. Una volta: se lo ripetesse a ogni sussulto
## diventerebbe una lezione, e la scena si spiega gi\u00e0 da s\u00e9.
func _spiega_le_strade(label: String) -> void:
	if _spiegato_le_strade:
		return
	_spiegato_le_strade = true
	_show_toast(L10n.tf("%s ha fatto un salto, poi ti ha riconosciuto: «ah… sei tu».",
			[label]))


# ============================================ l'animo e il villaggio

# Iscrive un residente al grafo del villaggio e lo lega a chi già conosce,
# usando l'affinità che il cervello tiene da sempre: le voci corrono lungo
# le amicizie vere, non lungo un grafo inventato per l'occasione.
func _iscrivi_al_villaggio(key: String, animo: RefCounted) -> void:
	if _villaggio == null:
		_villaggio = VILLAGGIO.new()
		# reinietta la memoria dei partiti dal salvataggio: la cronaca
		# della rivolta ricorda il primo focolaio anche dopo un riavvio
		if not _partiti_salvati.is_empty():
			_villaggio.partiti = _partiti_salvati.duplicate(true)
	_villaggio.aggiungi(animo)
	var brain: RefCounted = _brains.get(key)
	for altro in _animi:
		if altro == key:
			continue
		var forza := 0.45
		if brain and brain.affinita.has(altro):
			forza = clampf(0.25 + float(brain.affinita[altro]) * 0.12, 0.0, 1.0)
		_villaggio.lega(key, altro, forza)


## Dove si svolge ogni lavoro. Serve perché il rancore non resti astratto: chi
## viene mandato novanta giorni alla catasta finisce per non sopportare più
## LA CATASTA, e gira al largo anche quando è libero. È il condizionamento
## del limbico (Limbico.marchi) applicato alla geografia del villaggio.
const LUOGO_DEL_LAVORO := {
	"taglia_legna": "catasta", "coltiva": "orto", "cucina": "cucina",
	"guardia": "confine", "esplora": "bosco",
}

## E dove si svolgono le ATTIVITÀ LIBERE che sceglie il cervello. Sono due
## vocabolari diversi — il giocatore ordina «coltiva», il cervello sceglie
## «cura_giardino» — e il ponte fra i due è il LUOGO: chi è stato costretto
## all'orto per novanta giorni non ci va più nemmeno di sua volontà.
## (Il filtro prima leggeva le chiavi dei lavori su nomi di attività: non
## poteva scattare mai. È il tipo di silenzio che non dà errori e non fa
## niente — il peggiore.)
const LUOGO_ATTIVITA := {
	"cura_giardino": "orto", "spuntino": "cucina", "meraviglia": "bosco",
}
## Dove si mangia, in pezzi del catalogo. Fonte unica: la usano `_recita`
## (per mandarci chi ha fame) e `_luogo_posizione` (per sapere dove guardare
## quando quel posto è diventato insopportabile). Erano la stessa lista
## scritta due volte, ed è così che due sistemi cominciano a raccontare due
## villaggi diversi.
const PEZZI_CIBO := ["Cespuglio", "Fungo", "Orto"]
## Dove ripiega chi cambia idea: deve essere un'attività che _recita CONOSCE,
## o il ripiego cadrebbe nel vuoto e il residente resterebbe immobile.
const RIPIEGO := "quattro_chiacchiere"

## Un compito assegnato dal giocatore passa di qui: è il canale che porta al
## risentimento. Chi sognava altro lo vive tre volte più amaro di chi quel
## lavoro lo amava — ed è per questo che due residenti mandati allo stesso
## posto finiscono in due punti diversi della scala.
func assegna_compito(label: String, compito: String) -> void:
	if not _animi.has(label):
		return
	var animo: RefCounted = _animi[label]
	animo.esegue(compito, "giocatore")
	# e il POSTO si carica di com'è andata: dopo abbastanza volte, quel posto
	# diventa qualcosa da evitare — senza che nessuno lo scriva
	var luogo := str(LUOGO_DEL_LAVORO.get(compito, ""))
	if luogo != "" and not animo.ricordi.is_empty():
		var ultimo: Dictionary = animo.ricordi[animo.ricordi.size() - 1]
		var sentito: float = float(ultimo.get("valenza", 0.0))
		if absf(sentito) > 0.25:
			animo.limbico._marchia("luogo|" + luogo, sentito)


## Un gesto bello verso un residente: i regali e le attenzioni SCIOLGONO il
## rancore. Senza questa porta il sistema sarebbe una condanna, non un
## dialogo — e il giocatore non avrebbe modo di rimediare.
func gesto_gentile(label: String, tipo := "regalo", peso := 0.8) -> void:
	if not _animi.has(label):
		return
	(_animi[label] as RefCounted).ricorda(tipo, "giocatore", peso, 0.9)
	# rimediare RIAPRE il discorso: se scende di gradino tornerà a cercarti
	# solo se glielo dai di nuovo il motivo
	for r in _residents:
		if str(r.get("label", "")) == label:
			r["sfogato"] = false
			return


## Il lutto di un residente: se nessuno lo consola, il rancore va a chi
## comanda il villaggio. È l'indifferenza a ferire, non la perdita.
func lutto_di(label: String, amico: String, consolato_da := "") -> void:
	if _animi.has(label):
		(_animi[label] as RefCounted).lutto(amico, consolato_da)


## LA FUNZIONE DELLA LEGGIBILITÀ: perché quel residente si comporta così.
## È ciò che il giocatore legge parlando con lui, ed è la differenza fra
## «questo gioco è profondo» e «questo gioco ha un bug».
func perche(label: String) -> String:
	if not _animi.has(label):
		return ""
	return (_animi[label] as RefCounted).racconta()


## Come sta il CORPO di un residente (guardingo, di malumore, a corto di
## pazienza…): è la riga che spiega una reazione sproporzionata.
func corpo_di(label: String) -> String:
	if not _animi.has(label):
		return ""
	return str((_animi[label] as RefCounted).limbico.stato_corpo())


## IL PERCHÉ, SU RICHIESTA — la seconda metà delle due strade. Il registro
## (tasto N) mostra già `corpo_di`/`perche` per chi apri a tavolino; qui è
## lo stesso perché ma chiesto NEL MONDO, salutando (T) chi è ancora scosso.
##
## Le due funzioni sotto sono PURE apposta: la decisione (c'è qualcosa da
## dire?) e la composizione (corpo + il posto preciso, se c'è) si provano
## headless senza toccare un Visitors vero — `_show_toast` presuppone la UI
## costruita da `_build_ui()`, e chiamarla su un nodo appena creato con
## `.new()` (senza `_ready`) manderebbe in crash qualunque test.

## Il corpo ha qualcosa da dire, salutando? [param corpo] è la stringa RAW
## di `stato_corpo()` — MAI tradotta qui: si traduce solo al momento di
## mostrare, come ovunque in questo progetto. "tranquillo" (e tutto il
## resto) non merita una nuvoletta: solo chi ha ancora il corpo scosso.
static func corpo_ha_da_dire(corpo: String) -> bool:
	return corpo == "col cuore in gola" or corpo == "ancora guardingo"


## Compone corpo + il posto preciso in UNA frase — «gli è successo
## qualcosa di brutto lì (3 volte)» — o lascia il corpo da solo se lo
## spavento non ha un indirizzo (un sussulto addosso a Mochi, non un
## marchio su un luogo). Entrambi gli argomenti arrivano GIÀ tradotti.
static func spiegazione_del_corpo(corpo: String, perche: String) -> String:
	return corpo if perche == "" else "%s — %s" % [corpo, perche]


## Se il vicino è ancora scosso, glielo si vede in faccia PRIMA di dirlo:
## niente cuoricino festoso finto, una nuvoletta di puntini e poi la
## spiegazione vera. Ritorna true se ha parlato (così _saluta() sa di non
## dover fare anche il saluto felice sopra).
func _spiega_come_sta(label: String, node: Node3D) -> bool:
	if not _animi.has(label) or node == null or not is_instance_valid(node):
		return false
	var animo: RefCounted = _animi[label]
	var corpo := str(animo.limbico.stato_corpo())
	if not corpo_ha_da_dire(corpo):
		return false
	var perche := ""
	for l in luoghi_evitati(label):
		var d: Dictionary = animo.limbico.perche_evita_dati(str(l))
		if not d.is_empty():
			perche = L10n.tf(str(d["testo"]), [int(d["n"])])
			break
	if node.has_method("chat_bubble"):
		node.call("chat_bubble", "…")
	if node.has_method("speak"):
		node.call("speak", ["aspetta"], "neutro")
	_show_toast("%s: %s." % [label, spiegazione_del_corpo(L10n.t(corpo), perche)])
	return true


## Il diario di un residente: la STORIA dei suoi scatti, giorno per giorno.
func diario_di(label: String) -> Array:
	if not _animi.has(label):
		return []
	return (_animi[label] as RefCounted).diario()


## Lo stato d'animo attuale (il gradino della scala), per la UI e i test.
func animo_di(label: String) -> String:
	if not _animi.has(label):
		return ""
	return (_animi[label] as RefCounted).stato()


## GLI HAI SCRITTO. La lettera è nella cassetta e lui l'ha letta: se è in
## giro corre a ringraziarti col corpo (la sua indole decide come), e
## l'animo se lo ricorda — è un dono, non un ordine.
func grazie_per_la_lettera(nome: String) -> void:
	for r in _residents:
		var dna: Dictionary = r.get("dna", {})
		if str(dna.get("name", "")) != nome:
			continue
		var label := str(r.get("label", ""))
		_bump_friend(r, 1)
		if _animi.has(label):
			(_animi[label] as RefCounted).ricorda("regalo", "giocatore", 0.7, 0.8)
		var node := r.get("node") as Node3D
		if node != null and is_instance_valid(node):
			if node.has_method("celebrate"):
				node.call("celebrate")
			if node.has_method("speak"):
				node.call("speak", ["grazie", "ricordo"], "felice")
		_show_toast(L10n.tf("%s ha trovato la tua lettera.", [label]))
		return


## L'ANIMO in persona, non il suo riassunto: serve a chi deve farlo
## DECIDERE (le giornate libere del registro dei lavori). Gli altri
## chiamanti si accontentino di `animo_di`/`sogno_di`: qui si passa un
## oggetto vivo, e chi lo tocca ne è responsabile.
func animo_oggetto_di(label: String) -> RefCounted:
	return _animi.get(label)


## ------------------------------------------------- i canali della VEGLIA
## Tre porte sull'animo di un residente, aperte per la notte vegliata
## (scenes/npc/Veglia.gd). Stanno qui perché `_animi` è indicizzato per
## LABEL e nessuno da fuori deve conoscerne la forma.

## Muove un drive di un residente. `pavimento` è il fondo sotto cui non si
## scende: serve al buio della notte, che deve pesare un poco ma non
## portare MAI qualcuno alla ribellione da solo.
func dona_drive(label: String, drive: String, quanto: float,
		pavimento := 0.0) -> void:
	if not _animi.has(label):
		return
	var animo: RefCounted = _animi[label]
	var d: Dictionary = animo.get("drive")
	if not d.has(drive):
		return
	d[drive] = clampf(float(d[drive]) + quanto, pavimento, 1.0)


## Un ricordo buono (o cattivo) intestato a un ALTRO residente, non al
## giocatore: in Animo i ricordi buoni scontano i cattivi, e col nome
## sbagliato una notte di veglia comprerebbe il perdono del villaggio.
func ricorda_per(label: String, tipo: String, attore: String,
		valenza: float) -> void:
	if not _animi.has(label):
		return
	(_animi[label] as RefCounted).ricorda(tipo, attore, valenza, 0.6)


## Il legame fra due vicini si stringe (grafo del passaparola + Animo).
## `forza_inversa` negativa = simmetrico (come Villaggio.lega); la Voce la
## usa per non SCHIACCIARE il lato di chi già amava quando l'altro impara.
func lega_vicini(chi: String, verso: String, forza: float,
		forza_inversa := -1.0) -> void:
	if _villaggio and _villaggio.has_method("lega"):
		_villaggio.call("lega", chi, verso, forza, forza_inversa)


## ------------------------------------------------- i canali della VOCE
## (scenes/npc/Voce.gd): il grafo delle amicizie letto da fuori, senza
## esporne la forma. Solo lettura: per scrivere c'è `lega_vicini`.

## Le etichette di tutti i residenti vivi, nell'ordine di arrivo.
func etichette() -> Array:
	var out: Array = []
	for r in _residents:
		var l := str(r.get("label", ""))
		if l != "":
			out.append(l)
	return out


## Il lato di `label` nel grafo del passaparola: {altro: quanto ci tiene}.
## Una COPIA: il grafo vero lo scrive solo il Villaggio.
func amici_di(label: String) -> Dictionary:
	if _villaggio == null:
		return {}
	var amicizie: Dictionary = _villaggio.get("amicizie")
	if not amicizie.has(label):
		return {}
	return (amicizie[label] as Dictionary).duplicate()


## Il sogno di un residente ("boscaiolo", "cuoco"…). Serve al registro dei
## lavori per la resa: chi fa il lavoro che sognava produce di più.
func sogno_di(label: String) -> String:
	if not _animi.has(label):
		return ""
	return str((_animi[label] as RefCounted).sogno)


## La cronaca della rivolta, se ce n'è una: chi ha cominciato e perché.
func cronaca_villaggio() -> Array:
	if _villaggio == null:
		return ["Il villaggio è sereno."]
	return _villaggio.cronaca_rivolta()


# Un giorno di vita interiore: ognuno fa i conti con sé stesso, poi le voci
# girano. Chi scatta di gradino lo TELEGRAFA subito — postura e battuta —
# perché il giocatore possa accorgersene e correggere in tempo.
func _giorno_di_animo() -> void:
	if _villaggio == null:
		return
	for evento in _villaggio.simula_giorno():
		if str(evento.get("tipo", "")) != "scatto":
			continue
		var chi := str(evento["chi"])
		var animo: RefCounted = _animi.get(chi)
		if animo == null:
			continue
		var tel: Array = animo.telegrafo()
		_mostra_telegrafo(chi, tel)
		# solo i passaggi che contano finiscono nei toast: se avvisassimo a
		# ogni mugugno, il giocatore smetterebbe di leggere
		if ANIMO.almeno(int(animo.gradino), "rifiuto"):
			_show_toast("%s: «%s»" % [chi, L10n.t(str(tel[1]))])


# La postura e la battuta del gradino, addosso al residente.
func _mostra_telegrafo(label: String, tel: Array) -> void:
	for r in _residents:
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node == null:
			return
		node.set_meta("postura", str(tel[0]))
		if node.has_method("chat_bubble"):
			node.call("chat_bubble", "!")
		return


# ------------------------------------------------------- le stravaganze

# rare, innocue, indimenticabili: il tocco che rende ognuno SUO
func _quirk_tick(r: Dictionary, node: Node3D, brain: RefCounted, delta: float, t_ora: float) -> void:
	r["quirk_cd"] = float(r.get("quirk_cd", randf_range(20.0, 40.0))) - delta
	if float(r["quirk_cd"]) > 0.0:
		return
	r["quirk_cd"] = randf_range(45.0, 90.0)
	if str(node.get("_state")) not in ["r_idle", "r_wander", "r_sniff"]:
		return
	match str(brain.get("quirk")):
		"parla_ai_funghi":
			var fungo := _nearest_named(["Fungo"], node.global_position, 10.0)
			if fungo:
				node.call("do_task", "chat_fungo",
						fungo.global_position + Vector3(0.5, 0, 0.4), Callable())
				_vita_toast("fungo", L10n.tf("%s sta confidando un segreto a un fungo…", [r["label"]]))
		"paura_farfalle":
			if _cozy and int(_cozy.call("nearest_butterfly", node.global_position, 1.6)) >= 0:
				node.call("do_task", "startle", Vector3.ZERO, Callable())
				_vita_toast("farfalla", L10n.tf("Una farfalla ha spaventato %s!", [r["label"]]))
		"canta_alla_luna":
			if t_ora >= 0.78 and t_ora < 0.95:
				node.call("do_task", "sing", Vector3.ZERO, Callable())
				_vita_toast("canto", L10n.tf("♪ %s sta cantando alla luna.", [r["label"]]))
		"colleziona_sassolini":
			# la mania che diventa un dono: chi colleziona sassolini, quando
			# ne trova uno DAVVERO piatto e tu sei lì vicino, te lo porta —
			# ed e' la munizione del Rimbalzello sulla riva dello stagno.
			# L'indole esisteva da sempre e faceva una cosa carina che non
			# serviva a niente: adesso e' l'inizio di un gioco.
			node.call("do_task", "sasso", Vector3.ZERO,
					func() -> void: _dona_sasso(r, node))
		"ballerino":
			node.call("do_task", "twirl", Vector3.ZERO, Callable())
		"pisolini_ovunque":
			if randf() < 0.4:
				node.call("do_task", "nap", Vector3.ZERO,
						func(): brain.satisfy("pisolino"))


# ------------------------------------------------- il canale della vita
#
# Quello che i vicini combinano, detto al giocatore in una riga sola. È
# l'unico canale del gioco che parla senza essere stato interrogato, e per
# questo ha due lucchetti invece di uno.

## IL RITMO: quanto tace il canale dopo aver detto QUALUNQUE cosa.
## Un solo racconto di vita ogni tanto — la quiete è il prodotto.
const QUIETE := 25.0

## Il ripiego per la memoria del canale dove non c'è nessun DayNight (i
## banchi di prova, il prologo, il diorama): la giornata di fabbrica.
const GIORNO_DI_RIPIEGO := 240.0

## LA MEMORIA DEL CANALE: la stessa notizia non si ripete prima che sia
## passata una GIORNATA intera (`DayNight.cycle_seconds`, letto di là e mai
## ricopiato — è la stessa fonte da cui il cuore deriva le mezze vite dei
## ricordi). È una finestra che scorre, non il calendario: nessuno scalino a
## mezzanotte, e la garanzia è esattamente «al più una volta al giorno».
##
## ⚠️ QUESTO LUCCHETTO È NATO DA UNA CONSEGUENZA DELLA FASE 4 CHE NESSUNO
## AVEVA PREVISTO, e che non aggiunge una riga di testo nuova — quindi né la
## guardia della localizzazione né i test delle emozioni potevano vederla.
## Chi ti ha vista annaffiare ha più voglia di annaffiare (il modulatore di
## `cura_giardino` sale a 1.4278 misurato), quindi lo fa più spesso, quindi
## il villaggio te lo SCRIVE IN FACCIA più spesso. Misurato nel MainLevel
## vero (`tools/prova_toast.gd`: quattro vicini, sei aiuole tenute assetate,
## due fasi da 900 s con gli stessi corpi e gli stessi bisogni di partenza,
## e fra le due cambia SOLO il modulatore):
##
##   il GESTO    annaffiature vere    27 → 38   (+41%)
##   l'OFFERTA   notizie proposte     23 → 40   (+74%)
##   il FEED     toast letti          17 → 21   (col canale di allora)
##
## Ventun volte «♥ X sta annaffiando le tue aiuole!» in un quarto d'ora, una
## ogni quarantacinque secondi, sempre la stessa frase col nome cambiato:
## fai il gesto gentile, e il gioco comincia a mandarti notifiche. È «il
## villaggio non commenta MAI» violato da una porta di servizio.
##
## LA CURA STA NEL CANALE, NON NEL MODULATORE, ed è una decisione: che i
## vicini annaffino di più è la Fase 4 che funziona — la scena 4 è tornare
## all'orto e TROVARCI il proprio gesto fatto da un altro. Un toast che te
## lo annuncia è la cosa che quella scena non voleva: toglie la scoperta.
## Perciò il gesto resta com'è (misurato dopo la cura: sempre 27 → 38) e
## cambia solo quanto se ne parla — **3 → 3**.
##
## IL NUMERO SI È SCELTO GUARDANDO I CINQUE FEED, non a occhio. Lo stesso
## quarto d'ora caldo, rigiocato attraverso questo predicato a cinque
## tarature (`prova_toast.gd` lo stampa; le notizie offerte non dipendono
## dal filtro, quindi il confronto è esatto):
##
##   0 s (il canale di allora)  21 toast — uno ogni 45 s: un feed
##   60 s                       11 — uno ogni 80 s, si sente ancora il ritmo
##   120 s                       7 — uno ogni due minuti, e si ripete
##   240 s (una giornata)        4 — uno ogni quattro minuti
##   480 s                       2 — la vita del villaggio sparisce
##
## Da 120 in su il freddo e il caldo pareggiano; a 240 la frase smette di
## sembrare una notifica e la vita si sente ancora, e in più è l'unico
## valore che ha una RAGIONE invece di una taratura.
##
## E il lucchetto è PER GENERE, non più stretto in generale, perché c'è un
## guasto gemello che va nella direzione opposta: con il solo lucchetto
## globale le notizie comuni si mangiavano il canale e quelle rare — il
## segreto al fungo, la farfalla, il canto alla luna, la notte sotto le
## stelle — perdevano la corsa. Si conta dal diario: a 0 s l'annaffiatura
## teneva il canale chiuso per 21·25 = 525 s su 900, cioè **il 58% del
## tempo una notizia rara sarebbe stata inghiottita**; adesso l'8%.
## Stringere il lucchetto globale avrebbe peggiorato proprio quello.
static func vita_zitta(ora: float, ultimo_qualunque: float, ultimo_genere: float,
		quiete: float, quiete_genere: float) -> bool:
	return ora - ultimo_qualunque < quiete or ora - ultimo_genere < quiete_genere


## Il diario di quello che il canale si è sentito OFFRIRE, uscito o no —
## spento in partita, lo accende `debug_registra_vita`.
##
## Non è impalcatura da banco: un canale il cui mestiere è scegliere cosa
## NON dire non si può giudicare guardando solo quello che è uscito. Due
## tarature molto diverse danno lo stesso numero di toast quando il
## lucchetto globale è saturo, e senza le notizie fermate non c'è modo di
## sapere quale delle due sta zitta sulla cosa giusta.
var debug_vita_diario: Array = []
var debug_vita_registra := false


func debug_registra_vita(acceso: bool) -> void:
	debug_vita_registra = acceso
	if acceso:
		debug_vita_diario.clear()


func _vita_toast(genere: String, testo: String) -> void:
	var quiete_genere := GIORNO_DI_RIPIEGO
	if _daynight != null and is_instance_valid(_daynight):
		quiete_genere = float(_daynight.cycle_seconds)
	var zitta := vita_zitta(_vita_orologio, _vita_ultimo_qualunque,
			float(_vita_ultimo.get(genere, -1.0e18)), QUIETE, quiete_genere)
	if debug_vita_registra:
		debug_vita_diario.append({"t": _vita_orologio, "genere": genere,
				"testo": testo, "uscita": not zitta})
	if zitta:
		return
	_vita_ultimo_qualunque = _vita_orologio
	_vita_ultimo[genere] = _vita_orologio
	_show_toast(testo)


# il piano del Regista per questo residente, o [] = routine di default
func _regia_plan(r: Dictionary, fase: String) -> Array:
	var regista := get_tree().get_first_node_in_group("regista")
	if regista == null:
		return []
	return regista.plan_for(r, fase)


func _nearest_named(names: Array, from: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_d
	# IL MURO SI GUARDA QUI, una volta per tutti. Prima di questa fase la
	# ricerca del posto più vicino non sapeva niente dei recinti: il posto
	# chiuso dentro una staccionata vinceva lo stesso perché era il più
	# vicino, e il vicino ci si incamminava dentro. Adesso un posto che non
	# si raggiunge semplicemente non è un candidato — per TUTTI i sistemi
	# che chiedono «qual è il più vicino», non solo per il pianificatore.
	var qui := Vector2i(roundi(from.x), roundi(from.z))
	for item_name in names:
		for node in _build.get_placed_by_name(item_name):
			var pos: Vector3 = (node as Node3D).global_position
			var d: float = pos.distance_to(from)
			if d >= best_d:
				continue
			if not _build.raggiungibile(qui, Vector2i(roundi(pos.x), roundi(pos.z))):
				continue
			best_d = d
			best = node
	return best


## Un posto libero dove sedersi: una Panchina, oppure uno dei tre sgabelli
## del Gazebo — che hanno il loro ancoraggio «Posto» col meta `seduta`,
## come la poltrona del salone. È così che il gazebo smette di essere una
## scenografia e diventa il posto dove i vicini vanno a prendere il tè.
## L'occupazione si controlla sul NODO (ogni sgabello è un nodo suo):
## tre vicini, tre sgabelli, nessuno in braccio a nessuno.
func _free_bench(from: Vector3) -> Node3D:
	var candidati: Array = []
	for bench in _build.get_placed_by_name("Panchina"):
		candidati.append(bench)
	for gaz in _build.get_placed_by_name("Gazebo"):
		for posto in (gaz as Node3D).find_children("Posto*", "Node3D", true, false):
			candidati.append(posto)
	# e nella serra: uno sgabello al bancone, le sedie del tavolino, la
	# panca ad anello sotto l'agrume. D'inverno e' il posto piu' bello
	# del villaggio in cui stare seduti.
	for serra in _build.get_placed_by_name("Serra"):
		for posto in (serra as Node3D).find_children("Posto*", "Node3D", true, false):
			candidati.append(posto)
	var migliore: Node3D = null
	var d_migliore := 16.0
	for c in candidati:
		var seat := c as Node3D
		var d := seat.global_position.distance_to(from)
		if d > d_migliore:
			continue
		var taken := false
		for r in _residents:
			var node := r.get("node") as Node3D
			if node and is_instance_valid(node) and node.get("_routine_aux") == seat \
					and str(node.get("_state")) in ["walk", "r_bench"]:
				taken = true
				break
		if not taken:
			migliore = seat
			d_migliore = d
	return migliore


## CHI CHIACCHIERA ADESSO, E CHI APRE BOCCA — pura, e la sola cosa di
## `_chats` che meriti di esistere da sola.
##
## ⚠️ PRIMA DELLA FASE 4 QUESTA DECISIONE NON ESISTEVA, ed è il difetto che
## questa funzione è nata per chiudere. `_chats` scandiva le coppie con due
## cicli annidati (`for i … for j in range(i + 1, …)`) e si fermava alla
## PRIMA buona, chiamando `_run_chat(a, b)` con **sempre i < j**. Finché
## l'ordine era solo coreografia (chi mostra per primo la nuvoletta) non
## voleva dire niente. Da quando `EcsMondo.racconta(a, b)` è asimmetrica
## per contratto — A parla, B ascolta — quell'ordine è SEMANTICA, e il
## posto in `_residents` decideva chi ha una voce. Due misure, nel villaggio
## vero (`tools/prova_chiacchiere.gd`):
##
##  · **il capannello** — cinque vicini addosso, una notizia a testa, 300 s:
##    86 chiacchierate, gli indici 0-3 hanno raccontato una volta ciascuno e
##    **l'indice 4 ZERO**, pur avendo chiacchierato 33 volte. In generale il
##    residente k poteva raccontare solo a k+1…N−1, e l'ULTIMO a nessuno.
##  · **il falò** — dodici vicini sull'anello vero del fuoco, dove ognuno ha
##    quattro persone a portata di voce, 600 s: 181 chiacchierate e **cinque
##    residenti su dodici non hanno aperto bocca NEMMENO UNA VOLTA** (gli
##    indici 5-9), perché la prima coppia in ordine lessicografico vinceva
##    sempre e le altre non arrivavano mai al proprio turno.
##
## E in coda a `_residents` ci finiscono, per costruzione, il vicino appena
## arrivato (`_settle`) e il cucciolo appena nato (`Nascite`): il villaggio
## aveva **un solo cronista stabile, il più anziano**, e quello che i nuovi
## ti vedevano fare non usciva mai dalla loro testa.
##
## Le due leve sono diverse e servono tutte e due — riparare il verso e
## lasciare la scelta della coppia in ordine di anagrafe vorrebbe dire che
## il cucciolo può raccontare, ma non incontra mai nessuno:
##
##  1. **LA COPPIA SI SORTEGGIA** fra tutte quelle a portata di voce, con un
##     campionamento a serbatoio: uniforme in una passata sola, senza una
##     seconda lista da allocare dentro il frame.
##  2. **CHI APRE BOCCA È IL MOMENTO, NON L'ANAGRAFE**: una monetina. Resta
##     UN tentativo di racconto per incontro — quanto se ne parla nel
##     villaggio non cambia, cambia solo che non è sempre lo stesso a
##     parlare. (Provare tutti e due i versi raddoppierebbe il passaparola,
##     e con lui le conseguenze che i vicini traggono da un ricordo altrui:
##     è una taratura sua, non una riparazione.)
##
## `coppie` sono le coppie **già ordinate** (i < j, che è l'identità della
## coppia e la chiave del suo cooldown). Torna `Vector2i(chi_parla,
## chi_ascolta)`, oppure `Vector2i(-1, -1)` se non c'è nessuno che si parli.
static func scegli_chiacchiera(coppie: Array, rng: RandomNumberGenerator) -> Vector2i:
	var scelta := Vector2i(-1, -1)
	var quante := 0
	for c in coppie:
		quante += 1
		# campionamento a serbatoio: la k-esima candidata prende il posto con
		# probabilità 1/k, e alla fine tutte hanno avuto la stessa
		if int(rng.randi() % quante) == 0:
			scelta = c as Vector2i
	if scelta.x < 0:
		return scelta
	if rng.randf() < 0.5:
		return Vector2i(scelta.y, scelta.x)
	return scelta


# due vicini si scambiano nuvolette: zero testo, tanta vita
func _chats(delta: float) -> void:
	_chat_acc -= delta
	if _chat_acc > 0.0:
		return
	_chat_acc = 3.5
	var chatty := ["r_idle", "r_wander", "r_sniff", "r_fire", "r_bench"]
	var now := Time.get_ticks_msec()
	# SI GUARDANO TUTTE, e non è uno spreco: la scansione completa la si
	# pagava già ogni volta che nessuno si parlava — cioè quasi sempre —
	# perché il ciclo si interrompeva solo QUANDO trovava una coppia. Quello
	# che si paga in più è una tacca su ventiquattro.
	# MISURATO nel caso peggiore che esista (ventotto residenti tutti
	# attorno al falò, dove la prova a buon mercato non scarta più niente,
	# `tools/prova_chiacchiere.gd` sezione 3): **771 µs a scatto, e uno
	# scatto ogni 3,5 s = 0,22 ms al secondo.**
	# La DISTANZA sta per prima perché è la prova che ne scarta di più, e le
	# due chiamate a `is_hidden` (le sole vere chiamate di metodo) per
	# ultime, così quasi nessuna coppia ci arriva.
	var coppie: Array[Vector2i] = []
	for i in _residents.size():
		for j in range(i + 1, _residents.size()):
			var a := _residents[i].get("node") as Node3D
			var b := _residents[j].get("node") as Node3D
			if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
				continue
			if a.global_position.distance_to(b.global_position) > 1.9:
				continue
			if str(a.get("_state")) not in chatty or str(b.get("_state")) not in chatty:
				continue
			if a.call("is_hidden") or b.call("is_hidden"):
				continue
			# LE CRICCHE PRENDONO NOTA QUI, e PRIMA del raffreddamento: i 35
			# secondi sono della chiacchierata, non della co-presenza. Due
			# vicini che passano un pomeriggio nello stesso angolo si sono
			# trovati anche se hanno chiacchierato una volta sola.
			_segna_incontro(i, j, a, b)
			# la chiave del cooldown è la COPPIA (i < j), e resta tale: sono
			# due persone che si sono appena viste, non un verso
			if now - int(_pair_cd.get("%d_%d" % [i, j], -99999)) < 35000:
				continue
			coppie.append(Vector2i(i, j))
	var scelta := scegli_chiacchiera(coppie, _chat_rng)
	if scelta.x < 0:
		return
	_pair_cd["%d_%d" % [mini(scelta.x, scelta.y), maxi(scelta.x, scelta.y)]] = now
	_run_chat(_residents[scelta.x].get("node") as Node3D,
			_residents[scelta.y].get("node") as Node3D)


## SI CONTA SOLO DOVE SI VA DA SÉ — i quattro cancelli del campionamento
## delle cricche, e stanno qui perché questo è l'unico posto che sa che ora
## è al villaggio e chi è in mezzo a una scena.
##
## ⚠️ **IL FALÒ NON REGISTRA NIENTE, ed è il cancello che regge tutto il
## resto.** La sera `_posto_al_falo(i)` mette i vicini a 0,92 m (i±1) e
## 1,78 m (i±2), tutti dentro gli 1,9 m di questa scansione: ne uscirebbero
## cinquanta coppie a sera, sempre le stesse, con l'ora concentratissima e
## il posto fisso. Sarebbero clique PER COSTRUZIONE (i, i+1, i+2) e
## passerebbero ogni collaudo — solo che la loro forma non è un'abitudine:
## è `_posto_al_falo(i)`, cioè **l'ordine in cui la gente ha traslocato**.
## Al falò la vicinanza non la sceglie nessuno. Resta il posto dove una
## cricca si VEDE, mai quello dove si CONTA.
##
## Gli altri tre valgono la stessa cosa da tre parti: chi è in mezzo a una
## scena (Concerto, Congedo, Nascondino, Concertino, Nascite) e chi ha un
## lease lungo — cioè chi è stato MESSO lì da un sistema — non ci è andato
## da sé, e il suo stare vicino a qualcuno non è una notizia su di lui.
func _segna_incontro(i: int, j: int, a: Node3D, b: Node3D) -> void:
	if _cricche == null or not is_instance_valid(_cricche):
		_cricche = get_tree().get_first_node_in_group("cricche")
		if _cricche == null:
			return
	if _phase() == "fire":
		return
	if str(a.get("_state")) == "r_fire" or str(b.get("_state")) == "r_fire":
		return
	if bool(a.call("in_scena")) or bool(b.call("in_scena")):
		return
	if float(_residents[i].get("next_act", 0.0)) > 30.0:
		return
	if float(_residents[j].get("next_act", 0.0)) > 30.0:
		return
	# I NOMI, MAI GLI INDICI. `_residents` cambia lunghezza in mezzo alla
	# giornata (un arrivo, una nascita, una partenza): un indice conservato
	# è l'handle nudo che questo progetto ha già pagato con `Ricordo.soggetto`
	# — l'incontro di ieri finirebbe intestato a un'altra persona.
	var na := str((_residents[i].get("dna", {}) as Dictionary).get("name", ""))
	var nb := str((_residents[j].get("dna", {}) as Dictionary).get("name", ""))
	if na == "" or nb == "":
		return
	var dove: Vector3 = (a.global_position + b.global_position) * 0.5
	# IL CANCELLO DEL POSTO, e non e' un doppione di quello dell'ora.
	#
	# La regola dice «al falo' la vicinanza non la sceglie nessuno»: i posti
	# sono `_posto_al_falo(i)`, cioe' l'ORDINE DI TRASLOCO, e l'anello mette
	# gli stessi vicini a portata ogni sera. Con 13 residenti sono 27 coppie e
	# 16 triangoli; con 28 sono 86 coppie, 83 triangoli e 25 quartetti —
	# esattamente la «cricca per costruzione (i, i+1, i+2)» che quella regola
	# esiste per impedire.
	#
	# I due cancelli sopra guardano l'OROLOGIO e lo STATO, e non bastano: i
	# corpi non si smaterializzano quando la campanella suona. MISURATO su due
	# corse (22 giornate): 26 righe su 139 e 17 su 81 — cioe' il 19-21% —
	# scritte DENTRO la radura con l'ora fra 0.858 e 0.902, dopo la fase; e
	# hanno fabbricato 3 delle 6 abitudini della prima corsa e 2 delle 4 della
	# seconda. Il nuovo arrivato entrava in tre giornate tutte e due le volte
	# CON LA STESSA PERSONA, perche' il suo posto al fuoco le capitava a 1,36 m.
	# Il villaggio non c'entrava niente.
	#
	# ⚠️ E la misura precedente («zero righe dal falo'») non era sbagliata: il
	# suo oracolo classificava per fase NEL MOMENTO DEL CAMPIONE, quindi le
	# righe di dopo finivano nel secchio «fuori dal falo'». Verificava il
	# cancello contro se' stesso.
	if _cozy != null and is_instance_valid(_cozy):
		var centro: Vector3 = _cozy.get("CLEARING_CENTER")
		if dove.distance_to(centro) < float(_cozy.get("CLEARING_R")):
			return
	_cricche.call("incontro", na, nb, dove)


# LE CHIACCHIERE HANNO UN TEMA: la parola Chibiese detta a voce e il simbolo
# nella nuvoletta sono la stessa cosa — così si impara.
#
# La tabella dei simboli NON abita più qui. C'era un `CHAT_TOPICS` con sette
# voci, identiche a sette delle undici di `Visitor.LP_SIMBOLI`: due tabelle
# con gli stessi valori, cioè una fonte doppia già viva, che aspettava solo
# che qualcuno cambiasse un simbolo da una parte sola. Adesso il simbolo di
# un concetto sta dove sta già — nel corpo che lo mostra.


func _res_of(node: Node3D) -> Dictionary:
	for r in _residents:
		if r.get("node") == node:
			return r
	return {}


## UNA CHIACCHIERATA, E NON È SIMMETRICA: `a` è **chi apre bocca**, `b` chi
## risponde. Quasi tutto qui dentro va nei due versi (si guardano, si
## nutrono a vicenda l'affetto e la compagnia, il libro mastro segna due
## gesti), ma due cose no — il PETTEGOLEZZO (`racconta(a, b)`: A racconta,
## B ascolta) e la nuvoletta, che esce dalla bocca di A e solo dopo un
## secondo da quella di B.
##
## Chi passa i due corpi in un ordine invece che nell'altro sta perciò
## decidendo chi ha una voce, non una coreografia. In `_chats` lo decide una
## monetina (`scegli_chiacchiera`); a chiamarla in ordine di anagrafe si
## azzittisce metà villaggio, e la storia sta là sopra.
func _run_chat(a: Node3D, b: Node3D) -> void:
	a.call("face_towards", b.global_position)
	b.call("face_towards", a.global_position)
	var ra := _res_of(a)
	var rb := _res_of(b)
	var brain_a: RefCounted = _ensure_brain(ra) if not ra.is_empty() else null
	var brain_b: RefCounted = _ensure_brain(rb) if not rb.is_empty() else null

	# ────────────────────────────────────────────────────────────────────
	# IL PETTEGOLEZZO, e viene PRIMA di tutto il resto.
	#
	# «Hai una notizia?» — se A ha visto Mochi fare qualcosa che B non sa
	# ancora, di quello si parla. È l'unica uscita che la Fase 4 ha il
	# permesso di avere a schermo: non un toast, non una lettera, non una
	# nuvoletta rivolta al giocatore, ma un simbolo scambiato fra due di
	# LORO — e la magia sta tutta nell'averlo COLTO, non nell'esserne stati
	# avvisati.
	#
	# IL SILENZIO È IL COMPORTAMENTO NORMALE: `racconta` torna -1 quasi
	# sempre (misurato su ventotto vicini per mezz'ora, col verso deciso
	# come in partita: 111 chiacchiere con notizia contro 403 mute), perché
	# una notizia si racconta UNA volta e chi l'ha sentita non la ripassa.
	# Quando tace, il tema torna a essere quello di sempre.
	#
	# Lo smorzamento arriva da `Villaggio.SMORZAMENTO`, la costante con cui
	# in questo villaggio si è sempre pagata una cosa saputa per sentito
	# dire: non se ne inventa una seconda per un canale nuovo.
	var novita := -1
	if _ecs != null and is_instance_valid(_ecs) and ra.has("ecs") and rb.has("ecs"):
		novita = int(_ecs.racconta(int(ra["ecs"]), int(rb["ecs"]),
				VILLAGGIO.SMORZAMENTO))

	# altrimenti il tema lo detta il momento: la pioggia, il falò della sera,
	# un RICORDO recente («ho visto un posto bellissimo…»), o la testolina
	var topic := "fiore"
	if novita >= 0:
		topic = str(_ecs.nome_cosa(novita))
	elif _weather and _weather.is_raining():
		topic = "pioggia"
	elif brain_a and randf() < 0.35 and not (brain_a.ricordo_recente() as Array).is_empty():
		topic = str((brain_a.ricordo_recente() as Array)[0])
	elif _daynight and float(_daynight.get("time")) > 0.68:
		topic = ["fuoco", "dormire", "cibo", "amico"][randi() % 4]
	else:
		topic = ["fiore", "cibo", "amico", "felice"][randi() % 4]
	# un concetto che il corpo non sa mostrare diventa «amico»: il ripiego
	# c'era già, e adesso guarda la tabella VERA dei simboli
	if not VISITOR.LP_SIMBOLI.has(topic):
		topic = "amico"

	# le chiacchiere nutrono l'amicizia (e il bisogno di compagnia)
	if brain_a and not rb.is_empty():
		brain_a.bump_affinita(str(rb["label"]))
		brain_a.satisfy("quattro_chiacchiere")
	if brain_b and not ra.is_empty():
		brain_b.bump_affinita(str(ra["label"]))
		brain_b.satisfy("quattro_chiacchiere")
	# …e finiscono anche sul LIBRO MASTRO degli affetti, con il loro peso
	# vero: una chiacchiera vale un ventesimo di un atto di coraggio. La
	# vicinanza non è affetto, e senza questa proporzione il libro mastro
	# diventerebbe una mappa di chi passa più tempo vicino a chi.
	var nome_a := str((ra.get("dna", {}) as Dictionary).get("name", ""))
	var nome_b := str((rb.get("dna", {}) as Dictionary).get("name", ""))
	if nome_a != "" and nome_b != "":
		get_tree().call_group("affetti", "gesto", nome_a, nome_b, "chiacchiera")
		get_tree().call_group("affetti", "gesto", nome_b, nome_a, "chiacchiera")

	a.call("chat_bubble", VISITOR.LP_SIMBOLI[topic])
	a.call("speak", [topic, "~"], "neutro")
	var brontolone: bool = brain_b != null and brain_b.has_indole("brontolone")
	get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(b):
			if brontolone:
				# brontola («bu…»), ma resta ad ascoltare: cuore di panna
				b.call("chat_bubble", "…")
				b.call("speak", ["no", "~"], "neutro")
			else:
				b.call("chat_bubble", VISITOR.LP_SIMBOLI[topic])
				# la risposta: d'accordo («ha!») o entusiasta
				b.call("speak", ["si", topic] if randf() < 0.5 else ["~", "felice"], "felice"))
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(a):
			if randf() < 0.5:
				a.call("_spawn_heart")
			else:
				a.call("chat_bubble", "!"))


# i piccoli desideri: la stessa mente, ma dopo il trasloco
func _wishes(delta: float) -> void:
	_wish_acc -= delta
	if _wish_acc > 0.0:
		return
	_wish_acc = 2.5
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var wish: Dictionary = r.get("wish", {})
		if wish.is_empty():
			r["wish"] = _gen_wish(r.get("dna", {}))
			_show_toast(L10n.tf("%s sogna %s vicino a casa…",
					[r["label"], L10n.t(str(WISH_ART[r["wish"]["item"]]))]))
			_build.request_save()
			continue
		if bool(wish.get("done", false)):
			continue
		var home := Vector3(r["cell"].x, 0, r["cell"].y)
		for it in _build.get_placed_by_name(str(wish["item"])):
			if (it as Node3D).global_position.distance_to(home) < 4.5:
				wish["done"] = true
				node.call("celebrate")
				# «ta-ki, mi-ka!» — grazie, amico
				node.call("speak", ["grazie", "amico"], "felice")
				_bump_friend(r, 2)
				get_tree().call_group("legami", "momento",
						str(r.get("dna", {}).get("name", "")), "desiderio", "")
				_show_toast(L10n.tf("%s è al settimo cielo: %s vicino a casa!",
						[r["label"], L10n.t(str(WISH_ART[wish["item"]]))]))
				if _mail:
					_mail.call("queue_letter", {
						"from_key": str(r.get("dna", {}).get("name", "Un amico")),
						"text_key": "Grazie per %s vicino a casa mia!\nOgni mattina gli do il buongiorno.",
						"args": [{"k": str(WISH_ART[wish["item"]])}],
						"gift": true,
					})
				if _sfx:
					_sfx.place_ok()
				_build.request_save()
				break


func _gen_wish(dna: Dictionary) -> Dictionary:
	var w: Dictionary = dna.get("weights", {})
	var best := "Fungo"
	var best_v := -99.0
	for entry in WISH_POOL:
		var v: float = float(w.get(entry[1], 0.5)) * randf_range(0.85, 1.15)
		if v > best_v:
			best_v = v
			best = entry[0]
	return {"item": best, "done": false}


func _bump_friend(r: Dictionary, amount: int) -> void:
	var before := int(r.get("friend", 0))
	r["friend"] = before + amount
	# il timido si scioglie: dal terzo cuoricino ricomincia a salutare
	var node := r.get("node") as Node3D
	if node and is_instance_valid(node):
		var brain: RefCounted = _ensure_brain(r)
		node.set("greet_enabled",
				not brain.has_indole("timido") or int(r["friend"]) >= 3)
	# al terzo cuoricino, la lettera d'amicizia
	if before < 3 and before + amount >= 3 and _mail:
		# due frasi intere invece di una desinenza incollata: il maschile e il
		# femminile sono DUE frasi da tradurre, non una stringa più una lettera
		# (in inglese quella lettera non ha dove andare)
		var grazie := "Mi trovo così bene nel villaggio.\nGrazie di essermi amica." \
				if randf() < 0.5 \
				else "Mi trovo così bene nel villaggio.\nGrazie di essermi amico."
		_mail.call("queue_letter", {
			"from_key": str(r.get("dna", {}).get("name", "Un amico")),
			"text_key": grazie,
			"gift": true,
		})
	# l'amicizia PIENA lascia un ricordo indossabile: la soglia e il capo
	# per archetipo li decide il guardaroba, qui si passa solo il conto
	if is_inside_tree():
		var arch := str(r.get("dna", {}).get("archetype", ""))
		if arch != "":
			get_tree().call_group("guardaroba", "unlock_amicizia", arch, int(r["friend"]))


# il regalo della zuppetta: i gusti vengono dal DNA
func _dish_target() -> Dictionary:
	if _cooking == null or not _cooking.call("has_dish"):
		return {}
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden") \
				and _player.global_position.distance_to(node.global_position) < 1.6:
			return r
	return {}


func _give_dish(r: Dictionary) -> void:
	# un piatto caldo non è solo un piatto: SCIOGLIE il rancore. È la porta
	# che rende il sistema dell'animo un dialogo invece che una condanna.
	gesto_gentile(str(r.get("label", "")), "piatto", 0.85)
	get_tree().call_group("regista", "note", "socievole")
	var dish: Dictionary = _cooking.call("take_dish")
	var node := r.get("node") as Node3D
	# IL DONO SI VEDE, e chi lo riceve se lo ricorda il doppio: `a_chi` è la
	# sua label, e da quella `EcsMondo.osserva` DERIVA `R_SU_DI_ME` — l'unica
	# asimmetria fra persone che il grafo dei ricordi conosce.
	get_tree().call_group("percezione", "accaduto", "dona",
			node.global_position, str(r.get("label", "")))
	var w: Dictionary = r.get("dna", {}).get("weights", {})
	# chi ama il calduccio adora i piatti caldi, chi ama il giardino i freddi
	var loves_it: bool = bool(dish.get("warm", true)) == \
			(float(w.get("warmth", 0.5)) >= float(w.get("garden", 0.5)))
	node.call("face_towards", _player.global_position)
	var art := String(dish.get("art", "il"))
	var kind := String(dish.get("name", "zuppetta"))
	# se oggi è il suo compleanno, il piatto diventa la FESTA A SORPRESA
	var cal := get_tree().get_first_node_in_group("calendario")
	var dish_dna: Dictionary = r.get("dna", {})
	if cal and cal.call("is_birthday", str(dish_dna.get("name", ""))):
		cal.call("throw_party", str(dish_dna.get("name", "")), str(r["label"]), node)
		_bump_friend(r, 3)
		get_tree().call_group("legami", "momento",
				str(dish_dna.get("name", "")), "festa", "")
		_build.request_save()
		return
	# --- l'OFFERTA: zampine protese, inchino, il piatto che fluttua ---
	var mochi := _player.get_node_or_null("Mochi")
	var dir := ((node.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	if mochi:
		mochi.set("_yaw", atan2(-dir.x, -dir.z))
		mochi.call("hold_offer", true)
	var dish_col := Color("e8944a") if bool(dish.get("warm", true)) else Color("b04a7a")
	var bowl := _make_bowl(dish_col)
	add_child(bowl)
	bowl.global_position = _player.global_position + dir * 0.34 + Vector3(0, 0.55, 0)
	bowl.scale = Vector3.ONE * 0.05

	var tw := create_tween()
	# la ciotolina sboccia sulle zampine mentre Mochi si inchina
	tw.tween_property(bowl, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mochi:
		tw.parallel().tween_property(mochi, "pour", 1.0, 0.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.3)
	# il piatto fluttua fino alle zampine dell'amico
	tw.tween_property(bowl, "global_position",
			node.global_position + Vector3(0, 0.55, 0), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# la reazione arriva COL piatto, non prima
	tw.tween_callback(func():
		if loves_it:
			_bump_friend(r, 2)
			get_tree().call_group("legami", "momento",
					str(r.get("dna", {}).get("name", "")), "piatto", kind)
			_show_toast(L10n.tf("%s ADORA %s %s!", [r["label"], art, kind]))
			if mochi:
				var jt := create_tween()
				jt.tween_property(mochi, "joy", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
				jt.tween_callback(func(): mochi.set("joy", 0.0))
		else:
			_bump_friend(r, 1)
			_show_toast(L10n.tf("%s ringrazia sorridendo per %s %s.", [r["label"], art, kind]))
		if _sfx:
			_sfx.place_ok()
		if mochi:
			mochi.call("hold_offer", false)
		# IL PIATTO PORTA IL NOME DI CHI L'HA CUCINATO, e la riga del libro
		# mastro degli affetti nasce QUI, al morso: il cuoco non divide la sua
		# zuppa con tutto il villaggio in un colpo solo — la divide con chi il
		# GIOCATORE ha deciso di servire attraversando la piazza con la ciotola
		# in zampa. È la stessa moneta della Voce e delle Nascite, e la ragione
		# è misurata: scrivendo quella riga verso OGNI residente, il conto fra
		# il cuoco e la guardia cresceva 2,6 volte più in fretta che verso
		# chiunque altro, e nel villaggio non poteva più formarsi nessun'altra
		# coppia.
		var cuoco := str(dish.get("cuoco", ""))
		var chi_mangia := str((r.get("dna", {}) as Dictionary).get("name", ""))
		if cuoco != "" and cuoco != chi_mangia \
				and not e_cucciolo(str(r.get("label", ""))):
			get_tree().call_group("affetti", "gesto", cuoco, chi_mangia, "piatto")
		# IL CERCHIO SI CHIUDE: la ciotola non svanisce più a mezz'aria —
		# gliela si consegna, e lui la MANGIA davvero (Pasto.gd: annusa,
		# soffia se scotta, tre morsetti, e solo allora ringrazia).
		if node.has_method("mangia"):
			node.call("mangia", bowl, dish_col, bool(dish.get("warm", true)), loves_it)
		else:
			node.call("_spawn_heart")
			node.call("speak", ["grazie"], "neutro")
			var via := create_tween()
			via.tween_property(bowl, "scale", Vector3.ONE * 0.03, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			via.tween_callback(bowl.queue_free))
	_build.request_save()


## Il gesto del regalo generalizzato: una porzione (ciotola) o un tesoro
## (pacchetto) scelto dalle Tasche. La reazione nasce dall'affinità col gusto
## del residente; il resto è la stessa coreografia di offerta di _give_dish.
func offer_item(r: Dictionary, item: Dictionary) -> void:
	if r.is_empty() or item.is_empty():
		return
	var node := r.get("node") as Node3D
	if node == null or not is_instance_valid(node):
		return
	get_tree().call_group("regista", "note", "socievole")
	get_tree().call_group("percezione", "accaduto", "dona",
			node.global_position, str(r.get("label", "")))
	var w: Dictionary = r.get("dna", {}).get("weights", {})
	var loves_it := _item_loved(item, w)
	node.call("face_towards", _player.global_position)
	var art := String(item.get("art", "il"))
	var what := "%s %s" % [art, String(item.get("name", "un regalo")).to_lower()]
	var is_treasure := String(item.get("kind", "dish")) == "treasure"
	var dna: Dictionary = r.get("dna", {})
	# se oggi è il suo compleanno, il regalo diventa la FESTA A SORPRESA
	var cal := get_tree().get_first_node_in_group("calendario")
	if cal and cal.call("is_birthday", str(dna.get("name", ""))):
		cal.call("throw_party", str(dna.get("name", "")), str(r["label"]), node)
		_bump_friend(r, 3)
		# la festa è il gesto gentile più grande: scioglie il rancore
		gesto_gentile(str(r.get("label", "")), "festa", 1.0)
		get_tree().call_group("legami", "momento", str(dna.get("name", "")), "festa", "")
		_build.request_save()
		return
	# --- l'OFFERTA: zampine protese, inchino, il dono che fluttua ---
	var mochi := _player.get_node_or_null("Mochi")
	var dir := ((node.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	if mochi:
		mochi.set("_yaw", atan2(-dir.x, -dir.z))
		mochi.call("hold_offer", true)
	var item_col := Color("e8944a") if bool(item.get("warm", true)) else Color("b04a7a")
	var prop: Node3D = _make_present() if is_treasure else _make_bowl(item_col)
	add_child(prop)
	prop.global_position = _player.global_position + dir * 0.34 + Vector3(0, 0.55, 0)
	prop.scale = Vector3.ONE * 0.05

	var tw := create_tween()
	tw.tween_property(prop, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mochi:
		tw.parallel().tween_property(mochi, "pour", 1.0, 0.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(prop, "global_position",
			node.global_position + Vector3(0, 0.55, 0), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		# ogni dono si annoda al Filo Rosso (una volta al giorno per tipo)
		get_tree().call_group("legami", "momento", str(dna.get("name", "")),
				"regalo" if is_treasure else "piatto", String(item.get("name", "")).to_lower())
		# il dono arriva anche all'ANIMO: è l'unico canale con cui il giocatore
		# scioglie il rancore (senza, il sistema sarebbe una condanna)
		gesto_gentile(str(r.get("label", "")),
				"regalo" if is_treasure else "piatto",
				0.9 if loves_it else 0.55)
		# una PORZIONE si mangia (il rituale del Pasto la chiude davvero); un
		# tesoro invece si stringe al petto: le feste del corpo restano quelle
		var mangiabile: bool = not is_treasure and node.has_method("mangia")
		if loves_it:
			if not mangiabile:
				node.call("celebrate")
				node.call("speak", ["grazie", "felice"], "felice")
			_bump_friend(r, 2)
			_show_toast(L10n.tf("%s ADORA %s!", [r["label"], what]))
			if mochi:
				var jt := create_tween()
				jt.tween_property(mochi, "joy", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
				jt.tween_callback(func(): mochi.set("joy", 0.0))
		else:
			if not mangiabile:
				node.call("_spawn_heart")
				node.call("speak", ["grazie"], "neutro")
			_bump_friend(r, 1)
			_show_toast(L10n.tf("%s ringrazia sorridendo per %s.", [r["label"], what]))
		if _sfx:
			_sfx.place_ok()
		if mochi:
			mochi.call("hold_offer", false)
		# come in `_give_dish`: se dentro la porzione viaggia il nome di chi
		# l'ha cucinata, il libro mastro degli affetti se ne accorge al morso.
		# Un TESORO no: una conchiglia non si cucina e non lega nessuno — e da
		# qui, dalle Tasche, passa anche roba che non è cibo (campo `kind`).
		var cuoco := str(item.get("cuoco", ""))
		var chi_mangia := str(dna.get("name", ""))
		if not is_treasure and cuoco != "" and cuoco != chi_mangia \
				and not e_cucciolo(str(r.get("label", ""))):
			get_tree().call_group("affetti", "gesto", cuoco, chi_mangia, "piatto")
		if mangiabile:
			node.call("mangia", prop, item_col, bool(item.get("warm", true)), loves_it)
		else:
			var via := create_tween()
			via.tween_property(prop, "scale", Vector3.ONE * 0.03, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			via.tween_callback(prop.queue_free))
	_build.request_save()


# lo adorerebbe? l'affinità del modello, o il vecchio caldo-vs-giardino
func _item_loved(item: Dictionary, weights: Dictionary) -> bool:
	if _inventory:
		return _inventory.affinity(item.get("tags", []), weights) == _inventory.REACT_LOVES
	return bool(item.get("warm", true)) == \
			(float(weights.get("warmth", 0.5)) >= float(weights.get("garden", 0.5)))


## Il residente non nascosto più vicino entro raggio, o {} — usato dalle
## Tasche per sapere a chi stai per regalare.
func nearest_giftable_resident(pos: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		var d: float = pos.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


# la ciotolina del piatto avanzato: legno chiaro, contenuto colorato
func _make_bowl(col: Color) -> Node3D:
	var bowl := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("e8cfae")
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.11
	bm.bottom_radius = 0.075
	bm.height = 0.09
	body.mesh = bm
	body.material_override = wood
	bowl.add_child(body)
	var food := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.095
	fm.bottom_radius = 0.095
	fm.height = 0.03
	food.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = col
	food.material_override = fmat
	food.position = Vector3(0, 0.045, 0)
	bowl.add_child(food)
	return bowl


# ---------------------------------------------------------- le nuove leve
# Chi nasce nel villaggio entra da qui. È l'unica porta: nessun altro
# file deve toccare `_residents`, o la riga finisce senza cervello, senza
# animo o senza compleanno — e non se ne accorge nessuno per giorni.

## Accoglie un cucciolo appena nato. Ritorna la label vera (o "" se non
## c'è posto). Il lettino DEVE essere libero: è la stessa regola del
## trasloco — in questo villaggio si entra solo se c'è un posto dove
## dormire — e qui diventa la cosa più tenera del gioco: perché nasca
## qualcuno, qualcuno deve avergli preparato il letto.
## IL CUCCIOLO HA UN LETTO SUO, e non è una rinuncia: è che in questo
## villaggio LA CELLA È LA CHIAVE DI UNICITÀ DEL LETTO. `load_extra` scarta
## ogni riga la cui cella è già presa, e la madre sta sempre prima nell'array:
## dando al nato la soglia di lei, il piccolo NON TORNAVA PIÙ dopo un
## ricaricamento — mentre il villaggio continuava a parlare di lui (il
## compleanno sulla lavagna, il battesimo, i due momenti sul filo dei
## genitori). Un bambino cancellato dal salvataggio è la cosa peggiore che
## questo sistema potesse fare.
##
## `casa_di` resta nella firma perché è la strada giusta per il giorno in cui
## la convivenza avrà il suo supporto nel salvataggio (una chiave «con chi
## divido la soglia», e `load_extra` che la rispetta). Oggi non ce l'ha, e
## fingere di sì costa un bambino.
func accogli_nato(dna_figlio: Dictionary, _casa_di := "") -> String:
	if _residents.size() >= MAX_RESIDENTS:
		return ""
	var casa := _free_house()
	if casa.is_empty():
		return ""
	var cell: Vector2i = casa["cell"]
	var v: Node3D = VISITOR.new()
	v.species = "chibi"
	v.dna = dna_figlio
	add_child(v)
	v.setup_resident(casa)
	var label := str(dna_figlio.get("label", ""))
	_residents.append({"species": "chibi", "cell": cell, "node": v,
			"dna": dna_figlio, "label": label, "friend": 0, "wish": {}})
	# il compleanno sulla lavagna vale anche per chi non ha traslocato:
	# è il primo posto in cui il villaggio scrive che esisti
	var cal := get_tree().get_first_node_in_group("calendario")
	if cal:
		var nome := str(dna_figlio.get("name", ""))
		if nome != "":
			cal.call("register_resident", nome, label, v)
	# nasce già col suo corpo piccolo: senza questa riga comparirebbe
	# grande quanto i genitori per un frame, e si vedrebbe
	v.call("set_cucciolo", 0.0)
	_apply_eta.call_deferred()
	return label


## È un cucciolo che sta ancora crescendo? Lo chiedono i sistemi che
## trattano i residenti da adulti: il registro dei lavori (nessuno manda
## un bambino alla catasta), il congedo (non si parte da piccoli), le
## commissioni della lavagna.
func e_cucciolo(label: String) -> bool:
	var legami := get_tree().get_first_node_in_group("legami")
	if legami == null:
		return false
	for r in _residents:
		if str(r.get("label", "")) != label:
			continue
		var nome := str(r.get("dna", {}).get("name", ""))
		return float(legami.call("crescita", nome)) < 1.0
	return false


## Quanto si frequentano quei due, per label: è il contatore che sale a
## ogni chiacchierata (VillagerBrain.affinita). Le nascite ci leggono
## l'affetto senza dover conoscere i cervelli.
## La casa di un vicino, per NOME (non per label): serve a far nascere il
## cucciolo sulla soglia dei suoi. {} se quel vicino non c'è o non ha casa.
func _casa_del_nome(nome: String) -> Dictionary:
	if nome == "":
		return {}
	for r in _residents:
		if str((r.get("dna", {}) as Dictionary).get("name", "")) != nome:
			continue
		var n := r.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			return {}
		var casa: Dictionary = n.get("_house")
		return casa.duplicate(true) if casa is Dictionary else {}
	return {}


## Quanto contano l'uno per l'altro, per LABEL. Non è più il contatore
## grezzo delle chiacchiere: legge il LIBRO MASTRO degli affetti, dove una
## chiacchiera vale un ventesimo di un gesto vero. Le nascite ci leggono
## l'affetto senza dover conoscere i cervelli.
func affetto_fra(label_a: String, label_b: String) -> float:
	var aff := get_tree().get_first_node_in_group("affetti")
	if aff == null:
		return float(affinita_fra(label_a, label_b))
	return float(aff.call("quanto", _nome_da_label(label_a),
			_nome_da_label(label_b)))


func _nome_da_label(label: String) -> String:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return str((r.get("dna", {}) as Dictionary).get("name", ""))
	return label


func affinita_fra(label_a: String, label_b: String) -> int:
	for r in _residents:
		if str(r.get("label", "")) != label_a:
			continue
		var brain := _ensure_brain(r)
		return int(brain.affinita.get(label_b, 0))
	return 0


## Tutti i residenti adulti, come [[nome, label, dna]]: la lista da cui
## le nascite pescano le coppie possibili.
func adulti_del_villaggio() -> Array:
	var legami := get_tree().get_first_node_in_group("legami")
	var out: Array = []
	for r in _residents:
		if str(r.get("species", "")) != "chibi":
			continue
		var dna: Dictionary = r.get("dna", {})
		var nome := str(dna.get("name", ""))
		if nome == "":
			continue
		if legami and float(legami.call("crescita", nome)) < 1.0:
			continue
		out.append([nome, str(r.get("label", "")), dna])
	return out


# ---------------------------------------------------------------- trasloco

# una casa libera = un Letto col tetto, non reclamato, non casa del giocatore
## C'è una casa pronta per un ospite (Letto coperto, libero, non di casa)?
## Lo usano gli Ordini del Gufo per sapere se un trasloco è davvero possibile.
func has_free_house() -> bool:
	return not _free_house().is_empty()


func _free_house() -> Dictionary:
	var home := get_node_or_null("../Home")
	for bed in _build.get_placed_by_name("Letto"):
		var cell := Vector2i(roundi(bed.position.x), roundi(bed.position.z))
		if not _build.has_cover(cell):
			continue
		if is_bed_claimed(cell):
			continue
		if home and home.call("is_home", cell):
			continue
		return _make_house(bed, cell)
	return {}


func _make_house(bed: Node3D, cell: Vector2i) -> Dictionary:
	# l'uscio: appena fuori dalla porta più vicina, o davanti al letto
	var front: Vector3 = bed.global_position + Vector3(0, 0, 1.6)
	var best_d := 4.0
	for door in _build.get_placed_by_name("Porta"):
		var dp: Vector3 = (door as Node3D).global_position
		var d := dp.distance_to(bed.global_position)
		if d < best_d:
			best_d = d
			var out: Vector3 = (dp - bed.global_position) * Vector3(1, 0, 1)
			front = dp + out.normalized() * 1.1
	front.y = 0.0
	return {"bed": bed, "cell": cell, "front": front}


# la casa ridotta al vettore di feature che la mente sa leggere
func _house_features(house: Dictionary) -> Dictionary:
	var f := {
		"roof": 1.0, "walls": 0.0, "door": 0.0, "window": 0.0,
		"comfort": 0.0, "garden": 0.0, "warmth": 0.0,
		"sunny": 0.0 if (_weather and _weather.is_raining()) else 1.0,
	}
	var bed := house.get("bed") as Node3D
	if not is_instance_valid(bed):
		return f  # letto demolito durante la visita: feature neutre
	var bp: Vector3 = bed.global_position
	var walls := 0
	for node in (_build.get("_placed")["edge"] as Dictionary).values():
		var n: String = (node as Node3D).get_meta("item_name", "")
		var d: float = (node as Node3D).global_position.distance_to(bp)
		if d > 3.4:
			continue
		match n:
			"Muro":
				walls += 1
			"Finestra":
				walls += 1
				f["window"] = 1.0
			"Porta":
				walls += 1
				f["door"] = 1.0
	f["walls"] = clampf(walls / 4.0, 0.0, 1.0)

	var comfort := 0
	var garden := 0
	for layer in [1, 2]:
		for node in (_build.get("_placed")[layer] as Dictionary).values():
			var n: String = (node as Node3D).get_meta("item_name", "")
			var d: float = (node as Node3D).global_position.distance_to(bp)
			if n in ["Comodino", "Tappeto", "Lampada", "Libreria", "Sedia", "Tavolino", "Sgabello"] and d < 3.0:
				comfort += 1
			elif n == "Camino" and d < 3.2:
				f["warmth"] = 1.0
			elif n in ["Aiuola", "Pianta", "Cespuglio", "Fungo", "Alberello"] and d < 4.5:
				garden += 1
	f["comfort"] = clampf(comfort / 4.0, 0.0, 1.0)
	f["garden"] = clampf(garden / 3.0, 0.0, 1.0)
	return f


## Gli archetipi non ancora rappresentati tra i residenti dati. PURA e
## statica (la testa il test): è la garanzia di varietà — con otto posti
## devono arrivare tutti e cinque, non un villaggio di soli gattini.
static func archetipi_mancanti(presenti: Array) -> Array:
	var visti := {}
	for a in presenti:
		visti[str(a)] = true
	var out := []
	for a in DNA.ARCHETYPES:
		if not visti.has(str(a)):
			out.append(str(a))
	return out


func _spawn_candidate(dna: Dictionary, house: Dictionary) -> void:
	# etichette UNICHE: animo, cervello, incarichi e salvataggio sono tutti
	# keyed sulla label (solo ~80 combinazioni possibili) — due omonimi
	# condividerebbero la stessa vita interiore. Se il caso la ripesca,
	# si rigenera il DNA finché la label non è nuova. E la VARIETÀ: finché
	# un archetipo manca all'appello, il prossimo candidato tende a essere
	# uno di quelli (tentativi limitati: se il caso si impunta, va bene
	# comunque chiunque — mai bloccare l'arrivo).
	var presenti := []
	for r in _residents:
		presenti.append(str((r.get("dna", {}) as Dictionary).get("archetype", "")))
	var mancanti := archetipi_mancanti(presenti)
	for _tent in 24:
		var label_ok := not _label_in_use(str(dna["label"]))
		var arche_ok: bool = mancanti.is_empty() or str(dna["archetype"]) in mancanti
		if label_ok and arche_ok:
			break
		dna = DNA.generate()
	_timer = randf_range(80.0, 160.0)
	_cand_label = str(dna["label"])
	_mind = MIND.new("chibi", int(_cand_visits.get(dna["name"], 0)), dna["weights"])
	_decided = false
	_welcomes = 0
	var v: Node3D = VISITOR.new()
	v.species = "chibi"
	v.dna = dna
	add_child(v)
	v.setup_candidate(house, ENTRIES[randi() % ENTRIES.size()], Vector3(0, 0, -9), Vector3(-2, 0, -15))
	v.finished.connect(func(): if _active == v: _active = null)
	_active = v
	var trait_line: String = (dna["traits"] as Array)[0]
	_show_toast(L10n.tf("C'è %s alla porta, valigia in zampa! (%s)",
			[_cand_label, L10n.t(trait_line)]))


## Il benvenuto del giocatore: scalda la mente e la fa parlare.
func welcome_candidate() -> void:
	if _active == null or _mind == null or _welcomes >= 3:
		return
	if not is_instance_valid((_active.get("_house") as Dictionary).get("bed")):
		return  # la casetta non c'è più: lascia che sia _decide a congedarlo
	_welcomes += 1
	get_tree().call_group("regista", "note", "socievole")
	get_tree().call_group("legami", "momento",
			str((_active.get("dna") as Dictionary).get("name", "")), "benvenuto", "")
	_mind.call("add_welcome")
	var f := _house_features(_active.get("_house"))
	var line: String = _mind.call("best_liked", f)
	var miss: String = _mind.call("most_missed", f)
	if _welcomes == 1 and miss != "":
		_show_toast(L10n.tf("«%s… però %s»", [line, miss]))
	else:
		_show_toast("«%s»" % line)
	# risponde al benvenuto nella sua lingua: ciao, casa!
	_active.call("speak", ["ciao", "casa"], "felice" if miss == "" else "neutro")
	_active.call("_spawn_heart")
	if _sfx:
		_sfx.ui_select()
		if _active.get("species") == "passerotto":
			_sfx.play("chirp1", -16.0, 1.15)


func _decide() -> void:
	_decided = true
	var house: Dictionary = _active.get("_house")
	# il letto può essere stato demolito durante la visita
	if not is_instance_valid(house.get("bed")):
		_show_toast(L10n.tf("«Oh… la casetta non c'è più.» E %s riparte col trolley.",
				[_cand_label]))
		_active.call("candidate_result", false, Vector3.ZERO)
		_mind = null
		return
	var f := _house_features(house)
	var p: float = _mind.call("evaluate", f)
	var dna: Dictionary = _active.get("dna")
	if p > 0.72:
		var cell: Vector2i = house["cell"]
		var newcomer := _active
		_residents.append({"species": "chibi", "cell": cell, "node": newcomer,
				"dna": dna, "label": _cand_label})
		newcomer.call("candidate_result", true, (house["bed"] as Node3D).global_position + Vector3(0.0, 0, 0.6))
		# il primo nodo sul Filo Rosso: il giorno della valigia
		get_tree().call_group("legami", "momento",
				str(dna.get("name", "")), "trasloco", "")
		# da qui in poi è un residente: libera lo slot delle visite
		_active = null
		_spawn_suitcase_prop(cell)
		_show_toast(L10n.tf("%s ha deciso: si trasferisce nel villaggio!", [_cand_label]))
		# gli Ordini del Gufo aspettano il primo abitante
		get_tree().call_group("gufo", "note_arrival")
		# un arrivo si incide sugli anelli del Grande Albero
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.engrave("♥", "%s si è trasferito nel villaggio", [_cand_label])
		# e il nuovo abitante andrà a scrivere il compleanno sulla lavagna
		var cal := get_tree().get_first_node_in_group("calendario")
		if cal:
			# il nome, MAI la label di ripiego: register_resident indicizza
			# per nome e is_birthday cerca per nome — un ripiego a label
			# registrerebbe in una colonna che nessuno legge (festa mai,
			# e senza un errore)
			var res_nome := str(dna.get("name", ""))
			if res_nome != "":
				cal.call("register_resident", res_nome, _cand_label, newcomer)
		if _sfx:
			_sfx.place_ok()
			get_tree().create_timer(0.4).timeout.connect(func():
				# il timer sopravvive al nodo: guardia anti-freed
				if is_instance_valid(self) and _sfx: _sfx.build_open())
	else:
		_cand_visits[dna["name"]] = int(_cand_visits.get(dna["name"], 0)) + 1
		var miss: String = _mind.call("most_missed", f)
		_show_toast(L10n.tf("«Ci devo pensare… %s» E %s riparte col trolley.",
				[miss, _cand_label]))
		_active.call("candidate_result", false, Vector3.ZERO)
	_mind = null
	_build.request_save()


func _spawn_suitcase_prop(cell: Vector2i) -> void:
	var prop: Node3D = VISITOR.make_suitcase()
	prop.position = Vector3(cell.x + 0.55, 0.08, cell.y + 0.4)
	prop.rotation.y = 0.5
	add_child(prop)


# ---------------------------------------------------------------- raccolta

# il candidato aspetta sull'uscio: se ti avvicini puoi dargli il benvenuto
func _welcome_ready() -> bool:
	return _active != null and _active.get("mode") == "candidate" \
			and _active.get("_state") in ["c_wait", "c_inspect"] and _welcomes < 3 \
			and _player.global_position.distance_to(_active.global_position) < 1.7


func _update_welcome_prompt() -> void:
	if not _welcome_ready():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var wp: Vector3 = _active.global_position + Vector3(0, 0.85, 0)
	if cam.is_position_behind(wp):
		return
	_prompt_label.text = L10n.t("E — dai il benvenuto")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


# un solo pannello, quattro voci in ordine di priorità: benvenuto,
# regalino a terra, porzione da regalare, sogno del residente
func _update_prompts() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_prompt.visible = false
		return
	if _welcome_ready():
		_update_welcome_prompt()
		return
	if _gift and _player.global_position.distance_to(_gift.global_position) <= 1.2:
		_update_gift_prompt()
		return
	if _inventory and _inventory.has_giftable():
		var gr := nearest_giftable_resident(_player.global_position, 1.8)
		if not gr.is_empty():
			var gnode := gr.get("node") as Node3D
			_show_prompt_at(L10n.tf("E / Tab — regala a %s", [str(gr.get("label", ""))]),
					gnode.global_position + Vector3(0, 1.0, 0), cam)
			return
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		# se sta vivendo una scena (un appuntamento mantenuto) il desiderio
		# aspetta: è lui che ha chiamato, non la panchina
		if node.has_method("in_scena") and bool(node.call("in_scena")):
			continue
		var wish: Dictionary = r.get("wish", {})
		if wish.is_empty() or bool(wish.get("done", false)):
			continue
		if _player.global_position.distance_to(node.global_position) < 2.0:
			# e lo dice pure, in Chibiese: il concetto del desiderio
			var wish_concepts := {"Aiuola": "fiore", "Fungo": "cibo",
					"Cespuglio": "fiore", "Lampada": "casa", "Panchina": "casa"}
			node.call("speak", [wish_concepts.get(str(wish["item"]), "casa"), "~"], "domanda")
			_show_prompt_at(L10n.tf("«sogno %s vicino a casa…»",
					[L10n.t(str(WISH_ART[wish["item"]]))]),
					node.global_position + Vector3(0, 1.0, 0), cam)
			return
	_prompt.visible = false


func _show_prompt_at(text: String, wp: Vector3, cam: Camera3D) -> void:
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _update_gift_prompt() -> void:
	if _welcome_ready():
		return
	var cam := get_viewport().get_camera_3d()
	if _gift == null or cam == null:
		_prompt.visible = false
		return
	if _player.global_position.distance_to(_gift.global_position) > 1.2:
		_prompt.visible = false
		return
	var wp: Vector3 = _gift.global_position + Vector3(0, 0.55, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.t("E — raccogli il regalino")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("saluta"):
		_saluta()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	if _welcome_ready():
		welcome_candidate()
		get_viewport().set_input_as_handled()
		return
	if _gift and _player.global_position.distance_to(_gift.global_position) <= 1.2:
		_collect_gift()
		get_viewport().set_input_as_handled()
		return
	if _inventory and _inventory.has_giftable() and _pockets:
		var gr := nearest_giftable_resident(_player.global_position, 1.8)
		if not gr.is_empty():
			# il carretto ha la precedenza: se il mercante è a portata ed è
			# più vicino dell'amico, la E è del negozio, non del regalo
			# (altrimenti col taccuino pieno il mercante era irraggiungibile)
			var md := INF
			var cal := get_tree().get_first_node_in_group("calendario")
			if cal and cal.has_method("merchant_distance"):
				md = float(cal.call("merchant_distance", _player.global_position))
			var gd := INF
			var gnode := gr.get("node") as Node3D
			if gnode and is_instance_valid(gnode):
				gd = _player.global_position.distance_to(gnode.global_position)
			if md < 1.6 and md < gd:
				return   # la E prosegue fino a Calendar._merchant_trade
			_pockets.open_for_gift(gr)
			get_viewport().set_input_as_handled()


## T — Mochi saluta con la zampina; il vicino più caro si volta e
## risponde («ya-ho!» col cuoricino), dopo un attimo di reazione.
func _saluta() -> void:
	var mochi := _player.get_node_or_null("Mochi")
	if mochi:
		mochi.call("wave")
	var best: Node3D = null
	var best_r := {}
	var best_d := 4.5
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
			best_r = r
	if best:
		var nome := str((best_r.get("dna", {}) as Dictionary).get("name", ""))
		var label := str(best_r.get("label", ""))
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(best):
				best.call("face_towards", _player.global_position)
				# IL SALUTO È ANCHE UNA DOMANDA. Se il corpo ha ancora
				# qualcosa da dire — un cuore in gola, un residuo di
				# allerta — la festa forzata suonerebbe finta: il corpo
				# del Limbico non mente, e la zampina alzata diventa il
				# «richiedilo» di cui parlava la meccanica delle due
				# strade. Altrimenti resta il saluto felice di sempre.
				if not _spiega_come_sta(label, best):
					best.call("_spawn_heart")
					best.call("speak", ["ciao", "felice"], "felice")
				# la prima zampina alzata si annoda al Filo Rosso;
				# e a volte, salutandosi, un ricordo riaffiora
				get_tree().call_group("legami", "momento", nome, "primo_saluto", "")
				get_tree().call_group("legami", "ricorda", nome, best)
				# durante un lutto, la zampina alzata È la consolazione:
				# il Congedo sa chi sta aspettando un pensiero
				get_tree().call_group("congedo", "consolato", label, nome))


## Il sasso piatto del collezionista: glielo si vede raccogliere (tk_sasso)
## e se sei a due passi te lo mette in tasca. Non ogni volta: un sasso
## DAVVERO piatto e' raro, e il regalo vale quanto l'attesa.
func _dona_sasso(r: Dictionary, node: Node3D) -> void:
	if _inventory == null or _player == null or node == null \
			or not is_instance_valid(node):
		return
	if _player.global_position.distance_to(node.global_position) > 7.0:
		return   # se non c'eri, il sasso resta nella sua collezione
	if randf() > 0.45:
		return
	var scheda: Dictionary = _inventory.add_treasure("sasso_piatto")
	if scheda.is_empty():
		return
	node.call("_spawn_heart")
	node.call("speak", ["regalo"], "felice")
	_show_toast(L10n.tf("%s ti ha portato un sasso piatto: perfetto per rimbalzare.",
			[r.get("label", "")]))
	if _build:
		_build.request_save()


func _collect_gift() -> void:
	if _gift_bob:
		_gift_bob.kill()
	# il dono del bosco diventa un Tesoro vero nelle Tasche (era solo testo)
	var what := ""
	if _inventory:
		var scheda: Dictionary = _inventory.add_random_gift(_gift_species, randi())
		if not scheda.is_empty():
			what = "%s %s" % [scheda.get("art", ""), scheda.get("name", "")]
			_build.request_save()
	if what == "":
		var gifts: Array = GIFTS[_gift_species]
		what = L10n.t(str(gifts[randi() % gifts.size()]))
	_show_toast(L10n.tf("%s ti ha lasciato %s!",
			[L10n.t(str(SPECIES_LABEL[_gift_species])), what]))
	# dai regali del passerotto nasce la sciarpina di lana
	if _gift_species == "passerotto":
		var wr := get_tree().get_first_node_in_group("guardaroba")
		if wr:
			wr.unlock("sciarpina_lana")
	var pos := _gift.global_position
	var tw := create_tween()
	tw.tween_property(_gift, "scale", Vector3.ONE * 0.03, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_gift.queue_free)
	_gift = null
	if _sfx:
		_sfx.place_ok()
	# cuoricini di gratitudine
	for i in 3:
		get_tree().create_timer(0.15 * i).timeout.connect(func():
			_mini_heart(pos + Vector3(randf_range(-0.12, 0.12), 0.3, randf_range(-0.08, 0.08))))


func _mini_heart(pos: Vector3) -> void:
	var heart := Node3D.new()
	var pink := StandardMaterial3D.new()
	pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pink.albedo_color = Color(1.0, 0.55, 0.68)
	for side: float in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		b.mesh = sm
		b.material_override = pink
		b.position = Vector3(side * 0.026, 0.02, 0)
		heart.add_child(b)
	var tip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.052
	cm.height = 0.07
	tip.mesh = cm
	tip.material_override = pink
	tip.position = Vector3(0, -0.025, 0)
	tip.rotation.x = PI
	heart.add_child(tip)
	heart.position = pos
	add_child(heart)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(heart, "position:y", pos.y + 0.6, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart, "scale", Vector3.ONE * 0.2, 1.4).set_ease(Tween.EASE_IN)
	tw.tween_property(heart, "rotation:y", 2.0, 1.4)
	tw.chain().tween_callback(heart.queue_free)


# ---------------------------------------------------------------- UI

func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.modulate.a = 0.0
	_toast.visible = true
	var vp_w := get_viewport().get_visible_rect().size.x
	_toast.position = Vector2(vp_w * 0.5 - _toast.size.x * 0.5, 64)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _toast.visible = false)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)

	_toast = PanelContainer.new()
	var ts := sb.duplicate() as StyleBoxFlat
	ts.bg_color = Color(0.99, 0.96, 0.9, 0.96)
	ts.content_margin_left = 16.0
	ts.content_margin_right = 16.0
	ts.content_margin_top = 8.0
	ts.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("panel", ts)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 15)
	_toast_label.add_theme_color_override("font_color", Color("8a5a3a"))
	_toast.add_child(_toast_label)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for r in _residents:
		var row := {"sp": r["species"], "x": r["cell"].x, "z": r["cell"].y,
				"dna": r.get("dna", {}), "label": r.get("label", ""),
				"friend": int(r.get("friend", 0)), "wish": r.get("wish", {})}
		# la vita interiore si salva con lui: bisogni, amicizie, ricordi
		var key := str(r.get("label", "?"))
		if _brains.has(key):
			row["brain"] = (_brains[key] as RefCounted).to_dict()
		if _animi.has(key):
			row["animo"] = (_animi[key] as RefCounted).save()
		rows.append(row)
	# la memoria dei PARTITI (chi ha acceso la miccia della rivolta) vive
	# nel grafo del villaggio, ricostruito da zero a ogni avvio: senza
	# salvarla, la cronaca perdeva il primo focolaio a ogni riavvio
	var partiti: Dictionary = _partiti_salvati
	if _villaggio != null:
		partiti = _villaggio.partiti
	return {"residents": rows, "cand_mem": _cand_visits,
			"villaggio": {"partiti": partiti}}


func load_extra(data: Dictionary) -> void:
	_cand_visits = data.get("cand_mem", {})
	var vdata: Dictionary = data.get("villaggio", {})
	_partiti_salvati = vdata.get("partiti", {})
	for row in data.get("residents", []):
		if row is not Dictionary:
			continue
		var species := str(row.get("sp", "chibi"))
		var cell := Vector2i(int(row.get("x", 0)), int(row.get("z", 0)))
		if is_bed_claimed(cell):
			continue
		# il letto deve esistere ancora, altrimenti il villager è partito
		for bed in _build.get_placed_by_name("Letto"):
			if Vector2i(roundi(bed.position.x), roundi(bed.position.z)) == cell:
				var house := _make_house(bed, cell)
				var v: Node3D = VISITOR.new()
				v.species = species
				var dna: Dictionary = row.get("dna", {})
				if not dna.is_empty():
					v.dna = dna
				add_child(v)
				v.setup_resident(house)
				_residents.append({"species": species, "cell": cell, "node": v,
						"dna": dna, "label": str(row.get("label", "")),
						"friend": int(row.get("friend", 0)), "wish": row.get("wish", {}),
						"brain": row.get("brain", {}),
						# senza questa riga l'animo salvato non tornava mai:
						# _ensure_brain lo cerca in r["animo"] (rancore, ricordi,
						# gradino di ribellione ripartivano da zero a ogni avvio)
						"animo": row.get("animo", {})})
				_spawn_suitcase_prop(cell)
				# il Filo Rosso lo riconosce (o lo adotta, dai salvataggi
				# di prima del Filo) e l'età gli torna addosso
				get_tree().call_group("legami", "registra_arrivo",
						str(dna.get("name", "")))
				_apply_eta.call_deferred()
				break


# ---------------------------------------------------------------- debug CLI

func debug_visit(species: String) -> void:
	if _active:
		_active.queue_free()
		_active = null
	_spawn(species)


func debug_candidate(seed_v := -1) -> void:
	if _active:
		_active.queue_free()
		_active = null
	var house := _free_house()
	if house.is_empty():
		return
	_spawn_candidate(DNA.generate(seed_v), house)


func debug_goto_wait() -> void:
	if _active == null:
		return
	_active.position = (_active.get("_house") as Dictionary)["front"]
	_active.call("_enter_state", "c_wait")


func debug_force_decide() -> void:
	if _active and not _decided:
		_decide()


func debug_add_resident(seed_v: int, pos: Vector3) -> void:
	var dna: Dictionary = DNA.generate(seed_v)
	var v: Node3D = VISITOR.new()
	v.species = "chibi"
	v.dna = dna
	add_child(v)
	v.setup_resident({"bed": null, "cell": Vector2i(999, 999), "front": pos})
	_residents.append({"species": "chibi", "cell": Vector2i(999, 999), "node": v,
			"dna": dna, "label": str(dna["label"]), "friend": 0,
			"wish": {"item": "Fungo", "done": true}})


func debug_gather_fire() -> void:
	for i in _residents.size():
		var node := _residents[i].get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var spot := _posto_al_falo(i)
		node.position = spot + Vector3(0.04, 0, 0.04)
		node.call("do_routine", "fire", spot, CLEARING)
		_residents[i]["phase"] = "fire"
		_residents[i]["next_act"] = 9999.0


func debug_force_chat() -> void:
	if _residents.size() >= 2:
		_run_chat(_residents[0]["node"], _residents[1]["node"])


func debug_stage_resident(i: int, pos: Vector3) -> void:
	var node := _residents[i].get("node") as Node3D
	node.position = pos
	node.call("_enter_state", "r_idle")
	# la fase CORRENTE, così _routine non azzera il next_act in scena
	_residents[i]["phase"] = _phase()
	_residents[i]["next_act"] = 9999.0


func debug_give_dish(i := 0) -> void:
	if i >= 0 and i < _residents.size():
		_give_dish(_residents[i])


## Per il bootstrap del salvataggio: insedia un residente VERO al letto
## nella cella data — DNA generato dal seed, casa, valigia e amicizia.
func debug_settle(seed_v: int, cell: Vector2i) -> void:
	for bed in _build.get_placed_by_name("Letto"):
		if Vector2i(roundi(bed.position.x), roundi(bed.position.z)) != cell:
			continue
		var dna: Dictionary = DNA.generate(seed_v)
		var house := _make_house(bed, cell)
		var v: Node3D = VISITOR.new()
		v.species = "chibi"
		v.dna = dna
		add_child(v)
		v.setup_resident(house)
		_residents.append({"species": "chibi", "cell": cell, "node": v,
				"dna": dna, "label": str(dna["label"]), "friend": 1, "wish": {}})
		_spawn_suitcase_prop(cell)
		return


## Per il bootstrap: via tutti i residenti (e i loro cervelli).
func debug_reset() -> void:
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node):
			node.queue_free()
	_residents.clear()
	_brains.clear()
	_animi.clear()
	if _ecs != null and is_instance_valid(_ecs):
		_ecs.dimentica_tutti()
	_villaggio = null


func debug_brain(i: int) -> RefCounted:
	if i < 0 or i >= _residents.size():
		return null
	return _ensure_brain(_residents[i])


## Forza un'attività dell'agenda (per la verifica CLI). Vero se la
## scena è partita davvero.
func debug_force_activity(i: int, act: String) -> bool:
	if i < 0 or i >= _residents.size():
		return false
	var r := _residents[i]
	var node := r.get("node") as Node3D
	if node == null or not is_instance_valid(node) or node.call("is_hidden"):
		return false
	r["next_act"] = 9999.0
	r["phase"] = _phase()
	# I FATTI PRIMA DELLA SCENA: `_recita` chiede al piano, e il piano legge
	# `r["luoghi"]`. Senza questo rinfresco la verifica CLI proverebbe
	# sempre e solo il ramo scritto a mano — cioè non proverebbe la Fase 3.
	r["fatti_scad"] = -1.0
	_fatti_di(r, node)
	# E LA DEDUZIONE, esattamente come in `_gesti_agenda`. Non è una comodità:
	# è la stessa trappola già pagata dalla riga qui sopra — una verifica CLI
	# che salta un passo del cablaggio prova sempre e solo il ramo scritto a
	# mano, cioè non prova la fase per cui è stata scritta.
	act = _deduzione_dirotta(r, act)
	_recita(r, node, _ensure_brain(r), act, "day")
	return true


func debug_quirk(i: int, q: String) -> void:
	if i < 0 or i >= _residents.size():
		return
	var r := _residents[i]
	var brain: RefCounted = _ensure_brain(r)
	brain.set("quirk", q)
	r["quirk_cd"] = 0.0
	var node := r.get("node") as Node3D
	if node and is_instance_valid(node):
		var t_ora: float = float(_daynight.get("time")) if _daynight else 0.85
		_quirk_tick(r, node, brain, 0.0, t_ora)
