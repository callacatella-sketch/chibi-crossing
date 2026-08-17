extends RefCounted
## L'UFFICIO DEI PIANI: la parte pura della Fase 3.
##
## La Fase 2 sceglie l'AZIONE («spuntino»). Il risolutore in C++ sceglie la
## CATENA di gesti che ci arriva. In mezzo serve un ufficio che traduca —
## e sono tre tabelle piccole, tenute qui perché siano una sola volta e
## perché si possano provare senza villaggio.
##
## Il verso della traduzione è sempre lo stesso: **i nomi stanno in
## GDScript, gli indici in C++**. Come per le azioni e i bisogni della
## Fase 2, questo file non ripete mai un numero: chiede a `EcsMondo` come
## si chiama l'operatore 7.

## Dall'azione della Fase 2 all'obiettivo della Fase 3.
##
## Quattro azioni su otto hanno un piano. Le altre — «quattro_chiacchiere»,
## «gironzola», «regia», «riposo_forzato» — non ce l'hanno, e non è una
## dimenticanza: pianificare vuol dire poter DESCRIVERE il mondo con dei
## fatti, e «trovare qualcuno con cui parlare» dipende da dove sta andando
## un'altra persona in questo istante. Un piano su una cosa che si muove è
## un piano sbagliato appena lo consegni.
const OBIETTIVO := {
	"spuntino": "provvedi_pancino",
	"cura_giardino": "provvedi_cura",
	"riposo": "provvedi_energia",
	"meraviglia": "provvedi_meraviglia",
}

## I cinque luoghi, NELL'ORDINE di `chibi::Luogo`. Il ponte passa cinque
## double nudi: se quest'ordine e quello del C++ divergono, ogni vicino
## comincia a misurare la strada per il posto sbagliato — in silenzio.
## `test_piani.gd` li lega.
const LUOGHI := ["cibo", "aiuola", "seduta", "bello", "lavagna"]

## Quanto ci mette un chibi a fare un metro. Non è una stima: è
## `Visitor._speed` a riposo (1.45 m/s scalato dall'età), presa al valore
## di un adulto sano. Serve solo a mettere sulla stessa scala i secondi di
## un gesto e i metri di una strada — se fosse un po' diversa, cambierebbe
## di poco quale strada conviene, mai quale gesto è POSSIBILE.
const PASSO := 1.35

## Il luogo irraggiungibile si dichiara con un tempo NEGATIVO: è la doppia
## sicurezza del risolutore, oltre ai bit di raggiungibilità.
const LONTANO := -1.0


static func secondi(metri: float) -> float:
	return metri / PASSO


## L'azione ha un piano?
static func ha_obiettivo(act: String) -> bool:
	return OBIETTIVO.has(act)


## I FATTI DI RAGGIUNGIBILITÀ che questo luogo accende. La differenza fra
## `spuntino_vicino` e `spuntino_raggiungibile` è tutta la Fase 3: il primo
## dice «un cespuglio c'è», il secondo «e ci si arriva».
const FATTO_RAGG := {
	"cibo": "spuntino_raggiungibile",
	"aiuola": "aiuola_raggiungibile",
	"seduta": "seduta_libera_vicina",
	"bello": "meraviglia_raggiungibile",
	"lavagna": "lavagna_pronta",
}


## Da una lista di cinque `{"pos": Vector3, "ok": bool, "metri": float}` ai
## cinque tempi che il ponte si aspetta. Pura apposta: è il pezzo che si
## sbaglia per primo, e va provato senza accendere un villaggio.
static func cammino(luoghi: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(LUOGHI.size())
	for i in LUOGHI.size():
		if i >= luoghi.size():
			out[i] = LONTANO
			continue
		var l: Dictionary = luoghi[i]
		out[i] = secondi(float(l.get("metri", 0.0))) if bool(l.get("ok", false)) else LONTANO
	return out


## E i nomi dei fatti che quei cinque luoghi accendono.
static func fatti(luoghi: Array) -> Array:
	var out := []
	for i in LUOGHI.size():
		if i < luoghi.size() and bool((luoghi[i] as Dictionary).get("ok", false)):
			out.append(str(FATTO_RAGG[LUOGHI[i]]))
	return out
