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
const GIORNI_RIPETIZIONE := 7

## UNA RIGA PER TIPO DI GESTO, e vale come fonte unica. I numeri non sono
## gusto: la scala dice che la vicinanza non è affetto e che proteggere
## qualcuno pesa più che mangiarci insieme.
const GESTI := {
	"chiacchiera": 0.05,        # passare del tempo vicini
	"falo": 0.08,               # la stessa sera, lo stesso fuoco
	"salone": 0.30,             # l'ha visto diventare un altro
	"fianco": 0.35,             # ha attraversato il villaggio per stargli accanto
	"musica": 0.40,             # seduti al buio ad ascoltare
	"promessa": 0.60,           # si è fatto trovare
	"piatto": 0.70,             # ha diviso quello che aveva
	"veglia": 0.80,             # gli ha tenuto accesa una luce
	"posto": 0.90,              # si sono trovati senza dirselo
	"consolazione": 1.00,       # c'era, il giorno del lutto
	"coraggio": 1.20,           # ci è andato per primo
	"nascita": 2.00,            # hanno fatto una vita
	"mancanza": -0.50,          # aveva promesso, e non è venuto
}

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
static func il_piu_caro(righe: Array, io: String, tutti: Array, oggi: int,
		lealta := 0.5, margine := MARGINE_ELEZIONE) -> Array:
	var chi := ""
	var quanto := 0.0
	var secondo := 0.0
	for altro in tutti:
		if str(altro) == io:
			continue
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
	return out


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


func _tutti() -> Array:
	_cabla()
	var out: Array = []
	if _visitors == null:
		return out
	for r in (_visitors.get("_residents") as Array):
		var n := str((r.get("dna", {}) as Dictionary).get("name", ""))
		if n != "":
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
