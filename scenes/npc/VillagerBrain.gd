extends RefCounted

## Il cervello di un residente: la vita interiore che lo rende
## autosufficiente. Cinque bisogni che scorrono piano (pancino, energia,
## compagnia, meraviglia, cura), un'agenda a utilità che sceglie da sola
## cosa fare per soddisfarli, un'indole procedurale con effetti meccanici
## veri (il goloso ha sempre fame, il timido saluta solo gli amici, il
## sognatore resta sotto le stelle), una stravaganza rara e tutta sua,
## una memoria episodica e le amicizie con gli altri vicini.
##
## Il cervello DECIDE, la macchina a stati del Visitor RECITA, e il
## Regista Lua resta una delle attività possibili ("regia"): quando
## nessun bisogno urge, va in scena la routine composta sul giocatore.

# indole -> effetti: [descrizione, need accelerato, moltiplicatore]
const INDOLI := {
	"goloso": ["ha sempre un certo languorino", "pancino", 1.9],
	"dormiglione": ["poltrisce fino a tardi", "energia", 1.6],
	"mattiniero": ["è in piedi prima del sole", "cura", 1.3],
	"chiacchierone": ["attacca bottone con chiunque", "compagnia", 1.9],
	"timido": ["si scioglie solo con gli amici veri", "meraviglia", 1.2],
	"sognatore": ["si perde a guardare il cielo", "meraviglia", 1.7],
	"ordinato": ["non sopporta un'aiuola trascurata", "cura", 1.8],
	"brontolone": ["brontola, ma ha un cuore di panna", "compagnia", 1.4],
}

# stravaganze: rare, innocue, indimenticabili
const QUIRKS := ["parla_ai_funghi", "paura_farfalle", "canta_alla_luna",
		"colleziona_sassolini", "ballerino", "pisolini_ovunque"]

const QUIRK_LINES := {
	"parla_ai_funghi": "confida i suoi segreti ai funghi",
	"paura_farfalle": "ha una paura buffa delle farfalle",
	"canta_alla_luna": "canticchia alla luna",
	"colleziona_sassolini": "colleziona sassolini bellissimi",
	"ballerino": "ogni tanto fa una piroetta",
	"pisolini_ovunque": "si addormenta nei posti più strani",
}

const MAX_MEMORIA := 6

var indole: Array = []
var quirk := ""
var needs := {"pancino": 0.9, "energia": 1.0, "compagnia": 0.7,
		"meraviglia": 0.6, "cura": 0.8}
var memoria: Array = []      # ricordi recenti: ["concetto", "testo"]
var affinita := {}           # label di un altro residente -> punti
var _rng := RandomNumberGenerator.new()


## L'anima dal DNA: usa indole/quirk scritti nel genoma se ci sono,
## altrimenti li DERIVA in modo deterministico (i residenti salvati
## prima di questa versione ricevono la stessa indole a ogni avvio).
func setup(dna: Dictionary) -> void:
	_rng.seed = hash(str(dna.get("name", "?")) + str(dna.get("fur", "")))
	if dna.has("indole"):
		indole = (dna["indole"] as Array).duplicate()
		quirk = str(dna.get("quirk", ""))
	else:
		# derivazione deterministica dal genoma: due indoli distinte
		var keys := INDOLI.keys()
		var first := _rng.randi() % keys.size()
		var second := (first + 1 + _rng.randi() % (keys.size() - 1)) % keys.size()
		indole = [keys[first], keys[second]]
		quirk = QUIRKS[_rng.randi() % QUIRKS.size()] if _rng.randf() < 0.65 else ""
	# il seme del comportamento quotidiano resta personale ma vario
	_rng.seed = hash(str(dna.get("name", "?"))) + Time.get_ticks_msec() % 1000


func has_indole(id: String) -> bool:
	return id in indole


## Nottambulo: resta alzato quando gli altri rientrano.
func nottambulo() -> bool:
	return has_indole("sognatore") or quirk == "canta_alla_luna"


func descrizione() -> String:
	var parti: Array[String] = []
	for id in indole:
		parti.append(str(INDOLI[id][0]))
	if quirk != "":
		parti.append(str(QUIRK_LINES[quirk]))
	return " · ".join(parti)


# ---------------------------------------------------------------- bisogni

## I bisogni scendono piano; l'indole detta chi scende più in fretta.
## Nel sonno tutto si ferma e l'energia si ricarica: la notte ripara.
func tick(delta: float, asleep := false) -> void:
	if asleep:
		needs["energia"] = minf(1.0, float(needs["energia"]) + 0.05 * delta)
		return
	var rates := {"pancino": 0.010, "energia": 0.007, "compagnia": 0.009,
			"meraviglia": 0.008, "cura": 0.008}
	for id in indole:
		var eff: Array = INDOLI[id]
		rates[eff[1]] = float(rates[eff[1]]) * float(eff[2])
	for k in needs:
		needs[k] = maxf(0.0, float(needs[k]) - float(rates[k]) * delta)


## Un'attività compiuta ricarica il suo bisogno (e scalda il cuore).
func satisfy(tipo: String) -> void:
	match tipo:
		"spuntino":
			needs["pancino"] = 1.0
		"riposo", "pisolino":
			needs["energia"] = 1.0
		"quattro_chiacchiere", "falo":
			needs["compagnia"] = minf(1.0, float(needs["compagnia"]) + 0.7)
		"meraviglia", "stella":
			needs["meraviglia"] = 1.0
		"cura_giardino":
			needs["cura"] = 1.0
			needs["meraviglia"] = minf(1.0, float(needs["meraviglia"]) + 0.2)


func remember(concetto: String, testo: String) -> void:
	memoria.append([concetto, testo])
	if memoria.size() > MAX_MEMORIA:
		memoria = memoria.slice(memoria.size() - MAX_MEMORIA)


func ricordo_recente() -> Array:
	return memoria[memoria.size() - 1] if not memoria.is_empty() else []


func bump_affinita(label: String, n := 1) -> void:
	affinita[label] = int(affinita.get(label, 0)) + n


func migliore_amico() -> String:
	var best := ""
	var best_v := 2   # sotto tre chiacchierate non è ancora amicizia
	for k in affinita:
		if int(affinita[k]) > best_v:
			best_v = int(affinita[k])
			best = str(k)
	return best


# ---------------------------------------------------------------- agenda

## Il cuore dell'autosufficienza: ogni attività possibile riceve un
## punteggio = urgenza del bisogno × indole × contesto, più un filo di
## rumore perché la vita non è un foglio di calcolo. Vince la migliore.
##
## ctx: {"mattina": bool, "sera_stellata": bool, "aiuola_da_annaffiare":
##  bool, "spuntino_vicino": bool, "amico_in_giro": bool, "regia": bool}
func choose(ctx: Dictionary) -> String:
	var punti := {}

	punti["spuntino"] = (1.0 - float(needs["pancino"])) * 2.0 \
			* (1.6 if has_indole("goloso") else 1.0) \
			* (1.0 if bool(ctx.get("spuntino_vicino", false)) else 0.25)

	punti["riposo"] = (1.0 - float(needs["energia"])) * 1.6 \
			* (1.4 if has_indole("dormiglione") else 1.0)

	punti["quattro_chiacchiere"] = (1.0 - float(needs["compagnia"])) * 1.8 \
			* (1.5 if has_indole("chiacchierone") else 1.0) \
			* (0.6 if has_indole("timido") else 1.0) \
			* (1.0 if bool(ctx.get("amico_in_giro", false)) else 0.0)

	punti["cura_giardino"] = (1.0 - float(needs["cura"])) * 1.5 \
			* (1.7 if has_indole("ordinato") else 1.0) \
			* (1.4 if bool(ctx.get("mattina", false)) else 1.0) \
			* (1.0 if bool(ctx.get("aiuola_da_annaffiare", false)) else 0.0)
	# un'aiuola assetata chiama chiunque, anche a pancia piena
	if bool(ctx.get("aiuola_da_annaffiare", false)):
		punti["cura_giardino"] = maxf(float(punti["cura_giardino"]), 0.9)

	punti["meraviglia"] = (1.0 - float(needs["meraviglia"])) * 1.4 \
			* (1.6 if has_indole("sognatore") else 1.0)

	# la sera dei nottambuli: il cielo vince su tutto
	punti["stella"] = 3.0 if bool(ctx.get("sera_stellata", false)) and nottambulo() else 0.0

	# la regia del giocatore: la voce di fondo quando nessun bisogno urge
	punti["regia"] = 0.75 if bool(ctx.get("regia", false)) else 0.0

	var best := "regia" if bool(ctx.get("regia", false)) else "meraviglia"
	var best_v := -1.0
	for k in punti:
		var v: float = float(punti[k]) + _rng.randf() * 0.25
		if v > best_v:
			best_v = v
			best = k
	return best


# ------------------------------------------------------------ persistenza

func to_dict() -> Dictionary:
	return {"needs": needs, "aff": affinita, "mem": memoria,
			"indole": indole, "quirk": quirk}


func from_dict(d: Dictionary) -> void:
	var n: Dictionary = d.get("needs", {})
	for k in needs:
		needs[k] = clampf(float(n.get(k, needs[k])), 0.0, 1.0)
	affinita = d.get("aff", {})
	memoria = d.get("mem", [])
	var ind: Array = d.get("indole", [])
	if not ind.is_empty():
		indole = ind
		quirk = str(d.get("quirk", ""))
