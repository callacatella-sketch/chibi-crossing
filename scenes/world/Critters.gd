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
##   articolo  "una"/"un": l'italiano non si deriva dal nome, va detto.
##   classe    "farfalla" · "lucciola" · "pesce" · "raccolto"
##   colore    IL colore della creatura: quello che vedi volare, quello del
##             barattolo, quello del pallino nel negozio. Uno solo.
##   vendita   quanto paga il mercante (noccioline, per esemplare)
##   rara      true = acchiapparla regala una stellina
##
## L'ORDINE di questa tabella è anche l'ordine delle vetrine dei barattoli.

# id -> voce. L'id è la chiave che viaggia nei salvataggi: NON rinominarlo
# (i nomi visibili invece si possono ritoccare senza rompere i salvataggi).
const SPECIE := {
	# --- farfalle del prato ---
	"rosa": {"nome": "farfalla rosa", "articolo": "una", "classe": "farfalla",
		"colore": Color("ffd1e0"), "vendita": 3, "rara": false},
	"azzurra": {"nome": "farfalla azzurra", "articolo": "una", "classe": "farfalla",
		"colore": Color("cfe6ff"), "vendita": 6, "rara": false},
	"gialla": {"nome": "farfalla dorata", "articolo": "una", "classe": "farfalla",
		"colore": Color("fff3c9"), "vendita": 14, "rara": true},
	# --- la lucciola della notte ---
	"lucciola": {"nome": "lucciola", "articolo": "una", "classe": "lucciola",
		"colore": Color("d8ffa0"), "vendita": 22, "rara": true},
	# --- i pesci dello stagno ---
	"carpetta": {"nome": "carpa dorata", "articolo": "una", "classe": "pesce",
		"colore": Color("ffd76e"), "vendita": 4, "rara": false},
	"azzurrino": {"nome": "pesciolino azzurro", "articolo": "un", "classe": "pesce",
		"colore": Color("8fc0e8"), "vendita": 9, "rara": false},
	"rosina": {"nome": "carpa rosina", "articolo": "una", "classe": "pesce",
		"colore": Color("f4a0b8"), "vendita": 18, "rara": true},
	# --- l'orto e il bosco (si vendono, non si collezionano) ---
	"carota": {"nome": "carota", "articolo": "una", "classe": "raccolto",
		"colore": Color("f0964a"), "vendita": 3, "rara": false},
	"zucca": {"nome": "zucca", "articolo": "una", "classe": "raccolto",
		"colore": Color("e88a3c"), "vendita": 5, "rara": false},
	"bacca": {"nome": "bacca", "articolo": "una", "classe": "raccolto",
		"colore": Color("b0466e"), "vendita": 4, "rara": false},
	"fungo": {"nome": "fungo", "articolo": "un", "classe": "raccolto",
		"colore": Color("e9d3a8"), "vendita": 4, "rara": false},
}

## Le classi che finiscono nei barattoli della collezione (i raccolti no:
## quelli si mangiano o si vendono).
const CLASSI_COLLEZIONE := ["farfalla", "lucciola", "pesce"]

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


## Le specie rare: acchiapparle regala una stellina.
static func rare() -> Array:
	var out := []
	for id in SPECIE:
		if bool(SPECIE[id]["rara"]):
			out.append(id)
	return out
