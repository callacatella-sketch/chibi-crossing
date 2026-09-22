extends Node

## GLI AFFETTI FRA VICINI — il libro mastro dei gesti, e la famiglia.
##
## Il Filo Rosso lega il giocatore a ognuno. Questo lega i vicini FRA LORO, e
## con la stessa idea: non un numero che sale, ma un ELENCO DATATO di cose
## successe. Due vicini si affezionano perché hanno fatto delle cose insieme,
## e il giocatore quelle cose le ha viste tutte.
##
## ============================================================
## PERCHÉ NON È UN CONTATORE
## ============================================================
## Un contatore che sale non si può spiegare a posteriori: quando due si
## mettono insieme, il giocatore non ha modo di sapere perché quei due. Un
## elenco sì — e ogni sua riga è un momento che è accaduto davanti a lui.
##
## E soprattutto: le righe si LEGGONO, non si sommano. La stessa colonna,
## letta da due persone diverse, dà due numeri diversi, perché:
##  · chi è LEALE ha un passato che non sbiadisce (la mezza vita del ricordo
##    va da 36 giorni a 72 secondo la lealtà) — ed è per questo che certe
##    coppie sono inespugnabili, senza nessun caso speciale che le protegga;
##  · ESSERE SCELTI conta quasi il doppio che scegliere (`ASIMMETRIA`), così
##    un rapporto a senso unico si legge storto dai due lati senza una riga
##    di codice dedicata;
##  · la CHIACCHIERA vale un ventesimo di un atto di coraggio. La vicinanza
##    fisica non è affetto: senza questo il libro mastro diventa una mappa di
##    chi passa più tempo vicino a chi.
##
## ============================================================
## LA COPPIA NON È UN CAMPO
## ============================================================
## Non esiste da nessuna parte un dato «fidanzati». `coppia()` è un
## PREDICATO DERIVATO, vero quando ognuno dei due è il massimo dell'altro
## (il minimo reciproco — la stessa saggezza che `Nascite.coppia_migliore`
## aveva già scritto in un commento: «con chi non lo ricambia non è una
## coppia, è un'infatuazione»), quando tutti e due superano la soglia, e
## quando la cosa regge per qualche giorno di fila.
##
## Così non c'è niente da tenere sincronizzato, niente che possa restare
## appeso a metà, e nessun salvataggio vecchio da migrare: il legame si
## ricalcola dai fatti, sempre.

const ANIMO := preload("res://scenes/npc/Animo.gd")

const RECENZA_BASE := 36.0    # mezza vita del ricordo, in giorni, per un tipo poco leale
const RECENZA_LEALE := 72.0   # …e per uno che non dimentica
## Essere cercati vale quasi il doppio che cercare.
const ASIMMETRIA := 0.55
## Quanto conto serve per essere una coppia, e per quanti giorni di fila.
const SOGLIA_COPPIA := 2.4
const GIORNI_CONFERMA := 3
## Quante righe di peso vero servono perché un legame conti come tale: cento
## chiacchiere accidentali al falò non sono un affetto.
const PESO_VERO := 0.5
const GESTI_VERI_MIN := 3

## QUANTO SQUILIBRIO È UN DEBITO — cioè quanto uno deve aver ricevuto più di
## quanto ha dato perché la cosa valga ancora qualcosa.
##
## NON È UN NUMERO NUOVO: è `PESO_VERO` letto attraverso l'`ASIMMETRIA`, e la
## derivazione dice esattamente cosa significa. Un gesto solo, a senso unico,
## sposta lo `squilibrio` di `peso * (1 - ASIMMETRIA)` — la parte del peso che
## i due lati NON leggono uguale. Quindi un gesto singolo passa questa soglia
## se e solo se è un gesto VERO (`peso >= PESO_VERO`): la stessa domanda che
## `gesti_veri()` fa a una coppia, fatta da un'altra parte.
##
## Perciò qui NON serve un secondo filtro «solo i gesti veri»: LA SOGLIA È IL
## FILTRO. Scriverne uno accanto sarebbe una regola gemella, che diverge in
## silenzio il giorno che qualcuno tocca `GESTI`. MISURATO sulla tabella di
## oggi, riga singola letta lo stesso giorno: chiacchiera 0,0225 · salone
## 0,135 · fianco 0,1575 · musica 0,180 restano sotto; piatto 0,315 · veglia
## 0,360 · consolazione 0,450 · coraggio 0,540 · nascita 0,900 la passano.
## (E due gesti leggeri a senso unico la passano insieme: è accumulazione
## onesta — due volte «seduti al buio ad ascoltare» e mai una in cambio è
## davvero uno squilibrio.)
##
## E IL DEBITO SBIADISCE, come tutto in questo file: con la mezza vita media
## un piatto smette di essere un debito dopo ~26 giorni (0,315 · 2^(−g/54) =
## 0,225) e un atto di coraggio dopo ~68. La chiave a forma di giocatore non è
## l'unica che apre questa porta: c'è anche il tempo che passa.
const SQUILIBRIO_MIN := PESO_VERO * (1.0 - ASIMMETRIA)

## L'ABITUDINE NON È UN GESTO. Lo stesso gesto pesante, fra le stesse due
## persone e nello stesso verso, non si riscrive prima di una settimana: chi
## tiene accesa una luce sulla stessa porta ogni notte non sta rifacendo una
## scelta, sta tenendo un'abitudine — e il libro mastro tiene il gesto.
##
## MISURATO: una riga da 0,80 ripetuta ogni notte va a regime a ~41,9, cioè
## diciassette volte `SOGLIA_COPPIA`, e annega tutto quello che fa il
## giocatore (`coraggio` vale 1,20 e succede una volta sola). Con la valvola,
## un mese di veglie sulla stessa porta scrive 5 righe invece di 30 e si
## legge 3,33 da chi le riceve: conta ancora — deve contare — ma sta sulla
## stessa scala dei gesti del giocatore invece di sommergerli.
##
## Sette giorni, e non ventuno: è la finestra dell'`ASIMMETRIA`. Perché il
## solo DONATORE arrivi alla soglia con un flusso a senso unico serve
## `0.55*0.80/(1-2^(-T/36)) >= 2.4`, cioè T ≤ ~10 giorni con lealtà bassa;
## a 14-21 chi veglia non può più essere ricambiato affatto (misurato: a 28
## residenti la prima coppia slitta al giorno 114-198, oltre l'orizzonte di
## quasi ogni partita).
##
## ⚠️ E ADESSO QUESTO NUMERO HA UN SECONDO LETTORE, CHE NON È UN GESTO. La
## riconoscenza (`da_ringraziare`) manda un corpo ad attraversare il villaggio
## per mettersi accanto a chi si è preso cura di lui, e `Visitors` raffredda
## quella visita QUI — sulla coppia, con questa costante, per la stessa
## ragione: una cosa che si ripete ogni giorno smette di essere quella cosa.
##
## Ma non è solo buon gusto: è un FIREWALL, e la sua aritmetica va saputa
## prima di toccare il 7. Un corpo che si ferma a 0,9 m da un altro fa
## scrivere a `Visitors._segna_incontro` una riga di co-presenza, e
## `Cricche.ritrovo_vivo()` diventa vero con `GIORNATE_RITROVO` (3) giornate
## DIVERSE dentro `Cricche.FINESTRA` (7). Con un raffreddamento di C giorni,
## in una finestra di sette ci stanno al più `ceil(7/C)` visite: a 7 una, a 4
## due, **a 3 tre — e il ritrovo si forma**. Cioè un debito da un piatto
## fabbricherebbe un ritrovo, che riordina il cerchio del falò e finisce nel
## filo di un cucciolo per sempre: il libro mastro entrerebbe per la porta di
## servizio in due sistemi progettati apposta per non guardarlo — la forma
## esatta del guasto che questa tabella ha già chiuso togliendo la voce `falo`.
##
## CHI ABBASSA QUESTO NUMERO PER UNA RAGIONE DI AFFETTI riapre quel ciclo
## senza toccare una riga della riconoscenza. (La coincidenza col 7 di
## `Cricche.FINESTRA` è una coincidenza: sono due domande diverse, e nessuno
## dei due si scrive in funzione dell'altro.)
const GIORNI_RIPETIZIONE := 7

## UNA RIGA PER TIPO DI GESTO, e vale come fonte unica. I numeri non sono
## gusto: la scala dice che la vicinanza non è affetto e che proteggere
## qualcuno pesa più che mangiarci insieme.
const GESTI := {
	"chiacchiera": 0.05,        # passare del tempo vicini
	"salone": 0.30,             # l'ha visto diventare un altro
	"fianco": 0.35,             # ha attraversato il villaggio per stargli accanto
	"musica": 0.40,             # seduti al buio ad ascoltare
	"piatto": 0.70,             # ha diviso quello che aveva
	"veglia": 0.80,             # gli ha tenuto accesa una luce
	"consolazione": 1.00,       # c'era, il giorno del lutto
	"coraggio": 1.20,           # ci è andato per primo
	"nascita": 2.00,            # hanno fatto una vita
}

## ⚠️ QUATTRO VOCI TOLTE, E LA RAGIONE VALE PIÙ DELLA TABELLA.
## Fino al 2026-08-10 qui dentro c'erano anche `falo` 0.08, `promessa` 0.60,
## `posto` 0.90 e `mancanza` −0.50. **Non le emetteva NESSUNO**, e non è una
## dimenticanza recente: cercando in TUTTA la storia del repository non
## esiste un solo commit in cui una di quelle quattro sia mai stata passata
## a `gesto()`. Erano scritte a tavolino prima che il gioco esistesse, e
## ognuna delle quattro, esaminata, non poteva esistere:
##
## `posto` e `promessa` erano COPIE. Le stesse identiche parole vivono già
## in `Legami.TIPI` — «quel posto dove ci si trovava senza dirselo», «quella
## volta che ti ho aspettato, e sei venuto» — ma là il soggetto è il
## GIOCATORE, che è il libro giusto: le promesse sono fra un vicino e Mochi
## (`Promesse._prova_incontro` esce se il giocatore non è lì), e questo
## libro mastro «lega i vicini FRA LORO». Due tabelle, la stessa chiave, due
## significati: è la fonte doppia che questo progetto vieta. E per `posto`
## c'è un divieto scritto a mano da un altro file: `Cricche.gd` dice «**E non
## va in `Affetti._righe`**… una riga di co-presenza lì dentro cambierebbe
## `conto()`, quindi `il_piu_caro()`, quindi `coppia()`». MISURATO: due
## duetti a una settimana l'uno dall'altro — ventotto minuti reali, due
## Punti muti — bastavano a fabbricare una coppia (2.67 contro 2.40).
##
## `mancanza` era l'unico peso negativo, e faceva tre danni che nessuno si
## aspettava. `gesti_veri()` conta con `absf`, quindi **tre delusioni
## valevano tre gesti VERI** e passavano da sole il cancello che esiste per
## dimostrare che fra due c'è qualcosa; `pota()` non la buttava mai (stesso
## `absf`), quindi un rimprovero restava finché restava il villaggio; e nove
## a settimana scioglievano una coppia viva col calendario invece che coi
## gesti — la macchina del divorzio che la regola 3 vieta. Più la ragione
## che basta da sola: è la riga «tradimento» che la regola 5 giura di non
## avere. La delusione una casa ce l'ha già, ed è `Limbico`: là decade, là
## si estingue, e là la chiave a forma di giocatore esiste.
##
## `falo` era `_gesto_verso_tutti` al quadrato. Al fuoco i posti li assegna
## l'ordine di trasloco, non l'affetto — il commit che ha tolto il falò
## dalle cricche l'ha già misurato — e in Affetti non c'è nessun cancello a
## fermarlo: 756 righe a sera con ventotto residenti contro un tetto di 420,
## novantamila a regime, e `le_coppie()` (che gira una volta per giornata di
## gioco, cioè ogni quattro minuti reali) da 233 ms a **55 secondi**.
##
## TOGLIERLE NON HA RICHIESTO NESSUNA MIGRAZIONE, ed è per costruzione:
## `gesto()` rifiuta i tipi che non sono in tabella, e i tre lettori dei
## pesi chiedono `GESTI.get(tipo, 0.0)` — un tipo sconosciuto pesa zero e
## viene saltato. Un salvataggio che ne contenesse (non può: nessuno le ha
## mai scritte) si aprirebbe uguale.

## Quanti momenti col GIOCATORE servono per richiudere ogni ferita. È la
## chiave a forma di giocatore, e non è un ornamento: nessuna ferita che
## questo sistema apre può restare senza una porta. (È la stessa regola per
## cui `Visitors._filtra_luogo` esiste: la porta è sempre il giocatore.)
const MOMENTI_CHIAVE := {
	"chiudo_la_porta": 3,
	"mi_ritiro": 2,
	"sto_col_piccolo": 2,
	"me_ne_vado": 4,          # la più cara, e si spende nella settimana del congedo
	"lo_dico_a_tutti": 2,
	"faccio_finta": 1,
	"resto_e_aspetto": 1,
}

## Sotto questo margine la coppia è ancora coppia, ma il corpo lo dice già.
## Il telegrafo comincia PRIMA che succeda qualcosa — come gli otto gradini
## della scala della ribellione, che esistono proprio perché il giocatore
## possa vedere che sta perdendo qualcuno.
const MARGINE_FRAGILE := 1.25

## IL PAREGGIO NON ELEGGE NESSUNO. Quanto il primo deve staccare il secondo
## per potersi chiamare «il più caro».
##
## Nacque contro i gesti che il villaggio faceva VERSO TUTTI in un colpo
## solo — la guardia che vegliava su ognuno, il cuoco che divideva il piatto
## con ognuno: stesso tipo, stesso giorno, stesso peso verso ogni residente,
## `conto()` identico al centesimo e il `>` stretto che eleggeva il PRIMO
## dell'array `_residents`.
##
## POI L'ABBIAMO MISURATO (240 giorni x 6 semi) e non era un pareggio: era un
## DOMINIO. Fra la guardia e il cuoco il conto cresceva di 1,14 al giorno
## contro 0,44 verso chiunque altro — 2,6 a 1. Prima coppia sempre al giorno
## 3, sempre quei due, a 3, 6, 12 e 28 residenti; e UNA SOLA coppia in tutta
## la partita, perché per ogni altro vicino il massimo era la guardia, che
## non ricambiava nessuno. Un solo incarico assegnato sterilizzava gli
## affetti dell'INTERO villaggio — e questo margine non poteva fermarlo: è
## una guardia contro i pareggi, e contro un dominio non serve un margine.
##
## La cura sta alla radice, non qui: la riga nasce dove il gesto SUCCEDE
## davvero (una porta per notte per la veglia, la ciotola che il giocatore
## porta con le sue zampe per il piatto) e `GIORNI_RIPETIZIONE` impedisce
## all'abitudine di riscriverla ogni giorno.
##
## Il margine RESTA, perché i pareggi veri esistono ancora (due gesti gemelli
## lo stesso giorno) ed è esattamente la classifica invisibile che questo
## sistema si è ripromesso di non scrivere: se due contano UGUALE, il gioco
## non sceglie per il vicino. Nessun eletto, nessuna coppia, nessun
## telegrafo.
const MARGINE_ELEZIONE := 1.06

var _righe: Array = []        # {a, b, t, d}: da A verso B, tipo, giorno
## le coppie di ieri, per accorgersi quando una non c'è più
var _coppie_ieri: Array = []
## le ferite aperte: nome -> {reazione, ex, dal, momenti}
var _ferite := {}
var _ultimo_giorno := -1
## LE POSE CHE ABBIAMO POSATO NOI: nome -> postura. Il meta "postura" è di
## tutti (il telegrafo della ribellione, il fagotto della partenza, il
## concerto), e due sistemi usano gli STESSI nomi — «distratto» è sia il
## nostro margine che si assottiglia sia lo «ho scordato l'ascia» della
## scala. Senza sapere chi l'ha posata, toglierla spegnerebbe il telegrafo
## di un altro sistema, che non ha modo di accorgersene e non la riscriverà
## fino al gradino dopo. Non va nel salvataggio: i corpi rinascono nudi.
var _pose_nostre := {}
var _visitors: Node
var _daynight: Node3D
var _cablato := false


func _ready() -> void:
	add_to_group("affetti")
	add_to_group("persistable")
	_cabla()


## Il cablaggio si riprova: `Visitors` c'è dall'inizio, ma `DayNight` e i
## sistemi del mondo no — ed è la trappola già pagata due volte in questo
## progetto (un riferimento preso in un `call_deferred` del `_ready` resta
## null per sempre e il sistema gira a vuoto, senza un errore).
func _cabla() -> void:
	if _cablato:
		return
	if _visitors == null:
		_visitors = get_node_or_null("../Visitors")
	if _daynight == null:
		_daynight = get_node_or_null("../DayNight")
	_cablato = _visitors != null and _daynight != null


# ============================================================ la logica pura
# Tutto ciò che DECIDE è puro: entra un elenco di righe, esce un numero o un
# nome. Si prova headless, senza villaggio e senza aspettare cento giorni.

## QUANTO CONTA `altro` PER `io`, letto dal libro mastro. Puro.
##
## `lealta` (0..1) allunga la memoria: è il solo parametro di carattere che
## entra qui, ed è quello che rende una coppia inespugnabile senza doverla
## proteggere con un'eccezione.
static func conto(righe: Array, io: String, altro: String, oggi: int,
		lealta := 0.5) -> float:
	var mezza_vita := lerpf(RECENZA_BASE, RECENZA_LEALE, clampf(lealta, 0.0, 1.0))
	var tot := 0.0
	for r in righe:
		var da := str((r as Dictionary).get("a", ""))
		var verso := str((r as Dictionary).get("b", ""))
		# la riga conta se lega proprio questi due, in un verso o nell'altro
		if not ((da == altro and verso == io) or (da == io and verso == altro)):
			continue
		var peso: float = float(GESTI.get(str((r as Dictionary).get("t", "")), 0.0))
		if is_zero_approx(peso):
			continue
		var giorni: float = maxf(0.0, float(oggi - int((r as Dictionary).get("d", 0))))
		var recenza: float = pow(0.5, giorni / mezza_vita)
		# ESSERE CERCATI conta quasi il doppio che cercare
		var quanto: float = 1.0 if da == altro else ASIMMETRIA
		tot += peso * recenza * quanto
	return tot


## Chi conta di più per `io`, e quanto. Puro. Ritorna ["", 0.0] se non c'è
## nessuno — e anche quando il primo NON STACCA il secondo di `margine`
## (vedi `MARGINE_ELEZIONE`): a pari merito il gioco non sceglie al posto
## suo, perché l'unica cosa che romperebbe il pareggio sarebbe l'ordine
## dell'array dei residenti.
## ⚠️ **E `tutti` SI LEGGE COME UN INSIEME, non come una lista.** Il libro
## mastro è indicizzato per NOME del dna, e i nomi in questo villaggio NON
## sono unici: `Visitors._spawn_candidate` rigenera il DNA finché è nuova la
## **label**, e cinque archetipi per ventotto nomi vuol dire che «il gattino
## Cannella» e «la volpina Cannella» convivono senza che niente si lamenti
## (sta scritto in `Visitors.gd`: «Le label sono uniche e i nomi no»).
##
## Con lo stesso nome due volte nell'elenco, la seconda passata cadeva nel
## ramo `elif c > secondo` e portava `secondo` a PAREGGIARE `quanto` — e poi
## il margine dell'elezione, che esiste per non scegliere a pari merito,
## trovava un pari merito fabbricato dal doppione e tornava `["", 0.0]`.
## MISURATO sulle funzioni pure, stessa storia e stesso libro mastro:
## `coppia(Io, Cannella)` vale **true** senza omonimo e **false** con un
## omonimo in anagrafe. Cioè: chiunque avesse come più caro uno dei due
## omonimi non poteva formare coppia, mai, e in silenzio.
##
## Il rimedio sta QUI e non solo in `_tutti()` perché questa è statica e
## l'elenco glielo passano in quattro (`coppie`, `coppia`, `chi_e_il_piu_caro`,
## `Cricche`): una funzione pura deve reggere il proprio ingresso.
## ⚠️ **Resta aperto, ed è un'altra cosa:** due omonimi CONDIVIDONO la riga
## del libro mastro, quindi i gesti dell'uno contano per l'altro. Quello è il
## residuo delle due anagrafi, e non si chiude di qua.
static func il_piu_caro(righe: Array, io: String, tutti: Array, oggi: int,
		lealta := 0.5, margine := MARGINE_ELEZIONE) -> Array:
	var chi := ""
	var quanto := 0.0
	var secondo := 0.0
	var visti := {}
	for altro in tutti:
		if str(altro) == io or visti.has(str(altro)):
			continue
		visti[str(altro)] = true
		var c := conto(righe, io, str(altro), oggi, lealta)
		if c > quanto:
			secondo = quanto
			quanto = c
			chi = str(altro)
		elif c > secondo:
			secondo = c
	if chi == "":
		return ["", 0.0]
	if secondo > 0.0 and quanto < secondo * margine:
		return ["", 0.0]
	return [chi, quanto]


## `altro` è ancora in cima per `io`? A PARI MERITO SÌ — ed è voluto: per
## FORMARSI una coppia serve il margine di `il_piu_caro`, per RESTARE no.
## È la stessa isteresi per cui `ancora_coppia` non chiede la soglia
## assoluta: se pretendessimo il margine anche qui, il giorno in cui un
## terzo pareggia (i gesti «a tutti» pareggiano di continuo) la coppia si
## scioglierebbe da sola — e il calendario tornerebbe a fare il lavoro che
## devono fare i gesti. Puro.
static func resta_il_primo(righe: Array, io: String, altro: String,
		tutti: Array, oggi: int, lealta := 0.5) -> bool:
	var mio := conto(righe, io, altro, oggi, lealta)
	if mio <= 0.0:
		return false
	for terzo in tutti:
		if str(terzo) == io or str(terzo) == altro:
			continue
		if conto(righe, io, str(terzo), oggi, lealta) > mio:
			return false
	return true


## Quante righe di peso VERO ci sono fra due: è la valvola contro la
## prossimità travestita da affetto. Puro.
static func gesti_veri(righe: Array, a: String, b: String) -> int:
	var n := 0
	for r in righe:
		var da := str((r as Dictionary).get("a", ""))
		var verso := str((r as Dictionary).get("b", ""))
		if not ((da == a and verso == b) or (da == b and verso == a)):
			continue
		if absf(float(GESTI.get(str((r as Dictionary).get("t", "")), 0.0))) >= PESO_VERO:
			n += 1
	return n


## SONO UNA COPPIA? Puro, e derivato: nessun campo da tenere in ordine.
##
## Serve il MINIMO RECIPROCO — ognuno è il massimo dell'altro — perché
## l'amore non ricambiato è un'altra cosa, e il gioco lo sapeva già.
static func coppia(righe: Array, a: String, b: String, tutti: Array, oggi: int,
		lealta_a := 0.5, lealta_b := 0.5) -> bool:
	if a == "" or b == "" or a == b:
		return false
	if gesti_veri(righe, a, b) < GESTI_VERI_MIN:
		return false
	var da_a := il_piu_caro(righe, a, tutti, oggi, lealta_a)
	var da_b := il_piu_caro(righe, b, tutti, oggi, lealta_b)
	if str(da_a[0]) != b or str(da_b[0]) != a:
		return false
	return float(da_a[1]) >= SOGLIA_COPPIA and float(da_b[1]) >= SOGLIA_COPPIA


## Tutte le coppie del villaggio, oggi. Pura. Ognuno sta in una sola.
## RESTANO INSIEME? È `coppia()` SENZA la soglia assoluta — l'isteresi che
## mancava. Formarsi costa (bisogna superare `SOGLIA_COPPIA`); restare no:
## una volta che siete voi due, ci vuole QUALCUNO ALTRO per non esserlo più,
## non il calendario.
##
## Senza questa distinzione il decadimento del ricordo faceva da solo il
## lavoro dei gesti: misurato, una coppia appena formata si scioglieva in
## quattro giorni di niente. Era esattamente la macchina del divorzio che il
## progetto si era ripromesso di non scrivere.
static func ancora_coppia(righe: Array, a: String, b: String, tutti: Array,
		oggi: int, lealta_a := 0.5, lealta_b := 0.5) -> bool:
	if a == "" or b == "" or a == b:
		return false
	if gesti_veri(righe, a, b) < GESTI_VERI_MIN:
		return false
	# …e qui NON si passa da `il_piu_caro`: il suo margine serve a non
	# eleggere nessuno a pari merito, ma restare insieme non è un'elezione.
	# Un terzo che PAREGGIA non basta a separare due che stanno insieme:
	# per prenderne il posto deve superarli.
	return resta_il_primo(righe, a, b, tutti, oggi, lealta_a) \
			and resta_il_primo(righe, b, a, tutti, oggi, lealta_b)


static func coppie(righe: Array, tutti: Array, oggi: int,
		lealta := {}) -> Array:
	var out: Array = []
	var presi := {}
	for a in tutti:
		if presi.has(str(a)):
			continue
		var caro := il_piu_caro(righe, str(a), tutti, oggi,
				float(lealta.get(str(a), 0.5)))
		var b := str(caro[0])
		if b == "" or presi.has(b):
			continue
		if coppia(righe, str(a), b, tutti, oggi,
				float(lealta.get(str(a), 0.5)), float(lealta.get(b, 0.5))):
			out.append([str(a), b])
			presi[str(a)] = true
			presi[b] = true
	return out


## La potatura: un libro mastro di quattrocento giorni non serve a nessuno.
## Si buttano le righe così vecchie che la recenza le ha già azzerate — mai
## quelle pesanti, che restano finché resta il villaggio. Pura.
static func pota(righe: Array, oggi: int, tetto := 400) -> Array:
	if righe.size() <= tetto:
		return righe
	var out: Array = []
	for r in righe:
		var peso: float = absf(float(GESTI.get(str((r as Dictionary).get("t", "")), 0.0)))
		var giorni: int = oggi - int((r as Dictionary).get("d", 0))
		# le cose grandi non si dimenticano; le chiacchiere di un anno fa sì
		if peso >= PESO_VERO or giorni < 120:
			out.append(r)
	if out.size() <= tetto:
		return out

	# ⚠️⚠️ **E SE L'ETÀ NON È BASTATA, IL TETTO DEVE ESSERE UN TETTO.**
	# Questa funzione si chiama `pota`, il suo parametro si chiama `tetto` e
	# il chiamante la invoca dentro un `if _righe.size() > 420` — ma il filtro
	# qui sopra tiene una riga se «pesa» **oppure** se ha meno di 120 giornate,
	# e una chiacchiera pesa 0,05: sopravviveva 120 giornate qualunque fosse la
	# dimensione dell'array. Nessuna riga, da nessuna parte, imponeva
	# `out.size() <= tetto`.
	#
	# MISURATO sul `village.json` dell'autore: **1030 righe al giorno 22**,
	# cioè 2,45 volte il tetto, **tutte `chiacchiera`** — `pota()` ne buttava
	# ZERO, e sopra le 420 girava a ogni `gesto()` (due volte per
	# chiacchierata, ogni 3,5 s) per ricopiare 1030 elementi e non togliere
	# niente. E il libro mastro lo rilegge `conto()`, che il giro del giorno
	# chiama una volta per ogni coppia ordinata di residenti.
	#
	# Si lascia andare il LEGGERO più vecchio finché non si rientra. I gesti
	# veri restano intoccabili come prima — è la stessa frase di sopra («le
	# cose grandi non si dimenticano»), applicata anche quando a premere non è
	# il tempo ma la quantità. E toglie le righe che `conto()` pesa di meno:
	# la recenza le aveva già quasi azzerate.
	var leggeri: Array = []
	for i in out.size():
		var w: float = absf(float(GESTI.get(str((out[i] as Dictionary).get("t", "")), 0.0)))
		if w < PESO_VERO:
			leggeri.append(i)
	# dalla più vecchia: l'ordine dell'array è quello di scrittura, ma una
	# fusione di fantasmi o un caricamento possono averlo mescolato
	leggeri.sort_custom(func(a, b):
			return int((out[a] as Dictionary).get("d", 0)) \
					< int((out[b] as Dictionary).get("d", 0)))
	var da_buttare := {}
	var quante: int = mini(out.size() - tetto, leggeri.size())
	for k in quante:
		da_buttare[int(leggeri[k])] = true
	var stretto: Array = []
	for i in out.size():
		if not da_buttare.has(i):
			stretto.append(out[i])
	return stretto


## DA QUANTI GIORNI questa stessa riga — stesso chi, stesso verso, stesso
## tipo — non viene scritta. `-1` se non è mai successo. Pura.
##
## Si deriva da `_righe`, che è già nel salvataggio e che `pota()` non pota
## MAI per le righe pesanti: la risposta è la stessa prima e dopo un
## caricamento, e non c'è nessuno stato nuovo da migrare.
static func giorni_dall_ultimo(righe: Array, da: String, verso: String,
		tipo: String, oggi: int) -> int:
	# il «mai successo» è un BOOLEANO, non un giorno sentinella: con un -1 al
	# posto suo una riga datata a un giorno <= -1 (i provini partono da lì, e
	# un salvataggio storto pure) si leggerebbe come inesistente, e la valvola
	# si aprirebbe di soppiatto
	var trovato := false
	var ultimo := 0
	for r in righe:
		var riga := r as Dictionary
		# la chiave è la TERNA: un «piatto» fra due «veglia» non è una
		# ripetizione — è la differenza fra una consuetudine e due gesti
		if str(riga.get("a", "")) != da or str(riga.get("b", "")) != verso:
			continue
		if str(riga.get("t", "")) != tipo:
			continue
		# ⚠️ dal JSON il giorno torna `float`: senza `int()` il confronto
		# scivola e la valvola si apre (o si chiude) di un giorno
		var g := int(riga.get("d", 0))
		if not trovato or g > ultimo:
			ultimo = g
			trovato = true
	if not trovato:
		return -1
	return maxi(0, oggi - ultimo)


# ------------------------------------------------------------ la reciprocità
#
# CHI HA RICEVUTO E NON HA RICAMBIATO se ne ricorda. Non c'è nessun dato
# nuovo: il libro mastro è DATATO e DIREZIONALE da sempre, e la differenza fra
# i due versi è già scritta — `ASIMMETRIA` esiste apposta perché «un rapporto
# a senso unico si legga storto dai due lati senza una riga di codice
# dedicata». Qui quella riga storta si legge, e basta.
#
# ⚠️ IL VERSO NON SI ROVESCIA MAI. Si muove chi ha RICEVUTO; chi ha dato non
# sa niente, e non deve saperlo. `squilibrio()` è antisimmetrica, quindi per
# ogni debitore esiste un creditore con lo stesso numero cambiato di segno,
# già calcolato, a un `if` di distanza: un ramo su quel segno — «vado a
# riscuotere», «giro al largo da chi mi deve qualcosa» — sarebbe il gioco che
# dice a qualcuno che non ha ricambiato. Questo libro mastro non ha una riga
# «tradimento» (è la regola 5), e non deve averne una scritta col corpo.
#
# ⚠️ E LA LETTURA NON SCRIVE. Il debito si estingue in un modo solo — l'altro
# riceve qualcosa a sua volta — più il tempo che passa. La variante elegante
# (far scrivere alla visita una riga `fianco` vera, che estinguerebbe il
# debito e regalerebbe il raffreddamento) è stata esaminata e SCARTATA: è un
# quinto scrittore autonomo sul libro mastro, sposta `conto()`, quindi
# `il_piu_caro()`, quindi le soglie di `coppia()`, e tutte le misure già prese
# su questo file andrebbero rifatte. È un lavoro suo, con la misura in mano.
# Sta scritta qui come strada aperta, non si fa di contrabbando.

## QUANTO `io` HA RICEVUTO IN PIÙ DI QUANTO HA DATO, verso `altro`. Puro.
##
## Positivo: `io` è in debito, cioè ha ricevuto più di quanto ha reso.
## Negativo: ha dato di più. È la stessa colonna letta dai due lati e
## sottratta, nient'altro — per una riga sola vale `peso * recenza *
## (1 - ASIMMETRIA)`, cioè esattamente la parte di quel gesto che i due non
## leggono uguale.
##
## ⚠️ UNA SOLA `lealta`, e non è pignoleria: con due lealtà diverse
## `squilibrio(a, b)` smetterebbe di essere `-squilibrio(b, a)`, e il
## carattere di UNA persona entrerebbe nel conto di quanto le si DEVE — cioè
## chi è leale «meriterebbe» più riconoscenza. Chi legge passa la propria, e
## legge il proprio debito.
##
## ⚠️ E NON SI DIVIDE MAI per `(1 - ASIMMETRIA)` per «normalizzare» il numero:
## una mutazione che porta `ASIMMETRIA` a 1.0 deve far diventare ROSSO un
## test, non farlo esplodere — un errore a runtime non fa fallire niente,
## interrompe la funzione a metà e lascia la suite verde.
static func squilibrio(righe: Array, io: String, altro: String, oggi: int,
		lealta := 0.5) -> float:
	return conto(righe, io, altro, oggi, lealta) \
			- conto(righe, altro, io, oggi, lealta)


## A CHI `io` DEVE UN GRAZIE, e quanto. Puro. `["", 0.0]` se a nessuno — che è
## il caso normale, ed è un esito, non un ripiego.
##
## È lo scheletro di `il_piu_caro()` con due sole differenze, e nessuna delle
## due è un numero nuovo: si legge lo `squilibrio` invece del `conto`, e chi
## sta sotto `SQUILIBRIO_MIN` non è nemmeno un candidato.
##
## Il resto è identico apposta, `MARGINE_ELEZIONE` compreso: A PARI MERITO NON
## SI ELEGGE NESSUNO. Se due si sono presi cura di te lo stesso giorno e nello
## stesso modo, la sola cosa che romperebbe il pareggio sarebbe l'ordine
## dell'array dei residenti — e il gioco non sceglie al posto di chi deve il
## grazie. (Il pareggio si guarda fra i soli DEBITI: due creditori sotto
## soglia non pareggiano niente, perché nessuno dei due è un creditore.)
##
## ⚠️ UN NEGATIVO NON PUÒ VINCERE, e per costruzione due volte: la soglia è
## positiva e il massimo parte da zero. «Andare a riscuotere» non è un ramo
## che manca — è un ramo che non ha un posto dove stare.
static func da_ringraziare(righe: Array, io: String, tutti: Array, oggi: int,
		lealta := 0.5, margine := MARGINE_ELEZIONE) -> Array:
	var chi := ""
	var quanto := 0.0
	var secondo := 0.0
	for altro in tutti:
		if str(altro) == io:
			continue
		var s := squilibrio(righe, io, str(altro), oggi, lealta)
		# sotto la soglia non è un debito: è la scia di una chiacchiera, o un
		# gesto vero che il tempo ha già quasi finito di chiudere
		if s < SQUILIBRIO_MIN:
			continue
		if s > quanto:
			secondo = quanto
			quanto = s
			chi = str(altro)
		elif s > secondo:
			secondo = s
	if chi == "":
		return ["", 0.0]
	if secondo > 0.0 and quanto < secondo * margine:
		return ["", 0.0]
	return [chi, quanto]


# ============================================================ la porta unica

## UN GESTO È SUCCESSO. È l'unica porta per scrivere sul libro mastro: due
## modi di scrivere la stessa cosa e le due colonne divergono in silenzio.
##
## `da` è chi l'ha fatto, `verso` chi l'ha ricevuto — e l'ordine conta,
## perché essere cercati vale più che cercare.
func gesto(da: String, verso: String, tipo: String) -> void:
	if da == "" or verso == "" or da == verso or not GESTI.has(tipo):
		return
	_cabla()
	var oggi := _giorno()
	# LA VALVOLA CONTRO L'ABITUDINE: un gesto pesante che si ripete ogni
	# giorno fra le stesse due persone non è più una notizia (vedi
	# `GIORNI_RIPETIZIONE`). I gesti leggeri passano sempre: una chiacchiera
	# vale 0,05, e cento chiacchiere devono poter restare cento chiacchiere.
	if absf(float(GESTI.get(tipo, 0.0))) >= PESO_VERO:
		var da_quanto := giorni_dall_ultimo(_righe, da, verso, tipo, oggi)
		if da_quanto >= 0 and da_quanto < GIORNI_RIPETIZIONE:
			return
	_righe.append({"a": da, "b": verso, "t": tipo, "d": oggi})
	if _righe.size() > 420:
		_righe = pota(_righe, _giorno())


## Quanto conta `altro` per `io`, oggi. La porta di lettura.
func quanto(io: String, altro: String) -> float:
	return conto(_righe, io, altro, _giorno(), _lealta_di(io))


## A CHI `nome` DEVE UN GRAZIE, fra quelli che ci sono ADESSO. "" se a
## nessuno, ed è la risposta normale: la maggior parte delle giornate nessuno
## deve niente a nessuno.
##
## L'incapsulamento è quello di `quanto()`, e per la stessa ragione: `_righe`,
## `_giorno()` e `_lealta_di()` sono privati, e un chiamante che si rifacesse
## il conto per conto proprio scriverebbe una gemella con la soglia o il
## margine ricopiati.
##
## ⚠️ `fra` NON HA UN VALORE DI SERIE, e la tentazione c'è: `_tutti()` sta
## venti righe più giù. Ma `_tutti()` comprende chi dorme, chi è nascosto e
## chi è dentro una scena: usarlo come ripiego trasformerebbe «non c'è nessuno
## in giro» in «non ti ho detto chi è in giro», e manderebbe un corpo verso
## una casa chiusa. Chi chiama sa chi è in piedi; questo file no, e non deve
## provare a indovinarlo.
func chi_ringraziare(nome: String, fra: Array) -> String:
	if nome == "" or fra.is_empty():
		return ""
	return str(da_ringraziare(_righe, nome, fra, _giorno(), _lealta_di(nome))[0])


## CHI CONTA DI PIÙ PER `nome`, fra quelli che ci sono adesso. "" a pari
## merito, e "" se il libro mastro non ha ancora niente da dire.
##
## Sostituisce `VillagerBrain.migliore_amico()`, che leggeva `affinita` — un
## contatore di prossimità in circolo chiuso (si sale stando vicini, e si sta
## vicini perché si è saliti). Non è una meccanica nuova: è una migrazione
## finita, e il libro mastro alla stessa domanda risponde con le cose che sono
## successe davanti al giocatore.
##
## ⚠️ QUI NON C'È UNA SOGLIA MINIMA, e la perdita è consapevole: quella
## funzione ne aveva una interna («sotto tre chiacchierate non è ancora
## amicizia»), ma era la soglia di un'ALTRA moneta. Ricopiarla qui vorrebbe
## dire tarare un numero nuovo per una domanda che questo file sa già pesare
## da sé — e il degrado va dove va sempre: libro mastro muto, si risponde "",
## e chi chiama ripiega esattamente come ha sempre fatto.
func chi_e_il_piu_caro(nome: String, fra: Array) -> String:
	if nome == "" or fra.is_empty():
		return ""
	return str(il_piu_caro(_righe, nome, fra, _giorno(), _lealta_di(nome))[0])


## Le coppie del villaggio, adesso.
func le_coppie() -> Array:
	var tutti := _tutti()
	var leali := {}
	for n in tutti:
		leali[str(n)] = _lealta_di(str(n))
	return coppie(_righe, tutti, _giorno(), leali)


## Con chi sta `nome`, o "" se non sta con nessuno.
func compagno_di(nome: String) -> String:
	for c in le_coppie():
		if str((c as Array)[0]) == nome:
			return str((c as Array)[1])
		if str((c as Array)[1]) == nome:
			return str((c as Array)[0])
	return ""


## LE COPPIE DI ADESSO, senza ricalcolarle: è la fotografia che
## `giro_del_giorno()` ha già pagato all'ultimo cambio di giorno.
##
## Chi la legge NON deve chiamare `le_coppie()` per conto suo — quella
## scansione gira una volta per giornata di gioco apposta: MISURATO, il giorno
## che il libro mastro si è riempito è costata 55 secondi.
##
## Torna una COPIA, e l'idioma è quello di `ferita_di()`: `save_extra()`
## restituisce `_coppie_ieri` per riferimento, e un consumatore che mutasse
## l'array riscriverebbe lo stato persistito degli affetti senza passare da
## nessuna porta.
##
## ⚠️ Il nome dice la verità di chi legge, non quella del campo: in coda al
## giro `_coppie_ieri` diventa le coppie di OGGI. Prima del primo giro (una
## partita appena caricata, un banco senza `Legami`) è quello che ha messo
## `load_extra` — cioè le coppie con cui il villaggio si è addormentato.
func coppie_di_oggi() -> Array:
	return _coppie_ieri.duplicate(true)

## CON CHI STAVA IERI, dalla cache giornaliera. `""` se con nessuno.
##
## ⚠️ **E NON PASSA DA `le_coppie()`, che è la stessa funzione fatta al
## momento.** Quella ricostruisce il predicato da capo: per ogni residente un
## `il_piu_caro()` su tutti gli altri, cioè 156 `conto()` con tredici
## abitanti, e ognuno riscorre l'intero libro mastro. Misurato altrove in
## questo file: **~233 ms per chiamata**, ed è il motivo per cui il giro
## degli affetti gira **una volta per giornata di gioco** (quattro minuti
## reali) e non più spesso. Un chiamante che vive dentro un `_process` — il
## tampone sociale del `Limbico`, che chiede «chi gli è accanto adesso» a
## ogni percetto — se la chiedesse ogni volta pianterebbe il fotogramma.
##
## Qui invece si legge `_coppie_ieri`, che è la **fotografia** che
## `giro_del_giorno()` ha già pagato e ha messo da parte (ed è persistita:
## `save_extra`). Al massimo è vecchia di una giornata di gioco, ed è
## esattamente quello che serve a chi chiede «con chi sta»: una coppia è
## un'abitudine, non un fatto del fotogramma.
##
## ⚠️ **L'ANAGRAFE QUI È IL NOME DEL DNA**, non l'etichetta. Tutto questo
## libro mastro è indicizzato per nome (`_tutti()` legge `dna.name`), e le due
## anagrafi del villaggio si somigliano abbastanza da non fare rumore quando
## si sbagliano: chi chiama con una label si prende un `""` e crede che quel
## vicino sia solo.
##
## Degrado dichiarato: prima del primo `giro_del_giorno()` — villaggio appena
## caricato senza salvataggio, banchi, diorama — l'elenco è vuoto e la
## risposta è `""`. Va verso «nessun compagno», cioè verso il gioco che c'era.
func compagno_di_ieri(nome: String) -> String:
	if nome == "":
		return ""
	for c in _coppie_ieri:
		# ⚠️ e la riga si guarda PRIMA di indicizzarla: `_coppie_ieri` torna
		# dal JSON (`load_extra`), e un salvataggio storto darebbe qui un
		# errore a runtime — che nel runner non fa fallire niente e lascia la
		# suite verde con la funzione interrotta a metà.
		if typeof(c) != TYPE_ARRAY or (c as Array).size() < 2:
			continue
		if str((c as Array)[0]) == nome:
			return str((c as Array)[1])
		if str((c as Array)[1]) == nome:
			return str((c as Array)[0])
	return ""


func _tutti() -> Array:
	_cabla()
	var out: Array = []
	if _visitors == null:
		return out
	# l'elenco è un INSIEME di chiavi del libro mastro, non una lista di
	# corpi: i nomi non sono unici (lo sono le label), e un doppione qui
	# spegneva `il_piu_caro` — vedi la nota sopra quella funzione.
	var visti := {}
	for r in (_visitors.get("_residents") as Array):
		var n := str((r.get("dna", {}) as Dictionary).get("name", ""))
		if n != "" and not visti.has(n):
			visti[n] = true
			out.append(n)
	return out


## La lealtà di un vicino, dal suo animo. Senza animo, la media.
func _lealta_di(nome: String) -> float:
	_cabla()
	if _visitors == null:
		return 0.5
	var animi: Dictionary = _visitors.get("_animi")
	for r in (_visitors.get("_residents") as Array):
		if str((r.get("dna", {}) as Dictionary).get("name", "")) != nome:
			continue
		var key := str(r.get("label", ""))
		if animi.has(key):
			var a = animi[key]
			# ⚠️ **LA BASE, e non il tratto di adesso.** Questa lealta' decide
			# la MEZZA VITA con cui `conto()` rilegge TUTTE le righe del libro
			# mastro, comprese quelle di sei mesi fa. Una lealta' che derivasse
			# **riscriverebbe il passato**: `ancora_coppia()` e' un confronto
			# fra conti, e una mezza vita piu' corta schiaccia il passato e
			# lascia in piedi il recente — cioe' potrebbe sciogliere una coppia
			# senza che nessuno abbia fatto niente. La mezza vita e' la
			# grammatica con cui si legge la storia, non un colore.
			#
			# ⚠️ **E ADESSO LA MUTAZIONE E' ROSSA — il residuo e' chiuso.** Quando
			# questa riga e' stata scritta la lealta' non derivava ancora, quindi
			# `tratto` e `tratto_base` davano lo stesso numero e scambiarle
			# lasciava la suite verde: stava scritto qui che chi avrebbe cablato
			# la deriva della lealta' doveva rendere rossa la mutazione **prima**
			# di consegnare. E' stato fatto (`test_deriva`, il caso della lealta'
			# che deriva senza riscrivere il passato).
			#
			# E la MISURA ha corretto il timore di allora, che diceva «una mezza
			# vita piu' corta schiaccia il passato». La deriva della lealta' e'
			# solo POSITIVA (la compagnia e' una prova positiva e basta), quindi
			# la mezza vita si ALLUNGA: sullo stesso identico libro mastro il
			# conto passa da **0.5874 a 0.7443, +27%**. Non scioglie una coppia:
			# ne **fabbrica** una. `SOGLIA_COPPIA` e' un confronto assoluto, e
			# chi ha passato molto tempo con C vedrebbe gonfiarsi il proprio
			# conto con B — cioe' si troverebbe in coppia con B senza che fra
			# loro due sia successo niente di nuovo. E' lo specchio della regola
			# 3: la coppia si forma con GESTI VERI, mai per un coefficiente.
			if a.has_method("tratto_base"):
				return float(a.call("tratto_base", "lealta"))
			return float((a.get("tratti") as Dictionary).get("lealta", 0.5))
	return 0.5


func _giorno() -> int:
	_cabla()
	return int(_daynight.get("day")) if _daynight else 1


# ============================================================ la rottura
# LA ROTTURA NON È UN EVENTO: è il predicato che smette di essere vero.
#
# Non esiste nessuna macchina del divorzio, nessuna tassa giornaliera per
# essersi visti poco, nessuna soglia di pazienza che scende da sola. Due
# smettono di essere una coppia soltanto quando qualcun altro è diventato il
# massimo di uno dei due — e per diventarlo servono GESTI VERI, cioè la
# stessa moneta con cui la coppia si era formata.
#
# È la risposta alla critica più dura che questo sistema abbia ricevuto:
# «formare è limitato dal mondo, rompere non è limitato da niente». Qui le
# due cose costano uguale, perché sono la stessa cosa letta in due momenti.

## Il giro del giorno: si guarda chi non è più una coppia, e chi lo è ancora
## ma per poco. Da chiamare una volta al giorno.
func giro_del_giorno(oggi: int) -> void:
	if oggi == _ultimo_giorno:
		return
	_ultimo_giorno = oggi
	var adesso := le_coppie()
	# chi c'era ieri e oggi non c'è più
	for c in _coppie_ieri:
		var a := str((c as Array)[0])
		var b := str((c as Array)[1])
		if _ancora_insieme(adesso, a, b):
			continue
		# L'ISTERESI: chi c'era ieri non si lascia perché il conto è sceso
		# sotto la soglia di FORMAZIONE — solo perché qualcun altro è
		# diventato il massimo. Senza questa riga il tempo faceva il lavoro
		# dei gesti, e una coppia nata sul filo si scioglieva in quattro
		# giorni di niente.
		if ancora_coppia(_righe, a, b, _tutti(), oggi,
				_lealta_di(a), _lealta_di(b)):
			adesso.append([a, b])
			continue
		_si_sono_lasciati(a, b, oggi)
	_coppie_ieri = adesso
	# e il telegrafo, su chi è ancora insieme
	for c2 in adesso:
		_forse_fragile(str((c2 as Array)[0]), str((c2 as Array)[1]))
	_le_ferite_si_richiudono(oggi)


static func _ancora_insieme(coppie: Array, a: String, b: String) -> bool:
	for c in coppie:
		var x := str((c as Array)[0])
		var y := str((c as Array)[1])
		if (x == a and y == b) or (x == b and y == a):
			return true
	return false


## SI SONO LASCIATI. Ognuno dei due sceglie cosa fare — e sceglie DA SÉ,
## con la stessa macchina che gli fa scegliere il mestiere del giorno, letta
## sui suoi bisogni e sul suo carattere. Il gioco non decide chi ha ragione
## e non chiama nessuno dei due «quello che ha tradito»: nel libro mastro
## non esiste una riga «tradimento», esistono solo gesti.
func _si_sono_lasciati(a: String, b: String, oggi: int) -> void:
	for chi in [a, b]:
		var altro: String = b if chi == a else a
		var animo: Variant = _animo_di(str(chi))
		if animo == null:
			continue
		var possibili: Array = []
		for r in ANIMO.REAZIONI:
			# «stare col piccolo» esiste solo se un piccolo c'è
			if str(r) == "sto_col_piccolo" and not _hanno_un_figlio(str(chi), altro):
				continue
			possibili.append(str(r))
		var scelta := str(animo.call("decide", possibili, altro, ANIMO.NITIDEZZA_VITA))
		if scelta == "":
			continue
		_ferite[str(chi)] = {"reazione": scelta, "ex": altro, "dal": oggi,
				"momenti": 0}
		# il corpo lo dice subito, dal primo giorno: non si aspetta che
		# succeda qualcosa per farlo vedere
		_posa(str(chi), "spalle_basse")


## Il telegrafo: la coppia c'è ancora, ma il margine si è assottigliato. Il
## corpo lo dice — e NON si mostra nessuna classifica: chi guarda vede una
## persona con le spalle basse, non un numero che scende.
func _forse_fragile(a: String, b: String) -> void:
	for chi in [a, b]:
		var altro: String = b if chi == a else a
		var mio := quanto(str(chi), altro)
		var secondo := 0.0
		for terzo in _tutti():
			if str(terzo) == str(chi) or str(terzo) == altro:
				continue
			secondo = maxf(secondo, quanto(str(chi), str(terzo)))
		if secondo <= 0.0 or mio <= 0.0:
			continue
		if mio / maxf(secondo, 0.001) < MARGINE_FRAGILE:
			_posa(str(chi), "distratto")
		else:
			# …E IL TELEGRAFO SI SPEGNE. Il margine può tornare largo (sono
			# bastati due giorni di gesti veri): se la posa restasse, il
			# corpo continuerebbe a dire «questa coppia sta finendo» per il
			# resto della partita, e il giocatore imparerebbe a non
			# crederci più. Solo la NOSTRA posa, mai quella di un altro.
			_posa_via(str(chi))


## LE FERITE SI RICHIUDONO, e la chiave è il giocatore. Ogni momento che lui
## annoda con chi è rimasto solo conta: dopo abbastanza, la risposta finisce
## e la persona torna nel villaggio. Nessuna ferita di questo sistema è
## permanente — sarebbe uno stato assegnato dalla simulazione la cui unica
## chiave è in mano a un altro NPC, e questo gioco non lo fa.
func _le_ferite_si_richiudono(oggi: int) -> void:
	for chi in _ferite.keys():
		var f: Dictionary = _ferite[chi]
		var serve: int = int(MOMENTI_CHIAVE.get(str(f.get("reazione", "")), 2))
		if int(f.get("momenti", 0)) >= serve:
			_ferite.erase(chi)
			# E IL CORPO SI RADDRIZZA. La ferita si chiudeva solo nei dati:
			# la posa restava addosso per il resto della partita, e il gesto
			# più delicato del gioco — il giocatore che sta accanto a chi è
			# rimasto solo, per giorni — non aveva NESSUN riscontro nel
			# corpo di quella persona. Chi guarisce si vede.
			_posa_via(str(chi))
			continue
		# e comunque il tempo, da solo, non basta: passa e non guarisce.
		# (Ma dopo molto tempo la posa smette: restare curvi per sempre non
		# è dolore, è una statua.)
		if oggi - int(f.get("dal", oggi)) > 40:
			_posa_via(str(chi))


## POSA LA NOSTRA POSTURA su `nome`, e si segna che è nostra.
func _posa(nome: String, postura: String) -> void:
	var n := _nodo_di(nome)
	if n == null:
		return
	n.set_meta("postura", postura)
	_pose_nostre[nome] = postura


## TOGLIE la posa di `nome`, ma solo se l'avevamo posata noi ED è ancora
## quella: se nel frattempo un altro sistema ha scritto la sua (il fagotto
## della partenza, il telegrafo della ribellione), la lasciamo stare — e ci
## dimentichiamo della nostra, che non è più addosso a nessuno.
func _posa_via(nome: String) -> void:
	if not _pose_nostre.has(nome):
		return
	var nostra := str(_pose_nostre[nome])
	_pose_nostre.erase(nome)
	var n := _nodo_di(nome)
	if n == null or not n.has_meta("postura"):
		return
	if str(n.get_meta("postura")) == nostra:
		n.remove_meta("postura")


## Il giocatore ha annodato un momento con `nome`: se ha una ferita aperta,
## questo è un passo verso la porta. Lo chiama Legami quando annoda.
func momento_del_giocatore(nome: String) -> void:
	if not _ferite.has(nome):
		return
	var f: Dictionary = _ferite[nome]
	f["momenti"] = int(f.get("momenti", 0)) + 1


## La ferita aperta di `nome`, o {} se sta bene. La leggono i sistemi che
## devono onorarla (la porta di casa, le routine).
func ferita_di(nome: String) -> Dictionary:
	return (_ferite.get(nome, {}) as Dictionary).duplicate()


## `chi` fa entrare `altro` in casa sua? Falso solo se ha chiuso la porta
## PROPRIO a lui: una ferita non rende scontrosi con tutti.
func apre_a(chi: String, altro: String) -> bool:
	var f: Dictionary = _ferite.get(chi, {})
	if str(f.get("reazione", "")) != "chiudo_la_porta":
		return true
	return str(f.get("ex", "")) != altro


func _hanno_un_figlio(a: String, b: String) -> bool:
	var leg := get_tree().get_first_node_in_group("legami")
	if leg == null or not leg.has_method("figli_della_coppia"):
		return false
	return int(leg.call("figli_della_coppia", a, b)) > 0


func _animo_di(nome: String) -> Variant:
	_cabla()
	if _visitors == null:
		return null
	var animi: Dictionary = _visitors.get("_animi")
	for r in (_visitors.get("_residents") as Array):
		if str((r.get("dna", {}) as Dictionary).get("name", "")) != nome:
			continue
		var key := str(r.get("label", ""))
		return animi.get(key)
	return null


func _nodo_di(nome: String) -> Node3D:
	_cabla()
	if _visitors == null:
		return null
	for r in (_visitors.get("_residents") as Array):
		if str((r.get("dna", {}) as Dictionary).get("name", "")) != nome:
			continue
		var n := r.get("node") as Node3D
		return n if (n != null and is_instance_valid(n)) else null
	return null


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"affetti": _righe, "coppie_ieri": _coppie_ieri, "ferite": _ferite}


func load_extra(data: Dictionary) -> void:
	var r: Variant = data.get("affetti")
	if r is Array:
		_righe = r
	var c: Variant = data.get("coppie_ieri")
	if c is Array:
		_coppie_ieri = c
	var f: Variant = data.get("ferite")
	if f is Dictionary:
		_ferite = f


# ============================================================ debug CLI

func debug_stato() -> Dictionary:
	return {"righe": _righe.size(), "coppie": le_coppie(), "ferite": _ferite}
