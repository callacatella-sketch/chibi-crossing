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

var _righe: Array = []        # {a, b, t, d}: da A verso B, tipo, giorno
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
## nessuno.
static func il_piu_caro(righe: Array, io: String, tutti: Array, oggi: int,
		lealta := 0.5) -> Array:
	var chi := ""
	var quanto := 0.0
	for altro in tutti:
		if str(altro) == io:
			continue
		var c := conto(righe, io, str(altro), oggi, lealta)
		if c > quanto:
			quanto = c
			chi = str(altro)
	return [chi, quanto]


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
	_righe.append({"a": da, "b": verso, "t": tipo, "d": _giorno()})
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
			return float((a.get("tratti") as Dictionary).get("lealta", 0.5))
	return 0.5


func _giorno() -> int:
	_cabla()
	return int(_daynight.get("day")) if _daynight else 1


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"affetti": _righe}


func load_extra(data: Dictionary) -> void:
	var r: Variant = data.get("affetti")
	if r is Array:
		_righe = r


# ============================================================ debug CLI

func debug_stato() -> Dictionary:
	return {"righe": _righe.size(), "coppie": le_coppie()}
