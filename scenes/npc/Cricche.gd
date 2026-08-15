extends Node

## LE CRICCHE — l'abitudine di trovarsi, e il gruppo che ne esce.
##
## Tre vicini che da qualche giorno finiscono nello stesso angolo alla stessa
## ora non hanno deciso niente: si trovano. Questo file sa dire quando è
## successo, e sa **chiedere all'usciere di farlo vedere** — non muove un
## corpo, non posa una postura, non scrive una parola.
##
## ⚠️ **LA DIFFERENZA FRA «CHIEDE» E «MUOVE» È TUTTA LA STRUTTURA.** Sotto la
## linea «la logica pura» non si tocca l'albero della scena e non si legge un
## orologio: entra un elenco di righe, esce una risposta. Sopra, il nodo fa
## due cose e due sole — incassa la co-presenza e, quando riconosce un
## momento, **lo passa a `Visitors`**, che è l'unico posto del gioco in cui
## si decide se un momento vale il palco. È lo stesso cablaggio di
## `Percezione`, che riconosce uno sguardo e poi chiede.
##
## ============================================================
## È UN PREDICATO DERIVATO, come `Affetti.coppia()`
## ============================================================
## Non esiste da nessuna parte un dato «sono un gruppo». Esiste un ELENCO
## DATATO di incontri — chi, con chi, che giorno, a che ora, in che punto —
## e tutto il resto si RILEGGE da lì ogni volta. Quindi:
##
##  · niente da tenere sincronizzato, niente che resti appeso a metà;
##  · nessun salvataggio da migrare, adesso e mai;
##  · **LA DISSOLUZIONE NON È UN EVENTO**: non c'è nessuna riga «si sono
##    lasciati», nessun contatore che scende, nessuna posa da togliere. Una
##    cricca smette di esistere come si smette di passare da un posto —
##    il predicato smette di essere vero, e basta.
##
## ============================================================
## IL DATO NON È NUOVO: OGGI FINISCE NEL CESTINO
## ============================================================
## `Visitors._chats` costruisce ogni 3,5 s la lista di TUTTE le coppie entro
## 1,9 m in uno stato chiacchierabile — e ne usa UNA, buttando il resto.
## Quella lista *è* la co-presenza del villaggio, già filtrata e già pagata:
## la si registra lì dov'è, senza una casa nuova e senza un secondo giro sui
## residenti.
##
## E la riga che ne esce **NON HA UN VERSO** (i due nomi in ordine
## alfabetico, cioè in un ordine che non vuol dire niente). Da una riga
## senza verso non si ricava chi cercava chi, quindi non si ricava un
## giudizio. È l'opposto esatto di `Affetti.ASIMMETRIA`, ed è voluto:
## l'asimmetria è la grammatica dell'AFFETTO, non quella dell'ABITUDINE.
##
## **E non va in `Affetti._righe`**, che lo dice da sé: «la vicinanza fisica
## non è affetto: senza questo il libro mastro diventa una mappa di chi
## passa più tempo vicino a chi». Una riga di co-presenza lì dentro
## cambierebbe `conto()`, quindi `il_piu_caro()`, quindi `coppia()`.
##
## ============================================================
## LE CINQUE REGOLE CHE NON SI NEGOZIANO
## ============================================================
## 1. **Si conta solo dove si va da sé.** Al falò i posti li assegna
##    `_posto_al_falo(i)`, cioè l'ordine in cui la gente ha traslocato: la
##    vicinanza lì non la sceglie nessuno, e le cricche che ne uscirebbero
##    sarebbero clique per costruzione (i, i+1, i+2) che passano OGNI
##    collaudo. Il falò resta il posto dove una cricca si VEDE, mai quello
##    dove si CONTA. (I quattro cancelli stanno in `Visitors._segna_incontro`.)
## 2. **Mai la maggioranza, mai un ordine, mai un nome.** `2·membri ≤
##    presenti`; sopra il tetto SI TACE invece di scegliere un sottoinsieme;
##    l'uscita è ordinata per nome, cioè per una cosa che non vuol dire
##    niente; a pari merito non si elegge nessuno.
## 3. **La cricca non provoca mai un incontro.** Da qui non esce nessuna
##    meta, nessun anticipo, nessuna azione: il predicato risponde e basta.
## 4. **Nessun segno esclusivo, e non esiste l'elenco di chi è fuori.** Le
##    cricche SI SOVRAPPONGONO (niente `presi`, niente partizione): senza
##    partizione non c'è complemento, quindi «quelli che non sono nel gruppo
##    di X» non è un dato calcolabile — nemmeno per chi, fra due anni,
##    aggiungerà un consumatore che nessuno ha previsto.
## 5. **Una coppia non è un gruppo.** Le coppie il gioco ce le ha già
##    (`Affetti.coppia()`): una cricca comincia da tre.
##
## ============================================================
## QUANTO SUCCEDE DAVVERO — misurato, non sperato
## ============================================================
## `tools/misura_cricche.gd` apre il MainLevel vero e lascia passare sette
## giornate a velocità normale. Con dodici residenti (2026-08-14):
##
##  · **52 incontri, 24 coppie distinte su 66 possibili**, 7,4 al giorno;
##  · **zero righe dal falò** — l'oracolo indipendente del banco ci ha visto
##    52 coppie a portata, e il registro non ne ha presa una;
##  · **due coppie hanno passato il predicato**; altre due, con altrettante
##    giornate (sette e quattro), sono state rifiutate perché si erano viste
##    a ore a caso in posti a caso (dispersione 0,65 e 0,40, scarto 23 m e
##    21 m). **È la prova che le due soglie fini fanno il lavoro**: senza,
##    «si ritrovano» sarebbe stato detto al doppio delle coppie, e metà
##    sarebbe stata gente che si è solo incrociata;
##  · **nessuna cricca**, in sette giornate.
##
## L'ultima riga è la più importante per chi costruirà i canali visibili: il
## caso comune è **il ritrovo a DUE**, e il gruppo a tre è un evento raro,
## che probabilmente lo fa succedere il GIOCATORE mettendo un posto dove tre
## persone convergono. Chi taglia questa meccanica in un pezzo solo, tagli
## il ritrovo a due.
##
## Tutto ciò che DECIDE è `static` e puro: entra un elenco di righe, esce un
## bool o un elenco di nomi. Si prova headless, senza villaggio e senza
## aspettare quattordici giorni.

const POSTO := preload("res://scenes/world/PostoDiSempre.gd")

# ---------------------------------------------------------------- il tempo

## La finestra corta: quanto indietro si guarda per dire «è un'abitudine».
## Sette giornate di gioco sono 28 minuti reali (`DayNight.cycle_seconds`).
const FINESTRA := 7
## QUANTO RICORDA L'ISTERESI: fin dove il setaccio va a cercare il giorno in
## cui una coppia si è formata. Due settimane — otto minuti reali per ogni
## giornata, cinquantasei in tutto.
const FINESTRA_LUNGA := 14

## QUANTO INDIETRO SI TIENE IL REGISTRO, e non è un numero di gusto: è la
## riga più vecchia che la derivazione dell'isteresi può leggere.
##
## `abitudine_da()` rifà la storia giorno per giorno a partire da
## `oggi - FINESTRA_LUNGA`, e in quel giorno legge la sua finestra — cioè
## fino a `FINESTRA - 1` giornate ancora prima. Potare più corto non fa
## risparmiare: fa leggere un passato TRONCATO, e l'isteresi comincia a
## rispondere «non si erano mai trovati» su gruppi che si trovavano — in
## silenzio, e solo alle partite lunghe.
const MEMORIA := FINESTRA_LUNGA + FINESTRA

# ------------------------------------------------------------- le soglie
# NIENTE QUI È INVENTATO. Le tre soglie strette sono le risposte che il
# gioco aveva GIÀ dato alla stessa domanda («cos'è la stessa ora, cos'è lo
# stesso posto, quante volte è un'abitudine»), lette da dove vivono.

## In quante giornate DIVERSE ci si deve trovare. È `PostoDiSempre`: tre
## pomeriggi di fila sullo stesso sasso sono un'abitudine, tre ore nello
## stesso pomeriggio no.
const GIORNATE_RITROVO := POSTO.GIORNI_ABITUDINE
## …e quante ne bastano per RESTARE (l'isteresi, più sotto).
##
## ⚠️ C'è stata anche una seconda clausola — «e almeno tre giornate nelle
## ultime due settimane» — ed è stata TOLTA perché **non poteva mordere**.
## Il setaccio dell'isteresi ricorda `FINESTRA_LUNGA` giorni, e per essere
## viva una coppia deve essersi formata dentro quella memoria; formarsi vuole
## tre giornate in una settimana. Per violare la clausola servirebbe una
## coppia con due sole giornate nelle ultime due settimane e almeno due in
## OGNI settimana di quelle due — cioè quattro. È una contraddizione, non un
## caso raro: era codice morto, e una guardia che nessun test può far fallire
## è una guardia che non c'è. (L'ha trovata una mutazione: portarla a 1
## lasciava la suite verde.)
const GIORNATE_RESTA := 2

## QUANTO PUÒ BALLARE L'ORA. Non è una fascia con dei bordi — sarebbe la
## griglia, e la griglia ha il difetto qui sotto — ma la DISPERSIONE
## CIRCOLARE `1 − R` della media dei versori orari: zero se ci si trova
## sempre allo stesso minuto, uno se l'ora è un dado.
##
## Il numero viene dalla fascia di `PostoDiSempre`: incontri spalmati
## uniformemente su una fetta (un ottavo di giornata, ~30 s reali) danno
## `1 − sin(π/8)/(π/8) = 0,0255`. La soglia stretta è quella, col 18% di
## margine; la larga è la stessa formula per una fascia da ~40 s reali
## (`1 − sin(π/6)/(π/6) = 0,0451`).
const ORA_STRETTA := 0.030
const ORA_LARGA := 0.045

## QUANTO PUÒ BALLARE IL POSTO: lo scarto quadratico medio delle distanze
## dal punto medio. Lo stretto è `PostoDiSempre.CELLA`, cioè il lato del
## quadrato che in questo gioco vuol dire «lo stesso posto».
##
## ⚠️ E NON SI USA `PostoDiSempre.chiave()`: quantizzare in quadrati da 3 m
## fa sparire un trio che si trova a cavallo di un confine — tre corpi entro
## 1,9 m cadono nella stessa cella solo di rado, e un gruppo che non si
## forma perché una linea invisibile gli passa in mezzo è un guasto che non
## lascia tracce. La costante si eredita, la quantizzazione no.
const POSTO_STRETTO := POSTO.CELLA
const POSTO_LARGO := POSTO.CELLA * 1.5

## Quanti si può essere, e quanto può essere grande la macchia di gente che
## si ritrova prima che smetta di essere una cricca. *Un villaggio in cui
## tutti si ritrovano con tutti non ha cricche: ha una piazza.*
const MEMBRI_MAX := 4
const TETTO_COMPONENTE := 8
## Una cricca comincia da tre: due sono una coppia, e le coppie il gioco le
## ha già.
const MEMBRI_MIN := 3

## Quante righe si tengono in tutto prima di potare comunque. È un tetto di
## sicurezza contro un villaggio patologico, non il meccanismo: quello vero
## è `MEMORIA`, che è per giorni.
const RIGHE_MAX := 4000

## LA GRANA CON CUI UNA RIGA VA SUL DISCO. Un decimillesimo di giornata
## (0,024 s reali) e un centimetro: trecento volte più fini delle soglie che
## alimentano, e trentamila righe in meno di salvataggio (vedi `registra`).
const PASSO_ORA := 0.0001
const PASSO_POSTO := 0.01


var _incontri: Array = []      # {a, b, d, o, x, z} — a < b alfabetico, SEMPRE
## Le cricche di oggi. VIVONO IN RAM E NON SI SALVANO MAI: sono derivate,
## e ricalcolarle costa meno che tenerle in ordine.
var _oggi: Array = []
var _ultimo_giorno := -1
var _visitors: Node
var _daynight: Node3D
var _cablato := false


func _ready() -> void:
	add_to_group("cricche")
	add_to_group("persistable")
	_cabla()


## Il cablaggio SI RIPROVA, ed è la trappola già pagata tre volte in questo
## progetto: un riferimento preso una volta sola dentro un `call_deferred`
## del `_ready` resta `null` per sempre, e il sistema gira a vuoto senza un
## errore (è così che è morto il taccuino del Gufo).
## E OGNI CHIAMANTE CHIEDE SOLO QUEL CHE GLI SERVE: incassare un incontro
## vuole l'orologio, rileggere le cricche vuole l'anagrafe. Pretendere tutti
## e due per tutto vorrebbe dire buttare via gli incontri di una giornata
## intera perché un nodo che non c'entra non era ancora nato — in silenzio,
## che è il modo in cui questo sistema può morire senza che nessuno lo veda.
func _cabla() -> void:
	if _cablato:
		return
	if _visitors == null:
		_visitors = get_node_or_null("../Visitors")
	if _daynight == null:
		_daynight = get_node_or_null("../DayNight")
	_cablato = _visitors != null and _daynight != null


## Il giro del giorno, e il giro del MOMENTO. Nessuno dei due rifà il grafo
## sessanta volte al secondo: il primo gira quando cambia il giorno (il
## confronto è l'idioma di `Affetti._ultimo_giorno`, e non passa da un
## segnale così non c'è nessun ordine di connessione che possa perderlo), il
## secondo una volta al secondo e **solo se in questo momento c'è qualcuno
## che si sta ritrovando**.
func _process(delta: float) -> void:
	_cabla()
	if _daynight == null:
		return
	giro_del_giorno(_giorno())
	_guarda(delta)


# ============================================================ la logica pura
# Da qui in giù non si tocca l'albero della scena, non si legge un orologio
# e non si tira un dado. Entra un elenco di righe, esce una risposta.

## LA CHIAVE DI UNA COPPIA, e non ha un verso: i due nomi in ordine
## alfabetico. Il separatore è un a-capo perché un nome non può contenerlo.
static func chiave(a: String, b: String) -> String:
	return (a + "\n" + b) if a < b else (b + "\n" + a)


## SI È REGISTRATO UN INCONTRO? Pura, e con dentro l'unica regola di
## campionamento che c'è: **SI TIENE IL PRIMO INCONTRO DELLA GIORNATA, E
## BASTA.**
##
## È la proprietà che regge tutto il resto. Il predicato diventa immune
## alla cadenza con cui il villaggio guarda (3,5 s oggi, altro domani), al
## numero di residenti, e — soprattutto — a QUALUNQUE cosa il gioco farà
## un giorno per far vedere una cricca: un gesto che tiene fermi due vicini
## un secondo in più cade su una giornata già contata, e vale zero. Un
## sistema che si alimenta da solo è una profezia, non un'osservazione.
static func registra(inc: Array, a: String, b: String, giorno: int,
		ora: float, dove: Vector3) -> bool:
	if a == "" or b == "" or a == b:
		return false
	var primo := a if a < b else b
	var secondo := b if a < b else a
	for r in inc:
		var riga := r as Dictionary
		if int(riga.get("d", 0)) != giorno:
			continue
		if str(riga.get("a", "")) == primo and str(riga.get("b", "")) == secondo:
			return false
	# ⚠️ L'ora NON si normalizza: `fposmod(ora, 1.0)` c'è stato per un giro ed
	# è stato tolto, perché NESSUNA prova poteva farlo fallire — l'ora entra
	# sempre da `DayNight.time` e l'aggregazione la legge con `cos`/`sin`,
	# che sono periodici. Una guardia che nessun test può far fallire è una
	# guardia che non c'è.
	#
	# Si arrotonda, invece, e per una ragione misurata: questo registro va nel
	# salvataggio, e `MEMORIA` giornate di un villaggio pieno (480 righe: 28
	# residenti, 24 incontri al giorno) scritte con tutti i decimali di un
	# `double` pesano **49,6 KB su un `village.json` che ne pesa 85**.
	# Arrotondate ai passi qui sotto — che restano trecento volte più fini
	# delle soglie che alimentano — sono **33,6 KB**, e non si perde una sola
	# decisione.
	inc.append({
		"a": primo, "b": secondo, "d": giorno,
		"o": snappedf(ora, PASSO_ORA),
		"x": snappedf(dove.x, PASSO_POSTO), "z": snappedf(dove.z, PASSO_POSTO),
	})
	return true


## I campioni di una coppia, nell'ordine in cui sono stati scritti. Pura.
static func campioni(inc: Array, a: String, b: String) -> Array:
	var primo := a if a < b else b
	var secondo := b if a < b else a
	var out: Array = []
	for r in inc:
		var riga := r as Dictionary
		if str(riga.get("a", "")) == primo and str(riga.get("b", "")) == secondo:
			out.append(riga)
	return out


## Il registro indicizzato per coppia, in una passata sola. Pura.
static func indice(inc: Array) -> Dictionary:
	var out := {}
	for r in inc:
		var riga := r as Dictionary
		var k := str(riga.get("a", "")) + "\n" + str(riga.get("b", ""))
		if not out.has(k):
			out[k] = []
		(out[k] as Array).append(riga)
	return out


## LA POTATURA. Si buttano le righe più vecchie di `MEMORIA`, che è
## esattamente quanto indietro la derivazione dell'isteresi sa guardare:
## una riga più vecchia non cambierebbe nessuna risposta, e tenerla vuol
## dire solo far pesare il salvataggio. Pura.
static func pota(inc: Array, oggi: int, memoria := MEMORIA) -> Array:
	var out: Array = []
	for r in inc:
		var riga := r as Dictionary
		var eta := oggi - int(riga.get("d", 0))
		if eta >= 0 and eta < memoria:
			out.append(riga)
	return out


# ---------------------------------------------------------------- il profilo
# UNA SOLA aggregazione, letta da tutti. La stessa domanda («in questa
# finestra: quante giornate, dove, a che ora, quanto ballano») la fanno
# quarantacinque volte per coppia il setaccio dell'isteresi e una volta sola
# chi chiede il referto: scriverla due volte — una a scansione e una a
# somme parziali — sarebbe la tabella gemella che questo progetto ha già
# pagato tre volte. Si aggrega per ETÀ (`oggi - giorno`) una volta, e ogni
# finestra si legge poi in tempo costante.

## Le somme parziali dei campioni, per età. Pura.
static func profilo(camp: Array, oggi: int) -> Dictionary:
	var cnt := PackedFloat64Array()
	var gg := PackedFloat64Array()
	var sx := PackedFloat64Array()
	var sz := PackedFloat64Array()
	var sc := PackedFloat64Array()
	var ss := PackedFloat64Array()
	var sq := PackedFloat64Array()
	cnt.resize(MEMORIA)
	gg.resize(MEMORIA)
	sx.resize(MEMORIA)
	sz.resize(MEMORIA)
	sc.resize(MEMORIA)
	ss.resize(MEMORIA)
	sq.resize(MEMORIA)
	var quanti := 0
	for r in camp:
		var riga := r as Dictionary
		# ⚠️ dal JSON il giorno torna `float`: senza `int()` il confronto
		# scivola di un giorno e la finestra si sposta tutta
		var eta := oggi - int(riga.get("d", 0))
		if eta < 0 or eta >= MEMORIA:
			continue
		var o := float(riga.get("o", 0.0))
		var x := float(riga.get("x", 0.0))
		var z := float(riga.get("z", 0.0))
		cnt[eta] += 1.0
		gg[eta] = 1.0     # un'età È una giornata: o c'è o non c'è
		sx[eta] += x
		sz[eta] += z
		sc[eta] += cos(TAU * o)
		ss[eta] += sin(TAU * o)
		sq[eta] += x * x + z * z
		quanti += 1
	if quanti == 0:
		return {}
	return {
		"oggi": oggi,
		"cnt": cnt,
		"pc": _prefissi(cnt), "pg": _prefissi(gg), "px": _prefissi(sx),
		"pz": _prefissi(sz), "pcos": _prefissi(sc), "psin": _prefissi(ss),
		"pq": _prefissi(sq),
	}


static func _prefissi(v: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(v.size() + 1)
	var acc := 0.0
	out[0] = 0.0
	for i in v.size():
		acc += v[i]
		out[i + 1] = acc
	return out


static func _somma(pre: PackedFloat64Array, a0: int, a1: int) -> float:
	return pre[a1 + 1] - pre[a0]


## LA LETTURA DI UNA FINESTRA, vista dal giorno `g`, in somme nude:
## `[quanti, giornate, x medio, z medio, dispersione dell'ora, scarto del
## posto, prima età, ultima età]`. Vuota se non c'è niente da leggere.
##
## È **l'unica aggregazione del file**, e nessuno decide leggendo altro: chi
## deve giudicare chiama `passa()`, chi deve raccontare chiama
## `rapporto_da()`. Scriverne una seconda — una per giudicare e una per
## raccontare — sarebbe la tabella gemella che questo progetto ha già pagato
## tre volte, e divergerebbe il giorno in cui si tocca una soglia.
##
## ⚠️ **Il futuro non si legge**, e non per gentilezza: il setaccio
## dell'isteresi rifà la storia giorno per giorno, e se in una lettura del
## passato entrassero i campioni di dopo, ogni giornata saprebbe come è
## andata a finire. Qui la finestra parte dall'età `oggi - g`, quindi tutto
## ciò che è più recente di `g` è escluso per costruzione — non da un `if`
## che qualcuno può togliere.
static func somme(prof: Dictionary, g: int, finestra: int) -> PackedFloat64Array:
	var vuoto := PackedFloat64Array()
	if prof.is_empty() or finestra <= 0:
		return vuoto
	var oggi := int(prof["oggi"])
	if g > oggi:
		return vuoto
	var a0 := oggi - g
	if a0 >= MEMORIA:
		return vuoto
	var a1 := mini(a0 + finestra - 1, MEMORIA - 1)
	var n := _somma(prof["pc"], a0, a1)
	if n <= 0.0:
		return vuoto
	var mx := _somma(prof["px"], a0, a1) / n
	var mz := _somma(prof["pz"], a0, a1) / n
	var c := _somma(prof["pcos"], a0, a1) / n
	var s := _somma(prof["psin"], a0, a1) / n
	var var_pos := _somma(prof["pq"], a0, a1) / n - (mx * mx + mz * mz)
	return PackedFloat64Array([
		n, round(_somma(prof["pg"], a0, a1)), mx, mz, c, s,
		1.0 - sqrt(c * c + s * s), sqrt(maxf(0.0, var_pos)),
		float(a0), float(a1),
	])


## L'UNICO GIUDIZIO: giornate abbastanza, ora abbastanza ferma, posto
## abbastanza stretto.
static func passa(s: PackedFloat64Array, giorni_min: int, ora_max: float,
		posto_max: float) -> bool:
	if s.is_empty():
		return false
	return int(s[1]) >= giorni_min and s[6] <= ora_max and s[7] <= posto_max


## IL REFERTO, per chi deve raccontare invece di giudicare: giornate, punto
## medio, ora media (circolare) e l'ultima volta che ci si è trovati.
static func rapporto_da(prof: Dictionary, g: int, finestra: int) -> Dictionary:
	var s := somme(prof, g, finestra)
	if s.is_empty():
		return {}
	var oggi := int(prof["oggi"])
	var cnt: PackedFloat64Array = prof["cnt"]
	var ultimo := -1
	for eta in range(int(s[8]), int(s[9]) + 1):
		if cnt[eta] > 0.0:
			ultimo = oggi - eta
			break
	return {
		"giorni": int(s[1]),
		"dove": Vector3(s[2], 0.0, s[3]),
		"ora": fposmod(atan2(s[5], s[4]) / TAU, 1.0),
		"disp": s[6],
		"rms": s[7],
		"ultimo": ultimo,
	}


## IL RITROVO, con le soglie in mano al chiamante. Pura.
## `{}` se non è un'abitudine; altrimenti `{giorni, dove, ora, ultimo}`.
static func ritrovo(inc: Array, a: String, b: String, oggi: int,
		giorni_min: int, ora_max: float, posto_max: float,
		finestra: int) -> Dictionary:
	var prof := profilo(campioni(inc, a, b), oggi)
	if not passa(somme(prof, oggi, finestra), giorni_min, ora_max, posto_max):
		return {}
	return _referto(rapporto_da(prof, oggi, finestra))


static func _referto(rap: Dictionary) -> Dictionary:
	if rap.is_empty():
		return {}
	return {"giorni": rap["giorni"], "dove": rap["dove"],
			"ora": rap["ora"], "ultimo": rap["ultimo"]}


# ------------------------------------------------------------- l'isteresi
# FORMARSI COSTA, RESTARE NO — la forma di `coppia()`/`ancora_coppia()`.
# Senza, una cricca sul filo lampeggia a giorni alterni, e il calendario
# fa il lavoro che devono fare gli incontri.
#
#   si forma:  giornate(7) >= 3  e  disp <= 0,030  e  rms <= 3,0
#   resta:     giornate(7) >= 2  e  disp <= 0,045  e  rms <= 4,5
#
# Tre soglie che si allargano insieme: si resta insieme anche vedendosi meno
# spesso, anche con l'ora che comincia a ballare, anche col posto che si
# sposta. Se solo il conteggio si allargasse, una cricca si scioglierebbe
# perché il ritrovo si è spostato di un metro — che è il calendario travestito
# da gesto.
#
## ============================================================
## E L'ISTERESI È **DERIVATA**, NON RICORDATA
## ============================================================
## Non c'è nessun `_cricche_ieri` nel salvataggio, e non ci sarà: «lo erano
## ieri?» è una domanda a cui il REGISTRO sa già rispondere, perché il
## registro contiene il passato. Si rifà la storia in avanti dal giorno più
## vecchio che la memoria copre, con le stesse due regole, e si guarda dove
## si arriva.
##
## Costa quindici passate (fino a quarantacinque letture, tutte in tempo
## costante sulle somme parziali) e vale anche fuori di qui: dimostra che
## `Affetti._coppie_ieri`, oggi dentro `save_extra()`, è uno stato che si
## potrebbe togliere.
##
## Il residuo è dichiarato, ed è il verso giusto: **l'isteresi ricorda
## quattordici giorni**. Un gruppo che non si è più «formato» (tre giornate
## su sette) in due settimane non è vivo — e se l'abitudine c'è ancora, si
## riforma da sé al primo giorno buono.
static func _si_forma(prof: Dictionary, g: int) -> bool:
	return passa(somme(prof, g, FINESTRA), GIORNATE_RITROVO,
			ORA_STRETTA, POSTO_STRETTO)


static func _resta(prof: Dictionary, g: int) -> bool:
	return passa(somme(prof, g, FINESTRA), GIORNATE_RESTA,
			ORA_LARGA, POSTO_LARGO)


## IL RITROVO VIVO, isteresi compresa: `{}` oppure `{giorni, dove, ora,
## ultimo}` letti sulla finestra corta. Pura.
static func ritrovo_vivo_da(prof: Dictionary, oggi: int) -> Dictionary:
	if prof.is_empty():
		return {}
	var viva := false
	for g in range(oggi - FINESTRA_LUNGA, oggi + 1):
		if _si_forma(prof, g):
			viva = true
		elif viva:
			viva = _resta(prof, g)
	if not viva:
		return {}
	# Il referto si legge sulla finestra CORTA, che è la risposta più
	# aggiornata a «dove, e a che ora». Non è mai vuoto: per essere viva oggi
	# la coppia ha passato o `_si_forma` (>= 3 giornate su 7) o `_resta`
	# (>= 2 su 7), e tutte e due leggono proprio quella finestra.
	return _referto(rapporto_da(prof, oggi, FINESTRA))


## Lo stesso, partendo dai campioni — **con il cancello a buon mercato.**
##
## Non è un'euristica: per essere viva, una coppia deve essersi FORMATA
## almeno una volta, e formarsi vuole `GIORNATE_RITROVO` giornate DIVERSE.
## Con meno campioni di così non c'è nessuna storia da rifare, e si risparmia
## il profilo — che è quasi tutto il costo.
##
## In un villaggio da ventotto ci sono 378 coppie possibili e quasi tutte
## hanno una riga o due: il cancello le spegne tutte insieme. MISURATO su
## registri sintetici da 28 giornate, `cricche()` per intero:
##
##   | registro                        | prima    | dopo    |
##   |---------------------------------|----------|---------|
##   | 20 incontri al giorno           | 10,51 ms | 3,12 ms |
##   | 40 incontri al giorno           | 15,19 ms | 8,45 ms |
##   | sette quartetti che si ritrovano|  8,93 ms | 5,08 ms |
##   | patologico (tutti con tutti)    | 38,13 ms | 35,5 ms |
##
## (Il patologico non cala perché lì le coppie hanno tutte ventotto righe:
## il cancello non ne scarta nessuna. Ma è una scena che il gioco non può
## produrre — `_chats` guarda solo chi sta entro 1,9 m, e il falò, che è
## l'unico posto dove il villaggio si ammassa davvero, non registra.)
static func ritrovo_vivo_camp(camp: Array, oggi: int) -> Dictionary:
	if camp.size() < GIORNATE_RITROVO:
		return {}
	return ritrovo_vivo_da(profilo(camp, oggi), oggi)


static func ritrovo_vivo(inc: Array, a: String, b: String,
		oggi: int) -> Dictionary:
	return ritrovo_vivo_camp(campioni(inc, a, b), oggi)


## SI RITROVANO? Pura. È il predicato, e la coppia che smette di ritrovarsi
## non riceve nessun evento: questa smette di tornare `true`.
static func abitudine(inc: Array, a: String, b: String, oggi: int) -> bool:
	return not ritrovo_vivo(inc, a, b, oggi).is_empty()


static func abitudine_da(camp: Array, oggi: int) -> bool:
	return not ritrovo_vivo_camp(camp, oggi).is_empty()


# ---------------------------------------------------------------- le cricche

## LA CRICCA DI `chi`, o vuota. Pura.
static func cricca_di(inc: Array, chi: String, tutti: PackedStringArray,
		presenti: int, oggi: int) -> PackedStringArray:
	return _cricca(_contesto(inc, tutti, oggi), chi, presenti)


## TUTTE le cricche del villaggio, senza doppioni, ordinate per nome —
## cioè per una cosa che non vuol dire niente. Pura.
##
## ⚠️ **Niente `presi`**, e non è una svista: si può stare in due cricche.
## Una partizione avrebbe un complemento, e il complemento di un gruppo è
## l'elenco di chi ne è fuori — il dato che questo sistema si è ripromesso
## di non rendere calcolabile, nemmeno per chi fra due anni aggiungerà un
## consumatore che nessuno ha previsto.
static func cricche(inc: Array, tutti: PackedStringArray, presenti: int,
		oggi: int) -> Array:
	var ctx := _contesto(inc, tutti, oggi)
	var nomi: PackedStringArray = ctx["nomi"]
	var viste := {}
	var out: Array = []
	for nome in nomi:
		var c := _cricca(ctx, str(nome), presenti)
		if c.is_empty():
			continue
		var k := "\n".join(c)
		if viste.has(k):
			continue
		viste[k] = true
		out.append(c)
	out.sort_custom(func(x, y): return "\n".join(x) < "\n".join(y))
	return out


## Il contesto: i nomi in ordine, i campioni per coppia e le coppie vive.
## Si paga una volta per tutte le domande della giornata.
static func _contesto(inc: Array, tutti: PackedStringArray,
		oggi: int) -> Dictionary:
	var nomi := PackedStringArray()
	var visti := {}
	for n in tutti:
		var s := str(n)
		if s == "" or visti.has(s):
			continue
		visti[s] = true
		nomi.append(s)
	nomi.sort()
	var idx := indice(inc)
	var camp := {}
	var vivi := {}
	# ⚠️ `Array` e non `PackedStringArray`: i Packed* sono tipi a VALORE, e
	# `dizionario[k].append(x)` su un Packed appende a una copia che muore
	# subito — il grafo dei vicini resterebbe vuoto, senza un errore.
	var vicini := {}
	for n2 in nomi:
		vicini[str(n2)] = []
	# SI GIRA SUL REGISTRO, non sulle coppie possibili: in un villaggio da
	# ventotto le coppie possibili sono 378 e quelle che si sono davvero
	# incontrate una manciata. Girare sulle possibili vuol dire pagare 378
	# concatenazioni di stringa per trovare quasi sempre il vuoto.
	for k in idx:
		var due: PackedStringArray = str(k).split("\n")
		if due.size() != 2 or not visti.has(due[0]) or not visti.has(due[1]):
			continue
		var c: Array = idx[k]
		camp[k] = c
		if not abitudine_da(c, oggi):
			continue
		vivi[k] = true
		(vicini[due[0]] as Array).append(due[1])
		(vicini[due[1]] as Array).append(due[0])
	# il quaderno dei sottogruppi già collaudati, CONDIVISO fra tutti i
	# membri di una macchia: quattro persone della stessa cricca si fanno le
	# stesse identiche domande, e senza questo il collaudo dell'unione si
	# paga una volta per ciascuna
	return {"nomi": nomi, "camp": camp, "vivi": vivi, "vicini": vicini,
			"oggi": oggi, "quaderno": {}}


static func _componente(ctx: Dictionary, chi: String) -> PackedStringArray:
	var vicini: Dictionary = ctx["vicini"]
	if not vicini.has(chi):
		return PackedStringArray()
	var visti := {chi: true}
	var coda: Array = [chi]
	while not coda.is_empty():
		var n := str(coda.pop_back())
		for v in (vicini[n] as Array):
			if visti.has(str(v)):
				continue
			visti[str(v)] = true
			coda.append(str(v))
	var out := PackedStringArray()
	for k in visti:
		out.append(str(k))
	out.sort()
	return out


## L'ELEZIONE, e si legge come una scala che scende: la macchia di gente
## attorno a `chi`, poi i sottogruppi dal più grande al più piccolo, e ci si
## ferma sul primo che passa. Passa se è una CLIQUE (nessuno entra per
## catena) e se l'UNIONE delle sue righe supera lo stesso collaudo di una
## coppia. Se quel primo è più grande del tetto, si tace; se a quella taglia
## ce ne sono due a pari merito, si tace.
static func _cricca(ctx: Dictionary, chi: String,
		presenti: int) -> PackedStringArray:
	var vuota := PackedStringArray()
	var membri := _componente(ctx, chi)
	var n := membri.size()
	if n < MEMBRI_MIN:
		return vuota
	# *Un villaggio in cui tutti si ritrovano con tutti non ha cricche: ha
	# una piazza.*
	#
	# ⚠️ E NON È SOLO UN LIMITE DI COSTO (che pure è: si enumerano `2^n`
	# sottoinsiemi). La scena in cui questa riga CAMBIA la risposta è una
	# folla LARGA — nove persone che si ritrovano tutte a due a due, ma
	# ognuna in un angolo suo — con dentro un quartetto compatto: senza
	# questo tetto il gioco pescherebbe quei quattro da una piazza di nove,
	# cioè indicherebbe un gruppo dove c'è solo tanta gente. Il caso è in
	# `test_cricche._la_piazza_non_e_una_cricca`, e ci è voluto un secondo
	# banco per vederlo: con nove persone tutte appiccicate, togliere questa
	# riga non cambiava niente (il silenzio arrivava dal tetto dei membri) e
	# la guardia sembrava morta.
	if n > TETTO_COMPONENTE:
		return vuota
	@warning_ignore("integer_division")
	var tetto: int = mini(MEMBRI_MAX, presenti / 2)
	var vivi: Dictionary = ctx["vivi"]
	var indice_chi := -1
	var vic_mask := PackedInt32Array()
	vic_mask.resize(n)
	for i in n:
		if membri[i] == chi:
			indice_chi = i
		var m := 0
		for j in n:
			if i == j:
				continue
			if vivi.has(chiave(membri[i], membri[j])):
				m |= 1 << j
		vic_mask[i] = m
	if indice_chi < 0:
		return vuota
	var bit_chi := 1 << indice_chi
	var quaderno: Dictionary = ctx["quaderno"]
	for taglia in range(n, MEMBRI_MIN - 1, -1):
		var vincitori: Array = []
		for maschera in range(1 << n):
			if (maschera & bit_chi) == 0:
				continue
			if _quanti(maschera) != taglia:
				continue
			if not _e_clique(maschera, vic_mask, n):
				continue
			# la chiave del quaderno sono i NOMI del sottogruppo, non la
			# maschera: la maschera vale solo dentro una macchia
			var nota := _nomi_maschera(membri, maschera, n)
			var rap: Dictionary = quaderno[nota] if quaderno.has(nota) \
					else _rapporto_unione(ctx, membri, maschera, n)
			quaderno[nota] = rap
			if rap.is_empty():
				continue
			vincitori.append([maschera, int(rap["giorni"]), int(rap["ultimo"])])
		if vincitori.is_empty():
			continue
		# *Scegliere quattro su cinque vuol dire che è stato il gioco a
		# lasciare fuori il quinto.* Sopra il tetto si TACE — non si tronca.
		if taglia > tetto:
			return vuota
		vincitori.sort_custom(func(x, y):
			if int(x[1]) != int(y[1]):
				return int(x[1]) > int(y[1])
			return int(x[2]) > int(y[2]))
		# A PARI MERITO NON SI ELEGGE NESSUNO: l'unica cosa che romperebbe
		# il pareggio sarebbe l'ordine dell'anagrafe.
		if vincitori.size() > 1:
			var p: Array = vincitori[0]
			var s: Array = vincitori[1]
			if int(p[1]) == int(s[1]) and int(p[2]) == int(s[2]):
				return vuota
		var vinta := int((vincitori[0] as Array)[0])
		var out := PackedStringArray()
		for i2 in n:
			if (vinta & (1 << i2)) != 0:
				out.append(membri[i2])
		return out
	return vuota


static func _nomi_maschera(membri: PackedStringArray, maschera: int,
		n: int) -> String:
	var out := PackedStringArray()
	for i in n:
		if (maschera & (1 << i)) != 0:
			out.append(membri[i])
	return "\n".join(out)


static func _quanti(maschera: int) -> int:
	var n := 0
	var m := maschera
	while m != 0:
		n += m & 1
		m >>= 1
	return n


## Una clique: NESSUNO ENTRA PER CATENA. Se bastasse essere connessi, due
## coppie che condividono una persona sarebbero un gruppo di tre — e i due
## agli estremi non si sono mai trovati.
static func _e_clique(maschera: int, vic_mask: PackedInt32Array,
		n: int) -> bool:
	for i in n:
		if (maschera & (1 << i)) == 0:
			continue
		if ((vic_mask[i] | (1 << i)) & maschera) != maschera:
			return false
	return true


## LA STESSA REGOLA, A DUE SCALE. Un gruppo non è vero perché le sue coppie
## lo sono una per una: l'UNIONE delle loro righe deve superare lo stesso
## identico collaudo, isteresi compresa. Senza, tre coppie che si trovano in
## tre angoli diversi a tre ore diverse sarebbero una cricca.
static func _rapporto_unione(ctx: Dictionary, membri: PackedStringArray,
		maschera: int, n: int) -> Dictionary:
	var camp: Dictionary = ctx["camp"]
	var unione: Array = []
	for i in n:
		if (maschera & (1 << i)) == 0:
			continue
		for j in range(i + 1, n):
			if (maschera & (1 << j)) == 0:
				continue
			var k := chiave(membri[i], membri[j])
			if camp.has(k):
				unione.append_array(camp[k] as Array)
	return ritrovo_vivo_da(profilo(unione, int(ctx["oggi"])), int(ctx["oggi"]))


# ============================================================ il villaggio
# La parte impura, e fa tre cose: incassa, pota una volta al giorno, e
# risponde. Nessun corpo si muove da qui.

## UN INCONTRO È SUCCESSO. È l'unica porta di scrittura: due modi di
## scrivere la stessa cosa e le due colonne divergono in silenzio.
## I cancelli («si conta solo dove si va da sé») stanno a monte, in
## `Visitors._segna_incontro`, che è l'unico posto che sa che ora è al
## villaggio e chi è in scena.
func incontro(a: String, b: String, mezzo: Vector3) -> void:
	_cabla()
	if _daynight == null:
		return
	registra(_incontri, a, b, _giorno(), _ora(), mezzo)
	if _incontri.size() > RIGHE_MAX:
		_incontri = pota(_incontri, _giorno())


## Il giro del giorno: si pota e si rilegge chi si ritrova con chi. Una
## volta al giorno, e il risultato vive in RAM.
func giro_del_giorno(oggi: int) -> void:
	if oggi == _ultimo_giorno:
		return
	_cabla()
	# ⚠️ Senza anagrafe NON si segna la giornata come fatta: marcarla e poi
	# uscire vorrebbe dire saltare il giro proprio del giorno in cui il
	# villaggio è nato, e nessuno se ne accorgerebbe mai.
	if _visitors == null:
		return
	_ultimo_giorno = oggi
	_incontri = pota(_incontri, oggi)
	_oggi = cricche(_incontri, _tutti(), _presenti(), oggi)
	_coppie = coppie_vive(_incontri, _tutti(), oggi)


## LE COPPIE CHE SI RITROVANO, oggi. Pura.
##
## ⚠️ **È QUESTA, non `cricche()`, LA COSA CHE IL GIOCATORE PUÒ VEDERE.**
## MISURATO nel villaggio vero (`tools/misura_cricche.gd`, dodici residenti,
## sette giornate): **due coppie hanno passato il predicato e nessuna cricca
## a tre**. Se i canali visibili si appendessero alle sole cricche sarebbero
## codice morto in partita con la suite verde — il guasto che questo progetto
## si è già trovato in casa due volte (il Filo Rosso, le coppie di `Affetti`).
##
## E non rende calcolabile niente di nuovo: `abitudine()` rispondeva già per
## ogni coppia, uno per uno. Quello che resta vietato non è la domanda, è il
## CONSUMO — nessun canale di questo sistema si accende sul VUOTO. Chi non si
## ritrova con nessuno non riceve niente di diverso: riceve **esattamente
## quello che riceveva prima che questa cartella esistesse**.
static func coppie_vive(inc: Array, tutti: PackedStringArray,
		oggi: int) -> Array:
	var ci_sono := {}
	for n in tutti:
		ci_sono[str(n)] = true
	var out: Array = []
	var idx := indice(inc)
	for k in idx:
		var due: PackedStringArray = str(k).split("\n")
		if due.size() != 2 or not ci_sono.has(due[0]) or not ci_sono.has(due[1]):
			continue
		var rit := ritrovo_vivo_camp(idx[k], oggi)
		if rit.is_empty():
			continue
		out.append({"a": due[0], "b": due[1], "rit": rit})
	out.sort_custom(func(x, y): return str(x["a"] + x["b"]) < str(y["a"] + y["b"]))
	return out


## CON CHI SI RITROVA `nome`, oggi. Vuoto se con nessuno.
##
## ⚠️ **NON È UNA PARTIZIONE, e la differenza è tutto.** `cricche()` rinuncia
## a `presi` proprio perché una partizione ha un complemento, e il
## complemento di un gruppo è l'elenco di chi ne è fuori. Questa funzione
## non ha nemmeno la forma per averlo: risponde solo «questi qui», e la
## risposta vuota vuol dire «non lo so ancora», non «nessuno lo vuole».
##
## E l'ordine è alfabetico, cioè una cosa che non vuol dire niente: chi
## leggesse il primo elemento come «il più caro» leggerebbe l'anagrafe.
func compagni(nome: String) -> PackedStringArray:
	var out := PackedStringArray()
	for c in _coppie:
		if str(c["a"]) == nome:
			out.append(str(c["b"]))
		elif str(c["b"]) == nome:
			out.append(str(c["a"]))
	out.sort()
	return out


## La cricca di `nome`, oggi. Vuota se non ne ha una.
func cricca(nome: String) -> PackedStringArray:
	for c in _oggi:
		if (c as PackedStringArray).has(nome):
			return c
	return PackedStringArray()


## Il ritrovo vivo fra due, adesso: `{}` oppure `{giorni, dove, ora,
## ultimo}`. Costa una manciata di microsecondi — si può chiedere spesso.
func ritrovo_di(a: String, b: String) -> Dictionary:
	_cabla()
	if _daynight == null:
		return {}
	return ritrovo_vivo(_incontri, a, b, _giorno())


func _tutti() -> PackedStringArray:
	var out := PackedStringArray()
	if _visitors == null:
		return out
	for r in (_visitors.get("_residents") as Array):
		var n := str((r.get("dna", {}) as Dictionary).get("name", ""))
		if n != "":
			out.append(n)
	return out


## I PRESENTI, e vale il tetto `2·membri ≤ presenti`: mai la maggioranza.
func _presenti() -> int:
	return _tutti().size()


func _giorno() -> int:
	return int(_daynight.get("day")) if _daynight else 1


func _ora() -> float:
	return float(_daynight.get("time")) if _daynight else 0.5


# ================================================================ IL MOMENTO
#
# Un predicato che nessuno vede è un foglio di calcolo. Qui sotto ci sono le
# TRE domande che trasformano «questi due si ritrovano» in qualcosa che sta
# sullo schermo — e nessuna delle tre inventa un canale nuovo, un testo, un
# simbolo o un evento: si limitano a riconoscere un istante e a passarlo
# all'usciere, che poi dice di no quasi sempre.
#
#   IL DUETTO          due che ci stanno tornando si fermano, a un battito
#                      l'uno dall'altro                    → `ci_si_trova`
#   CI SEI ANCHE TU    uno ci sta tornando, e nel loro posto ci sei TU
#                                                          → `ci_sei_anche_tu`
#   NON CI SI ALZA     l'agenda tace sei secondi in più mentre l'altro — o
#   PER PRIMI          Mochi — è lì accanto      → `Visitors.trattieni_insieme`
#
# ⚠️ **NESSUNA DELLE TRE FA SUCCEDERE UN INCONTRO.** Non c'è un `manda()`,
# non c'è una meta nuova, non c'è un anticipo, non c'è un dado. È la regola
# «NESSUNA CASA NUOVA» di `Regia`: *il vocabolario non può far succedere le
# cose più spesso, può solo renderle visibili*. Chi si ritrova ci andava
# comunque; quello che cambia è che ogni tanto lo si vede.
#
# ⚠️ **E NESSUNA SI ACCENDE SUL VUOTO.** Ogni condizione qui sotto è un
# FATTO POSITIVO («questi due si ritrovano», «il giocatore è nel loro
# posto»). Non esiste in tutto il file un ramo che chieda «e chi non si
# ritrova con nessuno?»: chi sta da solo attraversa questa sezione senza che
# una riga lo riguardi, e il suo villaggio è **bit per bit** quello di prima.
# La differenza fra «sta bene da solo» e «nessuno lo vuole» non sta nel corpo
# di chi è solo — sta in quello che il gioco fa attorno a lui, e attorno a
# lui non fa niente.

## Ogni quanto ci si guarda intorno. Un secondo: il duetto vuole due corpi
## che stanno convergendo, e la convergenza dura decine di secondi — a
## sessanta volte al secondo si pagherebbero cinquantanove domande per la
## stessa risposta.
const PASSO_GUARDA := 1.0

## FIN DOVE L'ORA È ANCORA «LA LORO». È `ORA_LARGA`, cioè la stessa
## dispersione con cui una coppia RESTA viva: non un numero nuovo, e non a
## caso quello largo — l'ora stretta serve a dire se è un'abitudine, questa a
## dire se adesso è il momento.
const FINESTRA_ORA := ORA_LARGA

## Quanto lontano dal loro posto può ancora puntare il cammino di uno perché
## si dica che «ci sta tornando». Poco più di una cella di `PostoDiSempre`:
## dentro un raggio del genere, arrivare lì o due passi più in là è lo stesso
## posto per chiunque guardi.
const META_VICINA := 4.0

## E quanto vicino dev'essere qualcuno perché si dica che «c'è già».
const ACCANTO := 2.5

## UN DUETTO AL GIORNO IN TUTTO IL VILLAGGIO, e mai due volte sulla stessa
## coppia dentro la settimana.
##
## ⚠️ **I DUE TETTI SONO LA MECCANICA, non una prudenza.** Un momento che
## capita due volte in un minuto smette di essere un momento; e la stessa
## coppia che si ferma l'una per l'altra ogni giorno, sotto gli occhi del
## giocatore, costruirebbe in una settimana la mappa a due a due di chi sta
## con chi — cioè la classifica, dalla porta di servizio.
##
## Vivono in RAM e **non si salvano**: chi chiude il gioco a metà giornata
## può rivedere un duetto che aveva già visto. Perdere una scena è un
## residuo; salvare uno stato di appartenenza sarebbe una regola in meno.
var _duetto_giorno := -1
var _duetto_visti := {}       # chiave della coppia -> giorno
var _guarda_acc := 0.0
var _vicini_prima := {}       # chiave -> distanza al giro precedente
var _coppie: Array = []       # le coppie vive di oggi, dal giro del giorno
## Il referto dei momenti riconosciuti, per i banchi. In RAM, non si salva,
## e nel gioco non lo legge nessuno.
var _momenti := {}


func _conta(k: String) -> void:
	_momenti[k] = int(_momenti.get(k, 0)) + 1


func debug_momenti() -> Dictionary:
	return _momenti.duplicate()


## IL GIRO DEL MOMENTO. Torna presto e a mani vuote nel caso normale, che è
## la maggioranza schiacciante del tempo di gioco: nessuna coppia viva, o
## nessuna la cui ora sia adesso.
func _guarda(delta: float) -> void:
	_guarda_acc -= delta
	if _guarda_acc > 0.0:
		return
	_guarda_acc = PASSO_GUARDA
	if _coppie.is_empty() or _visitors == null or not is_instance_valid(_visitors):
		return
	# SENZA USCIERE NON SI GUARDA NEMMENO. Il degrado va verso quello che
	# c'era: un banco che monta mezzo villaggio, il diorama del titolo, il
	# Prologo — nessuno di loro ha un `Visitors` intero, e nessuno di loro
	# deve vedere un errore per una funzione che non ha chiesto. È la stessa
	# regola con cui `Visitor._capo_concesso` lascia passare chi non ha un
	# registro, e con cui il portiere del cuore che scrive tratta uno zero.
	if not _visitors.has_method("chiedi_duetto"):
		return
	var ora := _ora()
	for c in _coppie:
		var rit: Dictionary = c["rit"]
		# L'ORA È LA LORO? La distanza fra due ore è CIRCOLARE: mezzanotte e
		# le 23:59 distano un minuto, non un giorno.
		if _scarto_ora(ora, float(rit["ora"])) > FINESTRA_ORA:
			continue
		_conta("e' la loro ora")
		_momento_di(str(c["a"]), str(c["b"]), rit)


## La distanza fra due ore sul cerchio della giornata (0..0.5).
static func _scarto_ora(x: float, y: float) -> float:
	var d := absf(fposmod(x - y, 1.0))
	return minf(d, 1.0 - d)


## I due sono nel loro momento: c'è qualcosa da far vedere?
func _momento_di(a: String, b: String, rit: Dictionary) -> void:
	var dove: Vector3 = rit["dove"]
	var la := str(_visitors.call("label_di_nome", a))
	var lb := str(_visitors.call("label_di_nome", b))
	if la == "" or lb == "":
		return
	var na := _visitors.call("node_di", la) as Node3D
	var nb := _visitors.call("node_di", lb) as Node3D
	if na == null or nb == null \
			or not is_instance_valid(na) or not is_instance_valid(nb):
		return
	# I DUE CANALI CHE PRENDONO IL PALCO, e ne parla UNO SOLO per volta.
	#
	# CI SEI ANCHE TU si chiede per primo, apposta: fra «due vicini si sono
	# accorti l'uno dell'altro» e «un vicino si è accorto di TE nel suo
	# posto», la seconda è quella che il giocatore può ricondurre a sé — ed è
	# la regola con cui questo file sceglie sempre, quando deve scegliere.
	if not (_ci_sei_anche_tu(la, na, dove) or _ci_sei_anche_tu(lb, nb, dove)):
		_duetto(la, lb, na, nb, dove)
	# NON CI SI ALZA PER PRIMI: il canale sottrattivo, e **gira sempre**.
	#
	# ⚠️ Prima stava dietro a un `return` e non girava quando uno dei due si
	# era fermato per Mochi — cioè **proprio nella scena in cui il giocatore è
	# lì**, che è quella per cui questo canale esiste. Non è in concorrenza
	# con gli altri due: non prende il gettone, non muove nessuno, e l'unica
	# cosa che fa è non far finire un momento che sta già succedendo.
	var vicino := na.global_position.distance_to(nb.global_position) <= ACCANTO
	var mochi: Variant = _dove_sta_mochi()
	for coppia in [[la, na, nb], [lb, nb, na]]:
		var n_uno := coppia[1] as Node3D
		if n_uno.global_position.distance_to(dove) > ACCANTO:
			continue
		var con_qualcuno := vicino \
				or (mochi != null
					and n_uno.global_position.distance_to(mochi) <= ACCANTO)
		if not con_qualcuno:
			continue
		if bool(_visitors.call("trattieni_insieme", str(coppia[0]))):
			_conta("non ci si alza per primi")


## CI SEI ANCHE TU. Uno sta tornando nel posto in cui si trova con qualcuno,
## alla loro ora, e lì c'è **Mochi**.
##
## ⚠️ **È IL CANALE CHE ESISTE PER IL GIOCATORE, e per questo l'ancora è
## LUI.** Un Punto singolo puntato su un altro vicino, ripetuto ogni giorno,
## renderebbe la coppia leggibile a due a due — cioè la mappa, che questo
## sistema si è ripromesso di non disegnare. Fra vicini si parla solo col
## duetto, che è raro e non si ripete. Verso il giocatore invece si può dire
## tutti i giorni: *sei nel loro posto, alla loro ora, e uno di loro se n'è
## accorto.* È una cosa che ha fatto lui, e che può rifare domani.
func _ci_sei_anche_tu(label: String, nodo: Node3D, dove: Vector3) -> bool:
	var mochi: Variant = _dove_sta_mochi()
	if mochi == null or mochi.distance_to(dove) > ACCANTO:
		return false
	if str(nodo.get("_state")) != "walk":
		return false
	if (nodo.call("meta_cammino") as Vector3).distance_to(dove) > META_VICINA:
		return false
	_conta("? ci sei anche tu")
	if not bool(_visitors.call("chiedi_gesto", label, "ci_sei_anche_tu")):
		return false
	_conta("✓ ci sei anche tu")
	return true


## IL DUETTO. Due che ci stanno tornando, e che **si stanno avvicinando**.
##
## ⚠️ **«SI AVVICINANO» NON È UN ORNAMENTO.** Senza, due che si allontanano
## dallo stesso posto verso mete diverse passerebbero tutte le altre
## condizioni — sono al posto giusto, all'ora giusta, alla distanza giusta —
## e il giocatore vedrebbe due corpi fermarsi insieme voltandosi le spalle.
## Non è «si sono trovati»: è un singhiozzo del motore, cioè la lettura
## esattamente sbagliata.
func _duetto(la: String, lb: String, na: Node3D, nb: Node3D,
		dove: Vector3) -> bool:
	var k := chiave(la, lb)
	var oggi := _giorno()
	# ⚠️ **OGNI NO HA IL SUO NOME, e non è una comodità.** Questo momento tace
	# quasi sempre — è il comportamento normale — e da fuori i silenzi si
	# vedono tutti uguali. MISURATO in sette minuti di partita vera: zero
	# duetti spontanei, e senza queste righe non c'era modo di sapere se a
	# fermarli fosse un tetto (giusto), la geometria (giusta) o il cablaggio
	# (rotto). Il conto sta in RAM, costa un incremento, e lo legge
	# `debug_momenti()`.
	if _duetto_giorno == oggi:
		_conta("· il duetto di oggi è già stato")
		return false
	if oggi - int(_duetto_visti.get(k, -9999)) < FINESTRA:
		_conta("· questi due li ho già fatti vedere")
		return false
	var d := na.global_position.distance_to(nb.global_position)
	var prima := float(_vicini_prima.get(k, -1.0))
	_vicini_prima[k] = d
	if str(na.get("_state")) != "walk" or str(nb.get("_state")) != "walk":
		_conta("· non stanno camminando tutti e due")
		return false
	if (na.call("meta_cammino") as Vector3).distance_to(dove) > META_VICINA:
		_conta("· non ci stanno tornando")
		return false
	if (nb.call("meta_cammino") as Vector3).distance_to(dove) > META_VICINA:
		_conta("· non ci stanno tornando")
		return false
	if prima < 0.0 or d >= prima:
		_conta("· non si stanno avvicinando")
		return false
	_conta("? ci si trova")
	if not bool(_visitors.call("chiedi_duetto", la, lb, "ci_si_trova")):
		return false
	_duetto_giorno = oggi
	_duetto_visti[k] = oggi
	_conta("✓ ci si trova")
	return true


## Dove sta Mochi, o `null` se non c'è un giocatore (i banchi, il diorama).
## Non se lo cerca da sé: **la risposta è di `Visitors`**, che ha il
## riferimento vero, e una seconda strada per la stessa domanda sarebbe la
## tabella gemella al primo giorno in cui qualcuno sposta il nodo.
func _dove_sta_mochi() -> Variant:
	if _visitors == null or not is_instance_valid(_visitors):
		return null
	return _visitors.call("posizione_mochi")


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"incontri": _incontri}


func load_extra(data: Dictionary) -> void:
	var v: Variant = data.get("incontri")
	if v is Array:
		_incontri = v
		# il registro caricato si rilegge subito: `_ultimo_giorno` è ancora
		# a -1, quindi il primo `_process` fa il giro del giorno vero
		_ultimo_giorno = -1


# ============================================================ debug CLI

func debug_stato() -> Dictionary:
	return {"incontri": _incontri.size(), "cricche": _oggi.duplicate(),
			"coppie": _coppie.size(), "giorno": _ultimo_giorno,
			"momenti": _momenti.duplicate()}


## LA LEVA DEI BANCHI, e di nessun altro: fa il giro del momento ADESSO,
## saltando l'accumulatore da un secondo. Un banco che deve vedere un duetto
## non può aspettare che il caso gli faccia cadere il fotogramma giusto
## dentro la finestra in cui i due convergono.
##
## Nel gioco non la chiama nessuno, e un caso della suite scandaglia
## `scenes/` e `systems/` perché resti così.
func debug_guarda_ora() -> void:
	_guarda_acc = 0.0
	_guarda(0.0)
