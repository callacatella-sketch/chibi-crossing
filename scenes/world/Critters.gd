class_name Critters
extends RefCounted

## Il bestiario del villaggio: la FONTE UNICA di verità su farfalle, lucciole,
## pesci e raccolti.
##
## Prima questa tabella viveva in tre posti — `Economy` (negozio),
## `Collection` (barattoli) e `CozyWorld` (chi vola nel prato) — e aveva già
## cominciato a divergere: la stessa farfalla si chiamava "Farfalla dorata"
## sul bancone del mercante e "una farfalla gialla" nella vetrina, con due
## rosa diversi. Ogni specie nuova andava aggiunta a mano in tre file, e
## dimenticarne uno non dava errore: dava un pesce senza nome o un colore
## sbagliato. Adesso c'è UNA riga per specie, qui.
##
## Campi di ogni voce:
##   nome      il nome proprio, minuscolo e SENZA articolo ("farfalla dorata").
##             Le due forme che servono al gioco si DERIVANO da qui:
##             `etichetta()` -> "Farfalla dorata" (bancone, titolo)
##             `con_articolo()` -> "una farfalla dorata" (dentro una frase)
##             Così il nome è per definizione lo stesso nei due registri.
##   articolo  "una"/"un"/"uno": l'italiano non si deriva dal nome, va detto.
##   classe    "farfalla" · "lucciola" · "pesce" · "bestiola" · "raccolto"
##             (le bestiole: cicale, scarabei, lumachine, rane — si prendono
##             col retino come le farfalle, ma vivono a terra o sugli alberi)
##   colore    IL colore della creatura: quello che vedi volare, quello del
##             barattolo, quello del pallino nel negozio. Uno solo.
##   vendita   quanto paga il mercante (noccioline, per esemplare)
##   rara      true = acchiapparla regala una stellina
##
## Campi FACOLTATIVI (una specie senza è sempre disponibile, ovunque):
##   cond      QUANDO la specie esiste nel mondo: un dizionario con
##               "stagioni": [0..3]  (0 primavera · 1 estate · 2 autunno · 3 inverno)
##               "ora":      "giorno" | "notte" | "crepuscolo"
##               "meteo":    "pioggia" | "neve" | "nebbia"
##             Le chiavi presenti vanno soddisfatte TUTTE (AND). Per l'ora:
##             "giorno" vale anche al crepuscolo, "notte" pure — solo chi
##             chiede "crepuscolo" ha una finestra esclusiva (alba/tramonto).
##             La verità la dice SOLO disponibile(): nessun altro file deve
##             rifare questo ragionamento a mano.
##   peso      peso di estrazione (spawn/abbocco): più alto = più comune.
##             Senza: 3.0 per le comuni, 1.0 per le rare.
##   max       quante ne possono esistere insieme nel mondo (default 5).
##   luogo     dove nasce: "prato" (default) · "bosco" · "stagno".
##   indizio   la frase dell'enciclopedia per chi non l'ha mai vista:
##             è la sagoma misteriosa a dire DOVE e QUANDO cercare.
##
## L'ORDINE di questa tabella è anche l'ordine delle vetrine dei barattoli.

# id -> voce. L'id è la chiave che viaggia nei salvataggi: NON rinominarlo
# (i nomi visibili invece si possono ritoccare senza rompere i salvataggi).
const SPECIE := {
	# --- farfalle del prato (e chi vola come loro) ---
	"rosa": {"nome": "farfalla rosa", "articolo": "una", "classe": "farfalla",
		"colore": Color("ffd1e0"), "vendita": 3, "rara": false,
		"cond": {"ora": "giorno", "stagioni": [0, 1, 2]}, "peso": 3.0,
		"indizio": "Nel prato, di giorno. La più affettuosa."},
	"azzurra": {"nome": "farfalla azzurra", "articolo": "una", "classe": "farfalla",
		"colore": Color("cfe6ff"), "vendita": 6, "rara": false,
		"cond": {"ora": "giorno", "stagioni": [0, 1, 2]}, "peso": 3.0,
		"indizio": "Nel prato, di giorno, col cielo sereno negli occhi."},
	"gialla": {"nome": "farfalla dorata", "articolo": "una", "classe": "farfalla",
		"colore": Color("fff3c9"), "vendita": 14, "rara": true,
		"cond": {"ora": "giorno", "stagioni": [0, 1, 2]}, "peso": 1.2,
		"indizio": "Un lampo d'oro nel prato, nelle ore di sole."},
	"ciliegio": {"nome": "farfalla di ciliegio", "articolo": "una", "classe": "farfalla",
		"colore": Color("f6d9ee"), "vendita": 16, "rara": true,
		"cond": {"ora": "giorno", "stagioni": [0]}, "peso": 2.0, "max": 2,
		"indizio": "In primavera, di giorno, dove nevicano i petali di ciliegio."},
	"falena": {"nome": "falena della luna", "articolo": "una", "classe": "farfalla",
		"colore": Color("e8e6c0"), "vendita": 24, "rara": true,
		"cond": {"ora": "notte", "stagioni": [2]}, "peso": 2.0, "max": 2,
		"indizio": "Nelle notti d'autunno, al chiaro di luna."},
	"libellula": {"nome": "libellula ambrata", "articolo": "una", "classe": "farfalla",
		"colore": Color("f2c15e"), "vendita": 14, "rara": false,
		"cond": {"ora": "crepuscolo", "stagioni": [0, 1, 2]}, "peso": 2.0, "max": 2,
		"indizio": "Sfiora il prato soltanto all'alba e al tramonto."},
	"neve": {"nome": "farfalla di neve", "articolo": "una", "classe": "farfalla",
		"colore": Color("eaf6ff"), "vendita": 40, "rara": true,
		"cond": {"stagioni": [3], "meteo": "neve"}, "peso": 1.0, "max": 2,
		"indizio": "Rarissima: appare solo d'inverno, mentre la neve scende."},
	# le specie della nebbiolina (Weather.nebbia_del_mattino: mattine
	# d'autunno serene) — il meteo le gòverna da solo, niente doppie
	# condizioni di stagione da tenere allineate a mano
	"bruma": {"nome": "farfalla di bruma", "articolo": "una", "classe": "farfalla",
		"colore": Color("d9d4e6"), "vendita": 16, "rara": false,
		"cond": {"meteo": "nebbia"}, "peso": 2.4, "max": 2,
		"indizio": "Aleggia nella nebbiolina del mattino, come un pensiero."},
	# --- le lucciole della notte ---
	"lucciola": {"nome": "lucciola", "articolo": "una", "classe": "lucciola",
		"colore": Color("d8ffa0"), "vendita": 22, "rara": true,
		"cond": {"ora": "notte"}, "peso": 3.0,
		"indizio": "Si accende vicino a te, quando cala la notte."},
	"regale": {"nome": "lucciola regale", "articolo": "una", "classe": "lucciola",
		"colore": Color("ffe98a"), "vendita": 30, "rara": true,
		"cond": {"ora": "notte", "stagioni": [1]}, "peso": 1.0, "max": 1,
		"indizio": "Una luce più grande e più calda, nelle notti d'estate."},
	# --- i pesci dello stagno ---
	"carpetta": {"nome": "carpa dorata", "articolo": "una", "classe": "pesce",
		"colore": Color("ffd76e"), "vendita": 4, "rara": false, "peso": 5.8,
		"indizio": "Nello stagno, a qualsiasi ora. La prima amica di ogni canna."},
	"azzurrino": {"nome": "pesciolino azzurro", "articolo": "un", "classe": "pesce",
		"colore": Color("8fc0e8"), "vendita": 9, "rara": false, "peso": 3.0,
		"indizio": "Guizza nello stagno, quando gli pare."},
	"rosina": {"nome": "carpa rosina", "articolo": "una", "classe": "pesce",
		"colore": Color("f4a0b8"), "vendita": 18, "rara": true, "peso": 1.2,
		"indizio": "Timida e rara: lo stagno la nasconde bene."},
	"girino": {"nome": "girino", "articolo": "un", "classe": "pesce",
		"colore": Color("8d7f62"), "vendita": 5, "rara": false,
		"cond": {"stagioni": [0]}, "peso": 2.6,
		"indizio": "Nello stagno, in primavera: una virgola con la coda."},
	"alba": {"nome": "pesce dell'alba", "articolo": "un", "classe": "pesce",
		"colore": Color("ffb98a"), "vendita": 16, "rara": false,
		"cond": {"ora": "crepuscolo"}, "peso": 2.4,
		"indizio": "Abbocca solo all'alba e al tramonto, coi colori del cielo."},
	"foglia": {"nome": "carpa foglia d'oro", "articolo": "una", "classe": "pesce",
		"colore": Color("e8a84a"), "vendita": 26, "rara": true,
		"cond": {"stagioni": [2]}, "peso": 1.0,
		"indizio": "D'autunno, quando le foglie d'oro toccano l'acqua."},
	"ghiaccio": {"nome": "pesce ghiaccio", "articolo": "un", "classe": "pesce",
		"colore": Color("cfeaf2"), "vendita": 12, "rara": false,
		"cond": {"stagioni": [3]}, "peso": 2.6,
		"indizio": "Sotto l'acqua fredda d'inverno, quasi trasparente."},
	# --- le bestiole (a terra e sugli alberi, col retino) ---
	"cicala": {"nome": "cicala del bosco", "articolo": "una", "classe": "bestiola",
		"colore": Color("b6a86a"), "vendita": 8, "rara": false,
		"cond": {"ora": "giorno", "stagioni": [1]}, "peso": 2.0, "max": 1,
		"luogo": "bosco",
		"indizio": "Canta sugli alberi del bosco, nelle giornate d'estate."},
	"scarabeo": {"nome": "scarabeo dorato", "articolo": "uno", "classe": "bestiola",
		"colore": Color("d9b545"), "vendita": 20, "rara": true,
		"cond": {"ora": "notte", "stagioni": [1]}, "peso": 1.5, "max": 1,
		"indizio": "Un luccichio nell'erba, nelle notti d'estate."},
	"lumachina": {"nome": "lumachina di pioggia", "articolo": "una", "classe": "bestiola",
		"colore": Color("cbb7e6"), "vendita": 10, "rara": false,
		"cond": {"meteo": "pioggia"}, "peso": 2.0, "max": 2,
		"indizio": "Esce solo quando piove, col suo guscio a spirale."},
	"rana": {"nome": "rana blu", "articolo": "una", "classe": "bestiola",
		"colore": Color("6fa8dc"), "vendita": 15, "rara": false,
		"cond": {"meteo": "pioggia"}, "peso": 2.0, "max": 1, "luogo": "stagno",
		"indizio": "Saltella sulla riva dello stagno, sotto la pioggia."},
	"damigella": {"nome": "damigella di velo", "articolo": "una", "classe": "bestiola",
		"colore": Color("bfe3da"), "vendita": 26, "rara": true,
		"cond": {"meteo": "nebbia"}, "peso": 1.2, "max": 1, "luogo": "stagno",
		"indizio": "Quando lo stagno fuma di nebbia, all'alba, lei cuce l'aria."},
	# --- l'orto e il bosco (si vendono, non si collezionano) ---
	"carota": {"nome": "carota", "articolo": "una", "classe": "raccolto",
		"colore": Color("f0964a"), "vendita": 3, "rara": false},
	"zucca": {"nome": "zucca", "articolo": "una", "classe": "raccolto",
		"colore": Color("e88a3c"), "vendita": 5, "rara": false},
	"bacca": {"nome": "bacca", "articolo": "una", "classe": "raccolto",
		"colore": Color("b0466e"), "vendita": 4, "rara": false},
	# i frutti del frutteto (il semino raro del passerotto, piantato e
	# cresciuto in una stagione: vedi scenes/interact/Frutteto.gd)
	"mela": {"nome": "mela", "articolo": "una", "classe": "raccolto",
		"colore": Color("d94f4f"), "vendita": 6, "rara": false},
	"pera": {"nome": "pera", "articolo": "una", "classe": "raccolto",
		"colore": Color("c9cf6a"), "vendita": 7, "rara": false},
	"fungo": {"nome": "fungo", "articolo": "un", "classe": "raccolto",
		"colore": Color("e9d3a8"), "vendita": 4, "rara": false},
	"porcino": {"nome": "fungo porcino", "articolo": "un", "classe": "raccolto",
		"colore": Color("c69a6d"), "vendita": 15, "rara": false,
		"cond": {"stagioni": [2]},
		"indizio": "Un profumo raro nel sottobosco d'autunno."},
}

## Le classi che finiscono nei barattoli della collezione (i raccolti no:
## quelli si mangiano o si vendono).
const CLASSI_COLLEZIONE := ["farfalla", "lucciola", "pesce", "bestiola"]

## Quanto si satura il colore della creatura per farne il pallino del negozio.
## I colori veri sono pastello tenui (bellissimi in volo, quasi invisibili
## come pallino su carta crema): il pallino è lo STESSO colore, solo più
## carico. Una trasformazione di presentazione, non un secondo colore da
## mantenere a mano.
const SATURA_PALLINO := 1.8


# ---------------------------------------------------------------- accesso

static func esiste(id: String) -> bool:
	return SPECIE.has(id)


static func voce(id: String) -> Dictionary:
	return SPECIE.get(id, {})


## "Farfalla dorata" — il nome col maiuscolo, per titoli e bancone.
## (`capitalize()` di Godot spezzerebbe e ri-maiuscolerebbe ogni parola:
## qui serve solo la prima lettera, "farfalla dorata" -> "Farfalla dorata".)
static func etichetta(id: String) -> String:
	var n := nome(id)
	if n == "":
		return id
	return n.substr(0, 1).to_upper() + n.substr(1)


## "una farfalla dorata" — con l'articolo, per stare dentro una frase.
static func con_articolo(id: String) -> String:
	var v := voce(id)
	if v.is_empty():
		return id
	return "%s %s" % [str(v["articolo"]), str(v["nome"])]


static func nome(id: String) -> String:
	var v := voce(id)
	return str(v["nome"]) if not v.is_empty() else ""


static func colore(id: String) -> Color:
	var v := voce(id)
	return v["colore"] if not v.is_empty() else Color(1, 1, 0.8)


## Il colore della creatura, reso leggibile come pallino su fondo crema.
static func colore_pallino(id: String) -> Color:
	var c := colore(id)
	return Color.from_hsv(c.h, minf(1.0, c.s * SATURA_PALLINO), c.v, c.a)


static func vendita(id: String) -> int:
	var v := voce(id)
	return int(v["vendita"]) if not v.is_empty() else 1


static func rara(id: String) -> bool:
	var v := voce(id)
	return not v.is_empty() and bool(v["rara"])


static func classe(id: String) -> String:
	var v := voce(id)
	return str(v["classe"]) if not v.is_empty() else ""


# ---------------------------------------------------------------- elenchi

## Gli id di una classe, nell'ordine della tabella.
static func della_classe(cl: String) -> Array:
	var out := []
	for id in SPECIE:
		if str(SPECIE[id]["classe"]) == cl:
			out.append(id)
	return out


## Gli id che vanno nei barattoli, nell'ordine delle vetrine.
static func collezionabili() -> Array:
	var out := []
	for id in SPECIE:
		if str(SPECIE[id]["classe"]) in CLASSI_COLLEZIONE:
			out.append(id)
	return out


## Gli id dei pesci (quel che si prende con la canna, non col retino).
static func pesci() -> Array:
	return della_classe("pesce")


## Gli id delle farfalle (chi vola nel prato).
static func farfalle() -> Array:
	return della_classe("farfalla")


## Gli id delle lucciole (chi si accende di notte).
static func lucciole() -> Array:
	return della_classe("lucciola")


## Gli id delle bestiole (chi cammina a terra o canta sugli alberi).
static func bestiole() -> Array:
	return della_classe("bestiola")


## Le specie rare: acchiapparle regala una stellina.
static func rare() -> Array:
	var out := []
	for id in SPECIE:
		if bool(SPECIE[id]["rara"]):
			out.append(id)
	return out


# ------------------------------------------------------ quando e dove
# Il calendario delle specie. Tutto PURO: entra un contesto, esce un sì o
# un no — così le stagioni si provano headless invece che aspettando
# l'inverno a occhio (tests/cases/test_critters_stagioni.gd).

## Le fasce del crepuscolo sull'orologio di DayNight (time 0..1:
## 0.25 = alba, 0.75 = tramonto). Dentro queste fasce l'ora è "crepuscolo".
const ALBA_DA := 0.20
const ALBA_A := 0.33
const TRAMONTO_DA := 0.67
const TRAMONTO_A := 0.80


## Costruisce il contesto con cui si interroga disponibile().
##   stagione  0..3 (da DayNight.get_season())
##   tempo     l'orologio 0..1 di DayNight.time
##   notte     DayNight.is_night() (la soglia vera è la sua, non la nostra)
##   meteo     "sereno" | "pioggia" | "neve" | "nebbia"
static func contesto(stagione: int, tempo: float, notte: bool, meteo: String) -> Dictionary:
	var ora := "notte" if notte else "giorno"
	if (tempo >= ALBA_DA and tempo <= ALBA_A) \
			or (tempo >= TRAMONTO_DA and tempo <= TRAMONTO_A):
		ora = "crepuscolo"
	return {"stagione": stagione, "ora": ora, "meteo": meteo}


## La specie esiste ADESSO nel mondo? Le chiavi di `cond` presenti valgono
## tutte insieme (AND). Semantica dell'ora: chi chiede "giorno" c'è anche al
## crepuscolo, chi chiede "notte" pure — il crepuscolo è la loro frontiera,
## non un buco. Solo chi chiede "crepuscolo" ha la finestra esclusiva.
static func disponibile(id: String, ctx: Dictionary) -> bool:
	var v := voce(id)
	if v.is_empty():
		return false
	var cond: Dictionary = v.get("cond", {})
	if cond.is_empty():
		return true
	if cond.has("stagioni") and not (int(ctx.get("stagione", 0)) in (cond["stagioni"] as Array)):
		return false
	if cond.has("ora"):
		var chiede := str(cond["ora"])
		var ora := str(ctx.get("ora", "giorno"))
		if chiede == "crepuscolo":
			if ora != "crepuscolo":
				return false
		elif not (ora == chiede or ora == "crepuscolo"):
			return false
	if cond.has("meteo") and str(ctx.get("meteo", "sereno")) != str(cond["meteo"]):
		return false
	return true


## Gli id di una classe disponibili in questo contesto, nell'ordine della tabella.
static func disponibili(cl: String, ctx: Dictionary) -> Array:
	var out := []
	for id in della_classe(cl):
		if disponibile(id, ctx):
			out.append(id)
	return out


## Il peso di estrazione (spawn nel prato, abbocco alla canna).
static func peso(id: String) -> float:
	var v := voce(id)
	if v.is_empty():
		return 0.0
	if v.has("peso"):
		return float(v["peso"])
	return 1.0 if bool(v["rara"]) else 3.0


## Quanti esemplari di questa specie possono esistere insieme nel mondo.
static func max_vivi(id: String) -> int:
	return int(voce(id).get("max", 5))


## Dove nasce: "prato" (default) · "bosco" · "stagno".
static func luogo(id: String) -> String:
	return str(voce(id).get("luogo", "prato"))


## La frase dell'enciclopedia per una specie mai vista: dice dove e quando
## cercarla, mai che aspetto ha. È la sagoma misteriosa a far dire
## "ancora cinque minuti".
static func indizio(id: String) -> String:
	var v := voce(id)
	var frase := str(v.get("indizio", ""))
	if frase != "":
		return frase
	return "Qualcuno l'ha vista, da qualche parte..."


## Un'estrazione pesata da un elenco di id (con i pesi della tabella).
## `caso` è un randf() 0..1 passato da fuori: la funzione resta pura.
static func estrai(ids: Array, caso: float) -> String:
	if ids.is_empty():
		return ""
	var tot := 0.0
	for id in ids:
		tot += peso(str(id))
	if tot <= 0.0:
		return str(ids[0])
	var soglia := clampf(caso, 0.0, 0.999999) * tot
	var acc := 0.0
	for id in ids:
		acc += peso(str(id))
		if soglia < acc:
			return str(id)
	return str(ids[ids.size() - 1])
