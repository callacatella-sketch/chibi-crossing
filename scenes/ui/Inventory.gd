extends Node

## Le Tasche di Mochi — il cuore-dati dell'inventario. Un modello puro,
## senza UI: la vista è in Pockets.gd, la scelta di COSA regalare pure.
##
## Custodisce le due cose che Mochi porta con sé e può DONARE:
##   · i piatti avanzati dalla cucina (si accumulano: una dispensa di porzioni)
##   · i tesori del bosco (i doni di ricci e passerotti, ora oggetti veri)
## La dispensa di ingredienti resta in Cooking (serve a cucinare, non si
## regala) e la collezione resta sugli scaffali (Collection): le Tasche le
## MOSTRANO soltanto, per avere finalmente il quadro di «cosa ho».
##
## Il gusto dei residenti (l'affinità con un regalo) nasce dai pesi del DNA
## — calore vs giardino, come già decideva _give_dish — ma qui è generalizzato
## a ogni oggetto tramite le sue etichette. È logica pura e testabile: si crea
## con .new(), senza albero, e si interroga (vedi tests/cases/test_inventory.gd).

# ---------------------------------------------------------------- catalogo

## I tesori del bosco: id -> scheda. Le "tags" sono il profilo di gusto.
const TREASURES := {
	"bacca_lucida": {
		"name": "bacca lucida", "art": "la", "tags": ["dolce"],
		"src": "dono del riccio", "icon": "bacca_lucida",
		"desc": "Lucida come una gemma. Troppo bella da mangiare."},
	"funghetto": {
		"name": "funghetto profumato", "art": "il", "tags": ["terroso", "bosco"],
		"src": "dono del riccio", "icon": "funghetto",
		"desc": "Un profumo che sa di pioggia e di muschio."},
	"foglia_cuore": {
		"name": "foglia a cuore", "art": "la", "tags": ["floreale", "dolce"],
		"src": "dono del riccio", "icon": "foglia",
		"desc": "La natura l'ha piegata a forma di cuore."},
	"piuma": {
		"name": "piuma morbidissima", "art": "la", "tags": ["morbido"],
		"src": "dono del passerotto", "icon": "piuma",
		"desc": "Leggera come un soffio. Fa il solletico."},
	"semino": {
		"name": "semino raro", "art": "il", "tags": ["orto"],
		"src": "dono del passerotto", "icon": "semino",
		"desc": "Chissà cosa nasconde. Un regalo di speranza."},
	"fiocco_lana": {
		"name": "fiocco di lana", "art": "il", "tags": ["caldo", "morbido"],
		"src": "dono del passerotto", "icon": "fiocco",
		"desc": "Soffice e caldo. Chi ama il focolare lo adora."},
	# i tesori dei sistemi del mondo (non stanno nei pool dei visitatori:
	# la conchiglia arriva solo in bottiglia, la campanella solo scavando)
	"conchiglia_fiume": {
		"name": "conchiglia di fiume", "art": "la", "tags": ["fresco"],
		"src": "da oltre la cascata", "icon": "conchiglia",
		"desc": "Accostala all'orecchio: dentro c'è ancora la cascata."},
	"campanella_coccio": {
		"name": "campanella di coccio", "art": "la", "tags": ["terroso"],
		"src": "dissotterrata nel prato", "icon": "campanella",
		"desc": "Chissà chi la perse. Suona ancora, un po' stonata."},
}

## Cosa lascia ciascuna specie di visitatore (era testo, ora è un oggetto).
const RICCIO_GIFTS := ["bacca_lucida", "funghetto", "foglia_cuore"]
const PASSEROTTO_GIFTS := ["piuma", "semino", "fiocco_lana"]

## Le due famiglie di gusto. Il calduccio (chi ama camino e coperte) contro il
## fresco dell'orto in fiore. Ogni oggetto pende da una parte o dall'altra.
const COZY_TAGS := ["caldo", "morbido", "terroso"]
const FRESH_TAGS := ["fresco", "orto", "floreale", "dolce", "bosco"]

## Reazioni al regalo (nessun fallimento: ogni dono è almeno gradito).
const REACT_LIKES := 1   # sorride e ringrazia  (+1 amicizia)
const REACT_LOVES := 2   # esulta, lo adora     (+2 amicizia)

# ---------------------------------------------------------------- stato

## I piatti avanzati, in ordine di cucinatura. Ogni voce:
## {id, name, art, warm, tags:[...], icon}. Si accumulano e si impilano per id.
var dishes: Array[Dictionary] = []

## I tesori raccolti: id -> quantità.
var treasures: Dictionary = {}


func _ready() -> void:
	add_to_group("persistable")


# ---------------------------------------------------------------- piatti

## Aggiunge un piatto avanzato alle Tasche (dalla cucina del camino).
func add_dish(entry: Dictionary) -> void:
	dishes.append(entry.duplicate(true))


## Toglie un piatto col dato id (il primo che trova) e lo restituisce.
## {} se non c'è.
func take_dish(id: String) -> Dictionary:
	for i in dishes.size():
		if str(dishes[i].get("id", "")) == id:
			var d: Dictionary = dishes[i]
			dishes.remove_at(i)
			d["kind"] = "dish"   # così chi lo riceve sa che è un piatto
			return d
	return {}


## I piatti raggruppati per id, con la quantità: pronti per la vetrina/regalo.
func dishes_grouped() -> Array[Dictionary]:
	var order: Array[String] = []
	var by_id := {}
	for d in dishes:
		var id := str(d.get("id", ""))
		if not by_id.has(id):
			by_id[id] = d.duplicate(true)
			by_id[id]["count"] = 0
			by_id[id]["kind"] = "dish"
			order.append(id)
		by_id[id]["count"] = int(by_id[id]["count"]) + 1
	var out: Array[Dictionary] = []
	for id in order:
		out.append(by_id[id])
	return out


func has_dish() -> bool:
	return not dishes.is_empty()


# ---------------------------------------------------------------- tesori

## Raccoglie un tesoro del bosco. Ritorna la scheda (o {} se id ignoto).
func add_treasure(id: String, n := 1) -> Dictionary:
	if not TREASURES.has(id):
		return {}
	treasures[id] = int(treasures.get(id, 0)) + n
	return TREASURES[id]


## Un tesoro a caso lasciato dalla specie data (riccio/passerotto): lo
## aggiunge e ne ritorna la scheda con l'id. {} se la specie non dona tesori.
func add_random_gift(species: String, rng_val: int) -> Dictionary:
	var pool: Array = RICCIO_GIFTS if species == "riccio" else \
			(PASSEROTTO_GIFTS if species == "passerotto" else [])
	if pool.is_empty():
		return {}
	var id: String = pool[absi(rng_val) % pool.size()]
	add_treasure(id, 1)
	var scheda: Dictionary = TREASURES[id].duplicate(true)
	scheda["id"] = id
	return scheda


## Toglie un tesoro (scala la quantità) e ne ritorna la scheda con l'id.
func take_treasure(id: String) -> Dictionary:
	if int(treasures.get(id, 0)) <= 0:
		return {}
	treasures[id] = int(treasures[id]) - 1
	if int(treasures[id]) <= 0:
		treasures.erase(id)
	var scheda: Dictionary = TREASURES[id].duplicate(true)
	scheda["id"] = id
	# il "kind" viaggia con l'oggetto consumato: senza, offer_item scambia
	# il tesoro per un piatto (ciotola invece del pacchetto, bond "piatto"
	# invece di "regalo")
	scheda["kind"] = "treasure"
	return scheda


## I tesori posseduti, come schede pronte per la vetrina/regalo.
func treasure_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in TREASURES:
		var n := int(treasures.get(id, 0))
		if n <= 0:
			continue
		var e: Dictionary = TREASURES[id].duplicate(true)
		e["id"] = id
		e["count"] = n
		e["kind"] = "treasure"
		out.append(e)
	return out


# ---------------------------------------------------------------- regali

## Tutto ciò che si può regalare in questo momento: piatti + tesori.
func giftable_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(dishes_grouped())
	out.append_array(treasure_list())
	return out


func has_giftable() -> bool:
	return not dishes.is_empty() or not treasures.is_empty()


## Consuma una voce regalabile (piatto o tesoro) dal suo id+kind e la
## restituisce. {} se non c'è più.
func take_gift(entry: Dictionary) -> Dictionary:
	var id := str(entry.get("id", ""))
	if str(entry.get("kind", "")) == "treasure":
		return take_treasure(id)
	return take_dish(id)


# ---------------------------------------------------------------- affinità

## Quanto un residente gradirebbe un regalo, dalle sue etichette di gusto e
## dai pesi del DNA. Ritorna REACT_LOVES (lo adora) o REACT_LIKES (gli piace).
## Generalizza il vecchio loves_it di _give_dish: il tepore (calore+un po' di
## comfort) contro il verde (giardino) del residente, misurati sull'oggetto.
func affinity(tags: Array, weights: Dictionary) -> int:
	var cozy := float(weights.get("warmth", 0.5)) + 0.5 * float(weights.get("comfort", 0.5))
	var green := float(weights.get("garden", 0.5))
	var prefers_cozy := cozy >= green

	var cozy_hits := 0
	var fresh_hits := 0
	for tag in tags:
		if tag in COZY_TAGS:
			cozy_hits += 1
		if tag in FRESH_TAGS:
			fresh_hits += 1

	# un oggetto senza profilo (o in perfetto equilibrio) piace comunque a tutti
	if cozy_hits == 0 and fresh_hits == 0:
		return REACT_LOVES
	if cozy_hits == fresh_hits:
		return REACT_LOVES
	var item_is_cozy := cozy_hits > fresh_hits
	if item_is_cozy == prefers_cozy:
		return REACT_LOVES
	return REACT_LIKES


## Le etichette di gusto di un piatto, dal suo calore e dagli ingredienti.
## (Statica: la usa Cooking per taggare la porzione avanzata.)
static func dish_tags(warm: bool, need: Dictionary) -> Array:
	var tags: Array = []
	tags.append("caldo" if warm else "fresco")
	for kind in need:
		match kind:
			"bacca":
				if not "dolce" in tags:
					tags.append("dolce")
			"fungo":
				if not "terroso" in tags:
					tags.append("terroso")
			"carota", "zucca":
				if not "orto" in tags:
					tags.append("orto")
	return tags


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	if dishes.is_empty() and treasures.is_empty():
		return {}
	return {"inv_dishes": dishes, "inv_treasures": treasures}


func load_extra(data: Dictionary) -> void:
	dishes.clear()
	for d in data.get("inv_dishes", []):
		if d is Dictionary and d.has("id"):
			dishes.append((d as Dictionary).duplicate(true))
	treasures.clear()
	for id in data.get("inv_treasures", {}):
		if TREASURES.has(id):
			treasures[id] = int(data["inv_treasures"][id])


# ---------------------------------------------------------------- debug CLI

func debug_fill() -> void:
	add_dish({"id": "zuppa_di_carote", "name": "zuppa di carote", "art": "la",
			"warm": true, "tags": ["caldo", "orto"], "icon": "zuppa"})
	add_dish({"id": "risotto_ai_funghi", "name": "risotto ai funghi", "art": "il",
			"warm": true, "tags": ["caldo", "terroso"], "icon": "risotto"})
	add_treasure("fiocco_lana", 1)
	add_treasure("bacca_lucida", 2)
	add_treasure("piuma", 3)
