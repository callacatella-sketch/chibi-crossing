extends RefCounted

## La mente di un aspirante villager: un valutatore in stile percettrone.
##
## La casa candidata viene ridotta a un vettore di feature (tetto, pareti,
## porta, finestra, comfort, giardino, calore, accoglienza, bel tempo);
## ogni specie ha i SUOI pesi — la personalità — e la somma pesata passa
## in una sigmoide: la probabilità di trasferirsi. Niente black box: la
## mente sa anche SPIEGARSI, dicendo cosa le piace e cosa le manca, così
## il giocatore ha sempre una direzione. E ricorda le visite passate:
## tornare a trovare una casa migliorata parte col cuore già più caldo.

const WEIGHTS := {
	"riccio": {
		"bias": -6.0, "roof": 1.6, "walls": 1.2, "door": 0.7, "window": 0.3,
		"comfort": 1.3, "garden": 1.6, "warmth": 0.9, "welcome": 1.7, "sunny": 0.3,
	},
	"passerotto": {
		"bias": -6.0, "roof": 1.3, "walls": 0.8, "door": 0.5, "window": 1.6,
		"comfort": 1.1, "garden": 1.0, "warmth": 0.5, "welcome": 1.8, "sunny": 0.6,
	},
}

const LIKE_LINES := {
	"roof": "Un tetto vero sopra la testa!",
	"walls": "Che pareti solide e curate",
	"door": "Una porta tutta mia…",
	"window": "Adoro guardare fuori dalla finestra",
	"comfort": "È così accogliente qui dentro",
	"garden": "Che giardinetto delizioso qui davanti",
	"warmth": "Il camino scoppietta che è una meraviglia",
	"welcome": "E tu sei così gentile…",
}

const MISS_LINES := {
	"roof": "senza un tetto mi piove sul naso",
	"walls": "servirebbe qualche parete in più",
	"door": "una porta mi farebbe sentire al sicuro",
	"window": "sogno una finestra da cui guardare il prato",
	"comfort": "qualche mobile in più non guasterebbe",
	"garden": "un giardinetto davanti casa sarebbe un sogno",
	"warmth": "un caminetto scalderebbe le zampe",
	"welcome": "mi piacerebbe sentirmi davvero benvenuto",
}

var species := "riccio"
var welcomed := 0.0
var past_visits := 0
var custom_weights := {}


func _init(p_species: String, p_past_visits := 0, p_weights := {}) -> void:
	species = p_species
	past_visits = p_past_visits
	custom_weights = p_weights


# i pesi: quelli scritti nel DNA (chibi generati) o quelli di specie
# (fallback sicuro: "chibi" non è nel dizionario di specie)
func _w() -> Dictionary:
	if not custom_weights.is_empty():
		return custom_weights
	return WEIGHTS.get(species, WEIGHTS["riccio"])


## Ogni benvenuto scalda, ma con ritorni decrescenti: il primo conta tanto.
func add_welcome() -> void:
	welcomed = minf(welcomed + (0.6 if welcomed < 0.1 else (0.3 if welcomed < 0.7 else 0.1)), 1.0)


## features -> somma pesata -> sigmoide. Le visite passate ammorbidiscono
## la diffidenza iniziale: la mente ricorda di essere già stata qui.
func evaluate(f: Dictionary) -> float:
	var w: Dictionary = _w()
	var x: float = float(w.get("bias", -6.0)) + 0.35 * minf(past_visits, 3)
	for key in f:
		if w.has(key):
			x += w[key] * float(f[key])
	x += float(w.get("welcome", 0.0)) * welcomed
	return 1.0 / (1.0 + exp(-x))


# la feature presente che pesa di più per QUESTA personalità
func best_liked(f: Dictionary) -> String:
	var w: Dictionary = _w()
	var best := ""
	var best_v := 0.0
	for key in f:
		if w.has(key) and LIKE_LINES.has(key):
			var v: float = w[key] * float(f[key])
			if v > best_v:
				best_v = v
				best = key
	return L10n.t(str(LIKE_LINES.get(best, "Che bel posticino")))


# la feature assente (o scarsa) che pesa di più: il consiglio azionabile
func most_missed(f: Dictionary) -> String:
	var w: Dictionary = _w()
	var worst := ""
	var worst_v := 0.0
	for key in f:
		if w.has(key) and MISS_LINES.has(key):
			var lack: float = w[key] * (1.0 - clampf(float(f[key]), 0.0, 1.0))
			if lack > worst_v:
				worst_v = lack
				worst = key
	return L10n.t(str(MISS_LINES.get(worst, "")))
